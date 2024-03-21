classdef DI < dabs.resources.ios.D
    properties (Dependent, SetAccess=private, GetAccess=private)
        hTaskIn;
    end
    
    properties (SetAccess=private, GetAccess=private)
        hTaskIn_;
    end
    
    methods
        function obj = DI(name,hDAQ)
            obj@dabs.resources.ios.D(name,hDAQ);
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hTaskIn_);
        end
    end
    
    methods
        function samples = readValue(obj,n)
            if isa(obj.hDAQ,'dabs.resources.daqs.NIFlexRIOAdapterModule')
                samples = NaN(n,1);
                return
            end
            
            if nargin < 2 || isempty(n)
                n = 1;
            end
            
            samples = obj.hTaskIn.readChannelInputValues(n);
            obj.lastKnownValue = samples(end);
        end
    end
    
    methods
        function val = get.hTaskIn(obj)
            if isempty(obj.hTaskIn_)
                taskName = sprintf('Input Task %s %s',obj.hDAQ.name,regexprep(obj.channelName,'/',' '));
                hTaskIn__ = dabs.vidrio.ddi.DiTask(obj.hDAQ,taskName);
                hTaskIn__.addChannel(obj.channelName);
                obj.hTaskIn_ = hTaskIn__;
            end
            
            val = obj.hTaskIn_;
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
