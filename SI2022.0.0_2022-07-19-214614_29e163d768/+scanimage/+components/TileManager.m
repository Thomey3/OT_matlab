classdef TileManager < scanimage.interfaces.Component
    %%% ABSTRACT PROPERTY REALIZATION (scanimage.interfaces.Component)
    properties (SetAccess = protected, Hidden)
        numInstances = 1;
    end
    
    properties (Constant, Hidden)
        COMPONENT_NAME = 'TileManager';                     % [char array] short name describing functionality of component e.g. 'Beams' or 'FastZ'
        PROP_TRUE_LIVE_UPDATE = {};                         % Cell array of strings specifying properties that can be set while the component is active
        PROP_FOCUS_TRUE_LIVE_UPDATE = {};                   % Cell array of strings specifying properties that can be set while focusing
        DENY_PROP_LIVE_UPDATE = {};                         % Cell array of strings specifying properties for which a live update is denied (during acqState = Focus)
        
        FUNC_TRUE_LIVE_EXECUTION = {};                      % Cell array of strings specifying functions that can be executed while the component is active
        FUNC_FOCUS_TRUE_LIVE_EXECUTION = {};                % Cell array of strings specifying functions that can be executed while focusing
        DENY_FUNC_LIVE_EXECUTION = {};                      % Cell array of strings specifying functions for which a live execution is denied (during acqState = Focus)
    end
    
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = ziniInitPropAttributes();
        mdlInitSetExcludeProps;
        mdlHeaderExcludeProps;
    end
    
    properties(Hidden, SetAccess=protected)
       hOverviewTileObjListeners = event.listener.empty();   % Array of listeners to manage Overview tiles
       hScanTileObjListeners     = event.listener.empty();   % Array of listeners to manage Scan tiles
    end
    
    properties (SetObservable,SetAccess=protected)
       hOverviewTiles = scanimage.components.tiles.tile.empty();      % Array of overview tiles 
       hScanTiles     = scanimage.components.tiles.tile.empty();      % Array of scannable tiles
    end
    
    
    %% Tile Scanning Props
    properties(Hidden, SetAccess=protected)
        hScanControlListeners = [];           % [Listener] Array of Listeners for controlling tile scanning - Specifically done and abort calls.
    end
    
    properties(SetObservable)
        scanFramesPerTile = 1;                % [Integer] Specifies the number of frames to scan at each tile.
        isFastZ = false;                      % [Boolean] Specifies whether tiles are different Z planes should be imaged with the FastZ device or traversed with Stages
        scanStageSettleTime = 0.1;            % [Double]  Specifies the time for the stage to settle after moving to new tile before acquiring
    end
    
    properties(SetObservable, Transient)
        scanTileRoiGroups = scanimage.mroi.RoiGroup.empty(0,1);     % [ROI] Array of ROI's for the geometry of each tile. 
        acqDoneFlag = false;                                        % [Boolean] Flag to indicate acquisition has ended. (Work around for acqAbort firing at the end of grabs..)
        tilesDone;                                                  % [Integer] Counts the number of tiles that have been scanned.
        scanAbortFlag = false;                                      % [Boolean] Flag to indicate whether the tiling has been aborted. 
        tileScanningInProgress = false;
        
        loopedAcquisition = false, 
    end
    
    properties(SetObservable)
        scanTileSortFcn = 'scanimage.components.tileTools.tileSortingFcns.naiveNearest';  % [Char Fcn Path] The function used to order the scanning of Scan tiles by index.
        tileScanIndices;                                             % [Integer] Array of Scan tile indices indicating the order they are to be scanned in. 
    end
    
    %% Life-Cycle
    methods (Access = ?scanimage.SI)
        function obj = TileManager()
            obj@scanimage.interfaces.Component('SI TileManager');
        end
    end
    
    % Different method block due to access restrictions on constructor
    methods
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hOverviewTiles);
            most.idioms.safeDeleteObj(obj.hScanTiles);
            most.idioms.safeDeleteObj(obj.hOverviewTileObjListeners);
            most.idioms.safeDeleteObj(obj.hScanTileObjListeners);
            most.idioms.safeDeleteObj(obj.scanTileRoiGroups);
            most.idioms.safeDeleteObj(obj.hScanControlListeners);
        end
    end
    
    %% Abstract Realizations.
    methods(Access=protected)
        function componentStart(obj)
            %No-op
        end
        
        function componentAbort(obj)
            %No-op
        end
    end
    
    %% Tile Management
    methods
        function addOverviewTile(obj, tiles)
            hTiles = tiles;
            
            obj.hOverviewTiles = [obj.hOverviewTiles hTiles];
        end
        
        function addScanTile(obj, tiles)
            if ~obj.tileScanningInProgress
                hTiles = tiles;
                
                obj.hScanTiles = [obj.hScanTiles hTiles];
            end
        end
        
        % Object is already deleted at this point and this function just
        % cleans up handles to invalid or deleted objects in array,
        % Separated for performance
        function cleanUpScanTiles(obj, src, evt, varargin)
            removalMask = ~isvalid(obj.hScanTiles);
            if any(removalMask)
                obj.hScanTiles(removalMask) = [];
            end
        end
        
        function cleanUpOverviewTiles(obj, src, evt, varargin)
            removalMask = ~isvalid(obj.hOverviewTiles);
            if any(removalMask)
                obj.hOverviewTiles(removalMask) = [];
            end
        end
        
        % This will clear all overview tiles
        function clearOverviewTiles(obj)
            allTiles = obj.hOverviewTiles;
            obj.hOverviewTiles = [];
            delete(allTiles);
        end
        
        % This will clear all scan tiles
        function clearScanTiles(obj)
            if ~obj.tileScanningInProgress
                allTiles = obj.hScanTiles;
                obj.hScanTiles = [];
                delete(allTiles);
            end
        end
        
        function addAllScanTilesToOverview(obj)
            if ~obj.tileScanningInProgress
                warnFlag = false;
                if ~isempty(obj.hScanTiles)
                    ovTiles = scanimage.components.tiles.tile.empty();
                    for i = 1:numel(obj.hScanTiles)
                        
                        if ~isempty(obj.hScanTiles(i).hImgPyramid)
                            ovTiles(end+1) = obj.hScanTiles(i).copy();
                        else
                            warnFlag = true;
                        end
                    end
                    
                    if ~isempty(ovTiles)
                        obj.addOverviewTile(ovTiles);
                    end
                    
                    if warnFlag
                        warning('One or more scan tiles did not contain image data and could not be added to the overview');
                    end
                else
                    warning('No scan tiles exist to be added');
                end
            else
                warning('Can''t add scan tiles while currently engaged in scanning them');
            end
        end
        
        function loadTiles(obj, type)
            try
                assert(ischar(type) && ismember(type, {'Scan', 'Overview'}), 'Type must be one of either ''Scan'' or ''Overview'' ');
                
                if obj.tileScanningInProgress
                    warning('Can''t Load Tiles While Tile Scanning In Progress');
                else
                    hLoadTilesWB = waitbar(0/1, sprintf('Loading %s Tiles...', type));
                    setappdata(hLoadTilesWB,'canceling',0);
                    
                    startingDir = obj.hSI.hScan2D.logFilePath;
                    
                    if isempty(startingDir)
                        startingDir = pwd;
                    end
                    
                    [file, path] = uigetfile('*.SItile',sprintf('Load %s Tiles...', type),startingDir);
                    
                    if ~ischar(file) || ~ischar(path)
                        most.idioms.safeDeleteObj(hLoadTilesWB);
                        return;
                    end
                    
                    waitbar(.25/1,hLoadTilesWB, sprintf('Loading %s Tiles... ', type));
                    
                    load(fullfile(path, file), 'tiles_', '-mat');
                    
                    tilesArray = arrayfun(@(x) scanimage.components.tiles.tile.loadobj(x), tiles_);
                    
                    waitbar(1/1,hLoadTilesWB, sprintf('Loading %s Tiles... ', type));
                    
                    waitbar(.25/1,hLoadTilesWB, sprintf('Loading %s Tiles: Adding Tiles... ', type));
                    
                    switch type
                        case 'Scan'
                            obj.addScanTile(tilesArray);
                        case 'Overview'
                            obj.addOverviewTile(tilesArray);
                        otherwise
                            
                    end
                    
                    waitbar(1/1,hLoadTilesWB, sprintf('Loading %s Tiles: Adding Tiles... ', type));
                    
                    most.idioms.safeDeleteObj(hLoadTilesWB);
                end
            catch ME
                most.idioms.safeDeleteObj(hLoadTilesWB);
                most.ErrorHandler.logAndReportError(ME.message);
            end
        end
        
        function saveTiles(obj, type)
            try
                assert(ischar(type) && ismember(type, {'Scan', 'Overview'}), 'Type must be one of either ''Scan'' or ''Overview'' ');
                
                if obj.tileScanningInProgress
                    warning('Can''t Save Tiles While Tile Scanning In Progress');
                else
                    startingDir = obj.hSI.hScan2D.logFilePath;
                    timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
                    
                    if isempty(startingDir)
                        startingDir = pwd;
                    end
                    
                    defaultFileName = sprintf('%sTiles_%s.SItile',type, timestamp);
                    
                    [fname,logdir] = uiputfile('.SItile', sprintf('Save %s Tiles...',type), fullfile(startingDir, defaultFileName));
                    
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
                    
                    switch type
                        case 'Overview'
                            if isempty(obj.hOverviewTiles)
                                return;
                            else
                                tiles_ = arrayfun(@(x) x.saveobj(), obj.hOverviewTiles);
                            end
                        case 'Scan'
                            if isempty(obj.hScanTiles)
                                return;
                            else
                                tiles_ = arrayfun(@(x) x.saveobj(), obj.hScanTiles);
                                tiles_ = arrayfun(@(x) setfield(x,'imageData', cell(4,1)), tiles_);
                            end
                            
                        otherwise
                            error('Invalid Tile Type');
                    end
                    
                    save(fileAndPath,'tiles_');
                end
                
            catch ME
                most.ErrorHandler.logAndReportError(ME.message);
            end
        end
                       
        function tiles = makeTiles(obj, tfInMemory, tileParams)
            % Tile Params should either be roiData objects or a cell array
            % of defining parameters = {tileCenter, tileSize, zPos, channel, imageData}
            % imageData is optional (case for Scan Tiles)
            
            hCoordinateSystems = obj.hSI.hCoordinateSystems;
            extraParams = {obj.hSI.hDisplay.displayRollingAverageFactor, obj.hSI.hChannels.channelsAvailable};
            tiles = scanimage.components.tileTools.tileGeneratorFcns.defaultTileGenerator(hCoordinateSystems, tfInMemory, tileParams, extraParams);
        end
        
    end
    
    %% Get/Set Methods for tiles.
    methods
        function set.hOverviewTiles(obj,val)
            if isempty(val)
                val = scanimage.components.tiles.tile.empty();
            end
            
            delete(obj.hOverviewTileObjListeners);
            obj.hOverviewTileObjListeners = event.listener.empty();
            
            obj.hOverviewTiles = val(isvalid(val));
            
            obj.hOverviewTileObjListeners = most.ErrorHandler.addCatchingListener(obj.hOverviewTiles, 'ObjectBeingDestroyed', @(varargin)obj.cleanUpOverviewTiles);
            
            [obj.hOverviewTiles.scannable] = deal(false);
        end      
        
        function set.hScanTiles(obj,val)
            if isempty(val)
                val = scanimage.components.tiles.tile.empty();
            end
            
            delete(obj.hScanTileObjListeners);
            obj.hScanTileObjListeners = event.listener.empty();
            
            obj.hScanTiles = val(isvalid(val));
            
            obj.hScanTileObjListeners = most.ErrorHandler.addCatchingListener(obj.hScanTiles, 'ObjectBeingDestroyed', @(varargin)obj.cleanUpScanTiles);
            
        end
    end
    
    %% Helper Methods
    methods
        % Determines whether tile should be added or not
        function tf = addTile(obj, newTile, tilesArray, tileOverlap)
            closestTile = obj.findClosest(newTile, tilesArray);
            
            if ~isempty(closestTile)
                overlap = arrayfun(@(x) obj.getOverlap(newTile, x), closestTile, 'UniformOutput', true);
            end
            
            tf = isempty(closestTile) || ~any(overlap>tileOverlap);
        end
        
        % Find the tile(s) closes to this tile
        function closestTile = findClosest(obj, newTilePos, tilesArray, tfAllowThisTile)
            if nargin < 4 || isempty(tfAllowThisTile)
                tfAllowThisTile = false;
            end
            
            if isempty(tilesArray)
                closestTile = [];
                return;
            end
                
            newP = newTilePos;
            
            pointDistances = arrayfun(@(x) sqrt((x.samplePoint(1)-newP(1))^2+(x.samplePoint(2)-newP(2))^2+(x.samplePoint(3)-newP(3))^2),...
                tilesArray, 'UniformOutput', true);
            
            if ~tfAllowThisTile
                pointDistances(find(pointDistances == 0)) = [];
            end
            
            closestPointIdx = find(pointDistances == min(pointDistances));
            
            if numel(closestPointIdx) > 1
                closestPointIdx = closestPointIdx(randi(numel(closestPointIdx)));
            end

            closestTile = tilesArray(closestPointIdx);
        end
        
        % Determine the overlap between 2 tiles
        function overlapPercent = getOverlap(obj, newTile, refTile)
            
            sameZ = (newTile.zPos == refTile.zPos);
            sameRoi = strcmp(newTile.scanfield.name,refTile.scanfield.name);
            
            if sameZ
               overlapPercent = calcOverlap();
               
               % For precision issues, i.e. 0.999999999999999999997 != 1
               overlapPercent = str2num(num2str(overlapPercent, '%.3f'));
               
               if overlapPercent == 1 && ~(sameRoi)
                   overlapPercent = 0;
               end
               
            else
                overlapPercent = 0;
                return;
            end
            
            function overlap = calcOverlap()
                refTL = refTile.tileCornerPts(1,:);
                refTR = refTile.tileCornerPts(3,:);
                refBR = refTile.tileCornerPts(4,:);
                refBL = refTile.tileCornerPts(2,:);

                refLeftMostEdge = refTL(1);
                refRightMostEdge = refTR(1);
                refTopMostEdge  = refTL(2);
                refBottomMostEdge = refBL(2);

                AreaSelfNew = newTile.tileSize(1) * newTile.tileSize(2);

                newTL = newTile.tileCornerPts(1,:);
                newTR = newTile.tileCornerPts(3,:);
                newBR = newTile.tileCornerPts(4,:);
                newBL = newTile.tileCornerPts(2,:);

                newLeftMostEdge = newTL(1);
                newRightMostEdge = newTR(1);
                newTopMostEdge  = newTL(2);
                newBottomMostEdge = newBL(2);

                xOverlap = max(0, min(newRightMostEdge, refRightMostEdge) - max(newLeftMostEdge, refLeftMostEdge));
                yOverlap = max(0, min(newBottomMostEdge, refBottomMostEdge) - max(newTopMostEdge, refTopMostEdge));
                AreaOverlap = xOverlap*yOverlap;
                overlap = AreaOverlap/AreaSelfNew;
            end
        end
        
        % Find closes tile to current position
        function closestTileIdx = findTileClosestToCurPos(obj, tiles)
            curPos = obj.hSI.hMotors.samplePosition;
            
            startTile = obj.findClosest(curPos, tiles, true);
            TileIds = {tiles.uuid};
            closestTileIdx = find(contains(TileIds, startTile.uuid));
        end
        
        % Find tiles with matching geometery from all Z planes (Used for
        % filling data in FastZ)
        function indices = getSameTilesFromAllZ(obj, tile)
            sameTileLogical = arrayfun(@(x) all(all(tile.tileCornerPts == x.tileCornerPts)), obj.hScanTiles, 'UniformOutput', true);
            indices = find(sameTileLogical);
        end
        
    end
    
    %% Tile Scanning
    methods
        % Setup and start
        function initTileScanning(obj, varargin)
            % Re-create scanning listeners
            if ~isempty(obj.hScanControlListeners)
                most.idioms.safeDeleteObj(obj.hScanControlListeners);
            end
            
            if obj.isFastZ
                obj.hSI.hStackManager.enable = 1;
                obj.hSI.hStackManager.stackDefinition = 'arbitrary'; 
                obj.hSI.hStackManager.stackMode = 'fast';
                obj.hSI.hStackManager.stackFastWaveformType = 'step';
                % Handle Z pos outside FastZ range (i.e. negative).
                tileZs = [obj.hScanTiles.zPos];
                obj.hSI.hStackManager.numSlices = numel(unique(tileZs));
                obj.hSI.hStackManager.arbitraryZs = unique(sort(tileZs))';
                % Only do XY's of first plane. Fill data in subsequent
                % planes as needed... Need to identify.
                closestTileIdx = obj.findTileClosestToCurPos(obj.hScanTiles(find(tileZs == obj.hSI.hStackManager.zs(1))));
                obj.tileScanIndices = obj.getTileScanPath(closestTileIdx, obj.hScanTiles(find(tileZs == obj.hSI.hStackManager.zs(1))));
            else
                % Sort scanTile idexes by Z.
                obj.hSI.hStackManager.enable = 0;
                zPos = [obj.hScanTiles.zPos];
                closestTileIdx = obj.findTileClosestToCurPos(obj.hScanTiles);
                obj.tileScanIndices = obj.getTileScanPath(closestTileIdx, obj.hScanTiles);
            end
            
            obj.hScanControlListeners = [obj.hScanControlListeners most.ErrorHandler.addCatchingListener(obj.hSI.hUserFunctions, 'acqModeDone', @obj.endOfTile)];
            obj.hScanControlListeners = [obj.hScanControlListeners most.ErrorHandler.addCatchingListener(obj.hSI.hUserFunctions, 'acqAbort', @obj.abortTileScan)];
            obj.hScanControlListeners = [obj.hScanControlListeners most.ErrorHandler.addCatchingListener(obj.hSI.hUserFunctions, 'acqDone', @obj.setAcqDoneFlag)];
