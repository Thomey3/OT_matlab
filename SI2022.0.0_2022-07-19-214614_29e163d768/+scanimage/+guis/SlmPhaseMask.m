classdef SlmPhaseMask < most.Gui
    properties
        hSlm
        hCSDisplay
    end
    
    properties (SetAccess = private, Hidden)
        hAx1;
        hAx2;
        hAx3;
        hAxFlow;
        hCenterPt;
        hCurrentPt;
        hCurrentPtZ;
        markedPositions;
        hMarkedPts;
        hMarkedPtsZ;
        hText;
        hSurf;
        hDispUpdateTimer;
        phaseMaskDisplayNeedsUpdate = false;
        phaseMaskDisplayNeedsRescale = false;
        hOutline;

        hListeners = event.listener.empty();
        hCSListeners = event.listener.empty();
    end
    
    properties (Dependent)
        hCSBackend
    end
    
    methods
        function obj = SlmPhaseMask(hSlm)
            obj = obj@most.Gui();
            obj.hSlm = hSlm;
        end
        
        function delete(obj)
            delete(obj.hListeners);
            delete(obj.hCSListeners);
            most.idioms.safeDeleteObj(obj.hDispUpdateTimer);
        end
    end
    
    methods (Access = protected)
        function initGui(obj)
            obj.hCSDisplay = obj.hSlm.hCoordinateSystem;
            
            obj.markedPositions = obj.hSlm.wrapPointsCSObjective(double.empty(0,3));
            obj.initPhaseMaskDisplay();
            
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hSlm,'ObjectBeingDestroyed',@(varargin)obj.delete);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hSlm,'wavelength_um','PostSet',@(varargin)obj.rescaleAxes);
            
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hSlm,'focalLength_um','PostSet',@(varargin)obj.rescaleAxes);
            
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hSlm,'slmMediumRefractiveIdx','PostSet',@(varargin)obj.rescaleAxes);
            
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hSlm,'objectiveMediumRefractiveIdx','PostSet',@(varargin)obj.rescaleAxes);
            
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hSlm,'wavelength_um','PostSet',@(varargin)obj.rescaleAxes);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hSlm,'wavelength_um','PostSet',@(varargin)obj.geometryBuffer);
            
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hSlm,'hPtLastWritten','PostSet',@(varargin)obj.flagPhaseMaskDisplayNeedsUpdate);
            
            
            obj.hDispUpdateTimer = timer('Period',0.3,'ExecutionMode','fixedSpacing','BusyMode','drop','Name','SLM Phase Mask Display Update Timer','TimerFcn',@obj.updateDisplayTimerFcn);
            start(obj.hDispUpdateTimer);
            
            obj.updateDisplay();
        end        
    end
    
    %% UI methods
    methods (Hidden)
        function flagPhaseMaskNeedsRescale(obj)
            obj.phaseMaskDisplayNeedsUpdate = true;
            obj.phaseMaskDisplayNeedsRescale = true;
        end
        
        function flagPhaseMaskDisplayNeedsUpdate(obj)
            obj.phaseMaskDisplayNeedsUpdate = true;
        end
        
        function updateDisplayTimerFcn(obj,varargin)
            if obj.phaseMaskDisplayNeedsUpdate
                obj.phaseMaskDisplayNeedsUpdate = false;
                try
                    obj.updateDisplay();
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
            end
            
            if obj.phaseMaskDisplayNeedsRescale
                obj.phaseMaskDisplayNeedsRescale = false;
                try
                    obj.rescaleAxes();
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
            end
        end
        
        function displayCoordinateSystemChanged(obj)
            obj.rescaleAxes();
            obj.updateDisplay();
        end
        
        function updateDisplay(obj,hPts)
            if isempty(obj.hFig)
                return
            end
            
            if nargin<2
                hPts = obj.hSlm.hPtLastWritten;
            end
            
            obj.hSurf.CData = obj.hSlm.lastWrittenPhaseMask;
            obj.hAx1.CLim = [0 double(intmax(obj.hSlm.hDevice.pixelDataType))];
            
            hCenterPt_ = obj.hSlm.wrapPointsCSObjective([0 0 0]);
            hCenterPt_ = hCenterPt_.transform(obj.hCSDisplay);
            
            obj.hCenterPt.XData = hCenterPt_.points(1);
            obj.hCenterPt.YData = hCenterPt_.points(2);
            obj.hCenterPt.ZData = hCenterPt_.points(3);
            
            if isempty(obj.markedPositions)
                obj.hMarkedPts.Visible = 'off';
                obj.hMarkedPtsZ.Visible = 'off';
            else
                hPtsMarked = obj.markedPositions.transform(obj.hCSDisplay);
                pts_marked = vertcat(hPtsMarked.points);
                obj.hMarkedPts.XData = pts_marked(:,1);
                obj.hMarkedPts.YData = pts_marked(:,2);
                obj.hMarkedPts.ZData = pts_marked(:,3);
                
                obj.hMarkedPtsZ.XData = pts_marked(:,1);
                obj.hMarkedPtsZ.YData = pts_marked(:,2);
                obj.hMarkedPtsZ.ZData = pts_marked(:,3);
                
                obj.hMarkedPts.Visible = 'on';
                obj.hMarkedPtsZ.Visible = 'on';
            end
            
            if isempty(obj.hSlm.hPtLastWritten)
                obj.hCurrentPt.Visible = 'off';
                obj.hCurrentPtZ.Visible = 'off';
                obj.hText.Visible = 'off';
            else
                obj.hCurrentPt.Visible = 'on';
                obj.hCurrentPtZ.Visible = 'on';
                
                hPts = hPts.transform(obj.hCSDisplay);
                pts = hPts.points;
                
                obj.hCurrentPt.XData = pts(:,1);
                obj.hCurrentPt.YData = pts(:,2);
                obj.hCurrentPt.ZData = pts(:,3);
                
                obj.hCurrentPtZ.XData = pts(:,1);
                obj.hCurrentPtZ.YData = pts(:,2);
                obj.hCurrentPtZ.ZData = pts(:,3);
                
                if size(obj.hSlm.hPtLastWritten,1)>=2
                    obj.hText.Visible = 'off';
                else
                    obj.hText.Visible = 'on';
                    obj.hText.String = sprintf('X: %s \nY: %s \nZ: %s ',most.idioms.engineersStyle(pts(1,1)/1e6,'m','%.f'),most.idioms.engineersStyle(pts(1,2)/1e6,'m','%.f'),most.idioms.engineersStyle(pts(1,3)/1e6,'m','%.f'));
                end
            end
        end
        
        function initPhaseMaskDisplay(obj)                
            obj.hFig.Name = 'Phase Mask Display';
            obj.hFig.WindowScrollWheelFcn = @obj.windowScroll;
            p = most.gui.centeredScreenPos([620 800],'pixels');
            obj.hFig.Position = p;
            
            hMainFlow = most.gui.uiflowcontainer('Parent',obj.hFig,'FlowDirection','TopDown');
                hTopFlow    = most.gui.uiflowcontainer('Parent',hMainFlow,'FlowDirection','LeftToRight');
                    obj.hAx1 = most.idioms.axes('Parent',hTopFlow); 
                hBottomFlow = most.gui.uiflowcontainer('Parent',hMainFlow,'FlowDirection','LeftToRight');
                hBottomFlow.HeightLimits = [340 340];
                    hTabGroup = uitabgroup('Parent',hBottomFlow,'SelectionChangedFcn',@obj.changeCS);
                       hTab1 = uitab('Parent',hTabGroup,'Title','SLM Raw Coordinates');
                              obj.hAxFlow = most.gui.uiflowcontainer('Parent',hTab1,'FlowDirection','LeftToRight');
                       hTab2 = uitab('Parent',hTabGroup,'Title','Sample Coordinates');
                       
            obj.hAx2 = most.idioms.axes('Parent',obj.hAxFlow);
            obj.hAx3 = most.idioms.axes('Parent',obj.hAxFlow);
            
            obj.hOutline = line('Parent',obj.hAx2,'XData',[],'YData',[],'Color',most.constants.Colors.darkGray,'LineWidth',0.25,'Hittest','off','PickableParts','none');
            
            dims = obj.hSlm.hDevice.pixelResolutionXY;
            [xx,yy,zz] = meshgrid([-dims(1) dims(1)]/2,[-dims(2) dims(2)]/2,0);
            if obj.hSlm.hDevice.computeTransposedPhaseMask
                xx = xx';
                yy = yy';
                zz = zz';
            end
            
            obj.hSurf = surface('Parent',obj.hAx1,...
                'XData',xx,'YData',yy,'ZData',zz,'CData',0,...
                'FaceColor','texturemap',...
                'CDataMapping','scaled',...
                'FaceLighting','none',...
                'LineStyle','none');
            obj.hAx1.XLim = [-dims(1) dims(1)]/2;
            obj.hAx1.YLim = [-dims(2) dims(2)]/2;
            obj.hAx1.DataAspectRatio = [1 1 1];
            box(obj.hAx1,'on');
            
            %view(obj.hAx1,0,-90); % this messes up the zoom functions in the menu bar
            obj.hAx1.YDir = 'reverse';
            
            title(obj.hAx1,'SLM Phase Mask [pixel value]');
            colorbar(obj.hAx1);
            
            view(obj.hAx2,0,-90); % [x,-y] view
            grid(obj.hAx2,'on');
            box(obj.hAx2,'on');
            title(obj.hAx2,'SLM Position');
            xlabel(obj.hAx2,'x [um]');
            ylabel(obj.hAx2,'y [um]');
            zlabel(obj.hAx2,'z [um]');
            
            obj.hAx3.DataAspectRatio = [diff(obj.hAx3.XLim),diff(obj.hAx3.YLim),diff(obj.hAx3.ZLim)];
            view(obj.hAx3,0,180); % [x,-z] view
            grid(obj.hAx3,'on');
            box(obj.hAx3,'on');
            title(obj.hAx3,'Z');
            xlabel(obj.hAx3,'x [um]');
            ylabel(obj.hAx3,'y [um]');
            zlabel(obj.hAx3,'z [um]');
            
            obj.rescaleAxes();
            
            hPtContextMenu = uicontextmenu('Parent',obj.hFig);
            uimenu('Parent',hPtContextMenu,'Label','Park','Callback',@(src,evt)obj.hSlm.parkScanner);
            uimenu('Parent',hPtContextMenu,'Label','Zero','Callback',@(src,evt)obj.hSlm.zeroScanner);
            uimenu('Parent',hPtContextMenu,'Label','Mark Point','Callback',@mark);
            uimenu('Parent',hPtContextMenu,'Label','Delete Point','Callback',@deletePoint);
            
            hAx2ContextMenu = uicontextmenu('Parent',obj.hFig);
            uimenu('Parent',hAx2ContextMenu,'Label','Park','Callback',@(src,evt)obj.hSlm.parkScanner);
            uimenu('Parent',hAx2ContextMenu,'Label','Zero','Callback',@(src,evt)obj.hSlm.zeroScanner);
            uimenu('Parent',hAx2ContextMenu,'Label','Delete Marks','Callback',@deleteMarks);
            uimenu('Parent',hAx2ContextMenu,'Label','Add Point','Callback',@addPoint);
            obj.hAx2.UIContextMenu = hAx2ContextMenu;
            
            hMarkedPtsContextMenu = uicontextmenu('Parent',obj.hFig);
            uimenu('Parent',hMarkedPtsContextMenu,'Label','Goto Mark','Callback',@goToMark);
            uimenu('Parent',hMarkedPtsContextMenu,'Label','Delete Mark','Callback',@deleteMark);
            
            obj.hCenterPt = line('Parent',obj.hAx2,'XData',0,'YData',0,'ZData',0,'Marker','+','Color','black','HitTest','off','PickableParts','none');
            obj.hMarkedPts = line('Parent',obj.hAx2,'XData',[],'YData',[],'Marker','x','Color','black','LineStyle','none','UIContextMenu',hMarkedPtsContextMenu);
            obj.hMarkedPtsZ = line('Parent',obj.hAx3,'XData',[],'YData',[],'Marker','x','Color','black','LineStyle','none');
            obj.hText = text('Parent',obj.hAx2,'Position',[obj.hAx2.XLim(2) obj.hAx2.YLim(1)],'HorizontalAlignment','right','VerticalAlignment','top','HitTest','off','PickableParts','none');
            obj.hCurrentPt = line('Parent',obj.hAx2,'XData',NaN,'YData',NaN,'ZData',NaN,'Marker','o','Color','red','LineStyle','none','ButtonDownFcn',@obj.startMove,'UIContextMenu',hPtContextMenu);
            obj.hCurrentPtZ = line('Parent',obj.hAx3,'XData',NaN,'YData',NaN,'ZData',NaN,'Marker','o','Color','red','LineStyle','none','ButtonDownFcn',@obj.startMove,'UIContextMenu',hPtContextMenu);
            
            function mark(src,evt)
                idx = obj.closestPointIdx(obj.hAx2,obj.hSlm.hPtLastWritten);
                hPt = obj.hSlm.hPtLastWritten.filter(idx);
                hPt = hPt.transform(obj.hCSBackend);
                obj.markedPositions = obj.markedPositions.append(hPt);
            end
            
            function deleteMark(src,evt)
                idx = obj.closestPointIdx(obj.hAx2,obj.markedPositions);
                obj.markedPositions = obj.markedPositions.remove(idx);
            end
            
            function deleteMarks(src,evt)
                numPoints = obj.markedPositions.numPoints;
                obj.markedPositions = obj.markedPositions.remove(1:numPoints);
            end
            
            function goToMark(src,evt)
                idx = obj.closestPointIdx(obj.hAx2,obj.markedPositions);                
                obj.hSlm.pointScanner(obj.markedPositions.filter(idx));
            end
            
            function deletePoint(src,evt)
                idx = obj.closestPointIdx(obj.hAx2,obj.hSlm.hPtLastWritten);
                hPts = obj.hSlm.hPtLastWritten.remove(idx);
                obj.hSlm.pointScanner(hPts);
            end
            
            function addPoint(src,evt)
                hPts = obj.hSlm.hPtLastWritten;
                if isempty(hPts)
                    pts = zeros(0,3);
                else
                    hPts = hPts.transform(obj.hCSDisplay);
                    pts = hPts.points;
                end
                                
                newPt = obj.hAx2.CurrentPoint(1,1:2);
                newPt = [newPt 0];
                
                pts = vertcat(pts,newPt);
                
                hPts = scanimage.mroi.coordinates.Points(obj.hCSDisplay,pts);
                hPts = hPts.transform(obj.hCSBackend);
                obj.hSlm.pointScanner(hPts);
            end
        end
        
        function changeCS(obj,src,evt)
            obj.hAxFlow.Parent = evt.NewValue;
            
            switch evt.NewValue.Title
                case 'Sample Coordinates'
                    hCS = obj.hCSDisplay.filterTree(@(n)strcmp(n.name,'Sample Relative'));
                    obj.hCSDisplay = hCS{1};
                otherwise
                    obj.hCSDisplay = obj.hSlm.hCoordinateSystem;
            end
            
            obj.displayCoordinateSystemChanged();
        end
        
        function rescaleAxes(obj)
            if isempty(obj.hFig)
                return
            end
            
            slmRange = obj.hSlm.scanDistanceRangeXYObjective;
            
            outlinePts = [-slmRange(1)/2 -slmRange(2)/2 0
                    slmRange(1)/2 -slmRange(2)/2 0
                    slmRange(1)/2  slmRange(2)/2 0
                   -slmRange(1)/2  slmRange(2)/2 0];
               
            outlinePts(end+1,:) = outlinePts(1,:); % close the curve
               
            hOutlinePts = obj.hSlm.wrapPointsCSObjective(outlinePts);
            hOutlinePts = hOutlinePts.transform(obj.hCSDisplay);
            
            outlinePts = hOutlinePts.points;
            
            if ~isempty(obj.hAx2)
                obj.hAx2.XLim = centeredScale( [min(outlinePts(:,1)) max(outlinePts(:,1))] ,1.2);
                obj.hAx2.YLim = centeredScale( [min(outlinePts(:,2)) max(outlinePts(:,2))] ,1.2);
                obj.hAx2.DataAspectRatio = [1,1,1];
            end
            
            if ~isempty(obj.hOutline)
                obj.hOutline.XData = outlinePts(:,1);
                obj.hOutline.YData = outlinePts(:,2);
            end
            
            if ~isempty(obj.hAx3)
                obj.hAx3.XLim = [min(outlinePts(:,1)) max(outlinePts(:,1))];
                obj.hAx3.YLim = [min(outlinePts(:,2)) max(outlinePts(:,2))];
                if strcmp(obj.hAx3.ZLimMode,'auto')
                    obj.hAx3.ZLim = [-100 100];
                end
                obj.hAx3.DataAspectRatio = [diff(obj.hAx3.XLim),diff(obj.hAx3.YLim),diff(obj.hAx3.ZLim)];
            end
            
            if ~isempty(obj.hText) && ~isempty(obj.hAx2)
                obj.hText.Position = [obj.hAx2.XLim(2) obj.hAx2.YLim(1)];
            end
            
            function pts = centeredScale(pts,factor)
                pts = mean(pts) + diff(pts) * [-0.5 0.5] * factor;
            end
        end
        
        function windowScroll(obj,src,evt)
            ct = evt.VerticalScrollCount;
            
            ct = sign(ct);
            factor = 2^(ct/10);
            newZLim = obj.hAx3.ZLim(2) * factor;
            
            newZLim = max(min(newZLim,9999),10);
            
            obj.hAx3.ZLim = newZLim  * [-1 1];
            xspan = diff(obj.hAx3.XLim);
            yspan = diff(obj.hAx3.YLim);
            zspan = diff(obj.hAx3.ZLim);
            obj.hAx3.DataAspectRatio = [xspan, yspan, zspan];
        end
        
        function startMove(obj,src,evt)
            hFig_ = ancestor(src,'figure');
            hAx_ = ancestor(src,'axes');
            idx = obj.closestPointIdx(hAx_,obj.hSlm.hPtLastWritten);
            hFig_.Interruptible = 'off';
            hFig_.BusyAction = 'cancel';
            hFig_.WindowButtonMotionFcn = @(src_,evt_)obj.move(src_,evt,src,idx);
            hFig_.WindowButtonUpFcn = @obj.endMove;
        end
        
        function endMove(obj,src,evt)
            hFig_ = ancestor(src,'figure');
            hFig_.Interruptible = 'on';
            hFig_.WindowButtonMotionFcn = [];
            hFig_.WindowButtonUpFcn = [];
        end
        
        function move(obj,src,evt,line,idx)
            try
                hAx_ = ancestor(line,'axes');
                mousePt = hAx_.CurrentPoint;
                
                hPts = obj.hSlm.hPtLastWritten.transform(obj.hCSDisplay);
                pts = hPts.points;
                pt = pts(idx,:);
                
                [~,projectedPt] = scanimage.mroi.util.distanceLinePts3D(mousePt(1,:),diff(mousePt),pt);
                
                pts(idx,:) = projectedPt;
                hPt = scanimage.mroi.coordinates.Points(obj.hCSDisplay,pts);
                hPt = hPt.transform(obj.hCSBackend);
                
                obj.updateDisplay(hPt);
                obj.hSlm.pointScanner(hPt);
            catch ME
                obj.endMove(src,evt);
                rethrow(ME);
            end
        end
        
        function idx = closestPointIdx(obj,hAx_,pts)
            if isa(pts,'scanimage.mroi.coordinates.Points')
                pts = pts.transform(obj.hCSDisplay);
                pts = pts.points;
            end
            mousept = hAx_.CurrentPoint;
            d = scanimage.mroi.util.distanceLinePts3D(mousept(1,:),diff(mousept),pts); 
            [~,idx] = min(d);
        end
    end
    
    methods
        function set.markedPositions(obj,val)
            obj.markedPositions = val;
            obj.updateDisplay();
        end
        
        function val = get.hCSBackend(obj)
            val = obj.hSlm.hCoordinateSystem;
        end
        
        function set.hCSDisplay(obj,val)
            assert(isa(val,'scanimage.mroi.coordinates.CoordinateSystem'));
            assert(isscalar(val));
            assert(val.dimensions == 3);
            
            assert(~isempty(obj.hCSBackend.getRelationship(val)));
            
            obj.hCSDisplay = val;
            attachCS_Listeners();
            
            function attachCS_Listeners()
                delete(obj.hCSListeners);
                obj.hCSListeners = event.listener.empty();
                
                [~,nodes] = obj.hCSDisplay.getTree();
                for idx = 1:numel(nodes)
                    obj.hCSListeners(end+1) = most.ErrorHandler.addCatchingListener(nodes{idx},'changed',@(varargin)obj.flagPhaseMaskNeedsRescale);
                end
            end
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
