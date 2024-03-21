classdef LiveHistogram < handle
    properties
        dataRange = [intmin('int16'),intmax('int16')];
        viewRange = [0 1];
        lut = [NaN NaN];
        title = '';
        channel = [];
    end
    
    properties (Hidden, SetAccess = private)
        hFig;
        hHist;
        hAx;
        hTxInfo;
        hSI;
        hLutPatch;
        hSaturationPatch;
        hMeanLine;
        hMaxLine;
        YLim;
    end
    
    events
        lutUpdated;
    end
    
    methods
        function obj = LiveHistogram(hSI)
            if nargin > 0
                obj.hSI = hSI;
            end

            obj.hFig = most.idioms.figure('NumberTitle','off','Name','Pixel Histogram','MenuBar','none',...
                'WindowScrollWheelFcn',@obj.scrollWheelFcn,'CloseRequestFcn',@obj.closeRequestFcn);
            
            hTopFlow = most.gui.uiflowcontainer('Parent',obj.hFig,'FlowDirection','TopDown');
                hAxFlow = most.gui.uiflowcontainer('Parent',hTopFlow,'FlowDirection','LeftToRight');
                hInfoFlow = most.gui.uiflowcontainer('Parent',hTopFlow,'FlowDirection','LeftToRight');
                    set(hInfoFlow,'HeightLimits',[20 20]);
                
            obj.hAx = most.idioms.axes('Parent',hAxFlow);
            obj.hHist = histogram(obj.hAx,0,'Normalization','countdensity','EdgeColor','none','ButtonDownFcn',@obj.buttonDownFcn);
            
            obj.hAx.ButtonDownFcn = @obj.buttonDownFcn;
            set(get(obj.hAx,'XLabel'),'String','Pixel Value','FontWeight','bold','FontSize',12);
            set(get(obj.hAx,'YLabel'),'String','Number of Pixels','FontWeight','bold','FontSize',12);
            obj.hAx.YScale = 'log';
            obj.hAx.XGrid = 'on';
            obj.hAx.YGrid = 'on';
            obj.hAx.LooseInset = [0 0 0 0] + 0.01;
            
            obj.hLutPatch = patch('Parent',obj.hAx,...
                'XData',[0,0,1,1]','YData',[1,inf,inf,1]','ZData',[1,1,1,1]',...
                'FaceAlpha',0.1,'FaceColor',[0,0,0],'EdgeColor','none',...
                'HitTest','off','PickableParts','none');
            obj.hSaturationPatch = patch('Parent',obj.hAx,...
                'XData',[0,0,1,1]','YData',[1,inf,inf,1]','ZData',[1,1,1,1]',...
                'FaceAlpha',0.1,'FaceColor',[1,0,0],'EdgeColor','none',...
                'HitTest','off','PickableParts','none','Visible','off');
            
            obj.hMeanLine = line('Parent',obj.hAx,'PickableParts','none','Hittest','off','Marker','^','LineWidth',1);
            obj.hMaxLine = line('Parent',obj.hAx,'PickableParts','none','Hittest','off','Marker','v','LineWidth',1);
            
            obj.YLim = [0.8 100];
            
            obj.hTxInfo = uicontrol('Parent',hInfoFlow,'Style','text','HorizontalAlignment','left');
            
            obj.updateData(0);
            obj.viewRange = obj.dataRange;   
            obj.lut = obj.lut;
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hFig);
        end
        
        function updateData(obj,val)
            val = val(:);
            obj.YLim(2) = numel(val);
            
            obj.hHist.Data = val;
            
            % check minimum histogram value and update YLim if necessary
            histVals = obj.hHist.Values;
            minHistVal = min((histVals(histVals>0)));
            minHistVal = minHistVal/1.25;
            minHistVal = min(minHistVal,0.8);
            
            if isempty(histVals)
                obj.hMaxLine.XData = [];
                obj.hMaxLine.YData = [];
            else
                [maxHistVal,idx] = max(histVals);
                obj.hMaxLine.XData = obj.hHist.BinEdges(idx);
                obj.hMaxLine.YData = maxHistVal;                
            end
            
            
            if ~isempty(minHistVal) && minHistVal < obj.YLim(1)
                obj.YLim(1) = minHistVal;
            end
            
            val   = single(val);
            min_  = min(val);
            max_  = max(val);
            mean_ = mean(val);
            std_  = std(val);
            obj.hTxInfo.String = sprintf('Min: %+d \tMax: %+d Mean: %+.2f SD: %+.2f' ...
                                        ,min_, max_, mean_, std_);
            
            obj.hMeanLine.XData = [-std_ 0 std_] + mean_;
            obj.hMeanLine.YData = [1 1 1] * obj.YLim(1);
        end
    end
    
    %% Property getter/setter
    methods
        function set.YLim(obj,val)
            if isequal(obj.YLim,val)
                return
            end
            
            obj.YLim = val;
            obj.hAx.YLim = val;
            obj.hLutPatch.YData = [val(1) val(2) val(2) val(1)]';
            obj.dataRange = obj.dataRange();
        end
        
        function set.dataRange(obj,val)
            validateattributes(val,{'numeric'},{'row','numel',2,'increasing'});
            val = round(double(val));
            obj.dataRange = val;
            
            obj.viewRange = obj.viewRange;
            
            s = obj.dataRange(1);
            e = obj.dataRange(2);
            w = (e-s) * 0.05; % saturation region
            z = 0.5;
            ll = obj.YLim(1);
            dP = obj.YLim(2);
            obj.hSaturationPatch.Vertices = [s,ll,z;...
                                             s,dP,z;...
                                             s+w,dP,z;...
                                             s+w,ll,z;...
                                             ...
                                             e-w,ll,z;...
                                             e-w,dP,z;...
                                             e,dP,z;...
                                             e,ll,z];
            obj.hSaturationPatch.FaceVertexAlphaData = [1;1;0;0;0;0;1;1].*0.3;
            obj.hSaturationPatch.FaceAlpha = 'interp';
            obj.hSaturationPatch.AlphaDataMapping = 'none';
            obj.hSaturationPatch.Faces = [1:4;5:8];
            obj.hSaturationPatch.Visible = 'on';
        end
        
        
        function set.viewRange(obj,val)
            validateattributes(val,{'numeric'},{'row','numel',2,'increasing'});
            val = round(double(val));
            val(1) = max(val(1),double(obj.dataRange(1)));
            val(2) = min(val(2),double(obj.dataRange(2)));
            obj.viewRange = val;
            
            units_ = obj.hAx.Units;
            obj.hAx.Units = 'pixel';
            pixelWidth = obj.hAx.Position(4);
            obj.hAx.Units = units_;

            binEdges = linspace(val(1)-0.5,val(2)+0.5,diff(val)+2);
            obj.hAx.XLim = binEdges([1 end]);
            
            p = ceil(length(binEdges)./pixelWidth); % reduce number of bins for display
            binEdges = binEdges(1:p:end); % the last bin might be cut off
            binEdges(end+1) = binEdges(end) + diff(binEdges(end-1:end)); % add the last bin back in
            obj.hHist.BinEdges = binEdges;
        end
        
        function set.lut(obj,val)
            validateattributes(val,{'numeric'},{'row','numel',2});
            val = sort(round(double(val)));
            
            val(1) = max([val(1),double(obj.dataRange(1))],[],'includenan');
            val(2) = min([val(2),double(obj.dataRange(2))],[],'includenan');
           
            obj.lut = val;
            
            if ~any(isnan(val))
                obj.hLutPatch.Visible = 'on';
                obj.hLutPatch.XData = [val(1),val(1),val(2),val(2)]';
            else
                obj.hLutPatch.Visible = 'off';
            end
        end
        
        function set.title(obj,val)
            obj.title = val;
            title(obj.hAx,val); %#ok<CPROPLC>
        end
    end
    
    methods (Hidden)
        function scrollWheelFcn(obj,src,evt)
            mPt = obj.hAx.CurrentPoint(1,1);
            oldViewRange = obj.viewRange;
            
            zoomSpeedFactor = 1.2;
            scroll = zoomSpeedFactor ^ double(evt.VerticalScrollCount);
            obj.viewRange = (oldViewRange - mPt) * scroll + mPt;
        end
        
        function buttonDownFcn(obj,src,evt)
            axPt = obj.hAx.CurrentPoint(1,1);
            
            if abs(axPt-obj.lut(1)) < diff(obj.viewRange) * 0.02
                panLutMode = 'changeMin';
            elseif abs(axPt-obj.lut(2)) < diff(obj.viewRange) * 0.02
                panLutMode = 'changeMax';
            elseif axPt >= obj.lut(1) && axPt <= obj.lut(2)
                panLutMode = 'pan';
            else
                panLutMode = [];
            end
            
            if evt.Button == 1;
                if src == obj.hHist;
                    if any(strcmpi(panLutMode,{'changeMin','changeMax'}));
                        obj.lutPan('start',panLutMode);
                    else
                        obj.pan('start');
                    end
                elseif ~isempty(panLutMode)
                    obj.lutPan('start',panLutMode);
                else
                    obj.pan('start');
                end
            end
        end
        
        function pan(obj,mode)
            if nargin<2 || isempty(mode)
                mode = 'start';
            end
            
            persistent dragData
            persistent originalConfig
            
            try
                switch lower(mode)
                    case 'start'
                        dragData = struct();
                        dragData.startPoint = obj.hAx.CurrentPoint(1,1);
                        dragData.startViewRange = obj.viewRange;
                        
                        originalConfig = struct();
                        originalConfig.WindowButtonMotionFcn = obj.hFig.WindowButtonMotionFcn;
                        originalConfig.WindowButtonUpFcn = obj.hFig.WindowButtonUpFcn;
                        
                        obj.hFig.WindowButtonMotionFcn = @(varargin)obj.pan('move');
                        obj.hFig.WindowButtonUpFcn = @(varargin)obj.pan('stop');
                    case 'move'
                        currentPoint = obj.hAx.CurrentPoint(1,1);
                        currentViewRange = obj.viewRange;
                        
                        d = currentPoint(1) - currentViewRange(1) + dragData.startViewRange(1);
                        d = d - dragData.startPoint;
                        
                        newViewRange = dragData.startViewRange-d;
                        
                        if newViewRange(1) >= obj.dataRange(1) && newViewRange(2) <= obj.dataRange(2)
                            obj.viewRange = newViewRange;
                        end                        
                    case 'stop'
                        abort();
                    otherwise
                        assert(false);
                end
            catch ME
                abort();
                rethrow(ME);
            end
            
            %%% local function
            function abort()
                if isstruct(originalConfig) && isfield(originalConfig,'WindowButtonMotionFcn');
                    obj.hFig.WindowButtonMotionFcn = originalConfig.WindowButtonMotionFcn;
                else
                    obj.hFig.WindowButtonMotionFcn = [];
                end
                
                if isstruct(originalConfig) && isfield(originalConfig,'WindowButtonUpFcn');
                    obj.hFig.WindowButtonUpFcn = originalConfig.WindowButtonUpFcn;
                else
                    obj.hFig.WindowButtonUpFcn = [];
                end
                
                startPoint = [];
                originalConfig = struct();
            end
        end
        
        function lutPan(obj,mode,panMode)
            if nargin<2 || isempty(mode)
                mode = 'start';
            end
            
            if nargin<3 || isempty(panMode)
                panMode = 'pan';
            end
            
            persistent dragData
            persistent originalConfig
            
            try
                switch lower(mode)
                    case 'start'
                        dragData = struct();
                        dragData.startPoint = obj.hAx.CurrentPoint(1,1);
                        dragData.startLut = obj.lut;
                        
                        originalConfig = struct();
                        originalConfig.WindowButtonMotionFcn = obj.hFig.WindowButtonMotionFcn;
                        originalConfig.WindowButtonUpFcn = obj.hFig.WindowButtonUpFcn;
                        
                        obj.hFig.WindowButtonMotionFcn = @(varargin)obj.lutPan('move',panMode);
                        obj.hFig.WindowButtonUpFcn = @(varargin)obj.lutPan('stop');
                    case 'move'
                        currentPoint = obj.hAx.CurrentPoint(1,1);
                        
                        d = currentPoint(1) - dragData.startPoint;
                        
                        switch panMode
                            case 'changeMax'
                                newLut = dragData.startLut+[0 d];
                            case 'changeMin'
                                newLut = dragData.startLut+[d 0];
                            case 'pan'
                                newLut = dragData.startLut+d;
                                % constraint newLut
                                if newLut(1) < obj.dataRange(1)
                                    newLut = [obj.dataRange(1), obj.dataRange(1)+diff(newLut)];
                                elseif newLut(2) > obj.dataRange(2)
                                    newLut = [obj.dataRange(2)-diff(newLut), obj.dataRange(2)];
                                end
                            otherwise
                                assert(false);
                        end
                        
                        obj.lut = newLut;
                        
                        if ~isempty(obj.hSI) && isvalid(obj.hSI) && ~isempty(obj.channel)
                            obj.hSI.hChannels.channelLUT{obj.channel} = obj.lut;
                        end
                    case 'stop'
                        abort();
                        notify(obj, 'lutUpdated');
                    otherwise
                        assert(false);
                end
            catch ME
                abort();
                rethrow(ME);
            end
            
            %%% local function
            function abort()
                if isstruct(originalConfig) && isfield(originalConfig,'WindowButtonMotionFcn');
                    obj.hFig.WindowButtonMotionFcn = originalConfig.WindowButtonMotionFcn;
                else
                    obj.hFig.WindowButtonMotionFcn = [];
                end
                
                if isstruct(originalConfig) && isfield(originalConfig,'WindowButtonUpFcn');
                    obj.hFig.WindowButtonUpFcn = originalConfig.WindowButtonUpFcn;
                else
                    obj.hFig.WindowButtonUpFcn = [];
                end
                
                startPoint = [];
                originalConfig = struct();
            end
        end
        
        function closeRequestFcn(obj,src,evt)
            if isvalid(obj)
                obj.delete();
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
