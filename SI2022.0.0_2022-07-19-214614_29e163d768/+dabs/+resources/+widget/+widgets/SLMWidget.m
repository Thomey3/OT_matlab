classdef SLMWidget < dabs.resources.widget.Widget
    properties
        dirty = true;
        hAx;
        hSurf;
        hText;
        
        hListeners = event.listener.empty(0,1);
    end
    
    methods
        function obj = SLMWidget(hResource,hParent)
            obj@dabs.resources.widget.Widget(hResource,hParent);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'lastKnownBitmap','PostSet',@(varargin)obj.flagDirty);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'queueStarted','PostSet',@(varargin)obj.flagDirty);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResourceStore.hSystemTimer,'beacon_30Hz',@(varargin)obj.redraw);
        end
        
        function delete(obj)
            obj.hListeners.delete();
            most.idioms.safeDeleteObj(obj.hAx);
        end
    end
    
    methods
        function flagDirty(obj)
            obj.dirty = true;
        end
    end
    
    methods
        function makePanel(obj,hParent)
            hFlow = most.gui.uiflowcontainer('Parent',hParent,'FlowDirection','TopDown','margin',0.001);
            
            hAxFlow = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','LeftToRight','margin',0.001);
            hButtonFlow = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','LeftToRight','margin',0.001,'HeightLimits',[20,20]);

            obj.hAx = most.idioms.axes('Parent',hAxFlow,'Units','normalized','Position',[0 0 1 1],'DataAspectRatio',[1 1 1],'XTick',[],'YTick',[],'Visible','off','XLimSpec','tight','YLimSpec','tight');
            view(obj.hAx,0,-90);
            
            res = obj.hResource.pixelResolutionXY;
            [xx,yy,zz] = ndgrid([-0.5,0.5]*(res(1)-1),[-0.5,0.5]*(res(2)-1),0);
            
            obj.hSurf = surface(obj.hAx,xx,yy,zz,0,'FaceColor','texturemap','CDataMapping','scaled','FaceLighting','none','ButtonDownFcn',@(varargin)obj.openSlmControls);
            obj.hText = text('Parent',obj.hAx,'Position',[0 0 0],'String','Triggered output','Color',most.constants.Colors.white,'Visible','off','HorizontalAlignment','center','VerticalAlignment','middle');
            
            colormap(obj.hAx,'gray')
            obj.hAx.CLim = [0,(2^obj.hResource.pixelBitDepth)-1];
            
            uicontrol('Parent',hButtonFlow,'String','Zernike Generator','Callback',@(varargin)obj.openZernikeGenerator);
        end
        
        function redraw(obj)
            if obj.dirty && ~isempty(obj.hAx) && ~isempty(obj.hResource)                
                if obj.hResource.queueStarted
                    obj.hSurf.CData = 0;
                    obj.hText.Visible = 'on';
                else
                    data = obj.hResource.lastKnownBitmap;
                    maxRes = max(size(data));
                    downSampleFactor = floor(maxRes/100);
                    data = data(1:downSampleFactor:end,1:downSampleFactor:end); % downsample
                    
                    obj.hSurf.CData = data;
                    obj.hText.Visible = 'off';
                end
                
                obj.dirty = false;
            end
        end
        
        function openSlmControls(obj)
            hSlmScan = obj.findSlmScan();
            
            if most.idioms.isValidObj(hSlmScan)
                hSlmScan.showPhaseMaskDisplay();
            else
                hFig_ = warndlg('Start ScanImage and configure a SLM scan system to use SLM controls',obj.hResource.name);
                most.gui.centerOnScreen(hFig_);
            end
        end
        
        function openZernikeGenerator(obj)
            hSlmScan = obj.findSlmScan();
            
            if most.idioms.isValidObj(hSlmScan)
                hSlmScan.showZernikeGenerator();
            else
                hFig_ = warndlg('Start ScanImage and configure a SLM scan system to use SLM controls',obj.hResource.name);
                most.gui.centerOnScreen(hFig_);
            end
        end
        
        function hSlmScan = findSlmScan(obj)
            hSlmScan = dabs.resources.Resource.empty();
            hSlmScans = obj.hResourceStore.filterByClass('scanimage.components.scan2d.SlmScan');
            
            for idx = 1:numel(hSlmScans)
                hSlmScan_ = hSlmScans{idx};
                if hSlmScan_.mdlInitialized && hSlmScan_.hSlm.hDevice==obj.hResource
                    hSlmScan = hSlmScan_;
                    break;
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
