classdef CameraManager < scanimage.interfaces.Component & most.HasClassDataFile
    %% CameraManager
    %
    % Contains functionality to manage and arbitrate 1 or more cameras.
    %
    
    properties(Dependent, SetAccess=private, Transient)
        hCameras;                           % Cell array of Camera objects being managed
    end
    
    properties (SetAccess = private, Transient)
        hCameraWrappers = scanimage.components.cameramanager.CameraWrapper.empty(1,0); % array of camera wrappers
    end
    
    properties (Hidden, SetAccess=?scanimage.interfaces.Class, SetObservable)
        classDataFileName;
    end
    
    properties(Hidden, SetAccess = private, SetObservable)
        hListeners = event.proplistener.empty(1,0);  %  Array of listener objects for camera updates
    end
    
    events
        cameraLastFrameUpdated;              % Event to notify system that a camera has updated new frame
        cameraLUTChanged;                    % Event to notify system that the Camera Look Up Table has changed
    end
    
    %%% ABSTRACT PROPERTY REALIZATION (most.Model)
    properties (Hidden,SetAccess=protected)
        mdlPropAttributes = ziniInitPropAttributes();
        mdlHeaderExcludeProps = {'hCameras','hCameraWrappers'};
    end
    
    %%% ABSTRACT PROPERTY REALIZATION (scanimage.interfaces.Component)
    properties (SetAccess = protected, Hidden)
        numInstances = 1;
    end
    
    properties (Constant, Hidden)
        COMPONENT_NAME = 'CameraManager';    % [char array] short name describing functionality of component e.g. 'Beams' or 'FastZ'
        PROP_TRUE_LIVE_UPDATE = {};          % Cell array of strings specifying properties that can be set while the component is active
        PROP_FOCUS_TRUE_LIVE_UPDATE = {};    % Cell array of strings specifying properties that can be set while focusing
        DENY_PROP_LIVE_UPDATE = {};          % Cell array of strings specifying properties for which a live update is denied (during acqState = Focus)
        
        FUNC_TRUE_LIVE_EXECUTION = {};       % Cell array of strings specifying functions that can be executed while the component is active
        FUNC_FOCUS_TRUE_LIVE_EXECUTION = {}; % Cell array of strings specifying functions that can be executed while focusing
        DENY_FUNC_LIVE_EXECUTION = {};       % Cell array of strings specifying functions for which a live execution is denied (during acqState = Focus)
    end
    
    %% LIFE CYCLE METHODS
    methods (Access = ?scanimage.SI)
        function obj = CameraManager()
            obj@scanimage.interfaces.Component('SI CameraManager');
        end
    end
        
        %% Destructor
    methods
        function delete(obj)
            obj.saveClassData();
            most.idioms.safeDeleteObj(obj.hListeners);
            most.idioms.safeDeleteObj(obj.hCameraWrappers);
        end
    end

    methods        
        function reinit(obj)            
            % Determine classDataFile name and path
            if isempty(obj.hSI.classDataDir)
                pth = most.util.className(class(obj),'classPrivatePath');
            else
                pth = obj.hSI.classDataDir;
            end
            classNameShort = most.util.className(class(obj),'classNameShort');
            obj.classDataFileName = fullfile(pth, [classNameShort '_classData.mat']);
            
            hCameras_ = obj.findCameras();
            
            for idx=1:numel(hCameras_)
                hCamera = hCameras_{idx};
                
                hCameraWrapper = scanimage.components.cameramanager.CameraWrapper(hCamera);
                obj.hListeners(end+1) =...
                    most.ErrorHandler.addCatchingListener(hCameraWrapper,'lastFrame', 'PostSet',...
                    @(varargin)obj.notifyFrameUpdate(hCameraWrapper));
                obj.hListeners(end+1) =...
                    most.ErrorHandler.addCatchingListener(hCameraWrapper,'lut','PostSet',...
                    @(varargin)obj.notifyLUTUpdate(hCameraWrapper));
                obj.hCameraWrappers(idx) = hCameraWrapper;
            end
            
            % load class data file
            obj.loadClassData();
        end
    end
    
    methods (Hidden)
        function validateConfiguration(obj)
            hCameras_ = obj.findCameras();
            
            errorMsgs = {};
            
            for idx = 1:numel(hCameras_)
                hCamera_ = hCameras_{idx};
                if ~isempty(hCamera_.errorMsg)
                    errorMsgs{end+1} = sprintf('%s is in an error state',hCamera_.name);
                end
            end
            
            obj.errorMsg = strjoin(errorMsgs,'; ');
        end
        
        function hCameras = findCameras(obj)
            hCameras = obj.hResourceStore.filterByClass('dabs.resources.devices.Camera');
        end
    end
    
    %% USER METHODS
    methods
        %% resetTransforms(obj)
        %
        % Resets all cameraToRefTransforms to the identity matrix
        %
        function resetTransforms(obj)
            for idx = 1:length(obj.hCameraWrappers)
                obj.hCameraWrappers(idx).cameraToRefTransform = eye(3);
            end
        end
    end
    
    %% INTERNAL METHODS
    methods
        %% notifyFrameUpdate(obj, camera)
        %
        % Callback function passed to Camera constructor to fire frame
        % update event notification upon frame update.
        %
        function notifyFrameUpdate(obj,cameraWrapper)
            evntData = ...
                scanimage.components.cameramanager.frameUpdateEventData(...
                cameraWrapper);
            notify(obj,'cameraLastFrameUpdated',evntData);
        end
        
        %% notifyLUTUpdate(obj, camWrap)
        %
        % Function to notify other classes that a cameras look up table has
        % changed. This function is sent to the CameraWrappers object array
        % hCameraWrappers during construction and initialization as an anonymous
        % callback function. When the look up table for that cameras
        % CameraWrapper object changes, this function is called to let
        % other classes know.
        %
        function notifyLUTUpdate(obj, camWrap, varargin)
            evntData =...
                scanimage.components.cameramanager.lutUpdateEventData(camWrap);
            notify(obj, 'cameraLUTChanged', evntData);
        end
    end
    
    %% PROPERTY GET/SET METHODS
    methods
        %% get.hCameras(obj)
        %
        % Returns a cell array of handles to the camera objects currently
        % being managed.
        %
        function val = get.hCameras(obj)
            val = {obj.hCameraWrappers.hDevice};
        end
    end
    
    %% Friend Methods
    methods(Hidden, Access=protected)
        % start the component
        function componentStart(obj)
        end
        
        % abort the component
        function componentAbort(obj)
        end
    end
    
    methods(Access = protected, Hidden)
        function ensureClassDataFileProps(obj)
            obj.ensureClassDataFile(struct('cameraProps',[]),obj.classDataFileName);
        end
        
        function loadClassData(obj)
            obj.ensureClassDataFileProps();
            
            cameraProps = obj.getClassDataVar('cameraProps',obj.classDataFileName);
            for idx = 1:length(cameraProps)
                s = cameraProps(idx);
                camIdx = find(strcmpi(s.cameraName,{obj.hCameraWrappers.cameraName}), 1);
                if isempty(camIdx)
                    most.idioms.warn('CameraManager: Camera %s not found in system.',s.cameraName);
                else
                    try
                        obj.hCameraWrappers(camIdx).loadProps(s);
                    catch ME
                        most.ErrorHandler.logAndReportError(ME);
                    end
                end
            end
        end
        
        function saveClassData(obj)
            try
                obj.ensureClassDataFileProps();
                cameraProps = arrayfun(@(cw)cw.saveProps,obj.hCameraWrappers);
                obj.setClassDataVar('cameraProps',cameraProps,obj.classDataFileName);
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
        end
    end
end

%% LOCAL FUNCTIONS
function s = ziniInitPropAttributes()
s = struct();
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
