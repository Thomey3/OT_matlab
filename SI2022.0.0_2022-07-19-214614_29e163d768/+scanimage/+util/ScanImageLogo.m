classdef ScanImageLogo < handle
    properties
        progress
        backgroundColor = most.constants.Colors.vidrioBlue;
        color = 'white';
        Position
        Units
    end
    
    properties
        lineXY
        hParent
        hContainer
        hLine
        hLinePt
        hText
        hTextR
        hAx
    end
    
    methods
        function obj = ScanImageLogo(hParent,autoStart)
            if nargin < 2 || isempty(autoStart)
                autoStart = true;
            end
            
            obj.hParent = hParent;
            obj.init();
            obj.resize();
            
            obj.progress = 0;
            if autoStart
                obj.animate();
            end
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hContainer);
        end
        
        function init(obj)
            xx1 = linspace(-1,0,100)';
            yy1 = ones(size(xx1));
            
            turns = 4;
            nSamples = 500;
            yy2 = linspace(0,2*pi*turns,nSamples)';
            xx2 = sin(yy2)/2;
            yy2 = 1-yy2./(yy2(end));
            
            xx3 = linspace(0,6,100)';
            yy3 = zeros(size(xx3));
            
            obj.lineXY = struct();
            obj.lineXY.xx = vertcat(xx1,xx2,xx3);
            obj.lineXY.yy = vertcat(yy1,yy2,yy3);
            
            xLim = [min(obj.lineXY.xx),max(obj.lineXY.xx)];
            yLim = [min(obj.lineXY.yy),max(obj.lineXY.yy)];
            
            if isempty(obj.hParent)
                obj.hParent = most.idioms.figure();
            end
            
            if isempty(obj.backgroundColor) || (ischar(obj.backgroundColor) && strcmpi(obj.backgroundColor,'none'))
                params = {};
            else
                params = {'BackgroundColor',obj.backgroundColor};
            end
            obj.hContainer = uicontainer('Parent',obj.hParent,'SizeChangedFcn',@(varargin)obj.resize(),params{:});

            obj.hAx = most.idioms.axes('Parent',obj.hContainer,'DataAspectRatio',[1 1 1],'XLim',xLim,'YLim',yLim,'Visible','off','XTick',[],'YTick',[],'LooseInset',[0.05 0.1 0.1 0.1]);
            obj.hLine = line('Parent',obj.hAx,'Color',obj.color,'XData',[],'YData',[]);
            obj.hLinePt = line('Parent',obj.hAx,'Color',obj.color,'LineStyle','none','Marker','*','XData',[],'YData',[]);
            obj.hText = text('Parent',obj.hAx,'Position',[.8 0.1 0],'String','ScanImage','FontName','Arial','VerticalAlignment','bottom','FontWeight','bold','Color',obj.color);
            obj.hTextR = text('Parent',obj.hAx,'Position',[5.5 0.8 0],'String',most.constants.Unicode.registered_sign,'FontName','Arial','VerticalAlignment','bottom','Color',obj.color);
        end
        
        function animate(obj)
            obj.progress = 0;
            most.gui.Transition(2,obj,'progress',1,'sinIn');
        end
        
        function resize(obj)
            if isempty(obj.hAx)
                return
            end
            units_ = obj.hAx.Units;
            obj.hAx.Units = 'points';
            pos = obj.hAx.Position;
            obj.hAx.Units = units_;
            
            xsz = diff(obj.hAx.XLim);
            ysz = diff(obj.hAx.YLim);
            if xsz/ysz < pos(3)/pos(4)
                sz = pos(4) * xsz/ysz;
            else
                sz = pos(3);
            end
            
            sz = sz * 0.085;
            obj.hLine.LineWidth = sz * 0.1;
            obj.hLinePt.LineWidth = sz * 0.1;
            obj.hLinePt.MarkerSize = sz * 0.8;
            obj.hText.FontSize = sz * 1.5;
            obj.hTextR.FontSize = sz * 0.4;
        end
        
        function updateLine(obj)
            if obj.progress == 0
                obj.hLine.XData = [];
                obj.hLine.YData = [];
                obj.hLinePt.XData = [];
                obj.hLinePt.YData = [];
            else
                nPoints = ceil(numel(obj.lineXY.xx) * obj.progress);
                obj.hLine.XData = obj.lineXY.xx(1:nPoints);
                obj.hLine.YData = obj.lineXY.yy(1:nPoints);
                obj.hLinePt.XData = obj.lineXY.xx(nPoints);
                obj.hLinePt.YData = obj.lineXY.yy(nPoints);
            end
        end
        
        function set.progress(obj,val)
            validateattributes(val,{'single','double'},{'scalar','nonnan','>=',0,'<=',1});
            
            if ~most.idioms.isValidObj(obj.hLine)
                obj.delete();
                return
            end            
            
            obj.progress = val;
            obj.updateLine();
        end
        
        function val = get.Position(obj)
            val = obj.hContainer.Position;
        end
        
        function set.Position(obj,val)
            obj.hContainer.Position = val;
        end
        
        function val = get.Units(obj)
            val = obj.hContainer.Units;
        end
        
        function set.Units(obj,val)
            obj.hContainer.Units = val;
        end
        
        function set.backgroundColor(obj,val)
            obj.hContainer.BackgroundColor = val;
        end
        
        function set.color(obj,val)
            obj.hLine.Color = val;
            obj.hLinePt.Color = val;
            obj.hText.Color = val;
            obj.hTextR.Color = val;
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
