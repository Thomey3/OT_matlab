classdef MotorRegistry
    properties (Constant)
        searchPath = fullfile(fileparts(mfilename('fullpath')),'+motorRegistryEntries');
    end
    
    methods (Static)
        function entries = getEntries()
            searchPath = scanimage.components.motors.MotorRegistry.searchPath;
            mFiles = most.util.getAllMFiles(searchPath);
            
            entries = scanimage.components.motors.motorRegistryEntries.Simulated.empty(1,0);
            
            for idx = 1:numel(mFiles)
                mc = meta.class.fromName(mFiles{idx});
                if ~isempty(mc)
                    superClassList = vertcat(mc.SuperclassList.Name);
                    if ismember('scanimage.components.motors.motorRegistryEntries.MotorRegistryEntry',superClassList)
                        constructor = str2func(mFiles{idx});
                        entries(end+1) = constructor();
                    end
                end
            end
        end
        
        function entry = searchEntry(name)
            entries = scanimage.components.motors.MotorRegistry.getEntries();
            
            entry = scanimage.components.motors.motorRegistryEntries.Simulated.empty(1,0);
            
            for idx = 1:numel(entries)
                tf = any(strcmpi(name,entries(idx).displayName));
                tf = tf || any(strcmpi(name,entries(idx).aliases));
                tf = tf || any(strcmpi(name,entries(idx).className));
                
                if tf
                    entry = entries(idx);
                    return
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
