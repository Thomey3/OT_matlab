classdef Control < scanimage.interfaces.Class    
    properties (Hidden, SetAccess = immutable)
        hScan;
    end
    
    properties (Hidden, SetAccess = private)
        xGalvoExists = false;                % true if x-galvo exists 
    end
    
    properties (Hidden, Constant)
        AO_RATE_LIMIT = 200e3;               % limit for analog output rate
    end
    
    %% Original props
    %SCANNINGGALVO
    properties
        galvoFlyBackPeriods = 1;             % the number of scanner periods to fly back the galvo. can only be updated while the scanner is idle
        fillFractionSpatial = 1;
        
        frameClockIn = 'PFI1';               % String identifying the input terminal connected to the frame clock. Values are 'PFI0'..'PFI15' and 'PXI_Trig0'..'PXI_Trig7'

        %simulated mode
        simulated;
    end
    
    % Internal Parameters
    properties (SetAccess = private, Hidden)
        hDaqDevice; % galvo daq device
        
        hAOTaskGalvo;
        hCtrMSeriesSampClk;
        useSamplClkHelperTask = false;
        
        acquisitionActive = false;
        rateAOSampClk;
        
        activeFlag = false;
        
        galvoBufferUpdatingAsyncNow = false;
        galvoBufferNeedsUpdateAsync = false;
        galvoBufferUpdatingAsyncRetries = 0;
        galvoBuffer = [];
    end
    
    %% Lifecycle
    methods
        function obj = Control(hScan)
            if nargin < 1 || isempty(hScan)
                hScan = [];
            end
            
            obj.hScan = hScan;
        end
        
        function delete(obj)
            obj.deinit();
        end
    end
    
    methods        
        function deinit(obj)            
            try
                if obj.acquisitionActive
                    obj.stop();
                end
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
            
            try
                if most.idioms.isValidObj(obj.hScan.hResonantScanner)
                    obj.hScan.hResonantScanner.park();
                end
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
            
            % clear DAQmx buffered Tasks
            most.idioms.safeDeleteObj(obj.hCtrMSeriesSampClk);
            most.idioms.safeDeleteObj(obj.hAOTaskGalvo);
        end
        
        function reinit(obj)  
            obj.deinit();
            
            try
                obj.xGalvoExists = most.idioms.isValidObj(obj.hScan.xGalvo);
                obj.hDaqDevice = obj.hScan.yGalvo.hAOControl.hDAQ;
                
                % create Tasks
                obj.hAOTaskGalvo = most.util.safeCreateTask([obj.hScan.name '-GalvoCtrlGalvoPosition']);
                
                %set up buffered AO Task to control the Galvo Scan
                if obj.xGalvoExists
                    assert(isequal(obj.hScan.xGalvo.hAOControl.hDAQ,obj.hScan.yGalvo.hAOControl.hDAQ),'X and Y galvo must be configured to be on same DAQ board');
                    obj.hAOTaskGalvo.createAOVoltageChan(obj.hScan.xGalvo.hAOControl.hDAQ.name,obj.hScan.xGalvo.hAOControl.channelID,'X Galvo Control',-10,10);
                end
                obj.hAOTaskGalvo.createAOVoltageChan(obj.hDaqDevice.name,obj.hScan.yGalvo.hAOControl.channelID,'Y Galvo Control',-10,10);
                maxSampleRate = min(scanimage.util.daqTaskGetMaxSampleRate(obj.hAOTaskGalvo),obj.AO_RATE_LIMIT);
                
                galvoOutputMode = 'DAQmx_Val_FiniteSamps';
                if obj.simulated
                    galvoOutputMode = 'DAQmx_Val_ContSamps';
                end
                
                switch obj.hDaqDevice.productCategory
                    case 'DAQmx_Val_AOSeries'
                        most.idioms.warn('Support for PXIe-6738/6739 is experimental. Some features may not work.');
                        obj.hAOTaskGalvo.cfgSampClkTiming(maxSampleRate,galvoOutputMode,2); % length of output will be overwritten later
                        obj.rateAOSampClk = get(obj.hAOTaskGalvo,'sampClkRate');
                        obj.configureFrameClkTrigger(obj.hAOTaskGalvo);
                        obj.useSamplClkHelperTask = false;
                    case 'DAQmx_Val_XSeriesDAQ'
                        obj.hAOTaskGalvo.cfgSampClkTiming(maxSampleRate,galvoOutputMode,2); % length of output will be overwritten later
                        obj.rateAOSampClk = get(obj.hAOTaskGalvo,'sampClkRate');
                        obj.configureFrameClkTrigger(obj.hAOTaskGalvo);
                        obj.useSamplClkHelperTask = false;
                    case 'DAQmx_Val_MSeriesDAQ'
                        % the M series does not support native retriggering for
                        % AOs. Workaround: Use counter to produce sample clock
                        obj.hCtrMSeriesSampClk = most.util.safeCreateTask([obj.hScan.name '-M-Series helper task']);
                        obj.hCtrMSeriesSampClk.createCOPulseChanFreq(obj.hDaqDevice.name,0,[],maxSampleRate);
                        obj.rateAOSampClk = get(obj.hCtrMSeriesSampClk.channels(1),'pulseFreq');
                        obj.hCtrMSeriesSampClk.channels(1).set('pulseTerm',''); % we do not need to export the sample clock to a PFI. delete
                        obj.hCtrMSeriesSampClk.cfgImplicitTiming(galvoOutputMode,2); % length of output will be overwritten later
                        obj.configureFrameClkTrigger(obj.hCtrMSeriesSampClk);
                        
                        % setup hAOTaskGalvo to use the sample clock generated by the counter
                        samplClkInternalOutputTerm = sprintf('/%sInternalOutput',obj.hCtrMSeriesSampClk.channels(1).chanNamePhysical);
                        obj.hAOTaskGalvo.cfgSampClkTiming(obj.rateAOSampClk,'DAQmx_Val_ContSamps',2,samplClkInternalOutputTerm);
                        obj.useSamplClkHelperTask = true;
                    otherwise
                        error('Primary DAQ Device needs to be either M-series or X-series');
                end
                
                obj.parkGalvo();                
            catch ME
                obj.deinit();
                most.ErrorHandler.rethrow(ME);
            end
        end  
    end
    
    %% Public Methods
    methods        
        function start(obj)
            assert(~obj.acquisitionActive,'Acquisition is already active');    
            
            galvoPoints = obj.getGalvoScanOutputPts();
            if most.idioms.isValidObj(obj.hScan.xGalvo)
                obj.hScan.xGalvo.pointPosition_V(galvoPoints(1,1));
            end
            
            if most.idioms.isValidObj(obj.hScan.yGalvo)
                obj.hScan.yGalvo.pointPosition_V(galvoPoints(1,end));
            end
            
            % Reconfigure the Tasks for the selected acquisition Model
            obj.updateTaskCfg();
            % this pause needed for the Resonant Scanner to reach
            % its amplitude and send valid triggers
            obj.activeFlag = true;
            % during resonantScannerWaitSettle a user might have clicked
            % 'abort' - which in turn calls obj.abort and unreserves
            % obj.hAOTaskGalvo; catch this by checking obj.activeflag
            if ~obj.activeFlag
                errorStruct.message = 'Soft error: ResScan was aborted before the resonant scanner could settle.';
                errorStruct.identifier = '';
                errorStruct.stack = struct('file',cell(0,1),'name',cell(0,1),'line',cell(0,1));
                error(errorStruct); % this needs to be an error, so that Scan2D will be aborted correctly
            end
                  
            
            obj.hAOTaskGalvo.start();
            if obj.useSamplClkHelperTask
                obj.hCtrMSeriesSampClk.start();
            end
            
            if (~obj.simulated)    
                obj.hScan.liveScannerFreq = [];
                obj.hScan.lastLiveScannerFreqMeasTime = [];
            end
            
            obj.acquisitionActive = true;  
        end
        
        function stop(obj,soft)
            if nargin < 2 || isempty(soft)
                soft = false;
            end
            
            if obj.useSamplClkHelperTask
                obj.hCtrMSeriesSampClk.abort();
                obj.hCtrMSeriesSampClk.control('DAQmx_Val_Task_Unreserve'); % to allow the galvo to be parked
            end
            
            obj.hAOTaskGalvo.stop();
            obj.hAOTaskGalvo.control('DAQmx_Val_Task_Unreserve'); % to allow the galvo to be parked
            
            obj.activeFlag = false;
                        
            %Park scanner
            % parkGalvo() has to be called after acquisitionActive is set to
            % false, otherwise we run into an infinite loop
            obj.acquisitionActive = false;
            if (~obj.simulated)
                obj.parkGalvo();
            end
            
            if obj.hScan.keepResonantScannerOn || soft
                % No-op
            else
                obj.hScan.hResonantScanner.park();
            end
            
            obj.galvoBufferUpdatingAsyncNow = false;
        end
        
        function parkGalvo(obj)
           assert(~obj.acquisitionActive,'Cannot park galvo while scanner is active');
           
           if most.idioms.isValidObj(obj.hScan.xGalvo)
               obj.hScan.xGalvo.park();
           end
           
           if most.idioms.isValidObj(obj.hScan.yGalvo)
               obj.hScan.yGalvo.park();
           end
        end
        
        function centerGalvo(obj)
           assert(~obj.acquisitionActive,'Cannot center galvo while scanner is active');
           
           if most.idioms.isValidObj(obj.hScan.xGalvo)
               obj.hScan.xGalvo.center();
           end
           
           if most.idioms.isValidObj(obj.hScan.yGalvo)
               obj.hScan.yGalvo.center();
           end
        end
        
        function updateLiveValues(obj,regenAO,restartTask)
            if nargin < 2
                regenAO = true;
            end
            
            if nargin < 3
                restartTask = false;
            end
            
            if obj.acquisitionActive
                try
                    if regenAO
                        obj.hScan.hSI.hWaveformManager.updateWaveforms();
                    end
                    
                    obj.updateTaskCfg(true,restartTask);
                catch ME
                    % ignore DAQmx Error 200015 since it is irrelevant here
                    % Error message: "While writing to the buffer during a
                    % regeneration the actual data generated might have
                    % alternated between old data and new data."
                    if isempty(strfind(ME.message, '200015'))
                        rethrow(ME)
                    end
                end
            else
                % if the parking position for the Galvo was updated, apply
                % the new settings.
                obj.parkGalvo();
            end
        end
    end
    
    %% Private Methods
    methods (Hidden)        
        function v = nextResonantFov(obj)
            if obj.hScan.hSI.hScan2D == obj.hScan
                v = obj.hScan.scannerset.resonantScanFov(obj.hScan.currentRoiGroup);
            else
                v = 0;
            end
        end
    end
    
    methods (Access = private)        
        function configureFrameClkTrigger(obj,hTask)
            if ~obj.simulated
                hTask.cfgDigEdgeStartTrig(obj.frameClockIn,'DAQmx_Val_Rising');
                hTask.set('startTrigRetriggerable',true);
            end
        end
             
        function updateTaskCfg(obj, isLive, restartTask)            
            if nargin < 2 || isempty(isLive)
                isLive = false;
            end
            
            if nargin < 3
                restartTask = false;
            end
            
            recurse = false;
            
            [galvoPoints,samplesPerFrame,resScanOutputPoint] = obj.getGalvoScanOutputPts();
            
            % Handle Resonant Scanner.
            % Update AO Buffers (Performance seems to be better when updating the galvo task last.
            
            obj.hScan.hResonantScanner.assertNoError();
            
            if obj.hScan.isPolygonalScanner
                hPolygonalScanner =  obj.hScan.hResonantScanner;
                nominalLineRate_Hz = hPolygonalScanner.nominalFrequency_Hz;
                hPolygonalScanner.setLineRate_Hz(nominalLineRate_Hz);
            else
                obj.hScan.hResonantScanner.setAmplitude(resScanOutputPoint);
                obj.hScan.autoSetLinePhase(resScanOutputPoint);
            end
            
            % Handle Galvo.
            if obj.xGalvoExists
                obj.galvoBuffer = galvoPoints(:,1:2);
            else
                obj.galvoBuffer = galvoPoints(:,2);
            end
            bufferLength = length(obj.galvoBuffer);
            assert(bufferLength > 0, 'AO generation error. Galvo control waveform length is zero.');
            
            % If acq is not live make sure buffered tasks are stopped
            if ~isLive
                if obj.useSamplClkHelperTask
                    obj.hCtrMSeriesSampClk.abort();
                end

                obj.hAOTaskGalvo.abort();
                obj.hAOTaskGalvo.control('DAQmx_Val_Task_Unreserve'); % to allow the galvo to be parked
            
                oldSampleRate = obj.rateAOSampClk;
                if obj.useSamplClkHelperTask
                    obj.hCtrMSeriesSampClk.set('sampQuantSampPerChan',length(obj.galvoBuffer));
                    obj.configureFrameClkTrigger(obj.hCtrMSeriesSampClk);
                    if ~obj.simulated
                        obj.hCtrMSeriesSampClk.channels(1).set('ctrTimebaseSrc',obj.hScan.trigReferenceClkOutInternalTerm);
                        obj.hCtrMSeriesSampClk.channels(1).set('ctrTimebaseRate',obj.hScan.trigReferenceClkOutInternalRate);
                    end
                    obj.hAOTaskGalvo.set('sampQuantSampPerChan',samplesPerFrame);
                    
                    obj.rateAOSampClk = get(obj.hCtrMSeriesSampClk.channels(1),'pulseFreq');
                else
                    obj.configureFrameClkTrigger(obj.hAOTaskGalvo);
                    obj.hAOTaskGalvo.set('sampQuantSampPerChan',samplesPerFrame);
                    if ~obj.simulated
                        if obj.hScan.useResonantTimebase
                            obj.hAOTaskGalvo.set('sampClkTimebaseSrc',obj.hScan.hTrig.getPXITerminal('resonantTimebaseOut'));
                            obj.hAOTaskGalvo.set('sampClkTimebaseRate',obj.hScan.resonantTimebaseNominalRate);
                        else
                            obj.hAOTaskGalvo.set('sampClkTimebaseSrc',obj.hScan.trigReferenceClkOutInternalTerm);
                            obj.hAOTaskGalvo.set('sampClkTimebaseRate',obj.hScan.trigReferenceClkOutInternalRate);
                        end
                    end
                    obj.rateAOSampClk = get(obj.hAOTaskGalvo,'sampClkRate');
                end
                % setting the sampClkTimebaseSrc might change the
                % rateAOSampClk. in this case execute updateTaskCfg one
                % more time
                if obj.rateAOSampClk ~= oldSampleRate
                    recurse = true;
                end
                
                timeout = 3;
            else
                timeout = nan;
            end
            
            % Update AO Buffers
            if restartTask
                obj.hAOTaskGalvo.abort();
                timeout = 3;
            end
            
            obj.hAOTaskGalvo.cfgOutputBuffer(bufferLength);
            obj.updateGalvoBufferAsync(timeout);
            
            if restartTask && obj.hScan.active
                obj.hAOTaskGalvo.start();
            end
            
            if recurse
                obj.updateTaskCfg();
            end
        end
        
        function updateGalvoBufferAsync(obj, timeout)
            
            if nargin < 2 || isempty(timeout)
                timeout = nan;
            end
            
            if obj.galvoBufferUpdatingAsyncNow
                % async call currently in progress. schedule update after current update finishes
                obj.galvoBufferNeedsUpdateAsync = true;
            else
                obj.galvoBufferNeedsUpdateAsync = false;
                obj.galvoBufferUpdatingAsyncNow = true;
                obj.hAOTaskGalvo.writeAnalogDataAsync(obj.galvoBuffer,[],[],[],@(src,evt)obj.updateGalvoBufferAsyncCallback(src,evt));
            end
            
            if ~isnan(timeout)
                t = tic;
                while obj.galvoBufferUpdatingAsyncNow
                    pause(.01);
                    assert(toc(t) < timeout, 'Galvo buffer write timed out.');
                end
            end
        end
        
        function updateGalvoBufferAsyncCallback(obj,~,evt)
            obj.galvoBufferUpdatingAsyncNow = false;
            
            if evt.status ~= 0 && evt.status ~= 200015 && obj.hScan.active
                fprintf(2,'Error updating galvo buffer: %s\n%s\n',evt.errorString,evt.extendedErrorInfo);
                
                if obj.galvoBufferUpdatingAsyncRetries < 3 || obj.galvoBufferNeedsUpdateAsync
                    obj.galvoBufferUpdatingAsyncRetries = obj.galvoBufferUpdatingAsyncRetries + 1;
                    fprintf(2,'Scanimage will retry update...\n');
                    obj.updateGalvoBufferAsync();
                else
                    obj.galvoBufferUpdatingAsyncRetries = 0;
                end
            else
                obj.galvoBufferUpdatingAsyncRetries = 0;

                if obj.galvoBufferNeedsUpdateAsync
                    obj.updateGalvoBufferAsync();
                end
            end
        end
        
        function [galvoPoints,samplesPerFrame,resScanOutputPoint] = getGalvoScanOutputPts(obj)
            resScanOutputPoint = max(obj.hScan.hSI.hWaveformManager.scannerAO.ao_volts.R);
            
            galvoPoints = obj.hScan.hSI.hWaveformManager.scannerAO.ao_volts.G;
            samplesPerFrame = obj.hScan.hSI.hWaveformManager.scannerAO.ao_samplesPerTrigger.G;
            
            assert(~mod(length(galvoPoints),samplesPerFrame),'Length of dataPoints has to be divisible by samplesPerFrame');
        end
    end
    
    %% Property Set Methods
    methods       
        function val = get.simulated(obj)
            val = obj.hScan.simulated;
        end
        
        function set.frameClockIn(obj,value)
            assert(~obj.acquisitionActive,'Cannot change %s while scanner is active','frameClockIn');
            validateattributes(value,{'char'},{'vector','nonempty'});
            
            obj.frameClockIn = value;
            % settings are applied in updateTaskCfg()
        end
        
        function set.galvoFlyBackPeriods(obj,value)
            assert(~obj.acquisitionActive,'Cannot change %s while scanner is active','galvoFlyBackPeriods');
            assert(value >= 1,'galvoFlyBackPeriods must be greater or equal to 1');
            obj.galvoFlyBackPeriods = value;
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
