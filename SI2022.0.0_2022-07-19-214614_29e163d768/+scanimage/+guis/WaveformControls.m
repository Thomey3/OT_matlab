classdef WaveformControls < most.Gui
    
    properties (SetObservable)
        hWM;
        
        hTabGroup;
        hGalvoTab;
        hBeamTab;
        hFastzTab;
        hVisLis;
        
        hPlotPanelX;
        hPlotPanelY;
        hPlotPanelB;
        hPlotPanelBpb;
        hPlotPanelZ;
        
        pbRefresh;
        pbTest;
        pbOptimize;
        pbAccept;
        pbAbortO;
        pbAbortT;
        pbReset;
        pbCalibrate;
        
        hStatusFlow;
        hStatusText;
        
        hHistoryMenu;
        
        mouseMotionFunc;
        optMode = false;
        testMode = false;
        optCmd = '';
    end
    
    %% Lifecycle
    methods
        function obj = WaveformControls(hModel, hController)
            %% main figure
            if nargin < 1
                hModel = [];
            end
            
            if nargin < 2
                hController = [];
            end
            
            sz = get(0,'ScreenSize');
            obj = obj@most.Gui(hModel, hController, round(sz([3 4])*.8));
            set(obj.hFig,'Name','WAVEFORM CONTROLS');
            
            obj.showWaitbarDuringInitalization = true;
            
            if ~isempty(obj.hModel)
                obj.hWM = obj.hModel.hWaveformManager;
            end
        end
        
        function delete(obj)
            delete(obj.hPlotPanelX);
            delete(obj.hPlotPanelY);
            delete(obj.hPlotPanelB);
            delete(obj.hPlotPanelBpb);
            delete(obj.hPlotPanelZ);
            delete(obj.hVisLis);
        end
    end
    
    methods
        function tabChanged(obj,~,evt)
            obj.updateCurrentWaveforms();
            
            wavePlots = evt.NewValue.UserData;
            for i = 1:numel(wavePlots)
                wavePlots(i).resize();
            end
        end
        
        function visibilityChanged(obj,varargin)
            if obj.Visible
                obj.updateCurrentWaveforms();
            end
        end
        
        function updateCurrentWaveforms(obj,varargin)
            % if this was invoked from the user clicking the button, it
            % will have src and evt. Otherwise it was invoked internally
            isUsrReq = nargin > 1;
            obj.hStatusText.String = 'Updating waveforms...';
            drawnow('nocallbacks');
            
            if ~isempty(obj.hModel)
                try
                    obj.hWM.updateWaveforms();
                    ao = obj.hWM.scannerAO;
                    updateTabVisibility();
                    ss = obj.hModel.hScan2D.scannerset;
                    
                    switch obj.hTabGroup.SelectedTab
                        case obj.hGalvoTab
                            refreshGalvos();
                        case obj.hBeamTab
                            refreshBeams('B', obj.hPlotPanelB);
                            refreshBeams('Bpb', obj.hPlotPanelBpb);
                        case obj.hFastzTab
                            refreshFastZ();
                    end
                catch ME
                    most.ErrorHandler.logError(ME);
                    blankTabData();
                end
                
                obj.hPlotPanelX.updateCallback('done');
                obj.hPlotPanelY.updateCallback('done');
                obj.hPlotPanelZ.updateCallback('done');
                obj.optMode = false;
                obj.testMode = false;
            else
                simulateTabData();
            end
            
            obj.updateButtonStatus();
            obj.hStatusText.String = '';
            
            function refreshGalvos()
                [optimized,metaData] = obj.hWM.retrieveOptimizedAO('G',false);
                
                if ~isempty(optimized)
                    obj.hGalvoTab.Title = 'Galvos (Optimized)';
                    obj.pbReset.Enable = 'on';
                else
                    obj.hGalvoTab.Title = 'Galvos';
                    obj.pbReset.Enable = 'off';
                end
                
                for i = 1:2
                    % check for x galvo
                    if i == 1
                        if size(ao.ao_volts.G,2) < 2
                            obj.hPlotPanelX.visible = 0;
                            continue;
                        else
                            obj.hPlotPanelX.visible = 1;
                        end
                        hPP = obj.hPlotPanelX;
                        actuatorName = '_xGalvo';
                        scanner = obj.hModel.hScan2D.xGalvo;
                    else
                        obj.hPlotPanelX.visible = 1;
                        hPP = obj.hPlotPanelY;
                        actuatorName = '_yGalvo';
                        scanner = obj.hModel.hScan2D.yGalvo;
                    end
                    
                    isOptimized = (size(optimized,1) > 0) && (size(optimized,2) >= i);
                    wasOptimized = ~isempty(hPP.outputWaveform);
                    statusChanged = isOptimized ~= wasOptimized;
                    
                    % determine if waveform has changed
                    newDesired = ao.ao_volts_raw.G(:,i);
                    newName = [obj.hModel.imagingSystem actuatorName];
                    dataChanged = ~strcmp(newName, hPP.actuatorName);
                    dataChanged = dataChanged || (hPP.sampleRateHz ~= ao.sampleRates.G) || ~isequal(newDesired, hPP.desiredWaveform);
                    dataChanged = dataChanged || statusChanged || (isOptimized && ~isequal(optimized(:,i), hPP.outputWaveform));
                    
                    % reset the data if it has
                    if dataChanged || isUsrReq
                        hPP.sampleRateHz = ao.sampleRates.G;
                        hPP.desiredWaveform = newDesired;
                        if isOptimized
                            hPP.outputWaveform = optimized(:,i);
                            f = load(fullfile(metaData(i).path, metaData(i).feedbackWaveformFileName));
                            hPP.feedbackWaveform = repmat(f.volts,metaData(i).periodCompressionFactor,1);
                        else
                            hPP.outputWaveform = [];
                            hPP.feedbackWaveform = [];
                        end
                        hPP.optimizationHistory = [];
                        hPP.actuatorName = newName;
                        
                        a2d = obj.hModel.objectiveResolution;
                        v2fm = containers.Map;
                        v2fm('voltage') = @(v)v;
                        if isempty(scanner)
                            v2fm('angle') = @(v)v;
                            v2fm('microns') = @(v)v;
                        else
                            v2fm('angle') = @scanner.volts2Position;
                            v2fm('microns') = @(v)a2d*scanner.volts2Position(v);
                        end
                        hPP.volts2FuncMap = v2fm;
                        hPP.positionUnits = hPP.positionUnits;
                        
                        hPP.updateDisplay();
                    elseif ~isOptimized && ~isempty(hPP.optimizationHistory)
                        hPP.optimizationHistory = [];
                        hPP.updateDisplay();
                    end
                    
                    if dataChanged || isUsrReq
                        % reset the plot axes to defaults
                        hPP.vLim = [-inf inf];
                        hPP.historySel = inf;
                        
                        % find the most interesting time span for the detail view
                        td = hPP.T * [.3 .4]; % default
                        try
                            if ~obj.hModel.hRoiManager.isLineScan && (i == 2)
                                % zoom in on frame flyback
                                fbt = obj.hModel.hScan2D.flybackTimePerFrame;
                                td = hPP.T + [-fbt*2 fbt];
                            else
                                N = length(newDesired);
                                v = newDesired - circshift(newDesired,1);
                                assert(any(v(1) ~= v));
                                
                                rg = obj.hModel.hRoiManager.currentRoiGroup;
                                if isa(ss, 'scanimage.mroi.scannerset.GalvoGalvo') && ~obj.hModel.hRoiManager.isLineScan && (i == 1)
                                    % zoom in on line of first sf
                                    z = obj.hModel.hStackManager.zs(1);
                                    sfs = rg.scanFieldsAtZ(z);
                                    lp = obj.hModel.hRoiManager.linePeriod;
                                    td = lp*sfs{1}.pixelResolution(2)/2 + [-lp/2 lp*2.5];
                                    
                                elseif ~obj.hModel.hRoiManager.isLineScan && obj.hModel.hRoiManager.mroiEnable && (numel(rg.rois) > 1)
                                    % zoom in on most aggressive transition
                                    ftt = obj.hModel.hScan2D.flytoTimePerScanfield;
                                    [~, maxVii] = max(abs(v));
                                    td = hPP.T * maxVii/N + [-ftt ftt];
                                else
                                    [~, maxVii] = max(abs(v));
                                    td = hPP.T * maxVii/N + hPP.T * [-.05 .05];
                                end
                            end
                        catch
                        end
                        hPP.tDetail = td;
                    end
                end
            end
            
            function refreshBeams(waveformName,hWpp)
                if ~isfield(ao.ao_volts,waveformName)
                    hWpp.visible = 0;
                    return;
                end
                hWpp.visible = 1;
                newWvfm = ao.ao_volts.(waveformName);
                dataChanged = isempty(hWpp.sampleRateHz) || (hWpp.sampleRateHz ~= ao.sampleRates.B) || ~isequal(newWvfm, hWpp.desiredWaveform);
                
                % reset the data if it has
                if dataChanged || isUsrReq
                    hWpp.sampleRateHz = ao.sampleRates.B;
                    hWpp.desiredWaveform = newWvfm;
                    hWpp.outputWaveform = [];
                    hWpp.feedbackWaveform = [];
                    hWpp.optimizationHistory = [];
                    
                    unitMap = containers.Map;
                    unitMap('voltage') = newWvfm;
                    unitMap('power') = 100*ao.pathFOV.(waveformName);
                    hWpp.desiredWaveformMap = unitMap;
                    hWpp.volts2FuncMap = [];
                    hWpp.positionUnits = hWpp.positionUnits;
                    
                    hWpp.updateDisplay();
                end
                
                if dataChanged || isUsrReq
                    % reset the plot axes to defaults
                    hWpp.vLim = [-inf inf];
                    hWpp.historySel = inf;
                    
                    % find the most interesting time span for the detail view
                    hWpp.tDetail = hWpp.T * [.3 .4];
                end
            end
            
            function refreshFastZ()
                scanner = ss.fastz;
                
                [optimized,metaData] = obj.hWM.retrieveOptimizedAO('Z',false);
                
                isOptimized = ~isempty(optimized);
                wasOptimized = ~isempty(obj.hPlotPanelZ.outputWaveform);
                statusChanged = isOptimized ~= wasOptimized;
                
                if isOptimized
                    obj.hFastzTab.Title = 'Fast Z (Optimized)';
                    actuatorName = metaData.linearScannerName;
                else
                    obj.hFastzTab.Title = 'Fast Z';
                    actuatorName = 'Z';
                end
                
                obj.pbReset.Enable = isOptimized;
                
                % develop actual desired wvfm if necessary
                if obj.hModel.hFastZ.actuatorLag ~= 0
                    zs = obj.hModel.hStackManager.zs;
                    zsRelative = obj.hModel.hStackManager.zsRelative;
                    scannerSet = obj.hModel.hScan2D.scannerset;
                    fb = obj.hModel.hFastZ.numDiscardFlybackFrames;
                    wvType = obj.hModel.hFastZ.waveformType;
                    [~, newDesiredP, newOpP] = scannerSet.zWvfm(obj.hModel.hScan2D.currentRoiGroup,zs,zsRelative,fb,wvType);
                    newDesired = scanner.refPosition2Volts(newDesiredP);
                    newOp = scanner.refPosition2Volts(newOpP);
                else
                    newDesired = ao.ao_volts_raw.Z;
                    newOp = [];
                end
                
                % determine if waveform has changed
                newName = [obj.hModel.imagingSystem actuatorName];
                dataChanged = ~strcmp(newName, obj.hPlotPanelZ.actuatorName);
                dataChanged = dataChanged || (obj.hPlotPanelZ.sampleRateHz ~= ao.sampleRates.Z) || ~isequal(newDesired, obj.hPlotPanelZ.desiredWaveform);
                dataChanged = dataChanged || statusChanged || (isOptimized && ~isequal(optimized, obj.hPlotPanelZ.outputWaveform));
                
                % reset the data if it has
                if dataChanged || isUsrReq
                    obj.hPlotPanelZ.sampleRateHz = ao.sampleRates.Z;
                    obj.hPlotPanelZ.desiredWaveform = newDesired;
                    if isOptimized
                        obj.hPlotPanelZ.outputWaveform = optimized;
                        f = load(fullfile(metaData.path, metaData.feedbackWaveformFileName));
                        obj.hPlotPanelZ.feedbackWaveform = repmat(f.volts,metaData.periodCompressionFactor,1);
                    else
                        obj.hPlotPanelZ.outputWaveform = newOp;
                        obj.hPlotPanelZ.feedbackWaveform = [];
                    end
                    obj.hPlotPanelZ.optimizationHistory = [];
                    obj.hPlotPanelZ.actuatorName = newName;
                    
                    v2fm = containers.Map;
                    v2fm('voltage') = @(v)v;
                    v2fm('microns') = @(v)scanner.volts2Position(v);
                    obj.hPlotPanelZ.volts2FuncMap = v2fm;
                    obj.hPlotPanelZ.positionUnits = obj.hPlotPanelZ.positionUnits;
                    
                    obj.hPlotPanelZ.updateDisplay();
                elseif ~isOptimized && ~isempty(obj.hPlotPanelZ.optimizationHistory)
                    obj.hPlotPanelZ.optimizationHistory = [];
                    obj.hPlotPanelZ.updateDisplay();
                end
                
                if dataChanged || isUsrReq
                    % reset the plot axes to defaults
                    obj.hPlotPanelZ.vLim = [-inf inf];
                    obj.hPlotPanelZ.historySel = inf;
                    
                    % find the most interesting time span for the detail view
                    fbt = (.5 + obj.hModel.hFastZ.numDiscardFlybackFrames) / obj.hModel.hRoiManager.scanFrameRate;
                    obj.hPlotPanelZ.tDetail = [obj.hPlotPanelZ.T-fbt inf];
                end
            end
            
            function updateTabVisibility()
                waves = fieldnames(ao.ao_volts);
                
                tfG = ismember('G',waves);
                if tfG
                    obj.hGalvoTab.Parent = obj.hTabGroup;
                else
                    obj.hGalvoTab.Parent = [];
                end
                
                tfB = ismember('B',waves);
                if tfB
                    obj.hBeamTab.Parent = obj.hTabGroup;
                else
                    obj.hBeamTab.Parent = [];
                end
                
                tfZ = ismember('Z',waves);
                if tfZ
                    obj.hFastzTab.Parent = obj.hTabGroup;
                else
                    obj.hFastzTab.Parent = [];
                end
                
                tabArray = [obj.hGalvoTab obj.hBeamTab obj.hFastzTab];
                obj.hTabGroup.Children = tabArray([tfG tfB tfZ]);
            end
            
            function blankTabData()
                N = numel(obj.hTabGroup.SelectedTab.UserData);
                for i = 1:N
                    hWp = obj.hTabGroup.SelectedTab.UserData(i);
                    hWp.sampleRateHz = 500e3;
                    hWp.desiredWaveform = [];
                    hWp.outputWaveform = [];
                    hWp.feedbackWaveform = [];
                    hWp.optimizationHistory = [];
                    hWp.updateDisplay();
                    hWp.resize();
                end
            end
            
            function simulateTabData()
                N = numel(obj.hTabGroup.SelectedTab.UserData);
                for i = 1:N
                    hWp = obj.hTabGroup.SelectedTab.UserData(i);
                    hWp.sampleRateHz = 500e3;
                    hWp.desiredWaveform = sin(1:100)';
                    hWp.outputWaveform = sin(1:100)'-.1*cos(1:100)';
                    hWp.feedbackWaveform = sin(1:100)'+.1*cos(1:100)';
                    hWp.optimizationHistory = struct('outputWaveforms',[sin(1:100)' cos(1:100)' tan(1:100)'],'feedbackWaveforms',[sin(1:100)' cos(1:100)' tan(1:100)'], 'errors', [4 2 1]);
                    hWp.updateDisplay();
                    hWp.vLim = [-inf inf];
                    hWp.resize();
                end
            end
        end
        
        function updateButtonStatus(obj)
            switch obj.hTabGroup.SelectedTab
                case obj.hGalvoTab
                    prefix = 'G';
                case obj.hBeamTab
                    na();
                    obj.pbReset.Enable = 'off';
                    return;
                case obj.hFastzTab
                    prefix = 'Z';
            end
            
            if ~isempty(obj.hModel)
                ss = obj.hModel.hScan2D.scannerset;
                
                if ~ss.hasSensor(prefix)
                    na();
                elseif ~ss.sensorCalibrated(prefix)
                    obj.pbCalibrate.hCtl.BackgroundColor = 'y';
                    obj.pbCalibrate.Enable = 'on';
                    set(obj.pbTest, 'Enable', 'off');
                    set(obj.pbOptimize, 'Enable', 'off');
                else
                    obj.pbCalibrate.hCtl.BackgroundColor = .94*ones(1,3);
                    set([obj.pbTest obj.pbCalibrate], 'Enable', 'on');
                    set(obj.pbOptimize, 'Enable', 'on');
                end
            end
            
            function na()
                obj.pbCalibrate.hCtl.BackgroundColor = .94*ones(1,3);
                set([obj.pbTest obj.pbCalibrate], 'Enable', 'off');
                set(obj.pbOptimize, 'Enable', 'off');
            end
        end
        
        function test(obj,varargin)
            try
                obj.updateCurrentWaveforms();
                
                switch obj.hTabGroup.SelectedTab
                    case obj.hGalvoTab
                        prefix = 'G';
                        srcs = [obj.hModel.hScan2D.xGalvo obj.hModel.hScan2D.yGalvo];
                    case obj.hBeamTab
                        return;
                    case obj.hFastzTab
                        prefix = 'Z';
                        srcs = obj.hModel.hScan2D.scannerset.fastz(1).hDevice;
                end
                
                obj.testMode = true;
                obj.optCmd = '';
                
                hWPP = obj.hTabGroup.SelectedTab.UserData;
                for i = 1:numel(hWPP)
                    hWPP(i).optimizationHistory = [];
                    hWPP(i).feedbackWaveform = nan(size(hWPP(i).desiredWaveform));
                    hWPP(i).updateDisplay();
                    hWPP(i).updateCallback();
                    hWPP(i).hScanner = srcs(i);
                    hWPP(i).hProgressText.String = ['Testing ' hWPP(i).waveformName ':'];
                end
                
                drawnow('nocallbacks');
                feedback = obj.hWM.testWaveforms(prefix,@updateCb,false);
                
                obj.testMode = false;
                
                for i = 1:numel(hWPP)
                    hWPP(i).feedbackWaveform = feedback(:,i);
                    hWPP(i).updateDisplay();
                end
            catch ME
                obj.testMode = false;
                
                if strcmp(ME.message, 'Waveform test cancelled by user')
                    for i = 1:numel(hWPP)
                        hWPP(i).updateCallback('done',[]);
                        hWPP(i).updateDisplay();
                    end
                else
                    msg = ['Waveform test failed. Error: ' ME.message];
                    most.ErrorHandler.logAndReportError(ME,msg);
                    warndlg(msg,'Waveform Test');
                end
            end
            
            function tfContinue = updateCb(src,varargin)
                tfContinue = hWPP(src==srcs).updateCallback(varargin{:});
            end
        end
        
        function accept(obj,varargin)
            obj.optCmd = 'accept';
        end
        
        function abort(obj,varargin)
            obj.optCmd = 'abort';
        end
        
        function optimize(obj,varargin)
            try
                obj.updateCurrentWaveforms();
                
                switch obj.hTabGroup.SelectedTab
                    case obj.hGalvoTab
                        prefix = 'G';
                        srcs = [obj.hModel.hScan2D.xGalvo obj.hModel.hScan2D.yGalvo];
                    case obj.hBeamTab
                        return;
                    case obj.hFastzTab
                        prefix = 'Z';
                        srcs = obj.hModel.hScan2D.scannerset.fastz(1).hDevice;
                        if obj.hModel.hFastZ.actuatorLag ~= 0
                            choice = questdlg('When using waveform optimization for Z actuator, actuator lag parameter should be set to zero. Apply this change and continue?','Fast Z Optimization','Yes','Cancel','Cancel');
                            if strcmp(choice,'Yes')
                                obj.hModel.hFastZ.actuatorLag = 0;
                            else
                                return;
                            end
                        end
                end
                
                obj.optMode = true;
                obj.optCmd = '';
                
                hWPP = obj.hTabGroup.SelectedTab.UserData;
                for i = 1:numel(hWPP)
                    hWPP(i).optimizationHistory = struct('outputWaveforms',[],'feedbackWaveforms',[], 'errors', []);
                    hWPP(i).outputWaveform = [];
                    hWPP(i).feedbackWaveform = [];
                    hWPP(i).updateDisplay();
                    hWPP(i).updateCallback();
                    hWPP(i).hScanner = srcs(i);
                    hWPP(i).hProgressText.String = ['Optimizing ' hWPP(i).waveformName ':'];
                end
                
                drawnow('nocallbacks');
                obj.hWM.optimizeWaveforms(prefix,@updateCb,false)
                
                tname = obj.hTabGroup.SelectedTab.Title;
                if tname(end) ~= ')'
                    obj.hTabGroup.SelectedTab.Title = [tname ' (Optimized)'];
                end
                
                obj.optMode = false;
                obj.pbReset.Enable = 'on';
            catch ME
                obj.optMode = false;
                obj.pbReset.Enable = 'on';
                
                if strcmp(ME.message, 'Waveform test cancelled by user')
                    for i = 1:numel(hWPP)
                        hWPP(i).updateCallback('done');
                        if isempty(hWPP(i).optimizationHistory.errors)
                            hWPP(i).optimizationHistory = [];
                            hWPP(i).updateDisplay();
                        end
                    end
                else
                    msg = ['Optimization failed. Error: ' ME.message];
                    most.ErrorHandler.logAndReportError(ME,msg);
                    warndlg(msg,'Waveform Optimization');
                end
            end
            
            function tfContinue = updateCb(src,varargin)
                tfContinue = hWPP(src==srcs).updateCallback(varargin{:});
            end
        end
        
        function reset(obj,varargin)
            switch obj.hTabGroup.SelectedTab
                case obj.hGalvoTab
                    prefix = 'G';
                case obj.hBeamTab
                    return;
                case obj.hFastzTab
                    prefix = 'Z';
            end
            obj.hWM.clearCachedWaveform(prefix)
            obj.updateCurrentWaveforms();
        end
        
        function calibrate(obj,varargin)
            try
                switch obj.hTabGroup.SelectedTab
                    case obj.hGalvoTab
                        prefix = 'G';
                    case obj.hBeamTab
                        return;
                    case obj.hFastzTab
                        prefix = 'Z';
                end
                obj.hWM.calibrateScanner(prefix)
                obj.updateButtonStatus()
            catch ME
                warndlg(['Sensor calibration failed. Error: ' ME.message], 'ScanImage');
                ME.rethrow();
            end
        end
        
        function scrollFnc(obj,~,evt)
            N = numel(obj.hTabGroup.SelectedTab.UserData);
            for i = 1:N
                obj.hTabGroup.SelectedTab.UserData(i).scrollFunc(evt);
            end
        end
        
        function openGui(obj,scanner)
            if nargin > 1
                switch scanner
                    case 'G'
                        t = obj.hGalvoTab;
                    case 'B'
                        t = obj.hBeamTab;
                    case 'Z'
                        t = obj.hFastzTab;
                end
                
                t.Parent = obj.hTabGroup;
                obj.hTabGroup.SelectedTab = t;
            end
            v = obj.Visible;
            obj.Visible = 1;
            most.idioms.figure(obj.hFig);
            
            if v
                obj.updateCurrentWaveforms();
            end
        end
        
        function mouseMotionFunction(obj,varargin)
            if ~isempty(obj.mouseMotionFunc)
                obj.mouseMotionFunc(varargin{:});
            else
                hWPPs = obj.hTabGroup.SelectedTab.UserData;
                for i = 1:numel(hWPPs)
                    hWPPs(i).historyHover();
                end
            end
        end
        
        function use(obj,varargin)
            obj.hFig.CurrentObject.UserData.use();
        end
    end
    
    %% prop access
    methods
        function set.optMode(obj,v)
            obj.optMode = v;
            set([obj.pbAccept obj.pbAbortO], 'Visible', obj.tfMap(v));
            set([obj.pbRefresh obj.pbTest], 'Enable', obj.tfMap(~v));
            
            set([obj.pbReset obj.pbOptimize],'Visible',obj.tfMap(~v));
        end
        
        function set.testMode(obj,v)
            obj.testMode = v;
            set(obj.pbAbortT, 'Visible', obj.tfMap(v));
            set(obj.pbTest, 'Visible', obj.tfMap(~v));
            set(obj.pbRefresh, 'Enable', obj.tfMap(~v));
            
            set([obj.pbReset obj.pbOptimize], 'Enable', obj.tfMap(~v));
        end
    end
    
    %% most.Gui
    methods (Access = protected)
        function initGui(obj)
            mainFlow = most.gui.uiflowcontainer('parent',obj.hFig,'flowdirection','topdown','margin',0.0001);
            
            innerFlow = most.gui.uiflowcontainer('parent',mainFlow,'flowdirection','topdown','margin',8);
            obj.hTabGroup = uitabgroup('parent',innerFlow,'SelectionChangedFcn',@obj.tabChanged);
            
            bottomFlow = most.gui.uiflowcontainer('parent',mainFlow,'flowdirection','righttoleft','HeightLimits',44,'margin',0.0001);
            leftButtonFlow = most.gui.uiflowcontainer('parent',bottomFlow,'flowdirection','righttoleft','margin',8,'WidthLimits',120);
            obj.pbCalibrate = most.gui.uicontrol('parent',leftButtonFlow,'string','Calibrate Sensor','callback', @obj.calibrate);
            
            obj.hStatusFlow = most.gui.uiflowcontainer('parent',bottomFlow,'flowdirection','lefttoright','margin',8);
            
            rightButtonFlow = most.gui.uiflowcontainer('parent',bottomFlow,'flowdirection','lefttoright','margin',8,'WidthLimits',700);
            obj.pbRefresh = most.gui.uicontrol('parent',rightButtonFlow,'string','Refresh Waveforms','WidthLimits',120,'callback', @obj.updateCurrentWaveforms);
            
            obj.pbTest = most.gui.uicontrol('parent',rightButtonFlow,'string','Test Waveform','WidthLimits',120,'callback', @obj.test);
            
            obj.pbAbortT = most.gui.uicontrol('parent',rightButtonFlow,'string','Abort','WidthLimits',120,'callback', @obj.abort,'visible','off','BackgroundColor',[1 .5 .5]);
            
            obj.pbOptimize = most.gui.uicontrol('parent',rightButtonFlow,'string','Optimize Waveform','WidthLimits',120,'callback', @obj.optimize);
            
            obj.pbAccept = most.gui.uicontrol('parent',rightButtonFlow,'string','Accept Current','WidthLimits',120,'callback', @obj.accept,'visible','off','BackgroundColor',[.5 1 .5]);
            obj.pbAbortO = most.gui.uicontrol('parent',rightButtonFlow,'string','Abort','WidthLimits',120,'callback', @obj.abort,'visible','off','BackgroundColor',[1 .5 .5]);
            
            obj.pbReset = most.gui.uicontrol('parent',rightButtonFlow,'string','Reset Waveform','WidthLimits',120,'callback', @obj.reset);
            
            most.gui.uipanel('parent',rightButtonFlow,'bordertype','none','WidthLimits',20);
            obj.hStatusText = most.gui.staticText('parent',rightButtonFlow,'String','','fontsize',10);
            
            obj.hHistoryMenu = uicontextmenu('Parent',obj.hFig);
            uimenu('Parent',obj.hHistoryMenu,'Label','Use this waveform','Callback',@obj.use);
            
            %% create tabs
            tabCommonProps = {'parent',obj.hTabGroup,'BackgroundColor','w','userdata',scanimage.guis.waveformcontrols.WaveformPlotPanel.empty};
            
            obj.hGalvoTab = uitab(tabCommonProps{:},'Title','Galvos');
            galvoFlow = most.gui.uiflowcontainer('parent',obj.hGalvoTab,'flowdirection','lefttoright','margin',0.0001,'BackgroundColor','w');
            obj.hPlotPanelX = scanimage.guis.waveformcontrols.WaveformPlotPanel(obj,galvoFlow,obj.hGalvoTab, 'X Galvo', {'Voltage' 54 'Scan Angle' 68 'Microns' 54},'Galvo Scan Position');
            obj.hPlotPanelY = scanimage.guis.waveformcontrols.WaveformPlotPanel(obj,galvoFlow,obj.hGalvoTab, 'Y Galvo', {'Voltage' 54 'Scan Angle' 68 'Microns' 54},'Galvo Scan Position');
            
            obj.hBeamTab = uitab(tabCommonProps{:},'Title','Beams');
            beamFlow = most.gui.uiflowcontainer('parent',obj.hBeamTab,'flowdirection','lefttoright','margin',0.0001,'BackgroundColor','w');
            obj.hPlotPanelB = scanimage.guis.waveformcontrols.WaveformPlotPanel(obj,beamFlow,obj.hBeamTab, 'Beam Control', {'Voltage' 54 'Power' 44},'Beam Power');
            obj.hPlotPanelBpb = scanimage.guis.waveformcontrols.WaveformPlotPanel(obj,beamFlow,obj.hBeamTab, 'Beam Control (with PowerBox)', {'Voltage' 54 'Power' 44},'Beam Power');
            
            obj.hFastzTab = uitab(tabCommonProps{:},'Title','Fast Z');
            zFlow = most.gui.uiflowcontainer('parent',obj.hFastzTab,'flowdirection','lefttoright','margin',0.0001,'BackgroundColor','w');
            obj.hPlotPanelZ = scanimage.guis.waveformcontrols.WaveformPlotPanel(obj,zFlow,obj.hFastzTab, 'FastZ', {'Voltage' 54 'Microns' 54},'Z Actuator Position');
            
            %% finish up
            obj.hVisLis = most.ErrorHandler.addCatchingListener(obj.hFig,'Visible','PostSet',@obj.visibilityChanged);
            obj.hFig.WindowScrollWheelFcn = @obj.scrollFnc;
            obj.hFig.WindowButtonMotionFcn = @obj.mouseMotionFunction;
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
