classdef GalvoAnalogPage < dabs.resources.configuration.ResourcePage
    properties
        pmhAOControl
        pmhAIFeedback
        etVoltsPerDistance
        etVoltsOffset
        etAngularRange
        etParkPosition
        etSlewRateLimit
    end
    
    methods
        function obj = GalvoAnalogPage(hResource,hParent)
            obj@dabs.resources.configuration.ResourcePage(hResource,hParent);
        end
        
        function makePanel(obj,hParent)
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [25 29 170 20],'Tag','txhAOControl','String','Control Channel','HorizontalAlignment','right');
            obj.pmhAOControl  = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [200 24 120 20],'Tag','pmhAOControl');
            
            toolTipString = sprintf('commandVoltage = opticalDegrees * voltsPerOpticalDegree + voltsOffset');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [25 51 170 20],'Tag','txVoltsPerDistance','String','Volts per optical degree [V/deg]','HorizontalAlignment','right');
            obj.etVoltsPerDistance = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [200 49 120 20],'Tag','etVoltsPerDistance','TooltipString',toolTipString);
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [25 75 170 20],'Tag','txVoltsOffset','String','Volts offset [V]','HorizontalAlignment','right');
            obj.etVoltsOffset = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [200 72 120 20],'Tag','etVoltsOffset','TooltipString',toolTipString);
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [25 97 170 20],'Tag','txTravelRange1','String','Angular range [optical degrees]','HorizontalAlignment','right');
            obj.etAngularRange = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [200 95 120 20],'Tag','etAngularRange');
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [25 120 170 20],'Tag','txParkPosition','String','Park position [optical degrees]','HorizontalAlignment','right');
            obj.etParkPosition = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [200 118 120 20],'Tag','etParkPosition');
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [24 143 170 20],'Tag','txSlewRateLimit','String','Slew rate limit (vDAQ only) [V/s]','HorizontalAlignment','right');
            obj.etSlewRateLimit = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [200 141 120 20],'Tag','etSlewRateLimit');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [25 181 170 20],'Tag','txhAIFeedback','String','Feedback Channel (optional)','HorizontalAlignment','right');
            obj.pmhAIFeedback = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [199 180 120 20],'Tag','pmhAIFeedback');
            
            if isa(obj.hResource,'dabs.thorlabs.ecu1.Galvo') || isa(obj.hResource,'dabs.thorlabs.ecu2.Galvo')
                obj.pmhAOControl.Enable = 'off';
                obj.pmhAIFeedback.Enable = 'off';
            end
        end
        
        function redraw(obj)            
            hAOs = obj.hResourceStore.filterByClass(?dabs.resources.ios.AO);
            obj.pmhAOControl.String = [{''}, hAOs];
            obj.pmhAOControl.pmValue = obj.hResource.hAOControl;
            
            hAIs = obj.hResourceStore.filterByClass(?dabs.resources.ios.AI);
            obj.pmhAIFeedback.String = [{''}, hAIs];
            obj.pmhAIFeedback.pmValue = obj.hResource.hAIFeedback;
            
            obj.etVoltsPerDistance.String = num2str(obj.hResource.voltsPerDistance);
            obj.etVoltsOffset.String = num2str(obj.hResource.distanceVoltsOffset);
            obj.etAngularRange.String = num2str(diff(obj.hResource.travelRange));
            obj.etParkPosition.String = num2str(obj.hResource.parkPosition);
            obj.etSlewRateLimit.String = num2str(obj.hResource.slewRateLimit_V_per_s);
            obj.etSlewRateLimit.Enable = ~most.idioms.isValidObj(obj.hResource.hAOControl) || obj.hResource.hAOControl.supportsSlewRateLimit;
        end
        
        function apply(obj)
            most.idioms.safeSetProp(obj.hResource,'hAOControl',obj.pmhAOControl.pmValue);
            most.idioms.safeSetProp(obj.hResource,'hAIFeedback',obj.pmhAIFeedback.pmValue);
            
            most.idioms.safeSetProp(obj.hResource,'voltsPerDistance',str2double(obj.etVoltsPerDistance.String));
            most.idioms.safeSetProp(obj.hResource,'distanceVoltsOffset',str2double(obj.etVoltsOffset.String));
            most.idioms.safeSetProp(obj.hResource,'travelRange', [-1/2 1/2] * str2double(obj.etAngularRange.String));
            most.idioms.safeSetProp(obj.hResource,'parkPosition',str2double(obj.etParkPosition.String));
            most.idioms.safeSetProp(obj.hResource,'slewRateLimit_V_per_s',str2double(obj.etSlewRateLimit.String));
            
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
