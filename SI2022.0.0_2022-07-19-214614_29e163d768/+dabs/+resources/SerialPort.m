classdef SerialPort < dabs.resources.Resource
    properties (SetAccess = private,Dependent)
        number;
    end
    
    methods
        function obj = SerialPort(name)
            obj@dabs.resources.Resource(name);
        end
        
        function checkForErrors(obj)
            % No-op
        end
    end
    
    methods
        function val = get.number(obj)
            val = regexp(obj.name,'[0-9]+$','once','match');
            val = str2double(val);
        end
    end
    
    methods (Static)
        function r = scanSystem()
            if verLessThan('matlab','9.2')
                availableComPorts = arrayfun(@(x){sprintf('COM%d',x)},sort(dabs.generic.serial.findComPorts()));
            elseif verLessThan('matlab','9.7')
                % seriallist was introduced in Matlab R2017a
                availableComPorts = seriallist();
                availableComPorts = cellstr(availableComPorts);
            else
                % seriallist was introduced in Matlab R2019b
                availableComPorts = serialportlist();
                availableComPorts = cellstr(availableComPorts);
            end
            
            hResourceStore = dabs.resources.ResourceStore();
            
            for idx = 1:numel(availableComPorts)
                port = availableComPorts{idx};
                
                if isempty(hResourceStore.filterByName(port))
                    dabs.resources.SerialPort(port);
                end
            end
            
            r = hResourceStore.filterByClass(mfilename('class'));
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
