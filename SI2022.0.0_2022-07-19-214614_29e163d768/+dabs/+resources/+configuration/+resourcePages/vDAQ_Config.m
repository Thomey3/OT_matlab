classdef vDAQ_Config < dabs.resources.configuration.ResourcePage
    properties
        pmVdaq
        pmBitfile
        cbPassive
        
        serials;
    end
    
    methods
        function obj = vDAQ_Config(hResource,hParent)
            obj@dabs.resources.configuration.ResourcePage(hResource,hParent);
        end
        
        function makePanel(obj,hParent)
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [24 30 120 20],'String','vDAQ to Configure','HorizontalAlignment','right');
            obj.pmVdaq  = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [150 27 180 20]);
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [23 54 120 20],'String','Bitfile Name','HorizontalAlignment','right');
            obj.pmBitfile  = most.gui.popupMenuEdit('Parent',hParent,'RelPosition', [150 51 180 20]);
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [22 74 120 20],'String','Passive Initialization','HorizontalAlignment','right');
            obj.cbPassive = most.gui.uicontrol('Parent',hParent,'Style','checkbox','RelPosition', [150 72 120 20]);
        end
        
        function redraw(obj)
            % generating this list manually because we don't want to
            % trigger full bitstream load
            n = dabs.vidrio.rdi.Device.getDriverInfo().numDevices;
            nms = {};
            obj.serials = {};
            for i = n:-1:1
                id = i-1;
                hFpga = scanimage.fpga.vDAQ_SI(id);
                nfo = hFpga.deviceInfo;
                if ~nfo.designLoaded
                    hFpga.loadInitialDesign();
                end
                obj.serials{i} = hFpga.deviceSerialNumber;
                delete(hFpga);
                
                nms{i} = sprintf('vDAQ%d (R%d.%s SN:%s)', id, nfo.hardwareRevision, nfo.firmwareVersion, obj.serials{i});
            end
            obj.pmVdaq.String = [{' '} nms];
            
            if isempty(obj.hResource.vdaqNumber)
                obj.pmVdaq.Value = 1;
            else
                obj.pmVdaq.Value = obj.hResource.vdaqNumber+2;
                oldSn = obj.serials{obj.hResource.vdaqNumber+1};
                newSn = obj.hResource.serialNumber;
                if ~isempty(obj.hResource.serialNumber) && ~strcmp(newSn, oldSn)
                    % warn user that serial number has changed. this could
                    % happen if PCIe slots were changed
                    warndlg(sprintf('vDAQ%d has changed from SN:%s to SN:%s. Verify wiring configuration is correct.', obj.hResource.vdaqNumber, oldSn, newSn), 'vDAQ Configuration');
                end
            end
            
            obj.pmBitfile.choices = [{''} obj.hResource.availableBitfiles];
            
            obj.pmBitfile.string = obj.hResource.bitfileName;
            obj.cbPassive.Value = obj.hResource.passiveMode;
        end
        
        function apply(obj)
            v = obj.pmVdaq.Value - 1;
            if v
                most.idioms.safeSetProp(obj.hResource,'vdaqNumber',v-1);
                most.idioms.safeSetProp(obj.hResource,'serialNumber',obj.serials{v});
            else
                most.idioms.safeSetProp(obj.hResource,'vdaqNumber',[]);
                most.idioms.safeSetProp(obj.hResource,'serialNumber','');
            end

            most.idioms.safeSetProp(obj.hResource,'bitfileName',obj.pmBitfile.string);
            most.idioms.safeSetProp(obj.hResource,'passiveMode',obj.cbPassive.Value);
            
            obj.hResource.saveMdf();
            obj.hResource.reinit();
            if evalin('base','exist(''hSI'',''var'')==1')
                most.idioms.warn('Must restart ScanImage for vDAQ Advanced Parameter changes to take effect.');
            end
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
