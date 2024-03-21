classdef stageCoordinates < handle
    properties
        hPanel;
        hAx;
        hListeners = event.listener.empty();
        positionXYZ = [0,0,7];
        im = [];
        hSurf;
        hLineCrosshair;
        hZQuiver
        hZText
    end
    
    methods
        function obj = stageCoordinates(hParent)
            if nargin<1 || isempty(hParent)
                hParent = most.idioms.figure();
            end
            
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(hParent,'ObjectBeingDestroyed',@(varargin)obj.delete);
            obj.loadImage();
            obj.makePanel(hParent);
            obj.redraw();
        end
        
        function delete(obj)
            delete(obj.hListeners);
            most.idioms.safeDeleteObj(obj.hPanel);
        end
    end
    
    methods
        function loadImage(obj)
            filePath = fileparts(mfilename('fullpath'));
            filePath = fullfile(filePath,'Hippocampus_Jae_Sung_Lee.png');
            obj.im = imread(filePath);
        end
        
        function makePanel(obj,hParent)
            obj.hPanel = uipanel('Parent',hParent,'BorderType','none');
            obj.makeButtons(obj.hPanel);
            obj.makeAxes(obj.hPanel);
            
            tip = sprintf('ScanImage controls the position of the focal point in the sample.\nUse the buttons below for an example of a correct stage setup.');
            most.gui.uicontrol('Parent',obj.hPanel,'Tag','Tip','RelPosition', [4 33 340 30],'Style','text','String',tip,'HorizontalAlignment','left');
        end
        
        function makeAxes(obj,hParent)
            hAxPanel = most.gui.uicontrol('Parent',hParent,'Style','uipanel','BorderType','none','RelPosition', [1 168 190 130],'Tag','panel');
            obj.hAx = most.idioms.axes('Parent',hAxPanel.hCtl);
            
            hold(obj.hAx,'on');
            
            [xx,yy,zz] = ndgrid([-0.5 0.5],[-0.5 0.5],0);
            obj.hSurf = surface('Parent',obj.hAx,'XData',xx,'YData',yy,'ZData',zz,'FaceColor','texturemap','CData',NaN);
            obj.hLineCrosshair = line('Parent',obj.hAx,'XData',[-1 1 NaN 0 0]*0.1,'YData',[0 0 NaN -1 1]*0.1,'Color','white','LineWidth',1.5);
            quiver([0;0]-0.4,[0;0]-0.4,[1;0]*0.8,[0;1]*0.8,'Parent',obj.hAx,'Color','white','LineWidth',1.5,'MaxHeadSize',0.5);
            text('Parent',obj.hAx,'Position',[ 0.4 -0.4],'String','X','HorizontalAlignment','center','VerticalAlignment','middle','FontWeight','bold','Color','white');
            text('Parent',obj.hAx,'Position',[-0.4  0.4],'String','Y','HorizontalAlignment','center','VerticalAlignment','middle','FontWeight','bold','Color','white');
            obj.makeObjective();
            hold(obj.hAx,'off');
            
            view(obj.hAx,0,-90);
            obj.hAx.Units = 'normalized';
            obj.hAx.Position = [0 0 1 1];
            obj.hAx.DataAspectRatio = [1,1,1];
            obj.hAx.XLim = [-0.5,0.85];
            obj.hAx.YLim = [-0.5,0.5];
            obj.hAx.Visible = 'off';
            colormap(gray);
        end
        
        function makeObjective(obj)
            hParent = hgtransform('Parent',obj.hAx);
            
            obj.hZQuiver = quiver(0,0.1,0,10,'Parent',hParent,'Color','black','LineWidth',1.5,'MaxHeadSize',0.5);
            
            hPatch = patch('Parent',hParent,'LineStyle','none','FaceColor',most.constants.Colors.darkGray);
            objectiveVertices = [0 0
                                 1 0
                                 2 -1
                                 2 -3
                                -2 -3
                                -2 -1
                                -1 0
                                 0 0];
            hPatch.Vertices = objectiveVertices;
            hPatch.Faces = 1:size(objectiveVertices,1);
            
            obj.hZText = text('Parent',hParent,'Position',[0 10],'String','Z','HorizontalAlignment','center','VerticalAlignment','top','FontWeight','bold','Color','black');
            
            hParent.Matrix([1,6]) =  0.07;
            hParent.Matrix(13)    =  0.7;
            hParent.Matrix(14)    = -0.35;
        end
        
        function makeButtons(obj,hParent)
            most.gui.uicontrol('Parent',hParent,'Tag','Ydec','String',most.constants.Unicode.black_up_pointing_triangle,'Style','pushbutton','Callback',@(varargin)obj.incrementAxis(2,-1),'RelPosition', [230 87 30 30],'TooltipString','Decrement Y axis');
            most.gui.uicontrol('Parent',hParent,'Tag','Yinc','String',most.constants.Unicode.black_down_pointing_triangle,'Style','pushbutton','Callback',@(varargin)obj.incrementAxis(2,+1),'RelPosition', [230 147 30 30],'TooltipString','Increment Y axis');
            most.gui.uicontrol('Parent',hParent,'Tag','Xdec','String',most.constants.Unicode.black_left_pointing_triangle,'Style','pushbutton','Callback',@(varargin)obj.incrementAxis(1,-1),'RelPosition', [200 117 30 30],'TooltipString','Decrement X axis');
            most.gui.uicontrol('Parent',hParent,'Tag','Xinc','String',most.constants.Unicode.black_right_pointing_triangle,'Style','pushbutton','Callback',@(varargin)obj.incrementAxis(1,+1),'RelPosition', [260 117 30 30],'TooltipString','Increment X axis');
            most.gui.uicontrol('Parent',hParent,'Tag','X/Y','String','X/Y','Style','text','HorizontalAlignment','center','RelPosition', [236 115 20 20]);
            
            most.gui.uicontrol('Parent',hParent,'Tag','Zdec','String',most.constants.Unicode.black_up_pointing_triangle,'Style','pushbutton','Callback',@(varargin)obj.incrementAxis(3,-1),'RelPosition', [310 87 30 30],'TooltipString','Decrement Z axis');
            most.gui.uicontrol('Parent',hParent,'Tag','Zinc','String',most.constants.Unicode.black_down_pointing_triangle,'Style','pushbutton','Callback',@(varargin)obj.incrementAxis(3,+1),'RelPosition', [310 147 30 30],'TooltipString','Increment Z axis');
            most.gui.uicontrol('Parent',hParent,'Tag','Z','String','Z','Style','text','HorizontalAlignment','center','RelPosition', [320 115 10 20]);
        end
        
        function incrementAxis(obj,ax,d)
            obj.positionXYZ(ax) = obj.positionXYZ(ax) + d;
            obj.redraw();
        end
        
        function redraw(obj)
            CData = obj.im;
            
            CData = circshift(CData,-obj.positionXYZ(1)*5,2);
            CData = circshift(CData,-obj.positionXYZ(2)*5,1);
            
            windowSize = 200;
            
            mm = round( size(CData,1)/2 + [-0.5 0.5] * windowSize );
            nn = round( size(CData,2)/2 + [-0.5 0.5] * windowSize) ;
            
            CData = CData(mm(1):mm(2),nn(1):nn(2));
            
            obj.hSurf.CData = CData';
            
            quiverLength = 10;
            obj.hZQuiver.YData = obj.positionXYZ(3)-quiverLength;
            obj.hZQuiver.VData = quiverLength;
            obj.hZText.Position(2) = obj.positionXYZ(3);
        end
        
        function set.positionXYZ(obj,val)
            val(3) = max(min(val(3),10),2);
            obj.positionXYZ = val;
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
