classdef MCM5000MirrorsWidget < dabs.resources.widget.Widget
    properties
        hListeners = event.listener.empty(0,1);
        pbRGOut
        pbRGIn
        pbGGOut
        pbGGIn
        pbFlipperPmt
        pbFlipperCam
    end
    
    methods
        function obj = MCM5000MirrorsWidget(hResource,hParent)
            obj@dabs.resources.widget.Widget(hResource,hParent);
        end
        
        function delete(obj)
            delete(obj.hListeners);
        end
    end
    
    methods
        function makePanel(obj,hParent)
                hFlowTop = most.gui.uiflowcontainer('Parent',hParent,'FlowDirection','TopDown','Margin',0.001);
                hFlow = most.gui.uiflowcontainer('Parent',hFlowTop,'FlowDirection','LeftToRight');
                    obj.pbRGOut = most.gui.uicontrol('Parent',hFlow,'String','RG Out','Style','togglebutton','Callback',@(varargin)obj.setRG(false));
                    obj.pbRGIn  = most.gui.uicontrol('Parent',hFlow,'String','RG In' ,'Style','togglebutton','Callback',@(varargin)obj.setRG(true));

                hFlow = most.gui.uiflowcontainer('Parent',hFlowTop,'FlowDirection','LeftToRight','HeightLimits',[1 1]);
                    annotation(hFlow,'line',[0 1],[0 0], 'LineWidth', 1);
                    
                hFlow = most.gui.uiflowcontainer('Parent',hFlowTop,'FlowDirection','LeftToRight');
                    %most.gui.uicontrol('Parent',hFlow,'Style','text','String','GG:');
                    obj.pbGGOut = most.gui.uicontrol('Parent',hFlow,'String','GG Out','Style','togglebutton','Callback',@(varargin)obj.setGG(false));
                    obj.pbGGIn  = most.gui.uicontrol('Parent',hFlow,'String','GG In' ,'Style','togglebutton','Callback',@(varargin)obj.setGG(true));
                    
                hFlow = most.gui.uiflowcontainer('Parent',hFlowTop,'FlowDirection','LeftToRight','HeightLimits',[1 1]);
                    annotation(hFlow,'line',[0 1],[0 0], 'LineWidth', 1);
                
                hFlow = most.gui.uiflowcontainer('Parent',hFlowTop,'FlowDirection','LeftToRight');
                    %most.gui.uicontrol('Parent',hFlow,'Style','text','String',' ');
                    obj.pbFlipperPmt = most.gui.uicontrol('Parent',hFlow,'String','PMT','Style','togglebutton','Callback',@(varargin)obj.setFlipper('pmt'));
                    obj.pbFlipperCam = most.gui.uicontrol('Parent',hFlow,'String','CAM','Style','togglebutton','Callback',@(varargin)obj.setFlipper('camera'));
            
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource.hMCM5000,'galvoResonantMirrorInPath','PostSet',@(varargin)obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource.hMCM5000,'galvoGalvoMirrorInPath'   ,'PostSet',@(varargin)obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource.hMCM5000,'flipperMirrorPosition'    ,'PostSet',@(varargin)obj.redraw);
            
            obj.redraw();
        end
        
        function redraw(obj)
            rgPos = obj.hResource.hMCM5000.galvoResonantMirrorInPath;
            ggPos = obj.hResource.hMCM5000.galvoGalvoMirrorInPath;
            flipper = obj.hResource.hMCM5000.flipperMirrorPosition;
            
            obj.pbRGOut.Value = ~isnan(rgPos) && ~rgPos;
            obj.pbRGIn.Value  = ~isnan(rgPos) &&  rgPos;
            
            obj.pbGGOut.Value = ~isnan(ggPos) && ~ggPos;
            obj.pbGGIn.Value  = ~isnan(ggPos) &&  ggPos;
            
            obj.pbFlipperPmt.Value = strcmpi(flipper,'pmt');
            obj.pbFlipperCam.Value = strcmpi(flipper,'camera');
        end
        
        function setRG(obj,val)
            obj.hResource.hMCM5000.galvoResonantMirrorInPath = val;
        end
        
        function setGG(obj,val)
            obj.hResource.hMCM5000.galvoGalvoMirrorInPath = val;
        end
        
        function setFlipper(obj,val)
            obj.hResource.hMCM5000.flipperMirrorPosition = val;
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
