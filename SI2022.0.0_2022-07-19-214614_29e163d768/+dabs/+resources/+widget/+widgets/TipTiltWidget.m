classdef TipTiltWidget < dabs.resources.widget.Widget
    properties (SetAccess = private,Hidden)
        hListeners = event.listener.empty(0,1);
        etTip
        etTilt
        etInc
    end
    
    properties (SetObservable)
        inc = 0.1;
    end
    
    methods
        function obj = TipTiltWidget(hResource,hParent)
            obj@dabs.resources.widget.Widget(hResource,hParent);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'tip','PostSet',@(varargin)obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'tilt','PostSet',@(varargin)obj.redraw);
        end
        
        function delete(obj)
            obj.hListeners.delete();
        end
    end
    
    methods
        function makePanel(obj,hParent)
            hMainFlow = most.gui.uiflowcontainer('Parent',hParent,'FlowDirection','TopDown');
                hFlow = most.gui.uiflowcontainer('Parent',hMainFlow,'FlowDirection','LeftToRight','HeightLimits',[20 20],'margin',0.001);
                    most.gui.uicontrol('Parent',hFlow,'Style','text','String','Tip','WidthLimits',[20 20]);
                    obj.etTip = most.gui.uicontrol('Parent',hFlow,'Style','edit','String','','Callback',@(varargin)obj.changeTip);
                    most.gui.uicontrol('Parent',hFlow,'Style','text','String','Tilt','WidthLimits',[20 20]);
                    obj.etTilt= most.gui.uicontrol('Parent',hFlow,'Style','edit','String','','Callback',@(varargin)obj.changeTilt);
            
                hPanel = uipanel('Parent',hMainFlow,'Title','','BorderType','none');
                    most.gui.uicontrol('Parent',hPanel,'String',most.constants.Unicode.black_left_pointing_triangle ,'Tag', 'left','RelPosition', [18 54 27 27],'Callback',@(varargin)obj.move(-1, 0));
                    most.gui.uicontrol('Parent',hPanel,'String',most.constants.Unicode.black_right_pointing_triangle,'Tag','right','RelPosition', [73 54 27 27],'Callback',@(varargin)obj.move( 1, 0));
                    most.gui.uicontrol('Parent',hPanel,'String',most.constants.Unicode.black_up_pointing_triangle   ,'Tag',   'up','RelPosition', [45 27 27 27],'Callback',@(varargin)obj.move( 0,-1));
                    most.gui.uicontrol('Parent',hPanel,'String',most.constants.Unicode.black_down_pointing_triangle ,'Tag', 'down','RelPosition', [45 82 27 27],'Callback',@(varargin)obj.move( 0, 1));
                    obj.etInc = most.gui.uicontrol('Parent',hPanel,'RelPosition', [45 54 27 27],'Tag','inc','Style','edit','String','','Bindings',{obj 'inc' 'value' '%.2f'});
                    
            try
                obj.redraw();
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
        end
        
        function redraw(obj)
            obj.etTip.String  = num2str(obj.hResource.tip);
            obj.etTilt.String = num2str(obj.hResource.tilt);
        end
        
        function move(obj,tipInc,tiltInc)
            if tipInc~=0
                tip = obj.hResource.tip + obj.inc*tipInc;
                obj.hResource.changeTip(tip);
            end
            
            if tiltInc~=0
                tilt = obj.hResource.tilt + obj.inc*tiltInc;
                obj.hResource.changeTilt(tilt);
            end
        end
        
        function set.inc(obj,val)
            validateattributes(val,{'numeric'},{'scalar','nonnan','finite','real'});
            assert(val~=0,'Increment cannot be zero');
            obj.inc = val;
        end
        
        function changeTip(obj)
            try
                tip = str2double(obj.etTip.String);
                obj.hResource.changeTip(tip);
            catch ME
                obj.redraw();
                most.ErrorHandler.logAndReportError(ME);
            end
        end
        
        function changeTilt(obj)
            try
                tilt = str2double(obj.etTilt.String);
                obj.hResource.changeTilt(tilt);
            catch ME
                obj.redraw();
                most.ErrorHandler.logAndReportError(ME);
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
