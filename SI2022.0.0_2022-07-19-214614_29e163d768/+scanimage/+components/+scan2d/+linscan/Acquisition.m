classdef Acquisition < scanimage.interfaces.Class
    %% Class specific properties            
    %     properties (Dependent)
    %         channelsInputRanges;                    % [V] 1D cell array of [min max] input ranges for each channel
    %     end
    
    properties
        startTrigIn = '';
        startTrigEdge = 'rising';
        
        disableFpgaAveraging = false;
        disableMatlabAveraging = false;
        
        hFpga;
        fpgaSampleClockMode;
        
        MAX_NUM_STRIPES = 30;
    end
    
    %% Internal properties
    properties (SetAccess = immutable)
        hLinScan;            					% handle of hLinScan
    end
    
    properties (Constant)
        ACQ_BUFFER_SIZE = 30;                   % size of the AI input buffer in stripes
    end
    
    properties (SetAccess = private)
        hAI;                                    % handle of data stream object that abstracts communication between AI Task or FPGA for digitizing light input during scan, e.g. a PMT signal
        hAIFdbk;                                % handle of data stream object that abstracts communication between AI Task or FPGA for digitizing light input during scan, e.g. a PMT signal
        hAIFdbkZ;
        stripeCounterFdbk = 0;                      % total number of stripes acquired
        stripeCounter = 0;                      % total number of stripes acquired
        frameCounter = 0;                       % total number of frames acquired
        everyNSamples;                          % zzSamplesAcquiredFcn is called every N samples
        acqParamBuffer = struct();              % buffer holding frequently used parameters to limit parameter recomputation
        sampleBuffer = scanimage.components.scan2d.linscan.SampleBuffer(); % buffer holding samples for stripes
        acqDevType;
        endOfAcquisition = false;
        useFpgaOffset = false;
        isLineScan = false;
        is3dLineScan = false;
        rec3dPath = false;
        zFdbkShareDaq = false;
        zFdbkEn = false;
        zScannerId;
        hZLSC;
        
        fpgaLoopRate;
    end
    
    properties (Dependent, SetAccess = private)
        active;                                 % (logical) ndicates if the current task is active
    end
    
    %% Lifecycle
    methods
        function obj = Acquisition(hLinScan)
            obj.hLinScan = hLinScan;
        end
        
        function delete(obj)
            obj.deinit();
        end
        
        function deinit(obj)
            most.idioms.safeDeleteObj(obj.hAI);
            most.idioms.safeDeleteObj(obj.hAIFdbk);
            most.idioms.safeDeleteObj(obj.hAIFdbkZ);
        end
        
        function reinit(obj)
            obj.deinit();
            obj.ziniPrepareTasks();
        end
    end
    
    %% Public Methods
    methods
        function start(obj)
            obj.assertNotActive('method:start');
            obj.bufferAcqParams();
            
            % reset counters
            obj.stripeCounterFdbk = 0;
            obj.stripeCounter = 0;
            obj.frameCounter = 0;
            obj.endOfAcquisition = false;
            
            if ~isempty(obj.hFpga) && obj.hLinScan.externalSampleClock
                obj.hFpga.measureExternalRawSampleClockRate();
            end
            
            % configure AI task for acquisition
            obj.zzConfigSampModeAndSampPerChan();
            obj.zzConfigInputEveryNAndBuffering();
            obj.sampleBuffer.initialize(obj.acqParamBuffer.samplesPerFrame,obj.hAI.getNumAvailChans,obj.hLinScan.channelsDataType);
            
            if obj.isLineScan && obj.hLinScan.recordScannerFeedback
                obj.hAIFdbk.start();
                
                if obj.rec3dPath && ~obj.zFdbkShareDaq
                    obj.hAIFdbkZ.start();
                end
            end
            
            if strcmp(obj.hLinScan.hAcq.hAI.streamMode,'fpga')
                obj.hFpga.LinScanDivertSamples = obj.hLinScan.laserTriggerSampleMaskEnable;
                obj.hFpga.ResScanFilterSamples = false;
                obj.hFpga.LaserTriggerDelay = obj.hLinScan.laserTriggerSampleWindow(1);
                obj.hFpga.LaserSampleWindowSize = obj.hLinScan.laserTriggerSampleWindow(2);
                obj.hFpga.LaserTriggerFilterTicks = obj.hLinScan.laserTriggerDebounceTicks;
            end
            
            obj.hAI.start();
        end
        
        function updateBufferedPhaseSamples(obj)
            obj.acqParamBuffer.linePhaseSamples = round(obj.hLinScan.linePhase * obj.hLinScan.sampleRate); % round to avoid floating point accuracy issue
        end
        
        function updateBufferedOffsets(obj)
            if ~isempty(obj.acqParamBuffer)
                if ~obj.useFpgaOffset
                    tmpValA = cast(obj.hLinScan.hSI.hChannels.channelOffset(obj.acqParamBuffer.channelsActive),obj.hLinScan.channelsDataType);
                    tmpValB = cast(obj.hLinScan.hSI.hChannels.channelSubtractOffset(obj.acqParamBuffer.channelsActive),obj.hLinScan.channelsDataType);
                    channelsOffset = tmpValA .* tmpValB;
                    obj.acqParamBuffer.channelsOffset = channelsOffset;
                else
                    N = numel(obj.hLinScan.hSI.hChannels.channelOffset);
                    obj.acqParamBuffer.channelsOffset = zeros(1,numel(obj.acqParamBuffer.channelsActive),obj.hLinScan.channelsDataType);
                    channelsOffset_FPGA = double(obj.hLinScan.hSI.hChannels.channelOffset) .* double(obj.hLinScan.hSI.hChannels.channelSubtractOffset);
                    obj.hFpga.AcqParamLiveChannelOffsets(1:N) = -channelsOffset_FPGA;
                    obj.hFpga.MaskDisableAveraging = repmat(obj.disableFpgaAveraging,size(obj.hFpga.MaskDisableAveraging));
                end
            end
        end
        
        function clearAcqParamBuffer(obj)
            obj.acqParamBuffer = struct();
        end
        
        function zs = bufferAllSfParams(obj)
            roiGroup = obj.hLinScan.currentRoiGroup;
            scannerset=obj.hLinScan.scannerset;
            
            obj.isLineScan = obj.hLinScan.hSI.hRoiManager.isLineScan;
            
            if obj.isLineScan
                zs = 0;
            else
                % generate slices to scan based on motor position etc
                zs = obj.hLinScan.hSI.hStackManager.zs;
                obj.acqParamBuffer.zs = zs;
                
                uniqueZs = unique(zs);
                [uniqueScanFields,uniqueRois] = arrayfun(@(z)roiGroup.scanFieldsAtZ(z),uniqueZs,'Uniformoutput',false);
                
                for idx = numel(zs) : -1 : 1
                    z = zs(idx);
                    zmask = z==uniqueZs;
                    scanFields{idx} = uniqueScanFields{zmask};
                    rois{idx} = uniqueRois{zmask};
                    
                    [lineScanPeriods, lineAcqPeriods] = cellfun(@(sf)scannerset.linePeriod(sf),scanFields{idx},'UniformOutput', false);
                    
                    obj.acqParamBuffer.scanFieldParams{idx} = cellfun(@(sf,lsp,lap)...
                        struct('lineScanSamples',round(lsp * obj.hLinScan.sampleRate),...
                        'lineAcqSamples',round(lap * obj.hLinScan.sampleRate),...
                        'pixelResolution',sf.pixelResolution),...
                        scanFields{idx},lineScanPeriods,lineAcqPeriods);
                end
                obj.acqParamBuffer.rois = rois;
                obj.acqParamBuffer.scanFields = scanFields;
            end
        end
        
        function bufferAcqParams(obj,live,keepOld)
            if (nargin < 2 || isempty(live) || ~live) && (nargin < 3 || isempty(keepOld) || ~keepOld)
                obj.acqParamBuffer = struct(); % flush buffer
            end
            
            roiGroup = obj.hLinScan.currentRoiGroup;
            scannerset=obj.hLinScan.scannerset;
            
            if nargin < 2 || isempty(live) || ~live
                lclChannelsActive = obj.hLinScan.hSI.hChannels.channelsActive;
                obj.acqParamBuffer.channelsActive = lclChannelsActive;
                if obj.useFpgaOffset
                    % inversion is handled on FPGA
                    obj.acqParamBuffer.channelsSign = cast(ones(numel(lclChannelsActive),1),obj.hLinScan.channelsDataType);
                    obj.hAI.fpgaInvertChannels = obj.hLinScan.channelsInvert;
                else
                    % -1 for obj.channelsInvert == true, 1 for obj.channelsInvert == false
                    obj.acqParamBuffer.channelsSign = cast(1 - 2*obj.hLinScan.channelsInvert(lclChannelsActive),obj.hLinScan.channelsDataType);
                end
                obj.updateBufferedOffsets();
            end
            
            zs = obj.bufferAllSfParams();
            
            if obj.isLineScan
                obj.acqParamBuffer.frameTime = obj.hLinScan.hSI.hRoiManager.scanFramePeriod;
                obj.acqParamBuffer.samplesPerFrame = round(obj.acqParamBuffer.frameTime * obj.hLinScan.sampleRate);
                
                if obj.hLinScan.recordScannerFeedback
                    assert(obj.hLinScan.xGalvo.feedbackCalibrated && obj.hLinScan.yGalvo.feedbackCalibrated,'Galvo feedback sensors are uncalibrated.');
                    obj.hLinScan.sampleRateFdbk = [];
                    obj.acqParamBuffer.fdbkSamplesPerFrame = round(obj.hLinScan.sampleRateFdbk * obj.acqParamBuffer.frameTime)-5;
                    if obj.rec3dPath
                        for idx = 1:numel(obj.hLinScan.hFastZs)
                            hFastZ = obj.hLinScan.hFastZs{idx};
                            assert(hFastZ.feedbackAvailable,'%s: Z feedback sensor is uncalibrated',hFastZ.name);
                        end
                    end
                end
            else
                if nargin < 2 || isempty(live) || ~live
                    fbZs = obj.hLinScan.hSI.hFastZ.numDiscardFlybackFrames;
                    times = arrayfun(@(z)roiGroup.sliceTime(scannerset,z),zs);
                    obj.acqParamBuffer.frameTime  = max(times);
                    obj.acqParamBuffer.samplesPerFrame = round(obj.acqParamBuffer.frameTime * obj.hLinScan.sampleRate);
                    
                    [startSamples,endSamples] = arrayfun(@(z)roiSamplePositions(roiGroup,scannerset,z),zs,'UniformOutput',false);
                    
                    obj.acqParamBuffer.startSamples = startSamples;
                    obj.acqParamBuffer.endSamples   = endSamples;
                    
                    obj.acqParamBuffer.scannerset = scannerset;
                    obj.acqParamBuffer.flybackFramesPerStack = fbZs;
                    obj.acqParamBuffer.numSlices  = numel(zs);
                    obj.acqParamBuffer.roiGroup = roiGroup;
                    
                    obj.updateBufferedPhaseSamples();
                end
            end
            
            function [startSamples, endSamples] = roiSamplePositions(roiGroup,scannerset,z)
                % for each roi at z, determine the start and end time
                transitTimes = reshape(roiGroup.transitTimes(scannerset,z),1,[]); % ensure these are row vectors
                scanTimes    = reshape(roiGroup.scanTimes(scannerset,z),1,[]);
                
                % timeStep = 1/scannerset.sampleRateHz;
                times = reshape([transitTimes;scanTimes],1,[]); % interleave transit Times and scanTimes
                times = cumsum(times);  % cumulative sum of times
                times = reshape(times,2,[]);    % reshape to separate start and stop time vectors
                startTimes = times(1,:);
                endTimes   = times(2,:);
                
                startSamples = arrayfun(@(x)(round(x * obj.hLinScan.sampleRate) + 1), startTimes); % increment because Matlab indexing is 1-based
                endSamples   = arrayfun(@(x)(round(x * obj.hLinScan.sampleRate)),endTimes );
            end
        end
        
        function restart(obj)
            % reset counters
            obj.stripeCounterFdbk = 0;
            obj.stripeCounter = 0;
            obj.frameCounter = 0;
            obj.endOfAcquisition = false;
            
            obj.assertNotActive('method:restart');
            
            % TODO: should the acquisition buffer be flushed here?
            if obj.isLineScan && obj.hLinScan.recordScannerFeedback
                obj.hAIFdbk.start();
                
                if obj.rec3dPath && ~obj.zFdbkShareDaq
                    obj.hAIFdbkZ.start();
                end
            end
            
            obj.hAI.start();
        end
        
        function abort(obj,tfUnreserve)
            try
                obj.hAI.abort();
                obj.hAIFdbk.abort();
                obj.hAIFdbkZ.abort();
                
                if tfUnreserve
                    obj.hAI.unreserve();
                    obj.hAIFdbk.control('DAQmx_Val_Task_Unreserve');
                    obj.hAIFdbkZ.control('DAQmx_Val_Task_Unreserve');
                end
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
        end
        
        function data = acquireSamples(obj,numSamples)
            obj.assertNotActive('acquireSamples');
            data = obj.hAI.acquireSamples(numSamples);
                    
            obj.hLinScan.channelsInvert = obj.hLinScan.channelsInvert; % enforce correct number of entries in array
            channelsSign = 1 - 2*obj.hLinScan.channelsInvert; % -1 for obj.channelsInvert == true, 1 for obj.channelsInvert == false
            for chan = 1:size(data,2)
                data(:,chan) = data(:,chan) * channelsSign(chan);     % invert channels
            end
        end
    end
    
    %% Friendly Methods
    methods (Hidden)
        function ziniPrepareFeedbackTasks(obj)
            if ~obj.hLinScan.xGalvo.feedbackAvailable || ~obj.hLinScan.yGalvo.feedbackAvailable
                 return
            end
            
            assert(isequal(obj.hLinScan.xGalvo.hAIFeedback.hDAQ,obj.hLinScan.yGalvo.hAIFeedback.hDAQ)...
                ,'xGalvo feedback and yGalvo feedback must be on same daq board');
            
            obj.hAIFdbk.createAIVoltageChan(obj.hLinScan.xGalvo.hAIFeedback.hDAQ.name,obj.hLinScan.xGalvo.hAIFeedback.channelID,'x-Feedback',[],[],[],[],obj.hLinScan.xGalvo.hAIFeedback.termCfg);
            obj.hAIFdbk.createAIVoltageChan(obj.hLinScan.yGalvo.hAIFeedback.hDAQ.name,obj.hLinScan.yGalvo.hAIFeedback.channelID,'y-Feedback',[],[],[],[],obj.hLinScan.yGalvo.hAIFeedback.termCfg);
            
            % this is rather intrusive into the internals of fast z so
            % could easily break if that code changes
            
            
            obj.zFdbkEn = ~isempty(obj.hLinScan.hFastZs);
            for idx = 1:numel(obj.hLinScan.hFastZs)
                obj.zFdbkEn = obj.zFdbkEn && ~isempty(obj.hLinScan.hFastZs{idx}.hAIFeedback);
            end
            
            if obj.zFdbkEn
                obj.zFdbkShareDaq = strcmp(obj.hLinScan.xGalvo.hAIFeedback.hDAQ.name,obj.hLinScan.hFastZs{1}.hAIFeedback.hDAQ.name);
                
                if obj.zFdbkShareDaq
                    for idx = 1:numel(obj.hLinScan.hFastZs)
                        daqName = obj.hLinScan.hFastZs{idx}.hAIFeedback.hDAQ.name;
                        chID = obj.hLinScan.hFastZs{idx}.hAIFeedback.channelID;
                        obj.hAIFdbk.createAIVoltageChan(daqName,chID);
                    end
                else
                    for idx = 1:numel(obj.hLinScan.hFastZs)
                        daqName = obj.hLinScan.hFastZs{idx}.hAIFeedback.hDAQ.name;
                        chID = obj.hLinScan.hFastZs{idx}.hAIFeedback.channelID;
                        obj.hAIFdbkZ.createAIVoltageChan(daqName,chID);
                    end
                    
                    obj.hAIFdbkZ.cfgSampClkTiming(obj.hLinScan.sampleRateFdbk, 'DAQmx_Val_FiniteSamps', 2);
                    obj.hAIFdbkZ.cfgDigEdgeStartTrig(obj.hLinScan.hTrig.frameClockTermInt,'DAQmx_Val_Rising');
                    obj.hAIFdbkZ.set('startTrigRetriggerable',1);
                    try
                        obj.hAIFdbkZ.control('DAQmx_Val_Task_Verify');
                        obj.hAIFdbkZ.control('DAQmx_Val_Task_Unreserve');
                    catch
                        obj.zFdbkEn = false;
                    end
                end
            end
            
            obj.hAIFdbk.cfgSampClkTiming(obj.hLinScan.sampleRateFdbk, 'DAQmx_Val_FiniteSamps', 2);
            obj.hAIFdbk.everyNSamplesReadDataEnable = true;
            obj.hAIFdbk.cfgDigEdgeStartTrig('PFI0','DAQmx_Val_Rising');
            obj.hAIFdbk.set('startTrigRetriggerable',1);
            obj.hAIFdbk.everyNSamplesEventCallbacks = @(~,evnt)obj.zzFdbckSamplesAcquiredFcn(evnt.data,evnt.errorMessage);
            
            function cfg = daqMxTermCfgString(str)
                if length(str) > 4
                    str = str(1:4);
                end
                cfg = ['DAQmx_Val_' str];
            end
        end
    end
    
    %% Private Methods
    methods (Access = private)
        function ziniPrepareTasks(obj)
            %Initialize hAI object
            hDAQAcq = obj.hLinScan.hDAQAcq;
            if isa(hDAQAcq,'dabs.resources.daqs.NIRIO')
                %this is a flexrio fpga!
                obj.useFpgaOffset = true;
                obj.hAI = scanimage.components.scan2d.linscan.DataStream('fpga');
                obj.hAI.simulated = obj.hLinScan.simulated;
                
                if obj.hLinScan.mdfData.secondaryFpgaFifo
                    fifoName = 'fifo_LinScanMultiChannelToHostU64';
                else
                    fifoName = 'fifo_MultiChannelToHostU64';
                end
                
                % Determine bitfile parameters 
                if most.idioms.isValidObj(hDAQAcq.hFpga)
                    obj.hFpga = hDAQAcq.hFpga;
                else
                    obj.hFpga = hDAQAcq.initFPGA();
                end
                
                digitizerType = hDAQAcq.hAdapterModule.productType;
                
                obj.hAI.setFpgaAndFifo(digitizerType, obj.hFpga.(fifoName), obj.hLinScan.mdfData.secondaryFpgaFifo, digitizerType);
                obj.hAI.nSampleCallback = @(data)obj.zzSamplesAcquiredFcn(data,'');
                obj.hAI.doneCallback = @(data)obj.zzSamplesAcquiredFcn(data,'');
                obj.hAI.fpgaInvertChannels = obj.hLinScan.channelsInvert;
                
                if isempty(obj.hLinScan.hDataScope)
                    obj.hLinScan.hDataScope = scanimage.components.scan2d.resscan.FpgaDataScope(obj.hLinScan,hDAQAcq);
                end
                
                if obj.hLinScan.externalSampleClock
                    obj.hFpga.configureAdapterModuleExternalSampleClock(obj.hLinScan.externalSampleClockRate);
                    obj.hFpga.measureExternalRawSampleClockRate();
                else
                    obj.hFpga.configureAdapterModuleInternalSampleClock();
                end
                
                obj.hLinScan.laserTriggerFilterSupport = true;
                
            elseif isa(hDAQAcq,'dabs.resources.daqs.NIDAQ')
                import dabs.ni.daqmx.*;
                obj.acqDevType = hDAQAcq.productCategory;
                
                obj.hAI = scanimage.components.scan2d.linscan.DataStream('daq');
                
                obj.hAI.hTask = most.util.safeCreateTask([obj.hLinScan.name '-AnalogInput']);
                obj.hAI.hTaskOnDemand = most.util.safeCreateTask([obj.hLinScan.name '-AnalogInputOnDemand']);
                
                % make sure not more channels are created then there are channels available on the device
                for i=1:obj.hAI.getNumAvailChans(numel(obj.hLinScan.channelIDs),hDAQAcq.name)
                    obj.hAI.hTask.createAIVoltageChan(hDAQAcq.name,obj.hLinScan.channelIDs(i),sprintf('Imaging-%.2d',i-1),-1,1);
                    obj.hAI.hTaskOnDemand.createAIVoltageChan(hDAQAcq.name,obj.hLinScan.channelIDs(i),sprintf('ImagingOnDemand-%.2d',i-1));
                end
                
                % the AI task reuses the sample clock of the AO task this
                % guarantees the two tasks start at the same time and stay in sync
                obj.hAI.hTask.cfgSampClkTiming(obj.hAI.get('sampClkMaxRate'), 'DAQmx_Val_FiniteSamps', 2);
                obj.hAI.hTask.everyNSamplesReadDataEnable = true;
                obj.hAI.hTask.everyNSamplesReadDataTypeOption = 'native';
                obj.hAI.hTask.everyNSamplesEventCallbacks = @(~,evnt)obj.zzSamplesAcquiredFcn(evnt.data,evnt.errorMessage);
                obj.hAI.hTask.doneEventCallbacks = @obj.zzDoneEventFcn;
                
                % the on demand AI task does not use a sample clock
                obj.hAI.hTaskOnDemand.everyNSamplesReadDataTypeOption = 'native';
                obj.hAI.sampClkTimebaseRate = obj.hAI.hTask.get('sampClkTimebaseRate');
                
            else
                assert(false,'Invalid acquisition device: %s',class(hDAQAcq));
            end
            
            obj.hAIFdbk = dabs.ni.rio.fpgaDaq.fpgaDaqAITask.createTaskObj([obj.hLinScan.name '-GalvoFeedbackAI'], []);
            obj.hAIFdbkZ = most.util.safeCreateTask([obj.hLinScan.name '-ZFeedbackAI']);
        end
        
        function zzDoneEventFcn(obj,~,~)
            % when the event rate is high, for some strange reason the last
            % everyNSamples event of a finite acquisition is not fired, but
            % the doneEvent is fired instead. To work around this issue,
            % register both callbacks. if the done event is fired, generate
            % a 'pseudo callback' for the everyNSamples event
            availableSamples = obj.hAI.hTask.get('readAvailSampPerChan');
            if obj.isLineScan
                data = obj.hAI.hTask.readAnalogData(availableSamples,'native',0);
                obj.zzSamplesAcquiredFcn(data,''); % call the everNSamples callback with the pseudo event data
            elseif mod(availableSamples,obj.everyNSamples) == 0
                stripesAvailable = availableSamples/obj.everyNSamples;
                for idx = 1:stripesAvailable
                    obj.hAI.hTask.isTaskDone;
                    data = obj.hAI.hTask.readAnalogData(obj.everyNSamples,'native',0);
                    obj.zzSamplesAcquiredFcn(data,''); % call the everNSamples callback with the pseudo event data
                end
            else
                % this should never happen. if the done event is fired the
                % input buffer should be either empty, or the last frame
                % (availablesamples == obj.everyNSamples) should be in the
                % buffer
                obj.hLinScan.hSI.abort();
                error('LinScan Acq: Something bad happened: Available number of samples does not match expected number of samples.');
            end
        end
        
        function zzConfigInputEveryNAndBuffering(obj)
            %Determine everyNSamples value
            if obj.isLineScan
                cycleBatchSize = 1/(obj.acqParamBuffer.frameTime * obj.hLinScan.stripingMaxRate);
                if cycleBatchSize > 0.5 || ~obj.hLinScan.stripingEnable
                    % the cycles are shorter than the striping rate. we will update after multiple cycles have been collected
                    obj.acqParamBuffer.cycleBatchSize = ceil(cycleBatchSize);
                    obj.acqParamBuffer.numStripes = 1;
                    obj.everyNSamples = obj.acqParamBuffer.samplesPerFrame * obj.acqParamBuffer.cycleBatchSize;
                else
                    % the cycles are shorter than the striping rate. we will update after multiple cycles have been collected
                    obj.acqParamBuffer.cycleBatchSize = 0;
                    maxNStripes = floor(1/cycleBatchSize);
                    possibleNStripes = divisors(obj.acqParamBuffer.samplesPerFrame);
                    possibleNStripes = possibleNStripes(possibleNStripes <= maxNStripes);
                    obj.acqParamBuffer.numStripes = max(possibleNStripes);
                    obj.everyNSamples = round(obj.acqParamBuffer.samplesPerFrame / obj.acqParamBuffer.numStripes);
                end
                
                if obj.hLinScan.recordScannerFeedback
                    if obj.acqParamBuffer.numStripes > 1
                        possibleNStripes = divisors(obj.acqParamBuffer.fdbkSamplesPerFrame);
                        possibleNStripes = possibleNStripes(possibleNStripes <= obj.acqParamBuffer.numStripes);
                        obj.acqParamBuffer.numStripesFdbk = max(possibleNStripes);
                        obj.acqParamBuffer.nSampleFdbk = obj.acqParamBuffer.fdbkSamplesPerFrame / obj.acqParamBuffer.numStripesFdbk;
                    else
                        obj.acqParamBuffer.numStripesFdbk = 1;
                        nFr = min(obj.hLinScan.framesPerAcq, obj.acqParamBuffer.cycleBatchSize);
                        obj.acqParamBuffer.nSampleFdbk = obj.acqParamBuffer.fdbkSamplesPerFrame * nFr;
                    end
                     
                    obj.hAIFdbk.everyNSamples = [];
                    obj.hAIFdbk.sampQuantSampPerChan = obj.acqParamBuffer.fdbkSamplesPerFrame;
                    obj.hAIFdbk.cfgDigEdgeStartTrig(obj.hLinScan.hTrig.frameClockTermInt,'DAQmx_Val_Rising');
                    obj.hAIFdbk.cfgInputBufferVerify(obj.ACQ_BUFFER_SIZE * obj.acqParamBuffer.nSampleFdbk,2*obj.acqParamBuffer.nSampleFdbk);
                    obj.hAIFdbk.everyNSamples = obj.acqParamBuffer.nSampleFdbk; %registers callback
                    
                    if obj.rec3dPath && ~obj.zFdbkShareDaq
                        obj.hAIFdbkZ.sampQuantSampPerChan = obj.acqParamBuffer.fdbkSamplesPerFrame;
                        obj.hAIFdbkZ.cfgInputBufferVerify(obj.ACQ_BUFFER_SIZE * obj.acqParamBuffer.nSampleFdbk,2*obj.acqParamBuffer.nSampleFdbk);
                    end
                    
                    obj.hLinScan.lastFramePositionData = nan(obj.acqParamBuffer.fdbkSamplesPerFrame,2);
                else
                    obj.hLinScan.lastFramePositionData = nan;
                end
            else
                obj.acqParamBuffer.numStripes = determineNumStripes(obj.acqParamBuffer,obj.acqParamBuffer.samplesPerFrame);
                obj.everyNSamples = round(obj.acqParamBuffer.samplesPerFrame / obj.acqParamBuffer.numStripes);
            end
            
            obj.hAI.bufferSize = obj.ACQ_BUFFER_SIZE * obj.everyNSamples;
            obj.hAI.callbackSamples = obj.everyNSamples;
            obj.hAI.configureStream();
            
            function numStripes = determineNumStripes(acqParamBuffer,samplesPerFrame)
                if obj.hLinScan.stripingEnable ...
                        && length(acqParamBuffer.roiGroup.rois) == 1 ...
                        && length(acqParamBuffer.roiGroup.rois(1).scanfields) == 1
                    
                    maxNumStripes = min(acqParamBuffer.frameTime * obj.hLinScan.stripingMaxRate, obj.MAX_NUM_STRIPES);
                    possibleNumStripes = divisors(samplesPerFrame);
                    possibleNumStripes = possibleNumStripes(possibleNumStripes <= maxNumStripes);
                    numStripes = max(possibleNumStripes);
                    if isempty(numStripes)
                        numStripes = 1;
                    end
                else
                    numStripes = 1;
                end
            end
            
            function d = divisors(n) % local function
                % this algorithm should be sufficiently fast for small values of n
                d = 1:n/2;            % list of possible divisors
                d = d(mod(n,d) == 0); % test all possible divisors
            end
        end
        
        function zzConfigSampModeAndSampPerChan(obj,forceContinuous)
            if nargin < 2 || isempty(forceContinuous)
                forceContinuous = false;
            end
            
            obj.hAI.sampClkRate = obj.hLinScan.sampleRate;
            
            if forceContinuous || obj.hLinScan.framesPerAcq <= 0 || isinf(obj.hLinScan.framesPerAcq) || obj.hLinScan.trigNextStopEnableInternal
                obj.hAI.totalSamples = 0;
            else
                numSamples = obj.acqParamBuffer.samplesPerFrame * obj.hLinScan.framesPerAcq;
                
                if numSamples > 16777213 && strcmpi(obj.acqDevType,'DAQmx_Val_SSeriesDAQ');
                    %limitation in legacy S-Series (e.g. 6110): cannot set
                    %sampQuantSampPerChan to a high value, use continuous
                    %mode instead
                    obj.hAI.totalSamples = 0;
                elseif numSamples >= 2^32
                    obj.hAI.totalSamples = 0;
                else
                    % DAQmx property sampQuantSampPerChan is limited to 2^32-1
                    assert(numSamples < 2^32,['Exceeded maximum number of frames per acquisition.\n' ...
                        'Requested: %d; Maximum possible with current settings: %d (=%d min acquisition time) \n' ...
                        'Workaround: set number of frames to Inf (number of volumes for FastZ acquisition)'],...
                        obj.hLinScan.framesPerAcq,floor((2^32-1)/obj.acqParamBuffer.samplesPerFrame),round((2^32-1)/(60*obj.hLinScan.sampleRate)));
                    
                    obj.hAI.totalSamples = numSamples;
                end
            end
        end
        
        function zzFdbckSamplesAcquiredFcn(obj,data,err)
            if obj.endOfAcquisition
                return
            end
                        
            if ~isempty(err)                
                fprintf(2,'Error reading feedback data:\n%s\n',err);
                obj.hLinScan.hSI.abort();
                return;
            end
            
            N = size(data,1);
            finalData = zeros(N,2+obj.rec3dPath,'single');
            
            % convert samples to XY angle
            xyPts = [single(obj.hLinScan.xGalvo.feedbackVolts2Position(single(data(:,1)))) single(obj.hLinScan.yGalvo.feedbackVolts2Position(single(data(:,2))))];
            finalData(:,1:2) = single(scanimage.mroi.util.xformPoints(xyPts,single(obj.hLinScan.scannerToRefTransform)));
            if obj.rec3dPath
                if obj.zFdbkShareDaq
                    d = single(data(:,3));
                else
