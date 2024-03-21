classdef Triggering < scanimage.interfaces.Class
    %% FRIEND PROPS
    
    %%% The ScanImage timing signals
    properties
        periodClockIn = '';
        acqTriggerIn = '';
        nextFileMarkerIn = '';
        acqStopTriggerIn = '';
        laserTriggerIn = '';
        auxTrigger1In = '';
        auxTrigger2In = '';
        auxTrigger3In = '';
        auxTrigger4In = '';
        
        frameClockOut = '';
        lineClockOut = '';
        beamModifiedLineClockOut = '';
        volumeTriggerOut = '';
        
        sampleClkTermInt = '';
        lineClkTermInt = '';
        beamClkTermInt = '';
        sliceClkTermInt = '';
        volumeClkTermInt = '';
    end
    
    %%% Acq flow trigger input polarity 
    properties (Hidden)
        acqTriggerOnFallingEdge = false;
        nextFileMarkerOnFallingEdge = false;
        acqStopTriggerOnFallingEdge = false;
        
        enabled = true; % querried in si controller
        routes = {};
        routesEnabled = true;
    end

    %% INTERNAL PROPERTIES
    properties (Hidden, SetAccess=immutable)
        hScan;
        hAcq;
        hCtl;
    end
    
    properties (Hidden, Dependent, SetAccess = private)
        hFpga;
        hFpgaAE;
        externalTrigTerminalOptions; 
    end
    
    %% Lifecycle
    methods
        function obj = Triggering(hScan)
            % Validate input arguments
            obj.hScan = hScan;
            obj.hAcq = obj.hScan.hAcq;
            obj.hCtl = obj.hScan.hCtl;
            
            aeId = obj.hScan.mdfData.acquisitionEngineIdx-1;
            obj.sampleClkTermInt = sprintf('si%d_ctlSampleClk',aeId);
            obj.lineClkTermInt = sprintf('si%d_lineClk',aeId);
            obj.beamClkTermInt = sprintf('si%d_beamClk',aeId);
            obj.sliceClkTermInt = sprintf('si%d_sliceClk',aeId);
            obj.volumeClkTermInt = sprintf('si%d_volumeClk',aeId);
        end
        
        function delete(obj)
            if obj.hScan.mdlInitialized
                obj.unregisterTriggers();
            end
        end
        
        function applyTriggerConfig(obj)            
            if isempty(obj.hScan.hResonantScanner) || isempty(obj.hScan.hResonantScanner.hDISync)
                syncTerm = '';
            else
                syncTerm = obj.hScan.hResonantScanner.hDISync.channelName;
            end
            
            if isfield(obj.hScan.mdfData, 'simulatedResonantMirrorPeriod') && ~isempty(obj.hScan.mdfData.simulatedResonantMirrorPeriod)
                obj.hFpgaAE.acqParamSimulatedResonantPeriod = obj.hScan.mdfData.simulatedResonantMirrorPeriod;
            else
                obj.hFpgaAE.acqParamSimulatedResonantPeriod = 0;
            end
            
            
            obj.periodClockIn = syncTerm;
            dbt = obj.hScan.mdfData.PeriodClockDebounceTime * obj.hAcq.stateMachineLoopRate;
            obj.hFpgaAE.acqParamPeriodTriggerDebounce = round(dbt);
            
            if most.idioms.isValidObj(obj.hScan.hResonantScanner)
                resScanFreq = obj.hScan.hResonantScanner.currentFrequency_Hz;
                obj.hFpgaAE.acqParamPeriodTriggerMaxPeriod = min(2^18-1,round(1.05*obj.hFpga.nominalDataClkRate/resScanFreq));
                obj.hFpgaAE.acqParamPeriodTriggerMinPeriod = min(2^18-1,round(0.95*obj.hFpga.nominalDataClkRate/resScanFreq));
                obj.hFpgaAE.acqParamPeriodTriggerSettledThresh = 50;
                obj.hFpgaAE.acqParamPeriodTriggerSettledGate = 1;
            end
            
            obj.laserTriggerIn = obj.hScan.LaserTriggerPort;
            
            obj.auxTrigger1In = obj.hScan.auxTrigger1In;
            obj.auxTrigger2In = obj.hScan.auxTrigger2In;
            obj.auxTrigger3In = obj.hScan.auxTrigger3In;
            obj.auxTrigger4In = obj.hScan.auxTrigger4In;
            
            obj.frameClockOut = obj.hScan.frameClockOut;
            obj.lineClockOut = obj.hScan.lineClockOut;
            obj.beamModifiedLineClockOut = obj.hScan.beamModifiedLineClockOut;
            obj.volumeTriggerOut = obj.hScan.volumeTriggerOut;
            
            obj.hFpgaAE.acqParamLaserClkDebounce = obj.hScan.laserTriggerDebounceTicks;
        end
        
        function start(obj)
            tfNS = obj.hScan.trigNextStopEnable && obj.hScan.trigAcqTypeExternal;
            
            if tfNS && ~isempty(obj.nextFileMarkerIn)
                obj.hFpgaAE.acqParamNextTriggerChIdx = obj.hFpga.dioNameToId(obj.nextFileMarkerIn);
            else
                obj.hFpgaAE.acqParamNextTriggerChIdx = obj.hFpga.dioNameToId([]);
            end
            
            if tfNS && ~isempty(obj.acqStopTriggerIn)
                obj.hFpgaAE.acqParamStopTriggerChIdx = obj.hFpga.dioNameToId(obj.acqStopTriggerIn);
            else
                obj.hFpgaAE.acqParamStopTriggerChIdx = obj.hFpga.dioNameToId([]);
            end
            
            if obj.hScan.trigAcqTypeExternal && ~isempty(obj.acqTriggerIn)
                obj.hFpgaAE.acqParamStartTriggerChIdx = obj.hFpga.dioNameToId(obj.acqTriggerIn);
            else
                obj.hFpgaAE.acqParamStartTriggerChIdx = obj.hFpga.dioNameToId([]);
            end
            
            obj.applyTriggerConfig();
        end
            
        function stop(~)
        end
    end
    
    methods (Hidden)
        function reinitRoutes(obj)
            for i = 1:numel(obj.routes)
                obj.hFpga.setDioOutput(obj.routes{i}{2},obj.routes{i}{1});
            end
            obj.routesEnabled = true;
        end
        
        function deinitRoutes(obj)
            if obj.routesEnabled
                for i = 1:numel(obj.routes)
                    obj.hFpga.setDioOutput(obj.routes{i}{2}, 'Z');
                end
            end
            obj.routesEnabled = false;
        end
        
        function addRoute(obj,signal,dest)
            % make sure there is not already a route using the selected destination
            if isempty(dest)
                dest = '';
            elseif isa(dest,'dabs.resources.ios.D')
                dest = dest.channelName;
            end
            
            assert(~any(cellfun(@(rt)isequal(rt{2},dest),obj.routes)), 'Selected output is already in use.');
            
            % make sure it is a valid signal
            assert(ismember(signal, obj.hFpga.spclOutputSignals), 'Selected signal is not valid.');
            
            % add it to the list
            obj.routes{end+1} = {signal, dest};
            
            % if routes are active, enable it
            if obj.routesEnabled
                obj.hFpga.setDioOutput(dest,signal);
            end
        end
        
        function removeRoute(obj,signal,dest)
            % find it in the list
            if isempty(dest)
                dest = '';
            elseif isa(dest,'dabs.resources.ios.D')
                dest = dest.channelName;
            end
            
            id = find(cellfun(@(rt)isequal(rt{1},signal)&&isequal(rt{2},dest),obj.routes));
            
            if ~isempty(id)
                if obj.routesEnabled
                    obj.hFpga.setDioOutput(obj.routes{id}{2},'Z');
                end
                obj.routes(id) = [];
            end
        end
        
        function unregisterTriggers(obj)
            obj.changeTriggerUsageRegistration(false);
        end
        
        function registerTriggers(obj)
            obj.changeTriggerUsageRegistration(true);
        end
        
        function changeTriggerUsageRegistration(obj,registrationStatus)
            tf = registrationStatus;
            
            changeRegistration(tf,obj.acqTriggerIn,     'Acq Start');
            changeRegistration(tf,obj.nextFileMarkerIn, 'Next File');
            changeRegistration(tf,obj.acqStopTriggerIn, 'Acq Stop');
            
            %%% Nested function
            function changeRegistration(registrationStatus,terminal,description)
                try
                    daqName = obj.hScan.hDAQ.name;
                    if ischar(terminal)
                        terminal = regexpi(terminal,'[^/]+$','match','once'); % strip out /vDAQ0/ first to ensure uniform format
                        terminal = sprintf('/%s/%s',daqName,terminal); % add /vDAQ0/ back in
                    end
                    hIO = obj.hScan.hResourceStore.filterByName(terminal);
                    if ~isempty(hIO)
                        if registrationStatus
                            hIO.registerUser(obj.hScan,description);
                        else
                            hIO.unregisterUser(obj.hScan);
                        end
                    end
                catch ME
                    most.ErrorHandler.logAndReportError(ME) ;
                end
            end            
        end
    end
    
    %% Property Setter Methods
    methods
        function val = get.externalTrigTerminalOptions(obj)
            val = [{''} obj.hFpga.dioInputOptions];
        end
        
        function val = get.hFpga(obj)
            val = obj.hAcq.hFpga;
        end
        
        function val = get.hFpgaAE(obj)
            val = obj.hAcq.hAcqEngine;
        end            
            
        function set.acqTriggerIn(obj,newTerminal)
            obj.unregisterTriggers();
            
            id = obj.hFpga.dioNameToId(newTerminal);
            
            % make sure terminal is valid
            obj.acqTriggerIn = newTerminal;
            
            if obj.hScan.active && obj.hScan.trigAcqTypeExternal
                obj.hFpgaAE.acqParamStartTriggerChIdx = id;
            end
            
            obj.registerTriggers();
        end
        
        function set.nextFileMarkerIn(obj,newTerminal)
            obj.unregisterTriggers();
            
            % make sure terminal is valid
            id = obj.hFpga.dioNameToId(newTerminal);
            
            obj.nextFileMarkerIn = newTerminal;
            
            if obj.hScan.active && obj.hScan.trigNextStopEnable && obj.hScan.trigAcqTypeExternal
                obj.hFpgaAE.acqParamNextTriggerChIdx = id;
            end
            
            obj.registerTriggers();
        end
        
        function set.acqStopTriggerIn(obj,newTerminal)
            obj.unregisterTriggers();
            
            % make sure terminal is valid
            id = obj.hFpga.dioNameToId(newTerminal);
            
            obj.acqStopTriggerIn = newTerminal;
            
            if obj.hScan.active && obj.hScan.trigNextStopEnable && obj.hScan.trigAcqTypeExternal
                obj.hFpgaAE.acqParamStopTriggerChIdx = id;
            end
            
            obj.registerTriggers();
        end
        
        function set.periodClockIn(obj,newTerminal)
            id = obj.hFpga.dioNameToId(newTerminal);
            
            obj.periodClockIn = newTerminal;
            obj.hFpgaAE.acqParamPeriodTriggerChIdx = id;
        end
        
        function set.laserTriggerIn(obj,newTerminal)
            if isa(newTerminal,'dabs.resources.ios.CLKI') || any(strcmp(newTerminal, {'CLK IN','CLK_IN'}))
                id = 48;
            else
                id = obj.hFpga.dioNameToId(newTerminal);
            end
            
            obj.laserTriggerIn = newTerminal;
            obj.hFpgaAE.acqParamLaserClkChIdx = id;
        end
        
        function set.auxTrigger1In(obj,newTerminal)
            id = obj.hFpga.dioNameToId(newTerminal);
            
            obj.auxTrigger1In = newTerminal;
            obj.hFpgaAE.acqParamAuxTrig1TriggerChIdx = id;
        end
        
        function set.auxTrigger2In(obj,newTerminal)
            id = obj.hFpga.dioNameToId(newTerminal);
            
            obj.auxTrigger2In = newTerminal;
            obj.hFpgaAE.acqParamAuxTrig2TriggerChIdx = id;
        end
        
        function set.auxTrigger3In(obj,newTerminal)            
            id = obj.hFpga.dioNameToId(newTerminal);
            
            obj.auxTrigger3In = newTerminal;
            obj.hFpgaAE.acqParamAuxTrig3TriggerChIdx = id;
        end
        
        function set.auxTrigger4In(obj,newTerminal)
            id = obj.hFpga.dioNameToId(newTerminal);
            
            obj.auxTrigger4In = newTerminal;
            obj.hFpgaAE.acqParamAuxTrig4TriggerChIdx = id;
        end
        
        function set.frameClockOut(obj,newTerminal)
            if ~isempty(obj.frameClockOut)
                obj.removeRoute(obj.sliceClkTermInt,obj.frameClockOut);
            end
            obj.frameClockOut = '';
            
            if ~isempty(newTerminal)
                obj.addRoute(obj.sliceClkTermInt, newTerminal);
            end
            obj.frameClockOut = newTerminal;
        end
        
        function set.lineClockOut(obj,newTerminal)
            if ~isempty(obj.lineClockOut)
                obj.removeRoute(obj.lineClkTermInt,obj.lineClockOut);
            end
            obj.lineClockOut = '';
            
            if ~isempty(newTerminal)
                obj.addRoute(obj.lineClkTermInt, newTerminal);
            end
            obj.lineClockOut = newTerminal;
        end        
        
        function set.beamModifiedLineClockOut(obj,newTerminal)
            if ~isempty(obj.beamModifiedLineClockOut)
                obj.removeRoute(obj.beamClkTermInt,obj.beamModifiedLineClockOut);
            end
            obj.beamModifiedLineClockOut = '';
            
            if ~isempty(newTerminal)
                obj.addRoute(obj.beamClkTermInt, newTerminal);
            end
            obj.beamModifiedLineClockOut = newTerminal;
        end
        
        function set.volumeTriggerOut(obj,newTerminal)            
            if ~isempty(obj.volumeTriggerOut)
                obj.removeRoute(obj.volumeClkTermInt,obj.volumeTriggerOut);
            end
            obj.volumeTriggerOut = '';
            
            if ~isempty(newTerminal)
                obj.addRoute(obj.volumeClkTermInt, newTerminal);
            end
            obj.volumeTriggerOut = newTerminal;
        end
        
        function set.acqTriggerOnFallingEdge(obj,val)
            validateattributes(val,{'logical'},{'scalar','nonempty'});
            obj.acqTriggerOnFallingEdge = val;
            obj.hFpgaAE.acqParamStartTriggerInvert = val;
        end        
        
        function set.nextFileMarkerOnFallingEdge(obj,val)
            validateattributes(val,{'logical'},{'scalar','nonempty'});
            obj.nextFileMarkerOnFallingEdge = val;
            obj.hFpgaAE.acqParamNextTriggerInvert = val;
        end
        
        function set.acqStopTriggerOnFallingEdge(obj,val)
            validateattributes(val,{'logical'},{'scalar','nonempty'});
            obj.acqStopTriggerOnFallingEdge = val;
            obj.hFpgaAE.acqParamStopTriggerInvert = val;
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
