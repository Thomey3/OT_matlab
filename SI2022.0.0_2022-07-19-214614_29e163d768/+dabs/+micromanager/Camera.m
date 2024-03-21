classdef Camera < most.HasMachineDataFile & dabs.resources.devices.Camera & dynamicprops & dabs.resources.configuration.HasConfigPage
    properties (SetAccess=protected, Hidden)
        ConfigPageClass = 'dabs.resources.configuration.resourcePages.MicroManagerCameraPage';
    end
    
    methods (Static)
        function names = getDescriptiveNames()
            names = {'Camera\MicroManager 1.4 Camera','Camera\MicroManager 2.0 Camera'};
        end
    end
    
    %% Abstract Property Realizations (dabs.resources.devices.Camera)
    properties (Dependent, SetObservable)
        cameraExposureTime;     % Numeric containing the current exposure time of the camera.
    end
    
    properties (Constant)
        isTransposed = true;    % Boolean indicating whether camera frame data is column-major order (false) OR row-major order (true)
    end
   
    properties (SetAccess = private)    
        criticalSection = false;
    end
    
    properties (Hidden)
        mmInstallDir = '';
        mmConfigFile = '';
    end
    
    properties (Dependent, SetAccess=private, SetObservable)
        isAcquiring;            % Boolean indicating whether a continuous buffered acquisition is active.
        resolutionXY;           % Numeric Array [X Y] indicating the resolution of camera frames. 
    end
    
    %% ABSTRACT PROPERTY REALIZATIONS (most.HasMachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'MicroManager Camera';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
        
        mdfDefault = defaultMdfSection();
    end

    %% Class-specific Properties    
    properties (SetAccess=private, Hidden)
        hMM;                    % Handle to the MicroManager object.
        cameraLabel;            % A MicroManager identifier for the camera or device
    end
    
    %% LIFECYCLE METHODS
    methods
        %% Constructor
        function obj = Camera(name)
            obj@dabs.resources.devices.Camera(name);
            obj = obj@most.HasMachineDataFile(true);
            
            obj.deinit();
            obj.loadMdf();
            obj.reinit();
        end
        
        %% Destructor
        function delete(obj)
            obj.deinit();
        end
    end
    
    methods
        function deinit(obj)
            obj.errorMsg = 'Uninitialized';
            
            try
                if most.idioms.isValidObj(obj.hMM) && obj.isAcquiring
                    obj.stop();
                end
            catch ME
            end
            
            most.idioms.safeDeleteObj(obj.hMM);
            obj.hMM = [];
        end
        
        function reinit(obj)
            import dabs.resources.devices.camera.Datatype;
            import dabs.micromanager.MicroManager;
            obj.deinit();
            
            try
                assert(0 < exist(obj.mmInstallDir,'dir'),...
                    'MicroManager installation directory not found on disk: ''%s''', obj.mmInstallDir);
                assert(0 < exist(obj.mmConfigFile,'file'),...
                    'MicroManager config file not found: ''%s''', obj.mmConfigFile);
                
                assert(MicroManager.isOnWindowsPath(obj.mmInstallDir),...
                    'MicroManager is not found on the Windows search path.');
                
                obj.hMM = MicroManager(obj.mmConfigFile, obj.mmInstallDir);
                
                assert(most.idioms.isValidObj(obj.hMM),'Failed to connect to MicroManager');
                
                % according to the micromanager documentation, image data
                % always has to be interpreted as unsigned integers
                % https://micro-manager.org/wiki/Matlab_Configuration
                bytesPerPixel = obj.hMM.mmc.getBytesPerPixel();
                switch bytesPerPixel
                    case 1
                        obj.datatype = Datatype.U8;
                    case 2
                        obj.datatype = Datatype.U16;
                        % CURRENTLY UNSUPPORTED
%                     case 4
%                         obj.datatype = 'uint32';
%                     case 8
%                         obj.datatype = 'uint64';
                    otherwise
                        error('Unknown pixel datatype');
                end
                
                % there's currently no universal way in CMMCore to actually
                % change the pixel size, only to retrieve it.                
                obj.availableDatatypes = {char(obj.datatype)};

                
                obj.errorMsg = '';
                
                % add micromanager camera properties as dynamic properties to this object
                props = obj.hMM.mmc.getDevicePropertyNames(obj.cameraLabel).iterator();
                while props.hasNext()
                    pname = char(props.next());
                    if obj.hMM.mmc.isPropertyReadOnly(obj.cameraLabel, pname)
                        %ignore readonly properties
                        continue;
                    end
                    valid_pname = most.idioms.str2validName(pname);
                    dynamic = addprop(obj, valid_pname);
                    dynamic.SetMethod = @(~, val)obj.setMmcProp(pname,val);
                    dynamic.GetMethod = @(~)obj.getMmcProp(pname);
                    dynamic.SetObservable = true;
                end
                
            catch ME
                obj.deinit();
                obj.errorMsg = sprintf('%s: initialization error: %s',obj.name,ME.message);
                most.ErrorHandler.logError(ME,obj.errorMsg);
            end
        end
    end
    
    methods        
        function loadMdf(obj)
            success = true;
            success = success & obj.safeSetPropFromMdf('mmInstallDir', 'mmInstallDir');
            success = success & obj.safeSetPropFromMdf('mmConfigFile', 'mmConfigFile');
            
            if ~success
                obj.errorMsg = 'Error loading config';
            end
        end
        
        function saveMdf(obj)            
            obj.safeWriteVarToHeading('mmInstallDir', obj.mmInstallDir);
            obj.safeWriteVarToHeading('mmConfigFile', obj.mmConfigFile);
        end
    end

    %% ABSTRACT METHODS IMPL (dabs.resources.devices.Camera)
    methods
        function start(obj)
            obj.hMM.mmc.startContinuousSequenceAcquisition(0.01);
        end
        
        function stop(obj)
            obj.hMM.mmc.stopSequenceAcquisition();
        end
    end
    
    methods(Access=protected)
        function img = snap(obj)
            obj.hMM.mmc.snapImage();
            img = obj.hMM.mmc.getImage();
            img = typecast(img, obj.datatype.toMatlabType()); % data is returned as signed integer, but needs to be interpreted as unsigned integer
            
            resolution = obj.resolutionXY;
            img = reshape(img, resolution(1), resolution(2));
        end
        
        function [data, meta] = grabFrames(obj)
            assert(~obj.criticalSection,'Another module is getting images from the camera.');
            obj.criticalSection = true;
            
            try
                [data, meta] = obj.hMM.getNextImages();
                resolution = obj.resolutionXY;
                for iImage=1:length(data)
                    data_ = data{iImage};
                    data_ = typecast(data_, obj.datatype.toMatlabType()); % data is returned as signed integer, but needs to be interpreted as unsigned integer
                    data_ = reshape(data_, resolution(1), resolution(2));
                    data{iImage} = data_;
                end
                
                if ~isempty(data)
                    obj.lastAcquiredFrame = data{end};
                end
            catch ME
                obj.criticalSection = false;
                ME.rethrow();
            end
            obj.criticalSection = false;
        end
        
        function flushQueue(obj)
            obj.hMM.mmc.clearCircularBuffer();
        end
    end
    
    methods (Hidden)
        %% setMmcProp(obj, pname, val)
        %
        % Function to dynamically set property values through MicroManager.
        % Which properties exist depends on the device currently being
        % operated through MicroManager. Not all cameras will have the
        % same properties.
        %
       function setMmcProp(obj,pname, val)
           if isnumeric(val)
               val = num2str(val);
           end
           obj.hMM.mmc.setProperty(obj.cameraLabel, pname, val);
       end
        
        %% getMmcProp(obj, pnam)
        %
        % Function to dynamically recall prperty values through
        % MicorManager. Which properties exist depends on the device
        % currently being operated through MicroManager. Not all cameras
        % will have the same properties.
        %
        function val = getMmcProp(obj,pname)
            val = obj.hMM.mmc.getProperty(obj.cameraLabel, pname);
            val = char(val);
            
            % try converting to number
            val_ = str2double(val);
            if ~isnan(val_)
                val = val_; % if conversion succeeds, use val
            end
        end
        
        function metaProps = filterUserProps(obj,metaProps)
            propNames = {metaProps.Name};
            % the exposure property is handled by MicroManager natively
            mask = strcmpi(propNames,'Exposure');
            metaProps = metaProps(~mask);
        end
    end

    %% Property Control Methods
    methods
        %% out=get.isAcquiring(obj)
        %
        % Returns if camera is acquiring images
        %
        function out=get.isAcquiring(obj)
            out = most.idioms.isValidObj(obj.hMM) && obj.hMM.mmc.isSequenceRunning();
        end
        
        %% get.cameraLabel(obj)
        %
        % Get method for camera label, a MicroManager specific identifier.
        %
        function val = get.cameraLabel(obj)
            val = obj.hMM.mmc.getCameraDevice();
        end
        
        %% set.cameraExposureTime(obj, val)
        %
        % Function to set the camera exposure time.
        %
        function set.cameraExposureTime(obj,val)
            obj.hMM.mmc.setExposure(val);
        end
        
        %% get.cameraExposureTime(obj)
        %
        % Function to return the camera exposure time setting.
        %
        function val = get.cameraExposureTime(obj)
            val = obj.hMM.mmc.getExposure();
        end
        
        %% out=get.resolutionXY(obj)
        %
        % Returns current image resolution
        %
        function out=get.resolutionXY(obj)
            if most.idioms.isValidObj(obj.hMM)
                out = [obj.hMM.mmc.getImageWidth(), obj.hMM.mmc.getImageHeight()];
            else
                out = [];
            end
        end
        
        function set.mmInstallDir(obj,val)
            if isempty(val)
                val = '';
            else
                validateattributes(val,{'char'},{'row'});
            end
            
            oldVal = obj.mmInstallDir;
            obj.mmInstallDir = val;
            
            if ~strcmp(oldVal,val)
                obj.deinit();
            end
        end
        
        function set.mmConfigFile(obj,val)
            if isempty(val)
                val = '';
            else
                validateattributes(val,{'char'},{'row'});
            end
            
            oldVal = obj.mmConfigFile;
            obj.mmConfigFile = val;
            
            if ~strcmp(oldVal,val)
                obj.deinit();
            end
        end
    end
end

%% LOCAL METHODS
function s = defaultMdfSection()
s = [...
    most.HasMachineDataFile.makeEntry('mmInstallDir','C:\Program Files\Micro-Manager-1.4','Path to MicroManager installation directory. e.g. ''C:\Program Files\Micro-Manager-1.4''')...
    most.HasMachineDataFile.makeEntry('mmConfigFile','','Path to MicroManager Device Config File. e.g. ''C:\Program Files\Micro-Manager-1.4\MMConfig_demo.cfg''')...
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
