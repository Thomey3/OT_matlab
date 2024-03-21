classdef ResourceConfigurationEditor < most.util.Singleton
    properties
        hFig;
        hFlow;
        hLeftFlow;
        hButtonFlow = matlab.ui.container.internal.UIFlowContainer.empty();
        hPagePanel;
        hPageContainer;
        Visible;
        hTabGroup;
        hSITab;
        hDeviceTab;
        
        hButtons = matlab.ui.control.UIControl.empty(0,1);
        vDAQBreakoutButtons = matlab.ui.control.UIControl.empty(0,1)
        
        hButtonListeners = event.listener.empty(0,1);
        hListeners = event.listener.empty(0,1);
        hDelayedListeners = most.util.DelayedEventListener.empty(0,1);
        
        hResourceStore;
        hPage;
    end
    
    properties (SetAccess = private, GetAccess = private)
        initialized = false;
        semaphore = false;
        dirty = false;
    end
    
    methods
        function obj = ResourceConfigurationEditor()
            if ~obj.initialized
                obj.initialize();
                obj.initialized = true;
            end
        end
    end
    
    methods
        function delete(obj)
            if ~obj.singletonTrash
                most.idioms.safeDeleteObj(obj.hPage);
                most.idioms.safeDeleteObj(obj.hListeners);
                most.idioms.safeDeleteObj(obj.hDelayedListeners);
                most.idioms.safeDeleteObj(obj.hButtonListeners);
                most.idioms.safeDeleteObj(obj.hFig);
                
                obj.highlightBreakout();
            end
        end
        
        function initialize(obj)
            obj.hFig = most.idioms.figure('NumberTitle','off','Name','Resource Configuration','CloseRequestFcn',@(src,evt)obj.safeDeleteFig(src),'MenuBar','none');
            
            obj.hResourceStore = dabs.resources.ResourceStore();
            obj.hResourceStore.scanSystem();
            
            obj.hFlow = most.gui.uiflowcontainer('Parent',obj.hFig,'FlowDirection','LeftToRight','margin',5);
            obj.hLeftFlow = most.gui.uiflowcontainer('Parent',obj.hFlow,'FlowDirection','TopDown','margin',0.1,'WidthLimits',[150 150]);
            obj.hTabGroup = uitabgroup('Parent',obj.hLeftFlow,'SelectionChangedFcn',@(varargin)tabSwitch);
                obj.hSITab     = uitab('Parent',obj.hTabGroup,'Title','ScanImage');
                obj.hDeviceTab = uitab('Parent',obj.hTabGroup,'Title','Devices');
            
            obj.hPagePanel = uipanel('Parent',obj.hFlow);
            
            obj.hDelayedListeners(end+1) = most.util.DelayedEventListener(0.3,obj.hResourceStore,'hResources','PostSet',@(varargin)obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResourceStore,'ObjectBeingDestroyed',@(varargin)obj.delete);
            
            obj.showPage();
            obj.redraw();
            
            %%% Nested function
            function tabSwitch()
                obj.showPage();
                obj.redraw();
            end
        end
        
        function safeDeleteFig(obj,src)
            most.idioms.safeDeleteObj(obj);
            most.idioms.safeDeleteObj(src);
        end
        
        function redraw(obj)
            % this is to fix issue 468
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
            hSI = obj.hResourceStore.filterByClass('scanimage.SI');
            
            hSIResources = obj.hResourceStore.filter(...
                @(hR)isa(hR,'dabs.resources.configuration.HasConfigPage')...
                && isa(hR,'dabs.resources.SIComponent')...
                && ~isa(hR,'scanimage.components.Scan2D')...
                );
            
            hSIResources = [hSIResources obj.hResourceStore.filter(...
                @(hR)isa(hR,'scanimage.components.Scan2D')...
                )];
            
            hDevices = obj.hResourceStore.filter(...
                @(hR)isa(hR,'dabs.resources.configuration.HasConfigPage')...
                &&~isa(hR,'dabs.resources.SIComponent')...
                );
            
            switch obj.hTabGroup.SelectedTab
                case obj.hSITab
                    hResources = hSIResources;
                    addType = 'Scan2D';
                    
                    if ~isempty(hSI)
                        try
                            hSI{1}.validateConfiguration();
                        catch ME
                            most.ErrorHandler.logAndReportError(ME);
                        end
                    end
                case obj.hDeviceTab
                    hResources = hDevices;
                    addType = 'Device';
            end
            
            updateTabLabels(hDevices);
            makeResourceButtons(hResources);
            makeAddButton(addType);
            makevDaqBreakoutButtons();
            
            %%% NestdFunctions
            function updateTabLabels(hDevices)
                obj.hDeviceTab.Title = sprintf('Devices (%d)',numel(hDevices));
            end
            
            function makeResourceButtons(hResources)
                obj.hButtons.delete();
                obj.hButtons = most.gui.uicontrol.empty(0,1);
                
                obj.hButtonListeners.delete();
                obj.hButtonListeners = event.listener.empty(0,1);
                
                obj.hButtonFlow.delete();
                obj.hButtonFlow = matlab.ui.container.internal.UIFlowContainer.empty();
                
                % recreate buttons
                obj.hButtonFlow = most.gui.uiflowcontainer('Parent',obj.hTabGroup.SelectedTab,'FlowDirection','TopDown','margin',0.1);
                
                for idx = 1:numel(hResources)
                    hResource = hResources{idx};
                    
                    if ~isempty(hResource.errorMsg)
                        color   = most.constants.Colors.lightRed;
                        tooltip = sprintf('%s\n%s',class(hResource),hResource.errorMsg);
                    elseif ~isempty(hResource.warnMsg)
                        color   = most.constants.Colors.yellow;
                        tooltip = sprintf('%s\n%s',class(hResource),hResource.warnMsg);
                    else
                        color   = most.constants.Colors.lightGray;
                        tooltip = '';
                    end
                    
                    obj.hButtons(end+1) = most.gui.uicontrol( ...
                        'Parent',obj.hButtonFlow(end) ...
                        ,'Style','togglebutton' ...
                        ,'String',hResource.name ...
                        ,'Callback',@(varargin)obj.showPage(hResource) ...
                        ,'TooltipString',tooltip ...
                        ,'UserData',hResource ...
                        ,'BackgroundColor',color ...
                        ,'HeightLimits',[15 30] ...
                        ,'Value',most.idioms.isValidObj(obj.hPage)&&isequal(obj.hPage.hResource,hResource) ...
                        );
                    
                    obj.hButtonListeners(end+1) = most.ErrorHandler.addCatchingListener(hResource,'errorMsg','PostSet',@(varargin)obj.redraw);
                    obj.hButtonListeners(end+1) = most.ErrorHandler.addCatchingListener(hResource,'warnMsg','PostSet',@(varargin)obj.redraw);
                end
            end
            
            function makeAddButton(addType)
                isScan2D = strcmpi(addType,'Scan2D');
                
                hAddButton = most.gui.uicontrol( ...
                    'Parent',obj.hButtonFlow ...
                    ,'String', most.idioms.ifthenelse(isScan2D, '+ Add Imaging System +', '+') ...
                    ,'Callback', most.idioms.ifthenelse(isScan2D, @(varargin)obj.addScan2D, @(varargin)obj.addResource)  ...
                    ,'FontWeight','bold' ...
                    ,'FontSize', most.idioms.ifthenelse(isScan2D,8,12) ...
                    ,'TooltipString',most.idioms.ifthenelse(isScan2D, 'Add Imaging System', 'Add device') ...
                    ,'HeightLimits',[15 30]);
                
                obj.hButtons(end+1) = hAddButton;
                
                if isScan2D && isempty(obj.hResourceStore.filterByClass('scanimage.components.Scan2D'))
                    hAddButton.hCtl.BackgroundColor = most.constants.Colors.lightRed;
                end
            end
            
            function makevDaqBreakoutButtons()
                delete(obj.vDAQBreakoutButtons);
                obj.vDAQBreakoutButtons = most.gui.uicontrol.empty(0,1);
                hvDAQs = obj.hResourceStore.filterByClass(?dabs.resources.daqs.vDAQ);
                for idx = 1:numel(hvDAQs)
                    hvDAQ = hvDAQs{idx};
                    label = sprintf('Show %s pinout',hvDAQ.name);
                    obj.vDAQBreakoutButtons(end+1) = most.gui.uicontrol('Parent',obj.hLeftFlow,'String',label,'Callback',@(varargin)obj.showBreakout(hvDAQ),'HeightLimits',[30 30]);
                end
            end
        end
    end
    
    methods (Static)        
        function obj = show()
            obj = dabs.resources.configuration.ResourceConfigurationEditor();
            obj.raise();
        end
    end
    
    methods
        function raise(obj)
            obj.Visible = true;
            most.idioms.figure(obj.hFig);
        end
        
        function showPage(obj,hResource)
            if nargin < 2 || isempty(hResource) || ~most.idioms.isValidObj(hResource)
                hResource = [];
            end

            most.idioms.safeDeleteObj(obj.hPage);
            most.idioms.safeDeleteObj(obj.hPageContainer);

            try
                obj.hPageContainer = uicontainer('Parent',obj.hPagePanel);
                if nargin < 2 || isempty(hResource)
                    obj.hPage = dabs.resources.configuration.resourcePages.WelcomePage([],obj.hPageContainer);
                else
                    obj.hPage = hResource.makeConfigPage(obj.hPageContainer);
                end
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end

            if most.idioms.isValidObj(hResource)
                if isa(hResource,'dabs.resources.SIComponent')
                    obj.hTabGroup.SelectedTab = obj.hSITab;
                else
                    obj.hTabGroup.SelectedTab = obj.hDeviceTab;
                end
            end

            obj.redraw();
            obj.raise();
            obj.highlightBreakout();
            
            if isa(hResource,'dabs.resources.widget.HasWidget')
                hResource.highlightWidgets();
            end
        end
        
        function showBreakout(obj,hvDAQ)
            hvDAQ.showBreakout();
            obj.highlightBreakout();
        end
        
        function highlightBreakout(obj)
            try
                if most.idioms.isValidObj(obj.hPage) && most.idioms.isValidObj(obj.hPage.hResource)
                    hResource = obj.hPage.hResource;
                else
                    hResource = dabs.resources.Resource.empty();
                end
                
                hvDAQs = obj.hResourceStore.filterByClass('dabs.resources.daqs.vDAQ');
                for idx = 1:numel(hvDAQs)
                    hvDAQ = hvDAQs{idx};
                    if most.idioms.isValidObj(hvDAQ.hBreakout)
                        hvDAQ.hBreakout.highlightResource(hResource);
                    end
                end
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
        end
        
        function addScan2D(obj)
            hSI = obj.hResourceStore.filterByClass('scanimage.SI');
            if isempty(hSI)
                siRunning = false;
            else
                hSI = hSI{1};
                siRunning = hSI.mdlInitialized;
            end
            
            if siRunning
                warndlg('Cannot add imaging system while ScanImage is running.','Info');
            else
                dabs.resources.configuration.private.Scan2DSelector();
            end
        end
        
        function addResource(obj)               
            dabs.resources.configuration.private.ResourceSelector();
        end
    end
    
    %% Property getter/setter
    methods
        function set.Visible(obj,val)
            if strcmpi(val,'on') || val
                obj.hFig.Visible = 'on';
            else
                obj.hFig.Visible = 'off';
            end
        end
        
        function val = get.Visible(obj)
            val = strcmpi(obj.hFig.Visible,'on');
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
