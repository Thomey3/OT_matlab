classdef GenericPmtPage < dabs.resources.configuration.ResourcePage
    properties
        pmhAOGain
        pmhDOPower
        pmhDITripDetect
        pmhDOTripReset
        
        etAOVoltsMin
        etAOVoltsMax
        
        etPmtVolts1
        etPmtVolts2
        
        cbAutoOn
        etWavelength
    end
    
    methods
        function obj = GenericPmtPage(hResource,hParent)
            obj@dabs.resources.configuration.ResourcePage(hResource,hParent);
        end
        
        function makePanel(obj,hParent)
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [24 28 120 20],'Tag','txAOVoltsMin','String','AO Output Min [V]','HorizontalAlignment','right');
            obj.etAOVoltsMin = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [150 26 50 20],'Tag','etAOVoltsMin');            
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [201 29 15 20],'Tag','txArrow1','String',most.constants.Unicode.rightwards_arrow,'HorizontalAlignment','right');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [229 30 155 20],'Tag','txPmtVolts1','String','Pmt Supply Voltage [V]','HorizontalAlignment','right');
            obj.etPmtVolts1 = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [220 26 50 20],'Tag','etPmtVolts1');            
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [24 51 120 20],'Tag','txAOVoltsMax','String','AO Output Max [V]','HorizontalAlignment','right');
            obj.etAOVoltsMax = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [150 49 50 20],'Tag','etAOVoltsMax');            
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [201 52 15 20],'Tag','txArrow2','String',most.constants.Unicode.rightwards_arrow,'HorizontalAlignment','right');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [269 52 115 20],'Tag','txPmtVolts2','String','Pmt Supply Voltage [V]','HorizontalAlignment','right');
            obj.etPmtVolts2 = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [220 49 50 20],'Tag','etPmtVolts2');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [28 83 120 20],'Tag','txhAOGain','String','Gain channel (optional)','HorizontalAlignment','right');
            obj.pmhAOGain  = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [150 79 120 20],'Tag','pmhAOGain');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [8 105 140 20],'Tag','txhDOPower','String','Enable channel (optional)','HorizontalAlignment','right');
            obj.pmhDOPower  = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [150 101 120 20],'Tag','pmhDOPower');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [-12 126 160 20],'Tag','txhDITripDetect','String','Trip detect channel (optional)','HorizontalAlignment','right');
            obj.pmhDITripDetect  = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [150 123 120 20],'Tag','pmhDITripDetect');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [-3 148 150 20],'Tag','txhDOTripReset','String','Trip reset channel (optional)','HorizontalAlignment','right');
            obj.pmhDOTripReset  = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [150 124 120 0],'Tag','pmhDOTripReset');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [22 194 120 20],'Tag','txAutoOn','String','Auto on','HorizontalAlignment','right');
            obj.cbAutoOn = most.gui.uicontrol('Parent',hParent,'Style','checkbox','RelPosition', [149 192 250 22],'Tag','cbAutoOn');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [29 173 115 20],'Tag','txWavelength','String','Wavelength [nm]','HorizontalAlignment','right');
            obj.etWavelength = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [149 170 50 20],'Tag','etWavelength');
        end
        
        function redraw(obj)            
            hAOs = obj.hResourceStore.filterByClass(?dabs.resources.ios.AO);
            hDIs = obj.hResourceStore.filter(@(hR)isa(hR,'dabs.resources.ios.DI')||isa(hR,'dabs.resources.ios.PFI'));
            hDOs = obj.hResourceStore.filter(@(hR)isa(hR,'dabs.resources.ios.DO')||isa(hR,'dabs.resources.ios.PFI'));
            
            obj.pmhAOGain.String = [{''}, hAOs];
            obj.pmhAOGain.pmValue = obj.hResource.hAOGain;
            
            obj.pmhDOPower.String = [{''} hDOs];
            obj.pmhDOPower.pmValue = obj.hResource.hDOPower;
                        
            obj.pmhDITripDetect.String = [{''} hDIs];
            obj.pmhDITripDetect.pmValue = obj.hResource.hDITripDetect;
            
            obj.pmhDOTripReset.String = [{''} hDOs];
            obj.pmhDOTripReset.pmValue = obj.hResource.hDOTripReset;
            
            obj.etAOVoltsMin.String = num2str(obj.hResource.aoRange_V(1));
            obj.etAOVoltsMax.String = num2str(obj.hResource.aoRange_V(2));

            obj.etPmtVolts1.String = num2str(obj.hResource.pmtSupplyRange_V(1));
            obj.etPmtVolts2.String = num2str(obj.hResource.pmtSupplyRange_V(2));
            
            obj.cbAutoOn.Value = obj.hResource.autoOn;
            
            obj.etWavelength.String = obj.hResource.wavelength_nm;
        end
        
        function apply(obj)
            most.idioms.safeSetProp(obj.hResource,'hAOGain',obj.pmhAOGain.String{obj.pmhAOGain.Value});
            most.idioms.safeSetProp(obj.hResource,'hDOPower',obj.pmhDOPower.String{obj.pmhDOPower.Value});
            most.idioms.safeSetProp(obj.hResource,'hDITripDetect',obj.pmhDITripDetect.String{obj.pmhDITripDetect.Value});
            most.idioms.safeSetProp(obj.hResource,'hDOTripReset',obj.pmhDOTripReset.String{obj.pmhDOTripReset.Value});
            
            aoRange_V = [str2double(obj.etAOVoltsMin.String) str2double(obj.etAOVoltsMax.String)];
            pmtSupplyRange_V = [str2double(obj.etPmtVolts1.String) str2double(obj.etPmtVolts2.String)];
        
            most.idioms.safeSetProp(obj.hResource,'aoRange_V',aoRange_V);
            most.idioms.safeSetProp(obj.hResource,'pmtSupplyRange_V',pmtSupplyRange_V);
            
            most.idioms.safeSetProp(obj.hResource,'autoOn',obj.cbAutoOn.Value);
            most.idioms.safeSetProp(obj.hResource,'wavelength_nm',str2double(obj.etWavelength.String));
            
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
