classdef DAQ < dabs.resources.Resource
    properties (SetAccess = protected)
        hAOs = dabs.resources.ios.AO.empty();
        hAIs = dabs.resources.ios.AI.empty();
        hAIs_Internal = dabs.resources.ios.AI_Internal.empty();
        hPFIs = dabs.resources.ios.PFI.empty();
        hDIOs = dabs.resources.ios.DIO.empty();
        hDIs = dabs.resources.ios.DI.empty();
        hDOs = dabs.resources.ios.DO.empty();
        hCLKIs = dabs.resources.ios.CLKI.empty();
        hCLKOs = dabs.resources.ios.CLKO.empty();
        hDigitizerAIs = dabs.resources.ios.DigitizerAI.empty();
    end
    
    properties (Dependent)
        hIOs;
    end
    
    properties (SetAccess = protected)
        simulated = false;
    end
    
    properties (Abstract, SetAccess = protected)
        hDevice
    end
    
    methods
        function obj = DAQ(name)
            obj@dabs.resources.Resource(name);
        end
    end
    
    methods (Abstract)
        reset(obj);
    end

    methods (Static)
        function scanSystem()
            dabs.resources.daqs.vDAQ.scanSystem();
            dabs.resources.daqs.NIRIO.scanSystem();
            dabs.resources.daqs.NIDAQ.scanSystem();
        end
    end
    
    methods
        function v = get.hIOs(obj)
            v = horzcat(...
                 num2cell(obj.hAOs)   ...
                ,num2cell(obj.hAIs)   ...
                ,num2cell(obj.hAIs_Internal) ...
                ,num2cell(obj.hPFIs)  ...
                ,num2cell(obj.hDIOs)  ...
                ,num2cell(obj.hDIs)   ...
                ,num2cell(obj.hDOs)   ...
                ,num2cell(obj.hCLKIs) ...
                ,num2cell(obj.hCLKOs) ...
                );
        end
        
        function hUsers = getAllUsers(obj)
            u = cellfun(@getUsers,obj.hIOs,'UniformOutput',false);
            u{end+1} = obj.hUsers;
            hUsers = horzcat(u{:});
            
            function uu = getUsers(h)
                if most.idioms.isValidObj(h)
                    uu = h.hUsers;
                else
                    uu = {};
                end
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
