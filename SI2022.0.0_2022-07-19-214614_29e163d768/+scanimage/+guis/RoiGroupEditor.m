classdef RoiGroupEditor < most.Gui & most.HasClassDataFile
    
    properties (SetObservable)
        editorZ = 0;
        
        showEditorZ = true;
        showImagingZs = true;
        showScannerFov = true;
        showSelectedRoi = true;
        showOtherRois = true;
    end
    
    properties (SetObservable)
        viewMode = '2D';
        
        projectionMode = 'XZ';
        mainViewFov = 30;
        mainViewPosition = [0 0];
        zProjectionRange = [-inf inf];
        units;
        
        editingGroup;
        editorMode = 'imaging';
        
        newRoiDrawMode;
        newRoiDrawModeCache;
        scanfieldResizeMaintainPixelProp;
        newRoiDefaultResolutionMode;
        lockScanfieldWidth = false;
        lockScanfieldHeight = false;
        drawMultipleRois = false;
        drawArray = false;
        
        drawMultipleRoisCache = false;
        
        defaultRoiPositionX = 0;
        defaultRoiPositionY = 0;
        defaultRoiWidth = 5;
        defaultRoiHeight = 5;
        defaultRoiRotation = 0;
        defaultRoiPixelCountX = 512;
        defaultRoiPixelCountY = 512;
        defaultRoiPixelRatioX = 51.2;
        defaultRoiPixelRatioY = 51.2;
        defaultStimFunction = 'logspiral';
        defaultStimFunctionArgs = {'revolutions',5};
        defaultStimDuration = 10;
        defaultStimRepititions = 1;
        defaultStimPower = 50;
        defaultStimPowerLastAct = 50;
        defaultAnalysisRoiChannel = 1;
        defaultAnalysisRoiThreshold = 100;
        defaultAnalysisRoiProcessor = 'CPU';
        
        defaultWpStimDuration = .1;
        defaultScnStimDuration = 10;
        
        stimQuickAddDuration = 1;
        
        cellPickMode = 'Manual';
        cellPickManualRadius = 6;
        cellPickRoiMargin = 0;
        cellPickCreateAsDiscrete = true;
        cellPickCreateWithMask = true;
        cellPickPauseDuration = 1;
        diskCellPickParams = struct('radiusRange',[3 10],'edgeSign',-1,'postDilateBy',0,'dPosMax',2,'postFracRemove',0,'jitter',[]);
        annularCellPickParams = struct('radiusRange',[2 5],'edgeSign',1,'postDilateBy',2,'dPosMax',2,'postFracRemove',0.35,'jitter',[-2 -2; 0 -2 ; 2 -2; -2 0; 2 0; -2 2; 0 2; 2 2]);
        
        xyMaxVel = 40000;           %deg/sec
        xyMaxAccel = 80000000;         %deg/sec
        zMaxVel = 5000;            %um/sec^s
        zMaxAccel = 5000000;          %um/sec^s
        optimizeScanOrder = false;
        optimizeTransitions = true;
        optimizeStimuli = false;
        autoOptimize = false;
        
        contextImageTransparency = true;
        contextImageFillIntermediateZ = true;
        contextImageZTolerance = 1;
        
        stagePos = '[ 0.0   0.0   0.0 ]';
        
        slmPatternType = 'point';
        slmBitmapDisplayTransparency = 0.5;
        
        slmBitmapBrushEnable = false;
        slmBitmapBrushValue = 1;
        slmBitmapBrushSize = 20;
        slmBitmapBrushSoftEdgePct = .5;
        slmPixelMeshBuffer = [];
        
        stimpathRenderMaxPoints = 500;
    end
    
    properties (SetAccess = private)
        scannerSet;
        scannersetIsSlm;
        zProjectionDefaultRange;
        zProjectionLimits = [-1 1] * 1e6;
        interestingZs;
        maxInterestingZ;
        minInterestingZ;
    end
    
    properties (Hidden)
        roiTable;
        tblData;
        tblMapping;
        
        canDrawArray = false;
        
        drawData = {{}};
        drawDataProj = {{}};
        hSelObjHandles = {};
        scanPathCache = [];
        scanPathCacheIds = [];
        
        selectedObj;
        selectedObjParent;
        selectedObjRoiIdx = 0;
        
        hPropsPanels;
        hBlankPanel;
        hNewPanel;
        hGlobalImagingSfPropsPanel;
        hImagingRoiPropsPanel;
        hImagingSfPropsPanel;
        hStimRoiPropsPanel;
        hAnalysisRoiPropsPanel;
        hAnalysisSfPropsPanel;
        hNewImagingRoiPanel;
        hNewStimRoiPanel;
        hNewAnalysisRoiPanel;
        hStimOptimizationPanel;
        hStimQuickAddPanel;
        hSlmPropsPanel;
        hSlmPropsPanelCtls;
        
        hGlobalImagingSfPropsPanelCtls;
        hImagingRoiPropsPanelCtls;
        hImagingSfPropsPanelCtls;
        hStimRoiPropsPanelCtls;
        hAnalysisRoiPropsPanelCtls;
        hAnalysisSfPropsPanelCtls;
        hNewImagingRoiPanelCtls;
        hNewStimRoiPanelCtls;
        hNewAnalysisRoiPanelCtls;
        hStimOptimizationPanelCtls;
        
        activePanelUpdateFcn;
        
        h2DViewPanel;
        h2DMainViewAxes;
        h2DMainViewOutlineAxes;
        h2DMainViewTickAxes;
        h2DZScrollAxes;
        h2DProjectionViewAxes;
        h2DProjectionViewTickAxes;
        h2DScannerFovSurf;
        h2DScannerFovLines;
        h2DScannerFovHandles;
        h2DScannerFovZeroOrder;
        
        hZPlaneCtl;
        
        h2DScrollPatch;
        h2DScrollKnob;
        h2DScrollLine1;
        h2DScrollLine2;
        hZCursorText;
        hZCursorTextRect;
        
        h3DViewPanel;
        h3DViewAxes;
        h3DViewMouseFindAxes;
        
        hSnapLineX;
        hSnapLineY;
        hSnapLineR;
        
        makeToolBoxColor = most.constants.Colors.green;
        makeToolPathColor = most.constants.Colors.green;
        hMakeToolSquare;
        hMakeToolX;
        hMakeToolO;
        hMakeToolL;
        hMakeToolR;
        hMakeToolPath;
        makeToolPathNomPts;
        
        h2DImagingPlaneLines;
        h2DFocusPlaneLine;
        h3DImagingPlaneSurfs = matlab.graphics.primitive.Surface.empty;
        n3dip = 0;
        
        
        hSlmListener;
        hRGListener;
        hRGNameListener;
        hSelObjListener;
        hSIListeners;
        hSSListener;
        hImGrpLis;
        
        xyUnitFactor = 1;
        xyUnitOffset = [0 0];
        fovGridxx = [-.5 .5; -.5 .5];
        fovGridyy = [-.5 -.5; .5 .5];
        
        pbUnitsUM;
        pbUnitsSA;
        tbViewMode2D;
        tbViewMode3D;
        tbProjectionModeXZ;
        tbProjectionModeYZ;
        slLegendScroll;
        pbMoveTop;
        pbMoveUp;
        pbMoveDown;
        pbMoveBottom;
        pbNew;
        pbDel;
        hButtonFlow;
        hCopyButtonFlow;
        hNameFlow;
        etName;
        
        hSlmPatternTypeFlow;
        hSlmBitmapFlow;
        
        procMap = containers.Map({'cpu' 'fpga'}, {1 2});
        rProcMap = containers.Map({1 2}, {'cpu' 'fpga'});
        stimFcnOptions;
        slmScanOptions;
        slmOnlyOptions;
        stimFcnParamOptions;
        
        nLegendItems = 0;
        legendCols = 0;
        legendTotRows = 0;
        legendMaxTopRow = 1;
        hLegendScrollingPanel;
        hLegendGrid;
        rando = rand(6);
        createMode = false;
        editorModeIsStim = false;
        editorModeIsSlm = false;
        editorModeIsImaging = true;
        
        siZs;
        siImRg;
        mainViewFovLim = 30;
        siObjectiveResolution;
        
        contextImageEdgeColorList = {[0 1 1] [0.6392 0.2863 0.6431] [.5 .5 1] [0 .5 .5] [.5 .25 0] [.25 0 .25]};
        hContextImages = scanimage.guis.roigroupeditor.ContextImageProvider.empty();
        
        initDone = false;
        
        locks;
        defaultRoiSize;
        projectionDim = 1;
        
        cellPickOn = false;
        cellPickModes = {'Disk cell','Annular cell','Manual'};
        cellPickSurfs = [];
        cellPickSurfsIdMap = {};
        cellPickZs = [];
        cellPickCellsAtZ = {};
        cellPickFunc = [];
        cellPickSelectedCellIdx = [];
        
        showHandles = true;
        enableListeners = true;
        slmPatternTypeIsBitmap = false;
        
        cameraLiveSurface = matlab.graphics.chart.primitive.Surface.empty;
        cameraSnapshotSurfaces = [];
    end
    
    properties (SetObservable)
        slmPatternSfParent;
        slmPatternRoiParent;
        slmPatternRoiGroupParent;
    end
    
    %% Lifecycle
    methods
        function obj = RoiGroupEditor(hModel, hController)
            %% main figure
            if nargin < 1
                hModel = [];
            end
            
            if nargin < 2
                hController = [];
            end
            
            obj = obj@most.Gui(hModel, hController, [280 64], 'characters');
            obj.showWaitbarDuringInitalization = true;
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hContextImages);
            most.idioms.safeDeleteObj(obj.hSelObjListener);
            most.idioms.safeDeleteObj(obj.hRGListener);
            most.idioms.safeDeleteObj(obj.hRGNameListener);
            most.idioms.safeDeleteObj(obj.hSSListener);
            most.idioms.safeDeleteObj(obj.hSIListeners);
            most.idioms.safeDeleteObj(obj.hImGrpLis);
            most.idioms.safeDeleteObj(obj.hSlmListener);
        end
    end
    
    %% most.GUI
    methods (Access = protected)
        function initGui(obj)
            kpf = {'KeyPressFcn',@obj.keyPressFcn};
            set(obj.hFig,'Name','ROI Group Editor','WindowScrollWheelFcn',@obj.scrollWheelFcn,kpf{:});
            
            hMainFlow = most.gui.uiflowcontainer('Parent', obj.hFig,'FlowDirection','RightToLeft');
            
            %% right side panel
            hRightPanel = uipanel('Parent', hMainFlow);
            set(hRightPanel, 'WidthLimits', [400 400]);
            hRightFlow = most.gui.uiflowcontainer('Parent', hRightPanel,'FlowDirection','TopDown');
            
            obj.hButtonFlow = most.gui.uiflowcontainer('Parent', hRightFlow,'FlowDirection','LeftToRight', 'HeightLimits', 30);
            uicontrol('Parent',obj.hButtonFlow,'String','Save Group...','callback',@obj.saveGroup,kpf{:});
            uicontrol('Parent',obj.hButtonFlow,'String','Load Group...','callback',@obj.loadGroup,kpf{:});
            uicontrol('Parent',obj.hButtonFlow,'String','Clear Group','callback',@obj.clearGroup,kpf{:});
            
            obj.hCopyButtonFlow = most.gui.uiflowcontainer('Parent', hRightFlow,'FlowDirection','LeftToRight', 'HeightLimits', 30,'visible','off');
            uicontrol('Parent',obj.hCopyButtonFlow,'String','Copy Imaging ROIs','callback',@obj.copyImagingRois,kpf{:});
            
            obj.hNameFlow = most.gui.uiflowcontainer('Parent', hRightFlow,'FlowDirection','LeftToRight','HeightLimits',24);
            most.gui.staticText('Parent',obj.hNameFlow,'String','ROI Group Name:','WidthLimits',90);
            obj.etName = most.gui.uicontrol('Parent',obj.hNameFlow,'String','Awesome ROIs','Style','Edit','HorizontalAlignment','left','callback',@obj.chgName);

            obj.hSlmPatternTypeFlow = most.gui.uiflowcontainer('Parent', hRightFlow,'FlowDirection','LeftToRight','HeightLimits', 30,'visible','off');
            most.gui.staticText('Parent',obj.hSlmPatternTypeFlow,'String','SLM Pattern Type:','WidthLimits',100);
            most.gui.uicontrol('Parent',obj.hSlmPatternTypeFlow,'String','Point Array','style','togglebutton','Bindings',{obj 'slmPatternType' 'match' 'point'},kpf{:});
            most.gui.uicontrol('Parent',obj.hSlmPatternTypeFlow,'String','Bitmap','style','togglebutton','Bindings',{obj 'slmPatternType' 'match' 'bitmap'},kpf{:});
            
            obj.hSlmBitmapFlow = most.gui.uiflowcontainer('Parent', hRightFlow,'FlowDirection','TopDown', 'visible','off','margin',.0001);
            hSlmSaveLoadFlow = most.gui.uiflowcontainer('Parent', obj.hSlmBitmapFlow,'FlowDirection','LeftToRight','HeightLimits', 30);
            most.gui.uicontrol('Parent',hSlmSaveLoadFlow,'String','Load From File','callback',@obj.loadBitmapFromFile,kpf{:});
            most.gui.uicontrol('Parent',hSlmSaveLoadFlow,'String','Load From Var','callback',@obj.loadBitmapFromVar,kpf{:});
            most.gui.uicontrol('Parent',hSlmSaveLoadFlow,'String','Save To File','callback',@obj.saveBitmapToFile,kpf{:});
            most.gui.uicontrol('Parent',hSlmSaveLoadFlow,'String','Save To Var','callback',@obj.saveBitmapToVar,kpf{:});
            most.gui.uicontrol('Parent',hSlmSaveLoadFlow,'String','Clear','callback',@obj.clearBitmap,'WidthLimits',50,kpf{:});
            
            hSlmTransparencyFlow = most.gui.uiflowcontainer('Parent', obj.hSlmBitmapFlow,'FlowDirection','LeftToRight','HeightLimits', 26);
            most.gui.staticText('Parent',hSlmTransparencyFlow,'String','Bitmap Display Transparency:','WidthLimits',148);
            most.gui.slider('parent',hSlmTransparencyFlow, 'Bindings', {obj 'slmBitmapDisplayTransparency' 1});
            
            brushPanel = most.gui.uipanel('Parent', obj.hSlmBitmapFlow, 'title', 'Brush Tool', 'HeightLimits', 116);
            brushPanelFlow = most.gui.uiflowcontainer('Parent', brushPanel,'FlowDirection','TopDown','margin',.0001);
            
            brushEnableFlow = most.gui.uiflowcontainer('Parent', brushPanelFlow,'FlowDirection','LeftToRight','HeightLimits', 24);
            most.gui.uicontrol('Parent',brushEnableFlow,'string', 'Enable Brush','style','checkbox','Bindings',{obj 'slmBitmapBrushEnable' 'value'},kpf{:});
            
            brushValueFlow = most.gui.uiflowcontainer('Parent', brushPanelFlow,'FlowDirection','LeftToRight','HeightLimits', 24);
            most.gui.staticText('Parent',brushValueFlow,'String','Brush Value:','WidthLimits',90);
            most.gui.uicontrol('Parent',brushValueFlow,'style','edit','Bindings',{obj 'slmBitmapBrushValue' 'value'},'WidthLimits',40);
            most.gui.slider('parent',brushValueFlow, 'Bindings', {obj 'slmBitmapBrushValue' 1});
            
            brushSizeFlow = most.gui.uiflowcontainer('Parent', brushPanelFlow,'FlowDirection','LeftToRight','HeightLimits', 24);
            most.gui.staticText('Parent',brushSizeFlow,'String','Brush Size:','WidthLimits',90);
            most.gui.uicontrol('Parent',brushSizeFlow,'style','edit','Bindings',{obj 'slmBitmapBrushSize' 'value'},'WidthLimits',40);
            most.gui.slider('parent',brushSizeFlow, 'Bindings', {obj 'slmBitmapBrushSize' 1}, 'max', 256, 'min', 1);
            
            brushSoftFlow = most.gui.uiflowcontainer('Parent', brushPanelFlow,'FlowDirection','LeftToRight','HeightLimits', 24);
            most.gui.staticText('Parent',brushSoftFlow,'String','Brush Soft Edge:','WidthLimits',90);
            most.gui.uicontrol('Parent',brushSoftFlow,'style','edit','Bindings',{obj 'slmBitmapBrushSoftEdgePct' 'value'},'WidthLimits',40);
            most.gui.slider('parent',brushSoftFlow, 'Bindings', {obj 'slmBitmapBrushSoftEdgePct' 1});
            
            
            obj.roiTable = most.gui.uitable(...
                'Parent',hRightFlow,...
                'FontUnits',get(0,'defaultuitableFontUnits'),...
                'Units','characters',...
                'BackgroundColor',get(0,'defaultuitableBackgroundColor'),...
                'ColumnName',{''; 'ID'; 'ROI Name/SF Type'; 'Time (ms)'; 'Enable'; 'Display'; 'Z [um]'},...
                'ColumnWidth',{ 20 28 120 59 43 45 58 },...
                'RowName','',...
                'Position',[1 4.3 54 10.9],...
                'ColumnEditable',[true false true true true true true],...
                'ColumnFormat',{'logical' 'char' 'char' 'char' 'char' 'char' 'char'},...
                'RearrangeableColumns','off',...
                'RowStriping','on',...
                'CellEditCallback',@obj.roiTableCB,...
                'ForegroundColor',get(0,'defaultuitableForegroundColor'),...
                'Tag','utSfTable','KeyPressFcn',@obj.keyPressFcn);
            
            hRightFlow3 = most.gui.uiflowcontainer('Parent', hRightFlow,'FlowDirection','LeftToRight','Margin',0.0001);
            hRightFlow3L = most.gui.uiflowcontainer('Parent', hRightFlow3,'FlowDirection','LeftToRight');
            hRightFlow3R = most.gui.uiflowcontainer('Parent', hRightFlow3,'FlowDirection','RightToLeft');
            set(hRightFlow3, 'HeightLimits', [30 30]);
            obj.pbNew = uicontrol('Parent',hRightFlow3L,'String','Add ROI...','callback',@obj.newRoi,kpf{:});
            obj.pbDel = uicontrol('Parent',hRightFlow3L,'String','Delete Selected','callback',@obj.delSelection,kpf{:});
            btArgs = {'Parent',hRightFlow3R,'FontName','Arial Unicode MS','FontSize',12,'FontWeight','Bold'};
            obj.pbMoveBottom = uicontrol(btArgs{:},'String',most.constants.Unicode.downwards_paired_arrow,'callback',@(varargin)obj.moveButton(inf),kpf{:});
            obj.pbMoveDown = uicontrol(btArgs{:},'String',most.constants.Unicode.downwards_arrow,'callback',@(varargin)obj.moveButton(1),kpf{:});
            obj.pbMoveUp = uicontrol(btArgs{:},'String',most.constants.Unicode.upwards_arrow,'callback',@(varargin)obj.moveButton(-1),kpf{:});
            obj.pbMoveTop = uicontrol(btArgs{:},'String',most.constants.Unicode.upwards_paired_arrow,'callback',@(varargin)obj.moveButton(-inf),kpf{:});
            set(obj.pbNew, 'WidthLimits', [80 80]);
            set(obj.pbDel, 'WidthLimits', [100 100]);
            set([obj.pbMoveTop obj.pbMoveUp obj.pbMoveDown obj.pbMoveBottom], 'WidthLimits', [30 30]);
            
            
            %% Find stim function options
            stimfcnpackage = what('scanimage/mroi/stimulusfunctions');
            obj.stimFcnOptions = cellfun(@(mname)regexprep(mname,'\.m$',''),stimfcnpackage.m,'UniformOutput',false);
            obj.slmScanOptions = setdiff(obj.stimFcnOptions, {'park' 'pause' 'waypoint'});
            obj.slmOnlyOptions = {'point' 'pause' 'park'};
            
            for i = 1:numel(obj.stimFcnOptions)
                n = obj.stimFcnOptions{i};
                obj.stimFcnParamOptions.(n) = findParamOptions(fullfile(stimfcnpackage.path, [n '.m']));
            end
            
            %% properties panel section
            obj.hBlankPanel = uipanel('Parent', hRightFlow);
            set(obj.hBlankPanel, 'HeightLimits', [200 200]);
            uicontrol('Parent',obj.hBlankPanel,'string','Select an item to view properties','units','normalized','position',[0 0.49 1 .1],'style','text','enable','off');
            
            createNewImRoiPropsPanel(obj,hRightFlow,kpf);
            createNewStimRoiPropsPanel(obj,hRightFlow,kpf);
            createNewAnalysisRoiPropsPanel(obj,hRightFlow,kpf);
            createImagingRoiPropsPanel(obj,hRightFlow,kpf);
            createGlobalImagingSfPropsPanel(obj,hRightFlow,kpf);
            createImagingSfPropsPanel(obj,hRightFlow,kpf);
            createStimRoiPropsPanel(obj,hRightFlow,kpf);
            createAnalysisRoiPropsPanel(obj,hRightFlow,kpf);
            createAnalysisSfPropsPanel(obj,hRightFlow,kpf);
            createStimOptimizationPanel(obj,hRightFlow,kpf);
            createStimQuickAddPanel(obj,hRightFlow,kpf);
            createSlmPropsPanel(obj,hRightFlow,kpf);
            obj.hPropsPanels = [obj.hBlankPanel obj.hNewImagingRoiPanel obj.hNewStimRoiPanel obj.hNewAnalysisRoiPanel obj.hImagingRoiPropsPanel...
                obj.hGlobalImagingSfPropsPanel obj.hImagingSfPropsPanel obj.hStimRoiPropsPanel  obj.hAnalysisRoiPropsPanel obj.hAnalysisSfPropsPanel obj.hStimOptimizationPanel];
            
            
            %% main view area
            hLeftPanel = uipanel('Parent', hMainFlow);
            hLeftFlow = most.gui.uiflowcontainer('Parent', hLeftPanel,'FlowDirection','TopDown');
            
            %% 2D main view
            obj.h2DViewPanel = uipanel('Parent', hLeftFlow,'BorderType','None');
            c = most.constants.Colors.orange;
            obj.h2DProjectionViewAxes = most.idioms.axes('parent',obj.h2DViewPanel,'box','on','Color',most.constants.Colors.black,'ydir','reverse','XTick',[],'XTickLabel',[],'YTick',[],'YTickLabel',[],'ButtonDownFcn',@obj.zPan);
            obj.h2DProjectionViewTickAxes = most.idioms.axes('parent',obj.h2DViewPanel,'box','off','Color','none','YAxisLocation','right','hittest','off','ydir','reverse');
            xlabel(obj.h2DProjectionViewTickAxes,'X [um]');
            ylabel(obj.h2DProjectionViewTickAxes,'Sample Z [um]');
            obj.h2DScrollLine2 = line([-999999 999999],[0 0],'color',most.constants.Colors.white,'parent',obj.h2DProjectionViewAxes,'linewidth',3,'ButtonDownFcn',@obj.zScroll);
            
            obj.h2DImagingPlaneLines = line(nan,nan,'color',most.constants.Colors.white,'parent',obj.h2DProjectionViewAxes,'linewidth',1.5,'ButtonDownFcn',@obj.zScroll);
            obj.h2DFocusPlaneLine = line(nan, nan, 'color', most.constants.Colors.red  ,'parent',obj.h2DProjectionViewAxes,'linewidth',1.5,'ButtonDownFcn',@obj.zScroll);
            
            obj.h2DMainViewTickAxes = most.idioms.axes('parent',obj.h2DViewPanel,'box','off','Color','none','ydir','reverse');
            xlabel(obj.h2DMainViewTickAxes,'X [um]');
            ylabel(obj.h2DMainViewTickAxes,'Y [um]');
            obj.h2DMainViewAxes = most.idioms.axes('parent',obj.h2DViewPanel,'box','on','Color',most.constants.Colors.black,'GridColor',most.constants.Colors.lightGray,'XTickLabel',[],'YTickLabel',[],'ydir','reverse','ButtonDownFcn',@obj.mainPan,'ALim',[0 1]);
            grid(obj.h2DMainViewAxes,'on');
            
            obj.h2DMainViewOutlineAxes = most.idioms.axes('parent',obj.h2DViewPanel,'box','on','Color','none','xcolor',c,'ycolor',c,'linewidth',3,...
                'XTick',[],'XTickLabel',[],'YTick',[],'YTickLabel',[],'hittest','off');
            
            obj.h2DZScrollAxes = most.idioms.axes('parent',obj.h2DViewPanel,'Color','none','XTickLabelMode','manual','XTickLabel',[],'YTickLabelMode','manual','YTickLabel',[],...
                'XColor','none','YColor','none','ydir','reverse','ylim',[-5 100],'xlim',[0 1],'ButtonDownFcn',@obj.zScroll);
            obj.h2DScrollPatch = patch(nan,nan,.25*c,'parent',obj.h2DZScrollAxes,'EdgeColor',c,'linewidth',3,'hittest','off');
            obj.h2DScrollLine1 = line([.8 1],[0 0],'color',c,'parent',obj.h2DZScrollAxes,'linewidth',3,'hittest','off');
            obj.h2DScrollKnob = line(.8,0,'color',c,'parent',obj.h2DZScrollAxes,'markersize',15,'Marker','>','MarkerFaceColor',c,'hittest','off','color',most.constants.Colors.black,'linewidth',2);
            obj.hZCursorTextRect = rectangle('Parent',obj.h2DZScrollAxes,'EdgeColor',c,'FaceColor',most.constants.Colors.black,'ButtonDownFcn',@(src,evt)obj.selectZDialog,'Clipping','off');
            obj.hZCursorText = text('Parent',obj.h2DZScrollAxes,'HorizontalAlignment','center','VerticalAlignment','middle','Color',c,'HitTest','off','PickableParts','none','Clipping','off');
            
            obj.h2DScannerFovSurf = surface([0 1], [0 1], ones(2),'FaceColor','texturemap','edgecolor',most.constants.Colors.yellow,'linewidth',.5,'linestyle',':','parent',obj.h2DMainViewAxes,'hittest','off','ButtonDownFcn',@obj.fovSurfHit,'FaceAlpha',0.5);
            obj.h2DScannerFovLines = [line([0 0],[-999999 999999],'color',most.constants.Colors.yellow,'parent',obj.h2DProjectionViewAxes,'linewidth',.5,'linestyle',':','hittest','off')...
                line([1 1],[-999999 999999],'color',most.constants.Colors.yellow,'parent',obj.h2DProjectionViewAxes,'linewidth',.5,'linestyle',':','hittest','off')];
            obj.h2DScannerFovHandles = line(nan(8,1),nan(8,1),ones(8,1),'parent',obj.h2DMainViewAxes,'color',most.constants.Colors.yellow,'Marker','s','MarkerSize',10,'ButtonDownFcn',@obj.fovSurfHit,'visible','off');
            obj.h2DScannerFovZeroOrder = line(nan(20,1),nan(20,1),ones(20,1),'parent',obj.h2DMainViewAxes,'color',most.constants.Colors.yellow,'linestyle',':','ButtonDownFcn',@obj.fovSurfHit,'visible','off');
            
            obj.hSnapLineX = line([0,0],[-999999 999999],2*ones(1,2),'parent',obj.h2DMainViewAxes,'color',most.constants.Colors.cyan,'linestyle',':','visible','off','linewidth',1);
            obj.hSnapLineY = line([-999999 999999],[0,0],2*ones(1,2),'parent',obj.h2DMainViewAxes,'color',most.constants.Colors.cyan,'linestyle',':','visible','off','linewidth',1);
            obj.hSnapLineR = line([0 0],[0,0],2*ones(1,2),'parent',obj.h2DMainViewAxes,'color',most.constants.Colors.cyan,'linestyle',':','visible','off','linewidth',1);
            
            obj.h2DViewPanel.SizeChangedFcn = @obj.p2DViewSize;
            obj.p2DViewSize();
            
            obj.hSelObjHandles{end+1} = line(0,0,1,'Parent',obj.h2DMainViewAxes,'LineStyle','none','Marker','o','MarkerEdgeColor',most.constants.Colors.green,...
                'MarkerFaceColor',most.constants.Colors.darkGreen,'Markersize',8,'LineWidth',1.5,'visible','off','ButtonDownFcn',@obj.roiManip,'UserData','size');
            obj.hSelObjHandles{end+1} = line(zeros(2,1),zeros(2,1),[5.5;5.5],'Parent',obj.h2DMainViewAxes,'LineStyle','--','Marker','none',...
                'Color',[0 1 0],'Markersize',8,'LineWidth',1.5,'visible','off','ButtonDownFcn',@obj.roiManip,'UserData','move');
            obj.hSelObjHandles{end+1} = line(0,0,1,'Parent',obj.h2DMainViewAxes,'LineStyle','none','Marker','o','MarkerEdgeColor',most.constants.Colors.green,...
                'MarkerFaceColor','none','Markersize',8,'LineWidth',1.5,'visible','off','ButtonDownFcn',@obj.roiManip,'UserData','rotate');
            
            %% 3d main view
            obj.h3DViewPanel = uipanel('Parent', hLeftFlow,'BorderType','None','backgroundcolor',most.constants.Colors.black);
            obj.h3DViewAxes = most.idioms.axes('parent',obj.h3DViewPanel,'color',most.constants.Colors.black,'PlotBoxAspectRatio', ones(1,3),'XColor',most.constants.Colors.white,'YColor',most.constants.Colors.white,'ZColor',most.constants.Colors.white,'Projection','perspective',...
                'box','on','ZDir','reverse','YDir','reverse','ButtonDownFcn',@obj.pan3DView);
            zlabel(obj.h3DViewAxes,'Sample Z [um]');
            grid(obj.h3DViewAxes,'on');
            camtarget(obj.h3DViewAxes,[.5 .5 0]);
            view(obj.h3DViewAxes,45,45);
            obj.h3DViewPanel.Visible = 'off';
            obj.h3DViewMouseFindAxes = most.idioms.axes('parent',obj.h3DViewPanel,'color','none','XColor','none','YColor','none','position',[0 0 1 1],'hittest','off');
            
            
            %% bottom area
            hBottomLeftFlow = most.gui.uiflowcontainer('Parent', hLeftFlow,'FlowDirection','LeftToRight');
            createBottomControlsPnl(obj,hBottomLeftFlow,kpf);
            
            %% legend
            hLegendContPanel = uipanel('Parent', hBottomLeftFlow, 'title', 'Layers/Legend');
            hLegendFlow = most.gui.uiflowcontainer('Parent', hLegendContPanel,'FlowDirection','LeftToRight');
            obj.hLegendScrollingPanel = uipanel('Parent',hLegendFlow,'bordertype','none','SizeChangedFcn',@obj.legendSize);
            obj.hLegendGrid = uigridcontainer('v0','Parent',obj.hLegendScrollingPanel,'Margin',0.0001);
            obj.slLegendScroll = most.gui.uicontrol('Parent',hLegendFlow,'style','slider','callback',@obj.legendScrl,'LiveUpdate',true,kpf{:});
            set(obj.slLegendScroll, 'WidthLimits', 18*ones(1,2));
            
            obj.editingGroup = scanimage.mroi.RoiGroup;
            
            obj.initDone = true;
            obj.resetContextImages();
            
            %% init props
            if most.idioms.isValidObj(obj.hModel)
                obj.hSIListeners = most.ErrorHandler.addCatchingListener(obj.hModel.hStackManager, 'zs', 'PostSet', @obj.updateZs);
                obj.hSIListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hModel.hMotors,'samplePosition','PostSet',@obj.updateFocalPointZ);
                obj.hSIListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hModel.hCoordinateSystems.hCSFocus,'changed',@obj.updateFocalPointZ);
                obj.hSIListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hModel, 'hScan2D','PostSet',@obj.imagingSystemChange);
                obj.hSIListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hModel.hRoiManager, 'scanFrameRate','PostSet',@obj.frameRateUpdate);
            end
            
            obj.defaultStimFunction = obj.defaultStimFunction;
            obj.editorMode = 'imaging';
            obj.scannerSet = scanimage.mroi.scannerset.GalvoGalvo.default;
            obj.stagePos = nan;
            obj.editorZ = 0;
            obj.zProjectionRange = obj.zProjectionDefaultRange;
            obj.units = 'microns';
            obj.updateZs();
            obj.cellPickMode = obj.cellPickMode;
            
            obj.ensureClassDataFile(struct('lastFile','roigroup.roi'));
            obj.ensureClassDataFile(struct('lastSlmFile','slmPattern'));
            
            function setp(obj,prp,val)
                obj.(prp) = val;
            end
        end
    end
    
    %% Prop access
    methods
        function set.editorZ(obj, v)
            v = max(min(obj.zProjectionLimits(2),v),obj.zProjectionLimits(1));
            
            obj.h2DScrollKnob.YData = v;
            obj.h2DScrollLine1.YData = [v v];
            obj.h2DScrollLine2.YData = [v v];
            obj.editorZ = v;
            
            obj.updateScrollPatch();
            
            if isa(obj.selectedObj, 'scanimage.mroi.scanfield.ScanField')
                z = obj.selectedObjParent.zs(obj.selectedObjParent.scanfields == obj.selectedObj);
                if z ~= v
                    if obj.editorModeIsSlm
                        % No-op
                    elseif obj.editorModeIsStim
                        if ~obj.selectedObj.isPause
                            obj.changeSelection([], []);
                        end
                    else
                        obj.changeSelection(obj.selectedObjParent, []);
                    end
                    obj.fixTableCheck();
                end
            end
            
            if isa(obj.selectedObj, 'scanimage.mroi.Roi')
                if ismember(v, obj.selectedObj.zs)
                    str = 'Edit ScanField at Current Z';
                else
                    str = 'Add ScanField at Current Z';
                end
                obj.hAnalysisRoiPropsPanelCtls.pbCreateSf.hCtl.String = str;
                obj.hImagingRoiPropsPanelCtls.pbCreateSf.hCtl.String = str;
            end
            
            obj.updateDisplay();
            obj.cellPickSelectedCellIdx = [];
            set(obj.hZPlaneCtl, 'String', num2str(obj.editorZ));
        end
        
        function selectZDialog(obj)
            zStr = num2str(obj.editorZ);
            answer = inputdlg({'Jump to Z position (microns)','OR move ROIs to new Z position'},'Select Z',1,{zStr zStr});
            if ~isempty(answer)
                answer1 = str2double(answer{1});
                answer2 = str2double(answer{2});
                
                validateattributes(answer1,{'numeric'},{'scalar','nonnan','finite','real'});
                validateattributes(answer2,{'numeric'},{'scalar','nonnan','finite','real'});
                
                bothChanged = ~isequal(answer1,obj.editorZ) && ~isequal(answer2,obj.editorZ);
                assert(~bothChanged,'Only one of the options can be changed');
                
                if answer1 ~= obj.editorZ
                    obj.editorZ = answer1;
                elseif answer2 ~= obj.editorZ
                    deltaZ = answer2 - obj.editorZ;
                    obj.editingGroup.addZOffset(deltaZ);
                    obj.editorZ = answer2;
                end
            end
        end
        
        function set.editingGroup(obj,v)
            if isempty(v)
                v = scanimage.mroi.RoiGroup;
            end
            
            assert(isa(v,'scanimage.mroi.RoiGroup') && most.idioms.isValidObj(v),'Object must be a valid ROI group.');
            obj.editingGroup = v;
            obj.updateScanPathCache();
            
            most.idioms.safeDeleteObj(obj.hRGListener);
            most.idioms.safeDeleteObj(obj.hImGrpLis);
            obj.hRGListener = most.util.DelayedEventListener(0.5,obj.editingGroup,'changed',@obj.rgChanged);
            
            most.idioms.safeDeleteObj(obj.hRGNameListener);
            obj.hRGNameListener = most.ErrorHandler.addCatchingListener(obj.editingGroup, 'name','PostSet',@obj.nameChanged);
            obj.nameChanged();
            
            if obj.siImRg == v
                obj.hImGrpLis = most.ErrorHandler.addCatchingListener(obj.hModel.hRoiManager, 'roiGroupMroi','PostSet',@setToNewRg);
            end
            
            obj.setZProjectionLimits();
            
            function setToNewRg(varargin)
                obj.editingGroup = obj.hModel.hRoiManager.roiGroupMroi;
                obj.updateTable();
                obj.updateDisplay();
            end
        end
        
        function set.editorMode(obj,v)
            most.idioms.safeDeleteObj(obj.hSSListener);
            
            if ~obj.isGuiLoaded
                return;
            end
            switch v
                case 'imaging'
                    set(obj.roiTable, 'ColumnName', {''; 'ID'; 'ROI Name/SF Type'; 'Time (ms)'; 'Enable'; 'Display'; 'Z [um]'});
                    set(obj.roiTable, 'ColumnWidth', { 20 28 120 59 43 45 58 });
                    obj.hNewPanel = obj.hNewImagingRoiPanel;
                    obj.makeToolBoxColor = most.constants.Colors.green;
                    if most.idioms.isValidObj(obj.hModel)
                        obj.hSSListener = most.ErrorHandler.addCatchingListener(obj.hModel.hScan2D, 'scannerset','PostSet',@obj.ssChange);
                    end
                    obj.showHandles = true;
                    
                    obj.canDrawArray = isa(obj.scannerSet,'scanimage.mroi.scannerset.ResonantGalvoGalvo') && obj.scannerSet.extendedRggFov;
                    obj.hNewImagingRoiPanelCtls.cbDrawArray.Visible = obj.tfMap(obj.canDrawArray);
                    
                case 'stimulation'
                    set(obj.roiTable, 'ColumnName',{''; 'ID'; 'Stimulus Function'; 'Time (ms)'; 'Reps'; 'Power%'; 'Z [um]'});
                    set(obj.roiTable, 'ColumnWidth', { 20 28 120 64 36 60 45 });
                    obj.hNewPanel = obj.hNewStimRoiPanel;
                    obj.makeToolBoxColor = most.constants.Colors.darkGreen;
                    obj.showHandles = isa(obj.scannerSet,'scanimage.mroi.scannerset.GalvoGalvo');
                    obj.canDrawArray = false;
                    
                case 'analysis'
                    set(obj.roiTable, 'ColumnName',{''; 'ID'; 'Analysis Type'; 'Channel'; 'Thresh.'; 'Proc.'; 'Z [um]'});
                    set(obj.roiTable, 'ColumnWidth', { 20 28 120 59 56 45 45 });
                    obj.hNewPanel = obj.hNewAnalysisRoiPanel;
                    obj.makeToolBoxColor = most.constants.Colors.green;
                    if most.idioms.isValidObj(obj.hModel)
                        obj.hSSListener = most.ErrorHandler.addCatchingListener(obj.hModel.hScan2D, 'scannerset','PostSet',@obj.ssChange);
                    end
                    obj.showHandles = true;
                    obj.canDrawArray = false;
                    
                case 'slm'
                    set(obj.roiTable, 'ColumnName',{''; 'ID'; 'X'; 'Y'; 'Z'; 'Weight Factor'});
                    set(obj.roiTable, 'ColumnWidth', { 20 30 60 60 60 100});
                    if isa(obj.scannerSet,'scanimage.mroi.scannerset.GalvoGalvo')
                        obj.hSlmPropsPanelCtls.pmFunction.String = obj.slmScanOptions;
                        obj.hSlmPropsPanelCtls.pmFunction.Enable = 'on';
                        obj.showHandles = true;
                    else
                        obj.hSlmPropsPanelCtls.pmFunction.String = {'point'};
                        obj.hSlmPropsPanelCtls.pmFunction.Value = 1;
                        obj.hSlmPropsPanelCtls.pmFunction.Enable = 'off';
                        obj.showHandles = false;
                    end
                    obj.canDrawArray = false;
                    
                    %                     obj.hNewPanel = obj.hNewAnalysisRoiPanel;
                    %                     obj.makeToolBoxColor = [0 1 0];
                    %                     if most.idioms.isValidObj(obj.hModel)
                    %                         obj.hSSListener = most.ErrorHandler.addCatchingListener(obj.hModel.hScan2D, 'scannerset','PostSet',@obj.ssChange);
                    %                     end
                    
                otherwise
                    error('Invalid editor mode.');
            end
            obj.hSelObjHandles{1}.MarkerEdgeColor = obj.makeToolBoxColor;
            obj.hSelObjHandles{1}.MarkerFaceColor = obj.makeToolBoxColor * .5;
            obj.hSelObjHandles{2}.Color = obj.makeToolBoxColor;
            obj.hSelObjHandles{3}.MarkerEdgeColor = obj.makeToolBoxColor;
            
            obj.editorMode = v;
            
            obj.hCopyButtonFlow.Visible = obj.tfMap(strcmp(obj.editorMode, 'analysis'));
            
            obj.editorModeIsImaging = strcmp(obj.editorMode, 'imaging');
            obj.editorModeIsStim = strcmp(obj.editorMode, 'stimulation');
            obj.editorModeIsSlm = strcmp(obj.editorMode, 'slm');
        end
        
        function set.editorModeIsStim(obj,v)
            obj.hStimOptimizationPanel.Visible = obj.tfMap(v && isa(obj.scannerSet,'scanimage.mroi.scannerset.GalvoGalvo'));
            obj.hStimQuickAddPanel.Visible = obj.tfMap(v);
            
            obj.editorModeIsStim = v;
        end
        
        function set.editorModeIsSlm(obj,v)
            yesSlm = obj.tfMap(v);
            nonSlm = obj.tfMap(~v);
            
            obj.hButtonFlow.Visible = nonSlm;
            obj.hNameFlow.Visible = nonSlm;
            obj.pbMoveBottom.Visible = nonSlm;
            obj.pbMoveDown.Visible = nonSlm;
            obj.pbMoveUp.Visible = nonSlm;
            obj.pbMoveTop.Visible = nonSlm;
            
            obj.hSlmPatternTypeFlow.Visible = yesSlm;
            obj.hSlmPropsPanel.Visible = yesSlm;
            
            if v
                obj.pbNew.String = 'Add Points...';
            else
                obj.pbNew.String = 'Add ROI...';
                obj.pbNew.Visible = 'on';
                obj.pbDel.Visible = 'on';
                obj.roiTable.Visible = 'on';
                obj.hSlmBitmapFlow.Visible = 'off';
                obj.slmBitmapBrushEnable = false;
            end
            
            obj.editorModeIsSlm = v;
        end
        
        function set.units(obj,v)
            switch lower(v)
                case 'degrees'
                    obj.xyUnitFactor = 1;
                    xlabel(obj.h2DMainViewTickAxes,'X [deg]');
                    ylabel(obj.h2DMainViewTickAxes,'Y [deg]');
                    
                    switch obj.projectionMode
                        case 'XZ'
                            xlabel(obj.h2DProjectionViewTickAxes,'X [deg]');
                        case 'YZ'
                            xlabel(obj.h2DProjectionViewTickAxes,'Y [deg]');
                        otherwise
                            xlabel(obj.h2DProjectionViewTickAxes,'? [deg]');
                    end
                    
                    obj.hImagingSfPropsPanelCtls.stPixRatioX.hTxt.String = 'Pixel Ratio [Pix/deg] X:';
                    obj.hImagingSfPropsPanelCtls.stPixRatioY.hTxt.String = 'Pixel Ratio [Pix/deg] Y:';
                    obj.hNewImagingRoiPanelCtls.stPixRatioX.hTxt.String = 'Pixel Ratio [Pix/deg] X:';
                    obj.hNewImagingRoiPanelCtls.stPixRatioY.hTxt.String = 'Pixel Ratio [Pix/deg] Y:';
                    
                    obj.hNewImagingRoiPanelCtls.stMargin.hTxt.String = 'ROI Margin [deg]:';
                    obj.hNewAnalysisRoiPanelCtls.stMargin.hTxt.String = 'ROI Margin [deg]:';
                    
                    xlabel(obj.h3DViewAxes,'X [deg]');
                    ylabel(obj.h3DViewAxes,'Y [deg]');
                    
                case {'microns' 'um'}
                    v = 'microns';
                    obj.xyUnitFactor = obj.siObjectiveResolution;
                    xlabel(obj.h2DMainViewTickAxes,'X [um]');
                    ylabel(obj.h2DMainViewTickAxes,'Y [um]');
                    
                    switch obj.projectionMode
                        case 'XZ'
                            xlabel(obj.h2DProjectionViewTickAxes,'X [um]');
                        case 'YZ'
                            xlabel(obj.h2DProjectionViewTickAxes,'Y [um]');
                        otherwise
                            xlabel(obj.h2DProjectionViewTickAxes,'? [um]');
                    end
                    
                    obj.hImagingSfPropsPanelCtls.stPixRatioX.hTxt.String = 'Pixel Ratio [Pix/um] X:';
                    obj.hImagingSfPropsPanelCtls.stPixRatioY.hTxt.String = 'Pixel Ratio [Pix/um] Y:';
                    obj.hNewImagingRoiPanelCtls.stPixRatioX.hTxt.String = 'Pixel Ratio [Pix/um] X:';
                    obj.hNewImagingRoiPanelCtls.stPixRatioY.hTxt.String = 'Pixel Ratio [Pix/um] Y:';
                    
                    obj.hNewImagingRoiPanelCtls.stMargin.hTxt.String = 'ROI Margin [um]:';
                    obj.hNewAnalysisRoiPanelCtls.stMargin.hTxt.String = 'ROI Margin [um]:';
                    
                    xlabel(obj.h3DViewAxes,'X [um]');
                    ylabel(obj.h3DViewAxes,'Y [um]');
                    
                otherwise
                    error('Unsupported unit.');
            end
            
            obj.units = lower(v);
            obj.updateXYAxes();
            obj.updateDisplay();
            obj.selectedObjChanged();
            obj.updateGlobalPanel();
            
            if obj.editorModeIsSlm
                obj.updateTable();
            end
        end
        
        function set.zProjectionRange(obj, v)
            v(1) = min(max(v(1),obj.zProjectionLimits(1)),obj.zProjectionLimits(2));
            v(2) = min(max(v(2),obj.zProjectionLimits(1)),obj.zProjectionLimits(2));
            
            if diff(v) < 1
                v = [-.5 .5] + sum(v)/2;
            end
            
            obj.zProjectionRange = v;
            
            obj.h2DZScrollAxes.YLim = v;
            obj.h2DProjectionViewAxes.YLim = v;
            
            [~,prefix,exponent] = most.idioms.engineersStyle(max(abs(v))*1e-6,'m');
            obj.h2DProjectionViewTickAxes.YLim = v.*1e-6 ./ 10^exponent;
            ylabel(obj.h2DProjectionViewTickAxes,['Sample Z [' prefix 'm]']);
            
            obj.updateScrollPatch();
        end
        
        function set.mainViewFov(obj,v)
            obj.mainViewFov = max(min(obj.mainViewFovLim,v),2^-8);
            obj.mainViewPosition = obj.mainViewPosition;
        end
        
        function set.mainViewPosition(obj,v)
            mxPos = (obj.mainViewFovLim-obj.mainViewFov)/2;
            obj.mainViewPosition = max(min(v,mxPos),-mxPos);
            obj.updateXYAxes();
        end
        
        function set.viewMode(obj, v)
            obj.deleteDrawData();
            
            switch v
                case '2D'
                    obj.h3DViewPanel.Visible = 'off';
                    obj.h2DViewPanel.Visible = 'on';
                    obj.viewMode = v;
                    set(obj.tbViewMode2D, 'Value', true);
                    set(obj.tbViewMode3D, 'Value', false);
                    obj.updateDisplay();
                    
                case '3D'
                    obj.h2DViewPanel.Visible = 'off';
                    obj.h3DViewPanel.Visible = 'on';
                    obj.viewMode = v;
                    set(obj.tbViewMode3D, 'Value', true);
                    set(obj.tbViewMode2D, 'Value', false);
                    obj.updateDisplay();
                    camtarget(obj.h3DViewAxes,[.5 .5 mean(obj.h3DViewAxes.ZLim)]);
                    view(obj.h3DViewAxes,45,45);
                    
                otherwise
                    error('Unsupported view mode.');
            end
            
            obj.updateXYAxes();
        end
        
        function set.projectionMode(obj, v)
            switch lower(obj.units)
                case 'microns'
                    units_ = ' [um]';
                case 'degrees'
                    units_ = ' [deg]';
                otherwise
                    units_ = '';
            end
            
            switch v
                case 'XZ'
                    obj.projectionMode = v;
                    obj.projectionDim = 1;
                    set(obj.tbProjectionModeXZ, 'Value', true);
                    set(obj.tbProjectionModeYZ, 'Value', false);
                    
                    obj.h2DScannerFovLines(1).XData = min(obj.fovGridxx(:))*ones(1,2);
                    obj.h2DScannerFovLines(2).XData = max(obj.fovGridxx(:))*ones(1,2);
                    
                    xlabel(obj.h2DProjectionViewTickAxes,sprintf('X%s',units_));
                case 'YZ'
                    obj.projectionMode = v;
                    obj.projectionDim = 2;
                    set(obj.tbProjectionModeYZ, 'Value', true);
                    set(obj.tbProjectionModeXZ, 'Value', false);
                    
                    obj.h2DScannerFovLines(1).XData = min(obj.fovGridyy(:))*ones(1,2);
                    obj.h2DScannerFovLines(2).XData = max(obj.fovGridyy(:))*ones(1,2);
                    
                    xlabel(obj.h2DProjectionViewTickAxes,sprintf('Y%s',units_));
                otherwise
                    error('Unsupported projection mode.');
            end
            obj.updateDisplay();
            obj.updateXYAxes();
        end
        
        function set.showEditorZ(obj, v)
            obj.h2DScrollLine2.Visible = obj.tfMap(v);
            obj.showEditorZ = v;
        end
        
        function set.showImagingZs(obj, v)
            if v
                set(obj.h2DImagingPlaneLines, 'visible', 'on');
                set(obj.h2DFocusPlaneLine, 'visible', 'on');
                set(obj.h3DImagingPlaneSurfs(1:obj.n3dip), 'visible', 'on');
            else
                set(obj.h2DImagingPlaneLines, 'visible', 'off');
                set(obj.h2DFocusPlaneLine, 'visible', 'off');
                set(obj.h3DImagingPlaneSurfs, 'visible', 'off');
            end
            
            obj.showImagingZs = v;
        end
        
        function set.showScannerFov(obj, v)
            obj.showScannerFov = v;
            obj.h2DScannerFovSurf.Visible = obj.tfMap(v);
            set(obj.h2DScannerFovLines,'Visible',obj.tfMap(v));
        end
        
        function set.showSelectedRoi(obj, v)
            obj.showSelectedRoi = v;
            if obj.selectedObjRoiIdx > 0
                cellfun(@(x)set(x,'Visible',obj.tfMap(v)), obj.drawData{obj.selectedObjRoiIdx});
                if isa(obj.selectedObj, 'scanimage.mroi.Roi')
                    v = ~isempty(obj.selectedObj.get(obj.editorZ)) && v;
                end
                cellfun(@(x)set(x,'Visible',obj.tfMap(v && obj.showHandles)),obj.hSelObjHandles);
                
                if ~isempty(obj.drawDataProj{1})
                    cellfun(@(x)set(x,'Visible',obj.tfMap(v)), obj.drawDataProj{obj.selectedObjRoiIdx});
                end
            end
        end
        
        function set.showOtherRois(obj, v)
            obj.showOtherRois = v;
            ids = setdiff(1:numel(obj.drawData),obj.selectedObjRoiIdx);
            if ~isempty(ids)
                cellfun(@(x)set(x,'Visible',obj.tfMap(v)), horzcat(obj.drawData{ids}));
                
                if ~isempty(obj.drawDataProj{1})
                    cellfun(@(x)set(x,'Visible',obj.tfMap(v)), horzcat(obj.drawDataProj{ids}));
                end
            end
        end
        
        function set.newRoiDrawMode(obj, v)
            switch v
                case 'top left rectangle'
                    set(obj.hNewImagingRoiPanelCtls.rbTopLeftRect, 'Value', true);
                    set(obj.hNewImagingRoiPanelCtls.rbCenterPtRect, 'Value', false);
                    set(obj.hNewImagingRoiPanelCtls.rbCellPick, 'Value', false);
                    set(obj.hNewImagingRoiPanelCtls.stDraw, 'String', '   Draw new ROI...');
                    set(obj.hNewImagingRoiPanelCtls.pbCreate, 'String', 'Create Using Defaults');
                    set(obj.hNewImagingRoiPanelCtls.pbCreate, 'Enable', 'on');
                    
                    set(obj.hNewStimRoiPanelCtls.rbTopLeftRect, 'Value', true);
                    set(obj.hNewStimRoiPanelCtls.rbCenterPtRect, 'Value', false);
                    set(obj.hNewStimRoiPanelCtls.rbCellPick, 'Value', false);
                    set(obj.hNewStimRoiPanelCtls.stDraw, 'String', '   Draw new ROI...');
                    set(obj.hNewStimRoiPanelCtls.pbCreate, 'String', 'Create Using Defaults');
                    set(obj.hNewImagingRoiPanelCtls.pbCreate, 'Enable', 'on');
                    
                    set(obj.hNewAnalysisRoiPanelCtls.rbTopLeftRect, 'Value', true);
                    set(obj.hNewAnalysisRoiPanelCtls.rbCenterPtRect, 'Value', false);
                    set(obj.hNewAnalysisRoiPanelCtls.rbCellPick, 'Value', false);
                    set(obj.hNewAnalysisRoiPanelCtls.stDraw, 'String', '   Draw new ROI...');
                    set(obj.hNewAnalysisRoiPanelCtls.pbCreate, 'String', 'Create Using Defaults');
                    set(obj.hNewImagingRoiPanelCtls.pbCreate, 'Enable', 'on');
                    
                    
                    set(obj.hNewImagingRoiPanelCtls.cellCtls, 'Visible', 'off');
                    set(obj.hNewImagingRoiPanelCtls.rectCtls, 'Visible', 'on');
                    set(obj.hNewImagingRoiPanelCtls.cbDrawMultiple, 'Visible', 'on');
                    
                    set(obj.hNewStimRoiPanelCtls.cellCtls, 'Visible', 'off');
                    set(obj.hNewStimRoiPanelCtls.rectCtls, 'Visible', 'on');
                    set(obj.hNewStimRoiPanelCtls.cbDrawMultiple, 'Visible', 'on');
                    
                    set(obj.hNewAnalysisRoiPanelCtls.cellCtls, 'Visible', 'off');
                    set(obj.hNewAnalysisRoiPanelCtls.rectCtls, 'Visible', 'on');
                    set(obj.hNewAnalysisRoiPanelCtls.cbDrawMultiple, 'Visible', 'on');
                    
                    obj.cellPickOn = false;
                    obj.endCellPick(false);
                    
                case 'center point rectangle'
                    set(obj.hNewImagingRoiPanelCtls.rbTopLeftRect, 'Value', false);
                    set(obj.hNewImagingRoiPanelCtls.rbCenterPtRect, 'Value', true);
                    set(obj.hNewImagingRoiPanelCtls.rbCellPick, 'Value', false);
                    set(obj.hNewImagingRoiPanelCtls.stDraw, 'String', '   Draw new ROI...');
                    set(obj.hNewImagingRoiPanelCtls.pbCreate, 'String', 'Create Using Defaults');
                    set(obj.hNewImagingRoiPanelCtls.pbCreate, 'Enable', 'on');
                    
                    set(obj.hNewStimRoiPanelCtls.rbTopLeftRect, 'Value', false);
                    set(obj.hNewStimRoiPanelCtls.rbCenterPtRect, 'Value', true);
                    set(obj.hNewStimRoiPanelCtls.rbCellPick, 'Value', false);
                    set(obj.hNewStimRoiPanelCtls.stDraw, 'String', '   Draw new ROI...');
                    set(obj.hNewStimRoiPanelCtls.pbCreate, 'String', 'Create Using Defaults');
                    set(obj.hNewImagingRoiPanelCtls.pbCreate, 'Enable', 'on');
                    
                    set(obj.hNewAnalysisRoiPanelCtls.rbTopLeftRect, 'Value', false);
                    set(obj.hNewAnalysisRoiPanelCtls.rbCenterPtRect, 'Value', true);
                    set(obj.hNewAnalysisRoiPanelCtls.rbCellPick, 'Value', false);
                    set(obj.hNewAnalysisRoiPanelCtls.stDraw, 'String', '   Draw new ROI...');
                    set(obj.hNewAnalysisRoiPanelCtls.pbCreate, 'String', 'Create Using Defaults');
                    set(obj.hNewImagingRoiPanelCtls.pbCreate, 'Enable', 'on');
                    
                    
                    set(obj.hNewImagingRoiPanelCtls.cellCtls, 'Visible', 'off');
                    set(obj.hNewImagingRoiPanelCtls.rectCtls, 'Visible', 'on');
                    set(obj.hNewImagingRoiPanelCtls.cbDrawMultiple, 'Visible', 'on');
                    
                    set(obj.hNewStimRoiPanelCtls.cellCtls, 'Visible', 'off');
                    set(obj.hNewStimRoiPanelCtls.rectCtls, 'Visible', 'on');
                    set(obj.hNewStimRoiPanelCtls.cbDrawMultiple, 'Visible', 'on');
                    
                    set(obj.hNewAnalysisRoiPanelCtls.cellCtls, 'Visible', 'off');
                    set(obj.hNewAnalysisRoiPanelCtls.rectCtls, 'Visible', 'on');
                    set(obj.hNewAnalysisRoiPanelCtls.cbDrawMultiple, 'Visible', 'on');
                    
                    obj.cellPickOn = false;
                    obj.endCellPick(false);
                    
                case 'cell picker'
                    set(obj.hNewImagingRoiPanelCtls.rbTopLeftRect, 'Value', false);
                    set(obj.hNewImagingRoiPanelCtls.rbCenterPtRect, 'Value', false);
                    set(obj.hNewImagingRoiPanelCtls.rbCellPick, 'Value', true);
                    set(obj.hNewImagingRoiPanelCtls.stDraw, 'String', '   Select Cells...');
                    set(obj.hNewImagingRoiPanelCtls.pbCreate, 'String', 'Add Selected Cells');
                    
                    set(obj.hNewStimRoiPanelCtls.rbTopLeftRect, 'Value', false);
                    set(obj.hNewStimRoiPanelCtls.rbCenterPtRect, 'Value', false);
                    set(obj.hNewStimRoiPanelCtls.rbCellPick, 'Value', true);
                    set(obj.hNewStimRoiPanelCtls.stDraw, 'String', '   Select Cells...');
                    set(obj.hNewStimRoiPanelCtls.pbCreate, 'String', 'Add Selected Cells');
                    
                    set(obj.hNewAnalysisRoiPanelCtls.rbTopLeftRect, 'Value', false);
                    set(obj.hNewAnalysisRoiPanelCtls.rbCenterPtRect, 'Value', false);
                    set(obj.hNewAnalysisRoiPanelCtls.rbCellPick, 'Value', true);
                    set(obj.hNewAnalysisRoiPanelCtls.stDraw, 'String', '   Select Cells...');
                    set(obj.hNewAnalysisRoiPanelCtls.pbCreate, 'String', 'Add Selected Cells');
                    
                    
                    set(obj.hNewImagingRoiPanelCtls.rectCtls, 'Visible', 'off');
                    set(obj.hNewImagingRoiPanelCtls.cbDrawMultiple, 'Visible', 'off');
                    set(obj.hNewImagingRoiPanelCtls.cellCtls, 'Visible', 'on');
                    
                    set(obj.hNewStimRoiPanelCtls.rectCtls, 'Visible', 'off');
                    set(obj.hNewStimRoiPanelCtls.cbDrawMultiple, 'Visible', 'off');
                    set(obj.hNewStimRoiPanelCtls.cellCtls, 'Visible', 'on');
                    
                    set(obj.hNewAnalysisRoiPanelCtls.rectCtls, 'Visible', 'off');
                    set(obj.hNewAnalysisRoiPanelCtls.cbDrawMultiple, 'Visible', 'off');
                    set(obj.hNewAnalysisRoiPanelCtls.cellCtls, 'Visible', 'on');
                    
                    obj.cellPickOn = true;
                    
                    if obj.createMode && ~strcmp(obj.newRoiDrawMode, v)
                        obj.startCellPick();
                    end
                    
                otherwise
                    error('Invalid choice.');
            end
            
            if obj.createMode && ~obj.cellPickOn
                obj.h2DMainViewAxes.ButtonDownFcn = @obj.mainCreate;
            else
                obj.h2DMainViewAxes.ButtonDownFcn = @obj.mainPan;
            end
            
            obj.newRoiDrawMode = v;
            
            if (~obj.editorModeIsStim && ~obj.editorModeIsSlm) || (~strcmp(obj.defaultStimFunction,'point') && ~strcmp(obj.defaultStimFunction,'waypoint'))
                obj.newRoiDrawModeCache = v;
            end
        end
        
        function set.scanfieldResizeMaintainPixelProp(obj, v)
            switch v
                case 'count'
                    set(obj.hImagingSfPropsPanelCtls.rbMaintainPixCount, 'Value', true);
                    set(obj.hImagingSfPropsPanelCtls.rbMaintainPixRatio, 'Value', false);
                    
                case 'ratio'
                    set(obj.hImagingSfPropsPanelCtls.rbMaintainPixRatio, 'Value', true);
                    set(obj.hImagingSfPropsPanelCtls.rbMaintainPixCount, 'Value', false);
                    
                otherwise
                    error('Invalid choice.');
            end
            obj.scanfieldResizeMaintainPixelProp = v;
        end
        
        function set.newRoiDefaultResolutionMode(obj, v)
            switch v
                case 'pixel count'
                    set(obj.hNewImagingRoiPanelCtls.rbPixCount, 'Value', true);
                    set(obj.hNewImagingRoiPanelCtls.rbPixRatio, 'Value', false);
                    
                    obj.hNewImagingRoiPanelCtls.pixRatCtls.Visible = 'off';
                    obj.hNewImagingRoiPanelCtls.pixCntCtls.Visible = 'on';
                    
                case 'pixel ratio'
                    set(obj.hNewImagingRoiPanelCtls.rbPixRatio, 'Value', true);
                    set(obj.hNewImagingRoiPanelCtls.rbPixCount, 'Value', false);
                    
                    obj.hNewImagingRoiPanelCtls.pixCntCtls.Visible = 'off';
                    obj.hNewImagingRoiPanelCtls.pixRatCtls.Visible = 'on';
                    
                otherwise
                    error('Invalid choice.');
            end
            obj.newRoiDefaultResolutionMode = v;
        end
        
        function set.defaultRoiPixelCountX(obj,v)
            obj.defaultRoiPixelCountX = v;
            obj.hNewImagingRoiPanelCtls.etPixCountX.hCtl.String = v;
        end
        
        function set.defaultRoiPixelCountY(obj,v)
            obj.defaultRoiPixelCountY = v;
            obj.hNewImagingRoiPanelCtls.etPixCountY.hCtl.String = v;
        end
        
        function set.defaultRoiPixelRatioX(obj,v)
            obj.defaultRoiPixelRatioX = v;
            obj.hNewImagingRoiPanelCtls.etPixRatioX.hCtl.String = v/obj.xyUnitFactor;
        end
        
        function set.defaultRoiPixelRatioY(obj,v)
            obj.defaultRoiPixelRatioY = v;
            obj.hNewImagingRoiPanelCtls.etPixRatioY.hCtl.String = v/obj.xyUnitFactor;
        end
        
        function set.defaultRoiPositionX(obj,v)
            obj.defaultRoiPositionX = v;
            obj.hNewImagingRoiPanelCtls.etCenterX.hCtl.String = v*obj.xyUnitFactor + obj.xyUnitOffset(1);
            obj.hNewStimRoiPanelCtls.etCenterX.hCtl.String = v*obj.xyUnitFactor + obj.xyUnitOffset(1);
            obj.hNewAnalysisRoiPanelCtls.etCenterX.hCtl.String = v*obj.xyUnitFactor + obj.xyUnitOffset(1);
        end
        
        function set.defaultRoiPositionY(obj,v)
            obj.defaultRoiPositionY = v;
            obj.hNewImagingRoiPanelCtls.etCenterY.hCtl.String = v*obj.xyUnitFactor + obj.xyUnitOffset(2);
            obj.hNewStimRoiPanelCtls.etCenterY.hCtl.String = v*obj.xyUnitFactor + obj.xyUnitOffset(2);
            obj.hNewAnalysisRoiPanelCtls.etCenterY.hCtl.String = v*obj.xyUnitFactor + obj.xyUnitOffset(2);
        end
        
        function set.defaultRoiWidth(obj,v)
            obj.defaultRoiWidth = v;
            obj.hNewImagingRoiPanelCtls.etWidth.hCtl.String = v*obj.xyUnitFactor;
            obj.hNewStimRoiPanelCtls.etWidth.hCtl.String = v*obj.xyUnitFactor;
            obj.hNewAnalysisRoiPanelCtls.etWidth.hCtl.String = v*obj.xyUnitFactor;
        end
        
        function set.defaultRoiHeight(obj,v)
            obj.defaultRoiHeight = v;
            obj.hNewImagingRoiPanelCtls.etHeight.hCtl.String = v*obj.xyUnitFactor;
            obj.hNewStimRoiPanelCtls.etHeight.hCtl.String = v*obj.xyUnitFactor;
            obj.hNewAnalysisRoiPanelCtls.etHeight.hCtl.String = v*obj.xyUnitFactor;
        end
        
        function set.cellPickRoiMargin(obj,v)
            obj.cellPickRoiMargin = v;
            obj.hNewImagingRoiPanelCtls.etMargin.hCtl.String = v*obj.xyUnitFactor;
            obj.hNewStimRoiPanelCtls.etMargin.hCtl.String = v*obj.xyUnitFactor;
            obj.hNewAnalysisRoiPanelCtls.etMargin.hCtl.String = v*obj.xyUnitFactor;
        end
        
        function set.defaultRoiRotation(obj,v)
            obj.defaultRoiRotation = v;
            obj.hNewImagingRoiPanelCtls.etRotation.hCtl.String = v;
            obj.hNewStimRoiPanelCtls.etRotation.hCtl.String = v;
            obj.hNewAnalysisRoiPanelCtls.etRotation.hCtl.String = v;
        end
        
        function set.createMode(obj,v)
            if v
                obj.hFig.Pointer = 'crosshair';
                if ~obj.cellPickOn
                    obj.h2DMainViewAxes.ButtonDownFcn = @obj.mainCreate;
                end
            else
                if ~obj.slmBitmapBrushEnable
                    obj.hFig.Pointer = 'arrow';
                end
                obj.h2DMainViewAxes.ButtonDownFcn = @obj.mainPan;
                obj.endCellPick(false);
                
                if strcmp(obj.editorMode,'slm')
                    obj.pbNew.String = 'Add Points...';
                else
                    obj.pbNew.String = 'Add ROI...';
                end
            end
            
            obj.createMode = v;
        end
        
        function v = get.siZs(obj)
            if most.idioms.isValidObj(obj.hModel)
                v = obj.hModel.hStackManager.zs;
            else
                v = 0;
            end
        end
        
        function v = get.siImRg(obj)
            if most.idioms.isValidObj(obj.hModel)
                v = obj.hModel.hRoiManager.roiGroupMroi;
            else
                v = [];
            end
        end
        
        function v = get.siObjectiveResolution(obj)
            if most.idioms.isValidObj(obj.hModel)
                v = obj.hModel.objectiveResolution;
            else
                v = 15;
            end
        end
        
        function set.scannerSet(obj,ss)
            obj.scannerSet = ss;
            
            isgg = isa(ss,'scanimage.mroi.scannerset.GalvoGalvo');
            if isgg
                obj.hNewStimRoiPanelCtls.pmFunction.String = obj.stimFcnOptions;
                obj.hStimRoiPropsPanelCtls.pmFunction.String = obj.hNewStimRoiPanelCtls.pmFunction.String;
                
                if ~ismember(obj.defaultStimFunction, obj.hNewStimRoiPanelCtls.pmFunction.String)
                    obj.defaultStimFunction = 'logspiral';
                end
            elseif obj.editorModeIsStim
                obj.hNewStimRoiPanelCtls.pmFunction.String = obj.slmOnlyOptions;
                obj.hStimRoiPropsPanelCtls.pmFunction.String = obj.slmOnlyOptions;
                obj.defaultStimFunction = 'point';
            end
            
            if obj.editorModeIsStim || obj.editorModeIsSlm
                obj.showHandles = isgg;
            end
            
            if ~obj.isGuiLoaded
                return;
            end
            
            obj.updateFovLines();
            obj.updateMaxViewFov();
        end
        
        function v = get.scannersetIsSlm(obj)
            v = ~isempty(obj.scannerSet) && isa(obj.scannerSet,'scanimage.mroi.scannerset.SLM');
        end
        
        function set.cellPickMode(obj, v)
            switch v
                case 'Disk cell'
                    obj.cellPickFunc = @obj.diskCellPickFunc;
                    
                case 'Annular cell'
                    obj.cellPickFunc = @obj.annularCellPickFunc;
                    
                case 'Manual'
                    obj.cellPickFunc = @obj.manualCellPickFunc;
                    
                case 'Custom...'
                    resp = inputdlg('Enter the name of a function on the matlab search path that contains custom cell segmentation ...','Select Custom',1,{'customCellPickFunc'});
                    if isempty(resp)
                        return;
                    end
                    v = resp{1};
                    if isvarname(v)
                        obj.cellPickFunc = str2func(v);
                        obj.cellPickModes{end+1} = v;
                        set([obj.hNewImagingRoiPanelCtls.pmSelMode.hCtl obj.hNewStimRoiPanelCtls.pmSelMode.hCtl obj.hNewAnalysisRoiPanelCtls.pmSelMode.hCtl],'string',{obj.cellPickModes{:},'Custom...'});
                    else
                        fprintf(2,'Invalid function name.\n');
                        return;
                    end
                    
                otherwise
                    assert(isvarname(v),'Invalid function name.');
                    if ~ismember(v,obj.cellPickModes)
                        obj.cellPickModes{end+1} = v;
                        set([obj.hNewImagingRoiPanelCtls.pmSelMode.hCtl obj.hNewStimRoiPanelCtls.pmSelMode.hCtl obj.hNewAnalysisRoiPanelCtls.pmSelMode.hCtl],'string',{obj.cellPickModes{:},'Custom...'});
                    end
                    obj.cellPickFunc = str2func(v);
            end
            obj.cellPickMode = v;
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Added property access for default stim parameters panel
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function set.defaultStimDuration(obj, val)
            assert(~isempty(val) && ~isnan(val) && ~isinf(val) && (val > 0), 'Duration must be a valid number. NaN and Inf are not allowed. Resetting to previous value.');
            obj.defaultStimDuration = val;
            if strcmp('waypoint', obj.defaultStimFunction)
                obj.defaultWpStimDuration = val;
            else
                obj.defaultScnStimDuration = val;
            end
        end
        
        function set.defaultStimRepititions(obj, val)
            if ~isempty(val) && ~isnan(val) && ~isinf(val) && (val > 0)
                obj.defaultStimRepititions = ceil(val);
            else
                most.idioms.warn('Repititions must be a valid positive integer. NaN and Inf are not allowed. Resetting to previous value.');
            end
        end
        
        function set.defaultStimPower(obj, val)
            if isempty(val) || isnan(val)
                % store the last actual value
                if ~isempty(obj.defaultStimPower)
                    obj.defaultStimPowerLastAct = obj.defaultStimPower;
                end
                obj.defaultStimPower = [];
            elseif isinf(val)
                % restore last actual value
                obj.defaultStimPower = obj.defaultStimPowerLastAct;
            elseif val >= 0 && val <= 100
                obj.defaultStimPower = val;
            else
                most.idioms.warn('Beam Power must be a valid number between 0 and 100. Resetting to previous value.');
            end
        end
        
        function set.stagePos(obj,~)
            if most.idioms.isValidObj(obj.hModel)
                p = obj.hModel.hMotors.samplePosition;
                fmt = ['[ ' strtrim(repmat('%.2f   ',1,numel(p))) ' ]'];
                obj.stagePos = num2str(p,fmt);
            end
        end
        
        function v = get.locks(obj)
            v = logical([obj.lockScanfieldWidth obj.lockScanfieldHeight]);
        end
        
        function v = get.defaultRoiSize(obj)
            v = [obj.defaultRoiWidth obj.defaultRoiHeight];
        end
        
        function set.lockScanfieldWidth(obj, v)
            obj.lockScanfieldWidth = v;
            
            if isa(obj.selectedObj, 'scanimage.mroi.scanfield.ScanField')
                obj.defaultRoiWidth = obj.selectedObj.sizeXY(1);
            end
        end
        
        function set.lockScanfieldHeight(obj, v)
            obj.lockScanfieldHeight = v;
            
            if isa(obj.selectedObj, 'scanimage.mroi.scanfield.ScanField')
                obj.defaultRoiHeight = obj.selectedObj.sizeXY(2);
            end
        end
        
        function set.drawMultipleRois(obj,v)
            obj.drawMultipleRois = v;
            if obj.createMode
                if strcmp(obj.editorMode,'slm') || v
                    obj.pbNew.String = 'Done';
                else
                    obj.pbNew.String = 'Cancel';
                end
            end
            
            if ~obj.editorModeIsStim || ~strcmp('waypoint', obj.defaultStimFunction)
                obj.drawMultipleRoisCache = v;
            end
        end
        
        function set.enableListeners(obj,v)
            if most.idioms.isValidObj(obj.hRGListener)
                obj.hRGListener.enabled = v;
            end
            if most.idioms.isValidObj(obj.hSlmListener)
                obj.hSlmListener.enabled = v;
            end
            for i = 1:numel(obj.hSelObjListener)
                if most.idioms.isValidObj(obj.hSelObjListener(i))
                    obj.hSelObjListener(i).enabled = v;
                end
            end
        end
        
        function set.stimQuickAddDuration(obj,v)
            if ~isempty(v) && ~isnan(v)
                obj.stimQuickAddDuration = v;
            end
        end
        
        function set.defaultStimFunction(obj,v)
            obj.defaultStimFunction = v;
            obj.hNewStimRoiPanelCtls.etArgs.ParameterOptions = obj.getStimParamOptions(v);
            
            isp = strcmp('point', obj.defaultStimFunction);
            iswp = strcmp('waypoint', obj.defaultStimFunction);
            
            if obj.editorModeIsStim
                if iswp
                    obj.defaultStimDuration = obj.defaultWpStimDuration;
                    obj.drawMultipleRois = true;
                else
                    obj.defaultStimDuration = obj.defaultScnStimDuration;
                    obj.drawMultipleRois = obj.drawMultipleRoisCache;
                end
            else
                obj.drawMultipleRois = obj.drawMultipleRoisCache;
            end
            
            if obj.editorModeIsSlm || (obj.editorModeIsStim && (isp || iswp))
                obj.newRoiDrawMode = 'center point rectangle';
            else
                obj.newRoiDrawMode = obj.newRoiDrawModeCache;
            end
        end
        
        function set.slmPatternType(obj,v)
            if obj.editorModeIsSlm
                
                sf = obj.slmPatternSfParent;
                curpat = sf.slmPattern;
                
                if isempty(v)
                    if isempty(curpat) || size(curpat,2) < 5
                        v = 'point';
                    else
                        v = 'bitmap';
                    end
                end
                
                switch(v)
                    case 'point'
                        if ~isempty(curpat) && (size(curpat,2) > 4) && (sum(curpat(:)) > 0)
                            answ = questdlg('The current bitmap will be cleared. Continue?', 'SLM Pattern Editor', 'Continue', 'Cancel', 'Cancel');
                            if strcmp(answ, 'Continue')
                                curpat = [];
                            else
                                return;
                            end
                        elseif size(curpat,2) == 3
                            curpat(:,4) = 1;
                        elseif size(curpat,2) ~= 4
                            curpat = [];
                        end
                        obj.slmPatternSfParent.slmPattern = curpat;
                        
                        obj.editingGroup = [];
                        sz = sf.sizeXY;
                        for i = 1:size(curpat,1)
                            obj.createRoi(curpat(i,1:2) + sf.centerXY,sz,curpat(i,3),curpat(i,4));
                        end
                        
                        obj.updateTable();
                        bmtf = 'off';
                        nbmtf = 'on';
                        bm = false;
                        
                    case 'bitmap'
                        if ~isempty(curpat) && (size(curpat,2) < 5)
                            answ = questdlg('The current point array will be cleared. Continue?', 'SLM Pattern Editor', 'Continue', 'Cancel', 'Cancel');
                            if strcmp(answ, 'Continue')
                                ss = obj.scannerSet;
                                if isa(ss,'scanimage.mroi.scannerset.GalvoGalvo')
                                    ss = ss.slm;
                                end
                                obj.slmPatternSfParent.slmPattern = zeros(fliplr(ss.scanners{1}.hDevice.pixelResolutionXY));
                            else
                                return;
                            end
                        elseif isempty(obj.slmPatternSfParent.slmPattern)
                            ss = obj.scannerSet;
                            if isa(ss,'scanimage.mroi.scannerset.GalvoGalvo')
                                ss = ss.slm;
                            end
                            obj.slmPatternSfParent.slmPattern = zeros(fliplr(ss.scanners{1}.hDevice.pixelResolutionXY));
                        end
                        
                        obj.editingGroup = [];
                        obj.createRoi(sf.centerXY, sf.sizeXY, 0, 0);
                        
                        bmtf = 'on';
                        nbmtf = 'off';
                        bm = true;
                        
                    otherwise
                        error('Invalid SLM pattern type.');
                end
                
                obj.hSlmBitmapFlow.Visible = bmtf;
                obj.pbNew.Visible = nbmtf;
                obj.pbDel.Visible = nbmtf;
                obj.roiTable.Visible = nbmtf;
                
                obj.slmPatternType = v;
                obj.slmPatternTypeIsBitmap = bm;
                obj.slmBitmapBrushEnable = false;
                
                obj.changeSelection();
            end
        end
        
        function set.slmBitmapDisplayTransparency(obj,v)
            obj.h2DScannerFovSurf.FaceAlpha = v;
            obj.slmBitmapDisplayTransparency = v;
        end
        
        function set.slmBitmapBrushEnable(obj,v)
            if v
                obj.bufferSlmPixelMesh();
                obj.hFig.Pointer = 'crosshair';
                obj.hFig.WindowButtonMotionFcn = @obj.brushHover;
            else
                obj.hFig.Pointer = 'arrow';
                obj.hFig.WindowButtonMotionFcn = [];
            end
            obj.slmBitmapBrushEnable = v;
        end
        
        function set.scanPathCache(obj,v)
            obj.scanPathCache = v;
        end
    end % methods - property access
    
    %% User methods
    methods
        function setEditorGroupAndMode(obj,group,scannerset,mode)
            % this method can be called before the GUI is initialized
            % ensure initialization before continuing
            obj.initGuiOnce(); 
            
            if nargin > 3
                obj.editorMode = mode;
            end
            
            % for slm pattern editing, obj.slmPatternRoiParent must be
            % populated before setting the scannerset to properly represent
            % the slm FOV when offset by the galvos
            if obj.editorModeIsSlm
                if isempty(group) || ~isa(group, 'scanimage.mroi.Roi')
                    obj.slmPatternRoiParent = scanimage.mroi.Roi;
                    obj.slmPatternSfParent = scanimage.mroi.scanfield.fields.StimulusField('scanimage.mroi.stimulusfunctions.point',{},obj.defaultStimDuration/1000,...
                        1,[0 0],[obj.defaultRoiWidth obj.defaultRoiHeight]/2,obj.defaultRoiRotation,obj.defaultStimPower);
                    obj.slmPatternRoiParent.add(0,obj.slmPatternSfParent);
                else
                    obj.slmPatternRoiParent = group;
                    obj.slmPatternSfParent = group.scanfields(1);
                end
            end
            
            if isempty(scannerset)
                obj.scannerSet = scanimage.mroi.scannerset.GalvoGalvo.default;
            else
                obj.scannerSet = scannerset;
            end
            
            most.idioms.safeDeleteObj(obj.hSlmListener);
            
            if obj.editorModeIsSlm
                obj.hSlmListener = most.util.DelayedEventListener(0.5,obj.slmPatternRoiParent,'changed',@(varargin)obj.slmPropsPanelUpdate);
                
                obj.slmPatternType = [];
                
                obj.slmPropsPanelUpdate();
            else
                obj.editingGroup = group;
            end
            
            if ~obj.isGuiLoaded
                return;
            end
            obj.changeSelection();
            obj.updateTable();
            obj.updateDisplay();
        end
        
        function saveGroup(obj,varargin)
            [filename,pathname] = uiputfile('.roi','Choose filename to save ROI group to',obj.getClassDataVar('lastFile'));
            if filename==0;return;end
            filename = fullfile(pathname,filename);
            obj.setClassDataVar('lastFile',filename);
            
            try
                obj.hFig.Pointer = 'watch';
                drawnow();
                obj.editingGroup.saveToFile(filename);
                obj.hFig.Pointer = 'arrow';
            catch ME
                obj.hFig.Pointer = 'arrow';
                ME.rethrow;
            end
        end
        
        function loadGroup(obj,varargin)
            [filename,pathname] = uigetfile('.roi','Choose file to load ROI group from',obj.getClassDataVar('lastFile'));
            if filename==0;return;end
            filename = fullfile(pathname,filename);
            obj.setClassDataVar('lastFile',filename);
            
            try
                obj.hFig.Pointer = 'watch';
                drawnow();
                
                roigroup = scanimage.mroi.RoiGroup.loadFromFile(filename);
                assert(~isempty(roigroup.rois) && ~isempty(roigroup.rois(1).scanfields), 'Selected ROI group is empty');
                
                switch class(roigroup.rois(1).scanfields)
                    case 'scanimage.mroi.scanfield.fields.RotatedRectangle'
                        t = 'imaging';
                    case 'scanimage.mroi.scanfield.fields.StimulusField'
                        t = 'stimulation';
                    case 'scanimage.mroi.scanfield.fields.IntegrationField'
                        t = 'analysis';
                    otherwise
                        error('Unrecognized ROI type.');
                end
                
                if obj.editorModeIsImaging || obj.editorModeIsStim
                    assert(strcmp(t,obj.editorMode), 'Only %s ROIs can be imported into this ROI group. Selected file contains %s ROIs.',obj.editorMode,t);
                else
                    if strcmp(t,'imaging')
                        roigroup = obj.convertImagingToIntegrationRois(roigroup);
                    else
                        assert(strcmp(t,obj.editorMode), 'Only imaging or stimulation ROIs can be imported into this ROI group. Selected file contains %s ROIs.',t);
                    end
                end
                
                obj.enableListeners = false;
                obj.editingGroup.copyobj(roigroup);
                obj.enableListeners = true;
                delete(roigroup);
                obj.rgChangedPar();
                obj.setZProjectionLimits();
                obj.hFig.Pointer = 'arrow';
            catch ME
                obj.hFig.Pointer = 'arrow';
                warndlg(sprintf('Failed to import ROIs. %s', ME.message),'ROI Group Import');
                ME.rethrow;
            end
        end
        
        function clearGroup(obj,varargin)
            obj.enableListeners = false;
            obj.editingGroup.clear();
            obj.enableListeners = true;
            obj.rgChangedPar();
        end
        
        function copyImagingRois(obj,varargin)
            try
                roigroup = obj.hModel.hRoiManager.currentRoiGroup;
                assert(~isempty(roigroup.rois) && ~isempty(roigroup.rois(1).scanfields), 'Imaging ROI group is empty');
                assert(isa(roigroup.rois(1).scanfields(1), 'scanimage.mroi.scanfield.fields.RotatedRectangle'),...
                    'Only imaging ROIs can be imported for analysis.');
                
                roigroup = obj.convertImagingToIntegrationRois(roigroup);
                
                obj.enableListeners = false;
                obj.editingGroup.copyobj(roigroup);
                obj.enableListeners = true;
                delete(roigroup);
                
                obj.rgChangedPar();
                obj.setZProjectionLimits();
            catch ME
                warndlg(sprintf('Failed to import ROIs. %s', ME.message),'ROI Group Import');
                ME.rethrow;
            end
        end
        
        function newRg = convertImagingToIntegrationRois(obj,imRg)
            newRg = scanimage.mroi.RoiGroup;
            for i = 1:numel(imRg.rois)
                roi = imRg.rois(i);
                N = numel(roi.scanfields);
                if N
                    newRoi = scanimage.mroi.Roi;
                    
                    for j = 1:N
                        newSf = scanimage.mroi.scanfield.fields.IntegrationField();
                        
                        newSf.centerXY = roi.scanfields(j).centerXY;
                        newSf.sizeXY = roi.scanfields(j).sizeXY;
                        newSf.rotationDegrees = roi.scanfields(j).rotationDegrees;
                        newSf.threshold = obj.defaultAnalysisRoiThreshold;
                        newSf.channel = obj.defaultAnalysisRoiChannel;
                        newSf.processor = obj.defaultAnalysisRoiProcessor;
                        
                        newRoi.add(roi.zs(j), newSf);
                    end
                    
                    newRg.add(newRoi);
                end
            end
        end
        
        function resetContextImages(obj)
            delete(obj.hContextImages);
            obj.hContextImages = scanimage.guis.roigroupeditor.LiveContextImage(obj);
            obj.rebuildLegend();
            obj.scrollLegendToBottom();
        end
        
        function optimizePath(obj)
            if obj.editorModeIsStim && numNonPause(obj.editingGroup) > 0
                obj.enableListeners = false;
                
                try
                    % ensure uniform sample rate for all scanners
                    sampleRate = obj.scannerSet.scanners{1}.sampleRateHz;
                    obj.scannerSet.scanners{2}.sampleRateHz = sampleRate;
                    if obj.scannerSet.hasBeams
                        obj.scannerSet.beams(1).sampleRateHz = sampleRate;
                    end
                    if obj.scannerSet.hasFastZ
                        obj.scannerSet.fastz(1).sampleRateHz = sampleRate;
                    end
                    minDur = 10/sampleRate;
                    
                    % remove empty rois
                    emptyRois = arrayfun(@(r)~numel(r.scanfields),obj.editingGroup.rois);
                    emptyRois = [obj.editingGroup.rois(emptyRois).uuiduint64];
                    arrayfun(@(id)obj.editingGroup.removeById(id), emptyRois, 'UniformOutput', false);
                    
                    if obj.optimizeScanOrder && numNonPause(obj.editingGroup) > 1
                    end
                    
                    if obj.optimizeStimuli
                        % find where the stimuli are
                        isStim = arrayfun(@(x)~x.scanfields(1).isPause && ~x.scanfields(1).isPoint && ~x.scanfields(1).isPark,obj.editingGroup.rois);
                        stimIds = find(isStim);
                        
                        for id = stimIds
                            sf = obj.editingGroup.rois(id).scanfields(1);
                            [stimPts,~] = obj.scannerSet.scanPathStimulusFOV(sf,0,0,obj.editingGroup.rois(id).zs(1),0,true,false);
                            if isfield(stimPts,'Z')
                                P = [stimPts.G stimPts.Z];
                            else
                                P = [stimPts.G zeros(size(stimPts.G,1),1)];
                            end
                            
                            V = (P(2:end,:) - P(1:end-1,:)) * sampleRate;
                            A = (V(2:end,:) - V(1:end-1,:)) * sampleRate;
                            
                            Vm = max(abs(V),[],1);
                            Vscl = min([obj.xyMaxVel obj.xyMaxVel obj.zMaxVel] ./ Vm);
                            
                            Am = max(abs(A),[],1);
                            Ascl = min([obj.xyMaxAccel obj.xyMaxAccel obj.zMaxAccel] ./ Am)^.5;
                            
                            scl = min([Vscl Ascl]);
                            t = obj.editingGroup.rois(id).scanfields(1).duration;
                            obj.editingGroup.rois(id).scanfields(1).duration = max(minDur, t / scl);
                        end
                    end
                    
                    if obj.optimizeTransitions
                        % ensure there is one and only one pause between rois
                        i = 1;
                        N = numel(obj.editingGroup.rois);
                        while i <= N
                            previ = mod(i-2,N)+1;
                            if obj.editingGroup.rois(i).scanfields.isPause || obj.editingGroup.rois(i).scanfields.isPark
                                if obj.editingGroup.rois(previ).scanfields.isPause
                                    %previous was a pause. remove it
                                    obj.editingGroup.removeById(previ);
                                    if previ < i
                                        i = i-1;
                                    end
                                end
                            else
                                previ = mod(i-2,N)+1;
                                if ~obj.editingGroup.rois(previ).scanfields.isPause
                                    obj.quickAddPause(i-1,true);
                                    i = i+1;
                                end
                            end
                            
                            i = i+1;
                            N = numel(obj.editingGroup.rois);
                        end
                        
                        % find where the transitions and parks are
                        isTrans = arrayfun(@(x)x.scanfields(1).isPause,obj.editingGroup.rois);
                        transIds = find(isTrans);
                        
                        isParks = arrayfun(@(x)x.scanfields(1).isPark,obj.editingGroup.rois);
                        parkIds = find(isParks);
                        
                        % get the points for the stims between transistions
                        for id = setdiff(1:numel(obj.editingGroup.rois),transIds)
                            roi = obj.editingGroup.rois(id);
                            sf = roi.scanfields(1);
                            isWayP(id) = sf.isWayPoint;
                            if isWayP(id)
                                paths{id} = [sf.centerXY obj.editingGroup.rois(id).zs(1)];
                            elseif sf.isPark
                                paths{id} = inf;
                            else
                                [stimPts,~] = obj.scannerSet.scanPathStimulusFOV(sf,0,roi.zs,roi.zs,0,true,false);
                                if isfield(stimPts,'Z')
                                    paths{id} = [stimPts.G stimPts.Z];
                                else
                                    paths{id} = [stimPts.G zeros(size(stimPts.G,1),1)];
                                end
                            end
                        end
                        
                        % optimize each transition
                        % start with simple average velocity solution
                        bth = [transIds parkIds];
                        for i = 1:numel(bth)
                            id = bth(i);
                            
                            % figure out start and end position
                            previ = mod(id-2,N)+1;
                            if paths{previ}(1) == inf
                                strtP = [obj.scannerSet.mirrorsActiveParkPosition() 0];
                                wayPt = 0;
                            else
                                strtP = paths{previ}(end,:);
                                
                                if isWayP(previ)
                                    % half of the waypoint time belongs to this transision
                                    wayPt = obj.editingGroup.rois(previ).scanfields(1).duration / 2;
                                else
                                    wayPt = 0;
                                end
                            end
                            
                            if ismember(id,parkIds)
                                endP = [obj.scannerSet.mirrorsActiveParkPosition() 0];
                            else
                                nxti = mod(id,N)+1;
                                endP = paths{nxti}(1,:);
                                if isWayP(nxti)
                                    % half of the waypoint time belongs to this transision
                                    wayPt = wayPt + obj.editingGroup.rois(nxti).scanfields(1).duration / 2;
                                end
                            end
                            
                            % optimize by average velocity
                            dist = abs(endP - strtP);
                            t = dist ./ [obj.xyMaxVel obj.xyMaxVel obj.zMaxVel];
                            obj.editingGroup.rois(id).scanfields(1).duration = max(minDur, max(t) - wayPt);
                        end
                        
                        % generate the AO and check acceleration limits.
                        % Iterate this process N times
                        N = 4;
                        for it = 1:N
                            [pth,~,~] = obj.editingGroup.scanStackFOV(obj.scannerSet,0,0,'',0,[],[],[]);
                            if ~isfield(pth,'Z')
                                pth.Z = zeros(size(pth.G,1),1);
                            end
                            
                            j = 1;
                            p1 = [pth.G(end,:) pth.Z(end)];
                            v1 = (p1 - [pth.G(end-1,:) pth.Z(end-1)]) * sampleRate;
                            for i = 1:numel(obj.editingGroup.rois)
                                if ~isempty(obj.editingGroup.rois(i).scanfields)
                                    T = obj.scannerSet.scanTime(obj.editingGroup.rois(i).scanfields(1));
                                    jdur = obj.scannerSet.nsamples(obj.scannerSet.scanners{1},T);
                                    je = j+jdur-1;
                                    
                                    if ismember(i,bth)
                                        if i == numel(obj.editingGroup.rois)
                                            p2 = [pth.G(1,:) pth.Z(1)];
                                            v2 = ([pth.G(2,:) pth.Z(2)] - p2) * sampleRate;
                                        else
                                            p2 = [pth.G(je+1,:) pth.Z(je+1)];
                                            v2 = ([pth.G(je+2,:) pth.Z(je+2)] - p2) * sampleRate;
                                        end
                                        
                                        t = [scanimage.mroi.util.revMAA(p1(1), v1(1), p2(1), v2(1), obj.xyMaxVel, obj.xyMaxAccel);...
                                            scanimage.mroi.util.revMAA(p1(2), v1(2), p2(2), v2(2), obj.xyMaxVel, obj.xyMaxAccel);...
                                            scanimage.mroi.util.revMAA(p1(3), v1(3), p2(3), v2(3), obj.zMaxVel, obj.zMaxAccel)];
                                        
                                        obj.editingGroup.rois(i).scanfields(1).duration = max(minDur, max(t));
                                    else
                                        p1 = [pth.G(je,:) pth.Z(je)];
                                        v1 = (p1 - [pth.G(je-1,:) pth.Z(je-1)]) * sampleRate;
                                    end
                                    
                                    j = je+1;
                                end
                            end
                        end
                    end
                    
                    obj.enableListeners = true;
                    obj.updateScanPathCache();
                    obj.rgChanged();
                catch ME
                    obj.enableListeners = true;
                    obj.updateScanPathCache();
                    obj.rgChanged();
                    ME.rethrow();
                end
            end
        end
    end
    
    %% Internal methods
    methods (Hidden)
        function roiTableCB(obj,~,evt)
            diff = cellfun(@cmp,obj.tblData,obj.roiTable.Data);
            
            [j,i] = ind2sub(size(diff),find(~diff,1));
            reset = true;
            
            if ~isempty(i)
                if i == 1
                    % selection column. clear other selections and select this one
                    obj.tblData(:,1) = {false};
                    obj.tblData{j,1} = true;
                    obj.roiTable.Data = obj.tblData;
                    
                    parObj = obj.tblMapping{j,2};
                    if isnumeric(parObj)
                        parObj = obj.tblMapping{parObj,1};
                    end
                    obj.changeSelection(obj.tblMapping{j,1},parObj);
                    reset = false;
                elseif obj.editorModeIsSlm
                    switch i
                        case 3
                            % X column
                            if ~isnan(evt.NewData)
                                obj.enableListeners = false;
                                obj.editingGroup.rois(j).scanfields.centerXY(1) = evt.NewData / obj.xyUnitFactor;
                                obj.enableListeners = true;
                                obj.updateTable();
                                obj.updateScanPathCache();
                                obj.updateDisplay();
                                obj.updateSlmPattern();
                                reset = false;
                            end
                            
                        case 4
                            % Y column
                            if ~isnan(evt.NewData)
                                obj.enableListeners = false;
                                obj.editingGroup.rois(j).scanfields.centerXY(2) = evt.NewData / obj.xyUnitFactor;
                                obj.enableListeners = true;
                                obj.updateTable();
                                obj.updateScanPathCache();
                                obj.updateDisplay();
                                obj.updateSlmPattern();
                                reset = false;
                            end
                            
                        case 5
                            % Z column
                            if ~isnan(evt.NewData)
                                obj.enableListeners = false;
                                obj.editingGroup.rois(j).moveSfById(1,evt.NewData);
                                obj.enableListeners = true;
                                obj.updateTable();
                                obj.updateScanPathCache();
                                obj.updateDisplay();
                                obj.updateSlmPattern();
                                reset = false;
                            end
                            
                        case 6
                            % Wt column
                            if ~isnan(evt.NewData)
                                obj.enableListeners = false;
                                obj.editingGroup.rois(j).scanfields.powers = evt.NewData;
                                obj.enableListeners = true;
                                obj.updateTable();
                                obj.updateScanPathCache();
                                obj.updateDisplay();
                                obj.updateSlmPattern();
                                reset = false;
                            end
                    end
                elseif obj.editorModeIsStim
                    switch i
                        case 4
                            % duration
                            d = str2double(evt.NewData);
                            if ~isnan(d)
                                obj.enableListeners = false;
                                obj.editingGroup.rois(j).scanfields.duration = d/1000;
                                obj.enableListeners = true;
                                obj.updateTable();
                                obj.updateScanPathCache();
                                obj.updateDisplay();
                                obj.selectedObjChanged();
                                reset = false;
                            end
                            
                        case 5
                            % reps
                            if ~isnan(evt.NewData)
                                obj.enableListeners = false;
                                obj.editingGroup.rois(j).scanfields.repetitions = evt.NewData;
                                obj.enableListeners = true;
                                obj.updateTable();
                                obj.updateScanPathCache();
                                obj.updateDisplay();
                                obj.selectedObjChanged();
                                reset = false;
                            end
                            
                        case 6
                            % power
                            if ~isnan(evt.NewData)
                                if ischar(evt.NewData)
                                    newPowers = str2num(evt.NewData);
                                else
                                    newPowers = evt.NewData;
                                end
                                obj.enableListeners = false;
                                obj.editingGroup.rois(j).scanfields.powers = newPowers;
                                obj.enableListeners = true;
                                obj.updateTable();
                                obj.updateScanPathCache();
                                obj.updateDisplay();
                                obj.selectedObjChanged();
                                reset = false;
                            end
                            
                        case 7
                            % z
                            if ~isnan(evt.NewData)
                                obj.enableListeners = false;
                                obj.editingGroup.rois(j).moveSfById(1,evt.NewData);
                                obj.enableListeners = true;
                                obj.updateTable();
                                obj.updateScanPathCache();
                                obj.updateDisplay();
                                obj.selectedObjChanged();
                                reset = false;
                            end
                    end
                else % editor mode is imaging
                    switch i
                        case 5
                            % enable column
                            
                        case 6
                            % display column
                            
                        case 7
                            % z column
                            areZsValid = all(~isnan(evt.NewData));
                            if areZsValid && isa(obj.tblMapping{j,1},'scanimage.mroi.scanfield.ScanField')
                                roiIdx = obj.tblMapping{j,2};
                                roi = obj.tblMapping{roiIdx,1};
                                sf = obj.tblMapping{j,1};
                                sfIdx = find(sf == roi.scanfields);
                                
                                obj.enableListeners = false;
                                roi.moveSfById(sfIdx,evt.NewData);
                                obj.enableListeners = true;
                                obj.updateTable();
                                obj.updateScanPathCache();
                                obj.updateDisplay();
                                reset = false;
                            end
                    end
                end
            end
            
            if reset
                obj.roiTable.Data = obj.tblData;
            end
            
            function e = cmp(a,b)
                e = strcmp(class(a),class(b));
                if e
                    if ischar(a)
                        e = strcmp(a,b);
                    else
                        e = (isempty(a) && (numel(a) == numel(b))) || a == b;
                    end
                end
            end
        end
        
        function updateTable(obj)
            %get the current selection and reapply it
            newSel = 0;
            
            obj.tblData = {};
            obj.tblMapping = {};
            if most.idioms.isValidObj(obj.editingGroup)
                idx = 1;
                for i = 1:numel(obj.editingGroup.rois)
                    if obj.selectedObj == obj.editingGroup.rois(i)
                        newSel = idx;
                    end
                    
                    obj.tblData{idx,1} = newSel == idx;
                    obj.tblMapping{idx,1} = obj.editingGroup.rois(i);
                    obj.tblMapping{idx,2} = idx;
                    obj.tblMapping{idx,3} = obj.editingGroup.rois(i).uuiduint64;
                    
                    if obj.editorModeIsSlm
                        if ~isempty(obj.editingGroup.rois(i).scanfields)
                            sf = obj.editingGroup.rois(i).scanfields(1);
                            
                            if obj.selectedObj == sf
                                obj.tblData{idx,1} = true;
                                newSel = idx;
                            end
                            
                            obj.tblData{idx,2} = idx;
                            obj.tblData{idx,3} = sf.centerXY(1) * obj.xyUnitFactor;
                            obj.tblData{idx,4} = sf.centerXY(2) * obj.xyUnitFactor;
                            obj.tblData{idx,5} = obj.editingGroup.rois(i).zs(1);
                            obj.tblData{idx,6} = sf.powers(1);
                        end
                        idx = idx+1;
                    else
                        obj.tblData{idx,2} = i;
                        tlIdx = idx;
                        
                        if obj.editorModeIsStim
                            if ~isempty(obj.editingGroup.rois(i).scanfields)
                                sf = obj.editingGroup.rois(i).scanfields(1);
                                
                                if obj.selectedObj == sf
                                    obj.tblData{idx,1} = true;
                                    newSel = idx;
                                end
                                
                                if ~isempty(sf.slmPattern)
                                    obj.tblData{idx,3} = 'SLM Pattern';
                                    stimfcnname = regexpi(func2str(sf.stimfcnhdl),'[^\.]*$','match');
                                    if ~strcmp(stimfcnname{1},'point')
                                        obj.tblData{idx,3} = [obj.tblData{idx,3} ' + ' stimfcnname{1}];
                                    end
                                else
                                    obj.tblData{idx,3} = sf.shortDescription(7:end);
                                end
                                obj.tblData{idx,4} = sprintf('%.3f',obj.scannerSet.scanTime(sf)*1000);
                                obj.tblData{idx,5} = sf.repetitions;
                                obj.tblData{idx,6} = num2str(sf.powers);
                                obj.tblData{idx,7} = obj.editingGroup.rois(i).zs(1);
                                obj.tblMapping{idx,2} = sf;
                            end
                            idx = idx+1;
                        elseif strcmp(obj.editorMode, 'analysis')
                            if ~isempty(obj.editingGroup.rois(i).scanfields)
                                zs = obj.editingGroup.rois(i).zs;
                                sf = obj.editingGroup.rois(i).scanfields(1);
                                
                                obj.tblData{idx,3} = 'Integration';
                                obj.tblData{idx,4} = sf.channel;
                                obj.tblData{idx,5} = sf.threshold;
                                obj.tblData{idx,6} = upper(sf.processor);
                                obj.tblData{idx,7} = ['[' num2str(min(zs)) '  ' num2str(max(zs)) ']'];
                                tlIdx = idx;
                                
                                for j = 1:numel(zs)
                                    z = zs(j);
                                    sf = obj.editingGroup.rois(i).get(z);
                                    idx = idx+1;
                                    
                                    if obj.selectedObj == sf
                                        newSel = idx;
                                    end
                                    
                                    obj.tblData{idx,1} = newSel == idx;
                                    obj.tblData{idx,2} = '';
                                    obj.tblData{idx,3} = '     Integration Plane';
                                    obj.tblData{idx,4} = '';
                                    obj.tblData{idx,5} = '';
                                    obj.tblData{idx,6} = '';
                                    obj.tblData{idx,7} = z;
                                    obj.tblMapping{idx,1} = sf;
                                    obj.tblMapping{idx,2} = tlIdx;
                                    obj.tblMapping{idx,3} = sf.uuiduint64;
                                end
                            else
                                obj.tblData{idx,3} = '';
                                obj.tblData{idx,4} = '';
                                obj.tblData{idx,5} = '';
                                obj.tblData{idx,6} = '';
                                obj.tblData{idx,7} = '';
                            end
                            idx = idx+1;
                        else
                            obj.tblData{idx,3} = obj.editingGroup.rois(i).name;
                            
                            obj.tblData{idx,5} = obj.tfMap(obj.editingGroup.rois(i).enable);
                            obj.tblData{idx,6} = obj.tfMap(obj.editingGroup.rois(i).display);
                            
                            zs = obj.editingGroup.rois(i).zs;
                            
                            if obj.editingGroup.rois(i).discretePlaneMode || (numel(zs) > 1)
                                obj.tblData{idx,7} = ['[' num2str(min(zs)) '  ' num2str(max(zs)) ']'];
                            else
                                obj.tblData{idx,7} = '[-inf  inf]';
                            end
                            idx = idx+1;
                            
                            maxt = 0;
                            for j = 1:numel(zs)
                                z = zs(j);
                                sf = obj.editingGroup.rois(i).get(z);
                                tim = obj.scannerSet.scanTime(sf)*1000;
                                
                                if obj.selectedObj == sf
                                    newSel = idx;
                                end
                                
                                if ~isempty(sf)
                                    obj.tblData{idx,1} = newSel == idx;
                                    obj.tblData{idx,2} = '';
                                    obj.tblData{idx,3} = ['     ' sf.shortDescription];
                                    obj.tblData{idx,4} = sprintf('%.3f',tim);
                                    obj.tblData{idx,5} = '';
                                    obj.tblData{idx,6} = '';
                                    obj.tblData{idx,7} = z;
                                    obj.tblMapping{idx,1} = sf;
                                    obj.tblMapping{idx,2} = tlIdx;
                                    obj.tblMapping{idx,3} = sf.uuiduint64;
                                else
                                    obj.tblData{idx,1} = false;
                                    obj.tblData{idx,2} = '';
                                    obj.tblData{idx,3} = '';
                                    obj.tblData{idx,4} = '';
                                    obj.tblData{idx,5} = '';
                                    obj.tblData{idx,6} = '';
                                    obj.tblData{idx,7} = '';
                                    obj.tblMapping{idx,1} = [];
                                    obj.tblMapping{idx,2} = tlIdx;
                                    obj.tblMapping{idx,3} = [];
                                end
                                idx = idx+1;
                                
                                maxt = max(maxt,tim);
                            end
                            
                            obj.tblData{tlIdx,4} = sprintf('%.3f',maxt);
                        end
                    end
                end
            end
            obj.roiTable.Data = obj.tblData;
            
            if ~obj.createMode && newSel < 1
                obj.changeSelection();
            end
        end
        
        function fixTableCheck(obj)
            if numel(obj.tblData)
                tf = false;
                
                if most.idioms.isValidObj(obj.selectedObj)
                    [tf, idx] = ismember(obj.selectedObj.uuiduint64, [obj.tblMapping{:,3}]);
                end
                
                if ~tf && most.idioms.isValidObj(obj.selectedObjParent)
                    [tf, idx] = ismember(obj.selectedObjParent.uuiduint64, [obj.tblMapping{:,3}]);
                end
                
                obj.tblData(:,1) = {false};
                if tf
                    obj.tblData{idx,1} = true;
                    
                    %make sure it is in sight
                    tlIdx = obj.tblMapping{idx,2};
                    if tlIdx < obj.roiTable.firstRowIdx
                        obj.roiTable.firstRowIdx = max(1,tlIdx-1);
                    elseif tlIdx >= obj.roiTable.firstRowIdx + obj.roiTable.numVisibleRows
                        obj.roiTable.firstRowIdx = min(obj.roiTable.maxTopRow, tlIdx+numel(obj.tblMapping{tlIdx,1}.zs)+1-obj.roiTable.numVisibleRows);
                    end
                end
                obj.roiTable.Data = obj.tblData;
            end
        end
        
        function remTableRoi(obj, id)
            [tf, tlIdx] = ismember(id, [obj.tblMapping{:,3}]);
            
            if tf
                obj.tblMapping(tlIdx,:) = [];
                obj.tblData(tlIdx,:) = [];
                
                if ~(obj.editorModeIsStim || obj.editorModeIsSlm)
                    linesRemoved = 1;
                    i = tlIdx;
                    while i <= size(obj.tblMapping,1)
                        if obj.tblMapping{i,2} == tlIdx
                            obj.tblMapping(i,:) = [];
                            obj.tblData(i,:) = [];
                            linesRemoved = linesRemoved + 1;
                        else
                            obj.tblMapping{i,2} = obj.tblMapping{i,2} - linesRemoved;
                            i = i+1;
                        end
                    end
                end
                
                obj.roiTable.Data = obj.tblData;
            end
        end
        
        function remTableSf(obj, id)
            [tf, sfIdx] = ismember(id, [obj.tblMapping{:,3}]);
            
            if tf
                obj.tblMapping(sfIdx,:) = [];
                obj.tblData(sfIdx,:) = [];
                
                for i = sfIdx:size(obj.tblMapping,1)
                    if obj.tblMapping{i,2} > sfIdx
                        obj.tblMapping{i,2} = obj.tblMapping{i,2} - 1;
                    end
                end
                
                obj.roiTable.Data = obj.tblData;
            end
        end
        
        function updateDisplay(obj,rois)
            persistent inProg
            persistent req
            
            if ~obj.isGuiLoaded
                return;
            end
            
            if nargin < 2
                rois = inf;
            end
            
            if isempty(inProg) || ~inProg
                req = rois;
                
                while ~isempty(req)
                    inProg = true;
                    arg = req;
                    req = [];
                    
                    try
                        if isempty(obj.scanPathCache)
                            obj.refreshScanPath();
                        end
                        
                        if strcmp(obj.viewMode, '3D')
                            obj.draw3D(arg);
                        else
                            obj.draw2D(arg);
                        end
                        inProg = false;
                    catch ME
                        inProg = false;
                        ME.rethrow;
                    end
                end
            else
                req = [req rois];
            end
        end
        
        function updateScanPathCache(obj,roiIdx)
            if nargin < 2 || isempty(roiIdx) || ~obj.editorModeIsStim
                obj.scanPathCache = [];
                obj.scanPathCacheIds = [];
            elseif isa(obj.scannerSet,'scanimage.mroi.scannerset.SLM')
                % no op; slm patterns cant move
            else
                % selective update of one roi
                if ~isempty(obj.editingGroup.rois(roiIdx).scanfields) && ~obj.editingGroup.rois(roiIdx).scanfields(1).isPause
                    sf = obj.editingGroup.rois(roiIdx).scanfields(1);
                    ptIds = obj.scanPathCacheIds(roiIdx,:);
                    N = ptIds(2)-ptIds(1)+1;
                    
                    [stimPts,~] = obj.scannerSet.scanPathStimulusFOV(sf,0,obj.editingGroup.rois(roiIdx).zs(1),0,true,false,N);
                    
                    if size(stimPts.G,1) ~= N
                        datInds = floor(linspace(1,size(stimPts.G,1),N));
                        stimPts.G = stimPts.G(datInds,:);
                    end
                    
                    if isfield(stimPts,'Z')
                        if size(stimPts.Z,1) ~= N
                            datInds = floor(linspace(1,size(stimPts.Z,1),N));
                            stimPts.Z = stimPts.Z(datInds,:);
                        end
                    else
                        stimPts.Z = zeros(N,1);
                    end
                    
                    obj.scanPathCache.G(ptIds(1):ptIds(2),:) = stimPts.G;
                    obj.scanPathCache.Z(ptIds(1):ptIds(2),:) = stimPts.Z;
                    
                    % if prev or next are pauses, reinterpolate them
                    prev = roiIdx - 1;
                    nxt = roiIdx + 1;
                    
                    numRoi = numel(obj.editingGroup.rois);
                    prev = prev + numRoi*(prev < 1);
                    nxt = nxt - numRoi*(nxt > numRoi);
                    
                    pausenan(prev);
                    pausenan(nxt);
                    
                    obj.scanPathCache = obj.scannerSet.interpolateTransits(obj.scanPathCache,false);
                end
            end
            
            function pausenan(idx)
                if ~isempty(obj.editingGroup.rois(idx).scanfields) && obj.editingGroup.rois(idx).scanfields(1).isPause
                    ptIdxs = obj.scanPathCacheIds(idx,:);
                    obj.scanPathCache.G(ptIdxs(1):ptIdxs(2),:) = nan;
                    obj.scanPathCache.Z(ptIdxs(1):ptIdxs(2),:) = nan;
                end
            end
        end
        
        function refreshScanPath(obj)
            if (obj.editorModeIsStim || obj.editorModeIsSlm) && numNonPause(obj.editingGroup) > 0
                if isa(obj.scannerSet,'scanimage.mroi.scannerset.GalvoGalvo')
                    % ensure uniform sample rate for all scanners
                    sampleRate = obj.scannerSet.scanners{1}.sampleRateHz;
                    obj.scannerSet.scanners{2}.sampleRateHz = sampleRate;
                    if obj.scannerSet.hasBeams
                        obj.scannerSet.beams(1).sampleRateHz = sampleRate;
                    end
                    if obj.scannerSet.hasFastZ
                        obj.scannerSet.fastz(1).sampleRateHz = sampleRate;
                    end
                    
                    %determine best limit for stim function length to optimize gui speed
                    maxp = ceil(10000/numel(obj.editingGroup.rois));
                    maxp = max(100,min(maxp,obj.stimpathRenderMaxPoints));
                    
                    % get scan path
                    [obj.scanPathCache,~,~] = obj.editingGroup.scanStackFOV(obj.scannerSet,0,0,'',0,[],[],[],maxp,~obj.editorModeIsSlm);
                    N = size(obj.scanPathCache.G,1);
                    
                    % ensure presence of 'Z' data
                    if ~isfield(obj.scanPathCache,'Z')
                        obj.scanPathCache.Z = zeros(N,1);
                    else
                        Z = obj.scanPathCache.Z(:);
                        Z = scanimage.mroi.coordinates.Points(obj.scannerSet.hCSReference,[zeros(numel(Z),2) obj.scanPathCache.Z(:)]);
                        Z = Z.transform(obj.scannerSet.hCSSampleRelative);
                        Z = reshape(Z.points(:,3),size(obj.scanPathCache.Z));
                        obj.scanPathCache.Z = Z;
                    end
                    
                    %compute the start and end indices for each roi
                    Nr = numel(obj.editingGroup.rois);
                    obj.scanPathCacheIds = ones(Nr,2);
                    j = 1;
                    for i = 1:Nr
                        if ~isempty(obj.editingGroup.rois(i).scanfields)
                            T = obj.scannerSet.scanTime(obj.editingGroup.rois(i).scanfields(1),true);
                            jdur = min(maxp,obj.scannerSet.nsamples(obj.scannerSet.scanners{1},T));
                            obj.scanPathCacheIds(i,:) = [j max(j,j+jdur-1)];
                            j = j+jdur;
                        end
                    end
                    obj.scanPathCacheIds(end,end) = N;
                    obj.scanPathCacheIds = min(N,max(1,floor(obj.scanPathCacheIds)));
                else
                    % for SLM just show points
                    obj.scanPathCache = struct('G',{[]},'Z',{[]});
                    obj.scanPathCacheIds = [];
                    
                    Nr = numel(obj.editingGroup.rois);
                    for i = 1:numel(obj.editingGroup.rois)
                        if isempty(obj.editingGroup.rois(i).scanfields)
                            obj.scanPathCache.G(end+1,:) = nan(1,2);
                            obj.scanPathCache.Z(end+1,:) = nan;
                        else
                            obj.scanPathCache.G(end+1,:) = obj.editingGroup.rois(i).scanfields(1).centerXY;
                            obj.scanPathCache.Z(end+1,:) = obj.editingGroup.rois(i).zs;
                        end
                        obj.scanPathCacheIds(end+1,:) = [i i];
                    end
                end
            else
                obj.updateScanPathCache();
            end
        end
        
        function [path, waypath] = getStimPts(obj,i,sf)
            if sf.isPoint
                idx = floor(mean(obj.scanPathCacheIds(i,:)));
                path.G = obj.scanPathCache.G(idx,:);
                path.Z = obj.scanPathCache.Z(idx,:);
            else
                path.G = obj.scanPathCache.G(obj.scanPathCacheIds(i,1):obj.scanPathCacheIds(i,2),:);
                path.Z = obj.scanPathCache.Z(obj.scanPathCacheIds(i,1):obj.scanPathCacheIds(i,2),:);
            end
            
            if sf.isWayPoint
                waypath.G = obj.scanPathCache.G(obj.scanPathCacheIds(i,1):obj.scanPathCacheIds(i,2),:);
                waypath.Z = obj.scanPathCache.Z(obj.scanPathCacheIds(i,1):obj.scanPathCacheIds(i,2),:);
            else
                waypath = [];
            end
        end
        
        function remDrawnRoi(obj, id)
            objs = obj.drawData{id};
            obj.drawData(id) = [];
            cellfun(@delete,objs);
            if isempty(obj.drawData)
                obj.drawData = {{}};
            end
            
            if ~isempty(obj.drawDataProj{1})
                objs = obj.drawDataProj{id};
                obj.drawDataProj(id) = [];
                cellfun(@delete,objs);
                if isempty(obj.drawDataProj)
                    obj.drawDataProj = {{}};
                end
            end
        end
        
        function changeSelection(obj, selObj, selObjParent)
            obj.createMode = false;
            most.idioms.safeDeleteObj(obj.hSelObjListener);
            set(obj.hPropsPanels, 'Visible', 'off');
            
            if (nargin > 1) && most.idioms.isValidObj(selObj)
                obj.selectedObj = selObj;
                obj.selectedObjParent = selObjParent;
                obj.hSelObjListener = [most.util.DelayedEventListener(0.5,selObj,'changed',@(varargin)obj.selectedObjChanged())...
                    most.util.DelayedEventListener(0.5,selObj,'ObjectBeingDestroyed',@(varargin)obj.changeSelection())];
                
                obj.updateMoveButtons();
                
                switch class(selObj)
                    case 'scanimage.mroi.Roi'
                        switch obj.editorMode
                            case 'imaging'
                                obj.hImagingRoiPropsPanel.Visible = 'on';
                                obj.activePanelUpdateFcn = @obj.roiPropsPanelUpdate;
                                obj.editorZ = obj.editorZ;
                                
                            case {'stimulation' 'slm'}
                                obj.activePanelUpdateFcn = [];
                                if ~isempty(selObj.scanfields)
                                    obj.changeSelection(selObj.scanfields(1), selObj)
                                    obj.fixTableCheck();
                                end
                                
                            case 'analysis'
                                obj.hAnalysisRoiPropsPanel.Visible = 'on';
                                obj.activePanelUpdateFcn = @obj.analysisRoiPropsPanelUpdate;
                                obj.editorZ = obj.editorZ;
                        end
                        
                    case 'scanimage.mroi.scanfield.fields.StimulusField'
                        if obj.editorModeIsStim
                            obj.hStimRoiPropsPanel.Visible = 'on';
                            obj.activePanelUpdateFcn = @obj.stimRoiPropsPanelUpdate;
                        elseif obj.editorModeIsSlm
                            obj.activePanelUpdateFcn = @obj.updateTable;
                        end
                        
                        obj.selectedObjRoiIdx = obj.editingGroup.idToIndex(selObjParent.uuiduint64);
                        
                        if ~selObj.isPause
                            obj.editorZ = selObjParent.zs(1);
                        else
                            obj.editorZ = obj.editorZ;
                        end
                        
                    case 'scanimage.mroi.scanfield.fields.RotatedRectangle'
                        obj.hImagingSfPropsPanel.Visible = 'on';
                        obj.activePanelUpdateFcn = @obj.imagingSfPropsPanelUpdate;
                        obj.selectedObjRoiIdx = obj.editingGroup.idToIndex(selObjParent.uuiduint64);
                        obj.editorZ = selObjParent.zs(selObjParent.scanfields == selObj);
                        
                    case 'scanimage.mroi.scanfield.fields.IntegrationField'
                        obj.hAnalysisSfPropsPanel.Visible = 'on';
                        obj.activePanelUpdateFcn = @obj.analysisSfPropsPanelUpdate;
                        obj.selectedObjRoiIdx = obj.editingGroup.idToIndex(selObjParent.uuiduint64);
                        obj.editorZ = selObjParent.zs(selObjParent.scanfields == selObj);
                end
                
                obj.selectedObjChanged();
                
                obj.pbDel.Enable = 'on';
            else
                obj.selectedObj = [];
                obj.selectedObjParent = [];
                obj.selectedObjRoiIdx = 0;
                obj.activePanelUpdateFcn = [];
                obj.hSelObjListener = [];
                if obj.editorModeIsStim && isa(obj.scannerSet,'scanimage.mroi.scannerset.GalvoGalvo')
                    obj.hStimOptimizationPanel.Visible = 'on';
                elseif obj.editorModeIsImaging
                    obj.hGlobalImagingSfPropsPanel.Visible = 'on';
                    obj.updateGlobalPanel();
                elseif ~obj.editorModeIsSlm
                    obj.hBlankPanel.Visible = 'on';
                end
                obj.pbMoveBottom.Enable = 'off';
                obj.pbMoveDown.Enable = 'off';
                obj.pbMoveUp.Enable = 'off';
                obj.pbMoveTop.Enable = 'off';
                obj.pbDel.Enable = 'off';
                obj.updateDisplay();
            end
        end
        
        function updateMoveButtons(obj)
            if obj.editorModeIsStim
                selObj = obj.selectedObjParent;
            else
                selObj = obj.selectedObj;
            end
            
            if isa(selObj,'scanimage.mroi.Roi')
                obj.selectedObjRoiIdx = obj.editingGroup.idToIndex(selObj.uuiduint64);
                
                if obj.selectedObjRoiIdx > 1
                    obj.pbMoveUp.Enable = 'on';
                    obj.pbMoveTop.Enable = 'on';
                else
                    obj.pbMoveUp.Enable = 'off';
                    obj.pbMoveTop.Enable = 'off';
                end
                
                if obj.selectedObjRoiIdx < numel(obj.editingGroup.rois)
                    obj.pbMoveDown.Enable = 'on';
                    obj.pbMoveBottom.Enable = 'on';
                else
                    obj.pbMoveDown.Enable = 'off';
                    obj.pbMoveBottom.Enable = 'off';
                end
            else
                obj.pbMoveBottom.Enable = 'off';
                obj.pbMoveDown.Enable = 'off';
                obj.pbMoveUp.Enable = 'off';
                obj.pbMoveTop.Enable = 'off';
            end
        end
        
        function scrollWheelFcn(obj, ~, eventData)
            currentKeyModifiers = get(obj.hFig, 'currentModifier');
            isShiftPressed = ismember('shift', currentKeyModifiers);
            scrollCount = eventData.VerticalScrollCount;
            
            if strcmp(obj.viewMode, '3D') && checkIsMouseInAxes(obj.h3DViewMouseFindAxes)
                zoomSpeedFactor = 1.1;
                cameraAngle = obj.h3DViewAxes.CameraViewAngle;
                scroll = zoomSpeedFactor ^ double(scrollCount);
                cameraAngle = cameraAngle * scroll;
                obj.h3DViewAxes.CameraViewAngle = cameraAngle;
                return;
            end
            
            if checkIsMouseInAxes(obj.h2DMainViewAxes)
                if isShiftPressed
                    traverseZ(-scrollCount);
                else
                    originalLocation = getPointerLocation(obj.h2DMainViewAxes);
                    obj.mainViewFov = obj.mainViewFov * 1.5^scrollCount;
                    newLocation = getPointerLocation(obj.h2DMainViewAxes);
                    obj.mainViewPosition = obj.mainViewPosition...
                        + originalLocation - newLocation;
                end
            elseif checkIsMouseInAxes(obj.h2DProjectionViewAxes)
                if isShiftPressed
                    traverseZ(scrollCount * 2);
                else
                    originalLocation = getPointerLocation(obj.h2DProjectionViewAxes);
                    projectionDistance = obj.zProjectionRange(2) - obj.zProjectionRange(1);
                    rangeCenter = sum(obj.zProjectionRange) / 2;
                    newDistance = projectionDistance * 1.5^scrollCount;
                    newZRange = rangeCenter + [-newDistance newDistance] / 2;
                    obj.zProjectionRange = newZRange;
                    newLocation = getPointerLocation(obj.h2DProjectionViewAxes);
                    obj.zProjectionRange = obj.zProjectionRange...
                        + originalLocation(2) - newLocation(2);
                end
            elseif checkIsMouseInAxes(obj.h2DZScrollAxes)
                increment = scrollCount * diff(obj.zProjectionRange) / 10;
                traverseZ(floor(increment * 100) / 100);
            end
            
            function traverseZ(increment)
                newZ = obj.editorZ + increment;
                
                shouldSnap = (increment < 0 && obj.editorZ > obj.minInterestingZ)...
                    || (increment >= 0 && obj.editorZ < obj.maxInterestingZ);
                if ~shouldSnap
                    obj.editorZ = newZ;
                    return;
                end
                
                if increment < 0
                    nextZIdx = find(obj.interestingZs < obj.editorZ, 1, 'last');
                    obj.editorZ = max(obj.interestingZs(nextZIdx), newZ);
                else
                    nextZIdx = find(obj.interestingZs > obj.editorZ, 1, 'first');
                    obj.editorZ = min(obj.interestingZs(nextZIdx), newZ);
                end
            end
            
            function tf = checkIsMouseInAxes(hAx)
                coords = getPointerLocation(hAx);
                Coordinates = struct(...
                    'x', coords(1),...
                    'y', coords(2));
                xlim = hAx.XLim;
                ylim = hAx.YLim;
                isMouseXInAxes = Coordinates.x >= xlim(1) && Coordinates.x <= xlim(2);
                isMouseYInAxes = Coordinates.y >= ylim(1) && Coordinates.y <= ylim(2);
                tf = isMouseXInAxes && isMouseYInAxes;
            end
        end
        
        function zScroll(obj,stop,varargin)
            if nargin > 2
                pt = get(obj.h2DZScrollAxes,'CurrentPoint');
                setZ(pt(1,2));
                set(obj.hFig,...
                    'WindowButtonMotionFcn', @(varargin)obj.zScroll(false),...
                    'WindowButtonUpFcn',@(varargin)obj.zScroll(true));
                waitfor(obj.hFig,'WindowButtonMotionFcn',[]);
                if obj.slmBitmapBrushEnable
                    obj.hFig.WindowButtonMotionFcn = @obj.brushHover;
                end
            elseif stop
                set(obj.hFig, 'WindowButtonMotionFcn', [], 'WindowButtonUpFcn', []);
            else
                pt = get(obj.h2DZScrollAxes,'CurrentPoint');
                setZ(pt(1,2));
            end
            
            function setZ(z)
                % snap to interesting zs
                [dist,i] = min(abs(z-obj.interestingZs));
                if dist < diff(obj.zProjectionRange)/100
                    z = obj.interestingZs(i);
                else
                    z = floor(z*100)/100;
                end
                
                obj.editorZ = z;
            end
        end
        
        function mainPan(obj,stop,varargin)
            persistent ppt;
            persistent pptr;
            persistent mvd;
            
            if nargin > 2
                ppt = getPointerLocation(obj.h2DMainViewAxes);
                
                pptr = obj.hFig.Pointer;
                obj.hFig.Pointer = 'fleur';
                mvd = false;
                
                set(obj.hFig,'WindowButtonMotionFcn',@(varargin)obj.mainPan(false),'WindowButtonUpFcn',@(varargin)obj.mainPan(true));
                waitfor(obj.hFig,'WindowButtonMotionFcn',[]);
                if obj.slmBitmapBrushEnable
                    obj.hFig.WindowButtonMotionFcn = @obj.brushHover;
                end
            elseif stop
                set(obj.hFig,'WindowButtonMotionFcn',[],'WindowButtonUpFcn',[]);
                obj.hFig.Pointer = pptr;
                if ~mvd && ~isempty(obj.selectedObj)
                    % click and release with no drag. deselect
                    obj.changeSelection();
                    obj.fixTableCheck();
                end
            else
                nwpt = getPointerLocation(obj.h2DMainViewAxes);
                obj.mainViewPosition = obj.mainViewPosition - nwpt + ppt;
                mvd = true;
                ppt = getPointerLocation(obj.h2DMainViewAxes);
            end
        end
        
        function mainCreate(obj,stop,varargin)
            persistent oppt;
            persistent ocenterxy;
            persistent centerxy;
            persistent hsz;
            persistent olocks;
            
            if nargin > 2
                oppt = getPointerLocation(obj.h2DMainViewAxes);
                
                if obj.editorModeIsSlm
                    obj.createRoi(oppt,obj.slmPatternSfParent.sizeXY,obj.editorZ,1);
                    obj.roiManip(struct('UserData','move'),[]);
                elseif obj.editorModeIsStim && strcmp(obj.defaultStimFunction, 'point') && obj.scannersetIsSlm
                    obj.selectedObjParent = [];
                    obj.editSlmPattern();
                    obj.slmPatternRoiGroupParent.add(obj.slmPatternRoiParent);
                    
                    obj.newRoi();
                    obj.createRoi(oppt,obj.defaultRoiSize);
                    obj.roiManip(struct('UserData','move'),[]);
                else
                    hsz = [obj.defaultRoiWidth obj.defaultRoiHeight]/2;
                    switch obj.newRoiDrawMode
                        case 'top left rectangle'
                            centerxy = hsz;
                            
                        case 'center point rectangle'
                            centerxy = [0 0];
                            
                        case 'cell picker'
                            return;
                    end
                    
                    handleLen = diff(obj.h2DMainViewAxes.YLim) / 40;
                    
                    pts = [centerxy-hsz; centerxy+[-hsz(1) hsz(2)]; centerxy+[hsz(1) -hsz(2)]; centerxy+hsz; centerxy; centerxy-[0 hsz(2)+handleLen]];
                    rot = -obj.defaultRoiRotation * pi / 180;
                    R = [cos(rot) sin(rot) 0;-sin(rot) cos(rot) 0; 0 0 1];
                    pts = scanimage.mroi.util.xformPoints(pts,R);
                    pts = pts + repmat(oppt,6,1);
                    ocenterxy = pts(5,:);
                    centerxy = ocenterxy;
                    
                    xx = [pts(1:2,1) pts(3:4,1)];
                    yy = [pts(1:2,2) pts(3:4,2)];
                    obj.hMakeToolSquare = surface(xx, yy, ones(2),'FaceColor','none','edgecolor',obj.makeToolBoxColor,'linewidth',1,'parent',obj.h2DMainViewAxes);
                    obj.hMakeToolX = line(pts(5,1),pts(5,2),1,'Parent',obj.h2DMainViewAxes,'LineStyle','none','Marker','x','MarkerEdgeColor',obj.makeToolBoxColor,'Markersize',10,'LineWidth',1.5);
                    obj.hMakeToolO = line(pts(4,1),pts(4,2),1,'Parent',obj.h2DMainViewAxes,'LineStyle','none','Marker','o','MarkerEdgeColor',obj.makeToolBoxColor,'MarkerFaceColor',obj.makeToolBoxColor*.5,'Markersize',8,'LineWidth',1.5);
                    obj.hMakeToolL = line(pts(5:6,1), pts(5:6,2),[1;1],'Parent',obj.h2DMainViewAxes,'LineStyle','--','Marker','none','Color',obj.makeToolBoxColor,'Markersize',8,'LineWidth',1.5);
                    obj.hMakeToolR = line(pts(6,1),pts(6,2),1,'Parent',obj.h2DMainViewAxes,'LineStyle','none','Marker','o','MarkerEdgeColor',obj.makeToolBoxColor,'MarkerFaceColor',[0 0 0],'Markersize',8,'LineWidth',1.5);
                    
                    if obj.editorModeIsStim
                        sf = scanimage.mroi.scanfield.fields.StimulusField(sprintf('scanimage.mroi.stimulusfunctions.%s',obj.defaultStimFunction),obj.defaultStimFunctionArgs,obj.defaultStimDuration/1000,1,[0 0],[1 1],0,0);
                        [path_FOV,~] = obj.scannerSet.scanPathStimulusFOV(sf,0,obj.editorZ,0,false,false,obj.stimpathRenderMaxPoints); % dzdt is only used for beams generation at the moment, so it's not really relevant here
                        obj.makeToolPathNomPts = path_FOV.G;
                        
                        pts = scanimage.mroi.util.xformPoints(obj.makeToolPathNomPts,R);
                        pts = [pts(:,1)*hsz(1) pts(:,2)*hsz(2)] + repmat(ocenterxy,length(pts),1);
                        obj.hMakeToolPath = line('XData',pts(:,1),'YData',pts(:,2),'ZData',1.1*ones(length(pts),1),'Parent',obj.h2DMainViewAxes,'LineStyle','-','Marker','none','Color',obj.makeToolPathColor,'LineWidth',1);
                        delete(sf);
                    end
                    
                    olocks = obj.locks & [~obj.drawArray true];
                    
                    set(obj.hFig,'WindowButtonMotionFcn',@(varargin)obj.mainCreate(false),'WindowButtonUpFcn',@(varargin)obj.mainCreate(true));
                    waitfor(obj.hFig,'WindowButtonMotionFcn',[]);
                end
            elseif stop
                set(obj.hFig,'WindowButtonMotionFcn',[],'WindowButtonUpFcn',[]);
                
                most.idioms.safeDeleteObj(obj.hMakeToolSquare);
                most.idioms.safeDeleteObj(obj.hMakeToolX);
                most.idioms.safeDeleteObj(obj.hMakeToolO);
                most.idioms.safeDeleteObj(obj.hMakeToolL);
                most.idioms.safeDeleteObj(obj.hMakeToolR);
                most.idioms.safeDeleteObj(obj.hMakeToolPath);
                
                sz = hsz*2;
                sz(olocks) = obj.defaultRoiSize(olocks);
                if obj.canDrawArray && obj.drawArray
                    if obj.locks(1)
                        nsz = obj.defaultRoiWidth;
                        N = ceil(sz(1) / nsz);
                        sz(1) = nsz * N;
                    else
                        nsz = obj.scannerSet.scanners{1}.fullAngleDegrees * obj.scannerSet.scanners{1}.fillFractionSpatial;
                        N = ceil(sz(1) / nsz);
                        nsz = sz(1) / N;
                    end
                    
                    fl = centerxy(1) - sz(1)/2 + nsz/2;
                    sz(1) = nsz;
                    for i = 0:(N-1)
                        obj.createRoi([(fl + i*nsz) centerxy(2)],sz);
                    end
                else
                    obj.createRoi(centerxy,sz);
                end
            else
                nwpt = getPointerLocation(obj.h2DMainViewAxes);
                
                % special handling of line stimulus function to make it easier to draw
                if obj.editorModeIsStim && strcmp(obj.defaultStimFunction, 'line')
                    obj.hMakeToolSquare.ZData(:) = nan;
                    obj.hMakeToolX.ZData(:) = nan;
                    obj.hMakeToolL.ZData(:) = nan;
                    R = eye(3);
                    switch obj.newRoiDrawMode
                        case 'top left rectangle'
                            centerxy = (oppt+nwpt)/2;
                            hsz = [1 -1] .* (oppt-nwpt)/2;
                            
                        case 'center point rectangle'
                            centerxy = oppt;
                            hsz = [1 -1] .* (oppt-nwpt);
                    end
                    tl = centerxy+hsz.*[-1 1];
                    br = centerxy-hsz.*[-1 1];
                    obj.hMakeToolO.XData = tl(1);
                    obj.hMakeToolO.YData = tl(2);
                    obj.hMakeToolO.ZData = 2;
                    obj.hMakeToolR.XData = br(1);
                    obj.hMakeToolR.YData = br(2);
                    obj.hMakeToolR.ZData = 2;
                else
                    switch obj.newRoiDrawMode
                        case 'top left rectangle'
                            centerxy = (oppt+nwpt)/2;
                            
                        case 'center point rectangle'
                            centerxy = oppt;
                    end
                    % unrotate to find desired xy size
                    relpt = nwpt - centerxy;
                    rot = -obj.defaultRoiRotation * pi / 180;
                    R = [cos(rot) sin(rot) 0;-sin(rot) cos(rot) 0; 0 0 1];
                    hsz = abs(scanimage.mroi.util.xformPoints(relpt,R,true));
                    
                    % contrain minimum drag size
                    if hsz < (diff(obj.h2DMainViewAxes.YLim) / 200);
                        centerxy = ocenterxy;
                        hsz = [obj.defaultRoiWidth obj.defaultRoiHeight]/2;
                        flwMouse = false;
                    else
                        flwMouse = true;
                    end
                    
                    % if resonant constrain maximum size
                    if isa(obj.scannerSet,'scanimage.mroi.scannerset.ResonantGalvoGalvo') && ~(obj.drawArray && obj.canDrawArray)
                        hsz(1) = min(hsz(1), obj.scannerSet.scanners{1}.fullAngleDegrees*obj.scannerSet.scanners{1}.fillFractionSpatial/2);
                    end
                    
                    hsz(olocks) = obj.defaultRoiSize(olocks)/2;
                    centerxy(olocks) = ocenterxy(olocks);
                    
                    %find new points
                    handleLen = diff(obj.h2DMainViewAxes.YLim) / 40;
                    pts = [-hsz; -hsz(1) hsz(2); hsz(1) -hsz(2); hsz; 0 0; 0 -hsz(2)-handleLen];
                    rot = -obj.defaultRoiRotation * pi / 180;
                    R = [cos(rot) sin(rot) 0;-sin(rot) cos(rot) 0; 0 0 1];
                    pts = scanimage.mroi.util.xformPoints(pts,R);
                    pts = pts + repmat(centerxy,6,1);
                    
                    xx = [pts(1:2,1) pts(3:4,1)];
                    yy = [pts(1:2,2) pts(3:4,2)];
                    obj.hMakeToolSquare.XData = xx;
                    obj.hMakeToolSquare.YData = yy;
                    obj.hMakeToolX.XData = pts(5,1);
                    obj.hMakeToolX.YData = pts(5,2);
                    if flwMouse
                        obj.hMakeToolO.XData = nwpt(1);
                        obj.hMakeToolO.YData = nwpt(2);
                    else
                        obj.hMakeToolO.XData = pts(4,1);
                        obj.hMakeToolO.YData = pts(4,2);
                    end
                    obj.hMakeToolL.XData = pts(5:6,1);
                    obj.hMakeToolL.YData = pts(5:6,2);
                    obj.hMakeToolR.XData = pts(6,1);
                    obj.hMakeToolR.YData = pts(6,2);
                end
                
                if obj.editorModeIsStim
                    pts = [obj.makeToolPathNomPts(:,1)*hsz(1) obj.makeToolPathNomPts(:,2)*hsz(2)];
                    pts = scanimage.mroi.util.xformPoints(pts,R) + repmat(centerxy,length(obj.makeToolPathNomPts),1);
                    
                    obj.hMakeToolPath.XData = pts(:,1);
                    obj.hMakeToolPath.YData = pts(:,2);
                end
            end
        end
        
        function zPan(obj, isPanningStopped, varargin)
            persistent PreviousMouseLocation;
            
            CurrentMouseLocation = getCurrentPoint();
            if nargin > 2
                PreviousMouseLocation = CurrentMouseLocation;
                obj.hFig.Pointer = 'fleur';
                set(obj.hFig,...
                    'WindowButtonMotionFcn', @(varargin)obj.zPan(false),...
                    'WindowButtonUpFcn', @(varargin)obj.zPan(true));
                waitfor(obj.hFig,'WindowButtonMotionFcn',[]);
            elseif isPanningStopped
                set(obj.hFig,...
                    'WindowButtonMotionFcn', [],...
                    'WindowButtonUpFcn', []);
                obj.hFig.Pointer = 'arrow';
            else
                obj.zProjectionRange = obj.zProjectionRange...
                    - CurrentMouseLocation.y + PreviousMouseLocation.y;
                obj.mainViewPosition(obj.projectionDim) = obj.mainViewPosition(obj.projectionDim)...
                    - CurrentMouseLocation.x + PreviousMouseLocation.x;
                
                PreviousMouseLocation = getCurrentPoint();
            end
            
            function cp = getCurrentPoint()
                cp = getPointerLocation(obj.h2DProjectionViewAxes);
                cp = struct('x', cp(1),'y', cp(2));
            end
        end
        
        function pan3DView(obj,stop,varargin)
            persistent ppt;
            
            if nargin > 2
                ppt = getPt;
                set(obj.hFig,'WindowButtonMotionFcn',@(varargin)obj.pan3DView(false),'WindowButtonUpFcn',@(varargin)obj.pan3DView(true));
                waitfor(obj.hFig,'WindowButtonMotionFcn',[]);
            elseif stop
                set(obj.hFig,'WindowButtonMotionFcn',[],'WindowButtonUpFcn',[]);
            else
                nwpt = getPt();
                deltaPix = nwpt-ppt;
                
                mod = get(obj.hFig, 'currentModifier');
                if ismember('shift', mod) || strcmp(obj.hFig.SelectionType, 'extend')
                    camorbit(obj.h3DViewAxes,deltaPix(1),-deltaPix(2),'data',[0 0 1]);
                else
                    camdolly(obj.h3DViewAxes,-deltaPix(1),-deltaPix(2),0,'movetarget','pixels');
                end
                ppt = nwpt;
            end
            
            function p = getPt
                pt = hgconvertunits(obj.hFig,[0 0 obj.hFig.CurrentPoint],obj.hFig.Units,'pixels',0);
                p = pt([3,4]);
            end
        end
        
        function keyPressFcn(obj,~,evt)
            if ~isempty(evt.Modifier)
                return
            end
            
            switch lower(evt.Key)
                case {'a' 'insert'}
                    if obj.createMode && obj.cellPickOn
                        obj.endCellPick(true);
                    elseif obj.createMode && obj.canDrawArray
                        obj.drawArray = ~obj.drawArray;
                    elseif obj.editorModeIsSlm && obj.slmPatternTypeIsBitmap
                        obj.slmBitmapBrushEnable = true;
                    else
                        obj.newRoi();
                    end
                    
                case 'm'
                    if obj.createMode
                        if obj.cellPickOn
                            [tf, idx] = ismember(obj.cellPickMode,obj.cellPickModes);
                            if ~tf || idx == numel(obj.cellPickModes)
                                obj.cellPickMode = obj.cellPickModes{1};
                            else
                                obj.cellPickMode = obj.cellPickModes{idx + 1};
                            end
                        else
                            obj.drawMultipleRois = ~obj.drawMultipleRois;
                        end
                    end
                    
                case 'c'
                    obj.newRoiDrawMode = 'cell picker';
                    if ~obj.createMode
                        obj.newRoi();
                    end
                    
                case 'r'
                    if obj.createMode
                        switch obj.newRoiDrawMode
                            case {'cell picker' 'center point rectangle'}
                                obj.newRoiDrawMode = 'top left rectangle';
                                
                            case 'top left rectangle'
                                obj.newRoiDrawMode = 'center point rectangle';
                        end
                    end
                    
                case 'd'
                    if obj.createMode && obj.cellPickOn
                        obj.pbDilateCell()
                    else
                        obj.delSelection();
                    end
                    
                case 'e'
                    if obj.createMode && obj.cellPickOn
                        obj.pbErodeCell();
                    end
                    
                case 'delete'
                    if obj.createMode && obj.cellPickOn
                        obj.pbDeleteCell()
                    else
                        obj.delSelection();
                    end
                    
                case 'p'
                    if obj.editorModeIsStim
                        obj.quickAddPause();
                    end
                    
                case 'k'
                    if obj.editorModeIsStim
                        obj.quickAddPark();
                    end
                    
                case {'escape'}
                    obj.changeSelection();
                    obj.fixTableCheck();
                    
                    if obj.editorModeIsSlm && obj.slmPatternTypeIsBitmap
                        obj.slmBitmapBrushEnable = false;
                    end
            end
        end
        
        function rgChanged(obj,varargin)
            obj.setZProjectionLimits();
            obj.rgChangedPar();
        end
        
        function rgChangedPar(obj,~)
            % Dev Note: Originally updateScanPathCache was called after
            % updateTable but this resulted in indexing errors when loading
            % a group that had more patterns than the previously loaded
            % group. The reason is because updateTable calls
            % changedSelection which calls updateDisplay which tries to
            % pull path data from the cache for each scan pattern. Since
            % the cache has not yet been updated you will have an indexing
            % error where we try to pull cache data for a pattern that
            % isn't in the cache. For example start a group with 2 patterns
            % and then try to load a group with 4 patterns, since the 2
            % pattern group is what is currently cached you will get an
            % index error when trying to update from the cache for patterns
            % 3 and 4. - JLF
            obj.updateScanPathCache();
            obj.updateTable();
            obj.updateDisplay();
            obj.updateGlobalPanel();
        end
        
        function selectedObjChanged(obj)
            if isa(obj.activePanelUpdateFcn,'function_handle')
                obj.activePanelUpdateFcn();
            end
        end
        
        function newRoi(obj,varargin)
            if obj.createMode
                obj.changeSelection();
                return;
            end
            
            obj.defaultStimFunction = obj.defaultStimFunction;
            
            if numel(obj.tblData)
                obj.tblData(:,1) = {false};
            end
            
            obj.roiTable.Data = obj.tblData;
            obj.changeSelection();
            obj.hBlankPanel.Visible = 'off';
            obj.hStimOptimizationPanel.Visible = 'off';
            obj.hGlobalImagingSfPropsPanel.Visible = 'off';
            
            if ~obj.editorModeIsSlm
                obj.hNewPanel.Visible = 'on';
                obj.activePanelUpdateFcn = @obj.newRoiPropsPanelUpdate;
                obj.newRoiPropsPanelUpdate();
            end
            
            obj.createMode = true;
            
            if obj.cellPickOn
                obj.startCellPick();
            end
            
            if strcmp(obj.editorMode,'slm') || obj.drawMultipleRois
                obj.pbNew.String = 'Done';
            else
                obj.pbNew.String = 'Cancel';
            end
        end
        
        function delSelection(obj,varargin)
            if (obj.editorModeIsStim || obj.editorModeIsSlm) && isa(obj.selectedObj, 'scanimage.mroi.scanfield.ScanField')
                objToDel = obj.selectedObjParent;
            else
                objToDel = obj.selectedObj;
            end
            
            if obj.editorModeIsSlm
                obj.updateSlmPattern();
            end
            
            if most.idioms.isValidObj(objToDel)
                if isa(objToDel, 'scanimage.mroi.Roi')
                    %                     uuid = objToDel.uuiduint64;
                    
                    selectedObjRoiIdx_ = obj.selectedObjRoiIdx;
                    obj.enableListeners = false;
                    obj.editingGroup.removeById(obj.selectedObjRoiIdx);
                    obj.enableListeners = true;
                    obj.remDrawnRoi(obj.selectedObjRoiIdx);
                    cellfun(@(x)set(x,'Visible','off'),obj.hSelObjHandles);
                    %                     obj.remTableRoi(uuid);
                    obj.rgChangedPar();
                    
                    if numel(obj.editingGroup.rois) > 0
                        idx = min(selectedObjRoiIdx_, numel(obj.editingGroup.rois));
                        obj.changeSelection(obj.editingGroup.rois(idx),[]);
                        obj.fixTableCheck();
                    end
                elseif isa(obj.selectedObj, 'scanimage.mroi.scanfield.ScanField')
                    uuid = obj.selectedObj.uuiduint64;
                    idx = obj.selectedObjParent.idToIndex(uuid);
                    
                    obj.enableListeners = false;
                    obj.selectedObjParent.removeById(idx);
                    obj.enableListeners = true;
                    obj.remTableSf(uuid);
                    
                    if numel(obj.selectedObjParent.scanfields) > 0
                        idx = min(idx, numel(obj.selectedObjParent.scanfields));
                        obj.changeSelection(obj.selectedObjParent.scanfields(idx),obj.selectedObjParent);
                    else
                        obj.changeSelection(obj.selectedObjParent,[]);
                        obj.delSelection();
                    end
                    obj.fixTableCheck();
                end
                
                obj.setZProjectionLimits();
            end
        end
        
        function p2DViewSize(obj,varargin)
            obj.h2DViewPanel.Units = 'pixels';
            p = obj.h2DViewPanel.Position;
            HAX_MARG = 54;
            VAX_MARG = 44;
            
            W = max(p(3) - 2*HAX_MARG - 76,1);
            
            p1 = [HAX_MARG VAX_MARG max(floor(W*.75),200) max(p(4)-VAX_MARG-8,200)];
            set(obj.h2DMainViewAxes,'Units','pixels','position',p1);
            set(obj.h2DMainViewOutlineAxes,'Units','pixels','position',p1);
            set(obj.h2DMainViewTickAxes,'Units','pixels','position',p1);
            
            p2 = [p1(1)+p1(3)+1 VAX_MARG 75 max(p(4)-VAX_MARG-8,200)];
            set(obj.h2DZScrollAxes,'Units','pixels','position',p2);
            
            L = p2(1)+p2(3)+1;
            p3 = [L VAX_MARG max(floor(W*.25),100) max(p(4)-VAX_MARG-8,200)];
            set(obj.h2DProjectionViewAxes,'Units','pixels','position',p3);
            set(obj.h2DProjectionViewTickAxes,'Units','pixels','position',p3);
            
            obj.updateXYAxes();
            obj.updateScrollPatch();
        end
        
        function legendSize(obj,varargin)
            if obj.initDone
                obj.hLegendScrollingPanel.Units = 'pixels';
                w = obj.hLegendScrollingPanel.Position(3);
                if w > 448
                    obj.legendCols = max(floor(w/224),1);
                else
                    obj.legendCols = max(floor(w/180),1);
                end
                nRow = max(1,ceil(obj.nLegendItems/obj.legendCols));
                
                if nRow ~= obj.legendTotRows
                    obj.legendTotRows = nRow;
                    if obj.legendTotRows > 3
                        nVisibleRows = 3;
                        obj.legendMaxTopRow = obj.legendTotRows - nVisibleRows + 1;
                        
                        obj.slLegendScroll.hCtl.Min = 1;
                        obj.slLegendScroll.hCtl.Max = obj.legendMaxTopRow;
                        a = nVisibleRows / (obj.legendTotRows - nVisibleRows);
                        obj.slLegendScroll.hCtl.SliderStep = [1/(obj.legendMaxTopRow-1) a];
                        obj.slLegendScroll.hCtl.Value = obj.legendMaxTopRow;
                        obj.slLegendScroll.hCtl.Enable = 'on';
                    else
                        obj.slLegendScroll.hCtl.Min = 1;
                        obj.slLegendScroll.hCtl.Value = 1;
                        obj.slLegendScroll.hCtl.Enable = 'off';
                        obj.legendScrl();
                    end
                end
                
                obj.hLegendGrid.Units = 'pixels';
                obj.hLegendGrid.Position([3 4]) = [w 33*obj.legendTotRows];
                set(obj.hLegendGrid,'GridSize',[obj.legendTotRows obj.legendCols]);
            end
        end
        
        function legendScrl(obj,varargin)
            if obj.initDone
                %                 obj.hLegendScrollingPanel.Units = 'pixels';
                %                 H = obj.hLegendScrollingPanel.Position;
                H = 99; % this should not change
                
                v = (obj.slLegendScroll.hCtl.Value-1) * 33;
                obj.hLegendGrid.Units = 'pixels';
                obj.hLegendGrid.Position(2) = H - min(3,obj.legendTotRows)*33 - v;
            end
        end
        
        function scrollLegendToBottom(obj)
            obj.slLegendScroll.hCtl.Value = obj.slLegendScroll.hCtl.Min;
        end
        
        function rebuildLegend(obj)
            %delete old items
            delete(obj.hLegendGrid.Children);
            
            % default legend items which only need binding
            legendItemAttributes = [...
                struct(...
                'name', 'Scanner Field of View',...
                'lineColor', [1 1 0],...
                'lineStyle', ':',...
                'fillColor', 'none',...
                'localBinding', 'showScannerFov')...
                struct(...
                'name', 'Editor Z Plane',...
                'lineColor', most.constants.Colors.orange,...
                'lineStyle', '-',...
                'fillColor', 'none',...
                'localBinding', 'showEditorZ')...
                struct(...
                'name', 'Imaging Z Planes',...
                'lineColor', ones(1,3),...
                'lineStyle', '-',...
                'fillColor', 'none',...
                'localBinding', 'showImagingZs')...
                struct(...
                'name', 'Currently Selected ROI',...
                'lineColor', [0 1 0],...
                'lineStyle', '-',...
                'fillColor', 'none',...
                'localBinding', 'showSelectedRoi')...
                struct(...
                'name', 'Other ROIs',...
                'lineColor', [1 0 0],...
                'lineStyle', '-',...
                'fillColor', 'none',...
                'localBinding', 'showOtherRois')...
                ];
            numDefaultBoundItems = numel(legendItemAttributes);
            numContextIms = numel(obj.hContextImages);
            obj.nLegendItems = numDefaultBoundItems + numContextIms + 1;
            obj.legendSize();
            
            for i = 1:(obj.nLegendItems - 1)
                if i <= numDefaultBoundItems
                    makeItem(legendItemAttributes(i));
                else
                    imgIdx = i - numDefaultBoundItems;
                    hContextIm = obj.hContextImages(imgIdx);
                    s = makeItem(hContextIm.getLegendAttributes());
                    hContextIm.decorateLegendItem(s);
                end
            end
            
            % make "add image from file" button
            hItemContainer = most.gui.uiflowcontainer('parent',obj.hLegendGrid,...
                'FlowDirection','LeftToRight');
            most.gui.uicontrol('parent',hItemContainer,...
                'string','Add Image From File',...
                'callback', @(varargin)scanimage.guis.roigroupeditor.TiffContextImage(obj),...
                'KeyPressFcn',@obj.keyPressFcn);
            
            function s = makeItem(itemAttributes)
                s.hContainer = most.gui.uiflowcontainer('parent',obj.hLegendGrid,...
                    'FlowDirection','LeftToRight');
                
                hUP = uipanel('parent',s.hContainer,'bordertype','none');
                set(hUP, 'WidthLimits', 30*ones(1,2));
                
                hAx = most.idioms.axes('parent',hUP,'box','on','Color','k',...
                    'XTick',[],'XTickLabel',[],'YTick',[],'YTickLabel',[],...
                    'xlim', [0 1],'ylim', [0 1],'CLim',[0 1]);
                
                s.hCb = most.gui.uicontrol('parent',s.hContainer,...
                    'style', 'checkbox',...
                    'string', itemAttributes.name,...
                    'KeyPressFcn', @obj.keyPressFcn);
                
                if strcmp(itemAttributes.fillColor, 'none')
                    surface([.1 .9], [.1 .9], [0 0; 0 0], 'parent', hAx, 'edgecolor', itemAttributes.lineColor,...
                        'linewidth', 2, 'linestyle', itemAttributes.lineStyle,'FaceColor', itemAttributes.fillColor);
                else
                    sz = size(obj.rando,1);
                    cData = [];
                    cData(1,1,:) = itemAttributes.fillColor;
                    cData = repmat(cData,sz,sz,1) .* repmat(obj.rando,1,1,3);
                    surface([.1 .9], [.1 .9], [0 0; 0 0],...
                        'FaceColor', 'texturemap', 'CData', cData,...
                        'edgecolor', itemAttributes.lineColor,...
                        'linewidth', 2, 'linestyle', itemAttributes.lineStyle, 'parent', hAx);
                end
                
                if ~isempty(itemAttributes.localBinding)
                    s.hCb.bindings = {obj, itemAttributes.localBinding, 'Value'};
                end
            end
        end
        
        function updateFovLines(obj)
            offset = [0 0];
            ss = obj.scannerSet;
            if obj.editorModeIsSlm && isa(ss,'scanimage.mroi.scannerset.GalvoGalvo')
                offset = obj.slmPatternSfParent.centerXY;
                offset = offset - scanimage.mroi.util.xformPoints([0 0],ss.slm.scannerToRefTransform);
                ss = ss.slm;
                
                % we are editing an slm pattern for a galvo-galvo-slm set.
                % the fov is movable
                obj.h2DScannerFovSurf.HitTest = 'on';
                obj.h2DScannerFovHandles.Visible = 'on';
            else
                obj.h2DScannerFovSurf.HitTest = 'off';
                obj.h2DScannerFovHandles.Visible = 'off';
                obj.h2DScannerFovSurf.CData = [];
            end
            
            if isa(ss,'scanimage.mroi.scannerset.SLM') && ss.zeroOrderBlockRadius
                ctr = ss.fovCenterPoint + offset;
                
                theta = linspace(0,2*pi,20)';
                pts = [ss.zeroOrderBlockRadius*cos(theta) ss.zeroOrderBlockRadius*sin(theta)];
                T = ss.scannerToRefTransform;
                T([7 8]) = 0;
                pts = scanimage.mroi.util.xformPoints(pts,T) + repmat(ctr,20,1);
                
                obj.h2DScannerFovZeroOrder.XData = pts(:,1);
                obj.h2DScannerFovZeroOrder.YData = pts(:,2);
                obj.h2DScannerFovZeroOrder.Visible = 'on';
            else
                obj.h2DScannerFovZeroOrder.Visible = 'off';
            end
            
            cps = ss.fovCornerPoints + repmat(offset,4,1);
            obj.fovGridxx = [cps([1 4],1) cps([2 3],1)];
            obj.fovGridyy = [cps([1 4],2) cps([2 3],2)];
            
            obj.h2DScannerFovSurf.XData = obj.fovGridxx;
            obj.h2DScannerFovSurf.YData = obj.fovGridyy;
            
            obj.h2DScannerFovHandles.XData(1:2:7) = cps(:,1);
            obj.h2DScannerFovHandles.YData(1:2:7) = cps(:,2);
            
            switch obj.projectionMode
                case 'XZ'
                    obj.h2DScannerFovLines(1).XData = min(obj.fovGridxx(:))*ones(1,2);
                    obj.h2DScannerFovLines(2).XData = max(obj.fovGridxx(:))*ones(1,2);
                case 'YZ'
                    obj.h2DScannerFovLines(1).XData = min(obj.fovGridyy(:))*ones(1,2);
                    obj.h2DScannerFovLines(2).XData = max(obj.fovGridyy(:))*ones(1,2);
            end
        end
        
        function updateMaxViewFov(obj)
            m = max([max(abs(obj.fovGridxx(:))); max(abs(obj.fovGridyy(:)));]);
            if obj.editorModeIsSlm && isa(obj.scannerSet,'scanimage.mroi.scannerset.GalvoGalvo')
                cps = obj.scannerSet.fovCornerPoints();
                m = max([m; cps(:)]);
            end
            
            m = max(m, maxCellData([obj.hContextImages(:).roiCPs]));
            
            obj.mainViewFovLim = 2.2*m;
            obj.mainViewFov = obj.mainViewFov;
            
            function md = maxCellData(c)
                if isempty(c)
                    md = 0;
                elseif iscell(c)
                    md = max(cellfun(@maxCellData,c));
                else
                    md = max(c(:));
                end
            end
        end
        
        function updateXYAxes(obj)
            asp = obj.h2DMainViewOutlineAxes.PlotBoxAspectRatio/min(obj.h2DMainViewOutlineAxes.PlotBoxAspectRatio([1,2]));
            fov = asp * obj.mainViewFov;
            lims = {(obj.mainViewPosition(1) + [-fov(1) fov(1)]/2) (obj.mainViewPosition(2) + [-fov(2) fov(2)]/2)};
            obj.h2DMainViewAxes.XLim = lims{1};
            obj.h2DMainViewAxes.YLim = lims{2};
            obj.h2DMainViewTickAxes.XLim = lims{1} * obj.xyUnitFactor  + obj.xyUnitOffset(1);
            obj.h2DMainViewTickAxes.YLim = lims{2} * obj.xyUnitFactor  + obj.xyUnitOffset(2);
            obj.h2DProjectionViewAxes.XLim = lims{obj.projectionDim};
            obj.h2DProjectionViewTickAxes.XLim = lims{obj.projectionDim};
        end
        
        function deleteDrawData(obj)
            cellfun(@delete, horzcat(obj.drawData{:}));
            obj.drawData = repmat({{}},1,numel(obj.editingGroup.rois)+1);
            
            cellfun(@delete, horzcat(obj.drawDataProj{:}));
            obj.drawDataProj = repmat({{}},1,numel(obj.editingGroup.rois)+1);
        end
        
        function draw2D(obj,rois)
            nRois = numel(obj.editingGroup.rois);
            
            if ismember(inf,rois)
                rois = 1:nRois;
                selRoiDrawn = false;
            else
                selRoiDrawn = true;
                
                if obj.editorModeIsStim
                    rois = unique([rois rois-1 rois+1]);
                    rois(rois<1) = rois(rois<1) + nRois;
                    rois(rois>nRois) = rois(rois>nRois) - nRois;
                end
            end
            
            obj.drawData(end+1:numel(obj.editingGroup.rois)+1) = {{}};
            obj.drawDataProj(end+1:numel(obj.editingGroup.rois)+1) = {{}};
            
            numNonPauseRois = obj.editorModeIsStim && numNonPause(obj.editingGroup) > 0;
            
            handleLen = diff(obj.h2DMainViewAxes.YLim) / 40;
            infRg = 1000000;
            nInf = obj.zProjectionRange(1) - infRg;
            pInf = obj.zProjectionRange(2) + infRg;
            
            for i = rois
                roi = obj.editingGroup.rois(i);
                sf = roi.get(obj.editorZ);
                
                if i == obj.selectedObjRoiIdx
                    col = [0 1 0];
                    vistf = obj.showSelectedRoi;
                    vis = obj.tfMap(vistf);
                    lnz = .6;
                else
                    col = [1 0 0];
                    vistf = obj.showOtherRois;
                    vis = obj.tfMap(vistf);
                    lnz = .5;
                end
                
                wayxpts = nan;
                wayypts = nan;
                waylnz = .4;
                
                if ~isempty(sf)
                    if obj.editorModeIsStim || obj.editorModeIsSlm
                        % only draw box for selected, non park, non pause
                        if (i ~= obj.selectedObjRoiIdx) || sf.isPause || sf.isPark
                            surflinestyle = 'none';
                            col1 = col;
                        else
                            surflinestyle = '-';
                            col1 = obj.makeToolBoxColor;
                        end
                        linelinestyle = '-';
                        linemkrstyle = 'none';
                    else
                        % always draw box for imaging rois. solid for
                        % defined sf, dotted for interpolated
                        if ismember(obj.editorZ, roi.zs)
                            surflinestyle = '-';
                        else
                            surflinestyle = '--';
                        end
                        col1 = col;
                        linelinestyle = 'none';
                        linemkrstyle = 'x';
                    end
                    
                    ctr = sf.centerXY;
                    hsz = sf.sizeXY/2;
                    rot = sf.rotation;
                else
                    surflinestyle = '-';
                    linelinestyle = 'none';
                    linemkrstyle = 'x';
                    col1 = 'none';
                    ctr = [0 0];
                    hsz = [1 1];
                    rot = 0;
                end
                col2 = col1;
                
                pts = [-hsz; -hsz(1) hsz(2); hsz(1) -hsz(2); hsz; 0 0; 0 -hsz(2)-handleLen];
                rot = -rot * pi / 180;
                R = [cos(rot) sin(rot) 0;-sin(rot) cos(rot) 0; 0 0 1];
                pts = scanimage.mroi.util.xformPoints(pts,R);
                pts = pts + repmat(ctr,6,1);
                
                xx = [pts(1:2,1) pts(3:4,1)];
                yy = [pts(1:2,2) pts(3:4,2)];
                slmx = [];
                slmy = [];
                mk3 = 'h';
                ms3 = 10;
                
                if obj.editorModeIsStim || obj.editorModeIsSlm
                    lxpts = [];
                    lypts = [];
                    
                    if ~isempty(roi.scanfields) && (roi.scanfields(1).isPause || roi.scanfields(1).isPark)
                        if numNonPauseRois
                            path = obj.getStimPts(i,roi.scanfields(1));
                            
                            i_sch = findNextNonPauseRoi(i,-1);
                            prevRoiZ = obj.editingGroup.rois(i_sch).zs(1);
                            
                            i_sch = findNextNonPauseRoi(i,1);
                            nextRoiZ = obj.editingGroup.rois(i_sch).zs(1);
                            
                            zs = [prevRoiZ nextRoiZ path.Z(1) path.Z(end)];
                            minz = min(zs);
                            maxz = max(zs);
                            
                            % show if it is the selected roi and the editor
                            % z is within its range OR the editor z is at
                            % the same plane this transition starts or ends
                            % at
                            if (obj.editorZ >= (minz-.01)) && (obj.editorZ <= (maxz+.01))
                                lxpts = path.G(:,1);
                                lypts = path.G(:,2);
                                linelinestyle = '--';
                            end
                        end
                    elseif ~isempty(sf)
                        [path, waypath] = obj.getStimPts(i,sf);
                        lxpts = path.G(:,1);
                        lypts = path.G(:,2);
                        
                        % if it is a single point, make the marker bigger
                        if all(lxpts == lxpts(1)) && all(lypts == lypts(1))
                            linemkrstyle = 'o';
                            col2 = col;
                        end
                        
                        if ~isempty(waypath)
                            % add a solid line through the waypoint
                            wayxpts = waypath.G(:,1);
                            wayypts = waypath.G(:,2);
                        end
                        
                        if obj.editorModeIsStim
                            if size(sf.slmPattern,2) > 4
                                mk3 = 'square';
                                ms3 = 50;
                                slmx = ctr(1);
                                slmy = ctr(2);
                            elseif ~isempty(sf.slmPattern)
                                for ii = 1:size(sf.slmPattern,1)
                                    slmx = [slmx ctr(1) ctr(1)+sf.slmPattern(ii,1) nan];
                                    slmy = [slmy ctr(2) ctr(2)+sf.slmPattern(ii,2) nan];
                                end
                            end
                        end
                    end
                    adata = 1;
                    faceCol = 'none';
                    cdata = [];
                else
                    if isa(sf,'scanimage.mroi.scanfield.fields.IntegrationField') && numel(sf.mask) > 1
                        adata = sf.mask *.5 / max(sf.mask(:));
                        faceCol = 'texturemap';
                        cdata = [];
                        cdata(1,1,:) = uint8(col*255);
                        cdata = repmat(cdata,size(adata));
                    else
                        adata = 1;
                        faceCol = 'none';
                        cdata = [];
                    end
                    
                    lxpts = pts(5,1);
                    lypts = pts(5,2);
                end
                
                if i == obj.selectedObjRoiIdx && ~isempty(sf) && obj.showSelectedRoi && (~issstim(sf) || (~sf.isPark && ~sf.isPause))
                    selRoiDrawn = true;
                    
                    % special handling of line stimulus function to make it easier to draw
                    if issstim(sf) && strcmp(func2str(sf.stimfcnhdl), 'scanimage.mroi.stimulusfunctions.line')
                        pt1 = pts(2,:);
                        pt2 = pts(3,:);
                        z = 2;
                        obj.hSelObjHandles{1}.MarkerFaceColor = [.3 0 0];
                        obj.hSelObjHandles{3}.MarkerFaceColor = obj.makeToolBoxColor * .5;
                        xx(:) = nan;
                        yy(:) = nan;
                        
                        obj.hSelObjHandles{2}.Visible = obj.tfMap(false);
                    else
                        pt1 = pts(4,:);
                        pt2 = pts(6,:);
                        z = 1;
                        obj.hSelObjHandles{1}.MarkerFaceColor = obj.makeToolBoxColor * .5;
                        obj.hSelObjHandles{3}.MarkerFaceColor = 'none';
                        
                        obj.hSelObjHandles{2}.XData = pts(5:6,1);
                        obj.hSelObjHandles{2}.YData = pts(5:6,2);
                        obj.hSelObjHandles{2}.Visible = obj.tfMap(obj.showHandles);
                    end
                    
                    obj.hSelObjHandles{1}.XData = pt1(1);
                    obj.hSelObjHandles{1}.YData = pt1(2);
                    obj.hSelObjHandles{1}.ZData = z;
                    obj.hSelObjHandles{1}.Visible = obj.tfMap(obj.showHandles);
                    
                    obj.hSelObjHandles{3}.XData = pt2(1);
                    obj.hSelObjHandles{3}.YData = pt2(2);
                    obj.hSelObjHandles{3}.ZData = z;
                    obj.hSelObjHandles{3}.Visible = obj.tfMap(obj.showHandles);
                end
                
                if isempty(obj.drawData{i})
                    drawDat = {};
                    drawDat{1} = surface(xx, yy, lnz*ones(2),'FaceColor',faceCol,'AlphaData',adata,'edgecolor',col1,'linestyle',surflinestyle,'linewidth',2,...
                        'parent',obj.h2DMainViewAxes,'visible',vis,'ButtonDownFcn',@obj.roiHit,'UserData',roi.uuiduint64,'FaceAlpha','texturemap','CData',cdata);
                    drawDat{2} = line('XData',lxpts,'YData',lypts,'ZData',lnz*ones(size(lxpts)),'Parent',obj.h2DMainViewAxes,'LineStyle',linelinestyle,'Color',col,...
                        'Marker',linemkrstyle,'MarkerFaceColor',col2,'MarkerEdgeColor',col2,'Markersize',10,'LineWidth',1.5,'visible',vis,'ButtonDownFcn',@obj.roiHit,'UserData',roi.uuiduint64);
                    drawDat{3} = line('XData',slmx,'YData',slmy,'ZData',lnz*ones(size(slmx)),'Parent',obj.h2DMainViewAxes,'LineStyle',':','Color',col,...
                        'Marker',mk3,'MarkerFaceColor','none','MarkerEdgeColor',col,'Markersize',ms3,'LineWidth',1,'visible',vis,'ButtonDownFcn',@obj.roiHit,'UserData',roi.uuiduint64);
                    drawDat{4} = line('XData',wayxpts,'YData',wayypts,'ZData',waylnz*ones(size(wayxpts)),'Parent',obj.h2DMainViewAxes,'Color',col,...
                        'LineWidth',1,'Hittest','off','color',col);
                    
                    obj.drawData{i} = drawDat;
                else
                    obj.drawData{i}{1}.EdgeColor = col1;
                    obj.drawData{i}{2}.MarkerEdgeColor = col2;
                    obj.drawData{i}{2}.MarkerFaceColor = col2;
                    obj.drawData{i}{2}.Color = col;
                    
                    obj.drawData{i}{1}.UserData = roi.uuiduint64;
                    obj.drawData{i}{2}.UserData = roi.uuiduint64;
                    
                    obj.drawData{i}{1}.XData = xx;
                    obj.drawData{i}{1}.YData = yy;
                    obj.drawData{i}{1}.ZData = lnz*ones(2);
                    obj.drawData{i}{1}.LineStyle = surflinestyle;
                    obj.drawData{i}{1}.Visible = vis;
                    obj.drawData{i}{1}.FaceColor = faceCol;
                    obj.drawData{i}{1}.AlphaData = adata;
                    obj.drawData{i}{1}.CData = cdata;
                    
                    obj.drawData{i}{2}.XData = lxpts;
                    obj.drawData{i}{2}.YData = lypts;
                    obj.drawData{i}{2}.ZData = lnz*ones(size(lxpts));
                    obj.drawData{i}{2}.Visible = vis;
                    
                    obj.drawData{i}{2}.LineStyle = linelinestyle;
                    obj.drawData{i}{2}.Marker = linemkrstyle;
                    
                    obj.drawData{i}{3}.XData = slmx;
                    obj.drawData{i}{3}.YData = slmy;
                    obj.drawData{i}{3}.ZData = lnz*ones(size(slmx));
                    obj.drawData{i}{3}.Color = col;
                    obj.drawData{i}{3}.Marker = mk3;
                    obj.drawData{i}{3}.MarkerSize = ms3;
                    obj.drawData{i}{3}.MarkerEdgeColor = col;
                    obj.drawData{i}{3}.UserData = roi.uuiduint64;
                    
                    obj.drawData{i}{4}.XData = wayxpts;
                    obj.drawData{i}{4}.YData = wayypts;
                    obj.drawData{i}{4}.ZData = waylnz*ones(size(wayxpts));
                    obj.drawData{i}{4}.Color = col;
                end
                
                if numel(roi.zs) < 1
                    pxdata = [0 1];
                    pydata = [0 1];
                    lxdata = [0 1];
                    lydata = [0 1];
                    mlxdata = [];
                    mlydata = [];
                    col = 'none';
                    pvis = false;
                    pmkr = 'none';
                else
                    pxdata = [];
                    pxdataE = [];
                    pydata = [];
                    lxdata = [];
                    lydata = [];
                    mlxdata = [];
                    mlydata = [];
                    pmkr = 'none';
                    
                    if obj.editorModeIsStim || obj.editorModeIsSlm
                        if roi.scanfields(1).isPause
                            if numNonPauseRois
                                path = obj.getStimPts(i,roi.scanfields(1));
                                
                                mlxdata = [mlxdata path.G(1,obj.projectionDim) path.G(end,obj.projectionDim) nan];
                                mlydata = [mlydata path.Z(1) path.Z(end) nan];
                            end
                        else
                            path = obj.getStimPts(i,roi.scanfields(1));
                            pts = path.G(:,obj.projectionDim);
                            
                            mnpts = min(pts);
                            mxpts = max(pts);
                            
                            if roi.scanfields(1).isPark
                                mlxdata = [mlxdata pts(1) pts(end) nan];
                                mlydata = [mlydata path.Z(1) path.Z(end) nan];
                                mxpts = pts(end);
                                mnpts = mxpts - .00001;
                            end
                            
                            if mnpts == mxpts
                                pmkr = '.';
                                mnpts = mnpts - .00001;
                                lxdata = mnpts;
                                lydata = roi.zs(1);
                            else
                                lxdata = [mnpts mxpts nan];
                                lydata = [roi.zs(1) roi.zs(1) nan];
                            end
                        end
                        
                        pvis = false;
                    else
                        for j = numel(roi.zs):-1:1
                            z = roi.zs(j);
                            
                            if ~isnan(z)
                                sf = roi.get(z);
                                
                                pts = cornerpts(sf);
                                pts = pts(:,obj.projectionDim);
                                
                                pxdata(j) = min(pts);
                                pxdataE(j) = max(pts);
                                pydata(j) = z;
                                lxdata = [lxdata pxdata(j) pxdataE(j) nan];
                                lydata = [lydata z z nan];
                            end
                        end
                        
                        if roi.discretePlaneMode
                            pvis = false;
                        else
                            pvis = vistf;
                            if numel(roi.zs) == 1
                                pxdata = repmat(pxdata,1,2);
                                pxdataE = repmat(pxdataE,1,2);
                                pydata = [nInf pInf];
                            end
                        end
                        
                        %light dotted line down the middle
                        if ~(obj.editorModeIsStim || obj.editorModeIsSlm)
                            mlxdata = (pxdata + pxdataE) * .5;
                            mlydata = pydata;
                        end
                        
                        pxdata = [pxdata fliplr(pxdataE)];
                        pydata = [pydata fliplr(pydata)];
                    end
                end
                
                if ~pvis
                    pxdata = [];
                    pydata = [];
                end
                pvis = obj.tfMap(pvis);
                
                if isempty(obj.drawDataProj{i})
                    drawDat = {};
                    drawDat{1} = patch('xdata',pxdata,'ydata',pydata,'zdata',.45*ones(size(pxdata)),'FaceColor',col,'facealpha',.1,'edgecolor',col,...
                        'linestyle','--','linewidth',2,'parent',obj.h2DProjectionViewAxes,'visible',pvis,'UserData',roi.uuiduint64,'ButtonDownFcn',@obj.roiProjPatchHit);
                    drawDat{2} = line('xdata',lxdata,'ydata',lydata,'zdata',lnz*ones(size(lxdata)),'Color',col,...
                        'Parent',obj.h2DProjectionViewAxes,'linewidth',4,'visible',vis,'UserData',roi.uuiduint64,'ButtonDownFcn',@obj.roiProjLineHit);
                    drawDat{3} = line('xdata',mlxdata,'ydata',mlydata,'zdata',.4*ones(size(mlxdata)),'Color',col,'linestyle',':',...
                        'Parent',obj.h2DProjectionViewAxes,'linewidth',1,'visible',vis,'UserData',roi.uuiduint64,'ButtonDownFcn',@obj.roiProjPatchHit);
                    
                    obj.drawDataProj{i} = drawDat;
                else
                    obj.drawDataProj{i}{1}.FaceColor = col;
                    obj.drawDataProj{i}{1}.EdgeColor = col;
                    obj.drawDataProj{i}{2}.Color = col;
                    obj.drawDataProj{i}{3}.Color = col;
                    
                    obj.drawDataProj{i}{1}.UserData = roi.uuiduint64;
                    obj.drawDataProj{i}{2}.UserData = roi.uuiduint64;
                    obj.drawDataProj{i}{3}.UserData = roi.uuiduint64;
                    
                    obj.drawDataProj{i}{1}.XData = pxdata;
                    obj.drawDataProj{i}{1}.YData = pydata;
                    obj.drawDataProj{i}{1}.ZData = .45*ones(size(pxdata));
                    obj.drawDataProj{i}{1}.Visible = pvis;
                    
                    obj.drawDataProj{i}{2}.XData = lxdata;
                    obj.drawDataProj{i}{2}.YData = lydata;
                    obj.drawDataProj{i}{2}.ZData = lnz*ones(size(lxdata));
                    obj.drawDataProj{i}{2}.Visible = vis;
                    obj.drawDataProj{i}{2}.Marker = pmkr;
                    obj.drawDataProj{i}{2}.MarkerSize = 20;
                    
                    obj.drawDataProj{i}{3}.XData = mlxdata;
                    obj.drawDataProj{i}{3}.YData = mlydata;
                    obj.drawDataProj{i}{3}.ZData = .4*ones(size(mlxdata));
                    obj.drawDataProj{i}{3}.Visible = vis;
                end
            end
            
            if ~selRoiDrawn
                cellfun(@(x)set(x,'Visible','off'),obj.hSelObjHandles);
            end
            
            if numel(obj.drawData) > nRois
                cellfun(@delete, horzcat(obj.drawData{nRois+1:end}));
                cellfun(@delete, horzcat(obj.drawDataProj{nRois+1:end}));
                
                obj.drawData(nRois+1:end) = [];
                obj.drawDataProj(nRois+1:end) = [];
                
                obj.drawData(end+1) = {{}};
                obj.drawDataProj(end+1) = {{}};
            end
            
            function resulti = findNextNonPauseRoi(starti,schDir)
                resulti = starti;
                while true
                    resulti = resulti + schDir;
                    if ~resulti
                        resulti = nRois;
                    elseif resulti > nRois
                        resulti = 1;
                    end
                    
                    if (resulti == starti) || ~obj.editingGroup.rois(resulti).scanfields(1).isPause
                        break
                    end
                end
            end
        end
        
        function roiHit(obj,src,~)
            if obj.createMode && obj.cellPickOn
                return;
            end
            
            idx = obj.editingGroup.idToIndex(src.UserData);
            if idx > 0
                roi = obj.editingGroup.rois(idx);
                
                if idx ~= obj.selectedObjRoiIdx
                    if numel(roi.scanfields) > 0
                        if ismember(obj.editorZ, roi.zs)
                            obj.changeSelection(roi.get(obj.editorZ),roi);
                        else
                            obj.changeSelection(roi,[]);
                        end
                    else
                        obj.changeSelection(roi,[]);
                    end
                    obj.fixTableCheck();
                end
                
                % was alread selected. this is a drag
                if strcmp(obj.viewMode, '2D')
                    obj.roiManip(struct('UserData','move'),nan);
                end
            end
        end
        
        function roiManip(obj,stop,varargin)
            persistent op;
            persistent ppt;
            persistent orat;
            persistent nPattern;
            persistent objs;
            persistent allRoiMove;
            persistent xsnaps;
            persistent ysnaps;
            persistent unSnappedPos;
            
            if nargin > 2
                if obj.editorModeIsStim && isa(obj.scannerSet,'scanimage.mroi.scannerset.SLM')
                    % slm patterns can't move. do nothing
                    return;
                end
                
                %make sure the scanfield is selected, not the roi
                if ~(obj.editorModeIsStim || obj.editorModeIsSlm)
                    if isa(obj.selectedObj, 'scanimage.mroi.Roi')
                        if ismember(obj.editorZ, obj.selectedObj.zs)
                            obj.changeSelection(obj.selectedObj.get(obj.editorZ),obj.selectedObj);
                            obj.fixTableCheck();
                        else
                            obj.editOrCreateScanfieldAtZ();
                        end
                    end
                end
                
                op = stop.UserData;
                ppt = getPointerLocation(obj.h2DMainViewAxes);
                
                modif = get(obj.hFig, 'currentModifier');
                fullRoiMove = false;
                allRoiMove = false;
                if ismember('shift', modif)
                    fullRoiMove = true;
                elseif ismember('control', modif) && strcmp(op,'move')
                    r = obj.selectedObjParent.copy;
                    
                    obj.enableListeners = false;
                    obj.editingGroup.add(r);
                    obj.enableListeners = true;
                    
                    if obj.editorModeIsStim
                        obj.updateScanPathCache();
                    end
                    obj.changeSelection(r.get(obj.editorZ),r);
                    fullRoiMove = true;
                elseif ismember('alt', modif) && strcmp(op,'move')
                    allRoiMove = true;
                end
                
                if fullRoiMove
                    objs = obj.selectedObjParent.scanfields;
                elseif allRoiMove
                    objs = [obj.editingGroup.rois.scanfields];
                else
                    objs = obj.selectedObj;
                end
                
                xsnaps = [];
                ysnaps = [];
                unSnappedPos = obj.selectedObj.centerXY;
                % special handling of line stimulus function to make it easier to draw
                if issstim(obj.selectedObj) && strcmp(func2str(obj.selectedObj.stimfcnhdl), 'scanimage.mroi.stimulusfunctions.line')
                    switch op
                        case 'move'
                            
                        case 'size' % size is the bottom left corner handle for line function
                            op = 'bottomLeft';
                            
                            % store the top right coords. this point should stay fixed
                            rot = -obj.selectedObj.rotationDegrees * pi / 180;
                            R = [cos(rot) sin(rot) 0;-sin(rot) cos(rot) 0; 0 0 1];
                            orat = obj.selectedObj.centerXY + (scanimage.mroi.util.xformPoints(obj.selectedObj.sizeXY .* [.5 -.5],R));
                            
                        case 'rotate' % rotate is the top right corner handle for line function
                            op = 'topRight';
                            
                            % store the bottom left coords. this point should stay fixed
                            rot = -obj.selectedObj.rotationDegrees * pi / 180;
                            R = [cos(rot) sin(rot) 0;-sin(rot) cos(rot) 0; 0 0 1];
                            orat = obj.selectedObj.centerXY + (scanimage.mroi.util.xformPoints(obj.selectedObj.sizeXY .* [-.5 .5],R));
                    end
                else
                    switch op
                        case 'move'
                            % come up with a list of interesting points that the drag operatoin should snap to
                            % for each dimension, the snap points are in the following logical format:
                            % when dragging in dimension X, when Y in within range [rl rh], snap when approaching s1
                            
                            % only snap when there is no rotation
                            rot = obj.selectedObj.rotationDegrees;
                            if ~mod(rot,90)
                                hsz = obj.selectedObj.sizeXY/2;
                                if mod(rot, 180)
                                    % if rotated 90 deg, reverse xy size to
                                    % snap properly
                                    hsz = fliplr(hsz);
                                end
                                
                                tol = obj.mainViewFov/100;
                                
                                % snap to FOV edges and center
                                xsnaps = addSnap(xsnaps,[-inf inf],obj.fovGridxx(1)+hsz(1),obj.fovGridxx(1));
                                xsnaps = addSnap(xsnaps,[-inf inf],obj.fovGridxx(3)-hsz(1),obj.fovGridxx(3));
                                m = (obj.fovGridxx(1)+obj.fovGridxx(3))/2;
                                xsnaps = addSnap(xsnaps,[-inf inf],m,m);
                                
                                ysnaps = addSnap(ysnaps,[-inf inf],obj.fovGridyy(1)+hsz(2),obj.fovGridyy(1));
                                ysnaps = addSnap(ysnaps,[-inf inf],obj.fovGridyy(2)-hsz(2),obj.fovGridyy(2));
                                m = (obj.fovGridyy(1)+obj.fovGridyy(2))/2;
                                ysnaps = addSnap(ysnaps,[-inf inf],m,m);
                                
                                % snap to other rois
                                for r = obj.editingGroup.rois
                                    s = r.get(obj.editorZ);
                                    if ~isempty(s) && ~ismember(s,objs) && ~mod(s.rotationDegrees,90) && (~obj.editorModeIsStim || ~(s.isPause || s.isPark)) && ~obj.editorModeIsSlm
                                        shsz = 0.5 * s.sizeXY;
                                        if mod(s.rotationDegrees, 180)
                                            % if rotated 90 deg, reverse xy size to
                                            % snap properly
                                            shsz = fliplr(shsz);
                                        end
                                        
                                        % X
                                        rng = s.centerXY(2) + (shsz(2) + hsz(2)) * [-1 1] - [tol -tol];
                                        % adjacent edges
                                        xsnaps = addSnap(xsnaps,rng,s.centerXY(1)+shsz(1)+hsz(1),s.centerXY(1)+shsz(1));
                                        xsnaps = addSnap(xsnaps,rng,s.centerXY(1)-shsz(1)-hsz(1),s.centerXY(1)-shsz(1));
                                        % center
                                        xsnaps = addSnap(xsnaps,rng,s.centerXY(1),s.centerXY(1));
                                        % matching edges (only needed if size is not identical)
                                        xsnaps = addSnap(xsnaps,rng,s.centerXY(1)-shsz(1)+hsz(1),s.centerXY(1)-shsz(1));
                                        xsnaps = addSnap(xsnaps,rng,s.centerXY(1)+shsz(1)-hsz(1),s.centerXY(1)+shsz(1));
                                        
                                        % X
                                        rng = s.centerXY(1) + (shsz(1) + hsz(1)) * [-1 1] - [tol -tol];
                                        % adjacent edges
                                        ysnaps = addSnap(ysnaps,rng,s.centerXY(2)+shsz(2)+hsz(2),s.centerXY(2)+shsz(2));
                                        ysnaps = addSnap(ysnaps,rng,s.centerXY(2)-shsz(2)-hsz(2),s.centerXY(2)-shsz(2));
                                        % center
                                        ysnaps = addSnap(ysnaps,rng,s.centerXY(2),s.centerXY(2));
                                        % matching edges (only needed if size is not identical)
                                        ysnaps = addSnap(ysnaps,rng,s.centerXY(2)-shsz(2)+hsz(2),s.centerXY(2)-shsz(2));
                                        ysnaps = addSnap(ysnaps,rng,s.centerXY(2)+shsz(2)-hsz(2),s.centerXY(2)+shsz(2));
                                    end
                                end
                            end
                            
                        case 'size'
                            obj.hFig.Pointer = 'botr';
                            savePixRatio();
                            
                        case 'rotate'
                            obj.hFig.Pointer = 'cross';
                    end
                end
                
                % this is for maintaining slm points while dragging galvo position. dont do this if the pattern is a bitmap
                nPattern = isa(obj.selectedObj, 'scanimage.mroi.scanfield.fields.StimulusField') && ~isempty(obj.selectedObj.slmPattern) && (size(obj.selectedObj.slmPattern,2) < 5);
                if nPattern
                    nPattern = size(obj.selectedObj.slmPattern,1);
                end
                
                set(obj.hFig,'WindowButtonMotionFcn',@(varargin)obj.roiManip(false),'WindowButtonUpFcn',@(varargin)obj.roiManip(true));
                waitfor(obj.hFig,'WindowButtonMotionFcn',[]);
            elseif stop
                set(obj.hFig,'WindowButtonMotionFcn',[],'WindowButtonUpFcn',[]);
                if ~obj.createMode
                    obj.hFig.Pointer = 'arrow';
                end
                
                obj.enableListeners = false;
                obj.satisfyConstraints(obj.selectedObj);
                coercePixRatio();
                
                if obj.editorModeIsSlm
                    obj.updateSlmPattern();
                end
                
                obj.hSnapLineX.Visible = 'off';
                obj.hSnapLineY.Visible = 'off';
                obj.hSnapLineR.Visible = 'off';
                
                obj.enableListeners = true;
                obj.rgChangedPar();
                obj.selectedObjChanged();
            else
                nwpt = getPointerLocation(obj.h2DMainViewAxes);
                obj.enableListeners = false;
                switch op
                    case 'move'
                        %snap
                        delt = nwpt - ppt;
                        unSnappedPos = unSnappedPos + delt;
                        npos = unSnappedPos;
                        tol = obj.mainViewFov/100;
                        
                        dontSnap = ismember('alt', get(obj.hFig, 'currentModifier'));
                        
                        if ~isempty(xsnaps) && ~dontSnap
                            ac = arrayfun(@(sn)(npos(2) >= sn.range(1))&&(npos(2) <= sn.range(2)),xsnaps);
                            acsnaps = xsnaps(ac);
                            dists = abs(npos(1) - [acsnaps.point]);
                            [d,i] = min(dists);
                            
                            if d < tol
                                npos(1) = acsnaps(i).point;
                                msnaps = abs([acsnaps.point] - npos(1)) < 1e-10;
                                
                                clns = [acsnaps(msnaps).contextLine];
                                clns = [clns; clns; nan(size(clns))];
                                
                                ys = nan(size(clns));
                                ys(1,:) = -999999;
                                ys(2,:) = 999999;
                                
                                zs = 2*ones(size(ys));
                                
                                obj.hSnapLineX.Visible = 'on';
                                obj.hSnapLineX.XData = clns(:);
                                obj.hSnapLineX.YData = ys(:);
                                obj.hSnapLineX.ZData = zs(:);
                            else
                                obj.hSnapLineX.Visible = 'off';
                            end
                        else
                            obj.hSnapLineX.Visible = 'off';
                        end
                        
                        if ~isempty(ysnaps) && ~dontSnap
                            ac = arrayfun(@(sn)(npos(1) >= sn.range(1))&&(npos(1) <= sn.range(2)),ysnaps);
                            acsnaps = ysnaps(ac);
                            dists = abs(npos(2) - [acsnaps.point]);
                            [d,i] = min(dists);
                            
                            if d < tol
                                npos(2) = acsnaps(i).point;
                                msnaps = abs([acsnaps.point] - npos(2)) < 1e-10;
                                
                                clns = [acsnaps(msnaps).contextLine];
                                clns = [clns; clns; nan(size(clns))];
                                
                                xs = nan(size(clns));
                                xs(1,:) = -999999;
                                xs(2,:) = 999999;
                                
                                zs = 2*ones(size(xs));
                                
                                obj.hSnapLineY.Visible = 'on';
                                obj.hSnapLineY.XData = xs(:);
                                obj.hSnapLineY.YData = clns(:);
                                obj.hSnapLineY.ZData = zs(:);
                            else
                                obj.hSnapLineY.Visible = 'off';
                            end
                        else
                            obj.hSnapLineY.Visible = 'off';
                        end
                        
                        delt = npos - obj.selectedObj.centerXY;
                        
                        arrayfun(@(ob)setposdel(ob, delt),objs);
                        if nPattern && ~ismember('shift', get(obj.hFig, 'currentModifier'))
                            obj.selectedObj.slmPattern(:,1:2) = obj.selectedObj.slmPattern(:,1:2) - repmat(delt,nPattern,1);
                        end
                        ppt = nwpt;
                        
                    case 'size'
                        c = obj.selectedObj.centerXY;
                        
                        rot = obj.selectedObj.rotationDegrees * pi / 180;
                        R = [cos(rot) sin(rot) 0;-sin(rot) cos(rot) 0; 0 0 1];
                        nsz = (scanimage.mroi.util.xformPoints(nwpt-c,R)) * 2;
                        
                        if isa(obj.scannerSet,'scanimage.mroi.scannerset.ResonantGalvoGalvo')
                            nsz(1) = min(nsz(1), obj.scannerSet.scanners{1}.fullAngleDegrees*obj.scannerSet.scanners{1}.fillFractionSpatial);
                        end
                        
                        obj.selectedObj.sizeXY(~obj.locks) = nsz(~obj.locks);
                        if obj.editorModeIsSlm
                            for roi = obj.editingGroup.rois
                                if ~isempty(roi.scanfields)
                                    roi.scanfields(1).sizeXY = nsz;
                                end
                            end
                            obj.slmPatternSfParent.sizeXY = nsz;
                        end
                        coercePixRatio();
                        
                    case 'rotate'
                        xy = nwpt-obj.selectedObj.centerXY;
                        th = atand(-xy(1)/xy(2));
                        
                        if xy(2) < 0
                            th = floor(th);
                        else
                            th = floor(180+th);
                        end
                        if ~ismember('alt', get(obj.hFig, 'currentModifier'))
                            m = th / 15;
                            
                            if abs(m - round(m)) < 0.3
                                th = round(m) * 15;
                                
                                thd = th-90;
                                p1 = obj.selectedObj.centerXY;
                                p2 = p1 + 9999999*[cosd(thd) sind(thd)];
                                obj.hSnapLineR.XData = [p1(1) p2(1)];
                                obj.hSnapLineR.YData = [p1(2) p2(2)];
                                obj.hSnapLineR.Visible = 'on';
                            else
                                obj.hSnapLineR.Visible = 'off';
                            end
                        else
                            obj.hSnapLineR.Visible = 'off';
                        end
                        
                        obj.selectedObj.rotation = th;
                        
                        obj.hSelObjHandles{2}.XData(2) = nwpt(1);
                        obj.hSelObjHandles{2}.YData(2) = nwpt(2);
                        obj.hSelObjHandles{3}.XData = nwpt(1);
                        obj.hSelObjHandles{3}.YData = nwpt(2);
                        
                    case 'bottomLeft'
                        obj.selectedObj.centerXY = (orat + nwpt) / 2;
                        obj.selectedObj.sizeXY = (orat - nwpt) .* [1 -1];
                        obj.selectedObj.rotation = 0;
                        
                    case 'topRight'
                        obj.selectedObj.centerXY = (orat + nwpt) / 2;
                        obj.selectedObj.sizeXY = (orat - nwpt) .* [-1 1];
                        obj.selectedObj.rotation = 0;
                end
                
                if allRoiMove
                    upInds = {};
                else
                    upInds = {obj.selectedObjRoiIdx};
                end
                
                obj.updateScanPathCache(upInds{:});
                obj.updateDisplay(upInds{:});
                obj.enableListeners = true;
                obj.selectedObjChanged();
            end
            
            function savePixRatio
                if isa(obj.selectedObj, 'scanimage.mroi.scanfield.ImagingField') && ...
                        strcmp(op, 'size') && strcmp(obj.scanfieldResizeMaintainPixelProp, 'ratio')
                    orat = obj.selectedObj.pixelRatio;
                end
            end
            
            function coercePixRatio
                if isa(obj.selectedObj, 'scanimage.mroi.scanfield.ImagingField') && ...
                        strcmp(op, 'size') && strcmp(obj.scanfieldResizeMaintainPixelProp, 'ratio')
                    obj.selectedObj.pixelRatio = orat;
                    obj.selectedObj.pixelResolutionXY = ceil(obj.selectedObj.pixelResolutionXY/2)*2;
                end
            end
            
            function setposdel(o,d)
                o.centerXY = o.centerXY + d;
            end
            
            function snaps = addSnap(snaps, range, point, contextLine)
                if isempty(snaps)
                    snaps = struct('range',range,'point',point,'contextLine',contextLine);
                else
                    mtch = find(arrayfun(@(sn)(all(sn.range == range) && (sn.point == point)),snaps),1);
                    if isempty(mtch)
                        snaps(end+1) = struct('range',range,'point',point,'contextLine',contextLine);
                    else
                        snaps(mtch).contextLine = union(snaps(mtch(1)).contextLine,contextLine);
                    end
                end
            end
        end
        
        function roiProjPatchHit(obj,src,~)
            idx = obj.editingGroup.idToIndex(src.UserData);
            if idx > 0
                roi = obj.editingGroup.rois(idx);
                
                if idx ~= obj.selectedObjRoiIdx
                    if numel(roi.scanfields) > 0
                        if (obj.editorModeIsStim || obj.editorModeIsSlm)
                            sf = roi.scanfields(1);
                            obj.changeSelection(roi,sf);
                        else
                            if ismember(obj.editorZ, roi.zs)
                                obj.changeSelection(roi.get(obj.editorZ),roi);
                            else
                                obj.changeSelection(roi,[]);
                            end
                        end
                    else
                        obj.changeSelection(roi,[]);
                    end
                    obj.fixTableCheck();
                end
            end
        end
        
        function roiProjLineHit(obj,src,evt)
            idx = obj.editingGroup.idToIndex(src.UserData);
            if idx > 0
                roi = obj.editingGroup.rois(idx);
                z = evt.IntersectionPoint(2);
                diff = abs(z - roi.zs);
                [~,i] = min(diff);
                sf = roi.scanfields(i);
                
                if isempty(obj.selectedObj) || (sf ~= obj.selectedObj)
                    obj.changeSelection(sf,roi);
                    obj.fixTableCheck();
                else
                    % already selected. this is a drag
                    obj.sfDrag();
                end
            end
        end
        
        function sfDrag(obj,stop)
            persistent ppt;
            persistent snapZs;
            
            if nargin < 2
                if obj.editorModeIsStim && isa(obj.scannerSet,'scanimage.mroi.scannerset.SLM')
                    % slm patterns can't move. do nothing
                    return;
                end
                
                ppt = getPointerLocation(obj.h2DProjectionViewAxes);
                snapZs = obj.interestingZs;
                set(obj.hFig,'WindowButtonMotionFcn',@(varargin)obj.sfDrag(false),'WindowButtonUpFcn',@(varargin)obj.sfDrag(true));
                waitfor(obj.hFig,'WindowButtonMotionFcn',[]);
            elseif stop
                set(obj.hFig,'WindowButtonMotionFcn',[],'WindowButtonUpFcn',[]);
                obj.updateTable();
                obj.setZProjectionLimits();
                obj.satisfyConstraints(obj.selectedObj);
            else
                nwpt = getPointerLocation(obj.h2DProjectionViewAxes);
                delta = nwpt - ppt;
                ppt = nwpt;
                
                %                 nwctr = obj.selectedObj.centerXY(obj.projectionDim)+delta(1);
                nwz = nwpt(2);
                
                % snap to interesting zs
                [dist,i] = min(abs(nwz-snapZs));
                if dist < diff(obj.zProjectionRange)/100
                    nwz = snapZs(i);
                else
                    nwz = floor(nwz*100)/100;
                end
                
                obj.enableListeners = false;
                id = find(obj.selectedObjParent.scanfields == obj.selectedObj);
                [tf,idx] = ismember(nwz,obj.selectedObjParent.zs);
                if tf && (idx ~= id)
                    nwz = nwz + 0.0000001;
                end
                obj.selectedObjParent.moveSfById(id,nwz);
                %                 obj.selectedObj.centerXY(obj.projectionDim) = nwctr;
                obj.updateScanPathCache();
                obj.enableListeners = true;
                
                obj.editorZ = nwz;
                
                if nwz < obj.zProjectionRange(1)
                    obj.zProjectionRange(1) = nwz;
                elseif nwz > obj.zProjectionRange(2)
                    obj.zProjectionRange(2) = nwz;
                end
                
                obj.selectedObjChanged();
            end
        end
        
        function fovSurfHit(obj,src,evt)
            persistent lastPt;
            persistent obluem;
            
            if strcmp(evt.EventName, 'Hit')
                lastPt = obj.h2DMainViewAxes.CurrentPoint(1,1:2);
                set(obj.hFig,'WindowButtonMotionFcn',@obj.fovSurfHit,'WindowButtonUpFcn',@obj.fovSurfHit);
                
                if obj.slmBitmapBrushEnable
                    obluem = double(obj.h2DScannerFovSurf.CData(:,:,3))/255;
                    slmPt = evt.IntersectionPoint([1 2]) - obj.slmPatternSfParent.centerXY;
                    applyBrush(slmPt);
                end
            elseif strcmp(evt.EventName, 'WindowMouseMotion')
                if obj.slmBitmapBrushEnable
                    slmPt = obj.h2DMainViewAxes.CurrentPoint(1,1:2) - obj.slmPatternSfParent.centerXY;
                    applyBrush(slmPt);
                else
                    cp = obj.h2DMainViewAxes.CurrentPoint(1,1:2);
                    ctr = obj.slmPatternSfParent.centerXY;
                    
                    obj.enableListeners = false;
                    
                    obj.slmPatternSfParent.centerXY = ctr + cp - lastPt;
                    
                    % apply constraints
                    obj.satisfyConstraints(obj.slmPatternSfParent);
                    d = obj.slmPatternSfParent.centerXY - ctr;
                    
                    % move slm pattern?
                    % if it is a point array and shift is held OR if it is a bitmap
                    if ismember('shift', get(obj.hFig, 'currentModifier')) || obj.slmPatternTypeIsBitmap
                        for roi = obj.editingGroup.rois
                            roi.scanfields(1).centerXY = roi.scanfields(1).centerXY + d;
                        end
                        obj.updateScanPathCache();
                        obj.updateDisplay();
                    end
                    
                    obj.enableListeners = true;
                    
                    % update fov
                    obj.updateFovLines()
                    
                    lastPt = cp;
                end
            else
                if obj.slmBitmapBrushEnable
                    obj.hFig.WindowButtonMotionFcn = @obj.brushHover;
                    obj.slmPatternSfParent.slmPattern = double(obj.h2DScannerFovSurf.CData(:,:,3))/255;
                else
                    obj.hFig.WindowButtonMotionFcn = [];
                end
                obj.hFig.WindowButtonUpFcn = [];
                obj.updateTable();
            end
            
            function applyBrush(pt)
                % identify region affected
                [ptis, rs] = findBrushAffectedInds(obj,pt);
                
                % cache vals
                ocdat = obj.h2DScannerFovSurf.CData;
                ocdatbm = double(ocdat(:,:,3));
                sep = obj.slmBitmapBrushSoftEdgePct;
                
                % determine blue map values with soft edge
                % in order to prevent the soft edge from getting darkened
                % as the brush moves, we do a gradient from a cached
                % version of the bitmap from before this stroke started
                ovws = min(1,max(0,(sep - (1-rs)) / sep)); % old val weights
                bvs = (1-ovws) * obj.slmBitmapBrushValue + ovws.*obluem(ptis);
                
                % decide whether the new value is better
                omap = ocdatbm(ptis)/255;
                diffso = abs(obluem(ptis) - omap);
                diffsn = abs(obluem(ptis) - bvs);
                msk = diffsn < diffso;
                bvs(msk) = omap(msk);
                
                % apply new blue mask
                ocdatbm(ptis) = bvs * 255;
                ocdat(:,:,3) = uint8(ocdatbm);
                
                % calc and apply red mask
                rm = zeros(size(ocdatbm),'uint8');
                rvs = (1-ovws);
                rm(ptis) = uint8(min(rvs*255,ocdatbm(ptis)));
                ocdat(:,:,1) = rm;
                
                % determine green map values with soft edge
                ovws = min(1,max(0,(sep - (1-rs)) / sep)); % old val weights
                gvs = (1-ovws) + ovws.*ocdatbm(ptis)/255;
                
                % apply new green mask
                ocdatbm(ptis) = gvs * 255;
                ocdat(:,:,2) = uint8(ocdatbm);
                
                obj.h2DScannerFovSurf.CData = ocdat;
            end
        end
        
        function bufferSlmPixelMesh(obj)
            ss = obj.scannerSet;
            if isa(ss,'scanimage.mroi.scannerset.GalvoGalvo')
                ss = ss.slm;
            end
            
            z_ref = scanimage.mroi.coordinates.Points(ss.hCSReference,[0,0,0]);
            z_ref = z_ref.transform(ss.scanners{1}.hCoordinateSystem);
            z_slm = z_ref.points(3);
            
            res = ss.scanners{1}.hDevice.pixelResolutionXY;
            [xx_mesh,yy_mesh,zz_mesh] = meshgrid(1:res(1),1:res(2),z_slm);
            mesh = [xx_mesh(:),yy_mesh(:),zz_mesh(:)];
            mesh = scanimage.mroi.coordinates.Points(ss.scanners{1}.hCSPixel,mesh);
            mesh = mesh.transform(obj.scannerSet.hCSReference);
            mesh = mesh.points(:,1:2);
            
            obj.slmPixelMeshBuffer.mesh = mesh;
            obj.slmPixelMeshBuffer.boundsx = [min(mesh(:,1)) max(mesh(:,1))];
            obj.slmPixelMeshBuffer.boundsy = [min(mesh(:,2)) max(mesh(:,2))];
            obj.slmPixelMeshBuffer.needsBsxfun = verLessThan('matlab','9.1.0'); %implicit expansion is supported starting Matlab 2016b
        end
        
        function [inds, rs] = findBrushAffectedInds(obj,pt)
            ss = obj.scannerSet;
            if isa(ss,'scanimage.mroi.scannerset.GalvoGalvo')
                ss = ss.slm;
            end
            
            % determine brush size in reference space
            pts = [0                      0 0
                obj.slmBitmapBrushSize 0 0];
            pts = scanimage.mroi.coordinates.Points(ss.scanners{1}.hCSPixel,pts);
            pts = pts.transform(obj.scannerSet.hCSReference);
            pts = pts.points;
            brushSize = norm(pts(1,:)-pts(2,:));
            
            outOfBounds = (pt(1)+brushSize/2)<obj.slmPixelMeshBuffer.boundsx(1) || (pt(1)-brushSize/2)>obj.slmPixelMeshBuffer.boundsx(2) || ...
                (pt(2)+brushSize/2)<obj.slmPixelMeshBuffer.boundsy(1) || (pt(2)-brushSize/2)>obj.slmPixelMeshBuffer.boundsy(2);
            
            if outOfBounds
                inds = [];
                rs = [];
                return
            end
            
            if obj.slmPixelMeshBuffer.needsBsxfun
                mesh_pt = bsxfun(@minus,obj.slmPixelMeshBuffer.mesh,pt);
            else
                mesh_pt = obj.slmPixelMeshBuffer.mesh - pt;
            end
            
            mesh_pt = mesh_pt.^2;
            rs_squared = sum(mesh_pt,2);
            
            inds = find(rs_squared<brushSize^2);
            rs = sqrt(rs_squared(inds))/brushSize;
        end
        
        function brushHover(obj,varargin)
            ocdat = obj.h2DScannerFovSurf.CData;
            
            % reset and cache the green mask
            gm = ocdat(:,:,3);
            rm = zeros(size(gm),'uint8');
            
            % find the hover point
            cp = obj.h2DMainViewAxes.CurrentPoint(1,1:2) - obj.slmPatternSfParent.centerXY;
            
            % find affected points
            [ptinds, rs] = findBrushAffectedInds(obj,cp);
            
            % determine value with soft edge
            sep = obj.slmBitmapBrushSoftEdgePct;
            ovws = min(1,max(0,(sep - (1-rs)) / sep)); % old val weights
            gvs = (1-ovws) + ovws.*double(gm(ptinds))/255;
            rvs = (1-ovws) + ovws.*double(rm(ptinds))/255;
            
            % update maps
            rm(ptinds) = uint8(255*rvs);
            rm = min(rm,gm); % this makes brush tool green to white instead of yellow to white
            gm(ptinds) = uint8(255*gvs);
            
            ocdat(:,:,1) = rm;
            ocdat(:,:,2) = gm;
            obj.h2DScannerFovSurf.CData = ocdat;
        end
        
        function draw3D(obj,rois)
            obj.deleteDrawData();
            
            minz = min(obj.interestingZs);
            maxz = max(obj.interestingZs);
            
            if ~isempty(obj.scanPathCache)
                if isfield(obj.scanPathCache, 'Z')
                    minz = min([minz; obj.scanPathCache.Z(:)]);
                    maxz = max([maxz; obj.scanPathCache.Z(:)]);
                end
                
                if isfield(obj.scanPathCache,'SLM')
                    SLMPoints = {obj.scanPathCache.SLM.pattern};
                    ptMask = cellfun(@(p)size(p,2)==4,SLMPoints); % filter out bitmaps
                    SLMPoints = SLMPoints(ptMask);
                    SLMPoints = vertcat(SLMPoints{:});
                    
                    if ~isempty(SLMPoints)
                        minz = min([minz; SLMPoints(:,3)]);
                        maxz = max([maxz; SLMPoints(:,3)]);
                    end
                end
            end
            
            d = max(maxz - minz,10)/20;
            rg = [minz maxz] + [-d d];
            
            numNonPauseRois = (obj.editorModeIsStim || obj.editorModeIsSlm) && numNonPause(obj.editingGroup) > 0;
            
            for iter = 1:numel(obj.editingGroup.rois)
                if obj.selectedObjRoiIdx == iter
                    col = 'g';
                    drawtf = obj.showSelectedRoi;
                else
                    col = 'r';
                    drawtf = obj.showOtherRois;
                end
                
                if drawtf
                    if obj.editorModeIsStim || obj.editorModeIsSlm
                        obj.drawData{iter} = drawStim(obj.editingGroup.rois(iter),iter,col);
                    else
                        obj.drawData{iter} = drawRoi(obj.editingGroup.rois(iter),col,rg(1),rg(2));
                    end
                end
            end
            
            if isempty(obj.drawData)
                obj.drawData = {{}};
            end
            
            fov = [-1 1] * obj.mainViewFovLim/2;
            obj.h3DViewAxes.XLim = fov * obj.xyUnitFactor + obj.xyUnitOffset(1);
            obj.h3DViewAxes.YLim = fov * obj.xyUnitFactor + obj.xyUnitOffset(2);
            obj.h3DViewAxes.ZLim = rg;
            
            set(obj.h3DImagingPlaneSurfs, 'XData', obj.h3DViewAxes.XLim);
            set(obj.h3DImagingPlaneSurfs, 'YData', obj.h3DViewAxes.YLim);
            
            function handles = drawRoi(roi, c, minz, maxz)
                zs = roi.zs;
                handles = {};
                
                if numel(zs) == 1
                    sf = roi.get(zs(1));
                    if ~isnan(sf)
                        mesh = getSfMesh(sf);
                        baseAndSides(mesh, mesh, zs(1), minz, maxz, c)
                    end
                elseif numel(zs) > 1
                    %first plane
                    psf = roi.get(zs(1));
                    pmesh = getSfMesh(psf);
                    handles{end+1} = surface(pmesh{1}, pmesh{2}, zs(1)*ones(2),'FaceColor',c,'facealpha',.5,'edgecolor',c,'linewidth',2,'parent',obj.h3DViewAxes,'ButtonDownFcn',@obj.roiHit,'UserData',roi.uuiduint64);
                    
                    for i = 2:numel(zs)
                        sf = roi.get(zs(i));
                        mesh = getSfMesh(sf);
                        baseAndSides(mesh, pmesh, zs(i), zs(i), zs(i-1), c)
                        pmesh = mesh;
                    end
                end
                
                function mesh = getSfMesh(sf)
                    [xx,yy] = sf.meshgridOutline(2);
                    xx = xx .* obj.xyUnitFactor + obj.xyUnitOffset(1);
                    yy = yy .* obj.xyUnitFactor + obj.xyUnitOffset(2);
                    mesh = {xx,yy};
                end
                
                function pt = getMeshCenterPt(mesh)
                    xx = mesh{1};
                    yy = mesh{2};
                    pt = [xx(1)+xx(end),yy(1)+yy(end)]/2;
                end
                
                function baseAndSides(mesh1,mesh2, pz, z1, z2, col)
                    handles{end+1} = surface(mesh1{1},mesh1{2},pz*ones(2),'FaceColor',col,'facealpha',.5,'edgecolor',col,'linewidth',2,'parent',obj.h3DViewAxes,'ButtonDownFcn',@obj.roiHit,'UserData',roi.uuiduint64);
                    
                    if roi.discretePlaneMode
                        if numel(roi.scanfields) > 1
                            centerPt1 = getMeshCenterPt(mesh1);
                            centerPt2 = getMeshCenterPt(mesh2);
                            handles{end+1} = line([centerPt1(1) centerPt2(1)],[centerPt1(2) centerPt2(2)], [z1 z2],'linewidth',1,'linestyle',':','color',col,'parent',obj.h3DViewAxes,'ButtonDownFcn',@obj.roiHit,'UserData',roi.uuiduint64);
                        end
                    else
                        sideprops = {'FaceColor',col,'facealpha',.1,'edgecolor',col,'linewidth',2,'LineStyle','--','parent',obj.h3DViewAxes,'ButtonDownFcn',@obj.roiHit,'UserData',roi.uuiduint64};
                        %top side
                        handles{end+1} = surface([mesh1{1}(1,:);mesh2{1}(1,:)],[mesh1{2}(1,:);mesh2{2}(1,:)],[z1 z1; z2 z2],sideprops{:});
                        %bottom side
                        handles{end+1} = surface([mesh1{1}(2,:);mesh2{1}(2,:)],[mesh1{2}(2,:);mesh2{2}(2,:)],[z1 z1; z2 z2],sideprops{:});
                        %left side
                        handles{end+1} = surface([mesh1{1}(:,1),mesh2{1}(:,1)],[mesh1{2}(:,1),mesh2{2}(:,1)],[z1 z2; z1 z2],sideprops{:});
                        %right side
                        handles{end+1} = surface([mesh1{1}(:,2),mesh2{1}(:,2)],[mesh1{2}(:,2),mesh2{2}(:,2)],[z1 z2; z1 z2],sideprops{:});
                    end
                end
            end
            
            function handles = drawStim(roi, it, c)
                handles = {};
                if numNonPauseRois
                    path = obj.getStimPts(it,roi.scanfields(1));
                    
                    lxpts = path.G(:,1);
                    lypts = path.G(:,2);
                    lzpts = path.Z;
                    
                    if roi.scanfields(1).isPause || roi.scanfields(1).isPark
                        drP = false;
                        linestyle = ':';
                        numSlmPoints = 0;
                    else
                        linestyle = '-';
                        drP = all(lxpts == lxpts(end)) && all(lypts == lypts(end)) && all(lzpts == lzpts(end));
                        
                        slmPattern = roi.scanfields(1).slmPattern;
                        if size(slmPattern,2)==4
                            numSlmPoints = size(slmPattern,1);
                        else
                            numSlmPoints = 0; % ignore bitmap
                        end
                    end
                    
                    if numSlmPoints > 0
                        lxptsSlm = repmat(lxpts,1,numSlmPoints);
                        lyptsSlm = repmat(lypts,1,numSlmPoints);
                        lzptsSlm = repmat(lzpts,1,numSlmPoints) * 0;
                        
                        zeroOrderXYZ = [roi.scanfields(1).centerXY(:)' 0];
                        lxptsSlm = lxptsSlm + slmPattern(:,1)' - zeroOrderXYZ(1);
                        lyptsSlm = lyptsSlm + slmPattern(:,2)' - zeroOrderXYZ(2);
                        lzptsSlm = lzptsSlm + slmPattern(:,3)' - zeroOrderXYZ(3);
                        
                        lxptsSlm(end+1,:) = NaN;
                        lyptsSlm(end+1,:) = NaN;
                        lzptsSlm(end+1,:) = NaN;
                        
                        % draw zero order
                        handles{end+1} = line(zeroOrderXYZ(1) * obj.xyUnitFactor + obj.xyUnitOffset(1), zeroOrderXYZ(2) * obj.xyUnitFactor + obj.xyUnitOffset(2), zeroOrderXYZ(3),...
                            'linestyle','none','Marker','p','MarkerEdgeColor',col,'MarkerFaceColor',col,'Markersize',10,'parent',obj.h3DViewAxes,'ButtonDownFcn',@obj.roiHit,'UserData',roi.uuiduint64);
                        
                        % draw patterns
                        handles{end+1} = line(lxptsSlm(:) * obj.xyUnitFactor + obj.xyUnitOffset(1), lyptsSlm(:) * obj.xyUnitFactor + obj.xyUnitOffset(2), lzptsSlm(:),...
                            'color',c,'linewidth',2,'linestyle',linestyle,'parent',obj.h3DViewAxes,'ButtonDownFcn',@obj.roiHit,'UserData',roi.uuiduint64);
                        
                        if drP
                            handles{end+1} = line(lxptsSlm(1,:) * obj.xyUnitFactor + obj.xyUnitOffset(1), lyptsSlm(1,:) * obj.xyUnitFactor + obj.xyUnitOffset(2), lzptsSlm(1,:),...
                                'linestyle','none','Marker','o','MarkerEdgeColor',col,'MarkerFaceColor',col,'Markersize',10,'parent',obj.h3DViewAxes,'ButtonDownFcn',@obj.roiHit,'UserData',roi.uuiduint64);
                        end
                    else
                        
                        handles{end+1} = line(lxpts * obj.xyUnitFactor + obj.xyUnitOffset(1), lypts * obj.xyUnitFactor + obj.xyUnitOffset(2), lzpts,...
                            'color',c,'linewidth',2,'linestyle',linestyle,'parent',obj.h3DViewAxes,'ButtonDownFcn',@obj.roiHit,'UserData',roi.uuiduint64);
                        
                        if drP
                            handles{end+1} = line(lxpts(end) * obj.xyUnitFactor + obj.xyUnitOffset(1), lypts(end) * obj.xyUnitFactor + obj.xyUnitOffset(2), lzpts(end),...
                                'linestyle','none','Marker','o','MarkerEdgeColor',col,'MarkerFaceColor',col,'Markersize',10,'parent',obj.h3DViewAxes,'ButtonDownFcn',@obj.roiHit,'UserData',roi.uuiduint64);
                        end
                    end
                end
            end
        end
        
        function updateZs(obj, varargin)
            zs = obj.siZs;
            
            obj.n3dip = min(numel(zs),500);
            Ns = numel(obj.h3DImagingPlaneSurfs);
            for i = 1:obj.n3dip
                if i > Ns
                    obj.h3DImagingPlaneSurfs(end+1) = surface(obj.h3DViewAxes.XLim,obj.h3DViewAxes.YLim,ones(2),'FaceColor','w','facealpha',.1,'edgecolor','w','linewidth',1,'parent',obj.h3DViewAxes,'hittest','off','PickableParts','none');
                end
                obj.h3DImagingPlaneSurfs(i).ZData = zs(i)*ones(2);
            end
            set(obj.h3DImagingPlaneSurfs(1:obj.n3dip),'Visible',obj.tfMap(obj.showImagingZs));
            set(obj.h3DImagingPlaneSurfs(obj.n3dip+1:end),'Visible','off');
            
            yd = [zs;zs;nan(1,numel(zs))];
            obj.h2DImagingPlaneLines.XData = repmat([-999999 999999 nan],1,numel(zs));
            obj.h2DImagingPlaneLines.YData = yd(:)';
            
            obj.setZProjectionLimits();
        end
        
        function updateFocalPointZ(obj, varargin)
            hPtFocus = scanimage.mroi.coordinates.Points(obj.hModel.hCoordinateSystems.hCSFocus,[0,0,0]);
            hPtFocusRef = hPtFocus.transform(obj.hModel.hCoordinateSystems.hCSSampleRelative);
            
            focusRefZ = hPtFocusRef.points(1,3);
                
            obj.h2DFocusPlaneLine.XData = [-999999 999999 nan];
            obj.h2DFocusPlaneLine.YData = [focusRefZ focusRefZ nan];
        end
        
        function setZProjectionLimits(obj)
            obj.interestingZs = sort(unique([obj.siZs obj.editingGroup.zs obj.hContextImages.zs]));
            obj.maxInterestingZ = max(obj.interestingZs);
            obj.minInterestingZ = min(obj.interestingZs);
            
            mddl = (obj.maxInterestingZ + obj.minInterestingZ) / 2;
            rg = max(obj.maxInterestingZ - obj.minInterestingZ,20);
            
            obj.zProjectionDefaultRange = [mddl-rg*.6 mddl+rg*.6];
            
            defaultMaxLimit = 1e6; % 1 meter
            maxLimit = max([ abs(obj.interestingZs(:)') defaultMaxLimit ]);
            obj.zProjectionLimits = maxLimit * [-1 1];
            
            obj.zProjectionRange = obj.zProjectionRange;
            
            if obj.editorZ < obj.zProjectionLimits(1) || obj.editorZ > obj.zProjectionLimits(2)
                obj.editorZ = obj.editorZ;
            end
        end
        
        function chgName(obj,varargin)
            if most.idioms.isValidObj(obj.editingGroup)
                obj.editingGroup.name = obj.etName.String;
            else
                obj.etName.String = '';
            end
        end
        
        function op = getStimParamOptions(obj,n)
            if isfield(obj.stimFcnParamOptions,n)
                op = obj.stimFcnParamOptions.(n);
            else
                op = {};
            end
        end
        
        function nameChanged(obj,varargin)
            obj.etName.String = obj.editingGroup.name_;
        end
        
        function moveButton(obj,ammt)
            if obj.editorModeIsStim
                selObj = obj.selectedObjParent;
            else
                selObj = obj.selectedObj;
            end
            
            obj.enableListeners = false;
            obj.editingGroup.moveById(selObj.uuiduint64,ammt);
            obj.enableListeners = true;
            obj.updateScanPathCache();
            obj.updateTable();
            obj.updateMoveButtons();
            obj.updateDisplay();
        end
        
        function roiPropsPanelUpdate(obj)
            obj.hImagingRoiPropsPanelCtls.etName.hCtl.String = obj.selectedObj.name_;
            obj.hImagingRoiPropsPanelCtls.etUUID.hCtl.String = obj.selectedObj.uuid;
            obj.hImagingRoiPropsPanelCtls.cbEnable.hCtl.Value = obj.selectedObj.enable;
            obj.hImagingRoiPropsPanelCtls.cbDisplay.hCtl.Value = obj.selectedObj.display;
            obj.hImagingRoiPropsPanelCtls.cbDiscrete.hCtl.Value = obj.selectedObj.discretePlaneMode;
            obj.hImagingRoiPropsPanelCtls.etCPs.hCtl.String = numel(obj.selectedObj.zs);
            
            if obj.selectedObj.discretePlaneMode || (numel(obj.selectedObj.zs) > 1)
                obj.hImagingRoiPropsPanelCtls.etZmin.hCtl.String = min(obj.selectedObj.zs);
                obj.hImagingRoiPropsPanelCtls.etZmax.hCtl.String = max(obj.selectedObj.zs);
            else
                obj.hImagingRoiPropsPanelCtls.etZmin.hCtl.String = '-inf';
                obj.hImagingRoiPropsPanelCtls.etZmax.hCtl.String = 'inf';
            end
            
            if isempty(obj.selectedObj.powers)
                obj.hImagingRoiPropsPanelCtls.etPowers.hCtl.String = '[default]';
            else
                obj.hImagingRoiPropsPanelCtls.etPowers.hCtl.String = num2str(obj.selectedObj.powers);
            end
            
            if isempty(obj.selectedObj.pzAdjust)
                obj.hImagingRoiPropsPanelCtls.etPZ.hCtl.String = '[default]';
            else
                obj.hImagingRoiPropsPanelCtls.etPZ.hCtl.String = num2str(obj.selectedObj.pzAdjust);
            end
            
            if isempty(obj.selectedObj.Lzs)
                obj.hImagingRoiPropsPanelCtls.etLzs.hCtl.String = '[default]';
            else
                obj.hImagingRoiPropsPanelCtls.etLzs.hCtl.String = num2str(obj.selectedObj.Lzs);
            end
        end
        
        function roiPropsPanelCtlCb(obj,src,~)
            obj.enableListeners = false;
            
            try
                switch(src.Tag)
                    case 'etName'
                        obj.selectedObj.name = src.String;
                        
                    case 'cbEnable'
                        obj.selectedObj.enable = src.Value;
                        
                    case 'cbDisplay'
                        obj.selectedObj.display = src.Value;
                        
                    case 'cbDiscrete'
                        obj.selectedObj.discretePlaneMode = src.Value;
                        
                    case 'etPowers'
                        obj.selectedObj.powers = str2num(src.String);
                        
                    case 'etPZ'
                        obj.selectedObj.pzAdjust = str2num(src.String);
                        
                    case 'etLzs'
                        obj.selectedObj.Lzs = str2num(src.String);
                end
            catch ME
                cleanup();
                ME.rethrow();
            end
            
            cleanup();
            
            %%% Nested function            
            function cleanup()
                obj.enableListeners = true;
                obj.updateTable();
                obj.setZProjectionLimits();
                obj.updateDisplay();
                obj.roiPropsPanelUpdate();
            end
        end
        
        function stimRoiPropsPanelUpdate(obj)
            obj.hStimRoiPropsPanelCtls.etZ.hCtl.String = obj.selectedObjParent.zs(1);
            if most.idioms.isValidObj(obj.selectedObj)
                obj.hStimRoiPropsPanelCtls.etCenterX.hCtl.String = obj.selectedObj.centerXY(1) * obj.xyUnitFactor + obj.xyUnitOffset(1);
                obj.hStimRoiPropsPanelCtls.etCenterY.hCtl.String = obj.selectedObj.centerXY(2) * obj.xyUnitFactor + obj.xyUnitOffset(2);
                obj.hStimRoiPropsPanelCtls.etWidth.hCtl.String = obj.selectedObj.sizeXY(1) * obj.xyUnitFactor;
                obj.hStimRoiPropsPanelCtls.etHeight.hCtl.String = obj.selectedObj.sizeXY(2) * obj.xyUnitFactor;
                obj.hStimRoiPropsPanelCtls.etRotation.hCtl.String = obj.selectedObj.rotation;
                
                stimfcnname = regexpi(func2str(obj.selectedObj.stimfcnhdl),'[^\.]*$','match');
                stimfcnoptions = obj.hStimRoiPropsPanelCtls.pmFunction.hCtl.String;
                
                [~,obj.hStimRoiPropsPanelCtls.pmFunction.hCtl.Value] = ismember(stimfcnname,stimfcnoptions);
                obj.hStimRoiPropsPanelCtls.etArgs.ParameterOptions = obj.getStimParamOptions(stimfcnname{1});
                obj.hStimRoiPropsPanelCtls.etArgs.Value = obj.selectedObj.stimparams;
                
                
                shwSlm = (isa(obj.scannerSet,'scanimage.mroi.scannerset.SLM') || ~isempty(obj.scannerSet.slm)) && ~ismember(stimfcnname, {'pause' 'park' 'waypoint'});
                obj.hStimRoiPropsPanelCtls.slmFlow.Visible = obj.tfMap(shwSlm);
                if shwSlm
                    h = 164;
                else
                    h = 144;
                end
                obj.hStimRoiPropsPanelCtls.paramPanel.HeightLimits = [h h];
                
                if isempty(obj.selectedObj.slmPattern)
                    obj.hStimRoiPropsPanelCtls.pbEditSlm.String = 'Create';
                    obj.hStimRoiPropsPanelCtls.etPattern.String = 'None';
                else
                    obj.hStimRoiPropsPanelCtls.pbEditSlm.String = 'Clear';
                    if size(obj.selectedObj.slmPattern,2) > 4
                        obj.hStimRoiPropsPanelCtls.etPattern.String = 'Bitmap';
                    else
                        obj.hStimRoiPropsPanelCtls.etPattern.String = 'Points';
                    end
                end
                
                obj.hStimRoiPropsPanelCtls.etDuration.hCtl.String = obj.selectedObj.duration*1000;
                obj.hStimRoiPropsPanelCtls.etReps.hCtl.String = obj.selectedObj.repetitions;
                obj.hStimRoiPropsPanelCtls.etPower.hCtl.String = num2str(obj.selectedObj.powers);
            else
                obj.hStimRoiPropsPanelCtls.etCenterX.hCtl.String = '';
                obj.hStimRoiPropsPanelCtls.etCenterY.hCtl.String = '';
                obj.hStimRoiPropsPanelCtls.etWidth.hCtl.String = '';
                obj.hStimRoiPropsPanelCtls.etHeight.hCtl.String = '';
                obj.hStimRoiPropsPanelCtls.etRotation.hCtl.String = '';
                
                obj.hStimRoiPropsPanelCtls.etArgs.Value = {};
                obj.hStimRoiPropsPanelCtls.etDuration.hCtl.String = '';
                obj.hStimRoiPropsPanelCtls.etReps.hCtl.String = '';
                obj.hStimRoiPropsPanelCtls.etPower.hCtl.String = '';
            end
        end
        
        function stimRoiPropsPanelCtlCb(obj,src,~)
            obj.enableListeners = false;
            dud = false;
            switch(src.Tag)
                case 'etZ'
                    z = str2num(src.String);
                    if ~isempty(z) && ~isnan(z) && ~isinf(z)
                        obj.selectedObjParent.moveSfById(1,z);
                        if ~obj.selectedObj.isPause
                            obj.updateScanPathCache();
                            obj.editorZ = z;
                            dud = true;
                        end
                    else
                        most.idioms.warn('Z value must be a valid number. NaN and Inf are not allowed. Resetting to previous value.');
                    end
                    
                case 'etCenterX'
                    centerX = str2num(src.String);
                    
                    if ~isempty(obj.xyUnitFactor) && (obj.xyUnitFactor ~= 0)
                        if ~isempty(centerX) && ~isnan(centerX) && ~isinf(centerX)
                            obj.selectedObj.centerXY(1) = (centerX - obj.xyUnitOffset(1)) / obj.xyUnitFactor;
                        else
                            most.idioms.warn('Center X value must be a valid number. NaN and Inf are not allowed. Resetting to previous value.');
                        end
                    else
                        most.idioms.warn('XY UnitFactor must contain a numeric, non-zero value. Resetting Center X to previous value.');
                    end
                    
                case 'etCenterY'
                    centerY = str2num(src.String);
                    
                    if ~isempty(obj.xyUnitFactor) && (obj.xyUnitFactor ~= 0)
                        if ~isempty(centerY) && ~isnan(centerY) && ~isinf(centerY)
                            obj.selectedObj.centerXY(2) = (centerY - obj.xyUnitOffset(2)) / obj.xyUnitFactor;
                        else
                            most.idioms.warn('Center Y value must be a valid number. NaN and Inf are not allowed. Resetting to previous value.');
                        end
                    else
                        most.idioms.warn('XY UnitFactor must contain a numeric, non-zero value. Resetting Center Y to previous value.');
                    end
                    
                case 'etWidth'
                    etwidth = str2num(src.String);
                    
                    if ~isempty(obj.xyUnitFactor) && (obj.xyUnitFactor ~= 0)
                        if ~isempty(etwidth) && ~isnan(etwidth) && ~isinf(etwidth)
                            obj.selectedObj.sizeXY(1) = etwidth / obj.xyUnitFactor;
                        else
                            most.idioms.warn('NaN and Inf are not allowed for width. Resetting to previous value.');
                        end
                    else
                        most.idioms.warn('XY UnitFactor must contain a numeric, non-zero value. Resetting Width to previous value.');
                    end
                    
                case 'etHeight'
                    etheight = str2num(src.String);
                    
                    if ~isempty(obj.xyUnitFactor) && (obj.xyUnitFactor ~= 0)
                        if ~isempty(etheight) && ~isnan(etheight) && ~isinf(etheight)
                            obj.selectedObj.sizeXY(2) = etheight / obj.xyUnitFactor;
                        else
                            most.idioms.warn('NaN and Inf is not allowed for height. Resetting to previous value.');
                        end
                    else
                        most.idioms.warn('XY UnitFactor must contain a numeric, non-zero value. Resetting Height to previous value.');
                    end
                    
                case 'etRotation'
                    etrotation = str2num(src.String);
                    
                    if ~isempty(etrotation) && ~isnan(etrotation) && ~isinf(etrotation)
                        obj.selectedObj.rotation = etrotation;
                    else
                        most.idioms.warn('Rotation value must be a valid number. NaN and Inf are not allowed. Resetting to previous value.');
                    end
                    
                case 'pmFunction'
                    options = src.String;
                    fn = options{src.Value};
                    stimfcnname = sprintf('scanimage.mroi.stimulusfunctions.%s',fn);
                    obj.selectedObj.stimfcnhdl  = str2func(stimfcnname);
                    if ismember(fn, {'pause' 'park' 'waypoint'})
                        obj.selectedObj.slmPattern = [];
                    end
                    
                case 'etArgs'
                    obj.selectedObj.stimparams = src.Value;
                    
                case 'etDuration'
                    etduration = str2num(src.String);
                    
                    if ~isempty(etduration) && ~isnan(etduration) && ~isinf(etduration) && (etduration > 0)
                        obj.selectedObj.duration = etduration/1000;
                    else
                        most.idioms.warn('Duration value must be a valid number. NaN and Inf are not allowed. Resetting to previous value.');
                    end
                    
                case 'etReps'
                    etreps = str2num(src.String);
                    
                    if ~isempty(etreps) && ~isnan(etreps) && ~isinf(etreps) && (etreps > 0) && (round(etreps) == etreps)
                        obj.selectedObj.repetitions = etreps;
                    else
                        most.idioms.warn('Repititions must be a valid positive integer. NaN and Inf are not allowed. Resetting to previous value.');
                    end
                    
                case 'etPower'
                    etpower = str2num(src.String);
                    
                    if ~isempty(etpower) && ~any(isinf(etpower))
                        obj.selectedObj.powers = etpower;
                    else
                        most.idioms.warn('Beam Power must be a valid number or vector. Inf is not allowed. Resetting to previous value.');
                    end
            end
            obj.enableListeners = true;
            obj.stimRoiPropsPanelUpdate();
            obj.satisfyConstraints(obj.selectedObj);
            obj.updateTable();
            obj.setZProjectionLimits();
            
            if ~dud
                obj.updateScanPathCache();
                obj.updateDisplay();
            end
            %most.idioms.info('ROI position/size data typed directly into edit fields may have been altered due to contraints based on your scanner system.');
        end
        
        function editSlmPattern(obj,varargin)
            obj.slmPatternRoiGroupParent = obj.editingGroup;
            obj.setEditorGroupAndMode(obj.selectedObjParent,obj.scannerSet,'slm');
        end
        
        function editOrClearSlmPattern(obj,varargin)
            if isempty(obj.selectedObj.slmPattern)
                if isempty(obj.selectedObj.slmPattern)
                    % converting to an SLM pattern. Figure out best
                    % place to point galvos taking zero order beam
                    % block and slm fov into account
                    r = obj.scannerSet.slm.zeroOrderBlockRadius;
                    if r
                        % deflect y just outside zero order beam block
                        y  = - r * obj.scannerSet.slm.scannerToRefTransform(5) * 2;
                    else
                        % no zero order beam block. point galvos
                        % directly at spot and make slm pattern zero
                        y = 0;
                    end
                    obj.selectedObj.slmPattern = [0 y obj.selectedObjParent.zs(1) 1];
                    obj.selectedObj.centerXY = obj.selectedObj.centerXY - [0 y];
                end
                obj.editSlmPattern;
            else
                obj.selectedObj.slmPattern = [];
            end
        end
        
        function updateSlmPattern(obj)
            if ~obj.slmPatternTypeIsBitmap
                pat = zeros(numel(obj.editingGroup.rois),4);
                sfCenterXY = obj.slmPatternSfParent.centerXY;
                for i = 1:numel(obj.editingGroup.rois)
                    pat(i,:) = [obj.editingGroup.rois(i).scanfields(1).centerXY - sfCenterXY obj.editingGroup.rois(i).zs(1) obj.editingGroup.rois(i).scanfields(1).powers];
                end
                obj.slmPatternSfParent.slmPattern = pat;
            end
        end
        
        function finishSlmEdit(obj,varargin)
            obj.updateSlmPattern();
            
            obj.setEditorGroupAndMode(obj.slmPatternRoiGroupParent,obj.scannerSet,'stimulation');
            obj.changeSelection(obj.slmPatternSfParent,obj.slmPatternRoiParent);
            obj.fixTableCheck();
        end
        
        function analysisRoiPropsPanelUpdate(obj)
            obj.hAnalysisRoiPropsPanelCtls.etName.hCtl.String = obj.selectedObj.name_;
            obj.hAnalysisRoiPropsPanelCtls.etUUID.hCtl.String = obj.selectedObj.uuid;
            obj.hAnalysisRoiPropsPanelCtls.cbEnable.hCtl.Value = obj.selectedObj.enable;
            obj.hAnalysisRoiPropsPanelCtls.cbDisplay.hCtl.Value = obj.selectedObj.display;
            obj.hAnalysisRoiPropsPanelCtls.cbDiscrete.hCtl.Value = obj.selectedObj.discretePlaneMode;
            obj.hAnalysisRoiPropsPanelCtls.etCPs.hCtl.String = numel(obj.selectedObj.zs);
            
            obj.hAnalysisRoiPropsPanelCtls.etZmin.hCtl.String = min(obj.selectedObj.zs);
            obj.hAnalysisRoiPropsPanelCtls.etZmax.hCtl.String = max(obj.selectedObj.zs);
            
            if numel(obj.selectedObj.scanfields)
                obj.hAnalysisRoiPropsPanelCtls.pmChannel.hCtl.Value = obj.selectedObj.scanfields(1).channel;
                obj.hAnalysisRoiPropsPanelCtls.etThreshold.hCtl.String = obj.selectedObj.scanfields(1).threshold;
                obj.hAnalysisRoiPropsPanelCtls.pmProcessor.hCtl.Value = obj.procMap(lower(obj.selectedObj.scanfields(1).processor));
            end
        end
        
        function analysisRoiPropsPanelCtlCb(obj,src,~)
            obj.enableListeners = false;
            switch src.Tag
                case 'etName'
                    obj.selectedObj.name = src.String;
                    
                case 'cbEnable'
                    obj.selectedObj.enable = src.Value;
                    
                case 'cbDisplay'
                    obj.selectedObj.display = src.Value;
                    
                case 'cbDiscrete'
                    obj.selectedObj.discretePlaneMode = src.Value;
                    
                case 'pmChannel'
                    if numel(obj.selectedObj.scanfields)
                        arrayfun(@(x)setp(x,'channel',obj.hAnalysisRoiPropsPanelCtls.pmChannel.hCtl.Value),obj.selectedObj.scanfields);
                    end
                    
                case 'etThreshold'
                    if numel(obj.selectedObj.scanfields)
                        arrayfun(@(x)setp(x,'threshold',str2double(obj.hAnalysisRoiPropsPanelCtls.etThreshold.hCtl.String)),obj.selectedObj.scanfields);
                    end
                    
                case 'pmProcessor'
                    if numel(obj.selectedObj.scanfields)
                        arrayfun(@(x)setp(x,'processor',obj.rProcMap(obj.hAnalysisRoiPropsPanelCtls.pmProcessor.hCtl.Value)),obj.selectedObj.scanfields);
                    end
            end
            obj.enableListeners = true;
            obj.updateTable();
            obj.setZProjectionLimits();
            obj.updateDisplay();
            
            function setp(obj,prp,val)
                obj.(prp) = val;
            end
        end
        
        function analysisSfPropsPanelUpdate(obj)
            obj.hAnalysisSfPropsPanelCtls.etZ.hCtl.String = obj.selectedObjParent.zs(obj.selectedObjParent.scanfields == obj.selectedObj);
            obj.hAnalysisSfPropsPanelCtls.etCenterX.hCtl.String = obj.selectedObj.centerXY(1) * obj.xyUnitFactor + obj.xyUnitOffset(1);
            obj.hAnalysisSfPropsPanelCtls.etCenterY.hCtl.String = obj.selectedObj.centerXY(2) * obj.xyUnitFactor + obj.xyUnitOffset(2);
            obj.hAnalysisSfPropsPanelCtls.etWidth.hCtl.String = obj.selectedObj.sizeXY(1) * obj.xyUnitFactor;
            obj.hAnalysisSfPropsPanelCtls.etHeight.hCtl.String = obj.selectedObj.sizeXY(2) * obj.xyUnitFactor;
            obj.hAnalysisSfPropsPanelCtls.etRotation.hCtl.String = obj.selectedObj.rotationDegrees; % obj.selectedObj.rotation;
            
            if numel(obj.selectedObj.mask) <= 100
                str = mat2str(obj.selectedObj.mask,5);
            else
                str = '<Matrix too large for display>';
            end
            
            obj.hAnalysisSfPropsPanelCtls.etMask.hCtl.String = str;
        end
        
        function analysisSfPropsPanelCtlCb(obj,src,~)
            obj.enableListeners = false;
            switch(src.Tag)
                case 'etZ'
                    z = str2num(src.String);
                    if ~isempty(z) && ~isnan(z) && ~isinf(z)
                        obj.selectedObjParent.moveSfById(find(obj.selectedObjParent.scanfields == obj.selectedObj),z);
                        obj.editorZ = z;
                    else
                        most.idioms.warn('Z value must be a valid number. NaN and Inf are not allowed. Resetting to previous value.');
                    end
                    
                case 'etCenterX'
                    centerX = str2num(src.String);
                    
                    if ~isempty(obj.xyUnitFactor) && (obj.xyUnitFactor ~= 0)
                        if ~isempty(centerX) && ~isnan(centerX) && ~isinf(centerX)
                            obj.selectedObj.centerXY(1) = (centerX - obj.xyUnitOffset(1)) / obj.xyUnitFactor;
                        else
                            most.idioms.warn('Center X value must be a valid number. NaN and Inf are not allowed. Resetting to previous value.');
                        end
                    else
                        most.idioms.warn('XY UnitFactor must contain a numeric, non-zero value. Resetting Center X to previous value.');
                    end
                    
                case 'etCenterY'
                    centerY = str2num(src.String);
                    
                    if ~isempty(obj.xyUnitFactor) && (obj.xyUnitFactor ~= 0)
                        if ~isempty(centerY) && ~isnan(centerY) && ~isinf(centerY)
                            obj.selectedObj.centerXY(2) = (centerY - obj.xyUnitOffset(2)) / obj.xyUnitFactor;
                        else
                            most.idioms.warn('Center Y value must be a valid number. NaN and Inf are not allowed. Resetting to previous value.');
                        end
                    else
                        most.idioms.warn('XY UnitFactor must contain a numeric, non-zero value. Resetting Center Y to previous value.');
                    end
                    
                case 'etWidth'
                    etwidth = str2num(src.String);
                    
                    if ~isempty(obj.xyUnitFactor) && (obj.xyUnitFactor ~= 0)
                        if ~isempty(etwidth) && ~isnan(etwidth) && ~isinf(etwidth)
                            obj.selectedObj.sizeXY(1) = etwidth / obj.xyUnitFactor;
                        else
                            most.idioms.warn('NaN and Inf are not allowed for width. Resetting to previous value.');
                        end
                    else
                        most.idioms.warn('XY UnitFactor must contain a numeric, non-zero value. Resetting Width to previous value.');
                    end
                    
                case 'etHeight'
                    etheight = str2num(src.String);
                    
                    if ~isempty(obj.xyUnitFactor) && (obj.xyUnitFactor ~= 0)
                        if ~isempty(etheight) && ~isnan(etheight) && ~isinf(etheight)
                            obj.selectedObj.sizeXY(2) = etheight / obj.xyUnitFactor;
                        else
                            most.idioms.warn('NaN and Inf are not allowed. Resetting to previous value.');
                        end
                    else
                        most.idioms.warn('XY UnitFactor must contain a numeric, non-zero value. Resetting Height to previous value.');
                    end
                    
                case 'etRotation'
                    etrotation = str2num(src.String);
                    
                    if ~isempty(etrotation) && ~isnan(etrotation) && ~isinf(etrotation)
                        obj.selectedObj.rotationDegrees = etrotation;
                    else
                        most.idioms.warn('Rotation value must be a valid number. NaN and Inf are not allowed. Resetting to previous value.');
                    end
                    
                case 'etMask'
                    if isempty(src.String)
                        obj.selectedObj.mask = 1;
                    else
                        if isempty(regexpi(src.String,'^<.*>$','Match','once'))
                            try
                                obj.selectedObj.mask = evalin('base',src.String);
                            catch
                                error('Must be a matlab expression.');
                            end
                        else
                            obj.selectedObj.mask = obj.selectedObj.mask;
                        end
                    end
                    
                case 'pbClearMask'
                    obj.selectedObj.mask = 1;
            end
            obj.enableListeners = true;
            obj.analysisSfPropsPanelUpdate();
            obj.satisfyConstraints(obj.selectedObj);
            obj.updateTable();
            obj.setZProjectionLimits();
            obj.updateDisplay();
            %most.idioms.info('ROI position/size data typed directly into edit fields may have been altered due to contraints based on your scanner system.');
        end
        
        function imagingSfPropsPanelUpdate(obj)
            obj.hImagingSfPropsPanelCtls.etZ.hCtl.String = obj.selectedObjParent.zs(obj.selectedObjParent.scanfields == obj.selectedObj);
            obj.hImagingSfPropsPanelCtls.etCenterX.hCtl.String = obj.selectedObj.centerXY(1) * obj.xyUnitFactor + obj.xyUnitOffset(1);
            obj.hImagingSfPropsPanelCtls.etCenterY.hCtl.String = obj.selectedObj.centerXY(2) * obj.xyUnitFactor + obj.xyUnitOffset(2);
            obj.hImagingSfPropsPanelCtls.etWidth.hCtl.String = obj.selectedObj.sizeXY(1) * obj.xyUnitFactor;
            obj.hImagingSfPropsPanelCtls.etHeight.hCtl.String = obj.selectedObj.sizeXY(2) * obj.xyUnitFactor;
            obj.hImagingSfPropsPanelCtls.etRotation.hCtl.String = obj.selectedObj.degrees;
            obj.hImagingSfPropsPanelCtls.etPixCountX.hCtl.String = obj.selectedObj.pixelResolution(1);
            obj.hImagingSfPropsPanelCtls.etPixCountY.hCtl.String = obj.selectedObj.pixelResolution(2);
            obj.hImagingSfPropsPanelCtls.etPixRatioX.hCtl.String = obj.selectedObj.pixelRatio(1) / obj.xyUnitFactor;
            obj.hImagingSfPropsPanelCtls.etPixRatioY.hCtl.String = obj.selectedObj.pixelRatio(2) / obj.xyUnitFactor;
        end
        
        function imSfPropsPanelCtlCb(obj,src,~)
            obj.enableListeners = false;
            switch(src.Tag)
                case 'etZ'
                    z = str2num(src.String);
                    if ~isempty(z) && ~isnan(z) && ~isinf(z)
                        obj.selectedObjParent.moveSfById(find(obj.selectedObjParent.scanfields == obj.selectedObj),z);
                        obj.editorZ = z;
                        
                        %                         most.idioms.info('ROI position/size data typed directly into edit fields may have been altered due to contraints based on your scanner system.');
                    else
                        most.idioms.warn('Z value must be a valid number. NaN and Inf are not allowed. Resetting to previous value.');
                    end
                    
                case 'etCenterX'
                    centerX = str2num(src.String);
                    
                    if ~isempty(obj.xyUnitFactor) && (obj.xyUnitFactor ~= 0)
                        if ~isempty(centerX) && ~isnan(centerX) && ~isinf(centerX)
                            obj.selectedObj.centerXY(1) = (centerX - obj.xyUnitOffset(1)) / obj.xyUnitFactor;
                            %                             most.idioms.info('ROI position/size data typed directly into edit fields may have been altered due to contraints based on your scanner system.');
                        else
                            most.idioms.warn('Center X value must be a valid number. NaN and Inf are not allowed. Resetting to previous value.');
                        end
                    else
                        most.idioms.warn('XY UnitFactor must contain a numeric, non-zero value. Resetting Center X to previous value.');
                    end
                    
                case 'etCenterY'
                    centerY = str2num(src.String);
                    
                    if ~isempty(obj.xyUnitFactor) && (obj.xyUnitFactor ~= 0)
                        if ~isempty(centerY) && ~isnan(centerY) && ~isinf(centerY)
                            obj.selectedObj.centerXY(2) = (centerY - obj.xyUnitOffset(2)) / obj.xyUnitFactor;
                            %                             most.idioms.info('ROI position/size data typed directly into edit fields may have been altered due to contraints based on your scanner system.');
                        else
                            most.idioms.warn('Center Y value must be a valid number. NaN and Inf are not allowed. Resetting to previous value.');
                        end
                    else
                        most.idioms.warn('XY UnitFactor must contain a numeric, non-zero value. Resetting Center Y to previous value.');
                    end
                    
                case 'etWidth'
                    etwidth = str2num(src.String);
                    
                    if ~isempty(obj.xyUnitFactor) && (obj.xyUnitFactor ~= 0)
                        if ~isempty(etwidth) && ~isnan(etwidth) && ~isinf(etwidth)
                            orat = obj.selectedObj.pixelRatio(1);
                            nsz = etwidth / obj.xyUnitFactor;
                            obj.selectedObj.sizeXY(1) = nsz;
                            if strcmp(obj.scanfieldResizeMaintainPixelProp, 'ratio')
                                obj.selectedObj.pixelResolutionXY(1) = obj.cleanResolutionRatioValue(orat * nsz);    %%%orat * nsz;
                            end
                            %                             most.idioms.info('ROI position/size data typed directly into edit fields may have been altered due to contraints based on your scanner system.');
                        else
                            most.idioms.warn('NaN and Inf are not allowed for width. Resetting to previous value.');
                        end
                    else
                        most.idioms.warn('XY UnitFactor must contain a numeric, non-zero value. Resetting Width to previous value.');
                    end
                    
                case 'etHeight'
                    etheight = str2num(src.String);
                    
                    if ~isempty(obj.xyUnitFactor) && (obj.xyUnitFactor ~= 0)
                        if ~isempty(etheight) && ~isnan(etheight) && ~isinf(etheight)
                            orat = obj.selectedObj.pixelRatio(2);
                            nsz = etheight / obj.xyUnitFactor;
                            obj.selectedObj.sizeXY(2) = nsz;
                            if strcmp(obj.scanfieldResizeMaintainPixelProp, 'ratio')
                                obj.selectedObj.pixelResolutionXY(2) = obj.cleanResolutionRatioValue(orat * nsz);     %%%orat * nsz;
                            end
                            %                             most.idioms.info('ROI position/size data typed directly into edit fields may have been altered due to contraints based on your scanner system.');
                        else
                            most.idioms.warn('NaN and Inf are not allowed for height. Resetting to previous value.');
                        end
                    else
                        most.idioms.warn('XY UnitFactor must contain a numeric, non-zero value. Resetting Height to previous value.');
                    end
                    
                case 'etRotation'
                    etrotation = str2num(src.String);
                    
                    if ~isempty(etrotation) && ~isnan(etrotation) && ~isinf(etrotation)
                        obj.selectedObj.degrees = etrotation;
                        %                        most.idioms.info('ROI position/size data typed directly into edit fields may have been altered due to contraints based on your scanner system.');
                    else
                        most.idioms.warn('Rotation value must be a valid number. NaN and Inf are not allowed. Resetting to previous value.');
                    end
                    
                case 'etPixCountX'
                    pixCountX = str2num(src.String);
                    
                    if ~isempty(pixCountX) && ~isnan(pixCountX) && ~isinf(pixCountX) && (pixCountX > 0) && (round(pixCountX) == pixCountX)
                        obj.selectedObj.pixelResolution(1) = pixCountX;
                        %                         most.idioms.info('ROI position/size data typed directly into edit fields may have been altered due to contraints based on your scanner system.');
                    else
                        most.idioms.warn('Pixel Count X must be a valid positive integer value. NaN and Inf are not allowed. Resetting to previous value.');
                    end
                    
                case 'etPixCountY'
                    pixCountY = str2num(src.String);
                    
                    if ~isempty(pixCountY) && ~isnan(pixCountY) && ~isinf(pixCountY) && (pixCountY > 0) && (round(pixCountY) == pixCountY)
                        obj.selectedObj.pixelResolution(2) = pixCountY;
                        %                         most.idioms.info('ROI position/size data typed directly into edit fields may have been altered due to contraints based on your scanner system.');
                    else
                        most.idioms.warn('Pixel Count Y must be a valid positive integer. NaN and Inf are not allowed. Resetting to previous value.');
                    end
                    
                case 'etPixRatioX'
                    pixRatioX = str2num(src.String);
                    
                    if ~isempty(pixRatioX) && ~isnan(pixRatioX) && ~isinf(pixRatioX) && (pixRatioX ~= 0)
                        obj.selectedObj.pixelRatio(1) = obj.cleanResolutionRatioValue(pixRatioX * obj.xyUnitFactor);
                        %                         most.idioms.info('ROI position/size data typed directly into edit fields may have been altered due to contraints based on your scanner system.');
                    else
                        most.idioms.warn('Pixel Ratio X must be a valid non-zero number. NaN and Inf are not allowed. Resetting to previous value.');
                    end
                    
                case 'etPixRatioY'
                    pixRatioY = str2num(src.String);
                    
                    if ~isempty(pixRatioY) && ~isnan(pixRatioY) && ~isinf(pixRatioY) && (pixRatioY ~= 0)
                        obj.selectedObj.pixelRatio(2) = obj.cleanResolutionRatioValue(pixRatioY * obj.xyUnitFactor);
                        %                         most.idioms.info('ROI position/size data typed directly into edit fields may have been altered due to contraints based on your scanner system.');
                    else
                        most.idioms.warn('Pixel Ratio Y must be a valid non-zero number. NaN and Inf are not allowed. Resetting to previous value.');
                    end
                    
                case 'rbMaintainPixCount'
                    obj.scanfieldResizeMaintainPixelProp = 'count';
                    
                case 'rbMaintainPixRatio'
                    obj.scanfieldResizeMaintainPixelProp = 'ratio';
            end
            obj.enableListeners = true;
            obj.imagingSfPropsPanelUpdate();
            obj.satisfyConstraints(obj.selectedObj);
            obj.updateTable();
            obj.setZProjectionLimits();
            obj.updateDisplay();
        end
        
        function newRoiPropsPanelUpdate(obj)
            obj.defaultRoiPositionX = obj.defaultRoiPositionX;
            obj.defaultRoiPositionY = obj.defaultRoiPositionY;
            
            obj.defaultRoiWidth = obj.defaultRoiWidth;
            obj.defaultRoiHeight = obj.defaultRoiHeight;
            
            obj.defaultRoiPixelRatioX = obj.defaultRoiPixelRatioX;
            obj.defaultRoiPixelRatioY = obj.defaultRoiPixelRatioY;
            
            obj.cellPickRoiMargin = obj.cellPickRoiMargin;
            
            obj.defaultRoiRotation = obj.defaultRoiRotation;
            
            obj.defaultRoiPixelCountX = obj.defaultRoiPixelCountX;
            obj.defaultRoiPixelCountY = obj.defaultRoiPixelCountY;
        end
        
        function newRoiPropsPanelCtlCb(obj,src,~)
            switch(src.Tag)
                case 'pbCancel'
                    obj.changeSelection();
                    
                case 'pbCreateDefault'
                    if obj.cellPickOn
                        obj.endCellPick(true);
                    else
                        obj.createRoi();
                    end
                    
                case 'etCenterX'
                    centerX = str2num(src.String);
                    
                    if ~isempty(obj.xyUnitFactor) && (obj.xyUnitFactor ~= 0)
                        if ~isempty(centerX) && ~isnan(centerX) && ~isinf(centerX)
                            obj.defaultRoiPositionX = (centerX - obj.xyUnitOffset(1)) / obj.xyUnitFactor;
                        else
                            most.idioms.warn('Center X value must be a valid number. NaN and Inf are not allowed. Resetting to previous value.');
                        end
                    else
                        most.idioms.warn('XY UnitFactor must contain a numeric, non-zero value. Resetting Center X to previous value.');
                    end
                    
                case 'etCenterY'
                    centerY = str2num(src.String);
                    
                    if ~isempty(obj.xyUnitFactor) && (obj.xyUnitFactor ~= 0)
                        if ~isempty(centerY) && ~isnan(centerY) && ~isinf(centerY)
                            obj.defaultRoiPositionY = (centerY - obj.xyUnitOffset(2)) / obj.xyUnitFactor;
                        else
                            most.idioms.warn('Center Y value must be a valid number. NaN and Inf are not allowed. Resetting to previous value.');
                        end
                    else
                        most.idioms.warn('XY UnitFactor must contain a numeric, non-zero value. Resetting Center Y to previous value.');
                    end
                    
                case 'etWidth'
                    etwidth = str2num(src.String);
                    
                    if ~isempty(obj.xyUnitFactor) && (obj.xyUnitFactor ~= 0)
                        if ~isempty(etwidth) && ~isnan(etwidth) && ~isinf(etwidth)
                            obj.defaultRoiWidth = etwidth / obj.xyUnitFactor;
                        else
                            most.idioms.warn('NaN and Inf are not allowed for width. Resetting to previous value.');
                        end
                    else
                        most.idioms.warn('XY UnitFactor must contain a numeric, non-zero value. Resetting Width to previous value.');
                    end
                    
                case 'etHeight'
                    etheight = str2num(src.String);
                    
                    if ~isempty(obj.xyUnitFactor) && (obj.xyUnitFactor ~= 0)
                        if ~isempty(etheight) && ~isnan(etheight) && ~isinf(etheight)
                            obj.defaultRoiHeight = etheight / obj.xyUnitFactor;
                        else
                            most.idioms.warn('NaN and Inf are not allowed for height. Resetting to previous value.');
                        end
                    else
                        most.idioms.warn('XY UnitFactor must contain a numeric, non-zero value. Resetting Height to previous value.');
                    end
                    
                case 'etRotation'
                    etrotation = str2num(src.String);
                    
                    if ~isempty(etrotation) && ~isnan(etrotation) && ~isinf(etrotation)
                        obj.defaultRoiRotation = etrotation;
                    else
                        most.idioms.warn('Rotation value must be a valid number. NaN and Inf are not allowed. Resetting to previous value.');
                    end
                    
                case 'etPixCountX'
                    pixCountX = str2num(src.String);
                    
                    if ~isempty(pixCountX) && ~isnan(pixCountX) && ~isinf(pixCountX) && (pixCountX > 0) && (round(pixCountX) == pixCountX)
                        obj.defaultRoiPixelCountX = pixCountX;
                    else
                        most.idioms.warn('Pixel Count X value must be a valid positive integer. NaN and Inf are not allowed. Resetting to previous value.');
                    end
                    
                case 'etPixCountY'
                    pixCountY = str2num(src.String);
                    
                    if ~isempty(pixCountY) && ~isnan(pixCountY) && ~isinf(pixCountY) && (pixCountY > 0) && (round(pixCountY) == pixCountY)
                        obj.defaultRoiPixelCountY = pixCountY;
                    else
                        most.idioms.warn('Pixel Count Y must be a valid positive integer. NaN and Inf are not allowed. Resetting to previous value.');
                    end
                    
                case 'etPixRatioX'
                    pixRatioX = str2num(src.String);
                    
                    if ~isempty(pixRatioX) && ~isnan(pixRatioX) && ~isinf(pixRatioX) && (pixRatioX ~= 0)
                        obj.defaultRoiPixelRatioX = pixRatioX * obj.xyUnitFactor;
                    else
                        most.idioms.warn('Pixel Ratio X must be a valid non-zero number. NaN and Inf are not allowed. Resetting to previous value.');
                    end
                    
                case 'etPixRatioY'
                    pixRatioY = str2num(src.String);
                    
                    if ~isempty(pixRatioY) && ~isnan(pixRatioY) && ~isinf(pixRatioY) && (pixRatioY ~= 0)
                        obj.defaultRoiPixelRatioY = pixRatioY * obj.xyUnitFactor;
                    else
                        most.idioms.warn('Pixel Ratio Y value must be a valid non-zero number. NaN and Inf are not allowed. Resetting to previous value.');
                    end
                    
                case 'etMargin'
                    etmargin = str2num(src.String);
                    
                    if ~isempty(obj.xyUnitFactor) && (obj.xyUnitFactor ~= 0)
                        if ~isempty(etmargin) && ~isnan(etmargin) && ~isinf(etmargin)
                            obj.cellPickRoiMargin = etmargin / obj.xyUnitFactor;
                        else
                            most.idioms.warn('Margin value must be a valid number. NaN and Inf are not allowed. Resetting to previous value.');
                        end
                    else
                        most.idioms.warn('XY UnitFactor must contain a numeric, non-zero value. Resetting Margin to previous value.');
                    end
            end
            
            obj.newRoiPropsPanelUpdate();
            %most.idioms.info('ROI position/size data typed directly into edit fields may have been altered due to contraints based on your scanner system.');
        end
        
        function slmPropsPanelUpdate(obj)
            sf = obj.slmPatternSfParent;
            
            if isa(obj.scannerSet,'scanimage.mroi.scannerset.GalvoGalvo')
                slmScanFunction = regexpi(func2str(sf.stimfcnhdl),'[^\.]*$','match');
                [~,obj.hSlmPropsPanelCtls.pmFunction.hCtl.Value] = ismember(slmScanFunction,obj.slmScanOptions);
                obj.showHandles = ~strcmp(slmScanFunction,'point');
                
                obj.hSlmPropsPanelCtls.etArgs.ParameterOptions = obj.getStimParamOptions(slmScanFunction{1});
            end
            
            obj.hSlmPropsPanelCtls.etArgs.Value = sf.stimparams;
            
            obj.hSlmPropsPanelCtls.etDuration.hCtl.String = sf.duration*1000;
            obj.hSlmPropsPanelCtls.etReps.hCtl.String = sf.repetitions;
            obj.hSlmPropsPanelCtls.etWidth.hCtl.String = sf.sizeXY(1) * obj.xyUnitFactor;
            obj.hSlmPropsPanelCtls.etHeight.hCtl.String = sf.sizeXY(2) * obj.xyUnitFactor;
            obj.hSlmPropsPanelCtls.etRotation.hCtl.String = sf.rotation;
            obj.hSlmPropsPanelCtls.etPower.hCtl.String = sf.powers;
            
            if obj.slmPatternTypeIsBitmap
                mn = min(sf.slmPattern(:));
                mx = max(sf.slmPattern(:));
                cdat = repmat(uint8(255 * (sf.slmPattern - mn) / (mx - mn)),1,1,3);
                cdat(:,:,1) = 0;
                obj.h2DScannerFovSurf.CData = cdat;
            else
                obj.enableListeners = false;
                for roi = obj.editingGroup.rois
                    if ~isempty(roi.scanfields)
                        roi.scanfields(1).sizeXY = sf.sizeXY;
                        roi.scanfields(1).rotation = sf.rotation;
                        roi.scanfields(1).stimfcnhdl = sf.stimfcnhdl;
                    end
                end
                obj.enableListeners = true;
                obj.h2DScannerFovSurf.CData = [];
            end
        end
        
        function slmPropsPanelCtlCb(obj,src,~)
            obj.enableListeners = false;
            updateAll = false;
            switch(src.Tag)
                case 'pmFunction'
                    stimfcnname = obj.slmScanOptions{src.Value};
                    var = 'stimfcnhdl';
                    val = str2func(['scanimage.mroi.stimulusfunctions.' stimfcnname]);
                    obj.slmPatternSfParent.stimfcnhdl = val;
                    updateAll = true;
                    
                case 'etArgs'
                    var = 'stimparams';
                    val = src.Value;
                    
                case 'etWidth'
                    etwidth = str2num(src.String);
                    
                    if ~isempty(etwidth) && ~isnan(etwidth) && ~isinf(etwidth)
                        obj.slmPatternSfParent.sizeXY(1) = etwidth / obj.xyUnitFactor;
                        var = 'sizeXY';
                        val = obj.slmPatternSfParent.sizeXY;
                        updateAll = true;
                    else
                        most.idioms.warn('NaN and Inf are not allowed for width. Resetting to previous value.');
                    end
                    
                case 'etHeight'
                    etheight = str2num(src.String);
                    
                    if ~isempty(etheight) && ~isnan(etheight) && ~isinf(etheight)
                        obj.slmPatternSfParent.sizeXY(2) = etheight / obj.xyUnitFactor;
                        var = 'sizeXY';
                        val = obj.slmPatternSfParent.sizeXY;
                        updateAll = true;
                    else
                        most.idioms.warn('NaN and Inf is not allowed for height. Resetting to previous value.');
                    end
                    
                case 'etRotation'
                    etrotation = str2num(src.String);
                    
                    if ~isempty(etrotation) && ~isnan(etrotation) && ~isinf(etrotation)
                        obj.slmPatternSfParent.rotation = etrotation;
                        var = 'rotation';
                        val = etrotation;
                        updateAll = true;
                    else
                        most.idioms.warn('Rotation value must be a valid number. NaN and Inf are not allowed. Resetting to previous value.');
                    end
                    
                case 'etDuration'
                    etduration = str2num(src.String);
                    
                    if ~isempty(etduration) && ~isnan(etduration) && ~isinf(etduration) && (etduration > 0)
                        obj.slmPatternSfParent.duration = etduration/1000;
                    else
                        most.idioms.warn('Duration value must be a valid number. NaN and Inf are not allowed. Resetting to previous value.');
                    end
                    
                case 'etReps'
                    etreps = str2num(src.String);
                    
                    if ~isempty(etreps) && ~isnan(etreps) && ~isinf(etreps) && (etreps > 0) && (round(etreps) == etreps)
                        obj.slmPatternSfParent.repetitions = etreps;
                    else
                        most.idioms.warn('Repititions must be a valid positive integer. NaN and Inf are not allowed. Resetting to previous value.');
                    end
                    
                case 'etPower'
                    etpower = str2num(src.String);
                    
                    if ~isempty(etpower) && ~isnan(etpower) && ~isinf(etpower)
                        obj.slmPatternSfParent.powers = etpower;
                    else
                        most.idioms.warn('Beam Power must be a valid number. NaN and Inf are not allowed. Resetting to previous value.');
                    end
            end
            
            if updateAll
                for roi = obj.editingGroup.rois
                    if ~isempty(roi.scanfields)
                        roi.scanfields(1).(var) = val;
                    end
                end
            end
            
            obj.enableListeners = true;
            obj.updateScanPathCache();
            obj.updateDisplay();
        end
        
        function updateGlobalPanel(obj)
            if ~obj.isGuiLoaded
                return;
            end
            if obj.editorModeIsImaging && strcmp(obj.hGlobalImagingSfPropsPanel.Visible, 'on')
                if numel(obj.editingGroup.rois) && numel([obj.editingGroup.rois.scanfields])
                    allSfs = [obj.editingGroup.rois.scanfields];
                    N = numel(allSfs);
                    
                    for i = N:-1:1
                        c(i,:) = allSfs(i).centerXY;
                        s(i,:) = allSfs(i).sizeXY;
                        r(i) = allSfs(i).rotation;
                        p(i,:) = allSfs(i).pixelResolutionXY;
                        rr(i,:) = p(i,:)./s(i,:);
                    end
                    
                    % center x
                    if cmp(c(1,1), c(:,1))
                        obj.hGlobalImagingSfPropsPanelCtls.etCenterX.String = num2str(c(1,1) * obj.xyUnitFactor + obj.xyUnitOffset(1));
                    else
                        obj.hGlobalImagingSfPropsPanelCtls.etCenterX.String = 'Various';
                    end
                    
                    % center y
                    if cmp(c(1,2), c(:,2))
                        obj.hGlobalImagingSfPropsPanelCtls.etCenterY.String = num2str(c(1,2) * obj.xyUnitFactor + obj.xyUnitOffset(2));
                    else
                        obj.hGlobalImagingSfPropsPanelCtls.etCenterY.String = 'Various';
                    end
                    
                    % width
                    if cmp(s(1,1), s(:,1))
                        obj.hGlobalImagingSfPropsPanelCtls.etWidth.String = num2str(s(1,1) * obj.xyUnitFactor);
                    else
                        obj.hGlobalImagingSfPropsPanelCtls.etWidth.String = 'Various';
                    end
                    
                    % height
                    if cmp(s(1,2), s(:,2))
                        obj.hGlobalImagingSfPropsPanelCtls.etHeight.String = num2str(s(1,2) * obj.xyUnitFactor);
                    else
                        obj.hGlobalImagingSfPropsPanelCtls.etHeight.String = 'Various';
                    end
                    
                    % rotation
                    if cmp(r(1), r)
                        obj.hGlobalImagingSfPropsPanelCtls.etRotation.String = num2str(r(1));
                    else
                        obj.hGlobalImagingSfPropsPanelCtls.etRotation.String = 'Various';
                    end
                    
                    % pix x
                    if cmp(p(1,1), p(:,1))
                        obj.hGlobalImagingSfPropsPanelCtls.etPixCountX.String = num2str(p(1,1));
                    else
                        obj.hGlobalImagingSfPropsPanelCtls.etPixCountX.String = 'Various';
                    end
                    
                    % pix y
                    if cmp(p(1,2), p(:,2))
                        obj.hGlobalImagingSfPropsPanelCtls.etPixCountY.String = num2str(p(1,2));
                    else
                        obj.hGlobalImagingSfPropsPanelCtls.etPixCountY.String = 'Various';
                    end
                    
                    % res x
                    if cmp(rr(1,1), rr(:,1))
                        obj.hGlobalImagingSfPropsPanelCtls.etPixRatioX.String = num2str(rr(1,1) / obj.xyUnitFactor);
                    else
                        obj.hGlobalImagingSfPropsPanelCtls.etPixRatioX.String = 'Various';
                    end
                    
                    % res y
                    if cmp(rr(1,2), rr(:,2))
                        obj.hGlobalImagingSfPropsPanelCtls.etPixRatioY.String = num2str(rr(1,2) / obj.xyUnitFactor);
                    else
                        obj.hGlobalImagingSfPropsPanelCtls.etPixRatioY.String = 'Various';
                    end
                    
                    cellfun(@(x)set(x,'Enable','on'),obj.hGlobalImagingSfPropsPanelCtls.all);
                else
                    cellfun(@(x)set(x,'Enable','off'),obj.hGlobalImagingSfPropsPanelCtls.all);
                    cellfun(@(x)set(x,'String',''),obj.hGlobalImagingSfPropsPanelCtls.allFields)
                end
            end
            
            function q = cmp(a,b)
                q = all(abs(a) < 0.0000000001) && all(abs(b) < 0.0000000001) || all(abs(a-b) < abs(a(1) * 0.005));
            end
        end
        
        function globalPnlCallback(obj,src,prop,idx,fac,off)
            v = str2double(src.String);
            
            if fac
                v = v / (obj.xyUnitFactor^fac);
            end
            
            if off
                v = v - obj.xyUnitOffset(idx);
            end
            
            if ~isempty(v) && ~isnan(v)
                obj.enableListeners = false;
                for sf = [obj.editingGroup.rois.scanfields]
                    sf.(prop)(idx) = v;
                end
                obj.enableListeners = true;
                obj.rgChangedPar();
            end
            
            obj.updateGlobalPanel();
        end
        
        function zPlaneCtlCb(obj,src,~)
            etzplane = str2num(src.String);
            
            if ~isempty(etzplane) && ~isnan(etzplane) && ~isinf(etzplane)
                obj.editorZ = etzplane;
            else
                most.idioms.warn('Z plane must be a valid number. NaN and Inf are not allowed. Resetting to previous value.');
                obj.editorZ = obj.editorZ;
            end
        end
        
        function [roi, sf] = createRoi(obj,varargin)
            if nargin > 3
                z = varargin{3};
                varargin(3) = [];
            else
                z = obj.editorZ;
            end
            
            sf = obj.createSf(varargin{:});
            
            roi = scanimage.mroi.Roi;
            roi.add(z,sf);
            
            obj.enableListeners = false;
            obj.editingGroup.add(roi);
            obj.satisfyConstraints(sf);
            obj.enableListeners = true;
            
            if obj.editorModeIsSlm
                obj.updateScanPathCache();
                obj.selectedObj = sf;
                obj.selectedObjParent = roi;
                obj.selectedObjRoiIdx = numel(obj.editingGroup.rois);
            elseif ~obj.drawMultipleRois
                obj.createMode = false;
                obj.updateScanPathCache();
                obj.changeSelection(sf,roi);
            else
                obj.updateScanPathCache();
                obj.updateDisplay();
            end
            
            obj.setZProjectionLimits();
            obj.updateTable();
        end
        
        function sf = createSf(obj,centerXY,sizeXY,power)
            if nargin < 2 || isempty(centerXY)
                centerXY = [obj.defaultRoiPositionX obj.defaultRoiPositionY];
            end
            if nargin < 3 || isempty(sizeXY)
                sizeXY = [obj.defaultRoiWidth obj.defaultRoiHeight];
            end
            
            switch obj.editorMode
                case 'imaging'
                    switch obj.newRoiDefaultResolutionMode
                        case 'pixel count'
                            pixRes = [obj.defaultRoiPixelCountX obj.defaultRoiPixelCountY];
                            
                        case 'pixel ratio'
                            pixRes = sizeXY .* [obj.defaultRoiPixelRatioX obj.defaultRoiPixelRatioY];
                    end
                    
                    adjustedPixRes = abs(round(pixRes));
                    
                    for dx = 1:numel(pixRes)
                        if isnan(adjustedPixRes(dx)) || isinf(adjustedPixRes(dx)) || (adjustedPixRes(dx) == 0)
                            adjustedPixRes(dx) = 1;
                            most.idioms.warn('Pixel Resolution element cannot be NaN, Inf or 0. Setting Pixel Resolution to 1.');
                        end
                    end
                    
                    pixRes = adjustedPixRes;
                    
                    sf=scanimage.mroi.scanfield.fields.RotatedRectangle([centerXY-sizeXY/2 sizeXY],obj.defaultRoiRotation,pixRes);
                    
                case 'stimulation'
                    sf = scanimage.mroi.scanfield.fields.StimulusField(sprintf('scanimage.mroi.stimulusfunctions.%s',obj.defaultStimFunction),obj.defaultStimFunctionArgs,obj.defaultStimDuration/1000,...
                        obj.defaultStimRepititions,centerXY,sizeXY/2,obj.defaultRoiRotation,obj.defaultStimPower);
                    
                case 'analysis'
                    sf = scanimage.mroi.scanfield.fields.IntegrationField();
                    sf.centerXY = centerXY;
                    sf.sizeXY = sizeXY;
                    sf.rotationDegrees = obj.defaultRoiRotation;
                    sf.threshold = obj.defaultAnalysisRoiThreshold;
                    sf.channel = obj.defaultAnalysisRoiChannel;
                    sf.processor = obj.defaultAnalysisRoiProcessor;
                    
                case 'slm'
                    if nargin < 4
                        power = 1;
                    end
                    sf = scanimage.mroi.scanfield.fields.StimulusField(obj.slmPatternSfParent.stimfcnhdl,{},obj.defaultStimDuration/1000,...
                        obj.defaultStimRepititions,centerXY,sizeXY/2,obj.defaultRoiRotation,power);
            end
        end
        
        function satisfyConstraints(obj,sf)
            if obj.editorModeIsSlm
                if sf == obj.slmPatternSfParent
                    % satisfy constaints of galvo position for GG+SLM set
                    obj.scannerSet.satisfyConstraintsRoiGroup(obj.slmPatternRoiGroupParent,sf);
                else
                    % satisfy constraints of focal points?
                end
            else
                obj.scannerSet.satisfyConstraintsRoiGroup(obj.editingGroup,sf);
            end
        end
        
        function editOrCreateScanfieldAtZ(obj,varargin)
            if ismember(obj.editorZ, obj.selectedObj.zs)
                sf = obj.selectedObj.get(obj.editorZ);
                obj.changeSelection(sf,obj.selectedObj);
                obj.fixTableCheck();
            else
                sf = obj.selectedObj.get(obj.editorZ,true);
                if isempty(sf)
                    sf = obj.createSf();
                else
                    sf = sf.copy();
                end
                obj.enableListeners = false;
                obj.selectedObj.add(obj.editorZ,sf);
                obj.enableListeners = true;
                obj.changeSelection(sf,obj.selectedObj);
                obj.updateTable();
                obj.setZProjectionLimits();
            end
        end
        
        function imagingSystemChange(obj,varargin)
            switch obj.editorMode
                case {'imaging' 'analysis'}
                    obj.scannerSet = obj.hModel.hScan2D.scannerset;
                    most.idioms.safeDeleteObj(obj.hSSListener);
                    obj.hSSListener = most.ErrorHandler.addCatchingListener(obj.hModel.hScan2D, 'scannerset','PostSet',@obj.ssChange);
            end
            obj.frameRateUpdate();
        end
        
        function frameRateUpdate(obj,varargin)
            s = '';
            if obj.hModel.hRoiManager.mroiEnable
                r = obj.hModel.hRoiManager.scanFrameRate;
                if ~isinf(r) && ~isnan(r)
                    s = most.idioms.engineersStyle(1/r,'s','%.2f',' ');
                    s = sprintf('%.2f Hz (%s)',r,s);
                end
            end
            obj.hGlobalImagingSfPropsPanelCtls.etFrameRate.String = s;
        end
        
        function ssChange(obj,varargin)
            obj.scannerSet = obj.hModel.hScan2D.scannerset;
        end
        
        function c = pickMostUniqueCtxImColor(obj)
            usedColors = [obj.hContextImages.colorIdx];
            for i = numel(obj.contextImageEdgeColorList):-1:1
                usedColorCnt(i) = sum(usedColors == i);
            end
            [~, c] = min(usedColorCnt);
        end
        
        function startCellPick(obj)
            obj.cellPickZs = [];
            obj.cellPickCellsAtZ = {};
            obj.cellPickSelectedCellIdx = [];
            
            obj.updateCellPickToZ();
            obj.updateCellPickButtons();
        end
        
        function updateCellPickToZ(obj)
            most.idioms.safeDeleteObj(obj.cellPickSurfs);
            obj.cellPickSurfs = [];
            
            if obj.createMode && obj.cellPickOn
                ctxImSurfs = [obj.hContextImages(:).visibleSurfs];
                cpSurfs = {};
                
                for i = 1:numel(ctxImSurfs)
                    srf = ctxImSurfs(i);
                    cdsz = size(srf.CData);
                    cpSurfs{end+1} = surface(srf.XData,srf.YData,srf.ZData +.01,'Parent',obj.h2DMainViewAxes,'FaceColor','texturemap','CData',zeros(cdsz,'uint8'),...
                        'FaceAlpha','texturemap','AlphaData',zeros(cdsz(1:2)),'EdgeColor','none','ButtonDownFcn',@obj.cellPickHit,'userdata',srf,'Visible',srf.Visible);
                end
                obj.cellPickSurfs = [cpSurfs{:}];
                
                obj.redrawCellPickSurfs();
            end
        end
        
        function cellPickHit(obj,stop,varargin)
            persistent hitpt;
            persistent cpsurf;
            
            if nargin > 2
                hitpt = getPointerLocation(obj.h2DMainViewAxes);
                cpsurf = stop;
                
                set(obj.hFig,'WindowButtonMotionFcn',@(varargin)obj.cellPickHit(false),'WindowButtonUpFcn',@(varargin)obj.cellPickHit(true));
                waitfor(obj.hFig,'WindowButtonMotionFcn',[]);
            elseif stop
                set(obj.hFig,'WindowButtonMotionFcn',[],'WindowButtonUpFcn',[]);
                
                %try to pick a cell!
                obj.pickCell(cpsurf,hitpt);
            else
                % cursor moved. let this be a pan instead of a cell pick
                set(obj.hFig,'WindowButtonMotionFcn',[]);
                obj.mainPan(obj,false,[]);
            end
        end
        
        function pickCell(obj,cpSurf,hitPt)
            imSurf = cpSurf.UserData;
            aff = imSurf.UserData;
            sz = size(imSurf.CData);
            ptXY = floor(scanimage.mroi.util.xformPoints(hitPt,inv(aff)) .* sz([1,2])) + 1;
            
            % did user click on an already picked cell?
            [tf, iSurf] = ismember(cpSurf, obj.cellPickSurfs);
            if tf
                clkId = obj.cellPickSurfsIdMap{iSurf}(ptXY(1),ptXY(2));
                if clkId
                    obj.cellPickSelectedCellIdx = clkId;
                    obj.redrawCellPickSurfs();
                    return;
                end
            end
            
            wkngIm = double(max(imSurf.CData,[],3));
            pts = obj.cellPickFunc('pick', wkngIm, ptXY);
            
            if ~isempty(pts)
                c.pts = pts;
                c.aff = aff;
                c.imSz = sz([1,2]);
                [~, c.surfIdx] = ismember(cpSurf, obj.cellPickSurfs);
                
                [tf, i] = ismember(obj.editorZ, obj.cellPickZs);
                if tf
                    obj.cellPickCellsAtZ{i}(end+1) = c;
                    obj.cellPickSelectedCellIdx = numel(obj.cellPickCellsAtZ{i});
                else
                    obj.cellPickZs(end+1) = obj.editorZ;
                    obj.cellPickCellsAtZ{end+1}= c;
                    obj.cellPickSelectedCellIdx = 1;
                end
                
                obj.updateCellPickButtons();
                obj.redrawCellPickSurfs();
            end
        end
        
        function updateCellPickButtons(obj)
            set([obj.hNewImagingRoiPanelCtls.pbCreate.hCtl obj.hNewStimRoiPanelCtls.pbCreate.hCtl obj.hNewAnalysisRoiPanelCtls.pbCreate.hCtl], 'enable', obj.tfMap(logical(numel(obj.cellPickZs))));
            
            set([obj.hNewImagingRoiPanelCtls.pbErode obj.hNewStimRoiPanelCtls.pbErode obj.hNewAnalysisRoiPanelCtls.pbErode...
                obj.hNewImagingRoiPanelCtls.pbDilate obj.hNewStimRoiPanelCtls.pbDilate obj.hNewAnalysisRoiPanelCtls.pbDilate...
                obj.hNewImagingRoiPanelCtls.pbDelete obj.hNewStimRoiPanelCtls.pbDelete obj.hNewAnalysisRoiPanelCtls.pbDelete...
                ], 'enable', obj.tfMap(~isempty(obj.cellPickSelectedCellIdx)));
        end
        
        function redrawCellPickSurfs(obj)
            obj.cellPickSurfsIdMap = cell(numel(obj.cellPickSurfs),1);
            for i = 1:numel(obj.cellPickSurfs)
                cdat = zeros(size(obj.cellPickSurfs(i).CData),'uint8');
                adat = zeros(size(obj.cellPickSurfs(i).AlphaData));
                idMap = adat;
                
                [tf, j] = ismember(obj.editorZ, obj.cellPickZs);
                if tf
                    for k = 1:numel(obj.cellPickCellsAtZ{j})
                        cll = obj.cellPickCellsAtZ{j}(k);
                        if cll.surfIdx == i
                            if ~isempty(obj.cellPickSelectedCellIdx) && (k == obj.cellPickSelectedCellIdx)
                                cdat(sub2ind(size(cdat),cll.pts(:,1),cll.pts(:,2),ones(length(cll.pts),1))) = 0;
                                cdat(sub2ind(size(cdat),cll.pts(:,1),cll.pts(:,2),2*ones(length(cll.pts),1))) = 255;
                            else
                                cdat(sub2ind(size(cdat),cll.pts(:,1),cll.pts(:,2),ones(length(cll.pts),1))) = 255;
                            end
                            adat(sub2ind(size(adat),cll.pts(:,1),cll.pts(:,2))) = .5;
                            idMap(sub2ind(size(adat),cll.pts(:,1),cll.pts(:,2))) = k;
                        end
                    end
                end
                
                obj.cellPickSurfs(i).CData = cdat;
                obj.cellPickSurfs(i).AlphaData = adat;
                obj.cellPickSurfsIdMap{i} = idMap;
            end
        end
        
        function pbDilateCell(obj,varargin)
            [tf, i] = ismember(obj.editorZ, obj.cellPickZs);
            if tf && ~isempty(obj.cellPickSelectedCellIdx)
                cll = obj.cellPickCellsAtZ{i}(obj.cellPickSelectedCellIdx);
                wkngIm = double(max(obj.cellPickSurfs(cll.surfIdx).UserData.CData,[],3));
                obj.cellPickCellsAtZ{i}(obj.cellPickSelectedCellIdx).pts = obj.cellPickFunc('dilate', wkngIm, cll.pts);
                obj.redrawCellPickSurfs();
            end
        end
        
        function pbErodeCell(obj,varargin)
            [tf, i] = ismember(obj.editorZ, obj.cellPickZs);
            if tf && ~isempty(obj.cellPickSelectedCellIdx)
                cll = obj.cellPickCellsAtZ{i}(obj.cellPickSelectedCellIdx);
                wkngIm = double(max(obj.cellPickSurfs(cll.surfIdx).UserData.CData,[],3));
                obj.cellPickCellsAtZ{i}(obj.cellPickSelectedCellIdx).pts = obj.cellPickFunc('erode', wkngIm, cll.pts);
                obj.redrawCellPickSurfs();
            end
        end
        
        function pbDeleteCell(obj,varargin)
            [tf, i] = ismember(obj.editorZ, obj.cellPickZs);
            if tf && ~isempty(obj.cellPickSelectedCellIdx)
                obj.cellPickCellsAtZ{i}(obj.cellPickSelectedCellIdx) = [];
                obj.cellPickSelectedCellIdx = min(obj.cellPickSelectedCellIdx, numel(obj.cellPickCellsAtZ{i}));
                
                if obj.cellPickSelectedCellIdx < 1
                    obj.cellPickSelectedCellIdx = [];
                    obj.cellPickCellsAtZ(i) = [];
                    obj.cellPickZs(i) = [];
                end
                
                obj.redrawCellPickSurfs();
                obj.updateCellPickButtons();
            end
        end
        
        function endCellPick(obj,tfCreate)
            most.idioms.safeDeleteObj(obj.cellPickSurfs);
            obj.cellPickSurfs = [];
            
            if tfCreate
                obj.enableListeners = false;
                
                sf = [];
                roi = [];
                
                for i = 1:numel(obj.cellPickZs)
                    for j = 1:numel(obj.cellPickCellsAtZ{i})
                        cll = obj.cellPickCellsAtZ{i}(j);
                        
                        ptMin = min(cll.pts);
                        ptMax = max(cll.pts);
                        pixDiffs = ptMax - ptMin + 1;
                        
                        refPts = [ptMax; ptMin-1] ./ repmat(cll.imSz,2,1);
                        refPts = scanimage.mroi.util.xformPoints(refPts,cll.aff);
                        refdiffs = refPts(1,:) - refPts(2,:);
                        refCtr = mean(refPts);
                        
                        roi = scanimage.mroi.Roi;
                        
                        %                         [~,~,~,~,rot,~] = scanimage.mroi.util.paramsFromTransform(cll.aff);
                        
                        switch obj.editorMode
                            case 'imaging'
                                sf = obj.createSf(refCtr,refdiffs+obj.cellPickRoiMargin);
                                roi.discretePlaneMode = obj.cellPickCreateAsDiscrete;
                                
                            case 'stimulation'
                                sf = obj.createSf(refCtr,refdiffs);
                                if obj.cellPickPauseDuration > 0
                                    pSf = scanimage.mroi.scanfield.fields.StimulusField('scanimage.mroi.stimulusfunctions.pause',{},obj.cellPickPauseDuration/1000,...
                                        1,[obj.defaultRoiPositionX obj.defaultRoiPositionY],[obj.defaultRoiWidth obj.defaultRoiHeight]/2,0,obj.defaultStimPower);
                                    pRoi = scanimage.mroi.Roi;
                                    pRoi.add(obj.cellPickZs(i),pSf);
                                    obj.editingGroup.add(pRoi);
                                end
                                
                            case 'analysis'
                                % compute size oversized by margin but quantized to make mask still fit cell
                                overPixdiffs = ceil(pixDiffs .* (refdiffs+obj.cellPickRoiMargin*2) ./ refdiffs);
                                overSz = overPixdiffs-pixDiffs;
                                overPixdiffs = pixDiffs + ceil(overSz/2)*2;
                                
                                sf = obj.createSf(refCtr,refdiffs .* overPixdiffs ./ pixDiffs);
                                
                                roi.discretePlaneMode = obj.cellPickCreateAsDiscrete;
                                if obj.cellPickCreateWithMask
                                    % pad with zeros to account for margin
                                    diffmrg = floor((overPixdiffs-pixDiffs)/2);
                                    
                                    overPixdiffs = fliplr(overPixdiffs);
                                    msk = zeros(overPixdiffs);
                                    pts = cll.pts - repmat(ptMin,size(cll.pts,1),1)+1;
                                    msk(sub2ind(overPixdiffs,pts(:,2)+diffmrg(1),pts(:,1)+diffmrg(2))) = 1;
                                    sf.mask = msk;
                                end
                        end
                        
                        roi.add(obj.cellPickZs(i),sf);
                        obj.editingGroup.add(roi);
                    end
                end
                
                obj.satisfyConstraints(sf);
                obj.enableListeners = true;
                
                obj.updateScanPathCache();
                obj.changeSelection(sf, roi);
                obj.updateTable();
                obj.updateDisplay();
            end
        end
        
        function pts = diskCellPickFunc(obj, op, imData, xyPt)
            pts = [];
            
            switch op
                case 'pick'
                    indices = cellDetSemiautoGradient(xyPt,imData,obj.diskCellPickParams);
                    
                case 'dilate'
                    indices = sub2ind(size(imData),xyPt(:,1),xyPt(:,2));
                    indices = dilateRoiIndices(indices, 2, size(imData));
                    
                case 'erode'
                    indices = sub2ind(size(imData),xyPt(:,1),xyPt(:,2));
                    indices = erodeRoiIndices(indices, 2, size(imData));
            end
            
            if ~isempty(indices)
                [pts(:,1), pts(:,2)] = ind2sub(size(imData),indices);
            end
        end
        
        function pts = annularCellPickFunc(obj, op, imData, xyPt)
            pts = [];
            
            switch op
                case 'pick'
                    indices = cellDetSemiautoGradient(xyPt,imData,obj.annularCellPickParams);
                    
                case 'dilate'
                    indices = sub2ind(size(imData),xyPt(:,1),xyPt(:,2));
                    indices = dilateRoiIndices(indices, 2, size(imData));
                    
                case 'erode'
                    indices = sub2ind(size(imData),xyPt(:,1),xyPt(:,2));
                    indices = erodeRoiIndices(indices, 2, size(imData));
            end
            
            if ~isempty(indices)
                [pts(:,1), pts(:,2)] = ind2sub(size(imData),indices);
            end
        end
        
        function pts = manualCellPickFunc(obj, op, imData, xyPt, rad)
            if nargin < 5 || isempty(rad)
                rad = obj.cellPickManualRadius;
            end
            
            crad = ceil(rad);
            
            switch op
                case 'pick'
                    pts = xyPt;
                    for j = max((xyPt(2)-crad),1):min((xyPt(2)+crad),size(imData,2))
                        for i = max((xyPt(1)-crad),1):min((xyPt(1)+crad),size(imData,1))
                            if norm(xyPt - [i j]) <= rad
                                pts(end+1,:) = [i j];
                            end
                        end
                    end
                    
                case 'dilate'
                    ctr = xyPt(1,:); %first point is the center point
                    diffs = xyPt - repmat(ctr,size(xyPt,1),1); % distance of each point from centroid
                    r = max(sqrt(sum(diffs.^2,2))); % max distance
                    r = 1.1*r; % increase r by 10%
                    pts = obj.manualCellPickFunc('pick', imData, round(ctr), r); % find the new points
                    
                case 'erode'
                    ctr = xyPt(1,:); %first point is the center point
                    diffs = xyPt - repmat(ctr,size(xyPt,1),1); % distance of each point from centroid
                    r = max(sqrt(sum(diffs.^2,2))); % max distance
                    r = 0.9*r; % increase r by 10%
                    pts = obj.manualCellPickFunc('pick', imData, round(ctr), r); % find the new points
            end
        end
        
        function quickAddPause(obj,pos,silentUpdate)
            if nargin < 2
                pos = [];
            end
            
            if nargin < 3 || isempty(silentUpdate)
                silentUpdate = false;
            end
            
            if ~silentUpdate
                obj.enableListeners = false;
            end
            
            roi = scanimage.mroi.Roi;
            sf = scanimage.mroi.scanfield.fields.StimulusField('scanimage.mroi.stimulusfunctions.pause',{},obj.stimQuickAddDuration/1000,...
                1,[obj.defaultRoiPositionX obj.defaultRoiPositionY],[obj.defaultRoiWidth obj.defaultRoiHeight]/2,0,obj.defaultStimPower);
            roi.add(obj.editorZ,sf);
            
            if isempty(pos)
                obj.editingGroup.add(roi);
            else
                if pos > 0
                    obj.editingGroup.insertAfterId(pos,roi);
                else
                    obj.editingGroup.insertAfterId(1,roi);
                    obj.editingGroup.moveById(roi.uuiduint64,-1);
                end
            end
            
            if ~silentUpdate
                obj.enableListeners = true;
                obj.updateScanPathCache();
                obj.updateTable();
                obj.updateDisplay();
            end
        end
        
        function quickAddPark(obj,pos)
            if nargin < 2
                pos = [];
            end
            
            obj.enableListeners = false;
            
            roi = scanimage.mroi.Roi;
            sf = scanimage.mroi.scanfield.fields.StimulusField('scanimage.mroi.stimulusfunctions.park',{},obj.stimQuickAddDuration/1000,...
                1,[obj.defaultRoiPositionX obj.defaultRoiPositionY],[obj.defaultRoiWidth obj.defaultRoiHeight]/2,0,obj.defaultStimPower);
            roi.add(obj.editorZ,sf);
            
            if isempty(pos)
                obj.editingGroup.add(roi);
            else
                if pos > 0
                    obj.editingGroup.insertAfterId(pos,roi);
                else
                    obj.editingGroup.insertAfterId(1,roi);
                    obj.editingGroup.moveById(roi.uuiduint64,-1);
                end
            end
            
            obj.enableListeners = true;
            obj.updateScanPathCache();
            obj.updateTable();
            obj.updateDisplay();
        end
        
        function newRatio = cleanResolutionRatioValue(obj, val)
            if ~isempty(val) && ~isnan(val) && ~isinf(val) && (val > 0)
                newRatio = abs(round(val));
                
                if isempty(newRatio) || isnan(newRatio) || (newRatio <= 0)
                    newRatio = 1;
                elseif isinf(newRatio)
                    newRatio = 1000000000;
                end
            else
                if isinf(val)
                    newRatio = 1000000000;
                else
                    newRatio = 1;
                end
            end
        end
        
        function loadBitmapFromFile(obj,varargin)
            [fn, pth] = uigetfile({'*.png' 'PNGs'; '*.bmp' 'Bitmap'; '*.mat' 'MAT file'},'Import Bitmap Data...',obj.getClassDataVar('lastSlmFile'));
            if fn==0;return;end
            filename = fullfile(pth,fn);
            obj.setClassDataVar('lastSlmFile',filename);
            
            [~, ~, ext] = fileparts(filename);
            
            switch(ext)
                case {'.bmp' '.png'}
                    slmPattern = mean(double(imread(filename)),3);
                    
                case '.mat'
                    load(filename);
                    if ~exist('slmPattern','var')
                        errordlg('MAT file must include a variable called ''slmPattern''.','SLM Pattern Import');
                        return;
                    end
                    
                otherwise
                    errordlg('Invalid extension/file type.','SLM Pattern Import');
            end
            
            ss = obj.scannerSet;
            if isa(ss,'scanimage.mroi.scannerset.GalvoGalvo')
                ss = ss.slm;
            end
            nwSz = size(slmPattern);
            if (numel(nwSz) ~= 2) || ~all(nwSz == fliplr(ss.scanners{1}.hDevice.pixelResolutionXY))
                errordlg('Incorrect SLM pattern size.', 'SLM Pattern Import', 'modal');
                return;
            end
            
            obj.slmPatternSfParent.slmPattern = slmPattern;
        end
        
        function loadBitmapFromVar(obj,varargin)
            answer=inputdlg('Enter the name of a variable on the workspace (or a MATLAB expression) to import the pattern from.','SLM Pattern Editor',1,{'slmPattern'},struct('WindowStyle', 'modal'));
            if ~isempty(answer)
                try
                    newPat = evalin('base',answer{1});
                catch ME
                    errordlg(sprintf('Error evaluating input: %s',ME.message), 'SLM Pattern Import', 'modal');
                    return;
                end
                
                nwSz = size(newPat);
                
                ss = obj.scannerSet;
                if isa(ss,'scanimage.mroi.scannerset.GalvoGalvo')
                    ss = ss.slm;
                end
                
                if isempty(newPat)
                    obj.slmPatternSfParent.slmPattern = zeros(fliplr(ss.scanners{1}.pixelResolutionXY));
                    return;
                elseif (numel(nwSz) ~= 2) || ~all(nwSz == fliplr(ss.scanners{1}.pixelResolutionXY))
                    errordlg('Incorrect SLM pattern size.', 'SLM Pattern Import', 'modal');
                    return;
                end
                
                obj.slmPatternSfParent.slmPattern = newPat;
            end
        end
        
        function saveBitmapToFile(obj,varargin)
            [fn, pth] = uiputfile({'*.png' 'PNG'; '*.bmp' 'Bitmap'; '*.mat' 'MAT file'},'Export Bitmap Data...',obj.getClassDataVar('lastSlmFile'));
            if fn==0;return;end
            filename = fullfile(pth,fn);
            obj.setClassDataVar('lastSlmFile',filename);
            
            [~, ~, ext] = fileparts(filename);
            
            slmPattern = obj.h2DScannerFovSurf.CData(:,:,3);
            
            switch(ext)
                case '.png'
                    imwrite(repmat(slmPattern,1,1,3), filename, 'PNG');
                    
                case '.bmp'
                    imwrite(repmat(slmPattern,1,1,3), filename, 'BMP');
                    
                case '.mat'
                    slmPattern = double(slmPattern)/255;
                    save(filename,'slmPattern');
                    
                otherwise
                    errordlg('Invalid extension/file type.','SLM Pattern Export');
            end
        end
        
        function saveBitmapToVar(obj,varargin)
            answer=inputdlg('Enter the name of a variable to export the pattern into.','SLM Pattern Editor',1,{'slmPattern'},struct('WindowStyle', 'modal'));
            if ~isempty(answer)
                assignin('base',answer{1},obj.slmPatternSfParent.slmPattern);
            end
        end
        
        function clearBitmap(obj,varargin)
            slmPattern = obj.h2DScannerFovSurf.CData;
            if ~isempty(slmPattern) && (sum(slmPattern(:)) > 0)
                answer = questdlg('Are you sure you want to clear the bitmap?', 'SLM Pattern Editor','Yes','Cancel','Cancel');
                if strcmp(answer, 'Yes')
                    ss = obj.scannerSet;
                    if isa(ss,'scanimage.mroi.scannerset.GalvoGalvo')
                        ss = ss.slm;
                    end
                    obj.slmPatternSfParent.slmPattern = zeros(fliplr(ss.scanners{1}.hDevice.pixelResolutionXY));
                end
            end
        end
        
        function updateScrollPatch(obj)
            YLim = obj.h2DZScrollAxes.YLim;
            
            xx = linspace(0,.8,100);
            yy1 = spline(xx([1 end]),[0 YLim(1) obj.editorZ (obj.editorZ-YLim(1))/2],xx);
            yy2 = spline(xx([1 end]),[0 YLim(2) obj.editorZ (obj.editorZ-YLim(2))/2],xx);
            
            patchVertices = [        xx(:) ,        yy1(:) ;
                flipud(xx(:)), flipud(yy2(:)) ];
            
            obj.h2DScrollPatch.Vertices = patchVertices;
            obj.h2DScrollPatch.Faces = 1:size(patchVertices,1);
            
            
            textHeight = diff(YLim) / obj.h2DZScrollAxes.Position(4) * 20;
            position = [-0.25 obj.editorZ-textHeight/2 0.9 textHeight];
            obj.hZCursorTextRect.Position = position;
            obj.hZCursorTextRect.Curvature = [0.2 1];
            
            obj.hZCursorText.Position = [0.2 obj.editorZ];
            
            z_meter = obj.editorZ / 1e6;
            obj.hZCursorText.String = most.idioms.engineersStyle(z_meter,'m','%.1f');
            
            obj.h2DScrollKnob.Color = 'black';
        end
    end
end

%% Local Functions
function pt = getPointerLocation(hAx)
pt = hAx.CurrentPoint(1, 1:2);
end

function titleBar(parent,title)
t = most.gui.staticText('parent',parent,'BackgroundColor',.4*ones(1,3),'string',title,'FontSize',10,'HorizontalAlignment', 'center');
set(t.hPnl,'HeightLimits',20*ones(1,2));
t.hTxt.FontWeight = 'bold';
t.hTxt.Color = 'w';
end

function createGlobalImagingSfPropsPanel(obj,parent,kpf)
obj.hGlobalImagingSfPropsPanel = uipanel('Parent', parent);
set(obj.hGlobalImagingSfPropsPanel, 'HeightLimits', 170*ones(1,2));

hf = most.gui.uiflowcontainer('Parent', obj.hGlobalImagingSfPropsPanel,'FlowDirection','TopDown','Margin',0.0001);
titleBar(hf,'Global Scanfield Properties');

cols = most.gui.uiflowcontainer('Parent', hf,'FlowDirection','LeftToRight');
col1 = most.gui.uiflowcontainer('Parent', cols,'FlowDirection','TopDown','Margin',0.0001);
col2 = most.gui.uiflowcontainer('Parent', cols,'FlowDirection','TopDown','Margin',0.0001);
set(col1, 'WidthLimits', 194*ones(1,2));

up1 = uipanel('parent',col1,'title','Scanfield Position/Size');
up = most.gui.uiflowcontainer('Parent', up1,'FlowDirection','TopDown','Margin',0.0001);

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Center X:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 60*ones(1,2));
ctls.etCenterX = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@(src,~)obj.globalPnlCallback(src,'centerXY',1,true,true));
set(ctls.etCenterX, 'WidthLimits', 60*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Center Y:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 60*ones(1,2));
ctls.etCenterY = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@(src,~)obj.globalPnlCallback(src,'centerXY',2,true,true));
set(ctls.etCenterY, 'WidthLimits', 60*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Width:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 60*ones(1,2));
ctls.etWidth = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@(src,~)obj.globalPnlCallback(src,'sizeXY',1,true,false));
ctls.cbWidthLock = most.gui.uicontrol('Parent',hf1,'Style','Checkbox','string','Lock','Bindings',{obj 'lockScanfieldWidth' 'value'},kpf{:});
set(ctls.etWidth, 'WidthLimits', 60*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Height:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 60*ones(1,2));
ctls.etHeight = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@(src,~)obj.globalPnlCallback(src,'sizeXY',2,true,false));
ctls.cbHeightLock = most.gui.uicontrol('Parent',hf1,'Style','Checkbox','string','Lock','Bindings',{obj 'lockScanfieldHeight' 'value'},kpf{:});
set(ctls.etHeight, 'WidthLimits', 60*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Rotation:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 60*ones(1,2));
ctls.etRotation = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@(src,~)obj.globalPnlCallback(src,'rotation',1,false,false));
set(ctls.etRotation, 'WidthLimits', 60*ones(1,2));


up2 = uipanel('parent',col2,'title','Scanfield Resolution');
up = most.gui.uiflowcontainer('Parent', up2,'FlowDirection','TopDown','Margin',0.0001);

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Pixel Count X:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 120*ones(1,2));
ctls.etPixCountX = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@(src,~)obj.globalPnlCallback(src,'pixelResolutionXY',1,false,false));

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Pixel Count Y:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 120*ones(1,2));
ctls.etPixCountY = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@(src,~)obj.globalPnlCallback(src,'pixelResolutionXY',2,false,false));

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
ctls.stPixRatioX = most.gui.staticText('Parent',hf1,'String','Pixel Ratio [Pix/um] X:','HorizontalAlignment','right');
set(ctls.stPixRatioX, 'WidthLimits', 120*ones(1,2));
ctls.etPixRatioX = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@(src,~)obj.globalPnlCallback(src,'pixelRatio',1,-1,false));

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
ctls.stPixRatioY = most.gui.staticText('Parent',hf1,'String','Pixel Ratio [Pix/um] Y:','HorizontalAlignment','right');
set(ctls.stPixRatioY, 'WidthLimits', 120*ones(1,2));
ctls.etPixRatioY = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@(src,~)obj.globalPnlCallback(src,'pixelRatio',2,-1,false));

hf1 = most.gui.uiflowcontainer('Parent', col2,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
most.gui.staticText('Parent',hf1,'String','Frame Rate:','HorizontalAlignment','right', 'WidthLimits', 60);
ctls.etFrameRate = most.gui.uicontrol('Parent',hf1,'Style','edit','enable','inactive','BackgroundColor',.95*ones(1,3));

set(up1, 'HeightLimits', 142*ones(1,2));
set(up2, 'HeightLimits', 117*ones(1,2));

obj.hGlobalImagingSfPropsPanelCtls = ctls;
obj.hGlobalImagingSfPropsPanelCtls.all = {};
obj.hGlobalImagingSfPropsPanelCtls.allFields = {};
for n = fieldnames(ctls)'
    if strcmp(ctls.(n{1}).Style, 'edit')
        obj.hGlobalImagingSfPropsPanelCtls.allFields{end+1} = ctls.(n{1});
        obj.hGlobalImagingSfPropsPanelCtls.all{end+1} = ctls.(n{1});
    end
    if strcmp(ctls.(n{1}).Style, 'checkbox')
        obj.hGlobalImagingSfPropsPanelCtls.all{end+1} = ctls.(n{1});
    end
end
obj.hGlobalImagingSfPropsPanel.Visible = 'off';
end

function createImagingRoiPropsPanel(obj,parent,kpf)
obj.hImagingRoiPropsPanel = uipanel('Parent', parent);
set(obj.hImagingRoiPropsPanel, 'HeightLimits', 240*ones(1,2));
hf = most.gui.uiflowcontainer('Parent', obj.hImagingRoiPropsPanel,'FlowDirection','TopDown','Margin',0.0001);

titleBar(hf,'Selected ROI Properties');

hf1 = most.gui.uiflowcontainer('Parent', hf,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','ROI Name:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 120*ones(1,2));
ctls.etName = most.gui.uicontrol('Parent',hf1,'Style','Edit','HorizontalAlignment','left','callback',@obj.roiPropsPanelCtlCb,'tag','etName');

hf1 = most.gui.uiflowcontainer('Parent', hf,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Unique ID:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 120*ones(1,2));
ctls.etUUID = most.gui.uicontrol('Parent',hf1,'Style','Edit','enable','inactive','HorizontalAlignment','left','BackgroundColor',.95*ones(1,3));


cols = most.gui.uiflowcontainer('Parent', hf,'FlowDirection','LeftToRight','Margin',0.0001);
col1 = most.gui.uiflowcontainer('Parent', cols,'FlowDirection','TopDown','Margin',0.0001);
set(col1, 'WidthLimits', 160*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', col1,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Enabled:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 120*ones(1,2));
ctls.cbEnable = most.gui.uicontrol('Parent',hf1,'Style','Checkbox','callback',@obj.roiPropsPanelCtlCb,'tag','cbEnable',kpf{:});

hf1 = most.gui.uiflowcontainer('Parent', col1,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Show In Image Display:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 120*ones(1,2));
ctls.cbDisplay = most.gui.uicontrol('Parent',hf1,'Style','Checkbox','callback',@obj.roiPropsPanelCtlCb,'tag','cbDisplay',kpf{:});

hf1 = most.gui.uiflowcontainer('Parent', col1,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Discrete Plane Mode:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 120*ones(1,2));
ctls.cbDiscrete = most.gui.uicontrol('Parent',hf1,'Style','Checkbox','callback',@obj.roiPropsPanelCtlCb,'tag','cbDiscrete',kpf{:});

col2 = most.gui.uiflowcontainer('Parent', cols,'FlowDirection','TopDown','Margin',0.0001);

hf1 = most.gui.uiflowcontainer('Parent', col2,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Number of Scanfield Control Points:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 175*ones(1,2));
ctls.etCPs = most.gui.uicontrol('Parent',hf1,'Style','Edit','HorizontalAlignment','left','enable','inactive','BackgroundColor',.95*ones(1,3));

hf1 = most.gui.uiflowcontainer('Parent', col2,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','ROI Minimum Z [um]:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 175*ones(1,2));
ctls.etZmin = most.gui.uicontrol('Parent',hf1,'Style','Edit','HorizontalAlignment','left','enable','inactive','BackgroundColor',.95*ones(1,3));

hf1 = most.gui.uiflowcontainer('Parent', col2,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','ROI Maximum Z [um]:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 175*ones(1,2));
ctls.etZmax = most.gui.uicontrol('Parent',hf1,'Style','Edit','HorizontalAlignment','left','enable','inactive','BackgroundColor',.95*ones(1,3));


ctls.pbCreateSf = most.gui.uicontrol('Parent',col2,'String','Add ScanField at Current Z','callback',@obj.editOrCreateScanfieldAtZ,kpf{:});
set(ctls.pbCreateSf, 'HeightLimits', 24*ones(1,2));


hf1 = most.gui.uiflowcontainer('Parent', hf,'FlowDirection','LeftToRight');
pp = uipanel('parent',hf1,'title','ROI Specific Power Controls');
ppf = most.gui.uiflowcontainer('Parent', pp,'FlowDirection','LeftToRight','Margin',0.0001);
ppfL = most.gui.uiflowcontainer('Parent', ppf,'FlowDirection','TopDown','Margin',0.0001);
ppfR = most.gui.uiflowcontainer('Parent', ppf,'FlowDirection','TopDown','Margin',0.0001);

ppf1 = most.gui.uiflowcontainer('Parent', ppfL,'FlowDirection','LeftToRight');
set(ppf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',ppf1,'String','Powers%:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 100*ones(1,2));
ctls.etPowers = most.gui.uicontrol('Parent',ppf1,'Style','Edit','HorizontalAlignment','left','callback',@obj.roiPropsPanelCtlCb,'tag','etPowers');

ppf1 = most.gui.uiflowcontainer('Parent', ppfL,'FlowDirection','LeftToRight');
set(ppf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',ppf1,'String','Enable P/z Adjust:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 100*ones(1,2));
ctls.etPZ = most.gui.uicontrol('Parent',ppf1,'Style','Edit','HorizontalAlignment','left','callback',@obj.roiPropsPanelCtlCb,'tag','etPZ');

ppf1 = most.gui.uiflowcontainer('Parent', ppfR,'FlowDirection','LeftToRight');
set(ppf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',ppf1,'String','Length Constants:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 100*ones(1,2));
ctls.etLzs = most.gui.uicontrol('Parent',ppf1,'Style','Edit','HorizontalAlignment','left','callback',@obj.roiPropsPanelCtlCb,'tag','etLzs');

set(hf1, 'HeightLimits', 72*ones(1,2));

obj.hImagingRoiPropsPanelCtls = ctls;
obj.hImagingRoiPropsPanel.Visible = 'off';
end

function createImagingSfPropsPanel(obj,parent,kpf)
obj.hImagingSfPropsPanel = uipanel('Parent', parent);
set(obj.hImagingSfPropsPanel, 'HeightLimits', 208*ones(1,2));

hf = most.gui.uiflowcontainer('Parent', obj.hImagingSfPropsPanel,'FlowDirection','TopDown','Margin',0.0001);
titleBar(hf,'Selected Scanfield Properties');

cols = most.gui.uiflowcontainer('Parent', hf,'FlowDirection','LeftToRight');
col1 = most.gui.uiflowcontainer('Parent', cols,'FlowDirection','TopDown','Margin',0.0001);
col2 = most.gui.uiflowcontainer('Parent', cols,'FlowDirection','TopDown','Margin',0.0001);
set(col1, 'WidthLimits', 194*ones(1,2));

up1 = uipanel('parent',col1,'title','Scanfield Position/Size');
up = most.gui.uiflowcontainer('Parent', up1,'FlowDirection','TopDown','Margin',0.0001);

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Z:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 60*ones(1,2));
ctls.etZ = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@obj.imSfPropsPanelCtlCb,'tag','etZ');
set(ctls.etZ, 'WidthLimits', 60*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Center X:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 60*ones(1,2));
ctls.etCenterX = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@obj.imSfPropsPanelCtlCb,'tag','etCenterX');
set(ctls.etCenterX, 'WidthLimits', 60*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Center Y:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 60*ones(1,2));
ctls.etCenterY = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@obj.imSfPropsPanelCtlCb,'tag','etCenterY');
set(ctls.etCenterY, 'WidthLimits', 60*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Width:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 60*ones(1,2));
ctls.etWidth = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@obj.imSfPropsPanelCtlCb,'tag','etWidth');
ctls.cbWidthLock = most.gui.uicontrol('Parent',hf1,'Style','Checkbox','string','Lock','Bindings',{obj 'lockScanfieldWidth' 'value'},kpf{:});
set(ctls.etWidth, 'WidthLimits', 60*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Height:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 60*ones(1,2));
ctls.etHeight = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@obj.imSfPropsPanelCtlCb,'tag','etHeight');
ctls.cbHeightLock = most.gui.uicontrol('Parent',hf1,'Style','Checkbox','string','Lock','Bindings',{obj 'lockScanfieldHeight' 'value'},kpf{:});
set(ctls.etHeight, 'WidthLimits', 60*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Rotation:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 60*ones(1,2));
ctls.etRotation = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@obj.imSfPropsPanelCtlCb,'tag','etRotation');
set(ctls.etRotation, 'WidthLimits', 60*ones(1,2));


up2 = uipanel('parent',col2,'title','Scanfield Resolution');
up = most.gui.uiflowcontainer('Parent', up2,'FlowDirection','TopDown','Margin',0.0001);

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Pixel Count X:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 120*ones(1,2));
ctls.etPixCountX = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@obj.imSfPropsPanelCtlCb,'tag','etPixCountX');

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Pixel Count Y:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 120*ones(1,2));
ctls.etPixCountY = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@obj.imSfPropsPanelCtlCb,'tag','etPixCountY');

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
ctls.stPixRatioX = most.gui.staticText('Parent',hf1,'String','Pixel Ratio [Pix/um] X:','HorizontalAlignment','right');
set(ctls.stPixRatioX, 'WidthLimits', 120*ones(1,2));
ctls.etPixRatioX = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@obj.imSfPropsPanelCtlCb,'tag','etPixRatioX');

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
ctls.stPixRatioY = most.gui.staticText('Parent',hf1,'String','Pixel Ratio [Pix/um] Y:','HorizontalAlignment','right');
set(ctls.stPixRatioY, 'WidthLimits', 120*ones(1,2));
ctls.etPixRatioY = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@obj.imSfPropsPanelCtlCb,'tag','etPixRatioY');

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','TopDown');
nm = most.gui.staticText('Parent',hf1,'String','Resize Behavior:','HorizontalAlignment','left');
set(nm, 'HeightLimits', 24*ones(1,2));
ctls.rbMaintainPixCount = most.gui.uicontrol('Parent',hf1,'Style','radiobutton','string','Maintain Pixel Count','callback',@obj.imSfPropsPanelCtlCb,'tag','rbMaintainPixCount',kpf{:});
ctls.rbMaintainPixRatio = most.gui.uicontrol('Parent',hf1,'Style','radiobutton','string','Maintain Pixel Ratio','callback',@obj.imSfPropsPanelCtlCb,'tag','rbMaintainPixRatio',kpf{:});

set(up1, 'HeightLimits', 168*ones(1,2));
set(up2, 'HeightLimits', 180*ones(1,2));

obj.hImagingSfPropsPanelCtls = ctls;
obj.hImagingSfPropsPanel.Visible = 'off';
obj.scanfieldResizeMaintainPixelProp = 'count';
end

function createNewImRoiPropsPanel(obj,parent,kpf)
obj.hNewImagingRoiPanel = uipanel('Parent', parent);
set(obj.hNewImagingRoiPanel, 'HeightLimits', 220*ones(1,2));

flw = most.gui.uiflowcontainer('Parent',obj.hNewImagingRoiPanel,'FlowDirection','TopDown','Margin',0.0001);
titleBar(flw,'New ROI');

topStuff = most.gui.uiflowcontainer('Parent',flw,'FlowDirection','TopDown','Margin',0.0001);
botStuff = most.gui.uiflowcontainer('Parent',flw,'FlowDirection','BottomUp','Margin',0.0001);


topRow = most.gui.uiflowcontainer('Parent', topStuff,'FlowDirection','LeftToRight');
set(topRow, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',topRow,'String','Draw By:','HorizontalAlignment','left');
set(nm, 'WidthLimits', 50*ones(1,2));
ctls.rbTopLeftRect = most.gui.uicontrol('Parent',topRow,'Style','radiobutton','string','Top Left Rectangle','callback',@(varargin)set(obj,'newRoiDrawMode','top left rectangle'),kpf{:});
ctls.rbCenterPtRect = most.gui.uicontrol('Parent',topRow,'Style','radiobutton','string','Center Point Rectangle','callback',@(varargin)set(obj,'newRoiDrawMode','center point rectangle'),kpf{:});
ctls.rbCellPick = most.gui.uicontrol('Parent',topRow,'Style','radiobutton','string','Cell Picker','callback',@(varargin)set(obj,'newRoiDrawMode','cell picker'),kpf{:});
set(ctls.rbTopLeftRect, 'WidthLimits', 115*ones(1,2));
set(ctls.rbCenterPtRect, 'WidthLimits', 135*ones(1,2));
set(ctls.rbCellPick, 'WidthLimits', 70*ones(1,2));


botRow = most.gui.uiflowcontainer('Parent', botStuff,'FlowDirection','LeftToRight','Margin',0.0001);
botRowL = most.gui.uiflowcontainer('Parent', botRow,'FlowDirection','LeftToRight');
set(botRowL, 'WidthLimits', 160*ones(1,2));
botRowR = most.gui.uiflowcontainer('Parent', botRow,'FlowDirection','RightToLeft');
set(botStuff, 'HeightLimits', 28*ones(1,2));
ctls.stDraw = most.gui.staticText('Parent',botRowL,'String','   Draw new ROI...','HorizontalAlignment','left','FontWeight','bold','FontSize',12);
ctl = most.gui.uicontrol('Parent',botRowR,'string','Cancel','callback',@obj.newRoiPropsPanelCtlCb,'tag','pbCancel',kpf{:});
set(ctl, 'WidthLimits', 70*ones(1,2));
ctls.pbCreate = most.gui.uicontrol('Parent',botRowR,'string','Create Using Defaults','callback',@obj.newRoiPropsPanelCtlCb,'tag','pbCreateDefault',kpf{:});
set(ctls.pbCreate, 'WidthLimits', 140*ones(1,2));



cols = most.gui.uiflowcontainer('Parent', topStuff,'FlowDirection','LeftToRight');
col1 = most.gui.uiflowcontainer('Parent', cols,'FlowDirection','TopDown','Margin',0.0001);
col2 = most.gui.uiflowcontainer('Parent', cols,'FlowDirection','TopDown','Margin',0.0001);
set(col1, 'WidthLimits', 194*ones(1,2));

up1 = uipanel('parent',col1,'title','Default Scanfield Position/Size');
up = most.gui.uiflowcontainer('Parent', up1,'FlowDirection','TopDown','Margin',0.0001);

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Center X:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 60*ones(1,2));
ctls.etCenterX = most.gui.uicontrol('Parent',hf1,'Style','edit','tag','etCenterX','callback',@obj.newRoiPropsPanelCtlCb);
set(ctls.etCenterX, 'WidthLimits', 60*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Center Y:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 60*ones(1,2));
ctls.etCenterY = most.gui.uicontrol('Parent',hf1,'Style','edit','tag','etCenterY','callback',@obj.newRoiPropsPanelCtlCb);
set(ctls.etCenterY, 'WidthLimits', 60*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Width:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 60*ones(1,2));
ctls.etWidth = most.gui.uicontrol('Parent',hf1,'Style','edit','tag','etWidth','callback',@obj.newRoiPropsPanelCtlCb);
ctls.cbWidthLock = most.gui.uicontrol('Parent',hf1,'Style','Checkbox','string','Lock','Bindings',{obj 'lockScanfieldWidth' 'value'},kpf{:});
set(ctls.etWidth, 'WidthLimits', 60*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Height:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 60*ones(1,2));
ctls.etHeight = most.gui.uicontrol('Parent',hf1,'Style','edit','tag','etHeight','callback',@obj.newRoiPropsPanelCtlCb);
ctls.cbHeightLock = most.gui.uicontrol('Parent',hf1,'Style','Checkbox','string','Lock','Bindings',{obj 'lockScanfieldHeight' 'value'},kpf{:});
set(ctls.etHeight, 'WidthLimits', 60*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Rotation:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 60*ones(1,2));
%ctls.etRotation = most.gui.uicontrol('Parent',hf1,'Style','edit','Bindings',{obj 'defaultRoiRotation' 'value'});
ctls.etRotation = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@obj.newRoiPropsPanelCtlCb,'tag','etRotation');
set(ctls.etRotation, 'WidthLimits', 60*ones(1,2));



upCp = uipanel('parent',col1,'bordertype','none');
up = most.gui.uiflowcontainer('Parent', upCp,'FlowDirection','TopDown','Margin',0.0001);

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Selection Mode:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 84*ones(1,2));
ctls.pmSelMode = most.gui.uicontrol('Parent',hf1,'Style','popupmenu','string',[obj.cellPickModes {'Custom...'}],'Bindings',{obj 'cellPickMode' 'choice'},kpf{:});

upSel = uipanel('parent',up,'title','Selected Cell');
set(upSel, 'HeightLimits', 42*ones(1,2));
upf = most.gui.uiflowcontainer('Parent', upSel,'FlowDirection','LeftToRight');
ctls.pbDilate = uicontrol('Parent',upf,'string','Dilate','enable','off','callback',@obj.pbDilateCell,kpf{:});
ctls.pbErode = uicontrol('Parent',upf,'string','Erode','enable','off','callback',@obj.pbErodeCell,kpf{:});
ctls.pbDelete = uicontrol('Parent',upf,'string','Delete','enable','off','callback',@obj.pbDeleteCell,kpf{:});



hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
ctls.stMargin = most.gui.staticText('Parent',hf1,'String','ROI Margin [um]:','HorizontalAlignment','right');
set(ctls.stMargin, 'WidthLimits', 90*ones(1,2));
ctls.etMargin = most.gui.uicontrol('Parent',hf1,'Style','edit','tag','etMargin','callback',@obj.newRoiPropsPanelCtlCb);
set(ctls.etMargin, 'WidthLimits', 60*ones(1,2));

ctls.cbCreateDiscrete = most.gui.uicontrol('Parent',up,'Style','Checkbox','string','Create as discrete plane ROI','Bindings',{obj 'cellPickCreateAsDiscrete' 'Value'},kpf{:});
set(ctls.cbCreateDiscrete, 'HeightLimits', 24*ones(1,2));



up2 = uipanel('parent',col2,'title','Default Scanfield Resolution');
up = most.gui.uiflowcontainer('Parent', up2,'FlowDirection','TopDown','Margin',0.0001);

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
ctls.rbPixCount = most.gui.uicontrol('Parent',hf1,'Style','radiobutton','string','Pixel Count','callback',@(varargin)set(obj,'newRoiDefaultResolutionMode','pixel count'),kpf{:});
ctls.rbPixRatio = most.gui.uicontrol('Parent',hf1,'Style','radiobutton','string','Pixel Ratio','callback',@(varargin)set(obj,'newRoiDefaultResolutionMode','pixel ratio'),kpf{:});
set(hf1, 'HeightLimits', 24*ones(1,2));


ctls.pixCntCtls = most.gui.uiflowcontainer('Parent', up,'FlowDirection','TopDown','Margin',0.0001);

hf1 = most.gui.uiflowcontainer('Parent', ctls.pixCntCtls,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
ctls.stPixCountX = most.gui.staticText('Parent',hf1,'String','Pixel Count X:','HorizontalAlignment','right');
set(ctls.stPixCountX, 'WidthLimits', 120*ones(1,2));
%ctls.etPixCountX = most.gui.uicontrol('Parent',hf1,'Style','edit','Bindings',{obj 'defaultRoiPixelCountX' 'value'});
ctls.etPixCountX = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@obj.newRoiPropsPanelCtlCb,'tag','etPixCountX');

hf1 = most.gui.uiflowcontainer('Parent', ctls.pixCntCtls,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
ctls.stPixCountY = most.gui.staticText('Parent',hf1,'String','Pixel Count Y:','HorizontalAlignment','right');
set(ctls.stPixCountY, 'WidthLimits', 120*ones(1,2));
%ctls.etPixCountY = most.gui.uicontrol('Parent',hf1,'Style','edit','Bindings',{obj 'defaultRoiPixelCountY' 'value'});
ctls.etPixCountY = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@obj.newRoiPropsPanelCtlCb,'tag','etPixCountY');


ctls.pixRatCtls = most.gui.uiflowcontainer('Parent', up,'FlowDirection','TopDown','Margin',0.0001);

hf1 = most.gui.uiflowcontainer('Parent', ctls.pixRatCtls,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
ctls.stPixRatioX = most.gui.staticText('Parent',hf1,'String','Pixel Ratio [Pix/um] X:','HorizontalAlignment','right');
set(ctls.stPixRatioX, 'WidthLimits', 120*ones(1,2));
ctls.etPixRatioX = most.gui.uicontrol('Parent',hf1,'Style','edit','tag','etPixRatioX','callback',@obj.newRoiPropsPanelCtlCb);

hf1 = most.gui.uiflowcontainer('Parent', ctls.pixRatCtls,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
ctls.stPixRatioY = most.gui.staticText('Parent',hf1,'String','Pixel Ratio [Pix/um] Y:','HorizontalAlignment','right');
set(ctls.stPixRatioY, 'WidthLimits', 120*ones(1,2));
ctls.etPixRatioY = most.gui.uicontrol('Parent',hf1,'Style','edit','tag','etPixRatioY','callback',@obj.newRoiPropsPanelCtlCb);

set(up1, 'HeightLimits', 141*ones(1,2));
set(up2, 'HeightLimits', 92*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent',col2,'FlowDirection','LeftToRight');
ctls.cbDrawMultiple = most.gui.uicontrol('Parent',hf1,'Style','Checkbox','string','Draw Multiple','Bindings',{obj 'drawMultipleRois' 'value'},kpf{:});
ctls.cbDrawArray = most.gui.uicontrol('Parent',hf1,'Style','Checkbox','string','Draw Array','Bindings',{obj 'drawArray' 'value'},kpf{:});


ctls.rectCtls = up1;
ctls.cellCtls = upCp;
obj.hNewImagingRoiPanelCtls = ctls;
obj.hNewImagingRoiPanel.Visible = 'off';
obj.newRoiDefaultResolutionMode = 'pixel count';
end

function createStimRoiPropsPanel(obj,parent,kpf)
obj.hStimRoiPropsPanel = uipanel('Parent', parent);
set(obj.hStimRoiPropsPanel, 'HeightLimits', 196*ones(1,2));

hf = most.gui.uiflowcontainer('Parent', obj.hStimRoiPropsPanel,'FlowDirection','TopDown','Margin',0.0001);
titleBar(hf,'Selected Stimulus Function Properties');

cols = most.gui.uiflowcontainer('Parent', hf,'FlowDirection','LeftToRight');
col1 = most.gui.uiflowcontainer('Parent', cols,'FlowDirection','TopDown','Margin',0.0001);
col2 = most.gui.uiflowcontainer('Parent', cols,'FlowDirection','TopDown','Margin',0.0001);
set(col1, 'WidthLimits', 194*ones(1,2));

up1 = uipanel('parent',col1,'title','Stimulus Position/Size');
up = most.gui.uiflowcontainer('Parent', up1,'FlowDirection','TopDown','Margin',0.0001);

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Z:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 60*ones(1,2));
ctls.etZ = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@obj.stimRoiPropsPanelCtlCb,'tag','etZ');
set(ctls.etZ, 'WidthLimits', 60*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Center X:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 60*ones(1,2));
ctls.etCenterX = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@obj.stimRoiPropsPanelCtlCb,'tag','etCenterX');
set(ctls.etCenterX, 'WidthLimits', 60*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Center Y:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 60*ones(1,2));
ctls.etCenterY = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@obj.stimRoiPropsPanelCtlCb,'tag','etCenterY');
set(ctls.etCenterY, 'WidthLimits', 60*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Width:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 60*ones(1,2));
ctls.etWidth = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@obj.stimRoiPropsPanelCtlCb,'tag','etWidth');
ctls.cbWidthLock = most.gui.uicontrol('Parent',hf1,'Style','Checkbox','string','Lock','Bindings',{obj 'lockScanfieldWidth' 'value'},kpf{:});
set(ctls.etWidth, 'WidthLimits', 60*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Height:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 60*ones(1,2));
ctls.etHeight = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@obj.stimRoiPropsPanelCtlCb,'tag','etHeight');
ctls.cbHeightLock = most.gui.uicontrol('Parent',hf1,'Style','Checkbox','string','Lock','Bindings',{obj 'lockScanfieldHeight' 'value'},kpf{:});
set(ctls.etHeight, 'WidthLimits', 60*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Rotation:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 60*ones(1,2));
ctls.etRotation = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@obj.stimRoiPropsPanelCtlCb,'tag','etRotation');
set(ctls.etRotation, 'WidthLimits', 60*ones(1,2));


ctls.paramPanel = most.gui.uipanel('parent',col2,'title','Stimulus Parameters');
up = most.gui.uiflowcontainer('Parent', ctls.paramPanel,'FlowDirection','TopDown','Margin',0.0001);

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Function:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 50*ones(1,2));
ctls.pmFunction = most.gui.uicontrol('Parent',hf1,'Style','popupmenu','string',obj.stimFcnOptions,'callback',@obj.stimRoiPropsPanelCtlCb,'tag','pmFunction',kpf{:});

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Fcn Args:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 50*ones(1,2));
ctls.etArgs = most.gui.paramCellArrayEdit('Parent',hf1,'callback',@obj.stimRoiPropsPanelCtlCb,'tag','etArgs');

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Duration (ms):','HorizontalAlignment','right');
set(nm, 'WidthLimits', 70*ones(1,2));
ctls.etDuration = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@obj.stimRoiPropsPanelCtlCb,'tag','etDuration');
set(ctls.etDuration, 'WidthLimits', 40*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Repetitions:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 70*ones(1,2));
ctls.etReps = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@obj.stimRoiPropsPanelCtlCb,'tag','etReps');
set(ctls.etReps, 'WidthLimits', 40*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Beam Power%','HorizontalAlignment','right');
set(nm, 'WidthLimits', 70*ones(1,2));
ctls.etPower = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@obj.stimRoiPropsPanelCtlCb,'tag','etPower');
set(ctls.etPower, 'WidthLimits', 40*ones(1,2));

ctls.slmFlow = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight','HeightLimits', 24);
most.gui.staticText('Parent',ctls.slmFlow,'String','SLM Pattern:','HorizontalAlignment','right','WidthLimits', 70);
ctls.etPattern = most.gui.uicontrol('Parent',ctls.slmFlow,'Style','edit','ButtonDownFcn',@obj.editSlmPattern,'enable','inactive','BackgroundColor',.95*ones(1,3),'WidthLimits', 60);
ctls.pbEditSlm = most.gui.uicontrol('Parent',ctls.slmFlow,'Callback',@obj.editOrClearSlmPattern,'string','Clear','WidthLimits', 40);


set(up1, 'HeightLimits', 168*ones(1,2));
set(ctls.paramPanel, 'HeightLimits', 164*ones(1,2));


obj.hStimRoiPropsPanelCtls = ctls;
obj.hStimRoiPropsPanel.Visible = 'off';
end

function createNewStimRoiPropsPanel(obj,parent,kpf)
obj.hNewStimRoiPanel = uipanel('Parent', parent);
set(obj.hNewStimRoiPanel, 'HeightLimits', 240*ones(1,2));

flw = most.gui.uiflowcontainer('Parent',obj.hNewStimRoiPanel,'FlowDirection','TopDown','Margin',0.0001);
titleBar(flw,'New Stimulus Function');

topStuff = most.gui.uiflowcontainer('Parent',flw,'FlowDirection','TopDown','Margin',0.0001);
botStuff = most.gui.uiflowcontainer('Parent',flw,'FlowDirection','BottomUp','Margin',0.0001);


topRow = most.gui.uiflowcontainer('Parent', topStuff,'FlowDirection','LeftToRight');
set(topRow, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',topRow,'String','Draw By:','HorizontalAlignment','left');
set(nm, 'WidthLimits', 50*ones(1,2));
ctls.rbTopLeftRect = most.gui.uicontrol('Parent',topRow,'Style','radiobutton','string','Top Left Rectangle','callback',@(varargin)set(obj,'newRoiDrawMode','top left rectangle'),kpf{:});
ctls.rbCenterPtRect = most.gui.uicontrol('Parent',topRow,'Style','radiobutton','string','Center Point Rectangle','callback',@(varargin)set(obj,'newRoiDrawMode','center point rectangle'),kpf{:});
ctls.rbCellPick = most.gui.uicontrol('Parent',topRow,'Style','radiobutton','string','Cell Picker','callback',@(varargin)set(obj,'newRoiDrawMode','cell picker'),kpf{:});
set(ctls.rbTopLeftRect, 'WidthLimits', 115*ones(1,2));
set(ctls.rbCenterPtRect, 'WidthLimits', 135*ones(1,2));
set(ctls.rbCellPick, 'WidthLimits', 70*ones(1,2));



botRow = most.gui.uiflowcontainer('Parent', botStuff,'FlowDirection','LeftToRight','Margin',0.0001);
botRowL = most.gui.uiflowcontainer('Parent', botRow,'FlowDirection','LeftToRight');
set(botRowL, 'WidthLimits', 160*ones(1,2));
botRowR = most.gui.uiflowcontainer('Parent', botRow,'FlowDirection','RightToLeft');
set(botStuff, 'HeightLimits', 28*ones(1,2));
ctls.stDraw = most.gui.staticText('Parent',botRowL,'String','   Draw new ROI...','HorizontalAlignment','left','FontWeight','bold','FontSize',12);
ctl = most.gui.uicontrol('Parent',botRowR,'string','Cancel','callback',@obj.newRoiPropsPanelCtlCb,'tag','pbCancel');
set(ctl, 'WidthLimits', 70*ones(1,2));
ctls.pbCreate = most.gui.uicontrol('Parent',botRowR,'string','Create Using Defaults','callback',@obj.newRoiPropsPanelCtlCb,'tag','pbCreateDefault');
set(ctls.pbCreate, 'WidthLimits', 140*ones(1,2));



cols = most.gui.uiflowcontainer('Parent', topStuff,'FlowDirection','LeftToRight');
col1 = most.gui.uiflowcontainer('Parent', cols,'FlowDirection','TopDown','Margin',0.0001);
col2 = most.gui.uiflowcontainer('Parent', cols,'FlowDirection','TopDown','Margin',0.0001);
set(col1, 'WidthLimits', 194*ones(1,2));

up1 = uipanel('parent',col1,'title','Default Stimulus Position/Size');
up = most.gui.uiflowcontainer('Parent', up1,'FlowDirection','TopDown','Margin',0.0001);

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Center X:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 60*ones(1,2));
ctls.etCenterX = most.gui.uicontrol('Parent',hf1,'Style','edit','tag','etCenterX','callback',@obj.newRoiPropsPanelCtlCb);
set(ctls.etCenterX, 'WidthLimits', 60*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Center Y:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 60*ones(1,2));
ctls.etCenterY = most.gui.uicontrol('Parent',hf1,'Style','edit','tag','etCenterY','callback',@obj.newRoiPropsPanelCtlCb);
set(ctls.etCenterY, 'WidthLimits', 60*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Width:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 60*ones(1,2));
ctls.etWidth = most.gui.uicontrol('Parent',hf1,'Style','edit','tag','etWidth','callback',@obj.newRoiPropsPanelCtlCb);
ctls.cbWidthLock = most.gui.uicontrol('Parent',hf1,'Style','Checkbox','string','Lock','Bindings',{obj 'lockScanfieldWidth' 'value'},kpf{:});
set(ctls.etWidth, 'WidthLimits', 60*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Height:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 60*ones(1,2));
ctls.etHeight = most.gui.uicontrol('Parent',hf1,'Style','edit','tag','etHeight','callback',@obj.newRoiPropsPanelCtlCb);
ctls.cbHeightLock = most.gui.uicontrol('Parent',hf1,'Style','Checkbox','string','Lock','Bindings',{obj 'lockScanfieldHeight' 'value'},kpf{:});
set(ctls.etHeight, 'WidthLimits', 60*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Rotation:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 60*ones(1,2));
%ctls.etRotation = most.gui.uicontrol('Parent',hf1,'Style','edit','Bindings',{obj 'defaultRoiRotation' 'value'});
ctls.etRotation = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@obj.newRoiPropsPanelCtlCb,'tag','etRotation');
set(ctls.etRotation, 'WidthLimits', 60*ones(1,2));



upCp = uipanel('parent',col1,'bordertype','none');
up = most.gui.uiflowcontainer('Parent', upCp,'FlowDirection','TopDown','Margin',0.0001);

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Selection Mode:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 84*ones(1,2));
ctls.pmSelMode = most.gui.uicontrol('Parent',hf1,'Style','popupmenu','string',[obj.cellPickModes {'Custom...'}],'Bindings',{obj 'cellPickMode' 'choice'},kpf{:});

upSel = uipanel('parent',up,'title','Selected Cell');
set(upSel, 'HeightLimits', 42*ones(1,2));
upf = most.gui.uiflowcontainer('Parent', upSel,'FlowDirection','LeftToRight');
ctls.pbDilate = uicontrol('Parent',upf,'string','Dilate','enable','off','callback',@obj.pbDilateCell,kpf{:});
ctls.pbErode = uicontrol('Parent',upf,'string','Erode','enable','off','callback',@obj.pbErodeCell,kpf{:});
ctls.pbDelete = uicontrol('Parent',upf,'string','Delete','enable','off','callback',@obj.pbDeleteCell,kpf{:});

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Pause between stims (ms):','HorizontalAlignment','right');
set(nm, 'WidthLimits', 135*ones(1,2));
ctls.etPause = most.gui.uicontrol('Parent',hf1,'Style','edit','Bindings',{obj 'cellPickPauseDuration' 'Value'});
set(ctls.etPause, 'WidthLimits', 50*ones(1,2));


up2 = uipanel('parent',col2,'title','Default Stimulus Parameters');
up = most.gui.uiflowcontainer('Parent', up2,'FlowDirection','TopDown','Margin',0.0001);

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Function:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 50*ones(1,2));
ctls.pmFunction = most.gui.uicontrol('Parent',hf1,'Style','popupmenu','string',obj.stimFcnOptions,'Bindings',{obj 'defaultStimFunction' 'Choice'},kpf{:});

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Fcn Args:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 50*ones(1,2));
ctls.etArgs = most.gui.paramCellArrayEdit('Parent',hf1,'Bindings',{obj 'defaultStimFunctionArgs'});

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Duration (ms):','HorizontalAlignment','right');
set(nm, 'WidthLimits', 70*ones(1,2));
ctls.etDuration = most.gui.uicontrol('Parent',hf1,'Style','edit','Bindings',{obj 'defaultStimDuration' 'Value'});
set(ctls.etDuration, 'WidthLimits', 40*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Repetitions:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 70*ones(1,2));
ctls.etReps = most.gui.uicontrol('Parent',hf1,'Style','edit','Bindings',{obj 'defaultStimRepititions' 'Value'});
set(ctls.etReps, 'WidthLimits', 40*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Beam Power%','HorizontalAlignment','right');
set(nm, 'WidthLimits', 70*ones(1,2));
ctls.etPower = most.gui.uicontrol('Parent',hf1,'Style','edit','Bindings',{obj 'defaultStimPower' 'Value'});
set(ctls.etPower, 'WidthLimits', 40*ones(1,2));

set(up1, 'HeightLimits', 141*ones(1,2));
set(up2, 'HeightLimits', 141*ones(1,2));

ctls.cbDrawMultiple = most.gui.uicontrol('Parent',col2,'Style','Checkbox','string','Draw Multiple','Bindings',{obj 'drawMultipleRois' 'value'},kpf{:});


ctls.rectCtls = up1;
ctls.cellCtls = upCp;
obj.hNewStimRoiPanelCtls = ctls;
obj.hNewStimRoiPanel.Visible = 'off';
end

function createAnalysisRoiPropsPanel(obj,parent,kpf)
obj.hAnalysisRoiPropsPanel = uipanel('Parent', parent);
set(obj.hAnalysisRoiPropsPanel, 'HeightLimits', 197*ones(1,2));
hf = most.gui.uiflowcontainer('Parent', obj.hAnalysisRoiPropsPanel,'FlowDirection','TopDown','Margin',0.0001);
titleBar(hf,'Selected ROI Properties');

hf1 = most.gui.uiflowcontainer('Parent', hf,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','ROI Name:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 65*ones(1,2));
ctls.etName = most.gui.uicontrol('Parent',hf1,'Style','Edit','HorizontalAlignment','left','callback',@obj.analysisRoiPropsPanelCtlCb,'tag','etName');

hf1 = most.gui.uiflowcontainer('Parent', hf,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Unique ID:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 65*ones(1,2));
ctls.etUUID = most.gui.uicontrol('Parent',hf1,'Style','Edit','enable','inactive','HorizontalAlignment','left','BackgroundColor',.95*ones(1,3));


cols = most.gui.uiflowcontainer('Parent', hf,'FlowDirection','LeftToRight','Margin',0.0001);
col1 = most.gui.uiflowcontainer('Parent', cols,'FlowDirection','TopDown','Margin',0.0001);
set(col1, 'WidthLimits', 220*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', col1,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Enabled:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 175*ones(1,2));
ctls.cbEnable = most.gui.uicontrol('Parent',hf1,'Style','Checkbox','callback',@obj.analysisRoiPropsPanelCtlCb,'tag','cbEnable',kpf{:});

hf1 = most.gui.uiflowcontainer('Parent', col1,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Show In Integration Display:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 175*ones(1,2));
ctls.cbDisplay = most.gui.uicontrol('Parent',hf1,'Style','Checkbox','callback',@obj.analysisRoiPropsPanelCtlCb,'tag','cbDisplay',kpf{:});

hf1 = most.gui.uiflowcontainer('Parent', col1,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Discrete Plane Mode:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 175*ones(1,2));
ctls.cbDiscrete = most.gui.uicontrol('Parent',hf1,'Style','Checkbox','callback',@obj.analysisRoiPropsPanelCtlCb,'tag','cbDiscrete',kpf{:});

hf1 = most.gui.uiflowcontainer('Parent', col1,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Number of Scanfield Control Points:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 175*ones(1,2));
ctls.etCPs = most.gui.uicontrol('Parent',hf1,'Style','Edit','HorizontalAlignment','left','enable','inactive','BackgroundColor',.95*ones(1,3));

ctls.pbCreateSf = most.gui.uicontrol('Parent',col1,'String','Create ScanField at Current Z','callback',@obj.editOrCreateScanfieldAtZ,kpf{:});
set(ctls.pbCreateSf, 'HeightLimits', 24*ones(1,2));


col2 = most.gui.uiflowcontainer('Parent', cols,'FlowDirection','TopDown','Margin',0.0001);

hf1 = most.gui.uiflowcontainer('Parent', col2,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Channel:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 70*ones(1,2));
ctls.pmChannel = most.gui.uicontrol('Parent',hf1,'Style','popupmenu','string',{'1' '2' '3' '4'},'callback',@obj.analysisRoiPropsPanelCtlCb,'tag','pmChannel',kpf{:});
set(ctls.pmChannel, 'WidthLimits', 40*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', col2,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Threshold:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 70*ones(1,2));
ctls.etThreshold = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@obj.analysisRoiPropsPanelCtlCb,'tag','etThreshold','Enable','off');
set(ctls.etThreshold, 'WidthLimits', 40*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', col2,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Processor:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 70*ones(1,2));
ctls.pmProcessor = most.gui.uicontrol('Parent',hf1,'Style','popupmenu','string',{'CPU' 'FPGA'},'callback',@obj.analysisRoiPropsPanelCtlCb,'tag','pmProcessor','Enable','off',kpf{:});
set(ctls.pmProcessor, 'WidthLimits', 60*ones(1,2));


hf1 = most.gui.uiflowcontainer('Parent', col2,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','ROI Minimum Z [um]:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 120*ones(1,2));
ctls.etZmin = most.gui.uicontrol('Parent',hf1,'Style','Edit','HorizontalAlignment','left','enable','inactive','BackgroundColor',.95*ones(1,3));

hf1 = most.gui.uiflowcontainer('Parent', col2,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','ROI Maximum Z [um]:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 120*ones(1,2));
ctls.etZmax = most.gui.uicontrol('Parent',hf1,'Style','Edit','HorizontalAlignment','left','enable','inactive','BackgroundColor',.95*ones(1,3));

obj.hAnalysisRoiPropsPanelCtls = ctls;
obj.hAnalysisRoiPropsPanel.Visible = 'off';
end

function createAnalysisSfPropsPanel(obj,parent,kpf)
obj.hAnalysisSfPropsPanel = uipanel('Parent', parent);
set(obj.hAnalysisSfPropsPanel, 'HeightLimits', 148*ones(1,2));

hf = most.gui.uiflowcontainer('Parent', obj.hAnalysisSfPropsPanel,'FlowDirection','TopDown','Margin',0.0001);
titleBar(hf,'Selected Scanfield Properties');

uu = most.gui.uiflowcontainer('Parent', hf,'FlowDirection','TopDown');

up1 = uipanel('parent',uu,'title','Analysis ROI Position/Size');

cols = most.gui.uiflowcontainer('Parent', up1,'FlowDirection','LeftToRight');
col1 = most.gui.uiflowcontainer('Parent', cols,'FlowDirection','TopDown','Margin',0.0001);
col2 = most.gui.uiflowcontainer('Parent', cols,'FlowDirection','TopDown','Margin',0.0001);
set(col1, 'WidthLimits', 180*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', col1,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Z:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 90*ones(1,2));
ctls.etZ = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@obj.analysisSfPropsPanelCtlCb,'tag','etZ');
set(ctls.etZ, 'WidthLimits', 60*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', col1,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Center X:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 90*ones(1,2));
ctls.etCenterX = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@obj.analysisSfPropsPanelCtlCb,'tag','etCenterX');
set(ctls.etCenterX, 'WidthLimits', 60*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', col1,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Center Y:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 90*ones(1,2));
ctls.etCenterY = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@obj.analysisSfPropsPanelCtlCb,'tag','etCenterY');
set(ctls.etCenterY, 'WidthLimits', 60*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', col2,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Width:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 60*ones(1,2));
ctls.etWidth = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@obj.analysisSfPropsPanelCtlCb,'tag','etWidth');
ctls.cbWidthLock = most.gui.uicontrol('Parent',hf1,'Style','Checkbox','string','Lock','Bindings',{obj 'lockScanfieldWidth' 'value'},kpf{:});
set(ctls.etWidth, 'WidthLimits', 60*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', col2,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Height:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 60*ones(1,2));
ctls.etHeight = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@obj.analysisSfPropsPanelCtlCb,'tag','etHeight');
ctls.cbHeightLock = most.gui.uicontrol('Parent',hf1,'Style','Checkbox','string','Lock','Bindings',{obj 'lockScanfieldHeight' 'value'},kpf{:});
set(ctls.etHeight, 'WidthLimits', 60*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', col2,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Rotation:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 60*ones(1,2));
ctls.etRotation = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@obj.analysisSfPropsPanelCtlCb,'tag','etRotation');
set(ctls.etRotation, 'WidthLimits', 60*ones(1,2));


hf1 = most.gui.uiflowcontainer('Parent', uu,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Mask:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 30*ones(1,2));
ctls.etMask = most.gui.uicontrol('Parent',hf1,'Style','edit','HorizontalAlignment','left','callback',@obj.analysisSfPropsPanelCtlCb,'tag','etMask');
clr = most.gui.uicontrol('Parent',hf1,'String','Clear','callback',@obj.analysisSfPropsPanelCtlCb,'tag','pbClearMask',kpf{:});
set(clr, 'WidthLimits', 50*ones(1,2));

obj.hAnalysisSfPropsPanelCtls = ctls;
obj.hAnalysisSfPropsPanel.Visible = 'off';
end

function createNewAnalysisRoiPropsPanel(obj,parent,kpf)
obj.hNewAnalysisRoiPanel = uipanel('Parent', parent);
set(obj.hNewAnalysisRoiPanel, 'HeightLimits', 220*ones(1,2));

flw = most.gui.uiflowcontainer('Parent',obj.hNewAnalysisRoiPanel,'FlowDirection','TopDown','Margin',0.0001);
titleBar(flw,'New ROI');

topStuff = most.gui.uiflowcontainer('Parent',flw,'FlowDirection','TopDown','Margin',0.0001);
botStuff = most.gui.uiflowcontainer('Parent',flw,'FlowDirection','BottomUp','Margin',0.0001);


topRow = most.gui.uiflowcontainer('Parent', topStuff,'FlowDirection','LeftToRight');
set(topRow, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',topRow,'String','Draw By:','HorizontalAlignment','left');
set(nm, 'WidthLimits', 50*ones(1,2));
ctls.rbTopLeftRect = most.gui.uicontrol('Parent',topRow,'Style','radiobutton','string','Top Left Rectangle','callback',@(varargin)set(obj,'newRoiDrawMode','top left rectangle'),kpf{:});
ctls.rbCenterPtRect = most.gui.uicontrol('Parent',topRow,'Style','radiobutton','string','Center Point Rectangle','callback',@(varargin)set(obj,'newRoiDrawMode','center point rectangle'),kpf{:});
ctls.rbCellPick = most.gui.uicontrol('Parent',topRow,'Style','radiobutton','string','Cell Picker','callback',@(varargin)set(obj,'newRoiDrawMode','cell picker'),kpf{:});
set(ctls.rbTopLeftRect, 'WidthLimits', 115*ones(1,2));
set(ctls.rbCenterPtRect, 'WidthLimits', 135*ones(1,2));
set(ctls.rbCellPick, 'WidthLimits', 70*ones(1,2));



botRow = most.gui.uiflowcontainer('Parent', botStuff,'FlowDirection','LeftToRight','Margin',0.0001);
botRowL = most.gui.uiflowcontainer('Parent', botRow,'FlowDirection','LeftToRight');
set(botRowL, 'WidthLimits', 160*ones(1,2));
botRowR = most.gui.uiflowcontainer('Parent', botRow,'FlowDirection','RightToLeft');
set(botStuff, 'HeightLimits', 28*ones(1,2));
ctls.stDraw = most.gui.staticText('Parent',botRowL,'String','   Draw new ROI...','HorizontalAlignment','left','FontWeight','bold','FontSize',12);
ctl = most.gui.uicontrol('Parent',botRowR,'string','Cancel','callback',@obj.newRoiPropsPanelCtlCb,'tag','pbCancel',kpf{:});
set(ctl, 'WidthLimits', 70*ones(1,2));
ctls.pbCreate = most.gui.uicontrol('Parent',botRowR,'string','Create Using Defaults','callback',@obj.newRoiPropsPanelCtlCb,'tag','pbCreateDefault',kpf{:});
set(ctls.pbCreate, 'WidthLimits', 140*ones(1,2));



cols = most.gui.uiflowcontainer('Parent', topStuff,'FlowDirection','LeftToRight');
col1 = most.gui.uiflowcontainer('Parent', cols,'FlowDirection','TopDown','Margin',0.0001);
col2 = most.gui.uiflowcontainer('Parent', cols,'FlowDirection','TopDown','Margin',0.0001);
set(col1, 'WidthLimits', 194*ones(1,2));

up1 = uipanel('parent',col1,'title','Default Stimulus Position/Size');
up = most.gui.uiflowcontainer('Parent', up1,'FlowDirection','TopDown','Margin',0.0001);

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Center X:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 60*ones(1,2));
ctls.etCenterX = most.gui.uicontrol('Parent',hf1,'Style','edit','tag','etCenterX','callback',@obj.newRoiPropsPanelCtlCb);
set(ctls.etCenterX, 'WidthLimits', 60*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Center Y:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 60*ones(1,2));
ctls.etCenterY = most.gui.uicontrol('Parent',hf1,'Style','edit','tag','etCenterY','callback',@obj.newRoiPropsPanelCtlCb);
set(ctls.etCenterY, 'WidthLimits', 60*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Width:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 60*ones(1,2));
ctls.etWidth = most.gui.uicontrol('Parent',hf1,'Style','edit','tag','etWidth','callback',@obj.newRoiPropsPanelCtlCb);
ctls.cbWidthLock = most.gui.uicontrol('Parent',hf1,'Style','Checkbox','string','Lock','Bindings',{obj 'lockScanfieldWidth' 'value'},kpf{:});
set(ctls.etWidth, 'WidthLimits', 60*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Height:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 60*ones(1,2));
ctls.etHeight = most.gui.uicontrol('Parent',hf1,'Style','edit','tag','etHeight','callback',@obj.newRoiPropsPanelCtlCb);
ctls.cbHeightLock = most.gui.uicontrol('Parent',hf1,'Style','Checkbox','string','Lock','Bindings',{obj 'lockScanfieldHeight' 'value'},kpf{:});
set(ctls.etHeight, 'WidthLimits', 60*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Rotation:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 60*ones(1,2));
%    ctls.etRotation = most.gui.uicontrol('Parent',hf1,'Style','edit','Bindings',{obj 'defaultRoiRotation' 'value'});
ctls.etRotation = most.gui.uicontrol('Parent',hf1,'Style','edit', 'callback',@obj.newRoiPropsPanelCtlCb,'tag','etRotation');
set(ctls.etRotation, 'WidthLimits', 60*ones(1,2));



upCp = uipanel('parent',col1,'bordertype','none');
up = most.gui.uiflowcontainer('Parent', upCp,'FlowDirection','TopDown','Margin',0.0001);

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Selection Mode:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 84*ones(1,2));
ctls.pmSelMode = most.gui.uicontrol('Parent',hf1,'Style','popupmenu','string',[obj.cellPickModes {'Custom...'}],'Bindings',{obj 'cellPickMode' 'choice'},kpf{:});

upSel = uipanel('parent',up,'title','Selected Cell');
set(upSel, 'HeightLimits', 42*ones(1,2));
upf = most.gui.uiflowcontainer('Parent', upSel,'FlowDirection','LeftToRight');
ctls.pbDilate = uicontrol('Parent',upf,'string','Dilate','enable','off','callback',@obj.pbDilateCell,kpf{:});
ctls.pbErode = uicontrol('Parent',upf,'string','Erode','enable','off','callback',@obj.pbErodeCell,kpf{:});
ctls.pbDelete = uicontrol('Parent',upf,'string','Delete','enable','off','callback',@obj.pbDeleteCell,kpf{:});

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
ctls.stMargin = most.gui.staticText('Parent',hf1,'String','ROI Margin [um]:','HorizontalAlignment','right');
set(ctls.stMargin, 'WidthLimits', 90*ones(1,2));
ctls.etMargin = most.gui.uicontrol('Parent',hf1,'Style','edit','tag','etMargin','callback',@obj.newRoiPropsPanelCtlCb);
set(ctls.etMargin, 'WidthLimits', 60*ones(1,2));

ctls.cbCreateDiscrete = most.gui.uicontrol('Parent',up,'Style','Checkbox','string','Create as discrete plane ROI','Bindings',{obj 'cellPickCreateAsDiscrete' 'Value'},kpf{:});
set(ctls.cbCreateDiscrete, 'HeightLimits', 24*ones(1,2));

ctls.cbCreateDiscrete = most.gui.uicontrol('Parent',up,'Style','Checkbox','string','Create with mask','Bindings',{obj 'cellPickCreateWithMask' 'Value'},kpf{:});
set(ctls.cbCreateDiscrete, 'HeightLimits', 24*ones(1,2));


up2 = uipanel('parent',col2,'title','Default Analysis Parameters');
up = most.gui.uiflowcontainer('Parent', up2,'FlowDirection','TopDown','Margin',0.0001);

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Channel:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 70*ones(1,2));
ctls.pmChannel = most.gui.uicontrol('Parent',hf1,'Style','popupmenu','string',{'1' '2' '3' '4'},'Bindings',{obj 'defaultAnalysisRoiChannel' 'Value'},kpf{:});
set(ctls.pmChannel, 'WidthLimits', 40*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Threshold:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 70*ones(1,2));
ctls.etThreshold = most.gui.uicontrol('Parent',hf1,'Style','edit','Enable','off','Bindings',{obj 'defaultAnalysisRoiThreshold' 'Value'});
set(ctls.etThreshold, 'WidthLimits', 40*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Processor:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 70*ones(1,2));
ctls.pmProcessor = most.gui.uicontrol('Parent',hf1,'Style','popupmenu','string',{'CPU' 'FPGA'},'Bindings',{obj 'defaultAnalysisRoiProcessor' 'choice'},'Enable','off',kpf{:});
set(ctls.pmProcessor, 'WidthLimits', 60*ones(1,2));

set(up1, 'HeightLimits', 141*ones(1,2));
set(up2, 'HeightLimits', 94*ones(1,2));

ctls.cbDrawMultiple = most.gui.uicontrol('Parent',col2,'Style','Checkbox','string','Draw Multiple','Bindings',{obj 'drawMultipleRois' 'value'},kpf{:});

ctls.rectCtls = up1;
ctls.cellCtls = upCp;
obj.hNewAnalysisRoiPanelCtls = ctls;
obj.hNewAnalysisRoiPanel.Visible = 'off';
obj.newRoiDrawMode = 'top left rectangle';
end

function createBottomControlsPnl(obj,parent,kpf)
set(parent, 'HeightLimits', 124*ones(1,2));

hViewPropsFlow = most.gui.uiflowcontainer('Parent', parent,'FlowDirection','TopDown','Margin',0.0001);
set(hViewPropsFlow, 'WidthLimits', 356*ones(1,2));

% gap
hg = uipanel('parent',hViewPropsFlow,'bordertype','none');
set(hg, 'HeightLimits', 12*ones(1,2));

hViewPropsTopFlow = most.gui.uiflowcontainer('Parent', hViewPropsFlow,'FlowDirection','LeftToRight','Margin',0.0001);
set(hViewPropsTopFlow, 'HeightLimits', [24 24]);

gap = most.gui.staticText('Parent',hViewPropsTopFlow,'String','');
set(gap, 'WidthLimits', 10*ones(1,2));

nm = most.gui.staticText('Parent',hViewPropsTopFlow,'String','Z plane:');
set(nm, 'WidthLimits', 44*ones(1,2));
%zctl = most.gui.uicontrol('Parent',hViewPropsTopFlow,'Style','Edit','HorizontalAlignment','center','Bindings',{obj 'editorZ' 'value'});
obj.hZPlaneCtl = most.gui.uicontrol('Parent',hViewPropsTopFlow,'Style','Edit','HorizontalAlignment','center','callback',@obj.zPlaneCtlCb,'tag','etZPlane');
set(obj.hZPlaneCtl, 'WidthLimits', [40 40]);
set(obj.hZPlaneCtl, 'String', num2str(obj.editorZ));

gap = most.gui.staticText('Parent',hViewPropsTopFlow,'String','');
set(gap, 'WidthLimits', 12*ones(1,2));

nm = most.gui.staticText('Parent',hViewPropsTopFlow,'String','View:');
set(nm, 'WidthLimits', 30*ones(1,2));
obj.tbViewMode2D = uicontrol('Parent',hViewPropsTopFlow,'String','2D','value',true,'style','togglebutton','callback',@(varargin)set(obj,'viewMode','2D'),kpf{:});
obj.tbViewMode3D = uicontrol('Parent',hViewPropsTopFlow,'String','3D','value',false,'style','togglebutton','callback',@(varargin)set(obj,'viewMode','3D'),kpf{:});
set([obj.tbViewMode2D obj.tbViewMode3D], 'WidthLimits', 36*ones(1,2));

gap = most.gui.staticText('Parent',hViewPropsTopFlow,'String','');
set(gap, 'WidthLimits', 12*ones(1,2));

nm = most.gui.staticText('Parent',hViewPropsTopFlow,'String','Projection:');
set(nm, 'WidthLimits', 50*ones(1,2));
obj.tbProjectionModeXZ = uicontrol('Parent',hViewPropsTopFlow,'String','XZ','value',true,'style','togglebutton','callback',@(varargin)set(obj,'projectionMode','XZ'),kpf{:});
obj.tbProjectionModeYZ = uicontrol('Parent',hViewPropsTopFlow,'String','YZ ','value',false,'style','togglebutton','callback',@(varargin)set(obj,'projectionMode','YZ'),kpf{:});
set([obj.tbProjectionModeXZ obj.tbProjectionModeYZ], 'WidthLimits', 36*ones(1,2));


% gap
hg = uipanel('parent',hViewPropsFlow,'bordertype','none');
set(hg, 'HeightLimits', 12*ones(1,2));

%% display units section
hViewPropsBottomFlow = most.gui.uiflowcontainer('Parent', hViewPropsFlow,'FlowDirection','LeftToRight');
up = uipanel('parent',hViewPropsBottomFlow,'title','XY Display Units');
set(up, 'WidthLimits', 148*ones(1,2));
set(up, 'HeightLimits', 72*ones(1,2));
hUnitPanelFlow = most.gui.uiflowcontainer('Parent', up,'FlowDirection','LeftToRight','Margin',0.0001);

% gap
hg = uipanel('parent',hUnitPanelFlow,'bordertype','none');
set(hg, 'WidthLimits', 6*ones(1,2));

hUnitPanelLeftFlow = most.gui.uiflowcontainer('Parent', hUnitPanelFlow,'FlowDirection','TopDown');
set(hUnitPanelLeftFlow, 'WidthLimits', 140*ones(1,2));
obj.pbUnitsUM = most.gui.uicontrol('Parent',hUnitPanelLeftFlow,'String','Microns','value',true,'style','radiobutton','Bindings',{obj 'units' 'match' 'microns'},kpf{:});
obj.pbUnitsSA = most.gui.uicontrol('Parent',hUnitPanelLeftFlow,'String','Scan Angle (Degrees)','value',false,'style','radiobutton','Bindings',{obj 'units' 'match' 'degrees'},kpf{:});
set([obj.pbUnitsUM.hCtl obj.pbUnitsSA.hCtl], 'HeightLimits', 22*ones(1,2));

%% stage position section
hUnitPanelRightFlow = most.gui.uiflowcontainer('Parent', hViewPropsBottomFlow,'FlowDirection','TopDown');
nm = most.gui.staticText('Parent',hUnitPanelRightFlow,'String','Stage Position:');
set(nm, 'WidthLimits', 76*ones(1,2));
set(nm, 'HeightLimits', 20*ones(1,2));
sp = most.gui.uicontrol('Parent',hUnitPanelRightFlow,'String','[0.0, 0.0, 0.0]','style','edit','enable','inactive','BackgroundColor',.95*ones(1,3),'Bindings',{obj 'stagePos' 'string'});
set(sp, 'HeightLimits', 20*ones(1,2));
set(sp, 'WidthLimits', 198*ones(1,2));
upb = uicontrol('Parent',hUnitPanelRightFlow,'String','Update','callback',@(varargin)obj.set('stagePos', nan),kpf{:});
set(upb, 'WidthLimits', 56*ones(1,2));
set(upb, 'HeightLimits', 22*ones(1,2));
end

function createStimOptimizationPanel(obj,parent,kpf)
obj.hStimOptimizationPanel = uipanel('Parent', parent);
set(obj.hStimOptimizationPanel, 'HeightLimits', 128*ones(1,2));

hf = most.gui.uiflowcontainer('Parent', obj.hStimOptimizationPanel,'FlowDirection','TopDown','Margin',0.0001);
titleBar(hf,'Scan Path Optimization');

mainFlow = most.gui.uiflowcontainer('Parent', hf,'FlowDirection','LeftToRight','Margin',0.0001);
leftFlow = most.gui.uiflowcontainer('Parent', mainFlow,'FlowDirection','TopDown','Margin',0.0001);
rightFlow = most.gui.uiflowcontainer('Parent', mainFlow,'FlowDirection','TopDown','Margin',0.0001);


xyFlow1 = most.gui.uiflowcontainer('Parent', leftFlow,'FlowDirection','LeftToRight');
set(xyFlow1, 'HeightLimits', 22*ones(1,2));
ctls.stXYMaxVel = most.gui.staticText('Parent',xyFlow1,'String','XY Max Velocity [deg/ms]:','HorizontalAlignment','right');
set(ctls.stXYMaxVel, 'WidthLimits', 142*ones(1,2));
ctl = most.gui.uicontrol('parent',xyFlow1,'style','edit','Bindings',{obj 'xyMaxVel' 'Value' '%f' 'scaling' 1e-3});
set(ctl, 'WidthLimits', 40*ones(1,2));

xyFlow2 = most.gui.uiflowcontainer('Parent', rightFlow,'FlowDirection','LeftToRight');
set(xyFlow2, 'HeightLimits', 22*ones(1,2));
ctls.stXYMaxAccel = most.gui.staticText('Parent',xyFlow2,'String','XY Max Accel. [deg/ms]:','HorizontalAlignment','right');
set(ctls.stXYMaxAccel, 'WidthLimits', 142*ones(1,2));
ctl = most.gui.uicontrol('parent',xyFlow2,'style','edit','Bindings',{obj 'xyMaxAccel' 'Value' '%f' 'scaling' 1e-6});
set(ctl, 'WidthLimits', 40*ones(1,2));


zFlow1 = most.gui.uiflowcontainer('Parent', leftFlow,'FlowDirection','LeftToRight');
set(zFlow1, 'HeightLimits', 22*ones(1,2));
ctls.stZMaxVel = most.gui.staticText('Parent',zFlow1,'String','Z Max Velocity [um/ms]:','HorizontalAlignment','right');
set(ctls.stZMaxVel, 'WidthLimits', 142*ones(1,2));
ctl = most.gui.uicontrol('parent',zFlow1,'style','edit','Bindings',{obj 'zMaxVel' 'Value' '%f' 'scaling' 1e-3});
set(ctl, 'WidthLimits', 40*ones(1,2));

zFlow2 = most.gui.uiflowcontainer('Parent', rightFlow,'FlowDirection','LeftToRight');
set(zFlow2, 'HeightLimits', 22*ones(1,2));
ctls.stZMaxAccel = most.gui.staticText('Parent',zFlow2,'String','Z Max Accel. [um/ms]:','HorizontalAlignment','right');
set(ctls.stZMaxAccel, 'WidthLimits', 142*ones(1,2));
ctl = most.gui.uicontrol('parent',zFlow2,'style','edit','Bindings',{obj 'zMaxAccel' 'Value' '%f' 'scaling' 1e-6});
set(ctl, 'WidthLimits', 40*ones(1,2));

leftBottomFlow = most.gui.uiflowcontainer('Parent', leftFlow,'FlowDirection','TopDown','Margin',6);
%     most.gui.uicontrol('parent',leftBottomFlow,'style','checkbox','string','Optimize Scan Order','enable','off','Bindings',{obj 'optimizeScanOrder' 'Value'});
most.gui.uicontrol('parent',leftBottomFlow,'style','checkbox','string','Optimize Transition Durations','Bindings',{obj 'optimizeTransitions' 'Value'});
most.gui.uicontrol('parent',leftBottomFlow,'style','checkbox','string','Optimize Stimulation Durations','Bindings',{obj 'optimizeStimuli' 'Value'});

rightBottomFlow = most.gui.uiflowcontainer('Parent', rightFlow,'FlowDirection','BottomUp');
hg = uipanel('parent',rightBottomFlow,'bordertype','none');
set(hg, 'HeightLimits', 3*ones(1,2));
b = most.gui.uicontrol('parent',rightBottomFlow,'string','Optimize Now','callback',@(varargin)obj.optimizePath);
set(b.hCtl, 'WidthLimits', 188*ones(1,2));
set(b.hCtl, 'HeightLimits', 28*ones(1,2));
%     most.gui.uicontrol('parent',rightBottomFlow,'style','checkbox','string','Auto Optimize','Bindings',{obj 'autoOptimize' 'Value'});

obj.hStimOptimizationPanelCtls = ctls;
end

function createStimQuickAddPanel(obj,parent,kpf)
obj.hStimQuickAddPanel = uipanel('Parent', parent);
set(obj.hStimQuickAddPanel, 'HeightLimits', 50*ones(1,2));

hf = most.gui.uiflowcontainer('Parent', obj.hStimQuickAddPanel,'FlowDirection','TopDown','Margin',0.0001);
titleBar(hf,'Quick Add');

uu = most.gui.uiflowcontainer('Parent', hf,'FlowDirection','LeftToRight');

ctl = uicontrol('parent',uu,'string','Add Pause','callback',@(varargin)obj.quickAddPause,kpf{:});
set(ctl, 'WidthLimits', 80*ones(1,2));

ctl = uicontrol('parent',uu,'string','Add Park','callback',@(varargin)obj.quickAddPark,kpf{:});
set(ctl, 'WidthLimits', 80*ones(1,2));

nm = most.gui.staticText('Parent',uu,'String','Duration (ms):','HorizontalAlignment','right');
set(nm, 'WidthLimits', 80*ones(1,2));
ctl = most.gui.uicontrol('parent',uu,'style','edit','Bindings',{obj 'stimQuickAddDuration' 'Value'});
set(ctl, 'WidthLimits', 40*ones(1,2));
end

function createSlmPropsPanel(obj,parent,kpf)
obj.hSlmPropsPanel = uipanel('Parent', parent);
set(obj.hSlmPropsPanel, 'HeightLimits', 162*ones(1,2));

flw = most.gui.uiflowcontainer('Parent',obj.hSlmPropsPanel,'FlowDirection','TopDown','Margin',0.0001);
titleBar(flw,'SLM Pattern Properties');

cols = most.gui.uiflowcontainer('Parent', flw,'FlowDirection','LeftToRight');
col1 = most.gui.uiflowcontainer('Parent', cols,'FlowDirection','TopDown');
col2 = most.gui.uiflowcontainer('Parent', cols,'FlowDirection','TopDown');
set(col1, 'WidthLimits', 194*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', col1,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Scan Function:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 75*ones(1,2));
ctls.pmFunction = most.gui.uicontrol('Parent',hf1,'Style','popupmenu','string',obj.slmScanOptions,'callback',@obj.slmPropsPanelCtlCb,'tag','pmFunction',kpf{:});

hf1 = most.gui.uiflowcontainer('Parent', col1,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Fcn Args:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 50*ones(1,2));
ctls.etArgs = most.gui.paramCellArrayEdit('Parent',hf1,'callback',@obj.slmPropsPanelCtlCb,'tag','etArgs');

hf1 = most.gui.uiflowcontainer('Parent', col1,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Duration (ms):','HorizontalAlignment','right');
set(nm, 'WidthLimits', 75*ones(1,2));
ctls.etDuration = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@obj.slmPropsPanelCtlCb,'tag','etDuration');
set(ctls.etDuration, 'WidthLimits', 40*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', col1,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Repetitions:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 75*ones(1,2));
ctls.etReps = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@obj.slmPropsPanelCtlCb,'tag','etReps');
set(ctls.etReps, 'WidthLimits', 40*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', col2,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Width:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 70*ones(1,2));
ctls.etWidth = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@obj.slmPropsPanelCtlCb,'tag','etWidth');
set(ctls.etWidth, 'WidthLimits', 60*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', col2,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Height:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 70*ones(1,2));
ctls.etHeight = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@obj.slmPropsPanelCtlCb,'tag','etHeight');
set(ctls.etHeight, 'WidthLimits', 60*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', col2,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Rotation:','HorizontalAlignment','right');
set(nm, 'WidthLimits', 70*ones(1,2));
ctls.etRotation = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@obj.slmPropsPanelCtlCb,'tag','etRotation');
set(ctls.etRotation, 'WidthLimits', 60*ones(1,2));

hf1 = most.gui.uiflowcontainer('Parent', col2,'FlowDirection','LeftToRight');
set(hf1, 'HeightLimits', 24*ones(1,2));
nm = most.gui.staticText('Parent',hf1,'String','Beam Power%','HorizontalAlignment','right');
set(nm, 'WidthLimits', 70*ones(1,2));
ctls.etPower = most.gui.uicontrol('Parent',hf1,'Style','edit','callback',@obj.slmPropsPanelCtlCb,'tag','etPower');
set(ctls.etPower, 'WidthLimits', 60*ones(1,2));

ctls.etDone = most.gui.uicontrol('Parent',col2,'String','Done','callback',@obj.finishSlmEdit);

obj.hSlmPropsPanelCtls = ctls;
obj.hSlmPropsPanel.Visible = 'off';
end

function tf = issstim(sf)
tf = numel(sf) && isa(sf,'scanimage.mroi.scanfield.fields.StimulusField');
end

function N = numNonPause(rg)
sfs = [rg.rois.scanfields];
if numel(sfs)
    N = sum(~[sfs.isPause]);
else
    N = 0;
end
end

function cp = cornerpts(sf)
switch class(sf)
    case 'scanimage.mroi.scanfield.fields.IntegrationField'
        hsz = sf.sizeXY / 2;
        pts = [-hsz; -hsz(1) hsz(2); hsz(1) -hsz(2); hsz];
        rot = -sf.rotationDegrees * pi / 180;
        R = [cos(rot) sin(rot) 0;-sin(rot) cos(rot) 0; 0 0 1];
        cp = scanimage.mroi.util.xformPoints(pts,R) + repmat(sf.centerXY,4,1);
    otherwise
        cp = sf.cornerpoints();
end
end

%%  Cell Pick Funcs   %%
%%%%%%%%%%%%%%%%%%%%
% S Peron MAr 2010 %
%%%%%%%%%%%%%%%%%%%%


function inds = cellDetSemiautoGradient(centerPoint,imData,params)
imBounds = size(imData);
YMat = repmat(1:imBounds(1), imBounds(2),1)';
XMat = repmat(1:imBounds(2), imBounds(1),1);

inds = cellDetGradient(centerPoint);

% jitter loop -- try nearby points
if (size(params.jitter,1) > 0) && isempty(inds)
    for ctr=1:size(params.jitter,1)
        inds = cellDetGradient(centerPoint+params.jitter(ctr,:));
        if isempty(inds) ; break ; end
    end
end

    function inds = cellDetGradient(cpt)
        %% --- detection
        inds = [];
        
        % now generate angular profile of luminance
        fullRad = round(2*params.radiusRange(2));
        nSamples = 2*fullRad; % oversample by factor of ~2 samp/pixel
        thetas = linspace(0,2*pi,90);
        
        linProfile=zeros(nSamples,length(thetas));
        for i=1:length(thetas)
            f=most.mimics.improfile(imData,[cpt(2),cpt(2)+fullRad*cos(thetas(i))],[cpt(1),cpt(1)+fullRad*sin(thetas(i))],nSamples,'bilinear')';
            linProfile(:,i)=f;
        end
        
        % get the diff matrix ...
        dlp = diff(linProfile);
        
        % minima/maxima along diff -- that is our initial guess
        if (params.edgeSign == 1)
            [~, edgeIdx] = max(dlp);
        else
            [~, edgeIdx] = min(dlp);
        end
        
        % now smooth this to eliminate further outliers - start at 0, 1/5, 2/5,
        % 3/5, 4/5 of span, the average these 5 -- in case ends were screwy.
        mEdgeIdx = zeros(5,length(thetas));
        idx = 1:length(thetas);
        mEdgeIdx(1,:) = most.mimics.medfilt1(edgeIdx(idx), round(length(thetas)/10));
        for i=2:5
            sp = round(length(idx)/5);
            idx = [idx(sp+1:end) idx(1:sp)]; % shift indexing
            mEdgeIdx(i,idx) = most.mimics.medfilt1(edgeIdx(idx), round(length(thetas)/10));
        end
        sEdgeIdx = median(mEdgeIdx);
        
        % eliminate outliers via applying strict size range from settings, interpolating missing
        %  again with sliding window
        inval = find(sEdgeIdx/2 < params.radiusRange(1) | sEdgeIdx/2 > params.radiusRange(2));
        if (length(inval) > 0.5*length(sEdgeIdx))
            disp('roiGenSemiautoGradient::more than half of points exceed your radius tolerance; not detecting.');
            return;
        end
        if ~isempty(inval); sEdgeIdx = interpMissing(inval, thetas, sEdgeIdx); end
        
        %+++ Removed this routine for now.
        %	 smooth() is not included in vanilla Matlab. The overall routine
        %	 seems robust enough without it. Will revisit if needed.
        %% eliminate outliers in form of big jumps in sEdgeIdx by smooth
        %dPosMax = dPosMax*2; % conver to 2 pixels
        %inval = find(abs(diff(sEdgeIdx)) > dPosMax);
        %if (dPosMax > 0 && length(inval) > 1)
        %sEdgeIdx = smooth(sEdgeIdx, length(thetas/5))';
        %end
        
        %% --- setup indices and border indices
        
        % convert edgeIdx to x, y and actual radius
        fEdgeRad = round(sEdgeIdx)/2;
        X = cpt(2) + fEdgeRad.*cos(thetas);
        Y = cpt(1) + fEdgeRad.*sin(thetas);
        borderXY = [X ; Y]; % temporary ...
        indices = [];
        
        % now fill in border -- i.e., return indices
        % so you can fillToBorder ...
        
        % build tmp new roi, generating corners from border
        %                 tRoi = scanimage.guis.roi.roi(-1, borderXY, [], [1 0 0.5], obj.imageBounds, []);
        fillToBorder();
        borderXY = computeBoundingPoly();
        
        %% --- run post-steps and assign final output
        
        % dilate
        if (params.postDilateBy > 0 && params.postDilateBy >= 1)
            indices = dilateRoiIndices(indices, params.postDilateBy, imBounds);
        elseif (params.postDilateBy > 0) % fractional
            params.postDilateBy = ceil(params.postDilateBy*mean(fEdgeRad));
            indices = dilateRoiIndices(indices, params.postDilateBy, imBounds);
        end
        
        % remove center
        if (params.postFracRemove > 0)
            lumVals = imData(indices);
            [~, sIdx] = sort(lumVals, 'ascend');
            nR = round(params.postFracRemove*length(indices));
            indices = indices(sIdx(nR:end));
        end
        
        % final output
        borderXY = computeBoundingPoly();
        inds = round(indices);
        
        function fillToBorder()
            if (numel(borderXY) > 0)
                xv = borderXY(1,:);
                xv = [xv xv(1)]';
                yv = borderXY(2,:);
                yv = [yv yv(1)]';
                in = inpolygon(XMat, YMat, xv, yv);
                indices = find(in == 1);
            end
        end
        
        function corners = computeBoundingPoly()
            % convert to X Y
            Y = indices-imBounds(1)*floor(indices/imBounds(1));
            X = ceil(indices/imBounds(1));
            Y(Y == 0) = imBounds(1);
            
            % colinear? -- not perfect however!
            if (sum(abs(diff(X))) == 0)
                disp('roi.computeBoundingPoly::colinear points detected, meaning convex hull would fail.  Introducing jitter.');
                ridx = randperm(length(X));
                X(ridx(1:ceil(length(X)/2))) = 1+X(ridx(1:ceil(length(X)/2)));
            end
            if (sum(abs(diff(Y))) == 0)
                disp('roi.computeBoundingPoly::colinear points detected, meaning convex hull would fail.  Introducing jitter.');
                ridx = randperm(length(Y));
                Y(ridx(1:ceil(length(Y)/2))) = 1+Y(ridx(1:ceil(length(Y)/2)));
            end
            
            if (length(X) > 3 && length(Y) > 3)
                % run convex hull
                corn_idx = convhull(X,Y);
                
                corner_x = X(corn_idx);
                corner_y = Y(corn_idx);
                
                % build corners -- but omit last since it repeats
                corners(1,:) = corner_x(1:length(corner_x)-1);
                corners(2,:) = corner_y(1:length(corner_x)-1);
            else
                corners = [];
            end
        end
    end

    function sEdgeIdx  = interpMissing(inval, thetas, sEdgeIdx)
        val = setdiff(1:length(thetas),inval);
        mEdgeIdx = zeros(5,length(thetas));
        mEdgeIdx(1,inval) = interp1(val,sEdgeIdx(val), inval, 'linear', 'extrap');
        mEdgeIdx(:,val) = repmat(sEdgeIdx(val),5,1);
        idx = 1:length(thetas);
        for i=2:5
            sp = round(length(idx)/5);
            idx = [idx(sp+1:end) idx(1:sp)]; % shift indexing
            mEdgeIdx(i,inval) = interp1(idx(val),sEdgeIdx(val), idx(inval), 'linear', 'extrap');
        end
        sEdgeIdx = median(mEdgeIdx);
    end
end

function indices = dilateRoiIndices(indices, numPixels, imageBounds)

% --- construct morphological operator
s1 = imageBounds(1)/min(imageBounds);
s2 = imageBounds(2)/min(imageBounds);
cg = customdisk([2*round(numPixels*s2)+1 2*round(numPixels*s1)+1], ...
    [round(numPixels*s2) round(numPixels*s1)], [round(numPixels*s2) round(numPixels*s1)]+1, 0);

% --- apply
base_im = zeros(imageBounds(1), imageBounds(2));

% dilate it
base_im = 0*base_im;
base_im(indices) = 1;
f_im = most.mimics.imdilate(base_im,cg);
indices = find(f_im == 1);
end

function indices = erodeRoiIndices(indices, numPixels, imageBounds)

% --- construct morphological operator
s1 = imageBounds(1)/min(imageBounds);
s2 = imageBounds(2)/min(imageBounds);
cg = customdisk([2*round(numPixels*s2)+1 2*round(numPixels*s1)+1], ...
    [round(numPixels*s2) round(numPixels*s1)], [round(numPixels*s2) round(numPixels*s1)]+1, 0);

% --- apply
base_im = zeros(imageBounds(1), imageBounds(2));

% dilate it
base_im = 0*base_im;
base_im(indices) = 1;
f_im = most.mimics.imerode(base_im,cg);
indices = find(f_im == 1);
end

function disk = customdisk(mat_size, rad, center, ang)

% --- prelims
if ~isempty(ang)
    if (ang ~= 0)
        disp('customdisk::angle not yet implemented');
    end
end

if (length(mat_size) == 1) ; mat_size = mat_size*[1 1];end
if (length(rad) == 1) ; rad = rad*[1 1];end
if (length(center) == 1) ; center = center*[1 1];end

% --- generate
disk = zeros(mat_size);
[x, y] = meshgrid(1:mat_size(1), 1:mat_size(2));
x = x';
y = y';
ell = ((x-center(1)).^2)/(rad(1)*rad(1)) + ((y-center(2)).^2)/(rad(2)*rad(2));
disk(ell <= 1) = 1;
disk = disk';
%figure;  most.idioms.subplot(2,2,1);	most.mimics.imshow(x, [0 max(max(x))]); most.idioms.subplot(2,2,2);	most.mimics.imshow(y, [0 max(max(y))]); most.idioms.subplot(2,2,3); most.mimics.imshow(ell); most.idioms.subplot(2,2,4) ; most.mimics.imshow(disk);
end

function options = findParamOptions(filename)
options = {};
try
    rows = strsplit(fileread(filename),'\n');
    
    sch = '%% parameter options:';
    n = length(sch);
    i = find(strncmp(rows,sch,n),1);
    if ~isempty(i)
        options = strtrim(strsplit(rows{i}(n+1:end),','));
    end
catch
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
