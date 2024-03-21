classdef MotorAnalogPage < dabs.resources.configuration.ResourcePage
    properties
        pmhAOPosition

        etCommandVoltsPerMicron
        etCommandVoltsOffset
        etMinPosition_um
        etMaxPosition_um
        etSettlingTime_s
    end
    
    methods
        function obj = MotorAnalogPage(hResource,hParent)
            obj@dabs.resources.configuration.ResourcePage(hResource,hParent);
        end
        
        function makePanel(obj,hParent)
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [40 42 120 20],'Tag','txMinPosition_um','String','Minimum Position [um]','HorizontalAlignment','right');
            obj.etMinPosition_um = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [170 40 50 20],'Tag','etMinPosition_um');            
                                      
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [40 72 120 20],'Tag','txMaxPosition_um','String','Maximum Position [um]','HorizontalAlignment','right');
            obj.etMaxPosition_um = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [170 70 50 20],'Tag','etMaxPosition_um');            
   
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [40 102 120 20],'Tag','txhAOPosition','String','Position Device','HorizontalAlignment','right');
            obj.pmhAOPosition  = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [170 98 120 20],'Tag','pmhAOPosition');
                      
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [0 132 160 20],'Tag','txCommandVoltsPerMicron','String','Command Scaling Factor [V/um]','HorizontalAlignment','right');
            obj.etCommandVoltsPerMicron = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [170 131 50 22],'Tag','etCommandVoltsPerMicron');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [20 162 140 20],'Tag','txCommandVoltsOffset','String','Command Volts Offset [V]','HorizontalAlignment','right');
            obj.etCommandVoltsOffset = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [170 161 50 20],'Tag','etCommandVoltsOffset');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [30 202 130 30],'Tag','txSettlingTime_s','String','Settling Time [s]','HorizontalAlignment','right');
            obj.etSettlingTime_s = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [170 190 50 20],'Tag','etSettlingTime_s');
        end
        
        function redraw(obj)
            hResourceStore = dabs.resources.ResourceStore();
            
            hAOs = hResourceStore.filterByClass(?dabs.resources.ios.AO);
            
            obj.pmhAOPosition.String = [{''}, hAOs];
            obj.pmhAOPosition.pmValue = obj.hResource.hAOPosition;
            
            obj.etCommandVoltsPerMicron.String = num2str(obj.hResource.commandVoltsPerMicron);
            obj.etCommandVoltsOffset.String = num2str(obj.hResource.commandVoltsOffset);
            obj.etMinPosition_um.String = num2str(min(obj.hResource.travelRange_um));
            obj.etMaxPosition_um.String = num2str(max(obj.hResource.travelRange_um));
            
            obj.etSettlingTime_s.String = num2str(obj.hResource.settlingTime_s);
        end
        
        function apply(obj)
            most.idioms.safeSetProp(obj.hResource,'hAOPosition',obj.pmhAOPosition.pmValue);
            
            travelRange_um = [str2double(obj.etMinPosition_um.String) str2double(obj.etMaxPosition_um.String)];
        
            most.idioms.safeSetProp(obj.hResource,'travelRange_um',travelRange_um);
            most.idioms.safeSetProp(obj.hResource,'commandVoltsPerMicron',str2double(obj.etCommandVoltsPerMicron.String));
            most.idioms.safeSetProp(obj.hResource,'commandVoltsOffset',str2double(obj.etCommandVoltsOffset.String));
            most.idioms.safeSetProp(obj.hResource,'settlingTime_s',str2double(obj.etSettlingTime_s.String));
            
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
