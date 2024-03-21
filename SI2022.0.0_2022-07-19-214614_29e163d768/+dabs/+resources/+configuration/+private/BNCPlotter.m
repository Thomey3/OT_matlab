classdef BNCPlotter < handle
    properties
        hBNC
        hIO
        hFig
        hAx
        hGuideLine
        hLine
        hRect
        hListeners = event.listener.empty();
        historyLength_s = 3;
        historyTic = zeros(0,'uint64');
        historyVal = [];
        timerPeriod_s = 0.05;
        hText
        hLimitTextLower
        hLimitTextUpper
        
        updatePositionProtection = false;
    end
    
    methods
        function obj = BNCPlotter(hParent,hBNC)
            obj.hBNC = hBNC;
            obj.hIO = obj.hBNC.hResource;
            
            if ~most.idioms.isValidObj(obj.hIO.hDAQ.hFpga)
                obj.delete();
                return
            end
            
            obj.hFig = ancestor(hParent,'figure');
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(hParent,'ObjectBeingDestroyed',@(varargin)obj.delete);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(hBNC,'ObjectBeingDestroyed',@(varargin)obj.delete);

            obj.hAx = most.idioms.axes('Parent',obj.hFig,'PickableParts','none','HitTest','off','Units','pixels','Visible','off');
            obj.hAx.XLim = [0 1];
            obj.hAx.YLim = [0 1];
            obj.hRect = rectangle('Parent',obj.hAx,'Position',[-0.1 -0.25 1.2 1.5],'Curvature',0.1,'FaceColor',[1 1 1]*0.3,'EdgeColor',[1 1 1]*0.6,'Clipping','off','LineWidth',4);
            obj.hLine = line('Parent',obj.hAx,'XData',[],'YData',[],'Color',[1 1 1],'LineWidth',2);
            obj.hGuideLine = line('Parent',obj.hAx,'XData',[],'YData',[],'Color',[1 1 1]*0.8,'LineWidth',0.5,'LineStyle',':');
            obj.hText = text('Parent',obj.hAx,'Position',[0 1],'HorizontalAlignment','left','VerticalAlignment','bottom','FontWeight','bold','Color',[1 1 1]*0.6,'FontSize',10,'String',obj.hIO.channelName);
            obj.hLimitTextLower = text('Parent',obj.hAx,'Position',[0.5 0],'HorizontalAlignment','center','VerticalAlignment','top','FontWeight','bold','Color',[1 1 1]*0.6,'FontSize',10);
            obj.hLimitTextUpper = text('Parent',obj.hAx,'Position',[0.5 1],'HorizontalAlignment','center','VerticalAlignment','bottom','FontWeight','bold','Color',[1 1 1]*0.6,'FontSize',10);

            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hIO.hResourceStore.hSystemTimer,'beacon_15Hz',@(varargin)obj.updateData());
        end

        function delete(obj)
            most.idioms.safeDeleteObj(obj.hListeners);
            most.idioms.safeDeleteObj(obj.hAx);
        end
    end

    methods
        function updateData(obj)
            try
                [data,limits,limitString,guideLines] = obj.getData();
            catch ME
                data = [];
                limits = [-10 10];
                guideLines = [];
                limitString = {'',''};
            end

            if isempty(data)
                return
            end
            
            obj.historyTic(end+1) = tic();
            obj.historyVal(end+1) = data;

            t = zeros(size(obj.historyTic));
            for idx = 1:numel(obj.historyTic)
                t(idx) = toc(obj.historyTic(idx));
            end
            %t = arrayfun(@(t)toc(t),obj.historyTic);
            mask = t>obj.historyLength_s;

            obj.historyTic(mask) = [];
            obj.historyVal(mask) = [];

            t(mask) = [];
            
            if isempty(t)
                obj.hLine.XData = [];
                obj.hLine.YData = [];
            else
                obj.hLine.XData = (t-max(t)) / obj.historyLength_s * -1;
                obj.hLine.YData = (obj.historyVal - limits(1)) / diff(limits);
            end

            if isempty(guideLines)
                obj.hGuideLine.XData = [];
                obj.hGuideLine.YData = [];
            else
                guideLinesY = [guideLines;guideLines];
                guideLinesY(3,:) = NaN;
                guideLinesX = zeros(size(guideLinesY));
                guideLinesX(1,:) = 0;
                guideLinesX(2,:) = 1;
                guideLinesX(3,:) = NaN;
                obj.hGuideLine.XData = guideLinesX(:);
                obj.hGuideLine.YData = (guideLinesY(:) - limits(1)) / diff(limits);
            end
            
            obj.hLimitTextLower.String = limitString{1};
            obj.hLimitTextUpper.String = limitString{2};
        end

        function [data,limits,limitString,guideLines] = getData(obj)
            simulated = obj.hIO.hDAQ.simulated;

            if isa(obj.hIO,'dabs.resources.ios.AO')
                limits = [-10 10];
                guideLines = [-10 0 10];
                limitString = {'-10V', ' 10V'};
                if simulated
                    data = rand(1) * 20 - 10;
                else
                    data = obj.hIO.queryValue();
                end
            elseif isa(obj.hIO,'dabs.resources.ios.AI')
                guideLines = [-10 0 10];
                limits = [-10 10];
                limitString = {'-10V', ' 10V'};
                if simulated
                    data = rand(1) * 20 - 10;
                else
                    data = obj.hIO.readValue();
                end

            elseif isa(obj.hIO,'dabs.resources.ios.D')
                limits = [0 1];
                guideLines = [0 1];
                limitString = {'OFF', ' ON'};
                if simulated
                    data = rand(1) > 0.5;
                else
                    data = obj.hIO.queryValue();
                end
            else
                guideLines = [];
                limits = [0 1];
                data   = [];
            end
        end
        
        function updatePosition(obj)
            if obj.updatePositionProtection
                return
            end
            
            obj.updatePositionProtection = true;
            
            try
                obj.updatePositionProtected();
            catch ME
                obj.updatePositionProtection = false;
                ME.rethrow();
            end
            obj.updatePositionProtection = false;
        end

        function updatePositionProtected(obj)
            axOffset = [30 30];
            axSize = [100 80];
            axSizeWithPadding = axSize .* [1.1 1.25];

            [figPt,figPos] = getFigPointAndPosition();
            q = getBestQuadrant(figPt,figPos);

            updateAxesPosition(figPt,q);

            function [figPt,figPos] = getFigPointAndPosition()
                figUnits = obj.hFig.Units;
                obj.hFig.Units = 'pixels';
                figPt = obj.hFig.CurrentPoint;
                figPos = obj.hFig.Position;
                obj.hFig.Units = figUnits;
            end

            function q = getBestQuadrant(figPt,figPos)
                figSz = figPos(3:4);
                
                xpos = min(axSizeWithPadding(1), figSz(1)-(figPt(1)+axOffset(1)));
                xneg = min(axSizeWithPadding(1), figPt(1)-axOffset(1));
                ypos = min(axSizeWithPadding(2), figSz(2)-(figPt(2)+axOffset(2)));
                yneg = min(axSizeWithPadding(2), figPt(2)-axOffset(2));
                
                q1Area = xpos*ypos;
                q2Area = xneg*ypos;
                q3Area = xneg*yneg;
                q4Area = xpos*yneg;
                
                q1OpenSpace = (figSz(1)-figPt(1)) * (figSz(2)-figPt(2));
                q2OpenSpace = figPt(1) * (figSz(2)-figPt(2));
                q3OpenSpace = figPt(1) * figPt(2);
                q4OpenSpace = (figSz(1)-figPt(1)) * figPt(2);

                qAreas      = [q1Area,q2Area,q3Area,q4Area];
                qOpenSpaces = [q1OpenSpace,q2OpenSpace,q3OpenSpace,q4OpenSpace];
                
                if any(qAreas>=prod(axSizeWithPadding))
                    mask = qAreas>=prod(axSizeWithPadding);
                    qs = 1:4;
                    qs = qs(mask);
                    qOpenSpaces = qOpenSpaces(mask);
                    [~,idx] = max(qOpenSpaces);
                    q = qs(idx);
                else
                    [~,q] = max(qAreas);
                end
            end

            function updateAxesPosition(figPt,q)
                switch q
                    case 1
                        x = figPt(1) + axOffset(1);
                        y = figPt(2) + axOffset(2);
                    case 2
                        x = figPt(1) - axSize(1) - axOffset(1);
                        y = figPt(2) + axOffset(2);
                    case 3
                        x = figPt(1) - axSize(1) - axOffset(1);
                        y = figPt(2) - axSize(2) - axOffset(2);
                    case 4
                        x = figPt(1) + axOffset(1);
                        y = figPt(2) - axSize(2) - axOffset(2);
                end

                obj.hAx.Position = [x y axSize];
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
