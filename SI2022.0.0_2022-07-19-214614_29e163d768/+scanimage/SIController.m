classdef SIController < most.Controller & scanimage.interfaces.Class
    % SIController Controller class for the ScanImage application
    %   handles ScanImage GUI bindings
    
    %% USER PROPS
    properties
        beamDisplayIdx=1;                   % Index of beam whose properties are currently displayed/controlled
        phtCtgChannelDisplayIdx = 1;
        enablePhotostimHotkeys = false;     % enable hotkeys for on demand photostim while that gui is in the foreground
    end
    
    properties (Hidden)        
        % Legacy properties, might be removed in future version
        channelsTargetDisplay;              % A value indicating 'active' channel display, or Inf, indicating the merge display figure. If empty, no channel is active.
        lastZoomOnes = 1;
        lastZoomTens = 0;
        lastZoomFrac = 0;
    end
    
    %%% Read-only sub-controller handles
    %properties (SetAccess=immutable,Transient)
    properties (Hidden)
        hWidgetBar;
        hCycleManagerCtrl;
        openedBef = false;
        imagingSystemList;
    end

    %% FRIEND PROPS
    properties (Hidden)
        defaultGuis = {};                   % cell array of guis that are displayed by default on startup
        pbIdx;
        hCycleWaitTimer;
        tfMap = containers.Map({true false}, {'on' 'off'});
        hUiLogger;
        
        hChanTable;
    end
    
    properties (Hidden, Dependent,SetAccess={?scanimage.interfaces.Class})
        mainControlsStatusString;
    end
    
    properties (Hidden, SetAccess=?scanimage.interfaces.Class)
        waitCursorProps = {'acqInitInProgress' 'hPhotostim.initInProgress'};
        cancelStart = false;
    end
    
    %% INTERNAL PROPS
    properties (SetAccess=private,Hidden)
        h5771Sampler;
        h5771SamplerListener;
        hPathAdder;
        initComplete = false;
        cameraGuis = [];
        stimRoiGroupNameListeners = event.listener.empty(0,1);
        hStimRoiGroupListener = [];
        
        pshk_zeroshit = 0;              % love this variable name.
        temp_fname = {};
    end
    
    properties (Constant,Hidden)
        WINDOW_BORDER_SPACING = 8; % [pixels] space between tethered guis
    end
    
    properties(Hidden,SetAccess=private)
        usrSettingsPropListeners; % col vec of listener objects used for userSettingsV4
        hSliderListener = [];
        hWaitCursorListeners = [];
        hCSListeners = []; % coordinate system listeners
        
        hPowbAx;
        hPowbCtxIm;
        hPowbBoxSurf;
        hPowbBoxTL;
        hPowbBoxTR;
        hPowbBoxBL;
        hPowbBoxBR;
        hPowbBoxT;
        hPowbBoxB;
        hPowbBoxL;
        hPowbBoxR;
        hPowbBoxCtr;
        hText;
        hPowbOthers;
        hOthTexts;
        
        hFastZTuneFig;
        hFastZTuneAxes;
        hFastZDesiredWvfmPlot;
        hFastZPlotLines;
        hFastZCmdSigPlot;
        hFastZResponsePlot;
        
        gPowers;
        gGains;
        gTrips;
        gOffs;
        gBands;
    end
    
    properties(Hidden,Dependent,SetAccess=private)
        hMainPbFastCfg;  % 6x1 vector of MainControls fastCfg buttons
    end
    
    %%% USER FUNCTION RELATED PROPERTIES
    properties(Hidden,Dependent)
        userFunctionsViewType; % string enum; either 'CFG', 'USR', or 'none'.
        userFunctionsCurrentEvents;
        userFunctionsCurrentProp;
    end
    
    %%% ABSTRACT PROPERTY REALIZATIONS (most.Controller)
    properties (SetAccess=protected)
        propBindings = [];
    end
    
    %% LIFECYCLE
    methods (Hidden)
        function obj = SIController(hModel,hWb)
            if nargin < 2
                hWb = [];
            end
            
            baseDirectory = fileparts(which('scanimage'));
            requiredPaths{1} = fullfile(baseDirectory, 'guis');
            requiredPaths{2} = fullfile(baseDirectory, 'guis', 'icons');
            hPathAdder_ = most.util.PathAdder(requiredPaths);
            
            visibleGuis = {'mainControlsV4' 'configControlsV4' 'imageControlsV4'...
                'channelControlsV4' 'scanimage.guis.MotorControls' 'scanimage.guis.BeamControls'};
            hiddenGuis = {'fastConfigurationV4' 'userFunctionControlsV4' 'triggerControlsV5' 'userSettingsV4'...
                'photostimControlsV5' 'scanimage.guis.WaveformControls' 'powerBoxControlsV4'...
                'scanimage.guis.ScanfieldDisplayControls' 'scanimage.guis.RoiGroupEditor'...
                'integrationRoiOutputChannelControlsV5' 'roiIntegratorDisplay'...
                'scanimage.guis.AlignmentControls' 'motorsAlignmentControls' 'scanimage.guis.MotionDisplay'...
                'slmControls','scanimage.guis.SlmCalibrationControls',...
                'PhotonCountingCtrls'...
                'scanimage.guis.DataScope' 'scanimage.guis.SignalDemuxControls'...
                'scanimage.guis.SubStageCameraSlmCalibration' 'scanimage.guis.SlmLutCalibration' 'scanimage.guis.SlmSpatialCalibration'...
                'scanimage.guis.StackControls' 'scanimage.guis.TileView'};
            
            scc = all(isa(hModel.hScan2D, 'scanimage.components.scan2d.RggScan'));
            if scc
                hiddenGuis{end+1} = 'scanimage.guis.SignalConditioningControls';
            else
                hiddenGuis{end+1} = 'scanimage.guis.LaserTriggerScope';
            end
            
            hiddenGuis(cellfun(@(x)~exist(x),hiddenGuis)) = [];
            allGuis = union(visibleGuis, hiddenGuis);
            
            
            obj = obj@most.Controller(hModel,{},unique(allGuis),hWb);
            obj.hPathAdder = hPathAdder_; % this call has to occur after the superclass constructor
            obj.defaultGuis = visibleGuis;
            
            if scc
                m = findall(obj.hGUIs.mainControlsV4,'tag','mnu_View_LaserTriggerScope');
                m.Label = 'Signal Conditioning Controls';
                m.Callback = @(varargin)obj.hSignalConditioningControls.showGui();
            end
                
            try
                obj.hCycleWaitTimer = timer('Name','Cycle Wait Timer');
                obj.hCycleWaitTimer.StartDelay = 0.1;
                obj.hCycleWaitTimer.TimerFcn = @obj.updateCycleWaitStatus;
                obj.hCycleWaitTimer.ExecutionMode = 'fixedSpacing';
                %Capture keypresses for FastCfg F-key behavior. At moment, set
                %KeyPressFcn for all figures, uicontrols, etc so that all
                %keypresses over SI guis are captured. This can be modified
                %if/when certain figures/uicontrols need their own KeyPressFcns.
                structfun(@(handles)obj.ziniSetKeyPressFcn(handles),obj.hGUIData);
                
                %GUI Initializations
                obj.ziniMainControls();
                obj.ziniConfigControls();
                obj.ziniImageControls();
                obj.ziniPowerBoxControls();
                obj.ziniUsrSettingsGUI();
                obj.ziniTriggers();
                obj.ziniChannelControls();
                obj.ziniRegisterFigs();
                obj.ziniMotorAlignmentControls();
                obj.ziniRoiIntegratorsDisplay();
                obj.ziniIntegrationRoiOutputChannelControls();
                obj.ziniPhotostimControls();
                obj.ziniSlmControls();
                obj.ziniCameras();
                
                obj.hWidgetBar = dabs.resources.widget.WidgetBar();
                obj.registerGUI(obj.hWidgetBar.hFig);
                obj.hWidgetBar.CloseRequestFcn = @(varargin)obj.hWidgetBar.close;
                
                obj.hCycleManagerCtrl = scanimage.guis.CycleManagerController(hModel.hCycleManager);
                obj.registerGUI(obj.hCycleManagerCtrl.view.gui);
                
                %Listener Initializations
                for i = 1:numel(obj.waitCursorProps)
                    lobj = obj.hModel;
                    c = strsplit(obj.waitCursorProps{i}, '.');
                    if numel(c) > 1
                        for j = 1:numel(c)-1
                            lobj = lobj.(c{j});
                        end
                    end
                    obj.hWaitCursorListeners{end+1} = most.ErrorHandler.addCatchingListener(lobj,c{end},'PostSet',@(varargin)waitCursorUpdate);
                end
                obj.hWaitCursorListeners = [obj.hWaitCursorListeners{:}];
            catch ME
                most.idioms.safeDeleteObj(obj)
                rethrow(ME);
            end
            
            function waitCursorUpdate
                persistent curscache
                wt = cellfun(@(x)evalin('caller',x),strcat('obj.hModel.', obj.waitCursorProps));
                if any(wt)
                    if isempty(curscache)
                        nms = fieldnames(obj.hGUIs);
                        for k = 1:numel(nms)
                            try
                                curscache.(nms{k}) = get(obj.hGUIs.(nms{k}), 'pointer');
                            catch
                            end
                        end
                    end
                    set(obj.hGUIsArray, 'pointer', 'watch');
                    drawnow
                else
                    if ~isempty(curscache)
                        nms = fieldnames(curscache);
                        for k = 1:numel(nms)
                            try
                                set(obj.hGUIs.(nms{k}), 'pointer', curscache.(nms{k}));
                            catch
                            end
                        end
                    end
                 
                    drawnow
                    curscache = [];
                end
            end
        end
        
        function initialize(obj,usr,hidegui)
            if nargin < 2
                usr = '';
            end
            if nargin < 3 || isempty(hidegui)
                hidegui = false;
            end
            
            initialize@most.Controller(obj);
            
            %Load user file (which adjusts figure positions). If no user
            %file is loaded raise default guis in default positions
            if isempty(usr) || ~obj.hModel.hConfigurationSaver.usrLoadUsr(usr)
                obj.ziniFigPositions();
                if ~hidegui
                    obj.hMotorControls.Visible = true;
                    cellfun(@(gui)obj.showGUI(obj.hGUIs.(regexp(gui,'[^\.]*$','match','once'))),obj.defaultGuis);
                    arrayfun(@(figNum)figure(obj.hModel.hDisplay.hFigs(figNum)),obj.hModel.hChannels.channelDisplay);
                end
            end
            
            obj.initComplete = true;
            
            %Mark initialization as complete.
            obj.hModel.hUserFunctions.notify('applicationOpen');
            obj.hUiLogger = most.UiLogger(obj);
            
            obj.attachPropBindingsToToolTipStrings();
        end
        
        function exit(obj)
            obj.hModel.exit();
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.cameraGuis);
            most.idioms.safeDeleteObj(obj.h5771Sampler);
            most.idioms.safeDeleteObj(obj.h5771SamplerListener);
            most.idioms.safeDeleteObj(obj.hFastZTuneFig);
            most.idioms.safeDeleteObj(obj.hCycleManagerCtrl);
            most.idioms.safeDeleteObj(obj.hCycleWaitTimer);
            most.idioms.safeDeleteObj(obj.hSliderListener);
            most.idioms.safeDeleteObj(obj.hWaitCursorListeners);
            most.idioms.safeDeleteObj(obj.hCSListeners);
            
            obj.stimRoiGroupNameListeners.delete(); % event listeners should not need safeDeleteObj
            most.idioms.safeDeleteObj(obj.hStimRoiGroupListener);
            
            obj.prepareDelete();
            if most.idioms.isValidObj(obj.hPathAdder)
                force = true;
                obj.hPathAdder.removePaths(force);
                obj.hPathAdder.delete();
            end
        end
        
        function resetScanImage(obj)
            ans_ = questdlg('ScanImage needs to exit to reset. Do you want to proceed?',...
                'Exit ScanImage Confirmation','Yes','No','No');
            if strcmpi(ans_,'No')
                return; %Abort this exit function
            end
            classDataDir_ = obj.hModel.classDataDir; % obj.exit will delete the model cache the classDataDir property
            obj.exit()
            scanimage.util.resetClassDataFiles(classDataDir_);
        end
        
        function resetDaqDevices(obj)
            ans_ = questdlg('ScanImage needs to exit to reset all NI DAQ devices. Do you want to proceed?',...
                'Exit ScanImage Confirmation','Yes','No','No');
            if strcmpi(ans_,'No')
                return; %Abort this exit function
            end
            obj.exit()
            scanimage.util.resetDaqDevices();
        end
        
        function show_vDAQTestpanel(~)
            scanimage.guis.VdaqTestPanel(0);
        end
        
        function ziniChannelControls(obj)
            if isempty(obj.hChanTable)
                obj.hChanTable = obj.hGUIData.channelControlsV4.pcChannelConfig;
                obj.hChanTable.hSIC = obj;
                obj.hChanTable.hSI = obj.hModel;
            end
            obj.hChanTable.imgSysChanged();
            
            obj.hGUIData.channelControlsV4.channelImageHandler.initColorMapsInTable(); % re-init to deal with resize
                    
            % This re-registers figure windows with specific channels in the channel window. Not sure what this does
            % as virtually everything is handled via most MVC. Why change
            % use numChan?
            %
            %obj.hModel.hDisplay.prepareDisplayFigs();
%             obj.hGUIData.channelControlsV4.channelImageHandler.registerChannelImageFigs(obj.hModel.hDisplay.hFigs(1:numChan));
            obj.hGUIData.channelControlsV4.channelImageHandler.registerChannelImageFigs(obj.hModel.hDisplay.hFigs);
            
        end
        
        function ziniFigPositions(obj)
