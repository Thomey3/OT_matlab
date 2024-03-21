classdef NIDAQ < dabs.resources.DAQ
    properties (SetAccess = private)
        serial = '';
        productType = '';
        productCategory = '';
        isXSer = false;
        busType = '';
        simultaneousSampling = false;
        maxSingleChannelRate = 0;
        maxMultiChannelRate = 0;
        pxiNumber = NaN;
        pxiSlotNumber = NaN;
    end
    
    properties (SetAccess = protected)
        hDevice
    end
        
    methods
        function obj = NIDAQ(name)
            obj@dabs.resources.DAQ(name);
            
            hDaqSys = dabs.ni.daqmx.System;
            hDev = dabs.ni.daqmx.Device(name);
            
            obj.serial = dec2hex(hDev.serialNum,8);
            obj.productType = hDev.productType;
            obj.productCategory = hDev.productCategory;
            obj.isXSer = strcmp(obj.productCategory,'DAQmx_Val_XSeriesDAQ');
            obj.busType = get(hDev,'busType');
            obj.simulated = get(hDev,'isSimulated');
            
            try
                obj.simultaneousSampling = get(hDev,'AISimultaneousSamplingSupported');
            catch
                obj.simultaneousSampling = false;
            end
            if isempty(obj.simultaneousSampling) 
                obj.simultaneousSampling = false;
            end
            
            try
                obj.maxSingleChannelRate = get(hDev,'AIMaxSingleChanRate');
            catch
                obj.maxSingleChannelRate = 0;
            end
            if isempty(obj.maxSingleChannelRate)
                obj.maxSingleChannelRate = 0;
            end
            
            try
                obj.maxMultiChannelRate = get(hDev,'AIMaxMultiChanRate');
            catch
                obj.maxMultiChannelRate = 0;
            end
            if isempty(obj.maxMultiChannelRate)
                obj.maxMultiChannelRate = 0;
            end
            
            if strncmp(obj.busType,'DAQmx_Val_PXI',13)
                obj.pxiNumber = get(hDev,'PXIChassisNum');
                obj.pxiSlotNumber = get(hDev,'PXISlotNum');
                if obj.pxiNumber == 2^32-1
                    obj.pxiNumber = 1;
                end
            end
            
            [r, a] = hDaqSys.apiCall('DAQmxGetDevAOPhysicalChans',name,blanks(5000),5000);
            numAOs = numel(strsplit(a,','));
            for idx = 1:numAOs
                hAO = dabs.resources.ios.AO(sprintf('/%s/AO%d',name,idx-1),obj);
                obj.hAOs(end+1) = hAO;
            end
            
            [r, a] = hDaqSys.apiCall('DAQmxGetDevAIPhysicalChans',name,blanks(5000),5000);
            numAIs = numel(strsplit(a,','));
            for idx = 1:numAIs
                hAI = dabs.resources.ios.AI(sprintf('/%s/AI%d',name,idx-1),obj);
                obj.hAIs(end+1) = hAI;
            end
            
            if obj.isXSer && ~isempty(obj.hAIs)
                numAOs = numel(obj.hAOs);
                if obj.simultaneousSampling
                    internal_channels = internalChannels_XSeries_simultaneous(numAOs);
                else
                    internal_channels = internalChannels_XSeries_multiplexed(numAOs);
                end
                
                for idx = 1:numel(internal_channels)
                    hAI_Internal = dabs.resources.ios.AI_Internal(sprintf('/%s/%s',name,internal_channels{idx}),obj);
                    obj.hAIs_Internal(end+1) = hAI_Internal;
                end
            end
            
            [r, a] = hDaqSys.apiCall('DAQmxGetDevTerminals',name,blanks(5000),5000);
            a = strtrim(strsplit(a,','));
            terminals = regexpi(a,'.*/PFI[0-9]+','match','once'); % filter for PFI terminals
            for idx = 1:numel(terminals)
                if ~isempty(terminals{idx})
                    hPFI = dabs.resources.ios.PFI(terminals{idx},obj);
                    obj.hPFIs(end+1) = hPFI;
                end
            end
            
            [r, a] = hDaqSys.apiCall('DAQmxGetDevDILines',name,blanks(5000),5000);
            lines = cellfun(@(s)s(length(name)+2:end),strtrim(strsplit(a,',')),'uniformoutput',false)';
            
            for idx = 1:numel(lines)
                lineName = lines{idx};
                hDIO = dabs.resources.ios.DIO(sprintf('/%s/%s',name,lineName),obj);
                isPort0 = ~isempty( regexp(lineName,'^port0\/','once') );
                hDIO.supportsHardwareTiming = isPort0;
                obj.hDIOs(end+1) = hDIO;
            end
        end
    end
    
    methods
        function reset(obj)
            obj.hDevice.reset();
        end        
    end
    
    methods
        function val = get.hDevice(obj)
            val = dabs.ni.daqmx.Device(obj.name);
        end
    end
    
    methods (Static)
        function r = scanSystem()
            r = {};
            
            try
                hDaqSys = dabs.ni.daqmx.System;
            catch ME
                return % DAQmx driver is not installed
            end
                
            hResourceStore = dabs.resources.ResourceStore();
            dn = strtrim(hDaqSys.devNames);

            if ~isempty(dn)
                daqNames = strtrim(strsplit(dn,','))';

                for idx = 1:numel(daqNames)
                    daqName = daqNames{idx};
                    if isempty(hResourceStore.filterByName(daqName))
                        try
                            dabs.resources.daqs.NIDAQ(daqName);
                        catch ME
                            most.ErrorHandler.logAndReportError(ME,'Failed to instantiate NI DAQ ''%s''',daqName);
                        end
                    end
                end
            end
            
            r = hResourceStore.filterByClass(mfilename('class'));
        end
    end