%                     N_ = get(obj.hAIFdbkZ, 'readAvailSampPerChan')
%                     size(finalData)
                    d = obj.hAIFdbkZ.readAnalogData(N,[],0);
                end
                
                finalData(:,3) = single(obj.hLinScan.hFastZs{1}.feedbackVolts2Position(d(:,1)));
                assignin('base','finalData',finalData)
            end
            
            APB = obj.acqParamBuffer;
            if obj.acqParamBuffer.numStripesFdbk > 1
                stripeNumber = mod(obj.stripeCounterFdbk, APB.numStripes) + 1;
                obj.stripeCounterFdbk = obj.stripeCounterFdbk + 1;
                numFrames = 0;
                lastFrameStartIdx = (stripeNumber - 1) * obj.acqParamBuffer.nSampleFdbk + 1;
            else
                numFrames = N / APB.fdbkSamplesPerFrame;
                lastFrameStartIdx = (numFrames - 1) * APB.fdbkSamplesPerFrame + 1;
            end
            
            % pass data to be logged and displayed
            obj.hLinScan.zzFeedbackDataAcquiredCallback(finalData, numFrames, N, lastFrameStartIdx);
        end
        
        function zzSamplesAcquiredFcn(obj,inputSamples,err)
            try
                if obj.endOfAcquisition || ~obj.hLinScan.active
                    return
                end
                
                startProcessingTime = tic;
                
                %             % querrying the fpga takes a millisecond. should poll in C instead
                %             if obj.useFpgaOffset && obj.hFpga.FifoMultiChannelPixelsLost
                %                 fprintf(2,'Pixels lost in transfer from FPGA. Try lowering sample rate.\n');
                %                 obj.hLinScan.hSI.abort();
                %                 return;
                %             end
                
                if ~isempty(err)
                    fprintf(2,'Error reading PMT data:\n%s\n',err);
                    size(inputSamples)
                    obj.hLinScan.hSI.abort();
                    return;
                end
                
                N = size(inputSamples,1);
                if N ~= obj.everyNSamples && ~obj.isLineScan
                    fprintf(2,'Did not receive expected number of samples from analog input task\n');
                    obj.hLinScan.hSI.abort();
                    return;
                end
                
                if obj.isLineScan
                    APB = obj.acqParamBuffer;
                    
                    inputSamples = inputSamples(:,APB.channelsActive);
                    for i = 1:numel(APB.channelsActive)
                        inputSamples(:,i) = inputSamples(:,i) .* APB.channelsSign(i) - APB.channelsOffset(i);
                    end
                    
                    numFrames = N / APB.samplesPerFrame;
                    
                    if numFrames < 1
                        stripeNumber = mod(obj.stripeCounter, APB.numStripes) + 1;
                        obj.stripeCounter = obj.stripeCounter + 1;
                        eof = stripeNumber == obj.acqParamBuffer.numStripes;
                        frameNumbers = obj.frameCounter + 1;
                        obj.frameCounter = obj.frameCounter + eof;
                        rawDataStripePosition = (stripeNumber - 1) * N + 1;
                    else
                        frameNumbers = obj.frameCounter+1:obj.frameCounter+numFrames;
                        obj.frameCounter = frameNumbers(end);
                        stripeNumber = 1;
                        eof = true;
                        rawDataStripePosition = 1;
                    end
                    
                    stripeDat = scanimage.interfaces.StripeData();
                    stripeDat.frameNumberAcq = frameNumbers;
                    stripeDat.stripeNumber = stripeNumber;
                    stripeDat.stripesRemaining = 0;
                    stripeDat.startOfFrame = (stripeNumber == 1);
                    stripeDat.endOfFrame = eof;
                    stripeDat.overvoltage = false; % TODO: check for overvoltage
                    stripeDat.channelNumbers = APB.channelsActive;
                    stripeDat.rawData = inputSamples;
                    stripeDat.rawDataStripePosition = rawDataStripePosition;
                    
                    if stripeDat.endOfFrame && obj.hLinScan.framesPerAcq > 0 && frameNumbers(end) >= obj.hLinScan.framesPerAcq && ~obj.hLinScan.trigNextStopEnableInternal
                        obj.endOfAcquisition = true;
                    end
                    stripeDat.endOfAcquisition = obj.endOfAcquisition;
                    
                    obj.hLinScan.zzStripeAcquiredCallback(stripeDat, startProcessingTime);
                else
                    % calculate local frame and stripe number
                    % this needs to be done before the object counters are updated!
                    frameNumber = obj.frameCounter + 1;
                    stripeNumber = mod(obj.stripeCounter, obj.acqParamBuffer.numStripes) + 1;
                    
                    % update stripe and frame counter
                    obj.stripeCounter = obj.stripeCounter + 1;
                    if ~mod(obj.stripeCounter,obj.acqParamBuffer.numStripes)
                        obj.frameCounter = obj.frameCounter + 1;
                    end
                    
                    if obj.frameCounter >= obj.hLinScan.framesPerAcq && obj.hLinScan.framesPerAcq > 0 && ~obj.hLinScan.trigNextStopEnableInternal
                        obj.endOfAcquisition = true;
                    end
                    
                    % construct stripe data object
                    stripeData = scanimage.interfaces.StripeData();
                    stripeData.frameNumberAcq = frameNumber;
                    stripeData.stripeNumber = stripeNumber;
                    stripeData.stripesRemaining = 0;
                    stripeData.startOfFrame = (stripeNumber == 1);
                    stripeData.endOfFrame = (stripeNumber == obj.acqParamBuffer.numStripes);
                    stripeData.endOfAcquisition = obj.endOfAcquisition;
                    stripeData.overvoltage = false; % TODO: check for overvoltage
                    stripeData.channelNumbers = obj.hLinScan.hSI.hChannels.channelsActive;
                    
                    stripeData = obj.hLinScan.hSI.hStackManager.stripeDataCalcZ(stripeData);
                    stripeData = obj.zzDataToRois(stripeData,inputSamples);
                    % stripe data is still transposed at this point
                    obj.hLinScan.zzStripeAcquiredCallback(stripeData, startProcessingTime);
                end
            catch ME
                most.ErrorHandler.logAndReportError(ME,'Error processing acquisition data.');
            end
        end
        
        function stripeData = zzDataToRois(obj,stripeData,ai)   
            if stripeData.startOfFrame
                obj.sampleBuffer.reset();
            end
            
            obj.sampleBuffer.appendData(ai);
            
            APB = obj.acqParamBuffer;
            
            if isnan(stripeData.zIdx)
                % flyback frame
                stripeData.roiData = {};
            else
                stripeData.roiData = {};

                scannerset = APB.scannerset;
                z = obj.acqParamBuffer.zs(stripeData.zIdx);
                scanFieldParamsArr = APB.scanFieldParams{stripeData.zIdx};
                rois       = APB.rois{stripeData.zIdx};
                startSamples = APB.startSamples{stripeData.zIdx};
                endSamples = APB.endSamples{stripeData.zIdx};
                numFields = numel(scanFieldParamsArr);
                
                for i = 1:numFields
                    scanFieldParams = scanFieldParamsArr(i);
                    fieldSamples = [startSamples(i),endSamples(i)];
                    roi = rois{i};
                    [success,imageDatas,stripePosition] = scannerset.formImage(scanFieldParams,obj.sampleBuffer,fieldSamples,APB.channelsActive,APB.linePhaseSamples,obj.disableMatlabAveraging);
                    
                    if success
                        roiData = scanimage.mroi.RoiData;
                        roiData.hRoi = roi;
                        roiData.zs = z;
                        roiData.stripePosition = {stripePosition};
                        roiData.stripeFullFrameNumLines = scanFieldParams.pixelResolution(2);
                        roiData.channels = APB.channelsActive;
                        for iter = 1:length(imageDatas)
                            image = imageDatas{iter} .* APB.channelsSign(iter) - APB.channelsOffset(iter);
                            
                            if APB.numStripes > 1
                                roiData.imageData{iter}{1} = zeros(scanFieldParams.pixelResolution(1),scanFieldParams.pixelResolution(2));
                                roiData.imageData{iter}{1}(:,stripePosition(1):stripePosition(2)) = image;
                            else
                                roiData.imageData{iter}{1} = image;
                            end
                        end
                        stripeData.roiData{i} = roiData;
                    end
                end
            end
        end
    end
    
    %% Setter/Getter Methods
    methods
        function val = get.hFpga(obj)
            val = dabs.ni.rio.NiFPGA.empty();
            
            if most.idioms.isValidObj(obj.hLinScan.hDAQAcq) && isa(obj.hLinScan.hDAQAcq,'dabs.resources.daqs.NIRIO')
                val = obj.hLinScan.hDAQAcq.hFpga;
            end
        end
        
        function val = get.active(obj)
            val = obj.hAI.running;
        end
        
        function set.startTrigIn(obj,val)
            obj.assertNotActive('startTrigIn');
            
            switch obj.startTrigEdge
                case 'rising'
                    edge = 'DAQmx_Val_Rising';
                case 'falling'
                    edge = 'DAQmx_Val_Falling';
                otherwise
                    assert(false);
            end
            
            if isempty(val)
                obj.hAI.disableStartTrig();
            else
                obj.hAI.configureStartTrigger(val,edge);
            end
            
            obj.startTrigIn = val;
        end
        
        function set.startTrigEdge(obj,val)
            obj.assertNotActive('startTrigEdge');
            assert(ismember(val,{'rising','falling'}));
            obj.startTrigEdge = val;
            obj.startTrigIn = obj.startTrigIn;
        end
        
        function v = get.fpgaLoopRate(obj)
            v = obj.hAI.fpgaBaseRate;
        end
        
        function val = get.is3dLineScan(obj)
            val = obj.isLineScan && ~isempty(obj.hLinScan.hFastZs);
        end
        
        function val = get.rec3dPath(obj)
            val = obj.hLinScan.recordScannerFeedback && obj.is3dLineScan && obj.zFdbkEn;
        end
    end
    
    %% Helper functions
    methods (Access = private)        
        function assertNotActive(obj,propName)
            assert(~obj.active,'Cannot access property %s during an active acquisition',propName);
        end
        
        function valCoercedWarning(~,propName,requestedVal,actualVal)
            if requestedVal ~= actualVal
                warning('%s was coerced to the nearest possible value. Requested: %d Actual: %d', ...
                    propName, requestedVal, actualVal);
            end
        end
        
        function zprvClearTask(obj, taskPropertyName)
            hTask = obj.(taskPropertyName);
            
            if isempty(hTask) || ~isvalid(hTask)
                return;
            end
            
            hTask.clear();
            obj.(taskPropertyName) = [];
        end
    end
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
