classdef  MotorControls < most.Gui    
    %% GUI PROPERTIES
    properties (SetAccess = protected,SetObservable,Hidden)
        hListeners = event.listener.empty(1,0);
        hAx;
        hPatchFastZLimits;
        hLineFocus;
        hLineFocusMarker;
        hTextFocus;
        hFastZControls = scanimage.guis.motorcontrols.FastZControls.empty();
        hLineLimits;
        hLineLimitsMarkerMin;
        hLineLimitsMarkerMax;
        hTextExceeded;
        
        hPmCoordinateSystem
        hCSDisplay
        
        setClearMinLimCriticalSection = false;
        setClearMaxLimCriticalSection = false;
    end
    
    properties (SetObservable)
        xyIncrement = 10;
        zIncrement = 10;
        fastZIncrement = 10;
    end
    
    %% LIFECYCLE
    methods
        function obj = MotorControls(hModel, hController)
            if nargin < 1
                hModel = [];
            end
            
            if nargin < 2
                hController = [];
            end
            
            obj = obj@most.Gui(hModel, hController, [360 300], 'pixels');
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hListeners);
        end
    end
    
    methods (Access = protected)
        function initGui(obj)
            obj.hFig.Name = 'MOTOR CONTROLS';
            obj.hFig.WindowScrollWheelFcn = @obj.scroll;
            obj.hFig.KeyPressFcn = @obj.keyPressed;
            obj.hFig.Resize = 'off';            
            
            
            figWidth = 0;
            
            hFlowMain = most.gui.uiflowcontainer('Parent', obj.hFig,'FlowDirection','LeftToRight');
                hFlowAx = most.gui.uiflowcontainer('Parent', hFlowMain,'FlowDirection','TopDown');
                    set(hFlowAx,'WidthLimits',[120,120]);
                    figWidth = figWidth + 120;
                hFlowMotor = most.gui.uiflowcontainer('Parent', hFlowMain,'FlowDirection','TopDown');
                    set(hFlowMotor,'WidthLimits',[155,155]);
                    figWidth = figWidth + 155;
                    
            makeAxis(hFlowAx);
            makeMotorsPanel(hFlowMotor);
            
            hFastZs = obj.hModel.hFastZ.hFastZs;
            for idx = 1:numel(hFastZs)
                hFastZ = hFastZs{idx};
                postfix = sprintf('_%d',idx);
                h = scanimage.guis.motorcontrols.FastZControls(obj,hFlowMain,hFastZ,postfix);
                figWidth = figWidth + h.panelWidth;
                obj.hFastZControls(end+1) = h;
            end
            
            % adjust figure width
            obj.hFig.Position(3) = figWidth;
            
            setupListeners();
            obj.changeCoordinateSystem();
            obj.update();
            obj.updateLims();
            obj.statusChanged();
            
            %%% Nested functions
            function setupListeners()
                obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hModel.hMotors,'samplePosition','PostSet',@obj.update);
                obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hModel.hCoordinateSystems.hCSFocus,'changed',@obj.update);
                obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hModel.hMotors,'hMotors','PostSet',@obj.statusChanged);
                obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hModel.hMotors,'motorErrorMsg','PostSet',@obj.statusChanged);
                obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hModel.hMotors,'isHomed','PostSet',@obj.statusChanged);
                obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hModel.hMotors,'simulatedAxes','PostSet',@obj.statusChanged);
                obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hModel.hMotors,'hPtMinZLimit','PostSet',@obj.updateLims);
                obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hModel.hMotors,'hPtMaxZLimit','PostSet',@obj.updateLims);
                obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hModel.hMotors,'maxZStep','PostSet',@obj.updateMaxZStep);
            end
            
            function makeAxis(hParent)                
                obj.hAx = most.idioms.axes('Parent',hParent,'XTick',[],'YDir','reverse','YGrid','on','ButtonDownFcn',@obj.dragAxes);
                obj.hAx.OuterPosition = [0.05 0 0.9 1];
                obj.hAx.XLim = [0 1];
                obj.hAx.XTick = [0 0.5 1];
                obj.hAx.XTickLabel = {'FastZ  ' '[um]' ''};
                title(obj.hAx,'Z-Focus','FontWeight','normal');
                box(obj.hAx,'on');
                
                %ylabel(obj.hAx,'Z Reference Space [um]');
                obj.hPatchFastZLimits = patch('Parent',obj.hAx,'Faces',[],'Vertices',[],'FaceColor',[0 0 0],'FaceAlpha',0.2,'LineStyle','none');
                obj.hLineFocus = line('Parent',obj.hAx,'XData',[],'YData',[],'LineStyle','-','Color',[1 0 0],'LineWidth',0.5,'ButtonDownFcn',@obj.dragFocus);
                obj.hLineFocusMarker = line('Parent',obj.hAx,'XData',[],'YData',[],'LineStyle','none','Marker','*','MarkerSize',8,'Color',[1 0 0],'LineWidth',1,'ButtonDownFcn',@obj.dragFocus);
                obj.hTextFocus = text('Parent',obj.hAx,'String','','Position',[0 0],'HorizontalAlignment','center','VerticalAlignment','top','VerticalAlignment','bottom','Interpreter','tex','PickableParts','none','HitTest','off');
                obj.hLineLimits = line('Parent',obj.hAx,'XData',[],'YData',[],'LineStyle','-','Color',most.constants.Colors.lightBlue,'LineWidth',1.5);
                obj.hLineLimitsMarkerMin = line('Parent',obj.hAx,'XData',[],'YData',[],'LineStyle','none','Marker','v','MarkerSize',5,'MarkerEdgeColor',most.constants.Colors.lightBlue,'MarkerFaceColor',most.constants.Colors.lightBlue);
                obj.hLineLimitsMarkerMax = line('Parent',obj.hAx,'XData',[],'YData',[],'LineStyle','none','Marker','^','MarkerSize',5,'MarkerEdgeColor',most.constants.Colors.lightBlue,'MarkerFaceColor',most.constants.Colors.lightBlue);
                obj.hTextExceeded = text('Parent',obj.hAx,'String',sprintf('Limits\nExceeded'),'HorizontalAlignment','center','VerticalAlignment','middle','Color',most.constants.Colors.red,'FontWeight','bold');
                
                if yyaxisAvailable()
                    yyaxis(obj.hAx,'right');
                    %ylabel(obj.hAx,'Z Sample [um]');
                    obj.hAx.YAxis(1).Color = [0 0 0];
                    obj.hAx.YAxis(2).Color = [0 0 0];
                    obj.hAx.YAxis(2).Direction = 'reverse';
                    obj.hAx.XTickLabel{3} = '   Sample';
                end
            end
                
            function makeMotorsPanel(hParent)
                hPanel = most.gui.uipanel('Title','Motors','Parent',hParent);
                
                hMotors = obj.hModel.hMotors;
                obj.addUiControl('Parent',hPanel,'String',getConfigSymbol(),'Style','text','Tag','txConfig','RelPosition', [117 41 20 20],'Enable','inactive','ButtonDownFcn',@(varargin)hMotors.showConfig,'FontSize',12,'FontWeight','bold');
                
                csOptions = {'Sample','Raw Motor'};
                obj.hPmCoordinateSystem = obj.addUiControl('Parent',hPanel,'String',csOptions,'style','popupmenu','Callback',@obj.changeCoordinateSystem,'Tag','pmCoordinateSystem','RelPosition', [15 42 90 20],'TooltipString','Select coordinate system for XYZ axes display');
                obj.addUiControl('Parent',hPanel,'String','Zero All','style','pushbutton','Tag','pbZeroAll','RelPosition', [85 149 60 20],'Enable','on','Callback',@(varargin)obj.zeroSample([1 2 3]),'TooltipString','Establish relative zero point for all axes');
                obj.addUiControl('Parent',hPanel,'String','Clear Zeros','style','pushbutton','Tag','pbClearZero','RelPosition', [14 149 70 20],'Enable','on','Callback',@(varargin)obj.clearZero(),'TooltipString','Reset relative zero point for all axes');
                obj.addUiControl('Parent',hPanel,'String','Query Position','Callback',@obj.queryPosition,'style','pushbutton','Tag','pbQueryPosition','RelPosition', [15 62 90 20],'Enable','on','TooltipString','Query motors for position');
                
                obj.addUiControl('Parent',hPanel,'String','X','style','text','Tag','lbXPos','HorizontalAlignment','right','RelPosition', [1 82 10 15],'FontWeight','bold');
                obj.addUiControl('Parent',hPanel,'String','etXPos','style','edit','Tag','etXPos','RelPosition',[15 83 90 20],'Enable','inactive','ButtonDownFcn',@(varargin)obj.changePosition(1));
                obj.addUiControl('Parent',hPanel,'String','Zero','style','pushbutton','Tag','pbZeroX','RelPosition', [106 83 40 20],'Enable','on','Callback',@(varargin)obj.zeroSample(1),'TooltipString','Establish relative zero point for X-axis');
                
                obj.addUiControl('Parent',hPanel,'String','Y','style','text','Tag','lbYPos','HorizontalAlignment','right','RelPosition', [1 104 10 15],'FontWeight','bold');
                obj.addUiControl('Parent',hPanel,'String','etYPos','style','edit','Tag','etYPos','RelPosition', [15 105 90 20],'Enable','inactive','ButtonDownFcn',@(varargin)obj.changePosition(2));
                obj.addUiControl('Parent',hPanel,'String','Zero','style','pushbutton','Tag','pbZeroY','RelPosition', [106 105 40 20],'Enable','on','Callback',@(varargin)obj.zeroSample(2),'TooltipString','Establish relative zero point for Y-axis');
                
                obj.addUiControl('Parent',hPanel,'String','Z','style','text','Tag','lbZPos','HorizontalAlignment','right','RelPosition', [1 127 10 15],'FontWeight','bold');
                obj.addUiControl('Parent',hPanel,'String','etZPos','style','edit','Tag','etZPos','RelPosition', [15 127 90 20],'Enable','inactive','ButtonDownFcn',@(varargin)obj.changePosition(3));
                obj.addUiControl('Parent',hPanel,'String','Zero','style','pushbutton','Tag','pbZeroZ','RelPosition', [106 127 40 20],'Enable','on','Callback',@(varargin)obj.zeroSample(3),'TooltipString','Establish relative zero point for Z-axis');
                
                obj.addUiControl('Parent',hPanel,'Tag','XYPanel','RelPosition', [2 250 95 95],'Style','uipanel','BorderType','none');
                annotation(obj.XYPanel.hCtl,'arrow',[0.05 0.95],[0.95 0.95]);
                annotation(obj.XYPanel.hCtl,'arrow',[0.05 0.05],[0.95 0.05]);
                obj.addUiControl('Parent',hPanel,'String','X','style','text','Tag','lbX','RelPosition', [92 168 10 15]);
                obj.addUiControl('Parent',hPanel,'String','Y','style','text','Tag','lbY','RelPosition', [1 261 10 15]);
                  
                obj.addUiControl('Parent',hPanel,'Tag','Ydec','String',most.constants.Unicode.black_up_pointing_triangle,'Style','pushbutton','Callback',@(varargin)obj.incrementAxis(2,-1),'RelPosition', [41 195 30 30],'TooltipString',['Decrement Y axis' most.constants.Unicode.new_line 'Shortcut: arrow up key'    most.constants.Unicode.new_line 'Holding down the Ctrl key performs a 10x smaller step']);
                obj.addUiControl('Parent',hPanel,'Tag','Yinc','String',most.constants.Unicode.black_down_pointing_triangle,'Style','pushbutton','Callback',@(varargin)obj.incrementAxis(2,+1),'RelPosition', [41 255 30 30],'TooltipString',['Increment Y axis' most.constants.Unicode.new_line 'Shortcut: arrow down key'  most.constants.Unicode.new_line 'Holding down the Ctrl key performs a 10x smaller step']);
                obj.addUiControl('Parent',hPanel,'Tag','Xdec','String',most.constants.Unicode.black_left_pointing_triangle,'Style','pushbutton','Callback',@(varargin)obj.incrementAxis(1,-1),'RelPosition', [11 225 30 30],'TooltipString',['Decrement X axis' most.constants.Unicode.new_line 'Shortcut: arrow left key'  most.constants.Unicode.new_line 'Holding down the Ctrl key performs a 10x smaller step']);
                obj.addUiControl('Parent',hPanel,'Tag','Xinc','String',most.constants.Unicode.black_right_pointing_triangle,'Style','pushbutton','Callback',@(varargin)obj.incrementAxis(1,+1),'RelPosition', [71 225 30 30],'TooltipString',['Increment X axis' most.constants.Unicode.new_line 'Shortcut: arrow right key' most.constants.Unicode.new_line 'Holding down the Ctrl key performs a 10x smaller step']);
                obj.addUiControl('Parent',hPanel,'Tag','XYstep','Style','edit','Bindings',{obj 'xyIncrement' 'value' '%.1f'},'RelPosition', [41 225 30 30],'TooltipString','Step size for XY-axis');
                
                obj.addUiControl('Parent',hPanel,'Tag','ZPanel','RelPosition', [134 241 20 80],'Style','uipanel','BorderType','none');
                annotation(obj.ZPanel.hCtl,'arrow',[0.5 0.5],[0.95 0.05]);
                obj.addUiControl('Parent',hPanel,'String','Z','style','text','Tag','lbZ','RelPosition', [138 256 10 15]);
                
                obj.addUiControl('Parent',hPanel,'Tag','pbMinLim','String','Set Lim','Style','pushbutton','Callback',@(varargin)obj.setClearMinLim,'RelPosition', [107 165 30 15],'TooltipString',sprintf('Set / clear the min motor Z-limit.\nNote: Moving the stage with an external joystick\ncan exceed the ScanImage motor limits.'));
                obj.addUiControl('Parent',hPanel,'Tag','Zdec','String',most.constants.Unicode.black_up_pointing_triangle,'Style','pushbutton','Callback',@(varargin)obj.incrementAxis(3,-1),'RelPosition', [107 195 30 30],'TooltipString',['Decrement Z axis' most.constants.Unicode.new_line 'Shortcut: PgUp key' most.constants.Unicode.new_line 'Holding down the Ctrl key performs a 10x smaller step']);
                obj.addUiControl('Parent',hPanel,'Tag','Zstep','Style','edit','Bindings',{obj 'zIncrement' 'value' '%.1f'},'RelPosition', [107 225 30 30],'TooltipString','Step size for Z-axis');
                obj.addUiControl('Parent',hPanel,'Tag','Zinc','String',most.constants.Unicode.black_down_pointing_triangle,'Style','pushbutton','Callback',@(varargin)obj.incrementAxis(3,+1),'RelPosition', [107 255 30 30],'TooltipString',['Increment Z axis' most.constants.Unicode.new_line 'Shortcut: PgDn key' most.constants.Unicode.new_line 'Holding down the Ctrl key performs a 10x smaller step']);
                obj.addUiControl('Parent',hPanel,'Tag','pbMaxLim','String','Set Lim','Style','pushbutton','Callback',@(varargin)obj.setClearMaxLim,'RelPosition', [107 270 30 15],'TooltipString',sprintf('Set / clear the max motor Z-limit.\nNote: Moving the stage with an external joystick\ncan exceed the ScanImage motor limits.'));
                
                obj.addUiControl('Parent',hPanel,'String','Max Z-Step','style','text','Tag','txMaxZStep','RelPosition', [5 275 60 15]);
                obj.addUiControl('Parent',hPanel,'Style','edit','Tag','etMaxZStep','RelPosition', [65 274 41 15],'Bindings',{obj.hModel.hMotors 'maxZStep' 'value' '%.0f'},'TooltipString','Set maximally allowed step size for Z stage');
                obj.addUiControl('Parent',hPanel,'String','Reinit Motors','style','pushbutton','Tag','pbReinit','RelPosition', [5 290 70 15],'Enable','on','Callback',@(varargin)obj.reinitMotors(),'TooltipString','Reinit communication with motor controller');
                obj.addUiControl('Parent',hPanel,'String','Align','style','pushbutton','Tag','pbAlignMotors','RelPosition', [75 290 35 15],'Enable','on','Callback',@(varargin)obj.alignMotors(),'TooltipString','Align motor coordinate system to scan coordinate system');
                obj.addUiControl('Parent',hPanel,'String','Tilt','style','pushbutton','Tag','pbTiltMotors','RelPosition', [110 290 25 15],'Enable','on','Callback',@(varargin)obj.tiltMotors(),'TooltipString','Specify objective rotation (azimuth/elevation)');
                
                obj.addUiControl('Parent',hPanel,'String','','style','edit','Tag','etPlaceholder','RelPosition', [15 105 90 20], 'Visible','off');
            end
            
            function symbol = getConfigSymbol()
                if verLessThan('matlab','9.3')
                    % the gear symbol only works in Matlab R2017b or later
                    symbol = most.constants.Unicode.medium_black_circle;
                else
                    symbol = most.constants.Unicode.gear;
                end
            end
        end
    end
    
    methods
        function statusChanged(obj,varargin)
            defaultColor   = most.constants.Colors.white;
            simulatedColor = most.constants.Colors.darkGray;
            errorColor     = most.constants.Colors.lightRed;
            notHomedColor  = most.constants.Colors.yellow;
            
            if ~obj.isGuiLoaded
                return;
            end
            
            hCtls_all = [obj.etXPos.hCtl obj.etYPos.hCtl obj.etZPos.hCtl];
            
            set(hCtls_all,'BackgroundColor',defaultColor);
            set(hCtls_all,'TooltipString','');
            
            sim = obj.hModel.hMotors.simulatedAxes;
            
            set(hCtls_all(sim),'BackgroundColor',simulatedColor);
            set(hCtls_all(sim),'TooltipString','Simulated Axis');
        
            msgs = obj.hModel.hMotors.motorErrorMsg;
            anyErr = 0;
            for motorIdx = 1:numel(msgs)                
                hMotor = obj.hModel.hMotors.hMotors{motorIdx};
                if isa(hMotor,'dabs.simulated.Motor')
                    continue
                end
                
                msg = msgs{motorIdx};
                dimMap = obj.hModel.hMotors.motorDimMap{motorIdx};
                dimMap(isnan(dimMap)) = [];
                hCtls = hCtls_all(dimMap);
                if ~isempty(msg)
                    tip = sprintf('Motor error for %s:\n%s',class(hMotor),msg);
                    set(hCtls,'BackgroundColor',errorColor);
                    set(hCtls,'TooltipString',tip);
                    anyErr = 1;
                else
                    if ~hMotor.isHomed
                        set(hCtls,'BackgroundColor',notHomedColor);
                        set(hCtls,'TooltipString','Not homed');
                    end
                    
                end
            end
            
            if anyErr
                obj.pbReinit.hCtl.BackgroundColor = 'y';
            else
                obj.pbReinit.hCtl.BackgroundColor = .94*ones(1,3);
            end
        end
        
        function fastZGoto(obj,z)
            obj.hModel.hFastZ.positionTarget = z;
        end
        
        function calibrateFastZ(obj)
            obj.hModel.hWaveformManager.calibrateScanner('Z')
        end
        
        function reinitMotors(obj)
            try
                obj.hModel.hMotors.reinitMotors();
                obj.statusChanged();
                
                if obj.hModel.hMotors.errorTf
                    warndlg('One or more motors failed to initialize.', 'ScanImage');
                end
            catch ME
                msg = ['Motor reinitialization failed. Error: ' ME.message];
                most.ErrorHandler.logAndReportError(ME,msg);
                warndlg(msg,'Motor Control');
            end
        end
        
        function alignMotors(obj)
            obj.hController.showGUI('motorsAlignmentControls');
            obj.hController.raiseGUI('motorsAlignmentControls');
        end
        
        function tiltMotors(obj)
            az = obj.hModel.hMotors.azimuth;
            el = obj.hModel.hMotors.elevation;
            
            prompt = {'Azimuth [degree]','Elevation [degree]'};
            dlgtitle = 'Configure Motor Tilt';
            dims = [1 35];
            definput = {sprintf('%.2f',az),sprintf('%.2f',el)};
            answer = inputdlg(prompt,dlgtitle,dims,definput);
            
            if isempty(answer)
                return % user cancelled
            end
            
            answer = str2double(answer);
            validateattributes(answer,{'numeric'},{'nonnan','finite'});
            
            obj.hModel.hMotors.azimuth = answer(1);
            obj.hModel.hMotors.elevation = answer(2);
        end
        
        function zeroSample(obj,axes)
            newPt = [NaN NaN NaN];
            newPt(axes) = 0;            
            obj.hModel.hMotors.setRelativeZero(newPt);
        end
        
        function clearZero(obj)
            obj.hModel.hMotors.clearRelativeZero();
        end
        
        function queryPosition(obj,varargin)
            obj.queryMotors();
            obj.queryFastZs();
        end
        
        function queryMotors(obj)
            obj.hModel.hMotors.queryPosition();
        end
        
        function queryFastZs(obj)
            for idx = 1:numel(obj.hFastZControls)
                obj.hFastZControls(idx).readFeedback();
            end
        end
        
        function dragAxes(obj,varargin)
            % no op
        end
        
        function dragFocus(obj,varargin)
            obj.hFig.WindowButtonMotionFcn = @move;
            obj.hFig.WindowButtonUpFcn     = @stop;
            
            function move(varargin)
                try
                    if yyaxisAvailable()
                        yyaxis(obj.hAx,'left');
                    end                    
                    
                    pt = obj.hAx.CurrentPoint(1,1:2);
                    hFastZ = obj.hModel.hScan2D.hFastZs;
                    
                    if ~isempty(hFastZ)
                        hFastZ{1}.pointPosition(round(pt(2)));
                    end
                catch
                    stop();
                end
            end
            
            function stop(varargin)
                obj.hFig.WindowButtonMotionFcn = [];
                obj.hFig.WindowButtonUpFcn = [];
            end
        end
        
        function scroll(obj,src,evt)
            if most.gui.isMouseInAxes(obj.hAx)
                try
                    roundDigits = 0;
                    currentFastZControls = obj.hFastZControls([obj.hFastZControls.isCurrent]);
                    if ~isempty(currentFastZControls)
                        currentFastZControls(1).incrementFastZ(-evt.VerticalScrollCount,roundDigits);
                    end
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
            end
        end
        
        function keyPressed(obj,src,evt)
            switch evt.Key
                case 'rightarrow'
                    obj.incrementAxis(1,+1);
                case 'leftarrow'
                    obj.incrementAxis(1,-1);
                case 'uparrow'
                    obj.incrementAxis(2,-1);
                case 'downarrow'
                    obj.incrementAxis(2,+1);
                case 'pagedown'
                    obj.incrementAxis(3,+1);
                case 'pageup'
                    obj.incrementAxis(3,-1);
            end
        end
        
        function setClearMinLim(obj)
            if obj.setClearMinLimCriticalSection
                return
            end
            
            obj.setClearMinLimCriticalSection = true;
            
            try
                if isempty(obj.hModel.hMotors.hPtMinZLimit)
                    obj.assertNoRotation();
                    obj.hModel.hMotors.setMinZLimit();
                    obj.showLimWarningDialog();
                else
                    confirmed = obj.confirmClearingMotorLimit();
                    if confirmed
                        obj.hModel.hMotors.clearMinZLimit();
                    end
                end
            catch ME
                obj.setClearMinLimCriticalSection = false;
                ME.rethrow();
            end
            
            obj.setClearMinLimCriticalSection = false;
        end
        
        function setClearMaxLim(obj)
            if obj.setClearMaxLimCriticalSection
                return
            end
            
            obj.setClearMaxLimCriticalSection = true;
            
            try
                if isempty(obj.hModel.hMotors.hPtMaxZLimit)
                    obj.assertNoRotation();
                    obj.hModel.hMotors.setMaxZLimit();
                    obj.showLimWarningDialog();
                else
                    confirmed = obj.confirmClearingMotorLimit();
                    if confirmed
                        obj.hModel.hMotors.clearMaxZLimit();
                    end
                end
            catch ME
                obj.setClearMaxLimCriticalSection = false;
                ME.rethrow();
            end
            
            obj.setClearMaxLimCriticalSection = false;
        end
        
        function confirmed = confirmClearingMotorLimit(obj)
            button = questdlg('Do you want to clear the motor limit?','Confirmation','Yes','No','No');
            confirmed = strcmpi(button,'Yes');
        end
        
        function showLimWarningDialog(obj)
            msg = sprintf('Moving the stage with an external joystick\ncan exceed the ScanImage motor limits.');
            h = msgbox(msg,'Information','help','modal');
            uiwait(h);
        end
        
        function assertNoRotation(obj)
            if obj.hModel.hMotors.getRotationSet()
                msg = sprintf('Cannot set limit when stage coordinate system is rotated.');
                h = msgbox(msg,'Error','error','modal');
                uiwait(h);
                most.ErrorHandler.error('Cannot set limit when stage coordinate system is rotated.');
            end
        end
        
        function incrementAxis(obj,axis,direction,roundDigits)            
            if nargin < 4
                roundDigits = [];
            end
            
            if obj.hModel.hMotors.moveInProgress
                return
            end
            
            hPos = obj.hModel.hMotors.getPosition(obj.hCSDisplay);
            pos = hPos.points;
            
            speedFactor = obj.getSpeedFactor();
            
            if axis <= 2
                increment = speedFactor * direction * obj.xyIncrement;
                pos(axis) = roundTo(pos(axis) + increment,roundDigits);
            elseif axis == 3
                increment = speedFactor * direction * obj.zIncrement;
                pos(axis) = roundTo(pos(axis) + increment,roundDigits);
            else
                assert(false);
            end
            
            hCtls = [obj.Xdec.hCtl obj.Xinc.hCtl obj.Ydec.hCtl obj.Yinc.hCtl obj.Zdec.hCtl obj.Zinc.hCtl];
            hCtl = hCtls(2*axis - double(sign(direction)<0));
            
            oldColor = hCtl.BackgroundColor;            
            hCtl.BackgroundColor = [0.65 1 0.65];
            
            try
                hPos = scanimage.mroi.coordinates.Points(obj.hCSDisplay,pos);
                obj.hModel.hMotors.move(hPos);
            catch ME
                hCtl.BackgroundColor = oldColor;
                rethrow(ME);
            end
            hCtl.BackgroundColor = oldColor;
        end
        
        function speedFactor = getSpeedFactor(obj)
            if ismember('control',obj.hFig.CurrentModifier)
                speedFactor = 0.1;
            else
                speedFactor = 1;
            end
        end
        
        function changePosition(obj,dim)
            dimNames = 'XYZ';
            dimName = dimNames(dim);
            
            hCtl = obj.(['et' dimName 'Pos']);
            answer = inputdlg(['New ' dimName ' position:'],'Move',[1 35],{hCtl.String});
            if isempty(answer)
                return
            end
            
            answer = answer{1};
            v = str2double(answer);
            
            valid = isnumeric(v) && isscalar(v) && ~isnan(v) && isfinite(v) && isreal(v);
            if ~valid
                msg = sprintf('Invalid %s position: ''%s''',dimName,answer);
                errordlg(msg);
                most.ErrorHandler.error(msg);
            end
            
            try
                obj.hModel.hMotors.queryPosition();
                hPt = obj.hModel.hMotors.getPosition(obj.hCSDisplay);
                pt = hPt.points;
                pt(dim) = v;                
                hPt = scanimage.mroi.coordinates.Points(obj.hCSDisplay,pt);
                obj.hModel.hMotors.move(hPt);
                obj.update();
            catch ME
                obj.update();
                rethrow(ME);
            end
        end
        
        function update(obj,varargin)
            hPt = scanimage.mroi.coordinates.Points(obj.hModel.hCoordinateSystems.hCSReference,[0,0,0]);
            hPt = hPt.transform(obj.hCSDisplay);
            pt  = hPt.points;
            
            currentObj = obj.hFig.CurrentObject;
            
            if ~isequal(currentObj,obj.etXPos)
                obj.etXPos.String = sprintf('%.2f',pt(1));
            end
            
            if ~isequal(currentObj,obj.etYPos)
                obj.etYPos.String = sprintf('%.2f',pt(2));
            end
            
            if ~isequal(currentObj,obj.etZPos)
                obj.etZPos.String = sprintf('%.2f',pt(3));
            end
            
            obj.redraw();
        end
        
        function updateLims(obj,varargin)
            if isempty(obj.hModel.hMotors.hPtMinZLimit)
                obj.pbMinLim.String = 'SetLim';
                obj.pbMinLim.hCtl.BackgroundColor = most.constants.Colors.lightGray;
            else
                obj.pbMinLim.String = 'ClrLim';
                obj.pbMinLim.hCtl.BackgroundColor = most.constants.Colors.lightBlue;
            end
            
            if isempty(obj.hModel.hMotors.hPtMaxZLimit)
                obj.pbMaxLim.String = 'SetLim';
                obj.pbMaxLim.hCtl.BackgroundColor = most.constants.Colors.lightGray;
            else
                obj.pbMaxLim.String = 'ClrLim';
                obj.pbMaxLim.hCtl.BackgroundColor = most.constants.Colors.lightBlue;
            end
            
            obj.pbMinLim.hCtl.FontSize = 6;
            obj.pbMaxLim.hCtl.FontSize = 6;
            
            obj.redraw();
        end
        
        function updateMaxZStep(obj,varargin)
            if isinf(obj.hModel.hMotors.maxZStep)
                color = most.constants.Colors.lightGray;
            else
                color = most.constants.Colors.lightBlue;
            end
            
            obj.etMaxZStep.hCtl.BackgroundColor = color;
        end
        
        function redraw(obj,varargin)
            updateFocus();
            YLim_ref = updateLeftAxis();            
            drawLimits(YLim_ref);
            updateRightAxis(YLim_ref);
            
            %%% Nested functions
            function updateFocus()
                hPtFocus = scanimage.mroi.coordinates.Points(obj.hModel.hCoordinateSystems.hCSFocus,[0,0,0]);
                hPtFocusRef = hPtFocus.transform(obj.hModel.hCoordinateSystems.hCSReference);
                
                focusRefZ = hPtFocusRef.points(1,3);
                obj.hLineFocusMarker.XData = 0.5;
                obj.hLineFocusMarker.YData = focusRefZ;
                
                obj.hLineFocus.XData = [0 1];
                obj.hLineFocus.YData = [focusRefZ focusRefZ];
                
                hPtFocusSampleRelative = hPtFocus.transform(obj.hModel.hCoordinateSystems.hCSSampleRelative);
                focusSampleZ = hPtFocusSampleRelative.points(1,3);
                obj.hTextFocus.Position = [0.5 focusRefZ];
                obj.hTextFocus.String = sprintf('\\fontsize{8.5}%.2f\\fontsize{2}\n',focusSampleZ);
            end
            
            function YLim_ref = updateLeftAxis()
                hFastZs = obj.hModel.hScan2D.hFastZs;
                travelRange = [];
                
                if ~isempty(hFastZs)
                    travelRange = cellfun(@(hFZs)hFZs.travelRange,hFastZs,'UniformOutput',false);
                    travelRange = horzcat(travelRange{:});
                    travelRange = [min(travelRange) max(travelRange)];
                    extendRange = 1.2;
                    midPoint = sum(travelRange)/2;
                    range = diff(travelRange) * extendRange;
                    
                    YLim_ref = midPoint + range/2 * [-1 1];
                end
                
                if isempty(travelRange) || diff(travelRange)<=0
                    travelRange = [];
                    YLim_ref = [-100 100];
                end
                
                if isprop(obj.hAx,'YAxis')
                    obj.hAx.YAxis(1).Limits = YLim_ref;
                else
                    % Matlab 2015a workaround
                    obj.hAx.YLim = YLim_ref;
                end
                
                if isempty(travelRange)
                    V = [];
                    F = [];
                else
                    V = [0 YLim_ref(1);
                        0 travelRange(1);
                        1 travelRange(1);
                        1 YLim_ref(1);
                        ...
                        0 YLim_ref(2);
                        0 travelRange(2);
                        1 travelRange(2);
                        1 YLim_ref(2)];
                    
                    F = [1 2 3 4;
                        5 6 7 8];
                end
                
                obj.hPatchFastZLimits.Vertices = V;
                obj.hPatchFastZLimits.Faces = F;
            end
            
            function drawLimits(YLim_ref)
                exceeded_um = [];
                lineLimitsX = [];
                lineLimitsY = [];
                
                if isempty(obj.hModel.hMotors.hPtMinZLimit)
                    lineLimitsMarkerMinX = [];
                    lineLimitsMarkerMinY = [];
                else
                    hPt = obj.hModel.hMotors.hPtMinZLimit;
                    hPt = hPt.transform(obj.hModel.hCoordinateSystems.hCSReference);
                    minZ_ref = hPt.points(3);
                    lineLimitsX = [lineLimitsX        0        1 NaN];
                    lineLimitsY = [lineLimitsY minZ_ref minZ_ref NaN];
                    lineLimitsMarkerMinX = [    0.25     0.75];
                    lineLimitsMarkerMinY = [minZ_ref minZ_ref];
                    
                    if minZ_ref > 0
                        exceeded_um = minZ_ref;
                    end
                end
                
                if isempty(obj.hModel.hMotors.hPtMaxZLimit)
                    lineLimitsMarkerMaxX = [];
                    lineLimitsMarkerMaxY = [];
                else
                    hPt = obj.hModel.hMotors.hPtMaxZLimit;
                    hPt = hPt.transform(obj.hModel.hCoordinateSystems.hCSReference);
                    maxZ_ref = hPt.points(3);
                    lineLimitsX = [lineLimitsX        0       1 NaN];
                    lineLimitsY = [lineLimitsY maxZ_ref maxZ_ref NaN];
                    lineLimitsMarkerMaxX = [    0.25     0.75];
                    lineLimitsMarkerMaxY = [maxZ_ref maxZ_ref];
                    
                    if maxZ_ref < 0
                        exceeded_um = maxZ_ref;
                    end
                end
                
                if ~isempty(exceeded_um)
                    obj.hTextExceeded.Visible  = 'on';
                    obj.hTextExceeded.Position = [0.5 sum(YLim_ref)/2];
                    obj.hTextExceeded.String   = sprintf('Limit\nExceeded\n%.0fum',-exceeded_um);
                else
                    obj.hTextExceeded.Visible = 'off';
                end
                
                obj.hLineLimits.XData = lineLimitsX;
                obj.hLineLimits.YData = lineLimitsY;
                obj.hLineLimitsMarkerMin.XData = lineLimitsMarkerMinX;
                obj.hLineLimitsMarkerMin.YData = lineLimitsMarkerMinY;
                obj.hLineLimitsMarkerMax.XData = lineLimitsMarkerMaxX;
                obj.hLineLimitsMarkerMax.YData = lineLimitsMarkerMaxY;
            end
            
            function updateRightAxis(YLim_ref)
                pts = [0 0 YLim_ref(1);
                       0 0 YLim_ref(2)];
                hPts = scanimage.mroi.coordinates.Points(obj.hModel.hCoordinateSystems.hCSReference,pts);
                hPts = hPts.transform(obj.hModel.hCoordinateSystems.hCSSampleRelative);
                YLim_sample_rel = hPts.points(:,3);
                
                if isprop(obj.hAx,'YAxis') && numel(obj.hAx.YAxis)>1
                    yyaxis(obj.hAx,'right');
                    obj.hAx.YAxis(2).Limits = sort(YLim_sample_rel);
                end
            end
        end
    end
    
    methods
        function changeCoordinateSystem(obj,varargin)
            csOptions = obj.hPmCoordinateSystem.String;
            cs = csOptions{obj.hPmCoordinateSystem.Value};
            
            switch lower(cs)
                case 'sample'
                    hCS = obj.hModel.hCoordinateSystems.hCSSampleRelative;
                case 'raw motor'
                    hCS = obj.hModel.hMotors.hCSAxesPosition;
                otherwise
                    error('Unkown coordinate system: %s',cs);
            end
            obj.hCSDisplay = hCS;
        end
    end
    
    %% Getter/Setter
    methods
        function set.hCSDisplay(obj,val)
            obj.hCSDisplay = val;
            obj.update();
        end
    end
end

function tf = yyaxisAvailable()
    tf = ~verLessThan('matlab', '9.0');
end

function val = roundTo(val,digits)
    if ~isempty(digits)
        val = round(val,digits);
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
