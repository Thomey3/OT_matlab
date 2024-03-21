classdef ResonantWidget < dabs.resources.widget.Widget
    properties
        hAx
        hLineAngularRange;
        hLineCurrentAmplitude;
        hText;
        hListeners = event.listener.empty(0,1);
    end
    
    methods
        function obj = ResonantWidget(hResource,hParent)
            obj@dabs.resources.widget.Widget(hResource,hParent);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'angularRange_deg','PostSet',@(varargin)obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'currentAmplitude_deg','PostSet',@(varargin)obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'currentFrequency_Hz','PostSet',@(varargin)obj.redraw);
            
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
            obj.hAx = most.idioms.axes('Parent',hAxFlow,'Units','normalized','Position',[0.1 0.1 0.8 0.8],'DataAspectRatio',[1 1 1],'XTick',[],'YTick',[],'Visible','off','XLimSpec','tight','YLimSpec','tight');
            obj.hLineAngularRange = line('Parent',obj.hAx,'ButtonDownFcn',@(varargin)obj.setAmplitude);
            obj.hLineCurrentAmplitude = line('Parent',obj.hAx,'LineWidth',5,'ButtonDownFcn',@(varargin)obj.setAmplitude);
            obj.hText = text('Parent',obj.hAx,'ButtonDownFcn',@(varargin)obj.setAmplitude);
            
            hButtonFlow = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','LeftToRight','margin',0.001,'HeightLimits',[20 20]);
            most.gui.uicontrol('Parent',hButtonFlow,'String','LUT','Callback',@(varargin)obj.hResource.plotLUT);
            most.gui.uicontrol('Parent',hButtonFlow,'String','Freq','Callback',@(varargin)obj.hResource.plotFrequency);
            most.gui.uicontrol('Parent',hButtonFlow,'String','Phase','Callback',@(varargin)obj.hResource.plotLinePhase);
        end
        
        function redraw(obj)
            angularRange = linspace(-obj.hResource.angularRange_deg/2,obj.hResource.angularRange_deg/2,100)';
            angularRangeXY = [sind(angularRange), cosd(angularRange)];
            
            currentAmplitude = linspace(-obj.hResource.currentAmplitude_deg/2,obj.hResource.currentAmplitude_deg/2,100)';
            currentAmplitudeXY = [sind(currentAmplitude), cosd(currentAmplitude)];
            
            obj.hLineAngularRange.XData = angularRangeXY(:,1);
            obj.hLineAngularRange.YData = angularRangeXY(:,2);
            
            obj.hLineCurrentAmplitude.XData = currentAmplitudeXY(:,1);
            obj.hLineCurrentAmplitude.YData = currentAmplitudeXY(:,2);
            
            obj.hText.String = sprintf('%.2f%s\n%.2fHz'...
                ,obj.hResource.currentAmplitude_deg,most.constants.Unicode.degree_sign...
                ,obj.hResource.currentFrequency_Hz);
            
            obj.hText.Position = [0,0.98];
            obj.hText.HorizontalAlignment = 'center';
            obj.hText.VerticalAlignment = 'top';
            obj.hAx.YLim = [0.8 1];
        end
        
        function setAmplitude(obj)
            answer = most.gui.inputdlgCentered('Enter resonant scanner amplitude in optical degrees (peak-peak):'...
                ,'Resonant scanner amplitude'...
                ,[1 70]...
                ,{num2str(obj.hResource.currentAmplitude_deg)});
            
            if ~isempty(answer)
                answer = str2double(answer{1});
                try
                    obj.hResource.setAmplitude(answer);
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                    hFig_ = errordlg(ME.message,obj.hResource.name);
                    most.gui.centerOnScreen(hFig_);
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
