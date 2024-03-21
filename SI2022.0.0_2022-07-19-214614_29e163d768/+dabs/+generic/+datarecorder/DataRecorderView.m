classdef DataRecorderView < matlab.apps.AppBase
    
    % Properties that correspond to app components
    properties (Access = public)
        Figure matlab.ui.Figure
        AnalogVisibilityPanel matlab.ui.container.Panel
        SelectAllCheckBox matlab.ui.control.UIControl
        LiveViewAxes matlab.graphics.axis.Axes
    end
    
    properties (Access = private, Constant)
        USE_MOCK_DEBUG_MODE = false;
        ANALOG_LIVE_VIEW_POINT_RESOLUTION = 600; % pixel width scaled up to neatly align ticks.
        ANALOG_LIVE_VIEW_ZOOM_LOWER_LIMIT = 10; % 10 samples is the minimum view range.
        ANALOG_LIVE_VIEW_YLIM_WIDTH_LOWER_LIMIT = 2;
    end
    
    properties (Access = private)
        AnalogLines(:,1) matlab.graphics.primitive.Line
        DigitalLines(:,1) matlab.graphics.primitive.Line
        DataRecorder(1,1)
        AnalogPanelRows(:,1) dabs.generic.datarecorder.gui.SelectablePanelRow
    end
    
    % zoom properties
    properties (Access = private)
        viewOffset(1,1) uint64 = 0 % sample index relative to the analog acquisition index.
        zoomSize(1,1) uint64 = 5 % view zoom magnitude in number of samples.
        pollTimer timer = timer.empty(1,0); % refresh the sample view at some rate.
        previousMouseXPosition(1,1) double = 0; % last recorded mouse position on the X Axis in pixel units.
        isPanningEnabled(1,1) logical = false; % flag indicating if the mouse button is held down while in the axes.
    end
    
    methods (Access = private)
        function refreshView(app)
            persistent previousYLimits;
            persistent cachedAnalogStartInd;
            
            app.LiveViewAxes.XLim = [0, (app.zoomSize-1)] + app.viewOffset;
            
            if 0 == app.DataRecorder.analogSampleIndex
                if isempty(cachedAnalogStartInd)
                    analogStartInd = 1;
                    cachedAnalogStartInd = 1;
                else
                    analogStartInd = cachedAnalogStartInd;
                end
            else
                analogStartInd = app.DataRecorder.analogSampleIndex;
                cachedAnalogStartInd = analogStartInd;
            end

            sampleRange = floor(linspace(0, double(app.zoomSize-1), ...
                app.ANALOG_LIVE_VIEW_POINT_RESOLUTION));
            sampleRange = sampleRange + double(app.viewOffset);
            
            yDataBuffer = zeros(size(sampleRange));
            
            sampleBufferSize = size(app.DataRecorder.sampleBuffer, 1);
            sampleBufferIndices = min(analogStartInd, sampleBufferSize) - sampleRange;
            bufferEndInd = app.DataRecorder.lastAnalogSampleIndex;
            if 0 < bufferEndInd && analogStartInd < bufferEndInd
                % check for negative values that happen to exceed
                % analogStartInd if started from the end of the circular buffer.
                % values which are still smaller than analogStartInd cannot be corrected and are
                % invalid.
                overflowedIndicesMask = sampleBufferIndices < 1 ...
                    & (sampleBufferIndices + bufferEndInd) > analogStartInd;
                sampleBufferIndices(overflowedIndicesMask) = bufferEndInd ...
                    + sampleBufferIndices(overflowedIndicesMask);
            end
            
            visibleLineIndices = find(strcmp(get(app.AnalogLines, 'Visible'), 'on')) .';
            validBufferIndexIndices = sampleBufferIndices > 0 ...
                & sampleBufferIndices <= sampleBufferSize;
            sampleBufferIndices = sampleBufferIndices(validBufferIndexIndices);
            yLimits = [inf -inf];
            for iAnalogChan = visibleLineIndices
                bufferChannelInd = app.DataRecorder.indexFromConfiguration( ...
                    app.DataRecorder.analogConfiguration(iAnalogChan));
                
                if ~isempty(app.DataRecorder.sampleBuffer)
                    yDataBuffer(validBufferIndexIndices) = app.DataRecorder.sampleBuffer( ...
                        sampleBufferIndices, bufferChannelInd);
                end
                [localYMin, localYMax] = bounds(yDataBuffer);
                yLimits(1) = min(yLimits(1), localYMin);
                yLimits(2) = max(yLimits(2), localYMax);
                set(app.AnalogLines(iAnalogChan), ...
                    'XData', sampleRange, ...
                    'YData', yDataBuffer);
            end

            if isempty(visibleLineIndices)
                return; % don't rescale YLim if no lines are visible.
            end

            yWidth = diff(yLimits);
            yHalf = yLimits(1) + (yWidth / 2);
            % when calculating expansion, check for lower limit.
            yWidth = max(yWidth, app.ANALOG_LIVE_VIEW_YLIM_WIDTH_LOWER_LIMIT);
            yWidthExpansion = yWidth * 1.1;
            yLimits = yHalf + ((yWidthExpansion / 2) * [-1, 1]);

            if isempty(previousYLimits)
                previousYLimits = yLimits;
            elseif any(previousYLimits ~= yLimits)
                yLimDiff = diff([previousYLimits; yLimits]);
                yLimDelta = yLimDiff / 4;

                for iBound = 1:2
                    if abs(yLimDelta(iBound)) <= 1e-2
                        previousYLimits(iBound) = yLimits(iBound);
                    else
                        previousYLimits(iBound) = previousYLimits(iBound) ...
                            + yLimDelta(iBound);
                    end
                end
            end
            app.LiveViewAxes.YLim = previousYLimits;
        end
        
        function refreshCheckboxVisibility(app)
            for iCheckbox = 1:length(app.AnalogPanelRows)
                if app.AnalogPanelRows(iCheckbox).Value
                    app.AnalogLines(iCheckbox).Visible = 'on';
                else
                    app.AnalogLines(iCheckbox).Visible = 'off';
                end
            end
        end
        
        function lineVisibilityCheckboxValueChanged(app, index, value)
            if value
                app.AnalogLines(index).Visible = 'on';
            else
                app.AnalogLines(index).Visible = 'off';
            end

            if all([app.AnalogPanelRows.Visible])
                app.SelectAllCheckBox.Value = 1;
            else
                app.SelectAllCheckBox.Value = 0;
            end
        end
        
        function populateAnalogPanels(app, names, colors)
            import dabs.generic.datarecorder.gui.SelectablePanelRow

            assert(iscellstr(names), 'analog panel names argument must be a cell array of strings');
            validateattributes(colors, {'numeric'}, {'ncols', 3, 'nrows', length(names)});
            
            % all units in pixels.
            rowMargin = 5;
            currentRowPosition = app.AnalogVisibilityPanel.Position(4);
            for i = 1:length(app.AnalogLines)
                currentRowPosition = currentRowPosition ...
                    - rowMargin ...
                    - SelectablePanelRow.ELEMENT_HEIGHT_MAX;
                app.AnalogPanelRows(i) = SelectablePanelRow(...
                    app.AnalogVisibilityPanel, ...
                    'CheckBoxFcn', @(src,~)app.lineVisibilityCheckboxValueChanged(i, src.Value),...
                    'XYPosition', [5 currentRowPosition],...
                    'Text', names{i},...
                    'RgbColor', colors(i,:));
            end
        end
    end
    
    methods (Access = public)
        function show(app)
            figure(app.Figure);
        end
    end
    
    % Callbacks that handle component events
    methods (Access = private)
        % Code that executes after component creation
        function startupFcn(app, DataRecorder)
            import dabs.generic.datarecorder.gui.getDistinctColors

            if ~app.USE_MOCK_DEBUG_MODE
                validateattributes(DataRecorder,...
                    {'dabs.generic.datarecorder.DataRecorder'}, {'scalar'});
            end
            
            % move figure to center of the screen.
            screenSize = get(0, 'ScreenSize');
            initialFigurePosition = (screenSize(3:4) - app.Figure.Position(3:4)) / 2;
            app.Figure.Position = [initialFigurePosition app.Figure.Position(3:4)];
            
            if ~verLessThan('MATLAB', '9.6')
                % AxesToolbar object introduced in R2018b
                % Toolbar property in UIAxes introduced in R2019a
                app.LiveViewAxes.Toolbar.Visible = 'off';
            end
            
            if ~verLessThan('MATLAB', '9.5')
                % R2018b UIAxes has default panning/zooming behavior
                % enabled.
                disableDefaultInteractivity(app.LiveViewAxes);
            end
            
            app.zoomSize = DataRecorder.chunkSize;
            app.DataRecorder = DataRecorder;
            
            % init plot and analog channel selection.
            numAnalogInputs = length(DataRecorder.analogConfiguration);
            colors = getDistinctColors(numAnalogInputs);
            channelNames = cell(numAnalogInputs, 1);
            
            hold(app.LiveViewAxes, 'on'); % allow multiline plot.
            sampleRange = round(linspace(0, double(app.zoomSize-1), ...
                app.ANALOG_LIVE_VIEW_POINT_RESOLUTION));
            for iAnalogChan = 1:numAnalogInputs
                % dabs.generic.datarecorder.ChannelConfiguration
                ChannelConfig = DataRecorder.analogConfiguration(iAnalogChan);
                app.AnalogLines(end+1) = line(app.LiveViewAxes,...
                    sampleRange, zeros(size(sampleRange)),...
                    'Color', colors(iAnalogChan, :));

                if ~isempty(ChannelConfig.unit)
                    name = sprintf('%s (%s)', ...
                        ChannelConfig.name, ...
                        ChannelConfig.unit);
                else
                    name = ChannelConfig.name;
                end

                if numel(name) > 16
                    name = ChannelConfig.name;
                    name(16:end) = '';
                    name = [name '...'];
                end
                channelNames{iAnalogChan} = name;
            end
            hold(app.LiveViewAxes, 'off');
            app.LiveViewAxes.YLim = [-1 1];
            app.populateAnalogPanels(channelNames, colors);
            
            app.pollTimer = timer(...
                'TimerFcn', @(~,~)app.refreshView(), ...
                'Period', round(1 / DataRecorder.CALLBACK_RATE, 3), ...
                'TasksToExecute', Inf, ...
                'ExecutionMode', 'fixedSpacing');
            start(app.pollTimer);
        end
        
        % Close request function: UIFigure
        function UIFigureCloseRequest(app, event)
            delete(app)
        end
        
        % Value changed function: SelectAllCheckBox
        function SelectAllCheckBoxValueChanged(app, event)
            set(app.VisibilityCheckboxes, 'Value', app.SelectAllCheckBox.Value);
            app.refreshCheckboxVisibility();
        end
        
        % Window button down function: UIFigure
        function UIFigureWindowButtonDown(app, event)
            mousePosition = app.Figure.CurrentPoint;
            axesPosition = app.LiveViewAxes.Position(1:2);
            axesTopRightCorner = axesPosition + app.LiveViewAxes.Position(3:4);
            if ~all(mousePosition >= axesPosition & mousePosition <= axesTopRightCorner)
                return;
            end
            app.isPanningEnabled = true;
            app.previousMouseXPosition = mousePosition(1);
        end
        
        % Window button motion function: UIFigure
        function UIFigureWindowButtonMotion(app, event)
            if ~app.isPanningEnabled
                return;
            end
            
            mouseXPosition = app.Figure.CurrentPoint(1);
            mouseXDelta = mouseXPosition - app.previousMouseXPosition;
            pixelToSample = double(app.zoomSize) / app.LiveViewAxes.Position(3);
            mouseXPixelDelta = round(mouseXDelta * pixelToSample);
            
            
            app.viewOffset = min(max(app.viewOffset + mouseXPixelDelta, 0), ...
                app.DataRecorder.chunkSize - app.zoomSize);
            
            app.previousMouseXPosition = mouseXPosition;
        end
        
        % Window button up function: UIFigure
        function UIFigureWindowButtonUp(app, event)
            app.isPanningEnabled = false;
        end
        
        % Window scroll wheel function: UIFigure
        function UIFigureWindowScrollWheel(app, event)
            verticalScrollAmount = event.VerticalScrollAmount;
            verticalScrollCount = event.VerticalScrollCount;
            verticalScrollValue = verticalScrollCount * verticalScrollAmount;
            % positive: scroll out
            % negative: scroll in
            
            mousePosition = app.Figure.CurrentPoint;
            axesBottomRight = app.LiveViewAxes.OuterPosition(1:2);
            axesTopRight = axesBottomRight + app.LiveViewAxes.OuterPosition(3:4);
            % check if mouse in axes.
            if ~all(mousePosition >= axesBottomRight & mousePosition <= axesTopRight)
                return;
            end
            
            mouseXPosition = mousePosition(1) - app.LiveViewAxes.Position(1);
            mouseXPosition = min(...
                max(mouseXPosition, 0), ...
                app.LiveViewAxes.Position(1) + app.LiveViewAxes.Position(3));
            mouseXNormal = 1 - mouseXPosition / app.LiveViewAxes.Position(3);
            mouseIndex = app.viewOffset + round(double(app.zoomSize) * mouseXNormal);
            
            sampleDeltaPerClick = double(app.zoomSize) / 10;
            app.zoomSize = app.zoomSize + round(sampleDeltaPerClick * verticalScrollValue);
            app.zoomSize = min(max(app.zoomSize, app.ANALOG_LIVE_VIEW_ZOOM_LOWER_LIMIT), ...
                app.DataRecorder.chunkSize);
            app.viewOffset = min(max(mouseIndex - (double(app.zoomSize) / 2), 0), ...
                app.DataRecorder.chunkSize - app.zoomSize);
        end
    
        % Window resize function: Figure
        function FigureWindowResize(app, event)
            checkBoxTopYOffset = 44;
            analogPanelXOffset = sum(app.AnalogVisibilityPanel.Position([1 3]));

            app.Figure.Position(3) = max(analogPanelXOffset + 300, app.Figure.Position(3));

            yMinimum = 30 ...
                + checkBoxTopYOffset ...
                + dabs.generic.datarecorder.gui.SelectablePanelRow.ELEMENT_HEIGHT_MAX;
            if ~isempty(app.AnalogPanelRows)
                startY = app.AnalogPanelRows(end).XYPosition(2);
                endY = app.AnalogPanelRows(1).XYPosition(2);
                yMinimum = yMinimum + diff([startY endY]);
            end
            app.Figure.Position(4) = max(yMinimum + 5, app.Figure.Position(4));
            FigureSize = app.Figure.Position(3:4);

            app.SelectAllCheckBox.Position(2) = FigureSize(2) - 44;
            app.AnalogVisibilityPanel.Position(4) = FigureSize(2) ...
                - checkBoxTopYOffset ...
                - app.AnalogVisibilityPanel.Position(2) ...
                + 1;
            
            app.LiveViewAxes.OuterPosition(1) = analogPanelXOffset + 5;
            app.LiveViewAxes.OuterPosition(2) = 30;
            app.LiveViewAxes.OuterPosition(3) = FigureSize(1) - analogPanelXOffset - 16;
            app.LiveViewAxes.OuterPosition(4) = FigureSize(2) - 52;
            app.LiveViewAxes.Position(1) = app.LiveViewAxes.OuterPosition(1) + 50;
            app.LiveViewAxes.Position(2) = 60;
            app.LiveViewAxes.Position(3) = app.LiveViewAxes.OuterPosition(3) - 50;
            app.LiveViewAxes.Position(4) = app.LiveViewAxes.OuterPosition(4) - 30;

            rowMargin = 5;
            currentRowOffset = app.AnalogVisibilityPanel.Position(4);
            for iRow = 1:length(app.AnalogPanelRows)
                PanelRow = app.AnalogPanelRows(iRow);
                currentRowOffset = currentRowOffset - PanelRow.ELEMENT_HEIGHT_MAX - rowMargin;

                % the default property validation doesn't consider
                % individually indexed setters (i.e. .XYPosition(2) = 1
                % won't work).
                PanelRow.XYPosition = [PanelRow.XYPosition(1) currentRowOffset];
            end
        end
    end

    
    % Component initialization
    methods (Access = private)
        
        % Create UIFigure and components
        function createComponents(app)
            
            % Create UIFigure and hide until all components are created
            app.Figure = figure('Visible', 'off');
            app.Figure.Units = 'pixels';
            app.Figure.DockControls = 'off';
            app.Figure.MenuBar = 'none';
            app.Figure.ToolBar = 'none';
            app.Figure.NumberTitle = 'off';
            app.Figure.Position = [100 100 885 502];
            app.Figure.Name = 'Data Recorder Live View';
            app.Figure.Resize = 'on';
            app.Figure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);
            app.Figure.WindowButtonDownFcn = createCallbackFcn(app, @UIFigureWindowButtonDown, true);
            app.Figure.WindowButtonUpFcn = createCallbackFcn(app, @UIFigureWindowButtonUp, true);
            app.Figure.WindowButtonMotionFcn = createCallbackFcn(app, @UIFigureWindowButtonMotion, true);
            app.Figure.WindowScrollWheelFcn = createCallbackFcn(app, @UIFigureWindowScrollWheel, true);
            app.Figure.SizeChangedFcn = createCallbackFcn(app, @FigureWindowResize, true);
            
            % Create UIAxes
            app.LiveViewAxes = axes(app.Figure);
            app.LiveViewAxes.Units = 'pixels';
            title(app.LiveViewAxes, 'Analog Inputs')
            xlabel(app.LiveViewAxes, 'Samples')
            ylabel(app.LiveViewAxes, 'Units')
            zlabel(app.LiveViewAxes, 'Z')
            app.LiveViewAxes.XDir = 'reverse';
            app.LiveViewAxes.XGrid = 'on';
            app.LiveViewAxes.YGrid = 'on';
            app.LiveViewAxes.XLimMode = 'manual';
            app.LiveViewAxes.YLimMode = 'manual';
            app.LiveViewAxes.Box = 'on';
            app.LiveViewAxes.OuterPosition = [262 30 601 450];
            app.LiveViewAxes.Position = [312 60 551 420];

            
            % Create SelectAllCheckBox
            app.SelectAllCheckBox = uicontrol('Style', 'checkbox');
            app.SelectAllCheckBox.Units = 'pixels';
            app.SelectAllCheckBox.Callback = createCallbackFcn(app, @SelectAllCheckBoxValueChanged, true);
            app.SelectAllCheckBox.String = 'Select All';
            app.SelectAllCheckBox.Position = [29 458 71 22];
            app.SelectAllCheckBox.Value = true;
            
            % Create AnalogVisibilityPanel
            app.AnalogVisibilityPanel = uipanel(app.Figure);
            app.AnalogVisibilityPanel.Units = 'pixels';
            app.AnalogVisibilityPanel.Position = [30 30 232 429];
            
            % Show the figure after all components are created
            app.Figure.Visible = 'on';
        end
    end
    
    % App creation and deletion
    methods (Access = public)
        
        % Construct app
        function app = DataRecorderView(varargin)
            
            % Create UIFigure and components
            createComponents(app)
            
            % Register the app with App Designer
            registerApp(app, app.Figure)
            
            % Execute the startup function
            runStartupFcn(app, @(app)startupFcn(app, varargin{:}))
            
            if nargout == 0
                clear app
            end
        end
        
        % Code that executes before app deletion
        function delete(app)
            if isvalid(app.pollTimer)
                stop(app.pollTimer);
            end
            delete(app.pollTimer);
            % Delete UIFigure when app is deleted
            delete(app.Figure)
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
