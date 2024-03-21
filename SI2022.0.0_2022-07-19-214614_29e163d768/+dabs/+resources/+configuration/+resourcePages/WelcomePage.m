classdef WelcomePage < dabs.resources.configuration.ResourcePage
    methods
        function obj = WelcomePage(hResource,hParent)
            obj@dabs.resources.configuration.ResourcePage(hResource,hParent);
        end

        function makeLayout(obj)
            % overload parent function
            obj.makePanel(obj.hParent);
        end
        
        function makePanel(obj,hParent)
            hFlow = most.gui.uiflowcontainer('Parent',hParent,'FlowDirection','TopDown','margin',1);
                hFlowLogo = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','LeftToRight','margin',1,'HeightLimits',[80 80]);
                hFlowText = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','TopDown','margin',10);
            
            autoStart = false;
            hLogo = scanimage.util.ScanImageLogo(hFlowLogo,autoStart);
            hLogo.color = most.constants.Colors.darkGray;
            hLogo.backgroundColor = most.constants.Colors.lightGray;
            hLogo.progress = 1;
            
            hLine = makeLine(20);
            hLine.String = 'Welcome to the ScanImage configuration editor.';
            
            hLine = makeLine(20);
            hLine.String = 'To get started, follow these steps:';
            
            hLine = makeLine(70);
            hLine.String = [most.constants.Unicode.bullet ' Select the ''Devices'' tab and add devices you want to control with ScanImage. Use the Widget Bar to test the device behavior. Devices that are not configured correctly, or that are in an error state are highlighted in red.'];
            
            hLine = makeLine(80);
            hLine.String = [most.constants.Unicode.bullet ' After all devices are configured, select the ''ScanImage'' tab. Add at least one ''Imaging System'', and associate the devices configured in the previous step with the imaging system. When no device or system are highlighted in red, you are ready to start ScanImage.'];
            
            
            function hLine = makeLine(height)
                hFlowLine = most.gui.uiflowcontainer('Parent',hFlowText,'FlowDirection','LeftToRight','margin',0.1,'HeightLimits',[height height]);
                hLine = uicontrol('Parent',hFlowLine,'Style','text','HorizontalAlignment','left','FontSize',10,'Units','normalized','Position',[0 0 1 1]);
            end
        end
        
        function redraw(obj)
        end
        
        function apply(obj)
        end
        
        function remove(obj)
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
