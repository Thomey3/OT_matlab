classdef AcquisitionEngine < dabs.vidrio.rdi.Device
    
    properties
        acqParamChannelOffsets;
        acqParamChannelsInvert;
        
        acqParamDisableDivide;
        
        acqStatusStateMachineState;
        acqStatusRawChannelData;
        acqStatusPeriodTriggerSettled;
        acqStatusPeriodTriggerPeriod;
        
        bitResolution;
    end
    
    properties (Hidden)
        registerMap = initRegs();
        
        LOGICAL_CHANNEL_SOURCES = {'AI0' 'AI1' 'AI2' 'AI3' 'PH0' 'PH1' 'PH2' 'PH3'};
    end

    properties (Dependent)
        HS_MAX_NUM_LOGICAL_CHANNELS;
        MS_MAX_NUM_LOGICAL_CHANNELS;
    end

    properties (Constant, Hidden)
        SIMULATE_HS_MAX_NUM_LOGICAL_CHANNELS = 32;
        SIMULATE_MS_MAX_NUM_LOGICAL_CHANNELS = 8;
    end
    
    %% Lifecycle
    methods
        function obj = AcquisitionEngine(varargin)
            obj = obj@dabs.vidrio.rdi.Device(varargin{:});

            if obj.simulate
                rawSimMaxNumLogicalChannels = uint16([obj.SIMULATE_MS_MAX_NUM_LOGICAL_CHANNELS obj.SIMULATE_HS_MAX_NUM_LOGICAL_CHANNELS]);
                obj.RAW_NUM_LOGICAL_CHANNELS = typecast(rawSimMaxNumLogicalChannels,'uint32');
                obj.NUM_DIVIDERS = uint32(12);
                obj.ACCUM_DIVIDE_SUPPORT = uint32(1);
            end
        end
    end
    
    %% User methods
    methods
        function smReset(obj)
            obj.smCmd = 38;
        end
        
        function smEnable(obj)
            obj.smCmd = 37;
        end
        
        function softStartTrig(obj)
            obj.smCmd = 39;
        end
        
        function softNextTrig(obj)
            obj.smCmd = 40;
        end
        
        function softStopTrig(obj)
            obj.smCmd = 41;
        end
        
        function writeAcqPlan(obj,addr,newEntry,frameClockState,numPeriods)
            validateattributes(addr,{'numeric'},{'scalar','nonnegative','integer'});
            assert(addr<4096,'Acquisition plan BRAM overflow');
            
            validateattributes(newEntry,{'numeric','logical'},{'scalar','binary'});
            validateattributes(numPeriods,{'numeric'},{'scalar','nonnegative','integer'});
            
            if newEntry
                assert(numPeriods<2^7,'Error writing Acquisition plan: value of ''numPeriods'' for a new entry must be smaller than 127. Actual value: %d',numPeriods);
                validateattributes(frameClockState,{'numeric','logical'},{'scalar','binary'});
                v = uint32(2^8) + uint32(frameClockState*2^7) + uint32(bitand(numPeriods,2^7-1));
            else
                assert(numPeriods<2^8,'Error writing Acquisition plan: value of ''numPeriods'' for a follow-up entry must be smaller than 256. Actual value: %d',numPeriods);
                v = uint32(bitand(numPeriods,2^8-1));
            end
            
            v = v + uint32(addr * 2^9);
            
            obj.acqPlanWriteReg = v;
        end
        
        function writeMaskTable(obj,addr,val)
            accumBits = 12;
            v = uint32(addr*2^accumBits) + uint32(bitand(val,2^accumBits-1));
            obj.maskTableWriteReg = v;
        end
        
        function setLogicalChannelSource(obj,channel,src)
            obj.logicalChannelSettingsIdx = channel-1;
            
            [tf,idx] = ismember(upper(src),obj.LOGICAL_CHANNEL_SOURCES);
            assert(tf,'Invalid logical channel source.');
            obj.logicalChannelSettingsReg = uint32(bitand(idx-1,63));
        end
        
        function s = getLogicalChannelSettings(obj,channel)
            obj.logicalChannelSettingsIdx = channel-1;
            v = obj.logicalChannelSettingsReg;
            tv = typecast(v,'int16');
            
            srcInd = bitand(v,63)+1;
            N = numel(obj.LOGICAL_CHANNEL_SOURCES);
            s.source = obj.LOGICAL_CHANNEL_SOURCES{mod(srcInd-1,N)+1};
            
            modes = {'analog' 'photon counting'};
            s.mode = modes{1+(srcInd>N)};
            
            s.threshold = logical(bitget(v,7));
            s.binarize = logical(bitget(v,8));
            s.edgeDetect = logical(bitget(v,9));
            s.laserGate = logical(bitget(v,10));
            s.downshift = logical(bitget(v,11));
            s.thresholdValue = tv(2);
        end
        
        function setLogicalChannelSettings(obj,channel,settings)
            obj.logicalChannelSettingsIdx = channel-1;
            
            [tf,idx] = ismember(upper(settings.source),obj.LOGICAL_CHANNEL_SOURCES);
            assert(tf,'Invalid logical channel source.');
            
            idx = idx + numel(obj.LOGICAL_CHANNEL_SOURCES) * strcmp(settings.mode, 'photon counting');
            
            v = uint32(bitand(idx-1,63));
            v = v + 2^6  * logical(settings.threshold);
            v = v + 2^7  * logical(settings.binarize);
            v = v + 2^8  * logical(settings.edgeDetect);
            v = v + 2^9  * logical(settings.laserGate);
            v = v + 2^10 * logical(settings.downshift);
            
            v = v + 2^16 * typecast([int16(settings.thresholdValue) 0],'uint32');
            
            obj.logicalChannelSettingsReg = v;
        end
        
        function window = getLogicalChannelFilterWindowSettings(obj,channel)
            obj.logicalChannelSettingsIdx = channel-1;
            window = typecast(obj.logicalChannelFilterWindowReg,'uint16');
        end
        
        function setLogicalChannelFilterWindowSettings(obj,channel,window)
            obj.logicalChannelSettingsIdx = channel-1;
            obj.logicalChannelFilterWindowReg = typecast(uint16(window),'uint32');
        end
    end
    
    %% Prop Access
    methods
        function v = get.acqParamChannelOffsets(obj)
            r1 = obj.acqParamChannelOffsetsReg1;
            r2 = obj.acqParamChannelOffsetsReg2;
            
            v = [typecast(r1,'int16') typecast(r2,'int16')];
            v = v/obj.hRootObj.rawValScale;
        end
        
        function set.acqParamChannelOffsets(obj,v)
            v(end+1:4) = 0;
            v = round(v*obj.hRootObj.rawValScale);
            obj.acqParamChannelOffsetsReg1 = typecast(int16(v(1:2)),'uint32');
            obj.acqParamChannelOffsetsReg2 = typecast(int16(v(3:4)),'uint32');
        end
        
        function v = get.acqParamChannelsInvert(obj)
            v = obj.acqParamChannelsInvertReg;
            mask = cast(2.^(0:3),'like',v);
            v = logical(bitand(v,mask));
        end
        
        function set.acqParamChannelsInvert(obj,val)
            v = uint32(val(1));
            for c = 2:numel(val)
                v = bitor(v,(2^(c-1))*val(c));
            end
            obj.acqParamChannelsInvertReg = v;
            
            obj.hRootObj.hsPhotonInvertReg = v;
        end
        
        function v = get.acqStatusRawChannelData(obj)
            r1 = obj.acqStatusRawChannelDataReg1;
            r2 = obj.acqStatusRawChannelDataReg2;
            
            v = [typecast(r1,'int16') typecast(r2,'int16')];
        end
        
        function v = get.acqStatusStateMachineState(obj)
            v = obj.acqStatusStateMachineStateReg;
            
            states = {'idle' 'wait for trigger' 'acquire' 'linear aquire'};
            v = states{v+1};
        end
        
        function v = get.acqStatusPeriodTriggerSettled(obj)
            v = logical(bitand(obj.acqStatusPeriodTriggerInfo, 2^31));
        end
        
        function v = get.acqStatusPeriodTriggerPeriod(obj)
            v = double(bitand(obj.acqStatusPeriodTriggerInfo, 2^18-1));
        end
        
        function v = get.bitResolution(obj)
            v = 16;
        end
        
        function v = get.acqParamDisableDivide(obj)
            v = obj.acqParamDisableDivideReg;
            mask = cast(2.^(0:min(obj.HS_MAX_NUM_LOGICAL_CHANNELS-1,31)),'like',v);
            v = logical(bitand(v,mask));
            v(min(end+1,obj.NUM_DIVIDERS+1):obj.HS_MAX_NUM_LOGICAL_CHANNELS) = true;
        end
        
        function set.acqParamDisableDivide(obj,v)
            val = logical(v);
