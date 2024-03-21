classdef GenericActuatorPage < dabs.resources.configuration.ResourcePage
    properties
        etUnits
        pmhAOControl
        pmhAIFeedback
        etVoltsPerDistance
        etDistanceVoltsOffset
        etTravelRange1
        etTravelRange2
        etParkPosition
    end
    
    methods
        function obj = GenericActuatorPage(hResource,hParent)
            obj@dabs.resources.configuration.ResourcePage(hResource,hParent);
        end
        
        function makePanel(obj,hParent)
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [20 32 120 20],'Tag','txUnits','String','Units','HorizontalAlignment','right');
            obj.etUnits  = most.gui.uicontrol('Parent',hParent,'Style','edit','String',{''},'RelPosition', [150 29 120 20],'Tag','etUnits');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [20 55 120 20],'Tag','txhAOControl','String','Control Channel','HorizontalAlignment','right');
            obj.pmhAOControl  = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [150 52 120 20],'Tag','pmhAOControl');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [20 78 120 20],'Tag','txVoltsPerDistance','String','Volts per micron','HorizontalAlignment','right');
            obj.etVoltsPerDistance = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [150 77 120 20],'Tag','etVoltsPerDistance');
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [20 103 120 20],'Tag','txDistanceVoltsOffset','String','Volts Offset','HorizontalAlignment','right');
            obj.etDistanceVoltsOffset = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [150 101 120 20],'Tag','etDistanceVoltsOffset');
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [20 127 120 20],'Tag','txTravelRange1','String','Lower travel range [um]','HorizontalAlignment','right');
            obj.etTravelRange1 = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [150 125 120 20],'Tag','etTravelRange1');
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [20 151 120 20],'Tag','txTravelRange2','String','Upper Travel range [um]','HorizontalAlignment','right');
            obj.etTravelRange2 = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [150 149 120 20],'Tag','etTravelRange2');
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [20 174 120 20],'Tag','txParkPosition','String','Park position [um]','HorizontalAlignment','right');
            obj.etParkPosition = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [150 173 120 20],'Tag','etParkPosition');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [0 229.333333333333 140 20],'Tag','txhAIFeedback','String','Feedback Channel (optional)','HorizontalAlignment','right');
            obj.pmhAIFeedback = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [150 227.333333333333 120 20],'Tag','pmhAIFeedback');            
        end
        
        function redraw(obj)
            obj.etUnits = obj.hResource.units;
            
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
        end
        
        function apply(obj)
            try
                obj.hResource.setUnits(obj.etUnits);
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
            
            most.idioms.safeSetProp(obj.hResource,'hAOControl',obj.pmhAOControl.pmValue);
            most.idioms.safeSetProp(obj.hResource,'hAIFeedback',obj.pmhAIFeedback.pmValue);
            
            most.idioms.safeSetProp(obj.hResource,'voltsPerDistance',str2double(obj.etVoltsPerDistance.String));
            most.idioms.safeSetProp(obj.hResource,'distanceVoltsOffset',str2double(obj.etDistanceVoltsOffset.String));
            most.idioms.safeSetProp(obj.hResource,'travelRange',[str2double(obj.etTravelRange1.String) str2double(obj.etTravelRange2.String)]);
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
