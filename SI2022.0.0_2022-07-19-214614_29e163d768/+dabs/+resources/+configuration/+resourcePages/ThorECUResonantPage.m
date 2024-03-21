classdef ThorECUResonantPage < dabs.resources.configuration.ResourcePage
    properties
        etNominalFrequency
        etAngularRange
        etSettleTime
    end
    
    methods
        function obj = ThorECUResonantPage(hResource,hParent)
            obj@dabs.resources.configuration.ResourcePage(hResource,hParent);
        end
        
        function makePanel(obj,hParent)
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [27 36 170 20],'Tag','txNominalFrequency','String','Nominal Frequency [Hz]','HorizontalAlignment','right');
            obj.etNominalFrequency = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [200 33 120 20],'Tag','etNominalFrequency');            
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [27 58 170 20],'Tag','txAngularRange','String','Angular range [optical degrees]','HorizontalAlignment','right');
            obj.etAngularRange = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [200 56 120 20],'Tag','etAngularRange');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [27 81 170 20],'Tag','txSettleTime','String','Settle Time [s]','HorizontalAlignment','right');
            obj.etSettleTime = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [200 79 120 20],'Tag','etSettleTime');
        end
        
        function redraw(obj)
            obj.etNominalFrequency.String = num2str(obj.hResource.nominalFrequency_Hz);
            obj.etAngularRange.String = num2str(obj.hResource.angularRange_deg);
            obj.etSettleTime.String = num2str(obj.hResource.settleTime_s);
        end
        
        function apply(obj)
            most.idioms.safeSetProp(obj.hResource,'nominalFrequency_Hz', str2double(obj.etNominalFrequency.String));
            most.idioms.safeSetProp(obj.hResource,'angularRange_deg',str2double(obj.etAngularRange.String));
            most.idioms.safeSetProp(obj.hResource,'settleTime_s',str2double(obj.etSettleTime.String));
            
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
