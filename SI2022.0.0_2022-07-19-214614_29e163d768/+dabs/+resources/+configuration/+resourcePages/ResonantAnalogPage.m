classdef ResonantAnalogPage < dabs.resources.configuration.ResourcePage
    properties
        pmhAOZoom
        pmhDISync
        pmhDOEnable
        etVoltsPerOpticalDegrees
        etAngularRange
        etNominalFrequency
        etSettleTime
    end
    
    methods
        function obj = ResonantAnalogPage(hResource,hParent)
            obj@dabs.resources.configuration.ResourcePage(hResource,hParent);
        end
        
        function makePanel(obj,hParent)
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [22 172 170 20],'Tag','txNominalFrequency','String','Nominal Frequency [Hz]','HorizontalAlignment','right');
            obj.etNominalFrequency = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [200 170 120 20],'Tag','etNominalFrequency');            
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [20 25 170 20],'Tag','txhDISync','String','Sync Channel','HorizontalAlignment','right');
            obj.pmhDISync = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [200 23 120 20],'Tag','pmhDISync');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [19 49 170 20],'Tag','txhAOZoom','String','Zoom Control Channel','HorizontalAlignment','right');
            obj.pmhAOZoom  = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [200 46 120 20],'Tag','pmhAOZoom');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [20 98 170 20],'Tag','txVoltsPerOpticalDegrees','String','Volts per optical degree','HorizontalAlignment','right');
            obj.etVoltsPerOpticalDegrees = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [200 94 120 20],'Tag','etVoltsPerOpticalDegrees');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [21 122 170 20],'Tag','txAngularRange','String','Angular range [optical degrees]','HorizontalAlignment','right');
            obj.etAngularRange = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [200 119 120 20],'Tag','etAngularRange');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [22 147 170 20],'Tag','txSettleTime','String','Settle time [s]','HorizontalAlignment','right');
            obj.etSettleTime = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [200 144 120 20],'Tag','etSettleTime');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [20 73 170 20],'Tag','txhDOEnable','String','Enable Channel (optional)','HorizontalAlignment','right');
            obj.pmhDOEnable = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [200 70 120 20],'Tag','pmhDOEnable');
        end
        
        function redraw(obj)            
            hAOs = obj.hResourceStore.filterByClass(?dabs.resources.ios.AO);
            obj.pmhAOZoom.String = [{''}, hAOs];
            obj.pmhAOZoom.pmValue = obj.hResource.hAOZoom;
            
            hIOs = obj.hResourceStore.filter(@(hR)(isa(hR,'dabs.resources.ios.DI')&&isa(hR.hDAQ,'dabs.resources.daqs.vDAQ'))||isa(hR,'dabs.resources.ios.PFI'));
            obj.pmhDISync.String = [{''}, hIOs];
            obj.pmhDISync.pmValue = obj.hResource.hDISync;
            
            hIOs = obj.hResourceStore.filter(@(hR)(isa(hR,'dabs.resources.ios.DO')&&isa(hR.hDAQ,'dabs.resources.daqs.vDAQ'))||isa(hR,'dabs.resources.ios.PFI'));
            obj.pmhDOEnable.String = [{''}, hIOs];
            obj.pmhDOEnable.pmValue = obj.hResource.hDOEnable;
            
            obj.etVoltsPerOpticalDegrees.String = num2str(obj.hResource.voltsPerOpticalDegrees);
            obj.etAngularRange.String = num2str(obj.hResource.angularRange_deg);
            obj.etNominalFrequency.String = num2str(obj.hResource.nominalFrequency_Hz);
            obj.etSettleTime.String = num2str(obj.hResource.settleTime_s);
        end
        
        function apply(obj)
            most.idioms.safeSetProp(obj.hResource,'hAOZoom',obj.pmhAOZoom.pmValue);
            most.idioms.safeSetProp(obj.hResource,'hDISync',obj.pmhDISync.pmValue);
            most.idioms.safeSetProp(obj.hResource,'hDOEnable',obj.pmhDOEnable.pmValue);
            
            most.idioms.safeSetProp(obj.hResource,'angularRange_deg',str2double(obj.etAngularRange.String));
            most.idioms.safeSetProp(obj.hResource,'voltsPerOpticalDegrees', str2num(obj.etVoltsPerOpticalDegrees.String));
            most.idioms.safeSetProp(obj.hResource,'nominalFrequency_Hz', str2double(obj.etNominalFrequency.String));
            most.idioms.safeSetProp(obj.hResource,'settleTime_s', str2double(obj.etSettleTime.String));
            
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
