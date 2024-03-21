classdef DataScope < scanimage.components.scan2d.interfaces.DataScope
    properties (SetObservable)
        trigger = 'none';
        triggerLineNumber = 1;
        triggerSliceNumber = 1;
        channel = 1;
        inputRange = 2;
        acquisitionTime = 0.1;
        triggerHoldOffTime = 0;
        desiredSampleRate = [];
        
        includeDigital = true;
        includeSyncTrigger = false;
        
        callbackFcn = @(src,evt)plot(evt.data);
        errorCallbackFcn = [];
    end
    
    properties (SetObservable, SetAccess = protected)
        active = false;
        triggerAvailable = {'none','frame','slice','line'};
    end
    
    properties (Constant, Hidden)
        DATA_SIZE_BYTES = 10;
        FIFO_POLLING_PERIOD = 0.01;
    end
    
    properties (Hidden)
        maxAllowedDataRate = 800e6;
        displayPeriod = 60e-3;
        maxDataSizeBytes = 2e5;
        paramCache;
    end
    
    properties (SetObservable,Dependent,SetAccess = protected)
        channelsAvailable;
        digitizerSampleRate;
        digitizerActualSampleRate;
        currentDataRate;
    end
    
    properties (Hidden, SetAccess = private)
        hFpga
        hScan2D
        hFifo
        acquisitionActive = false;
        continuousAcqActive = false;
        lastDataReceivedTime;
        hDataStream;
        isH;
    end
    
    properties (SetAccess = private)
        hFifoPollingTimer;
    end
    
    
    %% LifeCycle
    methods
        function obj = DataScope(hParent)
            if isa(hParent, 'scanimage.components.scan2d.RggScan')
                obj.hScan2D = hParent;
                obj.hFpga = hParent.hAcq.hFpga;
            else
                obj.hFpga = hParent;
            end
            obj.hFifo = obj.hFpga.hScopeFifo;
            
            obj.isH = strcmp(obj.hFpga.hAfe.moduleType, 'H');
            
            obj.hFifoPollingTimer = timer('Name','DataScope Polling Timer');
            obj.hFifoPollingTimer.ExecutionMode = 'fixedSpacing';
        end
        
        function delete(obj)
            obj.abort();
            if ~isempty(obj.hFpga)
                obj.stopFifo();
            end
            most.idioms.safeDeleteObj(obj.hFifoPollingTimer);
        end
    end
    
    %% Public Methods
    methods
        function startContinuousAcquisition(obj)
            assert(~obj.active,'DataScope is already started');
            obj.lastDataReceivedTime = uint64(0);
            obj.start();
            obj.continuousAcqActive = true;
        end
        
        function start(obj)
            assert(~obj.active,'DataScope is already started');
            obj.abort();
            obj.active = true;
            obj.acquisitionActive = false;
            
            % make sure laser trigger port and perdiod clk port are cfgd
            if ~isempty(obj.hScan2D)
                obj.hScan2D.hTrig.applyTriggerConfig();
            end
            
            obj.hFpga.resetDataScope();
            obj.startFifo();
            
            obj.hFifoPollingTimer.Period = obj.FIFO_POLLING_PERIOD;
            obj.hFifoPollingTimer.TimerFcn = @obj.checkFifo;
            start(obj.hFifoPollingTimer);
        end
        
        function acquire(obj,callback)
            if nargin < 2 || isempty(callback)
                callback = obj.callbackFcn;
            end
            
            assert(obj.active,'DataScope is not started');
            assert(~obj.acquisitionActive,'Acquisition is already active');
            
            if ~isempty(obj.hScan2D)
                obj.inputRange = diff(obj.hScan2D.channelsInputRanges{obj.channel});
            end
            
            adcRes = obj.hFpga.hAfe.channelResolutionBits;
            adc2VoltFcn = @(a)obj.inputRange*single(a)./2^adcRes;

            [nSamples,sampleRate,downSampleFactor,totalDataSize] = obj.getSampleRate();
            
            triggerHoldOffResolution = 1 + 31*obj.isH;
            triggerHoldOff = round(obj.triggerHoldOffTime*sampleRate/triggerHoldOffResolution); % coerce triggerHoldOffTime
            triggerHoldOffTime_ = triggerHoldOff*triggerHoldOffResolution/sampleRate;
            
            settings = struct();
            settings.channel = obj.channel;
            settings.sampleRate = sampleRate;
            settings.digitzerSampleRate = obj.digitizerSampleRate;
            settings.downSampleFactor = downSampleFactor;
            settings.inputRange = obj.inputRange;
            settings.adcRes = adcRes;
            settings.nSamples = nSamples;
            settings.trigger = obj.trigger;
            settings.triggerHoldOff = triggerHoldOff;
            settings.triggerHoldOffTime = triggerHoldOffTime_;
            settings.triggerLineNumber = obj.triggerLineNumber;
            settings.triggerSliceNumber = obj.triggerSliceNumber;
            settings.adc2VoltFcn = adc2VoltFcn;
            settings.callback = callback;
            
            pCache = obj.configureFpga(settings);
            pCache.totalDataSize = totalDataSize;
            pCache.settings = settings;
            obj.paramCache = pCache;
            
            obj.acquisitionActive = true;
            obj.hFpga.startDataScope();
        end
        
        function abort(obj)
            try
                if ~isempty(obj.hFifoPollingTimer)
                    stop(obj.hFifoPollingTimer);
                end
                if ~isempty(obj.hFpga)
                    obj.hFpga.resetDataScope();
                end
                obj.active = false;
                obj.acquisitionActive = false;
                obj.continuousAcqActive = false;
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
        end
        
        function info = mouseHoverInfo2Pix(obj,mouseHoverInfo)
            info = [];
            
            if ~isa(obj.hScan2D,'scanimage.components.scan2d.RggScan')
                info = [];
                return
            end
            
            if nargin < 2 || isempty(mouseHoverInfo)
                mouseHoverInfo = obj.hScan2D.hSI.hDisplay.mouseHoverInfo;
            end
            
            acqParamBuffer = obj.hScan2D.hAcq.acqParamBuffer;
            if isempty(acqParamBuffer) || isempty(fieldnames(acqParamBuffer) )|| isempty(mouseHoverInfo)
                return
            end
            
            xPix = mouseHoverInfo.pixel(1);
            yPix = mouseHoverInfo.pixel(2);
            
            [tf,zIdx] = ismember(mouseHoverInfo.z,acqParamBuffer.zs);
            if ~tf
                return
            end
            
            rois = acqParamBuffer.rois{zIdx};
            
            mask = cellfun(@(r)isequal(mouseHoverInfo.hRoi,r),rois);
            if ~any(mask)
                return
            end
            
            roiIdx = find(mask,1);
            roiStartLine = acqParamBuffer.startLines{zIdx}(roiIdx);
            roiEndLine   = acqParamBuffer.endLines{zIdx}(roiIdx);
            
            pixelLine = roiStartLine + yPix - 1;
            
            mask = obj.hScan2D.hAcq.mask;
            if numel(mask) < xPix
                return
            end
            
            cumMask = cumsum(mask) * (1+31*obj.isH);
            
            if xPix==1
                pixelStartSample = 1;
            else
                pixelStartSample = cumMask(xPix-1)+1;
            end
            pixelEndSample = cumMask(xPix);
            
            reverseLine = obj.hScan2D.bidirectional && xor(obj.hScan2D.reverseLineRead,~mod(pixelLine,2));
            
            if reverseLine
                pixelStartSample = cumMask(end) - pixelStartSample +1;
                pixelEndSample = cumMask(end) - pixelEndSample + 1;
            end
            
            info = struct();
            info.pixelStartSample = pixelStartSample;
            info.pixelEndSample = pixelEndSample;
            info.pixelStartTime = (pixelStartSample - 1) / obj.digitizerSampleRate;
            info.pixelEndTime = pixelEndSample / obj.digitizerSampleRate;
            info.roiStartLine = roiStartLine;
            info.roiEndLine = roiEndLine;
            info.pixelLine = pixelLine;
            info.lineDuration = (cumMask(end)-1) / obj.digitizerSampleRate;
            info.channel = mouseHoverInfo.channel;
            info.z = mouseHoverInfo.z;
            info.zIdx = zIdx;
        end
    end
    
    %% Internal Functions    
    methods (Hidden)
        function restart(obj)
            if obj.continuousAcqActive
                obj.abort();
                obj.startContinuousAcquisition();
            elseif obj.active
                obj.abort();
                obj.start();
            end
        end
        
        function paramCache = configureFpga(obj,settings)
            if ~isempty(obj.hScan2D)
                obj.hFpga.scopeParamAeSel = obj.hScan2D.hAcq.acquisitionEngineIdx-1;
            end
            
            [packetSize, samplesPerPacket] = obj.getPacketSize(settings.downSampleFactor);
            
            if obj.isH
                obj.hFpga.scopeParamHsChanSel = obj.channel-1;
                assert((settings.downSampleFactor == 1) || ~obj.includeSyncTrigger, 'Sync trigger can only be used when sample decimation is disabled.');
                
                if settings.downSampleFactor == 1
                    paramCache.analogWidthBytes = 48;
                else
                    paramCache.analogWidthBytes = 64/min(settings.downSampleFactor,32);
                end
                
                paramCache.numPackets = settings.nSamples/samplesPerPacket;
                paramCache.packetSize = packetSize;
                
                paramCache.i16AnalogColumns = paramCache.analogWidthBytes / 2;
                
                paramCache.digitalColumn = paramCache.analogWidthBytes/2+1;
                paramCache.u16Columns = packetSize/2;
                
                paramCache.dmask = uint16(2.^(0:15));
            else
                paramCache.numColumns = 4 + obj.includeDigital;
                paramCache.numPackets = settings.nSamples/samplesPerPacket;
            end
            
            obj.hFpga.scopeParamFifoWriteWidth = packetSize - 1;
            obj.hFpga.scopeParamDecimationLB2 = log2(settings.downSampleFactor);
            obj.hFpga.scopeParamNumberOfSamples = paramCache.numPackets;
            obj.hFpga.scopeParamTriggerHoldoff = settings.triggerHoldOff;
            obj.hFpga.scopeParamTriggerLineNumber = settings.triggerLineNumber;
            % obj.hFpga.scopeParamTriggerSliceNumber = settings.triggerSliceNumber;
                        
            switch lower(settings.trigger)
                case {'none' ''}
                    obj.hFpga.scopeParamTriggerId = 0;
                case 'frame'
                    obj.hFpga.scopeParamTriggerId = 12;
                case 'slice'
                    obj.hFpga.scopeParamTriggerId = 12;
                case 'line'
                    obj.hFpga.scopeParamTriggerId = 9;
                otherwise
                    error('Unsupported trigger type: %s',settings.trigger);
            end
        end        
        
        function startFifo(obj)
            [~,~,~,totalDataSize] = obj.getSampleRate();
            obj.hFifo.configureOrFlush(totalDataSize);
        end
        
        function stopFifo(obj)
            obj.hFifo.close();
        end
        
        function checkFifo(obj,varargin)
            if ~obj.acquisitionActive
                if obj.continuousAcqActive && (toc(obj.lastDataReceivedTime) > obj.displayPeriod)
                    try
                        obj.acquire();
                    catch ME
                        if ~isempty(obj.errorCallbackFcn)
                            obj.errorCallbackFcn(obj,ME);
                        end
                        obj.abort();
                    end
                end
                return
            end
            
            if isempty(obj.paramCache)
                most.ErrorHandler.logAndReportError('Data scope error');
                obj.abort();
            else
                pCache = obj.paramCache;
            end
            
            try
                assert(~obj.hFpga.scopeStatusFifoOverflowCount,'Data Scope data was lost. PCIe bandwidth may have been exceeded.');
            catch ME
                if ~isempty(obj.errorCallbackFcn)
                    obj.errorCallbackFcn(obj,ME);
                else
                    try
                        obj.abort();
                    catch
                    end
                    most.ErrorHandler.logAndReportError(ME);
                end
                return;
            end
            
            [fifoData,bytesRemaining] = obj.hFifo.read(pCache.totalDataSize);
            
            if isempty(fifoData)
                return
            end
            
            if bytesRemaining
                obj.abort();
                error('DataScope: No elements are supposed to remain in FIFO');
            end
            
            if ~isempty(obj.hScan2D)
                chSign = (-1)^obj.hScan2D.hAcq.hAcqEngine(1).acqParamChannelsInvert(obj.channel);
            else
                chSign = 1;
            end
            
            if obj.isH
                if pCache.settings.downSampleFactor > 1
                    i16Data = typecast(fifoData,'int16');
                    rData = reshape(i16Data, pCache.packetSize/2, []);
                    aData = rData(1:pCache.i16AnalogColumns,:);
                    channeldata = aData(:) * chSign;
                else
                    rawDataReshape = reshape(fifoData, pCache.packetSize, []);
                    adata = rawDataReshape(1:pCache.analogWidthBytes,:);
                    rdata = reshape(adata(:),3,[]);
                    
                    channeldata = single(typecast(bitshift(reshape(...
                        [uint16(rdata(1,:))+(uint16(bitand(rdata(2,:),15))*256);...
                         uint16(bitshift(bitand(rdata(2,:),240),-4))+(uint16(rdata(3,:))*16)]...
                        ,[],1),4),'int16')/16) * chSign;
                end
                
                if obj.includeDigital || obj.includeSyncTrigger
                    u16Data = typecast(fifoData,'uint16');
                end
                
                if obj.includeDigital
                    triggers = triggerDecode(u16Data(pCache.digitalColumn:pCache.u16Columns:end));
                else
                    triggers = [];
                end
                
                if obj.includeSyncTrigger
                    % the u16 data is now the phase of the first sample, not the sync trigger
                    samplePhases = u16Data(26:pCache.u16Columns:end);
                    
                    % trace is generated in signal conditioning controls window
                    triggers.SamplePhase = samplePhases;
                end
            else
                fifoData = reshape(typecast(fifoData,'int16'),pCache.numColumns,[]);
                channeldata = single(fifoData(pCache.settings.channel,:)')*.25*chSign;
                
                if obj.includeDigital
                    triggers = typecast(fifoData(5:5:end),'uint16');
                    triggers = triggerDecode(triggers);
                else
                    triggers = [];
                end
            end
            
            if ~isempty(pCache.settings.callback)
                src = obj;
                evt = struct();
                evt.data = channeldata;
                evt.settings = pCache.settings;
                
                if obj.isH && obj.hFpga.scopeParamPh
                    u32 = typecast(u16Data,'uint32');
                    dd = u32(13:13:end);
                    nd = numel(dd);
                    ds = repmat(dd',32,1);
                    m = uint32(repmat(2.^(0:31)',1,nd));
                    pc = logical(bitand(ds,m));
                    evt.photonPeaks = pc(:);
                else
                    evt.triggers = triggers;
                end
                
                pCache.settings.callback(src,evt);
            end
            
            obj.lastDataReceivedTime = tic;
            obj.acquisitionActive = false;
            
            function s = triggerDecode(trigger)
                s = struct();
                s.PeriodClockRaw        = getDig(trigger,1);
                s.PeriodClockDebounced  = getDig(trigger,2);
                s.PeriodClockDelayed    = getDig(trigger,3);
                s.MidPeriodClockDelayed = getDig(trigger,4);
                s.AcquisitionTrigger    = getDig(trigger,5);
                s.AdvanceTrigger        = getDig(trigger,6);
                s.StopTrigger           = getDig(trigger,7);
                s.LaserTriggerRaw       = getDig(trigger,15);
                s.LaserTrigger          = getDig(trigger,14);
                s.ControlSampleClock    = getDig(trigger,16);
                s.FrameClock            = getDig(trigger,12);
                s.BeamClock             = getDig(trigger,10);
                s.SampleAcquired        = getDig(trigger,8);
                s.VolumeTrigger         = getDig(trigger,13);
                s.LineActive            = getDig(trigger,9);
            end
            
            function d = getDig(dat,bit)
                d = bitget(dat,bit);
                if obj.isH
                    d = reshape(repmat(d,1,max(1,32/pCache.settings.downSampleFactor))',[],1);
                end
            end
        end
        
        function [packetSize, samplesPerPacket] = getPacketSize(obj,downSampleFactor)
            if obj.isH
                samplesPerPacket = max(32/downSampleFactor,1);
                
                if obj.includeSyncTrigger
                    packetSize = 52;
                elseif downSampleFactor == 1
                    packetSize = 48 + 2*obj.includeDigital;
                else
                    packetSize = 2*samplesPerPacket + 2*obj.includeDigital;
                end
            else
                packetSize = 8 + 2*obj.includeDigital;
                samplesPerPacket = 1;
            end
        end
        
        function [nSamples,sampleRate,downSampleFactor,totalSize] = getSampleRate(obj)
            if isempty(obj.desiredSampleRate)
                downSampleFactor = 1;
            else
                downSampleFactor = max(1,2^floor(log2(obj.digitizerSampleRate / obj.desiredSampleRate)));
            end
            sampleRate = obj.digitizerSampleRate / downSampleFactor;
            
            [packetSize, samplesPerPacket] = obj.getPacketSize(downSampleFactor);
            nSamples = max(1,floor(ceil(obj.acquisitionTime * sampleRate)/samplesPerPacket))*samplesPerPacket;
            totalSize = nSamples*packetSize/samplesPerPacket;
            
            if isempty(obj.desiredSampleRate) && (totalSize > obj.maxDataSizeBytes)
                % sample rate is not fixed and acq parameters produce too much data
                
                % for high speed adc, sample decimation 1 gives 12 bit
                % samples, while >= 2 gives 16 bit samples. redo the
                % calculation for sample decimation 2
                [packetSize, samplesPerPacket] = obj.getPacketSize(2);
                totalSize = nSamples*packetSize/samplesPerPacket;
                
                downSampleFactor = min(2^ceil(log2(totalSize / obj.maxDataSizeBytes)),64);
                [packetSize, samplesPerPacket] = obj.getPacketSize(downSampleFactor);
                nPackets = floor(obj.maxDataSizeBytes / packetSize);
                totalSize = packetSize * nPackets;
                nSamples = nPackets * samplesPerPacket;
                sampleRate = obj.digitizerSampleRate / downSampleFactor;
            end
        end
    end
    
    %% Property Setter/Getter
    methods
        function val = get.digitizerSampleRate(obj)
            val = obj.hFpga.nominalAcqSampleRate;
        end
        
        function val = get.digitizerActualSampleRate(obj)
            val = obj.hFpga.dataClkRate * obj.hFpga.nominalAcqSampleRate / obj.hFpga.nominalDataClkRate;
        end
        
        function val = get.channelsAvailable(obj)
            val = obj.hFpga.hAfe.physicalChannelCount;
        end
        
        function set.channel(obj,val)
            validateattributes(val,{'numeric'},{'integer','positive','<=',obj.channelsAvailable});
            obj.channel = val;
        end
        
        function set.maxDataSizeBytes(obj,val)
            assert(~obj.active,'Cannot change maxDataSizeBytes while DataScope is active');
            obj.maxDataSizeBytes = val;
        end
                
        function set.trigger(obj,val)
            if isempty(val)
                val = 'none';
            else
                val = lower(val);
            end
            mask = strcmpi(val,obj.triggerAvailable);
            assert(sum(mask) == 1,'%s is not a supported Trigger Type',val);
            obj.trigger = val;
            
            obj.restart(); % abort old acquisition that might be stuck on a trigger that's not firing
        end
        
        function set.triggerLineNumber(obj,val)
            validateattributes(val,{'numeric'},{'scalar','nonnegative','integer','<',2^16});
            obj.triggerLineNumber = val;
            
            obj.restart(); % abort old acquisition that might be stuck on a trigger that's not firing
        end
        
        function set.triggerSliceNumber(obj,val)
            validateattributes(val,{'numeric'},{'scalar','nonnegative','integer','<',2^16});
            obj.triggerSliceNumber = val;
            
            obj.restart(); % abort old acquisition that might be stuck on a trigger that's not firing
        end
        
        function val = get.currentDataRate(obj)
            [~,sampleRate,downSampleFactor] = obj.getSampleRate();
            packetSize = obj.getPacketSize(downSampleFactor);
            if obj.isH
                writeDecim = max(1,downSampleFactor / 32);
                val = obj.hFpga.nominalDataClkRate * packetSize / writeDecim;
            else
                val = sampleRate * packetSize;
            end
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
