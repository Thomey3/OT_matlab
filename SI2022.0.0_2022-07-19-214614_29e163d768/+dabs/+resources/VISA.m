classdef VISA < dabs.resources.Resource
    properties (SetAccess = private)
        driverInfo
    end
    
    methods
        function obj = VISA(name)
            obj@dabs.resources.Resource(name);
        end
    end
    
    methods (Static)
        function [v,driverInfo] = scanSystem()
            hResourceStore = dabs.resources.ResourceStore();
            
            instrNames = {};
            try
                [instrNames,driverInfo] = dabs.ivi.visa.findResources();
            catch ME
                if strcmpi(ME.message,'VISA driver is not installed.')
                    % VISA driver is not installed
                else
                    most.ErrorHandler.logAndReportError(ME);
                end
            end
            
            existingVisaResources = hResourceStore.filterByClass('dabs.resources.VISA');
            existingNames = cellfun(@(hR)hR.name,existingVisaResources,'UniformOutput',false);
            [~,toDeleteMask] = setdiff(existingNames,instrNames);
            cellfun(@(hR)hR.delete,existingVisaResources(toDeleteMask));
            
            for idx = 1:numel(instrNames)
                name = instrNames{idx};
                if isempty(hResourceStore.filterByName(name))
                    h = dabs.resources.VISA(name);
                    h.driverInfo = driverInfo;
                end
            end
            
            v = hResourceStore.filterByClass('dabs.resources.VISA');
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
