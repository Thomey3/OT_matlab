classdef Control < scanimage.interfaces.Class
    properties (SetAccess = immutable)
        hLinScan;                             % handle of Scan2D, handle gracefully if empty
        hBeamsComponent;
        hFpgaDaq;
    end
    
    properties (SetAccess = private)
        hAOxyb;                                 % handle of AO Task for control of an analog-controlled X/Y scanner pair
        hAOxybz;                                % handle of AO Task for control of an analog-controlled X/Y scanner pair and fastz actuator
        hAO;                                    % handle to either hAOxyb or hAOxybz depending on if fastz is active
        
        zActive;                                % indicates that hAOxybz is the active task and that z AO waveform should be included
        hAOSampClk;                             % handle of Ctr Task for sample clock generation for hAO
        
        offsetVoltage = [0,0];                  % last written offset voltage for motion correction
        beamShareGalvoDAQ = false;              % Indicates that beam control channels are on the galvo DAQ. Possible if galvo control DAQ has >2 output channels
        zShareGalvoDAQ = false;                 % Indicates that the fastz control channel is on the galvo DAQ. Possible if galvo control DAQ has >2 output channels
        flagOutputNeedsUpdate = false;          % for 'live' acquisition output set to true to indicate that scan parameters (e.g. zoom) changed so that AO needs to be updated
        updatingOutputNow = false;              % protects the 'critical section' in obj.updateAnalogBufferAsync
        waveformLength;                         % length of the output waveform for one frame
        scannerOutputUnTransformed;             % scanner output before transformation (zoom,shift,multiplier)
        bufferUpdatingAsyncRetries = 0;
        samplesDone = 0;
    end
    
    properties (Access = private)
        offsetUseAsyncWrite = false;
        offsetVoltageAsyncLock = false;
        offsetVoltageAsyncNextUpdateVoltage = [];
    end
    
    properties (Dependent)
        active;                                 % (logical) true during an active output
        startTrigIn;                            % input terminal of the start trigger (e.g. 'PFI0'); if empty, triggering is disabled
        sampClkSrc;
        sampClkTimebaseSrc;
        sampClkTimebaseRate;
        sampClkRate;
        sampClkMaxRate;
    end
    
    properties
        scanXisFast = true;                     % Fast scanning done on X scanner (identified in MDF). If false, fast scanning done on Y scanner
        
        startTrigOut;                           % output terminal of the start trigger
        
        startTrigEdge = 'rising';               % trigger polarity for the start trigger. one of {'rising','falling'}
    end
    
    properties (Hidden)
        samplesWritten;
        samplesGenerated;
        framesGenerated;
        framesWritten;
        
        genSampClk = false;
    end
    
    properties
       lastSample = [];
       lastKnownAOBuffer = [];
    end
    
    %% Lifecycle
    methods
        function obj = Control(hLinScan)
            obj.hLinScan = hLinScan;
        end
        
        function delete(obj)
            obj.deinit();
        end
        
        function deinit(obj)
            most.idioms.safeDeleteObj(obj.hAOxyb);
            most.idioms.safeDeleteObj(obj.hAOxybz);
            most.idioms.safeDeleteObj(obj.hAOSampClk);
        end
        
        function reinit(obj)
            obj.deinit();
            obj.ziniPrepareTasks();
        end
    end
    
    % Public Methods
    methods
        function arm(obj)
            if isempty(obj.hLinScan.hSI.hWaveformManager.scannerAO)
                obj.hLinScan.hSI.hWaveformManager.updateWaveforms;
            end
            
            % don't move the galvos in the hLinScan.hCtl.start function! moving the
            % galvos will start the AO task sample clock, which in turn
            % will prematurely trigger the PMT AI task (this happens when
            % no Aux device is configured)
            obj.hLinScan.xGalvo.pointPosition_V(obj.hLinScan.hSI.hWaveformManager.scannerAO.ao_volts.G(end, 1));
            obj.hLinScan.yGalvo.pointPosition_V(obj.hLinScan.hSI.hWaveformManager.scannerAO.ao_volts.G(end, 2));
        end
        
        function start(obj)
            obj.assertNotActive('method:start');
            obj.hAO.abort(); % to prevent DAQmx error -200288
            if obj.genSampClk
                obj.hAOSampClk.abort();
            end
            
            obj.zActive = obj.zShareGalvoDAQ && obj.hLinScan.hSI.hFastZ.outputActive;
            if obj.zActive
                obj.hAO = obj.hAOxybz;
            else
                obj.hAO = obj.hAOxyb;
            end
            
            % calculate output buffer
            [waveformOutput,beamPathOutput] = obj.calcOutputBuffer();
            assert(obj.waveformLength > 0, 'AO generation error. Scanner control waveform length is zero.');
            
            obj.hAO.sampQuantSampMode = 'DAQmx_Val_ContSamps';
            
            % update output buffer
            obj.hAO.cfgOutputBuffer(obj.waveformLength);
            obj.hAO.writeRelativeTo = 'DAQmx_Val_FirstSample';
            obj.hAO.writeOffset = 0;
            if ~obj.hLinScan.simulated
                buffer = double(waveformOutput);
                obj.hAO.writeAnalogData(buffer);
                obj.lastKnownAOBuffer = buffer;
                obj.hAO.start();
                if obj.genSampClk
                    obj.hAOSampClk.start();
                end
            end
        end
        
        function [waveformOutput,beamPathOutput] = calcOutputBuffer(obj)
            if obj.beamShareGalvoDAQ
                obj.waveformLength = obj.hBeamsComponent.configureStreaming(obj.hAO.sampClkRate);
                obj.samplesGenerated = 0;
                obj.framesGenerated = 0;
                obj.samplesWritten = obj.hBeamsComponent.streamingBufferSamples;
                obj.framesWritten = obj.hBeamsComponent.streamingBufferFrames;
                [waveformOutput,beamPathOutput] = obj.calcJointBuffer(1,obj.hBeamsComponent.streamingBufferFrames);
                if obj.hBeamsComponent.streamingBuffer
                    obj.hAO.registerEveryNSamplesEvent(@obj.streamingBufferNSampCB,obj.hBeamsComponent.nSampCbN,false);
                    obj.hAO.set('writeRegenMode','DAQmx_Val_DoNotAllowRegen');
                else
                    obj.hAO.registerEveryNSamplesEvent([],[],false);
                    obj.hAO.set('writeRegenMode','DAQmx_Val_AllowRegen');
                end
            else
                beamPathOutput = [];
                waveformOutput = obj.hLinScan.hSI.hWaveformManager.scannerAO.ao_volts.G;
                
                if obj.zActive
                    waveformOutput = [waveformOutput obj.hLinScan.hSI.hWaveformManager.scannerAO.ao_volts.Z];
                end
                
                obj.hAO.set('writeRegenMode','DAQmx_Val_AllowRegen');
                obj.waveformLength = size(waveformOutput,1);
            end
        end
        
        function restart(obj)
            obj.assertNotActive('method:restart');
            obj.hAO.abort();
            
            obj.hAO.control('DAQmx_Val_Task_Unreserve');
            
            if obj.genSampClk
                obj.hAOSampClk.abort();
            end
            
            if obj.flagOutputNeedsUpdate
                % cannot simply restart, obj.start instead to update AO buffer
                obj.start()
                return;
            end
            
            try
                obj.hAO.start();
                if obj.genSampClk
                    obj.hAOSampClk.start();
                end
            catch ME
                if ~isempty(strfind(ME.message, '200462'))
