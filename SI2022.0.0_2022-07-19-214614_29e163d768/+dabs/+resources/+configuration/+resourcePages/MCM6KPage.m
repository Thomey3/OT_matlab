classdef MCM6KPage < dabs.resources.configuration.ResourcePage
    properties
        pmhCOM
        txBaudRate
        pmBaudRate
        
        pmFlipperMirrorSlot
        pmShutterSlot
        cbAutoRead;
        
        txInfo
    end
    
    properties (Dependent)
        isBaudRateSettable
    end
    
    methods
        function obj = MCM6KPage(hResource,hParent)
            obj@dabs.resources.configuration.ResourcePage(hResource,hParent);
        end
        
        function makePanel(obj,hParent)
            hTabGroup = uitabgroup('Parent',hParent);
            
            hTab = uitab('Parent',hTabGroup,'Title','Basic');
            most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [24 30 120 20],'Tag','txhComPort','String','Serial Port','HorizontalAlignment','right');
            obj.pmhCOM  = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [150 27 120 20],'Tag','pmhCOM');
            obj.txBaudRate = most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [24 55 120 20],'Tag','txhComPort','String','Baud rate','HorizontalAlignment','right');
            obj.pmBaudRate = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [150 52 120 20],'Tag','pmBaudRate');
            obj.txInfo = most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [4 260 167 210],'Tag','txInfo','String','','HorizontalAlignment','left');
            
            hTab = uitab('Parent',hTabGroup,'Title','Advanced');
            most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [24 30 120 20],'Tag','txShutter','String','Shutter Slot','HorizontalAlignment','right');
            obj.pmShutterSlot  = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [150 27 120 20],'Tag','pmShutter');
            
            most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [24 55 120 20],'Tag','txMirror','String','Flipper Mirror Slot','HorizontalAlignment','right');
            obj.pmFlipperMirrorSlot = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [150 52 120 20],'Tag','pmMirror');
            
            most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [24 80 120 20],'Tag','txAutoRead','String','Enable Auto Read','HorizontalAlignment','right');
            obj.cbAutoRead = most.gui.uicontrol('Parent',hTab,'Style','checkbox','String',{''},'RelPosition', [150 77 120 20],'Tag','cbAutoRead');
        end
        
        function redraw(obj)            
            hCOMs = obj.hResourceStore.filterByClass(?dabs.resources.SerialPort);
            
            obj.pmhCOM.String = [{''}, hCOMs];
            obj.pmhCOM.pmValue = obj.hResource.hCOM;
            
            obj.txBaudRate.Visible = obj.isBaudRateSettable;
            obj.pmBaudRate.Visible = obj.isBaudRateSettable;
            
            if obj.isBaudRateSettable
                if isprop(obj.hResource,'availableBaudRates')
                    obj.pmBaudRate.String = arrayfun(@(v)num2str(v),obj.hResource.availableBaudRates,'UniformOutput',false);
                else
                    obj.pmBaudRate.String = {'75' '110' '150' '300' '600' '1200' '1800' '2400' '4800' '7200' '9600' '14400' '19200' '31250' '38400' '56000' '57600' '76800' '115200' '128000' '230400' '256000'};
                end
                obj.pmBaudRate.pmValue = num2str(obj.hResource.baudRate);
            end
            
            obj.pmShutterSlot.String = {'' '1', '2', '3', '4', '5', '6', '7'};
            obj.pmShutterSlot.pmValue = num2str(obj.hResource.shutterSlot);
            
            obj.pmFlipperMirrorSlot.String = {'' '1', '2', '3', '4', '5', '6', '7'};
            obj.pmFlipperMirrorSlot.pmValue = num2str(obj.hResource.mirrorSlot);
            
            obj.cbAutoRead.Value = obj.hResource.tfAutoRead;
            
            info = '';
            
            if ~isempty(obj.hResource.hardwareInfo)
                cellfo = cellfun(@(x,y) [x ' = ' y '\n'], fieldnames(obj.hResource.hardwareInfo), struct2cell(obj.hResource.hardwareInfo), 'UniformOutput', false);
                s = size(cellfo,1);

                for i=1:s
                    info = [info sprintf(cellfo{i})];
                end
                obj.txInfo.String = info;
                obj.txInfo.hCtl.BackgroundColor = most.constants.Colors.lightGray;
            end
        end
        
        function apply(obj)
            obj.hResource.deinit();
            most.idioms.safeSetProp(obj.hResource,'hCOM',obj.pmhCOM.pmValue);
            most.idioms.safeSetProp(obj.hResource,'shutterSlot',str2num(obj.pmShutterSlot.pmValue));
            most.idioms.safeSetProp(obj.hResource,'mirrorSlot',str2num(obj.pmFlipperMirrorSlot.pmValue));
            most.idioms.safeSetProp(obj.hResource,'tfAutoRead',logical(obj.cbAutoRead.Value));
            
            if obj.isBaudRateSettable
                obj.hResource.baudRate = str2double(obj.pmBaudRate.pmValue);
            end
            
            obj.hResource.saveMdf();
            obj.hResource.reinit();
            pause(0.2);
            obj.redraw();
        end
        
        function remove(obj)
            obj.hResource.deleteAndRemoveMdfHeading();
        end
    end
    
    methods
        function val = get.isBaudRateSettable(obj)
            mc = meta.class.fromName(class(obj.hResource));
            [tf,idx] = ismember('baudRate',{mc.PropertyList.Name});
            
            if ~tf
                val = false;
                return
            end
            
            mp = mc.PropertyList(idx);
            
            val = true;
            val = val && ~mp.Constant;
            val = val && strcmpi(mp.GetAccess,'public');
            val = val && strcmpi(mp.SetAccess,'public');
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
