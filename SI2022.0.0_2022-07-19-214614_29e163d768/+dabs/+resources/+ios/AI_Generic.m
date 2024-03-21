classdef AI_Generic < dabs.resources.IO
    properties (Dependent, SetAccess=private, GetAccess=private)
        hTask;
    end
    
    properties (SetAccess=private, GetAccess=private)
        hTask_;
    end
    
    properties (SetAccess=private)
        defaultTermCfg;
    end
    
    properties (Dependent)
        maxSampleRate_Hz;
        termCfg;
    end
    
    methods
        function obj = AI_Generic(name,hDAQ)
            obj@dabs.resources.IO(name,hDAQ);
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hTask_);
        end
    end
    
    methods
        function samples = readValue(obj,n)
            if nargin<2 || isempty(n)
                n = 1;
            end
            
            samples = obj.hTask.readChannelInputValues(n);
            obj.lastKnownValue = samples(end);
        end
    end
    
    methods
        function val = get.termCfg(obj)
            if isa(obj.hDAQ,'dabs.resources.daqs.vDAQ')
                val = 'Differential';
            else
                val = obj.hTask.terminalConfig{1};
            end
        end
        
        function set.termCfg(obj,val)
            if isa(obj.hDAQ,'dabs.resources.daqs.vDAQ')
                return; % not supported
            end
            
            switch lower(val)
                case {'','default'}
                    val = obj.defaultTermCfg;
                case {'rse','daqmx_val_rse'}
                    val = 'DAQmx_Val_RSE';
                case {'nrse','daqmx_val_nrse'}
                    val = 'DAQmx_Val_NRSE';
                case {'differential','diff','daqmx_val_diff'}
                    val = 'DAQmx_Val_Diff';
                case {'pseudodiff','pseudodifferential','daqmx_val_pseudodiff'}
                    val = 'DAQmx_Val_PseudoDiff';                    
                otherwise
                    error('Invalid value: %s',val);
            end
            
            obj.hTask.terminalConfig = val;
        end
        
        function val = get.maxSampleRate_Hz(obj)
            val = obj.hTask.maxSampleRate;
        end
        
        function val = get.defaultTermCfg(obj)
            obj.initTask();
            val = obj.defaultTermCfg;
        end
        
        function val = get.hTask(obj)
            val = obj.initTask();
        end
    end
    
    methods
        function hTask = initTask(obj)
            if isempty(obj.hTask_)
                taskName = sprintf('Task %s AI%d',obj.hDAQ.name,obj.channelID);
                hTask__ = dabs.vidrio.ddi.AiTask(obj.hDAQ,taskName);
                hTask__.addChannel(obj);
                obj.hTask_ = hTask__;
                
                if isa(obj.hDAQ,'dabs.resources.daqs.vDAQ')
                    obj.defaultTermCfg = 'Differential';
                else
                    obj.defaultTermCfg = obj.hTask_.terminalConfig{1};
                end
            end
            
            hTask = obj.hTask_;
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
