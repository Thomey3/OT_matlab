classdef Widget < handle
    properties (SetAccess = private, Hidden)
        hFig
        hFlow
        hParent
        hResource;
        hPanel;
        hTxtTitle;
        hTxtConfig;
        hTxtMinimize;
        hPanelOutline;
        hTitleFlow;
        hListeners_Widget = event.listener.empty(0,1);
        sizeCache;
        highlightInProgress = false;
    end
    
    properties (SetAccess = private)
        hResourceStore;
    end
    
    methods (Abstract)
        makePanel(obj,hParent)
    end
    
    methods
        function obj = Widget(hResource,hParent)
            if nargin < 2 || isempty(hParent)
                obj.hFig = most.idioms.figure('CloseRequestFcn',@(varargin)obj.delete,'MenuBar','none','NumberTitle','off','Name',hResource.name);
                obj.hParent = obj.hFig;
            else
                obj.hParent = hParent;
            end
            
            obj.hResource = hResource;
            obj.hResourceStore = obj.hResource.hResourceStore;
            obj.hListeners_Widget(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'errorMsg','PostSet',@(varargin)obj.updateErrorStatus);
            obj.hListeners_Widget(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'warnMsg','PostSet',@(varargin)obj.updateErrorStatus);
            obj.hListeners_Widget(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'ObjectBeingDestroyed',@(varargin)obj.delete);
            obj.hListeners_Widget(end+1) = most.ErrorHandler.addCatchingListener(obj.hParent,'ObjectBeingDestroyed',@(varargin)obj.delete);
            
            obj.hFlow = most.gui.uiflowcontainer('Parent',obj.hParent,'FlowDirection','TopDown','margin',0.001);
                obj.hPanelOutline = uipanel('parent',obj.hFlow,'BorderWidth',2,'BorderType','line');
                    topPanelFlow = most.gui.uiflowcontainer('Parent',obj.hPanelOutline,'FlowDirection','TopDown','margin',0.001);
                        obj.hTitleFlow = most.gui.uiflowcontainer('Parent',topPanelFlow,'FlowDirection','LeftToRight','margin',1,'HeightLimits',[20 20]);
                            textColor = most.constants.Colors.white;
                            obj.hTxtTitle = most.gui.uicontrol('Parent',obj.hTitleFlow,'Style','text','String',obj.hResource.name,'HorizontalAlignment','left','FontSize',10,'FontWeight','bold','ForegroundColor',textColor,'Enable','inactive','ButtonDownFcn',@(varargin)obj.hResource.assigninBase(),'Units','pixel');
                            obj.hTxtConfig = most.gui.uicontrol('Parent',obj.hTitleFlow,'Style','text','Enable','inactive','String',getConfigSymbol(),'WidthLimits',[12 12],'ButtonDownFcn',@(varargin)obj.hResource.showConfig,'FontSize',11,'FontWeight','normal','ForegroundColor',textColor,'Visible','off');
                            obj.hTxtMinimize = most.gui.uicontrol('Parent',obj.hTitleFlow,'Style','text','Enable','inactive','String',most.constants.Unicode.black_up_pointing_triangle,'WidthLimits',[12 12],'ButtonDownFcn',@(varargin)toggleMinimize,'FontSize',8,'FontWeight','normal','ForegroundColor',textColor);
                        widgetFlow = most.gui.uiflowcontainer('Parent',topPanelFlow,'FlowDirection','LeftToRight','margin',0.001);
            
            if isa(hResource,'dabs.resources.configuration.HasConfigPage') && ~isempty(hResource.ConfigPageClass)
                obj.hTxtConfig.Visible = 'on';
            end
            
            obj.makePanel(widgetFlow);
            
            obj.updateErrorStatus();
            
            %%% Nested function
            function toggleMinimize()
                switch widgetFlow.Visible
                    case 'on'
                        widgetFlow.Visible = 'off';
                        obj.hTxtMinimize.String = most.constants.Unicode.black_down_pointing_triangle;
                        if isa(obj.hParent,'matlab.ui.container.internal.UIFlowContainer') && isprop(obj.hParent,'HeightLimits')
                           obj.sizeCache = obj.hParent.HeightLimits;
                           obj.hParent.HeightLimits = [23 23];
                        end
                    case 'off'
                        widgetFlow.Visible = 'on';
                        obj.hTxtMinimize.String = most.constants.Unicode.black_up_pointing_triangle;
                        if isa(obj.hParent,'matlab.ui.container.internal.UIFlowContainer') && isprop(obj.hParent,'HeightLimits')
                           obj.hParent.HeightLimits = obj.sizeCache;
                        end
                end
                
                if dabs.resources.widget.WidgetBar.isInstantiated
                    hWidgetBar = dabs.resources.widget.WidgetBar();
                    hWidgetBar.reLayout();
                end
            end
        end
        
        function delete(obj)
            obj.hListeners_Widget.delete();
            most.idioms.safeDeleteObj(obj.hFlow);
            most.idioms.safeDeleteObj(obj.hFig);
        end
    end
    
    methods
        function resizeTitle(obj)
            %obj.hTxtTitle.hCtl.Units = 'pixel';
            width = obj.hTxtTitle.hCtl.Position(3);
            numChar = numel(obj.hTxtTitle.String);
            
            nudgeFactor = 1.2;
            fontSize = width/numChar*nudgeFactor;
            fontSize = min(fontSize,10);
            obj.hTxtTitle.hCtl.FontSize = fontSize;
        end
            
        function updateErrorStatus(obj)
            if ~isempty(obj.hResource.errorMsg)
                color = most.constants.Colors.lightRed;
                textColor = most.constants.Colors.white;
            elseif ~isempty(obj.hResource.warnMsg)
                color = most.constants.Colors.yellow;
                textColor = most.constants.Colors.black;
            else
                color = most.constants.Colors.darkGray;
                textColor = most.constants.Colors.white;
            end
            
            obj.changeColor(color,textColor);
        end
        
        function highlight(obj)
            if obj.highlightInProgress
                return
            end
            
            obj.highlightInProgress = true;
            
            [originalColor,originalTextColor] = obj.getColor();
            highlightColor = most.constants.Colors.lightGray;
            highlightTextColor = most.constants.Colors.black;
            
            blinkTf = true;
            hTimer = timer('Period',0.1,'TasksToExecute',4,'ExecutionMode','fixedRate','TimerFcn',@blink,'StopFcn',@reset);
            start(hTimer);
            
            %%% Nested functios
            function blink(~,~)
                if most.idioms.isValidObj(obj)
                    if blinkTf
                        obj.changeColor(highlightColor,highlightTextColor);
                    else
                        obj.changeColor(originalColor,originalTextColor);
                    end
                    
                    blinkTf = ~blinkTf;
                end
            end
            
            function reset(src,~)
                most.idioms.safeDeleteObj(src);
                if most.idioms.isValidObj(obj)
                    obj.changeColor(originalColor,originalTextColor);
                    obj.highlightInProgress = false;
                end
            end
        end
        
        function changeColor(obj,color,textColor)
            obj.hTitleFlow.BackgroundColor = color;
            obj.hTxtTitle.hCtl.BackgroundColor  = color;
            obj.hTxtTitle.hCtl.ForegroundColor = textColor;
            obj.hTxtConfig.hCtl.BackgroundColor = color;
            obj.hTxtConfig.hCtl.ForegroundColor = textColor;
            obj.hTxtMinimize.hCtl.BackgroundColor = color;
            obj.hTxtMinimize.hCtl.ForegroundColor = textColor;
            obj.hPanelOutline.HighlightColor = color;
        end
        
        function [color,textColor] = getColor(obj)
            color = obj.hTxtTitle.hCtl.BackgroundColor;
            textColor = obj.hTxtTitle.hCtl.ForegroundColor;
        end
        
        function setParent(obj,hParent)
            obj.hFlow.hParent = hParent;
        end
    end
end

function symbol = getConfigSymbol()
    if verLessThan('matlab','9.3')
        % the gear symbol only works in Matlab R2017b or later
        symbol = most.constants.Unicode.medium_black_circle;
    else
        symbol = most.constants.Unicode.gear;
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
