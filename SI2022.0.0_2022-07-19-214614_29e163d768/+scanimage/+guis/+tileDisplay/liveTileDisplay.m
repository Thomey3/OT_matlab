classdef liveTileDisplay < scanimage.guis.tileDisplay.overviewTileDisplay
    methods
        function obj = liveTileDisplay(hTile,hAx,tileColor,hTileView)
            obj@scanimage.guis.tileDisplay.overviewTileDisplay(hTile,hAx,tileColor,hTileView);
                       
            obj.hListeners(end+1) = addlistener(obj.hTileView, 'liveTileEnable', 'PostSet', @(varargin)obj.drawTile);
            
            obj.hListeners(end+1) = addlistener(obj.hTileView, 'liveChansToShow', 'PostSet', @(varargin)obj.refreshImg);
            obj.hListeners(end+1) = addlistener(obj.hTileView, 'liveChanImageColors', 'PostSet', @(varargin)obj.refreshImg);
            obj.hListeners(end+1) = addlistener(obj.hTileView, 'liveChanAlphas', 'PostSet', @(varargin)obj.refreshImg);
            
        end
    end
    
    methods
       function hSurf = createSurfaceObject(obj,tileColor)
           hSurf = createSurfaceObject@scanimage.guis.tileDisplay.overviewTileDisplay(obj,tileColor);
       end 
       
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
                   if tfNoData
                       obj.refreshImg(true);
                   else
                       obj.refreshImg(false);
                   end
               end
               
               
           else
               delete(obj.hSurf);
               obj.hSurf = matlab.graphics.primitive.Surface.empty;
           end
           
       end
       
       function [tfRenderTile, tfShowZLine] = shouldShow(obj)
           % This is just if this channel is displayed, might change later.
           tfShowZLine = obj.hTileView.liveTileEnable;
           
           tfSameZPlane = obj.hTile.zPos == obj.hTileView.currentZ;
           
           tfRenderTile = obj.getInAxesLim() && tfSameZPlane && tfShowZLine;
       end
       
       function refreshImg(obj, tfNoData)
           
           if isempty(obj.hSurf) || ~isvalid(obj.hSurf)
               return;
           end
           
            if nargin < 2 || isempty(tfNoData)
               tfNoData = false;
            end
            
            if tfNoData
              obj.hSurf.CData = [0 0; 0 0];
              obj.hSurf.FaceAlpha = 0;
            else
              chanData = cell(1,numel(obj.hTileView.liveChansToShow));
              for idx = 1:numel(obj.hTileView.liveChansToShow)
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
                  
                  if obj.hTileView.liveChansToShow(idx)
                      color = obj.hTileView.liveChanImageColors(idx);
                      alpha = obj.hTileView.liveChanAlphas(idx);
                      LUT = obj.hTileView.hModel.hChannels.channelLUT{idx};

                      chDat = {img, color, LUT, alpha};
                  else
                      color = [0 0 0];
                      LUT = [0 1]; % to avoid div by 0 NaN dont use [0 0]
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
       
    end
        
    methods
       function addTileToOverview(obj)
           hTile = obj.hTile.copy(false);
           obj.hTileView.hModel.hTileManager.addOverviewTile(hTile);
       end
       
       % If tiles have the same confidence score only the first index will
       % return. Always returns 1 tile.
       function findInOverview(obj)
           chanDlg = inputdlg('Channel Select','Match for which channel?',1);
           
           if isempty(chanDlg)
              return;
           else
               channel = str2num(cell2mat(chanDlg));
           end
           
           ovTiles = obj.hTileView.hModel.hTileManager.hOverviewTiles;
           
           if isempty(ovTiles)
               warning('Tile Find Failed! The overview is empty!');
               return;
           end
           hOverviewRoiDatas = scanimage.mroi.RoiData.empty(0, numel(ovTiles));
           
           for ovTile = 1:numel(ovTiles)
               hTile = ovTiles(ovTile);
               
               hRoi = scanimage.mroi.Roi;
               
               sf = scanimage.mroi.scanfield.fields.RotatedRectangle();
               sf.setByAffine(hTile.affine)
               sf.pixelResolutionXY = hTile.resolutionXY;
               
               hRoi.add(hTile.zPos, sf);
               
               hRoiData = scanimage.mroi.RoiData;
               hRoiData.hRoi = hRoi;
               hRoiData.zs = hRoi.zs;
               hRoiData.channels = 1;
               
               if hTile.tfInMemory
                   hImg = hTile.imageData{channel};
               else
                   hImg = hTile.hImgPyramid(channel).getLod(1);
               end
               
               
               hRoiData.imageData = {{hImg}};
               
               hOverviewRoiDatas(ovTile) = hRoiData;

           end
           
           hEstimators = arrayfun(@(x) scanimage.components.motionEstimators.SimpleMotionEstimator(x), hOverviewRoiDatas);
           
           if obj.hTile.tfInMemory
               imData = obj.hTile.imageData{channel};
           else
               imData = obj.hTile.hImgPyramid(channel).getLod(1);
           end
           
           [~,conf,~] = arrayfun(@(x) x.estimationFcn(imData,1), hEstimators, 'UniformOutput', false);
           conf = cellfun(@(x) mean(x), conf);
           
           [val, idx] = max(conf(:));
           
           matchConf = val*100;
           match = ovTiles(idx);
           
           str = sprintf('Tile found!\nConfidence %.2f \nTile ID: %s\nTile Center: [%.2f %.2f]\n', matchConf, match.uuid, match.samplePoint(1), match.samplePoint(2));
           fprintf(str);
           disp('Matched Tile Assigned in Base');
           assignin('base', 'hTile', match);
           
           obj.hTileView.currentFovPos = match.samplePoint(1:2);
           obj.hTileView.setZ(match.samplePoint(end));
       end
       
       function updateContextMenu(obj,src,evt)
           obj.updateContextMenu@scanimage.guis.tileDisplay.tileDisplay(src,evt);          
           obj.rmTileMenuOption.Enable = 'off';
           uimenu('Parent',src,'Label','Make Scan Tile Here','Callback',@(varargin)obj.makeScanTile);
           uimenu('Parent',src,'Label','Add Tile to Overview','Callback',@(varargin)obj.addTileToOverview);
           uimenu('Parent',src,'Label','Find in Overview','Callback',@(varargin)obj.findInOverview);
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
