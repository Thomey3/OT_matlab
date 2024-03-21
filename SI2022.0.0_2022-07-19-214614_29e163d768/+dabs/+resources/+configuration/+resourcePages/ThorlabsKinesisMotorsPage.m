classdef ThorlabsKinesisMotorsPage < dabs.resources.configuration.ResourcePage
    properties
        etkinesisInstallDir
        pmSerial
        txMotorInfoPanel
        txMotorInfoFlow
        etHomingTimeout_s
        pmStartupSettingsMode
        pmUnits
        
        startupSettingMap
    end
    
    methods
        function obj = ThorlabsKinesisMotorsPage(hResource,hParent)
            obj@dabs.resources.configuration.ResourcePage(hResource,hParent);
        end
        
        function makePanel(obj,hParent)
            hTabGroup = uitabgroup('Parent',hParent);
            hTab = uitab('Parent',hTabGroup,'Title','Basic');
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [30 28 220 20],'Tag','txKinesisInstallDir','String','Thorlabs Kinesis installation directory','HorizontalAlignment','left');
                obj.etkinesisInstallDir = most.gui.uicontrol('Parent',hTab,'Style','edit','RelPosition', [30 43 280 20],'Tag','etkinesisInstallDir','HorizontalAlignment','left','Enable','inactive');
                most.gui.uicontrol('Parent',hTab,'RelPosition', [310 43 50 20],'String','Browse','Tag','pbmmInstallDir','Callback',@(varargin)obj.selectInstallDir);

                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [30 78 70 20],'Tag','txControllerName','String','Serial Number','HorizontalAlignment','left');
                obj.pmSerial = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [30 93 280 20],'Tag','pmSerial');

                obj.txMotorInfoPanel = most.gui.uicontrol('Parent',hTab,'Style','uipanel','RelPosition', [0 242 380 130],'Tag','txMotorInfoPanel','BorderType','none');
                obj.txMotorInfoFlow = most.gui.uiflowcontainer('Parent',obj.txMotorInfoPanel.hCtl,'FlowDirection','LeftToRight');
            
            hTab = uitab('Parent',hTabGroup,'Title','Advanced');            
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [40 42 125 18],'Tag','txHomingTimeout_s','String','Homing move timeout [s]','HorizontalAlignment','right');
                obj.etHomingTimeout_s = most.gui.uicontrol('Parent',hTab,'Style','edit','RelPosition', [170 42 50 20],'Tag','etHomingTimeout_s');
                
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [110 72 70 16],'Tag','txUnits','String','Motor units','HorizontalAlignment','left');
                obj.pmUnits = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [170 72 50 20],'Tag','pmUnits');

                toolTipStr = sprintf('Use Device Settings: An enum constant representing the use device settings option.\nUse File Settings: An enum constant representing the use file settings option.\nUse Configured Settings: An enum constant representing the use configured settings option.\nDefault Settings: Load configurtion without settings option.\n\n See docs for more info.');
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [86 100 125 16],'Tag','txStartupSettingsMode','String','Startup Settings','HorizontalAlignment','left');
                obj.pmStartupSettingsMode = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [170 100 150 20],'Tag','pmStartupSettingsMode','tooltip',toolTipStr);
                
                obj.startupSettingMap = {'Use Device Settings'    , 'UseDeviceSettings'    ;
                                         'Use File Settings'      , 'UseFileSettings'      ;
                                         'Use Configured Settings', 'UseConfiguredSettings';
                                         'Use Default Settings'   , ''                      };
                
                obj.pmStartupSettingsMode.String = obj.startupSettingMap(:,1);
        end
        
        function redraw(obj)
            obj.etkinesisInstallDir.String = obj.hResource.kinesisInstallDir;
            if obj.hResource.kinesisInstallDirValid
                obj.etkinesisInstallDir.hCtl.BackgroundColor = most.constants.Colors.white;
            else
                obj.etkinesisInstallDir.hCtl.BackgroundColor = most.constants.Colors.lightRed;
            end
            
            [serials,dotNetClasses] = obj.hResource.enumerate();
            dotNetClasses = regexp(dotNetClasses,'[^\.]*$','match','once');
            
            obj.pmSerial.String = [{''} serials(:)'];
            obj.pmSerial.pmValue = obj.hResource.serial;
            if isprop(obj.pmSerial,'pmComment')
                obj.pmSerial.pmComment = [{''} dotNetClasses(:)'];
            end
            
            drawChannelInfo();
            
            obj.etHomingTimeout_s.String = num2str(obj.hResource.homingTimeout_s);
            
            obj.pmUnits.String = {'um','deg'};
            obj.pmUnits.pmValue = obj.hResource.units;
            
            obj.pmStartupSettingsMode.pmValue = obj.startupModeValueToPrettyName(obj.hResource.startupSettingsMode);

            %%% Nested function
            function drawChannelInfo()
                hFlowContent = obj.txMotorInfoFlow.Children;
                delete(hFlowContent);
                
                uicontrol('Parent',obj.txMotorInfoFlow,'Style','text'); % flexible spacer
                for idx = 1:numel(obj.hResource.channelInfo)
                    channelInfo = obj.hResource.channelInfo(idx);
                    
                    string = sprintf('----- Axis %d -----\nModel: %s\nFirmware: %s\nHardware ver: %d\n%s\nVel: %.2f%s' ...
                        ,idx ...
                        ,channelInfo.model ...
                        ,channelInfo.firmwareVersion ...
                        ,channelInfo.hardwareVersion ...
                        ,channelInfo.actuator ...
                        ,obj.hResource.velocity(idx), obj.hResource.velocityUnits{idx});
                    
                    h = uicontrol('Parent',obj.txMotorInfoFlow,'Style','text','String',string,'HorizontalAlignment','left');
                    set(h,'WidthLimits',[120 120]);
                end
                uicontrol('Parent',obj.txMotorInfoFlow,'Style','text'); % flexible spacer
            end
        end
        
        function apply(obj)
            most.idioms.safeSetProp(obj.hResource,'kinesisInstallDir',obj.etkinesisInstallDir.String);
            most.idioms.safeSetProp(obj.hResource,'serial',obj.pmSerial.pmValue);
            most.idioms.safeSetProp(obj.hResource,'homingTimeout_s',str2double(obj.etHomingTimeout_s.String));
            most.idioms.safeSetProp(obj.hResource,'units',obj.pmUnits.pmValue);

            most.idioms.safeSetProp(obj.hResource,'startupSettingsMode',obj.startupModePrettyNameToValue(obj.pmStartupSettingsMode.pmValue));
            
            obj.hResource.saveMdf();
            
            % Don't Reinit unless a setting caused a deinit - otherwise the
            % dll might throw and exception error (specifically while
            % active, focus/grab/etc)
            if ~isempty(obj.hResource.errorMsg)
                obj.hResource.reinit();
            end
        end
        
        function remove(obj)
            obj.hResource.deleteAndRemoveMdfHeading();
        end
        
        function selectInstallDir(obj)
            selpath = uigetdir(obj.etkinesisInstallDir.String,'Select Thorlabs Kinesis installation directory.');
            if ischar(selpath)
                obj.hResource.kinesisInstallDir = selpath;
                obj.redraw();
            end
        end

        function val = startupModeValueToPrettyName(obj,val)
            mask = strcmp(val,obj.startupSettingMap(:,2));
            assert(sum(mask) == 1,'Could not translate value ''%s'' to pretty name',val);
            val = obj.startupSettingMap(mask,1);
            val = val{1};
        end

        function val = startupModePrettyNameToValue(obj,val)
            mask = strcmp(val,obj.startupSettingMap(:,1));
            assert(sum(mask) == 1,'Could not translate value ''%s'' to value',val);
            val = obj.startupSettingMap(mask,2);
            val = val{1};
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
