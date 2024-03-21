classdef ThorBCMPage < dabs.resources.configuration.ResourcePage
    properties
       hListeners = event.listener.empty(0,1); 
    end
    
    properties(SetObservable)
        pmhCOM;
        etLabelPosition0;
        etLabelPosition1;
        pmStartupPosition
    end
    
    methods
        function obj = ThorBCMPage(hResource,hParent)
            obj@dabs.resources.configuration.ResourcePage(hResource,hParent);
        end
        
        function makePanel(obj,hParent)
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [-23 55 120 20],'Tag','txhComPort','String','Serial Port','HorizontalAlignment','right');
            obj.pmhCOM  = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [120 52 120 20],'Tag','pmhCOM');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [-20 85 120 20],'Tag','txLabelPosition0','String','Position 0 Label ','HorizontalAlignment','right');
            obj.etLabelPosition0 = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [120 82 120 20],'Tag','etLabelPosition0');  
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [-20 115 120 20],'Tag','txLabelPosition1','String','Position 1 Label','HorizontalAlignment','right');
            obj.etLabelPosition1 = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [120 112 120 20],'Tag','etLabelPosition1');    
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [-12 146 120 20],'Tag','txStartupPosition','String','Startup Position: ','HorizontalAlignment','right');
            obj.pmStartupPosition = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{'Position 0', 'Position 1'},'RelPosition', [120 142 120 20],'Tag','pmStartupPosition');
        end
        
        function redraw(obj)
            hCOMs = obj.hResourceStore.filterByClass(?dabs.resources.SerialPort);
            obj.pmhCOM.String = [{''}, hCOMs];
            obj.pmhCOM.pmValue = obj.hResource.hCOM;
            
            obj.pmStartupPosition.Value = (obj.hResource.startupPosition + 1);            
            obj.etLabelPosition0.String = obj.hResource.labelPosition0;
            obj.etLabelPosition1.String = obj.hResource.labelPosition1;
        end
        
        function apply(obj)
            most.idioms.safeSetProp(obj.hResource,'hCOM',obj.pmhCOM.pmValue);
            most.idioms.safeSetProp(obj.hResource, 'startupPosition', logical(obj.pmStartupPosition.Value - 1));
            most.idioms.safeSetProp(obj.hResource, 'labelPosition0', obj.etLabelPosition0.String);
            most.idioms.safeSetProp(obj.hResource, 'labelPosition1', obj.etLabelPosition1.String);

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
