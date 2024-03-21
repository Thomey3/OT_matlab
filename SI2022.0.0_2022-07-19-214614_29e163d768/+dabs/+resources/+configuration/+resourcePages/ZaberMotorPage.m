classdef ZaberMotorPage < dabs.resources.configuration.ResourcePage
    properties
        pmhCOM
        etDeviceId
    end
    
    methods
        function obj = ZaberMotorPage(hResource,hParent)
            obj@dabs.resources.configuration.ResourcePage(hResource,hParent);
        end
        
        function makePanel(obj,hParent)
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [24 30 120 20],'Tag','txhComPort','String','Serial Port','HorizontalAlignment','right');
            obj.pmhCOM  = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [150 27 120 20],'Tag','pmhCOM');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [24 55 120 20],'Tag','txDeviceId','String','Device ID','HorizontalAlignment','right');
            obj.etDeviceId = most.gui.uicontrol('Parent',hParent,'Style','edit','String','','RelPosition', [150 53 120 20],'Tag','etDeviceId');
        end
        
        function redraw(obj)            
            hCOMs = obj.hResourceStore.filterByClass(?dabs.resources.SerialPort);
            obj.pmhCOM.String = [{''}, hCOMs];
            obj.pmhCOM.pmValue = obj.hResource.hCOM;
            
            obj.etDeviceId.String = num2str(obj.hResource.deviceId);
        end
        
        function apply(obj)
            most.idioms.safeSetProp(obj.hResource,'hCOM',obj.pmhCOM.pmValue);
            most.idioms.safeSetProp(obj.hResource,'deviceId',str2double(obj.etDeviceId.String));
            
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
