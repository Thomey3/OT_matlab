classdef vDAQR1Breakout < handle
    properties (SetAccess = private,Hidden)
        hFig
        hParent
        hAx
        hDAQ
        hTransform
        hSurf
        hLiveValueTool
        hBNCs = dabs.resources.configuration.private.BNC.empty(0,1);
        hListeners = event.listener.empty();
    end
    
    
    methods
        function obj = vDAQR1Breakout(hDAQ,hParent)
            if nargin < 1 || isempty(hDAQ)
                hResourceStore = dabs.resources.ResourceStore();
                hResourceStore.scanSystem();
                
                hvDAQs = hResourceStore.filterByClass(?dabs.resources.daqs.vDAQR1);
                
                assert(~isempty(hvDAQs),'No vDAQ R1 found in system');
                hDAQ = hvDAQs{1};
            end
            
            validateattributes(hDAQ,{'dabs.resources.daqs.vDAQR1'},{'scalar'});
            obj.hDAQ = hDAQ;
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hDAQ,'ObjectBeingDestroyed',@(varargin)obj.delete);
            
            if nargin < 2 || isempty(hParent)
                obj.hFig = most.idioms.figure('WindowButtonMotionFcn',@obj.WindowButtonMotionFcn,'CloseRequestFcn',@(varargin)obj.delete,'NumberTitle','off','MenuBar','none','Name',sprintf('%s Breakout',obj.hDAQ.name));
                obj.hParent = obj.hFig;
            else
                obj.hParent = hParent;
            end
            
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hParent,'ObjectBeingDestroyed',@(varargin)obj.delete);
            
            obj.hAx = most.idioms.axes('Parent',obj.hParent,'DataAspectRatio',[1 1 1],'Visible','off','XTick',[],'YTick',[],'XLimSpec','tight','YLimSpec','tight');
            obj.hAx.Units = 'normalized';
            obj.hAx.Position = [0 0 1 1];
            view(obj.hAx,0,-90);
            
            obj.makeSurface();
            obj.makeAIs();
            obj.makeAOs();
            obj.makeDIOs();
            
            if ~isempty(obj.hFig)
                aspectRatio = diff(obj.hAx.XLim) / diff(obj.hAx.YLim);
                %monitors = get(0, 'MonitorPositions');
                m = get(0, 'ScreenSize');
                screenWidthFraction = 0.75;
                obj.hFig.Position = [m(1)+m(3)*(1-screenWidthFraction)/2
                                     m(2)+40
                                     m(3)*screenWidthFraction
                                     m(3)*screenWidthFraction/aspectRatio];
                
                obj.hFig.ResizeFcn = @(varargin)obj.resizeIm();
            end
            
            obj.resizeIm();
            obj.hLiveValueTool = dabs.resources.configuration.private.LiveValueTool(obj);
        end
        
        function delete(obj)
            delete(obj.hListeners);
            most.idioms.safeDeleteObj(obj.hLiveValueTool);
            most.idioms.safeDeleteObj(obj.hBNCs);
            most.idioms.safeDeleteObj(obj.hFig);
        end
    end
    
    methods
        function raise(obj)
            hFig_ = ancestor(obj.hAx,'figure');
            most.idioms.figure(hFig_);
        end
        
        function highlightResource(obj,hResource)
            if nargin < 2 || isempty(hResource)
                hResource = [];
            end
            
            for idx = 1:numel(obj.hBNCs)
                obj.hBNCs(idx).highlightResource(hResource);
            end
        end
        
        function highlightWidget(obj)
            obj.hDAQ.highlightWidgets();
        end
    end
    
    methods (Hidden)
        function WindowButtonMotionFcn(obj,src,evt)
            for idx = 1:numel(obj.hBNCs)
                obj.hBNCs(idx).WindowButtonMotionFcn(src,evt);
            end
        end
    end
    
    methods (Access = private)
        function makeSurface(obj)
            [xx,yy,zz] = meshgrid([0 482.6],[0 88],0);
            im = [];
            obj.hSurf = surface('Parent',obj.hAx,'XData',xx,'YData',yy,'ZData',zz,'FaceColor','texturemap','CData',im,'LineStyle','none','ButtonDownFcn',@(varargin)obj.highlightWidget);
        end
        
        function resizeIm(obj)
            oldAxUnits = obj.hAx.Units;
            obj.hAx.Units = 'pixels';
            axPixSize = obj.hAx.Position(3:4);
            obj.hAx.Units = oldAxUnits;
            
            im = obj.readIm();
            im = most.gui.imageResample(im,round(axPixSize(1)));
            
            obj.hSurf.CData = im;
        end
        
        function im = readIm(obj)
            folder = fileparts(mfilename('fullpath'));
            file = fullfile(folder,'vDAQR1Breakout.PNG');
            im = imread(file);
        end
        
        function makeAIs(obj)
            hAIs = obj.hDAQ.hAIs;
            
            [yy,xx] = meshgrid(linspace(0,21,2),linspace(0,130,6));
            xx = xx+34.5;
            yy = yy+12.5;
            pos = [xx(:),yy(:)];
            
            for idx = 1:size(pos,1)
                hAI = hAIs(idx);
                hBNC = dabs.resources.configuration.private.BNC(hAI,obj.hAx);
                hBNC.Position = pos(idx,:);                
                obj.hBNCs(end+1) = hBNC;
            end
        end
        
        function makeAOs(obj)
            [yy,xx] = meshgrid(linspace(0,21,2),linspace(0,130,6));
            xx = xx + 34.5;
            yy = yy + 54.5;
            pos = [xx(:),yy(:)];
            
            hAOs = obj.hDAQ.hAOs;
            
            for idx = 1:size(pos,1)
                hAO = hAOs(idx);
                hBNC = dabs.resources.configuration.private.BNC(hAO,obj.hAx);
                hBNC.Position = pos(idx,:);                
                obj.hBNCs(end+1) = hBNC;
            end
        end
        
        function makeDIOs(obj)            
            ports = {obj.hDAQ.hDIOs(1:8) obj.hDAQ.hDIOs(9:16) obj.hDAQ.hDIs obj.hDAQ.hDOs};
            numPorts = 4;
            
            for portIdx = 1:numPorts
                xOffset = (portIdx-1) * 56 + 260.3;
                [yy,xx] = meshgrid(linspace(0,63,4),linspace(0,26,2));
                
                xx = xx + xOffset;
                yy = yy + 12.5;
                
                pos = [xx(:),yy(:)];
                
                Ds = ports{portIdx};
                
                for dioIdx = 1:size(pos,1)
                    hBNC = dabs.resources.configuration.private.BNC(Ds(dioIdx),obj.hAx);
                    hBNC.Position = pos(dioIdx,:);
                    obj.hBNCs(end+1) = hBNC;
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
