classdef FastZWidget < dabs.resources.widget.Widget
    properties
        hPatchObjective
        hPatchLight
        hAx
        hLineTravelRange
        hLineMarker
        hTextMarker
        
        hListeners = event.listener.empty(0,1);
    end
    
    methods
        function obj = FastZWidget(hResource,hParent)
            obj@dabs.resources.widget.Widget(hResource,hParent);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'travelRange','PostSet',@(varargin)obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'lastKnownPositionOutput','PostSet',@(varargin)obj.redraw);
            
            try
                obj.redraw();
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
        end
        
        function delete(obj)
            obj.hListeners.delete();
            most.idioms.safeDeleteObj(obj.hAx);
        end
    end
    
    methods
        function makePanel(obj,hParent)
            hFlow = most.gui.uiflowcontainer('Parent',hParent,'FlowDirection','TopDown','margin',0.001);
            
            hAxFlow = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','LeftToRight','margin',0.001);

            obj.hAx = most.idioms.axes('Parent',hAxFlow,'Units','normalized','Position',[0 0 1 1],'DataAspectRatio',[1 1 1],'XTick',[],'YTick',[],'Visible','off','XLimSpec','tight','YLimSpec','tight');
            view(obj.hAx,0,-90);
            
            obj.hPatchObjective = patch('Parent',obj.hAx,'LineStyle','none','FaceColor',most.constants.Colors.darkGray);
            obj.hPatchLight = patch('Parent',obj.hAx,'LineStyle','none','FaceColor',most.constants.Colors.red,'FaceAlpha',0.2);
            
            obj.hLineTravelRange = line('Parent',obj.hAx,'XData',[],'YData',[]);
            obj.hLineMarker = line('Parent',obj.hAx,'XData',[],'YData',[],'Marker','x');
            obj.hTextMarker = text('Parent',obj.hAx,'HorizontalAlignment','center','VerticalAlignment','top');
            
            hButtonFlow = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','LeftToRight','margin',0.001,'HeightLimits',[20 20]);
            most.gui.uicontrol('Parent',hButtonFlow,'String','LUT','Callback',@(varargin)obj.hResource.plotPositionLUT);
            most.gui.uicontrol('Parent',hButtonFlow,'String','Calib','Callback',@(varargin)obj.hResource.calibrate);
        end
        
        function redraw(obj) 
            t = map(obj.hResource.travelRange);
            pos = map(obj.hResource.lastKnownPositionOutput);
            
            if isempty(pos) || isnan(pos)
                pos = 0;
            end
            
            objectiveVertices = [-1 -1.2; 1 -1.2; 1 -1; 0.5 -0.5; -0.5 -0.5; -1 -1];
            obj.hPatchObjective.Vertices = objectiveVertices;
            obj.hPatchObjective.Faces = 1:size(objectiveVertices,1);
            
            lightConeVertices = [-0.4 -0.5; 0.4 -0.5; 0 pos];
            
            obj.hPatchLight.Vertices = lightConeVertices;
            obj.hPatchLight.Faces = 1:size(lightConeVertices,1);
            
            obj.hLineTravelRange.XData = [-0.5 0.5 nan -0.5 0.5]';
            obj.hLineTravelRange.YData = [t(1) t(1) nan t(2) t(2)]';
            
            obj.hLineMarker.XData = 0;
            obj.hLineMarker.YData = pos;
            
            obj.hTextMarker.Position = [0 -1.2];
            obj.hTextMarker.String = sprintf('%.1fum',obj.hResource.lastKnownPositionOutput);
            
            function v = map(v)
                t_ = sort(obj.hResource.travelRange);
                v = (v - t_(1)) / diff(t_);
            end
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
