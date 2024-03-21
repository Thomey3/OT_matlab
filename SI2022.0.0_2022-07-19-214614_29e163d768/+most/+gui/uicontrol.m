classdef uicontrol < handle
    %UICONTROL Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        hCtl;
        
        % pass through to hCtl
        Value;
        pmValue;
        pmComment;
        String;
        Visible;
        Enable;
        Style;
        RelPosition;
        layoutModeEnable = false;
        UserData;
        Data;
        TooltipString;
    end
    
    properties (Hidden)
        String_ = '';
        userdata;
        callback;
        bindings = {};
        hLiveListener;
        hBindingListeners = {};
        hRelPositionListener;
        ctlStyle;
        hDelLis;
        
        HeightLimits;
        WidthLimits;
        
        tfMap = containers.Map({true false}, {'on' 'off'});
        
        hUiControlLayout
        hLayoutModeChangedListener
        layoutModeBuffer
        callStack
        
        enumMembers
    end
    
    methods
        function obj = uicontrol(varargin)
            ip = most.util.InputParser;
            ip.addOptional('Bindings', {});
            ip.addOptional('LiveUpdate',false);
            ip.addOptional('WidthLimits',[]);
            ip.addOptional('HeightLimits',[]);
            ip.addOptional('SizeLimits',[]);
            ip.addOptional('RelPosition',[]);
            ip.addOptional('Style',[]);
            ip.addOptional('String','');
            ip.addOptional('UserData',[]);
            ip.parse(varargin{:});
            [~,otherPVArgs] = most.util.filterPVArgs(varargin,{'Bindings' 'LiveUpdate' 'WidthLimits' 'HeightLimits' 'SizeLimits' 'RelPosition' 'Style' 'String'});
            
             if ~isempty(ip.Results.Style)
                 style = ip.Results.Style;
             else
                 style = [];
             end
            
            if strcmpi(style,'uitable') || strcmpi(style,'table')
                obj.hCtl = uitable(otherPVArgs{:});
                obj.ctlStyle = 'uitable';
            elseif strcmpi(style,'uipanel')
                obj.hCtl = uipanel('Units','pixel',otherPVArgs{:});
                obj.ctlStyle = 'uipanel';
            else
                styleArg = {};
                if ~isempty(style)
                    styleArg = {'Style',style};
                end
                obj.hCtl = uicontrol(otherPVArgs{:},styleArg{:});
                obj.ctlStyle = get(obj.hCtl,'style');
                obj.callback = get(obj.hCtl, 'callback');
                set(obj.hCtl, 'callback', @obj.ctlCallback);
            end
            
            obj.userdata = get(obj.hCtl, 'userdata');
            set(obj.hCtl, 'userdata', obj);
            
            if ~isempty(ip.Results.WidthLimits)
                lms = [ip.Results.WidthLimits ip.Results.WidthLimits(1)];
                set(obj.hCtl, 'WidthLimits', lms(1:2));
            end
            if ~isempty(ip.Results.HeightLimits)
                lms = [ip.Results.HeightLimits ip.Results.HeightLimits(1)];
                set(obj.hCtl, 'HeightLimits', lms(1:2));
            end
            if ~isempty(ip.Results.SizeLimits)
                set(obj.hCtl, 'WidthLimits', ip.Results.SizeLimits(1)*ones(1,2));
                set(obj.hCtl, 'HeightLimits', ip.Results.SizeLimits(2)*ones(1,2));
            end
            if ~isempty(ip.Results.RelPosition)
                obj.RelPosition = ip.Results.RelPosition;
            end
            if ~isempty(ip.Results.UserData)
                obj.UserData = ip.Results.UserData;
            end
            if ~isempty(ip.Results.String)
                obj.String = ip.Results.String;
            end
            
            obj.bindings = ip.Results.Bindings;
            
            if ip.Results.LiveUpdate
                switch obj.ctlStyle
                    case 'slider'
                        obj.hLiveListener = most.ErrorHandler.addCatchingListener(obj.hCtl,'Value','PostSet',@obj.ctlCallback);
                        
                    otherwise
                        most.idioms.warn('Live update not supported for control type ''%s''.', obj.ctlStyle);
                end
            end
            
            obj.hDelLis = most.ErrorHandler.addCatchingListener(obj.hCtl,'ObjectBeingDestroyed',@(varargin)obj.delete);
            
            obj.hUiControlLayout = most.gui.uicontrolLayout();
            obj.hLayoutModeChangedListener = most.ErrorHandler.addCatchingListener(obj.hUiControlLayout,'layoutModeChanged',@(varargin)obj.layoutModeChanged);
            obj.layoutModeChanged();
            obj.callStack = dbstack('-completenames');
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hDelLis);
            most.idioms.safeDeleteObj(obj.hLiveListener);
            most.idioms.safeDeleteObj(obj.hBindingListeners);
            most.idioms.safeDeleteObj(obj.hCtl);
            most.idioms.safeDeleteObj(obj.hRelPositionListener);
            most.idioms.safeDeleteObj(obj.hLayoutModeChangedListener);
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
                hParent = obj.hCtl.Parent;
                mc = metaclass(hParent);
                assert(ismember('SizeChanged',{mc.EventList.Name}),'Cannot set relative position');
                obj.hRelPositionListener = most.ErrorHandler.addCatchingListener(hParent,'SizeChanged',@updateRelPosition);
                updateRelPosition();
            end
            
            function updateRelPosition(src,evt)
                ctlunits = obj.hCtl.Units;
                parentUnits = obj.hCtl.Parent.Units;
                
                obj.hCtl.Parent.Units = ctlunits;
                parentPos = obj.hCtl.Parent.Position;
                obj.hCtl.Parent.Units = parentUnits;
                
                parentTopLeft = [0 parentPos(4)];
                relPos = [obj.RelPosition(1)+parentTopLeft(1) parentTopLeft(2)-obj.RelPosition(2) obj.RelPosition(3:4)];
                obj.hCtl.Position = relPos;
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
        
        function v = get.Value(obj)
            if isprop(obj.hCtl,'Value')
                v = obj.hCtl.Value;
            else
                v = [];
            end
        end
        
        function set.Value(obj,v)
            obj.hCtl.Value = v;
        end
        
        function v = get.Data(obj)
            if isprop(obj.hCtl,'Data')
                v = obj.hCtl.Data;
            else
                v = [];
            end
        end
        
        function set.Data(obj,v)
            if iscell(v)
                for idx = 1:numel(v)
                    if most.idioms.isValidObj(v{idx}) && isprop(v{idx},'name')
                        comment = '';
                        if isprop(v{idx},'userInfo') && ~isempty(v{idx}.userInfo)
                            comment = [' ' v{idx}.userInfo];
                        end

                        v{idx} = [v{idx}.name comment];
                    end
                end
            end

            obj.hCtl.Data = v;
        end
        
        function v = get.pmValue(obj)
            if strcmpi(obj.hCtl.Style,'popupmenu')
                v = obj.String_{obj.hCtl.Value};
            else
                v = NaN;
            end
        end
        
        function set.pmValue(obj,val)
            assert(strcmpi(obj.hCtl.Style,'popupmenu'),'Cannot set pmValue for a control of type %s',obj.hCtl.Style);
            
            if isa(val,'dabs.resources.InvalidResource')
                val = obj.addInvalidOption(true);
            else
                obj.addInvalidOption(false);
            end
            
            if isempty(val)
                val = '';
            elseif most.idioms.isValidObj(val) && isprop(val,'name')
                val = val.name;
            end
            
            if ischar(val) && any(strcmp(val,obj.String_))
                obj.hCtl.Value = find(strcmp(val,obj.String_),1);
            elseif ischar(val) && any(strcmp('',obj.String_))
                obj.hCtl.Value = find(strcmp('',obj.String_),1);
            else
                obj.hCtl.Value = val;
            end
        end
        
        function invalidString = addInvalidOption(obj,tf)
            invalidString = '<<Invalid>>';
            mask = strcmp(invalidString,obj.String);
        
            if tf
                if ~any(mask)
                    obj.String{end+1} = invalidString;
                end
            else
                if any(mask)
                    obj.String(mask) = [];
                end
            end
        end
        
        function set.pmComment(obj,v)
            assert(strcmpi(obj.hCtl.Style,'popupmenu') ...
                ,'Cannot set pmValue for a control of type %s',obj.hCtl.Style);
            
            if isempty(v)
                v = cell(size(obj.String_));
            else
                assert(numel(v)==numel(obj.String_));
            end
            
            string_ = obj.String_;
            for idx = 1:numel(obj.String_)
                if ~isempty(v{idx})
                    string_{idx} = [string_{idx} ' ' v{idx}];
                end
            end
            
            obj.hCtl.String = string_;
        end
        
        function v = get.String(obj)
            if strcmpi(obj.hCtl.Style,'popupmenu')
                v = obj.String_;
            else
                v = obj.hCtl.String;
            end
        end
        
        function set.String(obj,v)
            comment = {};
            
            if iscell(v)
                comment = cell(size(v));
                
                for idx = 1:numel(v)
                    if most.idioms.isValidObj(v{idx}) && isprop(v{idx},'name')
                        if isprop(v{idx},'userInfo')
                            comment{idx} = v{idx}.userInfo;
                        end
                        
                        v{idx} = v{idx}.name;
                    end
                end
            end
            
            obj.hCtl.String = v;
            obj.String_ = v;
            
            if strcmpi(obj.hCtl.Style,'popupmenu')
                obj.pmComment = comment;
            end
        end

        function v = get.TooltipString(obj)
            if isprop(obj.hCtl,'TooltipString')
                v = obj.hCtl.TooltipString;
            else
                v = [];
            end
        end

        % Was going to call sprintf on v before setting, so that escape
        % characters would be pre-escaped without an sprintf call - but it
        % makes it so that if you sprintf beforehand, the escape characters
        % get figured out (like backslash) and passed again through sprintf
        % which doesn't work
        function set.TooltipString(obj,v)
            if isprop(obj.hCtl,'TooltipString')
                obj.hCtl.TooltipString = v;
            else
                warning('No TooltipString present in this uicontrol');
            end
        end
        
        function v = get.Visible(obj)
            v = obj.hCtl.Visible;
        end
        
        function set.Visible(obj,v)
            if islogical(v)
                v = obj.tfMap(v);
            end
            
            obj.hCtl.Visible = v;
        end
        
        function v = get.Enable(obj)
            v = obj.hCtl.Enable;
        end
        
        function set.Enable(obj,v)
            if islogical(v)
                v = obj.tfMap(v);
            end
            
            obj.hCtl.Enable = v;
        end
        
        function set.HeightLimits(obj,v)
            set(obj.hCtl, 'HeightLimits', v);
        end
        
        function v = get.HeightLimits(obj)
            v = get(obj.hCtl, 'HeightLimits');
        end
        
        function set.WidthLimits(obj,v)
            set(obj.hCtl, 'WidthLimits', v);
        end
        
        function v = get.WidthLimits(obj)
            v = get(obj.hCtl, 'WidthLimits');
        end
        
        function set.Style(obj,v)
            obj.hCtl.Style = v;
        end
        
        function v = get.Style(obj)
            v = obj.hCtl.Style;
        end
        
        function set.layoutModeEnable(obj,val)
            validateattributes(val,{'numeric','logical'},{'scalar','binary'});
            
            if val ~= obj.layoutModeEnable
                obj.layoutModeEnable = logical(val);
                
                if obj.layoutModeEnable
                    obj.activateLayoutMode();
                else
                    obj.deactivateLayoutMode();
                end
            end
        end
    end
    
    methods (Hidden)
        function ctlCallback(obj,varargin)
            if ~isempty(obj.bindings)
                try
                    for i = 1:numel(obj.bindings)
                        obj.view2model(i);
                    end
                catch ME
                    obj.model2view(); % refresh view to overwrite invalid values in view
                    rethrow(ME);
                end
            end
            
            if ~isempty(obj.callback)
                obj.callback(varargin{:});
            end
        end
        
        function view2model(obj,bindingIdx)
            if nargin < 2 || isempty(bindingIdx)
                for i = 1:numel(obj.bindings)
                    obj.view2model(i);
                end
            else
                binding = obj.bindings{bindingIdx};

                switch obj.ctlStyle
                    case {'edit'}
                        vt = 'string';
                        propVal = get(obj.hCtl,'string');
                        propStr = propVal;
                    case {'slider' 'checkbox' 'togglebutton' 'radiobutton'}
                        vt = 'value';
                        propVal = get(obj.hCtl,'Value');
                    case 'listbox'
                        vt = 'string';
                        items = get(obj.hCtl,'String');
                        propVal = items(get(obj.hCtl,'Value')); %Encode as cell array of selected options
                        propStr = propVal;
                        if ~isempty(propVal)
                            propChoice = propVal{1}; %Encode as string of the one-and-only selected option
                        else
                            propChoice = '';
                        end
                        
                        if ~isempty(obj.enumMembers)
                            propEnum = obj.enumMembers(propVal);
                        end
                        
                    case 'popupmenu'
                        vt = 'string';
                        propVal = get(obj.hCtl,'Value');
                        propStr = get(obj.hCtl,'String');
                        propChoice = propStr{propVal}; %Encode as string of the one-and-only selected option
                        
                        if ~isempty(obj.enumMembers)
                            propEnum = obj.enumMembers(propVal);
                        end
                        
                    otherwise
                        assert(strcmpi(binding{3}, 'callback'), 'Binding control of type ''%s'' is not supported', obj.ctlStyle);
                end

                if strcmpi(binding{3}, 'value')
                    if isnumeric(propVal)
                        if numel(binding) > 4 && strcmpi(binding{5},'scaling')
                            scl = binding{6};
                        else
                            scl = 1;
                        end
                        
                        binding{1}.(binding{2}) = propVal/scl;
                    elseif strcmp(vt, 'string')
                        if numel(binding) > 4 && strcmpi(binding{5},'scaling')
                            scl = binding{6};
                        else
                            scl = 1;
                        end
                        
                        if (numel(binding) > 3) && ~isempty(binding{4})
                            cc = binding{4};
                            if cc(end) == 'f'
                                binding{1}.(binding{2}) = str2double_(propVal)/scl;
                            elseif strcmp(cc,'%h')
                                binding{1}.(binding{2}) = hex2num(propVal);
                            else
                                error('Unsupported conversion format');
                            end
                        else
                            binding{1}.(binding{2}) = str2double_(propVal)/scl;
                        end
                    end

                elseif strcmpi(binding{3}, 'string')
                    if strcmpi(vt, 'string')
                        binding{1}.(binding{2}) = propVal;
                    end
                elseif strcmpi(binding{3}, 'enum')
                    if exist('propEnum', 'var')
                        binding{1}.(binding{2}) = propEnum;
                    end
                elseif strcmpi(binding{3}, 'choice')
                    if exist('propChoice','var')
                        binding{1}.(binding{2}) = propChoice;
                    end
                elseif strcmpi(binding{3}, 'match')
                    if numel(binding) > 3
                        matchVal = binding{4};
                    else
                        matchVal = obj.hCtl.String;
                    end
                    binding{1}.(binding{2}) = matchVal;
                end
            end
            
            function v = str2double_(v)
                if isempty(v)
                    v = [];
                elseif ~isempty(regexpi(v,'^\s*[\[\]\-0-9\s\.;:]*\s*$'))
                    v = eval(v);
                else
                    v = str2double(v);
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
                    return;
                end
                
                switch obj.ctlStyle
                    case {'edit'}
                        if strcmpi(binding{3}, 'value')
                            if numel(binding) > 4 && strcmpi(binding{5},'scaling')
                                scl = binding{6};
                            else
                                scl = 1;
                            end
                            
                            propVal = binding{1}.(binding{2}) * scl;
                            if isempty(propVal)
                                s = '';
                            elseif (numel(binding) > 3) && ~isempty(binding{4})
                                s = sprintf(binding{4},propVal);
                            else
                                s = mat2str(propVal);
                            end
                            set(obj.hCtl, 'String', s);
                            
                        elseif strcmpi(binding{3}, 'String')
                            set(obj.hCtl, 'String', binding{1}.(binding{2}));
                            
                        else
                            error('Binding type ''%s'' unsupported for control of type ''%s''', binding{3}, obj.ctlStyle);
                        end
                        
                    case {'slider' 'checkbox'}
                        if strcmpi(binding{3}, 'value')
                            set(obj.hCtl, 'Value', binding{1}.(binding{2}));
                        else
                            error('Binding type ''%s'' unsupported for control of type ''%s''', binding{3}, obj.ctlStyle);
                        end
                        
                    case {'togglebutton' 'radiobutton'}
                        if strcmpi(binding{3}, 'value')
                            set(obj.hCtl, 'Value', binding{1}.(binding{2}));
                            
                        elseif strcmpi(binding{3}, 'String')
                            set(obj.hCtl, 'String', binding{1}.(binding{2}));
                        elseif strcmpi(binding{3}, 'match')
                            if numel(binding) > 3
                                matchVal = binding{4};
                            else
                                matchVal = obj.hCtl.String;
                            end
                            
                            if ischar(matchVal)
                                obj.hCtl.Value = strcmp(binding{1}.(binding{2}),matchVal);
                            else
                                obj.hCtl.Value = binding{1}.(binding{2}) == matchVal;
                            end
                        else
                            error('Binding type ''%s'' unsupported for control of type ''%s''', binding{3}, obj.ctlStyle);
                        end
                        
                    case {'popupmenu' 'listbox'}                        
                        if strcmpi(binding{3}, 'enum')
                            if isenum(binding{1}.(binding{2}))
                                [m,s] = enumeration(binding{1}.(binding{2}));
                                [~,v] = ismember(binding{1}.(binding{2}),m);
                                obj.enumMembers = m;
                                set(obj.hCtl, 'Value', v);
                                set(obj.hCtl, 'String', s);
                            end
                        elseif strcmpi(binding{3}, 'Choice')
                            [tf,v] = ismember(binding{1}.(binding{2}), get(obj.hCtl,'String'));
                            if tf
                                set(obj.hCtl, 'Value', v);
                            end
                            
                        elseif strcmpi(binding{3}, 'Choices')
                            v = binding{1}.(binding{2});
                            if ~iscell(v)
                                v = num2cell(v);
                            end
                            set(obj.hCtl, 'String', v);
                            
                        elseif strcmpi(binding{3}, 'Value')
                            set(obj.hCtl, 'Value', binding{1}.(binding{2}));
                            
                        elseif strcmpi(binding{3}, 'String')
                            set(obj.hCtl, 'String', binding{1}.(binding{2}));
                            
                        else
                            error('Binding type ''%s'' unsupported for control of type ''%s''', binding{3}, obj.ctlStyle);
                        end

                    case {'uitable'}
                        if strcmpi(binding{3}, 'Data')
                            % todo: parse other possible values
                            set(obj.hCtl, 'Data', binding{1}.(binding{2}));
                        else
                            error('Binding type ''%s'' unsupported for control of type ''%s''', binding{3}, obj.ctlStyle);
                        end
                        
                    otherwise
                        error('Binding control of type ''%s'' is not supported', obj.ctlStyle);
                end
            end
        end
        
        function set(obj,prop,val)
            if ismember(lower(prop), {'callback' 'userdata'})
                for i=1:length(obj)
                    obj(i).(lower(prop)) = val;
                end
            else
                set([obj.hCtl],prop,val);
            end
        end
        
        function v = get(obj,prop)
            if ismember(lower(prop), {'callback' 'userdata'})
                v = obj.(lower(prop));
            else
                v = get(obj.hCtl,prop);
            end
        end
        
        function hL = addlistener(obj,varargin)
            hL = most.ErrorHandler.addCatchingListener(obj.hCtl,varargin{:});
        end
    end
    
    % layout functions
    methods (Access = private,Hidden)
        function layoutModeChanged(obj)
            obj.layoutModeEnable = obj.hUiControlLayout.layoutModeEnable;
        end
        
        function activateLayoutMode(obj)
            assert(isempty(obj.layoutModeBuffer));
            obj.layoutModeBuffer = struct();
            
            obj.layoutModeBuffer.hCtl_ButtonDownFcn = obj.hCtl.ButtonDownFcn;
            obj.layoutModeBuffer.hCtl_Units = obj.hCtl.Units;
            if isprop(obj.hCtl,'Enable')
                obj.layoutModeBuffer.hCtl_Enable = obj.hCtl.Enable;
                if strcmpi(obj.hCtl.Enable,'on')
                    obj.hCtl.Enable = 'inactive';
                end
            end
            obj.hCtl.ButtonDownFcn = @(varargin)obj.hUiControlLayout.editUiControl(obj);
        end
        
        function deactivateLayoutMode(obj)
            assert(~isempty(obj.layoutModeBuffer));
            
            if isprop(obj.hCtl,'Enable')
                obj.hCtl.Enable = obj.layoutModeBuffer.hCtl_Enable;
            end
            obj.hCtl.ButtonDownFcn = obj.layoutModeBuffer.hCtl_ButtonDownFcn;
            obj.hCtl.Units = obj.layoutModeBuffer.hCtl_Units;
            
            obj.layoutModeBuffer = [];
        end
    end
    
    methods (Hidden) 
        function updateLayoutDefinition(obj)
            assert(obj.layoutModeEnable);
            
            tag = obj.hCtl.Tag;
            assert(~isempty(tag),'Tag for uicontrol is not set');
            
            if strcmp(obj.callStack(2).name, 'Gui.addUiControl')
                callerPath = obj.callStack(3).file;
            else
                callerPath = obj.callStack(2).file;
            end
            
            code = fileread(callerPath);
            
            classname = regexptranslate('escape',mfilename('class'));
            tag_escaped = regexptranslate('escape',tag);
            
            expression = [ classname '\((?:(?!\);).)*''(?i:tag)''\s*,\s*''' tag_escaped '''(?:(?!\);).)*\)\s*;' ];
            [startIdx,endIdx] = regexp(code,expression);
            
            if numel(startIdx) < 1
                classname = 'obj\.addUiControl';
                expression = [ classname '\((?:(?!\);).)*''(?i:tag)''\s*,\s*''' tag_escaped '''(?:(?!\);).)*\)\s*;' ];
                [startIdx,endIdx] = regexp(code,expression);
            end
            
            assert(numel(startIdx)>0,'Call for uielement %s was not found in file %s.',tag,callerPath);
            assert(numel(startIdx)<2,'Call for uielement %s was found multiple times in file %s.',tag,callerPath);
            
            [startPosIdx,endPosIdx] = regexp(code(startIdx:endIdx),'(?<=(?i:''Position''))\s*,\s*\[[\-0-9\.\s]*\]');            
            [startRelPosIdx,endRelPosIdx] = regexp(code(startIdx:endIdx),'(?<=(?i:''RelPosition''))\s*,\s*\[[\-0-9\.\s]*\]');            
            
            if numel(startPosIdx) == 1
                posIdx = [startIdx+startPosIdx-1,startIdx+endPosIdx-1];
                newPosition = obj.hCtl.Position;
            elseif numel(startRelPosIdx) == 1
                posIdx = [startIdx+startRelPosIdx-1,startIdx+endRelPosIdx-1];
                
                parentUnits_ = obj.hCtl.Parent.Units;
                obj.hCtl.Parent.Units = obj.hCtl.Units;
                parentPos = obj.hCtl.Parent.Position;
                ctlPos = obj.hCtl.Position;
                obj.hCtl.Parent.Units = parentUnits_;
                newPosition = [ctlPos(1) parentPos(4)-ctlPos(2) ctlPos(3:4)];
                obj.RelPosition = newPosition;
            else
                error('Position for uielement %s was not found in ui definition.',tag,code(startIdx:endIdx));
            end
            
            codeBefore = code(1:posIdx(1)-1);
            positionCode = code(posIdx(1):posIdx(2));
            codeAfter = code(posIdx(2)+1:end);
            
            newPositionCode = [', ' mat2str(newPosition) ];
            
            newCode = [codeBefore newPositionCode codeAfter];
            
            hFile = fopen(callerPath,'w');
            assert(hFile>=0,'Could not open file %s for writing',callerPath);
            fprintf(hFile,'%s',newCode);
            fclose(hFile);
            
            rehash();
            
            idxs = regexpi(codeBefore,'(\r\n|\r|\n)');
            linenumber = length(idxs)+1;
            matlab.desktop.editor.openAndGoToLine(callerPath,linenumber);
        end
        
        function convertToRelPosition(obj)
            tag = obj.hCtl.Tag;
            assert(~isempty(tag),'Tag for uicontrol is not set');
            
            if strcmp(obj.callStack(2).name, 'Gui.addUiControl')
                callerPath = obj.callStack(3).file;
            else
                callerPath = obj.callStack(2).file;
            end
            
            code = fileread(callerPath);
            
            classname = regexptranslate('escape',mfilename('class'));
            expression = [ classname '\((?:(?!\);).)*''(?i:tag)''\s*,\s*''' tag '''(?:(?!\);).)*\)\s*;' ];
            [startIdx,endIdx] = regexp(code,expression);
            
            if numel(startIdx) < 1
                classname = 'obj\.addUiControl';
                expression = [ classname '\((?:(?!\);).)*''(?i:tag)''\s*,\s*''' tag '''(?:(?!\);).)*\)\s*;' ];
                [startIdx,endIdx] = regexp(code,expression);
            end
            
            assert(numel(startIdx)>0,'Call for uielement %s was not found in file %s.',tag,callerPath);
            assert(numel(startIdx)<2,'Call for uielement %s was found multiple times in file %s.',tag,callerPath);
            
            [startPosIdx,endPosIdx] = regexp(code(startIdx:endIdx),'(?<=(?i:''Position''))\s*,\s*\[[\-0-9\.\s]*\]');            
            
            if numel(startPosIdx) == 1
                posIdx = [startIdx+startPosIdx-1,startIdx+endPosIdx-1];
                
                ctlunits = obj.hCtl.Units;
                parentUnits = obj.hCtl.Parent.Units;
                
                obj.hCtl.Parent.Units = ctlunits;
                parentPos = obj.hCtl.Parent.Position;
                obj.hCtl.Parent.Units = parentUnits;
                
                newPosition = obj.hCtl.Position;
                newPosition(2) = parentPos(4)-newPosition(2);
            else
                error('Position for uielement %s was not found in ui definition.',tag,code(startIdx:endIdx));
            end
            
            codeBefore = code(1:posIdx(1)-1);
            codeAfter = code(posIdx(2)+1:end);
            
            newPositionCode = [', ' mat2str(newPosition) ];
            
            newCode = [codeBefore newPositionCode codeAfter];
            
            hFile = fopen(callerPath,'w');
            assert(hFile>=0,'Could not open file %s for writing',callerPath);
            fprintf(hFile,'%s',newCode);
            fclose(hFile);
            
            rehash();
            
            idxs = regexpi(codeBefore,'(\r\n|\r|\n)');
            linenumber = length(idxs)+1;
            matlab.desktop.editor.openAndGoToLine(callerPath,linenumber);
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
