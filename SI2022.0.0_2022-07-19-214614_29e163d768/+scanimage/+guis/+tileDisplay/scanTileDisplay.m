classdef scanTileDisplay < scanimage.guis.tileDisplay.tileDisplay
    
   methods
       function obj = scanTileDisplay(hTile,hAx,tileColor,hTileView)
           if ~strcmp(tileColor, 'orange')
               tileColor = 'orange';
           end
           
           obj@scanimage.guis.tileDisplay.tileDisplay(hTileView,hTile,hAx,tileColor);
           
           % Scan Tile Specific Listeners
           obj.hListeners(end+1) = addlistener(obj.hTileView, 'scanChansToShow', 'PostSet', @(varargin)obj.refreshImg);
           obj.hListeners(end+1) = addlistener(obj.hTileView, 'scanChanImageColors', 'PostSet', @(varargin)obj.refreshImg);
           obj.hListeners(end+1) = addlistener(obj.hTileView, 'scanChanAlphas', 'PostSet', @(varargin)obj.refreshImg);
           
           obj.hListeners(end+1) = addlistener(obj.hTileView, 'scanTileShowHideTf', 'PostSet', @(varargin)obj.drawTile);
           obj.hListeners(end+1) = addlistener(obj.hTileView, 'currentZ', 'PostSet', @(varargin)obj.drawTile);
           
           obj.hSurf = obj.createSurfaceObject(obj.tileColor);
           obj.drawTile(true);
       end
   end
   
   methods
       
       function hSurf = createSurfaceObject(obj,tileColor)
           hSurf = createSurfaceObject@scanimage.guis.tileDisplay.tileDisplay(obj,tileColor);
           hSurf.LineStyle = '--';
       end
       
       % Updates CData with Image Data
       function drawTile(obj,tfNoData)
           if nargin < 2 || isempty(tfNoData)
               if obj.hTile.tfInMemory
                   if isempty(obj.hTile.imageData)
                       tfNoData = true;
                   else
                       tfNoData = false;
                   end
               else
                   if isempty(obj.hTile.hImgPyramid)
                       tfNoData = true;
                   else
                       tfNoData = false;
                   end
               end
           end
           
           [tfRenderTile,tfShowZLine] = obj.shouldShow();
           
           obj.projectionLineVisible = tfShowZLine;
           
           if tfRenderTile
               if isempty(obj.hSurf)
                   obj.hSurf = obj.createSurfaceObject(obj.tileColor);
               end
               
               CData = obj.hSurf.CData;
               if isempty(CData) || (numel(CData)==1 && isnan(CData))
                   if tfNoData
                       obj.refreshImg(true);
                   else
                       obj.refreshImg(false);
                   end
               end
                                             
           elseif ~isempty(obj.hSurf)
               delete(obj.hSurf);
               obj.hSurf = matlab.graphics.primitive.Surface.empty();
           end
       end
       
       function [tfRenderTile, tfShowZLine] = shouldShow(obj)
           tfShowZLine = obj.hTileView.scanTileShowHideTf;
           tfSameZ = obj.hTile.zPos == obj.hTileView.currentZ;
           tfRenderTile = tfShowZLine && tfSameZ && obj.getInAxesLim();
       end 
       
       % Add Acquired data and tile to overview
       function addToOverview(obj)
           if isempty(obj.hTile.imageData) || all(cellfun(@(x) isempty(x), obj.hTile.imageData)) 
               warning('Can''t Pin Tile to Overview. Tile is empty.');
           else
               tile = obj.hTile.copy();
               obj.hTileView.hModel.hTileManager.addOverviewTile(tile);
           end
       end
       
       function refreshImg(obj,tfNoData)
           if ~most.idioms.isValidObj(obj.hSurf)
               return;
           end
           
            if nargin < 2 || isempty(tfNoData)
               tfNoData = false;
            end

            if tfNoData
              obj.hSurf.CData = [0 0; 0 0];
              obj.hSurf.FaceAlpha = 0;
            else
              chanData = cell(1,numel(obj.hTileView.scanChansToShow));

              for idx = 1:numel(obj.hTileView.scanChansToShow)
                  if obj.hTile.tfInMemory
                      if ~isempty(obj.hTile.imageData) && numel(obj.hTile.imageData)>=idx
                          img = obj.hTile.imageData{idx}./obj.hTile.displayAvgFactor;%obj.hTileView.hModel.hDisplay.displayRollingAverageFactor;
                      else
                          img = [];
                      end
                  else
                      if ~isempty(obj.hTile.hImgPyramid) && numel(obj.hTile.hImgPyramid)>=idx
                          img = obj.hTile.hImgPyramid(idx).getLod(obj.LodLvl)./obj.hTile.displayAvgFactor;%obj.hTileView.hModel.hDisplay.displayRollingAverageFactor;
                      else
                          img = [];
                      end
                  end
                  
                 if obj.hTileView.scanChansToShow(idx)
                      color = obj.hTileView.scanChanImageColors(idx);
                      alpha = obj.hTileView.scanChanAlphas(idx);
                      LUT = obj.hTileView.hModel.hChannels.channelLUT{idx};

                      chDat = {img, color, LUT, alpha};

                 else
                      color = [0 0 0];
                      LUT = obj.hTileView.hModel.hChannels.channelLUT{idx};
                      alpha = 0;

                      chDat = {img, color, LUT, alpha};
                  end
                  chanData{idx} = chDat;
              end

              % Do a "should refresh"
              CData = obj.generateImg(chanData);
              
              if isempty(CData)
                  CData = [0 0; 0 0];
                  obj.hSurf.CData = CData;
                  obj.hSurf.FaceAlpha = 0;
              else
                  obj.hSurf.CData = CData;
                  obj.hSurf.FaceAlpha = 0.75;
              end

            end
       end
       
       function updateContextMenu(obj,src,evt)
           obj.updateContextMenu@scanimage.guis.tileDisplay.tileDisplay(src,evt);          
           uimenu('Parent',src,'Label','Add to Overview','Callback',@(varargin)obj.addToOverview);
%            uimenu('Parent', src, 'Label', 'Toggle Scannable', 'Callback', @obj.toggleScannable)
       end
       
       % Potentially useful as added control over what should get scanned. 
%        function toggleScannable(obj)
%            obj.hTile.scannable = ~obj.hTile.scannable;
%            
%        end
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
