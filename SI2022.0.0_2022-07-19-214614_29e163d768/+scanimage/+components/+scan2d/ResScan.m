classdef ResScan < scanimage.components.Scan2D & most.HasMachineDataFile & dabs.resources.configuration.HasConfigPage
    % ResScan - subclass of Scan2D for resonant scanning
    %   - controls a resonant(X) - galvo(X) mirror pair OR
    %              a resonant(X) - galvo(X) - galvo(Y) mirror triplet
    %   - handles the configuration of the NI-FlexRIO FPGA and digitizer
    %       module for acquiring PMT
    %   - format PMT data into images
    %   - handles acquistion timing and acquisition state
    %   - export timing signals
    
    properties (SetAccess=protected,Hidden)
        ConfigPageClass = 'dabs.resources.configuration.resourcePages.ResScanPage';
    end
    
    methods (Static)
        function names = getDescriptiveNames()
            names = {'ResScan'};
        end
    end
    
    %% USER PROPS
    properties (SetObservable, Transient)
        linePhaseMode = 'Nearest Neighbor';   % Specifies method for estimating line phase if it is not measured at the current resonant amplitude
        % Note: This is all just guessing. The user must either explicitly
        % set scan phases for all zoom levels or we have to make a way for
        % the scanner to automatically set the scan phase for perfect bidi
        % alignment.
        %
        % Interpolate:      Linearly interpolate between next lower and next
        %                   higher zoom factor with a set scan phase.
        % Nearest Neighbor: Choose between scan phase of next lower and next
        %                   higher zoom factor with a set scan phase, whichever zoom factor is
        %                   closest to current.
        % Next Lower:       Choose the scan phase of the next lower zoom factor
        %                   with a set scan phase.
        % Next Higher:      Choose the scan phase of the next higher zoom factor
        %                   with a set scan phase.
        
        keepResonantScannerOn = false;  % Indicates that resonant scanner should always be on. Avoids settling time and temperature drift
        sampleRate;                     % [Hz] sample rate of the digitizer; cannot be set
        pixelBinFactor = 1;             % if objuniformSampling == true, pixelBinFactor defines the number of samples used to form a pixel
        channelOffsets;                 % Array of integer values; channelOffsets defines the dark count to be subtracted from each channel if channelsSubtractOffsets is true
        channelsInvert = false;
        laserTriggerPort = '';
        auxTriggersEnable = false;
        
        externalSampleClock = false;
        externalSampleClockRate = 80e6;
    end
    
    properties (SetObservable)
        uniformSampling = false;        % [logical] defines if the same number of samples should be used to form each pixel (see also pixelBinFactor); if true, the non-uniform velocity of the resonant scanner over the field of view is not corrected
        maskDisableAveraging = false;   % [logical, array] defines for each channel if averaging is enabled/disabled
        
        scanMode = 'resonant';
    end
    
    properties (SetObservable, Hidden)
        recordScannerFeedback = false;
    end
    
    %These are stored in class data file, so don't cfg
    properties (SetObservable, Transient, Dependent)
        mask;
        laserTriggerSampleMaskEnable;
        laserTriggerSampleWindow;
        laserTriggerDebounceTicks;
    end
    
    
    %% FRIEND PROPS
    properties (Hidden, SetObservable)
        enableContinuousFreqMeasurement = false;
        
        useResonantTimebase = true;
        resonantSettlingPeriods = 100;
        nomResPeriodTicks;
        resonantTimebaseNominalRate = 1e6;
        resonantTimebaseTicksPerPeriod;
        scannerPeriodRTB;
        
        hDAQAcq = dabs.resources.Resource.empty();
        hDAQAux = dabs.resources.Resource.empty();
        hResonantScanner = dabs.resources.Resource.empty();
        xGalvo = dabs.resources.Resource.empty();
        yGalvo = dabs.resources.Resource.empty();
        hFastZs = {};
        hShutters = {};
        hBeams = {};
        hDataScope = [];
        
        coercedFlybackTime;
        coercedFlytoTime;
        
        enableBenchmark = false;
        
        lastFrameAcqFcnTime = 0;
        totalFrameAcqFcnTime = 0;
        cpuFreq = 2.5e9;
        
        totalDispUpdates = 0;
        totalDispUpdateTime = 0;
        extendedRggFov = false;
        reverseLineRead = false;
        
        laserTriggerFilterSupport = true;
        laserTriggerDemuxSupport = false;
    end
    
    properties (Hidden, Dependent)
        resonantScannerLastWrittenValue;
        numDigitizerChannels;
    end
    
    properties (Hidden)
        disableResonantZoomOutput = false;
        flagZoomChanged = false;        % (Logical) true if user changed the zoom via spinner controls.
        
        liveScannerFreq;
        lastLiveScannerFreqMeasTime;
        
        controllingFastZ = false;
    end
 
    %% INTERNAL PROPS
    properties (Hidden, SetAccess = private)            
        hAcq;                               % handle to image acquisition system
        hCtl;                               % handle to galvo control system
        hTrig;                              % handle to trigger system
    end
    
    properties (Hidden, SetAccess = protected, Dependent) 
        %         trigAcqInTermAllowed;               % cell array of strings with allowed terminal names for the acq trigger (e.g. {'PFI1','PFI2'})
        %         trigNextInTermAllowed;              % cell array of strings with allowed terminal names for the acq trigger (e.g. {'PFI1','PFI2'})
        %         trigStopInTermAllowed;              % cell array of strings with allowed terminal names for the acq trigger (e.g. {'PFI1','PFI2'})        
        linePhaseStep;                      % [s] minimum step size of the linephase
        
        periodsPerFrame;
        digitalIODeviceType;
        digitalIODaqName;
    end
    
    properties (Hidden, SetAccess = protected)
        %allowedTriggerInputTerminals;
        %allowedTriggerInputTerminalsMap;
        
        defaultRoiSize;
        angularRange;
        supportsRoiRotation = false;
        physicalChannels = [];
    end
    
    %%% Abstract prop realizations (most.Model)
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = zlclAppendDependsOnPropAttributes(scanimage.components.Scan2D.scan2DPropAttributes());
        mdlHeaderExcludeProps = {'hFastZ' 'hShutters' 'logFileStem' 'logFilePath' 'logFileCounter' 'channelsAvailableInputRanges'};
    end    
        
    %%% Abstract property realizations (most.HasMachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'ResScan';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp; %#ok<MCCPI>
        mdfPropPrefix; %#ok<MCCPI>
        
        mdfDefault = defaultMdfSection();
    end
    
    %%% Abstract prop realization (scanimage.interfaces.Component)
    properties (SetAccess = protected, Hidden)
        numInstances = 0;
    end        
    
    %%% Abstract property realizations (scanimage.subystems.Scan2D)
    properties (Hidden, Constant)
        builtinFastZ = false;
    end
    
    properties (SetAccess = protected)
        scannerType;
        hasXGalvo;                          % logical, indicates if scanner has a galvo X mirror
        hasResonantMirror = true;           % logical, indicates if scanner has a resonant mirror
        isPolygonalScanner = false;         % logical, indicates if the resonant scanner is actually a polygonal scanner
    end
    
    properties (Constant, Hidden)
        linePhaseUnits = 'seconds';
    end
    
    %%% Constants
    properties (Constant, Hidden)
        MAX_NUM_CHANNELS = 4;               % Maximum number of channels supported
        
        COMPONENT_NAME = 'ResScan';                                                     % [char array] short name describing functionality of component e.g. 'Beams' or 'FastZ'
        PROP_TRUE_LIVE_UPDATE = {...              % Cell array of strings specifying properties that can be set while the component is active
            'linePhase','logFileCounter','channelsFilter','channelsAutoReadOffsets'};
        PROP_FOCUS_TRUE_LIVE_UPDATE = {};    % Cell array of strings specifying properties that can be set while focusing
        DENY_PROP_LIVE_UPDATE = {'framesPerAcq','trigAcqTypeExternal',...  % Cell array of strings specifying properties for which a live update is denied (during acqState = Focus)
            'trigAcqTypeExternal','trigNextStopEnable','trigAcqInTerm',...
            'trigNextInTerm','trigStopInTerm','trigAcqEdge','trigNextEdge',...
            'trigStopEdge','stripeAcquiredCallback','logAverageFactor','logFilePath',...
            'logFileStem','logFramesPerFile','logFramesPerFileLock','logNumSlices'};
        
        FUNC_TRUE_LIVE_EXECUTION = {'readStripeData','trigIssueSoftwareAcq','measureScannerFrequency',...
            'trigIssueSoftwareNext','trigIssueSoftwareStop'};  % Cell array of strings specifying functions that can be executed while the component is active
        FUNC_FOCUS_TRUE_LIVE_EXECUTION = {}; % Cell array of strings specifying functions that can be executed while focusing
        DENY_FUNC_LIVE_EXECUTION = {'pointScanner','parkScanner','centerScanner'};  % Cell array of strings specifying functions for which a live execution is denied (during acqState = Focus)
    end    
    
    %% Lifecycle
    methods
        function obj = ResScan(name)
            % ResScan constructor for scanner object
            %  obj = ResScan(name)
            obj = obj@scanimage.components.Scan2D(name);
            obj = obj@most.HasMachineDataFile(true);
            
            %Construct sub-components
            % Open FPGA acquisition adapter
            obj.hAcq = scanimage.components.scan2d.resscan.Acquisition(obj);
            
            % Open scanner control adapter
            obj.hCtl = scanimage.components.scan2d.resscan.Control(obj);
            
            % Open trigger routing adapter
            obj.hTrig = scanimage.components.scan2d.resscan.Triggering(obj);
            
            obj.deinit();
            
            obj.numInstances = 1; % some properties won't set correctly if numInstances == 0 (e.g. scannerToRefTransform)
            obj.loadMdf();
        end
        
        function delete(obj)
            % delete - deletes the ResScan object, parks the mirrors and
            %   deinitializes all routes
            %   obj.delete()  returns nothing
            %   delete(obj)   returns nothing
            
            obj.deinit();
            
            most.idioms.safeDeleteObj(obj.hTrig);
            most.idioms.safeDeleteObj(obj.hAcq);
            most.idioms.safeDeleteObj(obj.hCtl);
            
            obj.saveCalibration();
        end
    end
    
    methods
        function tf = checkSimulated(obj)
            tf = false;
            tf = tf || (most.idioms.isValidObj(obj.hDAQAcq) && obj.hDAQAcq.simulated);
            tf = tf || (most.idioms.isValidObj(obj.hDAQAux) && obj.hDAQAux.simulated);
            tf = tf || (most.idioms.isValidObj(obj.xGalvo) && most.idioms.isValidObj(obj.xGalvo.hAOControl) && obj.xGalvo.hAOControl.hDAQ.simulated);
            tf = tf || (most.idioms.isValidObj(obj.yGalvo) && most.idioms.isValidObj(obj.yGalvo.hAOControl) && obj.yGalvo.hAOControl.hDAQ.simulated);
            tf = tf || (most.idioms.isValidObj(obj.hResonantScanner) && most.idioms.isValidObj(obj.hResonantScanner.hDISync) && obj.hResonantScanner.hDISync.hDAQ.simulated);
        end
        
        function validateConfiguration(obj)
            try
                thisClassName = class(obj);
                otherClasses = obj.hResourceStore.filter(@(hR)isa(hR,thisClassName)&&(hR~=obj));
                assert(isempty(otherClasses),'Cannot instantiate more than one ResScan. Scanners %s violates this rule.',strjoin(cellfun(@(c)c.name,otherClasses,'UniformOutput',false),','));
                
                assert(most.idioms.isValidObj(obj.hDAQAcq),'Acquisition digitizer is not defined');
                assert(most.idioms.isValidObj(obj.hDAQAcq.hAdapterModule)&&verifyAllowedAdpaterModule(obj.hDAQAcq.hAdapterModule),'No valid FlexRIO adapter module found');
                
                assert(most.idioms.isValidObj(obj.hDAQAux),'Digital IO board is not defined');
                
                assert(most.idioms.isValidObj(obj.hResonantScanner),'Resonant scanner is undefined');
                obj.hResonantScanner.assertNoError();
                
                assert(most.idioms.isValidObj(obj.yGalvo),'yGalvo is undefined');
                obj.yGalvo.assertNoError();
                
                if most.idioms.isValidObj(obj.xGalvo)
                    obj.xGalvo.assertNoError();
                    assert(isequal(obj.xGalvo.hAOControl.hDAQ,obj.yGalvo.hAOControl.hDAQ),'X and Y galvo must be configured to be on same DAQ board');
                    assert(~isequal(obj.xGalvo,obj.yGalvo),'x and y galvo cannot be the same.');
                end
                
                beamErrors = cellfun(@(hB)~isempty(hB.errorMsg),obj.hBeams);
                assert(~any(beamErrors),'Beams %s are in error state', strjoin(cellfun(@(hB)hB.name,obj.hBeams(beamErrors),'UniformOutput',false)));
                
%                 beamDaqNames = cellfun(@(hB)hB.hAOControl.hDAQ.name,obj.hBeams,'UniformOutput',false);
                fastBeamDevicesMask = cellfun(@(hB)isa(hB, 'dabs.resources.devices.BeamModulatorFast'), obj.hBeams);
                fastBeamDevices = obj.hBeams(fastBeamDevicesMask);
                beamDaqNames = cellfun(@(hB)hB.hAOControl.hDAQ.name,fastBeamDevices,'UniformOutput',false);
                beamDaqName = unique(beamDaqNames);
                assert(numel(beamDaqName)<=1,'All ResScan beams must be configured to be on the same DAQ board. Current configuration: %s',strjoin(beamDaqName,','));
                
                fastZErrors = cellfun(@(hFZ)~isempty(hFZ.errorMsg),obj.hFastZs);
                assert(~any(fastZErrors),'FastZs %s are in error state', strjoin(cellfun(@(hFZ)hFZ.name,obj.hFastZs(fastZErrors),'UniformOutput',false)));
                
                fastZDaqNames = cellfun(@(hFZ)hFZ.hAOControl.hDAQ.name,obj.hFastZs,'UniformOutput',false);
                fastZDaqName = unique(fastZDaqNames);
                assert(numel(fastZDaqName)<=1,'All ResScan FastZs must be configured to be on the same DAQ board. Current configuration: %s',strjoin(fastZDaqName,','));
                
                galvoDaqName = obj.yGalvo.hAOControl.hDAQ.name;
                
                if ~isempty(beamDaqName)
                    assert(~strcmp(galvoDaqName,beamDaqName), 'Galvo and Beams cannot be configured on the same DAQ board');
                end
                
                if ~isempty(fastZDaqName)
                    assert(~strcmp(galvoDaqName,fastZDaqName),'Galvo and FastZ cannot be configured on the same DAQ board');
                end
                
                if ~isempty(beamDaqName) && ~isempty(fastZDaqName)
                    assert(~strcmp(beamDaqName,fastZDaqName), 'Beams and FastZ cannot be configured on the same DAQ board');
                end

                shutterErrors = cellfun(@(hSh)~isempty(hSh.errorMsg),obj.hShutters);
                assert(~any(shutterErrors),'Shutters %s are in error state', strjoin(cellfun(@(hSh)hSh.name,obj.hShutters(shutterErrors),'UniformOutput',false)));
                
                obj.parkScanner();
                
                obj.errorMsg = '';
            catch ME
                obj.errorMsg = ME.message;
            end
            
            function tf = verifyAllowedAdpaterModule(hAdapaterModule)
                if ~isempty(strfind(hAdapaterModule.productType, '5771')) && ~scanimage.SI.PREMIUM
                    tf = false;
                else
                    tf = true;
                end
            end
        end
        
        function deinit(obj)
            obj.safeAbortDataScope();
            most.idioms.safeDeleteObj(obj.hDataScope);
        end
        
        function reinit(obj)
            try
                obj.validateConfiguration();
                obj.assertNoError();
                
                obj.simulated = obj.checkSimulated();
                
                if obj.simulated
                    obj.useResonantTimebase = false;
                end
                
                %Construct sub-componentss
                obj.hAcq.reinit();
                obj.hAcq.frameAcquiredFcn = @(src,evnt)obj.frameAcquiredFcn;
                obj.hCtl.reinit();
                obj.hTrig.reinit();
                
                obj.numInstances = 1; % This has to happen _before_ any properties are set
                
                if obj.hasXGalvo
                    obj.scannerType = 'RGG';
                else
                    obj.scannerType = 'RG';
                end
                
                % initialize scanner frequency from mdfData
                obj.scannerFrequency = obj.hResonantScanner.nominalFrequency_Hz;

                obj.isPolygonalScanner = isa(obj.hResonantScanner,'dabs.resources.devices.PolygonalScanner');
                
                if obj.isPolygonalScanner
                    obj.uniformSampling = true;
                    obj.bidirectional = false;
                    obj.fillFractionSpatial = obj.fillFractionTemporal;
                end
                
                %Initialize sub-components
                
                obj.channelsFilter = 'Bessel';      % channels filter type; one of {'None','Elliptic','Bessel'}
                
                %Initialize Scan2D props (not initialized by superclass)
                obj.channelsInputRanges = repmat(obj.channelsAvailableInputRanges(1),1,obj.channelsAvailable);
                obj.channelOffsets = zeros(1, obj.channelsAvailable);
                obj.channelsSubtractOffsets = true(1, obj.channelsAvailable);
                
                if ~isempty(obj.mdfData.photonCountingDisableAveraging)
                    obj.maskDisableAveraging = obj.mdfData.photonCountingDisableAveraging;
                end
                
                obj.hDataScope = scanimage.components.scan2d.resscan.FpgaDataScope(obj,obj.hDAQAcq);
            catch ME
                most.ErrorHandler.rethrow(ME);
            end
        end 
    end
    
    methods
        function loadMdf(obj)
            success = true;
            
            success = success & obj.safeSetPropFromMdf('hDAQAcq', 'rioDeviceID');
            success = success & obj.safeSetPropFromMdf('hDAQAux', 'digitalIODeviceName');
            success = success & obj.safeSetPropFromMdf('hResonantScanner', 'resonantScanner');
            success = success & obj.safeSetPropFromMdf('xGalvo', 'xGalvo');
            success = success & obj.safeSetPropFromMdf('yGalvo', 'yGalvo');
            success = success & obj.safeSetPropFromMdf('hFastZs', 'fastZs');
            success = success & obj.safeSetPropFromMdf('hShutters', 'shutters');
            success = success & obj.safeSetPropFromMdf('hBeams', 'beams');
            success = success & obj.safeSetPropFromMdf('channelsInvert', 'channelsInvert');
            success = success & obj.safeSetPropFromMdf('extendedRggFov', 'extendedRggFov');
            success = success & obj.safeSetPropFromMdf('keepResonantScannerOn', 'keepResonantScannerOn');
            success = success & obj.safeSetPropFromMdf('laserTriggerPort', 'LaserTriggerPort');
            success = success & obj.safeSetPropFromMdf('auxTriggersEnable', 'auxTriggersEnable');
            success = success & obj.safeSetPropFromMdf('reverseLineRead', 'reverseLineRead');
            success = success & obj.safeSetPropFromMdf('externalSampleClock', 'externalSampleClock');
            success = success & obj.safeSetPropFromMdf('externalSampleClockRate', 'externalSampleClockRate');
            
            success = success & obj.loadCalibration();
            
            if ~success
                obj.errorMsg = 'Error loading config';
            end
        end
        
        function saveMdf(obj)
            obj.safeWriteVarToHeading('rioDeviceID', obj.hDAQAcq);
            obj.safeWriteVarToHeading('digitalIODeviceName', obj.hDAQAux);
            obj.safeWriteVarToHeading('resonantScanner', obj.hResonantScanner);
            obj.safeWriteVarToHeading('xGalvo', obj.xGalvo);
            obj.safeWriteVarToHeading('yGalvo', obj.yGalvo);
            obj.safeWriteVarToHeading('fastZs', resourceCellToNames(obj.hFastZs,false));
            obj.safeWriteVarToHeading('beams', resourceCellToNames(obj.hBeams,false));
            obj.safeWriteVarToHeading('shutters', resourceCellToNames(obj.hShutters,false));
            obj.safeWriteVarToHeading('channelsInvert', obj.channelsInvert);
            obj.safeWriteVarToHeading('extendedRggFov', obj.extendedRggFov);
            obj.safeWriteVarToHeading('keepResonantScannerOn', obj.keepResonantScannerOn);
            obj.safeWriteVarToHeading('LaserTriggerPort', obj.laserTriggerPort);
            obj.safeWriteVarToHeading('auxTriggersEnable', obj.auxTriggersEnable);
            obj.safeWriteVarToHeading('reverseLineRead', obj.reverseLineRead);
            obj.safeWriteVarToHeading('externalSampleClock', obj.externalSampleClock);
            obj.safeWriteVarToHeading('externalSampleClockRate', obj.externalSampleClockRate);
            
            obj.saveCalibration();
            obj.saveLaserTriggerSettings();
            
            %%% Nested functions
            function names = resourceCellToNames(hResources,includeInvalid)
               names = {};
               for idx = 1:numel(hResources)
                   if most.idioms.isValidObj(hResources{idx})
                       names{end+1} = hResources{idx}.name;
                   elseif includeInvalid
                       names{end+1} = '';
                   end
               end
            end
        end
        
        function saveLaserTriggerSettings(obj)
            obj.safeWriteVarToHeading('LaserTriggerSampleMaskEnable',obj.laserTriggerSampleMaskEnable);
            obj.safeWriteVarToHeading('LaserTriggerSampleWindow',obj.laserTriggerSampleWindow);
            obj.safeWriteVarToHeading('LaserTriggerFilterTicks',obj.laserTriggerDebounceTicks);
        end
        
        function success = loadCalibration(obj)
            success = true;
            success = success & obj.safeSetPropFromMdf('scannerToRefTransform', 'scannerToRefTransform');
        end
        
        function saveCalibration(obj)
            obj.safeWriteVarToHeading('scannerToRefTransform', obj.scannerToRefTransform);
        end 
    end
    
    %% PROP ACCESS METHODS
    methods
        function set.hDAQAcq(obj,val)
            val = obj.hResourceStore.filterByName(val);
            
            if ~isequal(val,obj.hDAQAcq)
                assert(~obj.mdlInitialized,'Cannot change DAQ while ScanImage is running');
                
                if most.idioms.isValidObj(val)
                    validateattributes(val,{'dabs.resources.daqs.NIRIO'},{'scalar'});
                    assert(most.idioms.isValidObj(val.hAdapterModule),'FlexRIO without adapter modules not supported');
                end
                
                obj.deinit();
                obj.hDAQAcq.unregisterUser(obj);
                obj.hDAQAcq = val;
                obj.hDAQAcq.registerUser(obj,'Acquisition DAQ');
            end
        end
        
        function val = get.hDAQAcq(obj)
            val = obj.hDAQAcq;
            if ~most.idioms.isValidObj(val)
                val = dabs.resources.Resource.empty();
            end
        end
        
        function set.hDAQAux(obj,val)
            val = obj.hResourceStore.filterByName(val);
            
            if ~isequal(val,obj.hDAQAux)
                assert(~obj.mdlInitialized,'Cannot change DAQ while ScanImage is running');
                
                if most.idioms.isValidObj(val)
                    validateattributes(val,{'dabs.resources.daqs.NIDAQ','dabs.resources.daqs.NIRIO'},{'scalar'});
                end
                
                obj.deinit();
                obj.hDAQAux.unregisterUser(obj);
                obj.hDAQAux = val;
                obj.hDAQAux.registerUser(obj,'Aux DAQ');
            end
        end
        
        function val = get.hDAQAux(obj)
            val = obj.hDAQAux;
            if ~most.idioms.isValidObj(val)
                val = dabs.resources.Resource.empty();
            end
        end
        
        function set.xGalvo(obj,val)
            val = obj.hResourceStore.filterByName(val);
            
            if ~isequal(val,obj.xGalvo)
                assert(~obj.mdlInitialized,'Cannot change x galvo while ScanImage is running');
                
                if most.idioms.isValidObj(val)
                    validateattributes(val,{'dabs.resources.devices.GalvoAnalog'},{'scalar'});
                end
                
                obj.deinit();
                obj.xGalvo.unregisterUser(obj);
                obj.xGalvo = val;
                obj.xGalvo.registerUser(obj,'X Galvo');
            end
        end
        
        function val = get.xGalvo(obj)
            val = obj.xGalvo;
            if ~most.idioms.isValidObj(val)
                val = dabs.resources.Resource.empty();
            end
        end
        
        function set.yGalvo(obj,val)
            val = obj.hResourceStore.filterByName(val);
            
            if ~isequal(val,obj.yGalvo)
                assert(~obj.mdlInitialized,'Cannot change y galvo while ScanImage is running');
                
                if most.idioms.isValidObj(val)
                    validateattributes(val,{'dabs.resources.devices.GalvoAnalog'},{'scalar'});
                end
                
                obj.deinit();
                obj.yGalvo.unregisterUser(obj);
                obj.yGalvo = val;
                obj.yGalvo.registerUser(obj,'Y Galvo');
            end
        end
        
        function val = get.yGalvo(obj)
            val = obj.yGalvo;
            if ~most.idioms.isValidObj(val)
                val = dabs.resources.Resource.empty();
            end
        end
        
        function set.hResonantScanner(obj,val)
            val = obj.hResourceStore.filterByName(val);
            
            if ~isequal(val,obj.hResonantScanner)
                assert(~obj.mdlInitialized,'Cannot change resonant scanner while ScanImage is running');
                
                if most.idioms.isValidObj(val)
                    validateattributes(val,{'dabs.resources.devices.SyncedScanner'},{'scalar'});
                end
                
                obj.deinit();
                obj.hResonantScanner.unregisterUser(obj);
                obj.hResonantScanner = val;
                obj.isPolygonalScanner = isa(val,'dabs.resources.devices.PolygonalScanner');
                obj.hResonantScanner.registerUser(obj,'Resonant Scanner');
            end
        end
        
        function val = get.hResonantScanner(obj)
            val = obj.hResonantScanner;
            if ~most.idioms.isValidObj(val)
                val = dabs.resources.Resource.empty();
            end
        end
        
        function set.hShutters(obj,val)
            validateattributes(val,{'cell'},{});
            [val,validMask] = obj.hResourceStore.filterByName(val);
            val = val(validMask);
            
            for idx = 1:numel(val)
                validateattributes(val{idx},{'dabs.resources.devices.Shutter'},{'scalar'});
            end
            
            obj.hShutters = val;                
        end
        
        function val = get.hShutters(obj)
            validMask = cellfun(@(h)most.idioms.isValidObj(h),obj.hShutters);
            val = obj.hShutters(validMask);
        end
        
        function set.hFastZs(obj,val)
            validateattributes(val,{'cell'},{});
            [val,validMask] = obj.hResourceStore.filterByName(val);
            val = val(validMask);
            
            for idx = 1:numel(val)
                validateattributes(val{idx},{'dabs.resources.devices.FastZAnalog'},{'scalar'});
            end
            
            obj.hFastZs = val;
        end
        
        function val = get.hFastZs(obj)
            validMask = cellfun(@(h)most.idioms.isValidObj(h),obj.hFastZs);
            val = obj.hFastZs(validMask);
        end
        
        function set.hBeams(obj,val)
            validateattributes(val,{'cell'},{});
            [val,validMask] = obj.hResourceStore.filterByName(val);
            val = val(validMask);
            
            for idx = 1:numel(val)
                validateattributes(val{idx},{'dabs.resources.devices.BeamModulator'},{'scalar'});
            end
            
            obj.hBeams = val;
        end
        
        function val = get.hBeams(obj)
            validMask = cellfun(@(h)most.idioms.isValidObj(h),obj.hBeams);
            val = obj.hBeams(validMask);
        end
        
        function val = get.numDigitizerChannels(obj)
            if most.idioms.isValidObj(obj.hDAQAcq) && most.idioms.isValidObj(obj.hDAQAcq.hAdapterModule)
                val = numel(obj.hDAQAcq.hAdapterModule.hDigitizerAIs);
            else
                val = 0;
            end
        end
        
        function set.channelsInvert(obj,val)
            if isempty(val)
                val = false;
            end
            
            validateattributes(val,{'numeric','logical'},{'binary','vector'});
            obj.channelsInvert = val;
        end
        
        function val = get.channelsInvert(obj)
            val = obj.channelsInvert;
            val(end+1:obj.numDigitizerChannels) = false;
            val(obj.numDigitizerChannels+1:end) = [];
        end
        
        function set.extendedRggFov(obj,val)
            validateattributes(val,{'numeric','logical'},{'scalar','binary'});
            obj.extendedRggFov = val;
        end
        
        function set.reverseLineRead(obj,val)
            validateattributes(val,{'numeric','logical'},{'scalar','binary'});
            obj.reverseLineRead = val;
        end
        
        function set.channelOffsets(obj,val)
            if ~isempty(val)
                assert(numel(val) == obj.channelsAvailable, 'Number of elements must match number of physical channels.');
                lclSubtractOffset = cast(obj.channelsSubtractOffsets,obj.channelsDataType);
                for iter = 1:min(numel(val),numel(lclSubtractOffset))
                    fpgaVal(iter) = -val(iter) * lclSubtractOffset(iter);
                end
                obj.channelOffsets = val;
                obj.hAcq.hFpga.AcqParamLiveChannelOffsets = fpgaVal;
            end
        end
        
        function set.pixelBinFactor(obj,val)
            if obj.uniformSampling
                val = obj.validatePropArg('pixelBinFactor',val);
                if obj.componentUpdateProperty('pixelBinFactor',val)
                    obj.pixelBinFactor = val;
                    obj.fillFractionTemporal = obj.fillFractionTemporal; %trigger update
                end
            else
                obj.errorPropertyUnSupported('pixelBinFactor',val);
            end
        end
        
        function set.sampleRate(obj,val)
            obj.errorPropertyUnSupported('sampleRate',val,'set');
            
            %side effects
            obj.linePhase = obj.linePhase;
            obj.fillFractionTemporal = obj.fillFractionTemporal; %trigger update
        end
        
        function val = get.sampleRate(obj)
            val = obj.hAcq.sampleRateAcq;
        end
        
        function set.externalSampleClock(obj,val)
            validateattributes(val,{'numeric','logical'},{'scalar','binary'});
            obj.externalSampleClock = logical(val);
        end
        
        function set.externalSampleClockRate(obj,val)
            validateattributes(val,{'numeric'},{'scalar','positive','nonnan','finite'});
            obj.externalSampleClockRate = val;            
        end
        
        function val = get.resonantScannerLastWrittenValue(obj)
           val = obj.hCtl.resonantScannerLastWrittenValue; 
        end
        
        function set.linePhaseStep(obj,val)
            obj.mdlDummySetProp(val,'linePhaseStep');
        end
        
        function val = get.linePhaseStep(obj)
            val = 1 / obj.hAcq.stateMachineLoopRate;
        end
        
        function val = get.digitalIODeviceType(obj)
            val = obj.hTrig.digitalIODeviceType;
        end
        
        function val = get.digitalIODaqName(obj)
            val = obj.hTrig.digitalIODaqName;
        end
        %         function val = get.trigNextInTermAllowed(obj)
        %             val = obj.allowedTriggerInputTerminals;
        %         end
        %
        %         function val = get.trigStopInTermAllowed(obj)
        %             val = obj.allowedTriggerInputTerminals;
        %         end
        
        function set.linePhaseMode(obj, v)
            assert(ismember(v, {'Next Lower' 'Next Higher' 'Nearest Neighbor' 'Interpolate'}), 'Invalid choice for linePhaseMode. Must be one of {''Next Lower'' ''Next Higher'' ''Nearest Neighbor'' ''Interpolate''}.');
            obj.linePhaseMode = v;
        end
        
        function set.enableContinuousFreqMeasurement(obj, v)
            if obj.componentUpdateProperty('enableContinuousFreqMeasurement',v)
                obj.enableContinuousFreqMeasurement = v;
                
                if v && strcmp(obj.hAcq.hTimerContinuousFreqMeasurement.Running,'off')
                    start(obj.hAcq.hTimerContinuousFreqMeasurement);
                else
                    stop(obj.hAcq.hTimerContinuousFreqMeasurement);
                end
            end
        end
        
        function set.keepResonantScannerOn(obj, v)
            validateattributes(v,{'numeric','logical'},{'scalar','binary'});
            obj.keepResonantScannerOn = logical(v);
            
            if obj.mdlInitialized && obj.numInstances > 0
                if ~obj.active
                    if obj.isPolygonalScanner
                        hPolyScnr = obj.hResonantScanner;
                        hPolyScnr.setLineRate_Hz(hPolyScnr.nominalFrequency_Hz);
                    else
                        deg = obj.hCtl.nextResonantFov() * obj.keepResonantScannerOn;
                        obj.hResonantScanner.setAmplitude(deg);
                    end
                    obj.safeWriteVarToHeading('keepResonantScannerOn', obj.keepResonantScannerOn);
                end
            end
        end
        
        function val = get.mask(obj)
            obj.hAcq.computeMask();
            val = obj.hAcq.mask;
        end
        
        function v = get.extendedRggFov(obj)
            v = obj.hasXGalvo && obj.extendedRggFov;
        end
        
        function v = get.hasXGalvo(obj)
            v = most.idioms.isValidObj(obj.xGalvo);
        end
        
        function sz = get.defaultRoiSize(obj)
            scales = abs(obj.scannerToRefTransform([1 5]));
            if obj.extendedRggFov
                sz = min([obj.hResonantScanner.angularRange_deg diff(obj.yGalvo.travelRange)] .* scales);
            else
                sz = min(obj.angularRange .* scales);
            end
        end
        
        function rg = get.angularRange(obj)
            if obj.extendedRggFov
                x = diff(obj.xGalvo.travelRange) + obj.hResonantScanner.angularRange_deg;
            else
                x = obj.hResonantScanner.angularRange_deg;
            end
            y = diff(obj.yGalvo.travelRange);
            rg = [x y];
        end
        
        function set.uniformSampling(obj,v)
            if obj.componentUpdateProperty('uniformSampling',v)
                if v ~= obj.uniformSampling
                    if obj.isPolygonalScanner && ~v
                        obj.uniformSampling = true;
                        assert(v,'Polygonal Scanning only supports uniform sampling');
                    end
                    
                    obj.uniformSampling = v;
                    obj.scanPixelTimeMean = nan;
                end
            end
        end
        
        function v = get.uniformSampling(obj)
            if obj.isPolygonalScanner
                v = true;
            else
                v = obj.uniformSampling;
            end
        end
        
        function set.maskDisableAveraging(obj,v)
            if obj.componentUpdateProperty('maskDisableAveraging',v)
                validateattributes(v,{'numeric','logical'},{'binary'});
                assert(length(v) <= obj.channelsAvailable);
                v(end+1:obj.channelsAvailable) = v(end);
                obj.maskDisableAveraging = v;
                
                if ~isempty(obj.mdfData.photonCountingDisableAveraging)
                    mdf = most.MachineDataFile.getInstance();
                    if mdf.isLoaded
                        obj.writeVarToHeading(obj.custMdfHeading,'photonCountingDisableAveraging',v);
                        obj.mdfData.photonCountingDisableAveraging = v;
                    end
                end
            end
        end
        
        function v = get.coercedFlybackTime(obj)
            numScannerPeriods = ceil(obj.flybackTimePerFrame * obj.scannerFrequency);
            v = numScannerPeriods / obj.scannerFrequency;
        end
        
        function v = get.coercedFlytoTime(obj)
            numScannerPeriods = ceil(obj.flytoTimePerScanfield * obj.scannerFrequency);
            v = numScannerPeriods / obj.scannerFrequency;
        end
        
        function set.laserTriggerPort(obj,v)
            %NOTE: laser triggering is only available in premium version
            allowedValues = {'','DIO0.0','DIO0.1','DIO0.2','DIO0.3'};
            assert(any(strcmp(v,allowedValues)),'Invalid value for laser trigger: %s',v);
            
            obj.laserTriggerPort = v;
            
            if obj.mdlInitialized && obj.hSI.hScan2D==obj
                obj.hTrig.laserTriggerIn = v;
            end
        end
        
        function v = get.laserTriggerSampleMaskEnable(obj)
            v = obj.mdfData.LaserTriggerSampleMaskEnable;
        end
        
        function set.laserTriggerSampleMaskEnable(obj,v)
            obj.mdfData.LaserTriggerSampleMaskEnable = v;
            obj.hAcq.hFpga.ResScanFilterSamples = v;
        end
        
        function v = get.laserTriggerSampleWindow(obj)
            v = obj.mdfData.LaserTriggerSampleWindow;
        end
        
        function set.laserTriggerSampleWindow(obj,v)
            obj.mdfData.LaserTriggerSampleWindow = v;
            obj.hAcq.hFpga.LaserTriggerDelay = v(1);
            obj.hAcq.hFpga.LaserSampleWindowSize = v(2);
        end
        
        function v = get.laserTriggerDebounceTicks(obj)
            v = obj.mdfData.LaserTriggerFilterTicks;
        end
        
        function set.laserTriggerDebounceTicks(obj,v)
            obj.mdfData.LaserTriggerFilterTicks = v;
            obj.hAcq.hFpga.LaserTriggerFilterTicks = v;
        end
        
        function set.auxTriggersEnable(obj,v)
            %NOTE: aux triggering is only available in premium version
            validateattributes(v,{'numeric','logical'},{'scalar','binary'});
            obj.auxTriggersEnable = logical(v);
        end
    end
      
    %%% Abstract method implementations (scanimage.components.Scan2D)
    % AccessXXX prop API for Scan2D
    methods (Access = protected, Hidden)
        function val = accessScannersetPostGet(obj,~)
            % Determine flyback time per frame
            if obj.hSI.hStackManager.isFastZ && strcmp(obj.hSI.hFastZ.waveformType, 'step')
                numScannerPeriods = ceil(obj.hSI.hFastZ.flybackTime * obj.scannerFrequency);
                flybackTime = max(obj.coercedFlybackTime, numScannerPeriods / obj.scannerFrequency);
            else
                flybackTime = obj.coercedFlybackTime;
            end
            
            % Define Resonant Scanning Hardware.
            
            scannerPeriod = 1/obj.scannerFrequency;
            r = scanimage.mroi.scanners.Resonant(...
                    obj.hResonantScanner,...
                    scannerPeriod,...
                    obj.bidirectional,...
                    obj.fillFractionSpatial);
            
            % Define Y-Galvo Scanning Hardware.
            assert(most.idioms.isValidObj(obj.yGalvo),'yGalvo is not defined in machine data file');
            yGalvoScanner = scanimage.mroi.scanners.Galvo(obj.yGalvo);
            yGalvoScanner.flytoTimeSeconds = obj.coercedFlytoTime;
            yGalvoScanner.flybackTimeSeconds = flybackTime;
            yGalvoScanner.sampleRateHz = obj.hCtl.rateAOSampClk;
            yGalvoScanner.useScannerTimebase = obj.useResonantTimebase;
            
            % Define X-Galvo Scanning Hardware.
            xGalvoScanner = [];
            if most.idioms.isValidObj(obj.xGalvo)
                xGalvoScanner = scanimage.mroi.scanners.Galvo(obj.xGalvo);
                xGalvoScanner.flytoTimeSeconds = obj.coercedFlytoTime;
                xGalvoScanner.flybackTimeSeconds = flybackTime;
                xGalvoScanner.sampleRateHz = obj.hCtl.rateAOSampClk;
                xGalvoScanner.useScannerTimebase = obj.useResonantTimebase;
            end
            
            % Define beam hardware
            [fastBeams, slowBeams] = obj.hSI.hBeams.wrapBeams(obj.hBeams);
            for idx = 1:numel(fastBeams)
                fastBeams(idx).sampleRateHz = obj.hSI.hBeams.maxSampleRate;
                fastBeams(idx).linePhase = obj.linePhase;
                fastBeams(idx).beamClockDelay = obj.beamClockDelay;
                fastBeams(idx).beamClockExtend = obj.beamClockExtend;
                fastBeams(idx).includeFlybackLines = false;
                
                if obj.hSI.hRoiManager.isLineScan
                    fastBeams(idx).powerBoxes = [];
                end
            end
            
            % Define fastz hardware
            fastZScanners = obj.hSI.hFastZ.wrapFastZs(obj.hFastZs);
            for idx = 1:numel(fastZScanners)
                fastZScanners(idx).useScannerTimebase = obj.useResonantTimebase && fastZScanners(idx).hDevice.isPXI;
                fastZScanners(idx).sampleRateHz = 200e3;
            end
            
            % Create resonant galvo galvo scannerset using hardware descriptions above
            val=scanimage.mroi.scannerset.ResonantGalvoGalvo(obj.name,r,xGalvoScanner,yGalvoScanner,fastBeams,slowBeams,fastZScanners,obj.fillFractionSpatial);
            val.extendedRggFov = obj.extendedRggFov;
            val.modifiedTimebaseSecsPerSec = obj.scannerFrequency * obj.resonantTimebaseTicksPerPeriod / obj.resonantTimebaseNominalRate;
            val.hCSSampleRelative = obj.hSI.hMotors.hCSSampleRelative;
            val.hCSReference = obj.hSI.hCoordinateSystems.hCSReference;
            val.beamRouters = obj.hSI.hBeams.hBeamRouters;
            val.objectiveResolution = obj.hSI.objectiveResolution;
        end
        
        function accessBidirectionalPostSet(obj,v)
            if obj.isPolygonalScanner && v
                obj.bidirectional = false;
                error('Bidirectional scanning is unsupported when using a polygonal Scanner');
            end
%             %Side-effects                        
%             obj.linesPerFrame = obj.linesPerFrame;                  % make sure that linesPerFrame is even when bidirectional scanning
%             obj.flybackLinesPerFrame = obj.flybackLinesPerFrame;    % make sure that flybackLinesPerFrame is even when bidirectional scanning
%                                     
%             obj.hAcq.computeMask();
%             obj.hAcq.flagResizeAcquisition = true;
        end
        
        function val = accessStripingEnablePreSet(~,val)
            % unsupported in ResScan
            val = false;
        end
        
        function val = accessLinePhasePreSet(obj,val)
            
            currentAmplitude_deg = obj.hResonantScanner.currentAmplitude_deg;
            
            if isempty(currentAmplitude_deg) || currentAmplitude_deg == 0
                currentAmplitude_deg = obj.hCtl.nextResonantFov;
            end
            
            if ~obj.robotMode && ~obj.flagZoomChanged && obj.mdlInitialized
                % line phase is measured in seconds
                samples = round((val) * obj.hAcq.stateMachineLoopRate);
                val = samples / obj.hAcq.stateMachineLoopRate ; % round to closest possible value
                
                if currentAmplitude_deg>0 && ~obj.isPolygonalScanner
                    obj.hResonantScanner.addToAmplitudeToLinePhaseMap(currentAmplitude_deg,val);
                end
            end
            
            obj.flagZoomChanged = false;
        end
        
        function accessLinePhasePostSet(obj)            
            obj.hAcq.fpgaUpdateLiveAcquisitionParameters('linePhaseSamples');
        end
        
        function val = accessLinePhasePostGet(obj,val)
            % no-op
        end
        
        function val = accessChannelsFilterPostGet(~,val)
            % no-op
        end
        
        function val = accessChannelsFilterPreSet(obj,val)
            val = obj.hAcq.hFpga.setChannelFilter(val);
        end
        
        function accessBeamClockDelayPostSet(~,~)            
        end
        
        function accessBeamClockExtendPostSet(~,~)
        end
        
        function accessChannelsAcquirePostSet(obj,~)
            obj.hAcq.flagResizeAcquisition = true;
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function val = accessChannelsInputRangesPreSet(obj,val)
            val = obj.hAcq.hFpga.setInputRanges(val);
        end
        
        function val = accessChannelsInputRangesPostGet(~,val)
            %No-op
        end
        
        function val = accessChannelsAvailablePostGet(obj,~)
            val = obj.hAcq.adapterModuleChannelCount;
        end
        
        function val = accessChannelsAvailableInputRangesPostGet(obj,~)
            upperLimits = obj.hAcq.ADAPTER_MODULE_AVAIL_INPUT_RANGES(obj.hAcq.flexRioAdapterModuleNameWithAppendix);
            upperLimits = sort(upperLimits,'descend');
            numRanges = length(upperLimits);
            val = cell(1,numRanges);
            for i = 1:numRanges
                val{i} = [-upperLimits(i) upperLimits(i)];
            end
        end
                     
        function val = accessFillFractionSpatialPreSet(obj,val)
            try
                if ~obj.uniformSampling
                    scanimage.util.computeresscanmask(obj.scannerFrequency, obj.sampleRate, val, obj.hAcq.pixelsPerLine);
                elseif obj.isPolygonalScanner
                    if obj.hSI.hRoiManager.pixelsPerLine ~= floor(obj.sampleRate/obj.scannerFrequency*val/obj.pixelBinFactor)
                        obj.hSI.hRoiManager.pixelsPerLine = floor(obj.sampleRate/obj.scannerFrequency*val/obj.pixelBinFactor);
                    end
                end
            catch
                most.idioms.warn('Attempted to set fill fraction too low.', val);
                val = obj.fillFractionSpatial;
            end
        end
                     
        function accessFillFractionSpatialPostSet(obj,~)
            obj.hAcq.computeMask();
        end
        
        function val = accessSettleTimeFractionPostSet(obj,val)
            obj.errorPropertyUnSupported('settleTimeFraction',val);
        end
        
        function val = accessFlytoTimePerScanfieldPostGet(obj,val)
            val = max(val, 1/obj.scannerFrequency);
        end
        
        function val = accessFlybackTimePerFramePostGet(obj,val)
            val = max(val, 1/obj.scannerFrequency);
        end
        
        function accessLogAverageFactorPostSet(obj,~)
            obj.hAcq.flagResizeAcquisition = true;
        end
        
        function accessLogFileCounterPostSet(obj,~)
            obj.hAcq.flagResizeAcquisition = true;
        end
        
        function accessLogFilePathPostSet(obj,~)
            obj.hAcq.flagResizeAcquisition = true;
        end
        
        function accessLogFileStemPostSet(obj,~)
            obj.hAcq.flagResizeAcquisition = true;
        end
        
        function accessLogFramesPerFilePostSet(obj,~)
            obj.hAcq.flagResizeAcquisition = true;
        end

        function accessLogFramesPerFileLockPostSet(obj,~)
            obj.hAcq.flagResizeAcquisition = true;
        end
        
        function val = accessLogNumSlicesPreSet(obj,val)
            obj.hAcq.loggingNumSlices = val;
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function val = accessTrigFrameClkOutInternalTermPostGet(obj,~)
            val = obj.hTrig.readInternalTerminalName('frameClockOut');
        end
        
        function val = accessTrigBeamClkOutInternalTermPostGet(obj,~)
            val = obj.hTrig.readInternalTerminalName('beamModifiedLineClockOut');
        end
        
        function val = accessTrigAcqOutInternalTermPostGet(obj,~)
            val = obj.hTrig.readInternalTerminalName('acqTriggerOut');
        end
        
        function val = accessTrigReferenceClkOutInternalTermPostGet(~,~)
            val = 'PXI_CLK10';
        end
        
        function val = accessTrigReferenceClkOutInternalRatePostGet(~,~)
            val = 10e6;
        end
        
        function val = accessTrigReferenceClkInInternalTermPostGet(~,~)
            val = 'PXI_CLK10';
        end
        function val = accessTrigReferenceClkInInternalRatePostGet(~,~)
            val = 10e6;
        end  
        function val = accessTrigAcqInTermAllowedPostGet(obj,~) 
            val = obj.hTrig.externalTrigTerminalOptions;
        end
        
        function val = accessTrigNextInTermAllowedPostGet(obj,~)
            val = obj.hTrig.externalTrigTerminalOptions;
        end
        
        function val = accessTrigStopInTermAllowedPostGet(obj,~)
            val = obj.hTrig.externalTrigTerminalOptions;
        end
             
        function val = accessTrigAcqEdgePreSet(obj,val)    
            obj.hTrig.acqTriggerOnFallingEdge = strcmp(val,'falling');
        end
        
        function accessTrigAcqEdgePostSet(~,~)
            % Nothing to do here
        end
        
        function val = accessTrigAcqInTermPreSet(obj,val)                        
            if isempty(val)
                obj.trigAcqTypeExternal = false;
            end
            obj.hTrig.acqTriggerIn = val;
        end
        
        function accessTrigAcqInTermPostSet(~,~)
            % Nothing to do here
        end
        
        function val = accessTrigAcqInTermPostGet(obj,~)
            val = obj.hTrig.acqTriggerIn;
        end
        
        function val = accessTrigAcqTypeExternalPreSet(obj,val)
            val = logical(val); % convert 'binaryflex' to 'logcial'
        end
        
        function accessTrigAcqTypeExternalPostSet(~,~)
             %No-op        
        end
        
        function val = accessTrigNextEdgePreSet(obj,val)
            obj.hTrig.nextFileMarkerOnFallingEdge = strcmp(val,'falling');
        end
        
        function val = accessTrigNextInTermPreSet(obj,val)
            obj.hTrig.nextFileMarkerIn = val;
        end
        
        function val = accessTrigNextStopEnablePreSet(~,~)
            val = true; % the FPGA can handle Next and Stop triggering at all times. no need to deactivate it               
        end
        
        function val = accessTrigStopEdgePreSet(obj,val)
            obj.hTrig.acqStopTriggerOnFallingEdge = strcmp(val,'falling');
        end
        
        function val = accessFunctionTrigStopInTermPreSet(obj,val)
            %termName = obj.allowedTriggerInputTerminalsMap(val); % qualify terminal name (e.g. DIO0.1 -> /FPGA/DIO0.1)
            obj.hTrig.acqStopTriggerIn = val;
        end
        
        function val = accessMaxSampleRatePostGet(obj,~)
            val = obj.sampleRate;
        end
        
        function accessScannerFrequencyPostSet(obj,~)
            obj.nomResPeriodTicks = floor(obj.hAcq.stateMachineLoopRate / obj.scannerFrequency);
            obj.resonantTimebaseTicksPerPeriod = floor(obj.resonantTimebaseNominalRate / obj.scannerFrequency);
            obj.scannerPeriodRTB = obj.resonantTimebaseTicksPerPeriod / obj.resonantTimebaseNominalRate;
        end
        
        function val = accessScannerFrequencyPostGet(~,val)
            % No op
        end

        function val = accessScanPixelTimeMeanPostGet(obj,~)
            if ~obj.active
                % if acq is active, let this occur automatically
                ppl = obj.getPixPerLine();
                if isempty(ppl) || ppl < 4
                    val = nan;
                    return;
                end
                obj.hAcq.pixelsPerLine = ppl;
                obj.hAcq.computeMask();
            end
            val = (sum(obj.hAcq.mask(1:obj.hAcq.pixelsPerLine)) / obj.sampleRate) / obj.hAcq.pixelsPerLine;
        end
        
        function val = accessScanPixelTimeMaxMinRatioPostGet(obj,~)
            if isnan(obj.scanPixelTimeMean)
                val = nan;
            else
                maxPixelSamples = double(max(obj.hAcq.mask(1:obj.hAcq.pixelsPerLine)));
                minPixelSamples = double(min(obj.hAcq.mask(1:obj.hAcq.pixelsPerLine)));
                val = maxPixelSamples / minPixelSamples;
            end
        end
        
        function val = accessChannelsAdcResolutionPostGet(obj,~)
            val = obj.hAcq.ADAPTER_MODULE_ADC_BIT_DEPTH(obj.hAcq.flexRioAdapterModuleNameWithAppendix);
        end
        
        function val = accessChannelsDataTypePostGet(~,~)
            val = 'int16';
        end
        
        % Component overload function
        function val = componentGetActiveOverride(obj,~)
            val = obj.hAcq.acqRunning;
        end
        
        function val = accessScannerToRefTransformPreSet(obj,val)
            assert(~scanimage.mroi.util.isTransformRotating(val),'ResScan affine cannot contain rotational component.');
            assert(~scanimage.mroi.util.isTransformShearing(val),'ResScan affine cannot contain shearing component.');
            assert(~scanimage.mroi.util.isTransformPerspective(val),'ResScan affine cannot contain perspective component.');
        end
        
        function accessChannelsSubtractOffsetsPostSet(obj)
            obj.channelOffsets = obj.channelOffsets; % update offsets on FPGA            
        end
    end
    
    %% USER METHODS
    
    %%% Abstract methods realizations (scanimage.interfaces.Scan2D)
    methods
        % methods to issue software triggers
        % these methods should only be effective if specified trigger type
        % is 'software'
        function trigIssueSoftwareAcq(obj)
            % trigIssueSoftwareAcq issues a software acquisition start trigger
            %   if ReScan is started, this will start an acquisition
            %   
            %   obj.trigIssueSoftwareAcq()  returns nothing
            
            if obj.componentExecuteFunction('trigIssueSoftwareAcq')
                obj.hAcq.generateSoftwareAcqTrigger();
            end
        end
        
        function trigIssueSoftwareNext(obj)
            % trigIssueSoftwareNext issues a software acquisition next trigger
            %   if ReScan is in an active acquisition, this will roll over the current acquisition
            %   
            %   obj.trigIssueSoftwareNext()  returns nothing
            
            if obj.componentExecuteFunction('trigIssueSoftwareNext')
                obj.hAcq.generateSoftwareNextFileMarkerTrigger();
            end
        end
        
        function trigIssueSoftwareStop(obj)
	        % trigIssueSoftwareStop issues a software acquisition stop trigger
            %   if ReScan is in an active acquisition, this stop the current acquisition
            %   
            %   obj.trigIssueSoftwareStop()  returns nothing
            
            if obj.componentExecuteFunction('trigIssueSoftwareStop')
                obj.hAcq.generateSoftwareAcqStopTrigger();
            end
        end
        
        function pointScanner(obj,fastDeg,slowDeg)
            % pointScanner moves the scanner to the defined angles (in degrees)
            %
            %   obj.pointScanner(fastDeg,slowDeg)   activates the resonant scanner with amplitude 'fastDeg' and points the galvo scanner to position 'slowDeg'
            %           slowDeg can be scalar (y-galvo only) or a 1x2 array [xGalvoDegree, yGalvoDegree]
            
            % points the XY scanner to a position (units: degree)
            if obj.componentExecuteFunction('pointScanner',fastDeg,slowDeg)
                if obj.isPolygonalScanner
                    most.idioms.warn('Polygonal scanners cannot point.');
                else
                    obj.hResonantScanner.setAmplitude(fastDeg);
                end
                
                if isempty(obj.xGalvo)
                    obj.yGalvo.pointPosition(slowDeg);
                else
                    validateattributes(slowDeg,{'numeric'},{'numel',2});
                    obj.xGalvo.pointPosition(slowDeg(1));
                    obj.yGalvo.pointPosition(slowDeg(2));
                end
            end
        end
        
        function centerScanner(obj)
            % centerScanner deactivates the resonant scanner and centers the x and y galvos
            % 
            %   obj.centerScanner()   returns nothing
            
            if obj.isPolygonalScanner
               most.idioms.warn('Polygonal Scanner cannot settle at the center of the FOV');
            end
            
            if obj.componentExecuteFunction('centerScanner')
                obj.hResonantScanner.park();
                obj.hCtl.centerGalvo();
            end
        end
        
        function parkScanner(obj)
            % parkScanner parks the x and y galvo scanner,
            %         deactivates resonant scanner if obj.keepResonantScannerOn == false
            %
            %   obj.parkScanner()  returns nothing
            
            if obj.componentExecuteFunction('parkScanner')
                obj.hCtl.parkGalvo();
                if obj.mdlInitialized
                    if ~obj.keepResonantScannerOn
                        obj.hResonantScanner.park();
                    end
                end
            end
        end
        
        function updateLiveValues(obj,regenAO,~)
            % updateLiveValues updates the scanner output waveforms after
            %       scan parameters have changed
            %
            %   obj.updateLiveValues()          regenerates the output waveforms and updates the output buffer
            %   obj.updateLiveValues(regenAO)   if regenAO == true regenerates the output waveforms, then updates the output buffer
            
            if nargin < 2 || isempty(regenAO)
                regenAO = true;
            end
            
            % waveforms parameter currently ignored. all waveforms updated
            
            obj.hCtl.updateLiveValues(regenAO);
            
            if obj.active && strcmpi(obj.hSI.acqState,'focus')
                obj.hAcq.bufferAcqParams(true);
            end
        end
        
        function updateSliceAO(obj)
            % updateSliceAO updates the scan paramters during a slow-z
            %    stack and refreshes the output waveforms
            %
            %  obj.updateSliceAO()
            
            obj.hAcq.bufferAcqParams(false);
            obj.hCtl.updateLiveValues(false,true);
        end
    end
    
    %%% Resonant scanning specific methods
    methods
        function calibrateGalvos(obj)
            hWb = waitbar(0,'Calibrating Scanner','CreateCancelBtn',@(src,evt)delete(ancestor(src,'figure')));
            try
                obj.scannerset.calibrateScanner('G');
                obj.galvoCalibration = []; % dummy set to store calibration
            catch ME
                hWb.delete();
                rethrow(ME);
            end
            hWb.delete();
        end
        
        function resFreq = measureScannerFrequency(obj)
            % measureScannerFrequency activates the resonant scanner with
            %   the currently selected amplitude and measures the resonant
            %   frequency
            %
            %   resFreq = obj.measureScannerFrequency()   returns the measured resonant frequency
            
            if obj.componentExecuteFunction('measureScannerFrequency')
                if obj.isPolygonalScanner
                    hPolyScnr = obj.hResonantScanner;
                    amplitudeWasZero = hPolyScnr.currentCommandedLineRate_Hz == 0;
                    if amplitudeWasZero
                        hPolyScnr.setLineRate_Hz(hPolyScnr.nominalFrequency_Hz);
                    end
                else
                    amplitudeWasZero = obj.hResonantScanner.currentAmplitude_deg == 0;
                    if amplitudeWasZero
                        obj.hResonantScanner.setAmplitude(obj.hCtl.nextResonantFov);
                    end
                end
                
                obj.hResonantScanner.waitSettlingTime();
                
                %update parameters
                period = obj.hAcq.stateMachineLoopRate / obj.hResonantScanner.nominalFrequency_Hz;
                obj.hAcq.hFpga.NominalResonantPeriodTicks = round(period);
                obj.hAcq.hFpga.MaxResonantPeriodTicks = floor(period*1.1);
                obj.hAcq.hFpga.MinResonantPeriodTicks = floor(period*0.9);
                
                if obj.isPolygonalScanner
                    frequency = obj.hResonantScanner.currentCommandedLineRate_Hz;
                    fprintf('Measuring scanner frequency at commanded frequency %g Hz ...\n',frequency);
                else
                    amplitude = obj.hResonantScanner.currentAmplitude_deg;
                    fprintf('Measuring scanner frequency at amplitude %.3f deg (peak-peak)...\n',amplitude);
                end
                
                
                resFreq = obj.hAcq.calibrateResonantScannerFreq();
                
                if amplitudeWasZero
                    obj.hResonantScanner.park();
                end
                
                if isnan(resFreq)
                    most.idioms.dispError('Failed to read scanner frequency. Period clock pulses not detected.\nVerify zoom control/period clock wiring and MDF settings.\n');
                else
                    fprintf('Scanner Frequency calibrated: %.2fHz\n',resFreq);
                    if isa(obj.hResonantScanner, 'dabs.resources.devices.ResonantScanner')
                        obj.hResonantScanner.addToAmplitudeToFrequencyMap(amplitude,resFreq);
                    end
                    obj.hResonantScanner.currentFrequency_Hz = resFreq;
                    
                    if ~obj.active
                        obj.scannerFrequency = resFreq;
                        obj.hAcq.computeMask();
                    end
                end
            end
        end
    end
    
    %% INTERNAL METHODS
    
    methods (Hidden)
        function reinitRoutes(obj)
            if obj.mdlInitialized
                obj.hTrig.reinitRoutes();
            end
        end
        
        function deinitRoutes(obj)
            if obj.mdlInitialized
                refClkTerm = obj.hTrig.referenceClockOut;
                obj.hTrig.deinitRoutes();
                obj.hTrig.referenceClockOut = refClkTerm;
            end
        end
        
        function frameAcquiredFcn(obj,src,evnt) %#ok<INUSD>
            if obj.active
                if obj.enableBenchmark
                    t = tic();
                end
                
                obj.stripeAcquiredCallback(obj,[]);
                
                if obj.enableBenchmark
                    T = toc(t);
                    obj.lastFrameAcqFcnTime = T;
                    obj.totalFrameAcqFcnTime = obj.totalFrameAcqFcnTime + T;
                    
                    benchmarkData = obj.hAcq.benchmarkData;
                    framesProcessed = obj.hAcq.framesProcessed;
                    
                    fcut = benchmarkData.frameCopierProcessTime/10e3;
                    fcutpf = fcut/benchmarkData.totalAcquiredFrames;
                    fccpucpf = benchmarkData.frameCopierCpuCycles/benchmarkData.totalAcquiredFrames;
                    
                    flut = benchmarkData.frameLoggerProcessTime/10e3;
                    flutpf = flut/benchmarkData.totalAcquiredFrames;
                    flcpucpf = benchmarkData.frameLoggerCpuCycles/benchmarkData.totalAcquiredFrames;
                    
                    faft = obj.totalFrameAcqFcnTime*1000/framesProcessed;
                    drops = benchmarkData.totalAcquiredFrames - framesProcessed;
                    pctDrop = drops * 100 / benchmarkData.totalAcquiredFrames;
                    
                    td = tic;
                    drawnow('nocallbacks');
                    td = toc(td);
                    
                    obj.totalDispUpdates = obj.totalDispUpdates + 1;
                    obj.totalDispUpdateTime = obj.totalDispUpdateTime + td;
                    
                    aveDispTime = obj.totalDispUpdateTime*1000/obj.totalDispUpdates;
                    nskipped = benchmarkData.totalAcquiredFrames-obj.totalDispUpdates;
                    pctSkipped = nskipped * 100 / benchmarkData.totalAcquiredFrames;
                    
                    fps = obj.totalDispUpdates/etime(clock,obj.hSI.acqStartTime);
                    
                    fprintf('Frm copier: %.3fms/fr, %.3f cpu clks/frm, %.3f cpu ms/frm.   Frm logger: %.3fms/fr, %.3f cpu clks/frm, %.3f cpu ms/frm.   MATLAB: %.3fms/fr, %d (%.2f%%) dropped.   Display Update: %.1fms/fr, %d (%.2f%%) skipped, %.2ffps\n',...
                        fcutpf,fccpucpf,fccpucpf*1000/obj.cpuFreq,flutpf,flcpucpf,flcpucpf*1000/obj.cpuFreq,faft,drops,pctDrop,aveDispTime,nskipped,pctSkipped,fps);
                end
            end
        end
        
        function val = estimateScanFreq(obj,amplitude_deg)
            if nargin<2 || isempty(amplitude_deg)
                amplitude_deg = obj.hResonantScanner.currentAmplitude_deg;
            end
            
            if any(obj.hResonantScanner.amplitudeToFrequencyMap(:,1)==amplitude_deg)
                val = obj.hResonantScanner.estimateFrequency(amplitude_deg);
            else
                val = obj.measureScannerFrequency();
            end
            
            if isnan(val)
                val = obj.hResonantScanner.nominalFrequency_Hz;
            end
        end
        
        function val = autoSetLinePhase(obj,amplitude_deg)
            if nargin<2 || isempty(amplitude_deg)
                amplitude_deg = obj.hResonantScanner.currentAmplitude_deg;
            end
            
            val = obj.hResonantScanner.estimateLinePhase(amplitude_deg);
            
            obj.flagZoomChanged = true;
            obj.linePhase = val;
        end
        
        function pixPerLine = getPixPerLine(obj)
            if obj.uniformSampling
                linesPerPeriod = 2^(~obj.isPolygonalScanner);
                pixPerLine = floor(1/linesPerPeriod * obj.sampleRate * obj.fillFractionTemporal / (obj.scannerFrequency * obj.pixelBinFactor));
            else
                pixPerLine = max(arrayfun(@(roi)maxPixelsPerLine(roi),obj.currentRoiGroup.rois));
            end
            
            function pixels = maxPixelsPerLine(roi)
                % Returns the maximum number of pixels per line in the RoiGroup.
                if ~isempty(roi.scanfields)
                    pixels = max(arrayfun(@(scanfield) scanfield.pixelResolution(1),roi.scanfields));
                else
                    pixels = 0;
                end
            end
        end
    end
    
    methods (Hidden)%, Access = private)
        function configureFrameResolution(obj)
            zs=obj.hSI.hStackManager.zs; % generate planes to scan based on motor position etc
            
            roiGroup = obj.currentRoiGroup;
            scannerset = obj.scannerset;
            [scanLines,flybackLines] = arrayfun(@linesPerSlice,zs);
            scanLines = max(scanLines);
            flybackLines = max(flybackLines);
            
            obj.hAcq.pixelsPerLine = obj.getPixPerLine();
            obj.hAcq.linesPerFrame = scanLines;
            obj.hAcq.flybackLinesPerFrame = flybackLines;
            
            obj.hAcq.computeMask();
            obj.hAcq.flagResizeAcquisition = true;
            
            % local functions to operate on roiGroup
            function [scanLines,flybackLines] = linesPerSlice(z)
                lineMask = acqActiveLineMask(z);
                scanLines = numel(lineMask);
                [~,flybackTime] = roiGroup.transitTimes(scannerset,z);
                flybackLines = round(flybackTime * (1/scannerset.scanners{1}.scannerPeriod) * 2^scannerset.scanners{1}.bidirectionalScan);
            end
            
            function lineMask = acqActiveLineMask(z)
                scanFields = roiGroup.scanFieldsAtZ(z);
                if(~isempty(scanFields))
                    % get transitLines
                    scanFieldsWithTransit = [{NaN} scanFields]; %pre- and ap- pend "park" to the scan field sequence to transit % the FPGA clock does not tick for the frame flyback, so we do not include the global flyback here
                    transitPairs = scanimage.mroi.util.chain(scanFieldsWithTransit); %transit pairs
                    transitTimes = cellfun(@(pair) scannerset.transitTime(pair{1},pair{2}),transitPairs);
                    linePeriods  = cellfun(@(sf)scannerset.linePeriod(sf),scanFields);
                    transitLines = round(transitTimes' ./ linePeriods);
                    
                    % get scanFieldLines
                    scanFieldLines = cellfun(@(sf)sf.pixelResolution(2),scanFields);
                    
                    lineMask = [];
                    for i = 1:length(scanFields)
                        lineMask(end+1:end+transitLines(i)) = false;
                        lineMask(end+1:end+scanFieldLines(i)) = true;
                    end
                else
                    lineMask = [];
                end
            end
        end
    end
    
    %%% Abstract methods realizations (scanimage.interfaces.Scan2D)    
    methods (Hidden)
        function arm(obj)
            resAmplitude = obj.hCtl.nextResonantFov;
            
            if resAmplitude > 0.0001
                if obj.isPolygonalScanner
                    hPolyScnr = obj.hResonantScanner;
                    hPolyScnr.setLineRate_Hz(hPolyScnr.nominalFrequency_Hz);
                    newFreq = hPolyScnr.nominalFrequency_Hz;
                else
                    obj.hResonantScanner.setAmplitude(resAmplitude);
                    newFreq = obj.estimateScanFreq();
                end
                                
                % avoid pointless change
                if (abs(newFreq - obj.scannerFrequency) / obj.scannerFrequency) > 0.00001
                    obj.scannerFrequency = newFreq;
                end
                

                if ~obj.isPolygonalScanner
                    obj.autoSetLinePhase(resAmplitude);
                end
            end
        end
        
        function data = acquireSamples(obj,numSamples)
            if obj.componentExecuteFunction('acquireSamples',numSamples)
                data = zeros(numSamples,obj.channelsAvailable,obj.channelsDataType); % preallocate data
                if ~obj.mdfData.photonCountingEnable
                    for i = 1:numSamples
                        data(i,:) = obj.hAcq.rawAdcOutput(1,1:obj.channelsAvailable);
                    end
                end
            end
        end
        
        function signalReadyReceiveData(obj)
            obj.hAcq.signalReadyReceiveData();
        end
                
        function [success,stripeData] = readStripeData(obj)
            % remove the componentExecute protection for performance
            %if obj.componentExecuteFunction('readStripeData')
                [success,stripeData] = obj.hAcq.readStripeData();
                if stripeData.endOfAcquisitionMode
                    obj.abort(); %self abort if acquisition is done
                end
            %end
        end
        
        function newPhase = calibrateLinePhase(obj)
            assert(~obj.isPolygonalScanner,'Automatic line phase calibration is unsupported when using a polygonal scanner');
            
            im = getImage();
            
            if obj.reverseLineRead
               im = flipud(im);
            end
            
            ff_s = obj.fillFractionSpatial;
            ff_t = obj.fillFractionTemporal;
            
            if ~obj.uniformSampling
                im = imToTimeDomain(im,ff_s,ff_t);
            end
            
            im_odd  = im(:,1:2:end);
            im_even = im(:,2:2:end);
            
            % first brute force search to find minimum
            offsets_rad = linspace(-1,1,31)*pi/8;
            ds = arrayfun(@(offset_rad)imDifference(im_odd,im_even,ff_s,ff_t,offset_rad),offsets_rad);
            [d,idx] = min(ds);
            offset_rad = offsets_rad(idx);

            % secondary brute force search to refine minimum
            offsets_rad = offset_rad+linspace(-1,1,51)*diff(offsets_rad(1:2));
            ds = arrayfun(@(offset_rad)imDifference(im_odd,im_even,ff_s,ff_t,offset_rad),offsets_rad);
            [d,idx] = min(ds);
            offset_rad = offsets_rad(idx);
            
            offsetLinePhase = offset_rad /(2*pi)/obj.scannerFrequency;
            obj.linePhase =  obj.linePhase - offsetLinePhase;
            
            newPhase = obj.linePhase;
            
            %%% Local Functions
            function [d,im] = imDifference(im_odd, im_even, ff_s, ff_t, offset_rad)                
                im_odd  = imToSpatialDomain(im_odd , ff_s, ff_t, offset_rad);
                im_even = imToSpatialDomain(im_even, ff_s, ff_t,-offset_rad);
                
                d = im_odd - im_even;
                d(isnan(d)) = []; % remove artifacts from interpolation
                d = sum(abs(d(:))) ./ numel(d); % least square difference, normalize by number of elements
                
                if nargout > 1
                    im = cat(3,im_odd,im_even);
                    im = permute(im,[1,3,2]);
                    im = reshape(im,size(im,1),[]);
                end
            end
            
            function im = imToTimeDomain(im,ff_s,ff_t)
                nPix = size(im,1);
                xx_lin = linspace(-ff_s,ff_s,nPix);
                xx_rad = linspace(-ff_t,ff_t,nPix)*pi/2;
                xx_linq = sin(xx_rad);
                
                im = interp1(xx_lin,im,xx_linq,'linear',NaN);
            end
            
            function im = imToSpatialDomain(im,ff_s,ff_t,offset_rad)
                nPix = size(im,1);
                xx_rad = linspace(-ff_t,ff_t,nPix)*pi/2+offset_rad;
                xx_lin = linspace(-ff_s,ff_s,nPix);
                xx_radq = asin(xx_lin);
                
                im = interp1(xx_rad,im,xx_radq,'linear',NaN);
            end
            
            function im = getImage()
                %get image from every roi
                roiDatas = obj.hSI.hDisplay.lastStripeData.roiData;
                for i = numel(roiDatas):-1:1
                    im = vertcat(roiDatas{i}.imageData{:});
                    
                    if ~roiDatas{i}.transposed
                        im = cellfun(@(imt){imt'},im);
                    end
                    
                    imData{i,1} = horzcat(im{:});
                end
                
                im = horzcat(imData{:});
                
                nLines = size(im,2);
                if nLines > 1024
                    im(:,1025:end) = []; % this should be enough lines for processing
                elseif mod(nLines,2)
                    im(:,end) = []; % crop to even number of lines
                end
                
                im = single(im);
            end
        end
    end
    
    %%% Abstract methods realizations (scanimage.interfaces.Component)
    methods (Access = protected, Hidden)

        function componentStart(obj)
            assert(~obj.robotMode);
            obj.independentComponent = false;
            obj.totalFrameAcqFcnTime = 0;
            obj.totalDispUpdates = 0;
            obj.totalDispUpdateTime = 0;
            
            obj.configureFrameResolution();
            
            obj.hTrig.start();
            obj.hCtl.start();
            obj.hAcq.start();
            
            fastBeamsMask = cellfun(@(hB)isa(hB, 'dabs.resources.devices.BeamModulatorFast'), obj.hBeams);
            fastBeams = obj.hBeams(fastBeamsMask);
            for idx = 1:numel(fastBeams)
                fastBeams{idx}.setLastKnownPowerFractionToNaN();
            end
            
            obj.flagZoomChanged = false;
            
            obj.hResonantScanner.waitSettlingTime();
        end
        
        function componentAbort(obj,soft)
            if nargin < 2 || isempty(soft)
                soft = false;
            end
            
            obj.hAcq.abort();
            obj.hCtl.stop(soft);
            obj.hTrig.stop();
            
            obj.flagZoomChanged = false;
            obj.independentComponent = true;
        end
        
        
        function fillFracTemp = fillFracSpatToTemp(obj,fillFracSpat)
            if obj.isPolygonalScanner
                fillFracTemp = fillFracSpat;
            else
                fillFracTemp = 2/pi * asin(fillFracSpat);
            end
        end
        
        function fillFracSpat = fillFracTempToSpat(obj,fillFracTemp)
            if obj.isPolygonalScanner
                fillFracSpat = fillFracTemp;
            else
                fillFracSpat = cos( (1-fillFracTemp) * pi/2 );
            end
        end
    end          
    
    %% FRIEND EVENTS
    events (Hidden) % for some reason NotifyAccess = {?scanimage.components.scan2d.resscan.Control} does not work
        resonantScannerOutputVoltsUpdated;
    end
    
end

function s = zlclAppendDependsOnPropAttributes(s)
end

function s = defaultMdfSection()
    s = [...
        most.HasMachineDataFile.makeEntry('DAQ settings')... % comment only
        most.HasMachineDataFile.makeEntry('rioDeviceID','RIO0','FlexRIO Device ID as specified in MAX. If empty, defaults to ''RIO0''')...
        most.HasMachineDataFile.makeEntry('digitalIODeviceName','PXI1Slot3','String: Device name of the DAQ board or FlexRIO FPGA that is used for digital inputs/outputs (triggers/clocks etc). If it is a DAQ device, it must be installed in the same PXI chassis as the FlexRIO Digitizer')...
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('channelsInvert',false,'Logical: Specifies if the input signal is inverted (i.e., more negative for increased light signal)')...
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('externalSampleClock',false,'Logical: use external sample clock connected to the CLK IN terminal of the FlexRIO digitizer module')...
        most.HasMachineDataFile.makeEntry('externalSampleClockRate',80e6,'[Hz]: nominal frequency of the external sample clock connected to the CLK IN terminal (e.g. 80e6); actual rate is measured on FPGA')...
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('enableRefClkOutput',false,'Enables/disables the 10MHz reference clock output on PFI14 of the digitalIODevice')...
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('Scanner settings')... % comment only
        most.HasMachineDataFile.makeEntry('resonantScanner','','Name of the resonant scanner')...
        most.HasMachineDataFile.makeEntry('xGalvo','','Name of the x galvo scanner')...
        most.HasMachineDataFile.makeEntry('yGalvo','','Name of the y galvo scanner')...
        most.HasMachineDataFile.makeEntry('beams',{{}},'beam device names')...
        most.HasMachineDataFile.makeEntry('fastZs',{{}},'fastZ device names')...
        most.HasMachineDataFile.makeEntry('shutters',{{}},'shutter device names')...   
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('extendedRggFov',false,'If true and x galvo is present, addressable FOV is combination of resonant FOV and x galvo FOV.')...
        most.HasMachineDataFile.makeEntry('keepResonantScannerOn',false,'Always keep resonant scanner on to avoid drift and settling time issues')...
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('Advanced/Optional')... % comment only
        most.HasMachineDataFile.makeEntry('PeriodClockDebounceTime', 100e-9,'[s] time the period clock has to be stable before a change is registered')...
        most.HasMachineDataFile.makeEntry('TriggerDebounceTime', 500e-9,'[s] time acquisition, stop and next trigger to be stable before a change is registered')...
        most.HasMachineDataFile.makeEntry('reverseLineRead', false,'flips the image in the resonant scan axis')...
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('Aux Trigger Recording, Photon Counting, and I2C are mutually exclusive')...
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('Aux Trigger Recording')... % comment only
        most.HasMachineDataFile.makeEntry('auxTriggersEnable', true)...
        most.HasMachineDataFile.makeEntry('auxTriggersTimeDebounce', 1e-6,'[s] time an aux trigger needs to be high for registering an edge (seconds)')...
        most.HasMachineDataFile.makeEntry('auxTriggerLinesInvert', false(4,1), '[logical] 1x4 vector specifying polarity of aux trigger inputs')...
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('Photon Counting')... % comment only
        most.HasMachineDataFile.makeEntry('photonCountingEnable', false)...
        most.HasMachineDataFile.makeEntry('photonCountingDisableAveraging', [],'disable averaging of samples into pixels; instead accumulate samples')...
        most.HasMachineDataFile.makeEntry('photonCountingScaleByPowerOfTwo', 8,'for use with photonCountingDisableAveraging == false; scale count by 2^n before averaging to avoid loss of precision by integer division')...
        most.HasMachineDataFile.makeEntry('photonCountingDebounce', 25e-9,'[s] time the TTL input needs to be stable high before a pulse is registered')...
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('I2C')... % comment only
        most.HasMachineDataFile.makeEntry('I2CEnable', false)...
        most.HasMachineDataFile.makeEntry('I2CAddress', uint8(0),'[byte] I2C address of the FPGA')...
        most.HasMachineDataFile.makeEntry('I2CDebounce', 500e-9,'[s] time the I2C signal has to be stable high before a change is registered')...
        most.HasMachineDataFile.makeEntry('I2CStoreAsChar', false,'if false, the I2C packet bytes are stored as a uint8 array. if true, the I2C packet bytes are stored as a string. Note: a Null byte in the packet terminates the string')...
        most.HasMachineDataFile.makeEntry('I2CDisableAckOutput', false, 'the FPGA confirms each packet with an ACK bit by actively pulling down the SDA line. I2C_DISABLE_ACK_OUTPUT = true disables the FPGA output')...
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('Laser Trigger')... % comment only
        most.HasMachineDataFile.makeEntry('LaserTriggerPort', '','Port on FlexRIO AM digital breakout (DIO0.[0:3]) where laser trigger is connected.')...
        most.HasMachineDataFile.makeEntry('LaserTriggerFilterTicks', 0)...
        most.HasMachineDataFile.makeEntry('LaserTriggerSampleMaskEnable', false)...
        most.HasMachineDataFile.makeEntry('LaserTriggerSampleWindow', [0 1])...
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('Calibration data')...
        most.HasMachineDataFile.makeEntry('scannerToRefTransform',eye(3),'')...
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
