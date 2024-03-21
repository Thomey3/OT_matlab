classdef UserButtonsWidget < dabs.resources.widget.Widget
    properties
        hButtonFlow
        hListeners = event.listener.empty(0,1);
        hButtons = matlab.ui.control.UIControl.empty();
    end
    
    methods
        function obj = UserButtonsWidget(hResource,hParent)
            obj@dabs.resources.widget.Widget(hResource,hParent);

            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'userButtons','PostSet',@(varargin)obj.redraw);
            
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
           most.idioms.safeDeleteObj(obj.hButtons);
           obj.hButtons = matlab.ui.control.UIControl.empty();
           
           for idx = 1:numel(obj.hResource.userButtons)
               entry = obj.hResource.userButtons{idx};
               buttonName = entry{1};
               buttonFunction = entry{2};
               
               hButton = uicontrol('Parent',obj.hButtonFlow); 
               set(hButton,'HeightLimits',[20 20]);
               hButton.Callback = @(varargin)obj.executeFunction(buttonName,buttonFunction);
               hButton.String = buttonName;
               
               obj.hButtons(idx) = hButton;
           end
       end
       
       function executeFunction(obj,buttonName,buttonFunction)
           try
               obj.hResource.executeFunction(buttonName);
           catch ME
               most.ErrorHandler.logAndReportError(ME);
               msg = sprintf('Error executing function ''%s'':\n%s',func2str(buttonFunction),ME.message);
               hFig_ = errordlg(msg,obj.hResource.name);
               most.gui.centerOnScreen(hFig_);
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
