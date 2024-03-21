classdef popupMenuEdit < handle
    %UICONTROL Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        hPopup;
        hEdit;
        hPanel;
        
        % pass through to hCtl
        string;
        showEdit;
        selectionIdx;
        choices;
        visible;
        enable;
        callback;
        position;
        tooltipString;
        validationFunc; % [result,newString,errMsg] = validationFunc(newString,oldString);
                        % result: 0=OK, 1=WARN, 2=ERROR
                        
        RelPosition;
    end
    
    properties (Hidden)
        bindings = {};
        hBindingListeners = {};
        hRelPositionListener;
        hDelLis;
        oldString = '';
        forceSet = false;
        tooltipStringRaw = '';
        currErrMsg = '';
    end
    
    methods
        function obj = popupMenuEdit(varargin)
            ip = most.util.InputParser;
            ip.addOptional('position', []);
            ip.addOptional('choices', []);
            ip.addOptional('bindings', {});
            ip.addOptional('callback', {});
            ip.addOptional('horizontalalignment', 'left');
            ip.addOptional('tooltipstring', '');
            ip.addOptional('validationFunc', {});
            ip.addOptional('WidthLimits',[]);
            ip.addOptional('HeightLimits',[]);
            ip.addOptional('SizeLimits',[]);
            ip.addOptional('RelPosition',[]);
            ip.addOptional('showEdit', true);
            ip.parse(varargin{:});
            otherPVArgs = most.util.structPV2cellPV(ip.Unmatched);
            
            obj.hPanel = uipanel(otherPVArgs{:},'bordertype','none','sizechangedfcn',@obj.sizeChg);
