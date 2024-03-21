classdef CameraWrapper < handle
    %CAMERAWRAPPER Wraps dabs.resources.devices.Camera
    %   Holds Scanimage-specific information separate from the lower-level interface.
    properties (Hidden)
        hCameraView;
    end
    
    properties(SetObservable)
        cameraToRefTransform = eye(3);  % 3x3 transform matrix from camera space to roi space
        lut = [0 100];                  % Lookup table range for camera view.
        flipH = false;                  % fFlips the camera view horizontally
        flipV = false;                  % flips the camera view vertically
        rotate = 0;                     % rotates the camera view, value in degrees
    end
    
    properties(Dependent)
        displayTransform;       % 3x3 transform matrix from camera space to display view.
        pixelToCameraTransform; % 3x3 transform matrix from pixel location to camera space.
        pixelToRefTransform;    % 3x3 transform matrix from pixel location to roi space.
        cameraName;             % string for camera's unique name.
    end
    
    properties(Hidden,SetObservable)
        referenceImages = cell(0,1);
        maxNumReferenceImages = 10;
        refAlpha = 0.5;
        roiAlpha = 0.5;
        lastFrame = [];
    end
    
    properties(SetAccess=private)
        hDevice; %readonly handle to internal camera device (dabs.resources.devices.Camera).
        hTimer; % polling timer
    end
    
    %% Lifecycle
    methods
        %% Constructor
        function obj = CameraWrapper(hCamera)
            validateattributes(hCamera,{'dabs.resources.devices.Camera'},{'scalar'});
            
            obj.hDevice = hCamera;
            obj.hTimer = timer(...
                'Name', sprintf('CameraWrapper-%s', obj.hDevice.cameraName),...
                'BusyMode', 'drop',...
                'ExecutionMode', 'fixedDelay',...
                'TimerFcn', @(~, ~) obj.pollFrames(),...
                'ErrorFcn', @(~, event) obj.timerError(event),...
                'StopFcn', @(~, ~) obj.timerStop());
        end
        
        %% getMeshgrid(obj)
        % returns 2D meshgrid for Camera in Camera space.
        function [xx,yy] = getMeshgrid(obj, varargin)
            % camera coordinate system is defined by a square with corner points
            % { [-.5,-.5], [.5,-.5], [.5,.5], [-.5,.5] }
            
            if isempty(varargin)
                gridResolution = 10;
            else
                gridResolution = varargin{1};
            end
            
            linspc = linspace(-.5,.5, gridResolution);
            [xx, yy, ~] = meshgrid(linspc, linspc, 1);
            if obj.hDevice.isTransposed
                xx = xx';
                yy = yy';
            end
        end
        
        %% getRefMeshgrid(obj)
        % returns 2D meshgrid for Camera in ROI Space
        function [xx, yy] = getRefMeshgrid(obj, varargin)
            if isempty(varargin)
                [xx, yy] = obj.getMeshgrid();
            else
                [xx, yy] = obj.getMeshgrid(varargin{1});
            end
            [xx, yy] = scanimage.mroi.util.xformMesh(xx,yy,obj.cameraToRefTransform);
        end
        
        %% getRefCornerPoints(obj)
        % returns 2D corner points for Camera in ROI Space
        function [xx, yy] = getRefCornerPoints(obj)
            [xx, yy] = obj.getRefMeshgrid(2);
        end
    end
    
    %% Class Data File Methods
    methods (Hidden)
        function s = saveProps(obj)
            s = struct();
            s.cameraName = obj.cameraName;
            s.lut = obj.lut;
            s.cameraToRefTransform = obj.cameraToRefTransform;
            s.pixelToRefTransform = obj.pixelToRefTransform; % save this as a reference only, don't load it back in
            s.referenceImages = obj.referenceImages;
            s.maxNumReferenceImages = obj.maxNumReferenceImages;
            s.cameraProps = obj.hDevice.saveUserProps();
            s.refAlpha = obj.refAlpha;
            s.roiAlpha = obj.roiAlpha;
            s.flipH = obj.flipH;
            s.flipV = obj.flipV;
            s.rotate = obj.rotate;
        end
        
        function loadProps(obj,s)
            assert(strcmp(obj.cameraName,s.cameraName));
            saveSetProp('lut');
            saveSetProp('cameraToRefTransform');
            saveSetProp('maxNumReferenceImages');
            saveSetProp('referenceImages');
            saveSetProp('refAlpha');
            saveSetProp('roiAlpha');
            saveSetProp('flipH');
            saveSetProp('flipV');
            saveSetProp('rotate');
            obj.hDevice.loadUserProps(s.cameraProps);
            
            function saveSetProp(propName)
                try
                    obj.(propName) = s.(propName);
                catch ME
                    most.idioms.warn('Cannot set property ''%s'' of camera ''%s''',propName,obj.cameraName);
                end
            end
        end
    end
    
    %% Property Getter/Setter
    methods
        function val = get.cameraName(obj)
            val = obj.hDevice.cameraName;
        end
        
        %% set.cameraToRefTransform(obj,val)
        % Given 3x3 transform matrix, sets the transform from camera space to reference space.
        function set.cameraToRefTransform(obj,val)
            if isempty(val)
                val = eye(3);
            end
            
            validateattributes(val,{'numeric'},{'size',[3,3],'nonnan','finite'});
            assert(det(val) ~= 0, 'Matrix is not invertible');
            obj.cameraToRefTransform = val;
        end
        
        %% get.displayTransform(obj)
        % Returns a transform from Camera Space to a Display-friendly space.
        % Accomodates for aspect ratio.
        function T = get.displayTransform(obj)
            resolution = double(obj.hDevice.resolutionXY);
            
            T_aspectratio = eye(3);
            T_aspectratio(2,2) = double(resolution(2)) / double(resolution(1)); % scale by aspect ratio
            
            % flip
            T_flip = eye(3);
            T_flip(1,1) = (-1)^obj.flipH;
            T_flip(2,2) = (-1)^obj.flipV;
            
            % rotate
            T_rot = eye(3);
            T_rot(1,1) = cos(obj.rotate * pi / 180);
            T_rot(2,2) = T_rot(1,1);
            T_rot(1,2) = sin(obj.rotate * pi / 180);
            T_rot(2,1) = -T_rot(1,2);
            
            T = T_rot * T_flip * T_aspectratio;
        end
        
        %% set.lut(obj, val)
        % Manual setter for color data limits given a horizontal vector of size 2.
        % The range is inclusive and should be in ascending order.
        % The values should not be less than zero or greater than the Camera Device's maximum value.
        function set.lut(obj, val)
            assert(val(1) < val(2), 'Camera look up table''s black value must be less than white value');
            maxval = obj.hDevice.datatype.getMaxValue();
            if val(2) > maxval
                val(2) = maxval;
            end
            obj.lut = round(val);
        end
        
        %% get.pixelToCameraTransform(obj)
        % Returns the 3x3 transform matrix from pixel space to camera space.
        function T = get.pixelToCameraTransform(obj)
            resolution = double(obj.hDevice.resolutionXY);
            
            T_translate_1 = eye(3);
            T_translate_1(1,3) = -1;
            T_translate_1(2,3) = -1;
            
            T_translate = eye(3);
            T_translate(1,3) = -(resolution(1)-1)/2;
            T_translate(2,3) = -(resolution(2)-1)/2;
            
            T_scale = eye(3);
            T_scale(1,1) = 0.5/ (0.5+(resolution(1)-1)/2);
            T_scale(2,2) = 0.5/ (0.5+(resolution(2)-1)/2);
            
            T = T_scale * T_translate * T_translate_1;
        end
        
        %% get.pixelToRefTransform(obj)
        % Returns the 3x3 transform matrix form pixel space to reference space.
        function T = get.pixelToRefTransform(obj)
            T = obj.cameraToRefTransform * obj.pixelToCameraTransform;
        end
        
        function set.referenceImages(obj,val)
            assert(iscellstr(val),'referenceImages needs to be a cell array');
            
            val = unique(val,'stable'); % filter duplicates
            
            validRefImages = true(size(val));
            %filter no longer valid files
            for i=1:length(val)
                [status, attrib] = fileattrib(val{i});
                validRefImages(i) = status && ~attrib.directory && attrib.UserRead;
                if ~validRefImages(i)
                    most.idioms.warn('Could not find camera reference image ''%s''.', val{i});
                end
            end
            
            % crop list length to maxNumReferenceImages
            validRefImages(obj.maxNumReferenceImages+1:end) = false;
            obj.referenceImages = val(validRefImages);
        end
        
        function set.flipH(obj,val)
            validateattributes(val,{'numeric','logical'},{'scalar','binary'});
            obj.flipH = logical(val);            
        end
        
        function set.flipV(obj,val)
            validateattributes(val,{'numeric','logical'},{'scalar','binary'});
            obj.flipV = logical(val);            
        end
        
        function set.rotate(obj,val)
            validateattributes(val,{'numeric'},{'scalar','finite','real','nonnan'});
            val = mod(val,360);
            obj.rotate = val;            
        end
    end
    
    %% Live Acquisition
    methods
        function startAcq(obj, rate)
            assert(~obj.isRunning(),...
                'Camera `%s` is already running.  Aborting startAcq()', obj.hDevice.cameraName);
            obj.hTimer.Period = 1 / rate;
            obj.hDevice.start();
            start(obj.hTimer);
        end
        
        function stopAcq(obj)
            assert(obj.isRunning(),...
                'Camera `%s` is not running.  Aborting stopAcq()', obj.hDevice.cameraName);
            stop(obj.hTimer);
            obj.hDevice.stop();
        end
        
        function out=isRunning(obj)
            out = strcmp(obj.hTimer.Running, 'on');
        end
    end
    
    methods(Access=private)
        function pollFrames(obj)
            persistent timeout;
            if isempty(timeout)
                timeout = 0;
            end
            
            if ~obj.hDevice.isAcquiring
                if timeout >= 1/obj.hTimer.Period
                    errorMessage = ['Timer `%s` timed out after 1 second '...
                        'of internal camera not acquiring.'];
                    most.idioms.dispError(errorMessage, obj.hTimer.Name);
                    
                    obj.stopAcq();
                else
                    timeout = timeout + 1; 
                end
                return;
            end
            
            try
                [frames, ~] = obj.hDevice.getAcquiredFrames();
            catch ME
                if strcmpi(ME.message,'Another module is getting images from the camera.')
                    frames = [];
                else
                    ME.rethrow();
                end
            end
            newestFrame = [];
            
            while ~isempty(frames)
                newestFrame = frames{end};
                try
                    [frames, ~] = obj.hDevice.getAcquiredFrames();
                catch ME
                    if strcmpi(ME.message,'Another module is getting images from the camera.')
                        frames = [];
                    else
                        ME.rethrow();
                    end
                end
            end
            
            newestFrame = squeeze(newestFrame);
            if ~ismatrix(newestFrame)
                imageXYDimensionMask = ismember(obj.hDevice.resolutionXY, size(newestFrame));
                colorDimension = find(~imageXYDimensionMask, 1);
                newestFrame = mean(newestFrame, colorDimension);
                newestFrame = squeeze(newestFrame);
                assert(ismatrix(newestFrame),...
                    '%s: Frame not properly coerced into a grayscale image',...
                    obj.hTimer.Name);
            end
            if ~isempty(newestFrame)
                obj.lastFrame = newestFrame;
            end
        end
        
        function timerError(~, event)
            most.idioms.dispError(event.Data.message);
        end
        
        function timerStop(obj)
            if obj.hDevice.isAcquiring
                obj.hDevice.stop();
            end
        end
    end
