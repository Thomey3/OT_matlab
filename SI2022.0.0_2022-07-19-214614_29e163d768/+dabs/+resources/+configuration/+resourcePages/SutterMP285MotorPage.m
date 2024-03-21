classdef SutterMP285MotorPage < dabs.resources.configuration.resourcePages.SerialMotorPage
    properties
        txDeprecationWarning
    end
    
    methods
        function obj = SutterMP285MotorPage(hResource,hParent)
            obj@dabs.resources.configuration.resourcePages.SerialMotorPage(hResource,hParent);
        end
        
        function makePanel(obj,hParent)
            obj.makePanel@dabs.resources.configuration.resourcePages.SerialMotorPage(hParent);
            
            obj.txDeprecationWarning = most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [30 150 320 70],'Tag','txDeprecationWarning','HorizontalAlignment','center');
            obj.txDeprecationWarning.String = 'The MP285 Controller is deprecated and is no longer recommended for use with ScanImage. Unexpected behavior might result. Please consider upgrading your motor controller to a model supported by ScanImage.';
            obj.txDeprecationWarning.hCtl.BackgroundColor = most.constants.Colors.lightRed;
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
