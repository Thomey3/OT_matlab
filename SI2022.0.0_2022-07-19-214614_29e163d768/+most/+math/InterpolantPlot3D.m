classdef InterpolantPlot3D < handle
    properties
        cursor;
    end
    
    properties (Hidden, SetAccess = private)
        hFig
        ranges
        valueRange
        hInterpolant
        
        hImXZ
        hImYZ
        hImXY
        
        hLineX
        hLineY
        hLineZ
        
        hLineX_base
        hLineY_base
        hLineZ_base
        
        hLineXZ
        hLineYZ
        hLineXYx
        hLineXYy
        
        AxesLabels
        name
    end
    
    methods
        function obj = InterpolantPlot3D(hInterpolant,ranges,name,axesLabels)
            if nargin < 2 || isempty(ranges)
                ranges = [];
            end
            
            if nargin < 3 || isempty(name)
                name = '';
            end
            
            if nargin < 4 || isempty(axesLabels)
                axesLabels = {'','','',''};
            end
            
            obj.hInterpolant = hInterpolant;
            obj.ranges = ranges;
            obj.AxesLabels = axesLabels;
            obj.name = name;
            obj.initUI();
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hFig);
        end
        
        function rms = calculateRMS(obj)
            [pp,vv] = obj.getInterpolantPoints();
            vv_i = obj.hInterpolant(pp);
            
            n = numel(vv);
            
            rms = sqrt( sum( (vv-vv_i).^2 ) / n);
        end
        
        function initUI(obj)
            most.idioms.safeDeleteObj(obj.hFig);
            obj.hFig = most.idioms.figure('CloseRequestFcn',@(varargin)delete(obj));
            
            [pp,vv] = obj.getInterpolantPoints();
            
            if isempty(obj.ranges)
                pp = max(abs(pp),[],1);
                
                xx = [-1 1] * pp(1) * 1.1;
                yy = [-1 1] * pp(2) * 1.1;
                zz = [-1 1] * pp(3) * 1.1;
                
                obj.ranges = [ xx;yy;zz ];
            end
            
            obj.valueRange = [min(vv) max(vv)];
            obj.valueRange = sum(obj.valueRange)/2 + [-0.5 0.5] * diff(obj.valueRange) * 1.3;
            
            if diff(obj.valueRange) <= 0
                obj.valueRange = obj.valueRange + [-1 1]                ;
            end
            
            if isempty(obj.cursor)
                obj.cursor = [mean(obj.ranges(1,:)) mean(obj.ranges(2,:)) mean(obj.ranges(3,:))];
            end
            
            
            hAxX = most.idioms.subplot(6,2,2,'Parent',obj.hFig,'XLim',obj.ranges(1,:),'YLim',obj.valueRange,'Box','on');
            hAxY = most.idioms.subplot(6,2,4,'Parent',obj.hFig,'XLim',obj.ranges(2,:),'YLim',obj.valueRange,'Box','on');
            hAxZ = most.idioms.subplot(6,2,6,'Parent',obj.hFig,'XLim',obj.ranges(3,:),'YLim',obj.valueRange,'Box','on');
            
            grid(hAxX,'on');
            grid(hAxY,'on');
            grid(hAxZ,'on');
            
            hAxXY = most.idioms.subplot(6,2,[1 3 5],'Parent',obj.hFig);
            hAxXZ = most.idioms.subplot(6,2,[7 9 11],'Parent',obj.hFig);
            hAxYZ = most.idioms.subplot(6,2,[8 10 12],'Parent',obj.hFig);
            
            title(hAxXY,sprintf('%s\n(RMS: %f)',obj.name,obj.calculateRMS()));
            
            obj.hImXZ = imagesc('Parent',hAxXZ,'XData',obj.ranges(1,:),'YData',obj.ranges(3,:));
            obj.hImYZ = imagesc('Parent',hAxYZ,'XData',obj.ranges(2,:),'YData',obj.ranges(3,:));
            obj.hImXY = imagesc('Parent',hAxXY,'XData',obj.ranges(1,:),'YData',obj.ranges(2,:));
            
            obj.hLineX = line('Parent',hAxX,'XData',[],'YData',[],'Color','blue');
            obj.hLineY = line('Parent',hAxY,'XData',[],'YData',[],'Color','blue');
            obj.hLineZ = line('Parent',hAxZ,'XData',[],'YData',[],'Color','blue');
            
            obj.hLineX_base = line('Parent',hAxX,'XData',[],'YData',[],'Color','red','LineStyle','none','Marker','x');
            obj.hLineY_base = line('Parent',hAxY,'XData',[],'YData',[],'Color','red','LineStyle','none','Marker','x');
            obj.hLineZ_base = line('Parent',hAxZ,'XData',[],'YData',[],'Color','red','LineStyle','none','Marker','x');
            
            obj.hLineXZ = line('Parent',hAxXZ,'XData',[],'YData',[],'Color','red','LineWidth',1,'ButtonDownFcn',@obj.moveXZ);
            obj.hLineYZ = line('Parent',hAxYZ,'XData',[],'YData',[],'Color','red','LineWidth',1,'ButtonDownFcn',@obj.moveYZ);
            obj.hLineXYx = line('Parent',hAxXY,'XData',[],'YData',[],'Color','red','LineWidth',1,'ButtonDownFcn',@obj.moveXYx);
            obj.hLineXYy = line('Parent',hAxXY,'XData',[],'YData',[],'Color','red','LineWidth',1,'ButtonDownFcn',@obj.moveXYy);
            
            axis(hAxXZ,'image');
            axis(hAxYZ,'image');
            axis(hAxXY,'image');
            
            view(hAxXZ,0,-90)
            view(hAxYZ,0,-90)
            view(hAxXY,0,-90)
            
            hAxXZ.CLim = obj.valueRange;
            hAxYZ.CLim = obj.valueRange;
            hAxXY.CLim = obj.valueRange;
            
            xlabel(hAxXZ,obj.AxesLabels{1});
            ylabel(hAxXZ,obj.AxesLabels{3});

            xlabel(hAxYZ,obj.AxesLabels{2});
            ylabel(hAxYZ,obj.AxesLabels{3});

            xlabel(hAxXY,obj.AxesLabels{1});
            ylabel(hAxXY,obj.AxesLabels{2});

            xlabel(hAxX,obj.AxesLabels{1});
            ylabel(hAxX,obj.AxesLabels{4});

            xlabel(hAxY,obj.AxesLabels{2});
            ylabel(hAxY,obj.AxesLabels{4});

            xlabel(hAxZ,obj.AxesLabels{3});
            ylabel(hAxZ,obj.AxesLabels{4});
            
            colorbar(hAxXY);
            
            obj.update();
        end
        
        function update(obj)
            nPoints = 100;
            
            [pp,vv] = obj.getInterpolantPoints();
            
            xx = linspace(obj.ranges(1,1),obj.ranges(1,2),nPoints)';
            yy = linspace(obj.ranges(2,1),obj.ranges(2,2),nPoints)';
            zz = linspace(obj.ranges(3,1),obj.ranges(3,2),nPoints)';
            
            xV = obj.hInterpolant(xx,repmat(obj.cursor(2),size(xx)),repmat(obj.cursor(3),size(xx)));
            yV = obj.hInterpolant(repmat(obj.cursor(1),size(yy)),yy,repmat(obj.cursor(3),size(yy)));
            zV = obj.hInterpolant(repmat(obj.cursor(1),size(zz)),repmat(obj.cursor(2),size(zz)),zz);
            
            obj.hLineX.XData = xx;
            obj.hLineX.YData = xV;
            
            obj.hLineY.XData = yy;
            obj.hLineY.YData = yV;
            
            obj.hLineZ.XData = zz;
            obj.hLineZ.YData = zV;
            
            [XZxx,XZzz] = meshgrid(xx,zz);
            [YZyy,YZzz] = meshgrid(yy,zz);
            [XYxx,XYyy] = meshgrid(xx,zz);            
            
            xzV = obj.hInterpolant(XZxx(:),repmat(obj.cursor(2),numel(XZxx),1),XZzz(:));
            yzV = obj.hInterpolant(repmat(obj.cursor(1),numel(YZyy),1),YZyy(:),YZzz(:));
            xyV = obj.hInterpolant(XYxx(:),XYyy(:),repmat(obj.cursor(3),numel(XYxx),1));

            xzV = reshape(xzV,size(XZxx));
            yzV = reshape(yzV,size(YZyy));
            xyV = reshape(xyV,size(XYxx));
            
            obj.hImXZ.CData = xzV;
            obj.hImYZ.CData = yzV;
            obj.hImXY.CData = xyV;
            
            obj.hLineXZ.XData = obj.ranges(1,:);
            obj.hLineXZ.YData = [obj.cursor(3) obj.cursor(3)];
            
            obj.hLineYZ.XData = obj.ranges(2,:);
            obj.hLineYZ.YData = [obj.cursor(3) obj.cursor(3)];
            
            obj.hLineXYx.XData = [obj.cursor(1) obj.cursor(1)];
            obj.hLineXYx.YData = obj.ranges(2,:);
            
            obj.hLineXYy.XData = obj.ranges(1,:);
            obj.hLineXYy.YData = [obj.cursor(2) obj.cursor(2)];
            
            xD = scanimage.mroi.util.distanceLinePts3D(obj.cursor,[1 0 0],pp);
            yD = scanimage.mroi.util.distanceLinePts3D(obj.cursor,[0 1 0],pp);
            zD = scanimage.mroi.util.distanceLinePts3D(obj.cursor,[0 0 1],pp);
            
            dTolerance = 0.01;
            
            xIdxs = find(xD < (diff(obj.ranges(1,:)) * dTolerance));
            yIdxs = find(yD < (diff(obj.ranges(2,:)) * dTolerance));
            zIdxs = find(zD < (diff(obj.ranges(3,:)) * dTolerance));
            
            obj.hLineX_base.XData = pp(xIdxs,1);
            obj.hLineX_base.YData = vv(xIdxs);
            
            obj.hLineY_base.XData = pp(yIdxs,2);
            obj.hLineY_base.YData = vv(yIdxs);
            
            obj.hLineZ_base.XData = pp(zIdxs,3);
            obj.hLineZ_base.YData = vv(zIdxs);
        end
        
        function moveXZ(obj,src,evt)
            obj.startCursoring(@getPt,3);
            
            function pt = getPt()
                hAx = ancestor(src,'axes');
                pt = hAx.CurrentPoint(1,2);
            end
        end
        
        function moveYZ(obj,src,evt)
            obj.startCursoring(@getPt,3);
            
            function pt = getPt()
                hAx = ancestor(src,'axes');
                pt = hAx.CurrentPoint(1,2);
            end
        end
        
        function moveXYx(obj,src,evt)
            obj.startCursoring(@getPt,1);
            
            function pt = getPt()
                hAx = ancestor(src,'axes');
                pt = hAx.CurrentPoint(1,1);
            end
        end
        
        function moveXYy(obj,src,evt)
            obj.startCursoring(@getPt,2);
            
            function pt = getPt()
                hAx = ancestor(src,'axes');
                pt = hAx.CurrentPoint(1,2);
            end
        end
        
        function startCursoring(obj,ptFcn,dim)
            obj.hFig.WindowButtonMotionFcn = @move;
            obj.hFig.WindowButtonUpFcn = @stop;
            
            function move(src,evt)
                try
                    pt = ptFcn();
                    obj.cursor(dim) = pt;
                    obj.update();
                catch ME
                    stop([],[]);
                    rethrow(ME);
                end
            end
            
            function stop(src,evt)
                obj.hFig.WindowButtonMotionFcn = [];
                obj.hFig.WindowButtonUpFcn = [];
            end
        end
        
        function [pp,vv] = getInterpolantPoints(obj)
            Class = class(obj.hInterpolant);
            switch Class
                case 'griddedInterpolant'
                    nDim = numel(obj.hInterpolant.GridVectors);
                    [pp{1:nDim}] = ndgrid(obj.hInterpolant.GridVectors{:});
                    pp = cellfun(@(p)p(:),pp,'UniformOutput',false);
                    pp = horzcat(pp{:});
                    vv = obj.hInterpolant.Values(:);
                otherwise
                    pp = obj.hInterpolant.Points;
                    vv = obj.hInterpolant.Values;
            end
        end
    end
    
    methods
        function set.cursor(obj,val)
            validateattributes(val,{'numeric'},{'finite','nonnan','vector','numel',3});
            
            val(1) = min(max(obj.ranges(1,1),val(1)),obj.ranges(1,2));
            val(2) = min(max(obj.ranges(2,1),val(2)),obj.ranges(2,2));
            val(3) = min(max(obj.ranges(3,1),val(3)),obj.ranges(3,2));
            
            obj.cursor = val;
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