%             obj.hPopup = most.gui.wire.popupMenu('parent',obj.hPanel,'callback', @obj.ctlCallback,'BorderColor', [0.6706 0.6784 0.7020],'BackgroundColor','w','cornerRadius',0);
            obj.hPopup = uicontrol('parent',obj.hPanel,'style','popupmenu','string',{' '}, 'callback', @obj.ctlCallback);
            obj.hEdit = uicontrol('parent',obj.hPanel,'style','edit', 'callback', @obj.ctlCallback,'horizontalalignment',ip.Results.horizontalalignment);
            if ~isempty(ip.Results.position)
                obj.position = ip.Results.position;
            end
    
            if ~isempty(ip.Results.WidthLimits)
                lms = [ip.Results.WidthLimits ip.Results.WidthLimits(1)];
                set(obj.hPanel, 'WidthLimits', lms(1:2));
            end
            if ~isempty(ip.Results.HeightLimits)
                lms = [ip.Results.HeightLimits ip.Results.HeightLimits(1)];
                set(obj.hPanel, 'HeightLimits', lms(1:2));
            end
            if ~isempty(ip.Results.SizeLimits)
                set(obj.hPanel, 'WidthLimits', ip.Results.SizeLimits(1)*ones(1,2));
                set(obj.hPanel, 'HeightLimits', ip.Results.SizeLimits(2)*ones(1,2));
            end
            if ~isempty(ip.Results.RelPosition)
                obj.RelPosition = ip.Results.RelPosition;
            end
            
            obj.hPanel.UserData = obj;
            obj.hPopup.UserData = obj;
            obj.hEdit.UserData = obj;
            
            obj.callback = ip.Results.callback;
            obj.bindings = ip.Results.bindings;
            obj.validationFunc = ip.Results.validationFunc;
            obj.tooltipString = ip.Results.tooltipstring;
            obj.showEdit = ip.Results.showEdit;
            if ~isempty(ip.Results.choices)
                obj.choices = ip.Results.choices;
            end
            
            obj.hDelLis = most.ErrorHandler.addCatchingListener(obj.hPanel,'ObjectBeingDestroyed',@(varargin)obj.delete);
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hDelLis);
            most.idioms.safeDeleteObj(obj.hBindingListeners);
            most.idioms.safeDeleteObj(obj.hRelPositionListener);
            most.idioms.safeDeleteObj(obj.hPopup);
            most.idioms.safeDeleteObj(obj.hEdit);
            most.idioms.safeDeleteObj(obj.hPanel);
        end
        
        function set.RelPosition(obj,v)
            if ~isempty(v)
                validateattributes(v,{'numeric'},{'vector','numel',4,'nonnan','finite'});
            end
            obj.RelPosition = v;
            obj.initRelPosition();
        end
        
        function initRelPosition(obj)
            most.idioms.safeDeleteObj(obj.hRelPositionListener);
            if ~isempty(obj.RelPosition)
                hParent = obj.hPanel.Parent;
                mc = metaclass(hParent);
                assert(ismember('SizeChanged',{mc.EventList.Name}),'Cannot set relative position');
                obj.hRelPositionListener = most.ErrorHandler.addCatchingListener(hParent,'SizeChanged',@updateRelPosition);
                updateRelPosition();
            end
            
            function updateRelPosition(~,~)
                ctlunits = obj.hPanel.Units;
                parentUnits = obj.hPanel.Parent.Units;
                
                obj.hPanel.Parent.Units = ctlunits;
                parentPos = obj.hPanel.Parent.Position;
                obj.hPanel.Parent.Units = parentUnits;
                
                parentTopLeft = [0 parentPos(4)];
                relPos = [obj.RelPosition(1)+parentTopLeft(1) parentTopLeft(2)-obj.RelPosition(2) obj.RelPosition(3:4)];
                obj.hPanel.Position = relPos;
            end
        end
        
        function set.bindings(obj,v)
            if ~isempty(obj.bindings)
                most.idioms.safeDeleteObj(obj.hBindingListeners);
                obj.hBindingListeners = {};
                obj.bindings = {};
            end
            
            if ~isempty(v)
                if ~iscell(v{1})
                    obj.bindings = {v};
                else
                    obj.bindings = v;
                end
                
                for i = 1:numel(obj.bindings)
                    binding = obj.bindings{i};
                    obj.hBindingListeners{end+1} = most.ErrorHandler.addCatchingListener(binding{1}, binding{2},'PostSet',@(varargin)obj.model2view(i));
                    obj.model2view(i);
                end
                
                obj.hBindingListeners = [obj.hBindingListeners{:}];
            end
        end
        
        function v = get.visible(obj)
            v = obj.hPanel.Visible;
        end
        
        function set.visible(obj,v)
            obj.hPanel.Visible = v;
        end
        
        function v = get.enable(obj)
            v = obj.hEdit.Enable;
        end
        
        function set.enable(obj,v)
            obj.hEdit.Enable = v;
            obj.hPopup.Enable = v;
        end
        
        function v = get.tooltipString(obj)
            v = obj.tooltipStringRaw;
        end
        
        function set.tooltipString(obj,v)
            obj.tooltipStringRaw = v;
            obj.updateTooltip();
        end
        
        function v = get.position(obj)
            obj.hPanel.Units = 'pixels';
            v = obj.hPanel.Position;
        end
        
        function set.position(obj,v)
            obj.hPanel.Units = 'pixels';
            obj.hPanel.Position = v;
        end
        
        function set.string(obj,v)
            % check validation
            if ~isempty(obj.validationFunc)
                [lvl,v,obj.currErrMsg] = obj.validationFunc(v,obj.oldString);
                if ~strcmp(v,obj.oldString)
                    switch lvl
                        case 0
                            obj.hEdit.BackgroundColor = [1 1 1];
                            
                        case 1
                            obj.hEdit.BackgroundColor = [1 1 .6];
                            
                        case 2
                            obj.hEdit.BackgroundColor = [1 .6 .6];
                    end
                end
                obj.updateTooltip();
            end
            
            obj.hEdit.String = v;
            obj.oldString = v;
            
            [tf,i] = ismember(v,obj.choices);
            if tf
                obj.hPopup.Value = i;
            end
        end
        
        function v = get.string(obj)
            v = obj.hEdit.String;
        end
        
        function set.selectionIdx(~,~)
            error('Cannot set by index. Use string instead.');
        end
        
        function v = get.selectionIdx(obj)
            [tf,v] = ismember(obj.string,obj.choices);
            if ~tf
                v = nan;
            end
        end
        
        function set.choices(obj,v)
            if isempty(v)
                obj.hPopup.String = {''};
            else
                obj.hPopup.String = v;
            end
