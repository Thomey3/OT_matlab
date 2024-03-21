classdef PIPiezoPage < dabs.resources.configuration.ResourcePage
    properties
        pmConnectionName;
        pmBaudRate;
        pmhAOControl
        pmhAIFeedback
        etVoltsPerDistance
        etDistanceVoltsOffset
        etTravelRange1
        etTravelRange2
        etParkPosition
        pmhFrameClockIn
        pbReadTravelRange
        cbServoMode
    end
    
    methods
        function obj = PIPiezoPage(hResource,hParent)
            obj@dabs.resources.configuration.ResourcePage(hResource,hParent);
        end
        
        function makePanel(obj,hParent)
            hTabGroup = uitabgroup('Parent',hParent);
            hTab = uitab('Parent',hTabGroup,'Title','Basic');
			    most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [14 30 120 20],'Tag','txhCOM','String','Serial port / USB','HorizontalAlignment','right');
                obj.pmConnectionName  = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [140 27 220 20],'Tag','pmConnectionName');
                
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [14 57 120 20],'Tag','txhAOControl','String','Control Channel','HorizontalAlignment','right');
                obj.pmhAOControl  = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [140 52 120 20],'Tag','pmhAOControl');

                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [13 84 120 20],'Tag','txVoltsPerDistance','String','Volts per micron','HorizontalAlignment','right');
                obj.etVoltsPerDistance = most.gui.uicontrol('Parent',hTab,'Style','edit','RelPosition', [140 82 120 20],'Tag','etVoltsPerDistance');
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [11 112 120 20],'Tag','txDistanceVoltsOffset','String','Volts Offset','HorizontalAlignment','right');
                obj.etDistanceVoltsOffset = most.gui.uicontrol('Parent',hTab,'Style','edit','RelPosition', [140 108 120 20],'Tag','etDistanceVoltsOffset');
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [11 135 120 20],'Tag','txTravelRange1','String','Lower travel range [um]','HorizontalAlignment','right');
                obj.etTravelRange1 = most.gui.uicontrol('Parent',hTab,'Style','edit','RelPosition', [140 133 120 20],'Tag','etTravelRange1');
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [11 161 120 20],'Tag','txTravelRange2','String','Upper Travel range [um]','HorizontalAlignment','right');
                obj.etTravelRange2 = most.gui.uicontrol('Parent',hTab,'Style','edit','RelPosition', [140 158 120 20],'Tag','etTravelRange2');
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [11 186 120 20],'Tag','txParkPosition','String','Park position [um]','HorizontalAlignment','right');
                obj.etParkPosition = most.gui.uicontrol('Parent',hTab,'Style','edit','RelPosition', [140 184 120 20],'Tag','etParkPosition');
                obj.pbReadTravelRange = most.gui.uicontrol('Parent',hTab,'Style','pushbutton','String', 'Read From Device', 'RelPosition', [139 214 123 22],'Tag','pbReadTravelRange', 'Callback', @obj.readTravelRange);
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [-30 242 170 20],'Tag','txhAIFeedback','String','Feedback Channel (optional)','HorizontalAlignment','right');
                obj.pmhAIFeedback = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [140 242 120 20],'Tag','pmhAIFeedback');
            
            hTab = uitab('Parent',hTabGroup,'Title','Advanced');
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [0 30.3333333333333 140 20],'Tag','txhFrameClockIn','String','Frame clock input','HorizontalAlignment','right');
                obj.pmhFrameClockIn = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [150 27.3333333333333 120 20],'Tag','pmhFrameClockIn');
                
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [48 66 140 20],'Tag','txtBaud','String','Serial connection baud rate','HorizontalAlignment','right');
                obj.pmBaudRate = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','RelPosition', [200 62 70 20],'Tag','pmBaudRate');
                
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [0 100 140 20],'Tag','txhFrameClockIn','String','Closed loop mode','HorizontalAlignment','right');
                obj.cbServoMode = most.gui.uicontrol('Parent',hTab,'Style','checkbox','RelPosition', [150 97 120 20],'Tag','cbServoMode','value',true);
        end
        
        function redraw(obj)
		    % Basic Tab
            usbNames = obj.hResource.enumerateUsbDevices();
            hCOMs = obj.hResourceStore.filterByClass(?dabs.resources.SerialPort);
            obj.pmConnectionName.String = [{''},usbNames,hCOMs];
            obj.pmConnectionName.pmValue = obj.hResource.connectionName;
            
            hAOs = obj.hResourceStore.filterByClass(?dabs.resources.ios.AO);
            obj.pmhAOControl.String = [{''}, hAOs];
            obj.pmhAOControl.pmValue = obj.hResource.hAOControl;
            
            hAIs = obj.hResourceStore.filterByClass(?dabs.resources.ios.AI);
            obj.pmhAIFeedback.String = [{''}, hAIs];
            obj.pmhAIFeedback.pmValue = obj.hResource.hAIFeedback;
            
            obj.etVoltsPerDistance.String = num2str(obj.hResource.voltsPerDistance);
            obj.etDistanceVoltsOffset.String = num2str(obj.hResource.distanceVoltsOffset);
            obj.etTravelRange1.String = num2str(obj.hResource.travelRange(1));
            obj.etTravelRange2.String = num2str(obj.hResource.travelRange(2));
            obj.etParkPosition.String = num2str(obj.hResource.parkPosition);
            
            % Advanced Tab
            hPFIs = obj.hResourceStore.filterByClass(?dabs.resources.ios.PFI);
            obj.pmhFrameClockIn.String = [{''}, hPFIs];
            obj.pmhFrameClockIn.pmValue = obj.hResource.hFrameClockIn;
            obj.pmhFrameClockIn.Enable = ~most.idioms.isValidObj(obj.hResource.hAOControl) || ~isa(obj.hResource.hAOControl.hDAQ,'dabs.resources.daqs.vDAQ');
            
            obj.pmBaudRate.String = {'300' '1200' '2400' '4800' '9600' '14400' '19200' '38400' '57600' '115200'};
            obj.pmBaudRate.pmValue = num2str(obj.hResource.baudRate);
            
            obj.cbServoMode.Value = obj.hResource.enableServoMode;
        end
        
        function apply(obj)
            most.idioms.safeSetProp(obj.hResource,'connectionName',obj.pmConnectionName.pmValue);
            most.idioms.safeSetProp(obj.hResource,'baudRate', str2num(obj.pmBaudRate.pmValue)); % str2num used because str2double('') = nan, whereas str2num('') = [];
            
            most.idioms.safeSetProp(obj.hResource,'hAOControl',obj.pmhAOControl.pmValue);
            most.idioms.safeSetProp(obj.hResource,'hAIFeedback',obj.pmhAIFeedback.pmValue);
            
            most.idioms.safeSetProp(obj.hResource,'voltsPerDistance',str2double(obj.etVoltsPerDistance.String));
            most.idioms.safeSetProp(obj.hResource,'distanceVoltsOffset',str2double(obj.etDistanceVoltsOffset.String));
            most.idioms.safeSetProp(obj.hResource,'travelRange',[str2double(obj.etTravelRange1.String) str2double(obj.etTravelRange2.String)]);
            most.idioms.safeSetProp(obj.hResource,'parkPosition',str2double(obj.etParkPosition.String));
            
            most.idioms.safeSetProp(obj.hResource,'hFrameClockIn',obj.pmhFrameClockIn.pmValue);
            
            most.idioms.safeSetProp(obj.hResource,'enableServoMode', logical(obj.cbServoMode.Value));
            
            obj.hResource.saveMdf();
            obj.hResource.reinit();
        end
        
        function remove(obj)
            obj.hResource.deleteAndRemoveMdfHeading();
        end
    end
    
    methods
        function readTravelRange(obj, src, evt)
            if isempty(obj.hResource.errorMsg)
                obj.hResource.readDeviceTravelRange();
                obj.redraw();
            else
                hFig_ = warndlg('Not connected to PI device.');
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
