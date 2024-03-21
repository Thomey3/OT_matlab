classdef GenericSLMPage < dabs.resources.configuration.ResourcePage
    properties
        pmhCOM
        etMonitorID
        etPixelResolutionX
        etPixelResolutionY
        etPixelPitchX
        etPixelPitchY
        etMaxRefreshRate
    end
    
    methods
        function obj = GenericSLMPage(hResource,hParent)
            obj@dabs.resources.configuration.ResourcePage(hResource,hParent);
        end
        
        function makePanel(obj,hParent)
            if isprop(obj.hResource,'monitorID')
                most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [64 24 125 17],'Tag','txMonitorID','String','Monitor ID','HorizontalAlignment','right');
                obj.etMonitorID = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [197 25 50 20],'Tag','etMonitorID');
            end
            
            if isprop(obj.hResource,'hCOM')
                most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [70 49 120 20],'Tag','txhCOM','String','COM Port','HorizontalAlignment','right');
                obj.pmhCOM  = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [197 47 100 20],'Tag','pmhCOM');
            end
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [180 105 10 20],'Tag','txX','String','X','HorizontalAlignment','right');
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [260 105 10 20],'Tag','txY','String','Y','HorizontalAlignment','right');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [20 125 125 16],'Tag','txPixelResolution','String','Pixel Resolution','HorizontalAlignment','right');
            obj.etPixelResolutionX = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [150 125 70 20],'Tag','etPixelResolutionX');
            obj.etPixelResolutionY = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [230 125 70 20],'Tag','etPixelResolutionY');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [20 148 126 17],'Tag','txPixelPitch','String','Pixel Pitch [um]','HorizontalAlignment','right');
            obj.etPixelPitchX = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [150 149 70 20],'Tag','etPixelPitchX');
            obj.etPixelPitchY = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [230 149 70 20],'Tag','etPixelPitchY');
            
            if isprop(obj.hResource,'maxRefreshRate')
                most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [66 68 125 17],'Tag','txMaxRefreshRate','String','Max Refresh Rate [Hz]','HorizontalAlignment','right');
                obj.etMaxRefreshRate = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [197 68 50 20],'Tag','etMaxRefreshRate');
            end
        end
        
        function redraw(obj)      
            if isprop(obj.hResource,'monitorID')
                obj.etMonitorID.String = num2str(obj.hResource.monitorID);
            end
            
            if isprop(obj.hResource,'hCOM')
                hCOMs = obj.hResourceStore.filterByClass(?dabs.resources.SerialPort);
                obj.pmhCOM.String = [{''}, hCOMs];
                obj.pmhCOM.pmValue = obj.hResource.hCOM;
            end
            
            obj.etPixelResolutionX.String = num2str(obj.hResource.pixelResolutionXY(1));
            obj.etPixelResolutionY.String = num2str(obj.hResource.pixelResolutionXY(2));
            obj.etPixelPitchX.String      = num2str(obj.hResource.pixelPitchXY(1));
            obj.etPixelPitchY.String      = num2str(obj.hResource.pixelPitchXY(2));
            
            if isprop(obj.hResource,'maxRefreshRate')
                obj.etMaxRefreshRate.String   = num2str(obj.hResource.maxRefreshRate);
            end
        end
        
        function apply(obj)
            if isprop(obj.hResource,'monitorID')
                most.idioms.safeSetProp(obj.hResource,'monitorID',str2double(obj.etMonitorID.String));
            end
            
            if isprop(obj.hResource,'hCOM')
                most.idioms.safeSetProp(obj.hResource,'hCOM',obj.pmhCOM.pmValue);
            end
            
            most.idioms.safeSetProp(obj.hResource,'pixelResolutionXY',[str2double(obj.etPixelResolutionX.String) str2double(obj.etPixelResolutionY.String)]);
            most.idioms.safeSetProp(obj.hResource,'pixelPitchXY',     [str2double(obj.etPixelPitchX.String) str2double(obj.etPixelPitchY.String)]);
            
            if isprop(obj.hResource,'maxRefreshRate')
                most.idioms.safeSetProp(obj.hResource,'maxRefreshRate',str2double(obj.etMaxRefreshRate.String));
            end
            
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
