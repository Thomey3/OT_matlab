classdef FastZ < scanimage.interfaces.Component
    %FastZ     Functionality to control volume acquisition through Fast-Z mode

    %% USER PROPS
    properties (SetObservable)
        enableFieldCurveCorr = false;   % Boolean, when true use fast z to correct for scanner field curvature
        flybackTime = 0;                % Time, in seconds, for axial position/ramp to settle.
        volumePeriodAdjustment = -6e-4; % Time, in s, to add to the nominal volume period, when determining fastZ sawtooth period used for volume imaging
        actuatorLag = 0;                % Acquisition delay, in seconds, of fastZScanner.
    end
    
    properties (SetObservable,SetAccess = ?scanimage.interfaces.Component)
        enable = false;                 % Boolean, when true, FastZ is enabled.
    end
    
    properties (Dependent,Transient,SetObservable)
        position;
        waveformType;
    end
    
    properties (Dependent,SetObservable)
        numDiscardFlybackFrames;        % Number of discarded frames for each period
        discardFlybackFrames;           % Logical indicating whether to discard frames during fastZ scanner flyback; leave this in for the moment to maintain support for openTiff
        numDiscardFlybackFramesForDisplay;
        hasFastZ;                       % Indicates if the current imaging system has an associated fastz actuator
    end
    
    properties (Hidden,SetAccess=private,Transient)
        extFrameClockTerminal;          % String. External frame-clock terminal.
        volumePeriodAdjSamples;
        syncedOutputMode = false;
    end
    
    %% INTERNAL PROPS
    properties (Hidden)
        useScannerTimebase = true;
        maxSampleRate;
    end
    
    properties (Hidden,SetAccess=private)        
        hAOTask;
        hFastZs = {};
        hResourceStoreListener = event.listener.empty();
        
        bufferNeedsUpdateAsync = false;
        bufferUpdatingAsyncNow = false;
        
        outputActive = false;
        sharingScannerDaq = false;
        
        hListeners = event.listener.empty(0,1);
    end
    
    properties (Hidden,Dependent)
        currentFastZs
        scanners
        currentScanners
    end
    
    %%% ABSTRACT PROPERTY REALIZATION (most.Model)
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = ziniInitPropAttributes();
        mdlHeaderExcludeProps = {'numDiscardFlybackFramesForDisplay','positionAbsolute'}
    end
    
    %%% ABSTRACT PROPERTY REALIZATION (scanimage.interfaces.Component)
    properties (SetAccess = protected, Hidden)
        numInstances = 0;
    end
    
    properties (Constant, Hidden)
        COMPONENT_NAME = 'FastZ';               % [char array] short name describing functionality of component e.g. 'Beams' or 'FastZ'
        PROP_TRUE_LIVE_UPDATE = {};             % Cell array of strings specifying properties that can be set while the component is active
        PROP_FOCUS_TRUE_LIVE_UPDATE = {};       % Cell array of strings specifying properties that can be set while focusing
        DENY_PROP_LIVE_UPDATE = {'enable'};     % Cell array of strings specifying properties for which a live update is denied (during acqState = Focus)
        FUNC_TRUE_LIVE_EXECUTION = {};          % Cell array of strings specifying functions that can be executed while the component is active
        FUNC_FOCUS_TRUE_LIVE_EXECUTION = {};    % Cell array of strings specifying functions that can be executed while focusing
        DENY_FUNC_LIVE_EXECUTION = {};          % Cell array of strings specifying functions for which a live execution is denied (during acqState = Focus)
    end
    
    %% LIFECYCLE
    methods (Access = ?scanimage.SI)
        function obj = FastZ()
            obj@scanimage.interfaces.Component('SI FastZ');
        end
    end
    
    methods
        function delete(obj)
            obj.deinit()
        end
    end
    
    methods (Hidden)        
        function deinit(obj)
            most.idioms.safeDeleteObj(obj.hAOTask);
            most.idioms.safeDeleteObj(obj.hListeners);
            most.idioms.safeDeleteObj(obj.hResourceStoreListener);
        end
        
        function reinit(obj)
            obj.hResourceStoreListener = most.ErrorHandler.addCatchingListener(obj.hResourceStore,'hResources','PostSet',@(varargin)obj.searchForFastZs);
            obj.searchForFastZs();
        end
        
        function searchForFastZs(obj)
            oldFastZs = obj.hFastZs;
            obj.hFastZs = obj.hResourceStore.filterByClass('dabs.resources.devices.FastZ');
            obj.numInstances = numel(obj.hFastZs);
            
            if ~isequal(oldFastZs,obj.hFastZs)
                obj.attachFastZListeners();
            end
        end
        
        function attachFastZListeners(obj)
            most.idioms.safeDeleteObj(obj.hListeners);
            obj.hListeners = event.listener.empty();
            
            for idx = 1:numel(obj.hFastZs)
                hFastZ = obj.hFastZs{idx};
                hFastZ.optimizationFcn = @scanimage.mroi.scanners.optimizationFunctions.proportionalOptimization;
                
                if isempty(hFastZ.errorMsg)
                    try
                        hFastZ.park();
                    catch ME
                        most.idioms.warn(sprintf('Failed to park FastZ %s. Error:\n%s',hFastZ.name,ME.message));
                    end
                end
                
                obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(hFastZ,'targetPosition','PostSet',@dummySetPosition);
            end
            
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hSI,'hScan2D','PostSet',@dummySetPosition);
            
            function dummySetPosition(varargin)
                obj.position = NaN;
            end
        end
    end
    
    %% PROP ACCESS
    methods        
        function v = get.currentFastZs(obj)
            v = obj.hSI.hScan2D.hFastZs;
        end
        
        function v = get.scanners(obj)
            v = obj.wrapFastZs(obj.hFastZs);
        end
        
        function v = get.currentScanners(obj)
            v = obj.wrapFastZs(obj.currentFastZs);
        end
        
        function scanners = wrapFastZs(obj,hFastZs)
            scanners = scanimage.mroi.scanners.FastZAnalog.empty();
            
            for idx = 1:numel(hFastZs)
                hFastZ = hFastZs{idx};
                scanner = scanimage.mroi.scanners.FastZAnalog(hFastZ);
                scanner.flybackTime = obj.flybackTime;
                scanner.actuatorLag = obj.actuatorLag;
                scanner.enableFieldCurveCorr = obj.enableFieldCurveCorr;
                scanner.actuatorLag = obj.actuatorLag;
                scanner.fieldCurvature = makeFieldCurvature();
                
                scanners(end+1) = scanner;
            end
            
            %%% Nested function
            function fieldCurvature = makeFieldCurvature()
                zs  = obj.hSI.fieldCurvatureZs;
                rxs = obj.hSI.fieldCurvatureRxs;
                rys = obj.hSI.fieldCurvatureRys;
                tip = obj.hSI.fieldCurvatureTip;
                tilt = obj.hSI.fieldCurvatureTilt;
                
                lengths = [numel(zs),numel(rxs),numel(rys)];
                if lengths(1)~=lengths(2) || lengths(2)~=lengths(3)
                    most.ErrorHandler.logAndReportError('Incorrect values for field curvature correction');
                end
                
                minlength = min(lengths);
                zs  = zs(1:minlength);
                rxs = rxs(1:minlength);
                rys = rys(1:minlength);
                
                fieldCurvature = struct('zs',zs,'rxs',rxs,'rys',rys,'tip',tip,'tilt',tilt);
            end
        end
        
        function set.position(obj,val)
            % For UI update only
        end
        
        function val = get.position(obj)
            hFastZs_ = obj.currentFastZs;
            
            if isempty(hFastZs_)
                val = 0;
            else
                val = hFastZs_{1}.targetPosition;
            end
        end
        
        function val = get.hasFastZ(obj)
            val = ~isempty(obj.currentFastZs);
        end
        
        function set.numDiscardFlybackFrames(obj,val)
            obj.mdlDummySetProp(val,'numDiscardFlybackFrames');
        end
         
        function val = get.numDiscardFlybackFrames(obj)
            if obj.hSI.hStackManager.enable && obj.hSI.hStackManager.stackMode == scanimage.types.StackMode.fast
                val = obj.numDiscardFrames;
            else
                val = 0;
            end
        end
        
        function set.numDiscardFlybackFramesForDisplay(obj,val)
            obj.mdlDummySetProp(val,'numDiscardFlybackFramesForDisplay');
        end
        
        function val = get.numDiscardFlybackFramesForDisplay(obj)
            val = obj.numDiscardFrames();
        end
        
        function val = numDiscardFrames(obj)
            if strcmp(obj.waveformType, 'sawtooth') && length(obj.hSI.hStackManager.zs) > 1 && obj.hSI.hStackManager.actualNumVolumes > 1
                if ~obj.hasFastZ
                    val = 0;
                else
                    %TODO: Tighten up these computations a bit to deal with edge cases
                    %TODO: Could account for maximum slew rate as well, at least when 'velocity' property is available
                    
                    val = ceil(obj.flybackTime/obj.hSI.hRoiManager.scanFramePeriod);
                    
                    if isinf(val) || isnan(val)
                        val = 0;
                    end
                end
            else
                val = 0;
            end
        end
        
        function set.discardFlybackFrames(obj,val)
            obj.mdlDummySetProp(val,'discardFlybackFrames');
        end
        
        function val = get.discardFlybackFrames(obj)
            val = obj.numDiscardFlybackFrames > 0;
        end
        
        function set.actuatorLag(obj,val)
            val = obj.validatePropArg('actuatorLag',val);
            if obj.componentUpdateProperty('actuatorLag',val)
                obj.actuatorLag = val;
            end
        end
        
        function set.flybackTime(obj,val)
            val = obj.validatePropArg('flybackTime',val);
            if obj.componentUpdateProperty('flybackTime',val)
                obj.flybackTime = val;
            end
        end
        
        function set.volumePeriodAdjustment(obj,val)
            if obj.componentUpdateProperty('volumePeriodAdjustment',val)
                obj.volumePeriodAdjustment = val;
            end
        end
        
        function set.waveformType(obj,val)
            % No-op
        end
        
        function val = get.waveformType(obj)
            val = obj.hSI.hStackManager.stackFastWaveformType;
            switch val
                case scanimage.types.StackFastWaveformType.sawtooth
                    val = 'sawtooth';
                case scanimage.types.StackFastWaveformType.step
                    val = 'step';
                otherwise
                    error('Unknown fast waveform type: %s',val);
            end
        end
        
        function set.enableFieldCurveCorr(obj,v)
            if obj.componentUpdateProperty('enableFieldCurveCorr',v)
                obj.enableFieldCurveCorr = v;
            end
        end
        
        function val = get.extFrameClockTerminal(obj)
            % This routine configures the start trigger for hTask
            % it first tries to connect the start trigger to the internal
            % beamsclock output of Scan2D. If this route fails, it uses the
            % external trigger terminal configured in the MDF
            
            if isempty(obj.hAOTask)
                val = '';
            else
                try
                    % Try internal routing
                    internalTrigTerm = obj.hSI.hScan2D.trigFrameClkOutInternalTerm;
                    obj.hAOTask.cfgDigEdgeStartTrig(internalTrigTerm);
                    obj.hAOTask.control('DAQmx_Val_Task_Reserve'); % if no internal route is available, this call will throw an error
                    obj.hAOTask.control('DAQmx_Val_Task_Unreserve');
                    
                    val = internalTrigTerm;
                    % fprintf('FastZ: internal trigger route found: %s\n',val);
                catch ME
                    % Error -89125 is expected: No registered trigger lines could be found between the devices in the route.
                    % Error -89139 is expected: There are no shared trigger lines between the two devices which are acceptable to both devices.
                    if isempty(strfind(ME.message, '-89125')) && isempty(strfind(ME.message, '-89139')) % filter error messages
                        rethrow(ME)
                    end
                    
                    % No internal route available - use MDF settings
                    hFrameClockIns = cellfun(@(hFz)hFz.hFrameClockIn,obj.currentFastZs,'UniformOutput',false);
                    frameClockNames = cell(size(hFrameClockIns));
                    for idx = 1:numel(hFrameClockIns)
                        if most.idioms.isValidObj(hFrameClockIns{idx})
                            frameClockNames{idx} = hFrameClockIns{idx}.name;
                        else
                            frameClockNames{idx} = '';
                        end
                    end
                    
                    most.ErrorHandler.assert(numel(unique(frameClockNames))==1 ...
                        , 'FastZ cannot synchronize to scanning system. Ensure the same frame clock input is specified for FastZs %s' ...
                        , strjoin(cellfun(@(hFz)hFz.name,obj.currentFastZs,'UniformOutput',false)) ...
                        );
                    
                    frameClockName = unique(frameClockNames);
                    most.ErrorHandler.assert(~isempty(frameClockName) ...
                        , 'FastZ cannot synchronize to scanning system. No frame clock input is defined for FastZs %s' ...
                        , strjoin(cellfun(@(hFz)hFz.name,obj.currentFastZs,'UniformOutput',false)) ...
                        );
                    
                    val = frameClockName{1};
                end
            end
        end
        
        function v = get.outputActive(obj)
            v = ~isempty(obj.currentFastZs);
            v = v && (obj.hSI.hStackManager.isFastZ || obj.hSI.hRoiManager.isLineScan || obj.enableFieldCurveCorr);
            v = v && ~obj.hSI.hScan2D.builtinFastZ; % disables FastZ for SlmScan
        end
    end
    
    %% USER METHODS
    methods
        function move(obj,hFastZ,position,force)
            if nargin < 4 || isempty(force)
                force = false;
            end
            
            assert(isa(hFastZ,'dabs.resources.devices.FastZAnalog'));
            validateattributes(position,{'numeric'},{'scalar','nonnan','finite','real'});
            
            fastZIdx = find( cellfun(@(hF)hF==hFastZ,obj.currentFastZs), 1);
            
            isCurrentFastZ = ~isempty(fastZIdx);
            bufferedOutput = isCurrentFastZ && obj.active && obj.outputActive;
            moveNotAllowed = isCurrentFastZ && any( strcmpi(obj.hSI.acqState,{'grab','loop'}) );
            
            if ~force
                most.ErrorHandler.assert(~moveNotAllowed,'Cannot move FastZ %s during an active acquisition.',hFastZ.name);
            end
            
            if bufferedOutput
                % this is only relevant for focus with field curvature enabled
                zRelative = obj.hSI.hStackManager.zsRelative(fastZIdx)-obj.hSI.hStackManager.zsRelativeOffsets(fastZIdx);
                obj.hSI.hStackManager.zsRelativeOffsets(fastZIdx) = position-zRelative;
                
                obj.hSI.hWaveformManager.updateWaveforms();
                obj.liveUpdate();                
                
                hFastZ.targetPosition = position;
            else
                hFastZ.move(position);
            end
        end
        
        function target = readTarget(obj)
            target = nan(1,numel(obj.hFastZs));
            for idx = 1:numel(obj.hFastZs)
                hFastZ = obj.hFastZs{idx};
                try
                    target(idx) = hFastZ.targetPosition;
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
            end
        end
        
        function output = readOutput(obj)
            output = nan(1,numel(obj.hFastZs));
            for idx = 1:numel(obj.hFastZs)
                hFastZ = obj.hFastZs{idx};
                try
                    output(idx) = hFastZ.readPositionOutput();
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
            end
        end
        
        function position = readFeedback(obj)
            position = nan(1,numel(obj.hFastZs));
            for idx = 1:numel(obj.hFastZs)
                hFastZ = obj.hFastZs{idx};
                try
                    position(idx) = hFastZ.readPositionFeedback();
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
            end
        end
        
        function park(obj)
            if obj.componentExecuteFunction('park')
                for idx = 1:numel(obj.hFastZs)
                    try
                        obj.hFastZs(idx).park();
                    catch ME
                        most.ErrorHandler.logAndReportError(ME);
                    end
                end
            end
        end
        
        function [toutput,desWvfm,cmdWvfm,tinput,respWvfm] = testActuator(obj)
            % TESTACTUATOR  Perform a test motion of the z-actuator
            %   [toutput,desWvfm,cmdWvfm,tinput,respWvfm] = obj.testActuator
            %
            % Performs a test motion of the z-actuator and collects position
            % feedback.  Typically this is displayed to the user so that they
            % can tune the actuator control.
            %
            % OUTPUTS
            %   toutput    Times of analog output samples (seconds)
            %   desWvfm    Desired waveform (tuning off)
            %   cmdWvfm    Command waveform (tuning on)
            %   tinput     Times of analog intput samples (seconds)
            %   respWvfm   Response waveform

            % TODO(doc): units on outputs
            
            assert(obj.numInstances > 0);
            assert(~obj.active, 'Cannot run test during active acquisition.');
            assert(~isa(obj.hScanner,'scanimage.mroi.scanners.FastZSlm'),'Cannot run waveform test for a SLM Z-actuator');
            
            hWb = waitbar(0,'Preparing Waveform and DAQs...','CreateCancelBtn',@(src,evt)delete(ancestor(src,'figure')));
            hHome = obj.hSI.hStackManager.getFocusPosition();
            
            try
                %% prepare waveform
                zs = obj.hSI.hStackManager.zs;
                zsRelative = obj.hSI.hStackManager.zsRelative;
                fb = obj.numDiscardFrames();
                wvType = obj.hSI.hFastZ.waveformType;
                scannerSet = obj.hSI.hScan2D.scannerset;
                scannerSet.fastz.useScannerTimebase = false;
                [toutput, desWvfm, cmdWvfm] = scannerSet.zWvfm(obj.hSI.hScan2D.currentRoiGroup,zs,zsRelative,fb,wvType);
                ao = obj.hScanner.refPosition2Volts(cmdWvfm);
                sLen = length(ao);
                testWvfm = repmat(ao,2,1);
                
                %% execute waveform test
                aoOutputRate = obj.hScanner.sampleRateHz;
                assert(most.idioms.isValidObj(hWb),'Waveform test cancelled by user');
                data = obj.hScanner.hDevice.testWaveformVolts(testWvfm,aoOutputRate,[],[],[],hWb);
                waitbar(100,hWb,'Analyzing data...');
                
                %% parse and scale data
                respWvfm = obj.hScanner.volts2RefPosition(data(1+sLen:sLen*2));
                tinput = (1:sLen)'/aoOutputRate;
                cleanup();
            catch ME
                cleanup();
                ME.rethrow
            end
            
            function cleanup()
                obj.goHome();
                delete(hWb);
                obj.hSI.hStackManager.setFocusPosition(hHome,scanimage.types.StackActuator.fastZ);
            end
        end
        
        function calibrateFastZ(obj,silent)
            if nargin < 2 || isempty(silent)
                silent = false;
            end
            
            if isempty(obj.hScanner) || ~isvalid(obj.hScanner)
                most.idioms.warn('FastZ is not initialized');
                return
            end
            
            if ~silent
                button = questdlg(sprintf('The FastZ actuator is going to move over its entire range.\nDo you want to continue?'));
                if ~strcmpi(button,'Yes')
                    fprintf('FastZ calibration cancelled by user.\n');
                    return
                end
            end
            
            hWb = waitbar(0,'Calibrating FastZ');
            try
                obj.hScanner.hDevice.calibrate();
                waitbar(1,hWb);
            catch ME
                most.idioms.safeDeleteObj(hWb);
                rethrow(ME);
            end
            most.idioms.safeDeleteObj(hWb);
        end
    end
    
    %% FRIEND METHODS
    methods (Hidden)        
        function updateSliceAO(obj)
            obj.liveUpdate();
        end
        
        function liveUpdate(obj)
            if obj.active && obj.outputActive
                if obj.sharingScannerDaq
                    obj.hSI.hScan2D.updateLiveValues(false);
                    
                elseif most.idioms.isValidObj(obj.hAOTask)
                    if obj.bufferUpdatingAsyncNow
                        % async call currently in progress. schedule update after current update finishes
                        obj.bufferNeedsUpdateAsync = true;
                    else
                        obj.bufferNeedsUpdateAsync = false;
                        
                        if ~obj.hSI.hScan2D.simulated
                            obj.bufferUpdatingAsyncNow = true;
                            
                            [ao, ~] = obj.getAO();
                            obj.hAOTask.writeAnalogDataAsync(ao,[],[],[],@(src,evt)obj.updateBufferAsyncCallback(src,evt));
                        end
                    end
                end
            end
        end
        
        function updateBufferAsyncCallback(obj,~,evt)
            obj.bufferUpdatingAsyncNow = false;
            
            if evt.status ~= 0 && evt.status ~= 200015 && obj.active
                fprintf(2,'Error updating fastZ buffer: %s\n%s\n',evt.errorString,evt.extendedErrorInfo);
            end

            if obj.bufferNeedsUpdateAsync
                obj.liveUpdate();
            end
        end
        
        function [ao, samplesPerTrigger] = getAO(obj)
            ao = obj.hSI.hWaveformManager.scannerAO.ao_volts.Z;
            if obj.volumePeriodAdjSamples > 0
                ao(end+1:end+obj.volumePeriodAdjSamples,:) = ao(end,:);
            elseif obj.volumePeriodAdjSamples < 0
                ao(end+obj.volumePeriodAdjSamples,:) = ao(end,:);
                ao(end+obj.volumePeriodAdjSamples+1:end,:) = [];
            end
            ao = double(ao);
            samplesPerTrigger = obj.hSI.hWaveformManager.scannerAO.ao_samplesPerTrigger.Z + obj.volumePeriodAdjSamples;
        end
    end
    
    %% INTERNAL METHODS
    methods (Hidden)        
        function updateTaskConfiguration(obj)
            most.idioms.safeDeleteObj(obj.hAOTask);
            obj.hAOTask = [];
            
            scannerset = obj.hSI.hScan2D.scannerset;
            fastZScanners = scannerset.fastz;
            
            taskName = 'FastZ_AO';
            obj.hAOTask = most.util.safeCreateTask(taskName);
            for idx = 1:numel(fastZScanners)
                hFastZ_ = fastZScanners(idx).hDevice;
                daqDeviceName = hFastZ_.hAOControl.deviceName;
                channelID = hFastZ_.hAOControl.channelID;
                obj.hAOTask.createAOVoltageChan(daqDeviceName,channelID);
            end
            
            assert(all([fastZScanners.sampleRateHz]==fastZScanners(1).sampleRateHz),'All FastZ Scanners need to have same sample rate');
            sampleRateHz = fastZScanners(1).sampleRateHz;
            
            obj.cfgSampClkTimebase(obj.hAOTask,obj.hSI.hScan2D);
            
            assert(~isempty(obj.hSI.hWaveformManager.scannerAO.ao_volts(1).Z));
            %Update AO Buffer
            [ao, N] = obj.getAO();
            
            obj.hAOTask.cfgSampClkTiming(sampleRateHz, 'DAQmx_Val_FiniteSamps', N);
            obj.hAOTask.cfgDigEdgeStartTrig(obj.extFrameClockTerminal, 'DAQmx_Val_Rising');
            obj.hAOTask.set('startTrigRetriggerable',true);
            
            obj.hAOTask.cfgOutputBuffer(N);
            if ~any([fastZScanners.simulated])
                obj.hAOTask.writeAnalogData(ao);
            end
            obj.hAOTask.control('DAQmx_Val_Task_Verify'); %%% Verify Task Configuration (mostly for trigger routing)
        end
    end
    
    %%% ABSTRACT METHOD Implementation (scanimage.interfaces.Component)
    methods (Hidden, Access = protected)
        function componentStart(obj)
        %   Runs code that starts with the global acquisition-start command
            if obj.outputActive
                obj.sharingScannerDaq = obj.hSI.hScan2D.controllingFastZ;
                
                if ~obj.sharingScannerDaq
                    obj.updateTaskConfiguration();
                    
                    if ~any([obj.currentScanners.simulated])
                        obj.hAOTask.start();
                    end
                end
            end
        end
        
        function componentAbort(obj)
            %   Runs code that aborts with the global acquisition-abort command
            if most.idioms.isValidObj(obj.hAOTask)
                try
                    obj.hAOTask.control('DAQmx_Val_Task_Abort');
                    obj.hAOTask.control('DAQmx_Val_Task_Unreserve');
                    obj.bufferNeedsUpdateAsync = false;
                    obj.bufferUpdatingAsyncNow = false;
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
            end
        end
        
        function cfgSampClkTimebase(obj,hTask,hScanner)
            if isa(hTask, 'dabs.ni.daqmx.Task')
                deviceName = hTask.deviceNames{1}; % to get the capitalization right
                isPxi = ismember(get(dabs.ni.daqmx.Device(deviceName),'busType'), {'DAQmx_Val_PXI','DAQmx_Val_PXIe'});
                
                if isPxi
                    obj.syncedOutputMode = (nargin > 2);
                    if obj.syncedOutputMode && isa(hScanner,'scanimage.components.scan2d.ResScan')
                        if obj.useScannerTimebase
                            tbSrc = hScanner.hTrig.getPXITerminal('resonantTimebaseOut');
                            tbRate = hScanner.resonantTimebaseNominalRate;
                        else
                            obj.syncedOutputMode = false;
                            tbSrc = ['/' deviceName '/PXI_Clk10'];
                            tbRate = 10e6;
                        end
                    else
                        tbSrc = ['/' deviceName '/PXI_Clk10'];
                        tbRate = 10e6;
                    end
                else
                    obj.syncedOutputMode = false;
                    tbSrc = 'OnboardClock';
                    tbRate = 100e6;
                end
                
                set(hTask,'sampClkTimebaseSrc',tbSrc);
                set(hTask,'sampClkTimebaseRate',tbRate);
                
                if obj.syncedOutputMode
                    obj.volumePeriodAdjSamples = - 8;
                elseif ~isempty(hScanner)
                    hFastZScanner = hScanner.scannerset.fastz(1);
                    obj.volumePeriodAdjSamples = floor(hFastZScanner.sampleRateHz * obj.volumePeriodAdjustment);
                end
            end
        end
    end
end

%% LOCAL
function s = ziniInitPropAttributes()
    s = struct;
    s.enable = struct('Classes','binaryflex','Attributes','scalar');
    s.numDiscardFlybackFrames = struct('DependsOn',{{'enable' 'hSI.hStackManager.actualNumVolumes' 'actuatorLag' 'flybackTime' 'hSI.hRoiManager.scanFrameRate'}});
    s.numDiscardFlybackFramesForDisplay = struct('DependsOn',{{'numDiscardFlybackFrames'}});
    s.discardFlybackFrames = struct('DependsOn',{{'numDiscardFlybackFrames'}});
    s.volumePeriodAdjustment = struct('Range',[-5e-3 5e-3]);
    s.flybackTime = struct('Attributes',{{'nonnegative', '<=', 1}});
    s.actuatorLag = struct('Attributes',{{'nonnegative', '<=', 1}});
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
