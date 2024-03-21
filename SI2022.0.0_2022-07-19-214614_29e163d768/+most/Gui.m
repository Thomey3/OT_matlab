classdef Gui < matlab.mixin.SetGet & dynamicprops
    %GUI Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetObservable)
        Visible;
    end
    
    properties (Hidden)
        hFig;
        hModel;
        hController;
        
        hCtls = {};
        hLis = event.listener.empty();
        tfMap = containers.Map({true false}, {'on' 'off'});
    end
    
    properties (SetAccess = private)
        isGuiLoaded = false;
    end
    
    properties (Hidden,SetAccess = protected)
        showWaitbarDuringInitalization = false;
    end
    
    methods
        function obj = Gui(hModel, hController, size, units, varargin)
            if nargin > 0
                obj.hModel = hModel;
            end
            
            if nargin > 1
                obj.hController = hController;
            end
            
            if nargin < 3
                size = [];
            end
            
            if nargin < 4 || isempty(units)
                units = 'pixels';
            end
            
            obj.hFig = most.idioms.figure('numbertitle', 'off', 'visible', 'off', 'menubar', 'none','Units',units,...
                'Color', get(0,'defaultfigureColor'), 'PaperPosition',get(0,'defaultfigurePaperPosition'),...
                'ScreenPixelsPerInchMode','manual', 'ParentMode', 'manual', 'HandleVisibility','callback',varargin{:});
            
            if ~isempty(size)
                p = most.gui.centeredScreenPos(size,units);
                set(obj.hFig, 'position', p)
            end
            
            %note this handle keeps this object in context as long as the
            %figure is still open even if all handles to the object go out
            %of scope
            set(obj.hFig,'UserData',obj);
            set(obj.hFig,'DeleteFcn',@(varargin)obj.figDeleted());
            
            obj.hLis(end+1) = most.ErrorHandler.addCatchingListener(obj.hFig, 'ObjectBeingDestroyed',@(varargin)obj.delete);
            obj.hLis(end+1) = most.ErrorHandler.addCatchingListener(obj.hFig, 'Visible','PostSet',@obj.visibleChangedHookInternal);
            if most.idioms.isValidObj(obj.hModel)
                obj.hLis(end+1) = most.ErrorHandler.addCatchingListener(obj.hModel, 'ObjectBeingDestroyed',@(varargin)most.idioms.safeDeleteObj(obj));
            end
            if most.idioms.isValidObj(obj.hController)
                obj.hLis(end+1) = most.ErrorHandler.addCatchingListener(obj.hController, 'ObjectBeingDestroyed',@(varargin)most.idioms.safeDeleteObj(obj));
            end
        end
        
        function delete(obj)
            delete(obj.hLis);
            
            for i = 1:numel(obj.hCtls)
                most.idioms.safeDeleteObj(obj.hCtls{i});
            end
            
            most.idioms.safeDeleteObj(obj.hFig);
        end
    end
    
    %% Public methods
    methods
        function hCtl = addUiControl(obj,varargin)
            if ~any(strcmpi(varargin,'Parent'))
                varargin{end+1} = 'Parent';
                varargin{end+1} = obj.hFig;
            end
            hCtl = most.gui.uicontrol(varargin{:});
            name = get(hCtl, 'Tag');
            obj.hCtls{end+1} = hCtl;
            
            if isvarname(name)
                hProp = obj.addprop(name);
                hProp.Hidden = true;
                obj.(name) = hCtl;
            end
        end
        
        function convertToRelPosition(obj)
            for i = 1:numel(obj.hCtls)
                obj.hCtls{i}.convertToRelPosition();
            end
        end
        
        function raise(obj)
            obj.Visible = true;
            most.idioms.figure(obj.hFig);
        end
    end
    
    %% Internal
    methods (Hidden)
        function figDeleted(obj)
            % called if the figure is deleted. Default behavior is do
            % nothing
        end
        
        function val = validatePropArg(obj,propname,val)
            
        end
    end
    
    %% Prop Access
    methods
        function val = get.Visible(obj)
            val = strcmp(get(obj.hFig,'Visible'),'on');
        end
        
        function set.Visible(obj,val)
            obj.initGuiOnce();
            
            if (~ischar(val) && val) || strcmpi(val,'on')
                set(obj.hFig,'Visible','on');
            else
                set(obj.hFig,'Visible','off');
            end
        end
    end
    
    methods
        function showGui(obj)
            obj.Visible = true;
        end
    end
    
    %% Overload methods if needed
    methods (Access = protected)
        function initGui(obj)
        end 
        
        function visibleChangedHook(obj,src,evt)
            % can be overloaded by child class
        end
        
        function initGuiOnce(obj)
            if ~obj.isGuiLoaded
                obj.isGuiLoaded = true;
                
                hWb = [];
                if obj.showWaitbarDuringInitalization
                    hWb = waitbar(0.2,'Initializing GUI','Name','Initializing');
                end
                
                try
                    obj.initGui();
                catch ME
                    most.idioms.safeDeleteObj(hWb);
                    ME.rethrow();
                end
                most.idioms.safeDeleteObj(hWb);
            end
        end
    end
    
    methods (Access = private)
        function visibleChangedHookInternal(obj,src,evt)
            if obj.Visible
                obj.initGuiOnce();
            end
            obj.visibleChangedHook(src,evt);
        end
    end
    
    methods
        function set.showWaitbarDuringInitalization(obj,val)
            validateattributes(val,{'numeric','logical'},{'binary','scalar'});
            obj.showWaitbarDuringInitalization = logical(val);
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
