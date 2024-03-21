classdef WaveformPlotPanel < handle
    
    properties (SetObservable)
        visible;
        showDetailView = true;
        
        actuatorName = '';
        positionUnits;
        positionName;
        historySel = inf;
        
        T = 1;
        
        tDetail = 1e-4*[.2 .6];
        vLim = [0 1];
        
        tLims = [0 1];
        vMaxLims = [0 1];
        
        sampleRateHz;
        desiredWaveform;
        outputWaveform;
        feedbackWaveform;
        optimizationHistory;
    end
    
    properties
        hWaveGui;
        hTabParent;
        hPanel;
        hTopFlow;
        
        hWaveAxes;
        hWaveAxesLabel;
        hWaveAxesDetail;
        hWaveAxesDetailOutline;
        
        hErrorAxes;
        hErrorAxesLabel;
        hErrorAxesDetail;
        hErrorAxesDetailOutline;
        
        hHistoryAxes;
        
        hDesiredLine;
        hDesiredDetailLine;
        hOutputLine;
        hOutputDetailLine;
        hFeedbackLine;
        hFeedbackDetailLine;
        hErrorLine;
        hErrorDetailLine;
        hHistoryLine;
        hHistoryLinePts;
        hHistoryMarker;
        
        hWaveEndLines;
        hErrorEndLines;
        hWaveEndLinesDetail;
        hErrorEndLinesDetail;
        
        hFrameStartLines;
        hFrameStopLines;
        
        hFrameStartLinesDetails;
        hFrameStopLinesDetails;
        
        hWaveDetailSurf;
        hWaveDetailLine1;
        hWaveDetailLine2;
        
        hErrorDetailSurf;
        hErrorDetailLine1;
        hErrorDetailLine2;

        hProgressFlow;
        hProgressSurf;
        hProgressText;
        
        pbShowDetail;
        
        volts2FuncMap;
        volts2Func;
        desiredWaveformMap;
        
        hasFdbk;
        hScanner;
        
        desWvfmColors = {[0 .5 0] 'b' 'r' 'm' 'k' 'c'};
        waveformName;
    end
    
    methods
        function obj = WaveformPlotPanel(hWaveGui,uiparent,hTabParent,waveformName,unitOptions,positionName)
            obj.hWaveGui = hWaveGui;
            obj.hTabParent = hTabParent;
            obj.hTabParent.UserData(end+1) = obj;
            obj.hPanel = uipanel('parent',uiparent,'bordertype','none','BackgroundColor','w','BusyAction','cancel','Interruptible','off');
            obj.positionName = positionName;
            obj.waveformName = waveformName;
            
            %% Create axeseses
            common = {'parent',obj.hPanel,'box','on','xgrid','on','ygrid','on','LineWidth',1};
            
            obj.hWaveAxes = most.idioms.axes(common{:},'ButtonDownFcn',@obj.plotDrag);
            xlabel(obj.hWaveAxes, 'Time (s)');
            ylabel(obj.hWaveAxes, 'Position (V)');
            obj.hWaveAxesDetail = most.idioms.axes(common{:},'Color',[.95 .95 1],'ButtonDownFcn',@obj.plotDrag,'YTickLabel',[]);
            obj.hWaveAxesDetailOutline = most.idioms.axes('parent',obj.hPanel,'box','on','xgrid','off','ygrid','off','Color','none','XTick',[],'YTick',[],'LineWidth',3,'hittest','off');
            
            obj.hErrorAxes = most.idioms.axes(common{:});
            xlabel(obj.hErrorAxes, 'Time (s)');
            ylabel(obj.hErrorAxes, 'Error (V)');
            obj.hErrorAxesDetail = most.idioms.axes(common{:},'Color',[.95 .95 1],'YTickLabel',[],'ButtonDownFcn',@obj.plotDrag,'YTickLabel',[]);
            obj.hErrorAxesDetailOutline = most.idioms.axes('parent',obj.hPanel,'box','on','xgrid','off','ygrid','off','Color','none','XTick',[],'YTick',[],'LineWidth',3,'hittest','off');
            
            obj.hHistoryAxes = most.idioms.axes('parent',obj.hPanel,'box','on','xgrid','on','ygrid','on','LineWidth',1,'YScale','log');
            title(obj.hHistoryAxes, 'Optimization History');
            ylabel(obj.hHistoryAxes, 'RMS Error (V)');
            xlabel(obj.hHistoryAxes, 'Iteration Number');
            
            %% Plot lines
            dColor = obj.desWvfmColors{1};
            oColor = [0.9412 0.5098 0.2353];
            fColor = 'r';
            obj.hOutputLine = line('parent',obj.hWaveAxes,'color',oColor,'linewidth',2,'linestyle','--','visible','off','DisplayName','Output Signal','hittest','off');
            obj.hOutputDetailLine = line('parent',obj.hWaveAxesDetail,'color',oColor,'linewidth',2,'linestyle','--','visible','off','hittest','off');
            obj.hDesiredLine = line('parent',obj.hWaveAxes,'color',dColor,'linewidth',1.5,'visible','off','DisplayName','Desired Position','hittest','off');
            obj.hDesiredDetailLine = line('parent',obj.hWaveAxesDetail,'color',dColor,'linewidth',1.5,'visible','off','hittest','off');
            obj.hFeedbackLine = line('parent',obj.hWaveAxes,'color',fColor,'linewidth',1,'visible','off','DisplayName','Actual Feedback','hittest','off');
            obj.hFeedbackDetailLine = line('parent',obj.hWaveAxesDetail,'color',fColor,'linewidth',1,'visible','off','hittest','off');
            obj.hErrorLine = line('parent',obj.hErrorAxes,'color','b','linewidth',1.5,'visible','off','hittest','off');
            obj.hErrorDetailLine = line('parent',obj.hErrorAxesDetail,'color','b','linewidth',1.5,'visible','off','hittest','off');
            obj.hHistoryLine = line('parent',obj.hHistoryAxes,'color','b','linewidth',2,'visible','off','hittest','off');
            obj.hHistoryLinePts = line('parent',obj.hHistoryAxes,'color','b','linestyle','none','Marker','.','MarkerSize',36,'visible','off','hittest','off');
            obj.hHistoryMarker = line('parent',obj.hHistoryAxes,'color','k','linestyle','none','Marker','o','MarkerSize',16,'linewidth',2,'visible','off','uicontextmenu',obj.hWaveGui.hHistoryMenu,'UserData',obj);
            
            obj.hWaveEndLines = line('parent',obj.hWaveAxes,'color','k','linewidth',1,'linestyle','--','xdata',[0 0 nan 0 0],'ydata',ones(1,5),'zdata',ones(1,5),'visible','off');
            obj.hWaveEndLinesDetail = line('parent',obj.hWaveAxesDetail,'color','k','linewidth',1,'linestyle','--','xdata',[0 0 nan 0 0],'ydata',ones(1,5),'zdata',ones(1,5),'visible','off');
            obj.hErrorEndLines = line('parent',obj.hErrorAxes,'color','k','linewidth',1,'linestyle','--','xdata',[0 0 nan 0 0],'ydata',ones(1,5),'zdata',ones(1,5),'visible','off');
            obj.hErrorEndLinesDetail = line('parent',obj.hErrorAxesDetail,'color','k','linewidth',1,'linestyle','--','xdata',[0 0 nan 0 0],'ydata',ones(1,5),'zdata',ones(1,5),'visible','off');
            
            %% Detail view objects
            obj.hWaveDetailSurf = surface('parent',obj.hWaveAxes,'xdata',ones(2),'ydata',ones(2),'zdata',zeros(2),'FaceAlpha',.05,'FaceColor','b','linestyle','none','visible','off','ButtonDownFcn',@obj.detailDrag);
            obj.hWaveDetailLine1 = line('parent',obj.hWaveAxes,'color','k','linewidth',1.2,'linestyle','--','xdata',ones(1,2),'ydata',ones(1,2),'zdata',ones(1,2),'visible','off','ButtonDownFcn',@obj.detailDrag);
            obj.hWaveDetailLine2 = line('parent',obj.hWaveAxes,'color','k','linewidth',1.2,'linestyle','--','xdata',ones(1,2),'ydata',ones(1,2),'zdata',ones(1,2),'visible','off','ButtonDownFcn',@obj.detailDrag);
            
            obj.hErrorDetailSurf = surface('parent',obj.hErrorAxes,'xdata',ones(2),'ydata',ones(2),'zdata',zeros(2),'FaceAlpha',.05,'FaceColor','b','linestyle','none','visible','off','ButtonDownFcn',@obj.detailDrag);
            obj.hErrorDetailLine1 = line('parent',obj.hErrorAxes,'color','k','linewidth',1.2,'linestyle','--','xdata',ones(1,2),'ydata',ones(1,2),'zdata',ones(1,2),'visible','off','ButtonDownFcn',@obj.detailDrag);
            obj.hErrorDetailLine2 = line('parent',obj.hErrorAxes,'color','k','linewidth',1.2,'linestyle','--','xdata',ones(1,2),'ydata',ones(1,2),'zdata',ones(1,2),'visible','off','ButtonDownFcn',@obj.detailDrag);

            %% Other GUI elements
            obj.pbShowDetail = uicontrol('parent',obj.hPanel,'String','Hide Detail View','callback',@obj.toggleDetailView);
            
            obj.hTopFlow = most.gui.uiflowcontainer('parent',obj.hPanel,'flowdirection','lefttoright','BackgroundColor','w','margin',0.0001);
            most.gui.staticText('parent',obj.hTopFlow,'string',[waveformName ' Waveform'],'fontsize',10,'fontweight','b','backgroundcolor','w');
            
            topRightFlow = most.gui.uiflowcontainer('parent',obj.hTopFlow,'flowdirection','righttoleft','BackgroundColor','w','WidthLimits',sum([unitOptions{2:2:end}])+80);
            obj.positionUnits = lower(unitOptions{1});
            for i = (numel(unitOptions)/2):-1:1
                un = strsplit(unitOptions{i*2-1});
                most.gui.uicontrol('parent',topRightFlow,'string',unitOptions{i*2-1},'style','togglebutton','Bindings',{obj 'positionUnits' 'match' lower(un{end})},'WidthLimits',unitOptions{i*2});
            end
            most.gui.staticText('parent',topRightFlow,'string','Output Units:','backgroundcolor','w','horizontalalignment','right');
            
            obj.hProgressFlow = most.gui.uiflowcontainer('parent',obj.hWaveGui.hStatusFlow,'flowdirection','lefttoright','visible','off');
            obj.hProgressText = most.gui.staticText('parent',obj.hProgressFlow,'string',['Optimizing ' waveformName ':'],'WidthLimits',100);
            hPrP = most.gui.uipanel('Parent',obj.hProgressFlow,'Bordertype','none');
            a = most.idioms.axes('parent',hPrP,'xlim',[0 1],'ylim',[0 1],'xtick',[],'ytick',[],'units','normalized','position',[0 0 1 1],'box','on','Layer','top','linewidth',2);
            obj.hProgressSurf = surface('parent',a,'xdata',zeros(2),'ydata',[0 0;1 1],'zdata',-1*ones(2),'facecolor',most.constants.Colors.vidrioBlue,'edgecolor','none');
            
            obj.volts2Func = @(v)v;
            
            obj.hPanel.SizeChangedFcn = @obj.resize;
            obj.resize();
        end
    end
    
    methods
        function updatePlotData(obj,desired,output,feedback)
            if nargin < 2
                desired = obj.desiredWaveform;
            end
            if nargin < 3
                output = obj.outputWaveform;
            end
            if nargin < 4
                feedback = obj.feedbackWaveform;
            end
            
            if isempty(obj.desiredWaveformMap)
                desired = obj.volts2Func(desired);
                output = obj.volts2Func(output);
                feedback = obj.volts2Func(feedback);
            else
                desired = obj.desiredWaveformMap(obj.positionUnits);
            end
            
            doPlot = ~isempty(desired);
            if doPlot
                Ndes = size(desired,2); % only beams will have more than 1 waveform in a single plot
                while numel(obj.hDesiredLine) < Ndes
                    colori = obj.desWvfmColors{mod(numel(obj.hDesiredLine),numel(obj.desWvfmColors))+1};
                    obj.hDesiredLine(end+1) = line('parent',obj.hWaveAxes,'color',colori,'linewidth',1.5,'visible','on','DisplayName','Desired Position','hittest','off');
                    obj.hDesiredDetailLine(end+1) = line('parent',obj.hWaveAxesDetail,'color',colori,'linewidth',1.5,'visible','on','hittest','off');
                end
                delete(obj.hDesiredLine(Ndes+1:end));
                delete(obj.hDesiredDetailLine(Ndes+1:end));
                
                for i = 1:Ndes
                    set([obj.hDesiredLine(i) obj.hDesiredDetailLine(i)], 'YData', repmat(desired(:,i),3,1));
                    
                    if Ndes > 1
                        obj.hDesiredLine(i).DisplayName = sprintf('Beam %d',i);
                    end
                end
                
                alldat = [desired(:)' output(:)' feedback(:)'];
                mx = max(alldat);
                mn = min(alldat);
                rg = diff([mn mx]);
                if rg == 0
                    rg = 2.3;
                end
                obj.vMaxLims = [mn mx] + .1*rg*[-1 1];
                obj.vLim = obj.vLim;
            end
            
            doOpPlot = doPlot && ~isempty(output);
            if doOpPlot
                set([obj.hOutputLine obj.hOutputDetailLine], 'YData', repmat(output,3,1));
            end
            
            doFbPlot = obj.hasFdbk;
            if doFbPlot
                errorWvfm = feedback-desired;
                set([obj.hFeedbackLine obj.hFeedbackDetailLine], 'YData', repmat(feedback,3,1));
                set([obj.hErrorLine obj.hErrorDetailLine], 'YData', repmat(errorWvfm,3,1));
                
                mx = max(errorWvfm);
                mn = min(errorWvfm);
                rg = diff([mn mx]);
                if isnan(rg)
                    ylims = [-.01 .01];
                else
                    if rg == 0
                        rg = 2.3;
                    end
                    ylims = [mn mx] + .1*rg*[-1 1];
                end
                obj.hErrorAxes.YLim = ylims;
                obj.hErrorAxesDetail.YLim = ylims;
                
                obj.hErrorDetailSurf.YData = repmat(ylims',1,2);
                obj.hErrorDetailLine1.YData = ylims;
                obj.hErrorDetailLine2.YData = ylims;
                set([obj.hErrorEndLines obj.hErrorEndLinesDetail], 'YData', [ylims nan ylims]);
            end
            
            if doPlot
                lobjs = [obj.hDesiredLine obj.hOutputLine obj.hFeedbackLine];
                legend(obj.hWaveAxes,lobjs([true(size(obj.hDesiredLine)) ~isempty(obj.outputWaveform) obj.hasFdbk]),'Location','northwest');
            else
                legend(obj.hWaveAxes,'hide');
            end
        end
        
        function updateDisplay(obj)
            obj.updateVisibility();
            obj.resize();
            
            doPlot = ~isempty(obj.desiredWaveform);
            if doPlot
                N = size(obj.desiredWaveform,1);
                obj.T = (N-1)/obj.sampleRateHz;
                
                Ts = 1/obj.sampleRateHz;
                tt = Ts*(0:(N-1))';
                tt = [(tt-obj.T-Ts); tt; (tt+obj.T+Ts)];
                
                obj.tLims = [-obj.T*.05 1.05*obj.T];
                obj.tDetail = obj.tDetail;
                
                set([obj.hDesiredLine obj.hDesiredDetailLine obj.hOutputLine obj.hOutputDetailLine...
                    obj.hFeedbackLine obj.hFeedbackDetailLine obj.hErrorLine obj.hErrorDetailLine], 'XData', tt);
                set([obj.hWaveEndLines obj.hWaveEndLinesDetail obj.hErrorEndLines obj.hErrorEndLinesDetail], 'XData', [zeros(1,2) nan obj.T*ones(1,2)]);
            end
            
            obj.updateFrameLines();
            obj.updatePlotData();
            obj.updateHistoryDisplay();
        end
        
        function updateFrameLines(obj)
            most.idioms.safeDeleteObj(obj.hFrameStartLines);
            most.idioms.safeDeleteObj(obj.hFrameStopLines);
            most.idioms.safeDeleteObj(obj.hFrameStartLinesDetails);
            most.idioms.safeDeleteObj(obj.hFrameStopLinesDetails);
            
            if ~strcmp(obj.hTabParent.Title, 'Fast Z')
                return;
            end
            
            framePeriod = obj.hWaveGui.hModel.hRoiManager.scanFramePeriod;
            frameFlyback = obj.hWaveGui.hModel.hScan2D.flybackTimePerFrame;
            
            frameScanTime = framePeriod - frameFlyback;
            
            framesPerSlice =  obj.hWaveGui.hModel.hStackManager.framesPerSlice;
            numSlices =  obj.hWaveGui.hModel.hSI.hStackManager.numSlices;
            
            totalFramesPerStack = framesPerSlice*numSlices;
            
            startTimes = [0:totalFramesPerStack-1]*framePeriod;
            endTimes = ([1:totalFramesPerStack]*framePeriod)-frameFlyback;
            
            temp = [];
            for i = 1:numel(startTimes)
                v = startTimes(i);
                v = [v v nan];
                if isempty(temp)
                    temp = v;
                else
                    temp = [temp v];
                end
            end
            startTimes = temp;
            
            temp = [];
            for i = 1:numel(endTimes)
                v = endTimes(i);
                v = [v v nan];
                if isempty(temp)
                    temp = v;
                else
                    temp = [temp v];
                end
            end
            endTimes = temp;
            
%             startTimes = sort(repmat(startTimes,1,2));
%             endTimes = sort(repmat(endTimes,1,2));
            
            yData = repmat([-100 100 nan], 1, numel(startTimes)/3);
            
            obj.hFrameStartLines = line(obj.hWaveAxes,'XData', startTimes, 'YData', yData, 'Color', 'Green', 'LineStyle', '--');
            obj.hFrameStopLines = line(obj.hWaveAxes,'XData', endTimes, 'YData', yData, 'Color', 'red', 'LineStyle', '--');
            
            obj.hFrameStartLinesDetails = line(obj.hWaveAxesDetail,'XData', startTimes, 'YData', yData, 'Color', 'Green', 'LineStyle', '--');
            obj.hFrameStopLinesDetails = line(obj.hWaveAxesDetail,'XData', endTimes, 'YData', yData, 'Color', 'red', 'LineStyle', '--');
        end
        
        function updateHistoryDisplay(obj)
            if ~isempty(obj.optimizationHistory) && ~isempty(obj.optimizationHistory.errors)
                N = numel(obj.optimizationHistory.errors);
                obj.hHistoryAxes.XTick = 1:10;
                set([obj.hHistoryLine obj.hHistoryLinePts], 'XData',1:N);
                set([obj.hHistoryLine obj.hHistoryLinePts], 'YData',obj.optimizationHistory.errors);
                xlim(obj.hHistoryAxes, [.8 8.2]);
                
                mn = min(obj.optimizationHistory.errors);
                mx = max(obj.optimizationHistory.errors);
                ylim(obj.hHistoryAxes, [mn mx] .* [.5 1.5]);
            end
            obj.historySel = obj.historySel;
        end
        
        function resize(obj,varargin)
            if obj.hWaveGui.hTabGroup.SelectedTab == obj.hTabParent || (nargin < 2)
                obj.hPanel.Units = 'pixels';
                sz = obj.hPanel.Position([3 4]);
                
                showHistory = ~isempty(obj.optimizationHistory);
                showError = obj.hasFdbk || showHistory;
                
                plotAreaMarginL = 90;
                plotAreaMarginR = 30;
                plotAreaMarginW_total = plotAreaMarginL + plotAreaMarginR;
                plotAreaMarginV = 60;
                titleGap = 60 * showHistory;
                topH = 32;
                
                plotSizeX = sz(1) - plotAreaMarginW_total;
                detailSizeX = plotSizeX * .3;
                detailActualSizeX = obj.showDetailView * detailSizeX;
                mainSizeX = plotSizeX - detailActualSizeX;
                
                plotSizeY = sz(2) - plotAreaMarginV * 2;
                optHistorySizeY = showHistory * (plotSizeY * .2 - titleGap);
                errorSizeY = showError * (plotSizeY * .2);
                mainSizeY = plotSizeY - optHistorySizeY - errorSizeY - titleGap;
                
                obj.hWaveAxes.Units = 'pixels';
                obj.hWaveAxes.Position = [plotAreaMarginL (sz(2)-plotAreaMarginV-mainSizeY) mainSizeX mainSizeY];
                obj.hWaveAxesDetail.Units = 'pixels';
                obj.hWaveAxesDetail.Position = [plotAreaMarginL+mainSizeX (sz(2)-plotAreaMarginV-mainSizeY) detailActualSizeX mainSizeY];
                obj.hWaveAxesDetailOutline.Units = 'pixels';
                obj.hWaveAxesDetailOutline.Position = [plotAreaMarginL+mainSizeX (sz(2)-plotAreaMarginV-mainSizeY) detailActualSizeX mainSizeY];
                
                obj.hErrorAxes.Units = 'pixels';
                obj.hErrorAxes.Position = [plotAreaMarginL (sz(2)-plotAreaMarginV-mainSizeY-errorSizeY) mainSizeX errorSizeY];
                obj.hErrorAxesDetail.Units = 'pixels';
                obj.hErrorAxesDetail.Position = [plotAreaMarginL+mainSizeX (sz(2)-plotAreaMarginV-mainSizeY-errorSizeY) detailActualSizeX errorSizeY];
                obj.hErrorAxesDetailOutline.Units = 'pixels';
                obj.hErrorAxesDetailOutline.Position = [plotAreaMarginL+mainSizeX (sz(2)-plotAreaMarginV-mainSizeY-errorSizeY) detailActualSizeX errorSizeY];
                
                obj.hHistoryAxes.Units = 'pixels';
                obj.hHistoryAxes.Position = [plotAreaMarginL plotAreaMarginV plotSizeX optHistorySizeY];
                
                obj.pbShowDetail.Units = 'pixels';
                obj.pbShowDetail.Position = [plotAreaMarginL+plotSizeX-detailSizeX sz(2)-plotAreaMarginV+2 detailSizeX+1 topH];
                
                obj.hTopFlow.Units = 'pixels';
                obj.hTopFlow.Position = [plotAreaMarginL sz(2)-plotAreaMarginV+2 plotSizeX-detailSizeX topH];

                obj.hWaveGui.hStatusFlow.Units = 'pixels';
                set(obj.hProgressFlow, 'WidthLimits', (obj.hWaveGui.hStatusFlow.Position(3)/3)*ones(1,2));
            end
        end
        
        function updateVisibility(obj)
            showDesired = ~isempty(obj.desiredWaveform);
            showOutput = showDesired && ~isempty(obj.outputWaveform);
            showError = showDesired && obj.hasFdbk;
            showHistory = showDesired && ~isempty(obj.optimizationHistory);
            showHistoryPlots = showHistory && ~isempty(obj.optimizationHistory.errors);
            showErrorAxes = showDesired && (showError || showHistory);
            
            set([obj.hWaveAxesDetail obj.hWaveAxesDetail.Children(:)' obj.hWaveAxesDetailOutline], 'Visible', obj.hWaveGui.tfMap(obj.showDetailView));
            set([obj.hErrorAxes obj.hErrorAxes.Children(:)'], 'Visible', obj.hWaveGui.tfMap(showErrorAxes));
            set([obj.hErrorAxesDetail obj.hErrorAxesDetail.Children(:)' obj.hErrorAxesDetailOutline], 'Visible', obj.hWaveGui.tfMap(obj.showDetailView && showErrorAxes));
            set([obj.hHistoryAxes obj.hHistoryAxes.Children(:)'], 'Visible', obj.hWaveGui.tfMap(showHistory));
            
            set([obj.hWaveDetailSurf obj.hWaveDetailLine1 obj.hWaveDetailLine2], 'Visible', obj.hWaveGui.tfMap(obj.showDetailView && showDesired));
            set([obj.hErrorDetailSurf obj.hErrorDetailLine1 obj.hErrorDetailLine2], 'Visible', obj.hWaveGui.tfMap(obj.showDetailView && showErrorAxes && showDesired));
            
            set(obj.hWaveEndLines, 'Visible', obj.hWaveGui.tfMap(showDesired));
            set(obj.hWaveEndLinesDetail, 'Visible', obj.hWaveGui.tfMap(showDesired && obj.showDetailView));
            set(obj.hErrorEndLines, 'Visible', obj.hWaveGui.tfMap(showErrorAxes && showDesired));
            set(obj.hErrorEndLinesDetail, 'Visible', obj.hWaveGui.tfMap(showErrorAxes && showDesired && obj.showDetailView));
            
            set(obj.hDesiredLine, 'Visible', obj.hWaveGui.tfMap(showDesired));
            set(obj.hDesiredDetailLine, 'Visible', obj.hWaveGui.tfMap(showDesired && obj.showDetailView));
            
            obj.hOutputLine.Visible = obj.hWaveGui.tfMap(showOutput);
            obj.hOutputDetailLine.Visible = obj.hWaveGui.tfMap(showOutput && obj.showDetailView);
            
            obj.hFeedbackLine.Visible = obj.hWaveGui.tfMap(showError);
            obj.hFeedbackDetailLine.Visible = obj.hWaveGui.tfMap(showError && obj.showDetailView);
            obj.hErrorLine.Visible = obj.hWaveGui.tfMap(showError);
            obj.hErrorDetailLine.Visible = obj.hWaveGui.tfMap(showError && obj.showDetailView);
            
            obj.hHistoryLine.Visible = obj.hWaveGui.tfMap(showHistoryPlots);
            obj.hHistoryLinePts.Visible = obj.hWaveGui.tfMap(showHistoryPlots);
            
            obj.updateXTickLabels(true);
        end
        
        function toggleDetailView(obj,varargin)
            obj.showDetailView = ~obj.showDetailView;
            obj.updateVisibility();
            obj.resize();
        end
        
        function plotDrag(obj,src,evt)
            persistent dragV
            persistent dragT
            persistent hAx
            persistent pp
            persistent ot
            persistent otw
            persistent ov
            persistent ovw
            if strcmp(evt.EventName, 'Hit')
                if src == obj.hWaveAxes
                    % drag vlim only
                    dragV = 1;
                    dragT = 0;
                elseif src == obj.hWaveAxesDetail
                    % drag vlim and tdetail
                    dragV = 1;
                    dragT = 1;
                else
                    % drag tdetail only
                    dragV = 0;
                    dragT = 1;
                end
                ot = obj.tDetail;
                otw = diff(ot);
                ov = obj.vLim;
                ovw = diff(ov);
                hAx = src;
                pp = hAx.CurrentPoint(1,[1 2]);
                set(ancestor(hAx,'figure'),'WindowButtonUpFcn',@obj.plotDrag);
                obj.hWaveGui.mouseMotionFunc = @obj.plotDrag;
            elseif strcmp(evt.EventName, 'WindowMouseMotion')
                np = hAx.CurrentPoint(1,[1 2]);
                if dragT
                    obj.tDetail = maintiainWidth(obj.coercetDetail(obj.tDetail - np(1) + pp(1)),obj.tLims,otw);
                end
                if dragV
                    obj.vLim = maintiainWidth(obj.coerceVlim(obj.vLim - np(2) + pp(2)),obj.vMaxLims,ovw);
                end
                pp = hAx.CurrentPoint(1,[1 2]);
            else
                set(ancestor(hAx,'figure'),'WindowButtonUpFcn',[]);
                obj.hWaveGui.mouseMotionFunc = [];
            end
        end
        
        function detailDrag(obj,src,evt)
            persistent inds
            persistent hAx;
            persistent op
            persistent ow
            persistent ov
            if strcmp(evt.EventName, 'Hit')
                if any(src == [obj.hWaveDetailLine1 obj.hErrorDetailLine1])
                    inds = 1;
                elseif any(src == [obj.hWaveDetailLine2 obj.hErrorDetailLine2])
                    inds = 2;
                else
                    inds = [1 2];
                end
                hAx = src.Parent;
                op = hAx.CurrentPoint(1);
                ov = obj.tDetail;
                ow = diff(ov);
                set(ancestor(hAx,'figure'),'WindowButtonUpFcn',@obj.detailDrag);
                obj.hWaveGui.mouseMotionFunc = @obj.detailDrag;
            elseif strcmp(evt.EventName, 'WindowMouseMotion')
                v = ov;
                v(inds) = v(inds) + hAx.CurrentPoint(1) - op;
                v = obj.coercetDetail(v);
                if numel(inds) > 1
                    v = maintiainWidth(v,obj.tLims,ow);
                end
                obj.tDetail = v;
            else
                set(ancestor(hAx,'figure'),'WindowButtonUpFcn',[]);
                obj.hWaveGui.mouseMotionFunc = [];
            end
        end
        
        function historyHover(obj)
            [tf, pt] = mouseInAxes(obj.hHistoryAxes);
            if tf && ~isempty(obj.optimizationHistory) && ~isempty(obj.optimizationHistory.errors)
                N = numel(obj.optimizationHistory.errors);
                [x,ix] = min(abs(pt(1)-(1:N)));
                if (x < .2) && (abs(obj.optimizationHistory.errors(ix) / pt(2) - 1) < .25)
                    obj.showHistory(ix);
                end
            end
        end
        
        function showHistory(obj,v)
            obj.outputWaveform = obj.optimizationHistory.outputWaveforms(:,v);
            obj.feedbackWaveform = obj.optimizationHistory.feedbackWaveforms(:,v);
            obj.updatePlotData();
            obj.historySel = v;
        end
        
        function v = coercetDetail(obj,v)
            tol = diff(obj.tLims)*.0005;
            v(1) = min([max([v(1) obj.tLims(1)]) (obj.tLims(2)-tol)]);
            v(2) = min([max([v(2) (v(1)+tol)]) obj.tLims(2)]);
        end
        
        function v = coerceVlim(obj,v)
            tol = diff(obj.vMaxLims)*.001;
            v(1) = min([max([v(1) obj.vMaxLims(1)]) (obj.vMaxLims(2)-tol)]);
            v(2) = min([max([v(2) (v(1)+tol)]) obj.vMaxLims(2)]);
        end
        
        function scrollFunc(obj, evt)
            scrollSpeedConst = 1.2;
            if mouseInAxes(obj.hWaveAxes)
                scrollV();
            elseif mouseInAxes(obj.hWaveAxesDetail)
                keyMods = get(obj.hWaveGui.hFig, 'currentModifier');
                if ~ismember('shift',keyMods) && ~ismember('alt',keyMods)
                    scrollV();
                end
                if ~ismember('control',keyMods) && ~ismember('alt',keyMods)
                    scrollT();
                end
                if ismember('alt',keyMods)
                    ov = obj.tDetail;
                    rg = diff(ov);
                    obj.tDetail = maintiainWidth(obj.coercetDetail(ov + rg*(scrollSpeedConst-1)*sign(evt.VerticalScrollCount)),obj.tLims,rg);
                end
            elseif mouseInAxes(obj.hErrorAxesDetail)
                scrollT();
            end
            
            function scrollV()
                op = obj.hWaveAxes.CurrentPoint(1,2);
                ol = obj.vLim;
                rg = diff(ol);
                c = mean(ol);
                obj.vLim = c + scrollSpeedConst^evt.VerticalScrollCount * rg * [-.5 .5];
                np = obj.hWaveAxes.CurrentPoint(1,2);
                obj.vLim = obj.vLim + op - np;
            end
            
            function scrollT()
                op = obj.hWaveAxesDetail.CurrentPoint(1);
                ol = obj.tDetail;
                rg = diff(ol);
                c = mean(ol);
                obj.tDetail = c + scrollSpeedConst^evt.VerticalScrollCount * rg * [-.5 .5];
                np = obj.hWaveAxesDetail.CurrentPoint(1);
                obj.tDetail = obj.tDetail + op - np;
            end
        end
        
        function updateXTickLabels(obj,mainAxesToo)
            if nargin < 2
                mainAxesToo = false;
            end
            
            lblVs = obj.hWaveAxesDetail.XTick;
            [~,prefix,exponent] = most.idioms.engineersStyle(max(abs(lblVs)));
            lbls = cellfun(@num2str,num2cell(lblVs*10^-exponent),'UniformOutput',false);
            
            if obj.hasFdbk
                obj.hWaveAxesDetail.XTickLabel = [];
                obj.hErrorAxesDetail.XTickLabel = lbls;
            else
                obj.hWaveAxesDetail.XTickLabel = lbls;
            end
            xlabel(obj.hWaveAxesDetail, ['Time (' prefix 's)']);
            xlabel(obj.hErrorAxesDetail, ['Time (' prefix 's)']);
            
            if mainAxesToo
                lblVs = obj.hWaveAxes.XTick;
                [~,prefix,exponent] = most.idioms.engineersStyle(max(abs(lblVs)));
                lbls = cellfun(@num2str,num2cell(lblVs*10^-exponent),'UniformOutput',false);
                
                if obj.hasFdbk
                    obj.hWaveAxes.XTickLabel = [];
                    obj.hErrorAxes.XTickLabel = lbls;
                else
                    obj.hWaveAxes.XTickLabel = lbls;
                end

                xlabel(obj.hWaveAxes, ['Time (' prefix 's)']);
                xlabel(obj.hErrorAxes, ['Time (' prefix 's)']);
            end
        end
        
        function v = updateCallback(obj,varargin)
            if nargin == 1
                obj.hProgressFlow.Visible = 'on';
                obj.hProgressSurf.XData(:,2) = 0;
            elseif nargin > 1 && ischar(varargin{1}) && strcmp('done',varargin{1})
                obj.hProgressFlow.Visible = 'off';
                obj.hProgressSurf.XData(:,2) = 0;
                if nargin > 2
                    obj.feedbackWaveform = varargin{2};
                    obj.updatePlotData();
                end
            elseif nargin == 3 && ischar(varargin{1}) && strcmp('start',varargin{1})
                obj.desiredWaveform = varargin{2};
            elseif nargin == 4 && ischar(varargin{1}) && strcmp('start',varargin{1})
                obj.outputWaveform = varargin{3};
            elseif nargin == 3
                obj.hProgressSurf.XData(:,2) = varargin{1};
            elseif nargin == 4
                optimizedWaveformHistory = varargin{1};
                feedbackHistory = varargin{2};
                errRmsHistory = varargin{3};

                obj.optimizationHistory.outputWaveforms = optimizedWaveformHistory;
                obj.optimizationHistory.feedbackWaveforms = feedbackHistory;
                obj.optimizationHistory.errors = errRmsHistory;
                obj.showHistory(numel(errRmsHistory));
                obj.updateVisibility();
                obj.updateHistoryDisplay();
            end
            
            v = obj.hWaveGui.optCmd;
            
            if strcmp(v,'accept')
                obj.hWaveGui.optCmd = '';
            end
        end
        
        function use(obj)
            idx = obj.hHistoryMarker.XData;
            nfo = struct;
            nfo.numIterations = numel(obj.optimizationHistory.errors);
            nfo.feedbackVoltLUT = obj.hScanner.feedbackVoltLUT;
            oWvfm = obj.optimizationHistory.outputWaveforms(:,idx);
            fbWvfm = obj.optimizationHistory.feedbackWaveforms(:,idx);
            obj.hScanner.cacheOptimizedWaveform(obj.sampleRateHz,obj.desiredWaveform,oWvfm,fbWvfm,[],nfo);
        end
    end
    
    %% Prop access
    methods
        function set.showDetailView(obj,v)
            obj.showDetailView = v;
            if v
                obj.pbShowDetail.String = 'Hide Detail View';
            else
                obj.pbShowDetail.String = 'Show Detail View';
            end
        end
        
        function set.visible(obj,v)
            obj.hPanel.Visible = obj.hWaveGui.tfMap(v);
        end
        
        function v = get.visible(obj)
            v = strcmp(obj.hPanel.Visible, 'on');
        end
        
        function set.positionUnits(obj, v)
            obj.positionUnits = v;
            switch v
                case 'voltage'
                    ylabel(obj.hWaveAxes, [obj.positionName ' (V)']);
                    ylabel(obj.hErrorAxes, [obj.positionName ' Error (V)']);
                case 'angle'
                    ylabel(obj.hWaveAxes, [obj.positionName ' (deg)']);
                    ylabel(obj.hErrorAxes, [obj.positionName ' Error (deg)']);
                case 'microns'
                    ylabel(obj.hWaveAxes, [obj.positionName ' (um)']);
                    ylabel(obj.hErrorAxes, [obj.positionName ' Error (um)']);
                case 'power'
                    ylabel(obj.hWaveAxes, [obj.positionName ' (%)']);
                    ylabel(obj.hErrorAxes, [obj.positionName ' Error (%)']);
            end
            
            try
                obj.volts2Func = obj.volts2FuncMap(v);
            catch
                obj.volts2Func = @(v)v;
            end
            
            pv = obj.vLim;
            pv = (pv - obj.vMaxLims(1)) ./ diff(obj.vMaxLims);
            obj.updatePlotData();
            
            if strcmp(v,'power')
                obj.vLim = inf*[-1 1];
            else
                obj.vLim = obj.vMaxLims(1) + diff(obj.vMaxLims) .* pv;
            end
        end
        
        function set.tDetail(obj,v)
            v = obj.coercetDetail(v);
            obj.tDetail = v;

            obj.hWaveDetailSurf.XData = repmat(v,2,1);
            obj.hWaveDetailLine1.XData = repmat(v(1),1,2);
            obj.hWaveDetailLine2.XData = repmat(v(2),1,2);

            obj.hErrorDetailSurf.XData = repmat(v,2,1);
            obj.hErrorDetailLine1.XData = repmat(v(1),1,2);
            obj.hErrorDetailLine2.XData = repmat(v(2),1,2);
            
            obj.hWaveAxesDetail.XLim = v;
            obj.hErrorAxesDetail.XLim = v;
            obj.updateXTickLabels();
        end
        
        function set.vLim(obj,v)
            v = obj.coerceVlim(v);
            obj.vLim = v;
            
            obj.hWaveAxes.YLim = v;
            obj.hWaveAxesDetail.YLim = v;
        end
        
        function set.tLims(obj,v)
            obj.tLims = v;
            
            obj.hWaveAxes.XLim = v;
            obj.hErrorAxes.XLim = v;
            obj.updateXTickLabels(true);
        end
        
        function set.vMaxLims(obj,v)
            obj.vMaxLims = v;
            
            set([obj.hWaveEndLines obj.hWaveEndLinesDetail], 'YData', [v nan v]);

            obj.hWaveDetailSurf.YData = repmat(v',1,2);
            obj.hWaveDetailLine1.YData = v;
            obj.hWaveDetailLine2.YData = v;
        end
        
        function v = get.hasFdbk(obj)
            v = ~isempty(obj.feedbackWaveform) && isequal(size(obj.desiredWaveform),size(obj.feedbackWaveform));
        end
        
        function set.historySel(obj,v)
            if ~isempty(obj.optimizationHistory) && ~isempty(obj.optimizationHistory.errors)
                v = min([v numel(obj.optimizationHistory.errors)]);
                obj.historySel = v;
                
                obj.outputWaveform = obj.optimizationHistory.outputWaveforms(:,v);
                obj.feedbackWaveform = obj.optimizationHistory.feedbackWaveforms(:,v);
                
                obj.hHistoryMarker.XData = v;
                obj.hHistoryMarker.YData = obj.optimizationHistory.errors(v);
                obj.hHistoryMarker.Visible = 'on';
            else
                obj.hHistoryMarker.Visible = 'off';
            end
        end
    end
end

function [tf, pt] = mouseInAxes(hAx)
    pt = hAx.CurrentPoint(1, 1:2);
    tf = (pt(1) >= hAx.XLim(1)) && (pt(1) <= hAx.XLim(2)) && (pt(2) >= hAx.YLim(1)) && (pt(2) <= hAx.YLim(2));
end

function newRange = maintiainWidth(newRange,limits,desiredWidth)
    if (abs(diff(newRange) - desiredWidth) > 0.0001*desiredWidth)
        if newRange(1) == limits(1)
            newRange(2) = limits(1)+desiredWidth;
        else
            newRange(1) = limits(2)-desiredWidth;
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
