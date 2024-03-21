classdef ThorBCMWidget < dabs.resources.widget.Widget
    properties
        hButtonFlow
        hListeners = event.listener.empty(0,1);
        hBCMs;
        hButtons;
    end
    
    methods
        function obj = ThorBCMWidget(hResource,hParent)
            obj@dabs.resources.widget.Widget(hResource,hParent);
            
            hBCMs_ =obj.hResourceStore.filterByClass(class(hResource));
            obj.hBCMs = horzcat(hBCMs_{:});
            
            mask = arrayfun(@(hR)hR==hResource,obj.hBCMs);
            idx = find(mask,1);
            
            if ~isequal(idx,1)
                obj.delete();
                return
            end
            
            for idx = 1:numel(obj.hBCMs)
                hBCM = obj.hBCMs(idx);
                obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(hBCM,'currentPositionLabel','PostSet',@(varargin)obj.redraw);
                obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(hBCM,'errorMsg','PostSet',@(varargin)obj.redraw);
            end
            
            try
                obj.redraw();
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
        end
        
        function delete(obj)
            obj.hListeners.delete();
        end
       
       function makePanel(obj,hParent)
           obj.hButtonFlow = most.gui.uiflowcontainer('Parent',hParent,'FlowDirection','TopDown','margin',2);
       end
       
       function redraw(obj)
           if numel(obj.hBCMs) > 1
               obj.hTxtTitle.String = 'BCM Control';
           else
               obj.hTxtTitle.String = obj.hBCMs.name;
           end
           most.idioms.safeDeleteObj(obj.hButtons);
           obj.hButtons = matlab.ui.control.UIControl.empty();
           
           for idx = 1:numel(obj.hBCMs)
               hBCM = obj.hBCMs(idx);
               hButton = uicontrol('Parent',obj.hButtonFlow,'Style','togglebutton','String','','Callback',@(varargin)obj.toggle(hBCM));
               hButton.HeightLimits = [15 30];
               
               obj.hButtons(idx) = hButton;
               
               hButton.Value = hBCM.currentPosition;
               
               if isempty(hBCM.errorMsg)
                   hButton.String = hBCM.currentPositionLabel;
               else
                   hButton.String = [hBCM.name, ': ERROR'];
                   hButton.BackgroundColor = most.constants.Colors.lightRed;
               end
           end
       end
       
       function toggle(obj,hBCM)
           try
               hBCM.togglePosition();
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
