classdef WidgetBar < handle & most.util.Singleton
    properties (SetAccess = private)
        hFig
        hWidgets = {};
        hMainFlow
        hWidgetsFlowLR
        hWidgetsFlow1
        hWidgetsFlow2
        hWidgetsFlow3
        hWidgetsFlow4
        
        hListeners = event.listener.empty(0,1);
        hDelayedListeners = most.util.DelayedEventListener.empty(0,1);
        
        hResourceStore;
        currentMonitor;
        currentSide;
        
        initialized = false;
        columnWidth = 132;
        numColumns = 1;
    end
    
    properties (SetAccess = private, Hidden)
        dirty = false;
        semaphore = false;
    end
    
    properties (SetObservable)
        CloseRequestFcn;
        stayOnTop = false;
    end
    
    properties (Dependent)
        Visible
    end
    
    methods
        function obj = WidgetBar()
            if ~obj.initialized
                obj.initialized = true;
                
                obj.hFig = most.idioms.figure('CloseRequestFcn',@(varargin)obj.closeRequest,'NumberTitle','off','MenuBar','none','Name','Widget Bar','Tag','WidgetBar','Resize','off');
                
                obj.moveToMonitor();
                
                obj.hResourceStore = dabs.resources.ResourceStore();
                obj.hDelayedListeners(end+1) = most.util.DelayedEventListener(0.5,obj.hResourceStore,'hResources','PostSet',@(varargin)obj.redraw);
                obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResourceStore,'ObjectBeingDestroyed',@(varargin)obj.delete);
                
                obj.stayOnTop = true;
                obj.hMainFlow = most.gui.uiflowcontainer('Parent',obj.hFig,'FlowDirection','TopDown','margin',0.001);
                obj.makeDecoration(obj.hMainFlow);
                obj.hWidgetsFlowLR = most.gui.uiflowcontainer('Parent',obj.hMainFlow,'FlowDirection','RightToLeft','margin',2);
                
                obj.redraw();
                
                obj.hFig.Visible = 'on';
            end
        end
        
        function delete(obj)
            if obj.initialized
                most.idioms.safeDeleteObj(obj.hListeners);
                most.idioms.safeDeleteObj(obj.hDelayedListeners);
                most.idioms.safeDeleteObj(obj.hWidgets);
                most.idioms.safeDeleteObj(obj.hFig);
                obj.initialized = false;
            end
        end
    end
    
    methods (Static)
        function tf = isInstantiated()
            tf = most.util.Singleton.isInstantiated(mfilename('class'));
        end
    end
    
    methods        
        function reLayout(obj)            
            drawnow(); % required to get correct height of widgets
            
            widgetHeights = zeros(numel(obj.hWidgets),1);
            widgetHeightLimits = zeros(numel(obj.hWidgets),1);

            for idx = 1:numel(obj.hWidgets)
                hWidget = obj.hWidgets{idx};
                hWidget.hParent.Units = 'pixel';
                widgetHeights(idx) = hWidget.hParent.Position(4);
                widgetHeightLimits(idx) = hWidget.hParent.HeightLimits(1);
            end
            
            obj.hWidgetsFlow1.Units = 'pixel';
            columnHeight = obj.hWidgetsFlow1.Position(4);
            widgetHeights = widgetHeights + 5.15; % add some height for frame and margin
            columnMask = ceil(cumsum(widgetHeights) / columnHeight);
            columnMask = min(columnMask,4);
            
            for idx = 1:numel(obj.hWidgets)
                obj.hWidgets{idx}.hParent.Parent = [];
            end

            for idx = 1:numel(obj.hWidgets)
                column = columnMask(idx);
                obj.hWidgets{idx}.hParent.Parent = obj.(sprintf('hWidgetsFlow%d',column));
                obj.hWidgets{idx}.hParent.HeightLimits = [1 1] * widgetHeightLimits(idx);
            end
            
            if isempty(columnMask)
                obj.numColumns = 1;
            else
                obj.numColumns = max(columnMask);
            end
            
            obj.moveToMonitor(obj.currentMonitor,obj.currentSide);
        end
        
        function moveToMonitor(obj,monitorNumber,side,inc)
            if isempty(obj.hFig)
                return
            end
            
            if nargin < 2 || isempty(monitorNumber)
                monitorNumber = getPrimaryMonitorNumber();
                side = 1;
            elseif nargin > 3 && ~isempty(inc)
                newSide = side+inc;
                side = mod(newSide,2);
                if side ~= newSide
                    monitorNumber = monitorNumber+inc;
                end
            end
            
            validateattributes(monitorNumber,{'numeric'},{'scalar','integer'});            
            monitors = getMonitorSizesLeftToRight();
            nMonitors = size(monitors,1);
            monitorNumber = mod(monitorNumber-1,nMonitors)+1;
            
            m = monitors(monitorNumber,:);
            
            figWidth = 20+(obj.columnWidth+1)*obj.numColumns; % minimum possible figure width is 132
            taskBarHeight = 33;
            xNudgeFactor = 7;
            
            obj.hFig.OuterPosition = [m(1)+side*(m(3)-figWidth)+xNudgeFactor*((-1)^(side+1)), ... % x
                                      m(2)+taskBarHeight,              ... % y
                                      figWidth,                        ... % width
                                      m(4)-taskBarHeight];                 % height

            if most.idioms.isValidObj(obj.hWidgetsFlowLR)
                if side == 0
                    obj.hWidgetsFlowLR.FlowDirection = 'LeftToRight';
                else
                    obj.hWidgetsFlowLR.FlowDirection = 'RightToLeft';
                end
            end
            
            obj.currentMonitor = monitorNumber;
            obj.currentSide = side;
        end
        
        function closeRequest(obj)
            if isempty(obj.CloseRequestFcn)
                obj.delete();
            else
                obj.CloseRequestFcn();
            end
        end
        
        function makeDecoration(obj,hParent)
            backgroundColor = most.constants.Colors.darkGray;
            textColor = most.constants.Colors.white;
            
            hFlow = most.gui.uiflowcontainer('Parent',hParent,'FlowDirection','LeftToRight','margin',0.001,'HeightLimits',[20 20],'BackgroundColor',backgroundColor);
                most.gui.uicontrol('Parent',hFlow,'Style','text','Enable','inactive','String',most.constants.Unicode.black_left_pointing_triangle, 'WidthLimits',[12 12],'ButtonDownFcn',@(varargin)move(-1),'FontSize',11,'FontWeight','normal','ForegroundColor',textColor,'BackgroundColor',backgroundColor);
                hSpaceFlow = most.gui.uiflowcontainer('Parent',hFlow,'BackgroundColor',backgroundColor);
                most.gui.uicontrol('Parent',hFlow,'Style','checkbox','String','stay on top','BackgroundColor',backgroundColor,'ForegroundColor',textColor,'Bindings',{obj,'stayOnTop','value'},'WidthLimits',[75 75]);
                hSpaceFlow = most.gui.uiflowcontainer('Parent',hFlow,'BackgroundColor',backgroundColor);
                most.gui.uicontrol('Parent',hFlow,'Style','text','Enable','inactive','String',most.constants.Unicode.black_right_pointing_triangle,'WidthLimits',[12 12],'ButtonDownFcn',@(varargin)move(+1),'FontSize',11,'FontWeight','normal','ForegroundColor',textColor,'BackgroundColor',backgroundColor);
            
            function move(inc)
                obj.moveToMonitor(obj.currentMonitor,obj.currentSide,inc);
            end
        end
        
        function redraw(obj)
            if obj.semaphore
                obj.dirty = true;
                return
            end
            
            obj.semaphore = true;
            obj.dirty = false;
            
            try
                obj.redrawProtected();
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
            
            obj.semaphore = false;
            
            if obj.dirty
                obj.redraw();
            end
        end
        
        function redrawProtected(obj)
            % recreate all widgets
            obj.clear();
            makeWidgets();
            resizeWidgetTitles();
            obj.reLayout();
            
            %%% Nested functions
            function makeWidgets()
                hResources = obj.hResourceStore.filterByClass('dabs.resources.widget.HasWidget');
                
                isSIMask      = cellfun(@(hR)isa(hR,'scanimage.SI'),hResources);
                isvDAQMask    = cellfun(@(hR)isa(hR,'dabs.resources.daqs.vDAQ'),hResources);
                isShutterMask = cellfun(@(hR)isa(hR,'dabs.resources.devices.Shutter'),hResources);
                
                priorityMask = zeros(size(hResources));
                priorityMask(isSIMask)      = -3;
                priorityMask(isvDAQMask)    = -2;
                priorityMask(isShutterMask) = -1;
                
                [~,sortIdxs] = sort(priorityMask);
                hResources = hResources(sortIdxs);
                
                drawnow(); % required to read the correct figure position
                height = obj.columnWidth;
                
                for idx = 1:numel(hResources)
                    try
                        hWidget = [];
                        hFlow = most.gui.uiflowcontainer('Parent',obj.hWidgetsFlow1,'FlowDirection','LeftToRight','margin',0.001,'HeightLimits',[height height]);
                        hWidget = hResources{idx}.makeWidget(hFlow);
                        if most.idioms.isValidObj(hWidget)
                            obj.hWidgets{end+1} = hWidget;
                        else
                            delete(hFlow);
                        end
                    catch ME
                        most.idioms.safeDeleteObj(hWidget)
                        most.idioms.safeDeleteObj(hFlow);
                        most.ErrorHandler.logAndReportError(ME);
                    end
                end
            end
            
            function resizeWidgetTitles()
                drawnow(); % this is needed to get the correct width of the widgets
                for idx = 1:numel(obj.hWidgets)
                    obj.hWidgets{idx}.resizeTitle();
                end
            end
        end
        
        function close(obj)
            obj.Visible = false;
        end
        
        function clear(obj)
            most.idioms.safeDeleteObj(obj.hWidgets);
            obj.hWidgets = {};
            
            most.idioms.safeDeleteObj(obj.hWidgetsFlow1);
            most.idioms.safeDeleteObj(obj.hWidgetsFlow2);
            most.idioms.safeDeleteObj(obj.hWidgetsFlow3);
            most.idioms.safeDeleteObj(obj.hWidgetsFlow4);
            
            obj.hWidgetsFlow1 = most.gui.uiflowcontainer('Parent',obj.hWidgetsFlowLR,'FlowDirection','TopDown','margin',5,'WidthLimits',[obj.columnWidth obj.columnWidth]);
            obj.hWidgetsFlow2 = most.gui.uiflowcontainer('Parent',obj.hWidgetsFlowLR,'FlowDirection','TopDown','margin',5,'WidthLimits',[obj.columnWidth obj.columnWidth]);
            obj.hWidgetsFlow3 = most.gui.uiflowcontainer('Parent',obj.hWidgetsFlowLR,'FlowDirection','TopDown','margin',5,'WidthLimits',[obj.columnWidth obj.columnWidth]);
            obj.hWidgetsFlow4 = most.gui.uiflowcontainer('Parent',obj.hWidgetsFlowLR,'FlowDirection','TopDown','margin',5,'WidthLimits',[obj.columnWidth obj.columnWidth]);
        end
    end
    
    methods
        function set.Visible(obj,val)
            oldVal = obj.Visible;
            
            switch val
                case {true,'on'}
                    val = true;
                    obj.hFig.Visible = 'on';
                otherwise
                    val = false;
                    obj.hFig.Visible = 'off';
                    most.idioms.safeDeleteObj(obj.hWidgets);
            end
            
            if val && ~oldVal
                obj.redraw();
                obj.stayOnTop = obj.stayOnTop;
            elseif ~val && oldVal
                obj.clear();
            end
        end
        
        function val = get.Visible(obj)
            val = strcmpi(obj.hFig.Visible,'on');
        end
        
        function set.stayOnTop(obj,val)
            validateattributes(val,{'logical','numeric'},{'scalar','binary'});
            val = logical(val);
            most.gui.winOnTop(obj.hFig,val);
            obj.stayOnTop = val;
        end
    end
end

%%% local functions
function monitorSizes = getMonitorSizesLeftToRight()
    monitorSizes = get(0, 'MonitorPositions');
    [~,sortIdx] = sort(monitorSizes(:,1));
    monitorSizes = monitorSizes(sortIdx,:);
end

function monitorNumber = getPrimaryMonitorNumber()
    monitorNumber = 1;

    primaryMonitorSize = get(0,'ScreenSize');
    monitorSizes = getMonitorSizesLeftToRight();
    
    for idx = 1:size(monitorSizes,1)
        if isequal(primaryMonitorSize,monitorSizes(idx,:))
            monitorNumber = idx;
            break;
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
