function pathIdxs = naiveNearestZ(startIdx, hTiles)
    
    tilesInPath = pathEvaluation(startIdx, hTiles);
    pathIdxs = arrayfun(@(x) findThisTilesIdx(x, hTiles), tilesInPath);
end

function paths = pathEvaluation(startIdx, hTiles)

    % Define empty output
    paths = scanimage.components.tiles.tile.empty(0,1);

    % Copy of tiles array. Will empty out as tiles are added to the path
    unprocessedTilesArray = hTiles;
    
    % Tiles added to path - indices sorted later
    tilesPath = scanimage.components.tiles.tile.empty(0,1);
    
    % This will increment as we move to new tiles
    currentTileIdx = startIdx;
    
    % Current Tile
    thisTile = unprocessedTilesArray(currentTileIdx);
    unprocessedTilesArray(currentTileIdx) = [];
    tilesPath = [tilesPath thisTile];
        
    % Find all tiles with the same XY coordinates
    tfIdx = arrayfun(@(x) sameXY(thisTile, x), unprocessedTilesArray);
    tilesSameXY = unprocessedTilesArray(tfIdx);
    
%     % Sort them by Z
%     tilesSameXY_ZSorted = sortTilesByZ(tilesSameXY);
    
    % Get the indices of these tiles, which have the same XY but different
    % Z's, from the unprocessed array
    inds = arrayfun(@(x) findThisTilesIdx(x, unprocessedTilesArray), tilesSameXY);
    
    % Add these tiles to the path in their Z order, and remove them from
    % them unprocessed array
    tilesPath = [tilesPath tilesSameXY];
    tilesPath = sortTilesByZ(tilesPath);
    unprocessedTilesArray(inds) = [];
    
    paths = [paths tilesPath];
    
    % Then move to the next closest Tile in XY prioritizing Y and repeat
    
    if isempty(unprocessedTilesArray)
       return; 
    end
    
    
    % Find the tile(s) on this Z plane that is closest in X and Y
    closestTile = getClosestTileIdxXY(thisTile, unprocessedTilesArray);
    
    if ~isempty(unprocessedTilesArray)
        closestTileIdx = findThisTilesIdx(closestTile, unprocessedTilesArray);
        paths = [paths pathEvaluation(closestTileIdx, unprocessedTilesArray)];
    end
            
end
    
function closestTile = getClosestTileIdxXY(thisTile, tilesArray)
    try
        thisPoint = thisTile.samplePoint;
        
        tilesAtSameZ = tilesArray([tilesArray.zPos] == thisTile.zPos);
        
        if ~isempty(tilesAtSameZ)
            tlAry = tilesAtSameZ;
        else
            % No other tiles at this Z plane. 
            tlAry = tilesArray;
        end

        pointDistances = arrayfun(@(x)norm(x.samplePoint-thisPoint),tlAry);
        minPointDistance = min(pointDistances);
        
        tolerance_um = 1e-3;
        closestTileIdxs = (pointDistances-minPointDistance) < tolerance_um;     
        closestTiles = tlAry(closestTileIdxs);
        
        yDistances = arrayfun(@(x)abs(x.samplePoint(2)-thisPoint(2)),closestTiles);    
        [~,idx] = min(yDistances);

        closestTile = closestTiles(idx);
    catch ME
        most.ErrorHandler.logAndReportError(ME);
    end
end

function tf = sameXY(tileA,tileB)
    tf = false;
    
    sameX = tileA.samplePoint(1) == tileB.samplePoint(1);
    sameY = tileA.samplePoint(2) == tileB.samplePoint(2);
    
    tf = sameX && sameY;
end

function zSortedTiles = sortTilesByZ(unsortedTilesArray)
    zSortedTiles = scanimage.components.tiles.tile.empty(0,1);
    
    % Unique also sorts from smallest to largest
    uniqueZPlanes = unique(arrayfun(@(x) x.zPos, unsortedTilesArray));
    
    for zIdx = 1:numel(uniqueZPlanes)
        zVal = uniqueZPlanes(zIdx);
        zSortedTiles = [zSortedTiles unsortedTilesArray([unsortedTilesArray.zPos] == zVal)];
    end
end

function idx = findThisTilesIdx(thisTile, tilesArray)
        try
            for t = 1:numel(tilesArray)
                if strcmp(tilesArray(t).uuid, thisTile.uuid)
                    idx = t;
                    return;
                end
            end
        catch ME
            most.ErrorHandler.logAndReportError(ME);
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
