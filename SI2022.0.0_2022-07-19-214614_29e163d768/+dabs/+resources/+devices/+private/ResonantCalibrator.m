classdef ResonantCalibrator < handle
    properties (Hidden)
        hResonantScanner;
        
        hFig;
        hAx;
        
        hCalPlotLinePts;
        hCalPlotLine;
        hCalPlotPt;
        
        hListeners = event.listener.empty(0,1);
    end
    
    %% Lifecycle
    methods
        function obj = ResonantCalibrator(hResonantScanner)
            obj.hResonantScanner = hResonantScanner;
            
            figName = sprintf('%s Amplitude LUT',obj.hResonantScanner.name);
            obj.hFig = most.idioms.figure('CloseRequestFcn',@(varargin)obj.delete,'NumberTitle','off','MenuBar','none','Name',figName);
            obj.hFig.KeyPressFcn = @obj.KeyPressFcn;
            hmain=most.idioms.uiflowcontainer('Parent',obj.hFig,'FlowDirection','TopDown');
            
            hContextMenu = uicontextmenu();
            uimenu(hContextMenu,'Label','Delete','Callback',@(varargin)obj.deletePoint);
            
            up = uipanel('Parent',hmain,'bordertype','none');
            obj.hAx = most.idioms.axes('Parent',up,'FontSize',12,'FontWeight','Bold');
            box(obj.hAx,'on');
            obj.hCalPlotLine = line('Parent',obj.hAx,'XData',[],'YData',[],'Color',most.constants.Colors.black,'LineWidth',2,'Hittest','off','PickableParts','none');
            obj.hCalPlotLinePts = line('Parent',obj.hAx,'XData',[],'YData',[],'Color',most.constants.Colors.black,'Marker','o','LineStyle','none','LineWidth',1,'MarkerSize',7,'UIContextMenu',hContextMenu);
            obj.hCalPlotPt = line('Parent',obj.hAx,'XData',[],'YData',[],'Color',most.constants.Colors.red,'Marker','o','LineStyle','none','LineWidth',1,'MarkerSize',10,'Hittest','off','PickableParts','none');
            
            xlabel(obj.hAx,'Resonant Scan Amplitude in [deg]','FontWeight','Bold');
            ylabel(obj.hAx,'Resonant Scan Amplitude out [deg]','FontWeight','Bold');
            
            grid(obj.hAx,'on');
            title(obj.hAx,figName);
            
            bottomContainer = most.idioms.uiflowcontainer('Parent',hmain,'FlowDirection','LeftToRight');
            set(bottomContainer,'HeightLimits',[30 30]);
            
            uicontrol('parent',bottomContainer,'style','pushbutton','Callback',@(src,evt)obj.clearCal,'string','Reset');
            
            ad1 = uicontrol('parent',bottomContainer,'style','pushbutton','Callback',@(src,evt)obj.adjustCal(-0.03),'string',most.constants.Unicode.downwards_paired_arrow,'FontName','Arial Unicode MS');
            ad2 = uicontrol('parent',bottomContainer,'style','pushbutton','Callback',@(src,evt)obj.adjustCal(-0.005),'string',most.constants.Unicode.downwards_arrow,'FontName','Arial Unicode MS');
            ad3 = uicontrol('parent',bottomContainer,'style','pushbutton','Callback',@(src,evt)obj.adjustCal(0.005),'string',most.constants.Unicode.upwards_arrow,'FontName','Arial Unicode MS');
            ad4 = uicontrol('parent',bottomContainer,'style','pushbutton','Callback',@(src,evt)obj.adjustCal(0.03),'string',most.constants.Unicode.upwards_paired_arrow,'FontName','Arial Unicode MS');
            set([ad1 ad2 ad3 ad4],'WidthLimits',[40 40]);
            
            obj.hListeners(end+1) = addlistener(obj.hResonantScanner,'currentAmplitude_deg','PostSet',@(varargin)obj.redraw);
            obj.hListeners(end+1) = addlistener(obj.hResonantScanner,'amplitudeLUT',        'PostSet',@(varargin)obj.redraw);
            obj.redraw();
        end
        
        function delete(obj)
            delete(obj.hListeners);
            most.idioms.safeDeleteObj(obj.hFig);
        end
    end
    
    methods        
        function redraw(obj)   
            obj.hAx.XLim = [0 obj.hResonantScanner.angularRange_deg];
            xx = linspace(obj.hResonantScanner.angularRange_deg/1000,obj.hResonantScanner.angularRange_deg,100);
            yy = obj.hResonantScanner.lookUpAmplitude(xx);
            
            obj.hCalPlotLine.XData = xx;
            obj.hCalPlotLine.YData = yy;
            
            obj.hCalPlotLinePts.XData = obj.hResonantScanner.amplitudeLUT(:,1);
            obj.hCalPlotLinePts.YData = obj.hResonantScanner.amplitudeLUT(:,2);
            
            obj.hCalPlotPt.XData = obj.hResonantScanner.currentAmplitude_deg;
            obj.hCalPlotPt.YData = obj.hResonantScanner.lookUpAmplitude(obj.hResonantScanner.currentAmplitude_deg);
        end
        
        function clearCal(obj)
            obj.hResonantScanner.amplitudeLUT = [];
        end
        
        function deletePoint(obj)
            pt = obj.hAx.CurrentPoint(1,1:2);
            lut = obj.hResonantScanner.amplitudeLUT;
            
            % find closest point in lut
            d = sqrt((lut(:,1)-pt(1)).^2 + (lut(:,2)-pt(2)).^2);
            [~,idx] = min(d);
            
            lut(idx,:) = [];
            
            obj.hResonantScanner.amplitudeLUT = lut;
        end
        
        function adjustCal(obj, adj)
            x = obj.hResonantScanner.currentAmplitude_deg;            
            y = obj.hResonantScanner.lookUpAmplitude(x);
            
            if x == 0
                return
            end
            
            lut = obj.hResonantScanner.amplitudeLUT;            
            tolerance = obj.hResonantScanner.angularRange_deg * 0.01;
            lut = removePointsInVicinity(lut,x,tolerance);            
            
            newX = x;
            newY = y+x*adj;

            lut(end+1,:) = [newX, newY];
            
            obj.hResonantScanner.amplitudeLUT = lut;
            applyNewLut();
            
            %%% Nested function
            function lut = removePointsInVicinity(lut,x,tolerance)
                mask = abs(lut(:,1)-x) <= tolerance;
                lut(mask,:) = [];
            end
            
            function applyNewLut()
                if isempty(obj.hResonantScanner.errorMsg)
                    if obj.hResonantScanner.currentAmplitude_deg>0
                        try
                            obj.hResonantScanner.setAmplitude(obj.hResonantScanner.currentAmplitude_deg);
                        catch ME
                            most.ErrorHandler.logAndReportError(ME);
                        end
                    end
                end
            end
        end
        
        function KeyPressFcn(obj,src,evt)
            switch evt.Key
                case {'leftarrow','rightarrow'}
                    % simply changing the amplitued during a scan is a bad idea
                    % this should always be done with the SI zoom controls instead
                case 'uparrow'
                    obj.adjustCal(0.005);
                case 'downarrow'
                    obj.adjustCal(-0.005);
                case 'delete'
                    obj.deletePoint();
                otherwise
                    %No-op
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
