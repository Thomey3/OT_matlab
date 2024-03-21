classdef BeamModulatorWidget < dabs.resources.widget.Widget
    properties
        hAx
        hLineLimit;
        hPatchOutput;
        hLineLut;
        hDragLine;
        
        hText;
        hListeners = event.listener.empty(0,1);
    end
    
    properties (SetAccess = private, GetAccess = private)
        lastClick = tic();
    end
    
    methods
        function obj = BeamModulatorWidget(hResource,hParent)
            obj@dabs.resources.widget.Widget(hResource,hParent);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'lastKnownPowerFraction','PostSet',@(varargin)obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'powerFractionLimit','PostSet',@(varargin)obj.redraw);
            
            if isprop(obj.hResource,'powerFraction2ModulationVoltLut')
                obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'powerFraction2ModulationVoltLut','PostSet',@(varargin)obj.redrawLut);
            end
            
            if isprop(obj.hResource,'powerFraction2ModulationAngleLut')
                obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'powerFraction2ModulationAngleLut','PostSet',@(varargin)obj.redrawLut);
            end
            
            try
                obj.redraw();
                obj.redrawLut();
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
        end
        
        function delete(obj)
            delete(obj.hListeners);
            most.idioms.safeDeleteObj(obj.hAx);
        end
    end
    
    methods
        function makePanel(obj,hParent)
            hFlow = most.gui.uiflowcontainer('Parent',hParent,'FlowDirection','TopDown','margin',0.001);
            
            hAxFlow = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','LeftToRight','margin',0.001);
            obj.hAx = most.idioms.axes('Parent',hAxFlow,'Units','normalized','Position',[0.1 0.1 0.8 0.8],'DataAspectRatio',[1 1 1],'XTick',[],'YTick',[],'Visible','on','XLimSpec','tight','YLimSpec','tight','Color','none','ButtonDownFcn',@(varargin)obj.click);
            obj.hAx.XLim = [0 1];
            obj.hAx.YLim = [0 1];
            box(obj.hAx,'on');
            obj.hAx.DataAspectRatio = [1 2 1];
            
            obj.hPatchOutput = patch('Parent',obj.hAx,'LineStyle','none','FaceColor',most.constants.Colors.red,'FaceAlpha',0.2,'Vertices',[],'Faces',[],'Hittest','off','PickableParts','none');
            
            obj.hLineLimit = line('Parent',obj.hAx,'Hittest','off','PickableParts','none','LineStyle','-.','XData',[],'YData',[],'LineWidth',1.5,'Color',most.constants.Colors.darkGray);
            obj.hLineLut   = line('Parent',obj.hAx,'Hittest','off','PickableParts','none','XData',[],'YData',[],'LineWidth',0.01,'LineStyle',':');
            obj.hDragLine  = line('Parent',obj.hAx,'Hittest','off','PickableParts','none','XData',[],'YData',[],'LineWidth',0.01,'Color',most.constants.Colors.red,'LineWidth',1.5);
            
            obj.hText = text('Parent',obj.hAx,'String','','VerticalAlignment','middle','HorizontalAlignment','center','Hittest','off','PickableParts','none');
            obj.hText.Position = [0.5 0.5];
            

            hButtonFlow = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','LeftToRight','margin',0.001,'HeightLimits',[20 20]);
            most.gui.uicontrol('Parent',hButtonFlow,'String','Calibrate','Callback',@(varargin)obj.calibrate);
            most.gui.uicontrol('Parent',hButtonFlow,'String','Show LUT','Callback',@(varargin)obj.hResource.plotLUT);
            
        end
        
        function redrawLut(obj)
            if isprop(obj.hResource,'powerFraction2ModulationAngleLut')
                drawLut( obj.hResource.powerFraction2ModulationAngleLut );
            elseif isprop(obj.hResource,'powerFraction2ModulationVoltLut')                
                drawLut( obj.hResource.powerFraction2ModulationVoltLut );
            else
                drawLut(zeros(0,2));
            end
            
            %%% Nested functions
            function drawLut(lut)
                if isempty(lut)
                    obj.hLineLut.XData = [];
                    obj.hLineLut.YData = [];
                else
                    ff = lut(:,1);
                    vv = lut(:,2);
                    
                    vv = vv/max(vv);
                    obj.hLineLut.XData = ff;
                    obj.hLineLut.YData = vv;
                end
            end
        end
        
        function redraw(obj)
            fraction = obj.hResource.lastKnownPowerFraction;
            power_W = obj.hResource.lastKnownPower_W;
            
            unknownFraction = isnan(fraction);
            if unknownFraction
                fraction = 1;
            end
                                         
            obj.hPatchOutput.Faces = 1:4;
            obj.hPatchOutput.Vertices = [0 0 0
                                         0 1 0
                                         fraction 1 0
                                         fraction 0 0];

            fraction_limit = obj.hResource.powerFractionLimit;
            if fraction_limit == 1
                obj.hLineLimit.XData = [];
                obj.hLineLimit.YData = [];
            else
                obj.hLineLimit.XData = [1 1] * fraction_limit;
                obj.hLineLimit.YData = [0 1];
            end
            
            if isnan(power_W)
                power_mW_string = '? ';
            else
                power_mW_string = sprintf('%.0f',power_W*1000);
            end
            
            if unknownFraction
                msg = 'Modulating';
            else
                msg = sprintf('%.1f%%\n%smW',fraction*100,power_mW_string);
            end
            obj.hText.String = msg;
        end
        
        function [errorMsg] = setPowerFraction(obj,val)
            errorMsg = '';
            
            try
                obj.hResource.setPowerFraction(val);
            catch ME
                most.ErrorHandler.logAndReportError(ME);
                
                if strcmpi(ME.message,'DAQmx call failed.')
                    errorMsg = sprintf('Could not set Pockels Cell output power.\nDuring an active acquisition, use the ScanImage power controls instead.');
                else
                    errorMsg = ME.message;
                end
            end
        end
        
        function calibrate(obj)
            try
                ignorePowerFractionLimit = false;
                
                if obj.hResource.powerFractionLimit < 1
                    msg = sprintf('Waring:\n''%s'' power limit is set to %.2f%%.\nDuring calibration this limit will be exceeded.',obj.hResource.name,obj.hResource.powerFractionLimit*100);
                    okClicked = showWarnDlg(msg,'Power limit warning','modal');
                    
                    if okClicked
                        ignorePowerFractionLimit = true;
                    else
                        return
                    end
                end
                
                obj.hResource.calibrate(ignorePowerFractionLimit);
            catch ME
                hFig_ = errordlg(ME.message);
                most.gui.centerOnScreen(hFig_);
                most.ErrorHandler.logAndReportError(ME);
            end
            
            %%% Nested function
            function okClicked = showWarnDlg(varargin)                
                okClicked = false;
                hFig = warndlg(varargin{:});
                most.gui.centerOnScreen(hFig);
                
                hOkButton = findobj(hFig,'Type','uicontrol','Tag','OKButton');
                originalOkButtonCallback = hOkButton.Callback;
                hOkButton.Callback = @(varargin)okButtonCallback(originalOkButtonCallback,varargin{:});
                
                waitfor(hFig);
                
                function okButtonCallback(callback,varargin)
                    okClicked = true;
                    if ischar(callback)
                        eval(callback);
                    else
                        callback(varargin{:});
                    end
                end
            end
        end
        
        function queryFraction(obj)
            answer = most.gui.inputdlgCentered('Enter power fraction in percent:'...
                ,'Power fraction'...
                ,[1 50]...
                ,{num2str(obj.hResource.lastKnownPowerFraction*100)});
            
            if ~isempty(answer)
                answer = str2double(answer{1})/100;
                errorMsg = obj.setPowerFraction(answer);
                
                if ~isempty(errorMsg)
                    hFig_ = warndlg(errorMsg,obj.hResource.name);
                    most.gui.centerOnScreen(hFig_);
                end
            end
        end
        
        function click(obj)
            d = toc(obj.lastClick);
            obj.lastClick = tic();
            
            if d<=0.3
                % double-click
                obj.queryFraction();
            else
                obj.startDrag();
            end
        end
        
        function startDrag(obj,src,evt)
            hFig = ancestor(obj.hAx,'figure');
            WindowButtonMotionFcn = hFig.WindowButtonMotionFcn;
            WindowButtonUpFcn     = hFig.WindowButtonUpFcn;
            Pointer               = hFig.Pointer;
            
            XLim = obj.hAx.XLim;
            YLim = obj.hAx.YLim;
            
            hFig.WindowButtonUpFcn     = @(varargin)stop;
            hFig.WindowButtonMotionFcn = @(varargin)drag;
            
            hFig.Pointer = 'left';
            
            function drag()
                pt = obj.hAx.CurrentPoint(1,1:2);                
                f = round(pt(1)*100)/100;
                f = max(min(f,1),0);
                f = min(f,obj.hResource.powerFractionLimit);
                
                errorMsg = '';
                if isa(obj.hResource, 'dabs.resources.devices.BeamModulatorFast')
                    [errorMsg] = obj.setPowerFraction(f);
                end
                
                obj.hDragLine.XData = [f f];
                obj.hDragLine.YData = [0 1];
                
                if ~isempty(errorMsg)
                    stop(); % stop drag before showing warn dialog. Otherwise the drag continues until the warndlg figure shows up
                    hFig_ = warndlg(errorMsg,obj.hResource.name);
                    most.gui.centerOnScreen(hFig_);
                elseif outOfBound(pt)
                    stop();
                end                
            end
            
            function stop()
                pt = obj.hAx.CurrentPoint(1,1:2);                
                
                f = round(pt(1)*100)/100;
                f = max(min(f,1),0);
                
                hFig.WindowButtonMotionFcn = WindowButtonMotionFcn;
                hFig.WindowButtonUpFcn     = WindowButtonUpFcn;
                hFig.Pointer = Pointer;
                
                obj.hDragLine.XData = [];
                obj.hDragLine.YData = [];
                
                errorMsg = '';
                if isa(obj.hResource, 'dabs.resources.devices.BeamModulatorSlow')
                    [errorMsg] = obj.setPowerFraction(f);
                end
                
                if ~isempty(errorMsg)
                    hFig_ = warndlg(errorMsg,obj.hResource.name);
                    most.gui.centerOnScreen(hFig_);
                end
            end
            
            
            function tf = outOfBound(pt)
                axLimExtend = 1.5;
                
                XBounds = sum(XLim)/2 + [-1 1] * diff(XLim)/2 * axLimExtend;
                YBounds = sum(YLim)/2 + [-1 1] * diff(YLim)/2 * axLimExtend;
                
                tf = pt(1)<XBounds(1) || pt(1)>XBounds(2) ...
                  || pt(2)<YBounds(1) || pt(2)>YBounds(2);
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