%             assert(all(find(~val) < obj.NUM_DIVIDERS), 'Divider must be disabled for all channels over %d.', obj.NUM_DIVIDERS);
            v = uint32(val(1));
            for c = 2:min(numel(val),32)
                v = bitor(v,(2^(c-1))*val(c));
            end
            obj.acqParamDisableDivideReg = v;
        end

        function v = get.HS_MAX_NUM_LOGICAL_CHANNELS(obj)
            raw = typecast(obj.RAW_NUM_LOGICAL_CHANNELS,'uint16');
            v = raw(2);
        end

        function v = get.MS_MAX_NUM_LOGICAL_CHANNELS(obj)
            raw = typecast(obj.RAW_NUM_LOGICAL_CHANNELS,'uint16');
            v = raw(1);
        end
    end
end

function s = initRegs()
    s.cmdRegs.smCmd = struct('address',100,'hide',true);
    
    s.dataRegs.RAW_NUM_LOGICAL_CHANNELS = struct('address',8,'hide',true);
    s.dataRegs.HSADC_SUPPORT = struct('address',12,'hide',true);
    s.dataRegs.FIFO_MAX_WIDTH_BYTES = struct('address',16,'hide',true);
    s.dataRegs.SUPPORTS_VARIABLE_FIFO = struct('address',20,'hide',true);
    s.dataRegs.NUM_DIVIDERS = struct('address',24,'hide',true);
    s.dataRegs.ACCUM_DIVIDE_SUPPORT = struct('address',28,'hide',true);
    s.dataRegs.HSADC_LRR_SUPPORT = struct('address',32,'hide',true);
    
    s.dataRegs.acqPlanWriteReg = struct('address',104,'hide',true);
    s.dataRegs.acqPlanNumSteps = struct('address',108);
    
    s.dataRegs.maskTableWriteReg = struct('address',112,'hide',true);
    s.dataRegs.maskTableSize = struct('address',116);
    
    s.dataRegs.acqParamPeriodTriggerChIdx = struct('address',120);
    s.dataRegs.acqParamStartTriggerChIdx = struct('address',124);
    s.dataRegs.acqParamNextTriggerChIdx = struct('address',128);
    s.dataRegs.acqParamStopTriggerChIdx = struct('address',132);
    s.dataRegs.acqParamStartTriggerInvert = struct('address',292);
    s.dataRegs.acqParamNextTriggerInvert = struct('address',296);
    s.dataRegs.acqParamStopTriggerInvert = struct('address',300);
    s.dataRegs.acqParamPhotonChIdx = struct('address',136);
    s.dataRegs.acqParamPeriodTriggerDebounce = struct('address',140);
    s.dataRegs.acqParamTriggerDebounce = struct('address',144);
    s.dataRegs.acqParamLiveHoldoffAdjustEnable = struct('address',148);
    s.dataRegs.acqParamLiveHoldoffAdjustPeriod = struct('address',152);
    s.dataRegs.acqParamTriggerHoldoff = struct('address',156);
    s.dataRegs.acqParamChannelsInvertReg = struct('address',160,'hide',true);
    s.dataRegs.acqParamSamplesPerLine = struct('address',168);
    s.dataRegs.acqParamVolumesPerAcq = struct('address',172);
    s.dataRegs.acqParamTotalAcqs = struct('address',176);
    s.dataRegs.acqParamBeamClockAdvance = struct('address',180);
    s.dataRegs.acqParamBeamClockDuration = struct('address',184);
    s.dataRegs.acqParamDummyVal = struct('address',188);
    s.dataRegs.acqParamDisableDivideReg = struct('address',192,'hide',true);
    s.dataRegs.acqParamScalePower = struct('address',196);
    s.dataRegs.acqParamEnableBidi = struct('address',200);
    s.dataRegs.acqParamPhotonPulseDebounce = struct('address',204);
    s.dataRegs.acqParamMaskLSBs = struct('address',208);
    s.dataRegs.acqParamEnableLineTag = struct('address',164);
    
    s.dataRegs.acqParamAuxTriggerEnable = struct('address',232);
    s.dataRegs.acqParamAuxTrig1TriggerChIdx = struct('address',212);
    s.dataRegs.acqParamAuxTrig2TriggerChIdx = struct('address',216);
    s.dataRegs.acqParamAuxTrig3TriggerChIdx = struct('address',220);
    s.dataRegs.acqParamAuxTrig4TriggerChIdx = struct('address',224);
    s.dataRegs.acqParamAuxTriggerDebounce = struct('address',228);
    s.dataRegs.acqParamAuxTriggerInvert = struct('address',288);
    
    s.dataRegs.logicalChannelSettingsIdx = struct('address',312);
    s.dataRegs.logicalChannelSettingsReg = struct('address',316,'hide',true);
    s.dataRegs.acqParamLaserClkChIdx = struct('address',304);
    s.dataRegs.acqParamLaserClkDebounce = struct('address',308);
    s.dataRegs.logicalChannelFilterWindowReg = struct('address',320,'hide',true);
    
    s.dataRegs.acqParamPeriodTriggerMaxPeriod = struct('address',236);
    s.dataRegs.acqParamPeriodTriggerMinPeriod = struct('address',368);
    s.dataRegs.acqParamPeriodTriggerSettledThresh = struct('address',240);
    s.dataRegs.acqParamSimulatedResonantPeriod = struct('address',284);
    s.dataRegs.acqParamPeriodTriggerSettledGate = struct('address',372);
    
    s.dataRegs.acqParamSampleClkPulsesPerPeriod = struct('address',324);
    s.dataRegs.acqParamLinearSampleClkPulseDuration = struct('address',328);
    
    s.dataRegs.acqParamLinearMode = struct('address',260);
    s.dataRegs.acqParamLinearFramesPerVolume = struct('address',264);
    s.dataRegs.acqParamLinearFrameClkHighTime = struct('address',268);
    s.dataRegs.acqParamLinearFrameClkLowTime = struct('address',272);
    s.dataRegs.acqParamUniformSampling = struct('address',276);
    s.dataRegs.acqParamUniformBinSize = struct('address',280);
    
    s.dataRegs.acqParamChannelOffsetsReg1 = struct('address',340,'hide',true);
    s.dataRegs.acqParamChannelOffsetsReg2 = struct('address',344,'hide',true);
    
    s.dataRegs.i2cEnable = struct('address',348,'hide',true);
    s.dataRegs.i2cDebounce = struct('address',352,'hide',true);
    s.dataRegs.i2cAddress = struct('address',356,'hide',true);
    s.dataRegs.i2cSdaPort = struct('address',360,'hide',true);
    s.dataRegs.i2cSclPort = struct('address',364,'hide',true);
    
    s.dataRegs.acqParamDataFifoWriteWidth1 = struct('address',244,'hide',true);
    s.dataRegs.acqParamDataFifoWriteWidth2 = struct('address',248,'hide',true);
    
    s.dataRegs.acqStatusPeriodTriggerInfo = struct('address',400,'hide',true);
    s.dataRegs.acqStatusDataFifoOverflowCount = struct('address',404);
    s.dataRegs.acqStatusAuxFifoOverflowCount = struct('address',408);
    s.dataRegs.acqStatusStateMachineStateReg = struct('address',412,'hide',true);
    s.dataRegs.acqStatusVolumesDone = struct('address',416);
    
    s.dataRegs.acqStatusRawChannelDataReg1 = struct('address',500,'hide',true);
    s.dataRegs.acqStatusRawChannelDataReg2 = struct('address',504,'hide',true);

    % TODO: set this register when mixed lasergating is enabled
    s.dataRegs.acqParamEnableMixedLasergating = struct('address',252,'hide',true);
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
