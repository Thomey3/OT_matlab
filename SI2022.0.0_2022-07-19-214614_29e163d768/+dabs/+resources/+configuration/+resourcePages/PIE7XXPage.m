classdef PIE7XXPage < dabs.resources.configuration.ResourcePage
    properties
        pmConnectionName;
        pmBaudRate;
        
    end
    
    methods
        function obj = PIE7XXPage(hResource,hParent)
            obj@dabs.resources.configuration.ResourcePage(hResource,hParent);
        end
        
        function makePanel(obj,hParent)
            hTabGroup = uitabgroup('Parent',hParent);
            hTab = uitab('Parent',hTabGroup,'Title','Basic');
			    most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [14 30 120 20],'Tag','txhCOM','String','Serial port / USB','HorizontalAlignment','right');
                obj.pmConnectionName  = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [140 27 220 20],'Tag','pmConnectionName');
                
            hTab = uitab('Parent',hTabGroup,'Title','Advanced');
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [48 66 140 20],'Tag','txtBaud','String','Serial connection baud rate','HorizontalAlignment','right');
                str = {'300' '1200' '2400' '4800' '9600' '14400' '19200' '38400' '57600' '115200'};
                obj.pmBaudRate = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','RelPosition', [200 62 70 20],'Tag','pmBaudRate', 'String', str);
        end
        
        function redraw(obj)
		    % Basic Tab
            usbNames = obj.hResource.enumerateControllers();
            hCOMs = obj.hResourceStore.filterByClass(?dabs.resources.SerialPort);
            hCOMNames = cellfun(@(cp)cp.name,hCOMs,'UniformOutput',false);
            obj.pmConnectionName.String = unique([{''} hCOMNames usbNames {obj.hResource.connectionName}]);
            obj.pmConnectionName.pmValue = obj.hResource.connectionName;
            
            % Advanced Tab
            obj.pmBaudRate.String = {'300' '1200' '2400' '4800' '9600' '14400' '19200' '38400' '57600' '115200'};
            obj.pmBaudRate.pmValue = num2str(obj.hResource.baudRate);
        end
        
        function apply(obj)
            most.idioms.safeSetProp(obj.hResource,'connectionName',obj.pmConnectionName.pmValue);
            most.idioms.safeSetProp(obj.hResource,'baudRate', str2num(obj.pmBaudRate.pmValue)); % str2num used because str2double('') = nan, whereas str2num('') = [];
            
            obj.hResource.saveMdf();
            obj.hResource.reinit();
        end
        
        function remove(obj)
            obj.hResource.deleteAndRemoveMdfHeading();
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
