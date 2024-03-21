classdef MCM6000MiscWidget < dabs.resources.widget.Widget
    properties
        hAx
        hPatchShutter;        
        hListeners = event.listener.empty(0,1);
        hTxWarning;
        hWarningFlow;
        
        pbPosition1;
        pbPosition2;
    end
    
    methods
        function obj = MCM6000MiscWidget(hResource,hParent)
            obj@dabs.resources.widget.Widget(hResource,hParent);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource.hMCM6000,'tfShutterOpen','PostSet',@(varargin)obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource.hMCM6000,'mirrorPosition','PostSet',@(varargin)obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'errorMsg','PostSet',@(varargin)obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'warnMsg','PostSet',@(varargin)obj.redrawWarning);
            
            try
                obj.redraw();
                obj.redrawWarning();
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
            hFlow = most.gui.uiflowcontainer('Parent',hParent,'FlowDirection','TopDown','Margin',1e-3);
                hPatchFlow = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','LeftToRight','Margin',1e-3);
                    obj.hAx = most.idioms.axes('Parent',hPatchFlow,'Units','normalized','Position',[0.1 0.1 0.8 0.8],'DataAspectRatio',[1 1 1],'XTick',[],'YTick',[],'Visible','on','XLimSpec','tight','YLimSpec','tight','ButtonDownFcn',@(varargin)obj.toggleShutter,'Color','none');
                    obj.hAx.XColor = 'none';
                    obj.hAx.YColor = 'none';
                    obj.hPatchShutter = patch('Parent',obj.hAx,'LineStyle','none','FaceColor',most.constants.Colors.darkGray,'PickableParts','none','Hittest','off');
                                    
                hButtonFlow = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','LeftToRight','Margin',1e-3, 'HeightLimits', [20 20]);
                    hButton = uicontrol('Parent',hButtonFlow);
                    set(hButton,'HeightLimits',[20 20]);
                    hButton.Callback = @(varargin)obj.gotoPosition1;
                    hButton.String = 'Position 1';
                    obj.pbPosition1 = hButton;
                    
                    hButton = uicontrol('Parent',hButtonFlow);
                    set(hButton,'HeightLimits',[20 20]);
                    hButton.Callback = @(varargin)obj.gotoPosition2;
                    hButton.String = 'Position 2';
                    obj.pbPosition2 = hButton;
                    
                obj.hWarningFlow = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','LeftToRight','Margin',1e-3,'HeightLimits',[20 20]);
                    obj.hTxWarning = uicontrol('Parent',obj.hWarningFlow,'Style','text');
                    obj.hTxWarning.BackgroundColor = most.constants.Colors.yellow;
                    obj.hTxWarning.FontWeight = 'Bold';
                    obj.hTxWarning.String = [ getWarningSign() ' Warning ' getWarningSign()];
                    obj.hTxWarning.FontSize = 12;
                    obj.hTxWarning.Enable = 'inactive';
                    obj.hTxWarning.ButtonDownFcn = @(varargin)obj.showWarningMessage();
                    
                
                    
            function warnsign = getWarningSign()
                if verLessThan('matlab','9.3') % warning sign is available in Matlab 2017b or later
                    warnsign = '!';
                else
                    warnsign = most.constants.Unicode.warning;
                end
            end
        end
        
        function redrawWarning(obj)
            if isempty(obj.hResource.warnMsg)
                obj.hWarningFlow.Visible = 'off';
            else
                obj.hWarningFlow.Visible = 'on';
            end
        end
        
        function showWarningMessage(obj)
            h = warndlg(obj.hResource.warnMsg);
            most.gui.centerOnScreen(h);
        end
        
        function redraw(obj)
            if ~isempty(obj.hResource.hMCM6000.errorMsg) || (isempty(obj.hResource.hMCM6000.mirrorSlot) || isempty(obj.hResource.hMCM6000.shutterSlot))
                obj.changeColor(most.constants.Colors.lightRed,most.constants.Colors.white);
                obj.pbPosition1.BackgroundColor = most.constants.Colors.lightRed;
                obj.pbPosition2.BackgroundColor = most.constants.Colors.lightRed;
%                 return;
            end
            t = linspace(300,355,100)';
            v = [sind(t), cosd(t)];
                       
            openFraction = double(obj.hResource.hMCM6000.tfShutterOpen);
            
            alpha = (1-openFraction) * -40;
            
            d = 0.3;
            r = sqrt(d^2+0.5^2);
            x = -d + cosd(alpha)*r-0.1;
            y = 0.5 + sind(alpha)*r;
            
            v(end+1,:) = [x y];
            v(:,3) = 1;
            
            vs = {};
            for idx = 1:6
                M = getMatrix(60*(idx-1));
                vs{idx} = v*M';
            end
            
            vs = cat(1,vs{:});
            
            obj.hPatchShutter.Vertices = vs;
            obj.hPatchShutter.Faces = reshape(1:size(vs,1),[],6)';
            
            switch obj.hResource.hMCM6000.mirrorPosition
                case 0
                    obj.pbPosition1.BackgroundColor = most.constants.Colors.lightRed;
                    obj.pbPosition2.BackgroundColor = most.constants.Colors.lightRed;
                case 1
                    obj.pbPosition1.BackgroundColor = most.constants.Colors.lightGreen;
                    obj.pbPosition2.BackgroundColor = most.constants.Colors.lightGray;
                case 2
                    obj.pbPosition1.BackgroundColor = most.constants.Colors.lightGray;
                    obj.pbPosition2.BackgroundColor = most.constants.Colors.lightGreen;
                otherwise
                    obj.pbPosition1.BackgroundColor = most.constants.Colors.lightRed;
                    obj.pbPosition2.BackgroundColor = most.constants.Colors.lightRed;
            end
            
            
            function T = getMatrix(alpha)
                T = [cosd(alpha) -sind(alpha) 0
                     sind(alpha)  cosd(alpha) 0
                     0            0           1];
            end
        end
        
        function toggleShutter(obj)
            if ~isempty(obj.hResource.errorMsg)
                most.ErrorHandler.logAndReportError('Shutter %s is in an error state:',obj.hResource.name,obj.hResource.errorMsg);
                return
            end
            
            obj.hResource.hMCM6000.setShutterOpen(~obj.hResource.hMCM6000.tfShutterOpen);
        end
        
        function gotoPosition1(obj,varargin)
            obj.hResource.hMCM6000.setMirrorPos(1);
        end
        
        function gotoPosition2(obj,varargin)
            obj.hResource.hMCM6000.setMirrorPos(2);
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
