classdef FastZControls < handle    
    properties
        hSI
        hGui
        hParent
        hPanel
        hFastZ
        postfix
        isCurrent = false;
        
        panelWidth = 70;
        
        hListeners = event.listener.empty(0,1);
    end
    
    properties (SetObservable)
        fastZIncrement = 10;
    end
    
    methods
        function obj = FastZControls(hGui,hParent,hFastZ,postfix)
            obj.hGui = hGui;
            obj.hSI = hGui.hModel;
            obj.hParent = hParent;
            obj.hFastZ = hFastZ;
            obj.postfix = postfix;
            
            obj.makeFastZPanel();
            
            obj.hListeners(end+1) = addlistener(hFastZ,'errorMsg','PostSet',@(varargin)obj.errorMsgChanged);
            obj.hListeners(end+1) = addlistener(hFastZ,'targetPosition','PostSet',@(varargin)obj.targetPositionChanged);
            obj.hListeners(end+1) = addlistener(obj.hSI,'hScan2D','PostSet',@(varargin)obj.currentFastZsChanged);
            
            obj.currentFastZsChanged();
            obj.targetPositionChanged();
            obj.errorMsgChanged();
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hListeners);
        end
        
        function makeFastZPanel(obj)
            hFlowFastZ = most.gui.uiflowcontainer('Parent', obj.hParent,'FlowDirection','TopDown');
            set(hFlowFastZ,'WidthLimits',[obj.panelWidth,obj.panelWidth]);
            
            obj.hPanel = most.gui.uipanel('Title',obj.hFastZ.name,'Parent',hFlowFastZ);
            
            obj.hGui.addUiControl('Parent',obj.hPanel,'Tag',['pbFastZZero' obj.postfix],'Style','pushbutton','String','Goto Zero','RelPosition', [5 42 55 20],'Enable','on','Callback',@(varargin)obj.move(0),'TooltipString','Move FastZ actuator to zero position');
            
            obj.hGui.addUiControl('Parent',obj.hPanel,'Tag',['lbFastZTarget'   obj.postfix],'Style','text','String','Target','RelPosition', [3 63 55 15]);
            obj.hGui.addUiControl('Parent',obj.hPanel,'Tag',['FastZTarget'     obj.postfix],'Style','edit','RelPosition', [5 82 55 20],'Callback',@(varargin)obj.changeTargetPosition,'TooltipString','Target position of the FastZ actuator.');
            obj.hGui.addUiControl('Parent',obj.hPanel,'Tag',['lbFastZFeedback' obj.postfix],'Style','text','String','Feedback','RelPosition', [6 103 55 15]);
            obj.hGui.addUiControl('Parent',obj.hPanel,'Tag',['FastZFeedback'   obj.postfix],'Style','edit','Bindings',{obj.hFastZ 'lastKnownPositionFeedback' 'value' '%.1f'},'RelPosition', [5 122 55 20],'Enable','off','BackgroundColor',most.constants.Colors.lightGray,'TooltipString','Feedback of the FastZ actuator.','ButtonDownFcn',@(varargin)obj.readFeedback);
            
            obj.hGui.addUiControl('Parent',obj.hPanel,'Tag',['FastZdec'  obj.postfix],'Style','pushbutton','String',most.constants.Unicode.black_up_pointing_triangle,'Callback',@(varargin)obj.incrementFastZ(-1),'RelPosition', [17 192 30 30],'TooltipString',['Decrement FastZ actuator position' most.constants.Unicode.new_line 'Alternative: hover mouse over axes and use scroll wheel' most.constants.Unicode.new_line 'Holding down the Ctrl key performs a 10x smaller step']);
            obj.hGui.addUiControl('Parent',obj.hPanel,'Tag',['FastZstep' obj.postfix],'Style','edit','Bindings',{obj 'fastZIncrement' 'value' '%.1f'},'RelPosition', [17 222 30 30],'TooltipString','Step size for FastZ actuator');
            obj.hGui.addUiControl('Parent',obj.hPanel,'Tag',['FastZinc'  obj.postfix],'Style','pushbutton','String',most.constants.Unicode.black_down_pointing_triangle,'Callback',@(varargin)obj.incrementFastZ(+1),'RelPosition', [17 252 30 30],'TooltipString',['Increment FastZ actuator position' most.constants.Unicode.new_line 'Alternative: hover mouse over axes and use scroll wheel' most.constants.Unicode.new_line 'Holding down the Ctrl key performs a 10x smaller step']);
            
            obj.hGui.addUiControl('Parent',obj.hPanel,'Tag',['pbAlignFastZ'     obj.postfix],'Style','pushbutton','String','Align','RelPosition', [5 282 55 20],'Enable','on','Callback',@(varargin)obj.alignFastZ(),'TooltipString','Align FastZ actuator to motor coordinate system');
            obj.hGui.addUiControl('Parent',obj.hPanel,'Tag',['pbCalibrateFastZ' obj.postfix],'Style','pushbutton','String','Calibrate','RelPosition', [5 149 55 20],'Enable','on','Callback',@(varargin)obj.hFastZ.calibrate(),'TooltipString','Calibrate FastZ actuator feedback. This will move the FastZ actuator through its entire range.');
        end
        
        function errorMsgChanged(obj)
            if isempty(obj.hFastZ.errorMsg)
                c = most.constants.Colors.lightGray;
            else
                c = most.constants.Colors.lightRed;
            end
            
            if most.idioms.isValidObj(obj.hPanel)
                obj.hPanel.BackgroundColor = c;
            end
        end
        
        function currentFastZsChanged(obj)
            currentFastZs = obj.hSI.hScan2D.hFastZs;
            obj.isCurrent = any(cellfun(@(cFzs)cFzs==obj.hFastZ,currentFastZs));
            
            if obj.isCurrent
                obj.hPanel.FontWeight = 'bold';
                obj.hPanel.Title = sprintf('<%s>',obj.hFastZ.name);
            else
                obj.hPanel.FontWeight = 'normal';
                obj.hPanel.Title = obj.hFastZ.name;
            end
        end
        
        function targetPositionChanged(obj)
            obj.hGui.(['FastZTarget' obj.postfix]).String = sprintf('%.3f',obj.hFastZ.targetPosition);
        end
        
        function changeTargetPosition(obj)
            try
                val = obj.hGui.(['FastZTarget' obj.postfix]).String;
                val = str2double(val);
                
                assert(~isnan(val));
                
                obj.move(val);
            catch ME
                obj.targetPositionChanged;
                rethrow(ME);
            end
        end
        
        function incrementFastZ(obj,direction,roundDigits)
            if nargin < 5
                roundDigits = [];
            end
            
            speedFactor = obj.hGui.getSpeedFactor();
            
            increment = speedFactor * direction * obj.fastZIncrement;
            
            hCtls = [obj.hGui.(['FastZdec' obj.postfix]).hCtl obj.hGui.(['FastZinc' obj.postfix]).hCtl];
            hCtl = hCtls(1.5 + 0.5*sign(direction));
            
            oldColor = hCtl.BackgroundColor;            
            hCtl.BackgroundColor = [0.65 1 0.65];
            
            try
                newPosition = roundTo(obj.hFastZ.targetPosition + increment,roundDigits);
                travelRange = obj.hFastZ.travelRange;
                newPosition = min(max(travelRange(1),newPosition),travelRange(2));
                obj.move(newPosition);
            catch ME
                hCtl.BackgroundColor = oldColor;
                rethrow(ME);
            end
            hCtl.BackgroundColor = oldColor;
        end
        
        function move(obj,position)
            obj.hSI.hFastZ.move(obj.hFastZ,position);
        end
        
        function alignFastZ(obj)
            obj.hFastZ.plotPositionLUT();
        end
        
        function feedbackPositions = readFeedback(obj)
            feedbackPositions = obj.hFastZ.readPositionFeedback();
        end
    end
end

%% Local functions
function val = roundTo(val,digits)
    if ~isempty(digits)
        val = round(val,digits);
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
