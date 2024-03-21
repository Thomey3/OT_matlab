classdef tileExpanseTool < scanimage.components.tileTools.tileTool
   
    %% Abstract Property Realization
    properties(Constant)
        toolName = 'Draw Tile Expanse';
    end
    
    properties
        tileData;
        initTileOutline = matlab.graphics.primitive.Surface.empty(0,1);
        tilePositions = {};
        phantomTiles;
    end
    
    properties
        zRange;
    end
    
    % Tile Properties
    properties(SetObservable)
        % Initial center around which tiles are made
        tilingCenterX = 0;
        tilingCenterY = 0;
        
        % Size of tiles in X and Y
        tileSizeX = 9;
        tileSizeY = 9;
        
        % The number of tiles in X and Y
        numTilesX = 1;
        numTilesY = 1;
        
        % How far apart Tiles are spaced in X and Y
        tileDistX = 5;
        tileDistY = 5;
        
        tileResX = 512;
        tileResY = 512;
        
        numTiles;
        
        tfSymmetricExpanse = true;
    end
    
    %% Life-Cycle
    methods
        function obj = tileExpanseTool(hTileView)
            obj@scanimage.components.tileTools.tileTool(hTileView);
            obj.activateTool();
        end
        
        function delete(obj)
            obj.deactivateTool();
            delete(obj.initTileOutline);
            delete(obj.phantomTiles);
        end
    end
    
    %% Functional
    methods
        function activateTool(obj)
            obj.hAxes.ButtonDownFcn = @obj.drawTileArea;
            obj.hFig.Pointer = 'crosshair';
            obj.disableTileSurfHitTest();
        end
        
        function deactivateTool(obj)
            obj.hFig.Pointer = 'arrow';
            set(obj.hFig,'WindowButtonMotionFcn',[],'WindowButtonUpFcn',[]);
            
            set(obj.hAxes, 'ButtonDownFcn', []);
            obj.hTileView.restoreBtnDwnFcn();
            
            obj.enableTileSurfHitTest();
        end
        
        % You can draw through/over tiles...
        function disableTileSurfHitTest(obj)
            
            obj.hTileView.hOverviewTileGroup.HitTest = 'off';
            obj.hTileView.hScanTileGroup.HitTest = 'off';
            obj.hTileView.hLiveDisplayGroup.HitTest = 'off';
            
            if most.idioms.isValidObj(obj.hTileView.hLiveTileDisp)
                arrayfun(@(x) set(x.hSurf,'HitTest','off'), obj.hTileView.hLiveTileDisp);
            end
            arrayfun(@(x) set(x.hSurf,'HitTest','off'), obj.hTileView.hScanTileDisps);
            arrayfun(@(x) set(x.hSurf,'HitTest','off'), obj.hTileView.hOverViewTileDisps);

        end
        
        function enableTileSurfHitTest(obj)
            obj.hTileView.hOverviewTileGroup.HitTest = 'on';
            obj.hTileView.hScanTileGroup.HitTest = 'on';
            obj.hTileView.hLiveDisplayGroup.HitTest = 'on';
            
            if most.idioms.isValidObj(obj.hTileView.hLiveTileDisp)
                arrayfun(@(x) set(x.hSurf,'HitTest','on'), obj.hTileView.hLiveTileDisp);
            end
            arrayfun(@(x) set(x.hSurf,'HitTest','on'), obj.hTileView.hScanTileDisps);
            arrayfun(@(x) set(x.hSurf,'HitTest','on'), obj.hTileView.hOverViewTileDisps);
            
        end
        
        function apply(obj, tileParams)
            tiles = scanimage.components.tiles.tile.empty(0,1);
            tfAdd = true;
            if ~isempty(tileParams)
                tileCenterPts = tileParams{1};
                tileCornerPts = tileParams{2};
                
                nTiles = obj.numTiles;
                finalZ = max(obj.zRange);
                
                
                tileGenWaitBar = waitbar(0,sprintf('Z Plane %.2f of %.2f, Generating Tiles %d of %d',min(obj.zRange), finalZ, 1, nTiles),'CloseRequestFcn','setappdata(gcbf,''canceling'',1)');
                setappdata(tileGenWaitBar,'canceling',0);
                
                try
                    if ~isempty(tileCenterPts)
                        for curZ = obj.zRange
                            waitbar(curZ/numel(obj.zRange),tileGenWaitBar,sprintf('Z Plane %.2f of %.2f, Generating %d Tiles',curZ, finalZ, nTiles));
                            for curTile = 1:nTiles
                                if getappdata(tileGenWaitBar,'canceling')
                                    most.idioms.safeDeleteObj(tileGenWaitBar);
                                    tfAdd = false;
                                    break
                                end
                                tiles(end+1) = obj.makeScanTile(obj.hSI,tileCenterPts{curTile},tileCornerPts{curTile},curZ, 1:obj.hSI.hChannels.channelsAvailable, [obj.tileResX obj.tileResY]);
                            end
                        end
                        most.idioms.safeDeleteObj(tileGenWaitBar);
                    else
                        tfAdd = false;
                    end
                catch ME
                    most.idioms.safeDeleteObj(tileGenWaitBar);
                    most.ErrorHandler.rethrow(ME);
                end
            end
            
            if tfAdd
                hWb = waitbar(0.2,'Generating tile displays');
                try
                    obj.hTileView.hModel.hTileManager.addScanTile(tiles);
                catch ME
                    most.idioms.safeDeleteObj(hWb);
                    most.ErrorHandler.rethrow(ME);
                end
                most.idioms.safeDeleteObj(hWb);
            else
                delete(tiles);
            end
        end
    end
    
    methods
        function val = get.numTiles(obj)
           val = numel(obj.tilePositions); 
        end
    end
    
    %% Tool Specific
    methods
        function drawTileArea(obj, stop, varargin)
            persistent oppt;
            persistent ocenterxy;
            persistent centerxy;
            persistent hsz;
            
            if nargin > 2
                oppt = getPointerLocation(obj.hAxes);
                
                hsz = [100 100]/2; 
                centerxy = hsz;
                
                handleLen = diff(obj.hAxes.YLim) / 40;

                pts = [centerxy-hsz; centerxy+[-hsz(1) hsz(2)]; centerxy+[hsz(1) -hsz(2)]; centerxy+hsz; centerxy; centerxy-[0 hsz(2)+handleLen]];
                rot = 0;
                R = [cos(rot) sin(rot) 0;-sin(rot) cos(rot) 0; 0 0 1];
                pts = scanimage.mroi.util.xformPoints(pts,R);
                pts = pts + repmat(oppt,6,1);
                ocenterxy = pts(5,:);
                centerxy = ocenterxy;

                xx = [pts(1:2,1) pts(3:4,1)];
                yy = [pts(1:2,2) pts(3:4,2)];
                
                % Zdata of outline must be within axes Z lim. 
                axesZLim = obj.hAxes.ZLim;
                obj.initTileOutline = surface(xx, yy, ones(2),'FaceColor','none','edgecolor','white','linewidth',1,'parent',obj.hAxes);
                zLimRange = min(axesZLim):0.0001:max(axesZLim);
                idx = floor(numel(zLimRange)/2)+1;
                obj.initTileOutline.ZData = zLimRange(idx)*ones(2);
                    
                set(obj.hFig,'WindowButtonMotionFcn',@(varargin)obj.drawTileArea(false),'WindowButtonUpFcn',@(varargin)obj.drawTileArea(true));
                waitfor(obj.hFig,'WindowButtonMotionFcn',[]);
            elseif stop
                
                obj.deactivateTool();
                
                sz = hsz*2;
                
                obj.tilingCenterX = centerxy(1);
                obj.tilingCenterY = centerxy(2);
                
                maxSz = obj.getAbsMaxScanTileSize();
                if sz(1) > maxSz(1)
                    sz(1) = maxSz(1);
                end
                
                if sz(2) > maxSz(2)
                    sz(2) = maxSz(2);
                end
                
                obj.tileSizeX = sz(1);
                obj.tileSizeY = sz(2);
                
                if isempty(obj.zRange)
                    obj.zRange = obj.hFig.UserData.currentZ;
                end
                
                obj.updateInitTile();
                obj.updatePhantomOutlines();
                
                tileParams = obj.setTileParams();
                
                % Send Tile Params to generator
                obj.apply(tileParams);
                
                if isvalid(obj.initTileOutline)
                    most.idioms.safeDeleteObj(obj.initTileOutline);
                end
                
                if isvalid(obj.phantomTiles)
                    most.idioms.safeDeleteObj(obj.phantomTiles);
                end
            else
                nwpt = getPointerLocation(obj.hAxes);
                
                centerxy = (oppt+nwpt)/2;
                
                relpt = nwpt - centerxy;
                rot = 0;
                R = [cos(rot) sin(rot) 0;-sin(rot) cos(rot) 0; 0 0 1];
                hsz = abs(scanimage.mroi.util.xformPoints(relpt,R,true));
                
                %find new points
                handleLen = diff(obj.hAxes.YLim) / 40;
                pts = [-hsz; -hsz(1) hsz(2); hsz(1) -hsz(2); hsz; 0 0; 0 -hsz(2)-handleLen];
                rot = 0;
                R = [cos(rot) sin(rot) 0;-sin(rot) cos(rot) 0; 0 0 1];
                pts = scanimage.mroi.util.xformPoints(pts,R);
                pts = pts + repmat(centerxy,6,1);

                xx = [pts(1:2,1) pts(3:4,1)];
                yy = [pts(1:2,2) pts(3:4,2)];
                obj.initTileOutline.XData = xx;
                obj.initTileOutline.YData = yy;
            end
        end
        
        function updateTilePositions(obj)
            
            if obj.tfSymmetricExpanse
                curXPos = obj.tilingCenterX-((0.5*obj.tileDistX)*(obj.numTilesX-1));
                curYPos = obj.tilingCenterY-((0.5*obj.tileDistY)*(obj.numTilesY-1));
            else
                curXPos = obj.tilingCenterX;
                curYPos = obj.tilingCenterY;
            end

            nRows = obj.numTilesY;
            nCols = obj.numTilesX;
            obj.tilePositions = cell(nRows,nCols);

            obj.tilePositions{1,1} = [curXPos,curYPos];

            for i = 1:nRows
                    for j = 1:nCols
                        if ~(i == 1 && j == 1)
                            obj.tilePositions{i,j} = [curXPos, curYPos];
                            curXPos = curXPos + obj.tileDistX;
                        else
                            curXPos = curXPos + obj.tileDistX;
                        end
                    end
                    if obj.tfSymmetricExpanse
                        curXPos = obj.tilingCenterX - ((0.5*obj.tileDistX)*(obj.numTilesX-1));
                    else
                        curXPos = obj.tilingCenterX;
                    end
                    
                    curYPos = curYPos + obj.tileDistY;
            end

        end
        
        function updatePhantomOutlines(obj)
            delete(obj.phantomTiles);
            
            obj.updateTilePositions();
            
            phantTileCorners = obj.generateCornerPoints(obj.tilePositions, [obj.tileSizeX obj.tileSizeY]);
            
            zPos = obj.hTileView.currentZ;
            
            xData = [];
            yData = [];
            zData = [];
            %cp_{i} = [TL; TR; BR; BL]
            for numeTileIdx = 1:numel(obj.tilePositions)
                currentCorners = phantTileCorners{numeTileIdx};
                TL = currentCorners(1,:);
                TR = currentCorners(2,:);
                BR = currentCorners(3,:);
                BL = currentCorners(4,:);
                xData = [xData TL(1) TR(1) BR(1) BL(1) TL(1) nan(1,5)];
                yData = [yData TL(2) TR(2) BR(2) BL(2) TL(2) nan(1,5)];
                zData = [zData zPos zPos zPos zPos zPos nan(1,5)];
            end
            
            obj.phantomTiles = line(xData,yData,zData,'color', 'white', 'parent', obj.hAxes);
            obj.initTileOutline.Visible = 'off';
        end
        
        % Leave init tile as surf, easier drawing
        function updateInitTile(obj)
            if isvalid(obj.initTileOutline) && isa(obj.initTileOutline, 'matlab.graphics.primitive.Surface')
                % 1) Update Center
                p = [obj.tilingCenterX obj.tilingCenterY obj.hFig.UserData.currentZ];
                
                % 2) Update Size
                sizeXum = obj.tileSizeX;
                sizeYum = obj.tileSizeY;
                [xx, yy] = meshgrid([-.5 .5], [-.5 .5]);
                ScannerToMotorSpace = [sizeXum 0 0; 0 sizeYum 0; 0 0 1];
                [surfMeshXX, surfMeshYY] = scanimage.mroi.util.xformMesh(xx,yy,ScannerToMotorSpace);
                
                % 3) Commit Changes to Surf
                cData = nan;
                xdata = p(1) + surfMeshXX;
                ydata = p(2) + surfMeshYY;
                zdata = p(3)*ones(2);
                
                obj.initTileOutline.XData = xdata;
                obj.initTileOutline.YData = ydata;
                obj.initTileOutline.ZData = zdata;
                obj.initTileOutline.CData = cData;
                
                obj.initTileOutline.Visible = 'off';
            else
                % Create surface?
            end
            
        end
        
    end
    
    %% UI
    methods
        function tileParams = setTileParams(obj)
            if nargin < 1 || isempty(obj)
                obj = [];
            end
            
            obj.tileDistX = obj.tileSizeX;
            obj.tileDistY = obj.tileSizeY;

            dlg = dialog('Position', most.gui.centeredScreenPos([270, 370]), 'Name', 'Tile Params', 'CloseRequestFcn', @closeFcn);
            
            mainFlow = most.gui.uiflowcontainer('Parent', dlg, 'FlowDirection', 'TopDown');
            
            
                columnFlow =  most.gui.uiflowcontainer('Parent', mainFlow, 'FlowDirection', 'LeftToRight');
                columnFlow.HeightLimits = [215 215];
                    %% Left Column: Headings
                    headingFlow = most.gui.uiflowcontainer('Parent', columnFlow, 'FlowDirection', 'TopDown');
                        emptyHeading = uicontrol('Parent', headingFlow, 'Style', 'text', 'String', '');
                            emptyHeading.HeightLimits = [20 20];
                        tileCenterText = uicontrol('Parent', headingFlow, 'Style', 'text', 'String', 'Center Pos(um):');
                            tileCenterText.HeightLimits = [30 30];
                        tileSizeText = uicontrol('Parent', headingFlow, 'Style', 'text', 'String', 'Tile Sizes(um):');
                            tileSizeText.HeightLimits = [30 30];
                        tileQuantText = uicontrol('Parent', headingFlow, 'Style', 'text', 'String', 'Num Tiles:');
                            tileQuantText.HeightLimits = [30 30];
                        tileDistText = uicontrol('Parent', headingFlow, 'Style', 'text', 'String', 'Tile Spacing(um):');
                            tileDistText.HeightLimits = [30 30];
                        overlapXTxt = uicontrol('Parent', headingFlow, 'Style', 'text', 'String', 'Overlap %');
                            overlapXTxt.HeightLimits = [30 30];
                        overlapResXY = uicontrol('Parent', headingFlow, 'Style', 'text', 'String', 'Resolution');
                            overlapResXY.HeightLimits = [30 30];
                            
                    headingFlow.WidthLimits = [100 100];
                    
                    %% Right Column: XY Settings
                    xyFlow = most.gui.uiflowcontainer('Parent', columnFlow, 'FlowDirection', 'TopDown');
                        XYText = uicontrol('Parent', xyFlow, 'Style', 'text', 'String', 'X                         Y');
                        XYText.WidthLimits = [160 160];
                        XYText.HeightLimits = [11 11];
                        
                        %% Init Center Pt
                        centerFlow = most.gui.uiflowcontainer('Parent', xyFlow, 'FlowDirection', 'LeftToRight');
                            etTilingCenterX = uicontrol('Parent', centerFlow, 'Style', 'edit', 'string', sprintf('%.2f', obj.tilingCenterX), 'callback', @setCenterX);
                                etTilingCenterX.HeightLimits = [30 30];
                                etTilingCenterX.WidthLimits = [75 75];

                            etTilingCenterY = uicontrol('Parent', centerFlow, 'Style', 'edit', 'string', sprintf('%.2f', obj.tilingCenterY), 'callback', @setCenterY);
                                etTilingCenterY.HeightLimits = [30 30];
                                etTilingCenterY.WidthLimits = [75 75];


                        centerFlow.HeightLimits = [30 30];
                        centerFlow.WidthLimits = [300 300];

                        %% Tile Sizes
                        sizeFlow = most.gui.uiflowcontainer('Parent', xyFlow, 'FlowDirection', 'LeftToRight');
                            etTileSizeX = uicontrol('Parent', sizeFlow, 'Style', 'edit', 'string', sprintf('%.2f', obj.tileSizeX), 'callback', @setSizeX);
                            etTileSizeX.HeightLimits = [30 30];
                            etTileSizeX.WidthLimits = [75 75];

                            etTileSizeY = uicontrol('Parent', sizeFlow, 'Style', 'edit', 'string', sprintf('%.2f', obj.tileSizeY), 'callback', @setSizeY);
                            etTileSizeY.HeightLimits = [30 30];
                            etTileSizeY.WidthLimits = [75 75];

                        sizeFlow.HeightLimits = [30 30];
                        sizeFlow.WidthLimits = [300 300];

                        %% Tile Quant
                        quantFlow = most.gui.uiflowcontainer('Parent', xyFlow, 'FlowDirection', 'LeftToRight');
                            etNumTilesX = uicontrol('Parent', quantFlow, 'Style', 'edit', 'string', sprintf('%d', obj.numTilesX), 'callback', @setTileQuantX);
                            etNumTilesX.HeightLimits = [30 30];
                            etNumTilesX.WidthLimits = [75 75];

                            etNumTilesY = uicontrol('Parent', quantFlow, 'Style', 'edit', 'string', sprintf('%d', obj.numTilesY), 'callback', @setTileQuantY);
                            etNumTilesY.HeightLimits = [30 30];
                            etNumTilesY.WidthLimits = [75 75];

                        quantFlow.HeightLimits = [30 30];
                        quantFlow.WidthLimits = [300 300];

                        %% Tile Distance
                        distFlow = most.gui.uiflowcontainer('Parent', xyFlow, 'FlowDirection', 'LeftToRight');
                            etTileDistX = uicontrol('Parent', distFlow, 'Style', 'edit', 'string', sprintf('%.2f', obj.tileSizeX), 'callback', @setTileDistX);
                            etTileDistX.HeightLimits = [30 30];
                            etTileDistX.WidthLimits = [75 75];

                            etTileDistY = uicontrol('Parent', distFlow, 'Style', 'edit', 'string', sprintf('%.2f', obj.tileSizeY), 'callback', @setTileDistY);
                            etTileDistY.HeightLimits = [30 30];
                            etTileDistY.WidthLimits = [75 75];

                        distFlow.HeightLimits = [30 30];
                        distFlow.WidthLimits = [300 300];

                        %% Tile Overlap
                        overlapFlow = most.gui.uiflowcontainer('Parent', xyFlow, 'FlowDirection', 'LeftToRight');
                            overlapX = obj.getTileOverlapX();
                            etOverlapX = uicontrol('Parent', overlapFlow, 'Style', 'edit', 'string', sprintf('%.2f', overlapX), 'Enable', 'off');

                            etOverlapX.HeightLimits = [30 30];
                            etOverlapX.WidthLimits = [75 75];

                            overlapY = obj.getTileOverlapY();
                            etOverlapY = uicontrol('Parent', overlapFlow, 'Style', 'edit', 'string', sprintf('%.2f', overlapY), 'Enable', 'off');

                            etOverlapY.HeightLimits = [30 30];
                            etOverlapY.WidthLimits = [75 75];

                        overlapFlow.HeightLimits = [30 30];
                        overlapFlow.WidthLimits = [300 300];
                        
                        %% Resolution
                        resFlow = most.gui.uiflowcontainer('Parent', xyFlow, 'FlowDirection', 'LeftToRight');
                            etTileResX = most.gui.uicontrol('Parent', resFlow, 'Style', 'edit', 'Bindings', {obj 'tileResX' 'value'});
                            
                            etTileResX.HeightLimits = [30 30];
                            etTileResX.WidthLimits = [75 75];
                            
                            etTileResY = most.gui.uicontrol('Parent', resFlow, 'Style', 'edit', 'Bindings', {obj 'tileResY' 'value'});
                            
                            etTileResY.HeightLimits = [30 30];
                            etTileResY.WidthLimits = [75 75];
                            
                        resFlow.HeightLimits = [30 30];
                        resFlow.WidthLimits = [300 300];
                        
                    xyFlow.WidthLimits = [160 160];

            %% Z Range
            zFlow = most.gui.uiflowcontainer('Parent', mainFlow, 'FlowDirection', 'LeftToRight');
                symmetryTxt = uicontrol('Parent', zFlow, 'Style', 'text', 'String', 'Symmetric?');
                symmetryTxt.WidthLimits = [60 60];
                
                cbSymmetry = uicontrol('Parent', zFlow, 'Style', 'checkbox', 'Value', obj.tfSymmetricExpanse,'Callback', @setSymmetryTF);
                cbSymmetry.WidthLimits = [25 25];
                cbSymmetry.HeightLimits = [20 20];
                
                zRangeTxt = uicontrol('Parent', zFlow, 'Style', 'text', 'String', 'Z Series(um):', 'Position', [10 45 70 20]);
                zRangeTxt.WidthLimits = [70 70];
                
                etZRange = uicontrol('Parent', zFlow, 'Style', 'edit', 'String', sprintf('%.3f', obj.hFig.UserData.currentZ), 'Position', [95 48 100 20], 'Callback', @setZRange);
                etZRange.HeightLimits = [30 30];
                etZRange.WidthLimits = [80 80];
                
            zFlow.HeightLimits = [40 40];
            zFlow.WidthLimits = [300 300];
                
            %% Enter
            enterFlow = most.gui.uiflowcontainer('Parent', mainFlow, 'FlowDirection', 'TopDown');
                pbAcceptCont = uicontrol('Parent', enterFlow, 'Style', 'pushbutton', 'String', 'Accept/Continue','Position', [8 10 100 30], 'Callback', @finish);
                pbAcceptCont.HeightLimits = [50 50];

                pbCancel = uicontrol('Parent', enterFlow, 'Style', 'pushbutton', 'String', 'Cancel','Position', [135 10 60 30], 'Callback', @finish);
                pbCancel.HeightLimits = [50 50];
                
            enterFlow.HeightLimits = [110 110];
            
            uiwait(dlg);
            
            %%
            function setZRange(src, evt)
                obj.zRange = str2num(src.String);
            end

            function finish(src, evt)
                if strcmp(src.String, 'Cancel')
                    tileParams = {};
                    delete(obj.phantomTiles);
                else
                    
                    samplePoints = obj.tilePositions;
                    cornerPts = obj.generateCornerPoints(samplePoints, [obj.tileSizeX obj.tileSizeY]);
                    tileParams = {samplePoints, cornerPts};
                end
                delete(gcf);
            end
            
            function closeFcn(src, evt)
                tileParams = {};
                delete(gcf);
            end
            
            function setCenterX(src, evt)
                val = str2num(src.String);
                obj.tilingCenterX = val;
                
                obj.updateInitTile();
                obj.updatePhantomOutlines();
            end
            
            function setCenterY(src, evt)
                val = str2num(src.String);
                obj.tilingCenterY = val;
                % Fire prop set fcn
                obj.updateInitTile();
                obj.updatePhantomOutlines();
            end
            
            function setSizeX(src, evt)
                val = str2num(src.String);
                maxSz = obj.getAbsMaxScanTileSize;
                if val > maxSz(1)
                    obj.tileSizeX = maxSz(1);
                    src.String = num2str(maxSz(1));
                else
                    obj.tileSizeX = val;
                end
                
                obj.updateInitTile();
                obj.updatePhantomOutlines();
                
                overlapX = obj.getTileOverlapX();
                etOverlapX.String = sprintf('%.2f', overlapX);
            end
            
            function setSizeY(src, evt)
                val = str2num(src.String);
                maxSz = obj.getAbsMaxScanTileSize;
                if val > maxSz(2)
                    obj.tileSizeY = maxSz(2);
                    src.String = num2str(maxSz(2));
                else
                    obj.tileSizeY = val;
                end
                
                obj.updateInitTile();
                obj.updatePhantomOutlines();
                
                overlapY = obj.getTileOverlapY();
                etOverlapY.String = sprintf('%.2f', overlapY);
            end
            
            function setTileQuantX(src, evt)
                val = str2num(src.String);
                obj.numTilesX = round(val);
                src.String = num2str(obj.numTilesX);
                
                obj.updateInitTile();
                obj.updatePhantomOutlines();
            end
            
            function setTileQuantY(src, evt)
                val = str2num(src.String);
                obj.numTilesY = round(val);
                src.String = num2str(obj.numTilesY);
                
                obj.updateInitTile();
                obj.updatePhantomOutlines();
            end
            
            function setTileDistX(src, evt)
                val = str2num(src.String);
                obj.tileDistX = val; 
               
                obj.updateInitTile();
                obj.updatePhantomOutlines();
                
                overlapX = obj.getTileOverlapX();
                etOverlapX.String = sprintf('%.2f', overlapX);
            end
            
            function setTileDistY(src, evt)
                val = str2num(src.String);
                obj.tileDistY = val;
                
                obj.updateInitTile();
                obj.updatePhantomOutlines();
                
                overlapY = obj.getTileOverlapY();
                etOverlapY.String = sprintf('%.2f', overlapY);
            end
            
            function setSymmetryTF(src, evt)
                val = src.Value;
                obj.tfSymmetricExpanse = val;
                
                obj.updateInitTile();
                obj.updatePhantomOutlines();
            end

        end
        
        function cornerPts = generateCornerPoints(obj, centerPts, tileSizes)
                cp_ = {};
                for i = 1:numel(centerPts)
                    curPt = centerPts{i};
                    
                    X = tileSizes(1)/2;
                    Y = tileSizes(2)/2;
                    
                    TL = [curPt(1) - X curPt(2) - Y];
                    TR = [curPt(1) + X curPt(2) - Y];
                    BR = [curPt(1) + X curPt(2) + Y];
                    BL = [curPt(1) - X curPt(2) + Y];
                    
                    cp_{i} = [TL; TR; BR; BL];
                end
                
                cornerPts = cp_;
            end
        
        function overlapX = getTileOverlapX(obj)
            if abs(obj.tileDistX) >= obj.tileSizeX
                overlapX = 0;
            else
                overlapX = ((obj.tileSizeX - abs(obj.tileDistX))/obj.tileSizeX)*100;
            end
        end
        
        function overlapY = getTileOverlapY(obj)
            if abs(obj.tileDistY) >= obj.tileSizeY
                overlapY = 0;
            else
                overlapY = ((obj.tileSizeY - abs(obj.tileDistY))/obj.tileSizeY)*100;
            end
        end
        
        function AbsMaxSize = getAbsMaxScanTileSize(obj)
            % Max Tile Size
            cp = obj.hSI.hScan2D.fovCornerPoints; % Need to deal with resonant FOV extended mode, remove addition of X Galvo range...
            cp(:,3) = 0;
            cp = scanimage.mroi.coordinates.Points(obj.hSI.hCoordinateSystems.hCSReference,cp);
            cpUm = cp.transform(obj.hSI.hMotors.hCSAlignment);
            cpUm = cpUm.points;
            cpUm(:,3) = [];
            AbsMaxSize = [(abs(cpUm(1,1))*2)*obj.hSI.hScan2D.fillFractionSpatial abs(cpUm(1,2))*2]; 
        end
        
        function tile = makeScanTile(obj, hSI, tileCenter, tileCornerPts, zPos, channel, XYRes)
            hCoordinateSystems = hSI.hCoordinateSystems;
            sizeX = tileCornerPts(2,1) - tileCornerPts(1,1);
            sizeY = tileCornerPts(4,2) - tileCornerPts(1,2);
            tileSize = [sizeX sizeY];
            imageData = [];
            
            tileParams = {tileCenter, tileSize, zPos, channel, XYRes, imageData};
            
            tile = scanimage.components.tileTools.tileGeneratorFcns.defaultTileGenerator(hCoordinateSystems, false, tileParams, []);
        end
    end
    
end

function pt = getPointerLocation(hAx)
    pt = hAx.CurrentPoint(1, 1:2);
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
