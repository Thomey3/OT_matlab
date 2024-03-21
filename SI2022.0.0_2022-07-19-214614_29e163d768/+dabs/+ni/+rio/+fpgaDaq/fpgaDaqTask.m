classdef fpgaDaqTask < hgsetget
    %FPGADAQAOTASK Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        name;
        hFpgaDaq;
        chans;
        deviceNames;
        
        buffered = false;
        
        sampClkSrc;
        sampClkTimebaseSrc;
        sampClkTimebaseRate;
        sampClkRate;
        sampClkMaxRate;
        
        writeRegenMode;
        
        sampQuantSampMode;
        sampQuantSampPerChan;
        writeRelativeTo;
        writeOffset;
    end
    
    methods
        function obj = fpgaDaqTask(hDaq)
            obj.hFpgaDaq = hDaq;
            obj.deviceNames = {hDaq.deviceID};
        end
    end
    
    methods
        function control(~,cmd)
            assert(strcmp(cmd,'DAQmx_Val_Task_Unreserve'), 'Don''t know this cmd!');
        end
        
        function stop(obj)
            obj.abort();
        end
    end
    
    methods
        function set.sampClkSrc(~,v)
            assert(isempty(v), 'Cannot set sampClkSrc');
        end
        
        function set.sampClkTimebaseSrc(~,~)
            error('Cannot set sampClkTimebaseSrc');
        end
        
        function set.sampClkTimebaseRate(~,~)
            error('Cannot set sampClkTimebaseRate');
        end
        
        function set.sampClkRate(obj,v)
            obj.hFpgaDaq.hFpga.LoopPeriodControlticks = 40e6 / v;
        end
        
        function v = get.sampClkRate(obj)
            v = 40e6 / double(obj.hFpgaDaq.hFpga.LoopPeriodControlticks);
        end
        
        function v = get.sampClkMaxRate(~)
            v = 1e6;
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
