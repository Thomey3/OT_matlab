classdef Acquisition < scanimage.interfaces.Class
    % Lightweight class enabling acquisition for SlmScan
    
    properties (SetAccess = private, Hidden)
        hSlmScan;                   % handle to Scan2D object
        hAI;                        % analog input task to read PMT data
        isFpga = false;             % indicates if hAI refers to a RIO device
        isVdaq;             %
        acqParamBuffer;             % buffer for acquisition parameters
        counters;                   % internal counters updated during acquisition
        sampleAcquisitionTimer;     % timer to acquire individual lines
        lastStripeData;             % buffer that holds last acquired stripe
        active = false;             % indicates if acquisition is active
        lastSlmUpdate = tic();      % last time SLM was updated
        hFpga;
        hAcqEngine;
    end
    
    %% Lifecycle
    methods
        function obj = Acquisition(hSlmScan)
            obj.hSlmScan = hSlmScan;
        end
        
        function delete(obj)
            obj.deinit();
        end
    end
    
    methods
        function deinit(obj)
            most.idioms.safeDeleteObj(obj.hAI);
        end
        
        function reinit(obj)
            %%% Initialize hAI object
            
            obj.deinit();
          
            hDAQ = obj.hSlmScan.hDAQ;
            
            if isa(hDAQ,'dabs.resources.daqs.vDAQ')
                acquisitionEngineIdx = 1;
                
                obj.hFpga = hDAQ.initFPGA();
                obj.hAcqEngine = obj.hFpga.hAcqEngine(acquisitionEngineIdx);
                
            elseif isa(hDAQ,'dabs.resources.daqs.NIRIO')
                %this is an fpga!
                obj.isFpga = true;
                obj.hAI = scanimage.components.scan2d.linscan.DataStream('fpga');
                obj.hAI.simulated = obj.hSlmScan.simulated;
                
                secondaryFpgaFifo = false;
                if secondaryFpgaFifo
                    fifoName = 'fifo_LinScanMultiChannelToHostU64';
                else
                    fifoName = 'fifo_MultiChannelToHostU64';
                end
                
                if most.idioms.isValidObj(hDAQ.hFpga)
                    obj.hFpga = hDAQ.hFpga;
                else
                    obj.hFpga = hDAQ.initFPGA();
                end
                
                digitizerType = hDAQ.hAdapterModule.productType;
                
                obj.hAI.setFpgaAndFifo(digitizerType, obj.hFpga.(fifoName), secondaryFpgaFifo, digitizerType);
                
            elseif isa(hDAQ,'dabs.resources.daqs.NIDAQ')
                obj.hAI = scanimage.components.scan2d.linscan.DataStream('daq');
                
                obj.hAI.hTask = most.util.safeCreateTask([obj.hSlmScan.name '-AnalogInput']);
                obj.hAI.hTaskOnDemand = most.util.safeCreateTask([obj.hSlmScan.name '-AnalogInputOnDemand']);
                
                % make sure not more channels are created then there are channels available on the device
                for i=1:obj.hAI.getNumAvailChans(obj.hSlmScan.MAX_NUM_CHANNELS,hDAQ.name,false)
                    obj.hAI.hTask.createAIVoltageChan(hDAQ.name,i-1,sprintf('Imaging-%.2d',i-1),-1,1);
                    obj.hAI.hTaskOnDemand.createAIVoltageChan(hDAQ.name,i-1,sprintf('ImagingOnDemand-%.2d',i-1));
                end
            end
            
            obj.clearAcqParamBuffer();
        end 
    end
    
    methods (Hidden)
        function start(obj)
            assert(~obj.active);
            obj.bufferAcqParams();
            obj.resetCounters();
            obj.active = true;
        end
        
        function trigIssueSoftwareAcq(obj)
            assert(obj.active);
            % start acquisition loop
            obj.acquisitionLoop();
        end
        
        function abort(obj)
            obj.active = false;
        end
        
        function acquisitionLoop(obj)
            lastDrawnow = tic();
            drawNowEveryNSeconds = 0.5;
            sfInfo = obj.acqParamBuffer.sfInfo;
            
            while true
                % prepare buffer for line
                data = zeros(sfInfo.pixelResolutionXY(1),obj.hSlmScan.channelsAvailable,obj.hSlmScan.channelsDataType);
                
                for idx = 1:sfInfo.pixelResolutionXY(1)
                    if toc(lastDrawnow) >= drawNowEveryNSeconds
                        % this is to ensure that ScanImage does not completely
                        % lock up during an acquisition
                        lastDrawnow = tic();
                        drawnow();
                    end
                    
                    if ~obj.active
                        return % check if acquisition was aborted
                    end
                    
                    obj.counters.currentSfSample = obj.counters.currentSfSample + 1;
                    obj.slmPointToSample(obj.counters.currentSfSample+obj.hSlmScan.linePhase); % point SLM to next sample
                    
                    averageNSamples = 10;
                    d = obj.acquireSamples(averageNSamples);
                    data(idx,:) = cast(mean(d,1),'like',d);
                end
                
                data = data(:,obj.acqParamBuffer.channelsActive);
                [I,J] = ind2sub(size(sfInfo.buffer),mod(obj.counters.currentSfSample-1,sfInfo.totalSamples)+1);
                obj.acqParamBuffer.sfInfo.buffer(:,J,:) = data;
                
                % end of line
                
                if obj.acqParamBuffer.bidirectional && mod(obj.counters.currentSfLine,2) == 0
                    obj.acqParamBuffer.sfInfo.buffer(:,J,:) = flip(obj.acqParamBuffer.sfInfo.buffer(:,J,:),1);
                end
                obj.lastStripeData = obj.formStripeData(obj.acqParamBuffer.sfInfo,obj.counters.currentSfLine,sfInfo.zs(obj.counters.currentZIdx));
                obj.counters.currentSfLine = obj.counters.currentSfLine+1;
                
                if ~obj.active
                    return % check if acquisition was aborted
                end
                % callback after every line
                obj.hSlmScan.hLog.logStripe(obj.lastStripeData);
                obj.hSlmScan.stripeAcquiredCallback(obj.hSlmScan,[]);
                
                lastDrawnow = tic();
                drawnow(); % refresh display and process callbacks
                
                if mod(obj.counters.currentSfSample,sfInfo.totalSamples)==0
                    if obj.counters.currentSfSample >= size(obj.acqParamBuffer.waveformOutputPoints,1)
                        obj.counters.currentSfSample = 0;
                    end
                    obj.counters.currentSfLine = 1;
                    obj.counters.currentZIdx = mod(obj.counters.currentZIdx+1-1,length(sfInfo.zs))+1;
                    
                    if obj.counters.currentFrameCounter == obj.hSlmScan.framesPerAcq
                        obj.hSlmScan.abort();
                    else
                        obj.counters.currentFrameCounter = obj.counters.currentFrameCounter + 1;
                    end
                end
            end
        end
        
        function data = acquireSamples(obj,numSamples)
            if nargin < 2 || isempty(numSamples)
                numSamples = 1;
            end
            
            if obj.isVdaq
                data = obj.hAcqEngine.acqStatusRawChannelData();
                data = repmat(data,numSamples,1); %preallocate data of correct size and datatype
                for idx = 2:numSamples
                    data(idx,:) = obj.hAcqEngine.acqStatusRawChannelData();
                end
            else
                data = obj.hAI.acquireSamples(numSamples);
            end
                    
            channelsSign = 1 - 2*obj.hSlmScan.channelsInvert; % -1 for obj.channelsInvert == true, 1 for obj.channelsInvert == false
            channelsSign(end+1:size(data,2)) = 1;
            channelsSign = cast(channelsSign,'like',data);
            data = bsxfun(@times,data,channelsSign);
        end        
        
        function [success, stripeData] = readStripeData(obj)
            success = ~isempty(obj.lastStripeData);
            stripeData = obj.lastStripeData;
            obj.lastStripeData = [];
        end
    end
    
    
    %% Internal Methods
    methods (Hidden)        
        function clearAcqParamBuffer(obj)
            obj.acqParamBuffer = struct();
        end
        
        function updateBufferedOffsets(obj)
            if ~isempty(obj.acqParamBuffer)
                tmpValA = cast(obj.hSlmScan.hSI.hChannels.channelOffset(obj.acqParamBuffer.channelsActive),obj.hSlmScan.channelsDataType);
                tmpValB = cast(obj.hSlmScan.hSI.hChannels.channelSubtractOffset(obj.acqParamBuffer.channelsActive),obj.hSlmScan.channelsDataType);
                channelsOffset = tmpValA .* tmpValB;
                obj.acqParamBuffer.channelsOffset = channelsOffset;
            end
        end
        
        function bufferAcqParams(obj)
            obj.acqParamBuffer = struct(); % flush buffer
            
            obj.acqParamBuffer.channelsActive = obj.hSlmScan.hSI.hChannels.channelsActive;
            obj.acqParamBuffer.channelsSign = cast(1 - 2*obj.hSlmScan.channelsInvert(obj.acqParamBuffer.channelsActive),obj.hSlmScan.channelsDataType); % -1 for obj.channelsInvert == true, 1 for obj.mdfDatachannelsInvert == false
            obj.acqParamBuffer.channelsSign(end+1:obj.hSlmScan.channelsAvailable) = 1;
            obj.acqParamBuffer.waveformOutputPoints = obj.hSlmScan.hSI.hWaveformManager.scannerAO.ao_volts.SLMxyz;
            obj.acqParamBuffer.bidirectional = obj.hSlmScan.hSlm.bidirectionalScan;
            obj.acqParamBuffer.dataType = obj.hSlmScan.channelsDataType;
            
            obj.bufferAllSfParams();
            obj.updateBufferedOffsets();
        end
        
        function resetCounters(obj)
            obj.counters = struct();
            obj.counters.currentSfLine = 1;
            obj.counters.currentZIdx = 1;
            obj.counters.currentSfSample = 0;
            obj.counters.currentFrameCounter = 1;
        end
        
        function zs = bufferAllSfParams(obj)
            roiGroup = obj.hSlmScan.currentRoiGroup;
            assert(length(obj.hSlmScan.currentRoiGroup.rois)==1,'Multi ROI imaging with SLM is currently unsupported');
            assert(length(obj.hSlmScan.currentRoiGroup.rois(1).scanfields)==1,'Multi ROI imaging with SLM is currently unsupported');
            
            % generate slices to scan based on motor position etc
            if obj.hSlmScan.hSI.hStackManager.isSlowZ
                zs = obj.hSlmScan.hSI.hStackManager.zs(obj.hSlmScan.hSI.hStackManager.slicesDone+1);
            else
                zs = obj.hSlmScan.hSI.hStackManager.zs;
            end
            obj.acqParamBuffer.zs = zs;
            
            [scanFields,rois] = roiGroup.scanFieldsAtZ(zs(1));    
            sf = scanFields{1};
            roi = rois{1};
            
            sfInfo = struct();
            sfInfo.scanfield         = sf;
            sfInfo.roi               = roi;
            sfInfo.pixelResolutionXY = sf.pixelResolutionXY;
            sfInfo.totalSamples      = prod(sf.pixelResolutionXY);
            sfInfo.zs                = zs;
            sfInfo.buffer = zeros([sf.pixelResolutionXY,numel(obj.acqParamBuffer.channelsActive)],obj.acqParamBuffer.dataType); % transposed
            
            obj.acqParamBuffer.sfInfo = sfInfo;
        end
        
        function slmPointToSample(obj,sampleNumber)            
            sampleNumber = mod(sampleNumber-1,size(obj.acqParamBuffer.waveformOutputPoints,1))+1;
            currentPoint = obj.acqParamBuffer.waveformOutputPoints(sampleNumber,:);
            obj.hSlmScan.hSlm.pointScanner(currentPoint);
            
            while toc(obj.lastSlmUpdate) < 1/obj.hSlmScan.sampleRate
                % tight loop
                % don't use pause here, since the timing is not precise enough
            end
            obj.lastSlmUpdate = tic();
        end
        
        function stripeData = formStripeData(obj,sfInfo,lineNumber,z)
            stripeData = scanimage.interfaces.StripeData();
            
            stripeData.frameNumberAcqMode = obj.counters.currentFrameCounter;
            stripeData.frameNumberAcq = obj.counters.currentFrameCounter;
            stripeData.acqNumber = 1;               % numeric, number of current acquisition
            stripeData.stripeNumber = lineNumber;   % numeric, number of stripe within the frame
            stripeData.stripesRemaining = 0;
            
            stripeData.startOfFrame = lineNumber==1;% logical, true if first stripe of frame
            stripeData.endOfFrame   = lineNumber==sfInfo.pixelResolutionXY(2); % logical, true if last stripe of frame
            stripeData.endOfAcquisition = stripeData.endOfFrame && (mod(obj.counters.currentFrameCounter,obj.hSlmScan.framesPerAcq)==0); % logical, true if endOfFrame and last frame of acquisition            
            stripeData.endOfAcquisitionMode = stripeData.endOfAcquisition && obj.counters.currentFrameCounter/obj.hSlmScan.framesPerAcq >= obj.hSlmScan.trigAcqNumRepeats; % logical, true if endOfFrame and end of acquisition mode
            stripeData.startOfVolume = false;       % logical, true if start of volume
            stripeData.endOfVolume = false;         % logical, true if start of volume
            stripeData.overvoltage = false;
            
            stripeData.epochAcqMode;                % string, time of the acquisition of the acquisiton of the first pixel in the current acqMode; format: output of datestr(now) '25-Jul-2014 12:55:21'
            stripeData.frameTimestamp;              % [s] time of the first pixel in the frame passed since acqModeEpoch
            
            stripeData.acqStartTriggerTimestamp;
            stripeData.nextFileMarkerTimestamp;
            
            stripeData.channelNumbers = 1;          % 1D array of active channel numbers for the current acquisition
            stripeData.rawData;                     % Raw data samples
            stripeData.rawDataStripePosition;       % Raw data samples start position
            stripeData.roiData{1} = formRoiData();  % 1D cell array of type scanimage.mroi.RoiData
            stripeData.transposed = true;
            
            function roiData = formRoiData()
                roiData = scanimage.mroi.RoiData;
                
                roiData.hRoi = sfInfo.roi;          % handle to roi
                roiData.zs = z;                     % [numeric] array of zs
                roiData.channels = obj.acqParamBuffer.channelsActive;  % [numeric] array of channelnumbers in imageData
                
                roiData.imageData = cell(0,1);
                for idx = 1:length(obj.acqParamBuffer.channelsActive)
                    roiData.imageData{idx}{1} = sfInfo.buffer(:,:,idx) + obj.acqParamBuffer.channelsOffset(idx);
                end
                
                roiData.stripePosition= {[lineNumber lineNumber]}; % cell array of 1x2 start and end line of the current stripe for each z. if empty, current stripe is full frame
                roiData.stripeFullFrameNumLines = [];   % stripeFullFrameNumLines indicates the number of lines in the full frame for each z
                
                roiData.transposed = true;
                roiData.frameNumberAcq = stripeData.frameNumberAcq;
                roiData.frameNumberAcqMode = stripeData.frameNumberAcqMode;
                roiData.frameTimestamp = stripeData.frameTimestamp;
            end
        end
    end
    
    methods
        function val = get.isVdaq(obj)
            val = isa(obj.hSlmScan.hDAQ,'dabs.resources.daqs.vDAQ');
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
