classdef SI < scanimage.interfaces.Component & most.HasMachineDataFile & dynamicprops & dabs.resources.configuration.HasConfigPage & dabs.resources.widget.HasWidget
    %SI     Top-level description and control of the state of the ScanImage application
    properties (SetAccess=protected, Hidden)
        WidgetClass = 'dabs.resources.widget.widgets.SIStatusWidget';
    end
    
    properties (SetAccess=protected,Hidden)
        ConfigPageClass = 'dabs.resources.configuration.resourcePages.SIPage';
    end
    
    methods (Static, Hidden)
        function names = getDescriptiveNames()
            names = {'ScanImage system'}; % returns cell string of descriptive names; this is a function so it can be overloaded
        end
        
        function classes = getClassesToLoadFirst()
            % overload if needed
            classes = {'scanimage.components.Scan2D'};
        end
    end

    %% USER PROPS
    %% Acquisition duration parameters
    properties (SetObservable)
        acqsPerLoop = 1;                        % Number of independently started/triggered acquisitions when in LOOP mode
        loopAcqInterval = 10;                   % Time in seconds between two LOOP acquisition triggers, for self/software-triggered mode.
        focusDuration = Inf;                    % Time, in seconds, to acquire for FOCUS acquisitions. Value of inf implies to focus indefinitely.
    end
    
    properties (SetObservable)
        mdlCustomProps = {};                     % Cell array indicating additional user selected properties to save to the header file.
        extCustomProps = {};                     % Cell array indicating additional user selected properties from outside of the model to save to the header file.
    end
    
    %%% Properties enabling/disabling component functionality at top-level
    properties (SetObservable)
        imagingSystem = [];                     % string, allows the selection of the scanner using a name settable by the user in the MDF
        extTrigEnable = false;                  % logical, enabling hScan2D external triggering features for applicable GRAB/LOOP acquisitions
    end
    
    %transient because it is saved in class data file
    properties (SetObservable, Transient)
        useJsonHeaderFormat = false;
        objectiveResolution;
        startUpScript = '';
        shutDownScript = '';
        fieldCurvatureZs = [];
        fieldCurvatureRxs = [];
        fieldCurvatureRys = [];
        fieldCurvatureTip = 0;
        fieldCurvatureTilt = 0;
    end
    
    %%% ROI properties - to devolve
    properties (SetObservable, Hidden, Transient)
        lineScanParamCache;                     % Struct caching 'base' values for the ROI params of hScan2D (scanZoomFactor, scanAngleShiftFast/Slow, scanAngleMultiplierFast/Slow, scanRotation)
        acqParamCache;                          % Struct caching values prior to acquisition, set to other values for the acquisition, and restored to cached values after acquisition is complete.        
    end
    
    properties (SetObservable, SetAccess=private, Hidden)
        acqStartTime;                           % Time at which the current acquisition started. This is not used for any purpose other than "soft" timing.
        imagingSystemChangeInProgress = false;
    end
    
    properties (SetObservable, SetAccess=private, Transient)
        acqState = 'idle';                      % One of {'focus' 'grab' 'loop' 'idle' 'point'}
    end
    
    properties (SetObservable, SetAccess=private, Hidden)
        loopAcqCounter = 0;                     % Number of grabs in acquisition mode 'loop'
        acqInitDone = false;                    % indicates the acqmode has completed initialization
        secondsCounter = 0;                     % current countdown or countup time, in seconds
        overvoltageStatus = false;              % Boolean. Shows if the system is in an over-voltage state
        hOvervoltageMsgDialog;
        hFAFErrMsgDialog;
    end
    
    %% PUBLIC API *********************************************************
    %%% Read-only component handles
    properties (SetAccess=immutable,Transient)
        hCoordinateSystems;     % scanimage.components.CoordinateSystems
        hWaveformManager;       % scanimage.components.WaveformManager handle
        hRoiManager;            % scanimage.components.RoiManager handle
        hBeams;                 % Beams handle
        hMotors;                % scanimage.components.Motors handle
        hFastZ;                 % scanimage.components.FastZ handle
        hStackManager;          % scanimage.components.StackManager handle
        hChannels;              % scanimage.components.Channels handle
        hPmts;                  % PMTs handle
        hShutters;              % scanimage.components.Shutters handle
        hDisplay;               % scanimage.components.Display handle
        hConfigurationSaver;    % scanimage.components.ConfigurationSaver handle
        hUserFunctions;         % scanimage.components.UserFunctions handle
        hWSConnector;           % WaveSurfer-Connection handle
        hMotionManager;         % scanimage.components.MotionManager handle

        hPhotostim;             % scanimage.components.Photostim handle.
        hIntegrationRoiManager; % scanimage.components.RoiManager handle.  Manages integration ROIs.
        hCameraManager;         % scanimage.components.CameraManager handle
        hTileManager;

        hCycleManager;          % scanimage.components.CycleManager handle
    end
    
    properties (SetObservable, SetAccess = private, Transient)
        hScan2D;                % Handle to the scanning component
                                % NOTE: hScan2D has to be included in mdlHeaderExcludeProps if it is not hidden (otherwise it will show up in the TIFF header)
                                
        hScanners = {};         % Scanners handle
        scannerNames;           % Names of available scanners
    end
 
    properties (SetObservable, Hidden)
        hSlmScan;               % Handle to active SlmScan (mostly for updating GUI)
    end
    
    %% FRIEND PROPS
    properties (Hidden, GetAccess = {?scanimage.interfaces.Class, ?most.Model})
        %Properties that are cache prior to acq, then set to another value, and finally restored after acq abort.
        cachedAcqProps = {'hPhotostim.logging', 'hChannels.loggingEnable','hStackManager.enable','hStackManager.framesPerSlice','extTrigEnable','acqsPerLoop'};
        
        %Properties that are cached when clicking line scan button
        cachedLineScanProps = {'hRoiManager.scanAngleMultiplierSlow' 'hRoiManager.scanAngleMultiplierFast' 'hRoiManager.scanAngleShiftSlow' 'hRoiManager.forceSquarePixels'};
    end
    
    %% INTERNAL PROPS
    %%%Constants
    properties(Transient,Constant)
        %Properties capturing the ScanImage version number - a single number plus the service pack number
        %Snapshots between service pack releases should add/subtract 0.5 from prior service pack to signify their in-betweenness
        VERSION_MAJOR  = 2022;     % Version number
        VERSION_MINOR  = 0;        % Minor release number  (0 = the initial release; positive numbers = maintenance releases)
        VERSION_UPDATE = 0;        % Bugfix release number (0 = the initial release; positive numbers = bugfix releases)
        VERSION_COMMIT = scanimage.util.getCommitHash(); % Git commit hash
        
         PREMIUM = true;

        % SI Tiff format version number
        TIFF_FORMAT_VERSION = 4;    % Tiff format version. This should be incremented any time there is a change in how a tiff should be decoded.
        LINE_FORMAT_VERSION = 1;    % Line scanning data format version. This should be incremented any time there is a change in how line scan data should be decoded.
    end
    
    properties (Constant,Hidden)
        MAX_NUM_CHANNELS = 4;
        LOOP_TIMER_PERIOD = 1;
        DISPLAY_REFRESH_RATE = 30;                % [Hz] requested rate for refreshing images and processing GUI events
    end
    
    properties (Hidden, SetObservable)
        % User-settable runtime adjustment properties
        debugEnabled = false;                   % show/hide debug information in ScanImage.
    end
    
    properties (Hidden, SetObservable, SetAccess=private)
        % The following need to be here to meet property binding requirements for most.Model.
        frameCounterForDisplay = 0;             % Number of frames acquired - this number is displayed to the user.
        acqInitInProgress = false;              % indicates the acqmode has completed initialization
        classDataDir = '';
    end
    
    properties (Hidden, SetAccess=private)      
        hLoopRepeatTimer;
        addedPaths = {};                        % cell array of paths that were added to the Matlab search path by scanimage
    end
    
    properties (Hidden, SetAccess=private, Dependent)
        secondsCounterMode;                     % One of {'up' 'down'} indicating whether this is a count-up or count-down timer
    end
    
    %%% ABSTRACT PROP REALIZATION (most.Model)
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = zlclInitPropAttributes();
        mdlHeaderExcludeProps = {'hScanners' 'scannerNames' 'useJsonHeaderFormat' 'focusDuration' 'mdlCustomProps' 'extCustomProps'};
    end
    
    %%% ABSTRACT PROPERTY REALIZATIONS (most.HasMachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'ScanImage';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
        
        mdfDefault = defaultMdfSection();
    end
    
    %%% ABSTRACT PROPERTY REALIZATION (scanimage.interfaces.Component)
    properties (SetAccess=protected, Hidden)
        numInstances = 0;        
    end
    
    properties (Constant, Hidden)
        COMPONENT_NAME = 'SI root object';                                % [char array] short name describing functionality of component e.g. 'Beams' or 'FastZ'
        PROP_TRUE_LIVE_UPDATE = {'focusDuration'};                         % Cell array of strings specifying properties that can be set while the component is active
        PROP_FOCUS_TRUE_LIVE_UPDATE = {};                                  % Cell array of strings specifying properties that can be set while focusing
        DENY_PROP_LIVE_UPDATE = {...                                       % Cell array of strings specifying properties for which a live update is denied (during acqState = Focus)
            'acqsPerLoop','loopAcqInterval','imagingSystem','extTrigEnable'};
        FUNC_TRUE_LIVE_EXECUTION = {};                                     % Cell array of strings specifying functions that can be executed while the component is active
        FUNC_FOCUS_TRUE_LIVE_EXECUTION = {};                               % Cell array of strings specifying functions that can be executed while focusing
        DENY_FUNC_LIVE_EXECUTION = {'scanPointBeam'};                      % Cell array of strings specifying functions for which a live execution is denied (during acqState = Focus)
    end    
    
    %% LIFECYCLE
    methods (Hidden)
        function obj = SI(varargin)
            scanimage.util.checkSystemRequirements();
            
            obj@scanimage.interfaces.Component('ScanImage'); % declares SI to root component
            obj@most.HasMachineDataFile(true);
            
            baseDirectory = fileparts(which('scanimage'));
            obj.addedPaths = most.idioms.addPaths({baseDirectory});
            
            obj.loadMdf();
            
            mdfLoc = most.MachineDataFile.getInstance.fileName;
            classDataDirBasePath = [mdfLoc(1:end-1) 'ConfigData'];
            obj.classDataDir = fullfile(classDataDirBasePath,num2str(obj.VERSION_MAJOR));
            
            obj.migrateConfigData();
            
            %Initialize non-hardware components
            obj.hCoordinateSystems = scanimage.components.CoordinateSystems();
            obj.hConfigurationSaver = scanimage.components.ConfigurationSaver();
            obj.hUserFunctions = scanimage.components.UserFunctions();
            obj.hWaveformManager = scanimage.components.WaveformManager();
            obj.hChannels = scanimage.components.Channels();
            obj.hShutters = scanimage.components.Shutters();
            obj.hBeams = scanimage.components.Beams();
            obj.hDisplay = scanimage.components.Display();
            obj.hRoiManager = scanimage.components.RoiManager();
            obj.hFastZ = scanimage.components.FastZ();
            obj.hStackManager = scanimage.components.StackManager();
            obj.hMotors = scanimage.components.Motors();
            obj.hPmts = scanimage.components.Pmts();
            obj.hWSConnector = scanimage.components.WSConnector();
            
            %Photostim
            obj.hTileManager = scanimage.components.TileManager();
            obj.hPhotostim=scanimage.components.Photostim();
            obj.hIntegrationRoiManager = scanimage.components.IntegrationRoiManager();
            obj.hCameraManager = scanimage.components.CameraManager();
            
            obj.hMotionManager = scanimage.components.MotionManager();
            obj.hCycleManager = scanimage.components.CycleManager();
            
            obj.numInstances = 1;
        end
        
        function validateConfiguration(obj)
            try
                errorMsgs = {};
                
                try
                    scanimage.util.checkSystemRequirements();
                catch ME
                    errorMsgs{end+1} = ME.message;
                end
                
                hScan2Ds = obj.hResourceStore.filterByClass('scanimage.components.Scan2D');
                if isempty(hScan2Ds)
                    errorMsgs{end+1} = 'No imaging system defined';
                end
                
                hComponents = obj.hResourceStore.filter(@(hR)isa(hR,'dabs.resources.SIComponent')&&~isequal(hR,obj));
                for idx = 1:numel(hComponents)
                    hComponent = hComponents{idx};
                    hComponent.validateConfiguration();
                    if ~isempty(hComponent.errorMsg)
                        errorMsgs{end+1} = sprintf('%s: %s',hComponent.name,hComponent.errorMsg);
                    end
                end
                
                if numel(obj.fieldCurvatureZs)~=numel(obj.fieldCurvatureRxs) ...
                 ||numel(obj.fieldCurvatureZs)~=numel(obj.fieldCurvatureRys)
                    errorMsgs{end+1} = sprintf('Invalid entries for field curvature correction:\nfieldCurvatureZs, fieldCurvatureRxs, fieldCurvatureRys must have same number of elements');
                end
                
                obj.errorMsg = strjoin(errorMsgs);
                
            catch ME
                obj.errorMsg = ME.message;
            end
        end
        
        function reinit(obj)            
            try
                hLM = scanimage.util.private.LM();
                isLicensed = hLM.licensed;
                assert(isLicensed,'No valid license for ScanImage found.');
                hLM.validate();
                
                obj.validateConfiguration();
                assert(isempty(obj.errorMsg),obj.errorMsg);
                
                obj.hMotors.hErrorCallBack = @obj.zprvMotorErrorCbk;
                
                obj.hScanners = obj.hResourceStore.filterByClass('scanimage.components.Scan2D');
                assert(~isempty(obj.hScanners),'No scanners defined. Exiting ScanImage.');
                
                baseDirectory = fileparts(which('scanimage'));
                obj.addedPaths = most.idioms.addPaths({baseDirectory});
                
                %Initialize non-hardware components
                obj.hConfigurationSaver.reinit();
                obj.hUserFunctions.reinit();
                obj.hWaveformManager.reinit();
                obj.hChannels.reinit();
                obj.hShutters.reinit();
                obj.hBeams.reinit();
                
                obj.hDisplay.reinit();
                obj.hRoiManager.reinit();
                obj.hFastZ.reinit();
                
                % initialize Scanners
                for idx = 1:numel(obj.hScanners)
                    hScanner = obj.hScanners{idx};
                    hScanner.reinit();
                    hScanner.stripeAcquiredCallback = @(src,evnt)obj.zzzFrameAcquiredFcn;
                    
                    propName = ['hScan_' hScanner.name];
                    
                    if ~isprop(obj,propName)
                        hProp = obj.addprop(propName);
                        obj.mdlHeaderExcludeProps{end+1} = propName;
                        obj.(propName) = hScanner;
                        
                        hProp.SetAccess = 'immutable';
                        
                        obj.mdlPropAttributes.(propName) = struct('Classes','most.Model');
                    end
                end
                
                slmScans = obj.hResourceStore.filterByClass('scanimage.components.scan2d.SlmScan');
                if ~isempty(slmScans)
                    obj.hSlmScan = slmScans{1};
                end
                
                obj.hCoordinateSystems.reinit(); % coordinate systems need to be initted after Scan2Ds to correctly load in coordinate systems                
                obj.hStackManager.reinit();
                obj.hMotors.reinit();
                obj.hMotors.hErrorCallBack = @obj.zprvMotorErrorCbk;
                obj.hPmts.reinit();
                obj.hWSConnector.reinit(); %WaveSurfer connector
                
                obj.imagingSystem = obj.hScanners{1}.name;
                
                %Photostim
                obj.hPhotostim.reinit();
                obj.hIntegrationRoiManager.reinit();
                obj.hCameraManager.reinit();
                
                obj.hMotionManager.reinit();
                obj.hCycleManager.reinit();
                
                %Loop timer
                obj.hLoopRepeatTimer = timer('BusyMode','drop',...
                    'Name','Loop Repeat Timer',...
                    'ExecutionMode','fixedRate',...
                    'StartDelay',obj.LOOP_TIMER_PERIOD, ...
                    'Period',obj.LOOP_TIMER_PERIOD, ...
                    'TimerFcn',@obj.zzzLoopTimerFcn);
                
                obj.mdlInitialize();
                
                if ~isempty(obj.startUpScript)
                    try
                        evalin('base',obj.startUpScript);
                    catch ME
                        most.ErrorHandler.logAndReportError(ME,['Error occurred running startup script: ' ME.message]);
                    end
                end
            catch ME
                rethrow(ME);
            end
        end
        
        function success = loadCalibration(obj)
            success = true;
            success = success & obj.safeSetPropFromMdf('fieldCurvatureZs', 'fieldCurvatureZs');
            success = success & obj.safeSetPropFromMdf('fieldCurvatureRxs', 'fieldCurvatureRxs');
            success = success & obj.safeSetPropFromMdf('fieldCurvatureRys', 'fieldCurvatureRys');
            
            if isfield(obj.mdfData,'fieldCurvatureTip')
                success = success & obj.safeSetPropFromMdf('fieldCurvatureTip', 'fieldCurvatureTip');
            end
            
            if isfield(obj.mdfData,'fieldCurvatureTilt')
                success = success & obj.safeSetPropFromMdf('fieldCurvatureTilt', 'fieldCurvatureTilt');
            end
        end
        
        function saveCalibration(obj)
            obj.safeWriteVarToHeading('fieldCurvatureZs',  obj.fieldCurvatureZs);
            obj.safeWriteVarToHeading('fieldCurvatureRxs', obj.fieldCurvatureRxs);
            obj.safeWriteVarToHeading('fieldCurvatureRys', obj.fieldCurvatureRys);
            obj.safeWriteVarToHeading('fieldCurvatureTip', obj.fieldCurvatureTip);
            obj.safeWriteVarToHeading('fieldCurvatureTilt', obj.fieldCurvatureTilt);            
        end
        
        function loadMdf(obj)
            success = true;
            success = success & obj.safeSetPropFromMdf('objectiveResolution', 'objectiveResolution');
            success = success & obj.safeSetPropFromMdf('startUpScript', 'startUpScript');
            success = success & obj.safeSetPropFromMdf('shutDownScript', 'shutDownScript');
            success = success & obj.safeSetPropFromMdf('useJsonHeaderFormat', 'useJsonHeaderFormat');
            
            success = success & obj.loadCalibration();
            
            if ~success
                obj.errorMsg = 'Error loading config';
            end
        end
        
        function saveMdf(obj)
            obj.safeWriteVarToHeading('objectiveResolution', obj.objectiveResolution);
            obj.safeWriteVarToHeading('startUpScript', obj.startUpScript);
            obj.safeWriteVarToHeading('shutDownScript', obj.shutDownScript);
            
            obj.saveCalibration();
        end
        
        function migrateConfigData(obj)
            classDataDirBasePath = fileparts(obj.classDataDir);
            
            if exist(obj.classDataDir,'dir')
                return % class data dir for this version exists. no need to migrate
            end
            
            if ~exist(classDataDirBasePath,'dir')
                return % class data dir base path does not exist. don't know where to migrate from
            end
            
            answer = questdlg('Do you want to migrate stored settings from a different ScanImage version?',...
                              'Migrate Settings','Yes','No','No');
            switch answer
                case 'Yes'
                    srcFolder = selectMigrationSource();
                otherwise
                    srcFolder = [];
            end
            
            if ~isempty(srcFolder)
                % just copy srcFolder content into new class data dir to
                % keep it simple
                copyfile(srcFolder,obj.classDataDir);
            end
            
            %%% Nested function
            function srcFolder = selectMigrationSource()
                srcFolder = [];
                
                while true
                    % loop until user selects a valid source OR cancels
                    [~,selpath] = uigetfile(fullfile(classDataDirBasePath,'CoordinateSystems_classData.mat'),'Select a CoordinateSystems_classData.mat');
                    
                    if isnumeric(selpath)
                        break % user aborted
                    else
                        if exist(fullfile(selpath,'CoordinateSystems_classData.mat'),'file')
                            srcFolder = selpath;
                            break;
                        else
                            f = msgbox(sprintf('Folder %s does not contain ScanImage configuration data.',selpath),'Configdata not found','warn');
                            waitfor(f);
                        end
                    end
                end
            end
        end
        
        function exit(obj)
            try
                fprintf('Exiting ScanImage...\n');
                shutDownScript_ = obj.shutDownScript;
                delete(obj);
                evalin('base','clear hSI hSICtl MachineDataFile');
                
                if ~isempty(shutDownScript_)
                    try
                        evalin('base',shutDownScript_);
                    catch ME
                        most.ErrorHandler.logAndReportError(ME,['Error occurred running shutdown script: ' ME.message]);
                    end
                end
                
                fprintf('Done!\n');
            catch ME
                most.ErrorHandler.logAndReportError(ME);
                fprintf('ScanImage exited with errors\n');
            end
        end
        
        function delete(obj)
            
            if obj.active
                obj.abort();
            end
            
            if most.idioms.isValidObj(obj.hUserFunctions)
                obj.hUserFunctions.notify('applicationWillClose');
            end
            
            obj.saveCalibration();
            
            most.idioms.safeDeleteObj(obj.hDisplay);
            most.idioms.safeDeleteObj(obj.hPhotostim);
            most.idioms.safeDeleteObj(obj.hShutters);
            
            most.idioms.safeDeleteObj(obj.hScanners);
            
            most.idioms.safeDeleteObj(obj.hLoopRepeatTimer);
            most.idioms.safeDeleteObj(obj.hBeams);
            most.idioms.safeDeleteObj(obj.hMotors);
            most.idioms.safeDeleteObj(obj.hFastZ);
            most.idioms.safeDeleteObj(obj.hPmts);
            most.idioms.safeDeleteObj(obj.hConfigurationSaver);
            most.idioms.safeDeleteObj(obj.hRoiManager);
            most.idioms.safeDeleteObj(obj.hStackManager);
            most.idioms.safeDeleteObj(obj.hUserFunctions);
            most.idioms.safeDeleteObj(obj.hWSConnector);
            most.idioms.safeDeleteObj(obj.hMotionManager);
            most.idioms.safeDeleteObj(obj.hCameraManager);
            most.idioms.safeDeleteObj(obj.hIntegrationRoiManager);
            most.idioms.safeDeleteObj(obj.hTileManager);
            most.idioms.safeDeleteObj(obj.hCycleManager);
            most.idioms.safeDeleteObj(obj.hOvervoltageMsgDialog);
            most.idioms.safeDeleteObj(obj.hFAFErrMsgDialog);
            most.idioms.safeDeleteObj(obj.hWaveformManager);
            most.idioms.safeDeleteObj(obj.hCoordinateSystems);
            
            obj.hResourceStore.delete();
        end
    end
    
    %% PROP ACCESS
    methods
        function scObj = hScanner(obj, scnnr)
            %   Returns the appropriate Scanner object, managing legacy versions
            try
                if nargin < 2
                    scObj = obj.hScan2D;
                elseif ischar(scnnr)
                    scObj = obj.hResourceStore.filterByName(scnnr);
                else
                    scObj = obj.hScanners{scnnr};
                end
            catch
                scObj = [];
            end
        end
        
        function set.acqsPerLoop(obj,val)
            val = obj.validatePropArg('acqsPerLoop',val);
            if obj.componentUpdateProperty('acqsPerLoop',val)
                obj.acqsPerLoop = val;
            end
        end
        
        function set.extTrigEnable(obj,val)
            val = obj.validatePropArg('extTrigEnable',val);
            if obj.componentUpdateProperty('extTrigEnable',val)
                obj.extTrigEnable = val;
            end
        end
        
        function set.acqState(obj,val)
            assert(ismember(val,{'idle' 'focus' 'grab' 'loop' 'loop_wait' 'point'}));
            obj.acqState = val;
        end
        
        function set.focusDuration(obj,val)
            obj.validatePropArg('focusDuration',val);
            if obj.componentUpdateProperty('focusDuration',val)
                obj.focusDuration = val;
            end
        end
        
        function set.loopAcqInterval(obj,val)
            val = obj.validatePropArg('loopAcqInterval',val);
            if obj.componentUpdateProperty('loopAcqInterval',val)
                obj.loopAcqInterval = val;
            end
        end
        
        function val = get.secondsCounterMode(obj)
            switch obj.acqState
                case {'focus' 'grab'}
                    val = 'up';
                case {'loop' 'loop_wait'}
                    if isinf(obj.loopAcqInterval) || obj.hScan2D.trigAcqTypeExternal
                        val = 'up';
                    else
                        val = 'down';
                    end
                otherwise
                    val = '';
            end
        end
        
        function set.imagingSystem(obj,val)
            if obj.componentUpdateProperty('imagingSystem',val)
                if obj.mdlInitialized
                    obj.hPhotostim.abort();
                end
                
                assert(~obj.imagingSystemChangeInProgress,'Imaging system switch is already in progress.');
                
                try
                    result = regexp(val,'(.+)\((.+)\)','tokens');
                    
                    if isempty(result)
                        name = val;
                        mode = '';
                    else
                        name = strtrim(result{1}{1});
                        mode = lower(strtrim(result{1}{2}));
                    end
                    
                    if most.idioms.isValidObj(obj.hScan2D)
                        obj.hScan2D.safeAbortDataScope();
                    end
                    
                    newScan2D = obj.hResourceStore.filterByName(name);
                    assert(~isempty(newScan2D),'Invalid imaging system selection: %s. Valid scanner names are ',name,strjoin(cellfun(@(hR)hR.name,obj.hScanners,'UniformOutput',false)));
                    
                    obj.imagingSystemChangeInProgress = true;
                    obj.hChannels.saveCurrentImagingSettings();
                    obj.hRoiManager.saveScan2DProps();
                    if most.idioms.isValidObj(obj.hScan2D)
                        obj.hScan2D.deinitRoutes();
                    end
                    obj.imagingSystem = name;
                    obj.hScan2D = newScan2D;
                    if ~isempty(mode)
                        obj.hScan2D.scanMode = mode;
                    end
                    
                    % Crude workaround to ensure triggering is only enabled if
                    % trigger terminals are defined
                    % Todo: Cach extTrigEnable for LinScan and ResScan and
                    % restore value when changing imagingSystem
                    obj.extTrigEnable = false;
                    
                    % Init DAQ routes and park scanner
                    try
                        obj.hScan2D.reinitRoutes();
                    catch ME
                        obj.hShutters.shuttersTransitionAll(false);
                        rethrow(ME);
                    end
                    obj.hShutters.shuttersTransitionAll(false);
                    
                    % Ensure valid scan type selection
                    if ~isa(obj.hScan2D,'scanimage.components.scan2d.LinScan') && obj.hRoiManager.isLineScan
                        obj.hRoiManager.scanType = 'frame';
                    end
                    
                    % park all scanners
                    cellfun(@(x)x.parkScanner(), obj.hScanners, 'UniformOutput', false);
                    
                    % Re-bind depends-on listeners
                    obj.reprocessDependsOnListeners('hScan2D');
                    
                    % Invoke channel registration in Channel component.
                    obj.hChannels.registerChannels();
                    
                    obj.hRoiManager.restoreScan2DProps();
                    
                    % coerce to scanning modes for this scanner
                    obj.hRoiManager.scanType = obj.hRoiManager.scanType;
                    
                    % Update file counter
                    obj.hScan2D.logFileStem = obj.hScan2D.logFileStem;
                    
                    obj.imagingSystemChangeInProgress = false;
                    
                    % update display
                    obj.hDisplay.resetActiveDisplayFigs(false);
                    
                    % Coerce fastz mode
                    obj.hFastZ.enable = obj.hFastZ.enable;
                    
                    obj.hBeams.recreateBeamDaqTask();
                    
                    % reset waveforms
                    obj.hWaveformManager.resetWaveforms(); % this is necessary to load optimized waveforms from the correct cache
                catch ME
                    obj.imagingSystemChangeInProgress = false;
                    ME.rethrow();
                end
            end
        end
        
        function v = get.scannerNames(obj)
            v = cellfun(@(s)s.name,obj.hScanners,'UniformOutput',false);
        end
        
        function set.useJsonHeaderFormat(obj,val)
            validateattributes(val,{'numeric','logical'},{'scalar'});
            obj.useJsonHeaderFormat = logical(val);
        end
        
        function set.objectiveResolution(obj,v)
            v = obj.validatePropArg('objectiveResolution',v);
            obj.objectiveResolution = v;
        end
        
        function set.startUpScript(obj,v)
            validateattributes(v,{'char'},{});
            obj.startUpScript = v;
        end
        
        function set.shutDownScript(obj,v)
            validateattributes(v,{'char'},{});
            obj.shutDownScript = v;
        end
        
        function set.fieldCurvatureZs(obj,v)
            validateattributes(v,{'numeric'},{'nonnan','finite','real'});
            obj.fieldCurvatureZs = v;
        end
        
        function set.fieldCurvatureRxs(obj,v)
            validateattributes(v,{'numeric'},{'nonnan','finite','real'});
            obj.fieldCurvatureRxs = v;
        end
        
        function set.fieldCurvatureRys(obj,v)
            validateattributes(v,{'numeric'},{'nonnan','finite','real'});
            obj.fieldCurvatureRys = v;
        end
        
        function set.fieldCurvatureTip(obj,v)
            validateattributes(v,{'numeric'},{'scalar','nonnan','finite','real'});
            assert(v<90 && v>-90,'Tilt must be in the range -90..90');
            obj.fieldCurvatureTip = v;
        end
        
        function set.fieldCurvatureTilt(obj,v)
            validateattributes(v,{'numeric'},{'scalar','nonnan','finite','real'});
            assert(v<90 && v>-90,'Tip must be in the range -90..90');
            obj.fieldCurvatureTilt = v;
        end
    end
    
    %% STATIC METHODS
    methods (Static)
        function tfCompatible = isMdfCompatible(mdfPath)
            tfCompatible = false;
            
            if nargin<1 || isempty(mdfPath)
                hMdf = most.MachineDataFile.getInstance();
                mdfPath = hMdf.fileName;
            end
            
            if ~exist(mdfPath,'file')
                return
            end
            
            data = loadFile(mdfPath);
            isOldMdf = checkIfOldMdfFormat(data);
            
            tfCompatible = ~isOldMdf;
            
            %%% Nested functions
            function data = loadFile(filePath)
                data = '';
                fid = fopen(filePath);
                try
                    data = fread(fid,Inf,'*char')';
                catch ME
                    fclose(fid);
                    ME.rethrow();
                end
                fclose(fid);
            end
            
            function isOldMdf = checkIfOldMdfFormat(data)
                % look for entry
                % beamDaqDevices = {'anyString'};
                match = regexp(data,'^\s*beamDaqDevices\s*=\s*{[^}]*};','match','once','lineanchors');
                isOldMdf = ~isempty(match); % if entry is found, this is an old MDF format
            end
        end
        
        function cd()
            % cd changes the working directory to the ScanImage
            % installation directory
            scanimage.util.checkSystemRequirements();
            cd(scanimage.util.siRootDir());
        end
        
        function code()
            % launches Visual Studio Code in the ScanImage Root Directory
            [status,cmdout] = system(sprintf('code "%s" -n',scanimage.util.siRootDir()));
            assert(~status,'%s',cmdout);
        end
               
        function str = version()
            % version outputs the ScanImage version and commit hash
            
            str_ = sprintf('ScanImage(R) %s %d.%d.%d %s' ...
                ,most.idioms.ifthenelse(scanimage.SI.PREMIUM,'Premium','Basic') ...
                ,scanimage.SI.VERSION_MAJOR ...
                ,scanimage.SI.VERSION_MINOR ...
                ,scanimage.SI.VERSION_UPDATE ...
                ,scanimage.SI.VERSION_COMMIT(1:10) ... % get short hash
                );
            
            if nargout > 0
                str = str_; % only assign output if nargout > 0. this suppresses 'ans' output in command window
            else
                fprintf('\n%s\n\n',str_);
            end
        end 
    end    
    
    %% USER METHODS
    methods
        function str = getHeaderString(obj,customProps)
            if nargin < 2 || isempty(customProps)
                customProps = [];
            end
            
            if obj.useJsonHeaderFormat
                s = obj.mdlGetHeaderStruct();
                str = most.json.savejson('SI',s,'tab','  ');
            else
                if ~isempty(customProps)
                    str = strrep(obj.mdlGetHeaderString('include',customProps),'scanimage.SI.','SI.');
                else
                    str = strrep(obj.mdlGetHeaderString(),'scanimage.SI.','SI.');
                end
            end
        end
        
        function str = getRoiDataString(obj)
            s.RoiGroups.imagingRoiGroup = obj.hRoiManager.currentRoiGroup.saveobj;
            s.RoiGroups.photostimRoiGroups = arrayfun(@saveobj,obj.hPhotostim.stimRoiGroups);
            s.RoiGroups.integrationRoiGroup = obj.hIntegrationRoiManager.roiGroup.saveobj;
            str = most.json.savejson('',s,'tab','  ');
        end
        
        
        function startFocus(obj)
            % STARTFOCUS   Starts the acquisition in "FOCUS" mode
            obj.start('focus');
        end
        
        function startGrab(obj)
            % STARTGRAB   Starts the acquisition in "GRAB" mode
            obj.start('grab');
        end
        
        function startLoop(obj)
            % STARTLOOP   Starts the acquisition in "LOOP" mode
            obj.start('loop');
            if obj.acqsPerLoop > 1
                start(obj.hLoopRepeatTimer);
            end
        end
        
        function startCycle(obj)
            % STARTCYCLE   Starts the acquisitoin through the CycleManager component
            obj.hCycleManager.start();
        end

        function backupRoiGroups(obj)
            % BACKUPROIGROUPS saves current imaging ROIs, photostim stimulus groups and integration ROIs to a backup file.
            %   obj.backupRoiGroups   executes the backup
            obj.hRoiManager.backupRoiGroup();
            obj.hPhotostim.backupRoiGroups();
            obj.hIntegrationRoiManager.backupRoiGroup();
        end
        
        function scanPointBeam(obj)
            % SCANPOINTBEAM Points scanner at center of FOV, open shutters
            %   obj.scanPointBeam
            
            if obj.componentExecuteFunction('scanPointBeam')                
                obj.acqState = 'point';
                obj.acqParamCache = struct();
                
                obj.hStackManager.resetHome(); % this will prevent the stackmanager to move the stage when aborting the point mode
                
                obj.hScan2D.centerScanner();
                obj.hScan2D.openExcitationShutters();
                
                obj.acqInitDone = true;
            end
        end
    end
    
    %%% PUBLIC METHODS (Scan Parameter Caching)
    methods        
        function lineScanRestoreParams(obj,~)
            % LINESCANRESTOREPARAMS  Set ROI scan parameters (zoom,scanAngleMultiplier) to cached values.
            %   obj.lineScanRestoreParams(params)
            %
            % If no values are cached, restores the scan parameters stored in currently loaded CFG file.
            cachedProps = obj.cachedLineScanProps;
            
            if ~isempty(obj.lineScanParamCache)
                for i=1:length(cachedProps)
                    tempName = strrep(cachedProps{i},'.','_');
                    val = obj.lineScanParamCache.(tempName);
                    zlclRecursePropSet(obj,cachedProps{i},val);
                end
            else
                cfgfile = obj.hConfigurationSaver.cfgFilename;
                
                resetFailProps = {};
                if exist(cfgfile,'file')==2
                    cfgPropSet = obj.mdlLoadPropSetToStruct(cfgfile);
                    
                    for i=1:length(cachedProps)
                        if zlclRecurseIsField(cfgPropSet,cachedProps{i})
                            val = zlclRecursePropGet(cfgPropSet,cachedProps{i});
                            zlclRecursePropSet(obj,cachedProps{i},val);
                        else
                            resetFailProps{end+1} = cachedProps{i};   %#ok<AGROW>
                        end
                    end
                end
                
                if ~isempty(resetFailProps)
                    warning('SI:scanParamNotReset',...
                        'One or more scan parameters (%s) were not reset to base or config file value.',most.util.toString(resetFailProps));
                end
            end
        end
        
        function lineScanCacheParams(obj)
            % LINESCANCACHEPARAMS Caches scan parameters (zoom, scan angle multiplier) which can be recalled by scanParamResetToBase() method
            for i=1:numel(obj.cachedLineScanProps)
                val = zlclRecursePropGet(obj,obj.cachedLineScanProps{i});
                tempName = strrep(obj.cachedLineScanProps{i},'.','_');
                obj.lineScanParamCache.(tempName) = val;
            end
        end
    end

    %%% HIDDEN METHODS
    methods (Hidden)
        function zzzRestoreAcqCacheProps(obj)
            try
                cachedProps = obj.cachedAcqProps;
                for i=1:length(cachedProps)
                    tempName = strrep(cachedProps{i},'.','_');
                    if isfield(obj.acqParamCache,tempName)
                        val = obj.acqParamCache.(tempName);
                        zlclRecursePropSet(obj,cachedProps{i},val);
                    end
                end
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
        end
        
        function zzzSaveAcqCacheProps(obj)
            cachedProps = obj.cachedAcqProps;
            for i=1:length(cachedProps)
                tempName = strrep(cachedProps{i},'.','_');
                val = zlclRecursePropGet(obj,cachedProps{i});
                obj.acqParamCache.(tempName) = val;
            end
        end
    end
    
    methods (Access = protected, Hidden)
        % component overload function
        function val = componentGetActiveOverride(obj,~)
            isIdle = strcmpi(obj.acqState,'idle');
            val = ~isIdle && obj.acqInitDone;
        end
    end
    
    %% FRIEND METHODS
    %%% Super-user Methods
    methods (Hidden)
        function val = getSIVar(obj,varName)
            val = eval(['obj.' varName]);
        end
    end
    
    %% INTERNAL METHODS
    methods (Hidden)
        function zzzShutdown(obj, soft, completedAcquisitionSuccessfully)
            if nargin < 3 || isempty(completedAcquisitionSuccessfully)
                completedAcquisitionSuccessfully = false;
            end
             
            try
                obj.acqInitDone = false;
                
                if most.idioms.isValidObj(obj.hScan2D)
                    %Close shutters for stop acquisition.
                    obj.hScan2D.closeShutters();
                    
                    %Stop the imaging component
                    obj.hScan2D.abort(soft);
                end
                
                %Stop the Pmts component
                obj.hPmts.abort();
                
                obj.hWaveformManager.abort();
                
                %Stop photostim logging
                obj.hPhotostim.stopLogging();
                
                %Abort RoiManager
                obj.hRoiManager.abort();
                
                obj.hMotionManager.abort();

                obj.hIntegrationRoiManager.abort();
                
                %Set beams to standby mode for next acquisition.
                obj.hBeams.abort();
                
                %Stop the loop repeat timer.
                stop(obj.hLoopRepeatTimer);
                
                %Set display to standby mode for next acquisition.
                obj.hDisplay.abort(soft);
                
                %Put pmt controller in idle mode so status is periodically updated
                obj.hPmts.abort();
                
                obj.hFastZ.abort();
                
                %Wait for any pending moves to finish, move motors to home position
                obj.hStackManager.abort();
                
                %Stop the Channel Manager as a metter of course. Currently doesn't do anything.
                obj.hChannels.abort();
                
                %Change the acq State to idle.
                obj.acqState = 'idle';
                
                obj.hWSConnector.abort(completedAcquisitionSuccessfully);
                
                obj.zzzRestoreAcqCacheProps();
            catch ME
                %Change the acq State to idle.
                obj.acqState = 'idle';
                obj.acqInitDone = false;
                
                ME.rethrow;
            end
        end
        
        function zzzEndOfAcquisitionMode(obj)
            obj.zzzEndOfAcquisition();
            
            %This function is called at the end of FOCUS, GRAB, and LOOP acquisitions.
            obj.hCycleManager.acqModeCompleted(); % This function does nothing.
            
            abortCycle = false;
            completedAcquisitionSuccessfully = true;
            obj.abort([],abortCycle,completedAcquisitionSuccessfully);
            
            % Moved after the abort command so user functions can call
            % startLoop or startGrab at the end of an acquisition.
            obj.hUserFunctions.notify('acqModeDone');
        end
        
        function zzzEndOfAcquisition(obj)
            stackDone = obj.hStackManager.endOfAcquisition();
            
            if stackDone
                obj.hUserFunctions.notify('acqDone');
                
                %Handle end of GRAB or LOOP Repeat
                obj.loopAcqCounter = obj.loopAcqCounter + 1;
                
                %Update logging file counters for next Acquisition
                if obj.hChannels.loggingEnable
                    obj.hScan2D.logFileCounter = obj.hScan2D.logFileCounter + 1;
                end
                
                obj.hStackManager.volumesDone = 0;
                
                %For Loop, restart or re-arm acquisition
                if isequal(obj.acqState,'loop')
                    obj.acqState = 'loop_wait';
                else
                    obj.zzzShutdown(false);
                end
            end
        end
    end
    
    %%% Callbacks
    methods (Hidden)
        function zzzFrameAcquiredFcn(obj,~,~) % Executes on Every Stripe as well.
            try
                %%%%%%%%%%%%%%% start of frame batch loop %%%%%%%%%%%%%%%%%%%
                maxBatchTime = 1/obj.DISPLAY_REFRESH_RATE;
                
                readSuccess = false;
                processFrameBatch = true;
                loopStart = tic;
                while processFrameBatch && toc(loopStart) <= maxBatchTime;
                    [readSuccess,stripeData] = obj.hScan2D.readStripeData();
                    if ~readSuccess;break;end % tried to read from empty queue
                    
                    % Stop processing frames once the number of frames remaining in this batch is zero
                    processFrameBatch = stripeData.stripesRemaining > 0;
                    
                    %**********************************************************
                    %HANDLE OVER-VOLTAGE CONDITION IF DETECTED.
                    %**********************************************************
                    if stripeData.overvoltage && ~obj.overvoltageStatus && ~most.idioms.isValidObj(obj.hOvervoltageMsgDialog)% Only fire this event once
                        obj.hUserFunctions.notify('overvoltage');
                        obj.overvoltageStatus = true;
                        most.idioms.dispError('DC Overvoltage detected. <a href ="matlab: hSI.hScan2D.hAcq.resetDcOvervoltage();disp(''Overvoltage reset successfully'')">RESET DIGITIZER</a>\n');
                        most.idioms.safeDeleteObj(obj.hOvervoltageMsgDialog);
                        obj.hOvervoltageMsgDialog = most.gui.nonBlockingDialog('Overvoltage detected',...
                            sprintf('The PMT signal exceeded the input range of the digitizer.\nThe input coupling changed from DC to AC to protect the digitizer.\n'),...
                            { {'Reset Digitizer',@(varargin)obj.hScan2D.hAcq.hFpga.resetDcOvervoltage()},...
                            {'Abort Acquisition',@(varargin)obj.abort()},...
                            {'Ignore',[]} },...
                            'Position',[0,0,350,150]);
                    elseif ~stripeData.overvoltage
                        obj.overvoltageStatus = false;
                        %                     if ~isempty(obj.hOvervoltageMsgDialog)
                        %                         most.idioms.safeDeleteObj(obj.hOvervoltageMsgDialog);
                        %                         obj.hOvervoltageMsgDialog =  [];
                        %                     end
                    end
                    
                    %**********************************************************
                    %HANDLE ACCOUNTING FOR FIRST FRAME OF ACQUISITION
                    %**********************************************************
                    if isequal(obj.acqState,'loop_wait')
                        obj.acqState = 'loop'; %Change acquisition state to 'loop' if we were in a 'loop_wait' mode.
                        obj.zprvResetAcqCounters();
                    end
                    
                    if stripeData.frameNumberAcq(1) == 1 && stripeData.startOfFrame
                        %Reset counters if this is the first frame of an acquisition.
                        obj.hUserFunctions.notify('acqStart');
                        %Only reset countdown timer if we are not currently in
                        %a slow stack grab.
                        if ~obj.hStackManager.isSlowZ
                            obj.zzStartSecondsCounter();
                        end
                    end
                    
                    % handle stacks
                    stripeData = obj.hStackManager.stripeAcquired(stripeData);
                    
                    %**********************************************************
                    %SEND FRAMES TO DISPLAY BUFFER
                    %**********************************************************
                    % Calling Integration Manager update
                    if stripeData.endOfFrame
                        stripeData = obj.hMotionManager.estimateMotion(stripeData);
                        obj.hPhotostim.compensateMotion();
                        obj.hIntegrationRoiManager.update(stripeData);
                    end
                    
                    obj.hDisplay.averageStripe(stripeData);
                    
                    if stripeData.endOfFrame
                        obj.hUserFunctions.notify('frameAcquired');
                    end
                    %**********************************************************
                    %ACQUISITION MODE SPECIFIC BEHAVIORS
                    %**********************************************************
                    switch obj.acqState
                        case 'focus'
                            if etime(clock, obj.acqStartTime) >= obj.focusDuration
                                obj.zzzEndOfAcquisition();
                            end
                        case {'grab' 'loop'}
                            %Handle signals from FPGA
                            if stripeData.endOfAcquisitionMode
                                obj.zzzEndOfAcquisitionMode();
                            elseif stripeData.endOfAcquisition
                                obj.zzzEndOfAcquisition();
                            end
                        case {'idle'}
                            %Do nothing...should this be an error?
                    end
                end
                %%%%%%%%%%%%%%% end of frame batch loop %%%%%%%%%%%%%%%%%%%
                
                if readSuccess
                    %**********************************************************
                    % DRAW FRAME BUFFER
                    %**********************************************************
                    obj.hDisplay.displayChannels();
                    
                    %**********************************************************
                    %UPDATE FRAME COUNTERS
                    %**********************************************************
                    obj.frameCounterForDisplay = obj.hStackManager.framesDone;
                end
                
            catch ME
                most.ErrorHandler.logAndReportError(ME,'An error occurred during frame processing. Datalogging to disk was uninterrupted but display and advanced processing failed.');
                
                if ~most.idioms.isValidObj(obj.hFAFErrMsgDialog)
                    obj.hFAFErrMsgDialog = most.gui.nonBlockingDialog('Frame Processing Error',...
                        sprintf(['An error occurred during frame processing. Datalogging to disk was '...
                        'uninterrupted but display and advanced processing failed. If this problem persists '...
                        'contact support and include a support report.']),...
                        { {'Abort Acquisition',@(varargin)obj.abort()},...
                        {'Generate Support Report',@(varargin)scanimage.util.generateSIReport(0)},...
                        {'Ignore',[]} },...
                        'Position',[0,0,500,120]);
                end
            end
            
            % This has to occur at the very end of the frame acquired function
            % signal scan2d that we are ready to receive new data
            obj.hScan2D.signalReadyReceiveData();
        end
        
        function zzzLoopTimerFcn(obj,src,~)
            obj.zprvUpdateSecondsCounter();
            
            if ~obj.hScan2D.trigAcqTypeExternal && ismember(obj.acqState,{'loop_wait'})
                if floor(obj.secondsCounter) <= 0
                    obj.zprvResetAcqCounters();
                    
                    obj.hScan2D.trigIssueSoftwareAcq();
                    stop(src);
                    
                    start(src);
                    obj.secondsCounter = obj.loopAcqInterval;
                end
            elseif obj.secondsCounter == 0
                most.idioms.warn('Software timer went to zero during active loop. Waiting until end of current acq before issuing software trigger.');
            end
        end
    end
    
    %%% TBD
    methods (Hidden)
        %% Timer functions
        function zprvUpdateSecondsCounter(obj)
            % Simple countup/countdown timer functionality.
            switch obj.acqState
                case 'focus'
                    obj.secondsCounter = obj.secondsCounter + 1;
                case 'grab'
                    obj.secondsCounter = obj.secondsCounter + 1;
                case 'loop_wait'
                    switch obj.secondsCounterMode
                        case 'up'
                            obj.secondsCounter = obj.secondsCounter + 1;
                        case 'down'
                            obj.secondsCounter = obj.secondsCounter - 1;
                    end
                case 'loop'
                    switch obj.secondsCounterMode
                        case 'up'
                            obj.secondsCounter = obj.secondsCounter + 1;
                        case 'down'
                            obj.secondsCounter = obj.secondsCounter - 1;
                    end
                otherwise
            end
        end
        
        function zzStartSecondsCounter(obj)
            if ismember(obj.acqState,{'focus','grab'}) || (ismember(obj.acqState,{'loop','loop_wait'}) && obj.hScan2D.trigAcqTypeExternal)
                obj.secondsCounter = 0;
            else
                obj.secondsCounter = obj.loopAcqInterval;
            end
        end
        
        function zprvResetAcqCounters(obj)
            
            %If in loop acquisition, do not reset the loopAcqCounter.
            if ~strcmpi(obj.acqState,'loop') && ~strcmpi(obj.acqState,'loop_wait')
                obj.loopAcqCounter = 0;
            end
            
            %Reset Frame Counter.
            obj.frameCounterForDisplay = 0;
        end
        
        function zprvMotorErrorCbk(obj,varargin)
            if obj.isLive()
                most.idioms.dispError('Motor error occurred. Aborting acquisition.\n');
                obj.abort();
            end
        end
        
        function tf = isLive(obj)
            tf = ismember(obj.acqState,{'focus' 'grab' 'loop'});
        end
        
        function s2dPrepList = getScan2DFromMdf(obj)
            % find all scanning systems
            mdf = most.MachineDataFile.getInstance;
            hdgs = {mdf.fHData.heading};
            
            %enumerate scan2d types
            s2dp = 'scanimage/components/scan2d';
            list = what(s2dp);
            list = list(1); % workaround for sparsely occuring issue where list is a 2x1 structure array, where the second element is empty
            s2dp = [strrep(s2dp,'/','.') '.'];
            names = cellfun(@(x)[s2dp x(1:end-2)],list.m,'UniformOutput',false);
            r = cellfun(@(x){eval(strcat(x,'.mdfHeading')) str2func(x)},names,'UniformOutput',false);
            r = horzcat(r{:});
            s2dMap = struct(r{:});
            s2dMdfHdgs = fieldnames(s2dMap);
            
            % search the mdf for each scan2d type
            s2dPrepList = struct;
            
            scannerHeadings = regexp(hdgs,'(.+)\((.+)\)','tokens');
            isScanner = ~cellfun(@isempty,scannerHeadings);
            
            for scannerHeading = scannerHeadings(isScanner)
                type = strtrim(scannerHeading{1}{1}{1});
                name = strtrim(scannerHeading{1}{1}{2});
                
                if ismember(type,s2dMdfHdgs) && (isempty(scanners) || ismember(name, scanners))
                    if isfield(s2dPrepList,name)
                        most.idioms.warn('Scanner names must be unique. ''%s'' is duplicated.',name);
                    elseif isvarname(name)
                        s2dPrepList.(name).initFunc = s2dMap.(type);
                        s2dPrepList.(name).type = type;
                    else
                        most.idioms.warn('Invalid scanner name. Names must be alphanumeric. ''%s'' will not be initialized',name);
                    end
                end
            end
        end
    end
    
    %%% ABSTRACT METHOD IMPLEMENTATONS (scanimage.interfaces.Component)
    methods (Access = protected)
        %Handle all component coordination at start
        function componentStart(obj, acqType)
            %   Starts the acquisition given the selected mode and propagates the event to all components
            
            assert(~obj.imagingSystemChangeInProgress,'Cannot start acquisition while imaging system switch is in progress.');
            assert(~obj.hPhotostim.active || obj.hPhotostim.parallelSupport, 'Current configuration does not support simultaneous imaging and stimulation. Abort photostim to start imaging.');
            
            
            
            if isempty(obj.hChannels.channelDisplay) && isempty(obj.hChannels.channelSave)
                most.idioms.dispError('Error: At least one channel must be selected for display or logging\n');
                return;
            end
            
            try
                assert(ismember(acqType, {'focus' 'grab' 'loop'}), 'Cannot start unknown acqType.');
                obj.acqState = acqType;
                obj.acqInitInProgress = true;
                %TODO: implement 'point'
                
                %Initialize component props (accounting for mode etc)
                obj.zzzSaveAcqCacheProps();
                
                switch acqType
                    case 'focus'
                        obj.hStackManager.enable = false;
                        obj.hStackManager.framesPerSlice = Inf;
                        obj.hChannels.loggingEnable = false;
                        obj.hPhotostim.logging = false;
                        obj.extTrigEnable = false;
                        obj.acqsPerLoop = 1;
                    case 'grab'
                        obj.acqsPerLoop = 1;
                    case 'loop'
                        % no-op
                end
                
                zzzResetAcqTransientVars();
                
                switch lower(acqType)
                    case 'focus'
                        obj.hUserFunctions.notify('focusStart');
                    case 'grab'
                        obj.hUserFunctions.notify('acqModeStart');
                    case 'loop'
                        obj.hUserFunctions.notify('acqModeStart');
                        obj.hLoopRepeatTimer.TasksToExecute = Inf;
                    otherwise
                        most.idioms.warn('Unknown acquisition type. Assuming ''focus''');
                        acqType = 'focus';
                        obj.hUserFunctions.notify('focusStart');
                end
                
                obj.hPmts.start();
                
                obj.hStackManager.start();
                obj.hRoiManager.start();
                
                obj.hPmts.waitAutoPowerComplete(); % give PMTs time to power on before measuring channel offsets
                armScan2D();
                
                obj.hWaveformManager.updateWaveforms();
                obj.hWaveformManager.start();
                zzzInitializeLogging(); % header props need to be generated after updateWaveforms to capture waveformManager's optimizedScanners property
                
                %Start each SI component
                obj.hChannels.start();
                obj.hDisplay.start();
                obj.hBeams.start();
                obj.hFastZ.start();
                obj.hMotionManager.start();
                obj.hScan2D.start();
                obj.hIntegrationRoiManager.start(); %needs to be started after scan2d
                obj.hPhotostim.startLogging();

                obj.hScan2D.startShuttersTransition(true);
                
                %Initiate acquisition
                obj.zzStartSecondsCounter();
                obj.acqStartTime = clock();
                obj.acqInitDone = true;
                
                obj.hScan2D.signalReadyReceiveData();
                obj.acqInitInProgress = false;
                if any(ismember(acqType,{'loop' 'grab'}))
                    obj.hUserFunctions.notify('acqModeArmed');
                end
                
                obj.hScan2D.waitShuttersTransitionComplete();
                
                zzzIssueTrigger();
                
                if ~isa(obj.hScan2D,'scanimage.components.scan2d.SlmScan')
                    % zzzIssueTrigger does not return because of the SlmScan
                    % acquisition loop for SlmScan the code below would
                    % only be executed after the acquisition is stopped.
                    % after the acquisition is stopped, we don't whant to
                    % start the wavesurfer connector
                    obj.hWSConnector.start(acqType);
                end
            catch ME
                obj.acqState = 'idle';
                obj.acqInitInProgress = false;
                
                ME.rethrow();
            end
            
            %%% LOCAL FUNCTION DEFINITIONS
            function zzzIssueTrigger()
                %Issues software timed
                softTrigger = (ismember(obj.acqState,{'grab' 'loop'}) && (~obj.hScan2D.trigAcqTypeExternal || ~obj.extTrigEnable))...
                    || isequal(obj.acqState, 'focus');
                
                if softTrigger
                    obj.hScan2D.trigIssueSoftwareAcq(); % ignored if obj.hAcq.triggerTypeExternal == true
                end
            end
            
            function zzzResetAcqTransientVars()
                obj.acqInitDone = false;
                obj.loopAcqCounter = 0;
                obj.overvoltageStatus = false;
                
                most.idioms.safeDeleteObj(obj.hOvervoltageMsgDialog);
                obj.hOvervoltageMsgDialog =  [];
                most.idioms.safeDeleteObj(obj.hFAFErrMsgDialog);
                obj.hFAFErrMsgDialog =  [];
                
                obj.zprvResetAcqCounters(); %Resets /all/ counters
            end
            
            function armScan2D()
                if obj.hScan2D.channelsAutoReadOffsets
                    obj.hScan2D.measureChannelOffsets();
                end
                
                obj.hScan2D.arm();
            end
            
            function zzzInitializeLogging()
                %Set the hScan2D (hidden) logging props
                if obj.hChannels.loggingEnable
                    modelProps = obj.mdlCustomProps;
                    externalProps = obj.extCustomProps;
                    
                    if ~isempty(modelProps)
                        if ~iscell(modelProps)
                            modelProps = [];
                        end
                    end
                    
                    if ~isempty(obj.extCustomProps)
                        if ~iscell(obj.extCustomProps)
                            externalProps = [];
                        else
                            externalProps = most.util.processExtCustomProps(externalProps);
                        end
                    end
                    if ~isempty(externalProps)
                        hdrBuf = [uint8(obj.getHeaderString(modelProps)) uint8(externalProps) 0];
                    else
                        hdrBuf = [uint8(obj.getHeaderString(modelProps)) 0];
                    end
                    hdrBufLen = length(hdrBuf);
                    
                    
                    hdrBuf = [hdrBuf uint8(obj.getRoiDataString()) 0];
                    
                    
                    pfix = [1 3 3 7 typecast(uint32(obj.TIFF_FORMAT_VERSION),'uint8') typecast(uint32(hdrBufLen),'uint8') typecast(uint32(length(hdrBuf)-hdrBufLen),'uint8')];
                    obj.hScan2D.tifHeaderData = [pfix hdrBuf]'; % magic number, format version, header byte count, roi data byte count, data
                    obj.hScan2D.tifHeaderStringOffset = length(pfix); % magic number, format version, byte count, hdrdata
                    
                    obj.hScan2D.tifRoiDataStringOffset = length(pfix) + hdrBufLen; % magic number, format version, byte count, hdrdata, roidata
                end
            end
        end
        
        function componentAbort(obj,soft,abortCycle,completedAcquisitionSuccessfully)
            % COMPONENTABORT Aborts the acquisition, affecting active components and sending related events
            %   obj.componentAbort         Hard shutdown of the microscope
            %
            % Aborts any running task or acquisition using this component.
            %
            if nargin < 2 || isempty(soft)
                soft = false;
            end
            if nargin < 3 || isempty(abortCycle)
                abortCycle = ~soft;
            end
            if nargin < 4 || isempty(completedAcquisitionSuccessfully)
                completedAcquisitionSuccessfully = false;
            end
            
            obj.hUserFunctions.notify('acqAbort');
            cachedAcqState = obj.acqState;
            
            obj.zzzShutdown(soft,completedAcquisitionSuccessfully);
            
            %Update logging file counters for next Acquisition
            if ismember(cachedAcqState,{'grab' 'loop'}) && obj.hChannels.loggingEnable
                obj.hScan2D.logFileCounter = obj.hScan2D.logFileCounter + 1;
            end
            
            %Restore cached acq state (only in focus mode)
            if ismember(cachedAcqState,{'focus'})
                obj.hUserFunctions.notify('focusDone');
            end
            
            if abortCycle
                obj.hCycleManager.abort();
            elseif ~soft
                obj.hCycleManager.iterationCompleted();
            end
        end
    end
end

%% LOCAL (after classdef)
function val = zlclRecurseIsField(obj, prop)
    [ basename, propname ] = strtok(prop,'.'); % split the basename of the property from the propname (if such a difference exists)
    if ~isempty(propname)
        val = zlclRecurseIsField(obj.(basename),propname(2:end));
    else
        val = isfield(obj,prop);
    end
end

function val = zlclRecursePropGet(obj, prop)
    [ basename, propname ] = strtok(prop,'.'); % split the basename of the property from the propname (if such a difference exists)
    if ~isempty(propname)
        val = zlclRecursePropGet(obj.(basename),propname(2:end));
    else
        val = obj.(prop);
    end
end

function zlclRecursePropSet(obj, prop, val)
    [ basename, propname ] = strtok(prop,'.'); % split the basename of the property from the propname (if such a difference exists)
    if ~isempty(propname)
        zlclRecursePropSet(obj.(basename),propname(2:end),val);
    else
        obj.(prop) = val;
    end
end

function s = zlclInitPropAttributes()
    %At moment, only application props, not pass-through props, stored here -- we think this is a general rule
    %NOTE: These properties are /ordered/..there may even be cases where a property is added here for purpose of ordering, without having /any/ metadata.
    %       Properties are initialized/loaded in specified order.
    %
    s = struct();

    %%% Acquisition
    s.acqsPerLoop = struct('Classes','numeric','Attributes',{{'scalar' 'positive' 'integer' 'finite'}});
    s.extTrigEnable = struct('Classes','binaryflex','Attributes',{{'scalar'}});

    s.focusDuration = struct('Range',[1 inf]);
    s.loopAcqInterval = struct('Classes','numeric','Attributes',{{'scalar','positive','integer','finite'}});
    s.useJsonHeaderFormat = struct('Classes','binaryflex','Attributes',{{'scalar'}});
    s.objectiveResolution = struct('Classes','numeric','Attributes',{{'scalar' 'positive' 'finite' 'nonnan'}});

    s.hMotionManager = struct('Classes','most.Model');

    %%% Submodel/component props
    s.hWaveformManager = struct('Classes','most.Model');
    s.hShutters = struct('Classes','most.Model');
    s.hChannels = struct('Classes','most.Model');
    s.hMotors   = struct('Classes','most.Model');
    s.hBeams    = struct('Classes','most.Model');
    s.hFastZ    = struct('Classes','most.Model');
    s.hDisplay  = struct('Classes','most.Model');
    s.hRoiManager = struct('Classes','most.Model');
    s.hConfigurationSaver = struct('Classes','most.Model');
    s.hUserFunctions = struct('Classes','most.Model');
    s.hStackManager = struct('Classes','most.Model');
    s.hWSConnector  = struct('Classes','most.Model');
    s.hPmts = struct('Classes','most.Model');
    s.hMotionManager = struct('Classes','most.Model');
    s.hCoordinateSystems = struct('Classes','most.Model');
    s.hSlmScan = struct('Classes','most.Model');
    s.hPhotostim  = struct('Classes','most.Model');
    s.hIntegrationRoiManager = struct('Classes','most.Model');
    s.hCameraManager = struct('Classes','most.Model');
end

function s = defaultMdfSection()
    s = [...
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('Global microscope properties')... % comment only
        most.HasMachineDataFile.makeEntry('objectiveResolution',15,'Resolution of the objective in microns/degree of scan angle')...
        ...
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('Data file location')... % comment only
        ...
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('Custom Scripts')... % comment only
        most.HasMachineDataFile.makeEntry('startUpScript','','Name of script that is executed in workspace ''base'' after scanimage initializes')...
        most.HasMachineDataFile.makeEntry('shutDownScript','','Name of script that is executed in workspace ''base'' after scanimage exits')...
        ...
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('fieldCurvatureZs', [],'Field curvature for mesoscope')...
        most.HasMachineDataFile.makeEntry('fieldCurvatureRxs',[],'Field curvature for mesoscope')...
        most.HasMachineDataFile.makeEntry('fieldCurvatureRys',[],'Field curvature for mesoscope')...
        most.HasMachineDataFile.makeEntry('fieldCurvatureTip',0,'Field tip for mesoscope')...
        most.HasMachineDataFile.makeEntry('fieldCurvatureTilt',0,'Field tilt for mesoscope')...
        ...
        most.HasMachineDataFile.makeEntry('useJsonHeaderFormat',false,'Use JSON format for TIFF file header')...
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
