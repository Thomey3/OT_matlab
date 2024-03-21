classdef overviewTileDisplay < scanimage.guis.tileDisplay.tileDisplay
    
   methods
       function obj = overviewTileDisplay(hTile,hAx,tileColor,hTileView)
           obj@scanimage.guis.tileDisplay.tileDisplay(hTileView,hTile,hAx,tileColor);
                      
           obj.hListeners(end+1) = addlistener(obj.hTileView, 'overviewTileColor', 'PostSet', @(varargin)obj.drawTile);
           obj.hListeners(end+1) = addlistener(obj.hTileView, 'overviewTileShowHideTf', 'PostSet', @(varargin)obj.drawTile);
           
           obj.hListeners(end+1) = addlistener(obj.hTileView, 'overviewChansToShow', 'PostSet', @(varargin)obj.refreshImg);
           obj.hListeners(end+1) = addlistener(obj.hTileView, 'overviewChanImageColors', 'PostSet', @(varargin)obj.refreshImg);
           obj.hListeners(end+1) = addlistener(obj.hTileView, 'overviewChanAlphas', 'PostSet', @(varargin)obj.refreshImg);
           
           % "Make Scan Tile Here" function
           uimenu('Parent',obj.hSurfContextMenu,'Label','Make Scan Tile Here','Callback',@(varargin)obj.makeScanTile);
           
           uimenu('Parent',obj.hSurfContextMenu,'Label','Rebase Coordinates to this Tile','Callback',@(varargin)obj.updateCurrentPosition);
           
           obj.hSurf = obj.createSurfaceObject(obj.tileColor);
           obj.drawTile();
       end
       
   end
   
   methods
       function hSurf = createSurfaceObject(obj,tileColor)
           hSurf = createSurfaceObject@scanimage.guis.tileDisplay.tileDisplay(obj,tileColor);
       end
       
       % Render Surface
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
           
           [tfRenderTile, tfShowZLine] = obj.shouldShow();
           
           if tfRenderTile || tfShowZLine
               obj.tileColor = obj.hTileView.overviewTileColor;
           end
           
           if tfShowZLine
               obj.hZprojectionLine.Color = obj.tileColor;
               obj.hZprojectionLine.Visible = 'on';
           else
               obj.hZprojectionLine.Visible = 'off';
           end
                      
           if tfRenderTile
               if isempty(obj.hSurf)
                   obj.hSurf = obj.createSurfaceObject(obj.tileColor);
               end               
               obj.hSurf.EdgeColor = obj.tileColor;
               
               
               if isempty(obj.hSurf.CData) || (numel(obj.hSurf.CData)==1 && isnan(obj.hSurf.CData))
                   obj.refreshImg();
               end
               
           else
               delete(obj.hSurf);
               obj.hSurf = matlab.graphics.primitive.Surface.empty;
           end
           
       end
       
       function [tfRenderTile, tfShowZLine] = shouldShow(obj)
           % This is just if this channel is displayed, might change later.
           tfShowZLine = obj.hTileView.overviewTileShowHideTf;
           
           tfSameZPlane = obj.hTile.zPos == obj.hTileView.currentZ;
           
           tfRenderTile = obj.getInAxesLim() && tfSameZPlane && tfShowZLine;
       end
       
       function makeScanTile(obj)
           hTile = obj.hTile.copy(false);
           % Empty the image data on conversion.
           hTile.imageData = [];
           obj.hTileView.hModel.hTileManager.addScanTile(hTile);
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
              chanData = cell(1,numel(obj.hTileView.overviewChansToShow));

              for idx = 1:numel(obj.hTileView.overviewChansToShow)
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
                  
                  
                 if obj.hTileView.overviewChansToShow(idx)
                      color = obj.hTileView.overviewChanImageColors(idx);
                      alpha = obj.hTileView.overviewChanAlphas(idx);
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
                  obj.hSurf.FaceAlpha = 0;
              else
                  obj.hSurf.CData = CData;
                  obj.hSurf.FaceAlpha = 0.75;
              end
              
            end
       end
       
       % Update Tile sample point
       function updateCurrentPosition(obj)
           hResourceStore = dabs.resources.ResourceStore();
           hSI = hResourceStore.filterByClass('scanimage.SI');
           hSI = hSI{1};
           hFocalPt = scanimage.mroi.coordinates.Points(hSI.hCoordinateSystems.hCSFocus,[0,0,0]);
           hFocalPt = hFocalPt.transform(hSI.hCoordinateSystems.hCSReference);
           focalPtRef = hFocalPt.points;
           
           newZeroRefPt = obj.hTile.samplePoint - focalPtRef;
           
           hSI.hMotors.setRelativeZero(newZeroRefPt);
       end
       
       function updateContextMenu(obj,src,evt)
           obj.updateContextMenu@scanimage.guis.tileDisplay.tileDisplay(src,evt);          
           uimenu('Parent',src,'Label','Make Scan Tile Here','Callback',@(varargin)obj.makeScanTile);
           uimenu('Parent',src,'Label','Rebase Coordinates to this Tile','Callback',@(varargin)obj.updateCurrentPosition);
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
