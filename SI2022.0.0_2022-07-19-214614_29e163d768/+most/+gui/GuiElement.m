classdef GuiElement < handle
    properties
        Position
        hUIPanel
        hParent
        Units
        minSizePixel = [0 0];
        maxSizePixel = [Inf Inf];
        hFig;
    end
    
    events (Hidden)
        scrollWheel;
    end
    
    properties (SetAccess = private,Hidden)
        hScrollWheelListener;
    end
    
    methods
        function obj = GuiElement(hParent,varargin)
            obj.hParent = hParent;
            
            if isa(obj.hParent,'matlab.ui.Figure')
                obj.hParent.SizeChangedFcn = @(varargin)obj.panelResized;
                obj.hParent.WindowScrollWheelFcn = @obj.scrollWheelListenerFcn;
                obj.hUIPanel = uipanel('Parent',hParent,varargin{:});
            else
                assert(isa(obj.hParent,mfilename('class')),'GuiElement can only be a child of a figure or another GuiElement');
                obj.hUIPanel = uipanel('Parent',hParent.hUIPanel,varargin{:});
                obj.hScrollWheelListener = most.ErrorHandler.addCatchingListener(obj.hParent,'scrollWheel',@obj.scrollWheelListenerFcn);
                obj.hScrollWheelListener.Recursive = true;
            end
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hUIPanel);
            most.idioms.safeDeleteObj(obj.hScrollWheelListener);
        end
        
        function scrollWheelListenerFcn(obj,src,evt)
            evt_ = most.gui.ScrollWheelData();
            evt_.VerticalScrollCount = evt.VerticalScrollCount;
            evt_.VerticalScrollAmount = evt.VerticalScrollAmount;
            obj.notify('scrollWheel',evt_);
            obj.scrollWheelFcn(src,evt);
        end
    end
    
    methods
        function set.Position(obj,val)
            obj.hUIPanel.Position = val;
            val = obj.getPositionInUnits('pixel');
            % scale around center
            sz = val(3:4);
            sz = max(sz,obj.minSizePixel);
            sz = min(sz,obj.maxSizePixel);
            val = [val(1)+(val(3)-sz(1))/2,val(2)+(val(4)-sz(2))/2,sz(1),sz(2)];
            
            obj.setPositionInUnits('pixel',val);
            obj.panelResized();
        end
        
        function maximize(obj)
            obj.setPositionInUnits('normalized',[0 0 1 1]);
            obj.panelResized();
        end
        
        function val = get.Position(obj)
            val = obj.hUIPanel.Position;
        end
        
        function set.Units(obj,val)
            obj.hUIPanel.Units = val;
        end
        
        function val = get.Units(obj) 
            val = obj.hUIPanel.Units;
        end
        
        function val = getPositionInUnits(obj,units)
            units_ = obj.Units;
            obj.Units = units;
            try
                val = obj.Position;
            catch ME
                obj.Units = units_;
                rethrow(ME);
            end
            obj.Units = units_;
        end
        
        function setPositionInUnits(obj,units,val)
            units_ = obj.Units;
            obj.Units = units;
            try
                obj.hUIPanel.Position = val;
            catch ME
                obj.Units = units_;
                rethrow(ME);
            end
            obj.Units = units_;
            obj.panelResized();
        end
        
        function val = get.hFig(obj)
            val = ancestor(obj.hUIPanel,'figure');
        end
    end
    
    methods (Abstract)
        panelResized(obj)
        init(obj)
        scrollWheelFcn(obj,src,evt)
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
