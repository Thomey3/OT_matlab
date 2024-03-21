classdef HasConfigPage < handle
    properties (Abstract, SetAccess=protected, Hidden)
        ConfigPageClass
    end
    
    methods (Abstract,Static,Hidden)
        names = getDescriptiveNames() % returns cell string of descriptive names; this is a function so it can be overloaded
    end
    
    methods (Static,Hidden)
        function classes = getClassesToLoadFirst()
            % overload if needed
            classes = {};
        end
    end
    
    methods        
        function showConfig(obj)
            try
                assert(~isempty(obj.ConfigPageClass),'ConfigPageClass cannot be empty');
                assert(logical(exist(obj.ConfigPageClass,'class')),'ConfigPageClass ''%s'' does not exist',obj.ConfigPageClass);
                assert(most.idioms.isa(obj.ConfigPageClass,'dabs.resources.configuration.ResourcePage'),...
                    '''%s'' is not a valid ''%s''',obj.ConfigPageClass);
                
                hEditor = dabs.resources.configuration.ResourceConfigurationEditor();
                hEditor.showPage(obj);
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
        end
    end
    
    methods (Hidden)
        function hPage = makeConfigPage(obj,hParent)
            if nargin < 2 || isempty(hParent)
                hParent = [];
            end
            
            if isempty(obj.ConfigPageClass)
                hPage = [];
                return
            end
            
            if isa(obj.ConfigPageClass,'meta.class') 
                constructor = str2func(obj.ConfigPageClass.Name);
            else
                constructor = str2func(obj.ConfigPageClass);
            end
            
            hPage = constructor(obj,hParent);
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
