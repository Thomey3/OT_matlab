classdef LinScan < scanimage.components.Scan2D & most.HasMachineDataFile & dabs.resources.configuration.HasConfigPage
    properties (SetAccess=protected,Hidden)
        ConfigPageClass = 'dabs.resources.configuration.resourcePages.LinScanPage';
    end
    
    methods (Static)
        function names = getDescriptiveNames()
            names = {'LinScan'};
        end
    end
    
    %% ABSTRACT PROPERTY REALIZATION (most.Model)
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = zlclAppendDependsOnPropAttributes(scanimage.components.Scan2D.scan2DPropAttributes());
        mdlHeaderExcludeProps = {'xGalvo' 'yGalvo' 'hFastZ' 'hShutters' 'hBeams' 'channelsAvailableInputRanges'};
    end
    
    %% Abstract property realizations (most.HasMachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'LinScan';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp; %#ok<MCCPI>
        mdfPropPrefix; %#ok<MCCPI>
        
        mdfDefault = defaultMdfSection();
    end
    
    %% ABSTRACT PROPERTY REALIZATION (scanimage.interfaces.Component)
    properties (SetAccess = protected, Hidden)
        numInstances = 0;
    end
    
    properties (Constant, Hidden)
        COMPONENT_NAME = 'LinScan';                  % [char array] short name describing functionality of component e.g. 'Beams' or 'FastZ'
    
        PROP_TRUE_LIVE_UPDATE = {'linePhase','beamClockDelay','logFileCounter','channelsAutoReadOffsets'};        % Cell array of strings specifying properties that can be set while the component is active
        PROP_FOCUS_TRUE_LIVE_UPDATE = {};   % Cell array of strings specifying properties that can be set while focusing
        DENY_PROP_LIVE_UPDATE = {'framesPerAcq','framesPerStack','trigAcqTypeExternal',...   % Cell array of strings specifying properties for which a live update is denied (during acqState = Focus)
            'trigAcqTypeExternal','trigNextStopEnable','trigAcqInTerm',...
            'trigNextInTerm','trigStopInTerm','trigAcqEdge','trigNextEdge',...
            'trigStopEdge','stripeAcquiredCallback','logAverageFactor','logFilePath',...
            'logFileStem','logFramesPerFile','logFramesPerFileLock','logNumSlices'};
        
        FUNC_TRUE_LIVE_EXECUTION = {'readStripeData','trigIssueSoftwareAcq','updateLiveValues',...
            'trigIssueSoftwareNext','trigIssueSoftwareStop','measureScannerFrequency'};  % Cell array of strings specifying functions that can be executed while the component is active
        FUNC_FOCUS_TRUE_LIVE_EXECUTION = {}; % Cell array of strings specifying functions that can be executed while focusing
        DENY_FUNC_LIVE_EXECUTION = {'centerScanner','pointScanner','parkScanner','acquireSamples'}; % Cell array of strings specifying functions for which a live execution is denied (during acqState = Focus)
    end
    
    %% Abstract property realizations (scanimage.subystems.Scan2D)
    properties (Hidden, Constant)
        builtinFastZ = false;
    end
    
    properties (SetAccess = protected)
        scannerType = 'GG';
        hasXGalvo = true;                   % logical, indicates if scanner has a X galvo mirror
        hasResonantMirror = false;          % logical, indicates if scanner has a resonant mirror
        isPolygonalScanner = false;          % logical, indicates if scanner has a polygonal mirror
    end
    
    properties (Constant, Hidden)
        linePhaseUnits = 'seconds';
    end
    
    properties (SetObservable)
        pixelBinFactor = 4;                 % number of acquisition samples that form one pixel, only applicable in LinScan
        sampleRate = 1.25e6;                % [Hz] sample rate of the digitizer / mirror controls
        sampleRateCtl;                      % [Hz] sample rate of the XY Galvo control task
        recordScannerFeedback = false;     % for line scanning, indicates if galvo position feedback should be monitored and recorded to disk
        sampleRateFdbk = 50e3;  % sample rate to record galvo positions at during line scanning
        
        scanMode = 'linear';
        maskDisableAveraging = false;
    end
    
    properties (SetObservable, Transient)
        channelOffsets;
        laserTriggerPort;
        laserTriggerSampleMaskEnable;
        laserTriggerSampleWindow;
        laserTriggerDebounceTicks;
        
        stripingMaxRate = 10;
        maxDisplayRate = 30;
    end
    
    properties (SetObservable, Hidden)
        keepResonantScannerOn = false;
        xGalvo = dabs.resources.Resource.empty();
        yGalvo = dabs.resources.Resource.empty();
        uniformSampling = true;
    end
    
    properties (Hidden, Dependent, SetAccess = protected, Transient) % SI internal properties, not SetObservable
        linePhaseStep;                       % [s] minimum step size of the linephase
        trigNextStopEnableInternal;
    end
    
    properties (Transient,SetObservable)
        hDAQAcq = dabs.resources.Resource.empty();
        hDAQAux = dabs.resources.Resource.empty();
        hFastZs = {};
        hShutters = {};
        hBeams = {};
        hDataScope = [];
        channelIDs;
        channelsInvert;

        
        externalSampleClock = false;
        externalSampleClockRate = 80e6;
    end
    
    properties (Hidden, SetAccess = protected)
        defaultRoiSize;
        angularRange;
        supportsRoiRotation = true;
    end
    
    properties (Dependent, SetAccess = protected)
        % data that is useful for line scanning meta data
        lineScanSamplesPerFrame;
        lineScanFdbkSamplesPerFrame;
        lineScanNumFdbkChannels;
    end
    
    %% Class specific properties
    properties (Hidden)
        logFilePerChannel = false;           % boolean, if true, each channel is saved to a separate file
        lastFramePositionData = [];
        hPixListener;
        
        controllingFastZ;
        validSampleRates;
        
        laserTriggerFilterSupport = false;
        laserTriggerDemuxSupport = false;
    end
    
    properties (Constant, Hidden)
        MAX_NUM_CHANNELS = 4;               % Maximum number of channels supported
        MAX_REQUESTED_CTL_RATE = 250e3      % [Hz] if acquisition sample rate and galvo output rate are independent, limit the galvo output rate to this value
        MAX_FDBK_RATE = 125e3;              % [Hz] limit the galvo feedback sampling rate for line scanning to this value
    end
    
    properties (Hidden, SetAccess = private)
        maxSampleRateCtl;                   % [Hz] maximum sample rate achievable by the XY Galvo control task
    end
    
    properties (Hidden, SetAccess = immutable)
        hAcq;                               % handle to image acquisition system
        hCtl;                               % handle to galvo control system
        hTrig;                              % handle to trigger system
        hLinScanLog;                        % handle to logging system
    end
    
    properties (Hidden, SetAccess = private)
        clockMaster;                        % {'auxiliary','controller'} specifies which board generates the sample clock/controlls the triggering
        linkedSampleClkAcqCtl;              % logical, indicates if the Acquisition AI and the Controller AO use the same sample clock
        
        epochAcqMode;                       % software timestamp taken at the first captured stripe in the acqMode
        epochAcq;                           % [s] time difference between epochAcqMode and start of current acquistion
        acqCounter = 0;                     % number of finished acquisitions since start of acquisition mode    
        frameCounter = 0;                   % frames acquired since start of acquisition mode
        lastAcquiredFrame;                  % buffers the last acquired frame
        lastDisplayTic = tic();             % last time (tic) when the frame was sent to ScanImage for display
        
        trigStartSoftwareTimestamp;         
        trigNextSoftwareTimestamp;
        trigStopSoftwareTimestamp;
        
        % property bufferes
        channelsAvailable_;
        channelsDataType_;
    end
    
    %% Lifecycle
    methods
        function obj = LinScan(name)
            % LinScan constructor for scanner object
            %  obj = LinScan(name)
            obj = obj@scanimage.components.Scan2D(name);
            obj = obj@most.HasMachineDataFile(true);
            
            obj.hCtl = scanimage.components.scan2d.linscan.Control(obj);
            obj.hAcq = scanimage.components.scan2d.linscan.Acquisition(obj);
            obj.hTrig = scanimage.components.scan2d.linscan.Triggering(obj);
            obj.hLinScanLog = scanimage.components.scan2d.linscan.Logging(obj);
            
            obj.numInstances = 1; % some properties won't set correctly if numInstances == 0 (e.g. scannerToRefTransform)
            obj.loadMdf();
        end
        
        function validateConfiguration(obj)            
            try
                assert(most.idioms.isValidObj(obj.hDAQAcq),'No valid acquisition device specified');
                if isa(obj.hDAQAcq,'dabs.resources.daqs.NIRIO')
                    assert(most.idioms.isValidObj(obj.hDAQAux),'No valid axiliary device specified.');
                end
                
                if most.idioms.isValidObj(obj.hDAQAux)
                    assert(ismember(obj.hDAQAux.productCategory,{'DAQmx_Val_XSeriesDAQ','DAQmx_Val_AOSeries'}) ...
                        ,'Auxiliary DAQ must be an NI X-series board');
                end
                
                assert(most.idioms.isValidObj(obj.xGalvo),'No valid x galvo specified.');
                obj.xGalvo.assertNoError();
                
                assert(most.idioms.isValidObj(obj.yGalvo),'No valid y galvo specified.');
                obj.yGalvo.assertNoError();
                
                assert(~isequal(obj.xGalvo,obj.yGalvo),'x and y galvo cannot be the same.');
                
                assert(isequal(obj.xGalvo.hAOControl.hDAQ,obj.yGalvo.hAOControl.hDAQ),...
                    'xGalvo and yGalvo control must be on same DAQ board');
                
                beamErrors = cellfun(@(hB)~isempty(hB.errorMsg),obj.hBeams);
                assert(~any(beamErrors),'Beams %s are in error state', strjoin(cellfun(@(hB)hB.name,obj.hBeams(beamErrors),'UniformOutput',false)));
                
                fastBeamDevicesMask = cellfun(@(hB)isa(hB, 'dabs.resources.devices.BeamModulatorFast'), obj.hBeams);
                fastBeamDevices = obj.hBeams(fastBeamDevicesMask);
                beamDaqNames = cellfun(@(hB)hB.hAOControl.hDAQ.name,fastBeamDevices,'UniformOutput',false);
                beamDaqName = unique(beamDaqNames);
                assert(numel(beamDaqName)<=1,'All LinScan beams must be configured to be on the same DAQ board. Current configuration: %s',strjoin(beamDaqName,','));
                
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
            obj.safeAbortDataScope();
            most.idioms.safeDeleteObj(obj.hDataScope);
            %obj.abort();
        end
        
        function reinit(obj)
            try
                obj.deinit();
                
                obj.validateConfiguration();
                obj.assertNoError();
                
                for idx = 1:numel(obj.hFastZs)
                    obj.hFastZs{idx}.assertNoError();
                end
                
                for idx = 1:numel(obj.hBeams)
                    obj.hBeams{idx}.assertNoError();
                end
                
                obj.simulated = obj.xGalvo.hAOControl.hDAQ.simulated ...
                    || obj.hDAQAcq.simulated ...
                    || (most.idioms.isValidObj(obj.hDAQAux) && obj.hDAQAux.simulated);
                
                obj.hCtl.reinit();
                obj.hAcq.reinit();
                obj.hTrig.reinit();
                obj.hLinScanLog.reinit();
                
                obj.numInstances = 1;
                
                obj.maxSampleRateCtl = obj.hCtl.sampClkMaxRate;
                
                obj.ziniConfigureRouting();
                obj.sampleRate = min(obj.sampleRate,obj.maxSampleRate); % Synchronize hAcq and hCtl
                
                %Initialize Scan2D props (not initialized by superclass)
                obj.channelsInputRanges = repmat(obj.channelsAvailableInputRanges(1),1,obj.channelsAvailable);
                obj.channelOffsets = zeros(1, obj.channelsAvailable);
                obj.channelsSubtractOffsets = true(1, obj.channelsAvailable);
                
                obj.loadCalibration();
                
                obj.parkScanner();
            catch ME
                most.ErrorHandler.rethrow(ME);
            end
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hAcq);
            most.idioms.safeDeleteObj(obj.hCtl);
            most.idioms.safeDeleteObj(obj.hTrig);
            most.idioms.safeDeleteObj(obj.hLinScanLog);
            most.idioms.safeDeleteObj(obj.hPixListener);
            
            obj.saveCalibration();
        end
    end
    
    methods (Access = protected, Hidden)
        function mdlInitialize(obj)
            mdlInitialize@scanimage.components.Scan2D(obj);
            
            obj.hPixListener = most.ErrorHandler.addCatchingListener(obj.hSI.hRoiManager, 'pixPerLineChanged',@updateCtlSampRate);
            
            obj.hAcq.ziniPrepareFeedbackTasks();
            
            function updateCtlSampRate(varargin)
                if obj.hSI.hScan2D == obj
                    obj.sampleRateCtl = [];
                end
            end
        end
        
        function componentStart(obj)
            assert(~obj.robotMode);
            assert(~(obj.hSI.hRoiManager.isLineScan && obj.trigNextStopEnable),...
                   'LineScanning currently does not support next triggering or stop triggering.');
            
            obj.independentComponent = false;
            obj.hCtl.resetOffsetVoltage();
            
            obj.epochAcq = 0;
            obj.acqCounter = 0;
            obj.frameCounter = 0;
            obj.trigStartSoftwareTimestamp = NaN;
            obj.trigStopSoftwareTimestamp = NaN;
            obj.trigNextSoftwareTimestamp = NaN;
            
            obj.hLinScanLog.start();
            obj.hTrig.startTiming();
            obj.hCtl.arm();
            
            mask = cellfun(@(hB)isa(hB, 'dabs.resources.devices.BeamModulatorFast'), obj.hBeams);
            fastBeams = obj.hBeams(mask);
            for idx = 1:numel(fastBeams)
                fastBeams{idx}.setLastKnownPowerFractionToNaN();
            end
            
            obj.configureStartTrigger();
            if obj.trigAcqTypeExternal
                obj.startAcquisition();
            else
                % do not start the acquisition yet, wait for software trigger instead
            end
        end
        
        function componentAbort(obj,varargin)
            obj.haltAcquisition(true);
            obj.hLinScanLog.abort();
            obj.hTrig.abortTiming();
            obj.hCtl.parkOrPointLaser();
            obj.independentComponent = true;
            
            if ~isempty(obj.hSlmScan) && obj.parkSlmForAcquisition
                try
                    obj.hSlmScan.parkScanner();
                catch
                end
            end
        end
    end
    
    %% User API
    methods
        function calibrateGalvos(obj)
            hWb = waitbar(0,'Calibrating Scanner','CreateCancelBtn',@(src,evt)delete(ancestor(src,'figure')));
            try
                obj.scannerset.calibrateScanner('G',hWb);
            catch ME
                hWb.delete();
                rethrow(ME);
            end
            hWb.delete();
        end
        
        function centerScanner(obj)
            if obj.componentExecuteFunction('centerScanner')
                obj.hCtl.centerScanner();
            end
        end
        
        function pointScannerRef(obj,ptXY)
            validateattributes(ptXY,{'numeric'},{'size',[1,2],'nonnan','finite','real'});
            ptXY = scanimage.mroi.util.xformPoints(ptXY,obj.scannerToRefTransform,true);
            obj.pointScanner(ptXY(1),ptXY(2));
        end
        
        function pointScanner(obj,fastDeg,slowDeg)
            if obj.componentExecuteFunction('pointScanner',fastDeg,slowDeg)
                obj.hCtl.parkOrPointLaser([fastDeg,slowDeg]);
            end
        end
        
        function parkScanner(obj)
            if obj.componentExecuteFunction('parkScanner')
                obj.hCtl.parkOrPointLaser();
            end
        end
        
   
        function trigIssueSoftwareAcq(obj)
            if obj.componentExecuteFunction('trigIssueSoftwareAcq')
                if ~obj.active
                    obj.componentShortWarning('Cannot generate software trigger while acquisition is inactive');
                    return;
                end
                
                obj.trigStartSoftwareTimestamp = now();
                
                if obj.trigAcqTypeExternal
                    assert(obj.hTrig.enabled,'Cannot issue software external trigger without auxiliary board');
                    obj.generateTrigger(obj.hDAQAux.name,obj.trigAcqInTerm);
                else
                    if ~obj.hCtl.active
                        if obj.acqCounter == 0
                            obj.startAcquisition();
                        elseif ~obj.trigNextStopEnableInternal
                            obj.restartAcquisition();
                        end
                    end
                end
            end
        end
        
        function trigIssueSoftwareNext(obj)
            if obj.componentExecuteFunction('trigIssueSoftwareNext')
                if ~obj.active
                    obj.componentShortWarning('Cannot generate software trigger while acquisition is inactive');
                    return;
                end
                assert(obj.hTrig.enabled,'Next triggering unavailable: no auxiliary board specified');
                obj.trigNextSoftwareTimestamp = now();
            end
        end
        
        function trigIssueSoftwareStop(obj)
            if obj.componentExecuteFunction('trigIssueSoftwareStop')
                if ~obj.active
                    obj.componentShortWarning('Cannot generate software trigger while acquisition is inactive');
                    return;
                end
                assert(obj.hTrig.enabled,'Next triggering unavailable: no auxiliary board specified');
                obj.trigStopSoftwareTimestamp = now();
            end
        end
        
        function measureScannerFrequency(obj)
            if obj.componentExecuteFunction('measureScannerFrequency')
                obj.componentShortWarning('Measuring resonant scanner frequency is unsupported in scanner type ''%s''.',obj.scannerType);
            end
        end
        
        function [fsOut,xWvfm,cmdWvfm,fsIn,respWvfm,lineScanPeriod,lineAcquisitionPeriod] = waveformTest(obj)
            % TESTACTUATOR  Perform a test motion of the z-actuator
            %   [toutput,desWvfm,cmdWvfm,tinput,respWvfm] = obj.testActuator
            %
            % Performs a test motion of the galvos and collects position
            % feedback.  Typically this is displayed to the user so that they
            % can tune the actuator control.
            %
            % OUTPUTS
            %   toutput    Times of analog output samples (seconds)
            %   desWvfm    Desired waveform (tuning off)
            %   cmdWvfm    Command waveform (tuning on)
            %   tinput     Times of analog intput samples (seconds)
            %   respWvfm   Response waveform

            assert(~obj.active, 'Cannot run test during active acquisition.');
            

            %% prepare waveform
            zs = obj.hSI.hStackManager.zs;
            zsRelative = obj.hSI.hStackManager.zsRelative;
            sf = obj.hSI.hRoiManager.currentRoiGroup.rois(1).get(zs(1));
            ss = obj.scannerset;
            
            % input and output sample rate must be the same. Ensure it is
            % achievable;
            fsOut = min(obj.sampleRateCtl, get(obj.xGalvo.feedbackTask, 'sampClkMaxRate'));
            obj.xGalvo.sampleRateHz     = fsOut;
            obj.yGalvo.sampleRateHz     = fsOut;
            
            [lineScanPeriod,lineAcquisitionPeriod] = ss.linePeriod(sf);
            nx = ss.nsamples(ss.scanners{1},lineScanPeriod);           % total number of scan samples per line
            
            [ao_volts_optimized,~,~] = obj.hSI.hRoiManager.currentRoiGroup.scanStackAO(ss,zs(1),zsRelative(1),'',0,[]);
            [ao_volts,~,~] = obj.hSI.hRoiManager.currentRoiGroup.scanStackAO(ss,zs(1),zsRelative(1),'',0,[],[],[],false);
            xWvfm = ao_volts.G(nx*2+1:nx*4,1);
            cmdWvfm = ao_volts_optimized.G(nx*2+1:nx*4,1);
            
            testWvfm = repmat(cmdWvfm,20,1);
            fsIn = fsOut;
            
            data = obj.xGalvo.testWaveformVolts(testWvfm,fsOut);
            
            %% parse and scale data
            sN = ceil(lineScanPeriod*fsIn);
            respWvfm = data(1+sN*16:sN*18);
        end
        function saveLaserTriggerSettings(obj)
            mdf = most.MachineDataFile.getInstance();
            if mdf.isLoaded
				mdf.writeVarToHeading(obj.hSI.hScan2D.custMdfHeading,'LaserTriggerSampleMaskEnable',obj.laserTriggerSampleMaskEnable);
				mdf.writeVarToHeading(obj.hSI.hScan2D.custMdfHeading,'LaserTriggerSampleWindow',obj.laserTriggerSampleWindow);
				mdf.writeVarToHeading(obj.hSI.hScan2D.custMdfHeading,'LaserTriggerFilterTicks',obj.laserTriggerDebounceTicks);
            end
        end
    end
    
    %% Friend API
    methods
        function loadMdf(obj)
            success = true;
            success = success & obj.safeSetPropFromMdf('hDAQAcq', 'deviceNameAcq');
            success = success & obj.safeSetPropFromMdf('hDAQAux', 'deviceNameAux');
            success = success & obj.safeSetPropFromMdf('xGalvo', 'xGalvo');
            success = success & obj.safeSetPropFromMdf('yGalvo', 'yGalvo');
            success = success & obj.safeSetPropFromMdf('hFastZs', 'fastZs');
            success = success & obj.safeSetPropFromMdf('hShutters', 'shutters');
            success = success & obj.safeSetPropFromMdf('hBeams', 'beams');
            success = success & obj.safeSetPropFromMdf('channelIDs', 'channelIDs');
            success = success & obj.safeSetPropFromMdf('channelsInvert', 'channelsInvert');
            success = success & obj.safeSetPropFromMdf('stripingEnable', 'stripingEnable');
            success = success & obj.safeSetPropFromMdf('stripingMaxRate', 'stripingMaxRate');
            success = success & obj.safeSetPropFromMdf('maxDisplayRate', 'maxDisplayRate');
            success = success & obj.safeSetPropFromMdf('laserTriggerPort', 'LaserTriggerPort');
            success = success & obj.safeSetPropFromMdf('externalSampleClock', 'externalSampleClock');
            success = success & obj.safeSetPropFromMdf('externalSampleClockRate', 'externalSampleClockRate');
            
            success = success & obj.loadCalibration();
            
            if ~success
                obj.errorMsg = 'Error loading config';
            end
        end
        
        function saveMdf(obj)
            obj.safeWriteVarToHeading('deviceNameAcq', obj.hDAQAcq);
            obj.safeWriteVarToHeading('deviceNameAux', obj.hDAQAux);
            obj.safeWriteVarToHeading('xGalvo', obj.xGalvo);
            obj.safeWriteVarToHeading('yGalvo', obj.yGalvo);
            obj.safeWriteVarToHeading('fastZs', resourceCellToNames(obj.hFastZs,false));
            obj.safeWriteVarToHeading('beams', resourceCellToNames(obj.hBeams,false));
            obj.safeWriteVarToHeading('shutters', resourceCellToNames(obj.hShutters,false));
            obj.safeWriteVarToHeading('channelIDs', obj.channelIDs);            
            obj.safeWriteVarToHeading('channelsInvert', obj.channelsInvert);
            obj.safeWriteVarToHeading('stripingEnable', obj.stripingEnable);
            obj.safeWriteVarToHeading('stripingMaxRate', obj.stripingMaxRate);
            obj.safeWriteVarToHeading('maxDisplayRate', obj.maxDisplayRate);
            obj.safeWriteVarToHeading('LaserTriggerPort', obj.laserTriggerPort);
            obj.safeWriteVarToHeading('externalSampleClock', obj.externalSampleClock);
            obj.safeWriteVarToHeading('externalSampleClockRate', obj.externalSampleClockRate);
            
            obj.saveCalibration();
            
            %%% Nested functions
            function names = resourceCellToNames(hResources,includeInvalid)
               names = {};
               for idx = 1:numel(hResources)
                   hResource = hResources{idx};
                   if most.idioms.isValidObj(hResource)
                       names{end+1} = hResource.name;
                   elseif includeInvalid
                       names{end+1} = '';
                   end
               end
            end
        end
        
        function success = loadCalibration(obj)
            success = true;
            success = success & obj.safeSetPropFromMdf('scannerToRefTransform', 'scannerToRefTransform');
        end
        
        function saveCalibration(obj)
            obj.safeWriteVarToHeading('scannerToRefTransform', obj.scannerToRefTransform);
        end
    end
    
    
    methods (Hidden)
        function reinitRoutes(obj)
            if obj.mdlInitialized
                obj.hTrig.reinitRoutes();
            end
        end
        
        function deinitRoutes(obj)
            if obj.mdlInitialized
                obj.hTrig.deinitRoutes();
            end
        end
        
        function reloadMdf(obj,varargin)
            obj.loadMdf();
        end
        
        function calibrateLinePhase(obj)
            imData = obj.hSI.hDisplay.lastFrame;
            
            
            %get image from every channel in every roi
            roiDatas = obj.hSI.hDisplay.lastStripeData.roiData;
            if ~isempty(roiDatas)
                for ir = numel(roiDatas):-1:1
                    im = vertcat(roiDatas{ir}.imageData{:});
                    
                    if roiDatas{ir}.transposed
                        im = cellfun(@(imt){imt'},im);
                    end
                    
                    imData{ir,1} = vertcat(im{:});
                end
                
                imData = vertcat(imData{:});
                
                if ~isempty(imData)
                    [im1,im2] = deinterlaceImage(imData);
                    [~,pixelPhase] = detectPixelOffset(im1,im2);
                    samplePhase = obj.pixelBinFactor * pixelPhase;
                    phaseOffset = samplePhase / obj.sampleRate;
                    obj.linePhase = obj.linePhase - phaseOffset / 2;
                end
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
        
        function updateLiveValues(obj,regenAO,~)
            if nargin < 2 || isempty(regenAO)
                regenAO = true;
            end
            
            % waveforms parameter currently ignored. all waveforms updated
            
            if obj.active && obj.componentExecuteFunction('updateLiveValues')
                if regenAO
                    obj.hSI.hWaveformManager.updateWaveforms();
                end
                
                obj.hCtl.updateAnalogBufferAsync();
                
                if strcmpi(obj.hSI.acqState,'focus')
                    obj.hAcq.bufferAcqParams(true);
                end
            end
        end
        
        function updateSliceAO(obj)
            obj.hAcq.bufferAcqParams(false,true);
            obj.hCtl.updateAnalogBufferAsync(true);
        end
        
        function arm(obj)
            obj.hAcq.bufferAcqParams();
            
            if ~isempty(obj.hSlmScan) && obj.parkSlmForAcquisition
                hCS = obj.hSlmScan.hCSCoordinateSystem.hParent;
                hPt = scanimage.mroi.coordinates.Points(hCS,[0,0,0]);
                obj.hSlmScan.pointSlm(hPt);
            end
        end
        
        function startAcquisition(obj)            
            obj.haltAcquisition(false);
            
            % start clock slaves before clock masters
            % hAcq is slave to hCtl is slave to hTrig
            obj.hAcq.start();
            obj.hCtl.start();
            obj.hTrig.start();
        end
        
        function haltAcquisition(obj,tfUnreserve)
            obj.hAcq.abort(tfUnreserve);
            obj.hTrig.abort();
            obj.hCtl.abort();
        end
        
        function restartAcquisition(obj)
            obj.haltAcquisition(false);
            
            % start clock slaves before clock masters
            % hAcq is slave to hCtl is slave to hTrig
            obj.hAcq.restart();
            obj.hCtl.restart();
            obj.hTrig.restart();
            
            obj.frameCounter = 0;
        end
        
        function signalReadyReceiveData(obj)
           % No op 
        end
        
        function [success,stripeData] = readStripeData(obj)
            % do not use componentExecuteFunction for performance
            %if obj.componentExecuteFunction('readStripeData')
                success = ~isempty(obj.lastAcquiredFrame);
                stripeData = obj.lastAcquiredFrame;
                obj.lastAcquiredFrame = [];
            %end
        end
        
        function range = resetAngularRange(obj)
            obj.xAngularRange = diff(obj.xGalvo.travelRange);
            obj.yAngularRange = diff(obj.yGalvo.travelRange);
            range = [obj.xAngularRange obj.yAngularRange];
        end
   
        function data = acquireSamples(obj,numSamples)
            if obj.componentExecuteFunction('acquireSamples',numSamples)
                data = obj.hAcq.acquireSamples(numSamples);
            end
        end
        
        function zzFeedbackDataAcquiredCallback(obj, data, numFrames, nSamples, lastFrameStartIdx)
            if numFrames
                obj.lastFramePositionData = data(lastFrameStartIdx:end,:);
            else
                obj.lastFramePositionData(lastFrameStartIdx:lastFrameStartIdx+nSamples-1,:) = data;
            end
            
            obj.hLinScanLog.logScannerFdbk(data);
            obj.hSI.hDisplay.updatePosFdbk();
        end
        
        function zzStripeAcquiredCallback(obj,stripeData,startProcessingTime)
            if ~obj.active
                return
            end
            
            if obj.frameCounter == 0 && stripeData.stripeNumber == 1
                stripesPerFrame = obj.hAcq.acqParamBuffer.numStripes;
                obj.epochAcqMode = now - ((obj.hAcq.acqParamBuffer.frameTime/stripesPerFrame - toc(startProcessingTime)) / 86400); %the stripeAcquiredCallback happens _after_ the stripe is acquired, so subtract duration of stripe. 86400 = seconds per day
                obj.epochAcq = 0;
            end
            
            if stripeData.endOfFrame && (~obj.trigNextStopEnableInternal || stripeData.endOfVolume) % when next triggering is enabled, wait with processing of triggering until the end of the volume (so that the next trigger does not split up volumes)
                triggerTimes = obj.processTriggers();
            else
                triggerTimes = struct('start',NaN,'stop',NaN,'next',NaN);
            end
            
            if obj.trigNextStopEnableInternal
                if obj.updateAcquisitionStatusWithNextTriggeringEnabled(stripeData,triggerTimes);
                    return
                end
            else
                obj.updateAcquisitionStatus(stripeData,triggerTimes,startProcessingTime);
            end

            % fill in missing data in stripeData
            stripeData.epochAcqMode = obj.epochAcqMode;
            stripeData.acqNumber = obj.acqCounter + 1; % the current acquisition is always one ahead of the acquisition counter
            stripeData.frameNumberAcq = stripeData.frameNumberAcq; % eigenset frameNumberAcq to fill out roiData frameNumberAcq
            stripeData.frameNumberAcqMode = obj.frameCounter + (1:numel(stripeData.frameNumberAcq)); % the current frame number is always one ahead of the acquisition counter
            stripeData.endOfAcquisitionMode = stripeData.endOfAcquisition && stripeData.acqNumber == obj.trigAcqNumRepeats && obj.trigAcqNumRepeats > 0;
            
            % update counters
            if stripeData.endOfFrame
                obj.frameCounter = obj.frameCounter + numel(stripeData.frameNumberAcq);
            end
            
            if stripeData.endOfAcquisition
                obj.acqCounter = obj.acqCounter + 1;
            end
            
            obj.hLinScanLog.logStripe(stripeData);

            % publish stripe data
            obj.lastAcquiredFrame = stripeData;
            
            % control acquisition state
            if stripeData.endOfAcquisition
                obj.zzAcquisitionDone();
            end
            
            % done processing signal 'listeners' that data is ready to be read
            % limit display rate only if numStripes == 1, push all
            % stripeData.endOfAcquisition and all stripeData.frameNumberAcq == 1
            if obj.hAcq.acqParamBuffer.numStripes > 1 || stripeData.frameNumberAcq(1) == 1 || stripeData.endOfAcquisition || toc(obj.lastDisplayTic) > 1/obj.maxDisplayRate
                obj.lastDisplayTic = tic;
                % fprintf('Frame umber %d pushed to display\n',stripeData.frameNumberAcqMode);
                obj.stripeAcquiredCallback(obj,[]);
            else
                % fprintf('Frame Number %d not displayed\n',stripeData.frameNumberAcqMode);
            end
        end
        
        function updateAcquisitionStatus(obj,stripeData,triggerTimes,startProcessingTime)
            if stripeData.endOfFrame
                if obj.frameCounter ~= 0 && stripeData.frameNumberAcq(1) == 1
                    if ~isnan(triggerTimes.start)
                        % found a hardware timestamp!
                        obj.epochAcq = triggerTimes.start;
                    else
                        most.idioms.dispError('Warning: No timestamp for start trigger found. Estimating time stamp in software instead.\n');
                        obj.epochAcq = 86400 * ((now() - ((obj.hAcq.acqParamBuffer.frameTime - toc(startProcessingTime)) / 86400)) - obj.epochAcqMode); %the stripeAcquiredCallback happens _after_ the stripe is acquired, so subtract duration of frame. 86400 = seconds per day
                    end
                end

                stripeData.frameTimestamp = obj.epochAcq + ( stripeData.frameNumberAcq - 1 ) * obj.hAcq.acqParamBuffer.frameTime;
                
                if ~isnan(triggerTimes.stop) && triggerTimes.stop > obj.epochAcq
                    stripeData.endOfAcquisition = true;
                end
                
                if ~isnan(triggerTimes.next) && triggerTimes.next > obj.epochAcq
                    most.idioms.dispError('Next trigger detected, but acqusition is not configured to process it\n');
                end
            end
        end
        
        function cancelProcessing = updateAcquisitionStatusWithNextTriggeringEnabled(obj,stripeData,triggerTimes)
            % if next triggering is enabed, a continuous acquisition is
            % used. this means that the stripeData 'end of acquisition'
            % flag has to be overwritten here
            cancelProcessing = false;
            stripeData.endOfAcquisition = false;
            
            persistent totalFrameCounter;
            persistent acquisitionActive;
            persistent currentAcq;
            persistent currentAcqFrame;
            persistent timeStamp;
            persistent startTriggerTimestamp;
            persistent nextTriggerTimestamp;
            persistent nextFileMarkerFlag;
            
            % initialize persistent variables
            if obj.frameCounter == 0 && stripeData.stripeNumber == 1
                acquisitionActive = true;
                totalFrameCounter = 0;
                currentAcq = 0;
                currentAcqFrame = 0;
                timeStamp = 0;
                startTriggerTimestamp = 0;
                nextTriggerTimestamp = 0;
                nextFileMarkerFlag = false;
            end
            
            if stripeData.endOfFrame
                totalFrameCounter = totalFrameCounter + 1;
                timeStamp = obj.hAcq.acqParamBuffer.frameTime * ( totalFrameCounter - 1 );
            end
            
            if ~acquisitionActive
                if ~isnan(triggerTimes.start) && obj.frameCounter > 0
                    acquisitionActive = true; %start Acquisition on next frame
                    startTriggerTimestamp = triggerTimes.start;
                end
                
                cancelProcessing = true;
                return; %discard current stripe
            end
            
            stripeData.frameNumberAcq = currentAcqFrame + 1;
            
            if stripeData.endOfFrame
                currentAcqFrame = currentAcqFrame + 1;
                stripeData.frameTimestamp = timeStamp;
                
                if currentAcqFrame >= obj.framesPerAcq && obj.framesPerAcq > 0 && ~isinf(obj.framesPerAcq)
                    stripeData.endOfAcquisition = true;
                    acquisitionActive = false;
                    currentAcqFrame = 0;
                    currentAcq = currentAcq + 1;
                end
                
                if ~isnan(triggerTimes.stop)
                    stripeData.endOfAcquisition = true;
                    acquisitionActive = false;
                    currentAcqFrame = 0;
                    currentAcq = currentAcq + 1;
                end
                
                if ~isnan(triggerTimes.next)
                    nextFileMarkerFlag = true;
                    nextTriggerTimestamp = triggerTimes.next;
                    stripeData.nextFileMarkerTimestamp = triggerTimes.next;
                end
                
                if nextFileMarkerFlag && mod(obj.framesPerAcq,obj.framesPerStack) == 0
                    nextFileMarkerFlag = false;
                    stripeData.endOfAcquisition = true;
                    acquisitionActive = true;
                    currentAcqFrame = 0;
                    currentAcq = currentAcq + 1;
                end
                
                if stripeData.frameNumberAcq == 1
                    stripeData.acqStartTriggerTimestamp = startTriggerTimestamp;
                    stripeData.nextFileMarkerTimestamp = nextTriggerTimestamp;
                end
            end
        end

        function triggerTimes = processTriggers(obj)
            triggerTimes = struct('start',NaN,'stop',NaN,'next',NaN);
            triggerTimesHardware = obj.hTrig.readTriggerTimes(); % returns a struct with fields start, stop, next
            
            % process start trigger
            if ~isnan(triggerTimesHardware.start)
                % hardware trigger takes precedence over software timestamp
                triggerTimes.start = triggerTimesHardware.start;
            elseif ~isnan(obj.trigStartSoftwareTimestamp)
                triggerTimes.start = 86400 * (obj.trigStartSoftwareTimestamp - obj.epochAcqMode);
            end
            
            % process stop trigger
            if ~obj.trigNextStopEnableInternal
                triggerTimes.stop = NaN;
            elseif ~isnan(triggerTimesHardware.stop) && ~isempty(obj.trigStopInTerm)
                % hardware trigger takes precedence over software timestamp
                triggerTimes.stop = triggerTimesHardware.stop;
            elseif ~isnan(obj.trigStopSoftwareTimestamp)
                triggerTimes.stop = 86400 * (obj.trigStopSoftwareTimestamp - obj.epochAcqMode);
            end

            % process next trigger
            if ~obj.trigNextStopEnableInternal
                triggerTimes.next = NaN;
            elseif ~isnan(triggerTimesHardware.next) && ~isempty(obj.trigNextInTerm)
                % hardware trigger takes precedence over software timestamp
                triggerTimes.next = triggerTimesHardware.next;
            elseif ~isnan(obj.trigNextSoftwareTimestamp)
                triggerTimes.next = 86400 * (obj.trigNextSoftwareTimestamp - obj.epochAcqMode);
            end

            % Reset trigger timestamps
            obj.trigStartSoftwareTimestamp = NaN;
            obj.trigStopSoftwareTimestamp  = NaN;
            obj.trigNextSoftwareTimestamp  = NaN;
        end
        
        function zzAcquisitionDone(obj)
            obj.haltAcquisition(false);
            
            if obj.trigAcqNumRepeats > 0 && obj.acqCounter >= obj.trigAcqNumRepeats;
                obj.abort(); % End of Acquisition Mode
            else
                if obj.trigAcqTypeExternal
                    obj.restartAcquisition();
                else
                    % do not start acquisition, instead wait for software trigger
                end
            end
        end
        
        function ziniConfigureRouting(obj)
            deviceNameAcq = obj.hDAQAcq.name;
            deviceNameGalvo = obj.xGalvo.hAOControl.hDAQ.name;
            
            % Here it gets complicated
            if obj.hTrig.enabled
                % Auxiliary board enabled.
                deviceNameAux = obj.hDAQAux.name;
                
                if strcmp(deviceNameAcq,deviceNameGalvo) && ~strcmp(deviceNameGalvo,deviceNameAux)
                    % PMT inputs and XY Galvo output configured to be on
                    % the same board, but Aux board is separate
                    % Setup: the acqClock is generated on the auxiliary
                    % board and routed to the combined Acq/Galvo board
                    % the start trigger triggers the acqClock
                    obj.hAcq.hAI.sampClkSrc = obj.hTrig.sampleClockAcqTermInt;
                    obj.hAcq.hAI.sampClkTimebaseRate = obj.hTrig.referenceClockRateInt;
                    obj.clockMaster = 'auxiliary';
                    obj.linkedSampleClkAcqCtl = true;
                elseif strcmp(deviceNameGalvo,deviceNameAux)
                    % The XY galvo output happens on the auxiliary board
                    obj.hAcq.hAI.sampClkSrc = obj.hTrig.sampleClockAcqTermInt;
                    obj.hAcq.hAI.sampClkTimebaseRate = obj.hTrig.referenceClockRateInt;
                    obj.hCtl.sampClkSrc = 'OnboardClock';
                    
                    if ~isempty(obj.trigReferenceClkOutInternalTerm)
                        obj.hCtl.sampClkTimebaseSrc = obj.hTrig.referenceClockTermInt;
                        obj.hCtl.sampClkTimebaseRate = obj.hTrig.referenceClockRateInt;
                    end
                    
                    obj.clockMaster = 'auxiliary';
                    obj.linkedSampleClkAcqCtl = false;
                else
                    error('Error initializing ''%s'' scanner.\nIf auxiliary digital trigger DAQ is defined, the XY Galvo output must be either configured to be on the signal acquisition DAQ or the auxiliary digital trigger DAQ', obj.name);
                end
            else
                % Auxiliary board disabled use only one board, no
                % beams/clock output, no synchronization with other boards
                if strcmp(deviceNameAcq,deviceNameGalvo)
                    obj.clockMaster = 'controller';
                    obj.linkedSampleClkAcqCtl = false;
                else
                   error('Error initializing ''%s'' scanner.\nIf auxiliary board is not defined, deviceNameAcq and deviceNameGalvo must be equal', obj.name);
                end       
            end
        end
        
        function configureStartTrigger(obj) 
            if obj.trigAcqTypeExternal
                trigTerm = obj.trigAcqInTerm;
            else
                trigTerm = '';
            end
            
            switch obj.clockMaster
                case 'auxiliary'
                    if obj.linkedSampleClkAcqCtl
                        obj.hAcq.startTrigIn = '';
                        obj.hCtl.startTrigIn = '';
                    else
                        obj.hCtl.startTrigIn = obj.hTrig.sampleClockAcqTermInt;
                        obj.hCtl.startTrigEdge = 'rising';
                    end
                    obj.hTrig.sampleClkAcqStartTrigEdge = obj.trigAcqEdge;
                    obj.hTrig.sampleClkAcqStartTrigIn = trigTerm;
                case 'controller'
                    obj.hAcq.startTrigIn = 'ao/SampleClock';
                    obj.hAcq.startTrigEdge = 'rising';
                    obj.hCtl.startTrigIn = trigTerm;
                    obj.hCtl.startTrigEdge = obj.trigAcqEdge;
                    obj.hTrig.sampleClkAcqStartTrigIn = '';
                otherwise
                    assert(false);
            end
        end
    end
    
    %% Internal API
    
    %%% PROPERTY ACCESS METHODS
    methods        
        function set.hDAQAcq(obj,val)            
            val = obj.hResourceStore.filterByName(val);
            
            if ~isequal(val,obj.hDAQAcq)
                assert(~obj.mdlInitialized,'Cannot change Acq DAQ board while ScanImage is running');
                
                if most.idioms.isValidObj(val)
                    validateattributes(val,{'dabs.resources.daqs.NIDAQ','dabs.resources.daqs.NIRIO'},{'scalar'});
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
                assert(~obj.mdlInitialized,'Cannot change Aux DAQ board while ScanImage is running');
                
                if most.idioms.isValidObj(val)
                    validateattributes(val,{'dabs.resources.daqs.NIDAQ'},{'scalar'});
                end
                
                obj.deinit();
                obj.hDAQAux.unregisterUser(obj);
                obj.hDAQAux = val;
                obj.hDAQAux.registerUser(obj,'Auxiliary DAQ');
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
                assert(~obj.mdlInitialized,'Cannot change x Galvo while ScanImage is running');
                
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
                assert(~obj.mdlInitialized,'Cannot change y Galvo while ScanImage is running');
                
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
            
            if numel(val)>1
                val = val(1); %LinScan does not support more than one FastZ
            end
            
            if ~isequal(val,obj.hFastZs)
                assert(~obj.mdlInitialized,'Cannot change fastZs while ScanImage is running');
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
            
            if ~isequal(val,obj.hBeams)
                assert(~obj.mdlInitialized,'Cannot change beams while ScanImage is running');
            end
            
            obj.hBeams = val;
        end
        
        function val = get.hBeams(obj)
            validMask = cellfun(@(h)most.idioms.isValidObj(h),obj.hBeams);
            val = obj.hBeams(validMask);
        end
        
        function set.laserTriggerPort(obj,val)
            if isempty(val)
                val = '';
            else
                isPFI = ~isempty(regexpi(val,'^PFI[0-9]+$','match','once'));
                isDIO = ~isempty(regexpi(val,'^DIO0\.[0-3]$','match','once'));
                assert(isPFI || isDIO,'Invalid value for laserTriggerPort');
            end
            
            oldVal = obj.laserTriggerPort;
            obj.laserTriggerPort = val;
            
            if ~strcmpi(oldVal,val) && obj.hTrig.routesInitted
                obj.hTrig.laserTriggerPort = obj.laserTriggerPort;
            end
        end
        
        function set.channelIDs(obj,val)
            if isempty(val)
                val = 0:(obj.MAX_NUM_CHANNELS-1);
            end
            
            validateattributes(val,{'numeric'},{'integer','nonnegative','vector'});
            val(obj.MAX_NUM_CHANNELS+1:end) = []; % coerce size
            assert(isUnique(val),'Channel selection must be unique.'); 
            
            obj.channelIDs = val;
            
            function tf = isUnique(v)
                tf = numel(unique(v)) == numel(v);
            end
        end
        
        function set.channelsInvert(obj,val)
            if isempty(val)
                val = false;
            end
            
            % coerce size
            val(end+1:obj.channelsAvailable) = val(end);
            val(obj.channelsAvailable+1:end) = [];
            
            validateattributes(val,{'numeric','logical'},{'binary'});
            obj.channelsInvert = logical(val);
        end
        
        function set.channelOffsets(obj,val)
            if isempty(val)
                val = false;
            end
            
            % coerce size
            val(end+1:obj.channelsAvailable) = 0;
            val(obj.channelsAvailable+1:end) = [];
            
            validateattributes(val,{'numeric'},{'finite','integer','nonnan'});
            
            obj.channelOffsets = val;
            if obj.active
                obj.hAcq.updateBufferedOffsets();
            end
        end
        
        function set.stripingMaxRate(obj,val)
            validateattributes(val,{'numeric'},{'scalar','positive','nonnan'});
            obj.stripingMaxRate = val;
        end
        
        function set.maxDisplayRate(obj,val)
            validateattributes(val,{'numeric'},{'scalar','positive','nonnan'});
            obj.maxDisplayRate = val;
        end
        
        function set.linePhaseStep(obj,val)
            obj.mdlDummySetProp(val,'linePhaseStep');
        end
        
        function val = get.linePhaseStep(obj)
           val = 1 / obj.sampleRate;
        end
        
        function set.externalSampleClock(obj,val)
            validateattributes(val,{'numeric','logical'},{'scalar','binary'});
            obj.externalSampleClock = logical(val);
        end
        
        function set.externalSampleClockRate(obj,val)
            validateattributes(val,{'numeric'},{'scalar','positive','nonnan','finite'});
            obj.externalSampleClockRate = val;            
        end
        
        function set.sampleRate(obj,val)
            val = obj.validatePropArg('sampleRate',val);
            assert(val <= obj.maxSampleRate,'Sample rate must be smaller or equal to %f Hz.',obj.maxSampleRate);
            
            % Get available sample rates.
            sampleRates = obj.hAcq.hAI.validSampleRates;
            % Max Sample Clock of Acq Device
            sampleClkMaxRate = obj.hAcq.hAI.sampClkMaxRate;
            % Set Floor of Valid Sample Rates -  might not be necessary
            % anymore
            sampleRates = sampleRates(sampleRates >= (200000));
            % Clamp Valid Sample Rates to Max Sample Reate of Acq
            % Device
            sampleRates = sampleRates(sampleRates <= (sampleClkMaxRate));

            if isempty(find(sampleRates == val))
                if isempty(find(sampleRates == round(val)))
                    error('Invalid Sample Rate.');
                end
            end
            
            if obj.componentUpdateProperty('sampleRate',val)
                % set sample rate in acquisition subsystem
                obj.hAcq.hAI.sampClkRate = val;
                % read sample rate back to get coerced value
                newVal = obj.hAcq.hAI.sampClkRate;
                obj.valCoercedWarning('sampleRate', val, newVal);
                
                % set property
                obj.sampleRate = newVal;
                
                % side effects
                obj.hTrig.sampleClkAcqFreq = obj.sampleRate;
                obj.sampleRateCtl = []; %updates the XY Galvo AO sample rate
                obj.linePhase = obj.linePhase;
            end
        end
        
        function set.sampleRateCtl(obj,~)            
            % val is ignored this setter is just to update the AO output rate
            maxOutputRate = min([obj.maxSampleRate,obj.maxSampleRateCtl,obj.MAX_REQUESTED_CTL_RATE]);
            
            % side effects
            % set AO output rate and read back to ensure it is set correctly
            if obj.linkedSampleClkAcqCtl
                if maxOutputRate >= obj.sampleRate
                    desSampleRate = obj.sampleRate;
                    obj.hCtl.sampClkSrc = 'ai/SampleClock';
                    obj.hCtl.genSampClk = false;
                else
                    desSampleRate = maxAccSampleRate(min(obj.sampleRate/4,maxOutputRate));
                    set(obj.hCtl.hAOSampClk.channels(1),'ctrTimebaseRate',obj.sampleRate);
                    set(obj.hCtl.hAOSampClk.channels(1),'pulseFreq',desSampleRate);
                    obj.hCtl.sampClkSrc = 'Ctr1InternalOutput';
                    obj.hCtl.genSampClk = true;
                end
            else
                desSampleRate = maxAccSampleRate(min(obj.sampleRate,maxOutputRate));
            end
            
            obj.hCtl.sampClkRate = desSampleRate;
            
            % check the actual output rate by reading it back from the task
            obj.sampleRateCtl = obj.hCtl.sampClkRate;
            assert(diff([obj.sampleRateCtl  desSampleRate]) < 1e-10,...
                ['Error: Output Rate for XY Galvo Control task could not be ',...
                 'set to requested value. Analog inputs and analog outputs ',...
                 'are out of sync']);
             
            obj.sampleRateFdbk = [];
            
            function v = maxAccSampleRate(maxRate)
                if ~obj.hSI.hRoiManager.isLineScan
                    try
                        % sample rate needs to be an integer multiple of all line acq times
                        obj.hAcq.bufferAllSfParams();
                        allSfp = [obj.hAcq.acqParamBuffer.scanFieldParams{:}];
                        lineAcqSamps = unique([allSfp.lineAcqSamples]);
                        assert(all(~isnan(lineAcqSamps)));
                        assert(all(lineAcqSamps > 0));
                        minDecim = ceil(obj.sampleRate / maxRate);
                        for d = minDecim:ceil(min(lineAcqSamps)/10)
                            divs = lineAcqSamps/d;
                            if ~any(divs - floor(divs))
                                v = obj.sampleRate/d;
                                return;
                            end
                        end
                    catch
                        % acq params may not yet be buffered. just use a simple
                        % solution
                        v = findNextPower2SampleRate(obj.sampleRate/4,maxRate);
                        return;
                    end
                    
                    error('No suitable control sample rate found for scan parameters. Try adjusting parameters including sample rate, pixel count, and pixel bin factor.');
                else
                    if obj.sampleRate > maxRate
                        v = obj.sampleRate / ceil(obj.sampleRate / maxRate);
                    else
                        v = maxRate;
                    end
                end
            end
        end
        
        function set.sampleRateFdbk(obj,~)
            if ~isempty(obj.hAcq.hAIFdbk.channels) && obj.hTrig.enabled
                maxRate = min(obj.MAX_FDBK_RATE, get(obj.hAcq.hAIFdbk, 'sampClkMaxRate'));
                
                if obj.hAcq.rec3dPath
                    maxRate = min(maxRate, get(obj.hAcq.hAIFdbkZ, 'sampClkMaxRate'));
                end
                
                if maxRate >= obj.sampleRateCtl
                    obj.sampleRateFdbk = obj.sampleRateCtl;
                else
                    obj.sampleRateFdbk = findNextPower2SampleRate(obj.sampleRateCtl/4,maxRate);
                end
                
                obj.hAcq.hAIFdbk.sampClkRate = obj.sampleRateFdbk;
                
                if obj.hAcq.rec3dPath
                    obj.hAcq.hAIFdbkZ.sampClkRate = obj.sampleRateFdbk;
                end
            end
        end
        
        function set.pixelBinFactor(obj,val)
            val = obj.validatePropArg('pixelBinFactor',val);
            if obj.componentUpdateProperty('pixelBinFactor',val)
               obj.pixelBinFactor = val;
               obj.sampleRateCtl = [];
            end
        end
        
        function set.logFilePerChannel(obj,val)
            if obj.componentUpdateProperty('logFilePerChannel',val)
                val = obj.validatePropArg('logFilePerChannel',val);
                
                obj.logFilePerChannel = val;
            end
        end
        
        function sz = get.defaultRoiSize(obj)
            o = [0,0];
            x = [obj.angularRange(1)/2,1];
            y = [1,obj.angularRange(2)/2];
            
            oRef = scanimage.mroi.util.xformPoints(o,obj.scannerToRefTransform);
            xRef = scanimage.mroi.util.xformPoints(x,obj.scannerToRefTransform);
            yRef = scanimage.mroi.util.xformPoints(y,obj.scannerToRefTransform);
            
            xSz = norm(xRef-oRef)*2;
            ySz = norm(yRef-oRef)*2;
            
            sz = min( [xSz,ySz] );
        end
        
        function rg = get.angularRange(obj)
            rg = [diff(obj.xGalvo.travelRange) diff(obj.yGalvo.travelRange)];
        end
        
        function set.recordScannerFeedback(obj,v)
            if v
                assert(obj.hTrig.enabled, 'Scanner feedback only supported if an auxiliary board is present');
                assert(most.idioms.isValidObj(obj.xGalvo.hAIFeedback) && most.idioms.isValidObj(obj.yGalvo.hAIFeedback) && ~isempty(obj.hAcq.hAIFdbk.channels), 'Scanner feedback channels are not set in MDF. If they have been modified, you must restart scanimage.');
                assert(obj.xGalvo.hAIFeedback.hDAQ==obj.yGalvo.hAIFeedback.hDAQ,'X and Y Galvo feedback must be configured on same device');
                assert(obj.xGalvo.hAIFeedback.hDAQ~=obj.hDAQAcq, 'Scanner feedback cannot be recorded for line scanning when it is on the same DAQ with PMT acquisition.');
            end
            
            if obj.componentUpdateProperty('recordScannerFeedback',v)
                obj.recordScannerFeedback = v;
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
        
        function val = get.trigNextStopEnableInternal(obj)
            val = obj.trigNextStopEnable && obj.trigAcqTypeExternal;
        end
        
        function val = get.controllingFastZ(obj)
            val = false;
            if isempty(obj.hFastZs)
                return
            end
            
            hAOControl = obj.hFastZs{1}.hAOControl;
            if most.idioms.isValidObj(hAOControl)
                fastZDaqBoardName = hAOControl.hDAQ.name;
                xGalvoDaqBoardName = obj.xGalvo.hAOControl.hDAQ.name;
                val = strcmp(xGalvoDaqBoardName,fastZDaqBoardName);
            end
        end
        
        function val = get.validSampleRates(obj)
            val = obj.hAcq.hAI.validSampleRates;
            val = val(val<=obj.hAcq.hAI.sampClkMaxRate);
        end
        
        function v = get.laserTriggerSampleMaskEnable(obj)
            v = obj.mdfData.LaserTriggerSampleMaskEnable;
        end
        
        function set.laserTriggerSampleMaskEnable(obj,v)
            v = logical(v);
            obj.mdfData.LaserTriggerSampleMaskEnable = v;
            if obj.laserTriggerFilterSupport
                obj.hAcq.hFpga.LinScanDivertSamples = v;
                obj.hAcq.hFpga.ResScanFilterSamples = false;
            end
        end
        
        function v = get.laserTriggerSampleWindow(obj)
            v = obj.mdfData.LaserTriggerSampleWindow;
        end
        
        function set.laserTriggerSampleWindow(obj,v)
            obj.mdfData.LaserTriggerSampleWindow = v;
            if obj.laserTriggerFilterSupport
                obj.hAcq.hFpga.LaserTriggerDelay = v(1);
                obj.hAcq.hFpga.LaserSampleWindowSize = v(2);
            end
        end
        
        function v = get.laserTriggerDebounceTicks(obj)
            v = obj.mdfData.LaserTriggerFilterTicks;
        end
        
        function set.laserTriggerDebounceTicks(obj,v)
            obj.mdfData.LaserTriggerFilterTicks = v;
            if obj.laserTriggerFilterSupport
                obj.hAcq.hFpga.LaserTriggerFilterTicks = v;
            end
        end
    end
    
    %% ABSTRACT METHOD IMPLEMENTATIONS (scanimage.components.Scan2D)
    methods (Access = protected, Hidden)
        function val = accessScannersetPostGet(obj,~)
            pixelTime =obj.pixelBinFactor/obj.sampleRate;
            
            if obj.hSI.hStackManager.isFastZ && strcmp(obj.hSI.hFastZ.waveformType, 'step')
                flybackTime = obj.zprvRoundTimeToNearestSampleCtl(max(obj.flybackTimePerFrame, obj.hSI.hFastZ.flybackTime));
            else
                flybackTime = obj.zprvRoundTimeToNearestSampleCtl(obj.flybackTimePerFrame);
            end
            
            assert(most.idioms.isValidObj(obj.xGalvo),'xGalvo is not defined in machine data file');
            xGalvoScanner = scanimage.mroi.scanners.Galvo(obj.xGalvo);
            xGalvoScanner.flytoTimeSeconds = obj.zprvRoundTimeToNearestSampleCtl(obj.flytoTimePerScanfield);
            xGalvoScanner.flybackTimeSeconds = flybackTime;
            xGalvoScanner.sampleRateHz     = obj.sampleRateCtl;
            
            assert(most.idioms.isValidObj(obj.yGalvo),'yGalvo is not defined in machine data file');
            yGalvoScanner = scanimage.mroi.scanners.Galvo(obj.yGalvo);
            yGalvoScanner.flytoTimeSeconds = obj.zprvRoundTimeToNearestSampleCtl(obj.flytoTimePerScanfield);
            yGalvoScanner.flybackTimeSeconds = flybackTime;
            yGalvoScanner.sampleRateHz     = obj.sampleRateCtl;
            
            % Define beam hardware
            % Define beam hardware
            [fastBeams, slowBeams] = obj.hSI.hBeams.wrapBeams(obj.hBeams);
            if ~isempty(obj.hBeams)
                if obj.hCtl.beamShareGalvoDAQ
                    beamsSampleRate = obj.sampleRateCtl;
                else
                    beamsSampleRate = findNextPower2SampleRate(obj.sampleRateCtl,obj.hSI.hBeams.maxSampleRate);
                end
            end
            
            for idx = 1:numel(fastBeams)
                fastBeams(idx).sampleRateHz = beamsSampleRate;
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
                if obj.controllingFastZ
                    fastZScanners(idx).sampleRateHz = obj.sampleRateCtl;
                else
                    if isempty(fastZScanners(idx).hDevice)
                        fastzMaxRate = 1e6;
                    else
                        fastzMaxRate = fastZScanners(idx).hDevice.positionMaxSampleRate;
                    end
                    fastZScanners(idx).sampleRateHz = findNextPower2SampleRate(obj.sampleRateCtl,fastzMaxRate);
                end
            end
            
            stepY = false;
            
            % Create galvo galvo scannerset using hardware descriptions above
            val = scanimage.mroi.scannerset.GalvoGalvo(obj.name,xGalvoScanner,yGalvoScanner,fastBeams, slowBeams, fastZScanners,...
                obj.fillFractionSpatial,pixelTime,obj.bidirectional,stepY,obj.settleTimeFraction);
            
            val.hCSSampleRelative = obj.hSI.hMotors.hCSSampleRelative;
            val.hCSReference = obj.hSI.hCoordinateSystems.hCSReference;
            val.beamRouters = obj.hSI.hBeams.hBeamRouters;
            val.objectiveResolution = obj.hSI.objectiveResolution;
        end
        
        function accessBidirectionalPostSet(~,~)
            % Nothing to do here
        end
        
        function val = accessBidirectionalPreSet(~,val)
            % Nothing to do here
        end
        
        function val = accessStripingEnablePreSet(~,val)
            % Nothing to do here
        end
        
        function val = accessChannelsFilterPostGet(~,~)
            val = 'None';
        end
        
        function val = accessChannelsFilterPreSet(obj,val)
            obj.errorPropertyUnSupported('channelsFilter',val);
            val = 'None';
        end
        
        function valActual = accessLinePhasePreSet(obj,val)
            valActual = obj.zprvRoundTimeToNearestSampleAcq(val);
        end        
        
        function val = accessLinePhasePostSet(obj,val)
            try
                if obj.active
                    obj.hAcq.updateBufferedPhaseSamples();
                    % regenerate beams output
                    obj.hSI.hBeams.updateBeamBufferAsync(true);
                end
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
        end
        
        function val = accessLinePhasePostGet(obj,val)
            %No-op
        end

        function accessBeamClockDelayPostSet(obj, val)
            if obj.active
                obj.hSI.hBeams.updateBeamBufferAsync(true);
            end
        end
        
        function accessBeamClockExtendPostSet(obj,val)
            if obj.mdlInitialized
                most.idioms.warn('Not yet supported in LinScan');
            end
        end
        
        function accessChannelsAcquirePostSet(obj,val)
            obj.hSI.hBeams.powers = obj.hSI.hBeams.powers; % regenerate beams output
        end
       %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function val = accessFillFractionSpatialPreSet(~,val)
            % No-op
        end
        
        function accessFillFractionSpatialPostSet(~,~)
            % No-op
        end
		
	    function val = accessSettleTimeFractionPostSet(~,val)
            % No-op
        end
        
        function val = accessFlytoTimePerScanfieldPostGet(~,val)
            % No-op
        end
        
        function val = accessFlybackTimePerFramePostGet(~,val)
            % No-op
        end
        
        function val = accessLogAverageFactorPostSet(obj,val)
            %fprintf('\nLog Average LinScan Set\n');
            %obj.hAcq.flagResizeAcquisition = true; % JLF Tag -- What does this do...
            %TODO: Implement this (if needed)
        end
        
        function accessLogFileCounterPostSet(obj,val)
            %TODO: Implement this (if needed)
        end
            
        function accessLogFilePathPostSet(obj,val)
            %TODO: Implement this (if needed)
        end
        
        function accessLogFileStemPostSet(obj,val)
            %TODO: Implement this (if needed)
        end
        
        function val = accessLogFramesPerFilePostSet(obj,val)
            %TODO: Implement this (if needed)
        end
        
        function val = accessLogFramesPerFileLockPostSet(obj,val)
            %TODO: Implement this (if needed)
        end
        
        function val = accessLogNumSlicesPreSet(obj,val)
            % TODO: Implement this
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function val = accessTrigFrameClkOutInternalTermPostGet(obj,val)
            if obj.hTrig.enabled
                val = obj.hTrig.frameClockTermInt;
            else
                val = ''; % no trigger routing available without auxiliary port
            end
        end

        function val = accessTrigBeamClkOutInternalTermPostGet(obj,val)
            val = ''; % no trigger routing available without auxiliary port
        end
        
        function val = accessTrigAcqOutInternalTermPostGet(obj,val)
            val = ''; %Not supported in LinScan
        end
        
        function val = accessTrigReferenceClkOutInternalTermPostGet(obj,val)
            if obj.hTrig.enabled
                val = obj.hTrig.referenceClockTermExt;
            else
                val = '';
            end
        end
        
        function val = accessTrigReferenceClkOutInternalRatePostGet(obj,val)
            if obj.hTrig.enabled
                val = obj.hTrig.referenceClockRateExt;
            else
                val = [];
            end
        end        
        
        function val = accessTrigReferenceClkInInternalTermPostGet(obj,val)
            if most.idioms.isValidObj(obj.hDAQAux)
                [device,terminal,frequency] = gethTrigRefClk(obj);
                val = terminal;
            else
                val = '';
            end
        end
        
        function val = accessTrigReferenceClkInInternalRatePostGet(obj,val)
            if most.idioms.isValidObj(obj.hDAQAux)
                [device,terminal,frequency] = gethTrigRefClk(obj);
                val = frequency;
            else
                val = [];
            end
        end
		
        function val = accessTrigAcqInTermAllowedPostGet(obj,val)
             val =  {'','PFI0'};
        end
        
        function val = accessTrigNextInTermAllowedPostGet(obj,val)
            if obj.hTrig.enabled
                val = {'' , obj.hTrig.TRIG_LINE_NEXT};
            else
                val = {''}; % Next/Stop Triggering is not supported without an auxiliary board
            end
        end
        
        function val = accessTrigStopInTermAllowedPostGet(obj,val)
            if obj.hTrig.enabled
                val = {'' , obj.hTrig.TRIG_LINE_STOP};
            else
                val = {''}; % Next/Stop Triggering is not supported without an auxiliary board
            end
        end
        
        function  val = accessTrigAcqEdgePreSet(~,val)
            % Nothing to do here
        end
        
        function accessTrigAcqEdgePostSet(obj,val)
            obj.configureStartTrigger()
        end
        
        function val = accessTrigAcqInTermPreSet(~,val)
            % Nothing to do here
        end
        
        function accessTrigAcqInTermPostSet(obj,val)
            if isempty(obj.trigAcqInTerm)
                obj.trigAcqTypeExternal = false;
            end
            obj.configureStartTrigger();
        end
        
        function val = accessTrigAcqTypeExternalPreSet(~,val)
            % Nothing to do here
        end
        
        function accessTrigAcqTypeExternalPostSet(obj,val)
            obj.configureStartTrigger();
        end
        
        function val = accessTrigNextEdgePreSet(~,val)
            % Nothing to do here
        end
        
        function val = accessTrigNextInTermPreSet(obj,val)
            if ~isempty(val) && ~obj.hTrig.enabled
                val = '';
                warning('Cannot configure next trigger without an auxiliary DAQ board');
            end
        end
        
        function val = accessTrigNextStopEnablePreSet(obj,val)
            if val && ~obj.hTrig.enabled
                val = false;
                warning('Next/Stop triggering unavailable: no auxiliary board specified');
            end
        end
        
        function val = accessTrigStopEdgePreSet(~,val)
            % Nothing to do here
        end
        
        function val = accessFunctionTrigStopInTermPreSet(obj,val)
            if ~isempty(val) && ~obj.hTrig.enabled
                val = '';
                warning('Cannot configure stop trigger without an auxiliary DAQ board');
            end
        end
        
        function val = accessMaxSampleRatePostGet(obj,~)
            val = obj.hAcq.hAI.get('sampClkMaxRate');
        end
        
        function accessScannerFrequencyPostSet(obj,val)
            obj.errorPropertyUnSupported('scannerFrequency',val);
        end
        
        function val = accessScannerFrequencyPostGet(~,~)
            val = NaN;
        end
        
        function val = accessChannelsInputRangesPreSet(obj,val)
            val = obj.hAcq.hAI.setInputRanges(val);
        end
        
        function val = accessChannelsInputRangesPostGet(obj,~)
            val = obj.hAcq.hAI.getInputRanges();
        end
        
        function val = accessChannelsAvailablePostGet(obj,~)
            val = numel(obj.channelIDs);
            if most.idioms.isValidObj(obj.hAcq.hAI)
                val = min(val,obj.hAcq.hAI.getNumAvailChans);
            elseif most.idioms.isValidObj(obj.hDAQAcq) && isa(obj.hDAQAcq, 'dabs.resources.daqs.NIRIO')
                val = numel(obj.hDAQAcq.hAdapterModule.hDigitizerAIs);
            end
        end
        
        function val = accessChannelsAvailableInputRangesPostGet(obj,~)
            val = obj.hAcq.hAI.getAvailInputRanges();
        end

        function val = accessScanPixelTimeMeanPostGet(obj,~)
            val = obj.pixelBinFactor / obj.sampleRate;
        end
        
        function val = accessScanPixelTimeMaxMinRatioPostGet(~,~)
            val = 1;
        end
        
        function val = accessChannelsAdcResolutionPostGet(obj,~)
            % assume all channels on the DAQ board have the same resolution
            val = obj.hAcq.hAI.adcResolution;
        end
        
        function val = accessChannelsDataTypePostGet(obj,~)
            if isempty(obj.channelsDataType_)
                singleSample = obj.hAcq.acquireSamples(1);
                val = class(singleSample);
                obj.channelsDataType_ = val;
            else
                val = obj.channelsDataType_;
            end
        end
        
        function val = accessScannerToRefTransformPreSet(obj,val)
            % No-op
        end
        
        function accessChannelsSubtractOffsetsPostSet(obj)
            obj.channelOffsets = obj.channelOffsets;
        end
    end
    
    %% ABSTRACT HELPER METHOD IMPLEMENTATIONS (scanimage.components.Scan2D)
    methods (Access = protected)
        function fillFracTemp = fillFracSpatToTemp(~,fillFracSpat)
            fillFracTemp = fillFracSpat;
        end
        
        function fillFracSpat = fillFracTempToSpat(~,fillFracTemp)
            fillFracSpat = fillFracTemp;
        end
    end
    
    %% Helper functions
    methods (Access = protected)
        function actualTime = zprvRoundTimeToNearestSampleCtl(obj,time)
            samples = time * obj.sampleRateCtl; %#ok<*MCSUP>
            actualTime = round(samples) / obj.sampleRateCtl;
        end
        
        function actualTime = zprvRoundTimeToNearestSampleAcq(obj,time)
            samples = time * obj.sampleRate; %#ok<*MCSUP>
            actualTime = round(samples) / obj.sampleRate;
        end
        
        function generateTrigger(~,deviceName,triggerLine)
            % generates a trigger on PFI line specified by triggerLine
            % usage: generateTrigger('Dev1','PFI11');
            
            digitalLine = scanimage.util.translateTriggerToPort(triggerLine);
            
            hTask = most.util.safeCreateTask('Trigger Generator');
            try
                hTask.createDOChan(deviceName,digitalLine);
                hTask.writeDigitalData([0;1;0],0.5,true);
            catch err
                hTask.clear();
                rethrow(err);
            end
            hTask.clear();
        end
	
	    function [device,terminal,frequency] = gethTrigRefClk(obj)
            device = obj.hDAQAux.name; % to get the capitalization right
            switch obj.hDAQAux.busType
                case {'DAQmx_Val_PXI','DAQmx_Val_PXIe'}
                    terminal = ['/' obj.hDAQAux.name '/PXI_Clk10'];
                    frequency = 10e6;
                    
                    if ~isempty(obj.mdfData.referenceClockIn)
                        most.idioms.warn(['LinScan: Potential trigger routing conflict detected: ', ...
                            'Device %s inherits its reference clock from the PXI chassis 10MHz clock ', ...
                            'but an external reference clock is configured in the MDF setting referenceClockIn = ''%s''',...
                            'Please set referenceClockIn = '''' and remove all incoming clocks from this pin'],...
                        obj.hDAQAux.name,obj.mdfData.referenceClockIn);
                    end
                otherwise
                    if isempty(obj.mdfData.referenceClockIn)
                        terminal = '';
                        frequency = [];
                    else
                        terminal = ['/' obj.hDAQAux.name '/' obj.mdfData.referenceClockIn];
                        frequency = 10e6;
                    end
            end
        end
    end
end

%% local functions
function sampleRate = findNextPower2SampleRate(sourceSampleRate,maxSampleRate)
    if isempty(sourceSampleRate) || isempty(maxSampleRate)
        sampleRate = [];
    else
        sampleRate = min(sourceSampleRate, sourceSampleRate / 2^ceil(log2(sourceSampleRate/maxSampleRate)));
    end
end

function s = zlclAppendDependsOnPropAttributes(s)
    s.scannerset.DependsOn = horzcat(s.scannerset.DependsOn,{'pixelBinFactor','fillFractionSpatial'});
end

function s = defaultMdfSection()
    s = [...
        most.HasMachineDataFile.makeEntry('deviceNameAcq','','string identifying NI DAQ board for PMT channels input')...
        most.HasMachineDataFile.makeEntry('deviceNameAux','','string identifying NI DAQ board for outputting clocks. leave empty if unused. Must be a X-series board')...
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('externalSampleClock',false,'Logical: use external sample clock connected to the CLK IN terminal of the FlexRIO digitizer module')...
        most.HasMachineDataFile.makeEntry('externalSampleClockRate',80e6,'[Hz]: nominal frequency of the external sample clock connected to the CLK IN terminal (e.g. 80e6); actual rate is measured on FPGA')...
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('Optional')... % comment only
        most.HasMachineDataFile.makeEntry('channelsInvert',false,'scalar or vector identifiying channels to invert. if scalar, the value is applied to all channels')...
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('xGalvo','','x Galvo device name')...
        most.HasMachineDataFile.makeEntry('yGalvo','','y Galvo device name')...
        most.HasMachineDataFile.makeEntry('fastZs',{{}},'fastZ device names')...
        most.HasMachineDataFile.makeEntry('beams',{{}},'fastZ device names')...
        most.HasMachineDataFile.makeEntry('shutters',{{}},'shutter device names')...
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('referenceClockIn','','one of {'''',PFI14} to which 10MHz reference clock is connected on Aux board. Leave empty for automatic routing via PXI bus')...
        most.HasMachineDataFile.makeEntry('enableRefClkOutput',false,'Enables/disables the export of the 10MHz reference clock on PFI14')...
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('Acquisition')... % comment only
        most.HasMachineDataFile.makeEntry('channelIDs',[],'Array of numeric channel IDs for PMT inputs. Leave empty for default channels (AI0...AIN-1)')...
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('Advanced/Optional:')... % comment only
        most.HasMachineDataFile.makeEntry('stripingEnable',true,'enables/disables striping display')...
        most.HasMachineDataFile.makeEntry('stripingMaxRate',10,'[Hz] determines the maximum display update rate for striping')...
        most.HasMachineDataFile.makeEntry('maxDisplayRate',30,'[Hz] limits the maximum display rate (affects frame batching)')...
        most.HasMachineDataFile.makeEntry('internalRefClockSrc','','Reference clock to use internally')...
        most.HasMachineDataFile.makeEntry('internalRefClockRate',[],'Rate of reference clock to use internally')...
        most.HasMachineDataFile.makeEntry('secondaryFpgaFifo',false,'specifies if the secondary fpga fifo should be used')...
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('Laser Trigger')... % comment only
        most.HasMachineDataFile.makeEntry('LaserTriggerPort', '','Port on FlexRIO AM digital breakout (DIO0.[0:3]) or digital IO DAQ (PFI[0:23]) where laser trigger is connected.')...
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
