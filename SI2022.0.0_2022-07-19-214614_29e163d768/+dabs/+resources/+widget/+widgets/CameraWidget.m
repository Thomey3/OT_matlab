classdef CameraWidget < dabs.resources.widget.Widget
    properties
        dirty = true;
        hAx;
        hSurf;
        
        resolutionXY;
        
        hListeners = event.listener.empty(0,1);
    end
    
    methods
        function obj = CameraWidget(hResource,hParent)
            obj@dabs.resources.widget.Widget(hResource,hParent);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'resolutionXY','PostSet',@(varargin)obj.flagDirty);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'lastAcquiredFrame','PostSet',@(varargin)obj.flagDirty);
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

            obj.hAx = most.idioms.axes('Parent',hAxFlow,'Units','normalized','Position',[0 0 1 1],'DataAspectRatio',[1 1 1],'XTick',[],'YTick',[],'Visible','off','XLimSpec','tight','YLimSpec','tight');
            view(obj.hAx,0,-90);
            
            res = double(obj.hResource.resolutionXY);
            if isempty(res)
                res = [1920 1080];                
            end
            obj.resolutionXY = res;
            [xx,yy,zz] = ndgrid([-0.5,0.5]*(res(1)-1),[-0.5,0.5]*(res(2)-1),0);
            
            obj.hSurf = surface('Parent',obj.hAx,'XData',xx,'YData',yy,'ZData',zz,'CData',0,'FaceColor','texturemap','CDataMapping','scaled','FaceLighting','none','ButtonDownFcn',@obj.openCameraControls);            
            colormap(obj.hAx,'gray')
            
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResourceStore.hSystemTimer,'beacon_15Hz',@(varargin)obj.redraw);
        end
        
        function redraw(obj)
            if ~obj.dirty || isempty(obj.hAx) || isempty(obj.hResource)
                return
            end
            
            res = double(obj.hResource.resolutionXY);
            if ~isempty(res) && ~isequal(obj.resolutionXY,res)
                [xx,yy,zz] = ndgrid([-0.5,0.5]*(res(1)-1),[-0.5,0.5]*(res(2)-1),0);
                obj.hSurf.XData = xx;
                obj.hSurf.YData = yy;
                obj.hSurf.ZData = zz;
            end
            
            data = obj.hResource.lastAcquiredFrame;
            
            if ~isempty(data)
                data = squeeze(data);
                maxRes = max(size(data));
                
                downSampleFactor = floor(maxRes/100);
                data = data(1:downSampleFactor:end,1:downSampleFactor:end); % downsample
                
                obj.hSurf.CData = data;
            end
            
            obj.dirty = false;
            
        end
        
        function openCameraControls(obj,varargin)            
            hCameraView = findSICameraView(obj.hResource);
            
            if isempty(hCameraView)
                if isempty(obj.hResource.errorMsg)
                    obj.hResource.stop();
                    obj.hResource.snapshot();
                end
            else
                most.idioms.figure(hCameraView.hFig);
            end
           
            
            %%% nested function
            function hCameraView = findSICameraView(hCamera)
                hCameraManager = obj.hResourceStore.filterByClass('scanimage.components.CameraManager');
                hCameraView = [];
                
                if ~isempty(hCameraManager)
                    hCameraWrappers = hCameraManager{1}.hCameraWrappers;
                    
                    for idx = 1:numel(hCameraWrappers)
                        if isequal(hCameraWrappers(idx).hDevice,hCamera) ...
                           && most.idioms.isValidObj(hCameraWrappers(idx).hCameraView)
                            hCameraView = hCameraWrappers(idx).hCameraView;
                            return;
                        end
                    end
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
