classdef tile < most.util.Uuid
    properties(SetObservable)
        hImgPyramid = scanimage.util.ImagePyramid.empty(0,1);
        resolutionXY = [];
        affine;             % The Affine matrix of the Tile's Scanfield
    end
    
    properties
        channels;
        displayAvgFactor = 1; 
    end
    
    properties(SetAccess=private)
       tfInMemory = false; 
    end
    
    properties (SetObservable)
        samplePoint;
        tileCornerPts;
        imageData;
    end
    
    properties (Dependent)
        tileSize;           % The Size[XY] of the Tile in microns - Dont make this dependent so you can update tile corner pts if sample pt changes
        zPos;
    end
    
    properties(Hidden)
        scannable = true;
    end
    
    properties (Hidden,Dependent)
        hCSSampleRelative;
        hCSReference;
    end
    
    methods
        function obj = tile(varargin)
            if ~isempty(varargin)
                obj = scanimage.components.tiles.tile.generateTile(varargin{:});
            end
        end
        
        function delete(obj)
           most.idioms.safeDeleteObj(obj.hImgPyramid);
        end
        
        function s=saveobj(obj)
            s = struct();
            s.samplePoint = obj.samplePoint;
            s.tileCornerPts = obj.tileCornerPts;
            s.resolutionXY = obj.resolutionXY;
            s.affine = obj.affine;
            s.channels = obj.channels;
            s.displayAvgFactor = obj.displayAvgFactor;
            s.imageData = obj.imageData;
            s.tfInMemory = obj.tfInMemory;
        end
    end
    
    methods (Static)
        function obj=loadobj(s)            
            obj = scanimage.components.tiles.tile.generateTile( ...
                 s.tfInMemory ...
                ,s.samplePoint ...
                ,s.tileCornerPts ...
                ,s.affine ...
                ,s.channels ...
                ,s.imageData ...
                ,s.resolutionXY ...
                ,s.displayAvgFactor);
        end
        
        function obj = generateTile(tfInMemory, samplePoint, cornerPoints, affine, channels, imData, resolutionXY, displayAvgFactor)
            obj = scanimage.components.tiles.tile();
            if nargin<8 || isempty(displayAvgFactor)
                obj.displayAvgFactor = 1;
            else
                obj.displayAvgFactor = displayAvgFactor;
            end
            
            obj.tfInMemory = tfInMemory;
            
            obj.affine = affine;
            obj.resolutionXY = resolutionXY;
            obj.channels = channels;
            
            obj.tileCornerPts = cornerPoints;
            obj.samplePoint = samplePoint;
            
            if nargin < 5 || isempty(imData)
                obj.hImgPyramid = scanimage.util.ImagePyramid.empty(0,max(channels));
            else
                obj.imageData = imData;
            end 
        end
    end
    
    % Set/Get Methods
    methods
        function move(obj,XYZ)
            validateattributes(newSamplePoint,{'numeric'},{'size',[1,3]});
            obj.tileCornerPts(:,1:2) = obj.tileCornerPts(:,1:2) + XYZ(:,1:2);
            obj.samplePoint = obj.samplePoint + XYZ;
        end
        
        function setNewSamplePoint(obj,newSamplePoint)
            validateattributes(newSamplePoint,{'numeric'},{'size',[1,3]});
            oldSamplePoint = obj.samplePoint;
            obj.samplePoint = newSamplePoint;
            obj.tileCornerPts = obj.tileCornerPts - oldSamplePoint(1:2) + newSamplePoint(1:2);
        end
        
        function val = get.zPos(obj)
            val = obj.samplePoint(3);
        end
        
        function val = get.tileSize(obj)
            sizeX = abs(obj.tileCornerPts(2,1) -  obj.tileCornerPts(1,1));
            
            sizeY = abs(obj.tileCornerPts(3,2) -  obj.tileCornerPts(1,2));
            
            val = [sizeX sizeY];
        end
        
        function set.samplePoint(obj,val)
            if isnumeric(val)
                % No-op
            elseif isa(val,'scanimage.mroi.coordinates.Points')
                hResourceStore = dabs.resources.ResourceStore();
                hSI = hResourceStore.filterByClass('scanimage.SI');
                hSI = hSI{1};
                val = val.transform(hSI.hCoordinateSystems.hCSSampleRelative);
                val = val.points;
            end
            
            validateattributes(val,{'numeric'},{'size',[1 3]});
            
            obj.samplePoint = val;
        end    
        
        function set.imageData(obj,val)
            % In some cases the data is a column not a row.
            if ~isrow(val)
                val = val';
            end
            
            % Val < num channels, padd val with empties. 
            if numel(val) < max(obj.channels)
                difChans = max(obj.channels) - numel(val);
                val = [val cell(1,difChans)];
            % If Val > num channels, update num channels.
            elseif numel(val) > max(obj.channels)
                obj.channels = [obj.channels max(obj.channels)+1:numel(val)];
            end
            
            if obj.tfInMemory
                obj.imageData = val;
            else
                most.idioms.safeDeleteObj(obj.hImgPyramid);
                
                obj.hImgPyramid = cellfun(@(x) scanimage.util.ImagePyramid(x), val); 
                
            end
        end
        
        function val = get.imageData(obj)
            if obj.tfInMemory
                val = obj.imageData;
            else
                if isempty(obj.hImgPyramid)
                    val = [];
                else
                    val = arrayfun(@(x) x.getLod(1), obj.hImgPyramid, 'UniformOutput', false);
                end                
            end
        end
    end
    
    % Utility
    methods        
        % This needs to exist to pin tiles to overview or make a scan tile out of an overview tile. 
        % Tile objects are non-specific and sorting dependns on adding to an array. If the same tile
        % exists in 2 arrays then deleting or manipulating the tile will effect both no?
        % Copying creates a unique tile object to avoid this. 
        function tile = copy(obj, tfInMemory)
            if nargin< 2 || isempty(tfInMemory)
                tfInMemory = obj.tfInMemory;
            end
            tile = scanimage.components.tiles.tile();
            
            tile.samplePoint = obj.samplePoint();
            tile.affine = obj.affine;
            tile.channels = obj.channels;
            
            tile.tileCornerPts = obj.tileCornerPts;
            
            tile.displayAvgFactor = obj.displayAvgFactor;
            
            tile.resolutionXY = obj.resolutionXY;
            
            tile.tfInMemory = tfInMemory;
            
            tile.imageData = obj.imageData;
        end
        
        function tf = isequalish(obj, tile)
            tfSamp = isequal(obj.samplePoint, tile.samplePoint);
            tfCorner = isequal(obj.tileCornerPts, tile.tileCornerPts);
            tfAffine = isequal(obj.affine, tile.affine);
            tfResolution =  isequal(obj.resolutionXY,tile.resolutionXY);
            
            tf = tfSamp && tfCorner && tfAffine && tfResolution;
        end
        
        function [xx,yy,zz] = meshgrid(obj)
            pts = obj.tileCornerPts;
            pts = pts([1 2 4 3],:);
            pts(:,3) = obj.samplePoint(3);
               
            xx = pts(:,1);
            yy = pts(:,2);
            zz = pts(:,3);
            
            xx = reshape(xx,2,2)';
            yy = reshape(yy,2,2)';
            zz = reshape(zz,2,2)';
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