%             movegui(obj.hGUIs.mainControlsV4,'northwest');
%             drawnow expose % otherwise the main gui is not always moved to the correct position

            % check if widget bar is on same monitor as si guis
            m = getMonitorNumber(obj.hGUIs.mainControlsV4);
            if obj.hWidgetBar.Visible && (obj.hWidgetBar.currentMonitor == m) && ~obj.hWidgetBar.currentSide
                most.gui.tetherGUIs(obj.hWidgetBar.hFig,obj.hGUIs.mainControlsV4,'righttop',obj.WINDOW_BORDER_SPACING);
            else
                most.gui.tetherGUIs([],obj.hGUIs.mainControlsV4,'northwest',[]);
            end
            most.gui.tetherGUIs(obj.hGUIs.mainControlsV4,obj.hGUIs.configControlsV4,'righttop',obj.WINDOW_BORDER_SPACING);
            most.gui.tetherGUIs(obj.hGUIs.mainControlsV4,obj.hGUIs.imageControlsV4,'bottomleft',obj.WINDOW_BORDER_SPACING);
            most.gui.tetherGUIs(obj.hGUIs.configControlsV4,obj.hGUIs.channelControlsV4,'righttop',obj.WINDOW_BORDER_SPACING);
            most.gui.tetherGUIs(obj.hGUIs.imageControlsV4,obj.hGUIs.BeamControls,'bottomleft',obj.WINDOW_BORDER_SPACING);
            most.gui.tetherGUIs(obj.hGUIs.imageControlsV4,obj.hGUIs.MotorControls,'righttop',obj.WINDOW_BORDER_SPACING);
            most.gui.tetherGUIs(obj.hGUIs.MotorControls,obj.hGUIs.StackControls,'rightbottom',obj.WINDOW_BORDER_SPACING);
            most.gui.tetherGUIs(obj.hGUIs.MotorControls,obj.hGUIs.photostimControlsV5,'righttop',obj.WINDOW_BORDER_SPACING);
            
            % stack channel display figures
            initialPosition = [700 300];
            offset = 30;
            numFigs = length(obj.hModel.hDisplay.hFigs);
            for i = 1:numFigs
                figNum = numFigs - i + 1;
                offset_ = offset * (i-1);
                position = [initialPosition(1)+offset_, initialPosition(2)-offset_];
                setpixelposition(obj.hModel.hDisplay.hFigs(figNum),[position(1,:) 408 408]);
            end
            setpixelposition(obj.hModel.hDisplay.hMergeFigs,[700 250 490 490]);     %Invisible by default
        
            % ensure no figure is located outside the visible part of the screen
            allFigs = [obj.hGUIsArray(:)' obj.hModel.hDisplay.hFigs(:)' obj.hModel.hDisplay.hMergeFigs(:)'];
            for hFig = allFigs
               most.gui.moveOntoScreen(hFig);
            end
            
            function monitorSizes = getMonitorSizesLeftToRight()
                monitorSizes = get(0, 'MonitorPositions');
                [~,sortIdx] = sort(monitorSizes(:,1));
                monitorSizes = monitorSizes(sortIdx,:);
            end
            
            function m = getMonitorNumber(hFig)
                monitorSizes = getMonitorSizesLeftToRight();
                hFig.Units = 'pixels';
                p = hFig.Position;
                m = 0;
                for iMonitor = 1:size(monitorSizes,1)
                    sz = monitorSizes(iMonitor,[1 2 1 2]) + [0 0 monitorSizes(iMonitor,[3 4])];
                    if (p(1) >= sz(1)) && (p(1) <= sz(3)) && (p(2) >= sz(2)) && (p(2) <= sz(4))
                        m = iMonitor;
                        break;
                    end
                end
            end
        end
        
        function ziniRegisterFigs(obj)
            % makes channel windows 'managed' figures so that they are
            % saved in the user settings file
            for i = 1:obj.hModel.hChannels.channelsAvailable
                hFig = obj.hModel.hDisplay.hFigs(i);
                obj.registerGUI(hFig);
            end
%             keyboard
%             for hDisp = obj.hModel.hDisplay.scanfieldDisplays
%                 obj.registerGUI(hDisp.hFig);
%             end
            obj.registerGUI(obj.hModel.hDisplay.hMergeFigs);
        end
        
        function ziniRoiIntegratorsDisplay(obj)
            obj.hGUIData.roiIntegratorDisplay.hDisplay;
        end
        
        function resetIntegrationRoiDisplay(obj)
            obj.hGUIData.roiIntegratorDisplay.hDisplay.reset();
        end
        
        function updateIntegrationRoiDisplay(obj,hIntegrationRois,integrationValues,timestamps)
            obj.hGUIData.roiIntegratorDisplay.hDisplay.updateDisplay(hIntegrationRois,integrationValues,timestamps)
        end
        
        function ziniIntegrationRoiOutputChannelControls(obj)
            if obj.hModel.hIntegrationRoiManager.numInstances <= 0
                set(obj.hGUIs.integrationRoiOutputChannelControlsV5,'Visible','off');
                return
            end
            
            channelNames = {obj.hModel.hIntegrationRoiManager.hIntegrationRoiOutputChannels.name};
            if isempty(channelNames)
                set(obj.hGUIs.integrationRoiOutputChannelControlsV5,'Visible','off');
                set(obj.hGUIData.integrationRoiOutputChannelControlsV5.pmOutputChannel,'String',{''});
                set(obj.hGUIData.integrationRoiOutputChannelControlsV5.pmOutputChannel,'Value',1);
                return
            end
            
            set(obj.hGUIData.integrationRoiOutputChannelControlsV5.pmOutputChannel,'String',channelNames);
            set(obj.hGUIData.integrationRoiOutputChannelControlsV5.pmOutputChannel,'Value',1);
            obj.changedIntegrationRoiOutputChannel();
        end
        
        function refreshOutputChannelsList(obj)
           obj.hModel.hIntegrationRoiManager.refreshOutputChannelsList();
           
           channelNames = {obj.hModel.hIntegrationRoiManager.hIntegrationRoiOutputChannels.name};
            if isempty(channelNames)
                set(obj.hGUIs.integrationRoiOutputChannelControlsV5,'Visible','off');
                set(obj.hGUIData.integrationRoiOutputChannelControlsV5.pmOutputChannel,'String',{''});
                set(obj.hGUIData.integrationRoiOutputChannelControlsV5.pmOutputChannel,'Value',1);
                return
            end
            
            set(obj.hGUIData.integrationRoiOutputChannelControlsV5.pmOutputChannel,'String',channelNames);
            set(obj.hGUIData.integrationRoiOutputChannelControlsV5.pmOutputChannel,'Value',1);
            obj.changedIntegrationRoiOutputChannel();
        end
        
        function hChannel = getCurrentlyEditedRoiOutputChannel(obj)        
            strings = get(obj.hGUIData.integrationRoiOutputChannelControlsV5.pmOutputChannel,'String');
            val = get(obj.hGUIData.integrationRoiOutputChannelControlsV5.pmOutputChannel,'Value');
            name = strings{val};
            
            channelNames = {obj.hModel.hIntegrationRoiManager.hIntegrationRoiOutputChannels.name};
            [~,idx] = ismember(name,channelNames);
            
            if idx > 0
                hChannel = obj.hModel.hIntegrationRoiManager.hIntegrationRoiOutputChannels(idx);
            else
                hChannel = [];
            end
        end
        
        function changedIntegrationRoiOutputChannel(obj,varargin)
            hChannel = obj.getCurrentlyEditedRoiOutputChannel();
            
            if isempty(hChannel)
                set(obj.hGUIData.integrationRoiOutputChannelControlsV5.cbEnableOutput,'Value',false);
                set(obj.hGUIData.integrationRoiOutputChannelControlsV5.etOutputFunction,'String','');
                set(obj.hGUIData.integrationRoiOutputChannelControlsV5.outputParameterGroup,'Title','');
                set(obj.hGUIData.integrationRoiOutputChannelControlsV5.tbRoiSelection,'Data',{},'UserData',[]);
                return
            end
            
            set(obj.hGUIData.integrationRoiOutputChannelControlsV5.cbEnableOutput,'Value',hChannel.enable);
            if isempty(hChannel.outputFunction)
                functionstring = '';
            else
                functionstring = func2str(hChannel.outputFunction);
            end
            set(obj.hGUIData.integrationRoiOutputChannelControlsV5.etOutputFunction,'String',functionstring);
            set(obj.hGUIData.integrationRoiOutputChannelControlsV5.outputParameterGroup,'Title',sprintf('%s output on %s',hChannel.outputMode,hChannel.physicalChannelName));
            
            rois = obj.hModel.hIntegrationRoiManager.roiGroup.rois;
            roiNames = {obj.hModel.hIntegrationRoiManager.roiGroup.rois.name};
            [~,idx] = ismember(hChannel.hIntegrationRois,rois);
            roisSelected = false(1,length(rois));
            if ~isequal(idx,0)
                roisSelected(idx) = true;
            end
            roisSelected = num2cell(roisSelected);
            
            tblData = horzcat(roisSelected',roiNames');
            set(obj.hGUIData.integrationRoiOutputChannelControlsV5.tbRoiSelection,'Data',tblData,'UserData',rois);
        end
        
        function changeIntegrationRoiOutputChannelRoiSelection(obj,modifier)
            hChannel = obj.getCurrentlyEditedRoiOutputChannel();
            
            if nargin < 2 || isempty(modifier)
                modifier = '';
            end
            
            if isempty(hChannel)
                obj.changedIntegrationRoiOutputChannel();
                return
            end
            
            tblData = get(obj.hGUIData.integrationRoiOutputChannelControlsV5.tbRoiSelection,'Data');
            roiSelection = [tblData{:,1}];
            rois = get(obj.hGUIData.integrationRoiOutputChannelControlsV5.tbRoiSelection,'UserData');
            
            switch modifier
                case 'none'
                    hChannel.hIntegrationRois = [];
                case 'all'
                    hChannel.hIntegrationRois = rois;
                otherwise
                    hChannel.hIntegrationRois = rois(roiSelection);
            end
        end
        
        function changeIntegraionRoiOutputChannelEnable(obj,varargin)
            hChannel = obj.getCurrentlyEditedRoiOutputChannel();
            if isempty(hChannel)
                obj.changedIntegrationRoiOutputChannel();
                return
            end
            
            hChannel.enable = logical(get(obj.hGUIData.integrationRoiOutputChannelControlsV5.cbEnableOutput,'Value'));
        end
        
        function editIntegrationRoiOutputChannelFunction(obj,varargin)
            hChannel = obj.getCurrentlyEditedRoiOutputChannel();
            if isempty(hChannel)
                obj.changedIntegrationRoiOutputChannel();
                return
            end
            
            prompt = 'Function editor';
            name = 'Function call';
            numlines = [1,100];
            defaultans = {func2str(hChannel.outputFunction)};
            answer = inputdlg(prompt,name,numlines,defaultans);
            if isempty(answer)
                % user clicked cancel
            else
                hChannel.outputFunction = answer{1};
            end
        end
        
        function ziniCameras(obj)
            cameraManager = obj.hModel.hCameraManager;
            wrappers = cameraManager.hCameraWrappers;
            if isempty(wrappers)
                return;
            end
            %add to dropdown menu
            children = obj.hGUIs.mainControlsV4.Children;
            viewMenu = children(strcmp(get(children, 'Tag'),'View'));
            camRootMenu = uimenu('Parent',viewMenu, 'Label', 'Cameras',...
                'Separator', 'on', 'Tag', 'Cameras');
            
            for idx=1:length(wrappers)
                wrapper = wrappers(idx);
                view = scanimage.guis.CameraView(obj.hModel, obj, wrapper);
                cameraName = wrapper.hDevice.cameraName;
                safeClassName = most.idioms.str2validName(cameraName);
                %tag is required for registry
                view.hFig.Tag = ['CameraView_' safeClassName];
                obj.registerGUI(view.hFig);
                obj.addGuiClass(view.hFig.Tag, view);
                uimenu('Parent',camRootMenu,'Label', cameraName,...
                    'Tag', cameraName, 'Callback', @(varargin)view.showGui());
                
                obj.cameraGuis = [obj.cameraGuis view];
            end
        end
        
        
        function zcbkKeyPress(obj,~,evt)
            % Currently this handles keypresses for all SI guis
            switch evt.Key
                % Keys that should be captured over all guis go in this top level case structure
                case {'f1' 'f2' 'f3' 'f4' 'f5' 'f6'}
                    idx = str2double(evt.Key(2));
                    tfRequireCtrl = get(obj.hGUIData.fastConfigurationV4.cbRequireControl,'Value');
                    tfLoadFastCfg = ~tfRequireCtrl || ismember('control',evt.Modifier);
                    tfBypassAutoStart = ismember('shift',evt.Modifier);
                    if tfLoadFastCfg
                        obj.hModel.hConfigurationSaver.fastCfgLoadConfig(idx,tfBypassAutoStart);
                    end
                    
                % Gui specific keys
                otherwise
                    [tf, i] = ismember(gcf, obj.hGUIsArray);
                    if tf
                        switch obj.guiNames{i}
                            case 'photostimControlsV5'
                                obj.photostimHotKey(evt.Key);
                        end
                    end
            end
        end
        
        function ziniSetKeyPressFcn(obj,handles)
            tags = fieldnames(handles);
            for c = 1:numel(tags)
                h = handles.(tags{c});
                if isprop(h,'KeyPressFcn')
                    set(h,'KeyPressFcn',@(src,evt)obj.zcbkKeyPress(src,evt));
                end
            end
        end
        
        function ziniMainControls(obj)
            obj.hGUIs.mainControlsV4.Name = obj.hModel.version;
            
            %Disable controls for currently unimplemented features
            disabledControls = {'stCycleIteration' 'stCycleIterationOf' ...
                'etIterationsDone' 'etIterationsTotal' ...
                'tbCycleControls' 'pbLastLineParent' ...
                'centerOnSelection' 'zoomhundredsslider' ...
                'zoomhundreds' 'pbLastLine' ...
                'pbBase' 'pbSetBase' 'pbRoot'};
            cellfun(@(s)set(obj.hGUIData.mainControlsV4.(s),'Enable','off'),disabledControls);
            
            if ~dabs.vidrio.rdi.Device.getDriverInfo.numDevices
                h = obj.hGUIData;
                h.mainControlsV4.mnu_View_vDAQTestpanel.Enable = 'off';
            end
            
            hiddenControls = {'xstep' 'ystep'};
            cellfun(@(s)set(obj.hGUIData.mainControlsV4.(s),'Visible','off'),hiddenControls);
            
            %Disable menu items for currently unimplemented features
            disabledMenuItems = {};
            
            % View MenuChannel 1 is never disabled.
            viewMenuChannelsEnabled = {};
            
            switch (obj.hModel.hChannels.channelsAvailable)
                case {1}
                    disabledMenuItems = {'mnu_View_Channel2Display' 'mnu_View_Channel3Display' 'mnu_View_Channel4Display'};
                case {2}
                    disabledMenuItems = {'mnu_View_Channel3Display' 'mnu_View_Channel4Display'};
                    viewMenuChannelsEnabled = {'mnu_View_Channel2Display'};
                case {3}
                    disabledMenuItems = {'mnu_View_Channel4Display'};
                    viewMenuChannelsEnabled = {'mnu_View_Channel2Display' 'mnu_View_Channel3Display'};
               case {4}
                   viewMenuChannelsEnabled = {'mnu_View_Channel2Display' 'mnu_View_Channel3Display' 'mnu_View_Channel4Display'};
            end
            
            cellfun(@(s)set(obj.hGUIData.mainControlsV4.(s),'Enable','on'),viewMenuChannelsEnabled);
            
            cellfun(@(s)set(obj.hGUIData.mainControlsV4.(s),'Enable','off'),disabledMenuItems);
            set(obj.hGUIData.mainControlsV4.figure1,'closeRequestFcn',@lclCloseEventHandler);

			%+++
            set(obj.hGUIData.mainControlsV4.mnu_Settings_YokeWS,'Checked','off');
            
            function lclCloseEventHandler(src,evnt)
                ans_ = questdlg('Are you sure you want to exit ScanImage?','Exit ScanImage Confirmation','Yes','No','No');
                if strcmpi(ans_,'No')
                    return; %Abort this exit function
                end
                set(src,'CloseRequestFcn',[]); % User clicked yes, don't ask again even if exit fails
                obj.exit();
            end
        end
        
        function ziniConfigControls(obj)
            %Configure imaging system list
            imSystemList = {};
            for i = 1:numel(obj.hModel.hScanners)
                hScn = obj.hModel.hScanners{i};
                scannerName = hScn.name;
                if isa(hScn, 'scanimage.components.scan2d.RggScan') && strcmp(hScn.scannerType,'RGG')
                    imSystemList = [imSystemList; {sprintf('%s (Resonant)', scannerName); sprintf('%s (Linear)', scannerName)}];
                else
                    imSystemList = [imSystemList; {scannerName}];
                end
            end
            set(obj.hGUIData.configControlsV4.pmImagingSystem, 'string', imSystemList);
            obj.imagingSystemList = imSystemList;
            
            set(obj.hGUIData.configControlsV4.pmScanType, 'string',{'Frame Scan', 'Line Scan'});
            
            %Hide controls not used
            hideControls = {'rbScanPhaseHardware'};
            cellfun(@(s)set(obj.hGUIData.configControlsV4.(s),'Visible','off'), hideControls);
            
            %Disable controls with features not supported
            disableControls = {'rbScanPhaseSoftware'};
            cellfun(@(s)set(obj.hGUIData.configControlsV4.(s),'Enable','off'), disableControls);
            
            %fix issue with last item in popup list
            itms = get(obj.hGUIData.configControlsV4.pmPixelsPerLine, 'string');
            itms{end} = strtrim(itms{end});
            set(obj.hGUIData.configControlsV4.pmPixelsPerLine, 'string', itms);
            
            %Set properties of line phase slider
            obj.cfgLinePhaseSlider();
            obj.changedLineRateVar();
           
        end % function - ziniConfigControls
        
        function ziniImageControls(obj)            
            %Initialize channel LUT controls
            for i=1:4
                if i > obj.hModel.hChannels.channelsAvailable %Disable controls for reduced channel count devices
                    set(findobj(obj.hGUIData.imageControlsV4.(sprintf('pnlChan%d',i)),'Type','uicontrol'),'Enable','off');
                    set(obj.hGUIData.imageControlsV4.(sprintf('blackSlideChan%d',i)),'Min',0,'Max',1,'SliderStep',[.01 .1],'Value',0);
                    set(obj.hGUIData.imageControlsV4.(sprintf('whiteSlideChan%d',i)),'Min',0,'Max',1,'SliderStep',[.01 .1],'Value',0);
                    set(obj.hGUIData.imageControlsV4.(sprintf('blackEditChan%d',i)),'String',num2str(0));
                    set(obj.hGUIData.imageControlsV4.(sprintf('whiteEditChan%d',i)),'String',num2str(100));
                    set(obj.hGUIData.imageControlsV4.(sprintf('tbCh%d',i)), 'Enable', 'off');
                else
                    %Allow 10-percent of negative range, if applicable
                    set(findobj(obj.hGUIData.imageControlsV4.(sprintf('pnlChan%d',i)),'Type','uicontrol'),'Enable','on');
                    chanLUTMin = round(obj.hModel.hChannels.channelLUTRange(1) * 0.1);
                    chanLUTMax = obj.hModel.hChannels.channelLUTRange(2);
                    blackVal = max(chanLUTMin,obj.hModel.hChannels.channelLUT{i}(1));
                    whiteVal = min(chanLUTMax,obj.hModel.hChannels.channelLUT{i}(2));
                    set(obj.hGUIData.imageControlsV4.(sprintf('blackSlideChan%d',i)),'Min',chanLUTMin,'Max',chanLUTMax,'SliderStep',[.001 .05],'Value',blackVal);
                    set(obj.hGUIData.imageControlsV4.(sprintf('whiteSlideChan%d',i)),'Min',chanLUTMin,'Max',chanLUTMax,'SliderStep',[.001 .05],'Value',whiteVal);
                    set(obj.hGUIData.imageControlsV4.(sprintf('tbCh%d',i)), 'Enable', 'on');
                end
            end
            
            %JLF Tag -- Why is this line here?? Edit for 3rd Option.
            set(obj.hGUIData.imageControlsV4.pmVolumeStyle, 'string',{'3D', 'Tiled', 'Current', 'Max'});
            
            %Move Frame Averaging/Selection panel up if there are 2 or less channels
            if obj.hModel.MAX_NUM_CHANNELS <= 2
                charShift = (obj.hModel.MAX_NUM_CHANNELS - 2) * 5;
                
                for i=3:obj.hModel.MAX_NUM_CHANNELS
                    hPnl = obj.hGUIData.imageControlsV4.(sprintf('pnlChan%d',i));
                    set(hPnl,'Visible','off');
                    set(findall(hPnl),'Visible','off');
                end
                
                for i=1:2
                    hPnl = obj.hGUIData.imageControlsV4.(sprintf('pnlChan%d',i));
                    set(hPnl,'Position',get(hPnl,'Position') + [0 -charShift 0 0]);
                end
                
                hFig = obj.hGUIs.imageControlsV4;
                set(hFig,'Position',get(hFig,'Position') + [0 charShift 0 -charShift]);
            end
            
        end
        
        function numBeamsChanged(obj,varargin)
            obj.ziniPowerBoxControls();
        end
        
        function ziniPowerBoxControls(obj)            
            if ~most.idioms.isValidObj(obj.hPowbAx)
                obj.hPowbAx = obj.hGUIData.powerBoxControlsV4.axBoxPos;
                set(obj.hPowbAx,'XLim',[0 1],'YLim',[0 1],'ButtonDownFcn',@(varargin)obj.powbPanFcn(true))
                obj.hPowbCtxIm = surface([0 1],[0 1],zeros(2),'Parent',obj.hPowbAx,'Hittest','off','FaceColor','texturemap',...
                    'CData',zeros(2,2,3),'EdgeColor','none','FaceLighting','none','FaceAlpha',1);
                obj.hPowbBoxSurf = surface([.25 .75],[.25 .75],ones(2),'Parent',obj.hPowbAx,'Hittest','off','FaceColor','texturemap',...
                    'EdgeColor','none','FaceLighting','none','FaceAlpha','texturemap','CData',[],'AlphaData',[]);

                args = {'Parent',obj.hPowbAx,'ZData',2,'Color','r','Hittest','on','Marker','.','MarkerSize',25};
                obj.hPowbBoxTL = line('XData',.25,'YData',.25,'ButtonDownFcn',@(varargin)obj.powbCpFunc([1 1 0 0],true),args{:});
                obj.hPowbBoxTR = line('XData',.75,'YData',.25,'ButtonDownFcn',@(varargin)obj.powbCpFunc([0 1 1 0],true),args{:});
                obj.hPowbBoxBL = line('XData',.25,'YData',.75,'ButtonDownFcn',@(varargin)obj.powbCpFunc([1 0 0 1],true),args{:});
                obj.hPowbBoxBR = line('XData',.75,'YData',.75,'ButtonDownFcn',@(varargin)obj.powbCpFunc([0 0 1 1],true),args{:});
                obj.hPowbBoxCtr = line('XData',.5,'YData',.5,'ButtonDownFcn',@(varargin)obj.powbCpFunc([1 1 1 1],true),args{:});
                obj.hText = text(.25,.25,2,'Power Box','Parent',obj.hPowbAx,'color','y','Hittest','off');
                if obj.graphics2014b
                    obj.hText.PickableParts = 'none';
                end

                args = {'Parent',obj.hPowbAx,'ZData',[1.5 1.5],'Color','r','Hittest','on','LineWidth',1.5,'ButtonDownFcn',@(varargin)obj.powbCpFunc([1 1 1 1],true)};
                obj.hPowbBoxT = line('XData',[.25 .75],'YData',[.25 .25],args{:});
                obj.hPowbBoxB = line('XData',[.25 .75],'YData',[.75 .75],args{:});
                obj.hPowbBoxL = line('XData',[.25 .25],'YData',[.25 .75],args{:});
                obj.hPowbBoxR = line('XData',[.75 .75],'YData',[.25 .75],args{:});

                set(obj.hGUIs.powerBoxControlsV4,'WindowScrollWheelFcn',@obj.powbScrollWheelFcn)
            end

            %hide unusable controls
            for iterChannels = 1:4
                if iterChannels <= obj.hModel.hChannels.channelsAvailable
                    set(obj.hGUIData.powerBoxControlsV4.(sprintf('pbCopy%d',iterChannels)),'Enable','on');
                else
                    set(obj.hGUIData.powerBoxControlsV4.(sprintf('pbCopy%d',iterChannels)),'Enable','off');
                end
            end

            %power box dropdown
            nms = {};
            for pb = obj.hModel.hBeams.powerBoxes
                nms{end+1} = pb.name;
                if isempty(nms{end})
                    nms{end} = sprintf('Power Box %d', numel(nms));
                end
            end
            nms{end+1} = 'New Power Box';
            set(obj.hGUIData.powerBoxControlsV4.pmPbSel,'String',nms);

            i = obj.pbIdx;
            if i <= numel(obj.hModel.hBeams.powerBoxes)
                set([obj.hPowbBoxSurf obj.hPowbBoxTL obj.hPowbBoxTR obj.hPowbBoxBL obj.hPowbBoxBR obj.hText...
                    obj.hPowbBoxCtr obj.hPowbBoxT obj.hPowbBoxB obj.hPowbBoxL obj.hPowbBoxR],'visible','on');
                set([obj.hGUIData.powerBoxControlsV4.etPowers...
                    obj.hGUIData.powerBoxControlsV4.etPosition],'enable','on');
                set(obj.hGUIData.powerBoxControlsV4.pnPbSettings,'Title',['Power Box Settings (' nms{i} ')']);
            else
                set([obj.hPowbBoxSurf obj.hPowbBoxTL obj.hPowbBoxTR obj.hPowbBoxBL obj.hPowbBoxBR obj.hText...
                    obj.hPowbBoxCtr obj.hPowbBoxT obj.hPowbBoxB obj.hPowbBoxL obj.hPowbBoxR],'visible','off');
                set([obj.hGUIData.powerBoxControlsV4.etPowers...
                    obj.hGUIData.powerBoxControlsV4.etPosition],'enable','off');
                set([obj.hGUIData.powerBoxControlsV4.etPowers...
                    obj.hGUIData.powerBoxControlsV4.etPosition],'string','');
                set(obj.hGUIData.powerBoxControlsV4.pnPbSettings,'Title','Power Box Settings');
            end

            if obj.hModel.hBeams.numInstances
                most.gui.enableAll(obj.hGUIs.powerBoxControlsV4,'on');
            else
                most.gui.enableAll(obj.hGUIs.powerBoxControlsV4,'off');
            end
        end
        
        function ziniSlmControls(obj)
            str = {};
            scanners = [];
            for scanner = obj.hModel.hScanners
                scanner = scanner{1};
                if isa(scanner,'scanimage.components.scan2d.SlmScan')
                    str{end+1} = scanner.name;
                    scanners = [scanners scanner];
                end
            end
            
            if isempty(scanners)
                most.gui.enableAll(obj.hGUIs.slmControls,'off');
                ctl = obj.hGUIData.mainControlsV4.mnu_View_SlmControls;
                ctl.Enable = 'off';
            else
                pmSlmSelect = obj.hGUIData.slmControls.pmSlmSelect;
                pmSlmSelect.String = str;
                pmSlmSelect.Value = 1;
                userData = struct('scanners',scanners);
                pmSlmSelect.UserData = userData;
                obj.changeSlmControlsScanner();
                
                obj.defaultGuis{end+1} = 'slmControls';
            end
        end
        
        function ziniPhotonCountingCtrls(obj)
            most.idioms.safeDeleteObj(obj.h5771SamplerListener);
            obj.h5771SamplerListener = [];
            
            hScan2D = obj.hModel.hScan2D;
            hFpga = hScan2D.hAcq.hFpga;
            if ~isempty(hFpga) && isprop(hFpga,'fifo_NI5771SampleToHost')
                set(obj.hGUIData.mainControlsV4.mnu_View_PhotonCountingCtrls,'Enable','on');
                
                if isempty(obj.h5771Sampler)
                    hFpga.NI5771PhotonCountingTwoGroups = true;
                    obj.h5771Sampler = scanimage.guis.photondiscriminator.NI5771Sampler(hFpga,hScan2D);
                    
                    % this used to occur during init because it was invoked
                    % by get and set methods for NI577XSamplerCfg property
                    % in resscan. Better architecture needed for this
                    obj.h5771Sampler.loadStruct(obj.h5771Sampler.saveStruct());
                else
                    obj.h5771Sampler.hScan = hScan2D;
                end
                
                obj.h5771SamplerListener = {most.util.DelayedEventListener(0.2,obj.h5771Sampler,'configurationChanged',@obj.changedPhotonCountingCtrls)};
                obj.h5771SamplerListener{end+1} = most.ErrorHandler.addCatchingListener(hScan2D,'uniformSampling','PostSet',@obj.changedPhotonCountingCtrls);
                obj.h5771SamplerListener{end+1} = most.ErrorHandler.addCatchingListener(hScan2D,'maskDisableAveraging','PostSet',@obj.changedPhotonCountingCtrls);
                
                obj.changedPhotonCountingCtrls();
            else
                set(obj.hGUIData.mainControlsV4.mnu_View_PhotonCountingCtrls,'Enable','off');
            end
        end
        
        function changedPhotonCountingCtrls(obj,varargin)
            tbdata = obj.hGUIData.PhotonCountingCtrls.tbChannelOverview.Data;
            sel = find([tbdata{:,2}]);
            newSel = setdiff(sel,obj.phtCtgChannelDisplayIdx);
            if isempty(newSel)
                newSel = obj.phtCtgChannelDisplayIdx;
            end
            
            obj.phtCtgChannelDisplayIdx = newSel;
            
            updateTableData();
            updateConfig();
            
            function updateTableData()
                nChannels = 4;
                tblabels = arrayfun(@(ch)sprintf('Channel %d',ch),1:nChannels,'UniformOutput',false)';
                tbsel = false(nChannels,1);
                tbsel(obj.phtCtgChannelDisplayIdx) = true;
                tbsel = num2cell(tbsel);
                
                chs = arrayfun(@(ch)obj.h5771Sampler.(['hSIChannel' num2str(ch)]).physicalChannelSelect,1:nChannels);
                tbchs = arrayfun(@(ch)sprintf('AI%d',ch),chs,'UniformOutput',false)';
                
                phtCtgMode = arrayfun(@(ch)obj.h5771Sampler.(['hSIChannel' num2str(ch)]).photonCountingEnable,1:nChannels);
                phtCtgMode = arrayfun(@(md)most.idioms.ifthenelse(md,'Photon Counting','Integration'),phtCtgMode,'UniformOutput',false)';
                
                tbdata = horzcat(tblabels,tbsel,tbchs,phtCtgMode);
                
                tbChannelOverview = obj.hGUIData.PhotonCountingCtrls.tbChannelOverview;
                tbChannelOverview.Data = tbdata;
            end
            
            function updateConfig()
                hChannel = obj.h5771Sampler.(['hSIChannel' num2str(obj.phtCtgChannelDisplayIdx)]);
                
                integrationCtrls = [...
                    obj.hGUIData.PhotonCountingCtrls.cbDifferentiate,...
                    obj.hGUIData.PhotonCountingCtrls.cbAbsoluteValue,...
                    obj.hGUIData.PhotonCountingCtrls.cbEnableIntegrationThreshold,...
                    obj.hGUIData.PhotonCountingCtrls.etIntThresh,...
                    obj.hGUIData.PhotonCountingCtrls.lbIntegrationThreshold];
                photonCtrls = [...
                    obj.hGUIData.PhotonCountingCtrls.pbConfigurePhotonDiscriminator,...
                    obj.hGUIData.PhotonCountingCtrls.pbShowPhotonHistogram,...
                    obj.hGUIData.PhotonCountingCtrls.etPhotonSelectionMask,...
                    obj.hGUIData.PhotonCountingCtrls.lbPhotonMask];
                
                cbUniformSampling = obj.hGUIData.PhotonCountingCtrls.cbUniformSampling;
                cbUniformSampling.Value = obj.h5771Sampler.hScan.uniformSampling;
                pmPhysicalChannelSelector = obj.hGUIData.PhotonCountingCtrls.pmPhysicalChannelSelector;
                pmPhysicalChannelSelector.String = {'AI0','AI1'};
                pmPhysicalChannelSelector = obj.hGUIData.PhotonCountingCtrls.pmPhysicalChannelSelector;
                pmPhysicalChannelSelector.Value = hChannel.physicalChannelSelect+1;

                pmPhtCtgEnable = obj.hGUIData.PhotonCountingCtrls.pmPhtCtgEnable;
                pmPhtCtgEnable.String = {'Integration','Photon Counting'};
                
                pmPhtCtgEnable = obj.hGUIData.PhotonCountingCtrls.pmPhtCtgEnable;
                pmPhtCtgEnable.Value = hChannel.photonCountingEnable+1;
                
                hDiscriminator = obj.h5771Sampler.(['hPhotonDiscriminatorChannel' num2str(hChannel.physicalChannelSelect)]);
                cbDifferentiate = obj.hGUIData.PhotonCountingCtrls.cbDifferentiate;
                cbDifferentiate.Value = hDiscriminator.differentiateBeforeIntegration;
                cbAbsoluteValue = obj.hGUIData.PhotonCountingCtrls.cbAbsoluteValue;
                cbAbsoluteValue.Value = hDiscriminator.absoluteValueBeforeIntegration;
                cbEnableIntegrationThreshold = obj.hGUIData.PhotonCountingCtrls.cbEnableIntegrationThreshold;
                cbEnableIntegrationThreshold.Value = hDiscriminator.enableIntegrationThreshold;
                etIntThresh = obj.hGUIData.PhotonCountingCtrls.etIntThresh;
                etIntThresh.String = num2str(hDiscriminator.integrationThreshold);
                etPhotonSelectionMask = obj.hGUIData.PhotonCountingCtrls.etPhotonSelectionMask;
                etPhotonSelectionMask.String = sprintf('%d',hChannel.photonSelectionMask);
                
                cbDisableMaskAveraging = obj.hGUIData.PhotonCountingCtrls.cbDisableMaskAveraging;
                cbDisableMaskAveraging.Value = obj.h5771Sampler.hScan.maskDisableAveraging(obj.phtCtgChannelDisplayIdx);                
                
                if hChannel.photonCountingEnable
                    set(integrationCtrls,'Visible','off');
                    set(photonCtrls,'Visible','on');
                else
                    set(integrationCtrls,'Visible','on');
                    set(photonCtrls,'Visible','off');
                end
            end
        end
        
        function changePhotonCountingCtrls(obj,varargin)
            hChannel = obj.h5771Sampler.(['hSIChannel' num2str(obj.phtCtgChannelDisplayIdx)]);
            hDiscriminator = obj.h5771Sampler.(['hPhotonDiscriminatorChannel' num2str(hChannel.physicalChannelSelect)]);
            
            try
                hChannel.physicalChannelSelect = obj.hGUIData.PhotonCountingCtrls.pmPhysicalChannelSelector.Value-1;
                hChannel.photonCountingEnable = obj.hGUIData.PhotonCountingCtrls.pmPhtCtgEnable.Value-1;
                str = obj.hGUIData.PhotonCountingCtrls.etPhotonSelectionMask.String;
                str(2,:) = ' ';
                hChannel.photonSelectionMask = logical(str2num(str(:)')); %#ok<ST2NM>
                hDiscriminator.differentiateBeforeIntegration = obj.hGUIData.PhotonCountingCtrls.cbDifferentiate.Value;
                hDiscriminator.absoluteValueBeforeIntegration = obj.hGUIData.PhotonCountingCtrls.cbAbsoluteValue.Value;
                hDiscriminator.enableIntegrationThreshold = obj.hGUIData.PhotonCountingCtrls.cbEnableIntegrationThreshold.Value;
                hDiscriminator.integrationThreshold = str2double(obj.hGUIData.PhotonCountingCtrls.etIntThresh.String);
            catch ME
                obj.changedPhotonCountingCtrls();
                rethrow(ME);
            end
            
            if obj.h5771Sampler.hScan.uniformSampling ~= obj.hGUIData.PhotonCountingCtrls.cbUniformSampling.Value
                obj.h5771Sampler.hScan.uniformSampling = obj.hGUIData.PhotonCountingCtrls.cbUniformSampling.Value;
            end
            
            if obj.h5771Sampler.hScan.maskDisableAveraging(obj.phtCtgChannelDisplayIdx) ~= obj.hGUIData.PhotonCountingCtrls.cbDisableMaskAveraging.Value
                obj.h5771Sampler.hScan.maskDisableAveraging(obj.phtCtgChannelDisplayIdx) = obj.hGUIData.PhotonCountingCtrls.cbDisableMaskAveraging.Value;
            end
        end
        
        function configurePhotonDiscriminator(obj,varargin)
            hChannel = obj.h5771Sampler.(['hSIChannel' num2str(obj.phtCtgChannelDisplayIdx)]);
            hDiscriminator = obj.h5771Sampler.(['hPhotonDiscriminatorChannel' num2str(hChannel.physicalChannelSelect)]);
            
            hDiscriminator.showConfigurationGUI();
        end
        
        function showPhotonHistogram(obj,varargin)
            obj.h5771Sampler.showPhotonHistogram = true;
        end
        
        function changeFastZCfg(obj)
            if obj.hModel.hFastZ.hasFastZ
                set(obj.hGUIData.mainControlsV4.cbCurvatureCorrection,  'enable', 'on');
            else
                set(obj.hGUIData.mainControlsV4.cbCurvatureCorrection,  'enable', 'off');
            end
        end
        
        function ziniPhotostimControls(obj)
            set(obj.hGUIData.photostimControlsV5.pbSoftTrig,'Enable','off');
            set(obj.hGUIData.photostimControlsV5.pbSync,'Enable','off');
            if obj.hModel.hPhotostim.numInstances > 0
                set(obj.hGUIData.photostimControlsV5.pbStart,'Enable','on');
                
                if obj.hModel.hPhotostim.isVdaq
                    pmTrigSource = obj.hGUIData.photostimControlsV5.pmTrigSource;
                    pmTrigSource.String = {'External' 'Frame Clk'};
%                     pmTrigSource.String = {'External' 'Frame Clk' 'Auto (period, s)'};
%                     pmTrigSource = obj.hGUIData.photostimControlsV5.pmSyncSource;
%                     pmTrigSource.String = {'External' 'Frame Clk'};
                    set(obj.hGUIData.photostimControlsV5.pmSyncSource, 'Visible', 'off');
                    set(obj.hGUIData.photostimControlsV5.etSyncTerm, 'Visible', 'off');
                    set(obj.hGUIData.photostimControlsV5.stSyncSource, 'Visible', 'off');
                    set(obj.hGUIData.photostimControlsV5.pbSync, 'Visible', 'off');
                    
                    ctl = obj.hGUIData.photostimControlsV5.cbStimImmediately;
                    ctl.Position(2) = 19.25;
                    ctl = obj.hGUIData.photostimControlsV5.cbAllowMult;
                    ctl.Position(2) = 17.5;
                    ctl = obj.hGUIData.photostimControlsV5.cbEnableHotkeys;
                    ctl.Position(2) = 15.75;
                    ctl = obj.hGUIData.photostimControlsV5.uipanel2;
                    ctl.Position(2) = 6.8;
                    ctl = obj.hGUIData.photostimControlsV5.extStimSelPanel;
                    ctl.Position(2) = 10.2;
                end
            else
                hChildren = most.gui.getAllChildren(obj.hGUIs.photostimControlsV5);
                mask = arrayfun(@(hChild)isprop(hChild,'Enable'),hChildren);
                hChildren = hChildren(mask);
                set(hChildren,'Enable','off');
            end
            
            obj.hStimRoiGroupListener = most.util.DelayedEventListener(0.3,obj.hModel.hPhotostim,'stimRoiGroups','PostSet',@obj.changedStimRoiGroups);
        end
        
        function ziniTriggers(obj)
            set(obj.hGUIData.triggerControlsV5.pmTrigAcqInTerm,'String',obj.hModel.hScan2D.trigAcqInTermAllowed,'Value',1);
            set(obj.hGUIData.triggerControlsV5.pmTrigStopInTerm,'String',obj.hModel.hScan2D.trigStopInTermAllowed,'Value',1);
            set(obj.hGUIData.triggerControlsV5.pmTrigNextInTerm,'String',obj.hModel.hScan2D.trigNextInTermAllowed,'Value',1);
        end
        
        function ziniUsrSettingsGUI(obj)
            availableUsrProps = obj.hModel.mdlGetConfigurableProps()';
            % Throw a warning if any available user prop is not
            % SetObservable. This can happen b/c SetObservable-ness of usr
            % properties is required neither by the Model:mdlConfig
            % infrastructure nor by SI (this is arguably the right
            % thing to do). Meanwhile, the userSettings GUI provides a view
            % (via a propTable) into the current usrProps; this is
            % implemented via listeners. (Side note: ML silently allows
            % adding a listener to an obj for a prop that is not
            % SetObservable.)
            %
            % At the moment I believe all available usr props for SI3/4 are
            % indeed SetObservable, but this warning will be good for
            % maintenance moving forward.
            data(:,1) = sort(availableUsrProps); %#ok<TRSRT>
            data(:,2) = {false};                 %will get initted below
            set(obj.hGUIData.userSettingsV4.tblSpecifyUsrProps,'Data',data);
            obj.changedUsrPropList();
        end
    end
    
    %% PROP ACCESS
    methods
        function viewType = get.userFunctionsViewType(obj)
            viewBtn = get(obj.hGUIData.userFunctionControlsV4.bgView,'SelectedObject');
            if ~isempty(viewBtn)
                switch get(viewBtn,'Tag')
                    case 'tbUsr'
                        viewType = 'USR';
                    case 'tbCfg'
                        viewType = 'CFG';
                end
            else
                viewType = 'none';
            end
        end
        
        function evtNames = get.userFunctionsCurrentEvents(obj)
            switch obj.userFunctionsViewType
                case 'none'
                    evtNames = cell(0,1);
                case 'CFG'
                    evtNames = unique(obj.hModel.hUserFunctions.userFunctionsEvents);
                case 'USR'
                    evtNames = unique([obj.hModel.hUserFunctions.userFunctionsEvents;...
                                     obj.hModel.hUserFunctions.userFunctionsUsrOnlyEvents]);
            end
        end
        
        function propName = get.userFunctionsCurrentProp(obj)
            switch obj.userFunctionsViewType
                case 'none'
                    propName = '';
                case 'CFG'
                    propName = 'userFunctionsCfg';
                case 'USR'
                    propName = 'userFunctionsUsr';
            end
        end
        
        function val = get.propBindings(obj)
            if isempty(obj.propBindings)
                obj.propBindings = lclInitPropBindings(obj.hModel);
            end
            
            val = obj.propBindings;
        end
        
        function val = get.pbIdx(obj)
            val = get(obj.hGUIData.powerBoxControlsV4.pmPbSel,'Value');
        end
        
        function set.pbIdx(obj,val)
            set(obj.hGUIData.powerBoxControlsV4.pmPbSel,'Value',val);
            obj.changedPowerBoxes();
        end
 
        function val = get.hMainPbFastCfg(obj)
            val = [obj.hGUIData.mainControlsV4.pbFastConfig1; ...
                obj.hGUIData.mainControlsV4.pbFastConfig2; ...
                obj.hGUIData.mainControlsV4.pbFastConfig3; ...
                obj.hGUIData.mainControlsV4.pbFastConfig4; ...
                obj.hGUIData.mainControlsV4.pbFastConfig5; ...
                obj.hGUIData.mainControlsV4.pbFastConfig6];
        end
        
        % This sets the GUI-displayed status string, NOT the hModel status string.
        function set.mainControlsStatusString(obj,val)
            set(obj.hGUIData.mainControlsV4.statusString,'String',val);
        end
        
        % This gets the GUI-displayed status string, NOT the hModel status
        % string.
        function val = get.mainControlsStatusString(obj)
            val = get(obj.hGUIData.mainControlsV4.statusString,'String');
        end
    end
    
    %% USER METHODS
    %%% ACTION CALLBACKS
    methods (Hidden)
        %%% MAIN %%%
        function focusButton(obj)
            if strcmpi(obj.hModel.acqState,'idle')
                try
                    obj.hModel.startFocus();

                    if obj.cancelStart
                        obj.cancelStart = false;
                        obj.hModel.abort();
                    end
                catch ME
                    warndlg(ME.message,'ScanImage');
                    rethrow(ME);
                end
            end
        end
        
        function grabButton(obj)
            if strcmpi(obj.hModel.acqState,'idle')
                try
                    obj.hModel.startGrab();

                    if obj.cancelStart
                        obj.cancelStart = false;
                        obj.hModel.abort();
                    end
                catch ME
                    warndlg(ME.message,'ScanImage');
                    rethrow(ME);
                end
            end
        end
        
        function loopButton(obj)
            if strcmpi(obj.hModel.acqState,'idle')
                try
                    if ~obj.hModel.hCycleManager.enabled
                        obj.hModel.startLoop();
                    else
                        obj.hModel.startCycle();
                    end

                    if obj.cancelStart
                        obj.cancelStart = false;
                        obj.hModel.abort();
                    end
                catch ME
                    warndlg(ME.message,'ScanImage');
                    rethrow(ME);
                end
            end
        end
        
        function abortButton(obj)
            if obj.hModel.hCycleManager.enabled
                obj.hModel.hCycleManager.abort();
            end

            if obj.hModel.acqInitInProgress
                fAbort = obj.hGUIData.mainControlsV4.fAbort;
                gAbort = obj.hGUIData.mainControlsV4.gAbort;
                lAbort = obj.hGUIData.mainControlsV4.lAbort;
                
                obj.cancelStart = true;
                set([fAbort gAbort lAbort],'Enable','off');
            else
                obj.hModel.abort();
            end
        end
        
        %%% IMAGE FUNCTION CALLBACKS
        function showChannelDisplay(obj,channelIdx)
            set(obj.hModel.hDisplay.hFigs(channelIdx),'visible','on');
        end
        
        function showMergeDisplay(obj,channelIdx)
            if ~obj.hModel.hDisplay.channelsMergeEnable
                obj.hModel.hDisplay.channelsMergeEnable = true;
            end
        end
        
        function linePhaseImageFunction(obj,fcnName)
            hFig = obj.zzzSelectImageFigure();
            if isempty(hFig)
                return;
            end
            
            allChannelFigs = [obj.hModel.hDisplay.hFigs(1:obj.hModel.hChannels.channelsAvailable)];
            [tf,chanIdx] = ismember(hFig,allChannelFigs);
            if tf
                feval(fcnName,obj.hModel.hScan2D,chanIdx);
            end
        end
        
        function toggleLineScan(obj,src,evnt)
            lineScanEnable = get(src,'Value');
            if lineScanEnable
                obj.hModel.lineScanCacheParams();
                obj.hModel.hRoiManager.forceSquarePixels = false;
                obj.hModel.hRoiManager.scanAngleMultiplierSlow = 0;
                set(obj.hGUIData.mainControlsV4.etScanAngleMultiplierSlow,'Enable','inactive');
            else
                set(obj.hGUIData.mainControlsV4.etScanAngleMultiplierSlow,'Enable','on');
                obj.hModel.lineScanRestoreParams();
            end
        end
        
        function changedUserFunctionsCfg(obj,~,~)
            switch obj.userFunctionsViewType
                case 'CFG'
                    obj.hGUIData.userFunctionControlsV4.uft.refresh();
            end
        end
        
        function changedUserFunctionsUsr(obj,~,~)
            switch obj.userFunctionsViewType
                case 'USR'
                    obj.hGUIData.userFunctionControlsV4.uft.refresh();
            end
        end
        
        function addMotorCalibrationPoints(obj)
            autoRead = get(obj.hGUIData.motorsAlignmentControls.cbStagePositionAutoRead,'Value');
            if autoRead
                obj.hModel.hMotors.addCalibrationPoint();
            else
                x = str2double(get(obj.hGUIData.motorsAlignmentControls.etXStagePosition,'String'));
                y = str2double(get(obj.hGUIData.motorsAlignmentControls.etYStagePosition,'String'));
                obj.hModel.hMotors.addCalibrationPoint([x,y]);
            end
        end
        
        function ziniMotorAlignmentControls(obj)
            most.ErrorHandler.addCatchingListener(obj.hModel.hMotors.hCSAlignment,'changed',@(varargin)obj.changedMotorToRefTransform);
            obj.hCSListeners = [obj.hCSListeners ];
            
            obj.changedMotorToRefTransform();
        end
        
        function changedMotorToRefTransform(obj)
            T = obj.hModel.hMotors.hCSAlignment.toParentAffine;
            % convert to 2D transform
            T(:,3) = [];
            T(3,:) = [];
            
            [offsetX,offsetY,scaleX,scaleY,rotation,shear] = scanimage.mroi.util.paramsFromTransform(T);
            
            T = obj.hModel.hMotors.hCSMicron.toParentAffine;
            scaleX = T(1);
            scaleY = T(6);
            
            motorsAlignmentControls = obj.hGUIData.motorsAlignmentControls;
            motorsAlignmentControls.etStageRotation. String = sprintf('%.2f',rotation);
            motorsAlignmentControls.etStageShear.String = sprintf('%.2f',shear);
            motorsAlignmentControls.etStageAspectRatio.String = sprintf('%.2f',scaleX/scaleY);
        end
        
        function changedMotorsCalibrationPoints(obj,~,~)
            numPts = size(obj.hModel.hMotors.calibrationPoints,1);
            set(obj.hGUIData.motorsAlignmentControls.etNumberCalibrationPoints,'String',num2str(numPts));
            
            pts = double.empty(0,3);
            if ~isempty(obj.hModel.hMotors.calibrationPoints)
                pts = obj.hModel.hMotors.calibrationPoints(:,2);
                pts = vertcat(pts{:});
            end
            
            obj.hModel.hMotionManager.motionMarkersXY = pts;
            
            if size(pts,1)>0
                obj.showGUI('MotionDisplay');
            end
        end
        
        function updateScanType(obj,varargin)
            switch obj.hModel.hRoiManager.scanType
                case 'frame'
                    set(obj.hGUIData.configControlsV4.pmScanType, 'value', 1);
                    
                case 'line'
                    set(obj.hGUIData.configControlsV4.pmScanType, 'value', 2);
            end
            
            obj.updateScanControls();
        end
        
        function changeScanType(obj,v)
            v = strsplit(v);
            obj.hModel.hRoiManager.scanType = lower(v{1});
        end
        
        function updateScanControls(obj,varargin)
            if obj.hModel.hConfigurationSaver.cfgLoadingInProgress
                return;
            end
            
            stdCtls = [obj.hGUIData.mainControlsV4.stScanRotation obj.hGUIData.mainControlsV4.scanRotation obj.hGUIData.mainControlsV4.scanRotationSlider obj.hGUIData.mainControlsV4.zeroRotate...
                obj.hGUIData.mainControlsV4.stScanShiftFast obj.hGUIData.mainControlsV4.scanShiftFast obj.hGUIData.mainControlsV4.stScanShiftSlow obj.hGUIData.mainControlsV4.scanShiftSlow...
                obj.hGUIData.mainControlsV4.zoomText obj.hGUIData.mainControlsV4.zoomtens obj.hGUIData.mainControlsV4.zoomtensslider obj.hGUIData.mainControlsV4.zoomones...
                obj.hGUIData.mainControlsV4.zoomonesslider obj.hGUIData.mainControlsV4.stScanAngleMultiplier obj.hGUIData.mainControlsV4.zoomfrac obj.hGUIData.mainControlsV4.zoomfracslider...
                obj.hGUIData.mainControlsV4.fullfield obj.hGUIData.mainControlsV4.up obj.hGUIData.mainControlsV4.down obj.hGUIData.mainControlsV4.left obj.hGUIData.mainControlsV4.right...
                obj.hGUIData.mainControlsV4.zero obj.hGUIData.mainControlsV4.ystep obj.hGUIData.mainControlsV4.xstep obj.hGUIData.mainControlsV4.text50 obj.hGUIData.configControlsV4.pmPixelsPerLine...
                obj.hGUIData.mainControlsV4.stScanAngleMultiplierFast obj.hGUIData.mainControlsV4.etScanAngleMultiplierFast obj.hGUIData.mainControlsV4.stScanAngleMultiplierSlow...
                obj.hGUIData.mainControlsV4.etScanAngleMultiplierSlow obj.hGUIData.mainControlsV4.tbToggleLinescan obj.hGUIData.configControlsV4.text3 obj.hGUIData.configControlsV4.etPixelsPerLine...
                obj.hGUIData.configControlsV4.text1 obj.hGUIData.configControlsV4.cbForceSquarePixelation obj.hGUIData.configControlsV4.cbForceSquarePixel];
            
            nonLineCtlsEn = [obj.hGUIData.configControlsV4.etScanPhase obj.hGUIData.configControlsV4.etScanPhase...
                obj.hGUIData.configControlsV4.pbCalibrateLinePhase obj.hGUIData.configControlsV4.etLineRate...
                obj.hGUIData.configControlsV4.scanPhaseSlider obj.hGUIData.imageControlsV4.pmVolumeStyle];
            nonLineCtlsVis = [obj.hGUIData.configControlsV4.text3 obj.hGUIData.configControlsV4.etPixelsPerLine...
                obj.hGUIData.configControlsV4.pmPixelsPerLine obj.hGUIData.configControlsV4.text1...
                obj.hGUIData.configControlsV4.etLinesPerFrame obj.hGUIData.configControlsV4.cbForceSquarePixelation...
                obj.hGUIData.configControlsV4.cbForceSquarePixel obj.hGUIData.imageControlsV4.etZSelection];
            lineCtls = [obj.hGUIData.configControlsV4.cbFeedback obj.hGUIData.imageControlsV4.etLineHistoryLength];
            
             nonPolyCtls = [obj.hGUIData.mainControlsV4.stScanRotation obj.hGUIData.mainControlsV4.scanRotation obj.hGUIData.mainControlsV4.scanRotationSlider obj.hGUIData.mainControlsV4.zeroRotate...
                obj.hGUIData.mainControlsV4.stScanShiftFast obj.hGUIData.mainControlsV4.scanShiftFast obj.hGUIData.mainControlsV4.stScanShiftSlow obj.hGUIData.mainControlsV4.scanShiftSlow...
                obj.hGUIData.mainControlsV4.zoomText obj.hGUIData.mainControlsV4.zoomtens obj.hGUIData.mainControlsV4.zoomtensslider obj.hGUIData.mainControlsV4.zoomones...
                obj.hGUIData.mainControlsV4.zoomonesslider obj.hGUIData.mainControlsV4.stScanAngleMultiplier obj.hGUIData.mainControlsV4.zoomfrac obj.hGUIData.mainControlsV4.zoomfracslider...
                obj.hGUIData.mainControlsV4.fullfield obj.hGUIData.mainControlsV4.up obj.hGUIData.mainControlsV4.down obj.hGUIData.mainControlsV4.left obj.hGUIData.mainControlsV4.right...
                obj.hGUIData.mainControlsV4.zero obj.hGUIData.mainControlsV4.ystep obj.hGUIData.mainControlsV4.xstep obj.hGUIData.mainControlsV4.text50 obj.hGUIData.configControlsV4.pmPixelsPerLine...
                obj.hGUIData.mainControlsV4.stScanAngleMultiplierFast obj.hGUIData.mainControlsV4.etScanAngleMultiplierFast obj.hGUIData.mainControlsV4.stScanAngleMultiplierSlow...
                obj.hGUIData.mainControlsV4.etScanAngleMultiplierSlow obj.hGUIData.mainControlsV4.tbToggleLinescan obj.hGUIData.configControlsV4.pbCalibrateLinePhase];
            
            if obj.hModel.hRoiManager.mroiEnable || strcmp(obj.hModel.hRoiManager.scanType, 'line')
                set(stdCtls,'Enable','off');
            else
                set(stdCtls,'Enable','on');
            end
            
            obj.changedForceSquarePixelation();
            
            tfLine = strcmp(obj.hModel.hRoiManager.scanType, 'line');
            set(obj.hGUIData.configControlsV4.pbCalibrateFeedback,'Visible','off');
            set(nonLineCtlsEn,'Enable',obj.tfMap(~tfLine));
            set(nonLineCtlsVis,'Visible',obj.tfMap(~tfLine));
            set(obj.hGUIData.mainControlsV4.cbEnableMroi,'Enable',obj.tfMap(~tfLine));
            set(obj.hGUIData.configControlsV4.cbBidirectionalScan,'Visible',obj.tfMap(~tfLine));
            set(obj.hGUIData.configControlsV4.pbEditRois,'Visible',obj.tfMap(tfLine));
            set(lineCtls,'Visible',obj.tfMap(tfLine));
            if tfLine
                set(obj.hGUIData.configControlsV4.stFrameRate,'string','Cycle Rate (Hz)');
                
                set(obj.hGUIData.configControlsV4.pmScanRateVar, 'Value', 1);
                set(obj.hGUIData.configControlsV4.pmScanRateVar, 'String', {'Sample Rate (MHz)'});
                
                set(obj.hGUIData.configControlsV4.slLineRate,'Enable','off');
                set(obj.hGUIData.configControlsV4.etLineRate, 'Enable', 'on');
                
                set(obj.hGUIData.configControlsV4.cbFeedback, 'Enable', obj.tfMap(obj.hModel.hScan2D.hTrig.enabled));
                
                set(obj.hGUIData.imageControlsV4.stZsel, 'String', 'History Frame Length');
            else
                set(obj.hGUIData.configControlsV4.stFrameRate,'string','Frame Rate (Hz)');
                
                set(obj.hGUIData.configControlsV4.pmScanRateVar, 'Value', 1);
%                 set(obj.hGUIData.configControlsV4.pmScanRateVar, 'String', {'Pixel Dwell Time (ns)' 'Line Rate (Hz)' 'Line Period (us)' 'Sample Rate (MHz)'});
                
                tfRes = strcmp(obj.hModel.hScan2D.scanMode, 'resonant');
                set(obj.hGUIData.configControlsV4.slLineRate,'Enable',obj.tfMap(~tfRes));
                set(obj.hGUIData.configControlsV4.slLineRate,'Visible','on');
                if tfRes
                    set(obj.hGUIData.configControlsV4.pmScanRateVar, 'Value', 1);
                    set(obj.hGUIData.configControlsV4.etLineRate,'Enable','inactive');
                    set(obj.hGUIData.configControlsV4.pmScanRateVar, 'String', {'Pixel Dwell Time (ns)' 'Line Rate (Hz)' 'Line Period (us)'});
                else
                    set(obj.hGUIData.configControlsV4.etLineRate,'Enable','on');
                    set(obj.hGUIData.configControlsV4.pmScanRateVar, 'String', {'Pixel Dwell Time (ns)' 'Line Rate (Hz)' 'Line Period (us)' 'Sample Rate (MHz)'});
                end
                
                set(obj.hGUIData.imageControlsV4.stZsel, 'String', 'Display Z Selection');
            end
            
            obj.changedLineRateVar();
                       
            if isprop(obj.hModel.hScanner, 'isPolygonalScanner') && obj.hModel.hScanner.isPolygonalScanner %&& ~isempty(pnlScanParams)
                set(nonPolyCtls,'Enable','off');
            end
        end
        
%         function editImagingRoiGroup(obj)
%             obj.mroiGuiSetGroup(obj.hModel.hRoiManager.roiGroupMroi, 'ImagingField');
%             obj.showGUI('RoiGroupEditor');
%         end

        function editImagingRoiGroup(obj,tfShow)
            if nargin < 2 || tfShow
                obj.hRoiGroupEditor.Visible = true;
            end
            
            if obj.hModel.hRoiManager.isLineScan
                obj.hRoiGroupEditor.setEditorGroupAndMode(obj.hModel.hRoiManager.roiGroupLineScan,obj.hModel.hScan2D.scannerset,'stimulation');
                obj.hRoiGroupEditor.defaultStimPower = [];
            else
                obj.hRoiGroupEditor.setEditorGroupAndMode(obj.hModel.hRoiManager.roiGroupMroi,obj.hModel.hScan2D.scannerset,'imaging');
            end
        end
    end
    
    %% FRIEND METHODS
    %%%  APP PROPERTY CALLBACKS 
    %%%  Methods named changedXXX(src,...) respond to changes to model, which should update the controller/GUI
    %%%  Methods named changeXXX(hObject,...) respond to changes to GUI, which should update the model %}
    methods (Hidden)
        %%% IMAGING SYSTEM METHODS
        function changedImagingSystem(obj,~,~)
            obj.changedScanMode();            
            obj.reprocessSubMdlPropBindings('hScan2D');
        end
        
        function changedScanMode(obj,~,~)
            hS2d = obj.hModel.hScan2D;
            nm = sprintf('%s (%s)',hS2d.name,upper1(hS2d.scanMode));
            [tf,id] = ismember(nm, obj.imagingSystemList);
            if ~tf
                [~,id] = ismember(obj.hModel.imagingSystem, obj.imagingSystemList);
            end
            set(obj.hGUIData.configControlsV4.pmImagingSystem, 'Value', id);
            
            persistent hImagingSystem_
            persistent mode_
            if ~isempty(hImagingSystem_) && isequal(hImagingSystem_,obj.hModel.hScan2D) && ...
                    ~isempty(mode_) && strcmp(mode_,obj.hModel.hScan2D.scanMode)
                return
            end
            
            obj.ziniChannelControls();
            obj.ziniTriggers();
            obj.changeFastZCfg();
            obj.ziniPhotonCountingCtrls();

            allInactiveControls = {...
                'etPixelTimeMean'...
                'etPixelTimeMaxMinRatio'...
                'etLinePeriod'};
            
            slmDisableControls = {...
                'scanPhaseSlider'...
                'pmScanRateVar'...
                'etLineRate'...
                'etFillFrac'...
                'etFillFracSpatial'...
                'etPixelTimeMean'...
                'etPixelTimeMaxMinRatio'...
                'etLinePeriod'...
                'etPixelBinFactor'...
                'etFlybackTimePerFrameMs'};
            slmDisableControls{end+1} = 'etFlytoTimePerScanfieldMs';
            enableControls(slmDisableControls,'on');
            enableControls(allInactiveControls,'inactive');
            
            switch obj.hModel.hScan2D.scanMode
                case 'resonant'
                    set(obj.hGUIData.configControlsV4.cbKeepScannerOn, 'Visible', 'on');
                    set(obj.hGUIData.configControlsV4.pbMeasureFrameRate, 'enable', 'on');
                    
                    set(obj.hGUIData.configControlsV4.cbStripingEnable, 'Visible', 'off');
                    
                    set(obj.hGUIData.configControlsV4.pmScanType, 'Visible', 'off');
                    set(obj.hGUIData.configControlsV4.stScanType, 'Visible', 'off');
                    
                    set(obj.hGUIData.configControlsV4.cbUniformSampling, 'Enable', 'on');

                    if obj.hModel.hScan2D.uniformSampling
                        set(obj.hGUIData.configControlsV4.etPixelBinFactor, 'Enable', 'on');
                    else
                        set(obj.hGUIData.configControlsV4.etPixelBinFactor, 'Enable', 'inactive');
                    end

                    set(obj.hGUIData.configControlsV4.etSampleRateMHz, 'Enable', 'inactive');
                    
                    set(obj.hGUIData.configControlsV4.pbShowSlmControls, 'Visible', 'off');
                    set(obj.hGUIData.configControlsV4.cbCenterSlm, 'Visible', 'off');
                case 'linear'
                    set(obj.hGUIData.configControlsV4.cbKeepScannerOn, 'Visible', 'off');
                    set(obj.hGUIData.configControlsV4.pbMeasureFrameRate, 'enable', 'off');
                    
                    set(obj.hGUIData.configControlsV4.cbStripingEnable, 'Visible', 'on');
                    
                    set(obj.hGUIData.configControlsV4.pmScanType, 'Visible', 'on');
                    set(obj.hGUIData.configControlsV4.stScanType, 'Visible', 'on');
                    
                    set(obj.hGUIData.configControlsV4.cbUniformSampling, 'Enable', 'off');
                    set(obj.hGUIData.configControlsV4.etPixelBinFactor, 'Enable', 'on');
                    set(obj.hGUIData.configControlsV4.etSampleRateMHz, 'Enable', 'on');
                    
                    set(obj.hGUIData.configControlsV4.pbShowSlmControls, 'Visible', 'off');
                    
                    set(obj.hGUIData.configControlsV4.cbCenterSlm, 'Visible', 'on');
                    if most.idioms.isValidObj(obj.hModel.hSlmScan)
                        set(obj.hGUIData.configControlsV4.cbCenterSlm, 'Enable', 'on');
                    else
                        set(obj.hGUIData.configControlsV4.cbCenterSlm, 'Enable', 'off');
                    end
                    
                case 'slm'
                    set(obj.hGUIData.configControlsV4.cbKeepScannerOn, 'Visible', 'off');
                    set(obj.hGUIData.configControlsV4.pbMeasureFrameRate, 'enable', 'off');
                    
                    set(obj.hGUIData.configControlsV4.cbStripingEnable, 'Visible', 'off');
                    
                    set(obj.hGUIData.configControlsV4.pmScanType, 'Visible', 'off');
                    set(obj.hGUIData.configControlsV4.stScanType, 'Visible', 'off');
                    
                    set(obj.hGUIData.configControlsV4.cbUniformSampling, 'Enable', 'off');
                    set(obj.hGUIData.configControlsV4.etPixelBinFactor,'Enable', 'off');
                    set(obj.hGUIData.configControlsV4.etSampleRateMHz, 'Enable', 'on');
                    
                    set(obj.hGUIData.configControlsV4.pbShowSlmControls, 'Visible', 'on');
                    set(obj.hGUIData.configControlsV4.cbCenterSlm, 'Visible', 'off');
                    
                    enableControls(slmDisableControls,'off');
                otherwise
                    error('Unknown Scan2D class: %s',class(obj.hModel.hScan2D));
            end
            
            % View MenuChannel 1 is never disabled.
            viewMenuChannelsEnabled = {};
            viewMenuChannelsDisabled = {};
            
            switch (obj.hModel.hChannels.channelsAvailable)
                case {1}
                    viewMenuChannelsDisabled = {'mnu_View_Channel2Display' 'mnu_View_Channel3Display' 'mnu_View_Channel4Display'};
                case {2}
                    viewMenuChannelsDisabled = {'mnu_View_Channel3Display' 'mnu_View_Channel4Display'};
                    viewMenuChannelsEnabled = {'mnu_View_Channel2Display'};
                case {3}
                    viewMenuChannelsDisabled = {'mnu_View_Channel4Display'};
                    viewMenuChannelsEnabled = {'mnu_View_Channel2Display' 'mnu_View_Channel3Display'};
               case {4}
                   viewMenuChannelsEnabled = {'mnu_View_Channel2Display' 'mnu_View_Channel3Display' 'mnu_View_Channel4Display'};
            end
            
            cellfun(@(s)set(obj.hGUIData.mainControlsV4.(s),'Enable','off'),viewMenuChannelsDisabled);
            cellfun(@(s)set(obj.hGUIData.mainControlsV4.(s),'Enable','on'),viewMenuChannelsEnabled);

            obj.ziniImageControls();
%             obj.ziniPowerBoxControls();
            obj.cfgLinePhaseSlider();
            obj.updateScanControls();
            
            ds = obj.hGuiClasses.DataScope;
            ds.hDataScope = obj.hModel.hScan2D.hDataScope;
            
            hImagingSystem_ = obj.hModel.hScan2D;
            mode_ = obj.hModel.hScan2D.scanMode;
            
            function enableControls(ctrls,status) 
                cellfun(@(ctrl)set(obj.hGUIData.configControlsV4.(ctrl),'Enable',status),ctrls);
            end
            
            function s = upper1(s)
                s = [upper(s(1)) s(2:end)];
            end
        end % function - changedImagingSystem
        
        function changeImagingSystem(obj,hObject)
            sys = get(hObject,'String');
            % If switching to a different scanner, make sure the resonant
            % scanner is turned off.
            if ~strcmp(obj.hModel.imagingSystem, sys{get(hObject,'Value')})
                obj.hModel.hScan2D.keepResonantScannerOn = 0;
            end
            obj.hModel.imagingSystem = sys{get(hObject,'Value')};
            
            pbCalibrateLinePhase = findobj('Tag', 'pbCalibrateLinePhase');
            if isprop(obj.hModel.hScanner, 'isPolygonalScanner') && obj.hModel.hScanner.isPolygonalScanner
                pbCalibrateLinePhase.Enable = 'off';
            else
                pbCalibrateLinePhase.Enable = 'on';
            end
        end
        
        %%% TIMER METHODS
        function changedSecondsCounter(obj,~,~)
            %TODO: make value of 0 'sticky' for 0.3-0.4s using a timer object here
            hSecCntr = obj.hGUIData.mainControlsV4.secondsCounter;
            
            switch obj.hModel.secondsCounterMode
                case 'up' %countup timer
                    set(hSecCntr,'String',num2str(max(0,floor(obj.hModel.secondsCounter))));
                case 'down'  %countdown timer
                    set(hSecCntr,'String',num2str(max(0,ceil(obj.hModel.secondsCounter))));
                otherwise
                    set(hSecCntr,'String','0');
            end
        end
        
        %%% DISPLAY METHODS
        function changedDisplayRollingAverageFactorLock(obj,~,~)
            if obj.hModel.hDisplay.displayRollingAverageFactorLock
                set(obj.hGUIData.imageControlsV4.etRollingAverage,'Enable','off');
            else
                set(obj.hGUIData.imageControlsV4.etRollingAverage,'Enable','on');
            end
        end
        
        function displaySelectedZsChanged(obj,varargin)
            if isempty(obj.hModel.hDisplay.selectedZs)
                str = '[All]';
            else
                str = mat2str(obj.hModel.hDisplay.selectedZs);
            end
            set(obj.hGUIData.imageControlsV4.etZSelection,'string',str)
        end
        
        function displayChangeSelectedZs(obj,str)
            if isempty(str) || strcmp(str,'[All]')
                obj.hModel.hDisplay.selectedZs = [];
            else
                obj.hModel.hDisplay.selectedZs = str2num(str);
            end
        end
        
        function displayChange3dStyle(obj,v)
            obj.hModel.hDisplay.volumeDisplayStyle = v;
        end
        
        function display3dStyleChanged(obj,varargin)
            switch obj.hModel.hDisplay.volumeDisplayStyle
                case '3D'
                    set(obj.hGUIData.imageControlsV4.pmVolumeStyle, 'value', 1);
            
                case 'Tiled'
                    set(obj.hGUIData.imageControlsV4.pmVolumeStyle, 'value', 2);
                    
                case 'Current'
                    set(obj.hGUIData.imageControlsV4.pmVolumeStyle, 'value', 3);
                    
                case 'Max'
                    set(obj.hGUIData.imageControlsV4.pmVolumeStyle, 'value', 4);
            end
        end
        
        function channelAutoScale(obj,ch)
            obj.hModel.hDisplay.channelAutoScale(ch);
        end
        
        function channelToggleButton(obj,ch)
            if ch
                % channel N
                didx = ch == obj.hModel.hChannels.channelDisplay;
                dsplyed = any(didx);
                if ~dsplyed
                    obj.hModel.hChannels.channelDisplay = [obj.hModel.hChannels.channelDisplay ch];
                    
                    %make sure the line above succeeded
                    if ~any(ch == obj.hModel.hChannels.channelDisplay)
                        set(obj.hGUIData.imageControlsV4.(sprintf('tbCh%d',ch)), 'Value', false);
                        return;
                    end
                    set(obj.hGUIData.imageControlsV4.(sprintf('tbCh%d',ch)), 'Value', true);
                end
                
                if obj.hModel.active
                    most.idioms.figure(obj.hModel.hDisplay.hFigs(ch));
                    set(obj.hGUIData.imageControlsV4.(sprintf('tbCh%d',ch)), 'Value', true);
                else
                    if dsplyed
                        obj.hModel.hChannels.channelDisplay(didx) = [];
                        obj.hModel.hDisplay.hFigs(ch).Visible = 'off';
                        set(obj.hGUIData.imageControlsV4.(sprintf('tbCh%d',ch)), 'Value', false);
                    else
                        most.idioms.figure(obj.hModel.hDisplay.hFigs(ch));
                    end
                end
            else
                % merge
                obj.hModel.hDisplay.channelsMergeEnable = ~obj.hModel.hDisplay.channelsMergeEnable;
            end
        end
        
        function saStep(obj,fast,slow)
            mult = 0.1 / obj.hModel.hRoiManager.scanZoomFactor;
            if fast ~= 0
                obj.hModel.hRoiManager.scanAngleShiftFast = obj.hModel.hRoiManager.scanAngleShiftFast + fast*mult;
            end
            if slow ~= 0
                obj.hModel.hRoiManager.scanAngleShiftSlow = obj.hModel.hRoiManager.scanAngleShiftSlow + slow*mult;
            end
        end
        
        function zeroScanAngle(obj)
            obj.hModel.hRoiManager.scanAngleShiftFast = 0;
            obj.hModel.hRoiManager.scanAngleShiftSlow = 0;
        end
        
        %% BEAM METHODS
        %GUI        
        function changedPowerBoxes(obj,~,~)
            obj.ziniPowerBoxControls();
            
            i = obj.pbIdx;
            if i <= numel(obj.hModel.hBeams.powerBoxes)
                pb = obj.hModel.hBeams.powerBoxes(i);
                set(obj.hGUIData.powerBoxControlsV4.etPowers,'String',num2str(pb.powers * 100));
                if obj.hGUIData.powerBoxControlsV4.rbFraction == get(obj.hGUIData.powerBoxControlsV4.unitPanel, 'SelectedObject')
                    %units are fraction
                    r = pb.rect;
                    s = num2str(r,'%.3f ');
                else
                    %units are pixels
                    sz = [obj.hModel.hRoiManager.pixelsPerLine obj.hModel.hRoiManager.linesPerFrame];
                    r = floor(pb.rect .* [sz sz]);
                    s = num2str(r,'%d   ');
                end
                set(obj.hGUIData.powerBoxControlsV4.etPosition,'String',s);
                obj.powerBoxUpdateBoxFigure();
            end
            
            obj.updateOtherPbs();
        end
        
        function updateOtherPbs(obj)
            i = obj.pbIdx;
            n = numel(obj.hModel.hBeams.powerBoxes);
            nOth = n - (i <= n);
            while numel(obj.hPowbOthers) < (nOth)
                obj.hPowbOthers(end+1) = surface([.25 .75],[.25 .75],0.5*ones(2),'Parent',obj.hPowbAx,'Hittest','off','FaceColor',[.5 .5 .5],...
                    'EdgeColor',[.5 .5 .5],'LineWidth',1.5,'FaceLighting','none','FaceAlpha',0.2,'visible','off');
                obj.hOthTexts(end+1) = text(.25,.25,.5,'Power Box','Parent',obj.hPowbAx,'visible','off','color','y','Hittest','on');
            end
            delete(obj.hPowbOthers(nOth+1:end));
            delete(obj.hOthTexts(nOth+1:end));
            obj.hPowbOthers(nOth+1:end) = [];
            obj.hOthTexts(nOth+1:end) = [];
            
            nms = {};
            for pb = obj.hModel.hBeams.powerBoxes
                nms{end+1} = pb.name;
                if isempty(nms{end})
                    nms{end} = sprintf('Power Box %d', numel(nms));
                end
            end
            
            oths = setdiff(1:n,i);
            for i = 1:nOth
                r = obj.hModel.hBeams.powerBoxes(oths(i)).rect;
                set(obj.hPowbOthers(i), 'XData', [r(1) r(1)+r(3)]);
                set(obj.hPowbOthers(i), 'YData', [r(2) r(2)+r(4)]);
                set(obj.hPowbOthers(i), 'visible','on');
                set(obj.hOthTexts(i), 'Position', [r(1)+.01 r(2)+.03 .75],'visible','on');
                set(obj.hOthTexts(i), 'String', nms{oths(i)});
                set(obj.hOthTexts(i), 'ButtonDownFcn', @(varargin)selPb(oths(i)));
            end
            
            function selPb(n)
                obj.pbIdx = n;
            end
        end
        
        function changePowerBoxRect(obj,~,~)
            i = obj.pbIdx;
            if i <= numel(obj.hModel.hBeams.powerBoxes)
                pb = obj.hModel.hBeams.powerBoxes(i);
                u = str2num(get(obj.hGUIData.powerBoxControlsV4.etPosition,'String'));
                if obj.hGUIData.powerBoxControlsV4.rbFraction == get(obj.hGUIData.powerBoxControlsV4.unitPanel, 'SelectedObject')
                    %units are fraction
                    pb.rect = u;
                else
                    %units are pixels
                    sz = [obj.hModel.hRoiManager.pixelsPerLine obj.hModel.hRoiManager.linesPerFrame];
                    pb.rect = u ./ [sz sz];
                end
                obj.hModel.hBeams.powerBoxes(i) = pb;
            end
        end
        
        function changePowerBoxPowers(obj,~,~)
            i = obj.pbIdx;
            if i <= numel(obj.hModel.hBeams.powerBoxes)
                v = str2num(get(obj.hGUIData.powerBoxControlsV4.etPowers,'String'));
                v = v/100; % conventionally use percent in GUI
                obj.hModel.hBeams.powerBoxes(i).powers = v;
            end
        end
        
        function powerBoxUpdateBoxFigure(obj)
            if obj.hModel.hBeams.numInstances <= 0
                return;
            end
            
            i = obj.pbIdx;
            if i <= numel(obj.hModel.hBeams.powerBoxes)
                pb = obj.hModel.hBeams.powerBoxes(i);
                x1 = pb.rect(1);
                x2 = pb.rect(1)+pb.rect(3);
                y1 = pb.rect(2);
                y2 = pb.rect(2)+pb.rect(4);
                
                set(obj.hPowbBoxSurf,'XData',[x1 x2],'YData',[y1 y2]);
                
                if isempty(pb.mask)
                    obj.hPowbBoxSurf.CData = shiftdim([1 0 0],-1);
                    obj.hPowbBoxSurf.AlphaData = 1;
                else
                    red = zeros(size(pb.mask,1),size(pb.mask,2),3);
                    red(:,:,1) = 1;
                    obj.hPowbBoxSurf.CData = red;
                    obj.hPowbBoxSurf.AlphaData = pb.mask;
                end
                obj.hPowbAx.ALim = [0 1] * 2; % factor of 2 to make surface semi transparent
                
                set(obj.hPowbBoxCtr,'XData',(x1+x2)*.5,'YData',(y1+y2)*.5);
                set([obj.hPowbBoxTL obj.hPowbBoxBL],'XData',x1);
                set([obj.hPowbBoxTR obj.hPowbBoxBR],'XData',x2);
                set([obj.hPowbBoxTL obj.hPowbBoxTR],'YData',y1);
                set([obj.hPowbBoxBL obj.hPowbBoxBR],'YData',y2);
                
                set([obj.hPowbBoxT obj.hPowbBoxB],'XData',[x1 x2]);
                set(obj.hPowbBoxL,'XData',[x1 x1]);
                set(obj.hPowbBoxR,'XData',[x2 x2]);
                set([obj.hPowbBoxL obj.hPowbBoxR],'YData',[y1 y2]);
                set(obj.hPowbBoxT,'YData',[y1 y1]);
                set(obj.hPowbBoxB,'YData',[y2 y2]);
                
                if isempty(pb.name)
                    nm = sprintf('Power Box %d', i);
                else
                    nm = pb.name;
                end
                set(obj.hText, 'Position', [x1+.01 y1+.03 2]);
                set(obj.hText, 'String', nm);
            end
        end
        
        function deletePowerBox(obj)
            i = obj.pbIdx;
            if i <= numel(obj.hModel.hBeams.powerBoxes)
                if i > 1
                    set(obj.hGUIData.powerBoxControlsV4.pmPbSel,'Value',i-1);
                end
                obj.hModel.hBeams.powerBoxes(i) = [];
                obj.ziniPowerBoxControls();
            end
        end
        
        function selectPowerBox(obj)
            if obj.pbIdx > numel(obj.hModel.hBeams.powerBoxes)
                obj.hModel.hBeams.powerBoxes(obj.pbIdx) = scanimage.components.beams.PowerBox(obj.hModel.hBeams);
                obj.ziniPowerBoxControls();
            else
                obj.changedPowerBoxes();
            end
        end
        
        function powerBoxGuiCopyChannel(obj,idx)
            try
                imdata = obj.hModel.hDisplay.lastAveragedFrame;
                imChannels = obj.hModel.hDisplay.lastFrameChannels;
                imdata = imdata(imChannels == idx);
                
                if isempty(imdata)
                    error('Channel not available');
                end
                
                imdata = single( imdata{1} );
                lut = single(obj.hModel.hChannels.channelLUT{idx});
                maxVal = single(255);
                scaledData = uint8((imdata - lut(1)) .* (maxVal / (lut(2)-lut(1))));
                set(obj.hPowbCtxIm, 'cdata', repmat(scaledData,1,1,3));
            catch
                most.idioms.warn('No image data found.');
                set(obj.hPowbCtxIm, 'cdata', zeros(2,2,3,'uint8'));
            end
        end
        
        function p = getPbPt(obj)
            p = get(obj.hPowbAx,'CurrentPoint');
            p = p([1 3]);
        end
        
        function powbScrollWheelFcn(obj, ~, evt)
            mv = double(evt.VerticalScrollCount) * 1;%evt.VerticalScrollAmount;
            
            % find old range and center
            xlim = get(obj.hPowbAx,'xlim');
            ylim = get(obj.hPowbAx,'ylim');
            rg = xlim(2) - xlim(1);
            ctr = 0.5*[sum(xlim) sum(ylim)];
            
            % calc and constrain new half range
            nrg = min(1,rg*.75^-mv);
            nrg = max(0.0078125,nrg);
            nhrg = nrg/2;
            
            %calc new center based on where mouse is
            pt = obj.getPbPt;
            odfc = pt - ctr; %original distance from center
            ndfc = odfc * (nrg/rg); %new distance from center
            nctr = pt - [ndfc(1) ndfc(2)];
            
            %constrain center
            nctr = max(min(nctr,1-nhrg),nhrg);
            
            % new lims
            xlim = [-nhrg nhrg] + nctr(1);
            ylim = [-nhrg nhrg] + nctr(2);
            set(obj.hPowbAx,'xlim',xlim,'ylim',ylim);
        end
        
        function powbPanFcn(obj,starting,stopping)
            persistent prevpt;
            persistent ohrg;
            
            if starting
                if strcmp(get(obj.hGUIs.powerBoxControlsV4,'SelectionType'), 'normal')
                    % left click
                    prevpt = obj.getPbPt;
                    
                    xlim = get(obj.hPowbAx,'xlim');
                    ohrg = (xlim(2) - xlim(1))/2;
                    
                    set(obj.hGUIs.powerBoxControlsV4,'WindowButtonMotionFcn',@(varargin)obj.powbPanFcn(false,false),'WindowButtonUpFcn',@(varargin)obj.powbPanFcn(false,true));
                    waitfor(obj.hGUIs.powerBoxControlsV4,'WindowButtonMotionFcn',[]);
                end
            else
                % find prev center
                xlim = get(obj.hPowbAx,'xlim');
                ylim = get(obj.hPowbAx,'ylim');
                octr = 0.5*[sum(xlim) sum(ylim)];
                
                % calc/constrain new center
                nwpt = obj.getPbPt;
                nctr = octr - (nwpt - prevpt);
                nctr = max(min(nctr,1-ohrg),ohrg);
                
                nxlim = nctr(1) + [-ohrg ohrg];
                nylim = nctr(2) + [-ohrg ohrg];
                
                set(obj.hPowbAx,'xlim',nxlim);
                set(obj.hPowbAx,'ylim',nylim);

                prevpt = obj.getPbPt;
                
                if stopping
                    set(obj.hGUIs.powerBoxControlsV4,'WindowButtonMotionFcn',[],'WindowButtonUpFcn',[]);
                end
            end
        end
        
        function powbCpFunc(obj,chgng,starting,stopping)
            persistent prevpt;
            
            if starting
                if strcmp(get(obj.hGUIs.powerBoxControlsV4,'SelectionType'), 'normal')
                    % left click
                    prevpt = obj.getPbPt;
                    
                    set(obj.hGUIs.powerBoxControlsV4,'WindowButtonMotionFcn',@(varargin)obj.powbCpFunc(chgng,false,false),'WindowButtonUpFcn',@(varargin)obj.powbCpFunc(chgng,false,true));
                    waitfor(obj.hGUIs.powerBoxControlsV4,'WindowButtonMotionFcn',[]);
                end
            else
                nwpt = obj.getPbPt;
                mv = nwpt - prevpt;
                i = obj.pbIdx;
                if i <= numel(obj.hModel.hBeams.powerBoxes)
                    pb = obj.hModel.hBeams.powerBoxes(i);
                    r = pb.rect;
                    osz = r([3 4]);
                    r([3 4]) = osz + r([1 2]);
                    
                    if chgng(1)
                        r(1) = r(1) + mv(1);
                    end
                    
                    if chgng(2)
                        r(2) = r(2) + mv(2);
                    end
                    
                    if chgng(3)
                        r(3) = r(3) + mv(1);
                    end
                    
                    if chgng(4)
                        r(4) = r(4) + mv(2);
                    end
                    
                    if all(chgng)
                        r([3 4]) = osz;
                        lims = 1 - osz;
                        r([1 2]) = min(lims,max(0,r([1 2])));
                    else
                        r([3 4]) = r([3 4]) - r([1 2]);
                    end
                    
                    r(3) = max(0,r(3)); % prevent negative width
                    r(4) = max(0,r(4)); % prevent negative height
                    
                    pb.rect = r;
                    obj.hModel.hBeams.powerBoxes(i) = pb;
                end
                
                if stopping
                    set(obj.hGUIs.powerBoxControlsV4,'WindowButtonMotionFcn',[],'WindowButtonUpFcn',[]);
                else
                    prevpt = nwpt;
                end
            end
        end
        
        %%% Trigger Methods
        function changedTrigNextStopEnable(obj,src,evnt)
            if obj.hModel.hScan2D.trigNextStopEnable
                buttonEnable = 'on';
            else
                buttonEnable = 'off';
            end
            set(obj.hGUIData.triggerControlsV5.pbAcqStop,'Enable',buttonEnable);
            set(obj.hGUIData.triggerControlsV5.pbNextFileMarker,'Enable',buttonEnable);
        end
        
        function changedTrigAcqInTerm(obj,src,evnt)
            if isempty(obj.hModel.hScan2D.trigAcqInTerm)
                triggerButtonEnable = 'off';
            else
                triggerButtonEnable = 'on';
            end
%             set(obj.hGUIData.mainControlsV4.cbExternalTrig,'Enable',triggerButtonEnable);
%             set(obj.hGUIData.triggerControlsV5.pbAcqStart,'Enable',triggerButtonEnable);
        end
        
        %%% CHANNEL METHODS        
        function changedChannelsMergeEnable(obj,src,evt)
            val = obj.hModel.hDisplay.channelsMergeEnable;
            set(obj.hGUIData.imageControlsV4.tbMrg, 'Value', val);
            if val
                set(obj.hGUIData.channelControlsV4.cbChannelsMergeFocusOnly,'Enable','on');
                set(obj.hModel.hDisplay.hMergeFigs,'visible','on');
            else
                set(obj.hGUIData.channelControlsV4.cbChannelsMergeFocusOnly,'Enable','off');
            end
        end
        
        function changedChanLUT(obj,src,evnt)
            chanNum = str2double(regexpi(src.Name,'[0-9]*','Match','Once'));
            
            chanProp = sprintf('chan%dLUT',chanNum);            
            blackVal = obj.hModel.hDisplay.(chanProp)(1);
            whiteVal = obj.hModel.hDisplay.(chanProp)(2);
            
            set(obj.hGUIData.imageControlsV4.(sprintf('blackEditChan%d',chanNum)),'String',num2str(blackVal));
            set(obj.hGUIData.imageControlsV4.(sprintf('whiteEditChan%d',chanNum)),'String',num2str(whiteVal));
            
            hBlackSlider = obj.hGUIData.imageControlsV4.(sprintf('blackSlideChan%d',chanNum));
            hWhiteSlider = obj.hGUIData.imageControlsV4.(sprintf('whiteSlideChan%d',chanNum));
            
            minSliderVal = fix(hBlackSlider.Min);
            maxSliderVal = fix(hWhiteSlider.Max);
            
            blackValSliderVal = min(max(blackVal,minSliderVal),maxSliderVal);
            whiteValSliderVal = min(max(whiteVal,minSliderVal),maxSliderVal);
            
            hBlackSlider.Value = blackValSliderVal;
            hWhiteSlider.Value = whiteValSliderVal;
        end
        
        function changeChannelsLUT(obj,src,blackOrWhite,chanIdx)
            %blackOrWhite: 0 if black, 1 if white
            %chanIdx: Index of channel whose LUT value to change
            switch get(src,'Style')
                case 'edit'
                    newVal = str2double(get(src,'String'));
                case 'slider'
                    newVal = get(src,'Value');
                    %Only support integer values, from slider controls
                    newVal = round(newVal);         
            end
            
            %Erroneous entry
            if isempty(newVal)
                %refresh View
                obj.changedChanLUT(); 
            else
                try
                    obj.hModel.hChannels.channelLUT{chanIdx}(2^blackOrWhite) = newVal;
                catch ME
                    obj.changedChanLUT();
                    obj.updateModelErrorFcn(ME);
                end
            end
        end
                
        %%% PHOTOSTIM METHODS
        function changedPhotostimState(obj,~,~)
            obj.pshk_zeroshit = 0;
            ctrls = [obj.hGUIData.photostimControlsV5.pbMode,...
                    obj.hGUIData.photostimControlsV5.etTrigTerm,...
                    obj.hGUIData.photostimControlsV5.etExtStimSelTriggerTerm,...
                    obj.hGUIData.photostimControlsV5.etExtStimSelTerms,...
                    obj.hGUIData.photostimControlsV5.etSequence,...
                    obj.hGUIData.photostimControlsV5.etNumSequences,...
                    obj.hGUIData.photostimControlsV5.pmTrigSource];
                 
            if ~obj.hModel.hPhotostim.isVdaq
                ctrls = [ctrls obj.hGUIData.photostimControlsV5.pmSyncSource,...
                    obj.hGUIData.photostimControlsV5.etSyncTerm];
            end
            
            if obj.hModel.hPhotostim.numInstances == 0
                return;
            elseif strcmp(obj.hModel.hPhotostim.status, 'Offline')
                set(obj.hGUIData.photostimControlsV5.pbStart,'String','START','Enable','on');
                set(obj.hGUIData.photostimControlsV5.pbSoftTrig,'Enable','off');
                set(obj.hGUIData.photostimControlsV5.pbSync,'Enable','off');
                set(obj.hGUIData.photostimControlsV5.lbStimGroups, 'BackgroundColor', [1 1 1])
                ctlState = 'on';
            elseif strcmp(obj.hModel.hPhotostim.status(1:4), 'Init')
                set(obj.hGUIData.photostimControlsV5.pbStart,'Enable','off');
                set(obj.hGUIData.photostimControlsV5.lbStimGroups, 'BackgroundColor', [1 1 1])
                ctlState = 'off';
            else
                set(obj.hGUIData.photostimControlsV5.pbStart,'String','ABORT','Enable','on');
                set(obj.hGUIData.photostimControlsV5.pbSoftTrig,'Enable','on');
                if ~isempty(obj.hModel.hPhotostim.syncTriggerTerm)
                    set(obj.hGUIData.photostimControlsV5.pbSync,'Enable','on');
                end
                if strcmp(obj.hModel.hPhotostim.stimulusMode, 'onDemand')
                    set(obj.hGUIData.photostimControlsV5.lbStimGroups, 'BackgroundColor', [1 .9 .9])
                end
                ctlState = 'off';
            end
            
            set(ctrls, 'Enable', ctlState);
        end
        
        function changePhotostimMode(obj, idx)
            try
                switch idx
                    case 1
                        obj.hModel.hPhotostim.stimulusMode = 'sequence';
                    case 2
                        obj.hModel.hPhotostim.stimulusMode = 'onDemand';
                end
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
            obj.changedPhotostimMode();
        end
        
        function changedPhotostimMode(obj,~,~)
            if strcmp(obj.hModel.hPhotostim.stimulusMode, 'sequence')
                set(obj.hGUIData.photostimControlsV5.pbMode,'value',1);
                seq = 'on';
                od = 'off';
            else
                set(obj.hGUIData.photostimControlsV5.pbMode,'value',2);
                seq = 'off';
                od = 'on';
            end
            
            set(obj.hGUIData.photostimControlsV5.lblSeqSel,'visible',seq);
            set(obj.hGUIData.photostimControlsV5.etSequence,'visible',seq);
            set(obj.hGUIData.photostimControlsV5.lblNumSeq,'visible',seq);
            set(obj.hGUIData.photostimControlsV5.etNumSequences,'visible',seq);
            
            set(obj.hGUIData.photostimControlsV5.cbAllowMult,'visible',od);
            set(obj.hGUIData.photostimControlsV5.cbEnableHotkeys,'visible',od);
            set(obj.hGUIData.photostimControlsV5.extStimSelPanel,'visible',od);
        end
        
        function changedStimRoiGroups(obj,src,evnt)
            if numel(obj.hModel.hPhotostim.stimRoiGroups)
                % update list
                nms = {obj.hModel.hPhotostim.stimRoiGroups.name};
                nms = cellfun(@(str,idx)sprintf('%d: %s', idx, str), nms, num2cell(1:numel(nms)), 'UniformOutput', false);
                set(obj.hGUIData.photostimControlsV5.lbStimGroups,'string',nms);
                
                % make sure value is valid
                v = get(obj.hGUIData.photostimControlsV5.lbStimGroups,'value');
                if isempty(v)
                    set(obj.hGUIData.photostimControlsV5.lbStimGroups,'value',1);
                elseif v > numel(nms)
                    set(obj.hGUIData.photostimControlsV5.lbStimGroups,'value',numel(nms));
                end
            else
                set(obj.hGUIData.photostimControlsV5.lbStimGroups,'string',{});
            end
                
            % add listener to name properties
            obj.stimRoiGroupNameListeners.delete(); % event listeners should not need safeDeleteObj
            obj.stimRoiGroupNameListeners = most.ErrorHandler.addCatchingListener(obj.hModel.hPhotostim.stimRoiGroups, 'name', 'PostSet', @obj.changedStimRoiGroupName);
        end
        
        function changedStimRoiGroupName(obj,~,~)
            if numel(obj.hModel.hPhotostim.stimRoiGroups)
                % update list
                nms = {obj.hModel.hPhotostim.stimRoiGroups.name};
                nms = cellfun(@(str,idx)sprintf('%d: %s', idx, str), nms, num2cell(1:numel(nms)), 'UniformOutput', false);
                set(obj.hGUIData.photostimControlsV5.lbStimGroups,'string',nms);
            end
        end
        
        function addStimGroup(obj,src,evnt)
            most.ErrorHandler.assert(~isempty(obj.hModel.hPhotostim.hScan) ...
                   ,'Stim scanner was not defined.To use the photostim module, exit ScanImage and configure the SI Photostim component from the resource configuration window.');
            
            if isempty(obj.hModel.hPhotostim.stimRoiGroups)
                obj.hModel.hPhotostim.stimRoiGroups = scanimage.mroi.RoiGroup('New stimulus group');
            else
                obj.hModel.hPhotostim.stimRoiGroups(end+1) = scanimage.mroi.RoiGroup('New stimulus group');
            end
            
            obj.changedStimRoiGroups();
            set(obj.hGUIData.photostimControlsV5.lbStimGroups,'value',numel(obj.hModel.hPhotostim.stimRoiGroups));
        end
        
        function remStimGroup(obj,src,evnt)
            if numel(obj.hModel.hPhotostim.stimRoiGroups)
                v = get(obj.hGUIData.photostimControlsV5.lbStimGroups,'value');
                obj.hModel.hPhotostim.stimRoiGroups(v) = [];
                obj.changedStimRoiGroups();
            end
        end
        
        function editStimGroup(obj,~,~)
            if numel(obj.hModel.hPhotostim.stimRoiGroups)
                v = get(obj.hGUIData.photostimControlsV5.lbStimGroups,'value');
%                 obj.mroiGuiSetGroup(obj.hModel.hPhotostim.stimRoiGroups(v), 'StimulusField');
                obj.hRoiGroupEditor.setEditorGroupAndMode(obj.hModel.hPhotostim.stimRoiGroups(v),obj.hModel.hPhotostim.stimScannerset,'stimulation');
                obj.hRoiGroupEditor.defaultStimPower = inf;
                obj.showGUI('RoiGroupEditor');
            end
        end
        
        function copyStimGroup(obj)
            if numel(obj.hModel.hPhotostim.stimRoiGroups)
                v = get(obj.hGUIData.photostimControlsV5.lbStimGroups,'value');
                obj.hModel.hPhotostim.stimRoiGroups(end+1) = obj.hModel.hPhotostim.stimRoiGroups(v).copy();
                obj.changedStimRoiGroups();
                set(obj.hGUIData.photostimControlsV5.lbStimGroups,'value',numel(obj.hModel.hPhotostim.stimRoiGroups));
            end
        end
        
        function moveStimGroup(obj,dir)
            n = numel(obj.hModel.hPhotostim.stimRoiGroups);
            if n
                v = get(obj.hGUIData.photostimControlsV5.lbStimGroups,'value');
                nv = v + dir;
                
                if (nv > 0) && (nv <= n)
                    obj.hModel.hPhotostim.stimRoiGroups([v,nv]) = obj.hModel.hPhotostim.stimRoiGroups([nv,v]);
                    set(obj.hGUIData.photostimControlsV5.lbStimGroups,'value',nv);
                end
            end
        end
        
        function photostimHotKey(obj,v)
            if obj.enablePhotostimHotkeys && strcmp(obj.hModel.hPhotostim.stimulusMode, 'onDemand') && obj.hModel.hPhotostim.active
                n = str2double(strrep(v,'numpad',''));
                if isnan(n)
                    switch v
                        case 't'
                            disp('Sending photostim trigger...');
                            obj.hModel.hPhotostim.triggerStim();
                            
                        case 's'
                            disp('Sending photostim sync...');
                            obj.hModel.hPhotostim.triggerSync();
                            
                        case 'a'
                            disp('Aborting photostim...');
                            obj.hModel.hPhotostim.abort();
                    end
                    obj.pshk_zeroshit = 0;
                else
                    if n ~= 0
                        v = 10 * obj.pshk_zeroshit + n;
                        fprintf('Sending stimulus %d command...\n', v);
                        obj.pshk_zeroshit = 0;
                        obj.hModel.hPhotostim.onDemandStimNow(v);
                    else
                        obj.pshk_zeroshit = obj.pshk_zeroshit + 1;
                        fprintf('Enter second digit to output stimulus %d*...\n',obj.pshk_zeroshit);
                    end
                end
            end
        end
        
        function dblClickStimGroup(obj, idx)
            if obj.hModel.hPhotostim.active
                if strcmp(obj.hModel.hPhotostim.stimulusMode, 'onDemand')
                    fprintf('Sending stimulus %d command...\n', idx);
                    obj.hModel.hPhotostim.onDemandStimNow(idx);
                end
            else
%                 obj.mroiGuiSetGroup(obj.hModel.hPhotostim.stimRoiGroups(idx), 'StimulusField');
                obj.hRoiGroupEditor.setEditorGroupAndMode(obj.hModel.hPhotostim.stimRoiGroups(idx),obj.hModel.hPhotostim.stimScannerset,'stimulation');
                obj.hRoiGroupEditor.defaultStimPower = inf;
                obj.showGUI('RoiGroupEditor');
            end
        end
        
        function changePhotostimTrigger(obj)
            try
                sel = get(obj.hGUIData.photostimControlsV5.pmTrigSource, 'value');
                v = get(obj.hGUIData.photostimControlsV5.etTrigTerm, 'string');
                
                switch sel
                    case 1 %PFI term
                        if obj.hModel.hPhotostim.isVdaq
                            try
                                obj.hModel.hPhotostim.hFpga.signalNameToTriggerId(v);
                            catch
                                v = '';
                            end
                        end
                        obj.hModel.hPhotostim.autoTriggerPeriod = 0;
                        obj.hModel.hPhotostim.stimTriggerTerm = v;
                    case 2 %Frame clock
                        obj.hModel.hPhotostim.autoTriggerPeriod = 0;
                        obj.hModel.hPhotostim.stimTriggerTerm = 'frame';
                    case 3 %Auto s
                        v = str2double(v);
                        if isempty(v) || isnan(v) || ~v
                            v = 1;
                        end
                        obj.hModel.hPhotostim.autoTriggerPeriod = v;
                        obj.hModel.hPhotostim.stimTriggerTerm = '';
                end
            catch ME
                obj.changedPhotostimTrigger();
                ME.rethrow();
            end
        end
        
        function changedPhotostimTrigger(obj,~,~)
            if obj.hModel.hPhotostim.stimTrigIsFrame
                set(obj.hGUIData.photostimControlsV5.pmTrigSource, 'value', 2)
                set(obj.hGUIData.photostimControlsV5.etTrigTerm, 'visible', 'off');
            elseif obj.hModel.hPhotostim.autoTriggerPeriod > 0
                set(obj.hGUIData.photostimControlsV5.pmTrigSource, 'value', 3)
                set(obj.hGUIData.photostimControlsV5.etTrigTerm, 'visible', 'on');
                v = num2str(obj.hModel.hPhotostim.autoTriggerPeriod);
                set(obj.hGUIData.photostimControlsV5.etTrigTerm, 'string', v);
            else 
                set(obj.hGUIData.photostimControlsV5.pmTrigSource, 'value', 1)
                set(obj.hGUIData.photostimControlsV5.etTrigTerm, 'visible', 'on');
                v = num2str(obj.hModel.hPhotostim.stimTriggerTerm);
                set(obj.hGUIData.photostimControlsV5.etTrigTerm, 'string', v);
            end
        end
        
        function changePhotostimSync(obj)
            try
                sel = get(obj.hGUIData.photostimControlsV5.pmSyncSource, 'value');
                v = get(obj.hGUIData.photostimControlsV5.etSyncTerm, 'string');

                switch sel
                    case 1 %PFI term
                        if obj.hModel.hPhotostim.isVdaq
                            try
                                obj.hModel.hPhotostim.hFpga.dioNameToId(v);
                            catch
                                v = '';
                            end
                        else
                            v = str2double(v);
                            if isnan(v) || v < 0
                                v = [];
                            end
                        end
                        obj.hModel.hPhotostim.syncTriggerTerm = v;
                    case 2 %Frame clock
                        obj.hModel.hPhotostim.syncTriggerTerm = 'frame';
                end
            catch ME
                obj.changedPhotostimSync();
                ME.rethrow();
            end
        end
        
        function changedPhotostimSync(obj,~,~)
            if obj.hModel.hPhotostim.syncTrigIsFrame
                set(obj.hGUIData.photostimControlsV5.pmSyncSource, 'value', 2)
                set(obj.hGUIData.photostimControlsV5.etSyncTerm, 'visible', 'off');
            elseif ~obj.hModel.hPhotostim.isVdaq
                set(obj.hGUIData.photostimControlsV5.pmSyncSource, 'value', 1)
                v = num2str(obj.hModel.hPhotostim.syncTriggerTerm);
                set(obj.hGUIData.photostimControlsV5.etSyncTerm, 'string', v);
                set(obj.hGUIData.photostimControlsV5.etSyncTerm, 'visible', 'on');
            end
        end
        
        function setPhotostimLogging(obj,v)
            try
                obj.hModel.hPhotostim.logging = v;
            catch ME
                obj.loggingErr(ME,'logging');
            end
        end
        
        function setPhotostimMonitor(obj,v)
            try
                obj.hModel.hPhotostim.monitoring = v;
            catch ME
                obj.loggingErr(ME,'monitoring');
            end
        end
        
        function loggingErr(obj, ME, var)
            obj.hModel.hPhotostim.logging = obj.hModel.hPhotostim.logging;
            
            if strncmp(ME.message, 'Photostim feedback calibration is invalid.',42);
                msg = [ME.message ' Calibrate now?'];
                if strcmp('Calibrate', questdlg(msg,'ScanImage','Cancel','Calibrate','Cancel'))
                    v = obj.calibratePhotostimMonitor();
                    obj.hModel.hPhotostim.(var) = v;
                else
                    obj.hModel.hPhotostim.(var) = false;
                end
            else
                obj.hModel.hPhotostim.(var) = obj.hModel.hPhotostim.(var);
                warndlg(ME.message,'ScanImage');
            end
        end
        
        function v = calibratePhotostimMonitor(obj)
            try
                obj.hModel.hPhotostim.calibrateMonitorAndOffset();
                v = true;
            catch ME
                warndlg(ME.message,'ScanImage');
                v = false;
            end
        end
        
        function editIntegrationFieldGroup(obj,src,evnt)
%             obj.mroiGuiSetGroup(obj.hModel.hIntegrationRoiManager.roiGroup, 'IntegrationField');
            obj.hRoiGroupEditor.setEditorGroupAndMode(obj.hModel.hIntegrationRoiManager.roiGroup,obj.hModel.hScan2D.scannerset,'analysis');
            obj.showGUI('RoiGroupEditor');
        end
        
        function changedExtTrigEnable(obj,src,evnt)
            h=obj.hGUIData.mainControlsV4.pbExternalTrig;
            if obj.hModel.extTrigEnable
                set(h,'BackgroundColor',most.constants.Colors.green);
            else
                set(h,'BackgroundColor',most.constants.Colors.lightGray);
            end
        end
        
        function changedAcqState(obj,~,~)
            hFocus = obj.hGUIData.mainControlsV4.focusButton;
            hGrab = obj.hGUIData.mainControlsV4.grabOneButton;
            hLoop = obj.hGUIData.mainControlsV4.startLoopButton;
            fAbort = obj.hGUIData.mainControlsV4.fAbort;
            gAbort = obj.hGUIData.mainControlsV4.gAbort;
            lAbort = obj.hGUIData.mainControlsV4.lAbort;
            hPoint = obj.hGUIData.mainControlsV4.tbPoint;
            hStat = obj.hGUIData.mainControlsV4.statusString;
            
            saveButtonUsr = obj.hGUIData.mainControlsV4.pbSaveUsr;
            saveButtonCfg = obj.hGUIData.mainControlsV4.pbSaveCfg;
            loadButtonUsr = obj.hGUIData.mainControlsV4.pbLoadUsr;
            loadButtonCfg = obj.hGUIData.mainControlsV4.pbLoadCfg;
            
            if obj.hModel.imagingSystemChangeInProgress
                set([hFocus hGrab hLoop],'Enable','off');
                set([hFocus hGrab hLoop],'Visible','on');
                set([fAbort gAbort lAbort],'Visible','off');
                set([fAbort gAbort lAbort],'Enable','on');
                hStat.String = 'Initializing';
            else
                switch obj.hModel.acqState
                    case 'idle'
                        if obj.hModel.hCycleManager.active
                            obj.startCycleWaitStatusTimer();
                            obj.updateCycleWaitStatus();
                            loopButtonState();
                        else
                            stop(obj.hCycleWaitTimer);
                            hStat.String = obj.hModel.acqState;
                            
                            set([hFocus hGrab hLoop],'Enable','on');
                            set([hFocus hGrab hLoop],'Visible','on');
                            set([fAbort gAbort lAbort],'Visible','off');
                            set([fAbort gAbort lAbort],'Enable','on');
                            
                            set(hPoint,'String','POINT','ForegroundColor',[0 .6 0],'Enable','on');
                            set(hPoint,'Value',false);
                            set([saveButtonUsr saveButtonCfg], 'Enable', 'on');
                            set([loadButtonUsr loadButtonCfg], 'Enable', 'on');
                        end
                        
                    case 'focus'
                        hStat.String = obj.hModel.acqState;
                        set([hFocus hGrab hLoop],'Visible','off');
                        set([fAbort gAbort lAbort],'Visible','off');
                        set([fAbort gAbort lAbort],'Enable','on');
                        set(hPoint,'Enable','off');
                        set(fAbort,'Visible','on');
                        set([saveButtonUsr saveButtonCfg], 'Enable', 'off');
                        set([loadButtonUsr loadButtonCfg], 'Enable', 'off');
                        
                    case 'grab'
                        hStat.String = obj.hModel.acqState;
                        set([hFocus hGrab hLoop],'Visible','off');
                        set([fAbort gAbort lAbort],'Visible','off');
                        set([fAbort gAbort lAbort],'Enable','on');
                        set(hPoint,'Enable','off');
                        set(gAbort,'Visible','on');
                        set([saveButtonUsr saveButtonCfg], 'Enable', 'off');
                        set([loadButtonUsr loadButtonCfg], 'Enable', 'off')
                        
                    case {'loop' 'loop_wait'}
                        hStat.String = strrep(obj.hModel.acqState,'_',' ');
                        loopButtonState();
                        
                    case 'point'
                        hStat.String = obj.hModel.acqState;
                        set(hPoint,'String','PARK','ForegroundColor','r');
                        set(hPoint,'Value',true);
                        set([hFocus hGrab hLoop],'enable','off');
                        
                        %TODO: Maybe add 'error' state??
                end
            end
            
            drawnow();
            
            function loopButtonState
                set([hFocus hGrab hLoop],'Visible','off');
                set([fAbort gAbort lAbort],'Visible','off');
                set([fAbort gAbort lAbort],'Enable','on');
                set(hPoint,'Enable','off');
                set(lAbort,'Visible','on');
                set([saveButtonUsr saveButtonCfg], 'Enable', 'off');
                set([loadButtonUsr loadButtonCfg], 'Enable', 'off')
            end
        end
        
        function startCycleWaitStatusTimer(obj)
            if ~strcmp(obj.hCycleWaitTimer.Running, 'on')
                start(obj.hCycleWaitTimer);
            end
        end
        
        function updateCycleWaitStatus(obj,varargin)
            hStat = obj.hGUIData.mainControlsV4.statusString;
            wp = obj.hModel.hCycleManager.waitParams;
            if isempty(wp)
                stop(obj.hCycleWaitTimer);
            else
                rem = wp.delay - toc(wp.waitStartTime);
                if rem >= 0
                    hStat.String = sprintf('cycle delay (%d)',floor(rem));
                else
                    stop(obj.hCycleWaitTimer);
                end
            end
        end
        
        function changedScanAngleMultiplierSlow(obj,~,~)
            s = obj.hGUIData.configControlsV4;
            hForceSquareCtls = [s.cbForceSquarePixel s.cbForceSquarePixelation];
            
            if obj.hModel.hRoiManager.scanAngleMultiplierSlow == 0
                set(obj.hGUIData.mainControlsV4.tbToggleLinescan,'Value',1);
                set(hForceSquareCtls,'Enable','off');
            else
                set(obj.hGUIData.mainControlsV4.tbToggleLinescan,'Value',0);
                set(hForceSquareCtls,'Enable','on');
            end
        end
        
        function changedisprope(obj,~,~)
            obj.cfgLinePhaseSlider();
        end
        
        function changedScanFramePeriod(obj,~,~)
            if isnan(obj.hModel.hRoiManager.scanFramePeriod)
                set(obj.hGUIData.configControlsV4.etFrameRate,'BackgroundColor',[0.9 0 0]);
            else
                set(obj.hGUIData.configControlsV4.etFrameRate,'BackgroundColor',get(0,'defaultUicontrolBackgroundColor'));
            end
        end
        
        function changedChannelDisplay(obj,~,~)
            for chan = 1:obj.hModel.hChannels.channelsAvailable
                hFig = obj.hModel.hDisplay.hFigs(chan);
                wasVisible = strcmp(get(hFig,'visible'),'on');
                activate = ismember(chan,obj.hModel.hChannels.channelDisplay);
                
                if activate
                    if ~wasVisible && obj.initComplete
                        set(hFig,'visible','on'); % only set property when it is changed to reduce flickering of the figure window
                    end
                    set(hFig,'UserData','active');
                else
                    set(hFig,'UserData','');
                end
                
                if chan < 5
                    set(obj.hGUIData.imageControlsV4.(sprintf('tbCh%d',chan)), 'Value', activate);
                end
            end
            
            for chan = obj.hModel.hChannels.channelsAvailable+1:4
                set(obj.hGUIData.imageControlsV4.(sprintf('tbCh%d',chan)), 'Value', false);
            end
            
            for chan = obj.hModel.hChannels.channelsAvailable+1:numel(obj.hModel.hDisplay.hFigs)
                set(obj.hModel.hDisplay.hFigs(chan),'visible','off');
            end
        end
        
        function changedForceSquarePixelation(obj,~,~)
            if obj.hModel.hRoiManager.mroiEnable || strcmp(obj.hModel.hRoiManager.scanType, 'line') || obj.hModel.hRoiManager.forceSquarePixelation
                set(obj.hGUIData.configControlsV4.etLinesPerFrame,'Enable','off');
            else
                set(obj.hGUIData.configControlsV4.etLinesPerFrame,'Enable','on');
            end
        end
        
        function pixPerLineCB(obj,~,~)
            itms = get(obj.hGUIData.configControlsV4.pmPixelsPerLine, 'string');
            [tf, v] = ismember(num2str(obj.hModel.hRoiManager.pixelsPerLine), itms);
            if ~tf
                itms{end+1} = num2str(obj.hModel.hRoiManager.pixelsPerLine);
                set(obj.hGUIData.configControlsV4.pmPixelsPerLine, 'string', itms);
                v = numel(itms);
            end
            set(obj.hGUIData.configControlsV4.pmPixelsPerLine, 'value', v);
            
            obj.changedPowerBoxes();
        end
        
        function changeScanZoomFactor(obj,hObject,absIncrement,lastVal, handles)
            newVal = get(hObject,'Value');
            currentZoom = obj.hModel.hRoiManager.scanZoomFactor;
            
            if newVal > lastVal
                if currentZoom + absIncrement > 99.9
                    newZoom = 99.9;
                else
                    newZoom = currentZoom + absIncrement;
                end
            elseif newVal < lastVal
                if currentZoom - absIncrement < 1
                    newZoom = 1;
                else
                    newZoom = currentZoom - absIncrement;
                end
            else
                newZoom = currentZoom;
            end

            obj.hModel.hRoiManager.scanZoomFactor = newZoom;
                    
            obj.lastZoomFrac = str2double(get(handles.zoomfrac, 'String'));
            obj.lastZoomOnes = str2double(get(handles.zoomones, 'String'));
            obj.lastZoomTens = str2double(get(handles.zoomtens, 'String'));

        end % function - changeScanZoomFactor
        
        function changeScanZoomFactorForEdit(obj,hObject,absIncrement,handles)

            lastZoomVal = 0;
            currVal = 0;

            switch (absIncrement)
                case .1
                    currVal = str2double(get(handles.zoomfrac,'String'));
                    lastZoomVal = obj.lastZoomFrac;
                case 1
                    currVal = str2double(get(handles.zoomones,'String'));
                    lastZoomVal = obj.lastZoomOnes;
                case 10
                    currVal = str2double(get(handles.zoomtens,'String'));
                    lastZoomVal = obj.lastZoomTens;
            end

            if isempty(currVal) || isnan(currVal) || isinf(currVal) || (currVal < 0) || (currVal > 10) || (round(currVal) ~= currVal)             
                set(hObject, 'String', num2str(lastZoomVal));
                most.idioms.warn('An invalid value was entered for the Zoom edit field.');
            else
    
                switch (absIncrement)
                    case .1
                        obj.lastZoomFrac = currVal;
                    case 1
                        obj.lastZoomOnes = currVal;
                    case 10
                        obj.lastZoomTens = currVal;
                end
                newZoom = (obj.lastZoomTens * 10) + (obj.lastZoomOnes) + (obj.lastZoomFrac * 0.1);    %currentZoom + absIncrement;

                if (newZoom < 1)
                    newZoom = 1;
                    obj.lastZoomFrac = 0;
                    obj.lastZoomOnes = 1;
                    obj.lastZoomTens = 0;
                    set(handles.zoomfrac, 'String', '0');
                    set(handles.zoomones, 'String', '1');
                    set(handles.zoomtens, 'String', '0');
                end
            
                obj.hModel.hRoiManager.scanZoomFactor = newZoom;
        
            end % else
            
        end % function - changeScanZoomFactorForEdit
        
        function changedLogEnable(obj,~,~)
            hLoggingControls = [obj.hGUIData.mainControlsV4.baseName obj.hGUIData.mainControlsV4.baseNameLabel ...
                obj.hGUIData.mainControlsV4.fileCounter obj.hGUIData.mainControlsV4.fileCounterLabel ...
                obj.hGUIData.mainControlsV4.stFramesPerFile obj.hGUIData.mainControlsV4.etFramesPerFile ...
                obj.hGUIData.mainControlsV4.cbFramesPerFileLock obj.hGUIData.mainControlsV4.etNumAvgFramesSave ...
                obj.hGUIData.mainControlsV4.stNumAvgFramesSave obj.hGUIData.mainControlsV4.pbIncAcqNumber ...
                obj.hGUIData.mainControlsV4.cbOverwriteWarn];
            
            if obj.hModel.hChannels.loggingEnable
                set(obj.hGUIData.mainControlsV4.cbAutoSave,'BackgroundColor',[0 .8 0]);
                set(hLoggingControls,'Enable','on');
            else
                set(obj.hGUIData.mainControlsV4.cbAutoSave,'BackgroundColor',[1 0 0]);
                set(hLoggingControls,'Enable','off');
            end
        end
        
        function setSavePath(obj,~,~)
          %  'entry function'
            folder_name = uigetdir(obj.hModel.hScan2D.logFilePath);
            
            if folder_name ~= 0
                obj.hModel.hScan2D.logFilePath = folder_name;
            end
            %'exit function'
        end
        
        function changedLogFilePath(obj,~,~)
            path_ = obj.hModel.hScan2D.logFilePath;
            if isempty(path_)
                path_ = ''; % ensure datatype char
            end 
            set(obj.hGUIData.mainControlsV4.pbSetSaveDir,'TooltipString',path_);
        end
        
        %%% CFG CONFIG 
        function changedCfgFilename(obj,~,~)
            cfgFilename = obj.hModel.hConfigurationSaver.cfgFilename;
            [~,fname] = fileparts(cfgFilename);
            
            hCtl = obj.hGUIData.mainControlsV4.configName;
            hCtl.String = fname;
        end
        
        %%% FASTCFG 
        function changedFastCfgCfgFilenames(obj,~,~)
            fastCfgFNames = obj.hModel.hConfigurationSaver.fastCfgCfgFilenames;
            tfEmpty = cellfun(@isempty,fastCfgFNames);
            set(obj.hMainPbFastCfg(tfEmpty),'Enable','off');
            set(obj.hMainPbFastCfg(~tfEmpty),'Enable','on');
            
            obj.changedFastCfgAutoStartTf();
        end
        
        function changedFastCfgAutoStartTf(obj,~,~)
            autoStartTf = obj.hModel.hConfigurationSaver.fastCfgAutoStartTf;
            
            defaultBackgroundColor = get(0,'defaultUicontrolBackgroundColor');
            set(obj.hMainPbFastCfg(autoStartTf),'BackGroundColor',[0 1 0]);
            set(obj.hMainPbFastCfg(~autoStartTf),'BackGroundColor',defaultBackgroundColor);
        end
        
        %%% USR CONFIG
        function changedUsrFilename(obj,~,~)
            usrFilename = obj.hModel.hConfigurationSaver.usrFilename;
            [~,fname] = fileparts(usrFilename);
            
            hCtl = obj.hGUIData.mainControlsV4.userSettingsName;
            hCtl.String = fname;
        end
        
        function changedCfgLoading(obj,~,~)
            if ~obj.hModel.hConfigurationSaver.cfgLoadingInProgress
                %cfg just finished loading. set mroi gui roi group to imaging so that
                %it is not left editing a roi group that no longer exists
                if obj.hRoiGroupEditor.isGuiLoaded
                    obj.editImagingRoiGroup(false);
                end
                obj.updateScanControls();
            end
        end
        
        function changedUsrPropList(obj,~,~)
            % This is done because the user is given the ability to modify
            % the values of properties in the "User Settings" GUI.
            usrPropSubsetCurrent = obj.hModel.hConfigurationSaver.usrPropList;
            usrPropSubsetCurrent_ = obj.hModel.hConfigurationSaver.usrPropList;
            NUsrPropSubsetCurrent = numel(usrPropSubsetCurrent);
            
            % remove previous listeners for userSettingsV4
            delete(obj.usrSettingsPropListeners);
            
            % add new listeners
            listenerObjs = event.proplistener.empty(0,1);
            for c = 1:NUsrPropSubsetCurrent
                pname = usrPropSubsetCurrent{c};
                %The problem here is that the function
                %changedCurrentUsrProp carries only the property name in
                %the object that holds the signal. What I really need to do
                %is encode the full property somehow.
                listenerObjs(c) = obj.hModel.mdlSetPropListenerFcn(pname,'PostSet',@(src,evt,fullname)obj.changedCurrentUsrPropCallback(src,evt,pname));
                usrPropSubsetCurrent_{c} = regexprep(pname,'\.','_dot_');
            end
            obj.usrSettingsPropListeners = listenerObjs;
            
            % BEGIN CODE TO SET USER SETTINGS STRUCT AND PASS TO GUI.
            % Update currentUsrProps table to use new property subset
            obj.hGUIData.userSettingsV4.pcCurrentUSRProps.reset();
            formatStruct = struct('format','char','info',[]); % xxx explain char
            formatCell = num2cell(repmat(formatStruct,NUsrPropSubsetCurrent,1));
            
            % The following is used to create the struct that is passed
            % onto the User Settings GUI. This struct is used by
            % most.gui.control.PropertyTable to fill in the "Current USR
            % Properties" table. The current issue is that the names of the
            % properties are used as keys, and therefore they cause
            % cell2struct to break because the properties have '.'s in
            % their name.
            metadata = cell2struct(formatCell,usrPropSubsetCurrent_,1);
            obj.hGUIData.userSettingsV4.pcCurrentUSRProps.addProps(metadata);
            
            % Manually fire listeners for each prop in usrPropSubsetCurrent
            % so that the currentUsrProps table updates
            for c = 1:NUsrPropSubsetCurrent
                pname = usrPropSubsetCurrent{c};
                obj.changedCurrentUsrProp(pname);
            end
            
            % Update specifyCurrentUsrProps table
            data = get(obj.hGUIData.userSettingsV4.tblSpecifyUsrProps,'Data');
            availableUsrProps = data(:,1);
            tfInCurrentUsrSubset = ismember(availableUsrProps,usrPropSubsetCurrent);
            data(:,2) = num2cell(tfInCurrentUsrSubset);
            set(obj.hGUIData.userSettingsV4.tblSpecifyUsrProps,'Data',data);
        end
        
        function changedCurrentUsrPropCallback(obj,~,~,fullname)
            % propName = src.Name;
            % propObj = evt.AffectedObject;
            % src and evt are unused - they are only there so I can pass in
            % the constant property name 'fullname' in the callback
            val = lclRecursePropGet(obj.hModel,fullname);
            obj.hGUIData.userSettingsV4.pcCurrentUSRProps.encodeFcn(regexprep(fullname,'\.','_dot_'),val);
            
            function val = lclRecursePropGet(obj, propName)
                %Detect if pname is a submodel reference by looking for a '.'.
                [baseName, propName] = strtok(propName,'.');
                if ~isempty(propName)
                    propName = propName(2:end);
                    val = lclRecursePropGet(obj.(baseName),propName);
                else
                    val = obj.(baseName);
                end
            end
        end
        
        function changedCurrentUsrProp(obj,varargin)
            switch nargin
                case 2
                    propName = varargin{1};
                    propObj  = [];
                case 3
                    src = varargin{1};
                    propName = src.Name;
                    propObj  = varargin{2}.AffectedObject;
                otherwise
                    assert(false,'Invalid number of args.');
            end
            propName = regexprep(propName,'_dot_','\.');
            
            if isempty(propObj)
                val = lclRecursePropGet(obj.hModel, propName);
            else
                val = propObj.(propName);
            end
            
            obj.hGUIData.userSettingsV4.pcCurrentUSRProps.encodeFcn(regexprep(propName,'\.','_dot_'),val);
            
            function val = lclRecursePropGet(obj, propName)
                %Detect if pname is a submodel reference by looking for a '.'.
                [baseName, propName] = strtok(propName,'.');
                if ~isempty(propName)
                    propName = propName(2:end);
                    val = lclRecursePropGet(obj.(baseName),propName);
                else
                    val = obj.(baseName);
                end
            end
        end
        
        % This looks similar to Controller.updateModel for PropControls.
        % However updateModel() does not quite work as when there is a
        % failure, it reverts using Controller.updateViewHidden. This will
        % not work as the currentUsrProps are not currently participating
        % in the prop2Control struct business.
        function changeCurrentUsrProp(obj,hObject,eventdata,handles)
            [status,propName,propVal] = ...
                obj.hGUIData.userSettingsV4.pcCurrentUSRProps.decodeFcn(hObject,eventdata,handles);
            propName = regexprep(propName,'_dot_','\.');
            
            switch status
                case 'set'
                    try
                        % obj.hModel.(propName) = propVal;
                        lclRecursePropSet(obj.hModel, propName, propVal);
                    catch ME
                        obj.changedCurrentUsrProp(propName);
                        switch ME.identifier
                            case 'most:InvalidPropVal'
                                % no-op
                            case 'PDEPProp:SetError'
                                throwAsCaller(obj.DException('','ModelUpdateError',ME.message));
                            otherwise
                                ME.rethrow();
                        end
                    end
                case 'revert'
                    obj.changedCurrentUsrProp(propName);
                otherwise
                    assert(false);
            end
            
            function lclRecursePropSet(obj, propName, val)
                %Detect if pname is a submodel reference by looking for a '.'.
                [baseName, propName] = strtok(propName,'.');
                if ~isempty(propName)
                    propName = propName(2:end);
                    lclRecursePropSet(obj.(baseName),propName,val);
                else
                    obj.(baseName) = val;
                end
            end
        end
        
        function specifyCurrentUsrProp(obj,hObject,eventdata,handles)
            data = get(hObject,'data');
            availableUsrProps = data(:,1);
            tf = cell2mat(data(:,2));
            obj.hModel.hConfigurationSaver.usrPropList = availableUsrProps(tf);
        end
        
        function changedFastZEnable(obj,~,~)            
            if obj.hModel.hFastZ.enable && ~strcmp(obj.hModel.hFastZ.waveformType, 'step') && ~obj.hModel.hRoiManager.isLineScan
%             if obj.hModel.hFastZ.enable && ~obj.hModel.hRoiManager.isLineScan
                set(obj.hGUIData.mainControlsV4.framesTotal,'Enable','off');
%                 obj.hModel.hStackManager.framesPerSlice = 1;
            else
                set(obj.hGUIData.mainControlsV4.framesTotal,'Enable','on');
            end
        end
        
        function tuneActuator(obj,varargin)
            if ~obj.hModel.hFastZ.hasFastZ
                return;
            end
            
            if most.idioms.isValidObj(obj.hFastZTuneFig)
                most.idioms.figure(obj.hFastZTuneFig);
            else
                resp = [];
                pltResp = [];
                avg = 10;
                obj.hFastZTuneFig = most.idioms.figure('Name','FastZ Actuator Tuning','NumberTitle','off','Color','White','MenuBar','none','ToolBar','figure','tag','FASTZTUNING');
                obj.registerGUI(obj.hFastZTuneFig);
                hmain=most.idioms.uiflowcontainer('Parent',obj.hFastZTuneFig,'FlowDirection','TopDown');
                    obj.hFastZTuneAxes = most.idioms.axes('Parent',hmain,'FontSize',12,'FontWeight','Bold');
                    hold(obj.hFastZTuneAxes,'on');
                    xlabel(obj.hFastZTuneAxes,'Time (ms)','FontWeight','Bold');
                    ylabel(obj.hFastZTuneAxes,'Position (um)','FontWeight','Bold');
                    grid(obj.hFastZTuneAxes,'on');
                    
                    hbottom = most.idioms.uiflowcontainer('Parent',hmain,'FlowDirection','LeftToRight');
                    set(hbottom,'HeightLimits',[32 32]);
                        ctl1 = uicontrol('parent',hbottom,'style','pushbutton','Callback',@updatePlot,'string','Update Waveform');
                        ctl2 = uicontrol('parent',hbottom,'style','pushbutton','Callback',@testWvfm,'string','Test Actuator');
                        ctl3 = uicontrol('parent',hbottom,'style','pushbutton','Callback',@clrFigure,'string','Clear Figure');
                        set([ctl1 ctl2 ctl3],'WidthLimits',[120 120]);
                        
                        stAF = uicontrol('parent',hbottom,'style','text','string','Sample Average Factor', 'HorizontalAlignment', 'right');
                        etAF = uicontrol('parent',hbottom,'style','edit','string',num2str(avg),'Callback',@changeAvgFac);
                        set(etAF,'WidthLimits',[40 40]);
                        set([stAF etAF],'HeightLimits',[20 20]);
                    
                    if isprop(obj.hFastZTuneAxes,'Toolbar')
                        % Matlab 2018b and later
                        obj.hFastZTuneAxes.Toolbar.Visible = 'on';
                    end
                    
                    updatePlot();
            end
            
            function changeAvgFac(varargin)
                avg = floor(str2double(get(etAF,'String')));
                avg(isnan(avg)) = 1;
                avg(avg < 1) = 1;
                avg(avg > 1000) = 1000;
                set(etAF,'String',num2str(avg));
                
                if most.idioms.isValidObj(obj.hFastZResponsePlot)
                    avgSamples();
                    set(obj.hFastZResponsePlot, 'YData', repmat(pltResp,3,1));
                end
            end
            
            function avgSamples()
                if avg > 1
                    N = length(resp);
                    inds = (1:avg) - ceil(avg/2);
                    inds = repmat(inds,N,1) + repmat((1:N)',1,avg);
                    inds(inds<1) = inds(inds<1) + N;
                    inds(inds>N) = inds(inds>N) - N;
                    pltResp = resp(inds);
                    pltResp = mean(pltResp,2);
                else
                    pltResp = resp;
                end
            end
            
            function testWvfm(varargin)
                most.idioms.safeDeleteObj(obj.hFastZCmdSigPlot);
                
                [to,desPos,cmd,ti,resp] = obj.hModel.hFastZ.testActuator();
                avgSamples();
                updatePlot([],[],to,desPos,cmd,ti,pltResp);
            end
        
            function updatePlot(~,~,totput,desWvfm,cmdWvfm,tinput,respWvfm)
                if most.idioms.isValidObj(obj.hFastZTuneFig)
                    if obj.hModel.hFastZ.hasFastZ
                        if nargin < 3 && most.idioms.isValidObj(obj.hFastZResponsePlot)
                            set(obj.hFastZResponsePlot,'LineWidth',1,'LineStyle','--');
                        else
                            most.idioms.safeDeleteObj(obj.hFastZResponsePlot);
                        end
                        most.idioms.safeDeleteObj(obj.hFastZDesiredWvfmPlot);
                        most.idioms.safeDeleteObj(obj.hFastZCmdSigPlot);
                        most.idioms.safeDeleteObj(obj.hFastZPlotLines);
                        
                        zs = obj.hModel.hStackManager.zs;
                        zsRelative = obj.hModel.hStackManager.zsRelative;
                        
                        scannerSet = obj.hModel.hScan2D.scannerset;
                        if nargin < 3
                            fb = obj.hModel.hFastZ.numDiscardFlybackFrames;
                            wvType = obj.hModel.hFastZ.waveformType;
                            [totput, desWvfm, cmdWvfm] = scannerSet.zWvfm(obj.hModel.hScan2D.currentRoiGroup,zs,zsRelative,fb,wvType);
                            respWvfm = [];
                        end
                        
                        totput = totput*1000;
                        trg = totput(end);
                        totput = [totput-totput(end);totput;totput+totput(end)];
                        desWvfm = repmat(desWvfm,3,1);
                        cmdWvfm = repmat(cmdWvfm,3,1);
                        
                        fp = obj.hModel.hRoiManager.scanFramePeriod*1000;
                        fbt = scannerSet.scanners{end}.flybackTimeSeconds*1000;
                        if numel(zs) > 1
                            obj.hFastZPlotLines = plot([0 0],[-10e8,10e8],'k--','Parent',obj.hFastZTuneAxes,'LineWidth',1);
                            obj.hFastZPlotLines(end+1) = plot((fp-fbt)*ones(1,2),[-10e8,10e8],'r--','Parent',obj.hFastZTuneAxes,'LineWidth',1);
                            for i = 1:(numel(zs)-1)
                                obj.hFastZPlotLines(end+1) = plot(i*(fp)*ones(1,2),[-10e8,10e8],'g--','Parent',obj.hFastZTuneAxes,'LineWidth',1);
                                obj.hFastZPlotLines(end+1) = plot(((i+1)*fp-fbt)*ones(1,2),[-10e8,10e8],'r--','Parent',obj.hFastZTuneAxes,'LineWidth',1);
                            end
                            obj.hFastZPlotLines(end+1) = plot([trg trg],[-10e8,10e8],'k--','Parent',obj.hFastZTuneAxes,'LineWidth',1);
                        else
                            obj.hFastZPlotLines = plot([0 0],[-10e8,10e8],'k--','Parent',obj.hFastZTuneAxes,'LineWidth',1);
                            obj.hFastZPlotLines(end+1) = plot((fp-fbt)*ones(1,2),[-10e8,10e8],'r--','Parent',obj.hFastZTuneAxes,'LineWidth',1);
                            obj.hFastZPlotLines(end+1) = plot([trg trg],[-10e8,10e8],'k--','Parent',obj.hFastZTuneAxes,'LineWidth',1);
                        end
                        
                        obj.hFastZDesiredWvfmPlot = plot(totput,desWvfm,'k-','Parent',obj.hFastZTuneAxes,'LineWidth',2);
                        obj.hFastZCmdSigPlot = plot(totput,cmdWvfm,'b-','Parent',obj.hFastZTuneAxes,'LineWidth',1);
                        
                        if ~isempty(respWvfm)
                            tinput = tinput*1000;
                            tinput = [tinput-tinput(end);tinput;tinput+tinput(end)];
                            respWvfm = repmat(respWvfm,3,1);
                            obj.hFastZResponsePlot = plot(tinput,respWvfm,'r-','Parent',obj.hFastZTuneAxes,'LineWidth',2);
                            uistack(obj.hFastZDesiredWvfmPlot, 'top')
                            uistack(obj.hFastZCmdSigPlot, 'top')
                        end
                        
                        xlim(obj.hFastZTuneAxes,[-.1*trg 1.1*trg]);
                        mm = [min([desWvfm; respWvfm]) max([desWvfm; respWvfm])];
                        rg = mm(2)-mm(1);
                        if rg == 0
                            rg = 1;
                        end
                        ylim(obj.hFastZTuneAxes,[mm(1)-rg*.1 mm(2)+rg*.1]);
                        
                        if most.idioms.isValidObj(obj.hFastZResponsePlot)
                            if isempty(respWvfm)
                                n = 'Actual (old)';
                            else
                                n = 'Actual';
                            end
                            l = legend([obj.hFastZDesiredWvfmPlot obj.hFastZCmdSigPlot obj.hFastZResponsePlot], {'Desired' 'Cmd' n},'location','NorthWest');
                        else
                            l = legend([obj.hFastZDesiredWvfmPlot obj.hFastZCmdSigPlot], {'Desired' 'Cmd'},'location','NorthWest');
                        end
                        
                        l.Units = 'normalized';
                        l.Position(1) = .25;
                    else
                        clrFigure();
                    end
                end
            end
            
            function clrFigure(varargin)
                most.idioms.safeDeleteObj(obj.hFastZDesiredWvfmPlot);
                most.idioms.safeDeleteObj(obj.hFastZCmdSigPlot);
                most.idioms.safeDeleteObj(obj.hFastZResponsePlot);
                most.idioms.safeDeleteObj(obj.hFastZPlotLines);
                legend(obj.hFastZTuneAxes, 'off');
            end
        end
        
        %%% Main Controls
        function changedPointButton(obj,src,~)
            if get(src,'Value')
                obj.hModel.scanPointBeam();
            else
                obj.hModel.abort();
            end
        end
        
        function changedLogFramesPerFileLock(obj,~,~)
            if obj.hModel.hChannels.loggingEnable
                if obj.hModel.hScan2D.logFramesPerFileLock
                    set(obj.hGUIData.mainControlsV4.etFramesPerFile,'Enable','off');
                else
                    set(obj.hGUIData.mainControlsV4.etFramesPerFile,'Enable','on');
                end
            else
                set(obj.hGUIData.mainControlsV4.etFramesPerFile,'Enable','off');
            end
        end
        
        function openConfigEditor(obj)
            dabs.resources.ResourceStore.showConfig();
        end
        
        function mdfUpdate(obj,varargin)
            hMDF = most.MachineDataFile.getInstance();
            hMDF.load(hMDF.fileName);
            obj.hModel.reloadMdf();
        end
        
        %%% Cfg controls
        function cfgLinePhaseSlider(obj,varargin)
            sliderMin  = -1000 * obj.hModel.hScan2D.linePhaseStep;
            sliderMax  =  1000 * obj.hModel.hScan2D.linePhaseStep;
            sliderStep = obj.hModel.hScan2D.linePhaseStep / (sliderMax - sliderMin);
            Value  =  obj.hModel.hScan2D.linePhase;
            set(obj.hGUIData.configControlsV4.scanPhaseSlider,'Min',sliderMin,'Max',sliderMax,'SliderStep',[sliderStep 10*sliderStep],'Value',Value);
            obj.changedScanPhase();
        end
        
        function cfgAdvancedPanel(obj,show)
            u = get(obj.hGUIs.configControlsV4,'units');
            set(obj.hGUIs.configControlsV4,'units','characters');
            
            p = get(obj.hGUIs.configControlsV4,'Position');
            if show && p(3) < 70
                p(3) = 127;
                set(obj.hGUIs.configControlsV4,'Position',p);
            elseif ~show && p(3) > 70
                p(3) = 65.4;
                set(obj.hGUIs.configControlsV4,'Position',p);
            end
            
            set(obj.hGUIs.configControlsV4,'units',u);
        end
        
        function changeScanPhaseSlider(obj,src)
            val = get(src,'Value');
            
            d = abs(obj.hModel.hScan2D.linePhase-val);
            tolerance_s = 1e-9;
            
            if d > tolerance_s
                obj.hModel.hScan2D.linePhase = val;
            end
        end
        
        function changeScanPhase(obj)
            val = get(obj.hGUIData.configControlsV4.etScanPhase,'String');
            val = str2double(val);
            
            switch obj.hModel.hScan2D.linePhaseUnits
                case 'seconds'
                    viewScaling = 1e6;
                case 'pixels'
                    viewScaling = 1;
                otherwise
                    assert(false);
            end
            
            obj.hModel.hScan2D.linePhase = val/viewScaling;
        end
        
        function changedScanPhase(obj,~,~)
            val = obj.hModel.hScan2D.linePhase;
            
            switch obj.hModel.hScan2D.linePhaseUnits
                case 'seconds'
                    viewScaling = 1e6;
                case 'pixels'
                    viewScaling = 1;
                otherwise
                    assert(false);
            end
            
            set(obj.hGUIData.configControlsV4.etScanPhase,'String',num2str(val*viewScaling));
            
            minSliderVal = get(obj.hGUIData.configControlsV4.scanPhaseSlider,'Min');
            maxSliderVal = get(obj.hGUIData.configControlsV4.scanPhaseSlider,'Max');
            
            % enforce limits
            if val < minSliderVal
                val = minSliderVal;
            elseif val > maxSliderVal
                val = maxSliderVal;
            end
            
            set(obj.hGUIData.configControlsV4.scanPhaseSlider,'Value',val);
        end
        
        function calibrateLinePhase(obj)
            %assert(~strcmp(obj.hModel.acqState, 'idle'),'This operation is only available while imaging.');
            %assert(obj.hModel.hScan2D.bidirectional,'This operation must be done with bidirectional scanning enabled');
            %assert(numel(obj.hModel.hChannels.channelDisplay) > 0,'At least one channel must be selected for display');
            
            if strcmp(obj.hModel.acqState, 'idle')
                most.idioms.warn('This operation is only available while imaging.');
            elseif ~obj.hModel.hScan2D.bidirectional
                most.idioms.warn('This operation must be done with bidirectional scanning enabled');
            elseif (numel(obj.hModel.hChannels.channelDisplay) <= 0)
                most.idioms.warn('At least one channel must be selected for display');
            else
                obj.hModel.hScan2D.calibrateLinePhase();
            end
            
        end % function - calibrateLinePhase
        
        %%
        function setLineRate(obj, src, val)
            if ~isnan(val)
                % Get available sample rates.
                sampleRates = obj.hModel.hScan2D.validSampleRates;
                % Max Sample Clock of Acq Device
                sampleClkMaxRate = max(sampleRates);
                % Set Floor of Valid Sample Rates
                sampleRates = sampleRates(sampleRates >= (200000));
                % Clamp Valid Sample Rates to Max Sample Reate of Acq
                % Device
                sampleRates = sampleRates(sampleRates <= (sampleClkMaxRate));
                
                hVarSel = obj.hGUIData.configControlsV4.pmScanRateVar;
                switch hVarSel.Value
                    case 1
                        if strcmp(obj.hModel.hRoiManager.scanType, 'line')
                            % sample rate (MHz)
                            obj.hModel.hScan2D.sampleRate = val*1e6;
                            return;
                        else
                            if strcmp(src.Style, 'slider')
                                obj.hModel.hScan2D.pixelBinFactor = round(val);
                                return
                            else
                                % pixel dwell time (ns)
                                pixelTime = val*1e-9;
                            end
                        end
                    case 2 % line rate (Hz)
                        if strcmp(src.Style, 'slider')
                            obj.hModel.hScan2D.pixelBinFactor = -round(val);
                            return
                        else
                            ppl = obj.hModel.hRoiManager.linePeriod / obj.hModel.hScan2D.scanPixelTimeMean;
                            pixelTime = 1/(val * ppl);
                        end
                    case 3 % line period (us)
                        if strcmp(src.Style, 'slider')
                            obj.hModel.hScan2D.pixelBinFactor = round(val);
                            return
                        else
                            ppl = obj.hModel.hRoiManager.linePeriod / obj.hModel.hScan2D.scanPixelTimeMean;
                            pixelTime = val*1e-6/ppl;
                        end
                    case 4 % Sample Rate (MHz) - Frame Scan
                        if strcmp(src.Style, 'slider')
                            obj.hModel.hScan2D.sampleRate = sampleRates(numel(sampleRates) - round(val) + 1);
                            return
                        else
                            if ~isempty(find(sampleRates == val*1e6,1))
                                obj.hModel.hScan2D.sampleRate = val*1e6;
                                return
                            else
                                warning('Invalid sample rate. Increase the precision of your entry or change the timebase in the MDF.');
                                obj.changedLineRate();
                                return
                            end
                        end
                    otherwise
                        return
                end
                
                % calculate appropriate sample rate and pixel bin factor to
                % achieve desired pixelTime
                
                % Determine all possible Bin Factors to achieve this
                binFs = pixelTime .* sampleRates;
                % Only allow valid integer Bin Factors
                binFs(binFs < .5) = [];
                binFs = unique(round(binFs));
                
                if isempty(binFs)
                    obj.changedLineRate();
                    return;
                else
                    % Parse through and find all the valid bin factors and
                    % sample rates that will achieve the desired
                    validRates = [];
                    validFactors = [];
                    
                    for i = 1:length(binFs)
                        for n = 1:length(sampleRates)
                            if (binFs(i)/sampleRates(n)) == pixelTime
                                validFactors(end+1) = binFs(i);
                                validRates(end+1) = sampleRates(n);
                            elseif abs((binFs(i)/sampleRates(n))-pixelTime) < 1e9*eps(min(abs((binFs(i)/sampleRates(n))),abs(pixelTime)))
                                validFactors(end+1) = binFs(i);
                                validRates(end+1) = sampleRates(n);
                            else
                            end
                        end
                    end

                    % Select settings that will achieve dwell time at
                    % highest sample rate.
                    if isempty(validRates) || isempty(validFactors)
                        most.idioms.warn('Requested setting can not be achieved at the given sample rate.');
                        obj.hModel.hScan2D.pixelBinFactor = obj.hModel.hScan2D.pixelBinFactor;
                        obj.hModel.hScan2D.sampleRate = obj.hModel.hScan2D.sampleRate;
                    else
                        obj.hModel.hScan2D.pixelBinFactor = validFactors(find(validRates == max(validRates)));
                        obj.hModel.hScan2D.sampleRate = max(validRates);
                    end
                end

            else
                obj.changedLineRate();
            end
        end

        function changedLineRateVar(obj)
            hVarSel = obj.hGUIData.configControlsV4.pmScanRateVar;
            hSldr = obj.hGUIData.configControlsV4.slLineRate;
            switch hVarSel.Value
                case 1
                    if strcmp(obj.hModel.hRoiManager.scanType, 'line')
                        % sample rate (MHz)
                        sliderMax = obj.hModel.hScan2D.maxSampleRate*1e-6;
                        sliderMin = 1e-3;
                    else
                        % pixel dwell time (ns)
                        % Just increments binFactor at same sample rate.
                        % Necessarily changes dwell time..
                        sliderMax = 40;
                        sliderMin = 1;
                    end
                case 2 % line rate (Hz)
                    sliderMax = -1;
                    sliderMin = -40;
                case 3 % line period (us)
                    sliderMax = 40;
                    sliderMin = 1;
                case 4
                    if isa(obj.hModel.hScan2D, 'scanimage.components.scan2d.ResScan')
                        sampleRates = obj.hModel.hScan2D.sampleRate;
                        sliderMax = length(sampleRates);
                        sliderMin = 1;
                    else
                        % Get available sample rates.
                        sampleRates = obj.hModel.hScan2D.validSampleRates;
                        % Set Floor of Valid Sample Rates
                        sampleRates = sampleRates(sampleRates >= (200000));
                        
                        sliderMax = length(sampleRates);
                        sliderMin = 1;
                    end
                otherwise
                    return
            end
            
            % configure the slider max and min
            sliderStep = min(1 / (sliderMax - sliderMin),1);
            set(hSldr,'Min',sliderMin,'Max',sliderMax, 'SliderStep',[sliderStep sliderStep]);
            
            obj.changedLineRate();
        end
        
        function changedLineRate(obj,~,~)
            hVarSel = obj.hGUIData.configControlsV4.pmScanRateVar;
            hSldr = obj.hGUIData.configControlsV4.slLineRate;
            
            switch hVarSel.Value
                case 1
                    if strcmp(obj.hModel.hRoiManager.scanType, 'line')
                        % Sample Rate (MHz) - Line Scan
                        v = obj.hModel.hScan2D.sampleRate * 1e-6;
                        set(obj.hGUIData.configControlsV4.etLineRate,'String',sprintf('%.3f',v));
                    else
                        % pixel dwell time
                        v = obj.hModel.hScan2D.scanPixelTimeMean * 1e9;
                        set(obj.hGUIData.configControlsV4.etLineRate,'String',sprintf('%.1f',v));
                    end
                case 2 % line rate (Hz)
                    v = 1/obj.hModel.hRoiManager.linePeriod;
                    set(obj.hGUIData.configControlsV4.etLineRate,'String',sprintf('%.1f',v));
                case 3 % line period (us)
                    v = obj.hModel.hRoiManager.linePeriod * 1e6;
                    set(obj.hGUIData.configControlsV4.etLineRate,'String',sprintf('%.1f',v));
                case 4 % Sample Rate (MHz) - Frame Scan
                    v = obj.hModel.hScan2D.sampleRate * 1e-6;
                    set(obj.hGUIData.configControlsV4.etLineRate,'String',sprintf('%.3f',v));
                otherwise
                    return
            end
            
            v(isnan(v)) = 0;
            switch obj.hModel.hScan2D.scanMode
                case 'resonant'
                    if hVarSel.Value == 2
                        set(hSldr, 'Value', -1);
                    else
                        set(hSldr, 'Value', 1);
                    end
                case 'linear'
                    if strcmp(obj.hModel.hRoiManager.scanType, 'line')
                        set(hSldr, 'Value', v);
                    else
                        if hVarSel.Value == 2
                            v = obj.hModel.hScan2D.pixelBinFactor;
                            set(hSldr, 'Value', -v);
                        elseif hVarSel.Value == 4
                            % Get available sample rates.
                            sampleRates = obj.hModel.hScan2D.validSampleRates;
                            % Set Floor of Valid Sample Rates -  might not be necessary
                            % anymore
                            sampleRates = sampleRates(sampleRates >= (200000));
                            v = v/(1e-6);
                            if ~isempty(find(sampleRates == v))
                                idx = find(sampleRates == v);
                            elseif ~isempty(find(abs((sampleRates)-v) < 1e9*eps(min(abs((sampleRates)),abs(v)))))
                                idx = find(abs((sampleRates)-v) < 1e9*eps(min(abs((sampleRates)),abs(v))));
                            else
                            end
                            set(hSldr, 'Value', numel(sampleRates) - idx + 1);
                        else
                            v = obj.hModel.hScan2D.pixelBinFactor;
                            set(hSldr, 'Value', v);
                        end
                    end
                case 'slm'
                    set(hSldr, 'Value', 10);
                otherwise
                    error('Unknown Scan2D class: %s',class(obj.hModel.hScan2D));
            end
        end
        
        function changeScanRotation(obj,src,inc)
            obj.hModel.hRoiManager.scanRotation = obj.hModel.hRoiManager.scanRotation + inc;
        end
        
        function zeroScanRotation(obj,src)
            obj.hModel.hRoiManager.scanRotation = 0;
        end
        
        function changedWSConnectorEnable(obj,varargin)
            hMnuEntry = obj.hGUIData.mainControlsV4.mnu_Settings_YokeWS;            
            
            if obj.hModel.hWSConnector.enable
                hMnuEntry.Checked = 'on';
            else
                hMnuEntry.Checked = 'off';
            end
        end
        
        function changeSlmControlsScanner(obj)
            selectedSlmIdx = obj.hGUIData.slmControls.pmSlmSelect.Value;
            
            if ~isempty(obj.hGUIData.slmControls.pmSlmSelect.UserData.scanners)
                obj.hModel.hSlmScan = obj.hGUIData.slmControls.pmSlmSelect.UserData.scanners(selectedSlmIdx);
                obj.changedSlmScan();
            end
        end
        
        function changedSlmScan(obj,varargin)
            if isempty(obj.hGUIData.slmControls.pmSlmSelect.UserData.scanners)
                return
            end
            
            [tf,idx] = ismember(obj.hModel.hSlmScan,obj.hGUIData.slmControls.pmSlmSelect.UserData.scanners);
            
            if ~isempty(obj.hModel.hSlmScan) && ~isempty(tf) && tf
                obj.reprocessSubMdlPropBindings('hSlmScan');
                ctl = obj.hGUIData.slmControls.pmSlmSelect;
                ctl.Value = idx;
                obj.changedSlmControls();
            end
        end
        
        function changedSlmControls(obj,varargin)
            persistent bgColorDefault
            
            pbCalibrateLut = obj.hGUIData.slmControls.pbCalibrateLut;
            pbLoadWavefrontCorrection = obj.hGUIData.slmControls.pbLoadWavefrontCorrection;
            
            if isempty(bgColorDefault)
                bgColorDefault = pbCalibrateLut.BackgroundColor;
            end
            
            highlightColor = [1 0.7 0.7];
            
            if isempty(obj.hModel.hSlmScan.lut)
                pbCalibrateLut.BackgroundColor = highlightColor;
            else
                pbCalibrateLut.BackgroundColor = bgColorDefault;
            end
            
            if isempty(obj.hModel.hSlmScan.wavefrontCorrectionNominal)
                pbLoadWavefrontCorrection.BackgroundColor = highlightColor;
            else
                pbLoadWavefrontCorrection.BackgroundColor = bgColorDefault;
            end
            
            calWl_nm = obj.hModel.hSlmScan.calibratedWavelengths * 1e9;
            if isempty(calWl_nm)
                str = {' '};
            else
                str = arrayfun(@(wl)num2str(wl),calWl_nm,'Uniformoutput',false);
            end
            pmWavelength_nm = obj.hGUIData.slmControls.pmWavelength_nm;
            pmWavelength_nm.String = str;
            pmWavelength_nm.Value = 1;
            
            pos = obj.hModel.hSlmScan.parkPosition_um;
            ctl = obj.hGUIData.slmControls.etParkPositionX;
            ctl.String = sprintf('%.1f',pos(1));
            ctl = obj.hGUIData.slmControls.etParkPositionY; 
            ctl.String = sprintf('%.1f',pos(2));
            ctl = obj.hGUIData.slmControls.etParkPositionZ;
            ctl.String = sprintf('%.1f',pos(3));
        end
        
        function changeWavelengthPm(obj,varargin)
            idx = obj.hGUIData.slmControls.pmWavelength_nm.Value;
            str = obj.hGUIData.slmControls.pmWavelength_nm.String{idx};
            
            wl = str2double(str) * 1e-9; %convert from nanometer to micrommeter
            if ~isempty(wl) && ~isnan(wl)
                obj.hModel.hSlmScan.wavelength = wl;
            end
        end
        
        function changeSlmParkPosition(obj,varargin)
            try
                x = str2double(obj.hGUIData.slmControls.etParkPositionX.String);
                y = str2double(obj.hGUIData.slmControls.etParkPositionY.String);
                z = str2double(obj.hGUIData.slmControls.etParkPositionZ.String);
                
                obj.hModel.hSlmScan.parkPosition_um = [x y z];
            catch ME
                obj.changedSlmControls();
            end
        end
        
        function changedSlmAlignmentPoints(obj,~,~)
            if ~isempty(obj.hModel.hSlmScan)
                numPts = size(obj.hModel.hSlmScan.alignmentPoints,1);

                motion = double.empty(0,2);
                if ~isempty(obj.hModel.hSlmScan.alignmentPoints)
                    motion = obj.hModel.hSlmScan.alignmentPoints;
                    motion = vertcat(motion{:,2});
                end

                obj.hModel.hMotionManager.motionMarkersXY = motion;
                
                if size(motion,1)>0
                    obj.showGUI('MotionDisplay');
                end
            end
        end
        
        function xGalvoPlot(obj)
            [fsOut,desiredWvfm,cmdWvfm,fsIn,respWvfm,T,Ta] = obj.hModel.hScan2D.waveformTest();
            
            No = length(cmdWvfm);
            outTs = linspace(1/fsOut, No/fsOut, No);
            Ni = length(respWvfm);
            inTs = linspace(1/fsIn, Ni/fsIn, Ni);
            
            bth = [cmdWvfm;respWvfm];
            rg = max(bth) - min(bth);
            
            Td=(T-Ta)/2;
            vertlines = [Td Ta+Td];
            vertlines = [vertlines vertlines+T];
            
            %% plot not accounting phase adjust
            hFig_ = most.idioms.figure();
            hAx = most.idioms.subplot(2,1,1,'Parent',hFig_);
            hold(hAx,'on');
            plot(hAx, outTs, desiredWvfm);
            plot(hAx, outTs, cmdWvfm);
            plot(hAx, inTs, respWvfm);
            grid(hAx,'on');
            title(hAx,'Real time plot')
            legend(hAx,'Desired','Command','Feedback');
            ylabel(hAx,'Amplitude [V]');
            
            ylim(hAx,[min(bth)-rg/20 max(bth)+rg/20]);
            
            for x = vertlines
                plot(hAx, [x x], [-15 15], '--k');
            end
            
            %% plot accounting phase adjust
            sampShift = ceil(obj.hModel.hScan2D.linePhase * fsIn);
            hAx = most.idioms.subplot(2,1,2,'Parent',hFig_);
            hold(hAx,'on');
            hAx = plotyy(hAx,[outTs(:),outTs(:),outTs(:)], [desiredWvfm(:),circshift(cmdWvfm(:),-sampShift),circshift(respWvfm(:),-sampShift)],...
                outTs(:),circshift(respWvfm(:),-sampShift)-desiredWvfm(:));

            grid(hAx(1),'on');
            title(hAx(1),'Phase setting adjusted plot')
            legend(hAx(1),'Desired','Command','Feedback','Error');
            
            ylabel(hAx(1),'Amplitude [V]');
            xlabel(hAx(1),'Time [s]');

            ylim(hAx(1),[min(bth)-rg/20 max(bth)+rg/20]);
            hAx(1).YTickMode = 'Auto';
            
            for x = vertlines
                plot(hAx(1),[x x], [-15 15], '--k');
            end
        end
    end
    
    %%% CONTROLLER PROPERTY CALLBACKS    
    methods (Hidden, Access=private)
        function hFig = zzzSelectImageFigure(obj)
            %Selects image figure, either from channelsTargetDisplay property or by user-selection
            if isempty(obj.channelsTargetDisplay)
                obj.mainControlsStatusString = 'Select image...';
                chanFigs = [ obj.hModel.hDisplay.hFigs obj.hModel.hDisplay.hMergeFigs ] ;
                hFig = most.gui.selectFigure(chanFigs);
                obj.mainControlsStatusString = '';
            elseif isinf(obj.channelsTargetDisplay)
                hFig = obj.hModel.hDisplay.hMergeFigs;
            else
                hFig = obj.hModel.hDisplay.hFigs(obj.channelsTargetDisplay);
            end
        end
    end
end

%% LOCAL
function v = zlclShortenFilename(v)
assert(ischar(v));
[~,v] = fileparts(v);
end

function s = lclInitPropBindings(hModel)
    %NOTE: In this prop metadata list, order does NOT matter!
    %NOTE: These are properties for which some/all handling of model-view linkage is managed 'automatically' by this class
    %TODO: Some native approach for dependent properties could be specified here, to handle straightforward cases where change in one property affects view of another -- these are now handled as 'custom' behavior with 'Callbacks'
    %For example: scanLinePeriodUS value depends on scanMode
    s = struct();

    %%SI Root Model
    s.imagingSystem             = struct('Callback','changedImagingSystem');
    s.imagingSystemChangeInProgress = struct('Callback','changedAcqState');
    s.acqsPerLoop               = struct('GuiIDs',{{'mainControlsV4','repeatsTotal'}});
    s.loopAcqInterval           = struct('GuiIDs',{{'mainControlsV4','etRepeatPeriod'}});
    s.extTrigEnable             = struct('GuiIDs',{{'mainControlsV4' 'cbExternalTrig'}},'Callback','changedExtTrigEnable');

    % acquisition State
    s.frameCounterForDisplay = struct('GuiIDs',{{'mainControlsV4','framesDone'}});
    s.loopAcqCounter         = struct('GuiIDs',{{'mainControlsV4','repeatsDone'}});
    s.acqState               = struct('Callback','changedAcqState');
    s.acqInitInProgress      = struct('Callback','changedAcqState');
    s.secondsCounter         = struct('Callback','changedSecondsCounter');

    %%% Stack props
    s.hStackManager.enable             = struct('GuiIDs',{{'mainControlsV4','cbEnableStack'}});
    s.hStackManager.framesPerSlice     = struct('GuiIDs',{{'mainControlsV4','framesTotal'}});
    s.hStackManager.actualNumSlices    = struct('GuiIDs',{{'mainControlsV4','slicesTotal'}});
    s.hStackManager.actualNumVolumes   = struct('GuiIDs',{{'mainControlsV4','volumesTotal'}});

    s.hStackManager.volumesDone        = struct('GuiIDs',{{'mainControlsV4','volumesDone'}});
    s.hStackManager.slicesDone         = struct('GuiIDs',{{'mainControlsV4','slicesDone'}});
    s.hStackManager.framesDone         = struct('GuiIDs',{{'mainControlsV4','framesDone'}});


    %%% Submodels (sub-components)
    %%% Display component
    s.hDisplay.displayRollingAverageFactor     = struct('GuiIDs',{{'imageControlsV4','etRollingAverage'}});
    s.hDisplay.lineScanHistoryLength           = struct('GuiIDs',{{'imageControlsV4','etLineHistoryLength'}});
    s.hDisplay.displayRollingAverageFactorLock = struct('GuiIDs',{{'imageControlsV4','cbLockRollAvg2AcqAvg'}},'Callback','changedDisplayRollingAverageFactorLock');
    s.hDisplay.selectedZs                      = struct('Callback','displaySelectedZsChanged');
    s.hDisplay.volumeDisplayStyle              = struct('Callback','display3dStyleChanged');
    
    s.hDisplay.chan1LUT = struct('Callback','changedChanLUT');
    s.hDisplay.chan2LUT = struct('Callback','changedChanLUT');
    s.hDisplay.chan3LUT = struct('Callback','changedChanLUT');
    s.hDisplay.chan4LUT = struct('Callback','changedChanLUT');
    
    s.hDisplay.channelsMergeEnable     = struct('GuiIDs',{{'channelControlsV4','cbMergeEnable'}},'Callback','changedChannelsMergeEnable');
    s.hDisplay.channelsMergeFocusOnly  = struct('GuiIDs',{{'channelControlsV4','cbChannelsMergeFocusOnly'}});
    
    %%% Scan2D component
    % channels
    s.hScan2D.channelsAutoReadOffsets  = struct('GuiIDs',{{'channelControlsV4','cbAutoReadOffsets'}});
    s.hScan2D.scanMode                         = struct('Callback','changedScanMode');

    s.hChannels.loggingEnable          = struct('GuiIDs',{{'mainControlsV4','cbAutoSave'}},'Callback','changedLogEnable');
    s.hChannels.channelDisplay         = struct('Callback','changedChannelDisplay');
    
    % SCAN
    s.hScan2D.bidirectional            = struct('GuiIDs',{{'configControlsV4','cbBidirectionalScan'}});
    s.hScan2D.stripingEnable           = struct('GuiIDs',{{'configControlsV4','cbStripingEnable'}});
    s.hScan2D.fillFractionTemporal     = struct('GuiIDs',{{'configControlsV4','etFillFrac'}},'ViewPrecision','%0.3f');
    s.hScan2D.fillFractionSpatial      = struct('GuiIDs',{{'configControlsV4','etFillFracSpatial'}},'ViewPrecision','%0.3f');
    s.hScan2D.scanPixelTimeMean        = struct('GuiIDs',{{'configControlsV4','etPixelTimeMean'}},'ViewScaling',1e9,'ViewPrecision','%.1f');
    s.hScan2D.scanPixelTimeMaxMinRatio = struct('GuiIDs',{{'configControlsV4','etPixelTimeMaxMinRatio'}},'ViewPrecision','%.1f');
    s.hScan2D.linePhase                = struct('Callback','changedScanPhase');
    s.hScan2D.sampleRate               = struct('GuiIDs',{{'configControlsV4','etSampleRateMHz'}},'ViewPrecision','%.3f','ViewScaling',1e-6,'Callback','cfgLinePhaseSlider');
    s.hScan2D.uniformSampling          = struct('GuiIDs',{{'configControlsV4','cbUniformSampling'}});
    s.hScan2D.trigAcqInTerm            = struct('GuiIDs',{{'triggerControlsV5','pmTrigAcqInTerm'}},'Callback','changedTrigAcqInTerm');
    s.hScan2D.trigStopInTerm           = struct('GuiIDs',{{'triggerControlsV5','pmTrigStopInTerm'}});
    s.hScan2D.trigNextInTerm           = struct('GuiIDs',{{'triggerControlsV5','pmTrigNextInTerm'}});
    s.hScan2D.trigAcqEdge              = struct('GuiIDs',{{'triggerControlsV5','pmTrigAcqEdge'}});
    s.hScan2D.trigStopEdge             = struct('GuiIDs',{{'triggerControlsV5','pmTrigStopEdge'}});
    s.hScan2D.trigNextEdge             = struct('GuiIDs',{{'triggerControlsV5','pmTrigNextEdge'}});
    s.hScan2D.trigNextStopEnable       = struct('GuiIDs',{{'triggerControlsV5','cbTrigNextStopEnable'}},'Callback', 'changedTrigNextStopEnable');
    s.hScan2D.pixelBinFactor           = struct('GuiIDs',{{'configControlsV4','etPixelBinFactor'}});
%     s.hScan2D.pixelBinFactor           = struct('GuiIDs',{{'configControlsV4','slLineRate'}});
    s.hScan2D.flytoTimePerScanfield    = struct('GuiIDs',{{'configControlsV4','etFlytoTimePerScanfieldMs'}},'ViewPrecision','%.3f','ViewScaling',1e3);
    s.hScan2D.flybackTimePerFrame      = struct('GuiIDs',{{'configControlsV4','etFlybackTimePerFrameMs'}},'ViewPrecision','%.3f','ViewScaling',1e3);
    s.hScan2D.keepResonantScannerOn    = struct('GuiIDs',{{'configControlsV4','cbKeepScannerOn'}});
    s.hScan2D.logFilePath              = struct('Callback','changedLogFilePath');
    s.hScan2D.recordScannerFeedback    = struct('GuiIDs',{{'configControlsV4','cbFeedback'}});
    s.hScan2D.parkSlmForAcquisition    = struct('GuiIDs',{{'configControlsV4','cbCenterSlm'}});
    
    % logging
    s.hScan2D.logFileStem           = struct('GuiIDs',{{'mainControlsV4' 'baseName'}});
    s.hScan2D.logFileCounter        = struct('GuiIDs',{{'mainControlsV4' 'fileCounter'}});
    s.hScan2D.logFramesPerFile      = struct('GuiIDs',{{'mainControlsV4' 'etFramesPerFile'}});
    s.hScan2D.logFramesPerFileLock  = struct('GuiIDs',{{'mainControlsV4' 'cbFramesPerFileLock'}},'Callback','changedLogFramesPerFileLock');
    s.hScan2D.logAverageFactor      = struct('GuiIDs',{{'mainControlsV4','etNumAvgFramesSave'}});
    s.hScan2D.logOverwriteWarn      = struct('GuiIDs',{{'mainControlsV4','cbOverwriteWarn'}});
    
    %%% ROIMANAGER component
    s.hRoiManager.forceSquarePixelation    = struct('GuiIDs',{{'configControlsV4','cbForceSquarePixelation'}},'Callback','changedForceSquarePixelation');
    s.hRoiManager.forceSquarePixels        = struct('GuiIDs',{{'configControlsV4','cbForceSquarePixel'}});
    s.hRoiManager.linesPerFrame            = struct('GuiIDs',{{'configControlsV4','etLinesPerFrame'}},'Callback','changedPowerBoxes');
    s.hRoiManager.pixelsPerLine            = struct('GuiIDs',{{'configControlsV4','etPixelsPerLine'}},'Callback','pixPerLineCB');
    s.hRoiManager.scanAngleMultiplierFast  = struct('GuiIDs',{{'mainControlsV4','etScanAngleMultiplierFast'}});
    s.hRoiManager.scanAngleMultiplierSlow  = struct('GuiIDs',{{'mainControlsV4','etScanAngleMultiplierSlow'}});
    s.hRoiManager.scanAngleShiftSlow       = struct('GuiIDs',{{'mainControlsV4','scanShiftSlow'}});
    s.hRoiManager.scanAngleShiftFast       = struct('GuiIDs',{{'mainControlsV4','scanShiftFast'}});
    s.hRoiManager.scanFrameRate            = struct('GuiIDs',{{'configControlsV4','etFrameRate'}},'ViewPrecision','%.2f');
    s.hRoiManager.linePeriod               = struct('GuiIDs',{{'configControlsV4','etLinePeriod'}},'ViewScaling',1e6,'ViewPrecision','%.2f','Callback','changedLineRate');
    s.hRoiManager.scanRotation             = struct('GuiIDs',{{'mainControlsV4','scanRotation'}});
    s.hRoiManager.scanZoomFactor           = struct('GuiIDs',{{'mainControlsV4' 'pcZoom'}});
    s.hRoiManager.mroiEnable               = struct('GuiIDs',{{'mainControlsV4', 'cbEnableMroi'}},'Callback','updateScanControls');
    s.hRoiManager.scanType                 = struct('Callback','updateScanType');
    
    s.hFastZ.enableFieldCurveCorr          = struct('GuiIDs',{{'mainControlsV4' 'cbCurvatureCorrection'}});
    
    %%% ConfigurationSaver component
    s.hConfigurationSaver.cfgFilename          = struct('Callback','changedCfgFilename');
    s.hConfigurationSaver.usrFilename          = struct('Callback','changedUsrFilename');
    s.hConfigurationSaver.usrPropList   = struct('Callback','changedUsrPropList');
    s.hConfigurationSaver.cfgLoadingInProgress = struct('Callback','changedCfgLoading');
    s.hConfigurationSaver.fastCfgCfgFilenames  = struct('GuiIDs',{{'fastConfigurationV4','pcFastCfgTable'}},'PropControlData',struct('columnIdx',3,'format','cellstr','customEncodeFcn',@zlclShortenFilename),'Callback','changedFastCfgCfgFilenames');
    s.hConfigurationSaver.fastCfgAutoStartTf   = struct('GuiIDs',{{'fastConfigurationV4','pcFastCfgTable'}},'PropControlData',struct('columnIdx',4,'format','logical'),'Callback','changedFastCfgAutoStartTf');
    s.hConfigurationSaver.fastCfgAutoStartType = struct('GuiIDs',{{'fastConfigurationV4','pcFastCfgTable'}},'PropControlData',struct('columnIdx',5,'format','options'));
    
    %%% UserFcns component
    s.hUserFunctions.userFunctionsCfg      = struct('Callback','changedUserFunctionsCfg');
    s.hUserFunctions.userFunctionsUsr      = struct('Callback','changedUserFunctionsUsr');
    
    %%% Power box
    s.hBeams.powerBoxes          = struct('Callback','changedPowerBoxes');
    s.hBeams.powerBoxStartFrame  = struct('GuiIDs',{{'powerBoxControlsV4','etStartFrame'}});
    s.hBeams.powerBoxEndFrame    = struct('GuiIDs',{{'powerBoxControlsV4','etEndFrame'}});

    %%% Motors component
    s.hMotors.calibrationPoints       = struct('Callback','changedMotorsCalibrationPoints');

    %%% Photostim component
    s.hPhotostim.status                     = struct('GuiIDs',{{'photostimControlsV5','etStatus'}}, 'Callback','changedPhotostimState');
    s.hPhotostim.stimulusMode               = struct('Callback','changedPhotostimMode');
    s.hPhotostim.stimImmediately            = struct('GuiIDs',{{'photostimControlsV5','cbStimImmediately'}});
    s.hPhotostim.numSequences               = struct('GuiIDs',{{'photostimControlsV5','etNumSequences'}});
    s.hPhotostim.stimTriggerTerm            = struct('Callback','changedPhotostimTrigger');
    s.hPhotostim.autoTriggerPeriod          = struct('Callback','changedPhotostimTrigger');
    s.hPhotostim.syncTriggerTerm            = struct('Callback','changedPhotostimSync');
    s.hPhotostim.sequenceSelectedStimuli    = struct('GuiIDs',{{'photostimControlsV5','etSequence'}});
    s.hPhotostim.allowMultipleOutputs       = struct('GuiIDs',{{'photostimControlsV5','cbAllowMult'}});
    s.hPhotostim.stimSelectionTriggerTerm   = struct('GuiIDs',{{'photostimControlsV5','etExtStimSelTriggerTerm'}});
    s.hPhotostim.stimSelectionTerms         = struct('GuiIDs',{{'photostimControlsV5','etExtStimSelTerms'}});
    s.hPhotostim.stimSelectionAssignment    = struct('GuiIDs',{{'photostimControlsV5','etExtStimSelAssignments'}});
    s.hPhotostim.monitoring                 = struct('GuiIDs',{{'photostimControlsV5','cbShowMonitor'}});
    s.hPhotostim.logging                    = struct('GuiIDs',{{'photostimControlsV5','cbLogging'}});
    s.hPhotostim.lastMotion                 = struct('GuiIDs',{{'photostimControlsV5','etMotionCorrectionVector'}});
    
    %%% IntegrationManager component
    s.hIntegrationRoiManager.enable         = struct('GuiIDs',{{'integrationRoiOutputChannelControlsV5','cbEnableIntegration','mainControlsV4','cbIntegration'}});
    s.hIntegrationRoiManager.enableDisplay  = struct('GuiIDs',{{'integrationRoiOutputChannelControlsV5','cbEnableDisplay'}});
    s.hIntegrationRoiManager.roiGroup       = struct('Callback','changedIntegrationRoiOutputChannel');
    s.hIntegrationRoiManager.hIntegrationRoiOutputChannels = struct('Callback','changedIntegrationRoiOutputChannel');
    
    %%% SLM component
    if ~isempty(hModel.hSlmScan) 
        s.hSlmScan.focalLength = struct('GuiIDs',{{'slmControls','etFocalLength_mm'}},'ViewScaling',1e3,'ViewPrecision','%.1f');
        s.hSlmScan.wavelength  = struct('GuiIDs',{{'slmControls','etWavelength_nm'}},'ViewScaling',1e9,'ViewPrecision','%.0f','Callback','changedSlmControls');
        s.hSlmScan.parkPosition_um = struct('Callback','changedSlmControls');
        s.hSlmScan.lut         = struct('Callback','changedSlmControls');
        s.hSlmScan.wavefrontCorrectionNominal = struct('Callback','changedSlmControls');
        s.hSlmScan.alignmentPoints = struct('Callback','changedSlmAlignmentPoints');
    end
    
    %%% WaveSurfer connector
    s.hWSConnector.enable = struct('Callback','changedWSConnectorEnable');
    
    %%% Cycle Manager
    s.hCycleManager.active = struct('Callback','changedAcqState');
    s.hCycleManager.waitParams = struct('Callback','changedAcqState');
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
