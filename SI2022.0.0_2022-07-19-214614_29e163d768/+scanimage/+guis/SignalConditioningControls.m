classdef SignalConditioningControls < most.Gui
    properties (SetObservable)
        updateRate = 10;
        traceLength = 2000;
        active = false;
        channel = 1;
        autoscale = true;
        
        laserTriggerFilter = 1;
        laserTriggerPhase = 0;
        enableSampleMask = false;
        samplingWindow = [0 1];
    end
    
    properties (Hidden)
        hPDFig;
        hAdvClkFig;
        
        hSI;
        hAxes;
        hWndoAxes;
        hDiffAxes;
        hDigAxes;
        
        hScan2D;
        hFpga;
        hSILis;
        hScan2DListners;
        hDataScope;
        hFifo;
        
        hPhysChannelTable;
        hVirtChannelTable;
        
        cbAutoOffset;
        pbAdvClk;
        pbApplyClockSettings;
        
        pbStart;
        hChanPop;
        lsrCh;
        
        etExtRate;
        etMult;
        etSampRate;
        etLaserPeriod;
        
        filterEnable = true(1,4);
        filter = {'40 MHz' '40 MHz' '40 MHz' '40 MHz'};

        phaseUnits;
        desiredPhs;
        actualPhs;
        phsRes;
        
        trigFiltRow;
        trigPhaseRow;
        
        upSimple;
        upAdvanced;
        
        pbDiscSettings;
        pmPhDetectMode;
        etPhDetectThresh;
        etPhDiffWidth;
        
        hPLLine;
        hSLLine;
        hAnLine;
        hDiffLine;
        hPcLine;
        hPcThLine;
        hDzLine
        hRawLLine;
        hFiltLLine;
        hMaskSurf  = matlab.graphics.primitive.Surface.empty();
        hMaskDLine = matlab.graphics.primitive.Line.empty();
        hMaskLLine = matlab.graphics.primitive.Line.empty();
        hMaskArrL  = matlab.graphics.primitive.Line.empty();
        hMaskArrH  = matlab.graphics.primitive.Line.empty();
        hMaskText  = matlab.graphics.primitive.Text.empty();
        scaleHistory;
        scaleHistoryD;
        
        hScaleText = matlab.graphics.primitive.Text.empty();
        hScaleTextD = matlab.graphics.primitive.Text.empty();
        
        initmode = false;
        settingsAreSimple;
        
        showPcTrace = false;
        showDiffTrace = false;
        
        unitConversion = 1;
        lastWindowUpdatePeriod;
        tholdDrag = false;
        lastData;

        hBlinkTimer = timer.empty();
        blinkCount = 3;
        blinkPeriod = 0.1;
    end
    
    properties (Hidden, SetObservable)
        triggerRate = '';
        wndStart = 0;
        wndEnd = 1;
        xlim;
        xlimMax;
        ylim = [-100 1000];
        ylimD = [-100 100];
        ylimMax = [-1000 1000];
        ylimDMax = [-1000 1000];
        units = 1;
        
        laserChoices = {}
        laserSel = '';
        showScope = false;
        showMask = false;
        
        clockSourceSel = 1;
        extClockRate = 125e6;
        clockMult = 1;
        sampleRate = 125e6;
        
        isH = false;
        
        digChcs;
        singleAcq;
        
        phDiscIdx = 1;

        hListeners = event.listener.empty(1,0);
    end

    properties (Hidden, SetObservable, Transient)
        triggerNominalPeriodTicksStr = '';
    end
    
    properties (Constant)
        PSEUDO_CLOCK_NAME = 'Custom Clock';
        SAMPLE_PHASE_SHIFT_CORRECTION = 31;
    end
    
    %% LifeCycle
    methods
        function obj = SignalConditioningControls(hSI,~)
            if nargin < 1
                try
                    obj.hSI = evalin('base','hSI');
                catch
                    error('ScanImage must be running.');
                end
            else
                obj.hSI = hSI;
            end
            
            assert(most.idioms.isValidObj(obj.hSI),'Could not find valid handle to ScanImage.');
            
            obj.showWaitbarDuringInitalization = true;
            
            obj.hFig.Name = 'Signal Conditioning Controls';
            obj.hFig.CloseRequestFcn = @obj.figCloseRequestFcn;
            obj.hFig.Position = most.gui.centeredScreenPos([1400 800]);

            obj.hBlinkTimer = timer('Name', 'Apply Clock Settings blink timer', ...
                'ExecutionMode', 'fixedSpacing', ...
                'TasksToExecute', obj.blinkCount*2, ...
                'Period', obj.blinkPeriod, ...
                'StopFcn', @obj.pbApplyClockSettings_restoreColor);
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hSILis);
            most.idioms.safeDeleteObj(obj.hScan2DListners);
            most.idioms.safeDeleteObj(obj.hPDFig);
            most.idioms.safeDeleteObj(obj.hAdvClkFig);
            most.idioms.safeDeleteObj(obj.hBlinkTimer);
        end
    end
    
    methods
        function start(obj)
            obj.stop(); % reset sampler system on FPGA
            if most.idioms.isValidObj(obj.hDataScope)
                obj.updateUnits();
                obj.scaleHistory = [];
                obj.scaleHistoryD = [];
                obj.channel = obj.channel;
                obj.traceLength = obj.traceLength;
                obj.hDataScope.includeSyncTrigger = obj.isH;
                obj.active = true;
                obj.hDataScope.trigger = '';
                obj.hDataScope.triggerHoldOffTime = 0;
                obj.hDataScope.callbackFcn = @obj.readSamples;
                obj.hDataScope.desiredSampleRate = obj.hDataScope.digitizerSampleRate;
                obj.hDataScope.startContinuousAcquisition();
            end
        end
        
        function stop(obj)
            obj.active = false;
            if most.idioms.isValidObj(obj.hSI.hScan2D.hDataScope)
                obj.hSI.hScan2D.hDataScope.abort();
            end
        end
        
        function loadConfig(obj,varargin)
            if nargin ~= 2
                [filename,pathname] = uigetfile('.mat','Choose filename to save channel settings to','channelSettings.mat');
                if filename==0;return;end
                filename = fullfile(pathname,filename);
            else
                filename = varargin{1};
            end
            
            cs = load(filename);
            obj.loadStruct(cs);
        end
        
        function applyClockSettings(obj,varargin)
            run = obj.active;
            
            obj.hScan2D.externalSampleClock = obj.clockSourceSel > 1;
            obj.hScan2D.externalSampleClockRate = obj.extClockRate;
            obj.hScan2D.externalSampleClockMultiplier = obj.clockMult;
            
            try
                obj.stop();

                % the high speed vDAQ only supports clock multiplier of 32 when using the external clock
                % (unless on the LRR bitfile)
                if obj.hScan2D.externalSampleClock && obj.isH && ~obj.hScan2D.hAcq.hAcqEngine.HSADC_LRR_SUPPORT
                    assert(obj.clockMult == 32, 'For the high speed vDAQ, the clock multiplier must be 32');
                end

                [tfExternalSuccess, err] = obj.hScan2D.reinitSampleClock();
                obj.hScan2D.saveClockSettings();
                
                if ~tfExternalSuccess
                    error(err);
                else
                    pbApplyClockSettings_startBlinkGreen();
                end
                
                if run
                    obj.start();
                end
            catch ME
                pbApplyClockSettings_startBlinkRed();
                warndlg(ME.message,'Sample Clock Error');
            end

            function pbApplyClockSettings_startBlinkRed()
                obj.hBlinkTimer.TimerFcn = @(varargin)pbApplyClockSettings_blinkCallback(most.constants.Colors.lightRed);
                obj.hBlinkTimer.start();
            end

            function pbApplyClockSettings_startBlinkGreen()
                obj.hBlinkTimer.TimerFcn = @(varargin)pbApplyClockSettings_blinkCallback(most.constants.Colors.lightGreen);
                obj.hBlinkTimer.start();
            end

            function pbApplyClockSettings_blinkCallback(blinkColor)
                if ~all(obj.pbApplyClockSettings.hCtl.BackgroundColor == blinkColor)
                    obj.pbApplyClockSettings.hCtl.BackgroundColor = blinkColor;
                else
                    obj.pbApplyClockSettings.hCtl.BackgroundColor = most.constants.Colors.lightGray;
                end
            end
        end

        function pbApplyClockSettings_restoreColor(obj,varargin)
            obj.pbApplyClockSettings.hCtl.BackgroundColor = most.constants.Colors.lightGray;
        end
        
        function measureOffsets(obj,varargin)
            if ~isempty(obj.hScan2D)
                obj.hScan2D.measureChannelOffsets([],true);
            end
        end
        
        function saveLaserTriggerSettings(obj,varargin)
            if ~isempty(obj.hScan2D)
                obj.hScan2D.saveLaserInputSettings();
            end
        end
        
        function saveFilterSettings(obj,varargin)
            if ~isempty(obj.hScan2D)
                obj.hScan2D.saveLaserTriggerSettings();
            end
        end
        
        function showDiscSettings(obj,varargin)
            if ~most.idioms.isValidObj(obj.hPDFig)
                makeFig();
            else
                most.idioms.figure(obj.hPDFig)
            end
            obj.phDiscIdx = obj.channel;
            
            function makeFig()
                obj.hPDFig = most.idioms.figure('Name', 'Photon Discriminator Settings', 'CloseRequestFcn', @hideFig, 'Position', most.gui.centeredScreenPos([255 132]),...
                    'numbertitle','off','MenuBar', 'none', 'Resize', 'off');
                f = most.gui.uiflowcontainer('parent',obj.hPDFig,'FlowDirection','TopDown', 'margin', 8);
                most.gui.uicontrol('parent',obj.hPDFig,'style','popupmenu','string',{'HSAI0' 'HSAI1'}, 'Bindings',{obj 'phDiscIdx' 'value'},'units','pixels','position',[80 107 60 22]);
                u = uipanel('parent',f,'Title','Settings for: ');
                ifl = most.gui.uiflowcontainer('Parent',u,'FlowDirection','TopDown');
                most.gui.uipanel('parent',ifl,'Bordertype','none','HeightLimits',4);
                rf = most.gui.uiflowcontainer('Parent',ifl,'FlowDirection','LeftToRight','HeightLimits',28);
                most.gui.staticText('parent',rf,'HorizontalAlignment','right','VerticalAlignment','middle','string','Detection Mode:','WidthLimits',105);
                obj.pmPhDetectMode = most.gui.uicontrol('parent',rf,'style','popupmenu','string',{'Threshold Crossing' 'Peak Detect'},'callback',@obj.changePhDetectMode);
                rf = most.gui.uiflowcontainer('Parent',ifl,'FlowDirection','LeftToRight','HeightLimits',28);
                most.gui.staticText('parent',rf,'HorizontalAlignment','right','VerticalAlignment','middle','string','Detection Threshold:','WidthLimits',105);
                obj.etPhDetectThresh = most.gui.uicontrol('parent',rf,'style','edit','callback',@obj.changePhDetectThresh,'WidthLimits',60,'KeyPressFcn',@obj.keyFunc2);
                rf = most.gui.uiflowcontainer('Parent',ifl,'FlowDirection','LeftToRight','HeightLimits',28);
                most.gui.staticText('parent',rf,'HorizontalAlignment','right','VerticalAlignment','middle','string','Differentiation Width:','WidthLimits',105);
                obj.etPhDiffWidth = most.gui.uicontrol('parent',rf,'style','edit','callback',@obj.changeDiffWidth,'WidthLimits',60,'KeyPressFcn',@obj.keyFunc2);
                obj.updatePcGui();
            end
            
            function hideFig(varargin)
                obj.hPDFig.Visible = 'off';
            end
        end
        
        function updatePcGui(obj,varargin)
            if obj.isH && most.idioms.isValidObj(obj.hPDFig)
                [~, obj.pmPhDetectMode.Value] = ismember(obj.hScan2D.photonDiscriminatorModes{obj.phDiscIdx}, {'threshold crossing' 'peak detect'});
                obj.etPhDetectThresh.String = num2str(obj.hScan2D.photonDiscriminatorThresholds(obj.phDiscIdx));
                obj.etPhDiffWidth.String = num2str(obj.hScan2D.photonDiscriminatorDifferentiateWidths(obj.phDiscIdx));
            end
        end
        
        function changePhDetectMode(obj,varargin)
            modes = {'threshold crossing' 'peak detect'};
            obj.hScan2D.photonDiscriminatorModes{obj.phDiscIdx} = modes{obj.pmPhDetectMode.Value};
            if ~obj.active && ~isempty(obj.lastData)
                obj.readSamples([],obj.lastData);
            end
        end
        
        function changePhDetectThresh(obj,varargin)
            obj.hScan2D.photonDiscriminatorThresholds(obj.phDiscIdx) = str2double(obj.etPhDetectThresh.String);
            if ~obj.active && ~isempty(obj.lastData)
                obj.readSamples([],obj.lastData);
            end
        end
        
        function changeDiffWidth(obj,varargin)
            obj.hScan2D.photonDiscriminatorDifferentiateWidths(obj.phDiscIdx) = max(min(str2double(obj.etPhDiffWidth.String),5),2);
            obj.etPhDiffWidth.String = num2str(obj.hScan2D.photonDiscriminatorDifferentiateWidths(obj.phDiscIdx));
            if ~obj.active && ~isempty(obj.lastData)
                obj.readSamples([],obj.lastData);
            end
        end
    end
    
    methods (Hidden)
        function plotSizeChanged(obj,~,~)
            set([obj.hAxes.Parent obj.hDigAxes obj.hAxes obj.hWndoAxes obj.hDiffAxes], 'Units', 'pixels');
            sz = obj.hAxes.Parent.Position([3 4]);
            xAxSize = 50;
            
            if isempty(obj.laserSel)
                digVsize = 0;
                obj.hDigAxes.Visible = 'off';
            else
                digVsize = 120;
                obj.hDigAxes.Visible = 'on';
            end
            
            if obj.showDiffTrace
                diffVsize = (sz(2)-digVsize)/3;
                obj.hDiffAxes.Visible = 'on';
                obj.hAxes.XTickLabel = [];
                obj.hAxes.XLabel = [];
                dvp = xAxSize;
            else
                diffVsize = 0;
                obj.hDiffAxes.Visible = 'off';
                obj.hAxes.XTickLabelMode = 'auto';
                xlabel(obj.hAxes, 'Sample Number/Time (Ticks)');
                dvp = -xAxSize;
            end
            
            obj.hDigAxes.Position = [-2 sz(2)-digVsize sz(1)+4 digVsize];
            obj.hAxes.Position = [-2 xAxSize+diffVsize sz(1)+4 sz(2)-digVsize-diffVsize-xAxSize];
            obj.hWndoAxes.Position = [-2 xAxSize+diffVsize sz(1)+4 sz(2)-digVsize-diffVsize-xAxSize];
            obj.hDiffAxes.Position = [-2 dvp sz(1)+4 diffVsize];
        end
        
        function phyTableCb(obj,~,evt)
            switch evt.Indices(2)
                case 2
                    obj.hSI.hChannels.channelInputRange{evt.Indices(1)} = str2num(evt.NewData);
                    obj.updatePhyTable();
                case 3
                    obj.hScan2D.channelsInvert(evt.Indices(1)) = logical(evt.NewData);
                case 4
                    obj.hSI.hChannels.channelSubtractOffset(evt.Indices(1)) = logical(evt.NewData);
                case 5
                    obj.hSI.hChannels.channelOffset(evt.Indices(1)) = evt.NewData;
                case 6
                    try
                        if evt.NewData
                            obj.filterEnable = true(1,obj.hSI.hScan2D.physicalChannelsAvailable);
                            obj.hScan2D.channelsFilter = obj.hPhysChannelTable.Data{1,7};
                        else
                            obj.filterEnable = false(1,obj.hSI.hScan2D.physicalChannelsAvailable);
                            obj.hScan2D.channelsFilter = 'fbw';
                        end
                    catch
                    end
                    obj.updatePhyTable();
                case 7
                    try
                        filter_ = str2double(evt.NewData);
                        
                        assert(filter_ > 0 && filter_ < 61);

                        if ~isnan(filter_)
                            filter_ = sprintf('%d MHz',filter_);
                        end
                        
                        obj.filter = repmat({filter_},1,obj.hSI.hScan2D.physicalChannelsAvailable);
                        
                        if obj.hPhysChannelTable.Data{1,6}
                            obj.hScan2D.channelsFilter = filter_;
                        else
                            obj.hScan2D.channelsFilter = 'fbw';
                        end
                    catch 
                        most.idioms.warn('%s: Invalid filter cutoff',class(obj));
                    end
                    obj.updatePhyTable();
            end
        end
        
        function updatePhyTable(obj,varargin)
            if isempty(obj.hScan2D)
                obj.hPhysChannelTable.Data = {};
            else
                N = obj.hScan2D.physicalChannelsAvailable;
                if obj.isH
                    d = arrayfun(@(n,r,i,s,o){{sprintf(' AI%d',n) sprintf('[%s %s]', num2str(r{1}(1)), num2str(r{1}(2))) logical(i) logical(s) o}'},0:(N-1),...
                        obj.hSI.hChannels.channelInputRange,obj.hScan2D.channelsInvert,obj.hSI.hChannels.channelSubtractOffset,obj.hSI.hChannels.channelOffset);
                else
                    d = arrayfun(@(n,r,i,s,o,fe,f){{sprintf(' AI%d',n) sprintf('[%s %s]', num2str(r{1}(1)), num2str(r{1}(2))) logical(i) logical(s) o fe f{1}}'},0:(N-1),...
                        obj.hSI.hChannels.channelInputRange,obj.hScan2D.channelsInvert,obj.hSI.hChannels.channelSubtractOffset,obj.hSI.hChannels.channelOffset,obj.filterEnable, obj.filter);
                end
                obj.hPhysChannelTable.Data = [d{:}]';
            end
        end
        
        function updateSettingDisplay(obj,varargin)
            v = obj.hScan2D.virtualChannelSettings;
            
            obj.updateVirtualTable();
            
            obj.initmode = true;
            obj.enableSampleMask = v(1).laserGate;
            obj.samplingWindow = v(1).laserFilterWindow;
            obj.initmode = false;
        end
        
        function virtualSettingsChanged(obj,varargin)
            obj.updateSettingDisplay();
            obj.updateWindowDisp();
            obj.checkForPc();
        end
        
        function updateVirtualTable(obj)
            if isempty(obj.hScan2D)
                obj.hVirtChannelTable.Data = {};
            else
                vcs = obj.hScan2D.virtualChannelSettings;
                Nv = numel(vcs);
                
                if obj.isH
                    d = arrayfun(@(n,s){{sprintf(' CH%d',n) [' ' upper(s.source)] s.mode ~logical(s.disableDivide)...
                        logical(s.laserGate) sprintf(' [%s %s]', num2str(s.laserFilterWindow(1)), num2str(s.laserFilterWindow(2))), ['   ' most.constants.Unicode.ballot_x]}'},1:Nv,vcs);
                    if numel(d) < obj.hScan2D.MAX_NUM_CHANNELS
                        d{end+1} = {'    +' '' '' '' '' '' ''}';
                    end
                else
                    d = arrayfun(@(n,s){{sprintf(' CH%d',n) [' ' upper(s.source)] logical(s.threshold) s.thresholdValue logical(s.binarize) logical(s.edgeDetect) logical(s.laserGate)...
                        sprintf(' [%s %s]', num2str(s.laserFilterWindow(1)), num2str(s.laserFilterWindow(2))), ['   ' most.constants.Unicode.ballot_x]}'},1:Nv,vcs);
                    if numel(d) < obj.hScan2D.MAX_NUM_CHANNELS
                        d{end+1} = {'    +' '' '' '' '' '' '' '' ''}';
                    end
                end
                
                obj.hVirtChannelTable.Data = [d{:}]';
            end
        end
        
        function virtualTableCb(obj,~,evt)
            try
                c = evt.Indices(2);
                
                c = c + 2*((c>4) && obj.isH);
                
                switch c
                    case 2
                        if strcmp('<delete row>', evt.NewData)
                            vcs = obj.hScan2D.virtualChannelSettings;
                            i = evt.Indices(1);
                            if i <= numel(vcs)
                                vcs(i) = [];
                                obj.hScan2D.virtualChannelSettings = vcs;
                            end
                        else
                            obj.hScan2D.virtualChannelSettings(evt.Indices(1)).source = upper(evt.NewData);
                        end
                    case 3
                        if obj.isH
                            obj.hScan2D.virtualChannelSettings(evt.Indices(1)).mode = lower(evt.NewData);
                        else
                            obj.hScan2D.virtualChannelSettings(evt.Indices(1)).threshold = logical(evt.NewData);
                        end
                    case 4
                        if obj.isH
                            obj.hScan2D.virtualChannelSettings(evt.Indices(1)).disableDivide = ~evt.NewData;
                        else
                            obj.hScan2D.virtualChannelSettings(evt.Indices(1)).thresholdValue = evt.NewData;
                        end
                    case 5
                        obj.hScan2D.virtualChannelSettings(evt.Indices(1)).binarize = logical(evt.NewData);
                    case 6
                        obj.hScan2D.virtualChannelSettings(evt.Indices(1)).edgeDetect = logical(evt.NewData);
                    case 7
                        if (obj.isH && (obj.clockMult == 32) && ~obj.hScan2D.hAcq.hAcqEngine.HSADC_LRR_SUPPORT) || ~obj.isH
                            obj.hScan2D.virtualChannelSettings(evt.Indices(1)).laserGate = logical(evt.NewData);
                        else
                            ss = arrayfun(@(s)setfield(s,'laserGate',logical(evt.NewData)),obj.hScan2D.virtualChannelSettings);
                            obj.hScan2D.virtualChannelSettings = ss;
                        end
                    case 8
                        obj.hScan2D.virtualChannelSettings(evt.Indices(1)).laserFilterWindow = str2num(evt.NewData);
                        lfw = obj.hScan2D.virtualChannelSettings(evt.Indices(1)).laserFilterWindow;
                        if lfw(2) < lfw(1)
                            obj.hScan2D.virtualChannelSettings(evt.Indices(1)).laserFilterWindow(2) = lfw(1);
                        elseif obj.hScan2D.hAcq.isH
                            obj.hScan2D.virtualChannelSettings(evt.Indices(1)).laserFilterWindow(2) = min([lfw(2) lfw(1)+32]);
                        end
                    case 9
                        %No-op
                    otherwise
                        %No-op
                end
            catch ME
                obj.virtualSettingsChanged();
                most.ErrorHandler.logAndReportError(ME);
                warndlg(ME.message);
            end
        end
        
        function virtualTableSelectionCb(obj,~,evt)
            try
                if ~isempty(evt.Indices)
                c = evt.Indices(2);
                
                c = c + 2*((c>4) && obj.isH);
                
                switch c
                    case 1
                        if evt.Indices(1) > numel(obj.hScan2D.virtualChannelSettings)
                            obj.hScan2D.virtualChannelSettings(evt.Indices(1)).source = 'AI0';
                            if obj.isH && (obj.clockMult ~= 32 || obj.hScan2D.hAcq.hAcqEngine.HSADC_LRR_SUPPORT) && numel(obj.hScan2D.virtualChannelSettings) > 1
                                obj.hScan2D.virtualChannelSettings(evt.Indices(1)).laserGate = obj.hScan2D.virtualChannelSettings(1).laserGate;
                            end
                        end
                    case 9
                        if evt.Indices(1) <= numel(obj.hScan2D.virtualChannelSettings)
                            obj.hScan2D.virtualChannelSettings(evt.Indices(1)) = [];
                        end
                    otherwise
                        %No-op
                end
                end
            catch ME
                obj.virtualSettingsChanged();
                most.ErrorHandler.logAndReportError(ME);
                warndlg(ME.message);
            end
        end
        
        function keyFunc(~,src,evt)
            switch evt.Key
                case 'uparrow'
                    n = str2num(src.String);
                    if ~isempty(n) && ~isnan(n)
                        src.String = n + 1;
                        src.Callback(src);
                    end
                case 'downarrow'
                    n = str2num(src.String);
                    if ~isempty(n) && ~isnan(n)
                        src.String = max(0,n-1);
                        src.Callback(src);
                    end
            end
        end
        
        function keyFunc2(~,src,evt)
            switch evt.Key
                case 'uparrow'
                    n = str2num(src.String);
                    if ~isempty(n) && ~isnan(n)
                        src.String = n + 1;
                        src.Callback(src);
                    end
                case 'downarrow'
                    n = str2num(src.String);
                    if ~isempty(n) && ~isnan(n)
                        src.String = n-1;
                        src.Callback(src);
                    end
            end
        end
        
        function readSamples(obj,~,data)
            if ~most.idioms.isValidObj(obj.hDataScope)
                return;
            end
            
            if obj.singleAcq || ~obj.Visible
                obj.stop();
            end
            
            %% parse data
            obj.lastData = data;
            analogData = single(data.data);
            
            if obj.isH
                rawlaser = nan(size(analogData,1),1);
                if ~isempty(obj.laserSel) && isfield(data.triggers,'SamplePhase')
                    firstSamplePhase = double(data.triggers.SamplePhase(1)) + obj.SAMPLE_PHASE_SHIFT_CORRECTION;
                    
                    laserClkPeriodTcks = double(obj.hFpga.laserClkPeriodSamples);
                    
                    syncTriggerPhase = mod((1:size(analogData,1))+firstSamplePhase,laserClkPeriodTcks);
                    syncTriggerGeneratedTrace = syncTriggerPhase < laserClkPeriodTcks/2;
                    
                    filteredlaser = syncTriggerGeneratedTrace;
                else
                    filteredlaser = nan(size(analogData,1),1);
                end
            else
                rawlaser = logical(data.triggers.LaserTriggerRaw);
                filteredlaser = logical(data.triggers.LaserTrigger);
            end
            
            obj.hAnLine.Visible = 'on';
            if isempty(obj.laserSel)
                obj.hRawLLine.Visible = 'off';
                obj.hFiltLLine.Visible = 'off';
            else
                obj.hRawLLine.Visible = 'on';
                obj.hFiltLLine.Visible = 'on';
            end
            
            %% calc diff and pc data
            if obj.showPcTrace
                threshold = obj.hScan2D.photonDiscriminatorThresholds(obj.channel);
                diffWidth = obj.hScan2D.photonDiscriminatorDifferentiateWidths(obj.channel);
                mode = obj.hScan2D.photonDiscriminatorModes{obj.channel};
                [pcData, analogDataD] = scanimage.fpga.sim.detectPhotons(analogData,mode,threshold,diffWidth,true);
            else
                analogDataD = nan(size(analogData));
                pcData = nan(size(analogData));
            end
            
            %% find laser rising edges
            if any(isnan(filteredlaser))
                reInds = [];
            else
                reInds = find(filteredlaser(2:end) .* ~filteredlaser(1:end-1)) + 1;
            end
            
            if isempty(obj.laserSel) || (numel(reInds) < 4)
                if isempty(obj.laserSel) || strcmp(obj.laserSel,obj.PSEUDO_CLOCK_NAME)
                    obj.triggerRate = '';
                else
                    obj.triggerRate = 'Not detected';
                end

                % reset the detected trigger period
                if ~obj.hScan2D.useCustomFilterClock
                    obj.triggerNominalPeriodTicksStr = '1';
                end

                obj.showMask = false;
                
                analogTraces = analogData;
                rawLaserTraces = single(rawlaser);
                filtLaserTraces = single(filteredlaser);
                
                analogTracesD = analogDataD;
                pcTraces = pcData;
                
                xdat = [1 length(analogData)];
                obj.xlimMax = xdat;
                xdat = (xdat(1):xdat(2))';
            else
                periods = reInds(2:end) - reInds(1:end-1);
                f = mean(single(periods));
                obj.triggerRate = sprintf('%.3f',obj.hDataScope.digitizerActualSampleRate*1e-6/f);
                p = round(f);
                obj.showMask = true;

                if obj.hScan2D.useCustomFilterClock
                    obj.triggerNominalPeriodTicksStr = obj.triggerNominalPeriodTicksStr;
                else
                    obj.triggerNominalPeriodTicksStr = num2str(p);
                end
                
                N = numel(reInds)-3;
                xl = [floor(obj.xlimMax(1))-1 ceil(obj.xlimMax(2))+1];
                L = ceil(diff(xl))+2;
                analogTraces = nan(L,N);
                rawLaserTraces = nan(L,N);
                filtLaserTraces = nan(L,N);
                analogTracesD = nan(L,N);
                pcTraces = nan(L,N);
                
                for ind = 1:N
                    reind = reInds(ind+1);
                    st = reind+xl(1)+1;
                    nd = reind+xl(2)+1;
                    if (st > 0) && (nd <= length(analogData))
                        analogTraces(1:end-1,ind) = analogData(st:nd);
                        analogTracesD(1:end-1,ind) = analogDataD(st:nd);
                        pcTraces(1:end-1,ind) = pcData(st:nd);
                        rawLaserTraces(1:end-1,ind) = rawlaser(st:nd);
                        filtLaserTraces(1:end-1,ind) = filteredlaser(st:nd);
                    end
                end
                
                xdat = repmat([xl(1):xl(2) nan]',N,1);
            end
            
            if obj.autoscale && (~obj.tholdDrag || obj.showDiffTrace)
                rg = [min(analogTraces(:)) max(analogTraces(:))] * obj.unitConversion;
                dr = max(diff(rg),10);
                lims = mean(rg) + .55*dr*[-1 1];
                
                if obj.singleAcq
                    obj.scaleHistory = lims;
                    obj.ylim = lims;
                else
                    obj.scaleHistory = [lims; obj.scaleHistory];
                    obj.scaleHistory(5:end,:) = [];
                    nwlms = [min(obj.scaleHistory(:,1)) max(obj.scaleHistory(:,2))];
                    olims = obj.ylim;
                    dff = (nwlms - olims) .* [1 -1];
                    d = min(dff,dff*.2) .* [1 -1];
                    obj.ylim = olims + d;
                end
            end
            
            if obj.showDiffTrace
                obj.hDiffLine.YData = analogTracesD(:);
                obj.hDiffLine.XData = xdat+1;
                
                if obj.autoscale && ~obj.tholdDrag
                    rg = [min(analogTracesD(:)) max(analogTracesD(:))];
                    dr = max(diff(rg),10);
                    lims = mean(rg) + .55*dr*[-1 1];
                    
                    if obj.singleAcq
                        obj.scaleHistoryD = lims;
                        obj.ylimD = lims;
                    else
                        obj.scaleHistoryD = [lims; obj.scaleHistoryD];
                        obj.scaleHistoryD(5:end,:) = [];
                        nwlms = [min(obj.scaleHistoryD(:,1)) max(obj.scaleHistoryD(:,2))];
                        olims = obj.ylimD;
                        dff = (nwlms - olims) .* [1 -1];
                        d = min(dff,dff*.2) .* [1 -1];
                        obj.ylimD = olims + d;
                    end
                end
            else
                obj.hDiffLine.YData = nan;
                obj.hDiffLine.XData = nan;
            end
            
            if obj.showPcTrace
                obj.hPcLine.Visible = 'on';
                obj.hPcLine.YData = pcTraces(:) * obj.unitConversion;
                obj.hPcLine.XData = xdat+1;
            else
                obj.hPcLine.Visible = 'off';
            end
            
            obj.hAnLine.Visible = 'on';
            obj.hAnLine.YData = analogTraces(:) * obj.unitConversion;
            obj.hAnLine.XData = xdat+1+~obj.isH;
            
            obj.hRawLLine.YData = rawLaserTraces(:);
            obj.hRawLLine.XData = xdat+3;
            
            obj.hFiltLLine.YData = filtLaserTraces(:);
            obj.hFiltLLine.XData = xdat+1;
        end
        
        function figCloseRequestFcn(obj,src,~)
            src.Visible = 'off';
            obj.stop();
        end
        
        function wndHit(obj,src,evt)
            persistent id
            persistent inds
            persistent op
            persistent ov
            persistent original_size
            
            if strcmp(evt.EventName, 'Hit')
                if any(src == [obj.hMaskDLine obj.hMaskArrH])
                    inds = 1;
                elseif any(src == obj.hMaskSurf)
                    inds = [1 2];
                else
                    inds = 2;
                end
                op = obj.hWndoAxes.CurrentPoint(1);
                id = src.UserData;
                ov = obj.hScan2D.virtualChannelSettings(id).laserFilterWindow(inds);
                original_size = diff(ov);
                set(obj.hFig,'WindowButtonMotionFcn',@obj.wndHit,'WindowButtonUpFcn',@obj.wndHit);
            elseif strcmp(evt.EventName, 'WindowMouseMotion')
                mouseMoveResult = ov + round(obj.hWndoAxes.CurrentPoint(1) - op);
                
                % enforce not below zero, but maintain the original size
                if numel(inds) == 2
                    mouseMoveResult = max(mouseMoveResult,[0 original_size]);
                else
                    mouseMoveResult = max(mouseMoveResult,0);
                end
                % enforce not above the clock multiplier
                if numel(inds) == 2
                    mouseMoveResult = min(mouseMoveResult,[obj.hScan2D.customFilterClockPeriod-original_size obj.hScan2D.customFilterClockPeriod]);
                else
                    mouseMoveResult = min(mouseMoveResult,obj.hScan2D.customFilterClockPeriod);
                end
                
                % set window
                obj.hScan2D.virtualChannelSettings(id).laserFilterWindow(inds) = mouseMoveResult;
                lfw = obj.hScan2D.virtualChannelSettings(id).laserFilterWindow;
                if lfw(2) < lfw(1)
                    obj.hScan2D.virtualChannelSettings(id).laserFilterWindow(2) = lfw(1);
                elseif obj.hScan2D.hAcq.isH
                    obj.hScan2D.virtualChannelSettings(id).laserFilterWindow(2) = min([lfw(2) lfw(1)+32]);
                end
            else
                set(obj.hFig,'WindowButtonMotionFcn',[],'WindowButtonUpFcn',[]);
                obj.updateVirtualTable();
            end
        end
        
        function updateWindowDisp(obj)
            if ~obj.showMask
                set([obj.hMaskSurf obj.hMaskDLine obj.hMaskLLine obj.hPLLine obj.hSLLine obj.hMaskArrL obj.hMaskArrH obj.hMaskText], 'Visible', 'off');
            else
                sa = obj.hScan2D.virtualChannelSettings;
                set([obj.hPLLine obj.hSLLine], 'Visible', 'on');
                N = sum(arrayfun(@(s)s.laserGate && strcmpi(s.source, sprintf('AI%d',obj.channel-1)), sa));
                inc = 1 / (N+1);
                y = 1 - inc;
                
                obj.hWndoAxes.Units = 'pixels';
                aw = obj.hWndoAxes.Position(3);
                p2u = diff(obj.xlim) / aw;
                
                for i = 1:64
                    objs = [obj.hMaskSurf(i) obj.hMaskDLine(i) obj.hMaskLLine(i) obj.hMaskArrL(i) obj.hMaskArrH(i)];
                    if (numel(sa) >= i)
                        if sa(i).laserGate && strcmpi(sa(i).source, sprintf('AI%d',obj.channel-1))
                            updateObjs(sa(i).laserFilterWindow,y);
                            y = y - inc;
                            set(objs,'Visible','on');
                            set(obj.hMaskText(i),'Visible','on');
                        else
                            set(objs,'Visible','off');
                            set(obj.hMaskText(i),'Visible','off');
                        end
                    elseif (i == 1) && obj.enableSampleMask
                        updateObjs(sa(i).laserFilterWindow,mean(obj.ylim));
                        set(objs,'Visible','on');
                        set(obj.hMaskText(i),'Visible','off');
                    else
                        set(objs,'Visible','off');
                        set(obj.hMaskText(i),'Visible','off');
                    end
                end
            end
            
            function updateObjs(wnd,yi)
                offs = .5;
                obj.hMaskSurf(i).XData = repmat([wnd(1) wnd(2)] + [-offs offs],2,1);
                obj.hMaskDLine(i).XData = repmat(wnd(1),1,2)-offs;
                obj.hMaskLLine(i).XData = repmat(wnd(2),1,2)+offs;
                obj.hMaskArrL(i).XData(1:2) = [0 wnd(1)-offs];
                obj.hMaskArrH(i).XData(1) = wnd(1)-offs-6*p2u;
                obj.hMaskArrL(i).YData = yi * [1 1 nan 1 1] * obj.unitConversion;
                obj.hMaskArrH(i).YData = yi * [1 nan 1] * obj.unitConversion;
                obj.hMaskText(i).Position = [(wnd(1)-offs+4*p2u) yi];
            end
        end
        
        function setImgSys(obj,varargin)
            obj.stop();
            delete(obj.hScan2DListners);
            
            if isa(obj.hSI.hScan2D, 'scanimage.components.scan2d.RggScan')
                obj.hScan2D = obj.hSI.hScan2D;
                obj.hDataScope = obj.hScan2D.hDataScope;
                obj.isH = obj.hDataScope.isH;
                obj.hFpga = obj.hDataScope.hFpga;
                
                numchans = obj.hScan2D.physicalChannelsAvailable;
                obj.channel = min(obj.channel,numchans);
                obj.hChanPop.String = arrayfun(@(n){sprintf('AI%d',n-1)},1:numchans);
                
                obj.initmode = true;
                
                obj.clockSourceSel = 1 + obj.hScan2D.externalSampleClock;
                if obj.hScan2D.externalSampleClock
                    obj.extClockRate = obj.hScan2D.externalSampleClockRate;
                    obj.clockMult = obj.hScan2D.externalSampleClockMultiplier;
                    obj.sampleRate = obj.extClockRate * obj.clockMult;
                else
                    obj.extClockRate = obj.hFpga.internalClockSourceRate;
                    if obj.isH
                        obj.clockMult = 20;
                        obj.sampleRate = 20 * obj.hFpga.internalClockSourceRate;
                    else
                        obj.clockMult = 1;
                        obj.sampleRate = obj.hFpga.internalClockSourceRate;
                    end
                end
                
                if obj.isH && obj.hScan2D.useCustomFilterClock
                    obj.laserSel = obj.PSEUDO_CLOCK_NAME;
                else
                    obj.laserSel = obj.hScan2D.LaserTriggerPort;
                end
                
                inputRgFmt = cellfun(@(r)sprintf('[%s %s]',num2str(r(1)),num2str(r(2))),obj.hScan2D.channelsAvailableInputRanges,'UniformOutput',false);
                if obj.isH
                    obj.trigFiltRow.Visible = 'off';
                    obj.trigPhaseRow.Visible = 'on';
                    obj.laserTriggerPhase = obj.hFpga.syncTrigPhaseAdjust;
                    
                    obj.hPhysChannelTable.ColumnName = {'' 'Range' 'Invert' 'Subtract Offset' 'Offset Value'};
                    obj.hPhysChannelTable.ColumnWidth = {25 50 40 90 80};
                    obj.hPhysChannelTable.ColumnEditable = [false true true true true];
                    obj.hPhysChannelTable.ColumnFormat = {'char' inputRgFmt 'logical' 'logical' 'numeric'};
                    
                    bits = 12;
                    
                    obj.pbAdvClk.Enable = 'off';
                    obj.hAdvClkFig.Visible = 'off';
                else
                    obj.trigPhaseRow.Visible = 'off';
                    obj.trigFiltRow.Visible = 'on';
                    obj.laserTriggerFilter = obj.hSI.hScan2D.laserTriggerDebounceTicks;
                    
                    obj.hPhysChannelTable.ColumnName = {'' 'Range' 'Invert' 'Offset' 'Offset' 'LP Filter' 'Cutoff'};
                    obj.hPhysChannelTable.ColumnWidth = {25 50 40 50 60 50 50};
                    obj.hPhysChannelTable.ColumnEditable = [false true true true true true true];
                    obj.hPhysChannelTable.ColumnFormat = {'char' inputRgFmt 'logical' 'logical' 'numeric' 'logical' 'char'};
                    
                    bits = 16;
                    
                    obj.pbAdvClk.Enable = 'on';
                    obj.updatePhsSettingDisplay();
                end
                lims = 2^(bits-1) * [-1.1 1.1];
                obj.ylimMax = lims;
                obj.ylim = lims;
                obj.ylimDMax = 2*lims;
                obj.ylimD = lims;
                
                obj.updatePhyTable();
                                
                nch = obj.hFpga.hAfe.physicalChannelCount;
                ops = arrayfun(@(n){sprintf('AI%d',n-1)},1:nch);
                ops{end+1} = '<delete row>';
                if obj.isH
                    obj.hVirtChannelTable.ColumnName = {'' 'Source' 'Mode' 'Average' 'Laser Filter' 'Window' 'Delete'};
                    obj.hVirtChannelTable.ColumnWidth = {36 50 140 54 75 60 63};
                    obj.hVirtChannelTable.ColumnEditable = [false true true true true true false];
                    obj.hVirtChannelTable.ColumnFormat = {'char' ops {'analog' 'photon counting'} 'logical' 'logical' 'char' 'char'};
                else
                    obj.hVirtChannelTable.ColumnName = {'' 'Source' 'Threshold' 'Threshold' 'Binarize' 'Edge Detect' 'Laser Filt' 'Window' 'Delete'};
                    obj.hVirtChannelTable.ColumnWidth = {36 50 60 60 50 72 50 60 40};
                    obj.hVirtChannelTable.ColumnEditable = [false true true true true true true true false];
                    obj.hVirtChannelTable.ColumnFormat = {'char' ops 'logical' 'numeric' 'logical' 'logical' 'logical' 'char' 'char'};
                end
                obj.virtualSettingsChanged();
                
                obj.hScan2DListners = most.ErrorHandler.addCatchingListener(obj.hScan2D, 'virtualChannelSettings', 'PostSet', @obj.virtualSettingsChanged);
                
                obj.cbAutoOffset.bindings = {obj.hScan2D 'channelsAutoReadOffsets' 'value'};
                obj.hScan2DListners(end+1) =  most.ErrorHandler.addCatchingListener(obj.hSI.hChannels, 'channelOffset', 'PostSet', @obj.updatePhyTable);
                obj.hScan2DListners(end+1) =  most.ErrorHandler.addCatchingListener(obj.hSI.hChannels, 'channelSubtractOffset', 'PostSet', @obj.updatePhyTable);
                obj.hScan2DListners(end+1) =  most.ErrorHandler.addCatchingListener(obj.hSI.hChannels, 'channelInputRange', 'PostSet', @obj.inputRangeChanged);
                obj.hScan2DListners(end+1) =  most.ErrorHandler.addCatchingListener(obj.hScan2D, 'channelsInvert', 'PostSet', @obj.updatePhyTable);
                obj.hScan2DListners(end+1) =  most.ErrorHandler.addCatchingListener(obj.hScan2D, 'photonDiscriminatorThresholds', 'PostSet', @obj.updatePcThLine);
                obj.hScan2DListners(end+1) =  most.ErrorHandler.addCatchingListener(obj.hScan2D, 'photonDiscriminatorModes', 'PostSet', @obj.checkForPc);
                obj.hScan2DListners(end+1) =  most.ErrorHandler.addCatchingListener(obj.hScan2D, 'photonDiscriminatorDifferentiateWidths', 'PostSet', @obj.checkForPc);
                
                obj.initmode = false;
            else
                obj.hScan2D = [];
                obj.hDataScope = [];
                obj.cbAutoOffset.bindings = {};
            end
        end
        
        function inputRangeChanged(obj,varargin)
            obj.updatePhyTable();
            obj.updateUnits();
        end
        
        function pbStartCb(obj, varargin)
            if obj.active
                obj.stop();
            else
                obj.singleAcq = false;
                obj.start();
            end
        end
        
        function pbGrabSingle(obj, varargin)
            obj.stop();
            obj.singleAcq = true;
            obj.start();
        end
        
        function actvChanged(obj,varargin)
            if obj.active
                str = 'Stop Scope';
            else
                str = 'Start Continuous';
            end
            obj.pbStart.Value = obj.active;
            obj.pbStart.String = str;
        end
        
        function checkForPc(obj,varargin)
            currentChan = sprintf('AI%d',obj.channel-1);
            obj.showPcTrace = obj.isH && any(arrayfun(@(s)strcmp(s.mode, 'photon counting') && strcmpi(s.source, currentChan),obj.hScan2D.virtualChannelSettings));
            obj.showDiffTrace = obj.showPcTrace && obj.hFpga.hsPhotonDifferentiate(obj.channel);
            obj.updatePcThLine();
            obj.pbDiscSettings.Visible = obj.showPcTrace;
            obj.updatePcGui();
            if ~obj.active && ~isempty(obj.lastData)
                obj.readSamples([],obj.lastData);
            end
        end
        
        function updatePcThLine(obj,varargin)
            if obj.isH && ~isempty(obj.hFpga)
                obj.hPcThLine.Visible = most.idioms.ifthenelse(obj.showPcTrace,'on','off');
                obj.hPcThLine.Parent = most.idioms.ifthenelse(obj.hFpga.hsPhotonDifferentiate(obj.channel),obj.hDiffAxes,obj.hAxes);
                if obj.showPcTrace
                    th = obj.hScan2D.photonDiscriminatorThresholds(obj.channel);
                    obj.hPcThLine.YData(:) = th * most.idioms.ifthenelse(obj.hFpga.hsPhotonDifferentiate(obj.channel),1,obj.unitConversion);
                    obj.hPcThLine.XData = obj.xlimMax;
                end
                obj.updatePcGui();
            end
        end
        
        function updateUnits(obj)
            if obj.units > 1
                bits = 14 - 2*obj.isH;
                rg = 1000*diff(obj.hSI.hChannels.channelInputRange{obj.channel});
                newConv = rg/(2^bits);
            else
                newConv = 1;
            end
            
            chg = obj.unitConversion ~= newConv;
            if chg
                cnv = newConv / obj.unitConversion;
                obj.unitConversion  = newConv;
                
                for h = obj.hAxes.Children'
                    if ~isa(h,'matlab.graphics.primitive.Text')
                        h.YData = h.YData * cnv;
                    end
                end
                
                obj.ylim = obj.ylim * cnv;
                obj.scaleHistory = obj.scaleHistory * cnv;
            end
        end
        
        function scrollWheelFcn(obj, ~, eventData)
            currentKeyModifiers = get(obj.hFig, 'currentModifier');
            noMods = isempty(currentKeyModifiers);
            isCtlPressed = ismember('control', currentKeyModifiers);
            scrollCount = eventData.VerticalScrollCount;
            
            if noMods && (checkIsMouseInAxes(obj.hAxes) || checkIsMouseInAxes(obj.hDigAxes) || checkIsMouseInAxes(obj.hDiffAxes))
                xpt = obj.hAxes.CurrentPoint(1);
                xpts = obj.xlim - xpt;
                obj.xlim = xpts * 1.2^scrollCount + xpt;
                return
            end
            
            if isCtlPressed && checkIsMouseInAxes(obj.hAxes)
                obj.autoscale = false;
                
                ypt = obj.hAxes.CurrentPoint(1,2);
                ypts = obj.ylim - ypt;
                obj.ylim = ypts * 1.2^scrollCount + ypt;
                return
            end
            
            if isCtlPressed && checkIsMouseInAxes(obj.hDiffAxes)
                obj.autoscale = false;
                
                ypt = obj.hDiffAxes.CurrentPoint(1,2);
                ypts = obj.ylimD - ypt;
                obj.ylimD = ypts * 1.2^scrollCount + ypt;
                return
            end
        end
        
        function dragThold(obj,~,evt)
            if strcmp(evt.EventName,'Hit')
                obj.tholdDrag = true;
                set(obj.hFig,'WindowButtonMotionFcn',@obj.dragThold,'WindowButtonUpFcn',@obj.dragThold);
            elseif strcmp(evt.EventName, 'WindowMouseMotion')
                obj.hScan2D.photonDiscriminatorThresholds(obj.channel) = round(obj.hPcThLine.Parent.CurrentPoint(1, 2));
                if ~obj.active && ~isempty(obj.lastData)
                    obj.readSamples([],obj.lastData);
                end
            else
                set(obj.hFig,'WindowButtonMotionFcn',[],'WindowButtonUpFcn',[]);
                obj.tholdDrag = false;
            end
        end
        
        function panAxes(obj,src,evt)
            persistent hAx
            persistent ylimvar
            persistent opt
            
            if strcmp(evt.EventName,'Hit')
                hAx = src;
                if src == obj.hAxes
                    ylimvar = 'ylim';
                elseif src == obj.hDiffAxes
                    ylimvar = 'ylimD';
                else
                    ylimvar = '';
                end
                opt = hAx.CurrentPoint(1,1:2);
                set(obj.hFig,'WindowButtonMotionFcn',@obj.panAxes,'WindowButtonUpFcn',@obj.panAxes);
            elseif strcmp(evt.EventName, 'WindowMouseMotion')
                dff = opt - hAx.CurrentPoint(1,1:2);
                obj.xlim = obj.xlim + dff(1);
                if ~obj.autoscale && ~isempty(ylimvar)
                    obj.(ylimvar) = obj.(ylimvar) + dff(2);
                end
                opt = hAx.CurrentPoint(1,1:2);
            else
                set(obj.hFig,'WindowButtonMotionFcn',[],'WindowButtonUpFcn',[]);
            end
        end
        
        function advancedClockSettings(obj,varargin)
            if obj.isH
                most.idioms.warn('Sampling phase delay only supported by standard vDAQ.');
            else
                if ~most.idioms.isValidObj(obj.hAdvClkFig)
                    makeFig();
                else
                    most.idioms.figure(obj.hAdvClkFig)
                end
                obj.updatePhsSettingDisplay();
            end
            
            function makeFig()
                obj.hAdvClkFig = most.idioms.figure('Name', 'Advanced Clock Settings', 'CloseRequestFcn', @hideFig, 'Position', most.gui.centeredScreenPos([295 86]),...
                    'numbertitle','off','MenuBar', 'none', 'Resize', 'off');
                f = most.gui.uiflowcontainer('parent',obj.hAdvClkFig,'FlowDirection','TopDown', 'margin', 4);
                rf = most.gui.uiflowcontainer('Parent',f,'FlowDirection','LeftToRight','HeightLimits',25);
                    most.gui.staticText('parent',rf,'HorizontalAlignment','right','VerticalAlignment','middle','string','Sample Clock Fine Adjust:','WidthLimits',130);
                    obj.desiredPhs = most.gui.uicontrol('parent',rf,'style','edit','callback',@changePhaseSetting,'WidthLimits',60,'KeyPressFcn',@phaseInc);
                    obj.phaseUnits = most.gui.uicontrol('parent',rf,'style','popupmenu','Tag','phaseUnits','string',{'Phase (deg)' 'Delay (ps)'},'WidthLimits',85, 'callback', @obj.updatePhsSettingDisplay);
                rf = most.gui.uiflowcontainer('Parent',f,'FlowDirection','LeftToRight','HeightLimits',25);
                    most.gui.staticText('parent',rf,'HorizontalAlignment','right','VerticalAlignment','middle','string','Actual Value:','WidthLimits',130);
                    obj.actualPhs = most.gui.uicontrol('parent',rf,'style','edit','WidthLimits',90,'BackgroundColor',.95*ones(1,3),'enable','inactive');
                    most.gui.uicontrol('parent',rf,'string','Apply','callback',@applyPhaseSetting);
                rf = most.gui.uiflowcontainer('Parent',f,'FlowDirection','LeftToRight','HeightLimits',26);
                    most.gui.staticText('parent',rf,'HorizontalAlignment','right','VerticalAlignment','top','string','Adjustment resolution:','WidthLimits',130);
                    obj.phsRes = most.gui.staticText('parent',rf,'HorizontalAlignment','left','VerticalAlignment','top','string','');
            end
            
            function hideFig(varargin)
                obj.hAdvClkFig.Visible = 'off';
            end
            
            function phaseInc(~,evt)
                phs = obj.hScan2D.sampleClockPhase;
                if isempty(phs)
                    phs = 0;
                end
                phs_step = obj.hScan2D.hAcq.hFpga.getMsadcSamplingPhaseStep();
                
                switch evt.Key
                    case 'uparrow'
                        newPhs = phs + phs_step;
                    case 'downarrow'
                        newPhs = phs - phs_step;
                    otherwise
                        return;
                end
                
                obj.hScan2D.sampleClockPhase = round(newPhs/phs_step)*phs_step;
                obj.updatePhsSettingDisplay();
            end
            
            function changePhaseSetting(varargin)
                phase = str2double(obj.desiredPhs.String);
                
                if phase == 0
                    obj.hScan2D.sampleClockPhase = [];
                else
                    if obj.phaseUnits.Value == 2
                        phase = mod(360 * (phase/1e12) * obj.sampleRate,360);
                    end
                    
                    obj.hScan2D.sampleClockPhase = phase;
                end
                
                obj.updatePhsSettingDisplay();
            end
            
            function applyPhaseSetting(varargin)
                if obj.hScan2D.hAcq.hFpga.nominalAcqSampleRate == obj.sampleRate
                    % looks like all the other clock settings are already
                    % applied. we can just update the phase setting which
                    % is faster than updating all the clock settings
                    obj.hScan2D.hAcq.hFpga.setMsadcSamplingPhase(obj.hScan2D.sampleClockPhase);
                    obj.hScan2D.saveClockSettings();
                else
                    obj.applyClockSettings();
                end
            end
        end
        
        function updatePhsSettingDisplay(obj,varargin)
            if most.idioms.isValidObj(obj.hAdvClkFig)
                phs = obj.hScan2D.sampleClockPhase;
                if isempty(phs)
                    phs = 0;
                end
                
                if obj.phaseUnits.Value == 2
                    phs = 1e12 * (phs/360) / obj.sampleRate;
                end
                
                obj.desiredPhs.String = num2str(phs);
                
                phs_step = getPhsStep();
                actPhs = round(phs/phs_step)*phs_step;
                
                if obj.phaseUnits.Value == 1
                    obj.actualPhs.String = [num2str(actPhs) ' deg'];
                    obj.phsRes.String = [num2str(phs_step) ' deg'];
                else
                    obj.actualPhs.String = [num2str(actPhs) ' ps'];
                    obj.phsRes.String = [num2str(phs_step) ' ps'];
                end
            end
            
            function v = getPhsStep()
                if obj.phaseUnits.Value == 1
                    v = obj.hScan2D.hAcq.hFpga.getMsadcSamplingPhaseStep();
                else
                    v = obj.hScan2D.hAcq.hFpga.getMsadcSamplingDelayStep();
                end
            end
        end
    end
    
    %% most.GUI
    methods (Access = protected)
        function initGui(obj)
            f = most.gui.uiflowcontainer('Parent',obj.hFig,'FlowDirection','BottomUp','margin',0.00001);
            pf = uipanel('Parent',f,'bordertype','none');
            obj.hDigAxes = most.idioms.axes('Parent',pf,'Box','on','XGrid','on','XMinorGrid','on','ylim',[-.25 1.25],'ytick',[0 1],'YTickLabel',{'L' 'H'},'XTickLabel',[],'ButtonDownFcn',@obj.panAxes);
            obj.hRawLLine = line('parent',obj.hDigAxes,'xdata',[0 0],'ydata',obj.ylim,'Color','b','Linewidth',.5,'visible','off');
            obj.hFiltLLine = line('parent',obj.hDigAxes,'xdata',[0 0],'ydata',obj.ylim,'Color','k','Linewidth',1,'visible','off');
            text(.5,.99,'Laser Trigger','parent',obj.hDigAxes,'horizontalalignment','center','Units', 'normalized','VerticalAlignment','top','FontSize',11,'FontWeight','bold');
            obj.hAxes = most.idioms.axes('Parent',pf,'Box','on','XGrid','on','YGrid','on','XMinorGrid','on','ylim',obj.ylim,'ButtonDownFcn',@obj.panAxes);
            obj.hAnLine = line('parent',obj.hAxes,'xdata',[0 0],'ydata',obj.ylim,'Color','k','Linewidth',1,'marker','.','visible','off','markersize',10);
            obj.hPcLine = line('parent',obj.hAxes,'xdata',[0 0],'ydata',obj.ylim,'Color','none','marker','o','MarkerFaceColor',most.constants.Colors.orange,'MarkerEdgeColor', 'k', 'visible','off','markersize',10);
            obj.hPcThLine = line('parent',obj.hAxes,'xdata',[0 0],'ydata',[0 0],'Color',most.constants.Colors.orange,'linestyle','--','visible','off','LineWidth',3,'ButtonDownFcn',@obj.dragThold);
            obj.hWndoAxes = most.idioms.axes('Parent',pf,'XColor','none','YColor','none','XMinorGrid','on','ylim',[0 1],'color','none','XTick',[],'YTick',[],'Visible','off');
            obj.hPLLine = line('parent',obj.hWndoAxes,'xdata',[0 0],'ydata',[0 1],'Color','r','Linewidth',2,'visible','off');
            obj.hSLLine = line('parent',obj.hWndoAxes,'xdata',[0 0 nan 0 0],'ydata',[0 1 nan 0 1],'Color','r','Linewidth',2,'LineStyle','--','visible','off');
            colors = repmat({'g' 'b' 'r' [0.6    0.19    0.8] [0 1 1] [0.6392 0.2863 0.6431] [.5 .5 1] [0 .5 .5] [.5 .25 0] [.25 0 .25]},1,7);
            for i = 1:64
                obj.hMaskSurf(end+1) = surface('parent',obj.hWndoAxes,'xdata',[0 1; 0 1],'ydata',[0 1; 0 1]','zdata',zeros(2),'FaceColor',colors{i},'Facealpha',.3,'linestyle','none','ButtonDownFcn',@obj.wndHit,'userdata',i,'visible','off');
                obj.hMaskDLine(end+1) = line('parent',obj.hWndoAxes,'xdata',[0 0],'ydata',[0 1],'Color','k','Linewidth',1,'LineStyle','--','ButtonDownFcn',@obj.wndHit,'userdata',i,'visible','off');
                obj.hMaskLLine(end+1) = line('parent',obj.hWndoAxes,'xdata',[1 1],'ydata',[0 1],'Color','k','Linewidth',1,'LineStyle','--','ButtonDownFcn',@obj.wndHit,'userdata',i,'visible','off');
                obj.hMaskArrL(end+1) = line('parent',obj.hWndoAxes,'xdata',nan(1,5),'ydata',.5 * [1 1 nan 1 1],'Color','k','Linewidth',1,'Marker','.','markersize',16,'userdata',i,'visible','off');
                obj.hMaskArrH(end+1) = line('parent',obj.hWndoAxes,'xdata',nan(1,3),'ydata',.5 * [1 nan 1],'Color','k','Linewidth',1,'Marker','>','markersize',6,'MarkerFaceColor','w','ButtonDownFcn',@obj.wndHit,'userdata',i,'visible','off');
                obj.hMaskText(end+1) = text(0,0,sprintf('Channel %d',i),'parent',obj.hWndoAxes,'horizontalalignment','left','VerticalAlignment','middle','userdata',i,'FontSize',11,'visible','off');
            end
            text(.5,.99,'PMT Signal','parent',obj.hWndoAxes,'horizontalalignment','center','Units', 'normalized','VerticalAlignment','top','FontSize',11,'FontWeight','bold');
            obj.hDiffAxes = most.idioms.axes('Parent',pf,'Box','on','XGrid','on','YGrid','on','XMinorGrid','on','ylim',[0 1],'ButtonDownFcn',@obj.panAxes);
            obj.hDiffLine = line('parent',obj.hDiffAxes,'xdata',[0 0],'ydata',nan(1,2),'Color',most.constants.Colors.orange*.7,'Linewidth',1,'marker','.','markersize',10);
            text(.5,.99,'Differentiated PMT Signal','parent',obj.hDiffAxes,'horizontalalignment','center','Units', 'normalized','VerticalAlignment','top','FontSize',11,'FontWeight','bold');
            obj.hDzLine = line('parent',obj.hDiffAxes,'xdata',[0 0],'ydata',[0 0],'Color',most.constants.Colors.orange,'linestyle','-','LineWidth',1);
            xlabel(obj.hDiffAxes, 'Sample Number/Time (Ticks)');
            pf.SizeChangedFcn = @obj.plotSizeChanged;
            
            rf = most.gui.uiflowcontainer('Parent',obj.hFig,'FlowDirection','LeftToRight','Units','pixels','position',[1 5 300 24]);
            most.gui.staticText('parent',rf,'HorizontalAlignment','right','VerticalAlignment','bottom','string','Vertical Units:','WidthLimits',70);
            most.gui.uicontrol('parent',rf,'style','popupmenu','string',{'ADC Counts' 'Milivolts (mV)'},'WidthLimits',88,'Bindings',{obj 'units' 'value'});
            most.gui.uipanel('parent',rf,'WidthLimits',12,'bordertype','none');
            most.gui.uicontrol('parent',rf,'style','checkbox','string','Autoscale','WidthLimits',100,'Bindings',{obj 'autoscale' 'value'});
            
            
            lf = most.gui.uiflowcontainer('Parent',f,'FlowDirection','LeftToRight','HeightLimits',160,'margin',4);
            up = most.gui.uipanel('parent',lf,'title','Sample Clock Settings','WidthLimits',200);
            upf = most.gui.uiflowcontainer('Parent',up,'FlowDirection','TopDown','margin',0.00001);
            ifl = most.gui.uiflowcontainer('Parent',upf,'FlowDirection','TopDown');
            rf = most.gui.uiflowcontainer('Parent',ifl,'FlowDirection','LeftToRight','HeightLimits',24);
            most.gui.staticText('parent',rf,'HorizontalAlignment','right','VerticalAlignment','middle','string','Clock Source:','WidthLimits',120);
            most.gui.uicontrol('parent',rf,'style','popupmenu','string',{'Internal' 'External'},'Bindings',{obj 'clockSourceSel' 'value'});
            rf = most.gui.uiflowcontainer('Parent',ifl,'FlowDirection','LeftToRight','HeightLimits',22);
            most.gui.staticText('parent',rf,'HorizontalAlignment','right','VerticalAlignment','middle','string','Input Clock Rate (MHz):','WidthLimits',120);
            obj.etExtRate = most.gui.uicontrol('parent',rf,'style','edit','Bindings',{obj 'extClockRate' 'value' '%.2f' 'scaling' 1e-6});
            rf = most.gui.uiflowcontainer('Parent',ifl,'FlowDirection','LeftToRight','HeightLimits',22);
            most.gui.staticText('parent',rf,'HorizontalAlignment','right','VerticalAlignment','middle','string','Clock Multiplier:','WidthLimits',120);
            obj.etMult = most.gui.uicontrol('parent',rf,'style','edit','Bindings',{obj 'clockMult' 'value' '%.2f'});
            rf = most.gui.uiflowcontainer('Parent',ifl,'FlowDirection','LeftToRight','HeightLimits',22);
            most.gui.staticText('parent',rf,'HorizontalAlignment','right','VerticalAlignment','middle','string','Sample Rate (MHz):','WidthLimits',120);
            obj.etSampRate = most.gui.uicontrol('parent',rf,'style','edit','Bindings',{obj 'sampleRate' 'value' '%.2f' 'scaling' 1e-6});
            ifl = most.gui.uiflowcontainer('Parent',upf,'FlowDirection','Bottomup','HeightLimits',28,'margin',0.00001);
            rf = most.gui.uiflowcontainer('Parent',ifl,'FlowDirection','RightToLeft');
            obj.pbApplyClockSettings = most.gui.uicontrol('parent',rf,'string','Apply Clock Settings','WidthLimits',120,'callback',@obj.applyClockSettings);
            obj.pbAdvClk = most.gui.uicontrol('parent',rf,'string','Advanced','WidthLimits',64,'callback',@obj.advancedClockSettings);
            
            up = most.gui.uipanel('parent',lf,'title','Physical Channel Settings','WidthLimits',344);
            ifl = most.gui.uiflowcontainer('Parent',up,'FlowDirection','TopDown','margin',4);
            obj.hPhysChannelTable = uitable('Parent',ifl,'rowname',{},'CellEditCallback',@obj.phyTableCb);
            utPhyJo = most.gui.findjobj(obj.hPhysChannelTable);
            utPhyJo.HorizontalScrollBarPolicy = 31; %never
            rf = most.gui.uiflowcontainer('Parent',ifl,'FlowDirection','LeftToRight','HeightLimits',24,'margin',0.00001);
            %                                 most.gui.uicontrol('Parent',rf,'string','Revert Settings','callback',@obj.revertSettings,'WidthLimits',90);
            most.gui.uicontrol('Parent',rf,'string','Measure Offsets','callback',@obj.measureOffsets,'WidthLimits',100);
            most.gui.uipanel('parent',rf,'bordertype','none','WidthLimits',10);
            obj.cbAutoOffset = most.gui.uicontrol('Parent',rf,'string','Auto Measure Offsets','style','checkbox','WidthLimits',130);
            
            up = most.gui.uipanel('parent',lf,'title','Laser Trigger Settings','WidthLimits',180);
            ifl = most.gui.uiflowcontainer('Parent',up,'FlowDirection','TopDown');
            rf = most.gui.uiflowcontainer('Parent',ifl,'FlowDirection','LeftToRight','HeightLimits',24);
            most.gui.staticText('parent',rf,'HorizontalAlignment','right','VerticalAlignment','middle','string','Input Terminal:','WidthLimits',102);
            obj.lsrCh = most.gui.uicontrol('parent',rf,'style','popupmenu','Bindings',{{obj 'laserChoices' 'choices'} {obj 'laserSel' 'choice'}});
            obj.trigFiltRow = most.gui.uiflowcontainer('Parent',ifl,'FlowDirection','LeftToRight','HeightLimits',22);
            most.gui.staticText('parent',obj.trigFiltRow,'HorizontalAlignment','right','VerticalAlignment','middle','string','Trigger Filter (Ticks):','WidthLimits',102);
            most.gui.uicontrol('parent',obj.trigFiltRow,'style','edit','Bindings',{obj 'laserTriggerFilter' 'value'},'KeyPressFcn',@obj.keyFunc);
            obj.trigPhaseRow = most.gui.uiflowcontainer('Parent',ifl,'FlowDirection','LeftToRight','HeightLimits',22);
            most.gui.staticText('parent',obj.trigPhaseRow,'HorizontalAlignment','right','VerticalAlignment','middle','string','Trigger Phase Adjust:','WidthLimits',102);
            most.gui.uicontrol('parent',obj.trigPhaseRow,'style','edit','Bindings',{obj 'laserTriggerPhase' 'value'},'KeyPressFcn',@obj.keyFunc2);
            rf = most.gui.uiflowcontainer('Parent',ifl,'FlowDirection','LeftToRight','HeightLimits',22);
            most.gui.staticText('parent',rf,'HorizontalAlignment','right','VerticalAlignment','middle','string','Detected Freq (MHz):','WidthLimits',102);
            most.gui.uicontrol('parent',rf,'style','edit','Bindings',{obj 'triggerRate' 'string'},'BackgroundColor',.95*ones(1,3),'enable','on');
            rf = most.gui.uiflowcontainer('Parent',ifl,'FlowDirection','LeftToRight','HeightLimits',22);
            most.gui.staticText('parent',rf,'HorizontalAlignment','right','VerticalAlignment','middle','string','Period (Ticks):','WidthLimits',102);
            obj.etLaserPeriod = most.gui.uicontrol('parent',rf,'style','edit','Bindings',{obj 'triggerNominalPeriodTicksStr' 'string'},'BackgroundColor',.95*ones(1,3),'enable','inactive');
            iflb = most.gui.uiflowcontainer('Parent',ifl,'FlowDirection','BottomUp','margin',0.00001);
            rf = most.gui.uiflowcontainer('Parent',iflb,'FlowDirection','RightToLeft','HeightLimits',28);
            most.gui.uicontrol('Parent',rf,'string','Save Trigger Settings','callback',@obj.saveLaserTriggerSettings,'WidthLimits',150);
                        
            obj.upAdvanced = most.gui.uipanel('parent',lf,'bordertype','none','WidthLimits',510,'Visible','on');
            ifl = most.gui.uiflowcontainer('Parent',obj.upAdvanced,'FlowDirection','TopDown','margin',0.00001);
            u = most.gui.uipanel('parent',ifl,'title','Virtual Channel Settings');
            ifl = most.gui.uiflowcontainer('Parent',u,'FlowDirection','TopDown','margin',0.00001);
            tf = most.gui.uiflowcontainer('Parent',ifl,'FlowDirection','TopDown','margin',4);
            obj.hVirtChannelTable = uitable('Parent',tf,'rowname',{},'CellEditCallback',@obj.virtualTableCb, 'CellSelectionCallback', @obj.virtualTableSelectionCb);
            utVirtJo = most.gui.findjobj(obj.hVirtChannelTable);
            utVirtJo.HorizontalScrollBarPolicy = 31; %never
            obj.updateVirtualTable();
            bf = most.gui.uiflowcontainer('Parent',ifl,'FlowDirection','LeftToRight','HeightLimits',28,'margin',0.00001);
            rf = most.gui.uiflowcontainer('Parent',bf,'FlowDirection','LeftToRight','HeightLimits',28);
            obj.pbDiscSettings = most.gui.uicontrol('Parent',rf,'string','Photon Discriminator Settings','callback',@obj.showDiscSettings,'WidthLimits',175,'Visible','off');
            rf = most.gui.uiflowcontainer('Parent',bf,'FlowDirection','RightToLeft','HeightLimits',28);
            %                                 most.gui.uicontrol('Parent',rf,'string','Revert Settings','callback',@obj.revertSettings,'WidthLimits',90);
            most.gui.uicontrol('Parent',rf,'string','Save Channel Settings','callback',@obj.saveFilterSettings,'WidthLimits',150);
            
            

            
            
            lfb = most.gui.uiflowcontainer('Parent',lf,'FlowDirection','RightToLeft','margin',0.00001);
            up = most.gui.uipanel('parent',lfb,'title','Signal Scope','WidthLimits',140);
            ifl = most.gui.uiflowcontainer('Parent',up,'FlowDirection','TopDown','margin',0.00001);
            %                                 rf = most.gui.uiflowcontainer('Parent',ifl,'FlowDirection','LeftToRight','HeightLimits',18);
            %                                     most.gui.staticText('parent',rf,'HorizontalAlignment','right','string','Show Scope:','WidthLimits',90);
            %                                     most.gui.uicontrol('parent',rf,'style','checkbox','WidthLimits',16,'Bindings',{obj 'showScope' 'value'});
            rf = most.gui.uiflowcontainer('Parent',ifl,'FlowDirection','LeftToRight','HeightLimits',28);
            most.gui.staticText('parent',rf,'HorizontalAlignment','right','VerticalAlignment','middle','string','Physical Channel:','WidthLimits',90);
            obj.hChanPop = most.gui.uicontrol('parent',rf,'style','popupmenu','string',{' '},'Bindings',{obj 'channel' 'value'});
            rf = most.gui.uiflowcontainer('Parent',ifl,'FlowDirection','LeftToRight','HeightLimits',22);
            most.gui.staticText('parent',rf,'HorizontalAlignment','right','string','Capture Length:','WidthLimits',90);
            most.gui.uicontrol('parent',rf,'style','edit','Bindings',{obj 'traceLength' 'value'});
            ifl = most.gui.uiflowcontainer('Parent',ifl,'FlowDirection','BottomUp','margin',0.00001);
            rf = most.gui.uiflowcontainer('Parent',ifl,'FlowDirection','LeftToRight','HeightLimits',28);
            most.gui.uicontrol('parent',rf,'style','pushbutton','string','Grab Single','callback',@obj.pbGrabSingle);
            rf = most.gui.uiflowcontainer('Parent',ifl,'FlowDirection','LeftToRight','HeightLimits',28);
            obj.pbStart = most.gui.uicontrol('parent',rf,'style','togglebutton','string','Start Continuous','Bindings',{obj 'active' 'callback' @obj.actvChanged},'callback',@obj.pbStartCb);
            
            obj.xlimMax = [-4 20];
            
            obj.hSILis = most.ErrorHandler.addCatchingListener(obj.hSI, 'imagingSystem','PostSet',@obj.setImgSys);
            obj.setImgSys();
            obj.updateSettingDisplay();
            obj.hFig.WindowScrollWheelFcn = @obj.scrollWheelFcn;

            obj.initListeners();
        end
    end

    %% Listeners
    methods
        function initListeners(obj)
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hScan2D,'customFilterClockPeriod','PostSet',@obj.updateTriggerNominalPeriodTicksStr);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hScan2D.hAcq.hFpga,'syncTrigPhaseAdjust','PostSet',@obj.updateSyncTrigPhaseAdjust);
        end

        function updateTriggerNominalPeriodTicksStr(obj,varargin)
            if obj.hScan2D.useCustomFilterClock
                newStr = num2str(obj.hScan2D.customFilterClockPeriod);
                if ~strcmp(obj.triggerNominalPeriodTicksStr,newStr)
                    obj.triggerNominalPeriodTicksStr = newStr;
                end
            end
        end

        function updateSyncTrigPhaseAdjust(obj,varargin)
            if obj.laserTriggerPhase ~= obj.hScan2D.hAcq.hFpga.syncTrigPhaseAdjust
                obj.laserTriggerPhase = obj.hScan2D.hAcq.hFpga.syncTrigPhaseAdjust;
            end
        end
    end
    
    %% Property Getter/Setter
    methods
        function set.triggerNominalPeriodTicksStr(obj,v)
            try
                validateattributes(v,{'char'},{'scalartext'});
                v = str2double(v);
                validateattributes(v,{'numeric'},{'nonnegative','finite','scalar','integer'})
            catch ME
                most.ErrorHandler.logAndReportError(false,ME);
            end

            obj.hScan2D.customFilterClockPeriod = v;
            obj.triggerNominalPeriodTicksStr = num2str(obj.hScan2D.customFilterClockPeriod);

            vs = (v+2) * [-.1 1.05];
            obj.xlimMax = vs;
            obj.hSLLine.XData = [-v -v nan v v];

            if isempty(obj.lastWindowUpdatePeriod) || (~isequal(obj.lastWindowUpdatePeriod,obj.hScan2D.customFilterClockPeriod))
                obj.updateWindowDisp();
                obj.lastWindowUpdatePeriod = obj.hScan2D.customFilterClockPeriod;
            end
        end
        
        function set.units(obj,v)
            obj.units = v;
            obj.updateUnits();
        end
        
        function set.ylim(obj,v)
            v(1) = min(max(obj.ylimMax(1),v(1)),obj.ylimMax(2)-100);
            v(2) = min(max(obj.ylimMax(1)+100,v(2)),obj.ylimMax(2));
            
            if ~isequal(obj.ylim, v) || isempty(obj.hScaleTextD)
                obj.ylim = v;
                
                obj.hAxes.YLim = obj.ylim;
                
                tcks = obj.hAxes.YTick;
                N = numel(tcks);
                x = obj.xlim(1) + .015*diff(obj.xlim);
                for i = 1:N
                    if numel(obj.hScaleText) < i
                        obj.hScaleText(end+1) = text(0,0,'','parent',obj.hAxes,'horizontalalignment','left','VerticalAlignment','middle','userdata',i,'FontSize',11,'BackgroundColor','w');
                    end
                    obj.hScaleText(i).Position = [x tcks(i)];
                    obj.hScaleText(i).String = num2str(tcks(i));
                    obj.hScaleText(i).Visible = 'on';
                end
                set(obj.hScaleText(i+1:end),'Visible','off');
            else
                % only need x update
                x = obj.xlim(1) + .015*diff(obj.xlim);
                N = numel(obj.hAxes.YTick);
                for i = 1:min(N,numel(obj.hScaleText))
                    obj.hScaleText(i).Position(1) = x;
                end
            end
        end
        
        function set.ylimD(obj,v)
            v(1) = min(max(obj.ylimDMax(1),v(1)),obj.ylimDMax(2)-100);
            v(2) = min(max(obj.ylimDMax(1)+100,v(2)),obj.ylimDMax(2));
            
            if ~isequal(obj.ylimD, v) || isempty(obj.hScaleTextD)
                obj.ylimD = v;
                
                obj.hDiffAxes.YLim = obj.ylimD;
                
                tcks = obj.hDiffAxes.YTick;
                N = numel(tcks);
                x = obj.xlim(1) + .015*diff(obj.xlim);
                for i = 1:N
                    if numel(obj.hScaleTextD) < i
                        obj.hScaleTextD(end+1) = text(0,0,'','parent',obj.hDiffAxes,'horizontalalignment','left','VerticalAlignment','middle','userdata',i,'FontSize',11,'BackgroundColor','w');
                    end
                    obj.hScaleTextD(i).Position = [x tcks(i)];
                    obj.hScaleTextD(i).String = num2str(tcks(i));
                    obj.hScaleTextD(i).Visible = 'on';
                end
                set(obj.hScaleTextD(i+1:end),'Visible','off');
            else
                % only need x update
                x = obj.xlim(1) + .015*diff(obj.xlim);
                N = numel(obj.hDiffAxes.YTick);
                for i = 1:min(N,numel(obj.hScaleTextD))
                    obj.hScaleTextD(i).Position(1) = x;
                end
            end
        end
        
        function set.xlim(obj,v)
            v(1) = min(max(obj.xlimMax(1),v(1)),obj.xlimMax(2)-10);
            v(2) = min(max(obj.xlimMax(1)+10,v(2)),obj.xlimMax(2));
            
            if ~isequal(v, obj.xlim)
                obj.xlim = v;
                
                obj.hAxes.XLim = v;
                obj.hWndoAxes.XLim = v;
                obj.hDigAxes.XLim = v;
                obj.hDiffAxes.XLim = v;
                obj.hDzLine.XData = v;
                setMinorXTick(obj.hAxes, v(1):round(diff(v)/50):v(2));
                setMinorXTick(obj.hDigAxes, v(1):round(diff(v)/50):v(2));
                setMinorXTick(obj.hDiffAxes, v(1):round(diff(v)/50):v(2));
                
                obj.updatePcThLine();
                obj.ylim = obj.ylim;
                obj.ylimD = obj.ylimD;
                obj.updateWindowDisp();
            end
        end
        
        function set.xlimMax(obj,v)
            if ~isequal(v, obj.xlimMax)
                obj.xlimMax = v;
                obj.xlim = v;
            end
        end
        
        function v = get.samplingWindow(obj)
            v = [obj.wndStart obj.wndEnd];
        end
        
        function set.samplingWindow(obj,v)
            % end cannot be before start
            if v(2) < v(1)
                v(2) = v(1);
            end

            obj.wndStart = v(1);
            obj.wndEnd = most.idioms.ifthenelse(obj.hSI.hScan2D.hAcq.isH,min([v(2) v(1)+32]),v(2));
        end
        
        function set.wndStart(obj,v)
            v = max(round(v),0);
            obj.wndStart = v;
            if ~obj.initmode
                obj.hSI.hScan2D.laserTriggerSampleWindow = obj.samplingWindow;
            end
        end
        
        function set.wndEnd(obj,v)
            v = max(round(v),1);
            obj.wndEnd = v;
            if ~obj.initmode
                obj.hSI.hScan2D.laserTriggerSampleWindow = obj.samplingWindow;
            end
        end
        
        function set.laserTriggerFilter(obj,v)
            obj.laserTriggerFilter = v;
            if ~obj.initmode && ~obj.isH
                obj.hSI.hScan2D.laserTriggerDebounceTicks = v;
            end
        end
        
        function set.laserTriggerPhase(obj,v)
            obj.laserTriggerPhase = v;
            if ~obj.initmode
                obj.hFpga.syncTrigPhaseAdjust = v;
            end
        end
        
        function set.enableSampleMask(obj,v)
            obj.enableSampleMask = v;
            if ~obj.initmode
                obj.hSI.hScan2D.laserTriggerSampleMaskEnable = v;
            end
        end
        
        function set.traceLength(obj,v)
            if most.idioms.isValidObj(obj.hDataScope)
                try
                    v = double(min(v,obj.hDataScope.hFifo.fifoNumberOfElementsFpga));
                catch
                    v = double(min(v,obj.hDataScope.hFifo.localBufferSizeBytes/2));
                end
            end
            obj.traceLength = v;
            obj.hDataScope.acquisitionTime = obj.traceLength / obj.hDataScope.digitizerSampleRate;
        end
        
        function set.channel(obj,v)
            obj.channel = v;
            obj.lastData = [];
            obj.hDataScope.channel = obj.channel;
            if ~obj.active
                obj.hAnLine.Visible = 'off';
                obj.hDiffLine.YData = nan;
                obj.hDiffLine.XData = nan;
                obj.hPcLine.Visible = 'off';
            end
            obj.updateWindowDisp();
            obj.checkForPc();
            obj.updateUnits();
        end
        
        function v = get.settingsAreSimple(obj)
            v = ~obj.hSI.hScan2D.laserTriggerFilterSupport || ~obj.hSI.hScan2D.laserTriggerDemuxSupport;
            if ~v
                sArray = obj.hScan2D.virtualChannelSettings;
                Nv = numel(sArray);
                v = Nv == obj.hFpga.hAfe.physicalChannelCount;
                v = v && all(arrayfun(@(s,idx)strcmp(sprintf('AI%d',idx-1),s.source),sArray,1:Nv)) && all(~[sArray.threshold sArray.binarize sArray.edgeDetect]);
                w = [sArray.laserFilterWindow];
                v = v && all(sArray(1).laserGate == [sArray.laserGate]) && (~sArray(1).laserGate || (all(w(1) == w(1:2:end)) && all(w(2) == w(2:2:end))));
            end
        end
        
        function set.clockSourceSel(obj,v)
            obj.clockSourceSel = v;
            
            hResourceStore = dabs.resources.ResourceStore();
            hDIs   = hResourceStore.filter(@(hR)isa(hR,'dabs.resources.ios.DI')&&isequal(hR.hDAQ,obj.hScan2D.hDAQ));
            hCLKIs = hResourceStore.filter(@(hR)isa(hR,'dabs.resources.ios.CLKI')&&isequal(hR.hDAQ,obj.hScan2D.hDAQ));
            
            DIs   = cellfun(@(v)v.name,hDIs  ,'UniformOutput',false);
            CLKIs = cellfun(@(v)v.name,hCLKIs,'UniformOutput',false);
            
            DIs   = regexp(DIs,  '[^\/]+$','match','once')';
            CLKIs = regexp(CLKIs,'[^\/]+$','match','once')';
            
            isExt = v > 1;
            if isExt
                set([obj.etExtRate obj.etMult obj.etSampRate], 'enable', 'on');
                set([obj.etExtRate obj.etMult obj.etSampRate], 'backgroundcolor', ones(1,3));
                
                obj.lsrCh.Enable = 'on';
                if obj.isH
                    obj.laserChoices = [{''}; CLKIs];

                    if obj.hScan2D.hAcq.hAcqEngine.HSADC_LRR_SUPPORT
                        obj.laserChoices = [obj.laserChoices; {obj.PSEUDO_CLOCK_NAME}];
                    end
                else
                    obj.laserChoices = [{''}; CLKIs; DIs];
                end
                
                p = obj.initmode;
                obj.initmode = true;
                obj.laserSel = obj.laserSel;
                obj.initmode = p;
            else
                obj.extClockRate = 125e6;
                obj.clockMult = 1 + 19 * obj.isH;
                
                set([obj.etExtRate obj.etMult obj.etSampRate], 'enable', 'inactive');
                set([obj.etExtRate obj.etMult obj.etSampRate], 'backgroundcolor', .95*ones(1,3));

                if strcmp(obj.laserSel, obj.PSEUDO_CLOCK_NAME)
                    obj.laserSel = '';
                end
                
                if obj.isH
                    obj.lsrCh.Enable = 'off';
                    obj.laserChoices = {''};
                else
                    obj.lsrCh.Enable = 'on';
                    obj.laserChoices = [{''}; DIs];
                end
                
                if strfind(obj.laserSel, 'CLK')
                    obj.laserSel = '';
                else
                    p = obj.initmode;
                    obj.initmode = true;
                    obj.laserSel = obj.laserSel;
                    obj.initmode = p;
                end
            end
        end
        
        function set.extClockRate(obj,v)
            obj.extClockRate = v;
            
            if ~obj.initmode
                obj.initmode = true;
                obj.sampleRate = obj.extClockRate * obj.clockMult;
                obj.initmode = false;
            end
        end
        
        function set.clockMult(obj,v)
            obj.clockMult = v;
            
            if ~obj.initmode
                obj.initmode = true;
                obj.sampleRate = obj.extClockRate * obj.clockMult;
                obj.initmode = false;
            end
        end
        
        function set.sampleRate(obj,v)
            obj.sampleRate = v;
            
            if ~obj.initmode
                obj.initmode = true;
                obj.clockMult = obj.sampleRate / obj.extClockRate;
                obj.initmode = false;
                obj.updatePhsSettingDisplay();
            end
        end
        
        function set.laserSel(obj,v)
            if most.idioms.isValidObj(v)
                v = v.name;
                v = regexp(v,'[^/]+$','match','once');
            elseif ~ischar(v)
                v = '';
            end
            
            if strcmp(v,obj.PSEUDO_CLOCK_NAME)
                obj.hScan2D.useCustomFilterClock = true;
                obj.etLaserPeriod.Enable = 'on';
                obj.triggerNominalPeriodTicksStr = num2str(obj.hScan2D.customFilterClockPeriod);
                obj.etLaserPeriod.hCtl.BackgroundColor = ones(1,3);
            else
                obj.hScan2D.useCustomFilterClock = false;
                obj.etLaserPeriod.Enable = 'inactive';
                obj.etLaserPeriod.hCtl.BackgroundColor = 0.95*ones(1,3);
            end

            obj.laserSel = v;
            
            if ~obj.initmode
                obj.hScan2D.LaserTriggerPort = qualifyName(v);
            end
            
            obj.plotSizeChanged();
            
            function v = qualifyName(v)
                if isempty(v)
                    v = '';
                else
                    v = ['/' obj.hScan2D.hDAQ.name '/' v];
                end
            end
        end
        
        function set.autoscale(obj, v)
            if ~v
                obj.scaleHistory = obj.ylim;
                obj.scaleHistoryD = obj.ylimD;
            end
            obj.autoscale = v;
        end
        
        
        function set.showDiffTrace(obj,v)
            if obj.showDiffTrace ~= v
                obj.showDiffTrace = v;
                obj.plotSizeChanged();
            end
        end
        
        function set.phDiscIdx(obj,v)
            obj.phDiscIdx = v;
            obj.updatePcGui();
        end
    end
end

function setMinorXTick(hA, vs)
if isprop(hA, 'XAxis')
    hA.XAxis.MinorTickValues = vs;
else
    hA.XRuler.MinorTick = vs;
end
end

function tf = checkIsMouseInAxes(hAx)
coords = hAx.CurrentPoint(1, 1:2);
xl = hAx.XLim;
yl = hAx.YLim;
tf = coords(1) >= xl(1) && coords(1) <= xl(2) && coords(2) >= yl(1) && coords(2) <= yl(2);
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
