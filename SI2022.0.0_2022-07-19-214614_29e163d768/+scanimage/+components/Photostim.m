classdef Photostim < scanimage.interfaces.Component & most.HasMachineDataFile & dabs.resources.configuration.HasConfigPage
    properties (SetAccess=protected,Hidden)
        ConfigPageClass = 'dabs.resources.configuration.resourcePages.SIPhotostimPage';
    end

    methods (Static)
        function names = getDescriptiveNames()
            names = {'ScanImage photostim system'}; % returns cell string of descriptive names; this is a function so it can be overloaded
        end
    end

    %% Photostim Module
    properties (SetObservable)
        % Array of stimulus groups.
        stimRoiGroups = scanimage.mroi.RoiGroup.empty;

        % Specifies what mode the photostim module should operate in. This property is initialized to 'sequence'.
        %
        % Possible modes are:
        %   'sequence' - A sequence of stimulus patterns are loaded and each trigger begins the next pattern. Note, all
        %                patterns will be padded to have the same time duration as the longest.
        %   'onDemand' - A set of stimulus patterns are loaded and any pattern can be immediately output on demand by
        %                the user by gui/command line. PC performance may affect delay from when a stimulus is commanded
        %                to actual output but the sync trigger can still be used. If stimImmediately is false, it will
        %                also wait for the stim trigger after the user commands a stimulation.
        stimulusMode = 'onDemand';

        % Sequence mode props

        % Array of the sequence of stimulus groups (represented as an index of the stimRoiGroups array) to load for a stimulus sequence.
        %
        % This is a sequence mode property.
        sequenceSelectedStimuli;

        % The number of times the entire sequence will be repeated.
        %
        % This is a sequence mode property and is initialized to inf.
        numSequences = inf;

        % OnDemand mode props

        % Flag that determines whether (true) or not (false) the selected on demand stimulus is allowed to be triggered multiple times.
        %
        % This is an on demand mode property and is initialized to false.
        allowMultipleOutputs = false;

        % Specifies the PFI terminal that should be used to trigger an on-demand stim selection.
        %
        % This is an on demand mode property.
        stimSelectionTriggerTerm = [];

        % Name of the DAQ device to use for external stim selection.
        %
        % This is an on demand mode property.
        stimSelectionDevice = '';

        % Array of the PFI terminals to use for stim selection.
        %
        % This is an on demand mode property.
        stimSelectionTerms = [];

        % Array of stimulus group IDs to select that correspond to each terminal in stimSelectionTerms.
        %
        % This is an on demand mode property.
        stimSelectionAssignment = [];

        % Both modes

        % Specifies the channel that should be used to trigger a stimulation.
        %
        % This property can be used for both sequence and on demand modes, and is initialized to 1.
        stimTriggerTerm = 1;

        % Specifies a channel to sync the stimulation to. When a stimulus trigger occurs,
        % the stimulus will begin at the next sync trigger. If this property is left empty,
        % stimulus will begin immediately after a stimulus trigger.
        %
        % This property can be used for both sequence and on demand modes.
        syncTriggerTerm = [];

        % Flag that determines whether (true) or not (false) the first stimulus in the sequence will be triggered
        % immediately upon starting the experiment (eg. don't wait for stim trigger. sync trigger still applies).
        %
        % This property can be used for both sequence and on demand modes and is initialized to false.
        stimImmediately = false;

        % Period, in seconds, of auto trigger.
        %
        % This property can be used for both sequence and on demand modes and is initialized to 0.
        autoTriggerPeriod = 0;

        % Monitoring props

        % Flag that determines whether (true) or not (false) the AI5/AI6/AI7 of the photostim device will be used to
        % read back the X/Y/beams channels of the photostimulation.
        %
        % This is a monitoring property and is initialized to false.
        monitoring = false;

        % Flag that determines whether (true) or not (false) the monitored data is logged to the same folder as the Scan2D data.
        %
        % This is a monitoring property and is initialized to false.
        logging = false;

        % Motion Compensation

        % Flag that determines whether (true) or not (false) the motion correction is enabled.
        % If enabled (true), the motion data will be used to compensate for motion.
        %
        % This is a motion compensation property and is initialized to true.
        compensateMotionEnabled = true;

        % Specifies whether or not to control Z focus with fast Z actuator.
        % Must be either '2D' or '3D'
        zMode = '2D';

        % Specifies time to advance signal that goes high when laser is
        % active
        laserActiveSignalAdvance = 0.001;
    end

    properties (Transient)
        BeamAiId = dabs.resources.Resource.empty();
        loggingStartTrigger = dabs.resources.Resource.empty();
        stimActiveOutputChannel = dabs.resources.Resource.empty();
        beamActiveOutputChannel = dabs.resources.Resource.empty();
        slmTriggerOutputChannel = dabs.resources.Resource.empty();
    end

    properties (SetObservable, SetAccess = private)
        % Indicates status of photostim module.
        %
        % Status values include:
        %   Offline
        %   Initializing...
        %   Ready
        %   Running
        %
        % This is a read-only property and is initialized to 'Offline'.
        status = 'Offline';

        % The sequence position in the selected stimuli.
        %
        % This is a read-only property and is initialized to 1.
        sequencePosition = 1;

        % The next sequence position in the selected stimuli.
        %
        % This is a read-only property and is initialized to 1.
        nextStimulus = 1;

        % Number of completed sequences in the selected stimuli.
        %
        % This is a read-only property and is initialized to 0.
        completedSequences = 0;

        % Number of outputs for obtaining samples. Only relevant if the 'allowMultipleOutputs' flag is set to true.
        %
        % This is a read-only property and is initialized to 0.
        numOutputs = 0;

        % The XY vector (in reference space) of the applied motion correction
        %
        % This is a read-only property and is initialized to [0 0].
        lastMotion = [0 0];
    end

    properties (SetObservable, SetAccess = private, Hidden)
        initInProgress = false;
        zMode3D = false;
        slmQueueActive = false;
    end

    properties (SetObservable, Dependent, Hidden)
        stimScannerset;                 % scannerset used for stimulation
    end

    % ABSTRACT PROPERTY REALIZATION (scanimage.interfaces.Component)
    properties (Hidden, SetAccess = protected)
        numInstances = 0;
    end

    properties (Constant, Hidden)
        COMPONENT_NAME = 'Photostim';           % [char array] short name describing functionality of component e.g. 'Beams' or 'FastZ'
        PROP_FOCUS_TRUE_LIVE_UPDATE = {};       % Cell array of strings specifying properties that can be set while focusing
        PROP_TRUE_LIVE_UPDATE = {'monitoring'}; % Cell array of strings specifying properties that can be set while the component is active
        DENY_PROP_LIVE_UPDATE = {'logging'};    % Cell array of strings specifying properties for which a live update is denied (during acqState = Focus)
        FUNC_TRUE_LIVE_EXECUTION = {'park'};    % Cell array of strings specifying functions that can be executed while the component is active
        FUNC_FOCUS_TRUE_LIVE_EXECUTION = {};    % Cell array of strings specifying functions that can be executed while focusing
        DENY_FUNC_LIVE_EXECUTION = {};          % Cell array of strings specifying functions for which a live execution is denied (during acqState = Focus)
        graphics2014b = most.idioms.graphics2014b();
    end

    %%% ABSTRACT PROPERTY REALIZATIONS (most.HasMachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'Photostim';

        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>

        mdfDefault = defaultMdfSection();
    end

    properties (Hidden, SetAccess = private)
        currentSlmPattern = [];
    end

    % Abstract prop realizations (most.Model)
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = ziniInitPropAttributes();
        mdlHeaderExcludeProps = {'stimRoiGroups'};
    end

    properties (Hidden)
        hScan = dabs.resources.SIComponent.empty();                          % Handle to scan2d component
    end

    %% INTERNAL PROPS
    properties (Hidden,SetAccess=private)
        hTaskGalvo;                     % Handle to DAQmx AO task used for galvo or galvo+beam control
        hTaskBeams;                     % Handle to DAQmx AO task used for beam control when a separate DAQ is used
        hTaskZ;                         % Handle to DAQmx AO task used for z control when a separate DAQ is used
        hTaskMain;                      % Handle to hTaskGalvo or hTaskBeams depending on whether galvos or beams are present
        hTaskAutoTrigger;               % Handle to DAQmx CO task for auto trigger
        hTaskArmedTrig;                 % Handle to DAQmx CO task used for start triggering
        hTaskArmedTrigSoft;             % Handle to DAQmx CO task used for soft start triggering
        hTaskSyncHelper;                % Handle to DAQmx CO task used for synced start triggering
        hTaskSyncHelperSoft;            % Handle to DAQmx CO task used for soft start triggering
        hTaskExtStimSel;                % Handle to DAQmx CO task used for hardware stim selection
        hTaskExtStimSelRead;            % Handle to DAQmx DI task used for hardware stim selection
        hTaskMonitoring;                % Handle to DAQmx AI task used for monitoring the X/Y galvos and beams output
        hTaskDigitalOut;                % Handle to DAQmx DO task used for outputting digital signals
        hListeners = [];

        isVdaq = false;
        hFpga;
        simulatedDevice = false;        % Logical indicating whether or not the configured FastZ device is simulated.
        separateBeamDAQ = false;        % Indicates that beams are on a separate DAQ
        zWithGalvos = false;            % Indicates that Z is on same DAQ with galvos
        zWithBeams = false;             % Indicates that Z is on same DAQ with beams
        separateZDAQ = false;           % Indicates that Z is on its own DAQ
        parallelSupport = false;        % Dependent. Indicates that simultaneous imaging and stim are possible
        hasGalvos = false;
        hasBeams = false;
        hasZ = false;
        zActuatorId = [];
        hasSlm = false;

        sampleRates;
        stimAO;                         % Stores the last generated AO. In sequence mode this is a structure with fields for galvos and beams. In on demand mode
        % this is an array of structures (one for each stimulus group) with fields for galvos and beams
        stimPath;                        % Stores the last generated Path. In sequence mode this is a structure with fields for galvos and beams. In on demand mode
        % this is an array of structures (one for each stimulus group) with fields for galvos and beams

        primedStimulus;                 % For on demand mode. Indicates which stimulus is currently in the buffer ready to go
        trigTermString;
        syncTermString;

        hMonitoringFile = [];           % handle to the monitoring file

        currentlyMonitoring = false;
        currentlyLogging = false;

        monitoringRingBuffer;           % used to allow a trailing display of the laser path

        autoTrTerms = {};
        frameTrTerms = {};
        frameScTerms = {};

        stimTrigIsFrame = false;
        syncTrigIsFrame = false;
    end

    properties (Hidden,Dependent)
        hSlm;                           % Handle to SLM scanner
        xGalvo;
        yGalvo;
        hBeams;
        hFastZ;
    end

    properties(SetObservable,Transient)
        % this should be included in the TIFF header

        monitoringSampleRate = 9000;        % [Hz] sample rate for the analog inputs. This is initialized to 9000.
    end

    properties(Constant, Hidden)
        monitoringEveryNSamples = 300;      % display rate = monitoringSampleRate/monitoringEveryNSamples
        monitoringBufferSizeSeconds = 10;    % [s] buffersize of the AI DAQmx monitoring task
        monitoringRingBufferSize = 10;      % number of callback data that can be stored in the ring buffer
    end

    %% LIFECYCLE
    methods (Access = ?scanimage.SI)
        function obj = Photostim(~)
            obj@scanimage.interfaces.Component('SI Photostim',true);
            obj@most.HasMachineDataFile(true);

            obj.loadMdf();
        end
    end

    methods
        function delete(obj)
            obj.deinit();
        end
    end

    methods (Hidden)
        function loadMdf(obj)
            success = true;
            success = success & obj.safeSetPropFromMdf('hScan', 'photostimScannerName');
            success = success & obj.safeSetPropFromMdf('BeamAiId', 'BeamAiId');
            success = success & obj.safeSetPropFromMdf('loggingStartTrigger', 'loggingStartTrigger');
            success = success & obj.safeSetPropFromMdf('stimActiveOutputChannel', 'stimActiveOutputChannel');
            success = success & obj.safeSetPropFromMdf('beamActiveOutputChannel', 'beamActiveOutputChannel');
            success = success & obj.safeSetPropFromMdf('slmTriggerOutputChannel', 'slmTriggerOutputChannel');

            if ~success
                obj.errorMsg = 'Error loading config';
            end
        end

        function saveMdf(obj)
            obj.safeWriteVarToHeading('photostimScannerName', obj.hScan);
            obj.safeWriteVarToHeading('BeamAiId', obj.BeamAiId);
            obj.safeWriteVarToHeading('loggingStartTrigger', obj.loggingStartTrigger);
            obj.safeWriteVarToHeading('stimActiveOutputChannel', obj.stimActiveOutputChannel);
            obj.safeWriteVarToHeading('beamActiveOutputChannel', obj.beamActiveOutputChannel);
            obj.safeWriteVarToHeading('slmTriggerOutputChannel', obj.slmTriggerOutputChannel);
        end

        function validateConfiguration(obj)
            try
                if most.idioms.isValidObj(obj.hScan)
                    if ~isa(obj.hScan,'scanimage.components.scan2d.SlmScan')
                        assert(most.idioms.isValidObj(obj.hScan.xGalvo),'Linear scan system has no x-Galvo specified.');
                        assert(most.idioms.isValidObj(obj.hScan.yGalvo),'Linear scan system has no y-Galvo specified.');
                    end

                    hDigitalDAQs = {};
                    if most.idioms.isValidObj(obj.stimActiveOutputChannel)
                        hDigitalDAQs{end+1} = obj.stimActiveOutputChannel.hDAQ;
                    end

                    if most.idioms.isValidObj(obj.beamActiveOutputChannel)
                        hDigitalDAQs{end+1} = obj.beamActiveOutputChannel.hDAQ;
                    end

                    if most.idioms.isValidObj(obj.slmTriggerOutputChannel)
                        hDigitalDAQs{end+1} = obj.slmTriggerOutputChannel.hDAQ;
                    end

                    daqNames = cellfun(@(hDAQ)hDAQ.name,hDigitalDAQs,'UniformOutput',false);
                    daqNames = unique(daqNames);
                    assert(numel(daqNames)<=1,'The following signals must be configured to be on the same DAQ board: stimActiveOutputChannel, beamActiveOutputChannel, slmTriggerOutputChannel');
                end

                obj.errorMsg = '';
            catch ME
                obj.errorMsg = ME.message;
            end
        end

        function deinit(obj)
            obj.abort();
            most.idioms.safeDeleteObj(obj.hTaskGalvo);
            most.idioms.safeDeleteObj(obj.hTaskBeams);
            most.idioms.safeDeleteObj(obj.hTaskZ);
            most.idioms.safeDeleteObj(obj.hTaskAutoTrigger);
            most.idioms.safeDeleteObj(obj.hTaskArmedTrig);
            most.idioms.safeDeleteObj(obj.hTaskArmedTrigSoft);
            most.idioms.safeDeleteObj(obj.hTaskSyncHelper);
            most.idioms.safeDeleteObj(obj.hTaskSyncHelperSoft);
            most.idioms.safeDeleteObj(obj.hTaskExtStimSel);
            most.idioms.safeDeleteObj(obj.hTaskExtStimSelRead);
            most.idioms.safeDeleteObj(obj.hTaskMonitoring);
            most.idioms.safeDeleteObj(obj.hTaskDigitalOut);
            delete(obj.hListeners);
        end

        function reinit(obj)
            obj.deinit();

            try
                obj.validateConfiguration();
                obj.assertNoError();

                if ~most.idioms.isValidObj(obj.hScan)
                    return
                end

                if isa(obj.hScan,'scanimage.components.scan2d.SlmScan')
                    if ~isempty(obj.hScan.hLinScan)
                        obj.hScan = obj.hScan.hLinScan;
                    end
                end

                obj.isVdaq = isa(obj.hScan, 'scanimage.components.scan2d.RggScan') ...
                    || (isa(obj.hScan, 'scanimage.components.scan2d.SlmScan') && obj.hScan.hAcq.isVdaq);

                if obj.isVdaq
                    obj.stimTriggerTerm = '';
                    obj.hFpga = obj.hScan.hAcq.hFpga;
                end

                obj.hasBeams = ~isempty(obj.hScan.hBeams);
                obj.hasGalvos = most.idioms.isValidObj(obj.xGalvo) && most.idioms.isValidObj(obj.yGalvo);

                galvoDev = dabs.resources.Resource.empty();
                if obj.hasGalvos
                    assert(isempty(obj.xGalvo.errorMsg),'X Galvo is in error state');
                    assert(isempty(obj.yGalvo.errorMsg),'Y Galvo is in error state');

                    assert(isequal(obj.xGalvo.hAOControl.hDAQ,obj.yGalvo.hAOControl.hDAQ));

                    galvoDev = obj.hScan.xGalvo.hAOControl.hDAQ;

                    obj.hTaskGalvo = dabs.vidrio.ddi.AoTask(galvoDev, 'PhotostimTask');
                    obj.hTaskGalvo.addChannel(obj.hScan.xGalvo.hAOControl, 'PhotostimGalvoX');
                    obj.hTaskGalvo.addChannel(obj.hScan.yGalvo.hAOControl, 'PhotostimGalvoY');
                    obj.hTaskGalvo.sampleMode = 'finite';
                    obj.hTaskMain = obj.hTaskGalvo;
                end

                beamDAQ = dabs.resources.Resource.empty();
                if isempty(obj.hScan.hBeams) || all(isa(obj.hScan.hBeams, 'dabs.resources.devices.BeamModulatorSlow'))
                    obj.separateBeamDAQ = false;
                    assert(obj.hasGalvos, 'Operation without galvos OR fast beams is not supported');
                else
                    beamsError = any(cellfun(@(hR)~isempty(hR.errorMsg),obj.hBeams));
                    assert(~beamsError,'One or more beam devices is in an error mode.');


                    fastBeamDevicesMask = cellfun(@(hB)isa(hB, 'dabs.resources.devices.BeamModulatorFast'), obj.hBeams);
                    fastBeamDevices = obj.hBeams(fastBeamDevicesMask);
                    beamDAQs = cellfun(@(hB)hB.hAOControl.hDAQ,fastBeamDevices,'UniformOutput',false);
                    beamDAQnames = cellfun(@(hR)hR.name,beamDAQs,'UniformOutput',false);
                    assert(~any(cellfun(@(b)isa(b, 'dabs.resources.devices.BeamModulatorSlow'),obj.hScan.hBeams)), 'Cannot use slow beam modulators for photostimulation');
                    assert(isscalar(unique(beamDAQnames)),'All beams need to be configured to be on the same device');

                    beamDAQ = beamDAQs{1};

                    if isequal(galvoDev,beamDAQ)
                        obj.separateBeamDAQ = false;
                        cellfun(@(hBeam)obj.hTaskGalvo.addChannel(hBeam.hAOControl),obj.hBeams);
                    else
                        % Galvos and beams are on separate DAQ
                        obj.separateBeamDAQ = true;
                        obj.hTaskBeams = dabs.vidrio.ddi.AoTask(beamDAQ, 'PhotostimBeamTask');
                        cellfun(@(hBeam)obj.hTaskBeams.addChannel(hBeam.hAOControl),obj.hBeams);
                        obj.hTaskBeams.sampleMode = 'finite';

                        if ~obj.hasGalvos
                            obj.hTaskMain = obj.hTaskBeams;
                        end
                    end
                end

                obj.hasZ = ~isempty(obj.hFastZ);
                if obj.hasZ
                    fastZDAQ = obj.hFastZ.hAOControl.hDAQ;

                    obj.separateZDAQ = false;
                    obj.zWithGalvos = false;
                    obj.zWithBeams = false;
                    zTask = [];

                    if ~obj.isVdaq && isequal(galvoDev,fastZDAQ)
                        obj.zWithGalvos = true;
                        zTask = obj.hTaskGalvo;
                    elseif ~obj.isVdaq && isequal(beamDAQ,fastZDAQ)
                        obj.zWithBeams = true;
                        zTask = obj.hTaskBeams;
                    end

                    if isempty(zTask)
                        obj.separateZDAQ = true;
                        obj.hTaskZ = dabs.vidrio.ddi.AoTask(fastZDAQ, 'PhotostimZTask');
                        obj.hTaskZ.addChannel(obj.hFastZ.hAOControl.channelID, 'PhotostimZ');
                        obj.hTaskZ.sampleMode = 'finite';
                        obj.hTaskZ.triggerOnStart = false;
                        if ~isa(fastZDAQ,'dabs.resources.daqs.vDAQ')
                            configTaskTimebase(obj.hTaskZ, 'Z');
                            configTaskStartTrigger(obj.hTaskZ, 'Z');
                        end
                    else
                        zTask.addChannel(obj.hFastZ.hAOControl.channelID, 'PhotostimZ');
                    end
                end

                if obj.hasGalvos
                    if obj.isVdaq
                        obj.hTaskGalvo.triggerOnStart = false;
                    else
                        configTaskTimebase(obj.hTaskGalvo, 'galvo');
                        obj.hTaskGalvo.startTrigger = 'Ctr0InternalOutput';
                    end
                end

                if obj.separateBeamDAQ
                    if obj.isVdaq
                        obj.hTaskBeams.triggerOnStart = false;
                    else
                        configTaskTimebase(obj.hTaskBeams, 'beams');
                        configTaskStartTrigger(obj.hTaskBeams, 'beams');
                    end
                end

                obj.hTaskMain.doneCallback = @obj.taskDoneCallback;
                obj.hTaskMain.sampleCallback = @obj.nSampleCallback;
                obj.hTaskMain.sampleCallbackAutoRead = false;

                hDigitalDAQs = {};
                if most.idioms.isValidObj(obj.stimActiveOutputChannel)
                    hDigitalDAQs{end+1} = obj.stimActiveOutputChannel.hDAQ;
                end

                if most.idioms.isValidObj(obj.beamActiveOutputChannel)
                    hDigitalDAQs{end+1} = obj.beamActiveOutputChannel.hDAQ;
                end

                if most.idioms.isValidObj(obj.slmTriggerOutputChannel)
                    hDigitalDAQs{end+1} = obj.slmTriggerOutputChannel.hDAQ;
                end

                if isempty(hDigitalDAQs)
                    obj.hTaskDigitalOut = [];
                else
                    daqNames = cellfun(@(hDAQ)hDAQ.name,hDigitalDAQs,'UniformOutput',false);
                    daqNames = unique(daqNames);
                    assert(isscalar(daqNames),'The following signals must be configured to be on the same DAQ board: stimActiveOutputChannel, beamActiveOutputChannel, slmTriggerOutputChannel');

                    obj.hTaskDigitalOut = dabs.vidrio.ddi.DoTask(hDigitalDAQs{1}, 'PhotostimActiveSignalTask');

                    if most.idioms.isValidObj(obj.stimActiveOutputChannel)
                        obj.hTaskDigitalOut.addChannel(obj.stimActiveOutputChannel);
                    end

                    if most.idioms.isValidObj(obj.beamActiveOutputChannel)
                        obj.hTaskDigitalOut.addChannel(obj.beamActiveOutputChannel);
                    end

                    if most.idioms.isValidObj(obj.slmTriggerOutputChannel)
                        obj.hTaskDigitalOut.addChannel(obj.slmTriggerOutputChannel);
                    end

                    obj.hTaskDigitalOut.sampleMode = 'finite';
                    obj.hTaskDigitalOut.syncTo(obj.hTaskMain);
                end

                obj.numInstances = 1;
                obj.stimTriggerTerm = obj.stimTriggerTerm;

                %hScan can be empty, so adding the following line to the
                %DependsOn Properties can throw an error
                %s.stimScannerset            = struct('DependsOn',{{'hScan.scannerset'}});
                %                 lh = most.ErrorHandler.addCatchingListener(obj.hScan,'scannerset','PostSet',@(src,evt)setStimScannerset(NaN));
                %                 obj.hListeners = [obj.hListeners lh];

                lh = most.ErrorHandler.addCatchingListener(obj.hSI.hConfigurationSaver,'cfgLoadingInProgress','PostSet',@(src,evt)cfgLoadingChanged());
                obj.hListeners = [obj.hListeners lh];

                lh = most.ErrorHandler.addCatchingListener(obj.hSI,'imagingSystem','PreSet',@(src,evt)obj.stopMonitoring());
                obj.hListeners = [obj.hListeners lh];
                lh = most.ErrorHandler.addCatchingListener(obj.hSI,'imagingSystem','PostSet',@(src,evt)cfgLoadingChanged());
                obj.hListeners = [obj.hListeners lh];
            catch ME
                obj.numInstances = 0;
                obj.errorMsg = sprintf('Photostimulation module initialization failed. Error:\n%s', ME.message);
                most.ErrorHandler.logAndReportError(ME,obj.errorMsg);
                return;
            end

            % Nested functions
            function setStimScannerset(val)
                obj.stimScannerset = val;
            end

            function cfgLoadingChanged()
                if obj.hSI.hConfigurationSaver.cfgLoadingInProgress
                    obj.stopMonitoring();
                else
                    obj.monitoring = obj.monitoring;
                end
            end

            function configTaskTimebase(hTask,name)
                %%% configure reference clock sharing
                devName = hTask.deviceName;
                busType = get(hTask.hDevice,'busType');
                isPxi = ismember(busType, {'DAQmx_Val_PXI','DAQmx_Val_PXIe'});

                % dummy settings just to run verify test
                hTask.sampleRate = 1000;
                hTask.samplesPerTrigger = 1000;

                if isPxi
                    term = ['/' devName '/PXI_Clk10'];
                    rate = 10e6;
                else
                    term = [];
                    rate = [];

                    if ~isempty(obj.hScan.trigReferenceClkOutInternalRate) && ~isempty(obj.hScan.trigReferenceClkOutInternalTerm)
                        try
                            %try automatic routing
                            hTask.sampleClockTimebaseRate = obj.hScan.trigReferenceClkOutInternalRate;
                            hTask.sampleClockTimebaseSource = obj.hScan.trigReferenceClkOutInternalTerm;
                            hTask.verifyConfig();
                            term = obj.hScan.trigReferenceClkOutInternalTerm;
                            rate = obj.hScan.trigReferenceClkOutInternalRate;

                        catch ME
                            % Error -89125 is expected: No registered trigger lines could be found between the devices in the route.
                            % Error -89139 is expected: There are no shared trigger lines between the two devices which are acceptable to both devices.
                            if isempty(strfind(ME.message, '-89125')) && isempty(strfind(ME.message, '-89139')) % filter error messages
                                rethrow(ME)
                            end

                            if strcmp(name,'beams')
                                hBeam = obj.stimScannerset.beams(1).hDevice;

                                if most.idioms.isValidObj(hBeam.hReferenceClockIn)
                                    term = hBeam.hReferenceClockIn.name;
                                    rate = hBeam.referenceClockRate;
                                else
                                    term = '';
                                    rate = [];
                                    msg = sprintf('Make sure to configure ''%s'' referenceClockIn in the Machine Configuration',hBeam.name);
                                end

                            elseif strcmp(name,'Z')
                                term = [];
                                msg = 'Put Z DAQ in same PXI chassis or connect with RTSI cable to digital IO DAQ.';
                            else
                                msg = '';
                            end
                        end
                    end
                end

                if isempty(term)
                    if strcmp(name, 'galvo')
                        msg = ['reference clock. ' msg];
                    else
                        msg = ['galvos. ' msg];
                    end
                    most.idioms.warn(['Photostim ' name ' task timebase could not be synchronized to ' msg]);

                    hTask.sampleClockTimebaseRate = [];
                    hTask.sampleClockTimebaseSource = [];
                else
                    hTask.sampleClockTimebaseRate = rate;
                    hTask.sampleClockTimebaseSource = term;
                end
            end

            function configTaskStartTrigger(hTask,name)
                try
                    %try automatic routing
                    hTask.startTrigger = sprintf('/%s/Ctr0InternalOutput', obj.hTaskMain.deviceName);
                    hTask.verifyConfig();
                catch ME
                    % Error -89125 is expected: No registered trigger lines could be found between the devices in the route.
                    % Error -89139 is expected: There are no shared trigger lines between the two devices which are acceptable to both devices.
                    if isempty(strfind(ME.message, '-89125')) && isempty(strfind(ME.message, '-89139')) % filter error messages
                        rethrow(ME)
                    end

                    switch name
                        case 'beams'
                            hDevice = obj.stimScannerset.beams(1).hDevice;
                        case 'Z'
                            hDevice = obj.stimScannerset.fastz(1).hDevice;
                        otherwise
                            error('Unknown task type: %s',name);
                    end

                    if most.idioms.isValidObj(hDevice.hFrameClockIn)
                        hTask.startTrigger = hDevice.hFrameClockIn.name;
                    else
                        most.idioms.warn(['Photostim ' name ' task start trigger could not be routed correctly - ', ...
                            'Photostim galvos and ' name ' are out of sync. ', ...
                            'Make sure to configure ' hDevice.name ' frameClockIn.'])
                    end
                end
            end
        end
    end

    %% PROP ACCESS
    methods
        function set.stimTriggerTerm(obj, v)
            assert(~obj.active, 'Cannot change this property while active.');

            if obj.isVdaq
                v = validate_vDAQ_triggers(v);
            else
                v = validate_niDAQ_triggers(v);
            end

            obj.stimTriggerTerm = v;

            %%% NestedFunctions
            function v = validate_niDAQ_triggers(v)
                assert(isnumeric(v)||ischar(v));

                if isempty(v)
                    v = '';
                    return
                end

                if ischar(v)
                    switch v
                        case 'frame'
                        otherwise
                            v = regexprep(v,'.*PFI','');
                            v = str2double(v);
                    end
                end

                if isnumeric(v)
                    assert(v>=0 && v<=15 && mod(v,1)==0,'Incorrect PFI port: ''%d''. Valid Ports are 0-15',v);
                end

            end

            function v = validate_vDAQ_triggers(v)
                if isempty(v)
                    v = '';
                else
                    DIs = unique([{obj.hScan.hDAQ.hDIOs.channelName},{obj.hScan.hDAQ.hDIs.channelName}]);
                    allowedValues = [{'frame'},DIs];
                    mask = strcmpi(v,allowedValues);
                    assert(any(mask),'Invalid trigger value: ''%s''. Allowed values are: %s',v,strjoin(allowedValues,', '));
                    v = allowedValues{mask};
                end
            end
        end

        function v  = get.stimTrigIsFrame(obj)
            v = strcmpi(obj.stimTriggerTerm,'frame');
        end

        function val = get.trigTermString(obj)
            if obj.isVdaq
                if isempty(obj.stimTriggerTerm)
                    val = '';
                else
                    val = obj.stimTriggerTerm;
                end
            else
                if obj.stimTrigIsFrame
                    val = obj.hSI.hScan2D.trigFrameClkOutInternalTerm;
                else
                    val = sprintf('/%s/PFI%d',obj.hTaskMain.deviceName,obj.stimTriggerTerm);
                end
            end
        end

        function set.autoTriggerPeriod(obj, v)
            assert(~obj.active, 'Cannot change this property while active.');
            v = obj.validatePropArg('autoTriggerPeriod',v);
            obj.autoTriggerPeriod = v;
        end

        function set.syncTriggerTerm(obj, v)
            assert(~obj.active, 'Cannot change this property while active.');
            if obj.isVdaq
                assert(isempty(v) || ischar(v), 'Invalid trigger setting.');
                obj.syncTriggerTerm = v;
                obj.syncTrigIsFrame = strcmp(v,'frame');
            else
                obj.syncTrigIsFrame = ischar(v) && strcmp(v,'frame');
                if ~obj.syncTrigIsFrame
                    v = obj.validatePropArg('syncTriggerTerm',v);
                end

                if isempty(v)
                    obj.syncTriggerTerm = v;
                    obj.syncTermString = v;
                elseif obj.numInstances
                    if obj.syncTrigIsFrame
                        obj.syncTermString = obj.hSI.hScan2D.trigFrameClkOutInternalTerm;
                    else
                        obj.syncTermString = sprintf('/%s/PFI%d',obj.hTaskMain.deviceName,v);
                    end

                    obj.syncTriggerTerm = v;
                end
            end
        end

        function set.stimSelectionTerms(obj, v)
            assert(~obj.active, 'Cannot change this property while active.');
            v = obj.validatePropArg('stimSelectionTerms',v);
            most.idioms.safeDeleteObj(obj.hTaskExtStimSelRead);
            obj.stimSelectionTerms = v;
        end

        function set.stimSelectionTriggerTerm(obj, v)
            assert(~obj.active, 'Cannot change this property while active.');
            v = obj.validatePropArg('stimSelectionTriggerTerm',v);
            most.idioms.safeDeleteObj(obj.hTaskExtStimSel);
            obj.stimSelectionTriggerTerm = v;
        end

        function val = get.stimScannerset(obj)
            if isempty(obj.hScan)
                val = [];
            else
                val = obj.hScan.stimScannerset;

                if isa(val, 'scanimage.mroi.scannerset.GalvoGalvo')
                    val.fillFractionSpatial = 1;
                    for idx = 1:numel(val.beams)
                        val.beams(idx).powerBoxes = [];
                    end

                    if ~obj.hasZ
                        val.fastz = [];
                    end
                end
            end
        end

        function set.stimulusMode(obj, v)
            assert(~obj.active, 'Cannot change this property while active.');
            assert(ismember(v, {'sequence' 'onDemand'}), 'Invalid choice for stimulus mode.');
            if obj.numInstances
                obj.stimulusMode = v;
            end
        end

        function set.allowMultipleOutputs(obj, v)
            obj.allowMultipleOutputs = v;

            if obj.active && strcmp(obj.stimulusMode, 'onDemand')
                obj.clearOnDemandStatus();
                obj.primedStimulus = [];

                if obj.hasGalvos
                    obj.hTaskGalvo.allowRetrigger = obj.allowMultipleOutputs;
                end
                if obj.separateBeamDAQ
                    obj.hTaskBeams.allowRetrigger = obj.allowMultipleOutputs;
                end
                if obj.separateZDAQ
                    obj.hTaskZ.allowRetrigger = obj.allowMultipleOutputs;
                end

                if ~isempty(obj.hTaskDigitalOut)
                    obj.hTaskDigitalOut.allowRetrigger = obj.allowMultipleOutputs;
                end
            end
        end

        function val = get.hSlm(obj)
            val = dabs.resources.Resource.empty();
            if ~isempty(obj.hScan) && ~isempty(obj.hScan.scannerset)
                ss = obj.hScan.scannerset.slm;
                if most.idioms.isValidObj(ss)
                    val = ss.scanners{1};
                end
            end
        end

        function val = get.hasSlm(obj)
            val = ~isempty(obj.hSlm);
        end

        function val = get.xGalvo(obj)
            val = dabs.resources.Resource.empty();
            if ~isempty(obj.hScan) && isprop(obj.hScan,'xGalvo')
                val = obj.hScan.xGalvo;
            end
        end

        function val = get.yGalvo(obj)
            val = dabs.resources.Resource.empty();
            if ~isempty(obj.hScan) && isprop(obj.hScan,'yGalvo')
                val = obj.hScan.yGalvo;
            end
        end

        function val = get.hBeams(obj)
            val = {};
            if ~isempty(obj.hScan) && isprop(obj.hScan,'hBeams')
                val = obj.hScan.hBeams;
            end
        end

        function val = get.hFastZ(obj)
            val = [];
            if ~isempty(obj.hScan) && isprop(obj.hScan,'hFastZs') && ~isempty(obj.hScan.hFastZs)
                val = obj.hScan.hFastZs{1};
            end
        end

        function set.hScan(obj,val)
            val = obj.hResourceStore.filterByName(val);

            if ~isequal(val,obj.hScan)
                assert(~obj.mdlInitialized,'Cannot change hScan while ScanImage is running.');

                if most.idioms.isValidObj(val)
                    validateattributes(val ...
                        ,{'scanimage.components.scan2d.RggScan' ...
                        ,'scanimage.components.scan2d.LinScan' ...
                        ,'scanimage.components.scan2d.SlmScan'}...
                        ,{'scalar'});
                end

                obj.hScan.unregisterUser(obj);
                obj.hScan = val;
                obj.hScan.registerUser(obj,'Scan2D');
            end
        end

        function set.BeamAiId(obj,val)
            val = obj.hResourceStore.filterByName(val);

            if ~isequal(val,obj.BeamAiId)
                if most.idioms.isValidObj(val)
                    validateattributes(val,{'dabs.resources.ios.AI'},{'scalar'});
                end

                obj.deinit();
                obj.BeamAiId.unregisterUser(obj);
                obj.BeamAiId = val;
                obj.BeamAiId.registerUser(obj,'Beam monitor');
            end
        end

        function set.loggingStartTrigger(obj,val)
            val = obj.hResourceStore.filterByName(val);

            if ~isequal(val,obj.loggingStartTrigger)
                if most.idioms.isValidObj(val)
                    validateattributes(val,{'dabs.resources.ios.PFI'},{'scalar'});
                end

                obj.deinit();
                obj.loggingStartTrigger.unregisterUser(obj);
                obj.loggingStartTrigger = val;
                obj.loggingStartTrigger.registerUser(obj,'Logging start trigger');
            end
        end

        function set.stimActiveOutputChannel(obj,val)
            val = obj.hResourceStore.filterByName(val);

            if ~isequal(val,obj.stimActiveOutputChannel)
                if most.idioms.isValidObj(val)
                    validateattributes(val,{'dabs.resources.ios.DO'},{'scalar'});
                    assert(val.supportsHardwareTiming,'%s.stimActiveOutputChannel: %s does not support hardware timing.',obj.name,val.name);
                end

                obj.deinit();
                obj.stimActiveOutputChannel.unregisterUser(obj);
                obj.stimActiveOutputChannel = val;
                obj.stimActiveOutputChannel.registerUser(obj,'Stim active signal');
            end
        end

        function set.beamActiveOutputChannel(obj,val)
            val = obj.hResourceStore.filterByName(val);

            if ~isequal(val,obj.beamActiveOutputChannel)
                if most.idioms.isValidObj(val)
                    validateattributes(val,{'dabs.resources.ios.DO'},{'scalar'});
                    assert(val.supportsHardwareTiming,'%s.beamActiveOutputChannel: %s does not support hardware timing.',obj.name,val.name);
                end

                obj.deinit();
                obj.beamActiveOutputChannel.unregisterUser(obj);
                obj.beamActiveOutputChannel = val;
                obj.beamActiveOutputChannel.registerUser(obj,'Beam active signal');
            end
        end

        function set.slmTriggerOutputChannel(obj,val)
            val = obj.hResourceStore.filterByName(val);

            if ~isequal(val,obj.slmTriggerOutputChannel)
                if most.idioms.isValidObj(val)
                    validateattributes(val,{'dabs.resources.ios.DO'},{'scalar'});
                    assert(val.supportsHardwareTiming,'%s.slmTriggerOutputChannel: %s does not support hardware timing.',obj.name,val.name);
                end

                obj.deinit();
                obj.slmTriggerOutputChannel.unregisterUser(obj);
                obj.slmTriggerOutputChannel = val;
                obj.slmTriggerOutputChannel.registerUser(obj,'SLM trigger signal');
            end
        end
    end

    methods
        function startMonitoring(obj,sync)
            %   Starts the monitoring process for the associated Photostim object.
            %
            %   Parameters
            %       sync - Flag that determines whether (true) or not (false)
            %       to set up a start trigger and perform automatic routing.
            %
            %   Syntax
            %       photostimObj.startMonitoring(sync)

            if nargin < 2 || isempty(sync)
                sync = false;
            end

            if obj.numInstances <= 0
                return
            end

            if ~most.idioms.isValidObj(obj.hTaskMonitoring)
                obj.prepareMonitorTask();
            elseif ~obj.hTaskMonitoring.done
                return
            else
                obj.hTaskMonitoring.abort();
            end

            if sync
                if obj.isVdaq
                    obj.hTaskMonitoring.startTrigger = obj.hSI.hScan2D.trigFrameClkOutInternalTerm;
                else
                    %%% set up start trigger
                    try
                        %try automatic routing
                        obj.hTaskMonitoring.startTrigger = obj.hSI.hScan2D.trigFrameClkOutInternalTerm;
                        obj.hTaskMonitoring.verifyConfig();
                    catch ME
                        % Error -89125 is expected: No registered trigger lines could be found between the devices in the route.
                        % Error -89139 is expected: There are no shared trigger lines between the two devices which are acceptable to both devices.
                        if isempty(strfind(ME.message, '-89125')) && isempty(strfind(ME.message, '-89139')) % filter error messages
                            rethrow(ME)
                        end

                        if most.idioms.isValidObj(obj.loggingStartTrigger)
                            obj.hTaskMonitoring.startTrigger = obj.loggingStartTrigger.channelName;
                        else
                            most.idioms.warn('Could not sync photostim monitoring start trigger to imaging. Make sure to specify loggingStartTrigger in Photostim MDF');
                        end
                    end

                    %%% set up timebase
                    if ismember(get(obj.hTaskMonitoring.hDevice,'busType'), {'DAQmx_Val_PXI','DAQmx_Val_PXIe'})
                        obj.hTaskMonitoring.sampleClockTimebaseRate = 10e6;
                        obj.hTaskMonitoring.sampleClockTimebaseSource = ['/' obj.hTaskMonitoring.deviceName '/PXI_Clk10'];
                    else
                        if isprop(obj.hScan,'referenceClockIn') && most.idioms.isValidObj(obj.hScan.referenceClockIn)
                            obj.hTaskMonitoring.sampleClockTimebaseRate = 10e6;
                            obj.hTaskMonitoring.sampleClockTimebaseSource = obj.hScan.referenceClockIn.channelName;
                        else
                            most.idioms.warn('Could not sync photostim monitoring timebase to imaging scanner. Make sure to specify referenceClockIn in photostim scanner MDF');
                        end
                    end
                end
            else
                obj.hTaskMonitoring.startTrigger = '';
            end

            obj.monitoringRingBuffer = NaN(obj.monitoringRingBufferSize * obj.monitoringEveryNSamples,3);
            obj.hTaskMonitoring.start();
        end

        function maybeStopMonitoring(obj)
            %   Stops the monitoring process for the associated Photostim object only if no monitoring and
            %   no logging processes are currently active.
            %
            %   Syntax
            %       photostimObj.maybeStopMonitoring()
            if ~obj.currentlyMonitoring && ~obj.currentlyLogging
                obj.stopMonitoring();
            end
        end

        function stopMonitoring(obj)
            %   Stops the monitoring process for the associated Photostim object.
            %
            %   Syntax
            %       photostimObj.stopMonitoring()
            obj.currentlyMonitoring = false;
            obj.currentlyLogging = false;

            if obj.numInstances <= 0
                return
            end

            if ~most.idioms.isValidObj(obj.hTaskMonitoring)
                return;
            end

            try
                obj.hTaskMonitoring.abort();
                obj.hTaskMonitoring.unreserveResource();
                obj.monitoringRingBuffer = [];
                if most.idioms.isValidObj(obj.hSI.hDisplay)
                    obj.hSI.hDisplay.forceRoiDisplayTransform = false;
                    if ~isempty(obj.hSI.hDisplay.hLinesPhotostimMonitor)
                        set([obj.hSI.hDisplay.hLinesPhotostimMonitor.patch],'Visible','off');
                        set([obj.hSI.hDisplay.hLinesPhotostimMonitor.endMarker],'Visible','off');
                        set([obj.hSI.hDisplay.hLinesPhotostimMonitor.endMarkerSlm],'Visible','off');
                    end
                end
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
        end

        function set.monitoring(obj,val)
            val = obj.validatePropArg('monitoring',val);

            if obj.numInstances <= 0
                return
            end

            if val && val ~= obj.monitoring && ~obj.graphics2014b
                v = ver('MATLAB');
                v = strrep(strrep(v.Release,'(',''),')','');
                choice = questdlg(sprintf('Matlab version %s can become instable using photostim monitoring.\nMatlab version 2015a or later is recommended.\n\nDo you want to enable the feature anyway?',v),...
                    'Matlab version warning','Yes','No','No');
                if ~strcmpi(choice,'yes')
                    return
                end
            end

            assert(~val || (obj.hScan.xGalvo.feedbackCalibrated && obj.hScan.yGalvo.feedbackCalibrated), 'Photostim feedback calibration is invalid. Feedback sensors must be calibrated first.');

            if obj.componentUpdateProperty('monitoring',val)
                if ~val
                    obj.currentlyMonitoring = false;
                    obj.maybeStopMonitoring();
                elseif obj.active
                    obj.hSI.hDisplay.forceRoiDisplayTransform = true;

                    if ~obj.hSI.hConfigurationSaver.cfgLoadingInProgress
                        obj.currentlyMonitoring = true;
                        try
                            obj.startMonitoring();
                        catch ME
                            obj.currentlyMonitoring = false;
                            ME.rethrow;
                        end
                    end
                end

                obj.monitoring = val;
            end
        end

        function set.logging(obj,val)
            val = obj.validatePropArg('logging',val);

            if obj.numInstances <= 0
                return
            end

            assert(~val || (obj.hScan.xGalvo.feedbackCalibrated && obj.hScan.yGalvo.feedbackCalibrated), 'Photostim feedback calibration is invalid. Feedback sensors must be calibrated first.');

            if obj.currentlyLogging
                error('Cannot disable logging while logging is in progress');
            end

            obj.logging = val;
        end

        function v = get.parallelSupport(obj)
            if obj.numInstances
                if isa(obj.hScan,'scanimage.components.scan2d.SlmScan')
                    v = true;
                elseif obj.isVdaq
                    if isa(obj.hSI.hScan2D, 'scanimage.components.scan2d.RggScan')
                        v = ~isequal(obj.hScan.hDAQ,obj.hSI.hScan2D.hDAQ);

                        if ~v
                            myChans    = getScan2DChans(obj.hScan);
                            theirChans = getScan2DChans(obj.hSI.hScan2D);
                            v = isempty(intersect(myChans,theirChans));
                        end
                    else
                        v = true;
                    end
                else
                    [aiDaqs,       aoCtrDaqs,       beamDaqs] = getDAQs(obj.hScan,true);
                    [imagingAiDaqs,imagingAoCtrDaqs,imagingBeamDaqs] = getDAQs(obj.hSI.hScan2D,false);

                    v =      isempty(intersect(aoCtrDaqs, imagingAoCtrDaqs));
                    v = v && isempty(intersect(aiDaqs,    imagingAiDaqs   ));
                    v = v && isempty(intersect(beamDaqs,  imagingBeamDaqs ));
                end
            else
                v = false;
            end

            function chans = getScan2DChans(hScan)
                chans = {};
                if most.idioms.isValidObj(hScan.xGalvo)
                    chans{end+1} = hScan.xGalvo.hAOControl.name;
                end

                if most.idioms.isValidObj(hScan.yGalvo)
                    chans{end+1} = hScan.yGalvo.hAOControl.name;
                end

                beamChannels = cellfun(@(hB)hB.hAOControl.name,hScan.hBeams,'UniformOutput',false);
                chans = [chans,beamChannels];
            end

            function [aiDaqs,aoCtrDaqs,beamDaqs] = getDAQs(hScan,includeGalvoFeedbackDAQ)
                beamDaqs = cellfun(@(hB)hB.hAOControl.hDAQ.name,hScan.hBeams,'UniformOutput',false);
                beamDaqs = unique(beamDaqs);

                switch class(hScan)
                    case 'scanimage.components.scan2d.ResScan'
                        aoCtrDaqs = unique({hScan.yGalvo.hAOControl.hDAQ.name hScan.hDAQAux.name});
                        aiDaqs = {};
                    case 'scanimage.components.scan2d.LinScan'
                        aoCtrDaqs = unique({hScan.xGalvo.hAOControl.hDAQ.name hScan.yGalvo.hAOControl.hDAQ.name hScan.hDAQAux.name});

                        aiDaqs = {hScan.hDAQAcq.name};
                        if includeGalvoFeedbackDAQ
                            if most.idioms.isValidObj(hScan.xGalvo.hAIFeedback) && most.idioms.isValidObj(hScan.yGalvo.hAIFeedback)
                                aiDaqs{end+1} = hScan.xGalvo.hAIFeedback.hDAQ.name;
                                aiDaqs{end+1} = hScan.yGalvo.hAIFeedback.hDAQ.name;
                            end

                            aiDaqs = unique(aiDaqs);
                        end

                    otherwise
                        aoCtrDaqs = {};
                        aiDaqs = {};
                end
            end
        end

        function set.stimRoiGroups(obj,v)
            if isempty(v)
                obj.stimRoiGroups = scanimage.mroi.RoiGroup.empty;
            else
                assert(isa(v,'scanimage.mroi.RoiGroup'), 'Invalid setting for stimRoiGroups.');
                obj.stimRoiGroups = v;
            end
        end

        function set.zMode(obj,v)
            assert(~obj.active, 'Cannot change this property while active.');

            if obj.zWithBeams || obj.zWithGalvos
                % if z shares a daq with beams or galvos, must use 3d mode
                v = '3D';
            elseif ~obj.hasZ
                v = '2D';
            end

            obj.zMode = v;
            obj.zMode3D = strcmp(v,'3D');

            if obj.isVdaq
                if obj.zMode3D
                    obj.hTaskZ.syncTo(obj.hTaskMain);
                elseif ~isempty(obj.hTaskZ)
                    obj.hTaskZ.clearSyncedTasks();
                end
            end
        end
    end

    %% USER METHODS
    methods
        function start(obj)
            %   This 'start' method overrides the default implementation of scanimage.interfaces.Component.start.
            %   Using the regular implementation of start is problematic because the photostim component
            %   can be started and stopped independently of the imaging components.
            %   A failure in photostim should not necessarily affect imaging.
            %
            %   -Make sure that the photostim component is configured and has
            %   been successfully initialized. Ensure LinScan is configured.
            %
            %   -If the photostim component is already active. You must first
            %   abort if you want to load new stimulus patterns.
            %
            %   -Photostim can only be started in on demand mode while imaging/linear imaging is active.
            %
            %   Syntax
            %       photostimObj.start()

            assert(~obj.active, 'The photostim component is already active. You must first abort if you want to load new stimulus patterns.');
            assert(obj.numInstances > 0, 'The photostim component is not configured or failed to initialize. Ensure LinScan is configured.');
            assert(~obj.hSI.active || obj.parallelSupport || strcmp(obj.stimulusMode, 'onDemand'), 'Current configuration does not support simultaneous imaging and stimulation. Photostim can only be started in on demand mode while imaging is active.');
            assert(~obj.hScan.active || strcmp(obj.stimulusMode, 'onDemand'), 'Photostim can only be started in on demand mode while linear imaging is active.');

            if obj.zMode3D
                if obj.hSI.active
                    sharedFastZDevice = any( cellfun(@(hFz)isequal(obj.hFastZ,hFz),obj.hSI.hScan2D.hFastZs) );
                    assert(~sharedFastZDevice,'Cannot start in 3D mode because Z actuator is shared with imaging scanner which is currently imaging.');
                end
            end

            try
                obj.status = 'Initializing...';
                obj.initInProgress = true;
                obj.completedSequences = 0;

                obj.park(); % also resets offsets

                [ao, triggerSamps, path] = obj.generateAO();

                most.idioms.safeDeleteObj(obj.hTaskSyncHelper);
                obj.hTaskSyncHelper = [];
                most.idioms.safeDeleteObj(obj.hTaskSyncHelperSoft);
                obj.hTaskSyncHelperSoft = [];
                most.idioms.safeDeleteObj(obj.hTaskArmedTrig);
                obj.hTaskArmedTrig = [];
                most.idioms.safeDeleteObj(obj.hTaskArmedTrigSoft);
                obj.hTaskArmedTrigSoft = [];
                most.idioms.safeDeleteObj(obj.hTaskAutoTrigger);
                obj.hTaskAutoTrigger = [];

                if ~obj.hScan.simulated
                    % set up triggering
                    if ~obj.isVdaq && obj.autoTriggerPeriod
                        obj.hTaskAutoTrigger = most.util.safeCreateTask('PhotostimAutoTriggerTask');
                        obj.hTaskAutoTrigger.createCOPulseChanTime(obj.hTaskMain.deviceName, 3, '', obj.autoTriggerPeriod/2, obj.autoTriggerPeriod/2, 0);
                        obj.hTaskAutoTrigger.cfgImplicitTiming('DAQmx_Val_ContSamps');
                        obj.hTaskAutoTrigger.channels(1).set('pulseTerm','');
                    end

                    if ~obj.isVdaq && ~isempty(obj.syncTriggerTerm)
                        % Set up task to create 4 pulses on ctr1 for every sync rising edge
                        obj.hTaskSyncHelper = most.util.safeCreateTask('PhotostimSyncHelperTask');
                        obj.hTaskSyncHelper.createCOPulseChanTicks(obj.hTaskMain.deviceName, 1, '', '', 2, 2, 0);
                        obj.hTaskSyncHelper.channels(1).set('pulseTerm','');
                        obj.hTaskSyncHelper.set('startTrigRetriggerable',true);
                        obj.hTaskSyncHelper.cfgDigEdgeStartTrig(obj.syncTermString);
                        obj.hTaskSyncHelper.cfgImplicitTiming('DAQmx_Val_FiniteSamps',4);
                        obj.hTaskSyncHelper.start();

                        obj.hTaskSyncHelperSoft = most.util.safeCreateTask('PhotostimSyncHelperTaskSoft');
                        obj.hTaskSyncHelperSoft.createCOPulseChanTicks(obj.hTaskMain.deviceName, 1, '', '', 2, 2, 0);
                        obj.hTaskSyncHelperSoft.channels(1).set('pulseTerm','');
                        obj.hTaskSyncHelperSoft.cfgImplicitTiming('DAQmx_Val_FiniteSamps',4);
                    end

                    if ~obj.isVdaq
                        obj.hTaskArmedTrig = most.util.safeCreateTask('PhotostimArmedTriggerTask');
                        obj.hTaskArmedTrigSoft = most.util.safeCreateTask('PhotostimArmedTriggerTaskSoft');

                        if isempty(obj.syncTriggerTerm)
                            % ctr0 is triggered by the stim trigger and internally timed. this
                            % counter isnt really needed. you could trigger the AO directly from
                            % the stim trigger. this is only here for consistency with syncd operation
                            obj.hTaskArmedTrig.createCOPulseChanTime(obj.hTaskMain.deviceName, 0, '', 1e-3, 1e-3, 0);
                            obj.hTaskArmedTrigSoft.createCOPulseChanTime(obj.hTaskMain.deviceName, 0, '', 1e-3, 1e-3, 0);
                        else
                            % ctr1 generates 4 pulses on every rising sync signal
                            % ctr1 is configured and started in the set method for sync channel
                            % ctr0 is triggered by the stim trigger and timed by ctr1
                            obj.hTaskArmedTrig.createCOPulseChanTicks(obj.hTaskMain.deviceName, 0, '', 'Ctr1InternalOutput', 2, 2, 0);
                            obj.hTaskArmedTrigSoft.createCOPulseChanTicks(obj.hTaskMain.deviceName, 0, '', 'Ctr1InternalOutput', 2, 2, 0);
                        end

                        obj.hTaskArmedTrig.set('startTrigRetriggerable',true);

                        if obj.autoTriggerPeriod
                            obj.hTaskArmedTrig.cfgDigEdgeStartTrig('Ctr3InternalOutput');
                        else
                            obj.hTaskArmedTrig.cfgDigEdgeStartTrig(obj.trigTermString);
                        end

                        obj.hTaskArmedTrig.channels(1).set('pulseTerm','');
                        obj.hTaskArmedTrigSoft.channels(1).set('pulseTerm','');
                    end

                    % route frame clock
                    if obj.isVdaq
                        if ~isempty(obj.syncTriggerTerm)
                            error('not done');
                            if obj.autoTriggerPeriod
                            elseif ~isempty(obj.stimTriggerTerm)
                            else
                            end
                        elseif obj.autoTriggerPeriod
                        elseif obj.stimTrigIsFrame
                            obj.hTaskMain.startTrigger = obj.hSI.hScan2D.trigFrameClkOutInternalTerm;
                        elseif ~isempty(obj.stimTriggerTerm)
                            obj.hTaskMain.startTrigger = obj.stimTriggerTerm;
                        else
                            obj.hTaskMain.startTrigger = [];
                        end
                    end

                    if strcmp(obj.stimulusMode, 'onDemand')
                        primeNow = ~obj.hScan.active && (~obj.hSI.active || obj.parallelSupport);
                        if primeNow
                            obj.primedStimulus = 1;
                        else
                            obj.primedStimulus = [];
                        end

                        if obj.isVdaq
                            % set up spcl trigger for ext stim selection trigger

                        else
                            % set up ext stim selection trigger
                            if ~isempty(obj.stimSelectionTerms)
                                %task that triggers a software callback when the trigger comes
                                if ~most.idioms.isValidObj(obj.hTaskExtStimSel)
                                    obj.hTaskExtStimSel = most.util.safeCreateTask('PhotostimExtStimSelectionCOTask');
                                    obj.hTaskExtStimSel.createCOPulseChanTime(obj.hTaskMain.deviceName, 2, '', 1e-3, 1e-3);
                                    obj.hTaskExtStimSel.channels(1).set('pulseTerm','');
                                    obj.hTaskExtStimSel.cfgImplicitTiming('DAQmx_Val_FiniteSamps',1);
                                    obj.hTaskExtStimSel.registerDoneEvent(@obj.extStimSelectionCB);
                                    obj.hTaskExtStimSel.cfgDigEdgeStartTrig(sprintf('PFI%d',obj.stimSelectionTriggerTerm));
                                end

                                %task to actually read the digital lines
                                if ~most.idioms.isValidObj(obj.hTaskExtStimSelRead)
                                    if isempty(obj.stimSelectionDevice)
                                        dev = obj.hTaskMain.deviceName;
                                    else
                                        dev = obj.stimSelectionDevice;
                                    end

                                    obj.hTaskExtStimSelRead = most.util.safeCreateTask('PhotostimExtStimSelectionDITask');
                                    fcn = @(trm)obj.hTaskExtStimSelRead.createDIChan(dev,scanimage.util.translateTriggerToPort(trm));
                                    arrayfun(fcn, obj.stimSelectionTerms, 'UniformOutput', false);
                                end

                                obj.hTaskExtStimSelRead.control('DAQmx_Val_Task_Unreserve');
                                obj.hTaskExtStimSel.control('DAQmx_Val_Task_Unreserve');
                                obj.hTaskExtStimSel.start();
                            end
                        end
                    else
                        % sequence
                        primeNow = 1;
                        obj.primedStimulus = [];
                        obj.sequencePosition = 1;
                        obj.nextStimulus = obj.sequenceSelectedStimuli(1);
                    end

                    for idx = 1:numel(obj.hScan.hBeams)
                        obj.hScan.hBeams{idx}.setLastKnownPowerFractionToNaN();
                    end

                    % prepare slm
                    if obj.hasSlm && ~obj.hScan.active
                        % prime SLM with first mask
                        obj.hSlm.writePhaseMaskRaw(ao(1).SLM(1).mask.phase,false);
                        obj.currentSlmPattern = path(1).SLM(1).pattern;


                        if strcmp(obj.stimulusMode, 'sequence')
                            % check for triggering
                            if obj.hSlm.hDevice.queueAvailable && most.idioms.isValidObj(obj.slmTriggerOutputChannel)
                                maskIdxs = obj.stimAO.SLMmaskIdxs(:);

                                masks = arrayfun(@(ao_)ao_.mask.phase,obj.stimAO.SLM,'UniformOutput',false);
                                masks = cat(3,masks{:});
                                masks = gather(masks);

                                % SLM is primed with first mask at this
                                % point. Need to shuffle masks to update in
                                % correct order
                                shuffledMaskIdxs = [maskIdxs(2:end);maskIdxs(1)];

                                % we update the SLM at the end of a
                                % stimulus with the pattern for the next
                                % stimulus
                                obj.slmTriggerOutputChannel.setValue(false); % pull SLM trigger down
                                obj.hSlm.hDevice.writeQueue(masks,shuffledMaskIdxs);
                                obj.hSlm.hDevice.startQueue();
                                obj.slmQueueActive = true;
                            end
                        end
                    end

                    % prepare digital pulse task
                    enableDigitalOutput = most.idioms.isValidObj(obj.hTaskDigitalOut) ...
                        && ( ~obj.hScan.active || isa(obj.hScan,'scanimage.components.scan2d.RggScan') );

                    if enableDigitalOutput
                        obj.hTaskDigitalOut.allowRetrigger = strcmp(obj.stimulusMode, 'sequence') || obj.allowMultipleOutputs;
                        obj.hTaskDigitalOut.sampleRate = obj.sampleRates.digital;
                        obj.hTaskDigitalOut.samplesPerTrigger = triggerSamps(1).D;

                        obj.hTaskDigitalOut.setChannelOutputValues(false(1,obj.hTaskDigitalOut.numChannels)); % ensure outputs are low

                        obj.hTaskDigitalOut.unreserveResource();

                        mask = [most.idioms.isValidObj(obj.stimActiveOutputChannel) ...
                            ,most.idioms.isValidObj(obj.beamActiveOutputChannel) ...
                            ,most.idioms.isValidObj(obj.slmTriggerOutputChannel)];

                        output = ao(1).D(:,mask);

                        obj.hTaskDigitalOut.writeOutputBuffer(output);
                    end

                    % prepare z task
                    if obj.separateZDAQ && obj.zMode3D
                        obj.hTaskZ.allowRetrigger = strcmp(obj.stimulusMode, 'sequence') || obj.allowMultipleOutputs;
                        obj.hTaskZ.sampleRate = obj.sampleRates.fastz;
                        obj.hTaskZ.samplesPerTrigger = triggerSamps(1).Z;

                        if primeNow
                            obj.hTaskZ.unreserveResource();
                            obj.hTaskZ.writeOutputBuffer(ao(1).Z);
                        end

                        if ~obj.isVdaq && strcmp(obj.stimulusMode, 'sequence')
                            obj.hTaskZ.start();
                        end
                    end

                    if strcmp(obj.stimulusMode, 'sequence')
                        if obj.isVdaq
                            % start spcl trigger module
                        else
                            obj.hTaskArmedTrig.start();
                        end
                        obj.hSI.hUserFunctions.notify('seqStimStart');
                    end
                end

                % prepare galvo task
                if obj.hasGalvos
                    obj.hTaskGalvo.allowRetrigger = strcmp(obj.stimulusMode, 'sequence') || obj.allowMultipleOutputs;
                    obj.hTaskGalvo.sampleRate = obj.sampleRates.galvo;
                    obj.hTaskGalvo.samplesPerTrigger = triggerSamps(1).G;
                    obj.hTaskGalvo.sampleCallbackN = triggerSamps(1).G;

                    if primeNow
                        obj.hTaskGalvo.unreserveResource();
                        buf = ao(1).G;
                        if obj.hasBeams && ~obj.separateBeamDAQ
                            buf = [buf ao(1).B];
                        end
                        if obj.zWithGalvos
                            buf = [buf ao(1).Z];
                        end
                        obj.hTaskGalvo.writeOutputBuffer(buf);
                    end

                    if strcmp(obj.stimulusMode, 'sequence')
                        obj.hTaskGalvo.start();
                    end
                end

                % prepare beam task
                if obj.separateBeamDAQ
                    obj.hTaskBeams.allowRetrigger = strcmp(obj.stimulusMode, 'sequence') || obj.allowMultipleOutputs;
                    obj.hTaskBeams.sampleRate = obj.sampleRates.beams;
                    obj.hTaskBeams.samplesPerTrigger = triggerSamps(1).B;

                    if ~obj.hasGalvos
                        obj.hTaskBeams.sampleCallbackN = triggerSamps(1).B;
                    end

                    if primeNow
                        obj.hTaskBeams.unreserveResource();
                        buf = ao(1).B;
                        if obj.zWithBeams
                            buf = [buf ao(1).Z];
                        end
                        obj.hTaskBeams.writeOutputBuffer(buf);
                    end

                    if strcmp(obj.stimulusMode, 'sequence')
                        obj.hTaskBeams.start();
                    end
                end

                obj.active = true;
                obj.lastMotion = [0 0];
                obj.initInProgress = false;

                obj.hScan.openExcitationShutters();

                if strcmp(obj.stimulusMode, 'onDemand')
                    obj.status = 'Ready';
                elseif strcmp(obj.stimulusMode, 'sequence')
                    obj.status = 'Running';
                    if obj.stimImmediately
                        obj.triggerStim();
                    end
                end

                if most.idioms.isValidObj(obj.hTaskAutoTrigger)
                    try
                        obj.hTaskAutoTrigger.start();
                    catch
                        error('Failed to start auto trigger. DAQ route conflict.');
                    end
                end

                obj.monitoring = obj.monitoring;
            catch ME
                obj.initInProgress = false;
                obj.abort();
                ME.rethrow;
            end
        end

        function backupRoiGroups(obj)
            %   Saves the ROI (region of interest) groups defined in the associated Photostim object,
            %   in a backup file in the filesystem directory where the scanimage application is currently running.
            %
            %   The backup filename is 'roigroupsStim.backup'.
            %
            %   Syntax
            %       photostimObj.backupRoiGroups()
            siDir = fileparts(which('scanimage'));
            filename = fullfile(siDir, 'roigroupsStim.backup');
            roigroupsStim = obj.stimRoiGroups; %#ok<NASGU>
            save(filename,'roigroupsStim','-mat');
        end

        function triggerStim(obj)
            %   Triggers the stimulus for the associated Photostim object.
            %
            %   -The Photostim module must be started before triggerStim() is called.
            %
            %   Syntax
            %       photostimObj.triggerStim()

            assert(obj.active, 'Photostim module must be started first.');
            assert(~strcmp(obj.status, 'Ready'), 'No stimulus has been selected. Select a stimulus to trigger.');

            if ~obj.hScan.simulated
                if obj.isVdaq
                    obj.hTaskMain.softTrigger();
                else
                    assert(obj.hTaskArmedTrigSoft.isTaskDone(),'Execution of previous soft trigger is not yet completed.');
                    obj.hTaskArmedTrig.abort();
                    obj.hTaskArmedTrigSoft.abort();
                    obj.hTaskArmedTrigSoft.start();

                    % tried using DAQmx event done, but it does not fire reliably; use polling instead
                    timeout_s = 1;
                    completed = pollingWaitForTaskCompletion(obj.hTaskArmedTrigSoft,timeout_s);

                    obj.hTaskArmedTrigSoft.abort();
                    obj.hTaskArmedTrig.start();

                    assert(completed,'Sync trigger was not received within timeout of %.0fms',timeout_s*1e3);
                end
            end

            %%% Nested functions
            function tf = pollingWaitForTaskCompletion(hTask,timeout_s)
                tf = false;
                s = tic();
                while ~tf && toc(s)<=timeout_s
                    pause(0.01);
                    tf = hTask.isTaskDone();
                end
            end
        end

        function triggerSync(obj)
            %   Triggers the synchronous stimulus for the associated Photostim object.
            %
            %   -The Photostim module must be started before triggerSync() is called.
            %
            %   Syntax
            %       photostimObj.triggerSync()
            assert(obj.active, 'Photostim module must be started first.');

            if ~obj.hScan.simulated && ~isempty(obj.syncTriggerTerm)
                if obj.isVdaq
                    obj.hFpga.hSpclTrig.softSync();
                else
                    assert(most.idioms.isValidObj(obj.hTaskSyncHelper));
                    obj.hTaskSyncHelper.abort();
                    obj.hTaskSyncHelperSoft.abort();
                    obj.hTaskSyncHelperSoft.start();
                    pause(0.1);
                    obj.hTaskSyncHelperSoft.abort();
                    obj.hTaskSyncHelper.start();
                end
            end
        end

        function onDemandStimNow(obj, stimGroupIdx, verbose)
            %   Starts the stimulus process for the associated Photostim object, on demand.
            %
            %   -This method can only be used in onDemand mode.
            %
            %   -The Photostim module must be started before onDemandStimNow() is called.
            %
            %   -The linear scanner should not be actively imaging. Abort imaging to output a stimulation.
            %
            %   Parameters
            %       stimGroupIdx - Stimulus group number.
            %       verbose - Flag that determines whether (true) or not (false) additional timing information
            %       is to be written to the standard output.
            %
            %   Syntax
            %       photostimObj.onDemandStimNow(stimGroupIdx, verbose)

            if nargin < 3 || isempty(verbose)
                verbose = false;
            end

            t = tic();
            assert(strcmp(obj.stimulusMode, 'onDemand'), 'This method can only be used in onDemand mode.');
            assert(obj.active, 'Photostim module must be started first.');
            assert(~obj.hScan.active, 'The linear scanner is actively imaging. Abort imaging to output a stimulation.');

            if ~strcmp(obj.status, 'Ready')
                if ~obj.allowMultipleOutputs
                    most.idioms.warn('The previous stimulus may not have completed output. Aborting to load new stimulus.');
                end
                if obj.isVdaq
                    % abort spcl trigger
                else
                    obj.hTaskArmedTrig.abort();
                end

                if obj.hasGalvos
                    obj.hTaskGalvo.abort();
                end

                if obj.separateBeamDAQ
                    obj.hTaskBeams.abort();
                end

                if ~obj.isVdaq && obj.separateZDAQ
                    obj.hTaskZ.abort();
                end
            end

            obj.status = sprintf('Preparing stumulus %d for output...',stimGroupIdx);
            drawnow('nocallbacks');

            if obj.hasGalvos
                sz = size(obj.stimAO(stimGroupIdx).G,1);
            else
                sz = size(obj.stimAO(stimGroupIdx).B,1);
            end

            if isempty(obj.primedStimulus) || obj.primedStimulus ~= stimGroupIdx
                assert(stimGroupIdx <= numel(obj.stimRoiGroups), 'Invalid stimulus group selection.');
                assert(sz > 0, 'The selected stimulus is empty. No output will be made.');

                if most.idioms.isValidObj(obj.hTaskDigitalOut)
                    N = size(obj.stimAO(stimGroupIdx).D,1);
                    obj.hTaskDigitalOut.unreserveResource();
                    obj.hTaskDigitalOut.sampleRate = obj.sampleRates.digital;
                    obj.hTaskDigitalOut.samplesPerTrigger = N;

                    mask = [most.idioms.isValidObj(obj.stimActiveOutputChannel) ...
                        ,most.idioms.isValidObj(obj.beamActiveOutputChannel) ...
                        ,most.idioms.isValidObj(obj.slmTriggerOutputChannel)];

                    output = obj.stimAO(stimGroupIdx).D(:,mask);
                    obj.hTaskDigitalOut.writeOutputBuffer(output);
                end

                if obj.hasGalvos
                    buf = obj.stimAO(stimGroupIdx).G;

                    obj.hTaskGalvo.unreserveResource();
                    obj.hTaskGalvo.sampleRate = obj.sampleRates.galvo;
                    obj.hTaskGalvo.samplesPerTrigger = size(buf,1);

                    if obj.hasBeams && ~obj.separateBeamDAQ
                        buf = [buf obj.stimAO(stimGroupIdx).B];
                    end
                    if obj.zWithGalvos
                        buf = [buf obj.stimAO(stimGroupIdx).Z];
                    end
                    obj.hTaskGalvo.writeOutputBuffer(buf);
                end

                if obj.separateBeamDAQ
                    buf = obj.stimAO(stimGroupIdx).B;

                    obj.hTaskBeams.unreserveResource();
                    obj.hTaskBeams.sampleRate = obj.sampleRates.beams;
                    obj.hTaskBeams.samplesPerTrigger = size(buf,1);

                    if obj.zWithBeams
                        buf = [buf obj.stimAO(stimGroupIdx).Z];
                    end
                    obj.hTaskBeams.writeOutputBuffer(buf);
                end

                if obj.separateZDAQ && obj.zMode3D
                    buf = obj.stimAO(stimGroupIdx).Z;

                    obj.hTaskZ.unreserveResource();
                    obj.hTaskZ.sampleRate = obj.sampleRates.fastz;
                    obj.hTaskZ.samplesPerTrigger = size(buf,1);
                    obj.hTaskZ.writeOutputBuffer(buf);
                end

                if obj.hasSlm
                    if ~obj.slmQueueActive
                        obj.hSlm.writePhaseMaskRaw(obj.stimAO(stimGroupIdx).SLM.mask.phase,false);
                    end
                    obj.currentSlmPattern = obj.stimPath(stimGroupIdx).SLM.pattern;
                end

                obj.primedStimulus = stimGroupIdx;
            end

            obj.numOutputs = 0;
            obj.hTaskMain.sampleCallbackN = sz;
            if obj.separateBeamDAQ
                obj.hTaskBeams.start();
            end
            if ~obj.isVdaq && obj.separateZDAQ && obj.zMode3D
                obj.hTaskZ.start();
            end
            if obj.hasGalvos
                obj.hTaskGalvo.start();
            end

            if obj.isVdaq
                % start spcl trigger module
            else
                obj.hTaskArmedTrig.start();
            end

            obj.hSI.hUserFunctions.notify('onDmdStimStart');

            if obj.stimImmediately
                obj.status = sprintf('Outputting stimulus group %d...', stimGroupIdx);
                if verbose
                    fprintf('It took %.4f seconds from the time you commanded to when the trigger was sent.\n',toc(t));
                end
                obj.triggerStim();
            else
                obj.status = sprintf('Stimulus group %d waiting for trigger...', stimGroupIdx);
                if verbose
                    fprintf('It took %.4f seconds from the time you commanded to when the task was ready and started.\n',toc(t));
                end
            end
        end

        function abort(obj)
            %   Aborts any currently active tasks for the associated Photostim object.
            %
            %   -Aborted tasks include tasks associated with: auto triggers;
            %   armed triggers; beams; and external stimulus.
            %
            %   -The status of the associated Photostim object is set to 'Offline'.
            %
            %   Syntax
            %       photostimObj.abort()

            if obj.numInstances <= 0
                return
            end

            if ~isempty(obj.hScan)
                obj.hScan.closeShutters();
            end

            if most.idioms.isValidObj(obj.hTaskAutoTrigger)
                obj.hTaskAutoTrigger.abort();
                most.idioms.safeDeleteObj(obj.hTaskAutoTrigger);
                obj.hTaskAutoTrigger = [];
            end

            if most.idioms.isValidObj(obj.hTaskArmedTrig)
                obj.hTaskArmedTrig.abort();
                most.idioms.safeDeleteObj(obj.hTaskArmedTrig);
                obj.hTaskArmedTrig = [];
            end

            if most.idioms.isValidObj(obj.hTaskArmedTrigSoft)
                obj.hTaskArmedTrigSoft.abort();
                most.idioms.safeDeleteObj(obj.hTaskArmedTrigSoft);
                obj.hTaskArmedTrigSoft = [];
            end

            if most.idioms.isValidObj(obj.hTaskSyncHelper)
                obj.hTaskSyncHelper.abort();
                most.idioms.safeDeleteObj(obj.hTaskSyncHelper);
                obj.hTaskSyncHelper = [];
            end

            if most.idioms.isValidObj(obj.hTaskSyncHelperSoft)
                obj.hTaskSyncHelperSoft.abort();
                most.idioms.safeDeleteObj(obj.hTaskSyncHelperSoft);
                obj.hTaskSyncHelperSoft = [];
            end

            if obj.hasGalvos
                if most.idioms.isValidObj(obj.hTaskGalvo)
                    obj.park();
                end
            end

            if obj.hasSlm
                if obj.slmQueueActive
                    obj.hSlm.hDevice.abortQueue();
                    obj.slmQueueActive = false;
                end

                obj.hSlm.parkScanner();
                obj.currentSlmPattern = [];
            end

            if obj.separateBeamDAQ
                obj.hTaskBeams.abort();
                obj.hTaskBeams.unreserveResource();
            end

            if obj.separateZDAQ && obj.zMode3D
                obj.hTaskZ.abort();
                obj.hTaskZ.unreserveResource();
            end

            if most.idioms.isValidObj(obj.hTaskExtStimSel)
                obj.hTaskExtStimSel.abort();
            end

            if most.idioms.isValidObj(obj.hScan)
                for idx = 1:numel(obj.hScan.hBeams)
                    try
                        obj.hScan.hBeams{idx}.setPowerFraction(0);
                    catch ME
                        most.ErrorHandler.logAndReportError(ME);
                    end
                end
            end

            if any(obj.lastMotion)
                obj.hScan.hCtl.writeOffsetAngle([0 0]);
                obj.lastMotion = [0 0];
            end

            obj.status = 'Offline';
            obj.stimAO = []; % release memory
            obj.stimPath = []; % release memory
            obj.active = false;
            obj.lastMotion = [0 0];
            obj.primedStimulus = [];

            obj.stopMonitoring();

            obj.hSI.hUserFunctions.notify('photostimAbort');
        end

        function calibrateMonitorAndOffset(obj)
            %   Calibrates the linear scanning mirror feedback (monitor) and offset.
            %
            %   -The associated Photostim object must be configured and
            %   successfully initialized before calibrateMonitorAndOffset() is
            %   called. Ensure LinScan is configured.
            %
            %   -Calibration cannot occur during an active photostimulation.
            %
            %   -Calibration cannot occur while photostim logging is active.
            %
            %   Syntax
            %       photostimObj.calibrateMonitorAndOffset()
            assert(obj.numInstances > 0, 'The photostim component is not configured or failed to initialize. Ensure LinScan is configured.');
            assert(~obj.active,'Cannot calibrate the monitor during active photostimulation');
            assert(~obj.currentlyLogging,'Cannot calibrate while photostim logging is active');

            monitoring_ = obj.monitoring;
            obj.monitoring = false;

            obj.stimScannerset.calibrateScanner('G');

            obj.monitoring = monitoring_;
        end
    end

    %% INTERNAL METHODS
    methods (Hidden)
        function compensateMotion(obj)
            if obj.active && obj.compensateMotionEnabled && ~isempty(obj.hSI.hMotionManager.motionHistory) && isa(obj.hScan, 'scanimage.components.scan2d.LinScan')
                absoluteMotion = obj.hSI.hMotionManager.motionCorrectionVector(1:2) .* strcmpi(obj.hSI.hMotionManager.correctionDeviceXY,'galvos');
                relativeMotion = obj.hSI.hMotionManager.motionHistory(end).drRef(1:2);
                motion = absoluteMotion + relativeMotion;
                if ~any(isnan(motion)) && ~isequal(obj.lastMotion,motion)
                    scannerOrigin_Ref = scanimage.mroi.util.xformPoints([0 0],obj.hScan.scannerToRefTransform);
                    motionPt_ref = scannerOrigin_Ref + motion;
                    motionPt_scanner = scanimage.mroi.util.xformPoints(motionPt_ref,obj.hScan.scannerToRefTransform,true);

                    offsetAngleXY = motionPt_scanner;
                    obj.hScan.hCtl.writeOffsetAngle(offsetAngleXY);

                    obj.lastMotion = motion;
                end
            end
        end

        function park(obj)
            if obj.componentExecuteFunction('park')
                if obj.hasGalvos
                    obj.hTaskGalvo.abort();
                    obj.hTaskGalvo.unreserveResource();
                end
                if ~obj.hScan.active
                    obj.hScan.parkScanner();
                end
            end
        end

        function [ao, samplesPerTrigger, path] = generateAO(obj)

            assert(~isempty(obj.stimRoiGroups),'There must be at least one stimulus group configured.');

            ss = obj.stimScannerset;
            obj.sampleRates.galvo = ss.scanners{1}.sampleRateHz;
            if obj.hasBeams
                obj.sampleRates.beams = ss.beams(1).sampleRateHz;
                obj.sampleRates.digital = obj.sampleRates.beams;
            else
                obj.sampleRates.digital = obj.sampleRates.galvo;
            end
            if obj.hasZ
                obj.sampleRates.fastz = ss.fastz(1).sampleRateHz;
            end
            advSamps = ceil(obj.laserActiveSignalAdvance * obj.sampleRates.digital);
            switch obj.stimulusMode
                case 'sequence'
                    assert(~isempty(obj.sequenceSelectedStimuli), 'At least one stimulus group must be selected for the sequence.');
                    assert(max(obj.sequenceSelectedStimuli) <= numel(obj.stimRoiGroups), 'Invalid stimulus group selection for sequence.');
                    %generate aos

                    activeStimuli = sort(unique(obj.sequenceSelectedStimuli));
                    activeRoiGroups = obj.stimRoiGroups(activeStimuli);
                    indices = zeros(1,length(obj.stimRoiGroups));
                    indices(activeStimuli) = 1:length(activeStimuli);

                    AOs = cell(1,length(activeRoiGroups));
                    paths = cell(1,length(activeRoiGroups));
                    for idx = 1:length(activeRoiGroups)
                        rg = activeRoiGroups(idx);
                        [AOs{idx},~,~,paths{idx}] = rg.scanStackAO(ss,0,0,'',0,[],[],[]);
                        pause(0); % ensure the AO generation does not block Matlab for too long
                    end

                    %make sure none are empty
                    if obj.hasGalvos
                        gSizes = cellfun(@(x)size(x.G,1), AOs);
                        assert(min(gSizes) > 0, 'One or more stimulus groups in the sequence were empty. Remove from the sequence to avoid unexpected results.');

                        %pad AOs
                        [samplesPerTrigger.G, mi] = max(gSizes);
                        AOs = cellfun(@(x)setfield(x,'G',[x.G; repmat(x.G(end,:), samplesPerTrigger.G - size(x.G,1), 1)]),AOs,'UniformOutput',false);
                        paths = cellfun(@(x)setfield(x,'G',[x.G; repmat(x.G(end,:), samplesPerTrigger.G - size(x.G,1), 1)]),paths,'UniformOutput',false);
                    else
                        bSizes = cellfun(@(x)size(x.B,1), AOs);
                        [~, mi] = max(bSizes);
                        assert(min(bSizes) > 0, 'One or more stimulus groups in the sequence were empty. Remove from the sequence to avoid unexpected results.');
                    end

                    %pad AOs
                    if obj.hasBeams
                        bSizes = cellfun(@(x)size(x.B,1), AOs);
                        samplesPerTrigger.B = size(AOs{mi}.B, 1);
                        AOs = cellfun(@(x)setfield(x,'B',[x.B; repmat(x.B(end,:), samplesPerTrigger.B - size(x.B,1), 1)]),AOs,'UniformOutput',false);
                        paths = cellfun(@(x)setfield(x,'B',[x.B; repmat(x.B(end,:), samplesPerTrigger.B - size(x.B,1), 1)]),paths,'UniformOutput',false);

                        %digital
                        samplesPerTrigger.D = samplesPerTrigger.B;
                        for i = 1:numel(AOs)
                            AOs{i}.D = digitalSigs(paths{i}.B,bSizes(i));
                        end
                    else
                        %digital
                        samplesPerTrigger.D = samplesPerTrigger.G;
                        for i = 1:numel(AOs)
                            w = zeros(samplesPerTrigger.G,1);
                            w(1:gSizes(i)) = 1;
                            AOs{i}.D = digitalSigs(w,gSizes(i));
                        end
                    end

                    %pad AOs
                    if obj.hasZ
                        samplesPerTrigger.Z = size(AOs{mi}.Z, 1);
                        AOs = cellfun(@(x)setfield(x,'Z',[x.Z; repmat(x.Z(end,:), samplesPerTrigger.Z - size(x.Z,1), 1)]),AOs,'UniformOutput',false);
                        paths = cellfun(@(x)setfield(x,'Z',[x.Z; repmat(x.Z(end,:), samplesPerTrigger.Z - size(x.Z,1), 1)]),paths,'UniformOutput',false);
                    end

                    %concat
                    AOs = [AOs{:}];
                    hasSlmOutputs = isfield(AOs,'SLM');
                    if hasSlmOutputs
                        SLM = [AOs.SLM];
                        AOs = rmfield(AOs,'SLM');
                    end

                    idxs = indices(obj.sequenceSelectedStimuli);
                    AOs = AOs(idxs);
                    ao = most.util.vertcatfields(AOs);
                    AOs = []; % release memory

                    if hasSlmOutputs
                        ao.SLM = SLM;
                        ao.SLMmaskIdxs = idxs;
                    end

                    paths = paths(indices(obj.sequenceSelectedStimuli));
                    path = most.util.vertcatfields([paths{:}]);
                    paths = []; % release memory

                    %multiple sequences
                    if obj.numSequences ~= inf
                        if obj.hasGalvos
                            ao.G = repmat(ao.G, obj.numSequences, 1);
                        end
                        if obj.hasBeams
                            ao.B = repmat(ao.B, obj.numSequences, 1);
                        end
                        if obj.hasZ
                            ao.Z = repmat(ao.Z, obj.numSequences, 1);
                        end
                    end

                case 'onDemand'
                    ao = [];
                    path = [];
                    for x = 1:numel(obj.stimRoiGroups)
                        g = obj.stimRoiGroups(x);
                        [ao_,~,~,path_] = g.scanStackAO(ss,0,0,'',0,[],[],[]);

                        if obj.hasBeams
                            assert(~isempty(path_.B), 'Error generating AO for Photostim pattern %d (''%s''). Pattern is empty.',x,g.name);
                            ao_.D = digitalSigs(path_.B);
                        else
                            assert(~isempty(path_.G), 'Error generating AO for Photostim pattern %d (''%s''). Pattern is empty.',x,g.name);
                            ao_.D = digitalSigs(path_.G);
                        end

                        ao = [ao, ao_]; %#ok<AGROW>
                        path = [path, path_];
                        pause(0); % ensure the AO generation does not block Matlab for too long
                    end

                    if obj.hasGalvos && obj.hasBeams
                        samplesPerTrigger = arrayfun(@(x)struct('D', size(x.B,1), 'G', size(x.G,1), 'B', size(x.B,1)),ao);
                    elseif obj.hasGalvos
                        samplesPerTrigger = arrayfun(@(x)struct('D', size(x.G,1), 'G', size(x.G,1)),ao);
                    else
                        samplesPerTrigger = arrayfun(@(x)struct('D', size(x.B,1), 'B', size(x.B,1)),ao);
                    end
                    if obj.hasZ
                        samplesPerTrigger = arrayfun(@(s,x)setfield(s,'Z', size(x.Z,1)),samplesPerTrigger,ao);
                    end
            end

            obj.stimAO = ao;
            obj.stimPath = path;

            function D = digitalSigs(beamPath,activeSamps)
                N = size(beamPath,1);
                %[stimActive laserActive SlmTrigger];
                D = [true(N,2) false(N,1)];

                if nargin > 1
                    D(activeSamps+1:end,1:2) = false;
                end

                % create laser active signal
                LA = sum(beamPath,2) > 0;

                % advance rising edges
                risingEdgeIdxs = find((LA(2:end) - LA(1:end-1)) > 0);
                for re = risingEdgeIdxs(:)'
                    LA(max(1,re-advSamps):re) = true;
                end

                D(:,2) = LA;
                D(end-1,3) = true; % trigger next SLM pattern at end of stimulus; some SLMs trigger on falling edge, so set second to last bit to true
                D(end,:) = false;
            end
        end
    end

    methods (Hidden)
        function clearOnDemandStatus(obj)
            if ~obj.isVdaq
                obj.hTaskArmedTrig.abort();
            end
            if obj.separateBeamDAQ
                obj.hTaskBeams.abort();
            end
            if ~obj.isVdaq && obj.separateZDAQ
                obj.hTaskZ.abort();
            end
            if obj.hasGalvos
                obj.hTaskGalvo.abort();
            end
            obj.status = 'Ready';
        end

        function taskDoneCallback(obj,~,~)
            if strcmp(obj.stimulusMode, 'onDemand')
                obj.clearOnDemandStatus();
                obj.hSI.hUserFunctions.notify('onDmdStimComplete');
            elseif obj.numSequences ~= inf
                obj.abort();
            end
        end

        function nSampleCallback(obj,~,~)
            if strcmp(obj.stimulusMode, 'sequence')
                if obj.sequencePosition == numel(obj.sequenceSelectedStimuli)
                    obj.completedSequences = obj.completedSequences + 1;
                    if obj.completedSequences >= obj.numSequences
                        obj.abort();
                        obj.hSI.hUserFunctions.notify('seqStimComplete');
                        return;
                    else
                        obj.sequencePosition = 1;
                        obj.hSI.hUserFunctions.notify('seqStimSingleComplete');
                    end
                else
                    obj.sequencePosition = obj.sequencePosition + 1;
                    obj.hSI.hUserFunctions.notify('seqStimAdvance');
                end

                obj.nextStimulus = obj.sequenceSelectedStimuli(obj.sequencePosition);
                obj.status = sprintf('Sequence #%d, position %d. Next stimulus: %d', obj.completedSequences + 1, obj.sequencePosition, obj.nextStimulus);
                if obj.hasSlm
                    if ~obj.slmQueueActive
                        idx = obj.stimAO.SLMmaskIdxs(obj.sequencePosition);
                        obj.hSlm.writePhaseMaskRaw(obj.stimAO.SLM(idx).mask.phase,false);
                    end
                    obj.currentSlmPattern = obj.stimPath.SLM(obj.sequencePosition).pattern;
                end
            elseif obj.allowMultipleOutputs
                obj.numOutputs = obj.numOutputs + 1;
                s = sprintf('%d time', obj.numOutputs);
                if obj.numOutputs > 1
                    s = [s 's'];
                end

                obj.hSI.hUserFunctions.notify('onDmdStimSingleComplete');
                obj.status = sprintf('Stimulus group %d output %s. Waiting for next trigger...', obj.primedStimulus, s);
            end
        end

        function nSampleCallbackMonitoring(obj,evt)
            data = evt.data;
            numElements = size(data,1);

            if (numElements == 0) || ~isempty(evt.errorMessage)
                obj.stopMonitoring();
                obj.monitoring = false;
                msg = 'Photostim monitoring did not receive the expected ammount of data. Logging has been aborted (if active) and monitoring disabled.';
                most.idioms.warn(msg);
                warndlg(msg);
                return
            end

            pathAI = data(:,1:2);
            if size(data,2) > 2
                beamAI = data(:,3);
                beamAI = obj.hBeams{1}.convertFeedbackVolt2PowerFraction(beamAI);
                beamAI(isnan(beamAI)) = 0;
            else
                beamAI = zeros(numElements,1,'single');
            end

            % transform to degrees
            pathAI(:,1) = obj.hScan.xGalvo.feedbackVolts2Position(pathAI(:,1));
            pathAI(:,2) = obj.hScan.yGalvo.feedbackVolts2Position(pathAI(:,2));

            pathFOV = scanimage.mroi.util.xformPoints(pathAI,obj.hScan.scannerToRefTransform);

            if obj.currentlyMonitoring
                obj.monitoringRingBuffer = circshift(obj.monitoringRingBuffer,-numElements);
                obj.monitoringRingBuffer(end-numElements+1:end,1:2) = pathFOV(:,1:2);
                obj.monitoringRingBuffer(end-numElements+1:end,3)   = beamAI(:,1);

                if isvalid(obj.hSI.hDisplay) && ~isempty(obj.hSI.hDisplay.hLinesPhotostimMonitor)
                    minColor = [0 0 1]; %blue
                    maxColor = [1 0 0]; %red

                    XY = obj.monitoringRingBuffer(:,1:2);
                    beamFraction = obj.monitoringRingBuffer(:,3);

                    color = zeros(length(beamFraction),3);
                    for colIdx = 1:3
                        color(:,colIdx) = beamFraction * (maxColor(colIdx) - minColor(colIdx)) + minColor(colIdx);
                    end
                    color(color>1) = 1;
                    color(color<0) = 0;

                    patchStruct = [];
                    if isempty(obj.currentSlmPattern)
                        patchStruct = addToPatch(XY,color,patchStruct);
                        markerC = color(end,:);

                        set([obj.hSI.hDisplay.hLinesPhotostimMonitor.endMarkerSlm],'Visible','off');
                    else
                        zeroOrderCol = [0 1 0];
                        markerC = zeroOrderCol;
                        patchStruct = addToPatch(XY,repmat(zeroOrderCol,size(XY,1),1),patchStruct);
                        for idx = 1:size(obj.currentSlmPattern,1)
                            patchStruct = addToPatch(bsxfun(@plus,XY,obj.currentSlmPattern(idx,1:2)),color,patchStruct);
                        end

                        set([obj.hSI.hDisplay.hLinesPhotostimMonitor.endMarkerSlm],...
                            'XData', XY(end,1) + obj.currentSlmPattern(:,1),...
                            'YData', XY(end,2) + obj.currentSlmPattern(:,2),...
                            'MarkerEdgeColor', color(end,:),...
                            'Visible', 'on');
                    end

                    set([obj.hSI.hDisplay.hLinesPhotostimMonitor.patch],...
                        'Faces', patchStruct.f,...
                        'Vertices', patchStruct.v,...
                        'FaceVertexCData', patchStruct.c,...
                        'Visible', 'on');

                    set([obj.hSI.hDisplay.hLinesPhotostimMonitor.endMarker],...
                        'XData' ,obj.monitoringRingBuffer(end,1),...
                        'YData' , obj.monitoringRingBuffer(end,2),...
                        'MarkerEdgeColor', markerC,...
                        'Visible', 'on');
                end
            end

            if obj.currentlyLogging
                % save as single to save space
                % data is interleaved: X,Y,Beams,X,Y,Beams,X,Y,Beams...
                data = [single(pathFOV),single(beamAI)]';
                fwrite(obj.hMonitoringFile,data(:),'single');
            end

            %%% Local function
            function patchStruct = addToPatch(XY,color,patchStruct)
                if nargin<3 || isempty(patchStruct)
                    patchStruct = struct('f',[],'v',[],'c',[]);
                end

                previousNumV = size(patchStruct.v,1);
                newNumV = size(XY,1);

                if isempty(patchStruct.v)
                    patchStruct.v = XY;
                    patchStruct.c = color;
                else
                    patchStruct.v = vertcat(patchStruct.v,XY);
                    patchStruct.c = vertcat(patchStruct.c,color);
                end

                f = zeros(1,2*newNumV);
                f(1:newNumV) = 1:newNumV;
                f(newNumV+1:end) = newNumV:-1:1;
                f = f + previousNumV;

                if isempty(patchStruct.f)
                    patchStruct.f = f;
                else
                    if size(patchStruct.f,2) < length(f)
                        patchStruct.f(:,end+1:length(f)) = NaN;
                    elseif length(f) < size(patchStruct.f,2)
                        f(end+1:size(patchStruct.f,2)) = NaN;
                    end

                    patchStruct.f = vertcat(patchStruct.f,f);
                end
            end
        end

        function extStimSelectionCB(obj,~,~)
            try
                data = obj.hTaskExtStimSelRead.readDigitalData();
                ind = find(data);
                if isempty(ind)
                    most.idioms.warn('External stimulus selection trigger came but no stimulus line was on. Ignoring.');
                elseif numel(ind) > 1
                    most.idioms.warn('External stimulus selection trigger came but multiple stimulus lines were on. Ignoring.');
                elseif ind > numel(obj.stimSelectionAssignment)
                    most.idioms.warn('No stimulus specified for PFI%d. Ignoring.', obj.stimSelectionTerms(ind));
                else
                    stm = obj.stimSelectionAssignment(ind);
                    fprintf('External stimulus selection trigger: stimulus %d\n', stm);
                    obj.hSI.hUserFunctions.notify('onDmdStimExtSel');
                    obj.onDemandStimNow(stm);
                end
            catch ME
                most.idioms.dispError('Error processing external on-demand stimulus trigger. Details:\n%s', ME.message);
            end
            obj.hTaskExtStimSel.abort();
            pause(0.1);
            obj.hTaskExtStimSel.start();
        end

        function startLogging(obj,sync)
            if nargin < 2 || isempty(sync)
                sync = true;
            end

            if obj.logging && obj.hSI.hChannels.loggingEnable
                obj.stopMonitoring();
                obj.prepareMonitoringFile();
                obj.currentlyLogging = true;
                obj.currentlyMonitoring = obj.monitoring;
                obj.startMonitoring(sync); %start logging
            end
        end

        function stopLogging(obj)
            if obj.currentlyLogging
                obj.currentlyLogging = false;
                obj.closeMonitoringFile();
                obj.stopMonitoring();
            end

            obj.monitoring = obj.monitoring;
        end

        function prepareMonitorTask(obj)
            most.idioms.safeDeleteObj(obj.hTaskMonitoring);

            galvoDAQ = obj.xGalvo.hAIFeedback.hDAQ;
            obj.hTaskMonitoring = dabs.vidrio.ddi.AiTask(galvoDAQ,'PhotostimMonitoringTask');

            obj.hTaskMonitoring.addChannel(obj.xGalvo.hAIFeedback,'PhotostimGalvoXMonitoring',obj.xGalvo.feedbackTermCfg);
            obj.hTaskMonitoring.addChannel(obj.yGalvo.hAIFeedback,'PhotostimGalvoYMonitoring',obj.yGalvo.feedbackTermCfg);

            if most.idioms.isValidObj(obj.BeamAiId)
                obj.hTaskMonitoring.addChannel(obj.BeamAiId,'PhotostimBeamMonitoring');
            elseif ~isempty(obj.hBeams)
                if most.idioms.isValidObj(obj.hBeams{1}.hAIFeedback) && isequal(obj.hBeams{1}.hAIFeedback.hDAQ,galvoDAQ)
                    obj.hTaskMonitoring.addChannel(obj.hBeams{1}.hAIFeedback,'PhotostimBeamMonitoring');
                end
            end

            obj.hTaskMonitoring.sampleMode = 'continuous';
            obj.hTaskMonitoring.sampleRate = obj.monitoringSampleRate;
            obj.hTaskMonitoring.bufferSize = max(ceil(obj.monitoringSampleRate*obj.monitoringBufferSizeSeconds),obj.monitoringEveryNSamples*4);
            obj.hTaskMonitoring.sampleCallback = @(src,evt)obj.nSampleCallbackMonitoring(evt);
            obj.hTaskMonitoring.sampleCallbackN = obj.monitoringEveryNSamples;
            obj.hTaskMonitoring.sampleCallbackAutoRead = true;
        end

        function prepareMonitoringFile(obj)
            filename = [obj.hSI.hScan2D.logFullFilename, sprintf('_%05d',obj.hSI.hScan2D.logFileCounter)];
            fileextension = '.stim';
            obj.hMonitoringFile = fopen([filename,fileextension],'W');
        end

        function closeMonitoringFile(obj)
            try
                fclose(obj.hMonitoringFile);
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
        end
    end

    %%% Abstract method implementation (scanimage.interfaces.Component)
    methods (Hidden, Access=protected)

        function componentStart(obj)
            %   Runs code that starts with the global acquisition-start command
            % NOTE: The default implementation of scanimage.interfaces.Component.start is overridden above. See the
            % comments there. This code should never be reached.
            assert(false, 'Bad call.');
        end

        function componentAbort(obj)
            %   Runs code that aborts with the global acquisition-abort command
            obj.abort();
        end
    end

    %% FRIEND EVENTS
    events (NotifyAccess = {?scanimage.interfaces.Class})
    end
end

%% LOCAL
function s = ziniInitPropAttributes()
s = struct();

s.stimTriggerTerm           = struct('Classes','numeric','Attributes',{{'nonzero' 'integer'}});
s.autoTriggerPeriod         = struct('Classes','numeric','Attributes',{{'scalar' 'nonnegative'}});
s.syncTriggerTerm           = struct('Classes','numeric','Attributes',{{'nonzero' 'integer'}},'AllowEmpty',true);
s.stimImmediately           = struct('Classes','binaryflex','Attributes',{{'scalar'}});
s.numSequences              = struct('Classes','numeric','Attributes',{{'positive' 'integer'}});
s.sequenceSelectedStimuli   = struct('Classes','numeric','Attributes',{{'vector' 'positive' 'integer' 'finite'}},'AllowEmpty',true);
s.stimSelectionTriggerTerm  = struct('Classes','numeric','Attributes',{{'positive' 'integer'}},'AllowEmpty',true);
s.stimSelectionTerms        = struct('Classes','numeric','Attributes',{{'vector' 'nonnegative' 'integer' 'finite'}},'AllowEmpty',true);
s.stimSelectionAssignment   = struct('Classes','numeric','Attributes',{{'vector' 'nonnegative' 'integer' 'finite'}},'AllowEmpty',true);
s.logging                   = struct('Classes','binaryflex','Attributes','scalar');
s.monitoring                = struct('Classes','binaryflex','Attributes','scalar');
end

function s = defaultMdfSection()
s = [...
    most.HasMachineDataFile.makeEntry('photostimScannerName','','Name of scanner (from first MDF section) to use for photostimulation. Must be a linear scanner')...
    most.HasMachineDataFile.makeEntry()... % blank line
    most.HasMachineDataFile.makeEntry('Monitoring DAQ AI channels')... % comment only
    most.HasMachineDataFile.makeEntry('BeamAiId',[],'AI channel to be used for monitoring the Pockels cell output')...
    most.HasMachineDataFile.makeEntry()... % blank line
    most.HasMachineDataFile.makeEntry('loggingStartTrigger','','PFI line to which start trigger for logging is wired to photostim board. Leave empty for automatic routing via PXI bus')...
    most.HasMachineDataFile.makeEntry()... % blank line
    most.HasMachineDataFile.makeEntry('stimActiveOutputChannel','','Digital terminal on stim board to output stim active signal. (e.g. on vDAQ: ''D2.6'' on NI-DAQ hardware: ''/port0/line0''')...
    most.HasMachineDataFile.makeEntry('beamActiveOutputChannel','','Digital terminal on stim board to output beam active signal. (e.g. on vDAQ: ''D2.7'' on NI-DAQ hardware: ''/port0/line1''')...
    most.HasMachineDataFile.makeEntry('slmTriggerOutputChannel','','Digital terminal on stim board to trigger SLM frame flip. (e.g. on vDAQ: ''D2.5'' on NI-DAQ hardware: ''/port0/line2''')...
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
