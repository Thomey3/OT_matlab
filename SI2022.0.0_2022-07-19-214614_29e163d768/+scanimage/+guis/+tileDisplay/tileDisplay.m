classdef tileDisplay < handle
    
    properties
        hTileView;                                           % Handle to TileView class which managers display objects
        
        hAx;                                                 % Handle to the TileView Main display Axes
        hParent;
        hSurf = matlab.graphics.primitive.Surface.empty;     % Surface Object for rendering the Tile
        hSurfContextMenu;                                    % Context Menu for the Surface
        hZprojectionLine;                                    % Z Projection Line indicating the Tiles current Z location in the TileView Z Projection
        
        tileColor;                                           % Color outline for the Surface.
        hListeners = event.listener.empty(0,1);              % Array of Listeners for the Display object.
        projectionLineVisible = true;                        % (Set Only) Draws Z projection based on Tile Show/Hide in TileView
    end
    
    properties(SetObservable)
        hTile;                                               % Handle to the tile object being displayed
        LodLvl = 1;
        
    end
    
    properties(Hidden)
        rmTileMenuOption;
        hSz;
        hCenter;
    end
    
    properties (SetAccess = immutable)
        hTileUuiduint64;
    end
    
    methods
        function obj = tileDisplay(hTileView,hTile,hParent,tileColor)
            obj.hTileView = hTileView;
            obj.hTile = hTile;
            obj.hTileUuiduint64 = hTile.uuiduint64;
            obj.tileColor = tileColor;
            
            obj.hParent = hParent;
            obj.hAx = ancestor(hParent,'axes');
            hFig = ancestor(hParent,'figure');
            obj.hSurfContextMenu = uicontextmenu('Parent',hFig);
            
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hTile, 'ObjectBeingDestroyed', @(varargin)obj.delete);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hAx,   'ObjectBeingDestroyed', @(varargin)obj.delete);
            
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hTileView, 'hFOV_XYLim', 'PostSet', @(varargin)obj.XYLimitChanged);
            % IF
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hTileView, 'hFOV_ZLim', 'PostSet', @(varargin)obj.drawTile);
            % HOW
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hTile, 'hImgPyramid', 'PostSet', @(varargin)obj.refreshImg);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hTile, 'imageData', 'PostSet', @(varargin)obj.refreshImg);
            
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hTileView.hModel.hChannels, 'channelLUT', 'PostSet', @(varargin)obj.refreshImg);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj, 'hTile', 'PostSet', @(varargin)obj.refreshImg);
            
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hTile, 'samplePoint', 'PostSet', @(varargin)obj.updateSurface);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hTile, 'tileCornerPts', 'PostSet', @(varargin)obj.updateSurface);
            
            obj.hZprojectionLine = line([0 1],[0 0],'color', obj.tileColor,'parent',obj.hTileView.hZAxes,'linewidth',3, 'YData', [obj.hTile.zPos obj.hTile.zPos]);
            
            if verLessThan('matlab','9.8')
                obj.hSurfContextMenu.Callback = @obj.updateContextMenu;
            else
                obj.hSurfContextMenu.ContextMenuOpeningFcn = @obj.updateContextMenu;
            end
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hListeners);
            most.idioms.safeDeleteObj(obj.hSurf);
            most.idioms.safeDeleteObj(obj.hSurfContextMenu);
            most.idioms.safeDeleteObj(obj.hZprojectionLine);
        end
    end
    
    methods
        function updateContextMenu(obj,src,evt)
            % Tile Info
            delete(src.Children);
            src.Children = [];
            
            obj.hSz = uimenu('Parent',src,'Label',sprintf('Tile Size: [%.2f %.2f]', obj.hTile.tileSize(1), obj.hTile.tileSize(2)));
            obj.hCenter = uimenu('Parent',src,'Label',sprintf('Tile Center: [%.2f %.2f]',obj.hTile.samplePoint(1), obj.hTile.samplePoint(2)));
            uimenu('Parent',src,'Label',sprintf('Tile Id: %s', obj.hTile.uuid));
            
            % Spatial Actions
            uimenu('Parent',src,'Label','Center on Tile','Separator', 'on', 'Callback',@(varargin)obj.center);
            uimenu('Parent',src,'Label','Move Stage Here','Callback',@(varargin)obj.gotoPosition);
            uimenu('Parent',src,'Label','Save this Position','Callback',@(src,evt, varargin)obj.hTileView.savePosition(src, evt, obj.hTile.samplePoint));
            
            % Tile Actions
            obj.rmTileMenuOption = uimenu('Parent',src,'Label','Remove Tile','Separator', 'on','Callback',@(varargin)most.idioms.safeDeleteObj(obj.hTile));
        end
        
        % Tile Size and Render
        function tf = getInAxesLim(obj)
            pts = obj.hTile.tileCornerPts;
            hFOV_XYLim = obj.hTileView.hFOV_XYLim;
            
            ptInX = pts(:,1) > hFOV_XYLim(1,1) & pts(:,1) < hFOV_XYLim(1,2);
            ptInY = pts(:,2) > hFOV_XYLim(2,1) & pts(:,2) < hFOV_XYLim(2,2);
            ptsSpanXFov = any(pts(:,1) < hFOV_XYLim(1,1)) && any(pts(:,1) > hFOV_XYLim(1,2));
            ptsSpanYFov = any(pts(:,2) < hFOV_XYLim(2,1)) && any(pts(:,2) > hFOV_XYLim(2,2));
            
            tf = any(ptInX & ptInY)      ...
                || (ptsSpanXFov && any(ptInY)) ...
                || (ptsSpanYFov && any(ptInX)) ...
                || (ptsSpanXFov && ptsSpanYFov);
        end
        
        function XYLimitChanged(obj)
            if ~obj.hTile.tfInMemory
                obj.updateLodLevel();
            end
            obj.drawTile();
        end
        
        function updateLodLevel(obj)
            tileRes = obj.getTileResolution();
            newLvl = obj.getTileLodLvl(tileRes);
            if ~isequal(newLvl, obj.LodLvl)
                obj.LodLvl = newLvl;
                obj.refreshImg();
            end
            
        end
        
        function tileRes = getTileResolution(obj)
            tileSize = obj.hTile.tileSize;
            tileWidthUm  = tileSize(1);
            tileHeightUm = tileSize(2);
            
            hFOV_AxPos = obj.hTileView.hFOV_AxPos;
            FovWidthPixels  = hFOV_AxPos(3);
            FovHeightPixels = hFOV_AxPos(4);
            
            hFOV_XYLim = obj.hTileView.hFOV_XYLim;
            FovHeightUm = diff(hFOV_XYLim(2,:));
            FovWidthUm  = diff(hFOV_XYLim(1,:));
            
            FovPixelPerUmX = FovWidthPixels/FovWidthUm;
            FovPixelPerUmY = FovHeightPixels/FovHeightUm;
            
            tileResX = FovPixelPerUmX*tileWidthUm;
            tileResY = FovPixelPerUmY*tileHeightUm;
            
            tileRes = [tileResX tileResY];
        end
        
        function lod = getTileLodLvl(obj, tileRes)
            if isempty(obj.hTile.hImgPyramid)
                lod = 1;
            else
                lod = max(arrayfun(@(x) x.determineLOD(tileRes), obj.hTile.hImgPyramid));
            end
        end
        
        % Tile Image Update
        function img = generateImg(obj, varargin)
            % Varargin entries should be image data in the order of
            % {img, color, LUT, alpha}
            img = single.empty();
            
            chanData = varargin{1};
            
            numChans = numel(chanData);
            
            for i = 1:numChans
                chan = chanData{i};
                image = chan{1};
                color = chan{2};
                
                if isempty(image)
                    continue;
                end
                
                if iscell(color)
                    color = color{1};
                end
                
                if ischar(color)
                    color = colorName2Rgb(color);
                end
                
                LUT = chan{3};
                alpha = chan{4};
                
                LUT = single(LUT);
                image = single(image);
                image = image - LUT(1);
                
                color = reshape(color,1,1,[]);
                color = color .* alpha ./ diff(LUT);
                
                color_uint8 = color * 255;
                
                image = image .* color_uint8;
                
                if isempty(img)
                    img = image;
                else
                    img = img + image;
                end
            end
            
            img = uint8(img);
            
            function rgb = colorName2Rgb(name)
                switch name
                    case {'red' 'Red'}
                        rgb = [1 0 0];
                    case {'green' 'Green'}
                        rgb = [0 1 0];
                        
                    case {'blue' 'Blue'}
                        rgb = [0 0 1];
                        
                    case {'grey' 'Grey'}
                        rgb = [1 1 1];
                        
                    otherwise
                        rgb = [0 0 0];
                end
            end
        end
        
        % Tile Navigation
        function center(obj)
            pt = obj.hTile.samplePoint;
            samplePosition = scanimage.mroi.coordinates.Points(obj.hTileView.hModel.hCoordinateSystems.hCSSampleRelative,pt);
            obj.hTileView.hModel.hMotors.movePtToPosition(obj.hTileView.hModel.hCoordinateSystems.focalPoint,samplePosition);
        end
        
        function gotoPosition(obj)
            obj.hTileView.gotoPosition();
        end
        
        % Visibility
        function set.projectionLineVisible(obj,val)
            if obj.projectionLineVisible ~= val
                if val
                    obj.hZprojectionLine.Visible = 'on';
                else
                    obj.hZprojectionLine.Visible = 'off';
                end
                
                obj.projectionLineVisible = val;
            end
        end
        
        function val = get.tileColor(obj)
            if strcmp(obj.tileColor, 'orange')
                obj.tileColor = [0.8500 0.3250 0.0980];
            else
                obj.tileColor = obj.tileColor;
            end
            val = obj.tileColor;
        end
        
        function hSurf = createSurfaceObject(obj,tileColor)
            if nargin < 2 || isempty(tileColor)
                tileColor = 'none';
            end
            
            cData = NaN;
            
            [xx,yy,zz] = obj.hTile.meshgrid();
            
            hSurf = surface('parent', obj.hParent,'xdata', xx', 'ydata', yy',...
                'zdata', zz', 'CData', cData, 'FaceColor', 'texturemap', 'FaceAlpha', .75,...
                'EdgeColor', tileColor, 'UIContextMenu',obj.hSurfContextMenu, 'ButtonDownFcn', @(src,evt)obj.hTileView.mainViewPan(src, evt));
            
        end
        
        function updateSurface(obj)
            % Don't update the surface if it does not exist but still
            % indicate its Z position via the meshgrid so you can find it
            % correctly
            [xx,yy,zz] = obj.hTile.meshgrid();
            if ~isempty(obj.hSurf)                
                obj.hSurf.XData = xx';
                obj.hSurf.YData = yy';
                obj.hSurf.ZData = zz';
            end
            [~,~,exponent] = most.idioms.engineersStyle(max(abs(obj.hTileView.zProjectionRange))*1e-6,'m');
            z_ = zz(1).*1e-6 ./ 10^exponent;
            
            obj.hZprojectionLine.YData = [z_ z_];
            obj.updateInfo();
        end
        
        % Menu Info
        function updateInfo(obj)
            obj.hSz.Label = sprintf('Tile Size: [%.2f %.2f]', obj.hTile.tileSize(1), obj.hTile.tileSize(2));
            obj.hCenter.Label = sprintf('Tile Center: [%.2f %.2f]',obj.hTile.samplePoint(1), obj.hTile.samplePoint(2));
        end
    end
    
    methods (Abstract)
        drawTile(obj,tfNoData);
        [tfRenderTile, tfShowZLine] = shouldShow(obj);
        refreshImg(obj,tfNoData)
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