end


function chns = internalChannels_XSeries_multiplexed(numAOs)
    % Internal Channels for X Series Multiplexed Sampling 
    % https://zone.ni.com/reference/en-XX/help/370466AH-01/mxdevconsid/xseriesinterchan/
    chns = {};
    chns{end+1} = '_aignd_vs_aignd';              % A single-ended terminal with the positive and negative terminals both connected to the ground reference for analog input.
    for idx = 1:numAOs
        chns{end+1} = sprintf('_ao%d_vs_aognd',idx-1); % A differential terminal with the positive terminal connected to physical channel ao0 and the negative terminal connected to the ground reference for analog output.
    end
    chns{end+1} = '_calref_vs_aignd';             % A single-ended terminal with the positive terminal connected to the internal calibration reference voltage and the negative terminal connected to the ground reference for analog input.
    chns{end+1} = '_aignd_vs_aisense';            % A differential terminal with the positive terminal connected to the ground reference for analog input and the negative terminal connected to physical channel AI SENSE.
    chns{end+1} = '_aignd_vs_aisense2';           % A differential terminal with the positive terminal connected to the ground reference for analog input and the negative terminal connected to physical channel AI SENSE2.
    chns{end+1} = '_aignd_vs_aisense3';           % A differential terminal with the positive terminal connected to the ground reference for analog input and the negative terminal connected to physical channel AI SENSE3.
    chns{end+1} = '_aignd_vs_aisense4';           % A differential terminal with the positive terminal connected to the ground reference for analog input and the negative terminal connected to physical channel AI SENSE4.
    chns{end+1} = '_calSrcHi_vs_aignd';           % A single-ended terminal with the positive terminal connected to the calibration PWM and the negative terminal connected to the ground reference for analog input.
    chns{end+1} = '_calref_vs_calSrcHi';          % A differential terminal with the positive terminal connected to the internal calibration reference voltage and the negative terminal connected to the calibration PWM.
    chns{end+1} = '_calSrcHi_vs_calSrcHi';        % A differential terminal with the positive and negative terminals connected to the calibration PWM.
    chns{end+1} = '_aignd_vs_calSrcHi';           % A differential terminal with the positive terminal connected to the ground reference for analog input and the negative terminal connected to the calibration PWM.
    chns{end+1} = '_calSrcMid_vs_aignd';          % A single-ended terminal with the positive terminal connected to the calibration PWM and the negative terminal connected to the ground reference for analog input. _calSrcMid is the divided down version of _calSrcHi.
    chns{end+1} = '_calSrcLo_vs_aignd';           % A single-ended terminal with the positive terminal connected to the calibration PWM and the negative terminal connected to the ground reference for analog input. _calSrcLo is the divided down version of _calSrcHi.
    chns{end+1} = '_ai0_vs_calSrcHi';             % A differential terminal with the positive terminal connected to physical channel ai0 and the negative terminal connected to the calibration PWM.
    chns{end+1} = '_ai8_vs_calSrcHi';             % A differential terminal with the positive terminal connected to physical channel ai8 and the negative terminal connected to the calibration PWM.
    chns{end+1} = '_boardTempSensor_vs_aignd';    % A single-ended terminal with the positive terminal connected to the onboard temperature sensor and the negative terminal connected to the ground reference for analog input.;
