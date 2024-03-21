classdef LC40xPage < dabs.resources.configuration.ResourcePage
    properties
        pmhCOM
        etChannel
        pmhAOControl
        pmhAIFeedback
        etParkPosition
    end
    
    methods
        function obj = LC40xPage(hResource,hParent)
            obj@dabs.resources.configuration.ResourcePage(hResource,hParent);
        end
        
        function makePanel(obj,hParent)
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [20 36 120 20],'Tag','txhCOM','String','COM Port','HorizontalAlignment','right');
            obj.pmhCOM  =        most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [150 32 120 20],'Tag','pmhCOM');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [20 66 120 20],'Tag','txChannel','String','Channel','HorizontalAlignment','right');
            obj.etChannel =      most.gui.uicontrol('Parent',hParent,'Style','edit','String',{''},'RelPosition', [150 62 120 20],'Tag','etChannel');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [20 96 120 20],'Tag','txhAOControl','String','Control AO','HorizontalAlignment','right');
            obj.pmhAOControl =   most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [150 92 120 20],'Tag','pmhAOControl');
           
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [20 126 120 20],'Tag','txhAIFeedback','String','Feedback AI','HorizontalAlignment','right');
            obj.pmhAIFeedback =  most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [150 122 120 20],'Tag','pmhAIFeedback');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [20 154 120 20],'Tag','txTravelRange2','String','Park Position [um]','HorizontalAlignment','right');
            obj.etParkPosition = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [150 152 120 20],'Tag','etTravelRange2');
        end
        
        function redraw(obj)
            hCOMs = obj.hResourceStore.filterByClass(?dabs.resources.SerialPort);
            obj.pmhCOM.String = [{''}, hCOMs];
            obj.pmhCOM.pmValue = obj.hResource.hCOM;
            
            obj.etChannel.String = num2str(obj.hResource.currentChannel);
            
            hAOs = obj.hResourceStore.filterByClass(?dabs.resources.ios.AO);
            obj.pmhAOControl.String = [{''}, hAOs];
            obj.pmhAOControl.pmValue = obj.hResource.hAOControl;
            
            hAIs = obj.hResourceStore.filterByClass(?dabs.resources.ios.AI);
            obj.pmhAIFeedback.String = [{''}, hAIs];
            obj.pmhAIFeedback.pmValue = obj.hResource.hAIFeedback;

            obj.etParkPosition.String = num2str(obj.hResource.parkPosition);
        end
        
        function apply(obj)
            most.idioms.safeSetProp(obj.hResource,'hCOM',obj.pmhCOM.pmValue);
            most.idioms.safeSetProp(obj.hResource,'currentChannel',str2num(obj.etChannel.String));
            most.idioms.safeSetProp(obj.hResource,'hAOControl',obj.pmhAOControl.pmValue);
            most.idioms.safeSetProp(obj.hResource,'hAIFeedback',obj.pmhAIFeedback.pmValue);
            most.idioms.safeSetProp(obj.hResource,'parkPosition',str2double(obj.etParkPosition.String));
            
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
