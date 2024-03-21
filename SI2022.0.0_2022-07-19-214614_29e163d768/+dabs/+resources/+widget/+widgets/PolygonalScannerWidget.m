classdef PolygonalScannerWidget < dabs.resources.widget.Widget
    properties
        hAx;
        etLineRate_Hz;
        hRateText;
        pbEnable;
        poly;
        enableArrow;
        arrowTip;
        hListeners = event.listener.empty(0,1);
        
        hLineAngularRange;
        hLineCurrentAmplitude;
        
        hSI;
    end
    
    methods
        function obj = PolygonalScannerWidget (hResource,hParent)
            obj@dabs.resources.widget.Widget(hResource,hParent);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'currentCommandedLineRate_Hz','PostSet',@(varargin)obj.redraw);
            try
                obj.redraw();
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
        end
        
        function delete(obj)
            obj.hListeners.delete();
            most.idioms.safeDeleteObj(obj.hAx);
        end
    end
    
    methods
        function makePanel(obj,hParent)
            hFlow = most.gui.uiflowcontainer('Parent',hParent,'FlowDirection','TopDown','margin',0.001);
            
            hAxFlow = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','LeftToRight','margin',0.001);
            
            obj.hAx = most.idioms.axes('Parent',hAxFlow,'Units','normalized','Position',[.1 .1 .8 .8],'DataAspectRatio',[1 1 1],'XTick',[],'YTick',[],'Visible','on','XLimSpec','tight','YLimSpec','tight','ButtonDownFcn',@(varargin)obj.setLineRate_Hz,'Color','none');
            obj.hAx.XColor = 'none';
            obj.hAx.YColor = 'none';
            theta = (0:60:720) + 0/2;
            x = cosd(theta);
            y = sind(theta);
            obj.poly = patch('XData',x,'YData',y,'Parent',obj.hAx, 'LineWidth', 3, 'EdgeColor',most.constants.Colors.darkGray,'FaceColor',most.constants.Colors.darkGray,'FaceAlpha',0.5,'PickableParts','none','Hittest','off');
            
            [arrowX, arrowY] = arrowPoints();
            obj.enableArrow = line(arrowX,arrowY,'Parent',obj.hAx,'Color',most.constants.Colors.red,'LineWidth',2,'Visible','off','PickableParts','none','Hittest','off');
            obj.arrowTip = line(arrowX(end),arrowY(end),'Parent',obj.hAx,'Color',most.constants.Colors.red,'LineWidth',1.5,'Visible','off','PickableParts','none','Hittest','off','Marker','^','MarkerFaceColor',most.constants.Colors.red);
            
            
            hRateFlow = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','TopDown','margin',0.001,'HeightLimits',[20 20]);
            hTextFlow = most.gui.uiflowcontainer('Parent',hRateFlow,'FlowDirection','LeftToRight','margin',0.001,'HeightLimits',[20 20]);
            obj.hRateText = most.gui.uicontrol('Parent',hTextFlow,'Style','text','String','Line Rate [Hz]','Tag','txLineRate_Hz');
            obj.etLineRate_Hz = most.gui.uicontrol('Parent',hTextFlow,'Style','edit','Tag','etLineRate_Hz','Position',[0 0 20 20],'callback',@(varargin)obj.setNominalLineRate_Hz);
            set(obj.etLineRate_Hz,'WidthLimits',[40 40]);
            hEnableFlow = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','TopDown','margin',0.001,'HeightLimits',[20 20]);
            obj.pbEnable = most.gui.uicontrol('Parent',hEnableFlow,'Style','pushbutton','String','Enable','Tag','pbEnable','callback',@(varargin)obj.setLineRate_Hz);
            %             obj.hText = text('Parent',obj.hFlow,'ButtonDownFcn',@(varargin)obj.setLineRate_Hz);
        end
        
        function redraw(obj)
            obj.etLineRate_Hz.String = num2str(obj.hResource.nominalFrequency_Hz);
            if obj.hResource.currentCommandedLineRate_Hz > 0
                obj.pbEnable.String = 'Disable';
                obj.enableArrow.Visible = 'on';
                obj.arrowTip.Visible = 'on';
            else
                obj.pbEnable.String = 'Enable';
                obj.enableArrow.Visible = 'off';
                obj.arrowTip.Visible = 'off';
            end
            
        end
        
        function setLineRate_Hz(obj)
            try
                if obj.hResource.currentCommandedLineRate_Hz > 0
                    obj.hResource.setLineRate_Hz(0);
                else
                    obj.hResource.setLineRate_Hz(obj.hResource.nominalFrequency_Hz);
                end
            catch ME
                most.ErrorHandler.logAndReportError(ME);
                hFig_ = errordlg(ME.message,obj.hResource.name);
                most.gui.centerOnScreen(hFig_);
            end
        end
        
        function setNominalLineRate_Hz(obj)
            obj.hResource.nominalFrequency_Hz = str2double(obj.etLineRate_Hz.String);
        end
    end
    
end

function [x,y] = arrowPoints()
theta = -(-30:270);
r = 0.5;
x = r*sind(theta);
y = r*cosd(theta);
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
