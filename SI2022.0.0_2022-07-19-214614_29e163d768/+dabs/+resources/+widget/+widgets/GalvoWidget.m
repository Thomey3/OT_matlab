classdef GalvoWidget < dabs.resources.widget.Widget
    properties
        hAx
        hLineAngularRange;
        hLineTargetPosition;
        hText;
        hListeners = event.listener.empty(0,1);
        dirty = false;
    end
    
    methods
        function obj = GalvoWidget(hResource,hParent)
            obj@dabs.resources.widget.Widget(hResource,hParent);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'travelRange','PostSet',@(varargin)obj.markDirty);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'lastKnownPositionOutput','PostSet',@(varargin)obj.markDirty);
            
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResourceStore.hSystemTimer,'beacon_30Hz',@(varargin)obj.redrawIfDirty);
            
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
            obj.hAx = most.idioms.axes('Parent',hAxFlow,'Units','normalized','Position',[0.1 0.1 0.8 0.8],'DataAspectRatio',[1 1 1],'XTick',[],'YTick',[],'Visible','off','XLimSpec','tight','YLimSpec','tight');
            obj.hAx.YLim = [0.8 1];
            
            obj.hLineAngularRange = line('Parent',obj.hAx);
            obj.hLineTargetPosition = line('Parent',obj.hAx,'Marker','o','LineStyle','none','ButtonDownFcn',@(varargin)obj.startDrag);
            
            obj.hText = text('Parent',obj.hAx,'ButtonDownFcn',@(varargin)obj.setPosition);
            obj.hText.Position = [0,0.98];
            obj.hText.HorizontalAlignment = 'center';
            obj.hText.VerticalAlignment = 'top';
            
            hButtonFlow = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','LeftToRight','margin',0.001,'HeightLimits',[20 20]);
            most.gui.uicontrol('Parent',hButtonFlow,'String','Calibrate','Callback',@(varargin)obj.hResource.calibrate);
        end
        
        function markDirty(obj)
            obj.dirty = true;
        end
        
        function redrawIfDirty(obj)
            % limited to 30Hz refresh rate
            if obj.dirty
                obj.redraw();
            end
        end
        
        function redraw(obj)
            angularRange = linspace(obj.hResource.travelRange(1),obj.hResource.travelRange(2),100)';
            angularRangeXY = [sind(angularRange), cosd(angularRange)];
            
            currentPosition = obj.hResource.lastKnownPositionOutput;
            
            if isempty(currentPosition) || isnan(currentPosition)
                currentPosition = 0;
            end
            
            currentPositionXY = [sind(currentPosition), cosd(currentPosition)];
            
            obj.hLineAngularRange.XData = angularRangeXY(:,1);
            obj.hLineAngularRange.YData = angularRangeXY(:,2);
            
            obj.hLineTargetPosition.XData = currentPositionXY(:,1);
            obj.hLineTargetPosition.YData = currentPositionXY(:,2);
            
            text = sprintf('%.2f%s',obj.hResource.lastKnownPositionOutput,most.constants.Unicode.degree_sign);
            obj.hText.String = text;
            
            obj.dirty = false;
        end
        
        function setPosition(obj)
            answer = most.gui.inputdlgCentered('Enter galvo position in optical degrees:'...
                ,'Galvo position'...
                ,[1 50]...
                ,{num2str(obj.hResource.lastKnownPositionOutput)});
            
            if ~isempty(answer)
                answer = str2double(answer{1});
                obj.hResource.pointPosition(answer);
            end
        end
        
        function startDrag(obj)
            hFig = ancestor(obj.hAx,'figure');
            WindowButtonMotionFcn = hFig.WindowButtonMotionFcn;
            WindowButtonUpFcn     = hFig.WindowButtonUpFcn;
            Pointer = hFig.Pointer;
            
            hFig.WindowButtonMotionFcn = @(varargin)drag;
            hFig.WindowButtonUpFcn     = @(varargin)stop;
            hFig.Pointer = 'left';
            
            function drag()
                try
                    pt = obj.hAx.CurrentPoint(1,1:2);
                    d = asind(pt(1)/pt(2));
                    
                    d = max(min(d,obj.hResource.travelRange(2)),obj.hResource.travelRange(1));
                    obj.hResource.pointPosition(d);
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                    stop();
                end
            end
            
            function stop()
                hFig.WindowButtonMotionFcn = WindowButtonMotionFcn;
                hFig.WindowButtonUpFcn     = WindowButtonUpFcn;
                hFig.Pointer = Pointer;
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
