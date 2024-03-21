classdef vDAQ_SI < dabs.vidrio.rdi.Device
    
    properties
        hClockCfg;
        
        hAfe;
        hMsadc;
        hHsadc;
        
        hAcqEngine;
        
        fifo_MultiChannelToHostU64;
        fifo_AuxDataToHostU64;
        
        hScopeFifo;
        
        hWaveGen;
        hWaveAcq;
        hDigitalWaveGen;
    end
    
    properties
        dataClkRate;
        systemClock;
        
        pwmMeasChan;
        pwmPeriod;
        pwmPulseWidth;
        
        meanBufferDelay;
        
        hsPhotonThresholds;
        hsPhotonInverts;
        hsPhotonDifferentiate;
        hsPhotonDifferentiateWidths;
    end

    properties (SetObservable)
        syncTrigPhaseAdjust
        laserClkPeriodSamples
    end
    
    properties (Hidden)
        bitfilePath;
        isR1 = false;
        initialized = false;
        
        nominalAcqSampleRate;
        nominalDataClkRate;
        
        spclOutputSignals = {};
        spclTriggerSignals = {};
        dioInputOptions = {};
        dioOutputOptions = {};
        
        internalClockSourceRate;
        rawValScale = 1;
    end
    
    properties (Constant, Hidden)
        waveformTimebaseRate = 200e6;
        DIO_SPCL_OUTPUTS = {'si%d_pixelClk' 'si%d_acqClk' 'si%d_lineClk' 'si%d_beamClk' 'si%d_roiClk' 'si%d_sliceClk' 'si%d_volumeClk' 'si%d_ctlSampleClk' 'si%d_i2cAck'};
        WFM_SPCL_TRIGGERS = {'si%d_beamClk' 'si%d_roiClk' 'si%d_sliceClk' 'si%d_volumeClk' 'si%d_ctlSampleClk'};
    end
    
    %% Lifecycle
    methods
        function obj = vDAQ_SI(dev,simulate)
            if nargin < 2
                simulate = false;
            end
            
            obj = obj@dabs.vidrio.rdi.Device(dev,0,simulate);
            
            scanimage.fpga.vDAQ_SI.checkHardwareSupport();
        end
        
        function s = getRegMap(obj)
            obj.isR1 = obj.simulate || (obj.deviceInfo.hardwareRevision > 0);
            
            s.dataRegs.T = struct('address',4194304+0);
            s.dataRegs.ledReg = struct('address',4194304+20,'hide',true);
            s.dataRegs.dataClkCount = struct('address',4194304+4,'hide',true);
            
            s.dataRegs.systemClockL = struct('address',4194304+8,'hide',true);
            s.dataRegs.systemClockH = struct('address',4194304+12,'hide',true);
            s.dataRegs.NUM_AE = struct('address',4194304+16,'hide',true);
            
            s.dataRegs.dio_i = struct('address',4194304+24);
            s.dataRegs.rtsi_i = struct('address',4194304+28);
            
            s.dataRegs.pwmMeasChanReg = struct('address',4194304+92,'hide',true);
            s.dataRegs.pwmMeasDebounce = struct('address',4194304+96);
            s.dataRegs.pwmMeasPeriodMax = struct('address',4194304+100);
            s.dataRegs.pwmMeasPeriodReg = struct('address',4194304+104,'hide',true);
            s.dataRegs.pwmMeasHighTimeReg = struct('address',4194304+108,'hide',true);
            
            s.dataRegs.sysClk200_en = struct('address',4194304+36,'hide',true);
            s.dataRegs.sysClk100_en = struct('address',4194304+40,'hide',true);
            s.dataRegs.ioClk_en = struct('address',4194304+48,'hide',true);
            s.dataRegs.ioClk40_en = struct('address',4194304+52,'hide',true);
            s.dataRegs.adcSpiClkOut_en = struct('address',4194304+56,'hide',true);
            s.dataRegs.dacSpiClkOut_en = struct('address',4194304+60,'hide',true);
            s.dataRegs.afeSelect = struct('address',4194304+32,'hide',true);
            
            s.dataRegs.scopeCmd = struct('address',4194304+140);
            s.dataRegs.scopeParamFifoWriteWidth = struct('address',4194304+144);
            s.dataRegs.scopeParamNumberOfSamples = struct('address',4194304+156);
            s.dataRegs.scopeParamDecimationLB2 = struct('address',4194304+160);
            s.dataRegs.scopeParamTriggerId = struct('address',4194304+164);
            s.dataRegs.scopeParamTriggerHoldoff = struct('address',4194304+168);
            s.dataRegs.scopeParamAeSel = struct('address',4194304+172);
            s.dataRegs.scopeParamTriggerLineNumber = struct('address',4194304+192);
            s.dataRegs.scopeParamPh = struct('address',4194304+84,'hide',true);
            
            s.dataRegs.scopeStatusWriteCount = struct('address',4194304+148);
            s.dataRegs.scopeStatusFifoOverflowCount = struct('address',4194304+152);
            
            s.dataRegs.hsPhotonThresholdReg = struct('address',4194304+72,'hide',true);
            s.dataRegs.hsPhotonInvertReg = struct('address',4194304+76,'hide',true);
            s.dataRegs.hsPhotonDifferentiateReg = struct('address',4194304+80,'hide',true);
            s.dataRegs.hsPhotonDifferentiateWidthReg = struct('address',4194304+112,'hide',true);
            
            if obj.isR1
                s.dataRegs.ioClk_oxen = struct('address',4194304+44,'hide',true);
                s.dataRegs.syncTriggerReset = struct('address',4194304+68,'hide',true);
                s.dataRegs.scopeParamHsChanSel = struct('address',4194304+176);
                s.dataRegs.hsSyncTrigPhaseShift = struct('address',4194304+180,'hide',true);
                s.dataRegs.hsSyncTrigIgnorePhysical = struct('address',4194304+184);
                s.dataRegs.laserClkPeriodSamplesReg = struct('address',4194304+188,'hide',true);
                s.dataRegs.SAMPLE_PHASE_BITS = struct('address',4194304+196,'hide',true);
            else
                s.dataRegs.moduleId = struct('address',4194304+64,'hide',true);
            end
            
            ndio = 39 + 8*obj.isR1;
            for i = 0:ndio
                s.dataRegs.(['digital_o_' num2str(i)]) = struct('address',4194304+200+i*4,'hide',true);
            end
        end
        
        function delete(obj)
            delete(obj.hWaveGen);
            delete(obj.hWaveAcq);
            delete(obj.hDigitalWaveGen);
            
            delete(obj.fifo_MultiChannelToHostU64);
            delete(obj.fifo_AuxDataToHostU64);
            delete(obj.hScopeFifo);
            
            delete(obj.hAcqEngine);
            obj.delete@dabs.vidrio.rdi.Device;
        end
    end
    
    %% User methods
    methods
        function loadDesign(obj,varargin)
            if nargin > 1
                obj.loadDesign@dabs.vidrio.rdi.Device(varargin{:});
            else
                if ~obj.deviceInfo.designLoaded
                    obj.loadInitialDesign();
                end
                
                if isempty(obj.bitfilePath)
                    bfPath = fullfile(fileparts(which(mfilename('fullpath'))),'bitfiles');
                    hwName = sprintf('vDAQR%d_', obj.deviceInfo.hardwareRevision);
                    obj.bitfilePath = fullfile(bfPath, [hwName 'SI.dbs']);
                end
                
                obj.loadDesign@dabs.vidrio.rdi.Device(obj.bitfilePath);
                
                obj.writeRegU32(5504,37100);
                obj.resetAfeProps();
                obj.initializeDesign();
            end
        end
        
        function initializeDesign(obj)
            if ~obj.initialized
                obj.hClockCfg = dabs.vidrio.vDAQ.ClkCfg(obj,'440000');
                obj.hMsadc = dabs.vidrio.vDAQ.Msadc(obj,'460000');
                
                obj.fifo_MultiChannelToHostU64 = dabs.vidrio.rdi.Fifo(obj,'480000');
                obj.fifo_AuxDataToHostU64 = dabs.vidrio.rdi.Fifo(obj,'481000');
                obj.hScopeFifo = dabs.vidrio.rdi.Fifo(obj,'482000');
                
                obj.hAcqEngine = scanimage.fpga.AcquisitionEngine(obj,4194304+1024);
                obj.spclOutputSignals = cellfun(@(s){sprintf(s,0)},obj.DIO_SPCL_OUTPUTS);
                obj.spclTriggerSignals = cellfun(@(s){sprintf(s,0)},obj.WFM_SPCL_TRIGGERS);
                
                if obj.isR1
                    if obj.simulate || (obj.NUM_AE > 1)
                        obj.hAcqEngine(2) = scanimage.fpga.AcquisitionEngine(obj,4194304+2048);
                        obj.fifo_MultiChannelToHostU64(2) = dabs.vidrio.rdi.Fifo(obj,'483000');
                        obj.fifo_AuxDataToHostU64(2) = dabs.vidrio.rdi.Fifo(obj,'484000');
                    end
                    
                    if obj.simulate || (obj.NUM_AE > 1)
                        obj.spclOutputSignals = [obj.spclOutputSignals cellfun(@(s){sprintf(s,1)},obj.DIO_SPCL_OUTPUTS)];
                        obj.spclTriggerSignals = [obj.spclTriggerSignals cellfun(@(s){sprintf(s,1)},obj.WFM_SPCL_TRIGGERS)];
                    end
                    
                    obj.hHsadc = dabs.vidrio.vDAQ.Hsadc(obj,'470000');
                    
                    obj.addprop('hLsadc');
                    obj.hLsadc = dabs.vidrio.vDAQ.Lsadc(obj,'0');
                    
                    nadc = 12;
                    ndac = 12;
                    
                    inPorts = [0 1 2];
                    outPorts = [0 1 3];
                else
                    nadc = 4;
                    ndac = 5;
                    
                    inPorts = [0 1];
                    outPorts = [0 2];
                end
                
                p = arrayfun(@(p){arrayfun(@(i){sprintf('D%d.%d',p,i)},0:7)},inPorts);
                obj.dioInputOptions = [p{:}];
                p = arrayfun(@(p){arrayfun(@(i){sprintf('D%d.%d',p,i)},0:7)},outPorts);
                obj.dioOutputOptions = [p{:}];
                
                a = arrayfun(@(a){dabs.vidrio.ddi.rdi.ip.SlowWaveformAcq(obj,a)}, 5242880:65536:(5242880 + (nadc-1)*65536));
                obj.hWaveAcq = [a{:}];
                
                a = arrayfun(@(a){dabs.vidrio.ddi.rdi.ip.SlowWaveformGen(obj,a)}, 6291456:65536:(6291456 + (ndac-1)*65536));
                obj.hWaveGen = [a{:}];
                
                a = arrayfun(@(a){dabs.vidrio.ddi.rdi.ip.DigitalWaveformGen(obj,a)}, 3145728:65536:(3145728 + 3*65536));
                obj.hDigitalWaveGen = [a{:}];
                
                obj.initialized = true;
            end
        end
        
        function loadInitialDesign(obj)
            bfPath = fullfile(fileparts(which(mfilename('fullpath'))),'bitfiles');
            hwName = sprintf('vDAQR%d_', obj.deviceInfo.hardwareRevision);
            obj.loadDesign(fullfile(bfPath, [hwName 'Firmware.dbs']));
        end
        
        function resetAfeProps(obj)
            obj.hAfe = [];
            obj.nominalDataClkRate = [];
            obj.nominalAcqSampleRate = [];
        end
        
        function run(obj)
            if ~obj.simulate
                obj.loadDesign();
            else
                obj.initializeDesign();
            end
        end
        
        function configureAfeSampleClock(obj,clockSource,sourceClockRate,desiredSampleClockRate,passive)
            if nargin < 2 || isempty(clockSource)
                clockSource = 'internal';
            end
            if nargin < 3
                sourceClockRate = obj.internalClockSourceRate;
            end
            if nargin < 4
                desiredSampleClockRate = [];
            end
            if nargin < 5
                passive = false;
            end
            
            if obj.simulate
                obj.nominalAcqSampleRate = obj.internalClockSourceRate;
                obj.nominalDataClkRate = obj.nominalAcqSampleRate;
                obj.hAfe = obj.hMsadc;
            else
                switch obj.moduleId
                    case 1
                        obj.configureMsadc(clockSource, sourceClockRate, desiredSampleClockRate, passive);
                        
                    case 2
                        obj.configureHsadc(clockSource, sourceClockRate, desiredSampleClockRate, passive);
                        
                    otherwise
                        error('Unsupported analog module');
                end
            end
        end
        
        function l = checkPll(obj)
            l = obj.hClockCfg.checkPll();
            
            if ~nargout
                if ~l
                    app = 'n''t';
                else
                    app = '';
                end
                disp(['Was' app ' locked..']);
            end
        end
        
        function lockPll(obj)
            l = obj.hClockCfg.lockPll();
            assert(l, 'FPGA clocking error');
        end
        
        function configureSyncTrig(obj,clkPhyMode,D)
            obj.syncTriggerReset = 1;
            
            if clkPhyMode == 0.5
                clkOutPhyVal = 2;
            else
                clkOutPhyVal = 1;
            end
            
            hiLoTime = D/2;
            
            pv = obj.readSyncTriggerPllDrp('0B');
            pv = setbits(pv,13:14,clkOutPhyVal);
            obj.writeSyncTriggerPllDrp('0B',pv);
            
            pv = obj.readSyncTriggerPllDrp('08');
            pv = setbits(pv,0:5,hiLoTime);
            pv = setbits(pv,6:11,hiLoTime);
            obj.writeSyncTriggerPllDrp('08',pv);
            
            obj.syncTriggerReset = 0;
        end
        
        function dataOut = readSyncTriggerPllDrp(obj, addr)
            if ischar(addr)
                addr = hex2dec(addr);
            end
            assert(logical(bitget(obj.syncTriggerStatus,8)), 'PLL DRP not ready.');
            
            obj.syncTriggerControl = typecast(uint16([addr 0]),'uint32');
            assert(logical(bitget(obj.syncTriggerStatus,8)), 'PLL command did not complete.');
            
            dataOut = obj.syncTriggerData;
        end
        
        function dataOut = writeSyncTriggerPllDrp(obj, addr, data)
            if ischar(addr)
                addr = hex2dec(addr);
            end
            if ischar(data)
                data = hex2dec(data);
            end
            assert(logical(bitget(obj.syncTriggerStatus,8)), 'PLL DRP not ready.');
            
            obj.syncTriggerControl = typecast(uint16([addr data]),'uint32');
            obj.syncTriggerStatus = 45873;
            assert(logical(bitget(obj.syncTriggerStatus,8)), 'PLL command did not complete.');
            
            dataOut = obj.syncTriggerData;
        end
        
        function configureMsadc(obj, clockSource, sourceClockRate, desiredSampleClockRate, passive)
            if nargin < 5
                passive = false;
            end
            
            if strcmp(clockSource, 'internal')
                assert(isempty(sourceClockRate) || isnan(sourceClockRate) || (sourceClockRate == obj.internalClockSourceRate), 'Invalid source clock rate for internal clock source.');
                sourceClockRate = obj.internalClockSourceRate;
            end
            if isempty(desiredSampleClockRate)
                desiredSampleClockRate = sourceClockRate;
            end
            assert(desiredSampleClockRate <= 125e6, 'Maximum sample rate is 125 MHz. Adjust external clock frquency and/or multiplier.');
            
            if ~passive
                % power down the ADC before setting up the clock, otherwise it can initialize incorrectly
                % and produce lots of invalid samples in the digitizer
                obj.hMsadc.adcPowerDwn = true;
                obj.hClockCfg.setupClk(clockSource, sourceClockRate, desiredSampleClockRate, [1 nan nan nan], true, obj.isR1);
                obj.hMsadc.adcPowerDwn = false;
                
                if ~obj.isR1
                    obj.hClockCfg.ch1Mute = 1;
                    obj.hClockCfg.ch0Mute = 0;
                    obj.hClockCfg.writeSettingsToDevice(8,8);
                end
                pause(0.1);
                
                obj.hMsadc.configurePllForClkRate(obj.nominalAcqSampleRate);
                
                if obj.isR1
                    obj.afeSelect = 0;
                    obj.configureSyncTrig(0.5,8);
                end
                pause(0.01);
                
                obj.initMsadc();
            end
            
            obj.nominalAcqSampleRate = desiredSampleClockRate;
            obj.nominalDataClkRate = obj.nominalAcqSampleRate;
            
            obj.rawValScale = 1;
            obj.hAfe = obj.hMsadc;
        end
        
        function initMsadc(obj)
            st = tic;
            while true
                try
                    obj.hMsadc.resetAcqEngine();
                    pause(0.01);
                    obj.verifyMsadcData();
                    break;
                catch ME
                    if toc(st) < 1
                        continue
                    else
                        ME.rethrow();
                    end
                end
            end
        end
        
        function verifyMsadcData(obj)
            assert(~isinf(obj.dataClkRate) && ~isnan(obj.dataClkRate),'Analog front end sample clock not running')
            
            obj.hMsadc.usrReqTestPattern = 1;
            inv = obj.hAcqEngine(1).acqParamChannelsInvertReg;
            obj.hAcqEngine(1).acqParamChannelsInvertReg = 0;
            
            try
                for i=1:100
                    assert(all(obj.hAcqEngine(1).acqStatusRawChannelData(:) == 24160),'Analog front end data error.');
                end
            catch ME
                obj.hAcqEngine(1).acqParamChannelsInvertReg = inv;
                obj.hMsadc.usrReqTestPattern = 0;
                ME.rethrow();
            end
            
            obj.hAcqEngine(1).acqParamChannelsInvertReg = inv;
            obj.hMsadc.usrReqTestPattern = 0;
        end
        
        function actualPhase_deg = setMsadcSamplingPhase(obj, phase_deg)
            assert(obj.hAfe == obj.hMsadc, 'MSADC must be initialized first.');
            assert(obj.isR1, 'Feature not supported by hardware.');

            % power down the ADC before adjusting the clock phase, otherwise it can initialize incorrectly
            % and produce lots of invalid samples in the digitizer
            obj.hMsadc.adcPowerDwn = true;
            [~, actualPhase_deg] = obj.hClockCfg.setClkPhase(1, phase_deg);
            obj.hMsadc.adcPowerDwn = false;
            obj.initMsadc();
        end
        
        function phaseStep_deg = getMsadcSamplingPhaseStep(obj)
            assert(obj.hAfe == obj.hMsadc, 'MSADC must be initialized first.');
            assert(obj.isR1, 'Feature not supported by hardware.');
            phaseStep_deg = obj.hClockCfg.getClkPhaseStep(1);
        end
        
        function actualDelay_ps = setMsadcSamplingDelay(obj, delay_ps)
            assert(obj.hAfe == obj.hMsadc, 'MSADC must be initialized first.');
            assert(obj.isR1, 'Feature not supported by hardware.');
            
            phase_deg = 360 * (delay_ps * 1e-12) * obj.nominalAcqSampleRate;
            
            [~, actualPhase_deg] = obj.hClockCfg.setClkPhase(1, phase_deg);
            obj.initMsadc();
            
            actualDelay_ps = 1e12 * (actualPhase_deg / 360) / obj.nominalAcqSampleRate;
        end
        
        function delayStep_ps = getMsadcSamplingDelayStep(obj)
            assert(obj.hAfe == obj.hMsadc, 'MSADC must be initialized first.');
            assert(obj.isR1, 'Feature not supported by hardware.');
            phaseStep_deg = obj.hClockCfg.getClkPhaseStep(1);
            delayStep_ps = 1e12 * (phaseStep_deg/360) / obj.nominalAcqSampleRate;
        end
        
        function configureHsadc(obj, clockSource, sourceClockRate, desiredSampleClockRate, passive)
            if nargin < 5
                passive = false;
            end
            
            if strcmp(clockSource, 'internal')
                assert(isempty(sourceClockRate) || isnan(sourceClockRate) || (sourceClockRate == obj.internalClockSourceRate), 'Invalid source clock rate for internal clock source.');
                sourceClockRate = obj.internalClockSourceRate;
            end
            if isempty(desiredSampleClockRate)
                desiredSampleClockRate = 2.5e9;
            end
            assert(desiredSampleClockRate <= 2.7e9, 'Maximum sample rate is 2.7 GHz. Adjust external clock frquency and/or multiplier.');
            
            if ~passive
                % core clk is constrained to 270 MHz in current FPGA build
                % which means 14 bit mode can only be used up to 2160 MSPS. for
                % now we will always force 12 bit mode to on
                obj.hHsadc.configure(clockSource,sourceClockRate,desiredSampleClockRate,1:2,true);
                
                obj.afeSelect = 1;
                obj.configureSyncTrig(1,4);
                
                obj.meanBufferDelay = mean(obj.hHsadc.jesdBufferDelay);
                obj.syncTrigPhaseAdjust = obj.syncTrigPhaseAdjust;
            else
                obj.meanBufferDelay = mean(obj.hHsadc.jesdBufferDelay);
            end
                
            obj.nominalAcqSampleRate = desiredSampleClockRate;
            obj.nominalDataClkRate = obj.nominalAcqSampleRate/32;
            
            obj.hAfe = obj.hHsadc;
            obj.rawValScale = 1/16;

            obj.hsSyncTrigIgnorePhysical = true;
        end
        
        function val = getChannelsInputRanges(obj)
            val = obj.hAfe.getChannelsInputRanges();
        end
        
        function val = setChannelsInputRanges(obj,val)
            val = obj.hAfe.setChannelsInputRanges(val);
        end
        
        function val = getChannelsFilter(obj)
            val = obj.hAfe.getChannelsFilter();
        end
        
        function val = setChannelsFilter(obj,val)
            obj.hAfe.setChannelsFilter(val);
        end
        
        function [id, port, line] = dioNameToId(obj,ch)
            if isempty(ch)
                id = 63;
                line = NaN;
                port = NaN;
                return
            end
            
            if isprop(ch,'name')
                ch = ch.name;
            end
            
            ch = regexpi(ch,'[^\/]+$','match','once'); % reduce /vDAQ0/D0.0 to D0.0
            
            if strncmpi(ch,'rtsi',4)
                line = str2double(ch(5:end));
                id = 24 + 8*obj.isR1 + line;
                assert(id < (40 + 8*obj.isR1), 'Invalid RTSI channel ID.');
                port = 'r';
            else
                [~,~,~,~,results] = regexpi(ch,'^D(.)\.(.)');
                assert(numel(results) == 1,'Invalid channel ID.');
                
                port = str2double(results{1}{1});
                line = str2double(results{1}{2});
                
                assert((port >= 0) && (port <= (2 + obj.isR1)),'Invalid channel ID.');
                assert((line >= 0) && (line <= 7),'Invalid channel ID.');
                
                id = port * 8 + line;
            end
        end
        
        function chId = digitalNameToOutputId(obj,ch,suppressOutputPortError)
            chId = obj.dioNameToId(ch);
            assert((chId < 8*(1+obj.isR1)) || (chId >= 8*(2+obj.isR1)) || suppressOutputPortError,...
                'Cannot use digital port %d for outputs.', 1+obj.isR1);
        end
        
        function chId = setDioOutput(obj,chId,outputValue)
            outputHighZ = isempty(outputValue) || all(isnan(outputValue)) || (ischar(outputValue) && strcmpi(outputValue,'Z'));
            
            if isempty(chId)
                return
            end
            
            if ischar(chId)
                chId = obj.digitalNameToOutputId(chId,outputHighZ);
            end
            
            if outputHighZ
                v = 0;
            elseif ischar(outputValue)
                [tf,srcId] = ismember(outputValue,obj.spclOutputSignals);
                if tf
                    v = srcId+2;
                else
                    [~,~,~,~,results] = regexpi(outputValue,'^task(.)\.(.)');
                    if numel(results) == 1
                        task = str2double(results{1}{1});
                        line = str2double(results{1}{2});

                        assert((task >= 1) && (task <= numel(obj.hDigitalWaveGen)),'Invalid task selection');
                        assert((line >= 0) && (line <= 7),'Invalid task line selection');

                        v = numel(obj.spclOutputSignals) - 5 + task*8 + line;
                    else
                        error('Invalid signal selection.');
                    end
                end
            else
                v = logical(outputValue)+1;
            end
            
            obj.(['digital_o_' num2str(chId)]) = v;
        end
        
        function v = getDioOutput(obj,channel)
            if ischar(channel)
                channel = obj.digitalNameToOutputId(channel);
            end
            v = obj.(['digital_o_' num2str(channel)]);
            
            tskStrtInd = numel(obj.spclOutputSignals) + 3;
            
            if ~v
                v = nan;
            elseif v < 3
                v = logical(v-1);
            elseif v < tskStrtInd
                v = obj.spclOutputSignals{v-2};
            else
                c = v-tskStrtInd;
                tsk = floor(c/8) + 1;
                line = mod(c,8);
                v = sprintf('Task%d.%d',tsk,line);
            end
        end
        
        function v = getDioInputVal(obj,channel)
            if ischar(channel)
                channel = obj.dioNameToId(channel);
            end
            
            ndio = 8*(3+obj.isR1);
            if channel < ndio
                v = logical(bitand(obj.dio_i,2^channel));
            else
                v = logical(bitand(obj.rtsi_i,2^(channel-ndio)));
            end
        end

        function id = signalNameToTriggerId(obj, signal)
            [tf, n] = ismember(signal,obj.spclTriggerSignals);
            if tf
                id = n + 39 + 8*obj.isR1;
            else
                try
                    id = obj.dioNameToId(signal);
                catch
                    error('Invalid trigger terminal.');
                end
            end
        end
        
        function resetDataScope(obj)
            obj.scopeCmd = 51;
        end
        
        function startDataScope(obj)
            obj.scopeCmd = 52;
        end
    end
    
    %% Prop Access
    methods
        function v = get.dataClkRate(obj)
            r = obj.dataClkCount;
            if r == 8388607
                v = nan;
            else
                v = calcClkRate(r,200e6);
            end
        end
        
        function v = get.systemClock(obj)
            obj.systemClockL = 0;
            v = uint64(obj.systemClockL) + uint64(obj.systemClockH) * 2^32;
        end
        
        function v = get.pwmMeasChan(obj)
            r = obj.pwmMeasChanReg;
            if r > 39
                v = [];
            elseif r > 23
                v = sprintf('RTSI%d',r-24);
            else
                prt = floor(r/8);
                lin = mod(r,8);
                v = sprintf('D%d.%d',prt,lin);
            end
        end
        
        function set.pwmMeasChan(obj,v)
            obj.pwmMeasChanReg = obj.dioNameToId(v);
        end
        
        function v = get.pwmPeriod(obj)
            r = obj.pwmMeasPeriodReg;
            
            if r < 2 || r >= obj.pwmMeasPeriodMax
                v = [];
            else
                v = double(obj.pwmMeasPeriodReg) / 200e6;
            end
        end
        
        function v = get.pwmPulseWidth(obj)
            r = obj.pwmMeasHighTimeReg;
            
            if r >= obj.pwmMeasPeriodMax
                v = [];
            else
                v = double(obj.pwmMeasHighTimeReg) / 200e6;
            end
        end
        
        function v = get.internalClockSourceRate(obj)
            v = (120+5*obj.isR1) * 1e6;
        end
        
        function v = get.hsPhotonThresholds(obj)
            v = typecast(obj.hsPhotonThresholdReg,'int16');
        end
        
        function set.hsPhotonThresholds(obj,v)
            v(end+1:2) = 0;
            v = max(min(v,2047),-2048);
            obj.hsPhotonThresholdReg = typecast(int16(v(1:2)),'uint32');
        end
        
        function v = get.hsPhotonDifferentiateWidths(obj)
            v = typecast(obj.hsPhotonDifferentiateWidthReg,'uint8');
            v = v(1:2)+2;
        end
        
        function set.hsPhotonDifferentiateWidths(obj,v)
            v = max(min(v,5),2);
            v = typecast(uint8(v(1:2)-2),'uint16');
            obj.hsPhotonDifferentiateWidthReg = v;
        end
        
        function v = get.hsPhotonInverts(obj)
            v = obj.hsPhotonInvertReg;
            mask = cast(2.^(0:1),'like',v);
            v = logical(bitand(v,mask));
        end
        
        function set.hsPhotonInverts(obj,val)
            v = uint32(val(1));
            for c = 2:numel(val)
                v = bitor(v,(2^(c-1))*val(c));
            end
            obj.hsPhotonInvertReg = v;
        end
        
        function v = get.hsPhotonDifferentiate(obj)
            v = obj.hsPhotonDifferentiateReg;
            mask = cast(2.^(0:1),'like',v);
            v = logical(bitand(v,mask));
        end
        
        function set.hsPhotonDifferentiate(obj,val)
            v = uint32(val(1));
            for c = 2:numel(val)
                v = bitor(v,(2^(c-1))*val(c));
            end
            obj.hsPhotonDifferentiateReg = v;
        end
        
        function set.laserClkPeriodSamples(obj,val)
            obj.laserClkPeriodSamplesReg = val;
            obj.syncTrigPhaseAdjust = obj.syncTrigPhaseAdjust;
        end
        
        function v = get.laserClkPeriodSamples(obj)
            v = obj.laserClkPeriodSamplesReg;
        end
        
        function set.syncTrigPhaseAdjust(obj,val)
            try
                validateattributes(val,{'numeric'},{'real','finite','scalar'});

                % enforce that phase shift is within one period
                val = mod(val, obj.laserClkPeriodSamples);

                maxShift = 2^obj.SAMPLE_PHASE_BITS-1;
                assert(val <= maxShift, 'Phase shift cannot be higher than %d', maxShift);
            catch ME
                most.ErrorHandler.logAndReportError(false,ME);
            end
            
            obj.hsSyncTrigPhaseShift = val;
            obj.syncTrigPhaseAdjust = val;
        end

        function val = get.syncTrigPhaseAdjust(obj)
            val = obj.hsSyncTrigPhaseShift;
        end
    end
    
    %% Static
    methods (Static)
        function checkHardwareSupport(devs)
            if ~nargin
                devs = (1:dabs.vidrio.rdi.Device.getDriverInfo.numDevices) - 1;
            end
            for i = devs
                s = dabs.vidrio.rdi.Device.getDeviceInfo(i-1);
                if s.hardwareRevision
                    if strcmp(s.firmwareVersion, 'A0')
                        error('A firmware update is required for your vDAQ in order to run this version of ScanImage. Please contact support@vidriotech.com for details.');
                    elseif ~strcmp(s.firmwareVersion, 'A1')
                        error('The firmware version of your vDAQ device is not compatible with this version of ScanImage. Please contact support@vidriotech.com for details.');
                    end
                elseif ~strcmp(s.firmwareVersion, 'A0')
                    error('The firmware version of your vDAQ device is not compatible with this version of ScanImage. Please contact support@vidriotech.com for details.');
                end
            end
        end
    end
end

function r = calcClkRate(v,measClkRate)
    if v == 2^32-1
        r = nan;
    else
        measClkPeriod = 1/measClkRate;
        TperNticks = double(v)*measClkPeriod;
        targetClkPeriod = TperNticks / 2^19;
        r = 1/targetClkPeriod;
    end
end

function v = setbits(v,bits,newv)
    for i = 1:numel(bits)
        v = bitset(v, bits(i)+1, bitget(newv,i));
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
