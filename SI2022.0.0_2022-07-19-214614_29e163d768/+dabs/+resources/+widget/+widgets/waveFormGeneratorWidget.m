classdef waveFormGeneratorWidget < dabs.resources.widget.Widget
    properties (SetObservable)
        hgraph;
        hAx;
        pbStartStop;
        hListeners = event.listener.empty(0,1);
        pbOptimize;
    end
    
    methods
        function obj = waveFormGeneratorWidget(hResource, hParent)
            obj@dabs.resources.widget.Widget(hResource,hParent);
            obj.hListeners = [obj.hListeners most.ErrorHandler.addCatchingListener(obj.hResource,'wvfrmFcn','PostSet', @obj.redraw)];
            obj.hListeners = [obj.hListeners most.ErrorHandler.addCatchingListener(obj.hResource,'errorMsg','PostSet', @obj.redraw)];
            obj.hListeners = [obj.hListeners most.ErrorHandler.addCatchingListener(obj.hResource,'redrawWidget', @obj.redraw)];
            try
                obj.redraw();
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hListeners);
            obj.hListeners = event.listener.empty(0,1);
        end
    end
    
    methods
        function makePanel(obj, hParent)
            hFlow = most.gui.uiflowcontainer('Parent',hParent,'FlowDirection','TopDown','margin',0.005);
            hChannelFlow = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','LeftToRight','margin',0.005,'HeightLimits',[20 22]);
            obj.pbOptimize = most.gui.uicontrol('Parent',hChannelFlow, 'Enable', 'off','String','Optimize','Tag','pbOptimize','HeightLimits', [15,23],'callback',@obj.pbOptimizeCallback);
                  
            hGraphFlow = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','LeftToRight','margin',0.001);
            obj.hAx = most.idioms.axes('Parent',hGraphFlow,'Units','normalized','Position',[0 0 1 1],'XTick',[],'YTick',[],...
                'Visible','on',...
            'XLimSpec','tight','YLimSpec','tight',...
            'Color','white','box','on',...
            'XAxisLocation','origin','XColor',most.constants.Colors.darkGray,...
            'YColor',most.constants.Colors.darkGray);
            
            obj.hgraph = line('parent',obj.hAx,'color','k','xdata',nan,'ydata',nan,'LineWidth',2);
            
            hButtonFlow = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','LeftToRight','margin',0.001,'HeightLimits',[20 20]);
            obj.pbStartStop = most.gui.uicontrol('Parent',hButtonFlow,'Style', 'pushbutton' ,'String','Start', 'Background', most.constants.Colors.lightGray ,'Callback',@(varargin)obj.pbStartStopCallback);
            
            obj.redraw();
        end
        
        function redraw(obj, varargin)
            wvfm = obj.hResource.computeWaveform();

            if ~isempty(wvfm)
                if ~isempty(obj.hResource.waveformCacheScannerPath)
                    [available, ~] = obj.hResource.isCached(obj.hResource.sampleRate_Hz,wvfm);
                else
                    available = false;
                end
    
                if available
                    [~, wvfm, ~] = obj.hResource.getCachedOptimizedWaveform(obj.hResource.sampleRate_Hz, wvfm);
                end
    
                hTime = 1:numel(wvfm);
    
                set(obj.hgraph,'XData',hTime,'YData',wvfm);
                set(obj.hAx,...
                    'xlim',[min(hTime),max(hTime)],...
                    'ylim',[min(wvfm),max(wvfm)],...
                    'Visible','on',...
                    'XTick',[],...
                    'Position',[0.01 .1 0.99 .8]);
                yticks(obj.hAx,'auto');
            else
                available = false;
                set(obj.hgraph,'XData',nan,'YData',nan);
                set(obj.hAx,'YTick',[]);
            end
                
            if obj.hResource.feedbackAvailable && ~isempty(wvfm)
                obj.pbOptimize.Enable = 'on';
                obj.pbOptimize.hCtl.TooltipString = '';
                if obj.hResource.feedbackCalibrated
                    if available
                        obj.pbOptimize.String = 'Clear';
                    else
                        obj.pbOptimize.String = 'Optimize';
                    end
                else
                    obj.pbOptimize.String = 'Calibrate';
                end
            else
                obj.pbOptimize.Enable = 'off';
                obj.pbOptimize.hCtl.TooltipString = 'Optimization only available for AO waveforms with feedback configured.';
            end
            
            if ~isempty(obj.hResource.errorMsg) || ~most.idioms.isValidObj(obj.hResource.hTask)
                obj.pbStartStop.Enable = 'off';
                obj.pbStartStop.String = 'Start';
                obj.pbStartStop.hCtl.BackgroundColor = most.constants.Colors.lightGray;
                obj.hResource.stopTask();
            end
            
            if most.idioms.isValidObj(obj.hResource.hTask) && isempty(obj.hResource.errorMsg)
                obj.pbStartStop.Enable = 'on';
                if obj.hResource.hTask.active
                    obj.pbStartStop.String = 'Stop';
                    obj.pbStartStop.hCtl.BackgroundColor = most.constants.Colors.lightRed;
                else
                    obj.pbStartStop.String = 'Start';
                    obj.pbStartStop.hCtl.BackgroundColor = most.constants.Colors.lightGray;
                end
            end
           
        end
        
        function pbStartStopCallback(obj, varargin)
            switch obj.pbStartStop.String
                case 'Start'
                    obj.hResource.startTask();
                case 'Stop'
                    obj.hResource.stopTask();
                otherwise
            end
        end
        
        function pbOptimizeCallback(obj, varargin)
            if obj.hResource.feedbackCalibrated
                wvfm = obj.hResource.computeWaveform();
                [available, ~] = obj.hResource.isCached(obj.hResource.sampleRate_Hz,wvfm);
                
                % If optimized waveform already exists, clear it
                if available
                    obj.hResource.clearCachedWaveform(obj.hResource.sampleRate_Hz,wvfm);
                else
                % If optimized waveform does not exist, optimize
                    obj.hResource.optimizeWaveformIteratively(wvfm,obj.hResource.sampleRate_Hz);
                end
            % If not Calibrated, do so
            else
                obj.hResource.calibrate();
            end
            obj.redraw();
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
