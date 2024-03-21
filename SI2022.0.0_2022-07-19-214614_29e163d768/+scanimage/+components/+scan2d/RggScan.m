classdef RggScan < scanimage.components.Scan2D & most.HasMachineDataFile & dabs.resources.configuration.HasConfigPage
    % RggScan - subclass of Scan2D for resonantor linear scanning usingvDAQ hardware
    %   - controls a resonant(X) - galvo(X) mirror pair OR a resonant(X) - galvo(X) - galvo(Y) mirror triplet
    %   - handles the configuration of vDAQ for acquiring signal andcontrol
    %   - format PMT data into images
    %   - handles acquistion timing and acquisition state
    %   - export timing signals
    
    properties (SetAccess=protected,Hidden)
        ConfigPageClass = 'dabs.resources.configuration.resourcePages.RggScanPage';
    end
    
    methods (Static)
        function names = getDescriptiveNames()
            names = {'RggScan'};
        end
    end
    
    
    %% USER PROPS
    
    % TODO: Add property to enable pseudo clock and tie that into
    % SignalConditioningControls, and in the set method for that program
    % the setting into the FPGA
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
        sampleRate;                     % [Hz] sample rate of the digitizer; can only be set for linear scanning
        sampleRateCtl;
        sampleRateFdbk;
        pixelBinFactor = 1;             % if linear scanning or uniformSampling is enabled, pixelBinFactor defines the number of samples used to form a pixel
        channelOffsets;                 % Array of integer values; channelOffsets defines the dark count to be subtracted from each channel if channelsSubtractOffsets is true
    end
    
    properties (SetObservable)
        uniformSampling = false;        % [logical] defines if the same number of samples should be used to form each pixel (see also pixelBinFactor); if true, the non-uniform velocity of the resonant scanner over the field of view is not corrected
        
        scanMode;
        scanModePropCache;
        stripingPeriod = 0.1;
        recordScannerFeedback = false;
        
        logAverageDisableDivide = false;
        
        useCustomFilterClock = false;        % [logical] defines if the physical sync trigger is ignored and the pseudoclock on the FPGA is used instead. This is used for LRR laser support

        % customFilterClockPeriod is the user specified laser clock period (in ticks) when the laser clock is a multiplied version of the actual laser rep rate
        % - it also holds the detected laser clock period when using the medium speed vDAQ and using a digital input terminal
        customFilterClockPeriod = 32;        % [numeric] period of the sync trigger
    end
    
    properties (SetObservable, Transient)
        mask;
        virtualChannelSettings;
        photonDiscriminatorThresholds = [500 500];
        photonDiscriminatorModes = {'threshold crossing' 'threshold crossing'};
        photonDiscriminatorDifferentiateWidths = [4 4];
    end
    properties (SetObservable, Hidden)
        laserTriggerSampleMaskEnable;
        laserTriggerSampleWindow;
    end
    properties (Dependent, SetAccess = protected)
        % data that is useful for line scanning meta data
        lineScanSamplesPerFrame;
        lineScanFdbkSamplesPerFrame;
        lineScanNumFdbkChannels;
    end
    
    %% FRIEND PROPS
    properties (Hidden)
        hListeners = event.listener.empty(0,1);
        hVirtualChannelSettingsListeners = event.listener.empty(0,1);
        coercedFlybackTime;
        coercedFlytoTime;
        
        enableBenchmark = false;
        
        lastFrameAcqFcnTime = 0;
        totalFrameAcqFcnTime = 0;
        cpuFreq = 2.5e9;
        
        totalDispUpdates = 0;
        totalDispUpdateTime = 0;
        
        controllingFastZ = true;
        
        scanModePropsToCache = struct('linear',{{'sampleRate' 'pixelBinFactor' 'fillFractionSpatial' 'bidirectional' 'stripingEnable' 'linePhase'}},...
            'resonant',{{'uniformSampling' 'pixelBinFactor' 'fillFractionSpatial' 'bidirectional' 'stripingEnable'}});
        sampleRateDecim = 1;
        sampleRateCtlDecim = 100;
        ctlTimebaseRate;
        sampleRateCtlMax = 1e6;
        
        hPixListener;
        ctlRateGood = false;
        
        internalPhaseUpdate = false;
    end
    
    properties (Hidden, Dependent)
        resonantScannerLastWrittenValue;
    end
    
    properties (Hidden)
        liveScannerFreq;
        lastLiveScannerFreqMeasTime;
        scanModeIsResonant = true;
        scanModeIsLinear = false;
        
        lastFramePositionData = [];
        validSampleRates;
        
        laserTriggerFilterSupport = true;
        laserTriggerDemuxSupport = true;
    
        defaultFlybackTimePerFrame = 1e-3;
        defaultFlytoTimePerScanfield = 1e-3;
    end
 
    %% INTERNAL PROPS
    properties (Hidden, SetAccess = private)            
        hAcq;                               % handle to image acquisition system
        hCtl;                               % handle to galvo control system
        hTrig;                              % handle to trigger system
    end
    
    properties (Hidden, SetAccess = protected, Dependent)
        linePhaseStep;                      % [s] minimum step size of the linephase
        
        MAX_NUM_CHANNELS;               % Maximum number of channels supported
    end
    
    properties (Transient, Hidden, SetObservable)
        hDAQ = dabs.resources.Resource.empty();
        hResonantScanner = dabs.resources.Resource.empty();
        xGalvo = dabs.resources.Resource.empty();
        yGalvo = dabs.resources.Resource.empty();
        hFastZs = {};
        hShutters = {};
        hBeams = {};
        hDataScope = [];
        extendedRggFov = false;
        reverseLineRead = false;
        auxTriggersTimeDebounce = 1e-7;
        auxTrigger1In = dabs.resources.Resource.empty();
        auxTrigger2In = dabs.resources.Resource.empty();
        auxTrigger3In = dabs.resources.Resource.empty();
        auxTrigger4In = dabs.resources.Resource.empty();        
        auxTriggerLinesInvert = false(1,4);
        i2cEnable = false;
        i2cSdaPort = dabs.resources.Resource.empty();
        i2cSclPort = dabs.resources.Resource.empty();
        i2cAddress = uint8(0);
        i2cDebounce = 100e-9;
        i2cStoreAsChar = false;
        i2cSendAck = true;
        LaserTriggerPort = dabs.resources.Resource.empty();
        frameClockOut = dabs.resources.Resource.empty();
        beamModifiedLineClockOut = dabs.resources.Resource.empty();
        lineClockOut = dabs.resources.Resource.empty();
        volumeTriggerOut = dabs.resources.Resource.empty();
        laserTriggerDebounceTicks = 1;
        externalSampleClock = false;
        externalSampleClockRate = 80e6;
        externalSampleClockMultiplier = 1;
        sampleClockPhase = [];
        channelsInvert;
        maskDisableDivide = false;   % [logical, array] defines for each channel if averaging is enabled/disabled
        enableHostPixelCorrection = false;
        hostPixelCorrectionMultiplier = 500;
    end
    
    properties (Hidden, SetAccess = protected)
        %allowedTriggerInputTerminals;
        %allowedTriggerInputTerminalsMap;
        
        defaultRoiSize;
        angularRange;
        supportsRoiRotation = false;
    end
    
    %%% Abstract prop realizations (most.Model)
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = scanimage.components.Scan2D.scan2DPropAttributes();
        mdlHeaderExcludeProps = {'hFastZs' 'hShutters' 'logFileStem' 'logFilePath' 'logFileCounter' 'channelsAvailableInputRanges' 'scanModePropCache'};
    end    
        
    %%% Abstract property realizations (most.HasMachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'RggScan';
        
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
        hasXGalvo;                   % logical, indicates if scanner has a galvo x mirror
        hasResonantMirror;           % logical, indicates if scanner has a resonant mirror
        isPolygonalScanner = false;  % logical, indicates if resonant scanner is actually a polygonal scanner
    end
    
    properties (Constant, Hidden)
        linePhaseUnits = 'seconds';
    end
    
    %%% Constants
    properties (Constant, Hidden)
        COMPONENT_NAME = 'RggScan';                                                     % [char array] short name describing functionality of component e.g. 'Beams' or 'FastZ'
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
        function obj = RggScan(name)
            % RggScan constructor for scanner object
            %  obj = RggScan(name)
            obj = obj@scanimage.components.Scan2D(name);
            obj = obj@most.HasMachineDataFile(true);
            
            %% Construct sub-components
            % Open FPGA acquisition adapter
            obj.hAcq = scanimage.components.scan2d.rggscan.Acquisition(obj);
            
            % Open scanner control adapter
            obj.hCtl = scanimage.components.scan2d.rggscan.Control(obj);
            
            % Open trigger routing adapter
            obj.hTrig = scanimage.components.scan2d.rggscan.Triggering(obj);
            
            obj.deinit();
            
            obj.numInstances = 1; % some properties won't set correctly if numInstances == 0 (e.g. scannerToRefTransform)
            obj.loadMdf();
        end
        
        function validateConfiguration(obj)
            try
                assert(most.idioms.isValidObj(obj.hDAQ),'No acquisition DAQ specified');
                
                if most.idioms.isValidObj(obj.hResonantScanner)
                    obj.hResonantScanner.assertNoError();
                    assert(obj.hResonantScanner.hDISync.hDAQ==obj.hDAQ,'The resonant scanner Sync input needs to be on %s',obj.hDAQ.name);
                end
                
                assert(most.idioms.isValidObj(obj.yGalvo),'yGalvo is undefined');
                obj.yGalvo.assertNoError();
                
                if most.idioms.isValidObj(obj.xGalvo)
                    obj.xGalvo.assertNoError();
                    assert(~isequal(obj.xGalvo,obj.yGalvo),'x and y galvo cannot be the same.');
                end
                
                assert(most.idioms.isValidObj(obj.hResonantScanner) || most.idioms.isValidObj(obj.xGalvo) ...
                      ,'No scanner for X-axis defined');
                
                beamErrors = cellfun(@(hB)~isempty(hB.errorMsg),obj.hBeams);
                assert(~any(beamErrors),'Beams %s are in error state', strjoin(cellfun(@(hB)hB.name,obj.hBeams(beamErrors),'UniformOutput',false)));
                
                fastZErrors = cellfun(@(hFZ)~isempty(hFZ.errorMsg),obj.hFastZs);
                assert(~any(fastZErrors),'FastZs %s are in error state', strjoin(cellfun(@(hFZ)hFZ.name,obj.hFastZs(fastZErrors),'UniformOutput',false)));
                
                shutterErrors = cellfun(@(hSh)~isempty(hSh.errorMsg),obj.hShutters);
                assert(~any(shutterErrors),'Shutters %s are in error state', strjoin(cellfun(@(hSh)hSh.name,obj.hShutters(shutterErrors),'UniformOutput',false)));
                
                obj.errorMsg = '';
            catch ME
                obj.errorMsg = ME.message;
            end
        end
        
        function deinit(obj)
            obj.errorMsg = 'Uninitialized';
            delete(obj.hListeners);
            obj.hListeners = event.listener.empty(0,1);
            delete(obj.hVirtualChannelSettingsListeners);
            obj.hVirtualChannelSettingsListeners = event.listener.empty(0,1);
            obj.hAcq.deinit();
            
            obj.safeAbortDataScope();
            most.idioms.safeDeleteObj(obj.hDataScope);
        end
        
        function reinit(obj)
            obj.deinit();
            
            try
                %% validate mdf options
                obj.validateConfiguration();
                obj.assertNoError();
                
                obj.simulated = obj.hDAQ.simulated;
                
                obj.hAcq.reinit();
                
                % Open data scope adapter
                obj.hDataScope = scanimage.components.scan2d.rggscan.DataScope(obj);
                
                obj.hasXGalvo = obj.hCtl.xGalvoExists;
                obj.hasResonantMirror = most.idioms.isValidObj(obj.hResonantScanner);
                if obj.hasResonantMirror
                    if obj.hasXGalvo
                        obj.scannerType = 'RGG';
                    else
                        obj.scannerType = 'RG';
                    end
                    obj.scanMode = 'resonant';
                else
                    assert(obj.hasXGalvo, 'X galvo must be present if there is no resonant mirror.');
                    obj.scannerType = 'GG';
                    obj.scanMode = 'linear';
                end
                
                if obj.isPolygonalScanner
                    obj.uniformSampling = true;
                    obj.bidirectional = false;
%                     obj.fillFractionSpatial = obj.fillFractionTemporal;
                end
                
                obj.hCtl.parkGalvo();
                
                %% Init
                obj.numInstances = 1; % This has to happen _before_ any properties are set
                
                % initialize scanner frequency from mdfData
                if ~isempty(obj.hResonantScanner)
                    obj.scannerFrequency = obj.hResonantScanner.nominalFrequency_Hz;
                end
                
                %Initialize sub-components
                obj.hAcq.frameAcquiredFcn = @obj.frameAcquiredFcn;
                obj.hAcq.initialize();
                
                obj.hVirtualChannelSettingsListeners = most.ErrorHandler.addCatchingListener(obj,'virtualChannelSettings','PostSet',@obj.virtualChannelSettings_changedCallback);
                
                %Initialize props (not initialized by superclass)
                obj.channelsFilter = obj.hAcq.defaultFilterSetting;
                obj.channelsInputRanges = repmat({[-1 1]},1,obj.physicalChannelsAvailable);
                obj.channelOffsets = zeros(1, obj.physicalChannelsAvailable);
                obj.channelsSubtractOffsets = true(1, obj.physicalChannelsAvailable);
                
                obj.parkScanner();
                
                obj.errorMsg = '';
                
            catch ME
                obj.deinit()
                most.ErrorHandler.rethrow(ME);
            end
        end
        
        function delete(obj)
            % delete - deletes the ResScan object, parks the mirrors and
            %   deinitializes all routes
            %   obj.delete()  returns nothing
            %   delete(obj)   returns nothing
            
            obj.saveCalibration();
            
            obj.deinit();
            most.idioms.safeDeleteObj(obj.hPixListener);
            most.idioms.safeDeleteObj(obj.hTrig);
            most.idioms.safeDeleteObj(obj.hCtl);
            most.idioms.safeDeleteObj(obj.hAcq);
        end
    end
    
    methods
        function loadMdf(obj)
            success = true;
            success = success & obj.safeSetPropFromMdf('hDAQ', 'acquisitionDeviceId');
            success = success & obj.safeSetPropFromMdf('hResonantScanner', 'resonantScanner');
            success = success & obj.safeSetPropFromMdf('xGalvo', 'xGalvo');
            success = success & obj.safeSetPropFromMdf('yGalvo', 'yGalvo');
            success = success & obj.safeSetPropFromMdf('hFastZs', 'fastZs');
            success = success & obj.safeSetPropFromMdf('hShutters', 'shutters');
            success = success & obj.safeSetPropFromMdf('hBeams', 'beams');
            success = success & obj.safeSetPropFromMdf('channelsInvert', 'channelsInvert');
            success = success & obj.safeSetPropFromMdf('auxTriggersTimeDebounce', 'auxTriggersTimeDebounce');
            success = success & obj.safeSetPropFromMdf('auxTriggerLinesInvert', 'auxTriggerLinesInvert');
            success = success & obj.safeSetPropFromMdf('auxTrigger1In', 'auxTrigger1In');
            success = success & obj.safeSetPropFromMdf('auxTrigger2In', 'auxTrigger2In');
            success = success & obj.safeSetPropFromMdf('auxTrigger3In', 'auxTrigger3In');
            success = success & obj.safeSetPropFromMdf('auxTrigger4In', 'auxTrigger4In');
            
            success = success & obj.safeSetPropFromMdf('i2cEnable', 'i2cEnable');
            success = success & obj.safeSetPropFromMdf('i2cSdaPort', 'i2cSdaPort');
            success = success & obj.safeSetPropFromMdf('i2cSclPort', 'i2cSclPort');
            success = success & obj.safeSetPropFromMdf('i2cAddress', 'i2cAddress');
            success = success & obj.safeSetPropFromMdf('i2cDebounce', 'i2cDebounce');
            success = success & obj.safeSetPropFromMdf('i2cStoreAsChar', 'i2cStoreAsChar');
            success = success & obj.safeSetPropFromMdf('i2cSendAck', 'i2cSendAck');
            
            success = success & obj.safeSetPropFromMdf('extendedRggFov', 'extendedRggFov');
            success = success & obj.safeSetPropFromMdf('frameClockOut', 'frameClockOut');
            success = success & obj.safeSetPropFromMdf('lineClockOut', 'lineClockOut');
            success = success & obj.safeSetPropFromMdf('beamModifiedLineClockOut', 'beamModifiedLineClockOut');
            success = success & obj.safeSetPropFromMdf('volumeTriggerOut', 'volumeTriggerOut');
            success = success & obj.safeSetPropFromMdf('keepResonantScannerOn', 'keepResonantScannerOn');
            success = success & obj.safeSetPropFromMdf('reverseLineRead', 'reverseLineRead');
            success = success & obj.safeSetPropFromMdf('defaultFlybackTimePerFrame', 'defaultFlybackTimePerFrame');
            success = success & obj.safeSetPropFromMdf('defaultFlytoTimePerScanfield', 'defaultFlytoTimePerScanfield');
            
            success = success & obj.safeSetPropFromMdf('LaserTriggerPort', 'LaserTriggerPort');
            success = success & obj.safeSetPropFromMdf('laserTriggerDebounceTicks', 'LaserTriggerDebounceTicks');
            
            success = success & obj.safeSetPropFromMdf('externalSampleClock', 'externalSampleClock');
            success = success & obj.safeSetPropFromMdf('externalSampleClockRate', 'externalSampleClockRate');
            success = success & obj.safeSetPropFromMdf('externalSampleClockMultiplier', 'externalSampleClockMultiplier');
            success = success & obj.safeSetPropFromMdf('sampleClockPhase', 'sampleClockPhase');
            success = success & obj.safeSetPropFromMdf('useCustomFilterClock', 'useCustomFilterClock');
            success = success & obj.safeSetPropFromMdf('customFilterClockPeriod', 'customFilterClockPeriod');
            
            success = success & obj.safeSetPropFromMdf('enableHostPixelCorrection', 'enableHostPixelCorrection');
            success = success & obj.safeSetPropFromMdf('hostPixelCorrectionMultiplier', 'hostPixelCorrectionMultiplier');
            
            success = success & obj.safeSetPropFromMdf('photonDiscriminatorThresholds', 'photonDiscriminatorThresholds');
            success = success & obj.safeSetPropFromMdf('photonDiscriminatorModes', 'photonDiscriminatorModes');
            success = success & obj.safeSetPropFromMdf('photonDiscriminatorDifferentiateWidths', 'photonDiscriminatorDifferentiateWidths');
            
            success = success & obj.loadCalibration();
            
            obj.loadVirtualChannelSettings();
            
            if ~success
                obj.errorMsg = 'Error loading config';
            end
        end
        
        function saveMdf(obj)
            obj.safeWriteVarToHeading('acquisitionDeviceId', obj.hDAQ);
            obj.safeWriteVarToHeading('resonantScanner', obj.hResonantScanner);
            obj.safeWriteVarToHeading('xGalvo', obj.xGalvo);
            obj.safeWriteVarToHeading('yGalvo', obj.yGalvo);
            obj.safeWriteVarToHeading('fastZs', resourceCellToNames(obj.hFastZs));
            obj.safeWriteVarToHeading('beams', resourceCellToNames(obj.hBeams));
            obj.safeWriteVarToHeading('shutters', resourceCellToNames(obj.hShutters));
            obj.safeWriteVarToHeading('channelsInvert', obj.channelsInvert);
            obj.safeWriteVarToHeading('auxTriggersTimeDebounce', obj.auxTriggersTimeDebounce);
            obj.safeWriteVarToHeading('auxTriggerLinesInvert', obj.auxTriggerLinesInvert);
            obj.safeWriteVarToHeading('auxTrigger1In', obj.auxTrigger1In);
            obj.safeWriteVarToHeading('auxTrigger2In', obj.auxTrigger2In);
            obj.safeWriteVarToHeading('auxTrigger3In', obj.auxTrigger3In);
            obj.safeWriteVarToHeading('auxTrigger4In', obj.auxTrigger4In);
            
            obj.safeWriteVarToHeading('i2cEnable', obj.i2cEnable);
            obj.safeWriteVarToHeading('i2cSdaPort', obj.i2cSdaPort);
            obj.safeWriteVarToHeading('i2cSclPort', obj.i2cSclPort);
            obj.safeWriteVarToHeading('i2cAddress', obj.i2cAddress);
            obj.safeWriteVarToHeading('i2cDebounce', obj.i2cDebounce);
            obj.safeWriteVarToHeading('i2cStoreAsChar', obj.i2cStoreAsChar);
            obj.safeWriteVarToHeading('i2cSendAck', obj.i2cSendAck);
            
            obj.safeWriteVarToHeading('extendedRggFov', obj.extendedRggFov);
            obj.safeWriteVarToHeading('keepResonantScannerOn', obj.keepResonantScannerOn);
            obj.safeWriteVarToHeading('frameClockOut', obj.frameClockOut);
            obj.safeWriteVarToHeading('lineClockOut', obj.lineClockOut);
            obj.safeWriteVarToHeading('beamModifiedLineClockOut', obj.beamModifiedLineClockOut);
            obj.safeWriteVarToHeading('volumeTriggerOut', obj.volumeTriggerOut);
            obj.safeWriteVarToHeading('reverseLineRead', obj.reverseLineRead);
            obj.safeWriteVarToHeading('defaultFlybackTimePerFrame', obj.defaultFlybackTimePerFrame);
            obj.safeWriteVarToHeading('defaultFlytoTimePerScanfield', obj.defaultFlytoTimePerScanfield);
            
            obj.safeWriteVarToHeading('LaserTriggerPort', obj.LaserTriggerPort);
            obj.safeWriteVarToHeading('LaserTriggerDebounceTicks', obj.laserTriggerDebounceTicks);
            
            obj.safeWriteVarToHeading('enableHostPixelCorrection', obj.enableHostPixelCorrection);
            obj.safeWriteVarToHeading('hostPixelCorrectionMultiplier', obj.hostPixelCorrectionMultiplier);
            
            obj.safeWriteVarToHeading('photonDiscriminatorThresholds', obj.photonDiscriminatorThresholds);
            obj.safeWriteVarToHeading('photonDiscriminatorModes', obj.photonDiscriminatorModes);
            obj.safeWriteVarToHeading('photonDiscriminatorDifferentiateWidths', obj.photonDiscriminatorDifferentiateWidths);
            
            obj.saveClockSettings();
            obj.saveVirtualChannelSettings();
            obj.saveCalibration();
            
            %%% Nested functions
            function names = resourceCellToNames(hResources)
               names = {};
               for idx = 1:numel(hResources)
                   if most.idioms.isValidObj(hResources{idx})
                       names{end+1} = hResources{idx}.name;
                   end
               end
            end
        end
        
        function success = loadCalibration(obj)
            success = true;
            success = success & obj.safeSetPropFromMdf('scannerToRefTransform', 'scannerToRefTransform');
            success = success & obj.safeSetPropFromMdf('maskDisableDivide', 'disableMaskDivide');
        end
        
        function saveCalibration(obj)
            obj.safeWriteVarToHeading('scannerToRefTransform', obj.scannerToRefTransform);
            obj.safeWriteVarToHeading('disableMaskDivide', obj.maskDisableDivide);
        end
        
        function saveVirtualChannelSettings(obj)
            mdf = most.MachineDataFile.getInstance();
            if mdf.isLoaded
                
                mdf.removeStructFromHeading(obj.custMdfHeading, 'virtualChannelSettings');
                
                [sources, modes, threshs, bins, edges, gates, divs, tvals, winds] =...
                    arrayfun(@(s)deal({s.source}, {s.mode}, logical(s.threshold), logical(s.binarize), logical(s.edgeDetect), logical(s.laserGate),...
                    logical(s.disableDivide), int32(s.thresholdValue), {s.laserFilterWindow}), obj.virtualChannelSettings);
                saveVar('virtualChannelsSource', sources, false);
                saveVar('virtualChannelsMode', modes, false);
                saveVar('virtualChannelsThreshold', threshs, false);
                saveVar('virtualChannelsBinarize', bins, false);
                saveVar('virtualChannelsEdgeDetect', edges, false);
                saveVar('virtualChannelsLaserGate', gates, false);
                saveVar('virtualChannelsDisableDivide', divs, false);
                saveVar('virtualChannelsThresholdValue', tvals, false);
                saveVar('virtualChannelsLaserFilterWindow', winds, true);
                
                % also a good place to save photon counting settings
                obj.safeWriteVarToHeading('photonDiscriminatorThresholds', obj.photonDiscriminatorThresholds);
                obj.safeWriteVarToHeading('photonDiscriminatorModes', obj.photonDiscriminatorModes);
                obj.safeWriteVarToHeading('photonDiscriminatorDifferentiateWidths', obj.photonDiscriminatorDifferentiateWidths);
            end
            
            function saveVar(nm,val,commit)
                mdf.writeVarToHeading(obj.custMdfHeading,nm,val,'',commit);
            end
        end
        
        function saveLaserTriggerSettings(obj)
            obj.saveVirtualChannelSettings();
        end
        
        function loadVirtualChannelSettings(obj)
            try
                if isfield(obj.mdfData,'virtualChannelsSource')
                    obj.virtualChannelSettings = arrayfun(@(s,m,t,b,e,l,dd,v,w)struct('source', s{1}, 'mode', m{1}, 'threshold', t, 'binarize', b,'edgeDetect', e,...
                         'laserGate', l, 'disableDivide', dd,'thresholdValue', v, 'laserFilterWindow', w{1}),obj.mdfData.virtualChannelsSource,obj.mdfData.virtualChannelsMode,...
                        obj.mdfData.virtualChannelsThreshold,obj.mdfData.virtualChannelsBinarize,obj.mdfData.virtualChannelsEdgeDetect,obj.mdfData.virtualChannelsLaserGate,...
                        obj.mdfData.virtualChannelsDisableDivide,obj.mdfData.virtualChannelsThresholdValue,obj.mdfData.virtualChannelsLaserFilterWindow);
                else
                    obj.virtualChannelSettings = obj.mdfData.virtualChannelSettings;
                end
            catch
                obj.virtualChannelSettings = obj.defaultVirtChanSettings();
            end
        end
        
        function saveClockSettings(obj)
            obj.safeWriteVarToHeading('externalSampleClock', obj.externalSampleClock);
            obj.safeWriteVarToHeading('externalSampleClockRate', obj.externalSampleClockRate);
            obj.safeWriteVarToHeading('externalSampleClockMultiplier', obj.externalSampleClockMultiplier);
            obj.safeWriteVarToHeading('sampleClockPhase', obj.sampleClockPhase);
            obj.safeWriteVarToHeading('useCustomFilterClock', obj.useCustomFilterClock);
            obj.safeWriteVarToHeading('customFilterClockPeriod', obj.customFilterClockPeriod);
        end
        
        function [tfExternalSuccess, err] = reinitSampleClock(obj)
            [tfExternalSuccess, err] = obj.hAcq.configureAcqSampleClock();
        end
        
        function saveLaserInputSettings(obj)
            obj.saveMdf();
        end
        
        function virtualChannelSettings_changedCallback(obj,varargin)
            if obj.active
                obj.hAcq.applyVirtualChannelSettings();
            else
                % perhaps a better approach is for hChannels.channelDisplay
                % and hChannels.channelSave to have dependsOn listeners on
                % virtualChannelSettings and update appropriately. or
                % better yet do away with hChannels altogether..
                obj.hSI.hChannels.registerChannels(true);
            end
        end
    end
    
    %% PROP ACCESS METHODS
    methods
        function set.hDAQ(obj,val)
            val = obj.hResourceStore.filterByName(val);
            
            if ~isequal(val,obj.hDAQ)
                if most.idioms.isValidObj(val)
                    validateattributes(val,{'dabs.resources.daqs.vDAQ'},{'scalar'});
                end
                
                obj.deinit();
                
                obj.hDAQ.unregisterUser(obj);
                obj.hDAQ = val;
                obj.hDAQ.registerUser(obj,'Acquisition DAQ');
            end
        end
        
        function val = get.hDAQ(obj)
            val = obj.hDAQ;
            if ~most.idioms.isValidObj(val)
                val = dabs.resources.Resource.empty();
            end
        end
        
        function set.xGalvo(obj,val)
            val = obj.hResourceStore.filterByName(val);
            
            if ~isequal(val,obj.xGalvo)
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
                if most.idioms.isValidObj(val)
                    validateattributes(val,{'dabs.resources.devices.SyncedScanner'},{'scalar'});
                end
                
                obj.deinit();
                
                obj.hResonantScanner.unregisterUser(obj);                
                obj.hResonantScanner = val;
                obj.isPolygonalScanner = isa(obj.hResonantScanner,'dabs.resources.devices.PolygonalScanner');
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
        
        function set.channelsInvert(obj,val)
            if isempty(val)
                val = false(1,obj.physicalChannelsAvailable);
            end
            
            val(end+1:obj.physicalChannelsAvailable) = val(1);
            val(obj.physicalChannelsAvailable+1:end) = [];
            
            validateattributes(val,{'numeric','logical'},{'binary'});
            obj.channelsInvert = val;
            
            if ~isempty(obj.hAcq) && ~isempty(obj.hAcq.hAcqEngine)
                obj.hAcq.hAcqEngine.acqParamChannelsInvert = val;
            end
        end
        
        function v = get.channelsInvert(obj)
            v = obj.channelsInvert;
            v(end+1:obj.physicalChannelsAvailable) = v(end);
            v(obj.physicalChannelsAvailable+1:end) = [];
        end
        
        function set.reverseLineRead(obj,val)
            validateattributes(val,{'numeric','logical'},{'scalar','binary'});
            obj.reverseLineRead = val;
        end
        
        function set.extendedRggFov(obj,val)
            validateattributes(val,{'numeric','logical'},{'scalar','binary'});
            obj.extendedRggFov = val;
        end
        
        function set.auxTriggersTimeDebounce(obj,val)
            validateattributes(val,{'numeric'},{'scalar','nonnegative','real','nonnan','finite'});
            obj.auxTriggersTimeDebounce = val;
        end
        
        function set.auxTriggerLinesInvert(obj,val)
            validateattributes(val,{'numeric','logical'},{'size',[1,4]});
            obj.auxTriggerLinesInvert = val;
        end
        
        function set.auxTrigger1In(obj,val)
            val = obj.hResourceStore.filterByName(val);
            
            if ~isequal(val,obj.auxTrigger1In)
                if most.idioms.isValidObj(val)
                    validateattributes(val,{'dabs.resources.ios.DI'},{'scalar'});
                    assert(isa(val.hDAQ,'dabs.resources.daqs.vDAQ'),'%s is not a vDAQ IO port',val.name);
                end
                
                obj.auxTrigger1In.unregisterUser(obj);
                obj.auxTrigger1In = val;
                obj.auxTrigger1In.registerUser(obj,'Aux Trigger 1');
                
                if obj.mdlInitialized && obj.hSI.hScan2D==obj
                    obj.hTrig.applyTriggerConfig();
                end
            end
        end
        
        function val = get.auxTrigger1In(obj)
            val = obj.auxTrigger1In;
            if ~most.idioms.isValidObj(val)
                val = dabs.resources.Resource.empty();
            end
        end
        
        function set.auxTrigger2In(obj,val)
            val = obj.hResourceStore.filterByName(val);
            
            if ~isequal(val,obj.auxTrigger2In)
                if most.idioms.isValidObj(val)
                    validateattributes(val,{'dabs.resources.ios.DI'},{'scalar'});
                    assert(isa(val.hDAQ,'dabs.resources.daqs.vDAQ'),'%s is not a vDAQ IO port',val.name);
                end
                
                obj.auxTrigger2In.unregisterUser(obj);
                obj.auxTrigger2In = val;
                obj.auxTrigger2In.registerUser(obj,'Aux Trigger 2');
                
                if obj.mdlInitialized && obj.hSI.hScan2D==obj
                    obj.hTrig.applyTriggerConfig();
                end
            end
        end
        
        function val = get.auxTrigger2In(obj)
            val = obj.auxTrigger2In;
            if ~most.idioms.isValidObj(val)
                val = dabs.resources.Resource.empty();
            end
        end
        
        function set.auxTrigger3In(obj,val)
            val = obj.hResourceStore.filterByName(val);
            
            if ~isequal(val,obj.auxTrigger3In)
                if most.idioms.isValidObj(val)
                    validateattributes(val,{'dabs.resources.ios.DI'},{'scalar'});
                    assert(isa(val.hDAQ,'dabs.resources.daqs.vDAQ'),'%s is not a vDAQ IO port',val.name);
                end
                
                obj.auxTrigger3In.unregisterUser(obj);
                obj.auxTrigger3In = val;
                obj.auxTrigger3In.registerUser(obj,'Aux Trigger 3');
                
                if obj.mdlInitialized && obj.hSI.hScan2D==obj
                    obj.hTrig.applyTriggerConfig();
                end
            end
        end
        
        function val = get.auxTrigger3In(obj)
            val = obj.auxTrigger3In;
            if ~most.idioms.isValidObj(val)
                val = dabs.resources.Resource.empty();
            end
        end
        
        function set.auxTrigger4In(obj,val)
            val = obj.hResourceStore.filterByName(val);
            
            if ~isequal(val,obj.auxTrigger4In)
                if most.idioms.isValidObj(val)
                    validateattributes(val,{'dabs.resources.ios.DI'},{'scalar'});
                    assert(isa(val.hDAQ,'dabs.resources.daqs.vDAQ'),'%s is not a vDAQ IO port',val.name);
                end
                
                obj.auxTrigger4In.unregisterUser(obj);
                obj.auxTrigger4In = val;
                obj.auxTrigger4In.registerUser(obj,'Aux Trigger 4');
                
                if obj.mdlInitialized && obj.hSI.hScan2D==obj
                    obj.hTrig.applyTriggerConfig();
                end
            end
        end
        
        function val = get.auxTrigger4In(obj)
            val = obj.auxTrigger4In;
            if ~most.idioms.isValidObj(val)
                val = dabs.resources.Resource.empty();
            end
        end
        
        function set.i2cEnable(obj,val)
            validateattributes(val,{'numeric','logical'},{'scalar'});
            obj.i2cEnable = logical(val);
        end
        
        function set.i2cSdaPort(obj,val)
            val = obj.hResourceStore.filterByName(val);
            
            if most.idioms.isValidObj(val)
                validateattributes(val,{'dabs.resources.ios.DI'},{'scalar'});
                assert(isa(val.hDAQ,'dabs.resources.daqs.vDAQ'),'%s is not a vDAQ IO port',val.name);
            end
            
            obj.i2cSdaPort.unregisterUser(obj);
            obj.i2cSdaPort = val;
            obj.i2cSdaPort.registerUser(obj,'I2C SDA');
        end
        
        function val = get.i2cSdaPort(obj)
            val = obj.i2cSdaPort;
            if ~most.idioms.isValidObj(val)
                val = dabs.resources.Resource.empty();
            end
        end
        
        function set.i2cSclPort(obj,val)
            val = obj.hResourceStore.filterByName(val);
            
            if most.idioms.isValidObj(val)
                validateattributes(val,{'dabs.resources.ios.DI'},{'scalar'});
                assert(isa(val.hDAQ,'dabs.resources.daqs.vDAQ'),'%s is not a vDAQ IO port',val.name);
            end
            
            obj.i2cSclPort.unregisterUser(obj);
            obj.i2cSclPort = val;
            obj.i2cSclPort.registerUser(obj,'I2C SCL');
        end
        
        function val = get.i2cSclPort(obj)
            val = obj.i2cSclPort;
            if ~most.idioms.isValidObj(val)
                val = dabs.resources.Resource.empty();
            end
        end
        
        function set.i2cAddress(obj,val)
            validateattributes(val,{'numeric'},{'scalar','integer','nonnegative','<=',255,'real'});
            obj.i2cAddress = uint8(val);
        end
        
        function set.i2cDebounce(obj,val)
            validateattributes(val,{'numeric'},{'scalar','nonnegative','finite','real'});
            obj.i2cDebounce = val;
        end
        
        function set.i2cStoreAsChar(obj,val)
            validateattributes(val,{'numeric','logical'},{'binary','scalar'});
            obj.i2cStoreAsChar = logical(val);
        end
        
        function set.i2cSendAck(obj,val)
            validateattributes(val,{'numeric','logical'},{'binary','scalar'});
            obj.i2cSendAck = logical(val);
        end
        
        function set.LaserTriggerPort(obj,val)
            val = obj.hResourceStore.filterByName(val);
            
            if most.idioms.isValidObj(val)
                validateattributes(val,{'dabs.resources.ios.DI','dabs.resources.ios.CLKI'},{'scalar'});
                assert(isa(val.hDAQ,'dabs.resources.daqs.vDAQ'),'%s is not a vDAQ IO port',val.name);
            end
            
            obj.LaserTriggerPort.unregisterUser(obj);
            obj.LaserTriggerPort = val;
            obj.LaserTriggerPort.registerUser(obj,'Laser Trigger');
            
            if obj.mdlInitialized && obj.hSI.hScan2D==obj
                obj.hTrig.applyTriggerConfig();
            end
        end
        
        function val = get.LaserTriggerPort(obj)
            val = obj.LaserTriggerPort;
            if ~most.idioms.isValidObj(val)
                val = dabs.resources.Resource.empty();
            end
        end
        
        function set.frameClockOut(obj,val)
            val = obj.hResourceStore.filterByName(val);
            
            if most.idioms.isValidObj(val)
                validateattributes(val,{'dabs.resources.ios.DO'},{'scalar'});
                assert(isa(val.hDAQ,'dabs.resources.daqs.vDAQ'),'%s is not a vDAQ IO port',val.name);
            end
            
            obj.frameClockOut.unregisterUser(obj);
            obj.frameClockOut = val;
            obj.frameClockOut.registerUser(obj,'Frame Clock');
            
            if obj.mdlInitialized && obj.hSI.hScan2D==obj
                obj.hTrig.applyTriggerConfig();
            end
        end
        
        function val = get.frameClockOut(obj)
            val = obj.frameClockOut;
            if ~most.idioms.isValidObj(val)
                val = dabs.resources.Resource.empty();
            end
        end
        
        function set.lineClockOut(obj,val)
            val = obj.hResourceStore.filterByName(val);
            
            if most.idioms.isValidObj(val)
                validateattributes(val,{'dabs.resources.ios.DO'},{'scalar'});
                assert(isa(val.hDAQ,'dabs.resources.daqs.vDAQ'),'%s is not a vDAQ IO port',val.name);
            end
            
            obj.lineClockOut.unregisterUser(obj);
            obj.lineClockOut = val;
            obj.lineClockOut.registerUser(obj,'Line Clock');
            
            if obj.mdlInitialized && obj.hSI.hScan2D==obj
                obj.hTrig.applyTriggerConfig();
            end
        end
        
        function val = get.lineClockOut(obj)
            val = obj.lineClockOut;
            if ~most.idioms.isValidObj(val)
                val = dabs.resources.Resource.empty();
            end
        end
        
        function set.beamModifiedLineClockOut(obj,val)
            val = obj.hResourceStore.filterByName(val);
            
            if most.idioms.isValidObj(val)
                validateattributes(val,{'dabs.resources.ios.DO'},{'scalar'});
                assert(isa(val.hDAQ,'dabs.resources.daqs.vDAQ'),'%s is not a vDAQ IO port',val.name);
            end
            
            obj.beamModifiedLineClockOut.unregisterUser(obj);
            obj.beamModifiedLineClockOut = val;
            obj.beamModifiedLineClockOut.registerUser(obj,'Beam Clock');
            
            if obj.mdlInitialized && obj.hSI.hScan2D==obj
                obj.hTrig.applyTriggerConfig();
            end
        end
        
        function val = get.beamModifiedLineClockOut(obj)
            val = obj.beamModifiedLineClockOut;
            if ~most.idioms.isValidObj(val)
                val = dabs.resources.Resource.empty();
            end
        end
        
        function set.volumeTriggerOut(obj,val)
            val = obj.hResourceStore.filterByName(val);
            
            if most.idioms.isValidObj(val)
                validateattributes(val,{'dabs.resources.ios.DO'},{'scalar'});
                assert(isa(val.hDAQ,'dabs.resources.daqs.vDAQ'),'%s is not a vDAQ IO port',val.name);
            end
            
            obj.volumeTriggerOut.unregisterUser(obj);
            obj.volumeTriggerOut = val;
            obj.volumeTriggerOut.registerUser(obj,'Volume Clock');
            
            if obj.mdlInitialized && obj.hSI.hScan2D==obj
                obj.hTrig.applyTriggerConfig();
            end
        end
        
        function val = get.volumeTriggerOut(obj)
            val = obj.volumeTriggerOut;
            if ~most.idioms.isValidObj(val)
                val = dabs.resources.Resource.empty();
            end
        end
        
        function set.channelOffsets(obj,val)
            if ~isempty(val)
                Nch = obj.physicalChannelsAvailable;
                if numel(val) ~= Nch
                	most.idioms.warn('When setting offsets, number of elements must match number of physical channels.');
                end
                lclSubtractOffset = cast(obj.channelsSubtractOffsets,obj.channelsDataType);
                lclSubtractOffset(end+1:Nch) = 0;
                lclSubtractOffset(Nch+1:end) = [];
                for iter = 1:min(numel(val),numel(lclSubtractOffset))
                    fpgaVal(iter) = -val(iter) * lclSubtractOffset(iter);
                end
                obj.channelOffsets = val;
                obj.hAcq.hAcqEngine.acqParamChannelOffsets = fpgaVal;
            end
        end
        
        function set.pixelBinFactor(obj,val)
            if obj.componentUpdateProperty('pixelBinFactor',val)
                val = obj.validatePropArg('pixelBinFactor',val);
                obj.pixelBinFactor = val;
                obj.fillFractionTemporal = obj.fillFractionTemporal; %trigger update
                
                if obj.scanModeIsLinear
                    obj.sampleRateCtl = nan;
                end
            end
        end
        
        function set.externalSampleClock(obj,val)
            validateattributes(val,{'numeric','logical'},{'scalar'});
            obj.externalSampleClock = logical(val);
        end
        
        function set.externalSampleClockRate(obj,val)
            validateattributes(val,{'numeric'},{'scalar','positive','finite','nonnan'});
            obj.externalSampleClockRate = val;
        end
        
        function set.externalSampleClockMultiplier(obj,val)
            validateattributes(val,{'numeric'},{'scalar','positive'});
            obj.externalSampleClockMultiplier = val;
        end
        
        function set.sampleRate(obj,val)
            if ~isempty(obj.scanModeIsResonant) && obj.scanModeIsResonant && ~isnan(val)
                obj.errorPropertyUnSupported('sampleRate',val,'set');
                obj.sampleRateDecim = 1;
            else
                if isnan(val)
                    laserGate = [obj.virtualChannelSettings.laserGate];
                    laserGateEnabledForSomeChannels = any(laserGate);
                    laserGateEnabledForAllChannels = all(laserGate);
                    laserGateMixed = laserGateEnabledForSomeChannels && ~laserGateEnabledForAllChannels;
                    if laserGateMixed || ~laserGateEnabledForSomeChannels
                        val = 2.5e6;
                    else
                        val = obj.hAcq.stateMachineSampleRate;
                    end
                end
                val = min(20e6,val);
                obj.sampleRateDecim = ceil(obj.hAcq.stateMachineSampleRate/val);
            end
            if obj.mdlInitialized
                obj.fillFractionTemporal = obj.fillFractionTemporal; %trigger update
                obj.sampleRateCtl = nan;
            end
        end
        
        function val = get.sampleRate(obj)
            if obj.scanModeIsResonant
                if any([obj.virtualChannelSettings.laserGate])
                    val = obj.hAcq.stateMachineSampleRate;
                else
                    val = obj.hAcq.rawAcqSampleRate;
                end
            else
                val = obj.hAcq.stateMachineSampleRate / obj.sampleRateDecim;
            end
        end
        
        function sf = getAllSfs(obj)
            roiGroup = obj.currentRoiGroup;
            zs = obj.hSI.hStackManager.zs;
            sf = scanimage.mroi.scanfield.fields.RotatedRectangle.empty(1,0);
            for idx = numel(zs) : -1 : 1
                zsf = roiGroup.scanFieldsAtZ(zs(idx));
                sf = [sf zsf{:}];
            end
        end
        
        function set.sampleRateCtl(obj,~)
            minDecim = max(ceil(obj.ctlTimebaseRate/obj.sampleRateCtlMax),2);
            ctlDecims = minDecim:(10*minDecim);
            
            if obj.hSI.hRoiManager.isLineScan || ~obj.scanModeIsLinear
                % for resonant scanning and arb line scanning ctl sample
                % rate doesn't really matter
                obj.sampleRateCtlDecim = min(ctlDecims);
                obj.ctlRateGood = true;
            else
                % for linear frame scanning determine a ctl rate that is
                % an integer divisor of the line period
                
                % for mroi we need to match line periods of all rois
                sf = obj.getAllSfs();
                if ~isempty(sf)
                    % start with a list of all the potential ctl sample rates
                    ctlTimebasePeriod = 1/obj.ctlTimebaseRate;
                    ctlMults = ctlDecims(:).^-1;
                    
                    % get the acq time for each scanfield
                    sfPRs = [sf.pixelResolution];
                    lineAcqPixCnts = unique(sfPRs(1:2:end));
                    lineAcqSamps = lineAcqPixCnts * obj.pixelBinFactor;
                    ff = obj.fillFractionTemporal;
                    acqSampleRate = obj.sampleRate;
                    acqSamplePeriod = 1/acqSampleRate;
                    
                    % for each sf we try a variety of line acquisition
                    % times based on varying from the desired temporal fill
                    % fraction
                    for i = 1:numel(lineAcqSamps)
                        lineAcqSampsi = lineAcqSamps(i);
                        overscanSamples = (lineAcqSampsi/ff - lineAcqSampsi)/2;
                        overscanSamples = ceil(overscanSamples:(overscanSamples*1.5));
                        linePeriods = acqSamplePeriod * (lineAcqSampsi + 2*overscanSamples);
                        
                        ctlTbPulses = (linePeriods / ctlTimebasePeriod);
                        ctlTbPulses(ctlTbPulses ~= round(ctlTbPulses)) = [];
                        
                        res = ctlMults * ctlTbPulses;
                        
                        idxs = find(res == round(res));
                        [ctlMultInds,~] = ind2sub(size(res),idxs);
                        
                        % whittle down list of valid ctl sample rates by
                        % the solutions that worked for this line acq time
                        ctlMults = ctlMults(unique(ctlMultInds));
                        
                        if isempty(ctlMults)
                            most.idioms.warn('Could not find a scanner control rate fitting the desired scan parameters. Try adjusting the acq sample rate or ROI pixel counts.');
                            obj.sampleRateCtlDecim = min(ctlDecims);
                            obj.ctlRateGood = false;
                            return;
                        end
                    end
                    
                    obj.sampleRateCtlDecim = 1/max(ctlMults);
                    obj.ctlRateGood = true;
                end
            end
        end
        
        function v = get.sampleRateFdbk(obj)
            v = obj.sampleRateCtl;
        end
        
        function v = get.ctlTimebaseRate(obj)
            if obj.scanModeIsLinear && obj.hCtl.useScannerSampleClk
                v = obj.hAcq.stateMachineSampleRate;
            else
                v = obj.hAcq.hFpga.waveformTimebaseRate;
            end
        end
        
        function val = get.sampleRateCtl(obj)
            val = obj.ctlTimebaseRate / obj.sampleRateCtlDecim;
        end
        
        function val = get.resonantScannerLastWrittenValue(obj)
           val = obj.hCtl.resonantScannerLastWrittenValue; 
        end
        
        function set.linePhaseStep(obj,val)
            obj.mdlDummySetProp(val,'linePhaseStep');
        end
        
        function val = get.linePhaseStep(obj)
            val = 1 / obj.sampleRate;
        end
        
        function set.keepResonantScannerOn(obj, v)
            validateattributes(v,{'numeric','logical'},{'scalar','binary'});
            obj.keepResonantScannerOn = logical(v);
            
            if obj.mdlInitialized && obj.numInstances > 0
                if ~obj.active && obj.scanModeIsResonant
                    deg = obj.hCtl.nextResonantFov() * obj.keepResonantScannerOn;
                    if obj.isPolygonalScanner
                        frequency_Hz = obj.hResonantScanner.nominalFrequency_Hz;
                        obj.hResonantScanner.setLineRate_Hz(frequency_Hz);
                    else
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
        
        function sz = get.defaultRoiSize(obj)
            if obj.scanModeIsLinear
                xRange = diff(obj.xGalvo.travelRange);
                yRange = diff(obj.yGalvo.travelRange);
                
                o = [0,0];
                x = [xRange/2,1];
                y = [1,yRange/2];
                
                oRef = scanimage.mroi.util.xformPoints(o,obj.scannerToRefTransform);
                xRef = scanimage.mroi.util.xformPoints(x,obj.scannerToRefTransform);
                yRef = scanimage.mroi.util.xformPoints(y,obj.scannerToRefTransform);
                
                xSz = norm(xRef-oRef)*2;
                ySz = norm(yRef-oRef)*2;
                
                sz = min( [xSz,ySz] );
            else
                scales = abs(obj.scannerToRefTransform([1 5]));
                xRange = obj.hResonantScanner.angularRange_deg;
                yRange = diff(obj.yGalvo.travelRange);
                sz = min([xRange yRange] .* scales);
            end
        end
        
        function rg = get.angularRange(obj)
            if obj.scanModeIsLinear
                x = diff(obj.xGalvo.travelRange);
            elseif obj.extendedRggFov && most.idioms.isValidObj(obj.xGalvo)
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
        
        function set.maskDisableDivide(obj,v)
            if obj.componentUpdateProperty('maskDisableDivide',v)
                validateattributes(v,{'numeric','logical'},{'binary'});
                obj.maskDisableDivide = v;
            end
        end
        
        function v = get.maskDisableDivide(obj)
            v = obj.maskDisableDivide;
            v(end+1:obj.channelsAvailable) = false;
            v(obj.channelsAvailable+1:end) = [];
        end
        
        function v = get.coercedFlybackTime(obj)
            v = obj.coercedTime(obj.flybackTimePerFrame);
        end
        
        function v = get.coercedFlytoTime(obj)
            v = obj.coercedTime(obj.flytoTimePerScanfield);
        end
        
        function set.scanMode(obj,v)
            if isempty(obj.scanMode)
                obj.scanMode = v;
                obj.scanModeIsResonant = strcmp(v,'resonant');
                obj.scanModeIsLinear = ~obj.scanModeIsResonant;
            elseif obj.numInstances && ~strcmp(v,obj.scanMode)
                switch v
                    case 'resonant'
                        assert(obj.hasResonantMirror,'Scanner ''%s'' does not support resonant scanning.', obj.name);
                    case 'linear'
                        assert(obj.hasXGalvo,'Scanner ''%s'' does not support linear scanning.', obj.name);
                    otherwise
                        error('Scan mode ''%s'' is not support by scanner ''%s''.', v, obj.name);
                end
                
                % cache current setting
                prevMode = obj.scanMode;
                if isfield(obj.scanModePropsToCache, prevMode)
                    propNames = obj.scanModePropsToCache.(prevMode);
                    for i = 1:numel(propNames)
                        propName = propNames{i};
                        s.(propName) = obj.(propName);
                    end
                    obj.scanModePropCache.(prevMode) = s;
                end
                
                obj.scanMode = v;
                obj.scanModeIsResonant = strcmp(v,'resonant');
                obj.scanModeIsLinear = ~obj.scanModeIsResonant;
                if obj.scanModeIsResonant
                    obj.sampleRateDecim = 1;
                    obj.sampleRateCtl = [];
                end
                
                % apply new settings
                obj.applyScanModeCachedProps();
                obj.parkScanner();
            end

            obj.supportsRoiRotation = obj.scanModeIsLinear;
        end
        
        function val = get.validSampleRates(obj)
            if obj.scanModeIsResonant
                val = obj.hAcq.rawAcqSampleRate;
            else
                val = min(20e6,obj.hAcq.stateMachineSampleRate ./ (1:1200));
            end
        end
        
        function v = get.lineScanSamplesPerFrame(obj)
            if obj.hSI.hRoiManager.isLineScan && isfield(obj.hAcq.acqParamBuffer, 'samplesPerFrame')
                v = obj.hAcq.acqParamBuffer.samplesPerFrame;
            else
                v = [];
            end
        end
        
        function v = get.lineScanFdbkSamplesPerFrame(obj)
            if obj.hSI.hRoiManager.isLineScan && isfield(obj.hAcq.acqParamBuffer, 'fdbkSamplesPerFrame')
                v = obj.hAcq.acqParamBuffer.fdbkSamplesPerFrame;
            else
                v = [];
            end
        end
        
        function v = get.lineScanNumFdbkChannels(obj)
            if obj.hSI.hRoiManager.isLineScan
                v = 2 + obj.hAcq.rec3dPath;
            else
                v = [];
            end
        end
        function v = get.virtualChannelSettings(obj)
            if isempty(obj.virtualChannelSettings)
                obj.loadVirtualChannelSettings();
            end
            
            v = obj.virtualChannelSettings;
        end
            
        function v = defaultVirtChanSettings(obj)
            if isempty(obj.hAcq) || isempty(obj.hAcq.hFpga) || isempty(obj.hAcq.hFpga.hAfe)
                N = 4;
            else
                N = obj.hAcq.hFpga.hAfe.physicalChannelCount;
            end
            
            for i = N:-1:1
                v(i).source = sprintf('AI%d',i-1);
                v(i).mode = 'analog';
                v(i).threshold = false;
                v(i).binarize = false;
                v(i).edgeDetect = false;
                v(i).laserGate = false;
                v(i).disableDivide = false;
                v(i).thresholdValue = 100;
                v(i).laserFilterWindow = [0 1];
            end
        end
        
        % TODO: make failures in this function more readable, especially within
        % validationFuncs. It can be hard to determine why things are failing
        function set.virtualChannelSettings(obj,v)
            ds = obj.defaultVirtChanSettings();
            lg1 = [];
            
            if isempty(v)
                v = ds;
            else
                nms = fieldnames(ds);

                % fix for when source is invalid because the default source contains channels not
                % available on the high speed vdaq:
                % TODO: something could probably be tidied so that this isn't necessary
                availableChans = arrayfun(@(i){sprintf('ai%d',i-1)},1:obj.physicalChannelsAvailable);
                for i = 1:numel(v)
                    if isempty(v(i).source) || ~ismember(lower(v(i).source),availableChans)
                        dsIdx = mod(i-1,numel(ds))+1;
                        v(i).source = ds(dsIdx).source;
                    end
                end
                
                validationFuncs.source = @(v)assert(ismember(lower(v),availableChans));
                validationFuncs.mode = @(v)assert(ismember(v,{'analog' 'photon counting'}));
                validationFuncs.threshold = @(v)validateattributes(v,{'numeric' 'logical'},{'scalar'});
                validationFuncs.binarize = @(v)validateattributes(v,{'numeric' 'logical'},{'scalar'});
                validationFuncs.edgeDetect = @(v)validateattributes(v,{'numeric' 'logical'},{'scalar'});
                validationFuncs.laserGate = @validateLaserGate;
                validationFuncs.disableDivide = @(v)validateattributes(v,{'numeric' 'logical'},{'scalar'});
                validationFuncs.thresholdValue = @(v)validateattributes(v,{'numeric'},{'scalar','integer','nonnegative','nonnan','finite'});
                validationFuncs.laserFilterWindow = @(v)validateattributes(v,{'numeric'},{'numel',2,'integer','nonnegative','nonnan','finite'});
                
                for i = 1:numel(nms)
                    f = nms{i};
                    
                    for j = 1:numel(v)
                        if j > numel(ds)
                            defVal = ds(1).(f);
                        else
                            defVal = ds(j).(f);
                        end
                        
                        v(j).(f) = validateVirtualChannelSetting(f,j,defVal);
                    end
                end
            end
            
            for i = 1:numel(v)
                s = v(i);
                
                if isempty(s.source)
                    s.source = 'AI0';
                else
                    assert(strncmp('AI',s.source,2), 'Source must be in the format AIx');
                end
                
                v(i) = s;
            end
            
            obj.virtualChannelSettings = v;
            
            if obj.hAcq.updateFilterClockParams()
                obj.sampleRate = nan;
            end
            
            function val = validateVirtualChannelSetting(fieldName,ch,defaultVal)
                if ~isfield(v,fieldName) || isempty(v(ch).(fieldName))
                    val = defaultVal;
                else
                    val = v(ch).(fieldName);
                    try
                        validationFuncs.(fieldName)(val);
                    catch
                        error('Invalid setting for ''%s'' for virtual channel %d',fieldName, ch);
                    end
                end
            end
            
            function validateLaserGate(v)
                validateattributes(v,{'numeric' 'logical'},{'scalar'});
                
                % unless this is high speed vDAQ and clock multiplier = 32, laser
                % gate setting must be the same for all channels
                % TODO: cleanup validation
                if isempty(lg1)
                    lg1 = v;
                elseif obj.hAcq.isH
                    assert(obj.externalSampleClockMultiplier == 32 || v == lg1, 'Laser gate setting must be the same for all channels unless externalSampleClockMultiplier = 32')
                end
            end
        end
        
        function set.laserTriggerDebounceTicks(obj,v)
            validateattributes(v,{'numeric'},{'scalar','integer','nonnegative','nonnan','finite'});
            obj.laserTriggerDebounceTicks = v;
            
            if obj.mdlInitialized && obj.hSI.hScan2D == obj
                obj.hTrig.applyTriggerConfig();
            end
        end
        
        % for legacy/simple mode support
        function v = get.laserTriggerSampleMaskEnable(obj)
            v = any([obj.virtualChannelSettings.laserGate]);
        end
        
        function set.laserTriggerSampleMaskEnable(obj,v)
            if obj.mdlInitialized && (obj.hSI.hScan2D == obj)
                ss = obj.virtualChannelSettings;
                for i = 1:numel(ss)
                    ss(i).laserGate = v;
                end
                obj.virtualChannelSettings = ss;
                obj.hAcq.applyVirtualChannelSettings();
            end
        end
        
        function v = get.laserTriggerSampleWindow(obj)
            wndos = reshape([obj.virtualChannelSettings.laserFilterWindow],2,[])';
            v = [min(wndos(:,1))-1 max(wndos(:,2))];
        end
        
        function set.laserTriggerSampleWindow(obj,v)
            if obj.mdlInitialized && (obj.hSI.hScan2D == obj)
                ss = obj.virtualChannelSettings;
                v(1) = v(1) + 1;
                for i = 1:numel(ss)
                    ss(i).laserFilterWindow = v;
                end
                obj.virtualChannelSettings = ss;
                obj.hAcq.applyVirtualChannelSettings();
            end
        end
        
        function set.photonDiscriminatorThresholds(obj,v)
            if ~isempty(obj.hAcq.hFpga)
                obj.hAcq.hFpga.hsPhotonThresholds = v;
            end
            obj.photonDiscriminatorThresholds = v;
        end
        
        function set.photonDiscriminatorModes(obj,v)
            if ~isempty(obj.hAcq.hFpga)
                [tf, idx] = ismember(v, {'threshold crossing' 'peak detect'});
                assert(all(tf), 'Invalid setting for photon detection mode.');
                obj.hAcq.hFpga.hsPhotonDifferentiate = logical(idx-1);
            end
            obj.photonDiscriminatorModes = v;
        end
        
        function set.photonDiscriminatorDifferentiateWidths(obj,v)
            if ~isempty(obj.hAcq.hFpga)
                obj.hAcq.hFpga.hsPhotonDifferentiateWidths = v;
            end
            obj.photonDiscriminatorDifferentiateWidths = v;
        end
        
        % flag which lets scanimage know whether to let the user select a custom laser
        % clock period in ticks or to just use the external sample clk multiplier
        function set.useCustomFilterClock(obj,v)
            try
                if isnumeric(v)
                    v = logical(v);
                end
                
                validateattributes(v,{'logical'},{'scalar'});
            catch ME
                most.ErrorHandler.logAndReportError(false,ME);
            end

            if most.idioms.isValidObj(obj.hAcq) && most.idioms.isValidObj(obj.hAcq.hFpga) && most.idioms.isValidObj(obj.hAcq.hAcqEngine)
                if v
                    % currently the custom laser filter clock should only be used with LRR support on the high speed vDAQ
                    assert(obj.hAcq.isH && obj.hAcq.hAcqEngine.HSADC_LRR_SUPPORT, 'Custom filter clock not supported.');
                    obj.useCustomFilterClock = true;
                else
                    obj.useCustomFilterClock = false;
                end

                if obj.mdlInitialized
                    obj.hAcq.updateFilterClockParams();
                end
            else
                % for when the saved settings in the GUIs are loading up, only has a true effect if LRR laser is enabled
                obj.useCustomFilterClock = v;
            end
        end

        % customFilterClockPeriod is the user specified laser clock period (in ticks) when the laser clock is a multiplied version of the actual laser rep rate
        % - it also holds the detected laser clock period when using the medium speed vDAQ and using a digital input terminal
        function set.customFilterClockPeriod(obj,v)
            try
                validateattributes(v,{'numeric'},{'nonnegative','integer','finite','scalar'});
            catch ME
                most.ErrorHandler.logAndReportError(false,ME);
            end

            obj.customFilterClockPeriod = v;
            
            if ~isempty(obj.hAcq) && obj.mdlInitialized
                obj.hAcq.updateFilterClockParams();
            end
        end
        
        function v = get.MAX_NUM_CHANNELS(obj)
            v = most.idioms.ifthenelse(obj.hAcq.isH, ...
                obj.hAcq.hAcqEngine.HS_MAX_NUM_LOGICAL_CHANNELS, ...
                obj.hAcq.hAcqEngine.MS_MAX_NUM_LOGICAL_CHANNELS);
        end
    end
    %%% Abstract method implementations (scanimage.components.Scan2D)
    % AccessXXX prop API for Scan2D
    methods (Access = protected, Hidden)
        function val = accessScannersetPostGet(obj,~)
            val = obj.getScannerset(obj.scanModeIsResonant,false);
        end
        
        function accessBidirectionalPostSet(obj,v)
            if obj.isPolygonalScanner && v
                obj.bidirectional = false;
%                 error('Bidirectional scanning is unsupported when using a polygonal Scanner');
            end
        end
        
        function val = accessStripingEnablePreSet(obj,val)
            % unsupported in resonant scanning
            val = val && obj.scanModeIsLinear;
        end
        
        function val = accessLinePhasePreSet(obj,val)
            if obj.scanModeIsResonant && ~obj.robotMode && obj.mdlInitialized
                % line phase is measured in seconds
                samples = round((val) * obj.hAcq.stateMachineLoopRate);
                val = samples / obj.hAcq.stateMachineLoopRate ; % round to closest possible value
                
                currentAmplitude_deg = obj.hResonantScanner.currentAmplitude_deg;
                if (currentAmplitude_deg > 0) && ~obj.internalPhaseUpdate
                    obj.hResonantScanner.addToAmplitudeToLinePhaseMap(currentAmplitude_deg,val);
                end
                obj.internalPhaseUpdate = false;
            end
        end        
        
        function accessLinePhasePostSet(obj)
            if obj.scanModeIsLinear
                if obj.active
                    obj.hAcq.updateBufferedPhaseSamples();
                    % regenerate beams output
                    obj.hSI.hBeams.updateBeamBufferAsync(true);
                end
            else
                obj.hAcq.fpgaUpdateLiveAcquisitionParameters('linePhaseSamples');
            end
        end 
        
        function val = accessLinePhasePostGet(obj,val)
            % no-op
        end
        
        function val = accessChannelsFilterPostGet(~,val)
            % no-op
        end
        
        function val = accessChannelsFilterPreSet(obj,val)
            if isempty(val) || ischar(val)
                if isempty(val) || ismember(val, {'none' 'bypass' 'fbw'})
                    val = nan;
                else
                    v = str2double(val);
                    
                    if isnan(v)
                        t = regexpi(val, '(\d*)\s*MHz', 'tokens');
                        assert(~isempty(t),'Invalid filter setting.');
                        val = str2double(t{1}{1});
                    else
                        val = v;
                    end
                end
            end
            
            assert(isnan(val) || ((val < 61) && (val > 0)), 'Invalid filter setting.');
            
            val = obj.hAcq.setChannelsFilter(val);
            
            if isnan(val)
                val = 'fbw';
            else
                val = sprintf('%d MHz',val);
            end
        end
        
        function accessBeamClockDelayPostSet(obj,~)
            if obj.scanModeIsLinear && obj.active
                obj.hSI.hBeams.updateBeamBufferAsync(true);
            end
        end
        
        function accessBeamClockExtendPostSet(obj,~)
            if obj.scanModeIsLinear && obj.active
                obj.hSI.hBeams.updateBeamBufferAsync(true);
            end
        end
        
        function accessChannelsAcquirePostSet(obj,~)
            obj.hAcq.flagResizeAcquisition = true;
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function val = accessChannelsInputRangesPreSet(obj,val)
            val = obj.hAcq.setChannelsInputRanges(val);
        end
        
        function val = accessChannelsInputRangesPostGet(~,val)
            %No-op
        end
        
        function val = accessChannelsAvailablePostGet(obj,~)
            val = numel(obj.virtualChannelSettings);
        end
        
        function val = accessPhysicalChannelsAvailablePostGet(obj)
            if isempty(obj.hAcq)
                val = 4;
            else
                val = obj.hAcq.physicalChannelCount;
            end
        end
        
        function val = accessChannelsAvailableInputRangesPostGet(obj,~)
            val = arrayfun(@(f){[-f f]},obj.hAcq.availableInputRanges/2);
        end
                     
        function val = accessFillFractionSpatialPreSet(obj,val)
            if obj.isPolygonalScanner
                pixelsPerLine_ = floor(obj.sampleRate/obj.scannerFrequency*val/obj.pixelBinFactor);
                if obj.hSI.hRoiManager.pixelsPerLine ~= pixelsPerLine_
                    obj.hSI.hRoiManager.pixelsPerLine = floor(obj.sampleRate/obj.scannerFrequency*val/obj.pixelBinFactor);
                end
            end
        end
                     
        function accessFillFractionSpatialPostSet(obj,~)
            if obj.scanModeIsResonant
                obj.hAcq.computeMask();
            end
        end
        
        function val = accessSettleTimeFractionPostSet(obj,val)
            obj.errorPropertyUnSupported('settleTimeFraction',val);
        end
        
        function val = accessFlytoTimePerScanfieldPostGet(obj,val)
            if obj.scanModeIsResonant
                mn = 1/obj.scannerFrequency;
            else
                mn = 1/obj.sampleRateCtl;
            end
            val = max(val, mn);
        end
        
        function val = accessFlybackTimePerFramePostGet(obj,val)
            if obj.scanModeIsResonant
                mn = 1/obj.scannerFrequency;
            else
                mn = 1/obj.sampleRateCtl;
            end
            val = max(val, mn);
        end
        
        function accessLogAverageFactorPostSet(~,~)
        end
        
        function accessLogFileCounterPostSet(~,~)
        end
        
        function accessLogFilePathPostSet(~,~)
        end
        
        function accessLogFileStemPostSet(~,~)
        end
        
        function accessLogFramesPerFilePostSet(~,~)
        end

        function accessLogFramesPerFileLockPostSet(~,~)
        end
        
        function val = accessLogNumSlicesPreSet(obj,val)
            obj.hAcq.loggingNumSlices = val;
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function val = accessTrigFrameClkOutInternalTermPostGet(obj,~)
            val = obj.hTrig.sliceClkTermInt;
        end
        
        function val = accessTrigBeamClkOutInternalTermPostGet(obj,~)
            val = obj.hTrig.beamClkTermInt;
        end
        
        function val = accessTrigAcqOutInternalTermPostGet(obj,~)
            val = '';
        end
        
        function val = accessTrigReferenceClkOutInternalTermPostGet(~,~)
            val = '';
        end
        
        function val = accessTrigReferenceClkOutInternalRatePostGet(~,~)
            val = 10e6;
        end
        
        function val = accessTrigReferenceClkInInternalTermPostGet(~,~)
            val = '';
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
            val = max(obj.validSampleRates);
        end
        
        function accessScannerFrequencyPostSet(~,~)
            % No op
        end
        
        function val = accessScannerFrequencyPostGet(~,val)
            % No op
        end

        function val = accessScanPixelTimeMeanPostGet(obj,~)
            if ~obj.active
                obj.hAcq.bufferAllSfParams();
                obj.hAcq.computeMask();
            end
            
            if obj.scanModeIsResonant
                val = (sum(obj.hAcq.mask(1:obj.hAcq.pixelsPerLine)) / obj.hAcq.stateMachineSampleRate) / obj.hAcq.pixelsPerLine;
            else
                val = obj.pixelBinFactor / obj.sampleRate;
            end
        end
        
        function val = accessScanPixelTimeMaxMinRatioPostGet(obj,~)
            if isnan(obj.scanPixelTimeMean)
                val = nan;
            elseif obj.scanModeIsResonant
                maxPixelSamples = double(max(obj.hAcq.mask));
                minPixelSamples = double(min(obj.hAcq.mask));
                val = maxPixelSamples / minPixelSamples;
            else
                val = 1;
            end
        end
        
        function val = accessChannelsAdcResolutionPostGet(obj,~)
            % bit resolution of the virtual channels
            val = obj.hAcq.hAcqEngine.bitResolution;
        end
        
        function val = accessChannelsDataTypePostGet(~,~)
            val = 'int16';
        end
        
        % Component overload function
        function val = componentGetActiveOverride(obj,~)
            val = obj.hAcq.acqRunning;
        end
        
        function val = accessScannerToRefTransformPreSet(obj,val)
            if obj.hasResonantMirror
                assert(~scanimage.mroi.util.isTransformRotating(val),'Scanner coordinate transform cannot contain rotational component.');
                assert(~scanimage.mroi.util.isTransformShearing(val),'Scanner coordinate transform cannot contain shearing component.');
                assert(~scanimage.mroi.util.isTransformPerspective(val),'Scanner coordinate transform cannot contain perspective component.');
            end
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
        
        function pointScannerRef(obj,ptXY)
            validateattributes(ptXY,{'numeric'},{'size',[1,2],'nonnan','finite','real'});
            ptXY = scanimage.mroi.util.xformPoints(ptXY,obj.scannerToRefTransform,true);
            obj.pointScanner(0,ptXY);
        end
        
        function pointScanner(obj,fastDeg,slowDeg)
            % pointScanner moves the scanner to the defined angles (in degrees)
            %
            %   obj.pointScanner(fastDeg,slowDeg)   activates the resonant scanner with amplitude 'fastDeg' and points the galvo scanner to position 'slowDeg'
            %           slowDeg can be scalar (y-galvo only) or a 1x2 array [xGalvoDegree, yGalvoDegree]
            
            % points the XY scanner to a position (units: degree)
            if obj.componentExecuteFunction('pointScanner',fastDeg,slowDeg)
                if most.idioms.isValidObj(obj.hResonantScanner)
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
            
            if obj.componentExecuteFunction('centerScanner')
                if obj.hasResonantMirror
                    obj.hResonantScanner.park();
                end
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
                if obj.mdlInitialized && obj.hasResonantMirror
                    if obj.scanModeIsLinear
                        if most.idioms.isValidObj(obj.hResonantScanner)
                            obj.hResonantScanner.park();
                        end
                    elseif ~obj.keepResonantScannerOn
                        obj.hResonantScanner.park();
                    end
                end
            end
        end
        
        function updateLiveValues(obj,regenAO,waveforms)
            % updateLiveValues updates the scanner output waveforms after
            %       scan parameters have changed
            %
            %   obj.updateLiveValues()          regenerates the output waveforms and updates the output buffer
            %   obj.updateLiveValues(regenAO)   if regenAO == true regenerates the output waveforms, then updates the output buffer
            
            if nargin < 2 || isempty(regenAO)
                regenAO = true;
            end
            
            if nargin < 3
                waveforms = 'RGBZ';
            end
            
            obj.hCtl.updateLiveValues(regenAO,waveforms);
            
            if obj.active && strcmpi(obj.hSI.acqState,'focus')
                estimateLinePhase();
                obj.hAcq.bufferAcqParams(true);
            end
            
            function estimateLinePhase()
                if obj.scanModeIsResonant && ~obj.isPolygonalScanner
                    amplitude_deg = obj.hResonantScanner.currentAmplitude_deg;
                    val = obj.hResonantScanner.estimateLinePhase(amplitude_deg);
                    obj.internalPhaseUpdate = true;
                    obj.linePhase = val;
                end
            end
        end
        
        function updateSliceAO(obj)
            % updateSliceAO updates the scan paramters during a slow-z
            %    stack and refreshes the output waveforms
            %
            %  obj.updateSliceAO()
            
            obj.hCtl.updateLiveValues(false);
        end
    end
    
    %%% Resonant scanning specific methods
    methods        
        function resFreq = measureScannerFrequency(obj)
            % measureScannerFrequency activates the resonant scanner with
            %   the currently selected amplitude and measures the resonant
            %   frequency
            %
            %   resFreq = obj.measureScannerFrequency()   returns the measured resonant frequency
            
            if obj.componentExecuteFunction('measureScannerFrequency')
                obj.hTrig.applyTriggerConfig();
                
                if obj.isPolygonalScanner
                    hPolyScnr = obj.hResonantScanner;
                    frequencyWasZero = hPolyScnr.currentCommandedLineRate_Hz == 0;
                    if frequencyWasZero
                        lineRate = hPolyScnr.nominalFrequency_Hz;
                        hPolyScnr.setLineRate_Hz(lineRate);
                    end
                    scannerWasParked = frequencyWasZero;
                else
                    amplitudeWasZero = obj.hResonantScanner.currentAmplitude_deg == 0;
                    if amplitudeWasZero
                        obj.hResonantScanner.setAmplitude(obj.hCtl.nextResonantFov);
                    end
                    scannerWasParked = amplitudeWasZero;
                end
                
                obj.hResonantScanner.waitSettlingTime();
                 
                %update parameters
                period = obj.hAcq.stateMachineLoopRate / obj.hResonantScanner.nominalFrequency_Hz;
                obj.hAcq.hAcqEngine.acqParamPeriodTriggerMaxPeriod = floor(period*1.1);
                obj.hAcq.hAcqEngine.acqParamPeriodTriggerMinPeriod = floor(period*0.9);
                

                if obj.isPolygonalScanner
                    frequency = obj.hResonantScanner.currentCommandedLineRate_Hz;
                    fprintf('Measuring scanner frequency at commanded frequency %g Hz ...\n',frequency);
                else
                    amplitude = obj.hResonantScanner.currentAmplitude_deg;
                    fprintf('Measuring scanner frequency at amplitude %.3f deg (peak-peak)...\n',amplitude);
                end
                
                
                %Need time after setting min and max period on vDAQ.
                pause(1);

                resFreq = obj.hAcq.calibrateResonantScannerFreq();
                
                if scannerWasParked
                    obj.hResonantScanner.park()
                end
                
                if isnan(resFreq)
                    most.idioms.dispError('Failed to read scanner frequency. Period clock pulses not detected.\nVerify zoom control/period clock wiring and MDF settings.\n');
                else
                    fprintf('Scanner Frequency calibrated: %.2fHz\n',resFreq);
                    if ~obj.isPolygonalScanner
                        obj.hResonantScanner.addToAmplitudeToFrequencyMap(amplitude,resFreq);
                    end
                    obj.hResonantScanner.currentFrequency_Hz = resFreq;
                    
                    if ~obj.active
                        %Side-effects
                        obj.scannerFrequency = resFreq;
                        obj.hAcq.computeMask();
                        obj.fillFractionSpatial = obj.fillFractionSpatial; %trigger update
                    end
                end
            end
        end
    end
    
    %% FRIEND METHODS
    methods (Hidden)
        function ss = getScannerset(obj, enableResonant, forStim)
            % Determine flyback time per frame
            if enableResonant
                flybackTimeDiv = obj.scannerFrequency;
                
                % Define Resonant Scanning Hardware.
                
                scannerPeriod = 1/obj.scannerFrequency;
                
                r = scanimage.mroi.scanners.Resonant(...
                    obj.hResonantScanner,...
                    scannerPeriod,...
                    obj.bidirectional,...
                    obj.fillFractionSpatial);
            else
                flybackTimeDiv = obj.sampleRateCtl;
            end
            
            if obj.hSI.hStackManager.isFastZ && strcmp(obj.hSI.hFastZ.waveformType, 'step')
                Nsteps = ceil(obj.hSI.hFastZ.flybackTime * flybackTimeDiv);
                flybackTime = max(obj.coercedFlybackTime, Nsteps / flybackTimeDiv);
            else
                flybackTime = obj.coercedFlybackTime;
            end
            
            if forStim
                ctlFs = 1e6;
            else
                ctlFs = obj.sampleRateCtl;
            end
            
            % Define X-Galvo Scanning Hardware.
            xGalvoScanner = [];
            if most.idioms.isValidObj(obj.xGalvo)
                xGalvoScanner = scanimage.mroi.scanners.Galvo(obj.xGalvo);
                xGalvoScanner.flytoTimeSeconds = obj.coercedFlytoTime;
                xGalvoScanner.flybackTimeSeconds = flybackTime;
                xGalvoScanner.sampleRateHz = ctlFs;
            end
            
            % Define Y-Galvo Scanning Hardware.
            assert(most.idioms.isValidObj(obj.yGalvo),'yGalvo is not defined in machine data file');
            yGalvoScanner = scanimage.mroi.scanners.Galvo(obj.yGalvo);
            yGalvoScanner.flytoTimeSeconds = obj.coercedFlytoTime;
            yGalvoScanner.flybackTimeSeconds = flybackTime;
            yGalvoScanner.sampleRateHz = ctlFs;
            
            % Define beam hardware
            [fastBeams, slowBeams] = obj.hSI.hBeams.wrapBeams(obj.hBeams);
            for idx = 1:numel(fastBeams)
                fastBeams(idx).sampleRateHz = ctlFs;
                fastBeams(idx).linePhase = obj.linePhase;
                fastBeams(idx).beamClockDelay = obj.beamClockDelay;
                fastBeams(idx).beamClockExtend = obj.beamClockExtend;
                fastBeams(idx).includeFlybackLines = true;
                
                if obj.hSI.hRoiManager.isLineScan
                    fastBeams(idx).powerBoxes = [];
                end
            end
            
            % Define fastz hardware
            fastZScanners = obj.hSI.hFastZ.wrapFastZs(obj.hFastZs);
            for idx = 1:numel(fastZScanners)
                fastZScanners(idx).sampleRateHz = ctlFs;
            end
            
            if enableResonant
                % Create resonant galvo galvo scannerset using hardware descriptions above
                ss=scanimage.mroi.scannerset.ResonantGalvoGalvo(obj.name,r,xGalvoScanner,yGalvoScanner,fastBeams, slowBeams,fastZScanners,obj.fillFractionSpatial);
                ss.useScannerTimebase = obj.hCtl.useScannerSampleClk;
                ss.extendedRggFov = obj.extendedRggFov && most.idioms.isValidObj(obj.xGalvo);
            else
                % Create galvo galvo scannerset using hardware descriptions above
                stepY = false; % ????????
                ss = scanimage.mroi.scannerset.GalvoGalvo(obj.name,xGalvoScanner,yGalvoScanner,fastBeams,slowBeams, fastZScanners,...
                    obj.fillFractionSpatial,obj.pixelBinFactor/obj.sampleRate,obj.bidirectional,stepY,0);
                ss.acqSampleRate = obj.sampleRate;
            end
            
            ss.hCSSampleRelative = obj.hSI.hMotors.hCSSampleRelative;
            ss.hCSReference = obj.hSI.hCoordinateSystems.hCSReference;
            ss.beamRouters = obj.hSI.hBeams.hBeamRouters;
            ss.objectiveResolution = obj.hSI.objectiveResolution;
        end
    end
    
    %% INTERNAL METHODS
    methods (Hidden)
        function reinitRoutes(obj)
            obj.hTrig.reinitRoutes();
        end
        
        function deinitRoutes(obj)
            if (~obj.simulated)
                obj.hAcq.hAcqFifo.close();
                obj.hAcq.hAuxFifo.close();
            end
            obj.hTrig.deinitRoutes();
        end
        
        function frameAcquiredFcn(obj)
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
        
        function applyScanModeCachedProps(obj)
            if isfield(obj.scanModePropCache, obj.scanMode)
                s = obj.scanModePropCache.(obj.scanMode);
                propNames = fieldnames(s);
                for i = 1:numel(propNames)
                    propName = propNames{i};
                    obj.(propName) = s.(propName);
                end
            end
            
            if obj.scanModeIsResonant
                if obj.isPolygonalScanner
                    obj.uniformSampling = true;
                    obj.bidirectional = false;
                else
                    obj.uniformSampling = false;
                    obj.bidirectional = true;
                end
                
                v = obj.hCtl.nextResonantFov();
                obj.internalPhaseUpdate = true;
                if ~obj.isPolygonalScanner
                    obj.linePhase = obj.hResonantScanner.estimateLinePhase(v);
                end
            end
        end
        
        function v = coercedTime(obj,v)
            if obj.scanModeIsResonant
                mult = 2 - obj.bidirectional;
                timeDiv = obj.scannerFrequency / mult;
                Nsteps = ceil(v * timeDiv);
                v = Nsteps / timeDiv;
            else
                % need a duration that evenly divides into ctl and acq sample rates
                ctlTicks = round(v * obj.sampleRateCtl);
                rng = max(round([.9 1.1] * ctlTicks),1);
                
                timebaseTicks = (rng(1):rng(end)) * obj.sampleRateCtlDecim;
                acqTicks = timebaseTicks / obj.sampleRateDecim;
                validRates = acqTicks == round(acqTicks);
                times = acqTicks(validRates) / obj.sampleRate;
                
                dt = abs(times-obj.flybackTimePerFrame);
                [~,ii] = min(dt);
                v = times(ii);
            end
        end
    end
    
    %%% Abstract methods realizations (scanimage.interfaces.Scan2D)    
    methods (Hidden)
        function arm(obj)
            if obj.scanModeIsResonant
                resAmplitude = obj.hCtl.nextResonantFov;
                
                if resAmplitude > 0
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
                    
                    obj.internalPhaseUpdate = true;
                    if ~obj.isPolygonalScanner
                        obj.linePhase = obj.hResonantScanner.estimateLinePhase(resAmplitude);
                    end
                end
            elseif obj.hasResonantMirror
                 obj.hResonantScanner.park();
                
                if ~obj.hSI.hRoiManager.isLineScan 
                    assert(obj.ctlRateGood, 'Could not find a scanner control rate fitting the desired scan parameters. Try adjusting the acq sample rate or ROI pixel counts.');
                end
            end
            
            obj.hAcq.bufferAcqParams();
        end
        
        function data = acquireSamples(obj,numSamples)
            if obj.componentExecuteFunction('acquireSamples',numSamples)
                obj.channelsInvert = obj.channelsInvert; % apply channels Invert
                N = obj.physicalChannelsAvailable;
                data = zeros(numSamples,N,obj.channelsDataType); % preallocate data
                for i = 1:numSamples
                    data(i,:) = obj.hAcq.rawAdcOutput(1,1:N);
                end
            end
        end
        
        function zzFeedbackDataAcquiredCallback(obj, data, numFrames, nSamples, lastFrameStartIdx)
            if numFrames
                obj.lastFramePositionData = data(lastFrameStartIdx:end,:);
            else
                obj.lastFramePositionData(lastFrameStartIdx:lastFrameStartIdx+nSamples-1,:) = data;
            end
            obj.hSI.hDisplay.updatePosFdbk();
        end
        
        function signalReadyReceiveData(obj)
            % no-op
        end
                
        function [success,stripeData] = readStripeData(obj)
            % remove the componentExecute protection for performance
            %if obj.componentExecuteFunction('readStripeData')
                [success,stripeData] = obj.hAcq.readStripeData();
                if ~isempty(stripeData) && stripeData.endOfAcquisitionMode
                    obj.abort(); %self abort if acquisition is done
                end
            %end
        end
        
        function newPhase = calibrateLinePhase(obj)
            if obj.scanModeIsLinear
                roiDatas = obj.hSI.hDisplay.lastStripeData.roiData;
                if ~isempty(roiDatas)
                    for ir = numel(roiDatas):-1:1
                        im = vertcat(roiDatas{ir}.imageData{:});
                        
                        if roiDatas{ir}.transposed
                            im = cellfun(@(imt){imt'},im);
                        end
                        
                        imData{ir,1} = vertcat(im{:});
                    end
                    
                    if numel(unique(cellfun(@(d)size(d,2),imData)))
                        imData = imData{1};
                    else
                        imData = vertcat(imData{:});
                    end
                    
                    if ~isempty(imData)
                        [im1,im2] = deinterlaceImage(imData);
                        [~,pixelPhase] = detectPixelOffset(im1,im2);
                        samplePhase = obj.pixelBinFactor * pixelPhase;
                        phaseOffset = samplePhase / obj.sampleRate;
                        obj.linePhase = obj.linePhase - phaseOffset / 2;
                    end
                end
            else
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
            end
            
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
            
            function [im1, im2] = deinterlaceImage(im)
                im1 = im(1:2:end,:);
                im2 = im(2:2:end,:);
            end
            
            function [iOffset,jOffset] = detectPixelOffset(im1,im2)
                numLines = min(size(im1,1),size(im2,1));
                im1 = im1(1:numLines,:);
                im2 = im2(1:numLines,:);

                c = real(most.mimics.xcorr2circ(single(im1),single(im2)));
                cdim = size(c);
                [~,idx] = max(c(:));
                [i,j] = ind2sub(cdim,idx);
                iOffset = floor((cdim(1)/2))+1-i;
                jOffset = floor((cdim(2)/2))+1-j;
            end
        end
    end
    
    %%% Abstract methods realizations (scanimage.interfaces.Component)
    methods (Access = protected, Hidden)
        function mdlInitialize(obj)
            obj.scanModePropCache = defaultModeProps();
            obj.applyScanModeCachedProps();
            
            mdlInitialize@scanimage.components.Scan2D(obj);
            obj.hAcq.ziniPrepareFeedbackTasks();
            obj.hPixListener = most.ErrorHandler.addCatchingListener(obj.hSI.hRoiManager, 'pixPerLineChanged',@updateCtlSampRate);
            
            function updateCtlSampRate(varargin)
                if obj.hSI.hScan2D == obj
                    obj.sampleRateCtl = [];
                end
            end
            
            function s = defaultModeProps()
                lsr = 2e6 + 5e5*obj.hAcq.hFpga.isR1;
                s.linear = struct('sampleRate', lsr, 'pixelBinFactor', 8, 'flybackTimePerFrame', obj.defaultFlybackTimePerFrame, 'flytoTimePerScanfield', obj.defaultFlytoTimePerScanfield,...
                    'fillFractionSpatial', .9, 'stripingEnable', true, 'linePhase', 0);
                s.resonant = struct('pixelBinFactor', 1, 'flybackTimePerFrame', obj.defaultFlybackTimePerFrame, 'flytoTimePerScanfield', obj.defaultFlytoTimePerScanfield, ...
                    'fillFractionSpatial', .9, 'bidirectional', true, 'stripingEnable', false, 'linePhase', 0);
            end
        end

        function componentStart(obj)
            assert(~obj.robotMode);
            
            obj.validateConfiguration();
            
            obj.independentComponent = false;
            obj.totalFrameAcqFcnTime = 0;
            obj.totalDispUpdates = 0;
            obj.totalDispUpdateTime = 0;
            
            if ~obj.scanModeIsResonant && obj.parkSlmForAcquisition
                obj.pointSlm();
            end
            
            obj.hTrig.start();
            obj.hCtl.start();
            obj.hAcq.start();
            
            if obj.scanModeIsResonant
                obj.hResonantScanner.waitSettlingTime();
            end
        end
        
        function componentAbort(obj,soft)
            if nargin < 2 || isempty(soft)
                soft = false;
            end
            
            obj.hAcq.abort();
            obj.hCtl.stop(soft);
            obj.hTrig.stop();
            
            if ~obj.scanModeIsResonant && obj.parkSlmForAcquisition
                obj.parkSlm();
            end
            
            obj.independentComponent = true;
        end
        
        function pointSlm(obj)
            if most.idioms.isValidObj(obj.hSlmScan)
                hCS = obj.hSlmScan.hCSCoordinateSystem.hParent;
                hPt = scanimage.mroi.coordinates.Points(hCS,[0,0,0]);
                obj.hSlmScan.pointSlm(hPt);
            end
        end  
        
        function parkSlm(obj)
            if most.idioms.isValidObj(obj.hSlmScan)
                try
                    obj.hSlmScan.parkScanner();
                catch
                end
            end
        end
        
        function fillFracTemp = fillFracSpatToTemp(obj,fillFracSpat)
            if obj.scanModeIsResonant
                if obj.isPolygonalScanner
                    fillFracTemp = fillFracSpat;
                else
                    fillFracTemp = 2/pi * asin(fillFracSpat);
                end
            else
                fillFracTemp = fillFracSpat;
            end
        end
        
        function fillFracSpat = fillFracTempToSpat(obj,fillFracTemp)
            if obj.scanModeIsResonant && ~obj.isPolygonalScanner
                fillFracSpat = cos( (1-fillFracTemp) * pi/2 );
            else
                fillFracSpat = fillFracTemp;
            end
        end
    end          
end

function s = defaultMdfSection()
    s = [...
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('acquisitionDeviceId','vDAQ0','RDI Device ID')...
        most.HasMachineDataFile.makeEntry('acquisitionEngineIdx',1)...
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('resonantScanner','','Name of the resonant scanner')...
        most.HasMachineDataFile.makeEntry('xGalvo','','Name of the x galvo scanner')...
        most.HasMachineDataFile.makeEntry('yGalvo','','Name of the y galvo scanner')...
        most.HasMachineDataFile.makeEntry('beams',{{}},'beam device names')...
        most.HasMachineDataFile.makeEntry('fastZs',{{}},'fastZ device names')...
        most.HasMachineDataFile.makeEntry('shutters',{{}},'shutter device names')...        
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('channelsInvert',false,'Logical: Specifies if the input signal is inverted (i.e., more negative for increased light signal)')...
        most.HasMachineDataFile.makeEntry('keepResonantScannerOn',false,'Always keep resonant scanner on to avoid drift and settling time issues')...
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('externalSampleClock',false,'Logical: use external sample clock connected to the CLK IN terminal of the FlexRIO digitizer module')...
        most.HasMachineDataFile.makeEntry('externalSampleClockRate',80e6,'[Hz]: nominal frequency of the external sample clock connected to the CLK IN terminal (e.g. 80e6); actual rate is measured on FPGA')...
        most.HasMachineDataFile.makeEntry('externalSampleClockMultiplier',1,'Multiplier to apply to external sample clock')...
        most.HasMachineDataFile.makeEntry('useCustomFilterClock',false,'')...
        most.HasMachineDataFile.makeEntry('customFilterClockPeriod',1,'')...
        most.HasMachineDataFile.makeEntry('sampleClockPhase',[],'Phase delay to apply to sample clock')...
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('extendedRggFov',false,'If true and x galvo is present, addressable FOV is combination of resonant FOV and x galvo FOV.')...
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('Advanced/Optional')... % comment only
        most.HasMachineDataFile.makeEntry('PeriodClockDebounceTime', 100e-9,'[s] time the period clock has to be stable before a change is registered')...
        most.HasMachineDataFile.makeEntry('TriggerDebounceTime', 500e-9,'[s] time acquisition, stop and next trigger to be stable before a change is registered')...
        most.HasMachineDataFile.makeEntry('reverseLineRead', false,'flips the image in the resonant scan axis')...
        most.HasMachineDataFile.makeEntry('defaultFlybackTimePerFrame',1e-3,'[s] default time to allow galvos to fly back after one frame is complete. overridden by cfg file')...
        most.HasMachineDataFile.makeEntry('defaultFlytoTimePerScanfield',1e-3,'[s] time to allow galvos to fly from one scanfield to the next. overridden by cfg file')...
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('Aux Trigger Recording, Photon Counting, and I2C are mutually exclusive')...
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('Aux Trigger Recording')... % comment only
        most.HasMachineDataFile.makeEntry('auxTriggersTimeDebounce', 1e-7,'[s] time after an edge where subsequent edges are ignored')...
        most.HasMachineDataFile.makeEntry('auxTriggerLinesInvert', false(1,4), '[logical] 1x4 vector specifying polarity of aux trigger inputs')...
        most.HasMachineDataFile.makeEntry('auxTrigger1In', '', 'Digital input lines for aux trigger 1')...
        most.HasMachineDataFile.makeEntry('auxTrigger2In', '', 'Digital input lines for aux trigger 2')...
        most.HasMachineDataFile.makeEntry('auxTrigger3In', '', 'Digital input lines for aux trigger 3')...
        most.HasMachineDataFile.makeEntry('auxTrigger4In', '', 'Digital input lines for aux trigger 4')...
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('Signal Conditioning')... % comment only
        most.HasMachineDataFile.makeEntry('disableMaskDivide', false,'disable averaging of samples into pixels; instead accumulate samples')...
        most.HasMachineDataFile.makeEntry('photonDiscriminatorThresholds', [500 500])...
        most.HasMachineDataFile.makeEntry('photonDiscriminatorModes', {{'threshold crossing' 'threshold crossing'}})...
        most.HasMachineDataFile.makeEntry('photonDiscriminatorDifferentiateWidths', [4 4])...
        most.HasMachineDataFile.makeEntry('enableHostPixelCorrection', false)...
        most.HasMachineDataFile.makeEntry('hostPixelCorrectionMultiplier', 500)...
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('I2C')... % comment only
        most.HasMachineDataFile.makeEntry('i2cEnable', false)...
        most.HasMachineDataFile.makeEntry('i2cSdaPort', '')...
        most.HasMachineDataFile.makeEntry('i2cSclPort', '')...
        most.HasMachineDataFile.makeEntry('i2cAddress', uint8(0),'[byte] I2C address of the FPGA')...
        most.HasMachineDataFile.makeEntry('i2cDebounce', 100e-9,'[s] time the I2C signal has to be stable high before a change is registered')...
        most.HasMachineDataFile.makeEntry('i2cStoreAsChar', false,'if false, the I2C packet bytes are stored as a uint8 array. if true, the I2C packet bytes are stored as a string. Note: a Null byte in the packet terminates the string')...
        most.HasMachineDataFile.makeEntry('i2cSendAck', true, 'When enabled FPGA confirms each packet with an ACK bit by actively pulling down the SDA line')...
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('Laser Trigger')... % comment only
        most.HasMachineDataFile.makeEntry('LaserTriggerPort', '','Digital input where laser trigger is connected.')...
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('Trigger Outputs')...
        most.HasMachineDataFile.makeEntry('frameClockOut', '', 'Output line for the frame clock')...
        most.HasMachineDataFile.makeEntry('lineClockOut', '', 'Output line for the line clock')...
        most.HasMachineDataFile.makeEntry('beamModifiedLineClockOut', '', 'Output line for beam clock')...
        most.HasMachineDataFile.makeEntry('volumeTriggerOut', '', 'Output line for the volume clock')...
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('Calibration data')...
        most.HasMachineDataFile.makeEntry('scannerToRefTransform',eye(3),'')...
        most.HasMachineDataFile.makeEntry('LaserTriggerDebounceTicks', 1)...
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
