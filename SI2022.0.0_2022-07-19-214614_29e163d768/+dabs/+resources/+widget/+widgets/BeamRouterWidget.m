classdef BeamRouterWidget < dabs.resources.widget.Widget
    properties
        hAx
        hPatchOutput;
        hOutLine;
        
        pmFunction;
        pbOpenFunction;
        hText = matlab.graphics.primitive.Text.empty();
        hListeners = event.listener.empty(0,1);
    end
    
    properties (SetAccess = private, GetAccess = private)
        lastClick = tic();
    end
    
    methods
        function obj = BeamRouterWidget(hResource,hParent)
            obj@dabs.resources.widget.Widget(hResource,hParent);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'lastKnownPowerFractions','PostSet',@(varargin)obj.redraw);
            
            try
                obj.redraw();
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
            obj.hAx.XColor = 'none';
            obj.hAx.YColor = 'none';
            obj.hAx.XLim = [0 1];
            obj.hAx.YLim = [0 1];
            obj.hAx.DataAspectRatio = [1 2 1];
            view(obj.hAx,0,-90);
            
            obj.hPatchOutput = patch('Parent',obj.hAx,'LineStyle','none','FaceColor',most.constants.Colors.red,'FaceAlpha',0.2,'Vertices',[],'Faces',[],'Hittest','off','PickableParts','none');
            obj.hOutLine = patch('Parent',obj.hAx,'XData',[],'YData',[],'Hittest','off','PickableParts','none');
            
            hFunctionFlow = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','LeftToRight','margin',0.001,'HeightLimits',[20 20]);
            obj.pmFunction = most.gui.uicontrol('Parent',hFunctionFlow,'Style','popupmenu','String','Bypass','Callback',@(varargin)obj.setFunction);
            obj.pbOpenFunction = most.gui.uicontrol('Parent',hFunctionFlow,'String','?','Tag','pbFunctionEdit','WidthLimits',[20 20],'Callback',@(varargin)obj.editFunctionFile);
            
            hButtonFlow = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','LeftToRight','margin',0.001,'HeightLimits',[20 20]);
            most.gui.uicontrol('Parent',hButtonFlow,'String','Calibrate','Callback',@(varargin)obj.calibrate);
        end
        
        function redraw(obj)
            fractions = obj.hResource.lastKnownPowerFractions;
            
            obj.hAx.YLim = [0 max(numel(fractions),1)];
            obj.hAx.DataAspectRatio = [1 max(numel(fractions),2) 1];
            
            faces = zeros(0,4);
            vertices = zeros(0,3);
            linePts = zeros(0,2);
            
            for idx = 1:numel(fractions)
                faces(end+1,:) = (idx-1)*4 + (1:4);
                
                f = fractions(idx);
                if isnan(f)
                    f = 1;
                end
                
                vertices(end+1:end+4,:)= [0   (idx-1)   0
                                          0   (idx-0.1) 0
                                          f   (idx-0.1) 0
                                          f   (idx-1)   0];
                                      
                linePts(end+1:end+6,:) = [0   (idx-1)  
                                          0   (idx-0.1)
                                          1   (idx-0.1)
                                          1   (idx-1)
                                          0   (idx-1)  
                                          NaN NaN];                                      
            end
            
            obj.hPatchOutput.Faces = faces;
            obj.hPatchOutput.Vertices = vertices;
            obj.hOutLine.XData = linePts(:,1);
            obj.hOutLine.YData = linePts(:,2);
            
            if numel(obj.hText)~=numel(fractions)
                most.idioms.safeDeleteObj(obj.hText);
                obj.hText = matlab.graphics.primitive.Text.empty();
                for idx = 1:numel(fractions)
                    obj.hText(idx) = text('Parent',obj.hAx,'String','','VerticalAlignment','middle','HorizontalAlignment','center','Hittest','off','PickableParts','none');
                    obj.hText(idx).Position = [0.5 0.45+idx-1];
                end
            end
            
            for idx = 1:numel(fractions)
                fraction = fractions(idx);
                if isnan(fraction)
                    msg = sprintf('B%d: Unknown',idx);
                else
                    msg = sprintf('B%d: %.2f%%',idx,fraction*100);
                end
                obj.hText(idx).String = msg;
            end
            
            mFiles = what('+dabs\+generic\+beamrouter\+functions');
            mFiles = mFiles.m;
            functionNames = cellfun(@(c)c(1:end-2),mFiles,'UniformOutput',false);
            obj.pmFunction.String = functionNames;
            
            functionString = func2str(obj.hResource.functionHandle);
            if ~isempty(functionString)
                idxs = strfind(functionString,'.');
                obj.pmFunction.pmValue = functionString(idxs(end)+1:end);
            end
        end
        
        function setFunction(obj)
            obj.hResource.functionHandle = ['dabs.generic.beamrouter.functions.' obj.pmFunction.pmValue];
        end
        
        function editFunctionFile(obj)
            edit(['dabs.generic.beamrouter.functions.' obj.pmFunction.pmValue]);
        end
        
        function calibrate(obj)
            try
                obj.hResource.calibrate;
            catch ME
                msg = sprintf('Error calibrating %s:\n%s',obj.hResource.name,ME.message);
                hFig_ = errordlg(msg,obj.hResource.name);
                most.gui.centerOnScreen(hFig_);
            end
        end
        
        function click(obj)
            d = toc(obj.lastClick);
            obj.lastClick = tic();
            
            if isempty(obj.hResource.hBeams)
                return;                
            end
            
            if d<=0.3
                % double-click
                obj.queryFraction();
            else
                obj.startDrag();
            end
        end
        
        function queryFraction(obj)
            f = obj.hResource.lastKnownPowerFractions;
            f(isnan(f)) = 0;
            
            prompt = arrayfun(@(idx)sprintf('Enter power fraction for beam %d in percent:',idx),1:numel(f),'UniformOutput',false);
            definput = arrayfun(@(f)sprintf('%.2f',f*100),f,'UniformOutput',false);
            
            answer = most.gui.inputdlgCentered(prompt...
                ,'Beam fraction'...
                ,[1 50]...
                ,definput);
            
            if ~isempty(answer)
                answer = answer(:)';
                f = cellfun(@(s)str2double(s)/100,answer);
                most.ErrorHandler.assert(~any(isnan(f)),'Invalid input: %s',strjoin(answer));
                obj.hResource.setPowerFractions(f);
            end
        end
        
        function startDrag(obj,src,evt)
            hFig = ancestor(obj.hAx,'figure');
            WindowButtonMotionFcn = hFig.WindowButtonMotionFcn;
            WindowButtonUpFcn     = hFig.WindowButtonUpFcn;
            
            hFig.WindowButtonMotionFcn = @(varargin)drag;
            hFig.WindowButtonUpFcn     = @(varargin)stop;
            
            function drag()
                try                    
                    fs = obj.hResource.lastKnownPowerFractions;
                    fs(isnan(fs)) = 0;
                    
                    pt = obj.hAx.CurrentPoint(1,1:2);
                    idx = ceil(pt(2));
                    idx = min(max(idx,1),numel(fs));
                    f = round(pt(1)*100)/100;
                    f = max(min(f,1),0);
                    
                    fs(idx) = f;
                    
                    obj.hResource.setPowerFractions(fs);
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                    stop();
                end
            end
            
            function stop()
                hFig.WindowButtonMotionFcn = WindowButtonMotionFcn;
                hFig.WindowButtonUpFcn     = WindowButtonUpFcn;
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
