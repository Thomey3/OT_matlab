classdef SIStatusWidget < dabs.resources.widget.Widget
    properties (SetAccess=private)
        hListeners = event.listener.empty(0,1);
        hPatchStop
        hTextStop
        hTextStatus
        hAx;
    end
    
    methods
        function obj = SIStatusWidget(hResource,hParent)
            obj@dabs.resources.widget.Widget(hResource,hParent);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(hResource,'acqState','PostSet',@(varargin)obj.redraw);
            
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
                hFlowAx = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','LeftToRight','margin',0.001);
                    obj.hAx = most.idioms.axes('Parent',hFlowAx,'Units','normalized','Position',[0 0 1 1],'DataAspectRatio',[1 1 1],'XTick',[],'YTick',[],'Visible','off','XLimSpec','tight','YLimSpec','tight');
                    obj.hPatchStop = patch('Parent',obj.hAx,'LineStyle','none','FaceColor',most.constants.Colors.red,'ButtonDownFcn',@(varargin)obj.stop);
                    obj.hTextStop = most.util.StaticHeightText('Parent',obj.hAx,'Position',[0,0],'String','STOP','HorizontalAlignment','center','VerticalAlignment','middle','Color','white','FontSize',0.6,'FontWeight','bold','Hittest','off','PickableParts','none');
                    obj.hTextStatus = text('Parent',obj.hAx);
                
                most.gui.uicontrol('Parent',hFlow,'String','Raise windows','HeightLimits',[18,18],'Callback',@(varargin)obj.raiseScanImage);
        end
        
        function redraw(obj)
            angles = linspace(45/2,360+45/2,9)';
            xy = [cosd(angles),sind(angles)];
            obj.hPatchStop.Vertices = xy;
            obj.hPatchStop.Faces = 1:size(xy,1);
            
            obj.hTextStatus.Position = [0,-1];
            obj.hTextStatus.String = ['SI: ' obj.hResource.acqState];
            obj.hTextStatus.HorizontalAlignment = 'center';
            obj.hTextStatus.VerticalAlignment = 'top';
            obj.hTextStatus.FontWeight = 'bold';
            
            obj.hAx.YLim = [-1.5 1.1];
        end
        
        function raiseScanImage(obj)
            hControllers = obj.hResource.hController;
            if isempty(hControllers) || ~most.idioms.isValidObj(hControllers{1})
                hFig = warndlg('ScanImage is not initialized');
                most.gui.centerOnScreen(hFig);
            else
                hController = hControllers{1};
                hController.raiseAllGUIs();
            end
        end
        
        function stop(obj)
            most.gui.Transition(0,obj.hPatchStop,'FaceColor',most.constants.Colors.white);
            most.gui.Transition(0.2,obj.hPatchStop,'FaceColor',most.constants.Colors.red,'circleIn');
            
            try
                if isempty(obj.hResource.errorMsg)
                    if obj.hResource.mdlInitialized
                        obj.hResource.abort();
                    end
                end
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
            
            hShutters = obj.hResourceStore.filterByClass('dabs.resources.devices.Shutter');
            for idx = 1:numel(hShutters)
                try
                    hShutters{idx}.close();
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
            end
            
            hBeams = obj.hResourceStore.filterByClass('dabs.resources.devices.BeamModulator');
            for idx = 1:numel(hBeams)
                try
                    hBeams{idx}.setPowerFraction(0);
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
            end
            
            hBeamRouter = obj.hResourceStore.filterByClass('dabs.generic.BeamRouter');
            for idx = 1:numel(hBeamRouter)
                try
                    hBeamRouter{idx}.setPowerFractionsZero();
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
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
