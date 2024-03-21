classdef IO < dabs.resources.Resource
    properties (SetAccess = protected)
        hDAQ;
        
        deviceName;
        channelID;
        channelName;
    end
    
    properties
        lastKnownValue = NaN; % empty means that the value has not been read
    end
    
    events
        lastKnownValueChanged;
    end
    
    methods
        function obj = IO(name,hDAQ)
            obj@dabs.resources.Resource(name);
            obj.hDAQ = hDAQ;
            
            obj.deviceName = obj.hDAQ.name;
            obj.channelID = str2double(regexpi(obj.name,'[0-9]+$','match','once'));
            obj.channelName = regexprep(obj.name,'^\/[^\/]+\/','');
            
            addlistener(obj.hDAQ,'ObjectBeingDestroyed',@(varargin)obj.delete);
        end
    end
    
    methods
        function tf = isOnSameDAQ(obj,other)
            if iscell(other)
                tf = cellfun(@(hR)obj.isOnSameDAQ(hR),other);
            elseif isvector(other)
                tf = arrayfun(@(hR)obj.isOnSameDAQ(hR),other);
            elseif isa(other,'dabs.resources.IO')
                tf = isequal(obj.hDAQ,other.hDAQ);
            elseif isa(other,'dabs.resources.DAQ')
                tf = isequal(obj.hDAQ,other);
            elseif ischar(other)
                tf = strcmp(obj.hDAQ.name,other);
            end
        end
        
        function set.lastKnownValue(obj,val)
            oldVal = obj.lastKnownValue;
            
            obj.lastKnownValue = val;
            
            if ~isequal(obj.lastKnownValue,oldVal)
                notify(obj,'lastKnownValueChanged');
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
