function tiles = defaultTileGenerator(hCoordinateSystem, tfInMemory, tileParams, extraParams)
    % Usage: Generates Tile objects from either user specified parameters or
    % from roiData objects.
    %
    % Tile params should be arranged as such {tileCenter, tileSize, zPos, channel, imageData}
    % Tile params will checked to see if they are roiData objects
    assert(isa(hCoordinateSystem, 'scanimage.components.CoordinateSystems'), 'Param 1 is not a valid coordinate system');
    assert(iscell(tileParams), 'Tile params must be a cell array of either roiData objects or tile parameters: centerXY, sizeXY, Z, channel, resolution, imageData(*optional)');
    
    
    if nargin<4||isempty(extraParams)
        rollingAvgFactor = 1;
        availableChannels = 4;
        
    else
        assert(iscell(extraParams), 'Extra parameters must be in a cell array. Valid extra params are: {rollingAvgFactor, maxChansAvail}.');
        rollingAvgFactor = extraParams{1};
        if numel(extraParams)>=2
            availableChannels = extraParams{2};
        end
    end
    
    tfRoiData = most.util.cellArrayClassUniformity(tileParams, 'scanimage.mroi.RoiData');
    
    if tfRoiData
        makeTileFromRoiData();
    else
        makeTileFromToolParameters();
    end
    
    %%% Nested functions
    function makeTileFromRoiData()
        roiData = tileParams;
        tiles = scanimage.components.tiles.tile.empty(0,1);
        for roiNum = 1:numel(roiData)

            if iscell(roiData)
                roiData_ = roiData{roiNum};
            else
                roiData_ = roiData(roiNum);
            end

            chans = roiData_.channels;
            imageData = roiData_.imageData;

            assert(numel(chans) == numel(imageData), 'Numberof ROI Channels and Image Data Channels Do NOT Match');

            roiChansAvail = 1:max(chans);

            maxChansAvailable = availableChannels;

            if max(chans) < maxChansAvailable
                chansAvail = [roiChansAvail max(chans)+1:maxChansAvailable];
            else
                chansAvail = roiChansAvail;
            end

            missingChans = find(ismember(chansAvail, chans)==0);
            % Insert empties for missing channels. 
            for i = 1:numel(missingChans)
                missingChan = missingChans(i);
                imageData = {imageData{1:missingChan-1}, {[]}, imageData{missingChan:end}};
            end

            zs = roiData_.zs;

            for zIdx = 1:numel(zs)
                scanfield = roiData_.hRoi.get(roiData_.zs(zIdx));
                imData = cell(1,numel(imageData));

                % Get Image data for all channels but only for this Z.
                % Ignore if imData empty for this channel, i.e. this
                % channel was not imaged for the ROI. 
                for chanIdx = 1:numel(chansAvail)
                    % Make sure its a channel we imaged
                     if ~isempty(imageData{chanIdx})
                         % Make sure we imaged this Z
                         if ~isempty(imageData{chanIdx}{zIdx})
                            imData{chanIdx} = imageData{chanIdx}{zIdx};
                         end
                     end
                end
                
                [samplePoint, cornerPoints] = scanimage.components.tileTools.tileGeneratorFcns.makeTilePoints(hCoordinateSystem,scanfield, []); % Z Set from transform, roiData Z value does not update during acquisition (Focus)
                
                tiles(end+1) = scanimage.components.tiles.tile.generateTile(tfInMemory, samplePoint, cornerPoints, scanfield.affine, chansAvail, imData, scanfield.pixelResolutionXY, rollingAvgFactor);
            end
        end
    end
    
    function makeTileFromToolParameters()
        if numel(tileParams) < 6 || isempty(tileParams{6})
            imageData = [];
        else
            imageData = tileParams{6};
        end
        
        assert(numel(tileParams)>=5, 'Missing Tile Params. Required Params are: centerXY, sizeXY, Z, chan');
        
        tileCenter = tileParams{1};
        assert(isnumeric(tileCenter) && isrow(tileCenter) && numel(tileCenter)==2, 'Param 1 is not a valid [X Y] Center');
        
        tileSize = tileParams{2};
        assert(isnumeric(tileSize) && isrow(tileSize) && numel(tileSize)==2, 'Param 2 is not a valid [X Y] Size');
        
        zPos = tileParams{3};
        assert(isnumeric(zPos)&&~isnan(zPos)&&~isinf(zPos), 'Param 3 is not a valid Z pos');
        
        chans = tileParams{4};
        assert(isnumeric(chans)&&all(chans>=1), 'Param 4 is not a valid channel or channel array');
        
        XYRes = tileParams{5};
         assert(isnumeric(XYRes)&&numel(XYRes)==2, 'Param 5 is not a valid X-Y Resolution');
        
        
        % Create Tile Corner Points in um from tileSize
        
        centerX = tileCenter(1);
        centerY = tileCenter(2);
        
        TL = [ (centerX-(tileSize(1)/2)), (centerY-(tileSize(2)/2))];
        TR = [ (centerX+(tileSize(1)/2)), (centerY-(tileSize(2)/2))];
        BR = [ (centerX+(tileSize(1)/2)), (centerY+(tileSize(2)/2))];
        BL = [ (centerX-(tileSize(1)/2)), (centerY+(tileSize(2)/2))];
        
        tileCornerPts = [TL;TR;BR;BL];                      
        
        % Convert cornerPts to scan anlges
        cp = tileCornerPts;
        cp(:,3) = 0;
        cp = scanimage.mroi.coordinates.Points(hCoordinateSystem.hCSSampleRelative, cp);
        cp = cp.transform(hCoordinateSystem.hCSReference);
        cp = cp.points;
        cp(:,3) = [];

        % Convert size to scan angles
        sizeXY = [abs(cp(1,1) - cp(2,1)) abs(cp(1,2) - cp(4,2))];

%         % Convert center to scan angles
%         centerPt = [tileCenter zPos];
%         centerPt = scanimage.mroi.coordinates.Points(hCoordinateSystem.hCSSampleRelative, centerPt);
%         centerPt = centerPt.transform(hCoordinateSystem.hCSReference);
%         centerPt = centerPt.points;
%         centerPt(:,3) = [];

        % Create Scanfield
        sf = scanimage.mroi.scanfield.fields.RotatedRectangle();
        sf.centerXY = [0,0]; % This needs to shift to 0,0 for scanning but needs to be unshifted here so the sample point will be correct
        sf.sizeXY = sizeXY;
        sf.pixelResolutionXY = XYRes;
        
        % Get the affine without creating the scanfield
        tiles = scanimage.components.tiles.tile.generateTile(tfInMemory, [tileCenter zPos], tileCornerPts, sf.affine, chans, imageData, XYRes, rollingAvgFactor);
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
