classdef WaveformGenerator < dabs.resources.Device & most.HasMachineDataFile & dabs.resources.configuration.HasConfigPage & dabs.resources.widget.HasWidget
    properties (SetAccess = protected)
        WidgetClass = 'dabs.resources.widget.widgets.waveFormGeneratorWidget';
    end
    
    properties (SetAccess = protected,Hidden)
        ConfigPageClass = 'dabs.resources.configuration.resourcePages.WaveformGeneratorPage';
    end
    
    methods (Static)
        function names = getDescriptiveNames()
            names = {'Waveform Generator'};
        end
        
    end
    
    %% ABSTRACT PROPERTY REALIZATIONS (most.HasMachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'Waveform Generator';
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
        
        mdfDefault = defaultMdfSection();
    end

    properties (SetObservable)
        taskType = 'Analog';                                        % The type of task  e.g. 'Analog' or 'Digital'
        sampleRate_Hz = 2e6;                                        % Sampling rate of the task
        startTriggerPort = dabs.resources.Resource.empty();         % digital input or output port used for triggering waveform output
        startTriggerEdge = 'rising';                                % Whether the rising or falling edge on the startTriggerPort starts waveform output.
        sampleMode = 'continuous';                                  % Whether the waveform loops through the waveform continuously or pauses/stops at samplesPerTrigger
        allowRetrigger = false;                                     % Whether or not to allow finite tasks to be triggered multiple times (e.g. if samplesPerTrigger < bufferSize_samples, the likely intent is to allow retrigger to execute the buffer in parts)
        
        hTask = dabs.vidrio.ddi.Task.empty();                       % Task object backend 
        
        wvfrmFcn;                                                   % Name of the function generating the waveform
        
        feedbackWaveform;                                           % feedback waveform for plotting
    end

    events
        redrawWidget;
    end

    % Waveform parameters (Users decide which values are pertinent to their
    % waveform functions)
    properties (SetObservable)
        amplitude;                                                  % Amplitude in Volts of the waveform. Can be negative or positive for Analog Waveforms.
        defaultValueVolts;                                          % Resting value of the control line or waveform.
        periodSec;                                                  % Time in seconds between periodic points in the waveform
        startDelay;                                                 % Time in seconds between when output starts and signal begins (formed by Waveform)
        dutyCycle;                                                  % Percentage of Period in which signal is Active at Amplitude value vs Inactive at Default
        wvfmParams = dabs.generic.waveforms.waveformParams.empty(); % Value class passed to Waveform functions holding parameters
    end

    % Used to update waveform parameters
    properties
        hWvfmParamListeners = event.listener.empty(0,1);
    end
    
    % IO Ports. AI Feedback is disabled when Control is a DO task
    properties
        hAOControl  = dabs.resources.ios.AO.empty(1,0);
        hDOControl  = dabs.resources.ios.DO.empty(1,0);
        hAIFeedback = dabs.resources.ios.AI.empty(1,0);
    end
    
    %% Linear Scanner Stuff for waveform calibration/optimization
    properties (SetAccess = private, Dependent)
        isvDAQ
        simulated
        hDAQ;
    end
    
    properties (SetObservable)
        daqOutputRange;
        feedbackVoltLUT = zeros(0,2); % translates feedback Volts into position Volts
        MaxSampleRate;
    end

    properties(Hidden, SetAccess = private)
        hResourceListeners = event.listener.empty();
    end
    
    % These are needed for optimization (I think)
    properties (SetObservable, AbortSet)
        lastKnownFeedback_V = NaN;  % updated by function readPositionFeedback
        lastKnownOutput_V   = NaN;  % this is updated by LinScan
    end
    
    properties (Hidden)
        numSmoothTransitionPoints = 100;
    end
    
    properties
        feedbackTermCfg = '';
        slewRateLimit_V_per_s = Inf;
        calibrationData;
        waveformCacheBasePath = '';
        optimizationFcn = @scanimage.mroi.scanners.optimizationFunctions.deconvOptimization;
    end
    
    properties (Dependent)
        outputAvailable;
        feedbackAvailable;
        feedbackCalibrated;
        waveformCacheScannerPath;
        hControl;
    end
    %% End Props for Linear Scanner/Waveform Calibration/Optimization
    
    %% Lifecycle Methods
    methods
        function obj = WaveformGenerator(name)
            obj@dabs.resources.Device(name);
            obj = obj@most.HasMachineDataFile(true);

            obj.deinit();
            obj.loadMdf();
            obj.reinit();
        end
        
        function delete(obj)
            obj.deinit();
            most.idioms.safeDeleteObj(obj.hResourceListeners);
        end
        
        function reinit(obj)
            try
                obj.deinit();
                obj.errorMsg = '';
                
                assert(most.idioms.isValidObj(obj.hControl),'No output for Waveform generator control specified');
                
                obj.hControl.reserve(obj);
                
                if isa(obj.hControl, 'dabs.resources.ios.AO')
                    obj.hControl.slewRateLimit_V_per_s = obj.slewRateLimit_V_per_s;
                    obj.validateSlewRateLimit();
                end
                
                if most.idioms.isValidObj(obj.hAIFeedback)
                    obj.hAIFeedback.reserve(obj);
                    obj.hAIFeedback.termCfg = obj.feedbackTermCfg;
                end

                obj.createWvfmParamListeners();
                obj.createTask();

                % fix sample rate to the actual task's decimated timebase sample rate:
                obj.hTask.sampleRate = obj.sampleRate_Hz;
                obj.sampleRate_Hz = obj.hTask.sampleRate;
                
            catch ME
                obj.deinit();
                obj.errorMsg = sprintf('%s: initialization error: %s',obj.name,ME.message);
                most.ErrorHandler.logError(ME,obj.errorMsg);
            end
            

        end
        
        function deinit(obj)
            obj.errorMsg = 'Uninitialized';
            
            try
                obj.deleteTask();
                if most.idioms.isValidObj(obj.hControl)
                    obj.hControl.unreserve(obj);
                    % Or just get rid of this???
                    if strcmp(obj.taskType, 'Analog')
                        obj.hControl.slewRateLimit_V_per_s = Inf;
                    end
                end
                
                delete(obj.hWvfmParamListeners);
                obj.hWvfmParamListeners = event.listener.empty(0,1);
                
                if most.idioms.isValidObj(obj.hAIFeedback)
                    obj.hAIFeedback.unreserve(obj);
                    obj.hAIFeedback.termCfg = 'Default';
                end
                
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
        end
        
        function loadMdf(obj)
            success = true;
            success = success & obj.safeSetPropFromMdf('taskType', 'taskType');
            success = success & obj.safeSetPropFromMdf('sampleRate_Hz', 'sampleRate_Hz');
            success = success & obj.safeSetPropFromMdf('startTriggerPort', 'startTriggerPort');
            success = success & obj.safeSetPropFromMdf('startTriggerEdge', 'startTriggerEdge');
            success = success & obj.safeSetPropFromMdf('sampleMode', 'sampleMode');
            success = success & obj.safeSetPropFromMdf('allowRetrigger', 'allowRetrigger');
            success = success & obj.safeSetPropFromMdf('wvfrmFcn', 'wvfrmFcn');

            success = success & obj.safeSetPropFromMdf('amplitude','amplitude');
            success = success & obj.safeSetPropFromMdf('defaultValueVolts','defaultValueVolts');
            success = success & obj.safeSetPropFromMdf('periodSec','periodSec');
            success = success & obj.safeSetPropFromMdf('startDelay','startDelay');
            success = success & obj.safeSetPropFromMdf('dutyCycle','dutyCycle');

            success = success & obj.safeSetPropFromMdf('hControl', 'hControl');
            success = success & obj.safeSetPropFromMdf('hAIFeedback', 'hAIFeedback');

            if ~success
                obj.errorMsg = 'Device partially or improperly configured';
            end
        end
        
        function saveMdf(obj)
            obj.safeWriteVarToHeading('taskType', obj.taskType);
            obj.safeWriteVarToHeading('sampleRate_Hz', obj.sampleRate_Hz);
            obj.safeWriteVarToHeading('startTriggerPort', obj.startTriggerPort);
            obj.safeWriteVarToHeading('startTriggerEdge', obj.startTriggerEdge);
            obj.safeWriteVarToHeading('sampleMode', obj.sampleMode);
            obj.safeWriteVarToHeading('allowRetrigger', obj.allowRetrigger);

            obj.safeWriteVarToHeading('wvfrmFcn', obj.wvfrmFcn);

            % wvfmParams
            obj.safeWriteVarToHeading('amplitude',obj.amplitude);
            obj.safeWriteVarToHeading('defaultValueVolts',obj.defaultValueVolts);
            obj.safeWriteVarToHeading('periodSec',obj.periodSec);
            obj.safeWriteVarToHeading('startDelay',obj.startDelay);
            obj.safeWriteVarToHeading('dutyCycle',obj.dutyCycle);

%             obj.safeWriteVarToHeading('wvfmParams', obj.wvfmParams);

            obj.safeWriteVarToHeading('hControl', obj.hControl);
            obj.safeWriteVarToHeading('hAIFeedback', obj.hAIFeedback);
            
        end

    end
    
    %% Control
    methods
        function createTask(obj)
            switch obj.taskType
                case 'Analog'
                    obj.hTask = dabs.vidrio.ddi.AoTask(obj.hControl.hDAQ, obj.name);
                case 'Digital'
                    obj.hTask = dabs.vidrio.ddi.DoTask(obj.hControl.hDAQ, obj.name);
                otherwise
            end

            obj.hTask.addChannel(obj.hControl);
            notify(obj,'redrawWidget');
        end

        function writeLineToDefaultVal(obj)
            obj.writeLineToVal(obj.defaultValueVolts);
        end
        
        function writeLineToVal(obj, val)
           validateattributes(val, {'numeric'}, {'scalar','nonnan', 'finite'});
           if most.idioms.isValidObj(obj.hControl) && ~obj.hTask.active
               assert(val >= obj.daqOutputRange(1) && val <= obj.daqOutputRange(2), 'Value exceeds DAQ range');
               obj.hControl.setValue(val);
           end
        end
        
        function wvfmBuf = updateWaveform(obj)
            try
                wvfmBuf = obj.computeWaveform();
                if isrow(wvfmBuf)
                    wvfmBuf = wvfmBuf';
                end
                
                if isa(obj.hControl, 'dabs.resources.ios.AO')
                    if isempty(obj.waveformCacheScannerPath)
                        available = false;
                    else
                        [available, ~] = obj.isCached(obj.sampleRate_Hz,wvfmBuf);
                    end
    
                    if available
                        [~, outputWaveform, fdbkWaveform] = obj.getCachedOptimizedWaveform(obj.sampleRate_Hz, wvfmBuf);
                        obj.feedbackWaveform = fdbkWaveform;
                        wvfmBuf = outputWaveform;
                    end
                end
                
                obj.updateTask(wvfmBuf);
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
        end
        
        function wvfrm = computeWaveform(obj)
            if isempty(obj.wvfrmFcn)
                wvfrm = [];
                return
            end
            switch obj.taskType
                case 'Analog'
                    wvfrmFunc = str2func(sprintf('dabs.generic.waveforms.analog.%s',obj.wvfrmFcn));
                case 'Digital'
                    wvfrmFunc = str2func(sprintf('dabs.generic.waveforms.digital.%s',obj.wvfrmFcn));
                otherwise
            end
            
            obj.refreshWvfmParams();
            wvfrm = wvfrmFunc(obj.sampleRate_Hz, obj.wvfmParams);
        end

        function updateTask(obj, wvfmBuf)
            try
                if ~obj.hTask.active
                    bufSize = size(wvfmBuf, 1);
                    obj.hTask.sampleRate = obj.sampleRate_Hz;
                    obj.hTask.sampleMode = obj.sampleMode;
                    obj.hTask.samplesPerTrigger = bufSize;
                    obj.hTask.allowRetrigger = obj.allowRetrigger;
                    obj.hTask.startTriggerEdge = obj.startTriggerEdge;
                    if ~most.idioms.isValidObj(obj.startTriggerPort)
                        obj.hTask.startTrigger = '';
                    else
                        obj.hTask.startTrigger = obj.startTriggerPort.name;
                    end
                    obj.hTask.writeOutputBuffer(wvfmBuf);
                else
                    warning('Task is still running. Stop task or wait for it to finish before updating task and waveform');
                end
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
        end
        
        % Auto update on acqModeStart and focusStart
        function refreshWvfmParams(obj,varargin)
            if isempty(obj.wvfmParams)
                obj.wvfmParams = dabs.generic.waveforms.waveformParams;
            end

            obj.wvfmParams.period_Sec = obj.periodSec;
            obj.wvfmParams.amplitude_Volts = obj.amplitude;
            obj.wvfmParams.restVal_Volts = obj.defaultValueVolts;
            obj.wvfmParams.dutyCycle = obj.dutyCycle;
            obj.wvfmParams.startDelay_Sec = obj.startDelay;

            hSI = obj.hResourceStore.filterByName('ScanImage');
            if most.idioms.isValidObj(hSI) && most.idioms.isValidObj(hSI.hScan2D)
                if isa(hSI.hScan2D.scannerset, 'scanimage.mroi.scannerset.GalvoGalvo')
                    if hSI.hRoiManager.mroiEnable
                        obj.wvfmParams.linePeriodAcq  = NaN;
                        obj.wvfmParams.linePeriodScan = NaN;
                    else
                        ss = hSI.hRoiManager.currentRoiGroup.rois.scanfields;
                        [scan, acq] = hSI.hScan2D.scannerset.linePeriod(ss);
                        obj.wvfmParams.linePeriodAcq = acq;
                        obj.wvfmParams.linePeriodScan = scan;
                    end
                else
                    [scan, acq] = hSI.hScan2D.scannerset.linePeriod;
                    obj.wvfmParams.linePeriodAcq = acq;
                    obj.wvfmParams.linePeriodScan = scan;
                end
                
            
                obj.wvfmParams.framePeriod = hSI.hRoiManager.scanFramePeriod;
                obj.wvfmParams.frameFlyback = hSI.hScan2D.flybackTimePerFrame;
                obj.wvfmParams.scanfieldFlyto = hSI.hScan2D.flytoTimePerScanfield;
                obj.wvfmParams.linesPerFrame = hSI.hRoiManager.linesPerFrame;
                obj.wvfmParams.pxPerLine = hSI.hRoiManager.pixelsPerLine;
            end
        end
        
        function startTask(obj)
            try
                if most.idioms.isValidObj(obj.hTask)
                    obj.updateWaveform();
                    obj.hTask.start();
                    notify(obj, 'redrawWidget');
                end
            catch ME
               most.ErrorHandler.logAndReportError(ME); 
            end
        end
        
        function stopTask(obj)
            try
                if most.idioms.isValidObj(obj.hTask)
                   obj.hTask.stop();
                   notify(obj, 'redrawWidget');
                   obj.writeLineToDefaultVal();
                end
            catch ME
               most.ErrorHandler.logAndReportError(ME); 
            end
        end
        
        function deleteTask(obj)
            if most.idioms.isValidObj(obj.hTask )
                try
                    obj.stopTask();
                    obj.hTask.unreserveResource();
                    obj.writeLineToVal(0);
                    most.idioms.safeDeleteObj(obj.hTask);
                    obj.hTask = dabs.vidrio.ddi.Task.empty();
                catch ME
                   most.ErrorHandler.logAndReportError(ME); 
                end
                notify(obj, 'redrawWidget');
            end
        end
    end

    %% Management
    methods
        function createWvfmParamListeners(obj)
            obj.hWvfmParamListeners = [obj.hWvfmParamListeners most.ErrorHandler.addCatchingListener(obj,'amplitude','PostSet', @obj.refreshWvfmParams)...
                most.ErrorHandler.addCatchingListener(obj,'defaultValueVolts','PostSet', @obj.refreshWvfmParams)...
                most.ErrorHandler.addCatchingListener(obj,'periodSec','PostSet', @obj.refreshWvfmParams)...
                most.ErrorHandler.addCatchingListener(obj,'startDelay','PostSet', @obj.refreshWvfmParams)...
                most.ErrorHandler.addCatchingListener(obj,'dutyCycle','PostSet', @obj.refreshWvfmParams)];
        end
    end
    
    %% Getter/Setter for DAQ, Control, Task, and Waveform properties
    methods

        function val = get.isvDAQ(obj)
            val = isa(obj.hControl.hDAQ,'dabs.resources.daqs.vDAQ');
        end
        
        function val = get.simulated(obj)
            val = obj.hControl.hDAQ.simulated;
        end
        
        function val = get.hDAQ(obj)
           if most.idioms.isValidObj(obj.hControl) && isprop(obj.hControl, 'hDAQ')
               val = obj.hControl.hDAQ;
           else
               val = NaN; 
           end
        end
        
        function val = get.hControl(obj)
            switch obj.taskType
                case 'Analog'
                    if most.idioms.isValidObj(obj.hAOControl)
                        val = obj.hAOControl;
                    else
                        val = NaN;
                    end
                case 'Digital'
                    if most.idioms.isValidObj(obj.hDOControl)
                        val = obj.hDOControl;
                    else
                        val = NaN;
                    end
                otherwise
                    val = NaN;
            end
        end
        
        function set.hControl(obj, val)
            try
                switch obj.taskType
                    case 'Analog'
                        obj.hAOControl = val;
                        obj.hDOControl = '';
                    case 'Digital'
                        obj.hDOControl = val;
                        obj.hAOControl = '';
                    otherwise
                end
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
        end

        function set.hAOControl(obj,val)
            if isempty(val)
                obj.hAOControl.unreserve(obj);
                obj.hAOControl.unregisterUser(obj);
                obj.hAOControl = dabs.resources.ios.AO.empty(1,0);
            else
                val = obj.hResourceStore.filterByName(val);
                if ~isequal(val,obj.hAOControl)
                    if most.idioms.isValidObj(val)
                        validateattributes(val,{'dabs.resources.ios.AO'},{'scalar'});
                    end
                    
                    obj.deinit();
                    obj.hAOControl.unregisterUser(obj);
                    obj.hAOControl = val;
                    obj.hAOControl.registerUser(obj,'Control');
                end
            end
        end

        function set.hDOControl(obj,val)

            if isempty(val)
                obj.hDOControl.unreserve(obj);
                obj.hDOControl.unregisterUser(obj);
                obj.hDOControl = dabs.resources.ios.DO.empty(1,0);
            else
                val = obj.hResourceStore.filterByName(val);
                
                if ~isequal(val,obj.hDOControl)
                    if most.idioms.isValidObj(val)
                        validateattributes(val,{'dabs.resources.ios.DO'},{'scalar'});
                    end
                    
                    obj.deinit();
                    obj.hDOControl.unregisterUser(obj);
                    obj.hDOControl = val;
                    obj.hDOControl.registerUser(obj,'Control');
                end
            end
        end
        
        function set.hAIFeedback(obj,val)

            if isempty(val)
                obj.hAIFeedback.unreserve(obj);
                obj.hAIFeedback.unregisterUser(obj);
                obj.hAIFeedback = dabs.resources.ios.AI.empty(1,0);
            else
                val = obj.hResourceStore.filterByName(val);
                
                if ~isequal(val,obj.hAIFeedback)
                    if most.idioms.isValidObj(val)
                        validateattributes(val,{'dabs.resources.ios.AI'},{'scalar'});
                    end
                    
                    obj.deinit();
                    obj.hAIFeedback.unregisterUser(obj);
                    obj.hAIFeedback = val;
                    obj.hAIFeedback.registerUser(obj,'Feedback');
                end
            end
        end
        
        function set.taskType(obj, val)
            validateattributes(val,{'char'},{'vector'});
            assert(any(strcmp(val,{'Digital','Analog'})),'Task type must be either ''analog'' or ''digital''.');
            obj.taskType = val;
        end
        
        function set.sampleRate_Hz(obj, val)
            validateattributes(val, {'numeric'}, {'positive','scalar'});
            assert(val <= obj.MaxSampleRate, 'Desired sample rate exceeds DAQ capabilities')
            assert(val >= 200e6 / intmax('uint16'),'Sampling rate must be greater than 3052Hz (time base rate / 16-bit maximum)');
            obj.sampleRate_Hz = val;
        end
        
        function set.startTriggerPort(obj, val)
            val = obj.hResourceStore.filterByName(val);
            
            if ~isequal(val,obj.startTriggerPort)
                if most.idioms.isValidObj(obj.startTriggerPort)
                    obj.startTriggerPort.unregisterUser(obj);
                end
                
                if most.idioms.isValidObj(val)
                    validateattributes(val,{'dabs.resources.ios.DI','dabs.resources.ios.DO'},{'scalar'});
                    allowMultipleUsers = true;
                    val.registerUser(obj,'Start Trigger Port',allowMultipleUsers);
                end
                
                obj.startTriggerPort = val;
            end
        end
        
        function set.startTriggerEdge(obj, val)
            assert(ismember(val,{'rising','falling'}),'Task type must be either ''rising'' or ''falling''.');
            obj.startTriggerEdge = val;
        end
        
        function set.sampleMode(obj, val)
            assert(ismember(val,{'continuous','finite'}),'Task type must be either ''continuous'' or ''finite''.');
            obj.sampleMode = val;
        end
        
        function set.allowRetrigger(obj, val)
            validateattributes(val, {'logical','numeric'}, {'scalar','binary'});
            obj.allowRetrigger = logical(val);
        end
        
        function set.amplitude(obj,val)
            outputRange = obj.daqOutputRange();
            assert(isnumeric(val) && val>=outputRange(1) && val<=outputRange(2), 'Desired amplitude is invalid or exceeds DAQ output range!');
            obj.amplitude = val;
        end

        function set.defaultValueVolts(obj,val)
            outputRange = obj.daqOutputRange();
            assert(isnumeric(val) && val>=outputRange(1) && val<=outputRange(2), 'Desired default value is invalid or exceeds DAQ output range!');
            obj.defaultValueVolts = val();
        end

        function set.periodSec(obj,val)
            assert(isnumeric(val)&&~isnan(val)&&val>=0, 'Perdiod must be a postive number');
            obj.periodSec = val;
        end

        function set.startDelay(obj,val)
            assert(isnumeric(val)&&~isnan(val)&&val>=0, 'Start delay must be a postive number');
            obj.startDelay = val;
        end

        function set.dutyCycle(obj,val)
            assert(isnumeric(val)&&~isnan(val)&&val>=0&&val<=100, 'Invalid duty cycle, value range:0-100%');
            obj.dutyCycle = val;
        end
    end
    
    %% Waveform Calibration and Optimization Stuff
    methods
        function val = get.daqOutputRange(obj)
            if most.idioms.isValidObj(obj.hControl)
                if isa(obj.hControl, 'dabs.resources.ios.AO')
                    val = obj.hControl.outputRange_V;
                elseif isa(obj.hControl, 'dabs.resources.ios.DO')
                    val = [0 1];
                end
            else
                val = [-10 10];
            end
        end
        
        function val = get.MaxSampleRate(obj)
            if most.idioms.isValidObj(obj.hControl)
                val = obj.hControl.maxSampleRate_Hz;
            else
                val = 20e6;
            end
        end
        
        function set.numSmoothTransitionPoints(obj,val)
            validateattributes(val,{'numeric'},{'scalar','integer','nonnan','finite','positive'});
            obj.numSmoothTransitionPoints = val;
        end
        
        function set.feedbackTermCfg(obj,val)
            if isempty(val)
                val = '';
            else
                assert(ismember(val,{'Differential','RSE','NRSE'}),'Invalid terminal configuration ''%s''.',val);
            end
            
            obj.feedbackTermCfg = val;
            
            if most.idioms.isValidObj(obj.hAIFeedback)
                obj.hAIFeedback.termCfg = val;
            end
        end
        
        function val = get.outputAvailable(obj)
            val = isempty(obj.errorMsg) && most.idioms.isValidObj(obj.hControl);
        end
        
        function val = get.feedbackAvailable(obj)
            val = isempty(obj.errorMsg) && most.idioms.isValidObj(obj.hAIFeedback);
        end
        
        function val = get.feedbackCalibrated(obj)
            val = ~isempty(obj.feedbackVoltLUT);
        end
        
        function set.lastKnownFeedback_V(obj,v)
            obj.lastKnownFeedback_V = v; 
        end
        
        function set.lastKnownOutput_V(obj,val)
            if ~isnan(val)
                obj.hControl.lastKnownValue = val;
            end
        end
        
        function val = get.lastKnownOutput_V(obj)
            val = obj.hControl.lastKnownValue;
        end
        
        function [voltMean, voltSamples] = readPositionFeedback_V(obj,n)
            if nargin < 2 || isempty(n)
                n = 100;
            end
            
            voltMean = NaN;
            voltSamples = nan(n,1);
            
            if obj.feedbackAvailable && obj.feedbackCalibrated
                voltSamples = obj.hAIFeedback.readValue(n);
                voltMean = mean(voltSamples);
            end
            
            obj.lastKnownFeedback_V = voltMean;
        end
        
        function volts = readPositionOutput_V(obj)
            volts = obj.hControl.queryValue();
            if isnan(volts)
                volts = obj.hControl.lastKnownValue;
            end
            
            obj.lastKnownOutput_V = volts;
        end
        
        function set.slewRateLimit_V_per_s(obj,v)
            validateattributes(v,{'numeric'},{'scalar','nonnan','positive'});
            
            obj.slewRateLimit_V_per_s = v;
            
            if obj.positionAvailable && obj.hAOControl.supportsSlewRateLimit
                obj.hAOControl.slewRateLimit_V_per_s = v;
            end
            
            obj.validateSlewRateLimit();
        end
        
        function validateSlewRateLimit(obj)
            if ~isinf(obj.slewRateLimit_V_per_s)
                if obj.positionAvailable && ~obj.hAOControl.supportsSlewRateLimit
                    try
                        error('%s: slew rate limit for position task is set to %fV/s, but device does not support slew rate limiting.',obj.name,obj.slewRateLimit_V_per_s);
                    catch ME
                        most.ErrorHandler.logError(ME);
                    end
                end
            end
        end
        
        function calibrate(obj,hWb)
            if nargin<2 || isempty(hWb)
                msg = sprintf('%s: Calibrating feedback',obj.name);
                hWb = waitbar(0,msg);
                deleteWaitbar = true;
            else
                deleteWaitbar = false;
            end
            
            try
                if obj.outputAvailable && obj.feedbackAvailable
                    fprintf('%s: calibrating feedback',obj.name);
                    obj.calibrateFeedback(true,hWb);
                    
                    fprintf(' ...done!\n');
                else
                    error('%s: feedback not configured - nothing to calibrate\n',obj.name);
                end
            catch ME
                cleanup();
                rethrow(ME);
            end
            cleanup();
            
            function cleanup()
                if deleteWaitbar
                    most.idioms.safeDeleteObj(hWb);
                end
            end
        end
        
        function calibrateFeedback(obj,preventTrip,hWb)
            if nargin < 2 || isempty(preventTrip)
                preventTrip = true;
            end
            
            if nargin < 3 || isempty(hWb)
                hWb = [];
            end
            
            if ~isempty(hWb)
                if ~isvalid(hWb)
                    return
                else
                    msg = sprintf('%s: calibrating feedback',obj.name);
                    waitbar(0,hWb,msg);
                end
            end
            
            assert(obj.outputAvailable,'Position output not initialized');
            assert(obj.feedbackAvailable,'Feedback input not initialized');
            
            
            numTestPoints = 10;
            rangeFraction = 1;
            
            travelRangeMidPoint = sum(obj.daqOutputRange)/2;
            travelRangeCompressed = diff(obj.daqOutputRange)*rangeFraction;
            
            outputPositions = linspace(travelRangeMidPoint-travelRangeCompressed/2,travelRangeMidPoint+travelRangeCompressed/2,numTestPoints)';
            
            % move to first position
            obj.smoothTransitionVolts(outputPositions(1));
            if preventTrip && ~obj.hAOControl.supportsOutputReadback
                pause(3); % we assume we were at the park position initially, but we cannot know for sure. If galvo trips, wait to make sure they recover
            else
                pause(0.5);
            end
            
            feedbackVolts = zeros(length(outputPositions),1);
            
            cancelled = false;
            for idx = 1:length(outputPositions)
                if idx > 1
                    obj.smoothTransitionVolts(outputPositions(idx));
                    pause(0.5); %settle
                end
                averageNSamples = 100;
                samples = obj.hAIFeedback.readValue(averageNSamples);
                feedbackVolts(idx) = mean(samples);
                
                if ~isempty(hWb)
                    if ~isvalid(hWb)
                        cancelled = true;
                        break
                    else
                        waitbar(idx/length(outputPositions),hWb,msg);
                    end
                end
            end
            
            % park the galvo
            obj.smoothTransitionVolts(obj.defaultValueVolts);
            
            if cancelled
                return
            end
            
            outputVolts = outputPositions;

            
            [feedbackVolts_lut,sortIdx] = sort(feedbackVolts);
            outputVolts_lut = outputVolts(sortIdx);
            
            lut = [feedbackVolts_lut,outputVolts_lut];
            try
                validateLUT(lut);
                obj.feedbackVoltLUT = lut;
                plotCalibrationCurve();
            catch ME
                plotCalibrationCurveUnsuccessful();
                rethrow(ME);
            end
                
            %%% local functions
            function plotCalibrationCurve()
                hFig = most.idioms.figure('NumberTitle','off','Name','Scanner Calibration');
                hAx = most.idioms.axes('Parent',hFig,'box','on');
                plot(hAx,outputVolts,feedbackVolts,'o-');
                title(hAx,sprintf('%s Feedback calibration',obj.name));
                xlabel(hAx,'Position Output [Volt]');
                ylabel(hAx,'Position Feedback [Volt]');
                grid(hAx,'on');
                drawnow();
            end
            
            function plotCalibrationCurveUnsuccessful()
                hFig = most.idioms.figure('NumberTitle','off','Name','Scanner Calibration');
                hAx = most.idioms.axes('Parent',hFig,'box','on');
                plot(hAx,[outputVolts,feedbackVolts],'o-');
                legend(hAx,'Command Voltage','Feedback Voltage');
                title(hAx,sprintf('%s Feedback calibration\nunsuccessful',obj.name));
                xlabel(hAx,'Position Output [Volt]');
                ylabel(hAx,'Position Feedback [Volt]');
                grid(hAx,'on');
                drawnow();
            end
        end
        
        function feedback = testWaveformVolts(obj,waveformVolts,sampleRate,preventTrip,startVolts,goToPark,hWb)
            assert(obj.outputAvailable,'Position output not initialized');
            assert(obj.feedbackAvailable,'Feedback input not configured');
            assert(obj.feedbackCalibrated,'Feedback input not calibrated');
            
            if nargin < 4 || isempty(preventTrip)
                preventTrip = true;
            end
            
            if nargin < 5 || isempty(startVolts)
                startVolts = waveformVolts(1);
            end
            
            if nargin < 6 || isempty(goToPark)
                goToPark = true;
            end
            
            if nargin < 7 || isempty(hWb)
                hWb = waitbar(0,'Preparing Waveform and DAQs...','CreateCancelBtn',@(src,evt)delete(ancestor(src,'figure')));
                deletewb = true;
            else
                deletewb = false;
            end
            
            try
                
                
                %move to first position
                obj.writeLineToVal(startVolts);
                
                if preventTrip && ~obj.hAOControl.supportsOutputReadback
                    pause(2); % if galvos trip, ensure we recover before proceeding
                end
                
                positionTask = dabs.vidrio.ddi.AoTask(obj.hAOControl.hDAQ.hDevice,'Position Task');
                positionTask.addChannel(obj.hAOControl.channelID);
                positionTask.sampleMode = 'finite';
                positionTask.startTrigger = '';
                positionTask.triggerOnStart = true;
                positionTask.allowRetrigger = false;
                positionTask.autoStartStopSyncedTasks = true;
                positionTask.allowEarlyTrigger = false;
                positionTask.sampleRate = sampleRate;
                positionTask.samplesPerTrigger = length(waveformVolts);
                
                feedbackTask = dabs.vidrio.ddi.AiTask(obj.hAIFeedback.hDAQ.hDevice,'Feedback Task');
                feedbackTask.addChannel(obj.hAIFeedback.channelID,[],obj.hAIFeedback.termCfg);
                
                % Front Panel AI limited
                positionTask.sampleRate = feedbackTask.sampleRate;
                
                feedbackTask.syncTo(positionTask);
                
                positionTask.writeOutputBuffer(waveformVolts(:));
                positionTask.start();
                
                duration = length(waveformVolts)/sampleRate;
                if duration > .4
                    start = tic();
                    while toc(start) < duration
                        pause(0.1);
                        if ~updateCheckWb(hWb, toc(start)./duration, sprintf('%s: executing waveform test...',obj.name))
                            abort();
                            error('Waveform test cancelled by user');
                        end
                    end
                end
                
                if deletewb
                    most.idioms.safeDeleteObj(hWb);
                end
                
                assert(feedbackTask.waitUntilTaskDone(3), 'Failed to read data.');
                feedback = feedbackTask.readInputBuffer(length(waveformVolts));
                
                abort();
                
                % might not be accurate if process was aborted early!!
                obj.lastKnownOutput_V = waveformVolts(end);
                
                if goToPark
                    % park the galvo
                    obj.writeLineToVal(obj.defaultValueVolts);
                end
                
                % scale the feedback
%                 feedback = obj.feedbackVolts2PositionVolts(feedbackVolts);
            catch ME
                abort();
                obj.writeLineToDefaultVal();
                if deletewb
                    most.idioms.safeDeleteObj(hWb);
                end
                rethrow(ME);
            end
            
            function abort()
                if most.idioms.isValidObj(feedbackTask)
                    feedbackTask.abort();
                    feedbackTask.delete();
                end
                
                if most.idioms.isValidObj(positionTask)
                    positionTask.abort();
                    positionTask.delete();
                end
            end
            
            function continuetf = updateCheckWb(wb,prog,msg)
                if isa(wb,'function_handle')
                    continuetf = wb(prog,msg);
                else
                    continuetf = isvalid(hWb);
                    if continuetf
                        waitbar(toc(start)./duration,hWb,sprintf('%s: executing waveform test...',obj.name));
                    end
                end
            end
        end
        
        function smoothTransitionVolts(obj,newV)
            assert(obj.outputAvailable);
            
            if obj.hAOControl.supportsSlewRateLimit
                transition_limit_slew_rate(newV);
            else
                transition_stepwise(newV);
            end
            
            %%% Nested functions
            function transition_limit_slew_rate(newV)
                outputRange = obj.hAOControl.outputRange_V;
                newV = min(max(outputRange(1),newV),outputRange(2));
                
                oldSlewRateLimit_V_per_s = obj.hAOControl.slewRateLimit_V_per_s;
                
                try
                    if isinf(obj.hAOControl.slewRateLimit_V_per_s)
                        obj.hAOControl.slewRateLimit_V_per_s = 1000;
                    end
                    
                    oldV = obj.hAOControl.queryValue();
                    obj.hAOControl.setValue(newV);
                    
                    dV = abs(oldV-newV);
                    t = dV/obj.hAOControl.slewRateLimit_V_per_s;
                    
                    pause(t);
                catch ME
                    obj.hAOControl.slewRateLimit_V_per_s = oldSlewRateLimit_V_per_s;
                    ME.rethrow();
                end
                
                obj.hAOControl.slewRateLimit_V_per_s = oldSlewRateLimit_V_per_s;
            end
            
            function transition_stepwise(newV)
                oldV = obj.hAOControl.queryValue();
                if isnan(oldV)
                    oldV = obj.lastKnownOutput_V;
                end
                
                if isempty(oldV) || isnan(oldV)
                    oldV = obj.defaultValueVolts;
                    most.idioms.warn('Scanner %s attempted a smooth transition, but last position was unknown. Assumed park position.',obj.name);
                end
                
                if oldV==newV
                    numPoints = 1;
                else
                    numPoints = obj.numSmoothTransitionPoints;
                end
                
                try
                sequence = oldV + (newV-oldV) * linspace(0,1,numPoints);
                outputRange = obj.hAOControl.outputRange_V;
                catch ME
                   disp(ME); 
                end
                for output = sequence
                    output_coerced = min(max(outputRange(1),output),outputRange(2));
                    obj.hAOControl.setValue(output_coerced);
                end
            end
        end
        
    end
    
    
    % Setter / Getter methods
    methods
        function val = get.waveformCacheScannerPath(obj)
            if isempty(obj.waveformCacheBasePath)
                hSI = obj.hResourceStore.filterByName('ScanImage');
                if ~isempty(hSI)
                    obj.waveformCacheBasePath = fullfile(hSI.classDataDir, sprintf('Waveforms_Cache'));
                    val = fullfile(obj.waveformCacheBasePath, obj.name);
                else
                    val = [];
                end
            else
                val = fullfile(obj.waveformCacheBasePath, obj.name);
            end
        end
    end
    
    % Public methods
    methods
        function [path,hash] = computeWaveformCachePath(obj,sampleRateHz,desiredWaveform)
            hash = computeWaveformHash(sampleRateHz,desiredWaveform);
            if isempty(obj.waveformCacheScannerPath)
                path = [];
            else
                path = fullfile(obj.waveformCacheScannerPath,hash);
            end
        end
        
        %%
        % Caches the original waveform, sample rate, optimized waveform and
        % feedback (for error calculation) associated with the original
        % waveform. Original waveform and sample rate are used to create an
        % identifier hash to label the .mat file which stores the
        % associated data.        
        function cacheOptimizedWaveform(obj,sampleRateHz,desiredWaveform,outputWaveform,feedbackWaveform,optimizationData,info)
            if nargin<6 || isempty(optimizationData)
                optimizationData = [];
            end
            
            if nargin<7 || isempty(info)
                info = [];
            end
            
            [workingDirectory,hash] = obj.computeWaveformCachePath(sampleRateHz,desiredWaveform);
            if isempty(workingDirectory)
                warning('Could not cache waveform because waveformCacheBasePath or scanner name is not set');
                return
            end
            
            if ~exist(workingDirectory,'dir')
                [success,message] = mkdir(workingDirectory);
                if ~success
                    warning('Creating a folder to cache the optimized waveform failed:\n%s',message);
                    return
                end
            end
            
            metaDataFileName = 'metaData.mat';
            metaDataFileName = fullfile(workingDirectory,metaDataFileName);
            hMetaDataFile = matfile(metaDataFileName,'Writable',true);
            
            idx = 1;
            metaData = struct();
            if isfield(whos(hMetaDataFile),'metaData')
                metaData = hMetaDataFile.metaData;
                idx = numel(metaData)+1;
            end
            
            uuid = most.util.generateUUID;
            metaData(idx).linearScannerName = obj.name;
            metaData(idx).hash = hash;
            metaData(idx).clock = clock();
            metaData(idx).optimizationFcn = func2str(obj.optimizationFcn);
            metaData(idx).sampleRateHz = sampleRateHz;
            metaData(idx).desiredWaveformFileName  = 'desiredWaveform.mat';
            metaData(idx).outputWaveformFileName   = sprintf('%s_outputWaveform.mat',uuid);
            metaData(idx).feedbackWaveformFileName = sprintf('%s_feedbackWaveform.mat',uuid);
            metaData(idx).optimizationDataFileName = sprintf('%s_optimizationData.mat',uuid);
            metaData(idx).info = info;
            
            desiredWaveformFileName  = fullfile(workingDirectory,metaData(idx).desiredWaveformFileName);
            outputWaveformFileName   = fullfile(workingDirectory,metaData(idx).outputWaveformFileName);
            feedbackWaveformFileName = fullfile(workingDirectory,metaData(idx).feedbackWaveformFileName);
            optimizationDataFileName = fullfile(workingDirectory,metaData(idx).optimizationDataFileName);
            
            if exist(desiredWaveformFileName,'file')
                delete(desiredWaveformFileName);
            end
            if exist(outputWaveformFileName,'file')
                delete(outputWaveformFileName);
            end
            if exist(feedbackWaveformFileName,'file')
                delete(feedbackWaveformFileName);
            end
            if exist(optimizationDataFileName,'file')
                delete(optimizationDataFileName);
            end
            
            hDesiredWaveformFile      = matfile(desiredWaveformFileName, 'Writable',true);
            hOutputWaveformFile       = matfile(outputWaveformFileName,  'Writable',true);
            hFeedbackWaveformFile     = matfile(feedbackWaveformFileName,'Writable',true);
            hOptimizationDataFileName = matfile(optimizationDataFileName,'Writable',true);
            
            hDesiredWaveformFile.sampleRateHz = sampleRateHz;
            hDesiredWaveformFile.volts = desiredWaveform;
            
            hOutputWaveformFile.sampleRateHz = sampleRateHz;
            hOutputWaveformFile.volts = outputWaveform;
            
            hFeedbackWaveformFile.sampleRateHz = sampleRateHz;
            hFeedbackWaveformFile.volts = feedbackWaveform;
            
            hOptimizationDataFileName.data = optimizationData;
            
            hMetaDataFile.metaData = metaData; % update metaData file
        end
        
        % Clears every .mat file in the caching directory indicated by dir
        % or if dir is left empty the default caching directory under
        % [MDF]\..\ConfigData\Waveforms_Cache\LinScanner_#_Galvo\
        function clearCache(obj)
            if isempty(obj.waveformCacheScannerPath)
                warning('Could not clear waveform cache because waveformCacheBasePath or scanner name is not set');
            else
                rmdir(obj.waveformCacheScannerPath,'s');
            end
        end

        % Clears a specific .mat file associated with the provided original
        % waveform and sample rate from the default directory or a specifc
        % caching directory (not yet implememted)
        function clearCachedWaveform(obj,sampleRateHz,originalWaveform)
            [available,metaData] = obj.isCached(sampleRateHz,originalWaveform);
            if available
                workingDirectory = metaData.path;
                
                desiredWaveformFileName  = fullfile(metaData.path,metaData.desiredWaveformFileName);
                outputWaveformFileName   = fullfile(metaData.path,metaData.outputWaveformFileName);
                feedbackWaveformFileName = fullfile(metaData.path,metaData.feedbackWaveformFileName);
                optimizationDataFileName = fullfile(metaData.path,metaData.optimizationDataFileName);
                
                if exist(outputWaveformFileName,'file')
                    delete(outputWaveformFileName)
                end
                
                if exist(feedbackWaveformFileName,'file')
                    delete(feedbackWaveformFileName)
                end
                
                if exist(optimizationDataFileName,'file')
                    delete(optimizationDataFileName)
                end
                
                metaDataFileName = fullfile(workingDirectory,'metaData.mat');
                m = matfile(metaDataFileName,'Writable',true);
                metaData_onDisk = m.metaData;
                metaData_onDisk(metaData.metaDataIdx) = [];
                m.metaData = metaData_onDisk;
                
                if isempty(metaData_onDisk)
                   rmdir(workingDirectory,'s');
                end
            end
        end
        
        % Checks whether a cached version of the associated waveform exists
        function [available,metaData] = isCached(obj,sampleRateHz,desiredWaveform)
            available = false;
            metaData = [];
            
            if ~isvector(desiredWaveform)
                return
            end
            %assert(isvector(desiredWaveform),'Cannot cache empty/multi-dimensional waveforms');
            
            [desiredWaveform,numPeriods] = compressWaveform(desiredWaveform);
            
            workingDirectory = obj.computeWaveformCachePath(sampleRateHz,desiredWaveform);
            if isempty(workingDirectory)
                warning('Could not check waveform cache because waveformCacheBasePath or scanner name is not set');
                return
            end
            
            metaDataFileName = fullfile(workingDirectory,'metaData.mat');
            
            if ~exist(metaDataFileName,'file')
                return % did not file metadata
            end
            
            m = matfile(metaDataFileName);
            metaData = m.metaData;
            optFunctions = {metaData.optimizationFcn};
            [tf,idx] = ismember(func2str(obj.optimizationFcn),optFunctions);
            
            if ~tf
                return % did not find optimization for current optimization function
            else
                available = true;
                metaData = metaData(idx);
                metaData.path = workingDirectory;
                metaData.metaDataIdx = idx;
                metaData.periodCompressionFactor = numPeriods;
                metaData.linearScanner = obj;
            end            
        end
        
        % Using an original waveform and sample rate this function double
        % checks the existence of a cached version of the optimized
        % waveform and if it exists loads that cached waveform and the
        % associated error (feedback?)
        function [metaData, outputWaveform, feedbackWaveform, optimizationData] = getCachedOptimizedWaveform(obj,sampleRateHz,desiredWaveform)
            outputWaveform = [];
            feedbackWaveform = [];
            optimizationData = [];
            
            [available,metaData] = obj.isCached(sampleRateHz,desiredWaveform);
            
            if available
                outputWaveformFileName   = fullfile(metaData.path,metaData.outputWaveformFileName);
                feedbackWaveformFileName = fullfile(metaData.path,metaData.feedbackWaveformFileName);
                optimizationDataFileName = fullfile(metaData.path,metaData.optimizationDataFileName);
                
                numPeriods = metaData.periodCompressionFactor;
                if nargout>1
                    assert(logical(exist(outputWaveformFileName,'file')),'The file %s was not found on disk.',outputWaveformFileName);
                    hFile = matfile(outputWaveformFileName);
                    outputWaveform = hFile.volts;
                    outputWaveform = repmat(outputWaveform,numPeriods,1);
                end
                
                if nargout>2
                    assert(logical(exist(feedbackWaveformFileName,'file')),'The file %s was not found on disk.',feedbackWaveformFileName);
                    hFile = matfile(feedbackWaveformFileName);
                    feedbackWaveform = hFile.volts;
                    feedbackWaveform = repmat(feedbackWaveform,numPeriods,1);
                end
                
                if nargout>3
                    assert(logical(exist(optimizationDataFileName,'file')),'The file %s was not found on disk.',optimizationDataFileName);
                    hFile = matfile(optimizationDataFileName);
                    optimizationData = hFile.volts;
                end
            end
        end
        
        
        function feedback = testWaveformAsync(obj, outputWaveform, sampleRateHz, guiCallback)
            assert(guiCallbackInternal('start',[],outputWaveform),'Waveform test cancelled by user');
            
            assert(obj.outputAvailable,'%s: Position output not initialized', obj.name);
            assert(obj.feedbackAvailable,'%s: Feedback input not initialized', obj.name);
            assert(obj.feedbackCalibrated,'%s: Feedback input not calibrated', obj.name);
            
            feedbackRaw = obj.testWaveformVolts(processSignal('expand',outputWaveform),sampleRateHz,true,outputWaveform(1),false,@guiCallbackInternal);
            feedback = processSignal('decimate',feedbackRaw);
            guiCallbackInternal('done',feedback);
            
            function tfContinue = guiCallbackInternal(varargin)
                tfContinue = isempty(guiCallback(obj,varargin{:}));
            end
        end
        
        %%
        % desiredWaveform is the desired trajectory, feedback is what the galvos
        % actually do, optimized is the adjusted AO out to make feedback ==
        % desired.
        function [optimizedWaveform,err] = optimizeWaveformIterativelyAsync(obj, desiredWaveform, sampleRateHz, guiCallback, cache) % Perhaps call reCache reOptimize instead? Better clarity maybe. 
            if nargin<5 || isempty(cache)
                cache = true;
            end

            assert(guiCallbackInternal('start',desiredWaveform),'Waveform test cancelled by user');
            
            acceptEarly = false;
            p_cont = true;
            
            assert(obj.outputAvailable,'%s: Position output not initialized', obj.name);
            assert(obj.feedbackAvailable,'%s: Feedback input not initialized', obj.name);
            assert(obj.feedbackCalibrated,'%s: Feedback input not calibrated', obj.name);
            
            [desiredWaveform,numPeriods] = compressWaveform(desiredWaveform);
            
            try
                feedback = obj.testWaveformVolts(processSignal('expand',desiredWaveform),sampleRateHz,true,desiredWaveform(1),false,@guiCallbackInternal);
                feedbackHistory = processSignal('decimate',feedback);
                errHistory = feedbackHistory - desiredWaveform;
                optimizedWaveformHistory = desiredWaveform;
                errRmsHistory = rms(errHistory);
                
                done = ~guiCallbackInternal(repmat(optimizedWaveformHistory,numPeriods,1),repmat(feedbackHistory,numPeriods,1),errRmsHistory);
                
                optimizationData = [];
                
                iterationNumber  = 0;
                while ~done
                    iterationNumber = iterationNumber+1;
                    [done,optimizedWaveform_new,optimizationData] = obj.optimizationFcn(obj,iterationNumber,sampleRateHz,desiredWaveform,optimizedWaveformHistory(:,end),feedbackHistory(:,end),optimizationData);
                    optimizedWaveform_new = min(max(optimizedWaveform_new,-10),10); % clamp output
                    
                    feedback_new = obj.testWaveformVolts(processSignal('expand',optimizedWaveform_new),sampleRateHz,false,optimizedWaveform_new(1),false,@guiCallbackInternal);
                    feedback_new = processSignal('decimate',feedback_new);
                    
                    err_new = feedback_new - desiredWaveform;
                    
                    optimizedWaveformHistory(:,end+1) = optimizedWaveform_new;
                    feedbackHistory(:,end+1) = feedback_new;
                    errHistory(:,end+1) = err_new;
                    
                    errRmsHistory(end+1) = rms(err_new);
                    
                    done = done || ~guiCallbackInternal(repmat(optimizedWaveformHistory,numPeriods,1),repmat(feedbackHistory,numPeriods,1),errRmsHistory);
                    pause(0.01);
                    
                    voltageRange = obj.position2Volts(obj.travelRange);
                    voltageRange = sort(voltageRange);
                    rangePp = diff(voltageRange);
                    tolerance = rangePp*0.01;
                    
                    assert(errRmsHistory(end)<=errRmsHistory(1)+tolerance,'Tracking error unexpectedly increased. Optimization stopped to prevent damage to actuator.');
                    assert(p_cont,'Waveform test cancelled by user')
                end
                
                % park the galvo
                obj.hAOControl.lastKnownValue = desiredWaveform(end);
                obj.smoothTransitionVolts(obj.defaultValueVolts);
            catch ME
                try
                    % park the galvo
                    obj.hAOControl.lastKnownValue = desiredWaveform(end);
                    obj.smoothTransitionVolts(obj.defaultValueVolts);
                catch
                end
                
                if ~acceptEarly
                    rethrow(ME);
                end
            end
            
            if exist('optimizedWaveformHistory','var')
                optimizedWaveform = optimizedWaveformHistory(:,end);
                feedback = feedbackHistory(:,end);
                err = errHistory(:,end);
                
                if cache
                    cacheWf(optimizedWaveform,feedback,iterationNumber);
                end
            else
                optimizedWaveform = repmat(desiredWaveform,numPeriods,1);
                err = nan(size(optimizedWaveform));
            end
            
            optimizedWaveform = repmat(optimizedWaveform,numPeriods,1);
            err = repmat(err,numPeriods,1);

            guiCallbackInternal('done');
            
            function tfContinue = guiCallbackInternal(varargin)
                cmd = guiCallback(obj,varargin{:});
                tfContinue = isempty(cmd);
                acceptEarly = strcmp(cmd,'accept');
                p_cont = tfContinue;
            end
            
            %%% local functions
            function cacheWf(Wf,Fb,N)
                nfo = struct;
                nfo.numIterations = N;
                nfo.feedbackVoltLUT = obj.feedbackVoltLUT;
                obj.cacheOptimizedWaveform(sampleRateHz,desiredWaveform,Wf,Fb,[],nfo);
            end
            
            function signal = processSignal(mode,signal)
                numReps = 5; % minimum of 3
                
                signal = signal(:);                
                switch mode
                    case 'expand'
                        signal = repmat(signal,numReps,1);
                    case 'decimate'
                        signal = reshape(signal,[],numReps);
                        signal = mean(signal(:,2:end),2);
                    otherwise
                        assert(false);
                end
            end
            
            function v = rms(err)
                v = sqrt(sum(err.^2) / numel(err));
            end
        end
        
        %%
        % desiredWaveform is the desired trajectory, feedback is what the galvos
        % actually do, optimized is the adjusted AO out to make feedback ==
        % desired.
        function [optimizedWaveform,err] = optimizeWaveformIteratively(obj, desiredWaveform, sampleRateHz, cache) % Perhaps call reCache reOptimize instead? Better clarity maybe. 
            if nargin<4 || isempty(cache)
                cache = true;
            end
            
            acceptEarly = false;
            p_cont = true;
            runInd = nan;
            
            assert(obj.outputAvailable,'%s: Position output not initialized', obj.name);
            assert(obj.feedbackAvailable,'%s: Feedback input not initialized', obj.name);
            assert(obj.feedbackCalibrated,'%s: Feedback input not calibrated', obj.name);
            
            [desiredWaveform,numPeriods] = compressWaveform(desiredWaveform);
            
            tt = linspace(0,(length(desiredWaveform)-1)/sampleRateHz,length(desiredWaveform))';
            
            hFig = most.idioms.figure('NumberTitle','off','units','pixels','position',most.gui.centeredScreenPos([1200 900]),'MenuBar','none',...
                'Toolbar','figure','Name',sprintf('%s waveform optimization',obj.name),'WindowButtonMotionFcn',@motion);
            mf = most.gui.uiflowcontainer('Parent',hFig,'FlowDirection','BottomUp','margin',0.00001);
                hBf = most.gui.uiflowcontainer('Parent',mf,'FlowDirection','LeftToRight','HeightLimits',44,'margin',8);
                    most.gui.uicontrol('parent',hBf,'String','Abort','BackgroundColor',[1 .9 .5],'WidthLimits',60,'callback',@lcl_cancel);
                    most.gui.uicontrol('parent',hBf,'String','Accept Current Waveform','BackgroundColor',[.65 .94 .65],'WidthLimits',180,'callback',@lcl_accept);
                    most.gui.uipanel('Parent',hBf,'Bordertype','none','WidthLimits',20);
                    hTxt = most.gui.staticText('parent',hBf,'String',sprintf('%s: Preparing waveform...',obj.name),'WidthLimits',300,'HorizontalAlignment','center');

                hPanel = most.gui.uipanel('Parent',mf,'Bordertype','none');
                    most.idioms.axes('parent',hPanel);
            
            hMenu = uicontextmenu('Parent',hFig);
                uimenu('Parent',hMenu,'Label','Use This Waveform','Callback',@useWavfm);
            
            hAx1 = most.idioms.subplot(4,1,[1,2],'NextPlot','add','Box','on','Parent',hPanel);
            ylabel(hAx1,'Signal [V]')
            hPlotDesired = plot(hAx1,tt,nan(size(tt)),'LineWidth',2);
            hPlotFeedback = plot(hAx1,tt,nan(size(tt)));
            hPlotOutput = plot(hAx1,tt,nan(size(tt)),'--');
            legend(hAx1,'Desired','Feedback','Output');
            hAx1.XTickLabel = {[]};
            grid(hAx1,'on');
            
            hAx2 = most.idioms.subplot(4,1,3,'Box','on','Parent',hPanel);
            hPlotError = plot(hAx2,tt,nan(size(tt)));
            linkaxes([hAx1,hAx2],'x')
            legend(hAx2,'Error');
            xlabel(hAx2,'Time [s]');
            ylabel(hAx2,'Error [V]');
            grid(hAx2,'on');
            
            XLim = [tt(1),tt(end)*1.02];
            if diff(XLim)==0
                XLim = [tt(1) tt(1)+1];
            end
            set([hAx1,hAx2],'XLim',XLim);
            
            hAx3 = most.idioms.subplot(4,1,4,'Box','on','Parent',hPanel);
            hPlotRms = plot(hAx3,NaN,NaN,'o-','UIContextMenu',hMenu,'ButtonDownFcn',@rmsLineHit);
            hPlotRmsMarker = line('Parent',hAx3,'XData',NaN,'YData',NaN,'ZData',-1,'MarkerSize',12,'Marker','o','MarkerEdgeColor','red','MarkerFaceColor',[1, 0.9, 0.9],'hittest','off');
            hAx3.YScale = 'log';
            xlabel(hAx3,'Iteration Number');
            ylabel(hAx3,'RMS [V]');
            hAx3.XLim = [0 10];
            grid(hAx3,'on');
            
            hTxt.String = sprintf('%s: Optimizing waveform',obj.name);
            
%             [optimizedWaveform,err] = obj.optimizeWaveformIterativelyAsync(desiredWaveform, sampleRateHz, @guiCallback, cache);
% 
%             function tfContinue = guiCallback(~,varargin)
%             end
            
            try
                feedback = obj.testWaveformVolts(processSignal('expand',desiredWaveform),sampleRateHz,true,desiredWaveform(1),false,@progressCb);
                feedbackHistory = processSignal('decimate',feedback);
                errHistory = feedbackHistory - desiredWaveform;
                optimizedWaveformHistory = desiredWaveform;
                errRmsHistory = rms(errHistory);
                plotWvfs();
                
                optimizationData = [];
                
                done = false;
                iterationNumber  = 0;
                while ~done
                    iterationNumber = iterationNumber+1;
                    [done,optimizedWaveform_new,optimizationData] = obj.optimizationFcn(obj,iterationNumber,sampleRateHz,desiredWaveform,optimizedWaveformHistory(:,end),feedbackHistory(:,end),optimizationData);
                    optimizedWaveform_new = min(max(optimizedWaveform_new,-10),10); % clamp output
                    
                    feedback_new = obj.testWaveformVolts(processSignal('expand',optimizedWaveform_new),sampleRateHz,false,optimizedWaveform_new(1),false,@progressCb);
                    feedback_new = processSignal('decimate',feedback_new);
                    
                    err_new = feedback_new - desiredWaveform;
                    
                    optimizedWaveformHistory(:,end+1) = optimizedWaveform_new;
                    feedbackHistory(:,end+1) = feedback_new;
                    errHistory(:,end+1) = err_new;
                    
                    errRmsHistory(end+1) = rms(err_new);
                    
                    plotWvfs();
                    
                    voltageRange = obj.daqOutputRange;%obj.position2Volts(obj.travelRange);
                    voltageRange = sort(voltageRange);
                    rangePp = diff(voltageRange);
                    tolerance = rangePp*0.01;
                    
                    assert(errRmsHistory(end)<=errRmsHistory(1)+tolerance,'Tracking error unexpectedly increased. Optimization stopped to prevent damage to actuator.');
                    assert(p_cont,'Waveform test cancelled by user')
                end
                
                % park the galvo
                obj.hAOControl.lastKnownValue = desiredWaveform(end);
                obj.smoothTransitionVolts(obj.defaultValueVolts);
            catch ME
                try
                    % park the galvo
                    obj.hAOControl.lastKnownValue = desiredWaveform(end);
                    obj.smoothTransitionVolts(obj.defaultValueVolts);
                catch
                end
                
                if ~acceptEarly
                    rethrow(ME);
                end
            end
            
            if exist('optimizedWaveformHistory','var')
                optimizedWaveform = optimizedWaveformHistory(:,end);
                feedback = feedbackHistory(:,end);
                err = errHistory(:,end);

                hTxt.String = sprintf('%s: Caching waveform',obj.name);
                drawnow('nocallbacks');
                
                if cache
                    cacheWf(optimizedWaveform,feedback,iterationNumber);
                end
            else
                optimizedWaveform = repmat(desiredWaveform,numPeriods,1);
                err = nan(size(optimizedWaveform));
            end
            
            optimizedWaveform = repmat(optimizedWaveform,numPeriods,1);
            err = repmat(err,numPeriods,1);
            
            hBf.Visible = 'off';
            
            %%% local functions
            function cacheWf(Wf,Fb,N)
                nfo = struct;
                nfo.numIterations = N;
                nfo.feedbackVoltLUT = obj.feedbackVoltLUT;
                obj.cacheOptimizedWaveform(sampleRateHz,desiredWaveform,Wf,Fb,[],nfo);
            end
            
            function continuetf = progressCb(pct,msg)
                continuetf = p_cont && most.idioms.isValidObj(hFig);
                if continuetf
                    hTxt.String = msg;
                    hS.XData(:,2) = pct;
                end
            end
            
            function lcl_cancel(varargin)
                p_cont = false;
                hTxt.String = sprintf('%s: Optimization aborted',obj.name);
            end
            
            function lcl_accept(varargin)
                p_cont = false;
                acceptEarly = true;
            end
            
            function useWavfm(varargin)
                optimizedWaveform = optimizedWaveformHistory(:,runInd);
                feedback = feedbackHistory(:,runInd);
                cacheWf(optimizedWaveform,feedback,runInd);
            end
            
            function rmsLineHit(~,evt)
                runInd = round(evt.IntersectionPoint(1))+1;
            end
            
            function plotWvfs(idx)
                if ~exist('feedbackHistory','var') || isempty(feedbackHistory)
                    return
                end
                
                if nargin < 1 || isempty(idx)
                    idx = size(feedbackHistory,2);
                end
                
                idx = max(1,min(idx,size(feedbackHistory,2)));
                
                if isvalid(hPlotDesired) && isvalid(hPlotFeedback) && isvalid(hPlotOutput)
                    hPlotDesired.YData = desiredWaveform;
                    hPlotFeedback.YData = feedbackHistory(:,idx);
                    hPlotOutput.YData = optimizedWaveformHistory(:,idx);
                end
                
                if isvalid(hPlotError)
                    hPlotError.YData = errHistory(:,idx);
                end
                
                if isvalid(hPlotRms)
                    hPlotRms.XData = 0:length(errRmsHistory)-1;
                    hPlotRms.YData = errRmsHistory;
                    hPlotRmsMarker.XData = idx-1;
                    hPlotRmsMarker.YData = errRmsHistory(idx);                    
                    hAx_ = ancestor(hPlotRms,'axes');
                    hAx_.XLim = [0 max(length(errRmsHistory)-1,hAx_.XLim(2))];
                end
                drawnow('limitrate');
            end
            
            function v = rms(err)
                v = sqrt(sum(err.^2) / numel(err));
            end
            
            function motion(src,evt)
                if exist('hAx3','var') && ~isempty(hAx3) && isvalid(hAx3) 
                    pt = hAx3.CurrentPoint(1,1:2);
                    if pt(1) >= hAx3.XLim(1) && pt(1) <= hAx3.XLim(2) && pt(2) >= hAx3.YLim(1) && pt(2) <= hAx3.YLim(2)
                        plotWvfs(round(pt(1))+1);
                    end
                end
            end
        end
    end
end

function [waveform,numPeriods] = compressWaveform(waveform)
    waveform = waveform(:);
    
    if numel(waveform) > 10e6
        numPeriods = 1;
    else
        [period,numPeriods] = scanimage.mroi.util.findWaveformPeriodicity(waveform);
        waveform = waveform(1:period);
    end
end

function hash = computeWaveformHash(sampleRateHz,originalWaveform)
    originalWaveform = round(originalWaveform * 1e6); % round to a precision of 1uV to eliminate rounding errors
    hash = most.util.dataHash({originalWaveform,sampleRateHz});
end

function signal = processSignal(mode,signal)
    numReps = 5; % minimum of 3

    signal = signal(:);
    switch mode
        case 'expand'
            signal = repmat(signal,numReps,1);
        case 'decimate'
            signal = reshape(signal,[],numReps);
            signal = mean(signal(:,2:end),2);
        otherwise
            assert(false);
    end
end

function val = validateLUT(val)
validateattributes(val,{'numeric'},{'ncols',2,'finite','nonnan','real'});

xx = val(:,1);
yy = val(:,2);

%sort LUT by first column
[~,sortIdx] = sort(xx);
xx = xx(sortIdx);
yy = yy(sortIdx);

% assert strictly monotonic
assert(all(diff(xx)>0),'LUT column 1 needs to be strictly monotonic');
assert(all(diff(yy)>0) || all(diff(yy)<0),'LUT column 2 needs to be strictly monotonic');
val = [xx,yy];
end

function vq = interp1Flex(x,v,xq,varargin)
if isempty(x)
    vq = xq;
elseif numel(x) == 1
    offset = v-x;
    vq = xq + offset;
else
    vq = interp1(x,v,xq,varargin{:});
end
end

function s = defaultMdfSection()
s = [...
    
    most.HasMachineDataFile.makeEntry('taskType'   , 'Analog'   ,'The type of task  e.g. ''Analog'' or ''Digital''')...
    most.HasMachineDataFile.makeEntry('hControl'  , '', 'Control terminal  e.g. ''/vDAQ0/AO0''')...
    most.HasMachineDataFile.makeEntry('hAIFeedback'  , '', 'Feedback terminal  e.g. ''/vDAQ0/AI0''')...
    most.HasMachineDataFile.makeEntry('sampleRate_Hz'  , 2e6, 'Sampling rate must e.g '''' or ''''')...
    most.HasMachineDataFile.makeEntry('startTriggerPort' , '','Trigger terminal  e.g. ''/vDAQ0/DO0.0''')...
    most.HasMachineDataFile.makeEntry('startTriggerEdge', 'rising'  , 'The type of edges are e.g ''rising'' or ''falling''')...
    most.HasMachineDataFile.makeEntry('sampleMode'  , 'continuous', 'The type of sampling modes e.g ''continuous'' or ''finite''')...
    most.HasMachineDataFile.makeEntry('allowRetrigger', true, 'Whether or not to allow finite tasks to be triggered multiple times (e.g. if samplesPerTrigger < bufferSize_samples, the likely intent is to allow retrigger to execute the buffer in parts)')...
    most.HasMachineDataFile.makeEntry('wvfrmFcn'  , '', 'Function name that generates waveform')...
    most.HasMachineDataFile.makeEntry('amplitude'  , 5, 'Waveform Amplitude Parameter')...
    most.HasMachineDataFile.makeEntry('defaultValueVolts'  , 0, 'Default Value Parameter')...
    most.HasMachineDataFile.makeEntry('periodSec'  , 0.1, 'Waveform period (sec)')...
    most.HasMachineDataFile.makeEntry('startDelay'  , 0, 'Waveform start delay (sec)')...
    most.HasMachineDataFile.makeEntry('dutyCycle'  , 50, 'Waveform duty cycle(%)')...
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