end

function chns = internalChannels_XSeries_simultaneous(numAOs)
    % Internal Channels for X Series Simultaneous Sampling Devices
    % https://zone.ni.com/reference/en-XX/help/370466AH-01/mxdevconsid/xseriessimulinterchan/
    chns = {};
    chns{end+1} = '_external_channel';     % The differential terminal on the I/O connector that is typically used for acquiring data.
    chns{end+1} = '_ai0_vs_calSrcHi';      % A differential terminal with the positive terminal connected to physical channel ao0 and the negative terminal connected to the calibration PWM.
    chns{end+1} = '_ai1_vs_calSrcHi';      % A differential terminal with the positive terminal connected to physical channel ao1 and the negative terminal connected to the calibration PWM
    chns{end+1} = '_aignd_vs_aignd';       % A single-ended terminal with the positive and negative terminals both connected to the ground reference for analog input.
    chns{end+1} = '_aignd_vs_calSrcHi';    % A differential terminal with the positive terminal connected to the ground reference for analog input and the negative terminal connected to the calibration PWM.
    for idx = 1:numAOs
        chns{end+1} = sprintf('_ao%d_vs_aognd',idx-1);    % A differential terminal with the positive terminal connected to physical channel ao0 and the negative terminal connected to the ground reference for analog output.
        chns{end+1} = sprintf('_ao%d_vs_calSrcHi',idx-1); % A differential terminal with the positive terminal connected to physical channel ao0 and the negative terminal connected to the calibration PWM.
    end
    chns{end+1} = '_calref_vs_aignd';      % A single-ended terminal with the positive terminal connected to the internal calibration reference voltage and the negative terminal connected to the ground reference for analog input.
    chns{end+1} = '_calSrcHi_vs_aignd';    % A single-ended terminal with the positive terminal connected to the calibration PWM and the negative terminal connected to the ground reference for analog input.
    chns{end+1} = '_calref_vs_calSrcHi';   % A differential terminal with the positive terminal connected to the internal calibration reference voltage and the negative terminal connected to the calibration PWM.
    chns{end+1} = '_calSrcMid_vs_aignd';   % A single-ended terminal with the positive terminal connected to the calibration PWM and the negative terminal connected to the ground reference for analog input. _calSrcMid is the divided down version of _calSrcHi.
    chns{end+1} = '_calSrcHi_vs_ai0';      % A differential terminal with the positive terminal connected to the calibration PWM and the negative terminal connected to physical channel ai0.
    chns{end+1} = '_calSrcHi_vs_ai8';      % A differential terminal with the positive terminal connected to the calibration PWM and the negative terminal connected to physical channel ai8.
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