%             obj.hPopup.choices = v;
            
            chcs = obj.choices;
            [tf,i] = ismember(obj.string,chcs);
            if tf
                obj.hPopup.Value = i;
            elseif obj.hPopup.Value > numel(chcs)
                obj.hPopup.Value = 1;
            end
        end
        
        function v = get.choices(obj)
            v = obj.hPopup.String;
            
            if ~iscell(v)
                v = cellstr(v);
            end
            
            if numel(v) == 1 && isempty(v{1})
                v = {};
            end
%             v = obj.hPopup.choices;
        end
        
        function set.showEdit(obj,v)
            if v
                obj.hEdit.Visible = 'on';
            else
                obj.hEdit.Visible = 'off';
            end
        end
        
        function v = get.showEdit(obj)
            v = strcmp(obj.hEdit.Visible,'on');
        end
    end
    
    methods (Hidden)
        function sizeChg(obj,varargin)
            if most.idioms.isValidObj(obj.hPopup)
                obj.hPanel.Units = 'pixels';
                obj.hPopup.Units = 'pixels';
                obj.hEdit.Units = 'pixels';
                
                v = obj.hPanel.Position;
                obj.hPopup.Position = [1 1 v(3) 22];
                obj.hEdit.Position = [1 1 max(1,v(3)-16) v(4)];
%                 obj.hPopup.Position = [1 .5 v(3) 22];
%                 obj.hEdit.Position = [1 1 max(1,v(3)-15) v(4)];
            end
        end
        
        function ctlCallback(obj,src,~)
            % propegate change between edit and popup
            if src == obj.hPopup
                nwStr = obj.choices{src.Value};
            else
                nwStr = obj.string;
            end
            
            obj.string = nwStr;
            
            % evaluate bindings
            if ~isempty(obj.bindings)
                for i = 1:numel(obj.bindings)
                    obj.view2model(i);
                end
            end
            
            % fire user defined callback
            if ~isempty(obj.callback)
                obj.callback(obj);
            end
        end
        
        function view2model(obj,bindingIdx)
            if nargin < 2 || isempty(bindingIdx)
                for i = 1:numel(obj.bindings)
                    obj.view2model(i);
                end
            else
                binding = obj.bindings{bindingIdx};

                if strcmpi(binding{3}, 'string')
                    binding{1}.(binding{2}) = obj.string;
                end
            end
        end
        
        function model2view(obj,bindingIdx)
            if nargin < 2 || isempty(bindingIdx)
                for i = 1:numel(obj.bindings)
                    obj.model2view(i);
                end
            else
                binding = obj.bindings{bindingIdx};
                
                if strcmpi(binding{3}, 'callback')
                    feval(binding{4},obj.hCtl);
                elseif strcmpi(binding{3}, 'string')
                    obj.forceSet = true;
                    try
                        obj.string = binding{1}.(binding{2});
                        obj.forceSet = false;
                    catch ME
                        obj.forceSet = false;
                        ME.rethrow();
                    end
                elseif strcmpi(binding{3}, 'choices')
                    obj.choices = binding{1}.(binding{2});
                end
            end
        end
        
        function updateTooltip(obj)
            v = obj.tooltipStringRaw;
            if ~isempty(obj.currErrMsg)
                if isempty(v)
                    v = obj.currErrMsg;
                else
                    v = sprintf('%s\n%s',v,obj.currErrMsg);
                end
            end
            
            obj.hEdit.TooltipString = v;
            obj.hPopup.TooltipString = v;
        end
        
        function set(obj,prop,val)
            set(obj.hPanel,prop,val);
        end
        
        function v = get(obj,prop)
            v = get(obj.hPanel,prop);
        end
        
        function hL = addlistener(obj,varargin)
            hL = most.ErrorHandler.addCatchingListener(obj.hPanel,varargin{:});
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