%                     warning('Output buffer is empty. Cannot restart. Starting a new generation instead');
                    obj.start();
                else
                    rethrow(ME);
                end
            end
        end
        
        function abort(obj) 
            try
                obj.hAO.abort();
                
                obj.updateLastKnownGalvoPositionFromOutputTask();
                obj.hAO.control('DAQmx_Val_Task_Unreserve');
                
                if ~isempty(obj.lastKnownAOBuffer)
                    obj.hLinScan.xGalvo.pointPosition_V(obj.lastKnownAOBuffer(1,1));
                    obj.hLinScan.yGalvo.pointPosition_V(obj.lastKnownAOBuffer(1,2));
                end
                
                obj.lastKnownAOBuffer = [];
                
                if isempty(obj.hLinScan.hSI.hWaveformManager.scannerAO)
                    obj.hLinScan.hSI.hWaveformManager.updateWaveforms;
                end
                
                if obj.genSampClk
                    obj.hAOSampClk.abort();
                end
                obj.updatingOutputNow = false;
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
        end
        
        function updateLastKnownGalvoPositionFromOutputTask(obj)
            lastWarnState = warning;
            warning('off');
            numSamplesGenerated = get(obj.hAO, 'writeTotalSampPerChanGenerated');
            warning('on');
            warning(lastWarnState);
            
            if ~isempty(numSamplesGenerated)
                bufferSize = size(obj.lastKnownAOBuffer,1);
                idx = mod(numSamplesGenerated,bufferSize);
                
                if idx > 0
                    obj.hLinScan.xGalvo.lastKnownPositionOutput_V = obj.lastKnownAOBuffer(idx,1);
                    obj.hLinScan.yGalvo.lastKnownPositionOutput_V = obj.lastKnownAOBuffer(idx,2);
                end
            end
        end
        
        function parkOrPointLaser(obj,xy)
            %   ParkOrPointLaser(): parks laser at mdf defined park location (vars state.acq.parkAngleX & state.acq.parkAngleY); closes shutter and turns off beam with Pockels Cell
            %   ParkOrPointLaser(xy): parks laser at user defined location xy, a 2 element vector of optical degree values
            obj.assertNotActive('parkOrPointLaser');
            
            if nargin < 2 || isempty(xy)
                obj.hLinScan.xGalvo.park();
                obj.hLinScan.yGalvo.park();
            else
                validateattributes(xy,{'numeric'},{'vector','numel',2});
                obj.hLinScan.xGalvo.pointPosition(xy(1));
                obj.hLinScan.yGalvo.pointPosition(xy(2));
            end
        end
        
        function centerScanner(obj)
            obj.hLinScan.xGalvo.center();
            obj.hLinScan.yGalvo.center();
        end
        
        function resetOffsetVoltage(obj)
            obj.writeOffsetAngle([0,0]);
        end
        
        function writeOffsetAngle(obj,xyAngle)
            if obj.hLinScan.xGalvo.offsetAvailable
                obj.hLinScan.xGalvo.pointOffsetPosition(xyAngle(1));
            end
            
            if obj.hLinScan.yGalvo.offsetAvailable
                obj.hLinScan.yGalvo.pointOffsetPosition(xyAngle(2));
            end
        end
        
        function issueStartTrigger(obj)
            obj.hAO.issueSoftwareStartTrigger();
        end
    end
    
    % Getter / Setter Methods for properties
    methods  
        function val = get.hBeamsComponent(obj)
            val = obj.hLinScan.hSI.hBeams;
        end
        
        function val = get.active(obj)
            val = ~obj.hAO.isTaskDoneQuiet();
        end
        
        function val = get.startTrigIn(obj)
            startTrigType = get(obj.hAO,'startTrigType');
            
            switch startTrigType
                case 'DAQmx_Val_None';
                    val = '';
                case 'DAQmx_Val_DigEdge';
                    val = get(obj.hAO,'digEdgeStartTrigSrc');
                otherwise
                    assert(false,'Unknown trigger type: %s',startTrigType);
            end
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
                obj.hAO.disableStartTrig();
            else
                obj.hAO.cfgDigEdgeStartTrig(val,edge);
            end
        end
        
        function set.startTrigEdge(obj,val)
            obj.assertNotActive('startTrigEdge');
            assert(ismember(val,{'rising','falling'}));
            obj.startTrigEdge = val;
            obj.startTrigIn = obj.startTrigIn;    
        end
        
        function set.startTrigOut(obj,val)
            obj.assertNotActive('startTrigOut');
            if ~isempty(obj.startTrigOut)
                % disconnect old output terminal
                hDaqSystem = dabs.ni.daqmx.System();
                hDaqSystem.tristateOutputTerm(obj.startTrigOut);
            end
            
            if ~isempty(val)
                % set the new route
                val = qualifyTerminal(val);
                obj.hAO.exportSignal('DAQmx_Val_StartTrigger',val);
            end
            
            obj.startTrigOut = val;
            
            function name = qualifyTerminal(name)
                if ~isempty(name) && isempty(strfind(name,'/'))
                    deviceNameGalvo = obj.yGalvo.hAOControl.hDAQ.name;
                    name = sprintf('/%s/%s',deviceNameGalvo,name); 
                end
            end
        end
        
        function set.sampClkSrc(obj,v)
            set(obj.hAOxyb, 'sampClkSrc', v);
            if ~isempty(obj.hAOxybz)
                set(obj.hAOxybz, 'sampClkSrc', v);
            end
        end
        
        function set.sampClkTimebaseSrc(obj,v)
            set(obj.hAOxyb, 'sampClkTimebaseSrc', v);
            if ~isempty(obj.hAOxybz)
                set(obj.hAOxybz, 'sampClkTimebaseSrc', v);
            end
        end
        
        function set.sampClkTimebaseRate(obj,v)
            set(obj.hAOxyb, 'sampClkTimebaseRate', v);
            if ~isempty(obj.hAOxybz)
                set(obj.hAOxybz, 'sampClkTimebaseRate', v);
            end
        end
        
        function set.sampClkRate(obj,v)
            set(obj.hAOxyb, 'sampClkRate', v);
            if ~isempty(obj.hAOxybz)
                set(obj.hAOxybz, 'sampClkRate', v);
            end
        end
        
        function v = get.sampClkRate(obj)
            v = get(obj.hAO, 'sampClkRate');
        end
        
        function v = get.sampClkMaxRate(obj)
            if isempty(obj.hAOxybz)
                v = get(obj.hAOxyb, 'sampClkMaxRate');
            else
                v = get(obj.hAOxybz, 'sampClkMaxRate');
            end
        end
    end
    
    methods (Hidden)
        function streamingBufferNSampCB(obj,~,~)
            obj.samplesGenerated = obj.samplesGenerated + obj.hBeamsComponent.nSampCbN;
            obj.framesGenerated = obj.samplesGenerated / obj.hBeamsComponent.frameSamps;
            obj.updateAnalogBufferAsync();
        end
        
        function [ao,bpath] = calcJointBuffer(obj, bufStartFrm, nFrames)
            if obj.hBeamsComponent.streamingBuffer
                [bao,bpath] = obj.hBeamsComponent.calcStreamingBuffer(bufStartFrm, nFrames);                
                ao = [repmat(obj.hLinScan.hSI.hWaveformManager.scannerAO.ao_volts.G, nFrames, 1) bao];
                
                if obj.zActive
                    %index out the correct section of z waveform
                    frms = bufStartFrm:(bufStartFrm+nFrames-1);
                    zWvSlices = obj.hSI.hStackManager.zs;
                    zWaveform = obj.hSI.hWaveformManager.scannerAO.ao_volts.Z;
                    zWvSliceSamps = length(zWaveform)/zWvSlices;
                    assert(zWvSliceSamps == floor(zWvSliceSamps), 'Z waveform length is not divisible by number of slices');
                    
                    for ifr = numel(frms):-1:1
                        ss = 1 + (ifr-1)*zWvSliceSamps;
                        es = ifr*zWvSliceSamps;
                        
                        slcInd_0ind = mod(frms(ifr)-1,zWvSlices);
                        aoSs = 1 + slcInd_0ind*zWvSliceSamps;
                        aoEs = (slcInd_0ind+1)*zWvSliceSamps;
                        
                        zAo(ss:es,1) = zWaveform(aoSs:aoEs,:);
                    end
                    
                    ao = [ao zAo];
                end
            else
                if obj.hBeamsComponent.enablePowerBox && obj.hBeamsComponent.hasPowerBoxes
                    ao = [obj.hLinScan.hSI.hWaveformManager.scannerAO.ao_volts.G obj.hLinScan.hSI.hWaveformManager.scannerAO.ao_volts.Bpb];
                    bpath = obj.hLinScan.hSI.hWaveformManager.scannerAO.pathFOV.Bpb;
                else
                    ao = [obj.hLinScan.hSI.hWaveformManager.scannerAO.ao_volts.G obj.hLinScan.hSI.hWaveformManager.scannerAO.ao_volts.B];
                    bpath = obj.hLinScan.hSI.hWaveformManager.scannerAO.pathFOV.B;
                end
                if obj.zActive
                    ao = [ao obj.hLinScan.hSI.hWaveformManager.scannerAO.ao_volts.Z];
                end
            end
        end
        
        function updateAnalogBufferAsync(obj,restartTask)
            if nargin < 2
                restartTask = false;
            end
            
            if obj.updatingOutputNow && ~restartTask
                obj.flagOutputNeedsUpdate = true;
                return;
            end
            
            streamingBuffer = false;
            
            if obj.beamShareGalvoDAQ
                if obj.hBeamsComponent.streamingBuffer
                    streamingBuffer = true;
                    
                    if restartTask
                        obj.samplesGenerated = 0;
                        obj.framesGenerated = 0;
                        obj.samplesWritten = obj.hBeamsComponent.streamingBufferSamples;
                        obj.framesWritten = obj.hBeamsComponent.streamingBufferFrames;
                        
                        framesToWrite = obj.framesWritten;
                        startFrame = 1;
                    else
                        framesToWrite = obj.hBeamsComponent.streamingBufferFrames + obj.framesGenerated - obj.framesWritten;
                        startFrame = obj.framesWritten + 1;
                    end
                    
                    obj.hAO.writeRelativeTo = 'DAQmx_Val_CurrWritePos';
                    obj.hAO.writeOffset = 0;
                    if framesToWrite > 0
                        [waveformOutput,beamPathOutput] = obj.calcJointBuffer(startFrame, framesToWrite);
                    end
                else
                    framesToWrite = 1;
                    [waveformOutput,beamPathOutput] = obj.calcJointBuffer();
                    obj.hAO.writeRelativeTo = 'DAQmx_Val_FirstSample';
                    obj.hAO.writeOffset = 0;
                end
            else
                framesToWrite = 1;
                beamPathOutput = [];
                obj.hAO.writeRelativeTo = 'DAQmx_Val_FirstSample';
                obj.hAO.writeOffset = 0;
                
                waveformOutput  = obj.hLinScan.hSI.hWaveformManager.scannerAO.ao_volts.G;
                if obj.zActive
                    waveformOutput = [waveformOutput obj.hLinScan.hSI.hWaveformManager.scannerAO.ao_volts.Z];
                end
                
                waveformLength_ = size(waveformOutput,1);
                assert(obj.waveformLength == waveformLength_, 'AO generation error. Size of waveforms have changed.');
            end
            
            obj.flagOutputNeedsUpdate = false;
            if framesToWrite > 0
                if restartTask
                    obj.hAO.abort();
                    obj.updateLastKnownGalvoPositionFromOutputTask();
                    newBuffer = double(waveformOutput);
                    obj.hLinScan.xGalvo.pointPosition_V(newBuffer(1,1));
                    obj.hLinScan.yGalvo.pointPosition_V(newBuffer(1,2));
                    obj.hAO.writeAnalogData(newBuffer);
                    obj.lastKnownAOBuffer = newBuffer;
                else
                    newBuffer = double(waveformOutput);
                    
                    if streamingBuffer
                        nSamples = min(size(obj.lastKnownAOBuffer,1),size(writeBuffer,1));
                        
                        galvoOld = obj.lastKnownAOBuffer(1:nSamples,1:2);
                        galvoNew = writeBuffer(1:mSamples,1:2);
                        
                        if isequal(galvoOld,galvoNew)
                            writeBuffer = newBuffer;
                        else
                            fraction = linspace(0,1,nSamples)';
                            galvoInterpolated = galvoOld + bsxfun(@times,(galvoNew-galvoOld),fraction);
                            writeBuffer(1:nSamples,1:2) = galvoInterpolated;
                        end
                    else
                        % interpolate between old and new galvo waveforms
                        % perform double write back to back to perform
                        % transition
                        nSamples = size(newBuffer,1);
                        galvoNew = newBuffer(:,1:2);
                        galvoOld = obj.lastKnownAOBuffer(:,1:2);
                        
                        if ~isequal(galvoNew,galvoOld)
                            fraction = linspace(0,1,nSamples)';
                            galvoInterpolated = galvoOld + bsxfun(@times,(galvoNew-galvoOld),fraction);
                            writeBuffer = repmat(newBuffer,1,1,2); % NxMx2 array for double write
                            writeBuffer(:,1:2,1) = galvoInterpolated;
                        else
                            writeBuffer = newBuffer;
                        end
                    end
                    
                    obj.updatingOutputNow = true;
                    obj.hAO.writeAnalogDataAsync(writeBuffer,2,[],[],@obj.updateAnalogBufferAsyncCb); % task.writeAnalogData(writeData, timeout, autoStart, numSampsPerChan)
                    obj.lastKnownAOBuffer = newBuffer;
                end
            end
        end
        
        function updateAnalogBufferAsyncCb(obj,~,evt)
            obj.updatingOutputNow = false; % this needs to be the first call in the function in case there are errors below

            if obj.beamShareGalvoDAQ && obj.hBeamsComponent.streamingBuffer
                obj.samplesWritten = obj.samplesWritten + evt.sampsWritten;
                obj.framesWritten = obj.samplesWritten / obj.hBeamsComponent.frameSamps;
            end
            
            if evt.status ~= 0 && evt.status ~= 200015 && obj.hLinScan.active
                fprintf(2,'Error updating scanner buffer: %s\n%s\n',evt.errorString,evt.extendedErrorInfo);
                
                if obj.bufferUpdatingAsyncRetries < 3 || obj.flagOutputNeedsUpdate
                    obj.bufferUpdatingAsyncRetries = obj.bufferUpdatingAsyncRetries + 1;
                    fprintf(2,'Scanimage will retry update...\n');
                    obj.updateAnalogBufferAsync();
                else
                    obj.bufferUpdatingAsyncRetries = 0;
                end
            else
                obj.bufferUpdatingAsyncRetries = 0;

                if obj.flagOutputNeedsUpdate
                    obj.updateAnalogBufferAsync();
                end
            end
        end
    end
    
    % Helper functions
    methods (Access = private)        
        function ziniPrepareTasks(obj)     
            fastBeamDevicesMask = cellfun(@(hB)isa(hB, 'dabs.resources.devices.BeamModulatorFast'), obj.hLinScan.hBeams);
            fastBeamDevices = obj.hLinScan.hBeams(fastBeamDevicesMask);
            beamDaqNames = cellfun(@(hB)hB.hAOControl.hDAQ.name,fastBeamDevices,'UniformOutput',false);
            beamDaqName = unique(beamDaqNames);
            assert(numel(beamDaqName)<=1,'All LinScan beams must be configured to be on the same DAQ board. Current configuration: %s',strjoin(beamDaqName,','));
            
            hGalvoDAQ = obj.hLinScan.xGalvo.hAOControl.hDAQ;
            
            obj.beamShareGalvoDAQ = ~isempty(beamDaqName) && strcmp(hGalvoDAQ.name, beamDaqName{1});
            obj.zShareGalvoDAQ = obj.hLinScan.controllingFastZ;
            
            % initialize hAO & hAI tasks
            taskName = [obj.hLinScan.name '-ScannerOut'];
            obj.hAOxyb = dabs.ni.rio.fpgaDaq.fpgaDaqAOTask.createTaskObj(taskName, obj.hFpgaDaq);
            obj.hAOxyb.createAOVoltageChan(obj.hLinScan.xGalvo.hAOControl.hDAQ.name, obj.hLinScan.xGalvo.hAOControl.channelID, 'XMirrorChannel');
            obj.hAOxyb.createAOVoltageChan(obj.hLinScan.yGalvo.hAOControl.hDAQ.name, obj.hLinScan.yGalvo.hAOControl.channelID, 'YMirrorChannel');

            % initialize extra AO channels for beams if they are on the same DAQ
            if obj.beamShareGalvoDAQ
                for i = 1:numel(fastBeamDevices)
                    hBeam = fastBeamDevices{i};
                    obj.hAOxyb.createAOVoltageChan(hBeam.hAOControl.hDAQ.name,hBeam.hAOControl.channelID,hBeam.name);
                end
            end

            % initialize extra AO channel for fastz if it is on the same DAQ
            if obj.zShareGalvoDAQ
                obj.hAOxybz = dabs.ni.rio.fpgaDaq.fpgaDaqAOTask.createTaskObj([taskName 'WZ'], obj.hFpgaDaq);
                obj.hAOxybz.createAOVoltageChan(obj.hLinScan.xGalvo.hAOControl.hDAQ.name, obj.hLinScan.xGalvo.hAOControl.channelID, 'XMirrorChannel');
                obj.hAOxybz.createAOVoltageChan(obj.hLinScan.yGalvo.hAOControl.hDAQ.name, obj.hLinScan.yGalvo.hAOControl.channelID, 'YMirrorChannel');
                
                % initialize extra AO channels for beams if they are on the same DAQ
                if obj.beamShareGalvoDAQ
                    for i = 1:numel(fastBeamDevices)
                        hBeam = fastBeamDevices{i};
                        obj.hAOxybz.createAOVoltageChan(hBeam.hAOControl.hDAQ.name,hBeam.hAOControl.channelID,hBeam.name);
                    end
                end

                % channel for fastz
                for idx = 1:numel(obj.hLinScan.hFastZs)
                    hFastZ = obj.hLinScan.hFastZs{idx};
                    
                    hAOControl = hFastZ.hAOControl;
                    fastZDaqBoardName = hAOControl.hDAQ.name;
                    fastZChannelID = hAOControl.channelID;
                    
                    obj.hAOxybz.createAOVoltageChan(fastZDaqBoardName, fastZChannelID, hFastZ.name);
                end
            end

            %create sample clock task if acq and ctrl are on same board but not aux board
            if isequal(obj.hLinScan.hDAQAcq,hGalvoDAQ) ...
               && ~isequal(hGalvoDAQ,obj.hLinScan.hDAQAux)
                obj.hAOSampClk = most.util.safeCreateTask([obj.hLinScan.name '-AOSampClk']);
                obj.hAOSampClk.createCOPulseChanFreq(hGalvoDAQ.name, 1, [obj.hLinScan.name '-AOSampClkChan'], 500e3);
                obj.hAOSampClk.cfgImplicitTiming('DAQmx_Val_ContSamps');
                obj.hAOSampClk.channels(1).set('ctrTimebaseSrc','ai/SampleClock');
                obj.hAOSampClk.channels(1).set('pulseTerm','');
            end

            % preliminary sample rate
            obj.hAOxyb.cfgSampClkTiming(obj.hAOxyb.get('sampClkMaxRate'), 'DAQmx_Val_FiniteSamps', 100);

            if ~isempty(obj.hAOxybz)
                obj.hAOxybz.cfgSampClkTiming(obj.hAOxybz.get('sampClkMaxRate'), 'DAQmx_Val_FiniteSamps', 100);
            end
                
            obj.hAO = obj.hAOxyb;
        end

        function assertNotActive(obj,propName)
            assert(~obj.active,'Cannot access %s during an active acquisition',propName);
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
