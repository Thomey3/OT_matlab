classdef DataRecorder < dabs.resources.Device & most.HasMachineDataFile & dabs.resources.configuration.HasConfigPage & dabs.resources.widget.HasWidget
    %% ABSTRACT PROPERTY REALIZATIONS 
    % most.HasMachineDataFile
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'DataRecorder';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
        
        mdfDefault = defaultMdfSection();
    end
    
    % HasConfigPage & HasWidget
    properties (SetAccess=protected)
        WidgetClass = 'dabs.resources.widget.widgets.DataRecorderWidget'; 
        ConfigPageClass = 'dabs.resources.configuration.resourcePages.DataRecorderPage';
    end
    
    % HasConfigPage
    methods (Static, Hidden)
        function names = getDescriptiveNames()
            names = {'Data Recorder'};
        end
    end
    
    %% PROPERTIES
    % MDF properties (user configuration)
    properties (SetObservable)
        % [DI resource] Data recorder digital signal trigger
        hTrigger = dabs.resources.Resource.empty();

        sampleRate;         % [Hz] Rate to sample
        sampleDuration;     % [s] Duration to sample
        fileBaseName;       % [char array] name of file
        fileDirectory;      % [char array] directory for file to be stored
        autoStart;          % [logical] whether to start/stop when scanimage starts/stops acquiring
        allowRetrigger;     % [logical] whether to retrigger after first trigger
        useTrigger;         % [logical] whether to use the currently configured trigger
        triggerEdge;        % ['rising' | 'falling'] what edge to use on the trigger
        useCompression;     % [logical] whether to compress the datafiles
        acquisitionNumber;  % [numeric] the current acquisition number
        chunkSize;          % [numeric] HDF5 chunk size
        deflateParam;       % [numeric] deflate parameter for compression

        % [ChannelConfiguration] Data recorder channel configuration
        configuration = dabs.generic.datarecorder.ChannelConfiguration.empty();
    end

    % listeners
    properties (SetAccess=private,Hidden)
        hUserFunctionsListener = event.listener.empty();
        hAcqListeners = event.listener.empty();
    end
    
    % HDF5 properties
    properties (Constant,Hidden)
        MAX_UNITS_LEN = 63;  % max number of characters in each dataset's units attribute
    end
    
    properties (SetObservable)
        datasetIDs = {};    % dataset handles
        fileID = [];        % file handle
    end
    
    properties (Dependent)
        currentFilename;    % filename with acquisition number
        currentFullname;    % filename with path
    end

    % Tasks
    properties (SetObservable)
        hAnalogTask;    % analog task handle
        hDigitalTask;   % digital task handle (not currently available)
    end

    properties (Dependent)
        % cell array of inputs for each task
        hAIs;
        hDIs;   % (not currently available)

        % other task properties
        maxSampleRate;  % max task sample rate
        running;        % whether the tasks are running
        hDAQ;           % the DAQ to run the tasks on
        bufferSize;     % the size of the task buffer
        isLongStart;    % whether or not it takes awhile to start the task
    end

    % task specific configuration properties that get set when configuration is set
    properties (SetAccess=private,Transient)
        analogConfiguration;    % analog specific configuration
        digitalConfiguration;   % digital specific configuration (not currently available)
    end

    properties (Transient,SetObservable,Hidden)
        sampleBuffer;               % the buffer that samples are stored on
        digitalSampleIndex = 0;     % the sampleBuffer index for the digital task (not currently available)
        analogSampleIndex = 0;      % the sampleBuffer index for the analog task

        lastDigitalSampleIndex = 0;
        lastAnalogSampleIndex = 0;  % the last index when the buffer is reset (for the viewer)
    end

    properties (Constant,Hidden)
        PREFERRED_LSADC_VER = 3;
        PREFERRED_DAC_VER = 3;
    end

    properties (Constant)
        SECONDS_TO_BUFFER = 5;       % maximum amount of seconds to buffer for large buffered tasks
        MAX_SAMPLES_TO_BUFFER = 5e6; % don't buffer more than 5 million samples
        CALLBACK_RATE = 15;          % [Hz] rate at which to process samples
        MAX_SAMPLE_RATE = 5e5;       % [Hz] max rate the data recorder can handle stably
        MIN_SAMPLE_RATE = 500;       % [Hz] observed min rate, don't go under because that tricks the callback to happen too fast
    end

    events (Hidden,NotifyAccess=private)
        redrawWidget;           % force a redraw call on the widget
    end

    %% CONSTRUCTOR/DESTRUCTOR
    methods
        function obj = DataRecorder(name)
            obj@dabs.resources.Device(name);
            obj@most.HasMachineDataFile(true);
            
            obj.deinit();
            obj.loadMdf();
            obj.reinit();
        end
        
        function delete(obj)
            obj.deinit();
        end
    end
    
    %% PROPERTY METHODS
    methods
        function set.hTrigger(obj,val)
            % deinits when set, so can be set while recording (stops recording)
            % this is because it must deal with being a registered user in the resource store

            if ischar(val)
                val = obj.hResourceStore.filterByName(val);
            end
            
            if ~isequal(val,obj.hTrigger)
                if most.idioms.isValidObj(val)
                    validateattributes(val,{'dabs.resources.ios.DI'},{'scalar'},'set.hTrigger','hTrigger');
                elseif ~isempty(val)
                    error('Unknown value for hTrigger');
                end
                
                if most.idioms.isValidObj(obj.hTrigger)
                    obj.hTrigger.unregisterUser(obj);
                end
                
                obj.hTrigger = val;
                
                if ~isempty(obj.hTrigger)
                    allowMultiple = true;
                    obj.hTrigger.registerUser(obj,'Trigger',allowMultiple); % allow multiple users
                end
                
                obj.reinit();
            end
        end
        
        function v = get.currentFilename(obj)
            v = sprintf('%s_%05d.h5',obj.fileBaseName,obj.acquisitionNumber);
        end
        
        function v = get.currentFullname(obj)
            v = fullfile(obj.fileDirectory,obj.currentFilename);
        end

        function v = get.running(obj)
            v = (~isempty(obj.hAnalogTask) && obj.hAnalogTask.active && ~obj.hAnalogTask.done)...
                || (~isempty(obj.hDigitalTask) && obj.hDigitalTask.active && ~obj.hDigitalTask.done);
        end

        function v = get.maxSampleRate(obj)
            v = realmax;
            if ~isempty(obj.hAnalogTask)
                v = min([v obj.hAnalogTask.maxSampleRate]);
            end
            if ~isempty(obj.hDigitalTask)
                v = min([v obj.hDigitalTask.maxSampleRate]);
            end
            if v ~= realmax
                v = min([v obj.MAX_SAMPLE_RATE]);
            end
            v = most.idioms.ifthenelse(v == realmax,0,v);
        end

        function set.sampleDuration(obj,v)
            % can be set while running, only used at task creation
            % will only update on the next recording

            validateattributes(v,{'numeric'},{'positive'},'set.sampleDuration','sampleDuration');

            if obj.running
                most.idioms.warn('Data recorder running: sampleDuration will be set, but only for the next recording.');
            end

            if isinf(v)
                obj.allowRetrigger = false;
            end

            obj.sampleDuration = v;
        end

        function set.configuration(obj,v)
            if obj.running
                error('Don''t change the configuration while the recorder is running!');
            end

            % unregister the old users
            arrayfun(@(cfg)cfg.hIO.unregisterUser(obj),obj.configuration);

            % set the new configuration
            obj.configuration = dabs.generic.datarecorder.ChannelConfiguration.fromTable(v);

            % set task specific configuration properties
            obj.analogConfiguration = dabs.generic.datarecorder.ChannelConfiguration.empty();
            obj.digitalConfiguration = dabs.generic.datarecorder.ChannelConfiguration.empty();
            for cfg = obj.configuration
                if most.idioms.isa(cfg.hIO,?dabs.resources.ios.AI)
                    obj.analogConfiguration(end+1) = cfg;
                    io_name = 'AI';
                else
                    obj.digitalConfiguration(end+1) = cfg;
                    io_name = 'DI';
                end

                allowMultiple = true;
                if ~isempty(cfg.name)
                    io_name = cfg.name;
                end

                cfg.hIO.registerUser(obj,io_name,allowMultiple);
            end

            obj.closeDatafile();
        end

        function v = get.hAIs(obj)
            if isempty(obj.analogConfiguration)
                v = {};
            else
                v = {obj.analogConfiguration.hIO};
            end
        end

        function v = get.hDIs(obj)
            if isempty(obj.digitalConfiguration)
                v = {};
            else
                v = {obj.digitalConfiguration.hIO};
            end
        end

        function v = get.hDAQ(obj)
            if ~isempty(obj.configuration)
                v = obj.configuration(1).hIO.hDAQ;
            else
                v = dabs.resources.Resource.empty();
            end
        end

        function v = get.bufferSize(obj)
            if ~isempty(obj.hAnalogTask)
                v = obj.hAnalogTask.bufferSize;
            elseif ~isempty(obj.hDigitalTask)
                v = obj.hDigitalTask.bufferSize;
            else
                v = 0;
            end
        end
        
        function set.useTrigger(obj,v)
            % can be set while running, only used at task creation
            % will only update on the next recording

            if isnumeric(v)
                v = logical(v);
            end

            validateattributes(v,{'logical'},{},'set.useTrigger','useTrigger');

            if obj.running
                most.idioms.warn('Data recorder running: useTrigger will be set, but only for the next recording.');
            end
            
            obj.useTrigger = v;
        end
        
        function set.allowRetrigger(obj,v)
            % can be set while running, only used at task creation
            % will only update on the next recording

            if isnumeric(v)
                v = logical(v);
            end

            validateattributes(v,{'logical'},{},'set.allowRetrigger','allowRetrigger');

            if obj.running
                most.idioms.warn('Data recorder running: allowRetrigger will be set, but only for the next recording.');
            end
            
            obj.allowRetrigger = v;
        end
        
        function set.triggerEdge(obj,v)
            % can be set while running, only used at task creation
            % will only update on the next recording

            validateattributes(v,{'char'},{},'set.triggerEdge','triggerEdge')
            assert(strcmp(v,'rising') || strcmp(v,'falling'),'Edge should be either ''rising'' or ''falling''');

            if obj.running
                most.idioms.warn('Data recorder running: triggerEdge will be set, but only for the next recording.');
            end

            obj.triggerEdge = v;
        end

        function set.acquisitionNumber(obj,v)
            % can be set while running, only used at file creation
            % will only update on the next recording

            validateattributes(v,{'numeric'},{'integer','nonnegative'},'set.acquisitionNumber','acquisitionNumber');

            if obj.running
                most.idioms.warn('Data recorder running: acquisitionNumber will be set, but only for the next recording.');
            end
            
            obj.acquisitionNumber = v;
        end

        function set.fileBaseName(obj,v)
            % can be set while running, only used at file creation
            % will only update on the next recording

            assert(ischar(v),'File must be a char array');

            if obj.running
                most.idioms.warn('Data recorder running: fileBaseName will be set, but only for the next recording.');
            end

            obj.fileBaseName = v;
        end

        function set.fileDirectory(obj,v)
            % can be set while running, only used at file creation
            % will only update on the next recording

            assert(ischar(v),'Directory must be a char array');

            if ~isempty(v)
                assert(exist(v,'dir')==7,'Directory must already be present on the system.\n"%s" is not a directory.',v);
            end

            if obj.running
                most.idioms.warn('Data recorder running: fileDirectory will be set, but only for the next recording.');
            end

            obj.fileDirectory = v;
        end

        function set.sampleRate(obj,v)
            % can be set while running, only used at task and file creation
            % will only update on the next recording

            validateattributes(v,{'numeric'},{'finite','real','nonnegative'},'set.sampleRate','sampleRate');
            assert(v>=3052,sprintf('Sample rate must be >= 3052Hz'));

            if obj.running
                most.idioms.warn('Data recorder running: sampleRate will be set, but only for the next recording.');
            end

            if obj.maxSampleRate > 0
                v = min([v obj.maxSampleRate]);
            end
            obj.sampleRate = max([v obj.MIN_SAMPLE_RATE]);
        end

        function v = get.isLongStart(obj)
            v = obj.bufferSize > 500e3;
        end

        function set.deflateParam(obj,v)
            % can be set while running, only used at file creation
            % will only update on the next recording

            validateattributes(v,{'numeric'},{'integer','>=',1,'<=',9},'set.deflateParam','deflateParam');

            if obj.running
                most.idioms.warn('Data recorder running: deflateParam will be set, but only for the next recording.');
            end

            obj.deflateParam = v;
        end

        function set.chunkSize(obj,v)
            if obj.running
                error('Dont''t change the chunkSize while the recorder is running!');
            end

            validateattributes(v,{'numeric'},{'integer','>=',1000,'<=',obj.MAX_SAMPLES_TO_BUFFER},'set.chunkSize','chunkSize');

            obj.chunkSize = v;
        end

        function set.hDigitalTask(obj,v)
            error('Digital task currently not supported');
        end
    end
    
    %% INIT METHODS
    methods
        function deinit(obj)
            obj.errorMsg = 'uninitialized';
            
            % stop recording
            obj.stop();

            % delete listeners
            most.idioms.safeDeleteObj(obj.hUserFunctionsListener);
            most.idioms.safeDeleteObj(obj.hAcqListeners);
        end
        
        function reinit(obj)
            obj.deinit();

            try
                % add listener for start/end of acquisition
                % (if not available, listens for when the component is available, then attaches proper listeners)
                obj.attachAcqStartNotification();
                if ~most.idioms.isValidObj(obj.hAcqListeners)
                    obj.hUserFunctionsListener = most.ErrorHandler.addCatchingListener(obj.hResourceStore,'hResources','PostSet',@obj.attachAcqStartNotification);
                end

                assert(~isempty(obj.configuration),'no channels specified');
                assert(~isempty(obj.fileBaseName),'filename not specified');
                assert(~isempty(obj.fileDirectory),'must have a logging directory specified ("Dir" button)');

                for cfg = obj.configuration
                    assert(obj.hDAQ == cfg.hIO.hDAQ,'must all be on the same daq');
                    assert(~isempty(cfg.name),'cannot have empty recorded names');
                end

                if ~isempty(obj.hTrigger)
                    assert(obj.hDAQ == obj.hTrigger.hDAQ);
                end
                
                hIOs = {obj.configuration.hIO};
                assert(all(cellfun(@(r)most.idioms.isa(r,?dabs.resources.ios.AI),hIOs)),'must be analog inputs');

                recordedNames = {obj.configuration.name};
                assert(numel(recordedNames) == numel(unique(recordedNames)), 'cannot have duplicate recorded names');

                if obj.useCompression
                    assert(logical(H5Z.filter_avail('H5Z_FILTER_DEFLATE')),'cannot compress files, gzip not available');
                    encodeEnabled = H5ML.get_constant_value('H5Z_FILTER_CONFIG_ENCODE_ENABLED');
                    decodeEnabled = H5ML.get_constant_value('H5Z_FILTER_CONFIG_DECODE_ENABLED');
                    filterInfo = H5Z.get_filter_info('H5Z_FILTER_DEFLATE');
                    assert(logical(bitand(filterInfo,encodeEnabled)),'cannot compress files, encoding not present');
                    assert(logical(bitand(filterInfo,decodeEnabled)),'cannot compress files, decoding not present');
                end

                obj.initTasks();
                obj.errorMsg = '';
            catch ME
                obj.deinit();
                obj.errorMsg = sprintf('%s: initialization error: %s',obj.name,ME.message);
                most.ErrorHandler.logError(ME,obj.errorMsg);
            end
        end

        function attachAcqStartNotification(obj,varargin)
            % do nothing if valid listeners already present
            if most.idioms.isValidObj(obj.hAcqListeners)
                return
            end

            % check for UserFunctions component availability
            hUserFunctions = obj.hResourceStore.filterByClass('scanimage.components.UserFunctions');
            if ~isempty(hUserFunctions)
                % wipe invalid listeners
                most.idioms.safeDeleteObj(obj.hAcqListeners);
                obj.hAcqListeners = event.listener.empty();

                % attach acqModeStart and acqAbort listeners
                obj.hAcqListeners(end+1) = most.ErrorHandler.addCatchingListener(hUserFunctions{1},'acqModeStart',@obj.startWithScanImageAcquisition);
                obj.hAcqListeners(end+1) = most.ErrorHandler.addCatchingListener(hUserFunctions{1},'acqAbort',@obj.stopWithScanImageAcquisition); % fires on abort and done

                % delete attaching listener
                most.idioms.safeDeleteObj(obj.hUserFunctionsListener);
            end
        end

        
    end

    %% Tasks
    methods
        function initTasks(obj)
            % cellarray so that multiple different task types can be supported
            tasks = {};

            % task specific configuration
            if ~isempty(obj.hAIs)
                obj.hAnalogTask = dabs.vidrio.ddi.AiTask(obj.hAIs{1}.hDAQ,sprintf('%s analog recorder',obj.name));
                obj.hAnalogTask.addChannels(obj.hAIs);
                obj.hAnalogTask.sampleCallback = @obj.nSampleCallbackAnalog;
                tasks{end+1} = obj.hAnalogTask;
            end
            
            if ~isempty(obj.hDIs)
                obj.hDigitalTask = dabs.vidrio.ddi.DiTask(obj.hDIs{1}.hDAQ,sprintf('%s digital recorder',obj.name));
                obj.hDigitalTask.addChannels(obj.hDIs);
                obj.hDigitalTask.sampleCallback = @obj.nSampleCallbackDigital;
                tasks{end+1} = obj.hDigitalTask;
            end
            
            % common task configuration
            for taskcell = tasks
                task = taskcell{1};
                task.sampleMode = most.idioms.ifthenelse(isinf(obj.sampleDuration),'continuous','finite');
                task.sampleRate = obj.sampleRate;
                task.allowRetrigger = obj.allowRetrigger;
                task.sampleCallbackAutoRead = false;
                task.doneCallback = @obj.done;

                if obj.useTrigger && ~isempty(obj.hTrigger)
                    task.startTrigger = obj.hTrigger.name;
                    task.startTriggerEdge = obj.triggerEdge;
                end
                
                if strcmp(task.sampleMode,'finite')
                    task.samplesPerTrigger = obj.sampleDuration * obj.sampleRate;
                end
                
                % make the callback happen at around a 15 Hz interval
                task.sampleCallbackN = ceil(obj.sampleRate / obj.CALLBACK_RATE);

                % buffer 5 seconds of samples in case GUIs take awhile to load
                % which sometimes blocks the callback from happening for awhile
                % (if the task buffer overflows, it's bad, but it can fill up 
                %  for 5 seconds without the callback)
                % don't buffer more than 5 million samples,
                % but store enough for the chunk size to match up
                task.bufferSize = min([obj.sampleRate*obj.SECONDS_TO_BUFFER obj.MAX_SAMPLES_TO_BUFFER]);
                task.bufferSize = max([task.bufferSize obj.chunkSize*1.5]);
            end
        end

        function nSampleCallbackDigital(obj,src,evt)
            error('Digital task currently not supported');
        end

        function nSampleCallbackAnalog(obj,varargin)
            try
                data = obj.hAnalogTask.readInputBuffer();
            catch ME
                most.ErrorHandler.logAndReportError(['Data Recorder task buffer overflowed due to lag in processing nSampleCallbackAnalog\n'...
                    'If auto start was enabled and this is the first acquisition, please try again']);
                obj.stop();
                return
            end

            [rows,cols] = size(data);
            assert(cols == numel(obj.analogConfiguration),'incorrect analog column count');

            % calculate buffer slice
            startIndex = obj.analogSampleIndex + 1;
            endIndex = obj.analogSampleIndex + rows;

            % set analog index to the end of the slice
            % must be done before setting sampleBuffer, DataRecorderView uses this property to access sampleBuffer
            obj.analogSampleIndex = endIndex;

            % store samples in the buffer
            for i = 1:cols
                sampleBufferColumn = obj.indexFromConfiguration(obj.analogConfiguration(i));
                sampleBufferIndex = sub2ind(size(obj.sampleBuffer),startIndex,sampleBufferColumn);
                convertedDataIndex = 1;
                numberOfElements = rows;

                convertedData = data(:,i).*obj.analogConfiguration(i).conversionMultiplier;

                try
                    most.memfunctions.inplacewrite(obj.sampleBuffer,convertedData,sampleBufferIndex,convertedDataIndex,numberOfElements);
                catch ME
                    obj.abort();
                    rethrow(ME);
                end
            end

            if endIndex >= obj.chunkSize
                obj.writeDatafile(endIndex);
                obj.lastDigitalSampleIndex = obj.digitalSampleIndex;
                obj.lastAnalogSampleIndex = obj.analogSampleIndex;
                obj.digitalSampleIndex = 0;
                obj.analogSampleIndex = 0;
            end
        end

        function idx = indexFromConfiguration(obj,cfg)
            for idx = 1:numel(obj.configuration)
                if strcmp(obj.configuration(idx).hIO.name,cfg.hIO.name)
                    return
                end
            end
        end

        function start(obj)
            % return if simulated
            hSI = obj.hResourceStore.filterByClass('scanimage.SI');
            if ~isempty(hSI) && hSI{1}.hScan2D.hAcq.hFpga.simulate
                most.ErrorHandler.logAndReportError(false,'Cannot run in simulated mode');
                return
            end

            % stop if already running
            if obj.running
                obj.stop();
            end

            % create the data file, but warn when overwriting the file
            try
                if exist(obj.currentFullname,'file')==2
                    answer = questdlg('This will overwrite the current file, are you sure?','Overwrite File?','Yes','Cancel','Cancel');
                    if strcmp(answer,'Cancel'); return; end
                end
                obj.createDatafile();
                
                % reset the sample buffer
                obj.sampleBuffer = zeros(obj.bufferSize,numel(obj.configuration),'single');
                obj.lastAnalogSampleIndex = 0;
                obj.analogSampleIndex = 0;
                
                obj.lastDigitalSampleIndex = 0;
                obj.digitalSampleIndex = 0;

                % reserve the input resources
                arrayfun(@(cfg)cfg.hIO.reserve(obj),obj.configuration);
                if most.idioms.isValidObj(obj.hTrigger)
                    obj.hTrigger.reserve(obj);
                end

                % start the tasks
                if ~isempty(obj.hAnalogTask)
                    obj.hAnalogTask.start();
                end

                if ~isempty(obj.hDigitalTask)
                    obj.hDigitalTask.start();
                end
            catch ME
                most.ErrorHandler.logAndReportError(ME);
                obj.deinit();
                obj.errorMsg = ME.message;
            end

            % redraw the widget
            notify(obj,'redrawWidget');
        end
        
        function abort(obj)
            % abort the tasks and unreserve resources
            try
                if ~isempty(obj.hAnalogTask)
                    obj.hAnalogTask.abort();
                end

                if ~isempty(obj.hDigitalTask)
                    obj.hDigitalTask.abort();
                end

                % unreserve the input resources
                arrayfun(@(cfg)cfg.hIO.unreserve(obj),obj.configuration);
                if most.idioms.isValidObj(obj.hTrigger)
                    obj.hTrigger.unreserve(obj);
                end
            catch ME
                most.ErrorHandler.logAndReportError(ME);
                % deinit calls abort so don't call deinit here
                obj.errorMsg = ME.message;
            end

            % redraw the widget
            notify(obj,'redrawWidget');
        end

        function stop(obj)
            % stop = abort and done
            wasRunning = obj.running;
            obj.abort();

            % only close the file if not running,
            % to not increment the acquisition number
            if wasRunning
                obj.done();
            else
                obj.closeDatafile();
            end
        end

        function done(obj, varargin)
            try
                % read leftover samples into buffers if there are any available
                if obj.hAnalogTask.getNumAvailableSamps() > 0
                    obj.nSampleCallbackAnalog();
                end

                % if obj.hDigitalTask.getNumAvailableSamps() > 0
                %     obj.nSampleCallbackDigital();
                % end

                % write out any samples that haven't been written yet, then close
                currentIndex = max([obj.digitalSampleIndex obj.analogSampleIndex]);
                if currentIndex > 0
                    obj.writeDatafile(currentIndex);
                end
                obj.closeDatafile();

                % increment acquisition number for next recording
                obj.acquisitionNumber = obj.acquisitionNumber + 1;
            catch ME
                most.ErrorHandler.logAndReportError(ME);
                obj.deinit();
                obj.errorMsg = ME.message;
            end
        end

        function startWithScanImageAcquisition(obj,varargin)
            if obj.autoStart
                obj.start();
            end
        end

        function stopWithScanImageAcquisition(obj,varargin)
            if obj.autoStart
                obj.stop();
            end
        end
    end
    
    %% MDF METHODS
    methods
        function loadMdf(obj)
            success = true;
            success = success & obj.safeSetPropFromMdf('hTrigger', 'recordingTrigger');
            success = success & obj.safeSetPropFromMdf('sampleRate', 'sampleRate_Hz');
            success = success & obj.safeSetPropFromMdf('sampleDuration', 'sampleDuration_s');
            success = success & obj.safeSetPropFromMdf('fileBaseName', 'fileBaseName');
            success = success & obj.safeSetPropFromMdf('fileDirectory', 'fileDirectory');
            success = success & obj.safeSetPropFromMdf('autoStart', 'autoStart');
            success = success & obj.safeSetPropFromMdf('allowRetrigger', 'allowRetrigger');
            success = success & obj.safeSetPropFromMdf('useTrigger', 'useTrigger');
            success = success & obj.safeSetPropFromMdf('useCompression', 'useCompression');
            success = success & obj.safeSetPropFromMdf('triggerEdge', 'triggerEdge');
            success = success & obj.safeSetPropFromMdf('configuration','configurationTable');
            success = success & obj.safeSetPropFromMdf('chunkSize','chunkSize');
            success = success & obj.safeSetPropFromMdf('deflateParam','deflateParam');
            
            if ~success
                obj.deinit();
                obj.errorMsg = 'Error loading config';
            end
        end
        
        function saveMdf(obj)
            obj.safeWriteVarToHeading('recordingTrigger', obj.hTrigger);
            obj.safeWriteVarToHeading('sampleRate_Hz', obj.sampleRate);
            obj.safeWriteVarToHeading('sampleDuration_s', obj.sampleDuration);
            obj.safeWriteVarToHeading('fileBaseName', obj.fileBaseName);
            obj.safeWriteVarToHeading('fileDirectory', obj.fileDirectory);
            obj.safeWriteVarToHeading('autoStart', obj.autoStart);
            obj.safeWriteVarToHeading('allowRetrigger', obj.allowRetrigger);
            obj.safeWriteVarToHeading('useTrigger', obj.useTrigger);
            obj.safeWriteVarToHeading('useCompression', obj.useCompression);
            obj.safeWriteVarToHeading('triggerEdge', obj.triggerEdge);
            obj.safeWriteVarToHeading('configurationTable', obj.configuration.toTable());
            obj.safeWriteVarToHeading('chunkSize', obj.chunkSize);
            obj.safeWriteVarToHeading('deflateParam', obj.deflateParam);
        end
    end

    %% HDF5 METHODS
    methods
        function createDatafile(obj)
            % close datafile if it's already open
            obj.closeDatafile();

            % create new file with rd/wr access, overwriting old file
            obj.fileID = H5F.create(obj.currentFullname,'H5F_ACC_TRUNC','H5P_DEFAULT','H5P_DEFAULT');
            
            % unlimited dimension length
            H5S_UNLIMITED = H5ML.get_constant_value('H5S_UNLIMITED');
            
            % create units attribute type
            unitsType = H5T.copy('H5T_FORTRAN_S1');
            H5T.set_size(unitsType, obj.MAX_UNITS_LEN);
            unitsMemType = H5T.copy('H5T_C_S1');
            H5T.set_size(unitsMemType, obj.MAX_UNITS_LEN);

            % create dataset creation params with chunking and compression
            createParams = H5P.create('H5P_DATASET_CREATE');
            H5P.set_chunk(createParams,obj.chunkSize);
            if obj.useCompression
                H5P.set_deflate(createParams,obj.deflateParam);
            end
            
            for i = 1:numel(obj.configuration)
                % create dataspace with chunking
                space = H5S.create_simple(1, 0, H5S_UNLIMITED);
                dataset = H5D.create(obj.fileID,obj.configuration(i).name,'H5T_NATIVE_FLOAT',space,createParams);
                obj.datasetIDs{i} = dataset;
                
                % create units attribute
                unitsSpace = H5S.create('H5S_SCALAR');
                unitsAttr = H5A.create(dataset,'units',unitsType,unitsSpace,'H5P_DEFAULT');
                H5A.write(unitsAttr,unitsMemType,obj.configuration(i).unitFull');

                % create conversion factor attribute
                conversionMultiplierSpace = H5S.create('H5S_SCALAR');
                conversionMultiplierAttr = H5A.create(dataset,'conversionMultiplier','H5T_NATIVE_FLOAT',conversionMultiplierSpace,'H5P_DEFAULT');
                H5A.write(conversionMultiplierAttr,'H5ML_DEFAULT',obj.configuration(i).conversionMultiplier)
                
                % close attributes, only used at file creation
                H5A.close(unitsAttr);
                H5A.close(conversionMultiplierAttr);
                H5S.close(unitsSpace);
                H5S.close(conversionMultiplierSpace);

                % close dataspace because we have to get a new space anyways each time the dataset is extended
                H5S.close(space);
            end
            
            % create sample rate attribute
            sampleRateSpace = H5S.create('H5S_SCALAR');
            sampleRateAttr = H5A.create(obj.fileID,'samplerate','H5T_NATIVE_DOUBLE',sampleRateSpace,'H5P_DEFAULT');
            H5A.write(sampleRateAttr,'H5ML_DEFAULT',obj.sampleRate);
            
            % close attributes types and creation params, only used at file creation
            H5A.close(sampleRateAttr);
            H5S.close(sampleRateSpace);
            H5T.close(unitsType);
            H5T.close(unitsMemType);
            H5P.close(createParams);
        end

        function writeDatafile(obj,len)
            % file is usually created before this
            if isempty(obj.fileID)
                most.idioms.warn(sprintf('Data Recorder file ID not found, creating datafile.\nThis may overwrite an existing file.'));
                obj.createDatafile();
            end
            
            % write the sample buffer to the file 
            % (sample buffer is already in order of datasetIDs)
            for i = 1:size(obj.sampleBuffer,2)
                dataset = obj.datasetIDs{i};
                space = H5D.get_space(dataset);
                start = H5S.get_simple_extent_npoints(space);  % current elements in dataset
                H5D.extend(dataset,start+len);         % extend by current sample buffer
                H5S.close(space);                      % the old space doesn't have the extension

                space = H5D.get_space(dataset);        % actual dataset dataspace
                mspace = H5S.create_simple(1,len,[]);  % memory space for the data being written to the extension
                H5S.select_hyperslab(space,'H5S_SELECT_SET',start,[],len,[]);  % select only the extension in the dataspace
                H5D.write(dataset,'H5T_NATIVE_FLOAT',mspace,space,'H5P_DEFAULT',obj.sampleBuffer(1:len,i));
                H5S.close(space);
                H5S.close(mspace);
            end
        end

        function readDatafile(obj)
            % reads chunks of data from the current file for offline viewing purposes
            % TODO
        end

        function closeDatafile(obj)
            if ~isempty(obj.fileID)
                for i = 1:numel(obj.datasetIDs)
                    if ~isempty(obj.datasetIDs{i})
                        H5D.close(obj.datasetIDs{i});
                    end
                end
                H5F.close(obj.fileID);

                obj.fileID = [];
                obj.datasetIDs = cell(1,numel(obj.configuration));
            end
        end
    end
end

function s = defaultMdfSection()
s = [...
    most.HasMachineDataFile.makeEntry('Channel configuration')...
    most.HasMachineDataFile.makeEntry('configurationTable',{{}})...
    most.HasMachineDataFile.makeEntry()... % blank line
    most.HasMachineDataFile.makeEntry('Data recorder controls')...
    most.HasMachineDataFile.makeEntry('sampleRate_Hz',5000,'Rate (hz) to capture analog signals')...
    most.HasMachineDataFile.makeEntry('sampleDuration_s',Inf,'Duration (s) to capture analog signals')...
    most.HasMachineDataFile.makeEntry('fileBaseName','','Base name of the file saved')...
    most.HasMachineDataFile.makeEntry('fileDirectory','','Directory to store the saved files')...
    most.HasMachineDataFile.makeEntry('autoStart',false,'Start recorder when GRAB acquisitions are initiated')...
    most.HasMachineDataFile.makeEntry('recordingTrigger',[],'Name of the input trigger to start recording data (e.g. /vDAQ0/D1.0)')...
    most.HasMachineDataFile.makeEntry('useTrigger',true,'Whether to use software or hardware trigger')...
    most.HasMachineDataFile.makeEntry('allowRetrigger',false,'Whether to retrigger if the signal trigger happens again after the first trigger')...
    most.HasMachineDataFile.makeEntry('useCompression',false,'Whether to use compression when storing the HDF5 file')...
    most.HasMachineDataFile.makeEntry()... % blank line
    most.HasMachineDataFile.makeEntry('Advanced controls')...
    most.HasMachineDataFile.makeEntry('triggerEdge','rising','What edge to trigger on for hardware trigger')...
    most.HasMachineDataFile.makeEntry('chunkSize',50000,'Data recorder output file chunk size')...
    most.HasMachineDataFile.makeEntry('deflateParam',5,'Deflate parameter for compression')...
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
