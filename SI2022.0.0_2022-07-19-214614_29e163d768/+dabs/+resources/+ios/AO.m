classdef AO < dabs.resources.IO
    properties (Dependent, SetAccess=private, GetAccess=private)
        hTask;
        hTaskFeedback;
    end
    
    properties (SetAccess=private, GetAccess=private)
        hListeners = event.listener.empty(0,1);
        hTask_;
        hTaskFeedback_;
    end
    
    properties (Dependent)
        supportsOutputReadback;
        supportsSlewRateLimit
        slewRateLimit_V_per_s;
        supportsOffset;
        outputRange_V;
        maxSampleRate_Hz;
    end
    
    methods
        function obj = AO(name,hDAQ)
            obj@dabs.resources.IO(name,hDAQ);

            if isa(obj.hDAQ,'dabs.resources.daqs.vDAQ') && ~obj.hDAQ.simulated
                obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResourceStore.hSystemTimer,'beacon_QueryIO',@(varargin)obj.maybeQueryValue);
            end
        end
        
        function delete(obj)
            delete(obj.hListeners);
            most.idioms.safeDeleteObj(obj.hTask_);
            most.idioms.safeDeleteObj(obj.hTaskFeedback_);
        end
    end
    
    methods
        function maybeQueryValue(obj)
            % only query value if anyone is listening
            if event.hasListener(obj,'lastKnownValueChanged')
                obj.queryValue();
            end
        end
        
        function val = queryValue(obj)
            if obj.hTask.supportsOutputReadback
                val = double(obj.hTask.channelValues);
            elseif most.idioms.isValidObj(obj.hTaskFeedback)
                try
                    val = obj.hTaskFeedback.readAnalogData();
                    obj.hTaskFeedback.control('DAQmx_Val_Task_Unreserve');
                catch ME
                    % this happens if the AIs of the DAQ device are reserved by another Task
                    val = NaN;
                end
            else
                val = NaN;
            end
            
            if ~isnan(val)
                obj.lastKnownValue = val;
            end
        end
        
        function setValue(obj,val)
            obj.hTask.setChannelOutputValues(val);
            obj.lastKnownValue = double(val);
        end
        
        function setOffset(obj,val)
            obj.hTask.setChannelOutputOffset(val);
        end
    end
    
    methods
        function set.slewRateLimit_V_per_s(obj,val)
            if obj.supportsSlewRateLimit
                obj.hTask.channelSlewRateLimits = val;
            end
        end
        
        function val = get.slewRateLimit_V_per_s(obj)
            if obj.supportsSlewRateLimit
                val = obj.hTask.channelSlewRateLimits;
            else
                val = Inf;
            end
        end
        
        function val = get.supportsSlewRateLimit(obj)
            val = obj.hTask.supportsSlewRateLimit;
        end
        
        function val = get.outputRange_V(obj)
            val = obj.hTask.channelRanges{1};
        end
        
        function val = get.maxSampleRate_Hz(obj)
            val = obj.hTask.maxSampleRate;
        end
        
        function val = get.supportsOffset(obj)
            val = obj.hTask.supportsOffset;
        end
        
        function val = get.supportsOutputReadback(obj)
            val = obj.hTask.supportsOutputReadback;
        end
    end
    
    methods
        function val = get.hTask(obj)
            if isempty(obj.hTask_)
                taskName = sprintf('Task %s AO%d',obj.hDAQ.name,obj.channelID);
                hTask__ = dabs.vidrio.ddi.AoTask(obj.hDAQ,taskName);
                hTask__.addChannel(obj);
                obj.hTask_ = hTask__;
            end
            
            val = obj.hTask_;
        end
        
        function val = get.hTaskFeedback(obj)
            if isempty(obj.hTaskFeedback_)
                hTask__ = dabs.ni.daqmx.Task();
                channelName = sprintf('_ao%d_vs_aognd',obj.channelID);
                try
                    hTask__.createAIVoltageChan(obj.hDAQ.name,channelName);
                catch ME
                    if ~isempty(strfind(ME.message,'-200170'))
                        % Physical channel specified does not exist on this device
                    else
                        most.ErrorHandler.logAndReportError(ME);
                    end
                    most.idioms.safeDeleteObj(hTask__);
                    hTask__ = -1;
                end
                obj.hTaskFeedback_ = hTask__;
            end
            
            val = [];
            if most.idioms.isValidObj(obj.hTaskFeedback_)
                val = obj.hTaskFeedback_;
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
