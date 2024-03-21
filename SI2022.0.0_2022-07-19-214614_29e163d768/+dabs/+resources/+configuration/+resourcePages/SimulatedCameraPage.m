classdef SimulatedCameraPage < dabs.resources.configuration.ResourcePage
    properties
        pmDatatype;
        etResolutionX;
        etResolutionY;
    end
    
    methods
        function obj = SimulatedCameraPage(hResource,hParent)
            obj@dabs.resources.configuration.ResourcePage(hResource,hParent);
        end
        
        function makePanel(obj,hParent)
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [-40 85 170 20],'Tag','txDatatype','String','Datatype','HorizontalAlignment','right');
            obj.pmDatatype  = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [140 82 110 20],'Tag','pmDatatype');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [50 54 80 20],'Tag','txResolution','String','Pixel resolution','HorizontalAlignment','right');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [155 32 20 20],'Tag','txResolutionX','String','X');
            obj.etResolutionX  = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [140 52 50 20],'Tag','etResolutionX');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [215 32 20 20],'Tag','txResolutionY','String','Y');
            obj.etResolutionY = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [200 52 50 20],'Tag','etResolutionY');
        end
        
        function redraw(obj)    
            obj.pmDatatype.String = {'U8', 'I8', 'U16','I16'};
            obj.pmDatatype.pmValue = char(obj.hResource.datatype);
            
            obj.etResolutionX.String = obj.hResource.resolutionXY_(1);
            obj.etResolutionY.String = obj.hResource.resolutionXY_(2);
        end
        
        function apply(obj)
            most.idioms.safeSetProp(obj.hResource,'datatype',obj.pmDatatype.pmValue);
            most.idioms.safeSetProp(obj.hResource,'resolutionXY_' ...
                ,[str2double(obj.etResolutionX.String) str2double(obj.etResolutionY.String)]);
            
            obj.hResource.saveMdf();
            obj.hResource.reinit();
        end
        
        function remove(obj)
            obj.hResource.deleteAndRemoveMdfHeading();
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
