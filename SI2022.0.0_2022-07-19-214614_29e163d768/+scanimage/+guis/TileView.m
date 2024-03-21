classdef TileView < most.Gui

    properties(Hidden, SetAccess=private)
       hPropListeners = [];                 % [Listener] Array of Property Listeners for updating UI, etc
       hOverViewTileDispListeners = [];     % [Listener] Array of Listeners for Overview Tile Display objects
       hScanTileDispListeners = [];         % [Listener] Array of Listeners for Scan Tile Display objects
    end
    
    % GUI Props
    properties(Hidden)                       
        hFovAxes;
        hFovPanel;
        
        hOverviewTileGroup;
        hScanTileGroup;
        hLiveDisplayGroup;
        hCrosshairGroup;
        
        maxFov = 100000;
        currentFovSize = 100;
        currentFovPos = [0 0];
        
        hXTicks = matlab.graphics.primitive.Text.empty();
        hYTicks = matlab.graphics.primitive.Text.empty();
        
        % Side Control Panel
        %% Gen Set
        statText;
        scanProgTxt;
        numOverviewTxt;
        numScanTxt;        
        
        %% Live
        hLiveChanTable;
        pbEnableLiveMode;
        txtLiveTileSize;
        txtLiveTilePos;
        
        hLiveTileDisp;
        
        %% Overview Tiles
        hOverviewChanTbl;
        pbOverviewTilesHideAll;
        
        %% Scan Tile
        hScnTileChanTbl;
        pbShowHideScanTiles;
        hTools;
        hToolBtnPositionsStart;
        
        %% zStuff
        hZAxes;
        hZprojectionScrollKnob;
        hZprojectionScrollLine;
        
        etZPos;
        cbZTrack;
        
        %% Crosshair
        Crosshair;       
        crosshairCenter;
    end
    
    properties
        hLiveTileDataWindow;
        hSavedPositionsWindow;
        hSavedPositionsTable;
        % Move others to separate Windows
    end
    
    % So Draw functions in tile disps dont have to query axes.
    properties(SetAccess = private, SetObservable, Hidden)
       hFOV_AxPos;
       hFOV_XYLim;
       hFOV_ZLim;
    end
    
    % Tile Displays
    properties(SetAccess=private)
        hOverViewTileDisps = scanimage.guis.tileDisplay.overviewTileDisplay.empty();    % [Tile Disp] Array of Tile Display objects for rendering the Overview
        hScanTileDisps = scanimage.guis.tileDisplay.scanTileDisplay.empty();            % [Tile Disp] Array of Tile Display objects for rendering the Scan Tiles
    end
    
    % Gui related control properties
    properties (SetObservable)
        liveTileEnable = false;
        
        % Live channel properties
        liveChansToShow;
        liveChanImageColors;
        liveChanAlphas;
        
        % Overview channel properties
        overviewChansToShow;
        overviewChanImageColors;
        overviewChanAlphas;
        overviewTileColor;
        
        % Scan channel properties
        scanChansToShow;
        scanChanImageColors;
        scanChanAlphas;
        
        % Toggle hide/show tiles
        overviewTileShowHideTf = true;
        scanTileShowHideTf = true;
    end
    
    properties(SetAccess=private, Hidden)
        tileTool;           % Active tile tool. 
        tileColorMap;       % [Container Map] Colors for overview tile outlines. 
    end
    
    properties(SetObservable)
        zProjectionRange = [-100 100];
        currentZ = 0;
        overviewTileZs;
        scanTileZs;
        liveTileZs;
        zTracksSample = false;
    end
    
    
    %% LifeCycle
    methods
        function obj = TileView(hModel, hController)
            if nargin < 1
                hModel = [];
            end
            
            if nargin < 2
                hController = [];
            end
            
            size = [1600,1050];
            obj = obj@most.Gui(hModel,hController,size,'pixels');
            obj.showWaitbarDuringInitalization = true;
        end
        
        function delete(obj)
            %% Delete All The GUI Stuff to be safe - unnecessary?
            most.idioms.safeDeleteObj(obj.hFig);
            most.idioms.safeDeleteObj(obj.hLiveTileDataWindow);
            most.idioms.safeDeleteObj(obj.hSavedPositionsWindow);
            
            most.idioms.safeDeleteObj(obj.hOverViewTileDisps);
            most.idioms.safeDeleteObj(obj.hScanTileDisps);
            
            % Delete the Listeners
            most.idioms.safeDeleteObj(obj.hPropListeners);
            
            
            
        end
    end
    
    methods
        % These are general listeners for functionality
        function configureListeners(obj)
            % Update displays when you add tiles
            obj.hPropListeners = [obj.hPropListeners most.ErrorHandler.addCatchingListener(obj.hModel.hTileManager, 'hOverviewTiles', 'PostSet', @(src,evt)obj.updateOverViewTiles(src,evt))];
            obj.hPropListeners = [obj.hPropListeners most.ErrorHandler.addCatchingListener(obj.hModel.hTileManager, 'hScanTiles', 'PostSet', @(src,evt)obj.updateScanTiles(src,evt))];
            % Updating Tile Hide/Show All
            obj.hPropListeners = [obj.hPropListeners most.ErrorHandler.addCatchingListener(obj, 'overviewTileShowHideTf', 'PostSet', @(src, evt)obj.toggleOverviewTileShowHide(src, evt))];
            obj.hPropListeners = [obj.hPropListeners most.ErrorHandler.addCatchingListener(obj, 'scanTileShowHideTf', 'PostSet', @(src, evt)obj.toggleScanTileShowHide(src, evt))];
            % Update the status window when scanning tiles
            obj.hPropListeners = [obj.hPropListeners most.ErrorHandler.addCatchingListener(obj.hModel.hTileManager, 'tileScanningInProgress', 'PostSet', @(src, evt)obj.updateStatus(src, evt))];
            obj.hPropListeners = [obj.hPropListeners most.ErrorHandler.addCatchingListener(obj.hModel.hTileManager, 'tilesDone', 'PostSet', @(src, evt)obj.updateStatus(src, evt))];
            
            % When performing a tile scan, the display will update the Z
            % position according to the Z value of the tile being scanned.
            % This way the user can see the tile actively being scanned and
            % does not have to fish around in Z to find the plane they are
            % currently imaging.
            obj.hPropListeners = [obj.hPropListeners most.ErrorHandler.addCatchingListener(obj.hModel.hCoordinateSystems, 'hCSSampleRelative', 'PostSet', @obj.setZ)];
            
            % Update the Z position edit box
            obj.hPropListeners = [obj.hPropListeners most.ErrorHandler.addCatchingListener(obj, 'currentZ', 'PostSet', @obj.updateZEdit)];
            
            % Update crosshair position
            obj.hPropListeners = [obj.hPropListeners most.ErrorHandler.addCatchingListener(obj.hModel.hMotors, 'samplePosition', 'PostSet', @obj.samplePositionUpdated)];
            
            % Update Channel Tables
            obj.hPropListeners = [obj.hPropListeners most.ErrorHandler.addCatchingListener(obj, 'liveChansToShow', 'PostSet', @obj.updateLiveChanTable)];
            obj.hPropListeners = [obj.hPropListeners most.ErrorHandler.addCatchingListener(obj, 'liveChanImageColors', 'PostSet', @obj.updateLiveChanTable)];
            obj.hPropListeners = [obj.hPropListeners most.ErrorHandler.addCatchingListener(obj, 'liveChanAlphas', 'PostSet', @obj.updateLiveChanTable)];
            
            obj.hPropListeners = [obj.hPropListeners most.ErrorHandler.addCatchingListener(obj, 'overviewChansToShow', 'PostSet', @obj.updateOverviewChanTable)];
            obj.hPropListeners = [obj.hPropListeners most.ErrorHandler.addCatchingListener(obj, 'overviewChanImageColors', 'PostSet', @obj.updateOverviewChanTable)];
            obj.hPropListeners = [obj.hPropListeners most.ErrorHandler.addCatchingListener(obj, 'overviewChanAlphas', 'PostSet', @obj.updateOverviewChanTable)];
            
            obj.hPropListeners = [obj.hPropListeners most.ErrorHandler.addCatchingListener(obj, 'scanChansToShow', 'PostSet', @obj.updateScanChanTable)];
            obj.hPropListeners = [obj.hPropListeners most.ErrorHandler.addCatchingListener(obj, 'scanChanImageColors', 'PostSet', @obj.updateScanChanTable)];
            obj.hPropListeners = [obj.hPropListeners most.ErrorHandler.addCatchingListener(obj, 'scanChanAlphas', 'PostSet', @obj.updateScanChanTable)];
                        
            % Update Tile image data with averaged images
            obj.hPropListeners = [obj.hPropListeners most.ErrorHandler.addCatchingListener(obj.hModel.hDisplay, 'rollingStripeDataBuffer', 'PostSet', @obj.imageDataUpdated)];
                        
        end
        
    end
    
    %% Manage Tile Disp Objects
    methods
        % These update display functions will fail if multiple tiles are
        % added all at once, i.e. stArray = 1x5 scanTiles,
        % obj.hModel.hTileManager.hScanTiles = stArray. This will only fire once in
        % in that case and only create 1 display. Can't delete existing
        % displays and loop through because deleting a display deletes the
        % tile due to linking... Need a way to update better
        function updateOverViewTiles(obj,src,evt,varargin)
            obj.cleanUpOverviewDisps();
            
            % Add new tiles
            ovTileUuids = [obj.hModel.hTileManager.hOverviewTiles.uuiduint64];
            viewUuids = [obj.hOverViewTileDisps.hTileUuiduint64];
            
            [~,toAddIdxs] = setdiff(ovTileUuids,viewUuids);
            toAddTiles = obj.hModel.hTileManager.hOverviewTiles(toAddIdxs);
            
            % Remove Tiles
            [~,toDeleteIdxs] = setdiff(viewUuids,ovTileUuids);
            hToDelete = obj.hOverViewTileDisps(toDeleteIdxs);
            obj.hOverViewTileDisps(toDeleteIdxs) = [];
            hToDelete.delete();
            
            newTileDisps = scanimage.guis.tileDisplay.overviewTileDisplay.empty();
            
            for idx = 1:numel(toAddTiles)
                hTile = toAddTiles(idx);
                newTileDisps(end+1) = scanimage.guis.tileDisplay.overviewTileDisplay(hTile, obj.hOverviewTileGroup, obj.overviewTileColor, obj);
            end
            
            obj.hOverViewTileDisps = [obj.hOverViewTileDisps newTileDisps];
            
            % Ask tiles to draw themselves if applicable
            obj.updateTileDisplays();
            obj.updateNumTiles()
        end
        
        function updatehFOV_AxPos(obj)
            oldUnits = obj.hFovAxes.Units;
            obj.hFovAxes.Units = 'pixel';
            obj.hFOV_AxPos = obj.hFovAxes.Position;
            obj.hFovAxes.Units = oldUnits;
        end
        
        function updateScanTiles(obj, src, evt, varargin)
            obj.cleanUpScanDisps();
            
            % Add new tiles
            scanTileUuids = [obj.hModel.hTileManager.hScanTiles.uuiduint64];
            viewUuids = [obj.hScanTileDisps.hTileUuiduint64];
            
            [~,toAddIdxs] = setdiff(scanTileUuids,viewUuids);
            toAddTiles = obj.hModel.hTileManager.hScanTiles(toAddIdxs);
            
            [~,toDeleteIdxs] = setdiff(viewUuids,scanTileUuids);
            hToDelete = obj.hScanTileDisps(toDeleteIdxs);
            obj.hScanTileDisps(toDeleteIdxs) = [];
            hToDelete.delete();
            
            newTileDisps = scanimage.guis.tileDisplay.scanTileDisplay.empty();
            
            for idx = 1:numel(toAddTiles)
                hTile = toAddTiles(idx);
                newTileDisps(end+1) = scanimage.guis.tileDisplay.scanTileDisplay(hTile, obj.hScanTileGroup, 'orange', obj);
            end
            
            obj.hScanTileDisps = [obj.hScanTileDisps newTileDisps];
            
            obj.updateTileDisplays();
            obj.updateNumTiles();
        end
        
        function cleanUpOverviewDisps(obj, src, evt, varargin)
            removalMask = ~isvalid(obj.hOverViewTileDisps);
            obj.hOverViewTileDisps(removalMask) = [];
        end
        
        function cleanUpScanDisps(obj, src, evt, varargin)
            removalMask = ~isvalid(obj.hScanTileDisps);
            obj.hScanTileDisps(removalMask) = [];
        end
        
        function updateLiveDisplay(obj, stripeData)
            persistent lastStripe;            
            
            if nargin < 2 || isempty(stripeData) || isempty(stripeData.roiData)
                if isempty(lastStripe) || isempty(lastStripe.roiData)
                    tfStripe = 0;
                else 
                    tfStripe = 1;
                end
            else
                tfStripe = 1;
                lastStripe = stripeData;
            end

            if tfStripe
                tfChanAvail = any(ismember(lastStripe.channelNumbers, find(obj.liveChansToShow)));
            end

            if obj.liveTileEnable
                if tfStripe && tfChanAvail
                    % Generate a Tile off the incoming stripedata
                    hTile = obj.hModel.hTileManager.makeTiles(true, lastStripe.roiData);
                    
                   % If the tile is the same just update the image data
                    if most.idioms.isValidObj(obj.hLiveTileDisp) && hTile.isequalish(obj.hLiveTileDisp.hTile)
                        obj.hLiveTileDisp.hTile.imageData = hTile.imageData;
                        obj.hLiveTileDisp.hTile.displayAvgFactor = obj.hModel.hDisplay.displayRollingAverageFactor;
                        obj.hLiveTileDisp.hTile.setNewSamplePoint(hTile.samplePoint);
                    else
                    % Otherwise replace the Live Tile with the one we just
                    % created.
                        most.idioms.safeDeleteObj(obj.hLiveTileDisp);
                        obj.hLiveTileDisp = arrayfun(@(x) obj.createLiveTileDisp(x), hTile);
                    end
                else
                    if most.idioms.isValidObj(obj.hLiveTileDisp)
                        obj.hLiveTileDisp.drawTile(true);
                    end
                end
                
                if most.idioms.isValidObj(obj.hLiveTileDisp)
                    obj.txtLiveTileSize.String = sprintf('[%.2f %.2f]', obj.hLiveTileDisp.hTile.tileSize(1), obj.hLiveTileDisp.hTile.tileSize(2));
                    obj.txtLiveTilePos.String = sprintf('[%.2f %.2f]', obj.hLiveTileDisp.hTile.samplePoint(1), obj.hLiveTileDisp.hTile.samplePoint(2));
                end
            end
        end
        
        function imageDataUpdated(obj, src, evt)
            data = obj.hModel.hDisplay.rollingStripeDataBuffer{1}{1};
            obj.updateLiveDisplay(data);
            
            if obj.hModel.hTileManager.tileScanningInProgress && ~obj.hModel.hTileManager.isFastZ
                data = obj.hModel.hDisplay.rollingStripeDataBuffer;
                obj.hModel.hTileManager.updateCurrentScanTile(data);
            end
        end
        
        function set.hOverViewTileDisps(obj, val)            
            obj.hOverViewTileDisps = val;
        end
        
        function set.hScanTileDisps(obj, val)
            obj.hScanTileDisps = val;
        end
        
        % Used to sort tile disps by Z value for saving overviews in
        % organized way
        function val = get.overviewTileZs(obj)
            zs_ = [obj.hModel.hTileManager.hOverviewTiles.zPos];
            val = zs_;
        end
        
        function val = get.scanTileZs(obj)
            zs_ = [obj.hModel.hTileManager.hScanTiles.zPos];
            val = zs_;
        end
        
        function val = get.liveTileZs(obj)
            if ~most.idioms.isValidObj(obj.hLiveTileDisp)
                val = [];
            else
                val = obj.hLiveTileDisp.hTile.zPos;
            end
        end
        
        function set.liveTileEnable(obj,val)
            validateattributes(val,{'numeric','logical'},{'binary','scalar'});
            obj.liveTileEnable = logical(val);
            
            obj.liveModeChanged();
            obj.updateLiveDisplay();
        end
    end
    
    methods
        % This is meant to have the live tile track the current position
        % even if you are not actively acquiring. Avoids confusion as to
        % whether a feature is working by showing the live view move and
        % update info
        function samplePositionUpdated(obj, varargin)
            obj.moveCrosshair();
            % Dont want this to happen when we pan around? Yes we do, live
            % view tracks current position.
            if most.idioms.isValidObj(obj.hLiveTileDisp)
                obj.hLiveTileDisp.hTile.setNewSamplePoint(obj.hModel.hMotors.samplePosition);
                obj.updateLiveDisplay();
            end
            % Set Z?
        end
        
    end
    
    %% Gui Related Property Methods
    % i.e. update GUI if props set via command window or script...
    methods
        
        % Live Chans
        function set.liveChansToShow(obj, val)
            channels = 1:obj.hModel.hChannels.channelsAvailable;
            
            assert(islogical(val) && numel(val)==numel(channels));
            
            %
            desiredVal = val;
            actualVal = desiredVal;
            actualVal(~ismember(1:numel(channels), obj.hModel.hChannels.channelDisplay)) = false;
            
            if ~isequal(desiredVal, actualVal)
                warning('Tile Display: One or more channels could not be shown because they are not actively displaying in the Channel Controls');
            end
            
            
            obj.liveChansToShow = actualVal;
            
        end
        
        function set.liveChanImageColors(obj,val)
            channels = 1:obj.hModel.hChannels.channelsAvailable;
            
            valIsChar = all(cellfun(@ischar, val));
            assert(valIsChar);
            
            tfValidColors = all(cellfun(@(x) validColor(x), val));
            assert(iscell(val) && numel(val) == numel(channels) && tfValidColors);
            
            obj.liveChanImageColors = val;
            
            function tf = validColor(col)
                switch col
                    case {'red' 'green' 'blue' 'grey'}
                        tf = true;
                    otherwise
                        tf = false;
                end
            end            
        end
        
        function set.liveChanAlphas(obj, val)
            assert(isnumeric(val) && all(val>=0) && all(val<=1))
            obj.liveChanAlphas = val;
        end
        
        function updateLiveChanTable(obj, src, evt, varargin)
            numChans = numel(obj.liveChansToShow);
            tableData = cell(numChans,4);
            
            tableData(:,1) = num2cell(1:numChans)';
            tableData(:,2) = num2cell(obj.liveChansToShow)';
            tableData(:,3) = obj.liveChanImageColors';
            tableData(:,4) = num2cell(obj.liveChanAlphas)';
            
            obj.hLiveChanTable.Data = tableData;
            
        end
        
        % Overview Chans
        function set.overviewChansToShow(obj,val)
            channels = 1:obj.hModel.hChannels.channelsAvailable;

            assert(islogical(val) && numel(val)==numel(channels));
            obj.overviewChansToShow = val;
        end
        
        function set.overviewChanImageColors(obj,val)
            channels = 1:obj.hModel.hChannels.channelsAvailable;
            
            valIsChar = all(cellfun(@ischar, val));
            assert(valIsChar);
            
            tfValidColors = all(cellfun(@(x) validColor(x), val));
            assert(iscell(val) && numel(val) == numel(channels) && tfValidColors);
            
            obj.overviewChanImageColors = val;
            
            function tf = validColor(col)
                switch col
                    case {'red' 'green' 'blue' 'grey'}
                        tf = true;
                    otherwise
                        tf = false;
                end
            end
        end
        
        function set.overviewChanAlphas(obj, val)
            validateattributes(val,{'numeric'},{'nonnan','>=',0,'<=',1,'vector'});
            obj.overviewChanAlphas = val;
        end
        
        function updateOverviewChanTable(obj,src,evt,varargin)
            numChans = numel(obj.overviewChansToShow);
            tableData = cell(numChans,4);
            
            tableData(:,1) = num2cell(1:numChans)';
            tableData(:,2) = num2cell(obj.overviewChansToShow)';
            tableData(:,3) = obj.overviewChanImageColors';
            tableData(:,4) = num2cell(obj.overviewChanAlphas)';
            
            obj.hOverviewChanTbl.Data = tableData;
        end
        
        % Scan Chans
        function set.scanChansToShow(obj,val)
            channels = 1:obj.hModel.hChannels.channelsAvailable;
            
            assert(islogical(val) && numel(val)==numel(channels));
            
            obj.scanChansToShow = val;
            
        end
        
        function set.scanChanImageColors(obj,val)
            channels = 1:obj.hModel.hChannels.channelsAvailable;
            
            valIsChar = all(cellfun(@ischar, val));
            assert(valIsChar);
            
            tfValidColors = all(cellfun(@(x) validColor(x), val));
            assert(iscell(val) && numel(val) == numel(channels) && tfValidColors);
            
            obj.scanChanImageColors = val;
            
            function tf = validColor(col)
                switch col
                    case {'red' 'green' 'blue' 'grey'}
                        tf = true;
                    otherwise
                        tf = false;
                end
            end
        end
        
        function set.scanChanAlphas(obj,val)
            assert(isnumeric(val) && all(val>=0) && all(val<=1))
            obj.scanChanAlphas = val;
        end
        
        function updateScanChanTable(obj,src,evt,varargin)
            
            numChans = numel(obj.scanChansToShow);
            tableData = cell(numChans,4);
            
            tableData(:,1) = num2cell(1:numChans)';
            tableData(:,2) = num2cell(obj.scanChansToShow)';
            tableData(:,3) = obj.scanChanImageColors';
            tableData(:,4) = num2cell(obj.scanChanAlphas)';
            
            obj.hScnTileChanTbl.Data = tableData;
        end
        
    end
    
    %% Gui Control Methods
    methods (Access = protected)
        function initGui(obj)
            obj.tileColorMap = genColorMap();
            
            availableChannels = obj.hModel.hChannels.channelsAvailable;
            
            obj.liveChansToShow = false(1,availableChannels);
            obj.liveChansToShow(1) = true;
            obj.liveChanImageColors = repmat({'grey'}, 1, availableChannels);
            obj.liveChanAlphas = ones(1, availableChannels);
            
            obj.overviewChansToShow = false(1,availableChannels);
            obj.overviewChansToShow(1) = true;
            obj.overviewChanImageColors = repmat({'grey'}, 1, availableChannels);
            obj.overviewChanAlphas = ones(1, availableChannels);
            obj.overviewTileColor = obj.tileColorMap('cyan');
            
            obj.scanChansToShow = false(1,availableChannels);
            obj.scanChansToShow(1) = true;
            obj.scanChanImageColors = repmat({'grey'}, 1, availableChannels);
            obj.scanChanAlphas = ones(1, availableChannels);
            
            obj.configureListeners();
            
            obj.populateFigure();
            obj.hFOV_XYLim = [obj.hFovAxes.XLim; obj.hFovAxes.YLim];
            obj.hFOV_ZLim = obj.hFovAxes.ZLim;
            
            function show(varargin)
                most.idioms.figure(obj.hFig);
            end
        end
    end
    
    methods
        % Main Figure Setup
        function populateFigure(obj)
            %% Figure Setup
            obj.hFig.Name = 'Tile Overviews';
            obj.hFig.Colormap = gray();
            obj.hFig.CloseRequestFcn = @obj.close;
            obj.hFig.ResizeFcn = @obj.figResized;
            
            
            obj.hFig.WindowScrollWheelFcn = @obj.scrollWheelFcn;

            %% Main Tile Display
            hMainFlow = most.gui.uiflowcontainer('Parent', obj.hFig, 'FlowDirection', 'LeftToRight');
            hControlsSideBar = most.gui.uiflowcontainer('Parent', hMainFlow, 'FlowDirection', 'TopDown');
            hControlsSideBar.WidthLimits = [0 200];

            obj.hFovPanel = uipanel('parent', hMainFlow, 'bordertype', 'none','ButtonDownFcn', @obj.mainViewPan);

            obj.hFovAxes = most.idioms.axes('parent', obj.hFovPanel, 'box', 'off', 'Color', 'k', 'xgrid', 'on', 'ygrid', 'on',...
                'YColor', [0 0 0], 'XColor', [0 0 0], 'GridAlpha', 0.5, 'GridColor', [.2 .2 .2]);
            
            axDefaultCreateFcn(obj.hFovAxes);
            obj.hFovAxes.ButtonDownFcn = @obj.mainViewPan;
            view(obj.hFovAxes,0,-90);
            
            obj.hFovPanel.SizeChangedFcn = @obj.updateFovLims;

            hFigContextMenu = handle(uicontextmenu('Parent', obj.hFig));
            uimenu('Parent',hFigContextMenu,'Label','Move Stage Here','Callback',@(src,evt)obj.gotoPosition(src,evt));
            uimenu('Parent',hFigContextMenu,'Label','Jump View To Current Position','Callback',@(src,evt)obj.gotoCrosshair(src,evt));
            uimenu('Parent',hFigContextMenu,'Label','Save this Position','Callback',@obj.savePosition);

            obj.hOverviewTileGroup = hggroup('Parent',obj.hFovAxes);
            obj.hScanTileGroup = hggroup('Parent',obj.hFovAxes);
            obj.hLiveDisplayGroup = hggroup('Parent',obj.hFovAxes);
            obj.hCrosshairGroup = hggroup('Parent',obj.hFovAxes);
            
            %% Crosshair
            XY_ = obj.hModel.hMotors.samplePosition(1:2);
            x = [XY_(1) XY_(1) NaN XY_(1)-(obj.currentFovSize/10) XY_(1)+(obj.currentFovSize/10)];
            y = [XY_(2)-(obj.currentFovSize/10) XY_(2)+(obj.currentFovSize/10) NaN XY_(2) XY_(2)];
            
            obj.Crosshair = line(x,y,...
                'color',most.constants.Colors.white,'parent', obj.hCrosshairGroup,'linewidth',0.5);
            
            obj.crosshairCenter = line(XY_(1),XY_(2),obj.currentZ,'color','white','LineStyle', 'none', 'LineWidth',1.5, 'Marker','o','MarkerSize', 6, 'MarkerFaceColor', 'white', 'parent',obj.hCrosshairGroup, 'ButtonDownFcn', @obj.crossCenterBtnDwnFcn);
                        
            
            uimenu('Parent',hFigContextMenu,'Label','Toggle Crosshair','Callback',@(src,evt)obj.toggleCrosshair(src,evt));

            obj.hFovAxes.UIContextMenu = hFigContextMenu;

            %% Z Projection
            zProjectionsFlow = most.gui.uiflowcontainer('Parent', hMainFlow, 'FlowDirection', 'TopDown');
            hZprojectionPanel = uipanel('parent', zProjectionsFlow, 'bordertype', 'line');
            zProjectionsFlow.WidthLimits = [160 160];
            
            obj.hZAxes = most.idioms.axes('Parent', hZprojectionPanel, 'box','on','Color',most.constants.Colors.black,'XTick',[],...
                'XTickLabel',[],'YAxisLocation','right','ygrid', 'on', 'GridAlpha', 1, 'GridColor', [.5 .5 .5],...
                'ylim',[-100 100],'xlim',[0 1],'ButtonDownFcn',@obj.zPan);
            obj.hZAxes.Position = [0.1 0.01 0.55 0.98];
            
            view(obj.hZAxes, 0, -90);
            
            obj.hZprojectionScrollLine = line([0 1],[0 0],[-1 -1],'color',most.constants.Colors.white,'parent',obj.hZAxes,'linewidth',3,'ButtonDownFcn',@obj.zScroll);
            obj.hZprojectionScrollKnob = line(0,0,-2,'color','white','parent',obj.hZAxes,'markersize',15,'Marker','>','MarkerFaceColor','white',...
                'hittest','on','color',most.constants.Colors.black,'linewidth',2,'ButtonDownFcn',@obj.zScroll);

            ZPosCtrlPanel = uipanel('parent', zProjectionsFlow, 'bordertype', 'line');
            ZPosCtrlPanel.HeightLimits = [70 70];
            
            etZposText = most.gui.uicontrol('Parent', ZPosCtrlPanel, 'Style', 'text','String', 'Z Position(um)', 'tag', 'etZposTextTag', 'RelPosition', [-9 114 100 100]);
            obj.etZPos = most.gui.uicontrol('Parent', ZPosCtrlPanel, 'Style', 'edit','String', num2str(obj.currentZ),'tag', 'etZPosTag', 'RelPosition', [88 32 60 20], 'Callback', @obj.setZ);

            cbTrackText = most.gui.uicontrol('Parent', ZPosCtrlPanel, 'Style', 'text', 'String', 'Z Tracks Sample?', 'tag', 'cbTrackText', 'RelPosition', [0 61 100 20]);
            obj.cbZTrack = most.gui.uicontrol('Parent', ZPosCtrlPanel, 'Style', 'checkbox', 'Bindings', {obj 'zTracksSample' 'value'}, 'tag', 'cbZTrack', 'RelPosition', [100 62 20 30]);

            obj.zProjectionRange = obj.zProjectionRange;

            %% Control Bar
            chans = num2str(1:obj.hModel.hChannels.channelsAvailable);
            chans = textscan(chans, '%s', 'Delimiter', ' ');
            chans = chans{1};
            chans = chans(~cellfun('isempty',chans));

            %% General Settings
            hControlsSideBarPanel = uipanel('parent', hControlsSideBar, 'bordertype', 'line');

                hGeneralFrame = most.gui.uicontrol('parent', hControlsSideBarPanel, 'Style', 'Frame', 'tag', 'hGenFrmTag', 'RelPosition', [1 77 193 70]);
                hGenSettingTxt = most.gui.uicontrol('Parent', hControlsSideBarPanel, 'Style', 'text', 'String', 'General', 'FontSize', 12, 'tag', 'txtGenSetTag', 'RelPosition', [14 20 58 23]);

                obj.statText = most.gui.uicontrol('Parent', hControlsSideBarPanel, 'Style', 'text', 'String', 'Status: Idle     ',...
                    'FontSize', 10, 'FontWeight', 'bold', 'tag', 'txtStatusTag', 'RelPosition', [10 32 89 16]);

                obj.scanProgTxt = most.gui.uicontrol('Parent', hControlsSideBarPanel, 'Style', 'text', 'String', sprintf('Scanning %d of %d Tiles', obj.hModel.hTileManager.tilesDone, numel(obj.hModel.hTileManager.hScanTiles)),...
                            'FontSize', 10, 'FontWeight', 'bold', 'Visible', 'off', 'Tag', 'txtScnProgTag', 'RelPosition', [17 48 112 17]);

                obj.numOverviewTxt = most.gui.uicontrol('Parent', hControlsSideBarPanel, 'Style', 'text', 'String', sprintf('# Overview Tiles: %d', numel(obj.hModel.hTileManager.hOverviewTiles)),...
                    'tag', 'txtNumOvTag', 'RelPosition', [7 61 106 12]);

                obj.numScanTxt = most.gui.uicontrol('Parent', hControlsSideBarPanel, 'Style', 'text', 'String',sprintf('# Scan Tiles: %d', numel(obj.hModel.hTileManager.hScanTiles)),...
                    'tag', 'txtNumScnTag', 'RelPosition', [9 73 79 12]);

            %% Live View
                hLiveViewFrame = most.gui.uicontrol('parent', hControlsSideBarPanel, 'Style', 'Frame', 'tag', 'hLiveFrmTag', 'RelPosition', [1 261 194 170]);
                hLiveViewFrameTxt = most.gui.uicontrol('Parent', hControlsSideBarPanel, 'Style', 'text', 'String', 'Live View', 'FontSize', 12, 'tag', 'txtLiveFrmTag', 'RelPosition', [14 103 70 22]);

                obj.pbEnableLiveMode = most.gui.uicontrol('Parent', hControlsSideBarPanel, 'String', 'Enable Live View', 'tag', 'pbLiveEnableTag', 'RelPosition', [40 135 114 29], 'Callback', @obj.toggleLiveMode);
                
                

                hLiveChanTxt = most.gui.uicontrol('Parent', hControlsSideBarPanel, 'Style', 'text', 'String', 'Image Controls', 'FontSize', 10, 'tag', 'txtLiveChTag', 'RelPosition', [9 158 89 17]);

                obj.hLiveChanTable = most.gui.uicontrol('Parent',hControlsSideBarPanel,'Style','uitable','ColumnFormat',{'char','logical', {'grey' 'red' 'green' 'blue'},'numeric'},...
                    'ColumnEditable',[false,true,true,true],'ColumnName',{'Ch.','Show', 'Color', 'Alpha'},'ColumnWidth',{25 35, 50, 50},'RowName',[],'RelPosition', [9 255 179 95],'Tag','liveChanTblTag','CellEditCallback',@obj.liveChanTableUpdated);

                    channelShow = obj.liveChansToShow;
                    col = obj.liveChanImageColors;
                    alphas = obj.liveChanAlphas;
                    obj.hLiveChanTable.Data = most.idioms.horzcellcat(chans,num2cell(channelShow), col, alphas);

            %% Overview Tiles
                hOverviewFrame = most.gui.uicontrol('parent', hControlsSideBarPanel, 'Style', 'Frame', 'tag', 'hOvFrmTag', 'RelPosition', [1 477 194 202]);
                hOverviewFrameTxt = most.gui.uicontrol('Parent', hControlsSideBarPanel, 'Style', 'text', 'String', 'Overview Tiles', 'FontSize', 12, 'tag', 'txtOvFrmTag', 'RelPosition', [14 282 103 17]);

                hOverviewChanTxt = most.gui.uicontrol('Parent', hControlsSideBarPanel, 'Style', 'text', 'String', 'Image Controls', 'FontSize', 10, 'tag', 'txtOverviewChTag', 'RelPosition', [8 305 89 17]);
                obj.hOverviewChanTbl = most.gui.uicontrol('Parent',hControlsSideBarPanel,'Style','uitable','ColumnFormat',{'char','logical', {'grey' 'red' 'green' 'blue'},'numeric'},'ColumnEditable',[false,true,true,true],'ColumnName',{'Ch.','Show', 'Color', 'Alpha'},...
                    'ColumnWidth',{25 35, 50,50},'RowName',[],'RelPosition', [9 401 179 94],'Tag','OvChanTblTag','CellEditCallback',@obj.overviewChanTableUpdated);                    

                    channelShow = obj.overviewChansToShow;
                    col = obj.overviewChanImageColors;
                    alphas = obj.overviewChanAlphas;
                    obj.hOverviewChanTbl.Data = most.idioms.horzcellcat(chans,num2cell(channelShow), col, alphas);

                obj.pbOverviewTilesHideAll = most.gui.uicontrol('Parent', hControlsSideBarPanel, 'String', 'Hide Overview Tiles', 'Callback', @(src,evt)obj.toggleOverviewTileShowHide(src,evt), 'tag', 'pbOverviewToggleTag', 'RelPosition', [35 472 124 30]);

                pbClearOverview = most.gui.uicontrol('Parent', hControlsSideBarPanel, 'String', 'Clear', 'Callback', @(varargin)obj.clearOverview, 'tag', 'pbClearOvTag', 'RelPosition', [129 439 58 30]);

                pbSaveOverview = most.gui.uicontrol('Parent', hControlsSideBarPanel, 'String', 'Save', 'Callback', @(varargin)obj.saveOverviewTiles, 'tag', 'pbSaveOvTag', 'RelPosition', [9 439 58 30]);

                pbLoadOverview = most.gui.uicontrol('Parent', hControlsSideBarPanel, 'String', 'Load', 'Callback', @(varargin)obj.loadOverviewTiles, 'tag', 'pbLoadOvTag', 'RelPosition', [69 439 58 30]);

            %% Scan Tiles
                hScanTileFrame = most.gui.uicontrol('parent', hControlsSideBarPanel, 'Style', 'Frame', 'tag', 'hScnTileFrmTag', 'RelPosition', [1 808 194 316]);
                hScanTileFrameTxt = most.gui.uicontrol('parent', hControlsSideBarPanel, 'Style', 'Text', 'String', 'Scan Tiles', 'FontSize', 12, 'tag', 'txtScnTileFrmTag', 'RelPosition', [14 500 75 18]);
                
                    hScnTileCreateToolsTxt = most.gui.uicontrol('parent', hControlsSideBarPanel, 'Style', 'Text', 'String', 'Tile Creation Tools', 'FontSize', 10, 'tag', 'txtScnTileCreateToolsTag', 'RelPosition', [11 520 109 14]);
                    hTileToolPanel = most.gui.uicontrol('Parent', hControlsSideBarPanel, 'Style', 'uipanel', 'tag', 'panTileToolTag', 'RelPosition', [11 577 174 55]);
                    
                        toolClasses = scanimage.components.tileTools.tileTool.findAllTools();
                        for idx = 1:numel(toolClasses)
                            toolClass = toolClasses{idx};
                            toolName = eval([toolClass,'.toolName']);
                            
                            if idx == 1
                                obj.hTools{idx} = most.gui.uicontrol('Parent',hTileToolPanel.hCtl,'String',toolName,'Callback',@(varargin)obj.makeTool(toolClass),'tag', [toolName 'Tag'],'RelPosition', [0 28 145 25]);
                            else
                                lastToolBtn = obj.hTools{idx-1};
                                lastToolBtnPos = lastToolBtn.RelPosition;
                                newToolBtnPos = lastToolBtnPos;
                                newToolBtnPos(2) = newToolBtnPos(2) + newToolBtnPos(4);
                                obj.hTools{idx} = most.gui.uicontrol('Parent',hTileToolPanel.hCtl,'String',toolName,'Callback',@(varargin)obj.makeTool(toolClass),'tag', [toolName 'Tag'],'RelPosition', newToolBtnPos);
                            end
                        end
                        
                        obj.hToolBtnPositionsStart = fliplr(cellfun(@(x) x.hCtl.Position, obj.hTools, 'UniformOutput', false));
                        
                        slRange = (idx*20)/2;                        
                        hToolSlider = most.gui.uicontrol('Parent', hTileToolPanel.hCtl, 'Style', 'slider','value', slRange, 'Min', -slRange, 'Max', slRange,'SliderStep',([1, 1] / (2*slRange)),'tag', 'slToolSelTag', 'RelPosition', [151 53 20 50], 'Callback', @obj.toolSliderCallback);
                        
                hScnTileChanTxt = most.gui.uicontrol('Parent', hControlsSideBarPanel, 'Style', 'text', 'String', 'Image Controls', 'FontSize', 10, 'tag', 'txtScnTileChTag', 'RelPosition', [8 601 90 17]);
                obj.hScnTileChanTbl = most.gui.uicontrol('Parent',hControlsSideBarPanel,'Style','uitable','ColumnFormat',{'char','logical', {'grey' 'red' 'green' 'blue'}, 'numeric'},'ColumnEditable',[false,true, true,true],...
                    'ColumnName',{'Ch.','Show', 'Color', 'Alpha'},'ColumnWidth',{25 35, 50,50},'RowName',[],'RelPosition', [9 697 179 95],'Tag','ScnTileChanTblTag','CellEditCallback',@obj.scanChanTableUpdated);                    

                    channelShow = obj.scanChansToShow;
                    col = obj.scanChanImageColors;
                    alphas = obj.scanChanAlphas;
                    obj.hScnTileChanTbl.Data = most.idioms.horzcellcat(chans,num2cell(channelShow), col, alphas);

                obj.pbShowHideScanTiles = most.gui.uicontrol('Parent', hControlsSideBarPanel, 'String', 'Hide Scan Tiles', 'tag', 'pbTglShwScnTiles','RelPosition', [35 769 129 30] , 'Callback', @obj.toggleScanTileShowHide);

                pbClearScanTiles = most.gui.uicontrol('Parent', hControlsSideBarPanel, 'String', 'Clear', 'tag', 'pbClearScnTiles','RelPosition', [130 736 58 31] ,'Callback', @obj.clearScanTiles);

                pbPinAllScanTiles = most.gui.uicontrol('Parent', hControlsSideBarPanel, 'String', 'Add All to Overview', 'tag', 'pbAddScnTiles','RelPosition', [35 802 129 30] ,'Callback', @obj.scanTileAddAll);

                pbSaveScanTiles = most.gui.uicontrol('Parent', hControlsSideBarPanel, 'String', 'Save', 'tag', 'pbSaveScnTiles','RelPosition', [8 735 58 30] ,'Callback', @obj.saveScanTiles);

                pbLoadScanTiles = most.gui.uicontrol('Parent', hControlsSideBarPanel, 'String', 'Load', 'tag', 'pbLoadScnTiles','RelPosition', [69 735 58 30] ,'Callback', @obj.loadScanTiles);

            %% Scan Controls
                hScanCtrlFrame = most.gui.uicontrol('parent', hControlsSideBarPanel, 'Style', 'Frame', 'tag', 'hScnCtrlFrmTag', 'RelPosition', [1 1011 194 185]);
                hScanCtrlFrameTxt = most.gui.uicontrol('parent', hControlsSideBarPanel, 'Style', 'Text', 'String', 'Scan Control', 'FontSize', 12, 'tag', 'txtScnCtrlFrmTag', 'RelPosition', [14 833 92 18]);

                pbStartTileScan = most.gui.uicontrol('Parent', hControlsSideBarPanel, 'String', 'START','tag', 'pbStartScnTag', 'RelPosition', [16 883 74 43], 'Callback', @(src,evt)obj.startTileScan(src,evt));

                pbStopTileScan = most.gui.uicontrol('Parent', hControlsSideBarPanel, 'String', 'STOP', 'tag', 'pbStpScnTag', 'RelPosition', [107 883 74 43], 'Callback', @(src,evt)obj.stopTileScan(src,evt));

                hScanFramesTxt = most.gui.uicontrol('parent', hControlsSideBarPanel, 'Style', 'Text', 'String', 'Frames Per Tile:', 'tag', 'txtScnFrmsTag', 'RelPosition', [8 911 79 12]);
                etScnFramesPerTile = most.gui.uicontrol('parent', hControlsSideBarPanel, 'Style', 'edit', 'Bindings', {obj.hModel.hTileManager 'scanFramesPerTile' 'value'}, 'tag', 'etScnFrmsTag', 'RelPosition', [92 918 40 24]);

                hFastZTxt = most.gui.uicontrol('parent', hControlsSideBarPanel, 'Style', 'Text', 'String', 'Enable FastZ Scan?', 'tag', 'txtFastZTag', 'RelPosition', [7 937 100 12]);
                cbFastZScanEnable = most.gui.uicontrol('Parent', hControlsSideBarPanel, 'Style', 'checkbox', 'Bindings', {obj.hModel.hTileManager 'isFastZ' 'value'},'tag', 'cbFastZTag', 'RelPosition', [112 941 14 17]);

                pbLoadTileFcn = most.gui.uicontrol('Parent', hControlsSideBarPanel, 'String', 'Tile Sort Fcn','tag','pbLoadTileFcnTag','RelPosition', [6 1005 81 30],'Callback', @(src, evt)obj.setSortFcn(src,evt));
                etTileSortFcn = most.gui.uicontrol('Parent', hControlsSideBarPanel, 'Style','Edit','tag','etTileSortFcnTag','Enable', 'inactive','RelPosition', [92 1004 98 30], 'Bindings', {obj.hModel.hTileManager 'scanTileSortFcn' 'callback' @(src)updateSortFcnName(src)});
                
                hSettleTimeTxt = most.gui.uicontrol('Parent', hControlsSideBarPanel, 'Style', 'Text', 'String', 'Stage Settling Time (sec)', 'tag', 'txtStageSettle', 'RelPosition', [5 963 125 13]);
                etSettleTime = most.gui.uicontrol('Parent', hControlsSideBarPanel, 'Style', 'edit', 'tag', 'etStageSettle', 'RelPosition', [133 968 46 24], 'Bindings', {obj.hModel.hTileManager 'scanStageSettleTime' 'Value'});


        function updateSortFcnName(hCtl)
            classname = obj.hModel.hTileManager.scanTileSortFcn;
            classname = regexp(classname,'[^\.]*$','match','once'); % abbreviate package name
            hCtl.String = classname;
        end
        
            obj.launchLiveTileDataWindow();
            obj.launchSavedPositionWindow();
            
            %% Menu Options
            hView = uimenu('Parent', obj.hFig, 'Label', 'View');
               uimenu('Parent', hView, 'Label', 'Live Tile Info Window', 'Callback', @obj.launchLiveTileDataWindow);
               uimenu('Parent', hView, 'Label', 'Saved Position Window', 'Callback', @obj.launchSavedPositionWindow); 
            
        end
        
        function launchLiveTileDataWindow(obj,varargin)
            if most.idioms.isValidObj(obj.hLiveTileDataWindow)
                obj.hLiveTileDataWindow.Visible = 'on';
            else
                most.idioms.safeDeleteObj(obj.hLiveTileDataWindow);
                obj.hLiveTileDataWindow = most.idioms.figure('Name', 'Live Tile Data', 'numbertitle', 'off', 'CloseRequestFcn', @(src,evt)hideClose(src,evt), 'ToolBar', 'auto',...
                    'MenuBar', 'none', 'Resize', 'off', 'Position' ,most.gui.centeredScreenPos([200 150]), 'Visible', 'off');
                
                txtLiveTileSizeTitle = most.gui.uicontrol('Parent', obj.hLiveTileDataWindow, 'Style', 'text', 'String', 'Live Tile Size', 'tag', 'txtLiveTileSzTitle', 'RelPosition', [36 39 121 28], 'FontSize', 12);
                obj.txtLiveTileSize = most.gui.uicontrol('Parent', obj.hLiveTileDataWindow, 'Style', 'text', 'String', '[NA NA]', 'tag', 'txtLiveTileSz', 'RelPosition', [15 59 161 28], 'FontSize', 12);
                
                txtLiveTilePosTitle = most.gui.uicontrol('Parent', obj.hLiveTileDataWindow, 'Style', 'text', 'String', 'Live Tile Center', 'tag', 'txtLiveTileCenterTitle', 'RelPosition', [33 97 131 29], 'FontSize', 12);
                obj.txtLiveTilePos = most.gui.uicontrol('Parent', obj.hLiveTileDataWindow, 'Style', 'text', 'String', '[NA NA]', 'tag', 'txtLiveTileCenter', 'RelPosition', [13 119 171 29], 'FontSize', 12);
                
            end
            
            function hideClose(src,evt,varargin)
                obj.hLiveTileDataWindow.Visible = 'off';
            end
        end
        
        function launchSavedPositionWindow(obj, varargin)
            if most.idioms.isValidObj(obj.hSavedPositionsWindow)
                obj.hSavedPositionsWindow.Visible = 'on';
            else
                most.idioms.safeDeleteObj(obj.hSavedPositionsWindow);
                obj.hSavedPositionsWindow = most.idioms.figure('Name', 'Saved Positions', 'numbertitle', 'off', 'CloseRequestFcn',  @(src,evt)hideClose(src,evt), 'ToolBar', 'auto',...
                    'MenuBar', 'none', 'Resize', 'off', 'Position', most.gui.centeredScreenPos([328 300]), 'Visible', 'off');
                
                obj.hSavedPositionsTable = most.gui.uicontrol('Parent', obj.hSavedPositionsWindow, 'Style', 'uitable', 'ColumnFormat', {'char', 'numeric', 'numeric', 'numeric', 'char'}, 'ColumnEditable', [false false false false false],...
                    'ColumnName', {'Position Name', 'X', 'Y', 'Z', ''}, 'ColumnWidth', {100 50 50 50 30}, 'RelPosition', [9 225 313 220], 'Tag', 'posTableTag', 'CellSelectionCallback', @obj.savedPositionTableCbFunc);
                
                pbSavePositions = most.gui.uicontrol('Parent', obj.hSavedPositionsWindow, 'String', 'Save', 'tag', 'pbSavePositions', 'RelPosition', [64 293 93 56], 'Callback', @savePositions);
                pbLoadPositions = most.gui.uicontrol('Parent', obj.hSavedPositionsWindow, 'String', 'Load', 'tag', 'pbLoadPositions', 'RelPosition', [169 293 93 56], 'Callback', @loadPositions);
               
            end
            
            function savePositions(src, evt, varargin)
                hPosStruct = []; %struct('Name', '', 'Pos', []);
                
                [r,~] = size(obj.hSavedPositionsTable.Data);
                
                for i = 1:r
                    Name = obj.hSavedPositionsTable.Data{i,1};
                    pos = [obj.hSavedPositionsTable.Data{i,2:4}];
                    tempStruct = struct('Name', Name, 'Pos', pos);
                    
                    if isempty(hPosStruct)
                        hPosStruct = tempStruct;
                    else
                        hPosStruct = [hPosStruct tempStruct];
                    end
                end
                
                startingDir = obj.hModel.hScan2D.logFilePath;
                timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
                
                if isempty(startingDir)
                    startingDir = pwd;
                end
                
                defaultFileName = sprintf('overviewPositions_%s.mat', timestamp);
                
                [fname,logdir] = uiputfile('.mat', 'Save Positions', fullfile(startingDir, defaultFileName));
                
                if ~ischar(logdir) || ~ischar(fname)
                    return;
                end
                
                if isempty(logdir)
                    logdir = startingDir;
                end
                
                if isempty(fname)
                    fname = defaultFileName;
                end
                
                fileAndPath = fullfile(logdir, fname);
                
                save(fileAndPath, 'hPosStruct');
            end
            
            function loadPositions(src, evt, varargin)
                
                startingDir = obj.hModel.hScan2D.logFilePath;
                    
                if isempty(startingDir)
                    startingDir = pwd;
                end
                
                [file, path] = uigetfile('*.mat','Load Positions',startingDir);
                
                if ~ischar(file) || ~ischar(path)
                    return;
                end
                                
                load(fullfile(path, file), 'hPosStruct', '-mat');
                
                for i = 1:numel(hPosStruct)
                    name = {hPosStruct(i).Name};
                    pos = num2cell(hPosStruct(i).Pos);
                    dat = [name pos {['   ' char(10007) '   ']}];
                    
                    obj.hSavedPositionsTable.Data = [obj.hSavedPositionsTable.Data; dat];
                end
                
            end
            
            function hideClose(src,evt,varargin)
                obj.hSavedPositionsWindow.Visible = 'off';
            end
        end
        
        % This is cb to addSavedPosition
        function savePosition(obj, src, evt, varargin)
            if isempty(varargin) && most.gui.isMouseInAxes(obj.hFovAxes)
                pt = getPointerLocation(obj.hFovAxes, false);
                pt = [pt obj.currentZ];
                
                obj.addSavedPosition(pt);
            else
                pt = varargin{1};
                obj.addSavedPosition(pt);
            end
        end
        
        function addSavedPosition(obj, pos, name)
            if nargin < 3 || isemtpy(name)
               name = inputdlg('Enter position name:', 'Add Position', [1 50]);
               if isempty(name)
                   return;
               else
                   name = name{1};
               end
            end
            
            obj.hSavedPositionsTable.Data = [obj.hSavedPositionsTable.Data; most.idioms.horzcellcat({name},{pos(1)},{pos(2)},{pos(3)},{['   ' char(10007) '   ']})];
            
        end
        
        function savedPositionTableCbFunc(obj, src, evt, varargin)
            cellClicked = evt.Indices;
            if isempty(cellClicked)
                return;
            end
            switch cellClicked(2)
                case 1
                    pos = [obj.hSavedPositionsTable.Data{cellClicked(1), 2:4}];
                    
                    obj.currentFovPos = [pos(1) pos(2)];
                    % Update Z
                    obj.setZ(pos(3))
                    % Draw the tiles
                    obj.updateTileDisplays();
                    
                case 5
                    tblData = obj.hSavedPositionsTable.Data;
                    tblData(cellClicked(1), :) = [];
                    obj.hSavedPositionsTable.Data = tblData;
                otherwise
                    return;
                    
            end
        end
        
        % Channel Table updates
        function liveChanTableUpdated(obj,src,evt,varargin)
            try
                tableData = src.Data;
                obj.liveChansToShow = cell2mat(tableData(:,2)');
                obj.liveChanImageColors = tableData(:,3)';
                obj.liveChanAlphas = cell2mat(tableData(:,4)');
            catch ME
                obj.updateLiveChanTable();
                ME.rethrow();
            end
            
            obj.updateLiveChanTable();
        end
        
        function overviewChanTableUpdated(obj,src,evt,varargin)
            try
                tableData = src.Data;
                obj.overviewChansToShow = cell2mat(tableData(:,2)');
                obj.overviewChanImageColors = tableData(:,3)';
                obj.overviewChanAlphas = cell2mat(tableData(:,4)');
            catch ME
                obj.updateOverviewChanTable();
                ME.rethrow();
            end
            
            obj.updateOverviewChanTable();
        end
        
        function scanChanTableUpdated(obj, src, evt, varargin)
            try
                tableData = src.Data;
                obj.scanChansToShow = cell2mat(tableData(:,2)');
                obj.scanChanImageColors = tableData(:,3)';
                obj.scanChanAlphas = cell2mat(tableData(:,4)');
            catch ME
                obj.updateScanChanTable();
                ME.rethrow();
            end
            
            obj.updateScanChanTable();
        end
        
        function reinitGui(obj)
           delete(obj.hFig.Children);
           obj.initGui();
        end
        
        function close(obj, ~, evt)
           obj.hFig.Visible = 'off';
           obj.liveTileEnable = false;
        end
        
        function figResized(obj,varargin)
            obj.updatehFOV_AxPos();
        end
        
        %% Controls/Settings Side Bar
        % General Settings
        function updateStatus(obj, src, evt)
            if obj.hModel.hTileManager.tileScanningInProgress
                obj.statText.String = 'Status: Active';
                obj.scanProgTxt.Visible = 'on';
                obj.scanProgTxt.String = sprintf('Scanning %d of %d Tiles', obj.hModel.hTileManager.tilesDone, numel(obj.hModel.hTileManager.tileScanIndices));
            else
                obj.statText.String = 'Status: Idle     ';
                obj.scanProgTxt.Visible = 'off';
            end
        end
        
        function updateNumTiles(obj, src, evt)
            obj.numOverviewTxt.String = sprintf('# Overview Tiles: %d', numel(obj.hModel.hTileManager.hOverviewTiles));
            obj.numScanTxt.String = sprintf('# Scan Tiles: %d', numel(obj.hModel.hTileManager.hScanTiles));
        end
        
        % Live Tiles
        function toggleLiveMode(obj, src, evt)
            if ~strcmp(evt.EventName, 'PostSet')
                obj.liveTileEnable = ~obj.liveTileEnable;
            end
        end
        
        function liveModeChanged(obj)
            if obj.liveTileEnable
                obj.pbEnableLiveMode.String = 'Disable Live View';
                obj.pbEnableLiveMode.hCtl.BackgroundColor = 'green';
                obj.currentZ = obj.currentZ;
            else
                obj.pbEnableLiveMode.String = 'Enable Live View';
                obj.pbEnableLiveMode.hCtl.BackgroundColor = [0.9400 0.9400 0.9400];
            end
        end
        
        % Overview Tiles
        function toggleOverviewTileShowHide(obj, src, evt)
            if ~strcmp(evt.EventName, 'PostSet')
                obj.overviewTileShowHideTf = ~obj.overviewTileShowHideTf;
            end

            if obj.overviewTileShowHideTf
                obj.pbOverviewTilesHideAll.String = 'Hide Overview Tiles';
            else
                obj.pbOverviewTilesHideAll.String = 'Show Overview Tiles';
            end
        end
        
        function clearOverview(obj, varargin)
            if ~isempty(obj.hOverViewTileDisps) && ~isempty(obj.hModel.hTileManager.hOverviewTiles)
                resp = questdlg('This will delete the entire overview, are you sure you wish to continue? Consider saving the overview to file first',...
                    'Clear all Overview Tiles?', 'Yes', 'No', 'No');

                if strcmp(resp, 'Yes')
                    obj.hModel.hTileManager.clearOverviewTiles();
                end
            end
        end
        
        % Currently just organizes the overview tiles by Z, and Channel,
        % in a cell array and saves it to a .mat would like to save a
        % stitched image as well.
        function saveOverviewTiles(obj, varargin)
            obj.hModel.hTileManager.saveTiles('Overview');
        end
        
        function loadOverviewTiles(obj, varargin)
            obj.hModel.hTileManager.loadTiles('Overview');
        end
        
        % Scan Tiles
        function makeTool(obj,toolClassName)
            most.idioms.safeDeleteObj(obj.tileTool);
            obj.tileTool = [];
            
            constructor = str2func(toolClassName);
            obj.tileTool = constructor(obj);            
        end
        
        function toolSliderCallback(obj, src, evt, varargin)
            allBtns = src.Parent.Children(2:end);
            
            offset = (src.Max - src.Value);
            
            for btn = 1:numel(allBtns)
                newBtnPosition = obj.hToolBtnPositionsStart{btn};
                newBtnPosition(2) = newBtnPosition(2) + offset;
                allBtns(btn).Position = newBtnPosition;
            end

        end
        
        function saveScanTiles(obj, varargin)
            obj.hModel.hTileManager.saveTiles('Scan');
        end
        
        function loadScanTiles(obj, varargin)
            obj.hModel.hTileManager.loadTiles('Scan');
        end
        
        function scanTileAddAll(obj, src, evt)
            obj.hModel.hTileManager.addAllScanTilesToOverview();
        end
        
        function toggleScanTileShowHide(obj, src, evt)
%             if ~obj.hModel.hTileManager.tileScanningInProgress
                if ~strcmp(evt.EventName, 'PostSet')
                    obj.scanTileShowHideTf = ~obj.scanTileShowHideTf;
                end

                if obj.scanTileShowHideTf
                    obj.pbShowHideScanTiles.String = 'Hide Scan Tiles';
                else
                    obj.pbShowHideScanTiles.String = 'Show Scan Tiles';
                end
%             end
        end
        
        function clearScanTiles(obj, varargin)
            if ~obj.hModel.hTileManager.tileScanningInProgress
                if ~isempty(obj.hScanTileDisps) && ~isempty(obj.hModel.hTileManager.hScanTiles)
                    resp = questdlg('This will delete all scan tiles, are you sure you wish to continue?',...
                        'Clear all Scan Tiles?', 'Yes', 'No', 'No');

                    if strcmp(resp, 'Yes')
                        obj.hModel.hTileManager.clearScanTiles();
                    end
                end
            end
        end
        
        % Tile Scanning
        function startTileScan(obj, src,evt)
            if isempty(obj.hModel.hTileManager.hScanTiles)
                warning('No scan tiles defined!');
                return;
            else
                obj.hModel.hTileManager.initTileScanning();
            end
        end
        
        function stopTileScan(obj, src,evt)
            obj.hModel.hTileManager.scanAbortFlag = true;
            obj.hModel.hTileManager.abortTileScan();
        end
        
        %% Main View Controls
        % Panning Around Main Tile View
        function mainViewPan(obj,~,evt)            
            if (strcmp(evt.EventName, 'Hit') && (evt.Button == 1)) || strcmp(evt.EventName, 'WindowMousePress')
                startingPoint = obj.hFovAxes.CurrentPoint([1 3]);
                
                obj.hFig.WindowButtonUpFcn = @(varargin)stop;
                obj.hFig.WindowButtonMotionFcn = @(varargin)drag;
            end
            
            %%% Nested functions
            function drag()
                try
                    obj.currentFovPos = obj.currentFovPos + startingPoint - obj.hFovAxes.CurrentPoint([1 3]);
                catch ME
                    stop();
                    ME.rethrow();
                end
            end
            
            function stop()
                obj.hFig.WindowButtonMotionFcn = [];
                obj.hFig.WindowButtonUpFcn = [];
            end
            
        end
        
        function restoreBtnDwnFcn(obj)
            obj.hFovAxes.ButtonDownFcn = @obj.mainViewPan;
        end
        
        % Scrolling/zooming in and out of Main Tile View
        function scrollWheelFcn(obj,~,evt)
            keyModifiers = get(obj.hFig, 'currentModifier');
            isShiftPressed = ismember('shift', keyModifiers);
            scrollCount = evt.VerticalScrollCount;
            if most.gui.isMouseInAxes(obj.hFovAxes)
                opt = obj.hFovAxes.CurrentPoint([1 3]);
                obj.currentFovSize = obj.currentFovSize * 1.5^scrollCount;
                obj.currentFovPos = obj.currentFovPos + opt - obj.hFovAxes.CurrentPoint([1 3]);
                
                if isvalid(obj.Crosshair)
                    XY_ = obj.hModel.hMotors.samplePosition(1:2);
                    obj.Crosshair.YData(1:2) = [XY_(2)-(obj.currentFovSize/10) XY_(2)+(obj.currentFovSize/10)];
                    obj.Crosshair.XData(4:5) = [XY_(1)-(obj.currentFovSize/10) XY_(1)+(obj.currentFovSize/10)];
                    
                    obj.Crosshair.ZData = (obj.currentZ - 0.00001) * ones(1,5);
                end
                
                if isvalid(obj.crosshairCenter)
                    XY_ = obj.hModel.hMotors.samplePosition(1:2);
                    
                    obj.crosshairCenter.XData = XY_(1);
                    obj.crosshairCenter.YData = XY_(2);
                    obj.crosshairCenter.ZData = obj.currentZ-0.0001;
                    
                end
            elseif most.gui.isMouseInAxes(obj.hZAxes)
                if isShiftPressed
                    
                else
                    originalLocation = getPointerLocation(obj.hZAxes, true, obj.zProjectionRange);
                
                    projectionDistance = obj.zProjectionRange(2) - obj.zProjectionRange(1);
                    rangeCenter = sum(obj.zProjectionRange) / 2;
                    newDistance = projectionDistance * 1.5^scrollCount;
                    newZRange = rangeCenter + [-newDistance newDistance] / 2;
                    obj.zProjectionRange = newZRange;
                    
                    newLocation = getPointerLocation(obj.hZAxes, true, obj.zProjectionRange);
                    
                    obj.zProjectionRange = obj.zProjectionRange...
                        + originalLocation(2) - newLocation(2);
                end
            end
        end
        
        % Update Axis Position Tick Labels and Spatial Location in Main
        % Tile View
        function updateTickLabels(obj)
            Xmarg = 95;
            yMarg = 10;
            
            
            obj.hFovAxes.Units = 'pixels';
            axPos = obj.hFovAxes.Position;
            
            xLim = obj.hFovAxes.XLim;
            yLim = obj.hFovAxes.YLim;
            xtck = obj.hFovAxes.XTick;
            ytck = obj.hFovAxes.YTick;
                        
            pix2xlim = diff(xLim) /  axPos(3);
            xp = xLim(1) + Xmarg*pix2xlim;
            
            N = numel(ytck);
            for i = 1:N
                if numel(obj.hYTicks) < i
                    obj.hYTicks(i) = text('parent',obj.hFovAxes,'fontsize',12,'color','w','HorizontalAlignment','right', 'HitTest', 'off');
                end
                
                obj.hYTicks(i).Position = [xp ytck(i) obj.currentZ];
                
                v = ytck(i);
                
                [~,prefix,exponent] = most.idioms.engineersStyle(max(abs(v))*1e-6,'m');
                
                if isempty(prefix) || isempty(exponent)
                   prefix = 'u';
                end
                
                v = v.*1e-6 ./ 10^exponent;
                
                obj.hYTicks(i).String = sprintf(['%.3f [' prefix 'm]'],v);
            end
            set(obj.hYTicks(1:N),'Visible','on');
            set(obj.hYTicks(N+1:end),'Visible','off');
            
            xtck(xtck < (xp + 6*pix2xlim)) = [];
            
            pix2ylim = diff(yLim) /  axPos(4);
            yp = yLim(1) + yMarg*pix2ylim;
            
            N = numel(xtck);
            for i = 1:N
                if numel(obj.hXTicks) < i
                    obj.hXTicks(i) = text('parent',obj.hFovAxes,'fontsize',12,'color','w','Rotation',90,'HorizontalAlignment','right', 'HitTest', 'off');
                end
                
                obj.hXTicks(i).Position = [xtck(i) yp obj.currentZ];
                
                v = xtck(i);
                
                [~,prefix,exponent] = most.idioms.engineersStyle(max(abs(v))*1e-6,'m');
                
                if isempty(prefix) || isempty(exponent)
                   prefix = 'u';
                end
                
                v = v.*1e-6 ./ 10^exponent;
                
                obj.hXTicks(i).String = sprintf(['%.3f [' prefix 'm]'],v);
            end
            set(obj.hXTicks(1:N),'Visible','on');
            set(obj.hXTicks(N+1:end),'Visible','off');
        end
        
        function set.currentFovSize(obj,v)
            obj.currentFovSize = max(min(v,obj.maxFov),obj.maxFov/10000);
            obj.currentFovPos = obj.currentFovPos;
        end
        
        function set.currentFovPos(obj,v)
            mxPos = (obj.maxFov-obj.currentFovSize);
            obj.currentFovPos = max(min(v,mxPos),-mxPos);
            obj.updateFovLims();
        end
        
        function updateFovLims(obj, src, evt)
            obj.hFovPanel.Units = 'pixels';
            p = obj.hFovPanel.Position;
            
            lm = obj.currentFovSize * p(3:4) / min(p(3:4));
            xlim_ = lm(1) * [-1 1] + obj.currentFovPos(1);
            obj.hFovAxes.XLim = xlim_;
            
            ylim_ = lm(2) * [-1 1] + obj.currentFovPos(2);
            obj.hFovAxes.YLim = ylim_;
            
            % Force Square Grid
            delta = mean(diff(obj.hFovAxes.YTick));
            
            xlim = obj.hFovAxes.XLim;
            
            for idx = 1:2
               if xlim(idx) < 0
                   xlim(idx) = ceil(xlim(idx)/delta)*delta;
               elseif xlim(idx) > 0
                   xlim(idx) = floor(xlim(idx)/delta)*delta;
               else
                   xlim(idx) = 0;
               end
            end
            
            try
                obj.hFovAxes.XTick = [xlim(1):delta:xlim(2)];
            catch ME
                
            end
            
            obj.hFovAxes.Units = 'normalized';
            obj.hFovAxes.Position = [0 0 1 1];
            
            obj.updateTickLabels();
            obj.hFOV_XYLim = [xlim_; ylim_]; % Slow due to post set callbacks?
        end
        
        % Have tiles draw themselves if needed
        function updateTileDisplays(obj)
            
            if most.idioms.isValidObj(obj.hLiveTileDisp)
                obj.hLiveTileDisp.drawTile();
            end
            
            arrayfun(@(x) x.drawTile, obj.hOverViewTileDisps);
            arrayfun(@(x) x.drawTile, obj.hScanTileDisps);
            
        end
        
        % Move stages to this position
        function gotoPosition(obj, src, evt)
            if obj.hModel.hTileManager.tileScanningInProgress
                warning('Don''t move stage while Tile Scanning in progress!');
            else
                if most.gui.isMouseInAxes(obj.hFovAxes)
                    pt = getPointerLocation(obj.hFovAxes, false);
                    pt = [pt obj.currentZ];

                    samplePosition = scanimage.mroi.coordinates.Points(obj.hModel.hCoordinateSystems.hCSSampleRelative,pt);
                    obj.hModel.hMotors.movePtToPosition(obj.hModel.hCoordinateSystems.focalPoint,samplePosition)
                end
            end
        end
        
        % Jump back to where the crosshair is, does not move stage, just
        % FOV
        function gotoCrosshair(obj, src, evt)
            obj.currentFovPos = [mean(obj.Crosshair.XData(1:2)) mean(obj.Crosshair.YData(4:5))];
            % Update Z
            hPtFocus = scanimage.mroi.coordinates.Points(obj.hModel.hCoordinateSystems.hCSFocus,[0,0,0]);
            hPtFocusSampleRelative = hPtFocus.transform(obj.hModel.hCoordinateSystems.hCSSampleRelative);
            focusSampleZ = hPtFocusSampleRelative.points(1,3);
            obj.setZ(focusSampleZ);%obj.hModel.hMotors.samplePosition(end))
            % Draw the tiles
            obj.updateTileDisplays();
        end
        
        % Crosshair - This moves crosshair to current position, not
        % arbitrarily
        function moveCrosshair(obj,varargin)
            if isvalid(obj.Crosshair)
                XY_ = obj.hModel.hMotors.samplePosition(1:2);
                obj.Crosshair.XData = [XY_(1) XY_(1) NaN XY_(1)-(obj.currentFovSize/10) XY_(1)+(obj.currentFovSize/10)];
                obj.Crosshair.YData = [XY_(2)-(obj.currentFovSize/10) XY_(2)+(obj.currentFovSize/10) NaN XY_(2) XY_(2)];
                
                obj.Crosshair.ZData = (obj.currentZ - 0.00001) * ones(1,5);
            end
            
            if isvalid(obj.crosshairCenter)
                XY_ = obj.hModel.hMotors.samplePosition(1:2);
                
                obj.crosshairCenter.XData = XY_(1);
                obj.crosshairCenter.YData = XY_(2);
                obj.crosshairCenter.ZData = obj.currentZ-0.0001;
                
            end
                        
        end
        
        function crossCenterBtnDwnFcn(obj,src,evt)
            switch evt.Button
                case 1 % left click
                    lastMove = uint64(0);
                    obj.hFig.WindowButtonUpFcn = @(varargin)stop;
                    obj.hFig.WindowButtonMotionFcn = @(varargin)moveStage;
                case 3 % right click
                    if most.idioms.isValidObj(obj.hLiveTileDisp)
                        obj.hLiveTileDisp.addTileToOverview();
                    end
            end
             
            function moveStage()
                try
                    if toc(lastMove)<0.05
                        return
                    end
                    
                    pt = getPointerLocation(obj.hFovAxes, false);
                    pt = [pt NaN];
                    
                    if obj.hModel.hMotors.isAligned && obj.hModel.hMotors.isContinuousMoveAllowed()
                        tfAsync = true;
                        obj.hModel.hMotors.moveSample(pt,tfAsync);
                        lastMove = tic;
                    end
                catch ME
                    stop();
                    most.ErrorHandler.logAndReportError(ME);
                end
            end
            
            function stop()
                obj.hFig.WindowButtonMotionFcn = [];
                obj.hFig.WindowButtonUpFcn = [];
            end
        end
        
        function toggleCrosshair(obj, varargin)
            if isvalid(obj.Crosshair)
                Vis = strcmp('on',obj.Crosshair.Visible);

                if Vis
                    obj.Crosshair.Visible = 'off';
                    obj.crosshairCenter.Visible = 'off';
                else
                    obj.Crosshair.Visible = 'on';
                    obj.crosshairCenter.Visible = 'on';
                end
            end
        end
        
        %% Live Mode Surface Funcs
        function hTileDisp = createLiveTileDisp(obj, hTile)
            if nargin<2 || isempty(hTile)
                scanfield = obj.hModel.hRoiManager.currentRoiGroup.rois.scanfields;
                hCoordinateSystems = obj.hModel.hCoordinateSystems;
                zs = obj.currentZ;
                chansAvail = obj.hModel.hChannels.channelsAvailable;

                [samplePoint, cornerPoints] = scanimage.components.tileTools.tileGeneratorFcns.makeTilePoints(hCoordinateSystems,scanfield,zs);
                
                % The corner points I think are wrong
                sizeXY = [(cornerPoints(2,1)-cornerPoints(1,1)) (cornerPoints(4,2)-cornerPoints(1,2))];
                tileParams = {samplePoint(1:2), sizeXY, zs, chansAvail, scanfield.pixelResolutionXY, []};

                hTile = scanimage.components.tileTools.tileGeneratorFcns.defaultTileGenerator(hCoordinateSystems, true, tileParams);
            end
            
            hTileDisp = scanimage.guis.tileDisplay.liveTileDisplay(hTile, obj.hLiveDisplayGroup, 'blue', obj);
        end
                
        %% Z Scrolling Stuff
        % Pan through Z range
        function zPan(obj, isPanningStopped, varargin)
            persistent PreviousMouseLocation;
                        
            CurrentMouseLocation = getPointerLocation(obj.hZAxes,true,obj.zProjectionRange);
            
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
                    - CurrentMouseLocation(2) + PreviousMouseLocation(2);
                
                PreviousMouseLocation = getPointerLocation(obj.hZAxes,true,obj.zProjectionRange);
            end
            
        end
        
        function zScroll(obj, stop, varargin)
            if nargin > 2
                pt = getPointerLocation(obj.hZAxes, true, obj.zProjectionRange);%get(obj.hZAxes,'CurrentPoint');
                obj.setZ(pt(1,2));
                set(obj.hFig,...
                    'WindowButtonMotionFcn', @(varargin)obj.zScroll(false),...
                    'WindowButtonUpFcn',@(varargin)obj.zScroll(true));
                waitfor(obj.hFig,'WindowButtonMotionFcn',[]);
            elseif stop
                set(obj.hFig, 'WindowButtonMotionFcn', [], 'WindowButtonUpFcn', []);
            else
                pt = getPointerLocation(obj.hZAxes, true, obj.zProjectionRange);%get(obj.hZAxes,'CurrentPoint');
                obj.setZ(pt(1,2));
            end
        end
        
        % Linked to listener
        function setZ(obj, varargin)
            tfCont = false;
            if numel(varargin) == 2
                if isa(varargin{2}, 'event.PropertyEvent')
                    evt = varargin{2};
                    if strcmp(evt.EventName, 'PostSet') && (obj.zTracksSample || obj.hModel.hTileManager.tileScanningInProgress)

                        hPtFocus = scanimage.mroi.coordinates.Points(obj.hModel.hCoordinateSystems.hCSFocus,[0,0,0]);
                        hPtFocusSampleRelative = hPtFocus.transform(obj.hModel.hCoordinateSystems.hCSSampleRelative);
                        focusSampleZ = hPtFocusSampleRelative.points(1,3);
                        z = focusSampleZ;
                        
                        tfCont = true;
                    end
                else
                    src = varargin{1};
                    z = str2double(src.String);
                    tfCont = true;
                end
            elseif numel(varargin) == 1 && isnumeric(varargin{1})
                z = varargin{1};
                tfCont = true;
            else
                error('Unknown inputs');
            end
            
            if tfCont
                overviewZs = obj.overviewTileZs;
                scanZs = obj.scanTileZs;
                liveZs = obj.liveTileZs;

                allTileZs = [overviewZs scanZs liveZs 0];
                allUniqueTileZs = unique(allTileZs);

                [~, idx] = min(abs(z-allUniqueTileZs));

                nearestZ = allUniqueTileZs(idx);
                delta_ = abs(z-nearestZ);

                if delta_ < diff(obj.zProjectionRange)/100
                    z = nearestZ;
                end

                obj.currentZ = z;
                
                [~,~,exponent] = most.idioms.engineersStyle(max(abs(obj.zProjectionRange))*1e-6,'m');
                z_ = z.*1e-6 ./ 10^exponent;
                
                obj.hZprojectionScrollLine.YData = [z_ z_];
                obj.hZprojectionScrollKnob.YData = z_;
                
                obj.crosshairCenter.ZData = obj.currentZ-0.0001;
                
            end
        end
        
        function set.zProjectionRange(obj, v)
            
            if abs(diff(v)) > 2e6 || abs(diff(v)) < 1
                return
            end
            
            obj.zProjectionRange = v;
            
            [~,prefix,exponent] = most.idioms.engineersStyle(max(abs(v))*1e-6,'m');
            
            obj.hZAxes.YLim = v.*1e-6 ./ 10^exponent;
            ylabel(obj.hZAxes,['Sample Z [' prefix 'm]']); 
            
            z = obj.currentZ;
            z_ = z.*1e-6 ./ 10^exponent;
            
            obj.hZprojectionScrollLine.YData = [z_ z_];
            obj.hZprojectionScrollKnob.YData = z_;
            
            obj.crosshairCenter.ZData = obj.currentZ-0.0001;
        end
        
        function set.currentZ(obj, z)
            if z == 0
                obj.hFovAxes.ZLim = [-0.001 0.001]; 
            elseif z < 0
                obj.hFovAxes.ZLim = [z+(z*.001) z-(z*.001)];
            else
                obj.hFovAxes.ZLim = [z-(z*.001) z+(z*.001)];
            end
            obj.currentZ = z;
            obj.hFOV_ZLim = obj.hFovAxes.ZLim;
            
            
            obj.Crosshair.ZData = max(obj.hFovAxes.ZLim) * ones(1,5);
            
            obj.updateTickLabels;
        end
        
        function updateZEdit(obj, src, evt)
            obj.etZPos.String = num2str(obj.currentZ);
        end
                
        %% Z Scan
        function setSortFcn(obj, src, evt)
            path = which(obj.hModel.hTileManager.scanTileSortFcn);
            filterspec = {'*.m;*.p'};
            [filename,pathname] = uigetfile(filterspec,'Select a sorting function',path);
            if isequal(filename,0)
                % user cancelled
                return
            end
            
            [~,filename,~] = fileparts(filename); % remove extension
            path = fullfile(pathname,filename);
            
            path = regexp(path,'(\\\+[^(\\|(\\\+))]*){0,}\\[^\\]*$','match','once');
            path = regexprep(path,'(\\\+)|(\\)','.');
            path(1) = []; % remove leading '.'
            
            obj.hModel.hTileManager.scanTileSortFcn = path;
            
        end
        
        
    end
    
end

function colorMap = genColorMap()
    colorMap = containers.Map();
    %myMap('ColorName') = [r g b];
    colorMap('red') = [1 0 0];                   
    colorMap('green') = [0 1 0];                 
    colorMap('yellow') = [1 1 0];                
    colorMap('magenta') = [1 0 1];               
    colorMap('cyan') = [0 .6 1];                 
    colorMap('white') = [1 1 1];                 
    colorMap('grey') = [0.6510 0.6510 0.6510];   
    colorMap('purple') = [0.4941 0.1843 0.5569]; 
end

function warnFlash(element)
    element.BackgroundColor = [1 0 0];
    pause(0.05);
    element.BackgroundColor = [0.94 0.94 0.94];
    pause(0.05);
    element.BackgroundColor = [1 0 0];
    pause(0.05);
    element.BackgroundColor = [0.94 0.94 0.94];
end

function axDefaultCreateFcn(hAxes, ~)
    try
        hAxes.Interactions = [];
        hAxes.Toolbar = [];
    catch
        % ignore - old Matlab release
    end
end

function pt = getPointerLocation(hAx, tfRangeScale, range)
    if nargin < 3 || isempty(range)
        range = [];
        tfRangeScale = false;
    end
    
    pt = hAx.CurrentPoint(1, 1:2);
    
    if tfRangeScale
        [~,~,exponent] = most.idioms.engineersStyle(max(abs(range))*1e-6,'m');
        pt = (pt.*(10^exponent))./1e-6;
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
