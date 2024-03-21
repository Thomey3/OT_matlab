classdef PIC413AScannerPage < dabs.resources.configuration.ResourcePage
    properties
        pmhAOControl
        pmhAIFeedback
        etVoltsPerDistance
        etDistanceVoltsOffset
        etTravelRange1
        etTravelRange2
        etParkPosition
        cbEnabled
    end
    
    methods
        function obj = PIC413AScannerPage(hResource,hParent)
            obj@dabs.resources.configuration.ResourcePage(hResource,hParent);
        end
        
        function makePanel(obj,hParent)
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [24 27 120 20],'Tag','txhAOControl','String','Control Channel','HorizontalAlignment','right');
            obj.pmhAOControl  = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [150 24 120 20],'Tag','pmhAOControl');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [23 51 120 20],'Tag','txVoltsPerDistance','String','Volts per micron','HorizontalAlignment','right');
            obj.etVoltsPerDistance = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [150 49 120 20],'Tag','etVoltsPerDistance');
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [22 74 120 20],'Tag','txDistanceVoltsOffset','String','Volts Offset','HorizontalAlignment','right');
            obj.etDistanceVoltsOffset = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [150 72 120 20],'Tag','etDistanceVoltsOffset');
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [21 97 120 20],'Tag','txTravelRange1','String','Lower travel range [um]','HorizontalAlignment','right');
            obj.etTravelRange1 = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [150 95 120 20],'Tag','etTravelRange1');
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [21 119 120 20],'Tag','txTravelRange2','String','Upper Travel range [um]','HorizontalAlignment','right');
            obj.etTravelRange2 = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [150 118 120 20],'Tag','etTravelRange2');
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [21 141 120 20],'Tag','txParkPosition','String','Park position [um]','HorizontalAlignment','right');
            obj.etParkPosition = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [150 141 120 20],'Tag','etParkPosition');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [1 185 140 20],'Tag','txhAIFeedback','String','Feedback Channel (optional)','HorizontalAlignment','right');
            obj.pmhAIFeedback = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [147 183 120 20],'Tag','pmhAIFeedback');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [18 221 120 20],'Tag','txEnabled','String','Enable axis','HorizontalAlignment','right');
            obj.cbEnabled = most.gui.uicontrol('Parent',hParent,'Style','checkbox','RelPosition', [147 217 20 20],'Tag','cbEnabled');
            
            most.gui.uicontrol('Parent',hParent,'RelPosition', [281 73 90 45],'String','<html>Read settings<br/>from controller</html>','Tag','pbReadSaling','Callback',@(varargin)obj.readSettings);
        end
        
        function readSettings(obj)
            obj.hResource.readScalingFromController();
            obj.redraw();            
        end
        
        function redraw(obj)    
            hAOs = obj.hResourceStore.filterByClass(?dabs.resources.ios.AO);
            obj.pmhAOControl.String = [{''}, hAOs];
            obj.pmhAOControl.pmValue = obj.hResource.hAOControl;
            
            hAIs = obj.hResourceStore.filterByClass(?dabs.resources.ios.AI);
            obj.pmhAIFeedback.String = [{''}, hAIs];
            obj.pmhAIFeedback.pmValue = obj.hResource.hAIFeedback;
            
            obj.etVoltsPerDistance.String = num2str(obj.hResource.voltsPerDistance);
            obj.etDistanceVoltsOffset.String = num2str(obj.hResource.distanceVoltsOffset);
            obj.etTravelRange1.String = num2str(obj.hResource.travelRange(1));
            obj.etTravelRange2.String = num2str(obj.hResource.travelRange(2));
            obj.etParkPosition.String = num2str(obj.hResource.parkPosition);
            
            obj.cbEnabled.Value = obj.hResource.enabled;
        end
        
        function apply(obj)
            most.idioms.safeSetProp(obj.hResource,'hAOControl',obj.pmhAOControl.pmValue);
            most.idioms.safeSetProp(obj.hResource,'hAIFeedback',obj.pmhAIFeedback.pmValue);
            
            most.idioms.safeSetProp(obj.hResource,'voltsPerDistance',str2double(obj.etVoltsPerDistance.String));
            most.idioms.safeSetProp(obj.hResource,'distanceVoltsOffset',str2double(obj.etDistanceVoltsOffset.String));
            most.idioms.safeSetProp(obj.hResource,'travelRange',[str2double(obj.etTravelRange1.String) str2double(obj.etTravelRange2.String)]);
            most.idioms.safeSetProp(obj.hResource,'parkPosition',str2double(obj.etParkPosition.String));
            
            most.idioms.safeSetProp(obj.hResource,'enabled',obj.cbEnabled.Value);
            
            obj.hResource.saveMdf();
            obj.hResource.hC413A.saveMdf();
            obj.hResource.hC413A.reinit();
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