end



% ----------------------------------------------------------------------------
% Copyright (C) 2022 Vidrio Technologies, LLC
% 
% ScanImage (R) 2022 is software to be used under the purchased terms
% Code may be modified, but not redistributed without the permission
% of Vidrio Technologies, LLC
% 
% VIDRIO TECHNOLOGIES, LLC MAKES NO WARRANTIES, EXPRESS OR IMPLIED, WITH
% RESPECT TO THIS PRODUCT, AND EXPRESSLY DISCLAIMS ANY WARRANTY OF
% MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE.
% IN NO CASE SHALL VIDRIO TECHNOLOGIES, LLC BE LIABLE TO ANYONE FOR ANY
% CONSEQUENTIAL OR INCIDENTAL DAMAGES, EXPRESS OR IMPLIED, OR UPON ANY OTHER
% BASIS OF LIABILITY WHATSOEVER, EVEN IF THE LOSS OR DAMAGE IS CAUSED BY
% VIDRIO TECHNOLOGIES, LLC'S OWN NEGLIGENCE OR FAULT.
% CONSEQUENTLY, VIDRIO TECHNOLOGIES, LLC SHALL HAVE NO LIABILITY FOR ANY
% PERSONAL INJURY, PROPERTY DAMAGE OR OTHER LOSS BASED ON THE USE OF THE
% PRODUCT IN COMBINATION WITH OR INTEGRATED INTO ANY OTHER INSTRUMENT OR
% DEVICE.  HOWEVER, IF VIDRIO TECHNOLOGIES, LLC IS HELD LIABLE, WHETHER
% DIRECTLY OR INDIRECTLY, FOR ANY LOSS OR DAMAGE ARISING, REGARDLESS OF CAUSE
% OR ORIGIN, VIDRIO TECHNOLOGIES, LLC's MAXIMUM LIABILITY SHALL NOT IN ANY
% CASE EXCEED THE PURCHASE PRICE OF THE PRODUCT WHICH SHALL BE THE COMPLETE
% AND EXCLUSIVE REMEDY AGAINST VIDRIO TECHNOLOGIES, LLC.
% ----------------------------------------------------------------------------
