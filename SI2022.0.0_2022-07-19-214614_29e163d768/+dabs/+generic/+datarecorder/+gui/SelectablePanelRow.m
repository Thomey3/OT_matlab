classdef SelectablePanelRow < handle
    %SELECTABLEPANELROW Summary of this class goes here
    %   Detailed explanation goes here

    properties (Constant)
        ELEMENT_HEIGHT_MAX = 20;
        ELEMENT_COLUMN_MARGIN = 5;
    end
    
    properties (SetAccess = private)
        ParentPanel(1,1) matlab.ui.container.Panel
        CheckBox(1,1) matlab.ui.control.UIControl
        Label(1,1) matlab.ui.control.UIControl
        PreviewLineAxes(1,1) matlab.graphics.axis.Axes
        PreviewLine(1,1) matlab.graphics.primitive.Line
    end

    properties (Dependent)
        CheckBoxFcn function_handle
        XYPosition(1,2) double
        RgbColor(1,3) double
        Text(1,:) char
        IsChecked(1,1) logical
    end

    methods (Access = private)
        function constructGui(obj)
            xOffset = 0;
            
            % initialize and listen to checkbox
            checkBoxWidth = 15;
            obj.CheckBox = uicontrol(obj.ParentPanel,...
                'Units', 'pixels',...
                'Style', 'checkbox',...
                'Value', 1,... % always start checked.
                'Position', [xOffset 0 checkBoxWidth obj.ELEMENT_HEIGHT_MAX]);
            xOffset = xOffset + checkBoxWidth + obj.ELEMENT_COLUMN_MARGIN;

            % set name label
            labelWidth = 100;
            obj.Label = uicontrol(obj.ParentPanel, ...
                'Units', 'pixels', ...
                'Style', 'text', ...
                'Position', [xOffset 0 labelWidth obj.ELEMENT_HEIGHT_MAX]);
            xOffset = xOffset + labelWidth + obj.ELEMENT_COLUMN_MARGIN;

            % draw line color.
            obj.PreviewLineAxes = axes(obj.ParentPanel, ...
                'Units', 'pixels', ...
                'XTickLabel', [], ...
                'XLim', [0 1],'YLim', [0 1], ...
                'XColor', 'none','YColor', 'none', ...
                'GridLineStyle', 'none',...
                'Color', 'none', ...
                'SelectionHighlight', 'off', ...
                'Position', [xOffset 0 80 obj.ELEMENT_HEIGHT_MAX]);
            if isprop(obj.PreviewLineAxes, 'Toolbar')
                obj.PreviewLineAxes.Toolbar.Visible = 'off';
            end
            if ~verLessThan('MATLAB', '9.5')
                % disable default user panning/scrolling.
                disableDefaultInteractivity(obj.PreviewLineAxes); 
            end

            obj.PreviewLine = line(obj.PreviewLineAxes, ...
                'XData', [0 1], ...
                'YData', [0.5 0.5], ...
                'LineWidth', 3);
        end
    end
    
    methods
        function obj = SelectablePanelRow(Panel, varargin)
            obj.ParentPanel = Panel;

            % constructGui must be called here as dependent assignments
            % rely on gui components being constructed.
            obj.constructGui();

            p = inputParser;
            p.addParameter('CheckBoxFcn', @noOp, ...
                @(f)validateattributes(f, {'function_handle'}, {'scalar'}));
            p.addParameter('XYPosition', [0, 0], ...
                @(p)validateattributes(p, {'numeric'}, {'vector', 'numel', 2}));
            p.addParameter('Text', 'checkbox panel row default string', ...
                @(s)validateattributes(s, {'char'}, {'scalartext'}));
            p.addParameter('RgbColor', [0 0 0], ...
                @(c)validateattributes(c, {'numeric'}, {'vector', 'numel', 3}));
            p.parse(varargin{:});

            obj.CheckBoxFcn = p.Results.CheckBoxFcn;
            obj.XYPosition = p.Results.XYPosition;
            obj.RgbColor = p.Results.RgbColor;
            obj.Text = p.Results.Text;
        end
    end

    methods %set/get
        function f = get.CheckBoxFcn(obj)
            f = obj.CheckBox.Callback;
        end

        function set.CheckBoxFcn(obj, f)
            obj.CheckBox.Callback = f;
        end

        function p = get.XYPosition(obj)
            width = sum(obj.PreviewLineAxes.OuterPosition([1 3])) - obj.CheckBox.Position(1);
            p = [obj.CheckBox.Position(1:2) width obj.ELEMENT_HEIGHT_MAX];
        end

        function set.XYPosition(obj, p)
            obj.CheckBox.Position(1) = p(1);
            obj.Label.Position(1) = sum(obj.CheckBox.Position([1 3])) ...
                + obj.ELEMENT_COLUMN_MARGIN;
            obj.PreviewLineAxes.Position(1) = sum(obj.Label.Position([1 3])) ...
                + obj.ELEMENT_COLUMN_MARGIN;
            obj.CheckBox.Position(2) = p(2);
            obj.Label.Position(2) = p(2);
            obj.PreviewLineAxes.Position(2) = p(2);
        end

        function rgb = get.RgbColor(obj)
            rgb = obj.PreviewLine.Color;
        end

        function set.RgbColor(obj, color)
            obj.PreviewLine.Color = color;
        end

        function s = get.Text(obj)
            s = obj.Label.String;
        end

        function set.Text(obj, s)
            obj.Label.String = s;
        end

        function b = get.IsChecked(obj)
            b = obj.CheckBox.Value;
        end

        function set.IsChecked(obj, b)
            obj.CheckBox.Value = b;
        end
    end
end

function noOp(src, evt)
 % no-op
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
