classdef  BeamControls < most.Gui    
    %% GUI PROPERTIES
    properties (SetAccess=protected,Hidden)
        hPnSelectedControls;
        
        hTblBeams;
        
        hBnShowProfile;
        hBnPowerBoxSettings;
        hBnBrowse;
        hBnShowLUT;
        hBnEdit;
        
        hCbEnablePowerBox;
        hCbFlybackBlanking;
        
        hEtBeamLeadTime;
        hEtPowerValue;
        hEtSourceValue;
        
        hPmSourceOptions;

        hTxSource;
        
        hSldPowerSetting;
        
        hFlSourceBns;
        hFlFormula;
        
        hAxPowerProfile;
        hLnPower;
        hLnPowerReference;
        hLnPowerMarkers;
        hLnLimit;
        
        hAxLUT;
        hLnLUT;
        hLnLUTMarkers;
        hLnZMarkers;
        hLnLutLimit;
        
        hFigPlot;
        
        previousNumBeams = 0;
    end
    
    properties (SetAccess=protected,SetObservable)
        hListeners = event.listener.empty(1,0);
    end
    
    properties (SetObservable,AbortSet)
        beamIdx = 1;
    end
    
    % dependent on beamIdx, the currently selected beam
    properties (Transient,Dependent)
        pzAdjust;
        pzFunction;
        pzLUT;
        pzLUTSource;
        expLzConstant;
        power;
        name;
        beamLeadTime;
        flybackBlanking;
        enablePowerBox;
        scanner;
        powerFractionLimits;
        numBeams;
    end
    
    properties (Constant)
        ADJUST_OPTIONS = {'None','Exponential','Function','LUT'};
        SMALL_WIDTH = 289;
        LARGE_WIDTH = 740;
        LINE_COLOR = [0 0.4470 0.7410];
    end
    
    % getters/setters for dependent properties
    methods
        function val = get.pzAdjust(obj)
            val = obj.hModel.hBeams.pzAdjust(obj.beamIdx);
        end
        
        function set.pzAdjust(obj,val)
            obj.hModel.hBeams.pzAdjust(obj.beamIdx) = val;
        end
        
        function val = get.pzFunction(obj)
            val = obj.hModel.hBeams.pzFunction{obj.beamIdx};
        end
        
        function set.pzFunction(obj,val)
            obj.hModel.hBeams.pzFunction{obj.beamIdx} = val;
        end
        
        function val = get.pzLUT(obj)
            val = obj.hModel.hBeams.pzLUT{obj.beamIdx};
        end
        
        function set.pzLUTSource(obj,val)
            obj.hModel.hBeams.pzLUTSource{obj.beamIdx} = val;
        end
        
        function val = get.pzLUTSource(obj)
            val = obj.hModel.hBeams.pzLUTSource{obj.beamIdx};
        end
        
        function val = get.expLzConstant(obj)
            val = obj.hModel.hBeams.lengthConstants(obj.beamIdx);
        end
        
        function set.expLzConstant(obj,val)
            obj.hModel.hBeams.lengthConstants(obj.beamIdx) = val;
        end
        
        function val = get.power(obj)
            val = obj.hModel.hBeams.powers(obj.beamIdx);
        end
        
        function set.power(obj,val)
            obj.hModel.hBeams.powers(obj.beamIdx) = val;
        end
        
        function val = get.name(obj)
            val = obj.hModel.hBeams.hBeams{obj.beamIdx}.name;
        end
        
        function val = get.flybackBlanking(obj)
            val = obj.hModel.hBeams.flybackBlanking;
        end
        
        function set.flybackBlanking(obj,val)
            obj.hModel.hBeams.flybackBlanking = val;
        end
        
        function val = get.beamLeadTime(obj)
            val = obj.hModel.hScan2D.beamClockDelay * 1e6;
        end
        
        function set.beamLeadTime(obj,val)
            obj.hModel.hScan2D.beamClockDelay = val * 1e-6;
        end
        
        function val = get.enablePowerBox(obj)
            val = obj.hModel.hBeams.enablePowerBox;
        end
        
        function set.enablePowerBox(obj,val)
            obj.hModel.hBeams.enablePowerBox = val;
        end
        
        function val = get.scanner(obj)
            val = [];
            
            if isempty(obj.hModel.hBeams.hBeams)
                return
            end
            
            scanners = obj.hModel.hBeams.currentScanners;
            scanners = [num2cell(scanners.fastBeams),num2cell(scanners.slowBeams)];
            currentBeam = obj.hModel.hBeams.hBeams{obj.beamIdx};
            mask = cellfun(@(s)isequal(s.hDevice,currentBeam),scanners);
            if any(mask)
                val = scanners{mask};
            end
        end
        
        function val = get.powerFractionLimits(obj)
            val = obj.hModel.hBeams.powerFractionLimits(obj.beamIdx);
        end
        
        function val = get.numBeams(obj)
            val = numel(obj.hModel.hBeams.hBeams);
        end
    end
    
    %% LIFECYCLE
    methods
        function obj = BeamControls(hModel, hController)
            if nargin < 1
                hModel = [];
            end
            
            if nargin < 2
                hController = [];
            end
            
            % note this width is updated in redraw, can't use constants in supercall
            obj = obj@most.Gui(hModel, hController, [289 330], 'pixels');
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hListeners);
            most.idioms.safeDeleteObj(obj.hFigPlot);
        end
    end
    
    methods (Access = protected)
        function initGui(obj)
            obj.hFig.Name = 'BEAM CONTROLS';
            
            obj.makeWindow();
            obj.addListeners();
            obj.redraw();
        end
    end
    
    %% GUI/DATA CONSTRUCTION
    methods (Access=protected,Hidden)
        function makeWindow(obj)
            obj.hFig.SizeChangedFcn = @obj.hFig_changedSize;
            
            obj.previousNumBeams = obj.numBeams;
            
            hFlMain = most.gui.uiflowcontainer('Parent',obj.hFig,'FlowDirection','LeftToRight');
                hFlLeftCol = most.gui.uiflowcontainer('Parent',hFlMain,'FlowDirection','TopDown','WidthLimits',[obj.SMALL_WIDTH obj.SMALL_WIDTH]-5);
                hFlRightCol = most.gui.uiflowcontainer('Parent',hFlMain,'FlowDirection','TopDown');
            
            obj.makeTopPanel(hFlLeftCol);
            obj.makeTable(hFlLeftCol);
            obj.makeAdjustPanel(hFlLeftCol);
            obj.makeBottomPanel(hFlLeftCol);
            obj.makeRightPanel(hFlRightCol);
        end
        
        function makeTopPanel(obj,hFlParent)
            % Top panel includes Beam Lead Time, Flyback Blanking
            
            hFlTopHeightLimit = most.gui.uiflowcontainer('Parent',hFlParent,'FlowDirection','LeftToRight','HeightLimits',[40 40]);
                hPnTopItems = uipanel('Parent',hFlTopHeightLimit);
                    hFlTopItems = most.gui.uiflowcontainer('Parent',hPnTopItems,'FlowDirection','LeftToRight');
                        hFlBeamLeadTimeText = most.gui.uiflowcontainer('Parent',hFlTopItems,'FlowDirection','TopDown','WidthLimits',[90 90]);
                            most.gui.uiflowcontainer('Parent',hFlBeamLeadTimeText,'FlowDirection','TopDown','HeightLimits',[3 3]);
                            most.gui.uicontrol('Parent',hFlBeamLeadTimeText,'Style','text','String','Beam Lead Time:','HorizontalAlignment','right');
                        hFlBeamLeadTimeEdit = most.gui.uiflowcontainer('Parent',hFlTopItems,'FlowDirection','TopDown','WidthLimits',[20 Inf]);
                            obj.hEtBeamLeadTime = most.gui.uicontrol('Parent',hFlBeamLeadTimeEdit,'Style','edit','String','1.5','Callback',@obj.hEtBeamLeadTime_changed);
                            obj.hEtBeamLeadTime.hCtl.TooltipString = 'Command line: hSI.hScan2D.beamClockDelay';
                        hFlBeamLeadTimeUnits = most.gui.uiflowcontainer('Parent',hFlTopItems,'FlowDirection','TopDown','WidthLimits',[20 20]);
                            most.gui.uiflowcontainer('Parent',hFlBeamLeadTimeUnits,'FlowDirection','TopDown','HeightLimits',[3 3]);
                            most.gui.uicontrol('Parent',hFlBeamLeadTimeUnits,'Style','text','String','us','HorizontalAlignment','left');
                        hFlFlybackBlanking = most.gui.uiflowcontainer('Parent',hFlTopItems,'FlowDirection','LeftToRight','Margin',3,'WidthLimits',[95 Inf]);
                            obj.hCbFlybackBlanking = most.gui.uicontrol('Parent',hFlFlybackBlanking,'Style','checkbox','String','Blank Flyback','Callback',@obj.hCbFlybackBlanking_changed);
                            obj.hCbFlybackBlanking.hCtl.TooltipString = 'Command line: hSI.hBeams.flybackBlanking';
        end
        
        function makeTable(obj,hFlParent)
            % Table shows all of the beams
            columnFormat = {'char' 'logical' obj.ADJUST_OPTIONS 'numeric'};
            columnEditable = [false true true true];
            columnName = {'Name' 'Sel' 'P/Z Adjust' 'Power %'};
            columnWidth = {110 25 80 55};
            
            hTblBeamsFlow = most.gui.uiflowcontainer('Parent',hFlParent,'FlowDirection','LeftToRight');
                obj.hTblBeams = most.gui.uicontrol('Parent',hTblBeamsFlow,'Style','uitable','ColumnFormat',columnFormat,'ColumnEditable',columnEditable,'ColumnName',columnName,'ColumnWidth',columnWidth,'RowName',[],'CellEditCallback',@obj.tableCallback,'CellSelectionCallback',@obj.tableCellSelectionCallback);
        end
        
        function makeAdjustPanel(obj,hFlParent)
            % Adjust panel includes settings for each beam
            
            hFlWrapHeightLimit = most.gui.uiflowcontainer('Parent',hFlParent,'FlowDirection','LeftToRight','HeightLimits',[120 120]);
                obj.hPnSelectedControls = uipanel('Parent',hFlWrapHeightLimit,'FontWeight','bold');
                    hFlSelectedControls = most.gui.uiflowcontainer('Parent',obj.hPnSelectedControls,'FlowDirection','TopDown');
                        hFlPowerSlider = most.gui.uiflowcontainer('Parent',hFlSelectedControls,'FlowDirection','LeftToRight','HeightLimits',[32 32]);
                            obj.hSldPowerSetting = most.gui.uicontrol('Parent',hFlPowerSlider,'Style','slider','Max',100,'Callback',@obj.hSldPowerSetting_changed);
                            powerTip = sprintf('Note: This is the imaging power used during acquisition,\nnot the current physical power of the beam.\nTo control the beam power directly, use the beam widget in the Widget Bar.');
                            obj.hSldPowerSetting.hCtl.TooltipString = powerTip;
                            hFlPowerET = most.gui.uiflowcontainer('Parent',hFlPowerSlider,'FlowDirection','LeftToRight','WidthLimits',[80 80]);
                                obj.hEtPowerValue = most.gui.uicontrol('Parent',hFlPowerET,'Style','edit','String','0','Callback',@obj.hEtPowerValue_changed);
                                obj.hEtPowerValue.hCtl.TooltipString = powerTip;
                                hFlPowerLbl = most.gui.uiflowcontainer('Parent',hFlPowerET,'FlowDirection','TopDown','WidthLimits',[16 16]);
                                    most.gui.uiflowcontainer('Parent',hFlPowerLbl,'FlowDirection','TopDown','HeightLimits',[2 2]);
                                    most.gui.uicontrol('Parent',hFlPowerLbl,'Style','text','String','%');
                                    
                        hFlPowerAdjust = most.gui.uiflowcontainer('Parent',hFlSelectedControls,'FlowDirection','LeftToRight','HeightLimits',[30 30]);
                            hFlPowerAdjustText = most.gui.uiflowcontainer('Parent',hFlPowerAdjust,'FlowDirection','TopDown','WidthLimits',[0 56]);
                                most.gui.uiflowcontainer('Parent',hFlPowerAdjustText,'FlowDirection','TopDown','HeightLimits',[2 2]);
                                most.gui.uicontrol('Parent',hFlPowerAdjustText,'Style','text','String','P/Z Adjust','HorizontalAlignment','right');
                            hFlAdjustPm = most.gui.uiflowcontainer('Parent',hFlPowerAdjust,'FlowDirection','LeftToRight');
                                obj.hPmSourceOptions = most.gui.uicontrol('Parent',hFlAdjustPm,'Style','popupmenu','String',obj.ADJUST_OPTIONS,'Callback',@obj.hPmPowerSourceOptions_selected);
                                obj.hPmSourceOptions.hCtl.TooltipString = 'The type of power/depth adjustment. Can be either None, Exponential (exponential function), Function (custom user function), or Look-Up Table (LUT).';
                                hFlShowBn = most.gui.uiflowcontainer('Parent',hFlAdjustPm,'FlowDirection','LeftToRight','WidthLimits',[110 110],'Margin',0.0001);
                                    obj.hBnShowProfile = most.gui.uicontrol('Parent',hFlShowBn,'Style','pushbutton','String','Power Z-Profile >>','Callback',@obj.hBnShowProfile_clicked);
                                    obj.hBnShowProfile.hCtl.TooltipString = 'Show/hide the Power/Z curve.';

                        hFlSource = most.gui.uiflowcontainer('Parent',hFlSelectedControls,'FlowDirection','LeftToRight','HeightLimits',[25 25]);
                            hFlSourceTx = most.gui.uiflowcontainer('Parent',hFlSource,'FlowDirection','TopDown','WidthLimits',[0 56]);
                                most.gui.uiflowcontainer('Parent',hFlSourceTx,'FlowDirection','TopDown','HeightLimits',[0.5 0.5]);
                                obj.hTxSource = most.gui.uicontrol('Parent',hFlSourceTx,'Style','text','String','Source','HorizontalAlignment','right');
                            hFlSourceEt = most.gui.uiflowcontainer('Parent',hFlSource,'FlowDirection','LeftToRight');
                                obj.hEtSourceValue = most.gui.uicontrol('Parent',hFlSourceEt,'Style','edit','String','','Callback',@obj.hEtSourceValue_changed);
                                obj.hFlSourceBns = most.gui.uiflowcontainer('Parent',hFlSourceEt,'FlowDirection','LeftToRight','WidthLimits',[30 30],'Margin',0.0001);
                                    obj.hBnEdit = most.gui.uicontrol('Parent',obj.hFlSourceBns,'Style','pushbutton','String','Edit','Callback',@obj.hBnEdit_clicked);
                                    obj.hBnBrowse = most.gui.uicontrol('Parent',obj.hFlSourceBns,'Style','pushbutton','String','Open','Callback',@obj.hBnBrowse_clicked);
                                    obj.hBnShowLUT = most.gui.uicontrol('Parent',obj.hFlSourceBns,'Style','pushbutton','String','Plot','Visible','off','Callback',@obj.hBnPlot_clicked);
                                    obj.hBnShowLUT.hCtl.TooltipString = 'Show a plot with the full look-up table.';
                                    obj.hFlFormula = most.gui.uiflowcontainer('Parent',obj.hFlSourceBns,'FlowDirection','TopDown','Margin',0.0001);
                                        most.gui.uiflowcontainer('Parent',obj.hFlFormula,'FlowDirection','TopDown','HeightLimits',[2 2]);
                                        tooltip = sprintf('P ..... Output power at z\nP0 ... Power at reference z\nz ...... Current z [um]\nz0 .... Reference z [um]\nLz .... Length contstant [um]');
                                        most.gui.uicontrol('Parent',obj.hFlFormula,'Style','text','String','P = P0 * exp( (z-z0) / Lz )','TooltipString',tooltip);
        end
        
        function makeBottomPanel(obj,hFlParent)
            % Bottom panel has powerbox settings
            
            hFlBottomItemsHeightLimit = most.gui.uiflowcontainer('Parent',hFlParent,'FlowDirection','LeftToRight','HeightLimits',[40 40]);
                hPnBottomItems = uipanel('Parent',hFlBottomItemsHeightLimit);
                    hFlBottomItems = most.gui.uiflowcontainer('Parent',hPnBottomItems,'FlowDirection','LeftToRight','Margin',4);
                        obj.hCbEnablePowerBox = most.gui.uicontrol('Parent',hFlBottomItems,'Style','checkbox','String','Enable Power Box','Callback',@obj.hCbEnablePowerBox_changed);
                        obj.hCbEnablePowerBox.hCtl.TooltipString = 'Command line: hSI.hBeams.enablePowerBox';
                        obj.hBnPowerBoxSettings = most.gui.uicontrol('Parent',hFlBottomItems,'Style','pushbutton','String','Power Box Settings','Callback',@obj.hBnPowerBoxSettings_clicked);
        end
        
        function makeRightPanel(obj,hFlParent)
            % Right panel has the power profile plot
            
            hFlOuterRightPanel = most.gui.uiflowcontainer('Parent',hFlParent,'FlowDirection','TopDown','WidthLimits',[300 Inf]);
                hPnRightPanel = uipanel('Parent',hFlOuterRightPanel,'Title','Power Z-Profile');
                    hFlRightPanel = most.gui.uiflowcontainer('Parent',hPnRightPanel,'FlowDirection','TopDown');
                        obj.hAxPowerProfile = most.idioms.axes('Parent',hFlRightPanel);
                        obj.hLnPower =  line('Parent',obj.hAxPowerProfile,'XData',[],'YData',[],'Color',obj.LINE_COLOR);
                        obj.hLnPowerMarkers = line('Parent',obj.hAxPowerProfile,'XData',[],'YData',[],'Color',obj.LINE_COLOR,'Marker','o','LineStyle','none');
                        obj.hLnPowerReference = line('Parent',obj.hAxPowerProfile,'XData',[],'YData',[],'Color',most.constants.Colors.red,'MarkerFaceColor',most.constants.Colors.lightRed,'Marker','o','LineStyle','none');
                        obj.hLnLimit = line('Parent',obj.hAxPowerProfile,'XData',[],'YData',[],'Color',most.constants.Colors.red,'LineStyle','--');
            
            dcm = datacursormode(obj.hFig);
            dcm.UpdateFcn = @obj.getPlotDatatip;
            dcm.Enable = 'on';
            
            grid(obj.hAxPowerProfile,'on');
            obj.hAxPowerProfile.NextPlot = 'add';
            obj.hAxPowerProfile.Box = 'on';
            xlabel(obj.hAxPowerProfile,'z [um]');
            ylabel(obj.hAxPowerProfile,'Power [%]');
            obj.hAxPowerProfile.XLim = [0 10];
            obj.hAxPowerProfile.YLim = [0 105];
        end
        
        function makeLUTPlot(obj)
            if most.idioms.isValidObj(obj.hFigPlot)
                most.idioms.figure(obj.hFigPlot);
                return
            end
            
            obj.hFigPlot = most.idioms.figure('NumberTitle','off','MenuBar','none','CloseRequestFcn',@obj.closeLUTPlot,'Visible','off');
            hFlFig = most.idioms.uiflowcontainer('Parent',obj.hFigPlot,'FlowDirection','TopDown');
            obj.hAxLUT = most.idioms.axes('Parent',hFlFig,'YLim',[0 105]);
            grid(obj.hAxLUT,'on');
            box(obj.hAxLUT,'on');
            
            dcm = datacursormode(obj.hFigPlot);
            dcm.UpdateFcn = @obj.getPlotDatatip;
            dcm.Enable = 'on';
            
            xlabel(obj.hAxLUT,'Z-Depth [um]');
            ylabel(obj.hAxLUT,'Beam power [%]');
            
            obj.hLnLUT = line('Parent',obj.hAxLUT,'XData',[],'YData',[],'Color',obj.LINE_COLOR);
            obj.hLnZMarkers = line('Parent',obj.hAxLUT,'Marker','o','LineStyle','none','XData',[],'YData',[],'Color',obj.LINE_COLOR);
            obj.hLnLUTMarkers = line('Parent',obj.hAxLUT,'Marker','.','MarkerSize',10,'LineStyle','none','XData',[],'YData',[],'Color',most.constants.Colors.black);
            obj.hLnLutLimit = line('Parent',obj.hAxLUT,'XData',[],'YData',[],'Color',most.constants.Colors.red,'LineStyle','--');
            
            legend(obj.hAxLUT,[obj.hLnLUTMarkers obj.hLnZMarkers],{'LUT Point','Power/Z Profile (Interpolated)'},'Location','northwest');
        end
        
        function addListeners(obj)
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hModel.hBeams,'hBeams','PostSet',@obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hModel.hBeams,'pzAdjust','PostSet',@obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hModel.hBeams,'flybackBlanking','PostSet',@obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hModel.hBeams,'enablePowerBox','PostSet',@obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hModel.hBeams,'lengthConstants','PostSet',@obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hModel.hBeams,'pzFunction','PostSet',@obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hModel.hBeams,'pzLUTSource','PostSet',@obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hModel.hBeams,'powers','PostSet',@obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj,'beamIdx','PostSet',@obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hModel.hStackManager,'actualNumSlices','PostSet',@obj.zsChanged);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hModel,'hScan2D','PostSet',@obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hModel.hStackManager,'zs','PostSet',@obj.zsChanged);
            
            for idx = 1:numel(obj.hModel.hScanners)
                obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hModel.hScanners{idx},'hBeams','PostSet',@obj.redraw);
                obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hModel.hScanners{idx},'beamClockDelay','PostSet',@obj.redraw);
            end
        end
    end
    
    methods
        function redraw(obj,varargin)
            obj.beamIdx = coerceBeamIdx(obj.beamIdx);
            
            obj.redrawTopBottom();
            obj.redrawAdjust();
            obj.redrawTable();
            obj.redrawProfile();
            obj.redrawProfileButton();
            obj.redrawLUTPlot();
            raiseWindow();
            
            %%% Nested functions
            function beamIdx = coerceBeamIdx(beamIdx)
                beamIdx = min(obj.numBeams,beamIdx);
                beamIdx = max(1,beamIdx);
            end
            
            function raiseWindow()
                if obj.numBeams > obj.previousNumBeams
                    obj.raise();
                end
                obj.previousNumBeams = obj.numBeams;
            end
        end
        
        function redrawTopBottom(obj,varargin)
            obj.hEtBeamLeadTime.String = sprintf('%g',obj.beamLeadTime);
            obj.hCbFlybackBlanking.Value = obj.flybackBlanking;
            obj.hCbEnablePowerBox.Value = obj.enablePowerBox;
        end
        
        function redrawAdjust(obj,varargin)
            if obj.numBeams <= 0
                obj.hTxSource.Visible = false;
                obj.hEtSourceValue.Visible = false;
                obj.hSldPowerSetting.Enable = false;
                obj.hEtPowerValue.Enable = false;
                obj.hBnShowLUT.Visible = false;
                obj.hFlFormula.Visible = 'off';
                obj.hBnBrowse.Visible = false;
                obj.hBnEdit.Visible = false;
                obj.hBnShowLUT.Visible = false;
                
                obj.hPnSelectedControls.Title = '';
                obj.hPmSourceOptions.Value = 1;
                obj.hPmSourceOptions.Enable = false;
                
                return;
            end
            
            % set properties that only depend on one state
            obj.hTxSource.Visible       = most.gui.OnOff(obj.pzAdjust ~= scanimage.types.BeamAdjustTypes.None);
            obj.hEtSourceValue.Visible  = most.gui.OnOff(obj.pzAdjust ~= scanimage.types.BeamAdjustTypes.None);
            obj.hSldPowerSetting.Enable = most.gui.OnOff(obj.pzAdjust ~= scanimage.types.BeamAdjustTypes.LUT);
            obj.hEtPowerValue.Enable    = most.gui.OnOff(obj.pzAdjust ~= scanimage.types.BeamAdjustTypes.LUT);
            obj.hBnShowLUT.Visible      = most.gui.OnOff(obj.pzAdjust == scanimage.types.BeamAdjustTypes.LUT);
            obj.hFlFormula.Visible      = most.gui.OnOff(obj.pzAdjust == scanimage.types.BeamAdjustTypes.Exponential);
            
            obj.hPnSelectedControls.Title = sprintf('"%s" Aquisition Power Options',obj.name);
            obj.hPmSourceOptions.Value = double(obj.pzAdjust)+1;
            
            obj.hSldPowerSetting.Value = obj.power;
            obj.hEtPowerValue.String = sprintf('%.4g',obj.power);
            
            obj.hPmSourceOptions.Enable = true;
            obj.hBnShowLUT.Enable = obj.pzAdjust == scanimage.types.BeamAdjustTypes.LUT;
            obj.hTxSource.hCtl.TooltipString = most.idioms.ifthenelse(obj.pzAdjust==scanimage.types.BeamAdjustTypes.LUT,'Look-Up Table','');
            
            % set properties that depend on multiple states
            switch obj.pzAdjust
                case scanimage.types.BeamAdjustTypes.None
                    obj.hBnBrowse.Visible = false;
                    obj.hBnEdit.Visible = false;
                case scanimage.types.BeamAdjustTypes.Exponential
                    obj.hTxSource.String = 'Lz (um)';
                    obj.hEtSourceValue.hCtl.TooltipString = 'The exponential length constant Lz in microns (um).';
                    obj.hEtSourceValue.String = sprintf('%g',obj.expLzConstant);
                    obj.hBnBrowse.Visible = false;
                    obj.hBnEdit.Visible = false;
                    obj.hFlSourceBns.WidthLimits = [150 150];
                case scanimage.types.BeamAdjustTypes.Function
                    obj.hTxSource.String = 'Function';
                    obj.hEtSourceValue.hCtl.TooltipString = ['A function of the form "powerPercents = PowerFunction(startPower,zPowerReference,z)" '... 
                                                       'located on the MATLAB path and saved as a .m file.'];
                    obj.hBnBrowse.hCtl.TooltipString = 'Open the file dialog to browse for the function''s .m file. Note the file must be on the MATLAB path.';
                    obj.hEtSourceValue.String = func2str(obj.pzFunction);
                    obj.hBnBrowse.Visible = true;
                    obj.hBnEdit.Visible = true;
                    obj.hFlSourceBns.WidthLimits = [60 60];
                case scanimage.types.BeamAdjustTypes.LUT
                    obj.hTxSource.String = 'LUT';
                    obj.hEtSourceValue.hCtl.TooltipString = ['A 2-column matrix saved as a .mat or .csv file where the 1st column represents z-depths '...
                                                       'in microns and the 2nd column represents beam powers in percents.'];
                    obj.hBnBrowse.hCtl.TooltipString = 'Open the file dialog to browse for the Look-Up Table''s .mat or .csv file.';
                    if isnumeric(obj.pzLUTSource)
                        obj.hEtSourceValue.String = '<matrix>';
                    else
                        obj.hEtSourceValue.String = obj.pzLUTSource;
                    end
                    obj.hBnBrowse.Visible = true;
                    obj.hBnEdit.Visible = false;
                    obj.hFlSourceBns.WidthLimits = [61 61];
                otherwise
                    most.ErrorHandler.logAndReportError('Unknown option for depth power-adjustment source: ''%s''',obj.pzAdjust);
            end
        end
        
        function redrawTable(obj,varargin)
            if obj.numBeams <= 0
                obj.hTblBeams.Data = [];
                
                return;
            end
            
            rowNames = cellfun(@(c)c.name,obj.hModel.hBeams.hBeams(:),'UniformOutput',false);
            usedBeamNames = cellfun(@(c)c.name,obj.hModel.hBeams.currentBeams,'UniformOutput',false);
            
            idx = false(obj.numBeams,1);
            idx(obj.beamIdx) = true;
            idx = num2cell(idx);
            
            pzAdjust = double(obj.hModel.hBeams.pzAdjust)+1;
            pzAdjust = obj.ADJUST_OPTIONS(pzAdjust)';
            
            powers = round(obj.hModel.hBeams.powers(:),2);
            powers = num2cell(powers);
            
            for i = 1:obj.numBeams
                inUse = any(strcmp(usedBeamNames,rowNames{i}));
                if inUse
                    rowNames{i} = ['<' rowNames{i} '>']; % could use HTML to highlight
                end
            end
            
            data = [rowNames idx pzAdjust powers];
            
            obj.hTblBeams.Data = data;
        end
        
        function zsChanged(obj,varargin)
            obj.redrawProfile();
            obj.redrawLUTPlot();
        end
        
        function redrawProfile(obj,varargin)
            if obj.numBeams <= 0
                % hide profile if no beams
                p = get(obj.hFig, 'position');
                p = min([Inf Inf obj.SMALL_WIDTH Inf],p);
                set(obj.hFig, 'position', p);
                
                return;
            end
            
            scanner_ = obj.scanner;
            if isempty(scanner_)
                drawEmptyProfile();
                return
            end
            
            allZs = obj.hModel.hStackManager.zsAllActuators;
            if size(allZs,2) >= scanner_.beamIdx
                zs = allZs(:,scanner_.beamIdx)';
            else
                zs = allZs(:,1)';
            end
            
            samplingMask = 1:length(zs);
            
            if ~isscalar(zs) && obj.hModel.hStackManager.isFastZ && strcmpi(obj.hModel.hFastZ.waveformType,'sawtooth')
                zs = [zs 2*zs(end)-zs(end-1)];
            end
            
            powerReference = scanner_.powerFraction;
            pzReferenceZ = scanner_.pzReferenceZ;
            powers = scanner_.powerDepthCorrectionFunc(powerReference, zs(:));
            powersReference = scanner_.powerDepthCorrectionFunc(powerReference, pzReferenceZ);
            
            if isscalar(zs)
                zs = [zs-1;zs;zs+1];
                powers = repmat(powers,3,1);
                samplingMask = 2;
            end
            
            powersPercent = powers * 100;
            powersReferencePercent = powersReference * 100;
            
            if obj.pzAdjust == scanimage.types.BeamAdjustTypes.Exponential || obj.pzAdjust == scanimage.types.BeamAdjustTypes.Function
                obj.hLnPowerReference.XData = pzReferenceZ;
                obj.hLnPowerReference.YData = powersReferencePercent;
            else
                obj.hLnPowerReference.XData = [];
                obj.hLnPowerReference.YData = [];
            end
            
            obj.hLnPower.XData = zs;
            obj.hLnPower.YData = powersPercent;
            obj.hLnPowerMarkers.XData = zs(samplingMask);
            obj.hLnPowerMarkers.YData = powersPercent(samplingMask);
            
            xRange = [min(zs),max(zs)];
            xRange = mean(xRange) + [-diff(xRange) diff(xRange)] * 0.6; % expand xRange
            if xRange(1) == xRange(2)
                xRange = [xRange(1)-1 xRange(2)+1]; % for sanity
            end
            
            drawPowerLimit(xRange);
            
            obj.hAxPowerProfile.XLim = xRange;
            
            %%% Nested function
            function drawEmptyProfile()
                xRange = [-1 1];
                drawPowerLimit(xRange);
                obj.hAxPowerProfile.XLim = xRange;
                obj.hLnPowerReference.XData = [];
                obj.hLnPowerReference.YData = [];
                obj.hLnPower.XData = [];
                obj.hLnPower.YData = [];
                obj.hLnPowerMarkers.XData = [];
                obj.hLnPowerMarkers.YData = [];
            end
            
            function drawPowerLimit(xLim)
                if obj.powerFractionLimits < 1
                    obj.hLnLimit.XData = xLim;
                    obj.hLnLimit.YData = [100 100] * obj.powerFractionLimits;
                else
                    obj.hLnLimit.XData = [];
                    obj.hLnLimit.YData = [];
                end
            end
        end
        
        function redrawProfileButton(obj,varargin)
            obj.hBnShowProfile.Enable = obj.numBeams > 0;
            
            p = get(obj.hFig, 'position');
            if p(3) <= obj.SMALL_WIDTH
                obj.hBnShowProfile.String = 'Power Z-Profile >>';
            else
                obj.hBnShowProfile.String = 'Power Z-Profile <<';
            end
        end
        
        function redrawLUTPlot(obj,varargin)            
            if obj.numBeams <= 0 || obj.pzAdjust~=scanimage.types.BeamAdjustTypes.LUT
                obj.closeLUTPlot();
                return;
            end
            
            % don't redraw component when it's not visible
            if ~most.idioms.isValidObj(obj.hFigPlot) || strcmp(obj.hFigPlot.Visible,'off')
                return;
            end

            currentScanner_ = obj.scanner;

            if isempty(currentScanner_)
                zsInUseX = [];
            else
                allZs = obj.hModel.hStackManager.zsAllActuators;
                if size(allZs,2) >= currentScanner_.beamIdx
                    zsInUseX = allZs(:,currentScanner_.beamIdx)';
                else
                    zsInUseX = allZs(:,1)';
                end
            end

            if ~isempty(currentScanner_)

                figName = sprintf('"%s" Power/Z LUT',obj.name);
                obj.hFigPlot.Name = figName;
                title(obj.hAxLUT,figName);

                pzLUT_ = obj.pzLUT;
                lutDataX = pzLUT_(:,1);
                lutDataY = pzLUT_(:,2) * 100;


                zsInUseY = currentScanner_.powerDepthCorrectionFunc(currentScanner_.powerFraction,zsInUseX)*100;

                allXs = unique([lutDataX(:);zsInUseX(:)]);
                allYs = currentScanner_.powerDepthCorrectionFunc(currentScanner_.powerFraction,allXs)*100;

                obj.hLnLUT.XData = allXs;
                obj.hLnLUT.YData = allYs;

                obj.hLnZMarkers.XData = zsInUseX;
                obj.hLnZMarkers.YData = zsInUseY;

                obj.hLnLUTMarkers.XData = lutDataX;
                obj.hLnLUTMarkers.YData = lutDataY;

                xSpace = round((max(allXs)-min(allXs))/15);
                xSpace = max([xSpace 1]);
                xLim = [min(allXs)-xSpace max(allXs)+xSpace];

                if isempty(xLim)
                    xLim = [-1 1];
                end

                obj.hAxLUT.XLim = xLim;

                if currentScanner_.powerFractionLimit < 1
                    obj.hLnLutLimit.XData = xLim;
                    obj.hLnLutLimit.YData = [100 100] * currentScanner_.powerFractionLimit;
                else
                    obj.hLnLutLimit.XData = [];
                    obj.hLnLutLimit.YData = [];
                end
            else
                figName = sprintf('%s not paired with selected imaging scanner',obj.name);
                obj.hFigPlot.Name = figName;
                title(obj.hAxLUT,figName);

                obj.hLnLUT.XData = [];
                obj.hLnLUT.YData = [];

                obj.hLnZMarkers.XData = [];
                obj.hLnZMarkers.YData = [];

                obj.hLnLUTMarkers.XData = [];
                obj.hLnLUTMarkers.YData = [];

                obj.hLnLutLimit.XData = [];
                obj.hLnLutLimit.YData = [];
            end
        end
        
        function closeLUTPlot(obj,varargin)
            obj.hFigPlot.Visible = false;
        end
        
        function datatip = getPlotDatatip(obj,~,info)
            datatip = sprintf('(%g,% g)',info.Position(1),info.Position(2));
        end
        
        function highlightCurrentBeamWidget(obj)
            hBeam = obj.hModel.hBeams.hBeams{obj.beamIdx};
            if isa(hBeam,'dabs.resources.widget.HasWidget')
                hBeam.highlightWidgets();
            end
        end
    end
    
    % callbacks
    methods
        function tableCellSelectionCallback(obj,src,evt)
            if isempty(evt.Indices)
                return;
            end
            
            switch evt.Indices(2)
                case 1
                    obj.beamIdx = evt.Indices(1);
                    obj.highlightCurrentBeamWidget();
            end
        end
        
        function tableCallback(obj,src,evt)
            if isempty(evt.Indices)
                return;
            end
            
            try
                obj.beamIdx = evt.Indices(1);
                
                switch evt.Indices(2)
                    case 2
                        obj.highlightCurrentBeamWidget();
                    case 3
                        adjustVal = find(strcmp(obj.ADJUST_OPTIONS,evt.NewData))-1;
                        obj.pzAdjust = scanimage.types.BeamAdjustTypes(adjustVal);
                    case 4
                        obj.power = evt.NewData;
                end
                
                obj.redraw();
                
            catch ME
                most.ErrorHandler.logAndReportError(ME);
                obj.redraw();
            end
        end
        
        function hEtBeamLeadTime_changed(obj,varargin)
            val = str2double(obj.hEtBeamLeadTime.String);
            
            try
                obj.beamLeadTime = val;
            catch ME
                most.ErrorHandler.logAndReportError(ME);
                obj.redraw();
            end
        end
        
        function hEtSourceValue_changed(obj,varargin)
            try
                switch obj.pzAdjust
                    case scanimage.types.BeamAdjustTypes.None
                        % No-op
                    case scanimage.types.BeamAdjustTypes.Exponential
                        val = str2double(obj.hEtSourceValue.String);
                        obj.expLzConstant = val;
                    case scanimage.types.BeamAdjustTypes.Function
                        obj.pzFunction = obj.hEtSourceValue.String;
                    case scanimage.types.BeamAdjustTypes.LUT
                        obj.pzLUTSource = obj.hEtSourceValue.String;
                    otherwise
                        error('Unknown option for depth power-adjustment source: ''%s''',obj.pzAdjust);
                end
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
            
            obj.redraw();
        end
        
        function hPmPowerSourceOptions_selected(obj,varargin)
            obj.pzAdjust = scanimage.types.BeamAdjustTypes(obj.hPmSourceOptions.Value-1);
        end
        
        function hCbFlybackBlanking_changed(obj,varargin)
            obj.flybackBlanking = obj.hCbFlybackBlanking.Value;
        end
        
        function hCbEnablePowerBox_changed(obj,varargin)
            obj.enablePowerBox = obj.hCbEnablePowerBox.Value;
        end
        
        function hSldPowerSetting_changed(obj,varargin)
            obj.power = round(obj.hSldPowerSetting.Value);
        end
        
        function hEtPowerValue_changed(obj,varargin)
            val = str2double(obj.hEtPowerValue.String);
            
            try
                obj.power = val;
            catch ME
                most.ErrorHandler.logAndReportError(ME);
                obj.redraw();
            end
        end
        
        function hBnShowProfile_clicked(obj,varargin)
            p = get(obj.hFig, 'position');
            
            if p(3) <= obj.SMALL_WIDTH
                p = max([0 0 obj.LARGE_WIDTH 0],p);
            else
                p = min([Inf Inf obj.SMALL_WIDTH Inf],p);
            end
            
            set(obj.hFig, 'position', p);
        end
        
        function hBnPowerBoxSettings_clicked(obj,varargin)
            obj.hController.showGUI('powerBoxControlsV4');
            obj.hController.raiseGUI('powerBoxControlsV4');
        end
        
        function hBnEdit_clicked(obj,varargin)
            funcString = scanimage.util.validateFunctionHandle(obj.pzFunction);
            edit(funcString);
        end
        
        function hBnBrowse_clicked(obj,varargin)
            root = scanimage.util.siRootDir;
            if root(end) ~= '\'
                root(end+1) = '\';
            end
            
            switch obj.pzAdjust
                case scanimage.types.BeamAdjustTypes.Function
                    [file,path] = uigetfile({'*.m' 'MATLAB Function (*.m)'});
                    if ~file
                        return;
                    else                        
                        filepath = fullfile(path,file);
                        [~,~,~,fullyQualifiedName] = most.idioms.getFunctionInfo(filepath);
                        
                        obj.pzFunction = fullyQualifiedName;
                    end
                    
                case scanimage.types.BeamAdjustTypes.LUT
                    [file,path] = uigetfile({'*.mat;*.csv' 'MATLAB Matrix (*.mat,*.csv)'});
                    if ~file
                        return;
                    else
                        fullpath = strcat(path,file);
                        indices = strfind(fullpath,root);
                        
                        if ~isempty(indices) && indices(1) == 1
                            fullpath = erase(fullpath,root);
                        end
                        
                        obj.pzLUTSource = fullpath;
                    end
            end
        end
        
        function hBnPlot_clicked(obj,varargin)
            obj.makeLUTPlot();
            
            obj.hFigPlot.Visible = true;
            obj.redrawLUTPlot();
        end
        
        function hFig_changedSize(obj,varargin)
            % todo: see if theres a better way that gets rid of the flashy effect
            % also, doesn't work if you click and hold a long press, then
            % let go. Must also make a timer function which will
            % occasionally check the size
            p = get(obj.hFig, 'position');
            p = max([0 0 obj.SMALL_WIDTH 0],p);
            set(obj.hFig, 'position', p);
            
            obj.redrawProfileButton;
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