%             obj.hScanControlListeners = [obj.hScanControlListeners most.ErrorHandler.addCatchingListener(obj.hSI.hUserFunctions, 'frameAcquired', @obj.tileImageUpdated)];
            
            obj.hScanControlListeners = [obj.hScanControlListeners most.ErrorHandler.addCatchingListener(obj.hSI.hDisplay, 'rollingStripeDataBuffer', 'PostSet', @obj.tileImageUpdated)];

            % Setup Scanning
            obj.hSI.hStackManager.framesPerSlice = obj.scanFramesPerTile;
            obj.hSI.hRoiManager.mroiEnable = true;

            % Setup tile ROIs for tile sizes...
            obj.scanTileRoiGroups = obj.generateTileRoiGroups();
            
            allRoiGroupsAreTheSame = all( obj.scanTileRoiGroups(1).isequalish(obj.scanTileRoiGroups,1) );
            obj.loopedAcquisition = allRoiGroupsAreTheSame;

            % Start the scan
            obj.scanAbortFlag = false;
            obj.acqDoneFlag = false;
            obj.tilesDone = 1;
            
            % Prevents distortions caused by turning this on and off.
            switch obj.hSI.hScan2D.scannerType
                case {'RG', 'RGG', 'ResScan', 'Resscan'}
                    obj.hSI.hScan2D.keepResonantScannerOn = 1;
                otherwise
                    obj.hSI.hScan2D.keepResonantScannerOn = 0;
            end
                        
            obj.tileScanningInProgress = true;
            
            if obj.loopedAcquisition
                obj.hSI.hRoiManager.roiGroupMroi.copyobj(obj.scanTileRoiGroups(1));
                obj.hSI.extTrigEnable = true;
                
                if isa(obj.hSI.hScan2D, 'scanimage.components.scan2d.LinScan')
                    obj.hSI.hScan2D.trigAcqInTerm = 'PFI0'; % Needs to be set for GG NI
                else
                    obj.hSI.hScan2D.trigAcqInTerm = ''; 
                end
                
                obj.hSI.acqsPerLoop = numel(obj.scanTileRoiGroups);
                % Do not start the loop yet as the scan is not configured
                % and the tile is not moved to yet.
            else
                obj.hSI.extTrigEnable = false;
            end
            
            obj.startNextTileScan();
        end
        
        function scanTilePathIdxs = getTileScanPath(obj, startTileIdx, scanTiles)            
            pathFnc = str2func(obj.scanTileSortFcn);
            scanTilePathIdxs = pathFnc(startTileIdx, scanTiles);
        end
        
        % Starts next scan or returns done and aborts
        function done = startNextTileScan(obj)
            N = numel(obj.tileScanIndices);
            done = (obj.tilesDone > N)||obj.scanAbortFlag;
            obj.tileScanningInProgress = ~done;
            
            if done
                obj.abortTileScan();
            else
                % move to next tile
                samplePosition = scanimage.mroi.coordinates.Points(obj.hSI.hCoordinateSystems.hCSSampleRelative,...
                    obj.hScanTiles(obj.tileScanIndices(obj.tilesDone)).samplePoint);
                
                obj.hSI.hMotors.movePtToPosition(obj.hSI.hCoordinateSystems.focalPoint,samplePosition);
                % Allow motor to settle - necessary for loop mode
                pause(obj.scanStageSettleTime);
                
                % This might seem redundant but depending on when you abort
                % you can get odd behavior without it.- i.e. if the abort
                % happens during settling pause, tileScanningInPogress is
                % set to false. 
                if obj.tileScanningInProgress
                    
                    if obj.loopedAcquisition
                        if ~strcmp(obj.hSI.acqState, 'loop')
                            obj.hSI.startLoop();
                        end
                        obj.hSI.hScan2D.trigIssueSoftwareAcq();
                    else
                        % Load Next TileROI Group
                        %                     obj.hSI.hController{1}.hRoiGroupEditor.clearGroup();
                        nextTileIdx = obj.tileScanIndices(obj.tilesDone);
                        nextRoiGroup = obj.scanTileRoiGroups(nextTileIdx);
                        obj.hSI.hRoiManager.roiGroupMroi.copyobj(nextRoiGroup);
                        
                        % Start next tile acquisition
                        obj.hSI.startGrab();
                    end
                end
            end
        end      
        
        % Iterates scan tiles
        function endOfTile(obj, varargin)
            data = obj.hSI.hDisplay.rollingStripeDataBuffer;
            obj.updateCurrentScanTile(data);
            obj.saveTileMetaData();
            if obj.tileScanningInProgress && ~obj.scanAbortFlag
                obj.tilesDone = obj.tilesDone + 1;
                obj.startNextTileScan();
            end
        end
        
        function abortTileScan(obj, varargin)
            % When acqAbort is fired as part of the end of grab routine,
            % it is preceded by an acqDone event and followed by
            % acqModeDone event. The latter is used to trigger scanning of
            % the subsequent tile. However, in an intentional abort,
            % acqAbort is the only event fired. This flag is used to
            % distinguish the two situations
            if ~obj.scanAbortFlag && obj.acqDoneFlag
                obj.acqDoneFlag = false;
                % This flag trick is for dealing with then end of a grab
                % sequence, it works differently for loops so a manually
                % call to abort is made after the flag is set differently
                % to actually abort. 
                if obj.loopedAcquisition
                    obj.abortTileScan();
                end
            else
                % Delete the listeners so these aren't being fired when not-tile
                % scanning...
                most.idioms.safeDeleteObj(obj.hScanControlListeners);
                obj.tileScanningInProgress = false;
                obj.scanAbortFlag = false;
                
                % Some of these properties reset themselves when doing
                % looped mode because they are cached and restored
                % before and after the acquisition. This not an issue with
                % grab mode because each is a separate acquisition. 
                obj.hSI.abort();
                obj.hSI.hRoiManager.mroiEnable = 0;
                obj.hSI.hStackManager.enable = 0;
                obj.hSI.hScan2D.keepResonantScannerOn = 0;
                obj.hSI.extTrigEnable = false;
                obj.hSI.hScan2D.trigAcqInTerm = '';
            end
        end
        
        function tileImageUpdated(obj, varargin)
            data = obj.hSI.hDisplay.rollingStripeDataBuffer;
            obj.updateCurrentScanTile(data);
        end
        
        % Updates the scan tile with live image data
        function updateCurrentScanTile(obj, data)
            if obj.isFastZ
                thisTile = obj.hScanTiles(obj.tileScanIndices(obj.tilesDone));
                allTileZIndices = obj.getSameTilesFromAllZ(thisTile);
                % Rolling stripe Data buffer is empty before Z is
                % scanned... No tracking of what Z I am on? 
                if ~isempty(data)%&& ~any(cellfun(@(x) isempty(x.roiData), data{1}))
                    % If GG the data buffer seems to update 1 at a time. So
                    % live update doesnt work
                    for numZ = 1:numel(allTileZIndices)
                        try
                            stripeData = data{numZ}{1};
                        catch ME
                            'tt'
                        end
                        
                        if ~isempty(stripeData)
                            imgData = parseStripeImgData(stripeData);
                            
                            
                            obj.hScanTiles(allTileZIndices(numZ)).imageData = imgData;
                            obj.hScanTiles(allTileZIndices(numZ)).displayAvgFactor = obj.hSI.hDisplay.displayRollingAverageFactor;
                        end
                    end
                end
                
            else
                stripeData = data{1}{1};
                if ~isempty(stripeData.roiData)
                    imgData = parseStripeImgData(stripeData);
                    
                    obj.hScanTiles(obj.tileScanIndices(obj.tilesDone)).imageData = imgData;
                    obj.hScanTiles(obj.tileScanIndices(obj.tilesDone)).displayAvgFactor = obj.hSI.hDisplay.displayRollingAverageFactor;
                end
            end
            
            % For consistency, parse out image data from stripe object
            % which is usually wrapped in an extra cell and missing 
            % sequntial channel information. 
            %
            % For example, imaging channels 1, 2, 4 results in imgData as
            % { {[512x512]}  {[512x512]} {[512x512]} } which would be 
            % interpreted as Chans 1-3 and has an extra cell layer. 
            % Ideally, we want the Tile Image data to be sent to the Tile 
            % constructor in the form
            % { [512x512] [512x512] [] [512x512] }. 
            % This is normally taken care of by the Tile Generator function
            % however, Scan Tile start with empty image data and the data
            % is added as stripes are collected during imaging. 
            function imgData = parseStripeImgData(stripeData)
                if isempty(stripeData.roiData)
                    imgData = cell(1,4);
                    return
                end
                
                stripeChans = stripeData.channelNumbers;
                imgData = cell(1,max(stripeChans));
                
                imageData = stripeData.roiData{1}.imageData;
                
                chansAvail = 1:max(stripeData.channelNumbers);
                
                missingChans = find(ismember(chansAvail, stripeChans)==0);
                % Insert empties for missing channels.
                for i = 1:numel(missingChans)
                    missingChan = missingChans(i);
                    imageData = {imageData{1:missingChan-1}, {[]}, imageData{missingChan:end}};
                end
                
                % Remove extra cell layer.
                imgData = cellfun(@(x) x{1}, imageData, 'UniformOutput', false);
            end
            
        end
        
        % Creates the ROI groups for each scan tile
        function TileRG = generateTileRoiGroups(obj)
             tileRoiGroup = scanimage.mroi.RoiGroup.empty(0,numel(obj.hScanTiles));
             for tileIdx = 1:numel(obj.hScanTiles)
                 tileRoi = scanimage.mroi.Roi;
                 
                 sf = scanimage.mroi.scanfield.fields.RotatedRectangle();
                 sf.setByAffine(obj.hScanTiles(tileIdx).affine)
                 sf.centerXY = [0 0]; %Needs to be [0 0] or offset if mROI
                 sf.pixelResolutionXY = obj.hScanTiles(tileIdx).resolutionXY;
                 
                 tileRoi.add(obj.hScanTiles(tileIdx).zPos, sf);
                 tileRoiGroup(tileIdx) = scanimage.mroi.RoiGroup(sprintf('ScanTiles_%d',tileIdx));
                 tileRoiGroup(tileIdx).add(tileRoi);
             end
             
             TileRG = tileRoiGroup;
             
        end
        
        % When acqAbort is fired as part of the end of grab routine,
        % it is preceded by an acqDone event and followed by
        % acqModeDone event. The latter is used to trigger scanning of
        % the subsequent tile. However, in an intentional abort,
        % acqAbort is the only event fired. This flag is used to
        % distinguish the two situations.
        % This function is called on acqDone
        function setAcqDoneFlag(obj, varargin)
            obj.acqDoneFlag = true;
            if obj.loopedAcquisition
                obj.endOfTile();
            end
        end
        
    end
    
    %% Tile Meta-Data Logging
    methods
        function metaData = getTileMetaData(obj)
            currentTile = obj.hScanTiles(obj.tileScanIndices(obj.tilesDone));
            metaData = struct();
            
            
            metaData.tileID = currentTile.uuid;
            metaData.tileSamplePointXY = currentTile.samplePoint(1:2);
            metaData.tileSizeUm = currentTile.tileSize;
            metaData.tileCornerPtsUm = currentTile.tileCornerPts;
            metaData.tileResolution = currentTile.resolutionXY;
            metaData.tileAffine = currentTile.affine;
            
            metaData.tileChannelsAvailable = currentTile.channels;
            metaData.channelsAcquired = obj.hSI.hChannels.channelsActive;
            metaData.channelsSaved = obj.hSI.hChannels.channelSave;
            
            metaData.displayAvgFactor = currentTile.displayAvgFactor;

            metaData.framesPerTile = obj.scanFramesPerTile;
            metaData.isFastZ = obj.isFastZ;

            if obj.isFastZ
                metaData.numTilesToScan = numel(obj.tileScanIndices)*numel(unique(sort([obj.hScanTiles.zPos])));
                metaData.tileScannedThisFile = [obj.getSameTilesFromAllZ(currentTile)];
                metaData.tileZs = unique(sort([obj.hScanTiles.zPos]));
            else
                metaData.numTilesToScan = numel(obj.tileScanIndices);
                metaData.tileScannedThisFile = obj.tilesDone;
                metaData.tileZs = currentTile.zPos;
            end            
            
        end
        
        function saveTileMetaData(obj)
            if obj.hSI.hChannels.loggingEnable
                if isempty(obj.hSI.hScan2D.logFilePath)
                    path = pwd;
                else
                    path = obj.hSI.hScan2D.logFilePath;
                end
                fname = fullfile([path '\' obj.hSI.hScan2D.logFileStem '_' sprintf('%05d', obj.hSI.hScan2D.logFileCounter)]);
                
                if obj.hSI.hScan2D.logFramesPerFile < inf
                    fname = [fname '_' sprintf('%05d', obj.hSI.hScan2D.logFileSubCounter)];
                end
                
                fname = [fname '.tileData.txt'];
                
                metaStruct = obj.getTileMetaData;
                most.json.savejson('TileData', metaStruct, 'tab', '   ', 'filename', fname);
            end
        end
    end
    
end

function s = ziniInitPropAttributes()
    s = struct();
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
