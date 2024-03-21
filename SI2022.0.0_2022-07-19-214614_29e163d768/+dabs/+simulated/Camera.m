classdef Camera < most.HasMachineDataFile & dabs.resources.devices.Camera & dabs.resources.configuration.HasConfigPage
    properties (SetAccess=protected,Hidden)
        ConfigPageClass = 'dabs.resources.configuration.resourcePages.SimulatedCameraPage';
    end
    
    methods (Static)
        function names = getDescriptiveNames()
            names = {'Camera\Simulated Camera'};
        end
    end
    
    %% ABSTRACT PROPERTY (dabs.resources.devices.Camera)
    properties (SetObservable)
        cameraExposureTime = 10;    % Numeric indicating the current exposure time of a camera.
    end
    
    properties (Constant)
        isTransposed = true;        % Boolean indicating whether camera frame data is column-major order (false) OR row-major order (true)
    end
    
    properties (SetAccess = private, SetObservable)
        isAcquiring = false;        % Boolean indicating whether a bufferd continuous acquisition is active.
        resolutionXY = [512 512];   % Numeric array [X Y] indicating the resolution of returned frame data.
    end
    
    properties (Hidden, Dependent)
        resolutionXY_        
    end
    
    %% ABSTRACT PROPERTY (most.HasMachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'Simulated Camera';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
        
        mdfDefault = defaultMdfSection();
    end
    
    %% Simulation Properties
    properties (SetObservable)
        testPattern;
    end
    
    properties
        cameraHz = 30; % per second
    end
    
    properties(Constant)
        ALL_TEST_PATTERNS = {'Random', 'Gradient'};
    end
    
    %% Private Properties
    properties (Hidden)
        frameGenerator = timer.empty();
        frameAvgNum;
        frameBufferIdx = 1;
        frameBuffer;
        lastGrabTimestamp = [];
    end
    
    %% ABSTRACT METHODS (dabs.resources.devices.Camera)
    methods
        function start(obj)
            if obj.isAcquiring
                return;
            end
            obj.frameGenerator.Period = round(1/obj.cameraHz, 3);
            obj.frameAvgNum = max(obj.cameraHz / (obj.cameraExposureTime * 1000), 1);
            obj.frameBuffer = single(zeros([obj.resolutionXY obj.frameAvgNum]));
            start(obj.frameGenerator);
            obj.lastGrabTimestamp = tic();
            obj.isAcquiring = true;
        end
        
        function stop(obj)
            if obj.isAcquiring
                stop(obj.frameGenerator);
            end
            obj.isAcquiring = false;
        end
    end
    
    methods(Access=protected)
        function img = snap(obj)
            if ~obj.isAcquiring % then fake it
                obj.frameAvgNum = max(obj.cameraHz / (obj.cameraExposureTime * 1000), 1);
                obj.frameBuffer = single(zeros([obj.resolutionXY obj.frameAvgNum]));
                for iFrame=1:obj.frameAvgNum
                    obj.generateBufferData();
                end
            end
            
            % may be called by grabFrames
            img = (...
                mean(obj.frameBuffer, 3) *...
                diff(single([obj.datatype.getMinValue() obj.datatype.getMaxValue()]))...
                ) +...
                obj.datatype.getMinValue();
            img = cast(img,obj.datatype.toMatlabType());
        end
        
        function flushQueue(obj)
            % no-op
        end
        
        function [data, meta] = grabFrames(obj)
            elapsedTime = toc(obj.lastGrabTimestamp);
            numElapsedFrames = elapsedTime * obj.cameraHz * obj.frameAvgNum;
            
            if numElapsedFrames < 1
                data = [];
                meta = struct([]);
            else
                % just return one as it would take too long to generate multiple frames.
                data = {obj.snap()};
                meta = struct();
                obj.lastGrabTimestamp = tic();
            end
            
            if ~isempty(data)
                obj.lastAcquiredFrame = data{end};
            end
        end
    end
    
    %% Lifecycle
    methods
        function obj = Camera(name)
            obj@dabs.resources.devices.Camera(name);
            obj = obj@most.HasMachineDataFile(true);
            
            obj.availableDatatypes = {...
                char(dabs.resources.devices.camera.Datatype.U8),...
                char(dabs.resources.devices.camera.Datatype.I8),...
                char(dabs.resources.devices.camera.Datatype.U16),...
                char(dabs.resources.devices.camera.Datatype.I16)};
            
            obj.deinit();
            obj.loadMdf();
            obj.reinit();
        end
        
        function delete(obj)
            obj.deinit();
        end
    end
    
    methods
        function deinit(obj)
            obj.stop();
            most.idioms.safeDeleteObj(obj.frameGenerator);
            obj.frameGenerator = timer.empty();
            obj.errorMsg = 'Uninitialized';
        end
        
        function reinit(obj)            
            obj.frameGenerator = timer(...
                'Name', sprintf('Simulated-FrameGenerator-%s', obj.cameraName),...
                'BusyMode', 'drop',...
                'ExecutionMode', 'fixedSpacing',...
                'TimerFcn', @(~,~)obj.generateBufferData());
            
            obj.testPattern = obj.ALL_TEST_PATTERNS{1};
            
            obj.errorMsg = '';
        end
    end
    
    methods
        function loadMdf(obj)
            success = true;
            
            success = success & obj.safeSetPropFromMdf('datatype', 'simcamDatatype');
            success = success & obj.safeSetPropFromMdf('resolutionXY_', 'simcamResolution');
            
            if ~success
                obj.errorMsg = 'Error loading config';
            end
        end
        
        function saveMdf(obj)            
            obj.safeWriteVarToHeading('simcamDatatype', char(obj.datatype));
            obj.safeWriteVarToHeading('simcamResolution', obj.resolutionXY_);
        end
    end
    
    %% External + Property Methods
    methods
        function set.cameraExposureTime(obj, val)
            assert(val > 0);
            obj.cameraExposureTime = val;
            if strcmp(obj.frameGenerator.Running, 'on')
                obj.stop();
                obj.start();
            end
        end
        
        function set.cameraHz(obj, val)
            assert(val > 0 && val <= 1000,...
                'Simulated Camera Hz cannot exceed 1000, zero, or lower than zero.');
            obj.cameraHz = val;
            obj.framesPerGrab = getFramesPerGrab(obj.cameraExposureTime, obj.cameraHz);
        end
        
        function set.testPattern(obj, val)
            formattedTestPattern = strjoin(obj.ALL_TEST_PATTERNS, '|');
            if isnumeric(val)
                assert(val > 0 && val <= length(obj.ALL_TEST_PATTERNS),...
                    'Test Pattern Index must be 1-%d',...
                    length(obj.ALL_TEST_PATTERNS));
            elseif ischar(val)
                patternIdx = strcmpi(val, obj.ALL_TEST_PATTERNS);
                assert(any(patternIdx),...
                    'Test Pattern String must be one of `%s` (case insensitive)',...
                    formattedTestPattern);
                val = find(patternIdx, 1);
            else
                errorMessage = ['Test Pattern must be a string of or index to '...
                    'a valid test pattern `%s` (case insensitive).'];
                error(errorMessage, formattedTestPattern);
            end
            obj.testPattern = obj.ALL_TEST_PATTERNS{val};
        end
    end
    
    %% Internal Methods
    methods(Access=private)
        function generateBufferData(obj)
            if obj.isTransposed
                resolution = obj.resolutionXY;
            else
                resolution = flip(obj.resolutionXY);
            end
            
            switch obj.testPattern
                case 'Random'
                    frame = rand(resolution, 'single');
                case 'Gradient'
                    column = sin(linspace(0, pi, resolution(1))) .';
                    frame = repmat(column,1,resolution(2));
            end
            obj.frameBuffer(:,:,obj.frameBufferIdx) = frame;
            if obj.frameBufferIdx == obj.frameAvgNum
                obj.frameBufferIdx = 1;
            else
                obj.frameBufferIdx = obj.frameBufferIdx + 1;
            end
        end
    end
    
    methods
        function set.resolutionXY_(obj,val)
            obj.resolutionXY = val;
        end
        
        function val = get.resolutionXY_(obj)
            val = obj.resolutionXY;
        end
        
        function set.resolutionXY(obj,val)
            validateattributes(val,{'numeric'},{'integer','positive','size',[1,2],'nonnan'});
            
            oldVal = obj.resolutionXY;
            obj.resolutionXY = val;
            
            if ~isequal(oldVal,val)
                obj.deinit();
            end
        end
    end
end

%% Default MDF Values
function s = defaultMdfSection()
s = [...
    most.HasMachineDataFile.makeEntry('simcamDatatype' ,'U8','Datatype of the Simulated Camera. See `randi` for compatible types')...
    most.HasMachineDataFile.makeEntry('simcamResolution',[512 512],'Resolution of the simulated camera in form [X Y]. Cannot have negative values.')...
    ];
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
