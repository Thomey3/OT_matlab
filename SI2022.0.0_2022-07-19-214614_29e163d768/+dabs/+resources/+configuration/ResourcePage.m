classdef ResourcePage < handle
    properties (SetAccess = private)
        hResourceStore
        hResource
    end
    
    properties (SetAccess = private, Hidden)
        hFlow
        hFig
        hParent
        hPanel
        hStatusText
        hPbRemove
        hPbApply
        hResourcePageListeners = event.listener.empty(0,1);
    end
    
    methods (Abstract)
        makePanel(obj,hParent)
        redraw(obj)
        apply(obj)
        remove(obj)
    end
    
    methods
        function obj = ResourcePage(hResource,hParent)
            if nargin < 2 || isempty(hParent)
                obj.hFig = most.idioms.figure('CloseRequestFcn',@(varargin)obj.delete);
                obj.hParent = obj.hFig;
            else
                obj.hParent = hParent;
            end
            
            obj.hResourceStore = dabs.resources.ResourceStore();
            obj.hResource = hResource;
            
            obj.hResourceStore.scanSystemQuick();
            
            if most.idioms.isValidObj(hResource)
                obj.hResourcePageListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'ObjectBeingDestroyed',@(varargin)obj.delete);
            end
            obj.hResourcePageListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hParent,'ObjectBeingDestroyed',@(varargin)obj.delete);

            obj.makeLayout();
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hResourcePageListeners);
            most.idioms.safeDeleteObj(obj.hFlow);
            most.idioms.safeDeleteObj(obj.hFig);
        end
    end
    
    methods
        function makeLayout(obj)
            obj.hFlow = most.gui.uiflowcontainer('Parent',obj.hParent,'FlowDirection','TopDown','margin',5);
            obj.makeTitle(obj.hFlow);
            obj.hPanel = uipanel('parent',obj.hFlow,'BorderType','none');
            obj.makeStatus(obj.hFlow);
            
            obj.makePanel(obj.hPanel);
            obj.redraw();
        end

        function makeTitle(obj,hParent)
            flow = most.gui.uiflowcontainer('Parent',hParent,'FlowDirection','TopDown','margin',1,'HeightLimits',[30 30]);
            container = most.gui.uiflowcontainer('Parent',flow,'FlowDirection','LeftToRight','margin',1);
            most.gui.uicontrol('Parent',container,'Style','text','String',obj.hResource.name,'FontSize',15,'HorizontalAlignment','left','ButtonDownFcn',@(varargin)obj.hResource.assigninBase(),'Enable','inactive');
            container = most.gui.uiflowcontainer('Parent',hParent,'FlowDirection','LeftToRight','margin',1,'HeightLimits',[17 17]);
            most.gui.uicontrol('Parent',container,'Style','text','String',class(obj.hResource),'ButtonDownFcn',@(varargin)obj.editClass,'Enable','inactive','HorizontalAlignment','left');
            container = most.gui.uiflowcontainer('Parent',hParent,'FlowDirection','LeftToRight','margin',1,'HeightLimits',[1 1]);
            annotation(container,'line',[0 1],zeros(1,2), 'LineWidth', 1);
        end
        
        function editClass(obj)
            try
                edit(class(obj.hResource));
            catch ME
                if strcmpi(ME.identifier,'MATLAB:Editor:PFile')
                    msgbox('Driver is protected and cannot be edited.', 'Protected','help');
                else
                    most.ErrorHandler.rethrow(ME);
                end
            end
        end
        
        function makeStatus(obj,hParent)
            flow = most.gui.uiflowcontainer('Parent',hParent,'FlowDirection','LeftToRight','margin',1,'HeightLimits',[1 1]);
            annotation(flow,'line',[0 1],zeros(1,2), 'LineWidth', 1);
            flow = most.gui.uiflowcontainer('Parent',hParent,'FlowDirection','LeftToRight','margin',1,'HeightLimits',[30 30]);
            obj.hStatusText = most.gui.uicontrol('Parent',flow,'Style','text','String','Status','HorizontalAlignment','left','ButtonDownFcn',@(varargin)obj.displayStatus,'Enable','inactive');
            %most.gui.uicontrol('Parent',flow,'String','Undo','Callback',@(varargin)obj.redraw,'WidthLimits',[80 80]);
            obj.hPbRemove = most.gui.uicontrol('Parent',flow,'String','Remove','Callback',@(varargin)queryRemove(obj),'WidthLimits',[80 80]);
            obj.hPbApply  = most.gui.uicontrol('Parent',flow,'String','Apply','Callback',@(varargin)apply_,'WidthLimits',[80 80]);
            
            obj.hResourcePageListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'errorMsg','PostSet',@(varargin)obj.updateStatusText);
            obj.hResourcePageListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'warnMsg','PostSet',@(varargin)obj.updateStatusText);
            obj.updateStatusText();
            
            %%% Nested function
            function queryRemove(obj)
                answer = questdlg(...
                    sprintf('This will remove ''%s'' from your configuration.\nDo you want to proceed?',obj.hResource.name), ...
                    'Confirm removal','No');
                
                if strcmpi(answer,'Yes')
                    % prevent clicking of apply/remove button multiple times
                    obj.hPbRemove.Enable = 'off';
                    obj.hPbApply.Enable  = 'off';
                    try
                        obj.remove();
                    catch ME
                        most.ErrorHandler.logAndReportError(ME);
                        warndlg(ME.message,'Remove Resource');
                    end
                    try obj.hPbRemove.Enable = 'on'; end
                    try obj.hPbApply.Enable  = 'on'; end
                end
            end
            
            function apply_
                % prevent clicking of apply/remove button multiple times
                hFig_ = ancestor(obj.hParent,'figure');
                oldPointer = hFig_.Pointer;
                hFig_.Pointer = 'watch';
                
                obj.hPbRemove.Enable = 'off';
                obj.hPbApply.Enable  = 'off';
                drawnow();
                
                try
                    obj.apply();
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
                
                try
                    obj.redraw();
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
                
                obj.hPbRemove.Enable = 'on';
                obj.hPbApply.Enable  = 'on';
                hFig_.Pointer = oldPointer;
            end
        end
        
        function updateStatusText(obj)
            if ~isempty(obj.hResource.errorMsg)
                obj.hStatusText.hCtl.BackgroundColor = most.constants.Colors.lightRed;
                obj.hStatusText.String = ['Status: ' obj.hResource.errorMsg];
            elseif ~isempty(obj.hResource.warnMsg)
                obj.hStatusText.hCtl.BackgroundColor = most.constants.Colors.yellow;
                obj.hStatusText.String = ['Warning: ' obj.hResource.warnMsg];
            else
                obj.hStatusText.hCtl.BackgroundColor = most.constants.Colors.lightGray;
                obj.hStatusText.String = 'Status: OK';                
            end
            
            obj.hStatusText.hCtl.TooltipString = obj.hStatusText.String;
        end
        
        function setParent(obj,hParent)
            obj.hFlow.hParent = hParent;
        end
        
        function raise(obj)
            hFig_ = ancestor(obj.hParent,'figure');
            most.idioms.figure(hFig_);
        end
        
        function displayStatus(obj)
            if ~isempty(obj.hResource.errorMsg)
                h = errordlg(obj.hResource.errorMsg,obj.hResource.name);
                most.gui.centerOnScreen(h);
                
                fprintf(2,'%s: %s\n',obj.hResource.name,obj.hResource.errorMsg);
            elseif ~isempty(obj.hResource.warnMsg)
                h = warndlg(obj.hResource.warnMsg,obj.hResource.name);
                most.gui.centerOnScreen(h);
                
                fprintf(2,'%s: %s\n',obj.hResource.name,obj.hResource.warnMsg);
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
