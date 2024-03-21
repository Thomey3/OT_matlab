classdef SutterMP285AMotorPage < dabs.resources.configuration.ResourcePage
    properties
        pmhCOM
        txBaudRate
        pmBaudRate
        pmResolutionMode
        etVelocityFine
        etVelocityCoarse
        txStatus
        txThirdPartyInfo
    end
    
    properties (Dependent)
        isBaudRateSettable
    end
    
    methods
        function obj = SutterMP285AMotorPage(hResource,hParent)
            obj@dabs.resources.configuration.ResourcePage(hResource,hParent);
        end
        
        function makePanel(obj,hParent)   
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [24 30 120 20],'Tag','txhComPort','String','Serial Port','HorizontalAlignment','right');
            obj.pmhCOM  = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [150 27 120 20],'Tag','pmhCOM');
            obj.txBaudRate = most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [24 55 120 20],'Tag','txhComPort','String','Baud rate','HorizontalAlignment','right');
            obj.pmBaudRate = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [150 52 120 20],'Tag','pmBaudRate');

            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [27 89 120 20],'Tag','txResolutionMode','String','Resolution Mode','HorizontalAlignment','right');
            obj.pmResolutionMode = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{'fine','coarse'},'RelPosition', [150 83 120 20],'Tag','pmResolutionMode');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [26 110 120 20],'Tag','txVelocityFine','String','Fine Velocity [um/s]','HorizontalAlignment','right');
            obj.etVelocityFine = most.gui.uicontrol('Parent', hParent, 'Style', 'edit', 'String', num2str(obj.hResource.fineVelocity), 'RelPosition', [150 108 120 20], 'Tag', 'etVelocityFine');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [26 132 120 20],'Tag','txVelocityCoarse','String','Coarse Velocity [um/s]','HorizontalAlignment','right');
            obj.etVelocityCoarse = most.gui.uicontrol('Parent', hParent, 'Style', 'edit', 'String', num2str(obj.hResource.coarseVelocity), 'RelPosition', [150 131 120 20], 'Tag', 'etVelocityCoarse');

            obj.txThirdPartyInfo = most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [10 180 360 30],'Tag','txStatus','HorizontalAlignment','center','Enable','inactive','ButtonDownFcn',@(varargin)obj.showAdvancedSettings());
            obj.txThirdPartyInfo.String = ['If non-Sutter stages are used, please contact Sutter Instruments to obtain the drive current and scaling settings for the MP-285A controller.'];
            obj.txStatus = most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [150 300 200 100],'Tag','txStatus','String','','HorizontalAlignment','left');
        end
        
        function redraw(obj)            
            hCOMs = obj.hResourceStore.filterByClass(?dabs.resources.SerialPort);
            
            obj.pmhCOM.String = [{''}, hCOMs];
            obj.pmhCOM.pmValue = obj.hResource.hCOM;
            
            obj.txBaudRate.Visible = obj.isBaudRateSettable;
            obj.pmBaudRate.Visible = obj.isBaudRateSettable;

            obj.pmResolutionMode.pmValue = obj.hResource.resolutionMode;
            obj.etVelocityFine.String = num2str(obj.hResource.fineVelocity);
            obj.etVelocityCoarse.String = num2str(obj.hResource.coarseVelocity);
            
            if obj.isBaudRateSettable
                if isprop(obj.hResource,'availableBaudRates')
                    obj.pmBaudRate.String = arrayfun(@(v)num2str(v),obj.hResource.availableBaudRates,'UniformOutput',false);
                else
                    obj.pmBaudRate.String = {'75' '110' '150' '300' '600' '1200' '1800' '2400' '4800' '7200' '9600' '14400' '19200' '31250' '38400' '56000' '57600' '76800' '115200' '128000' '230400' '256000'};
                end
                obj.pmBaudRate.pmValue = num2str(obj.hResource.baudRate);
            end

            obj.txStatus.String = '';
            try
                if isempty(obj.hResource.errorMsg)
                    status = obj.hResource.getStatus();
                    info = {};
                    info{end+1} = '---- MP285A Status ----';
                    info{end+1} = sprintf('Firmware Version: %s',status.VERSION);
                    info{end+1} = sprintf('Resolution: %s',status.XSPEED_RES);
                    info{end+1} = sprintf('Speed [um/s]: %d',status.XSPEED);
                    info{end+1} = sprintf('Microns per microstep: %f',status.micronsPerMicroStep);
                    info = strjoin(info,'\n');
                    obj.txStatus.String = info;
                end
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
        end

        function showAdvancedSettings(obj)
            title = 'MP285A advanced settings';
            msg = sprintf(['Note: Changing current/scaling settings can damage your\r\nstage system and may result in unexpected behavior.\r\n' ...
                           'Contact Sutter Instruments to obtain the correct settings for your stage.\r\n' ...
                           'Proceed at your own risk.\r\n' ...
                           '=========================================\r\n' ...
                           'To change the current settings select\r\n' ...
                           '[ Program --> Setup --> Utilities --> Info ] then press *\r\n'...
                           '\r\n' ...
                           'To change the scaling settings select\r\n' ...
                           '[ Program --> Setup --> Utilities --> Info ] then press 2']);
            helpdlg(msg,title);
        end
        
        function apply(obj)
            most.idioms.safeSetProp(obj.hResource,'hCOM',obj.pmhCOM.pmValue);
            
            most.idioms.safeSetProp(obj.hResource, 'resolutionMode', obj.pmResolutionMode.pmValue);
            most.idioms.safeSetProp(obj.hResource, 'fineVelocity',   str2double(obj.etVelocityFine.String));
            most.idioms.safeSetProp(obj.hResource, 'coarseVelocity', str2double(obj.etVelocityCoarse.String));
            
            if obj.isBaudRateSettable
                obj.hResource.baudRate = str2double(obj.pmBaudRate.pmValue);
            end
            
            obj.hResource.saveMdf();
            obj.hResource.reinit();
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
