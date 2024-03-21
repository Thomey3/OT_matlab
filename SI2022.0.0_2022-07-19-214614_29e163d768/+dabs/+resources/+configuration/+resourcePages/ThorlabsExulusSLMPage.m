classdef ThorlabsExulusSLMPage < dabs.resources.configuration.ResourcePage
    properties
        pmhCOM
        etMonitorID
        etPixelResolutionX
        etPixelResolutionY
        etPixelPitchX
        etPixelPitchY
    end
    
    methods
        function obj = ThorlabsExulusSLMPage(hResource,hParent)
            obj@dabs.resources.configuration.ResourcePage(hResource,hParent);
        end
        
        function makePanel(obj,hParent)
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [0 27 120 20],'Tag','txhCOM','String','Serial Port','HorizontalAlignment','right');
            obj.pmhCOM  = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [130 22 100 20],'Tag','pmhCOM');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [0 51 120 20],'Tag','txMonitorID','String','Monitor ID','HorizontalAlignment','right');
            obj.etMonitorID = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [130 49 60 20],'Tag','etMonitorID');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [224 82 10 20],'Tag','txX','String','Y','HorizontalAlignment','right');
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [155 82 10 20],'Tag','txY','String','X','HorizontalAlignment','right');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [0 105 120 20],'Tag','txPixelResolution','String','Pixel Resolution','HorizontalAlignment','right');
            obj.etPixelResolutionX = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [130 102 60 20],'Tag','etPixelResolutionX');
            obj.etPixelResolutionY = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [200 102 60 20],'Tag','etPixelResolutionY');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [0 134 120 20],'Tag','txPixelPitch','String','Pixel Pitch [um]','HorizontalAlignment','right');
            obj.etPixelPitchX = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [130 132 60 20],'Tag','etPixelPitchX');
            obj.etPixelPitchY = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [200 132 60 20],'Tag','etPixelPitchY');
        end
        
        function redraw(obj)            
            hCOMs = obj.hResourceStore.filterByClass(?dabs.resources.SerialPort);
            obj.pmhCOM.String = [{''}, hCOMs];
            obj.pmhCOM.pmValue = obj.hResource.hCOM;
            
            obj.etMonitorID.String = num2str(obj.hResource.monitorID);
            obj.etPixelResolutionX.String = num2str(obj.hResource.pixelResolutionXY(1));
            obj.etPixelResolutionY.String = num2str(obj.hResource.pixelResolutionXY(2));
            obj.etPixelPitchX.String = num2str(obj.hResource.pixelPitchXY(1)*1e6);
            obj.etPixelPitchY.String = num2str(obj.hResource.pixelPitchXY(2)*1e6);
        end
        
        function apply(obj)
            most.idioms.safeSetProp(obj.hResource,'hCOM',obj.pmhCOM.pmValue);
            most.idioms.safeSetProp(obj.hResource,'monitorID',str2double(obj.etMonitorID.String));
            most.idioms.safeSetProp(obj.hResource,'pixelResolutionXY',[str2double(obj.etPixelResolutionX.String) str2double(obj.etPixelResolutionY.String)]);
            most.idioms.safeSetProp(obj.hResource,'pixelPitchXY',[str2double(obj.etPixelPitchX.String) str2double(obj.etPixelPitchY.String)]*1e-6);
            
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
