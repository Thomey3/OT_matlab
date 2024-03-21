classdef ZaberMultiDevicePage < dabs.resources.configuration.ResourcePage
    properties
        pmhCOM
        pmBaudRate
        pmCommunicationProtocol
        txInfo
        pbDownloadToolbox
        etDeviceLibraryPath
        etHomingTimeout_s
    end
    
    methods
        function obj = ZaberMultiDevicePage(hResource,hParent)
            obj@dabs.resources.configuration.ResourcePage(hResource,hParent);
        end
        
        function makePanel(obj,hParent)
            hTabGroup = uitabgroup('Parent',hParent);
            
            hTab = uitab('Parent',hTabGroup,'Title','Basic');
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [6 22 115 16],'Tag','txhComPort','String','Serial Port','HorizontalAlignment','right');
                obj.pmhCOM  = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [130 22 120 20],'Tag','pmhCOM');

                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [5 52 115 16],'Tag','txBaudRate','String','Baud Rate','HorizontalAlignment','right');
                obj.pmBaudRate = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [130 52 120 20],'Tag','pmBaudRate');

                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [5 82 115 16],'Tag','txCommunicationProtocol','String','Protocol','HorizontalAlignment','right');
                obj.pmCommunicationProtocol = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [130 82 120 20],'Tag','pmCommunicationProtocol');

                obj.txInfo = most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [10 312 360 220],'Tag','txInfo','String','','HorizontalAlignment','left');
                obj.pbDownloadToolbox = most.gui.uicontrol('Parent',hTab,'RelPosition', [100 182 150 40],'Tag','pbDownloadToolbox','String','Download Toolbox','Callback',@(varargin)obj.downloadToolbox);

            hTab = uitab('Parent',hTabGroup,'Title','Advanced');
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [10 70 220 20],'Tag','txDeviceLibraryPath','String','Device library file','HorizontalAlignment','left');
                obj.etDeviceLibraryPath = most.gui.uicontrol('Parent',hTab,'Style','edit','RelPosition', [10 87 260 20],'Tag','etDeviceLibraryPath','HorizontalAlignment','left','Enable','inactive');
                most.gui.uicontrol('Parent',hTab,'RelPosition', [270 87 50 20],'String','Browse','Tag','pbSelectDeviceLibraryPath','Callback',@(varargin)obj.selectDeviceLibraryPath);
                most.gui.uicontrol('Parent',hTab,'RelPosition', [320 87 50 20],'String','Clear','Tag','pbClearDeviceLibraryPath','Callback',@(varargin)obj.clearDeviceLibraryPath);
                hDescription = most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [10 152 350 60],'Tag','txDeviceLibraryDescription','HorizontalAlignment','left');
                hDescription.String = sprintf('The Zaber Motion Library automatically downloads device definitions.\nFor offline use, a device library can be downloaded and specified here.');
                
                most.gui.uicontrol('Parent',hTab,'RelPosition', [100 182 150 40],'Tag','pbDownloadDeviceLibrary','String','Download device library','Callback',@(varargin)obj.downloadDeviceLibrary);
                
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [10 32 135 18],'Tag','txHomingTimeout_s','String','Homing move timeout [s]','HorizontalAlignment','right');
                obj.etHomingTimeout_s = most.gui.uicontrol('Parent',hTab,'Style','edit','RelPosition', [150 32 60 20],'Tag','etHomingTimeout_s');
        end
        
        function redraw(obj)            
            hCOMs = obj.hResourceStore.filterByClass(?dabs.resources.SerialPort);
            obj.pmhCOM.String = [{''}, hCOMs];
            obj.pmhCOM.pmValue = obj.hResource.hCOM;
            
            obj.pmBaudRate.String = arrayfun(@(b)num2str(b),obj.hResource.AVAILABLE_BAUD_RATES,'UniformOutput',false);
            obj.pmBaudRate.pmValue = num2str(obj.hResource.baudRate);
            obj.pmBaudRate.hCtl.TooltipString = sprintf('Default for ASCII protocol: 115200\nDefault for binary protocol: 9600');
            
            obj.pmCommunicationProtocol.String = {'ASCII' 'Binary'};
            obj.pmCommunicationProtocol.pmValue = obj.hResource.communicationProtocol;
            
            toolboxValid = obj.hResource.checkToolbox();
            
            if toolboxValid
                toolboxInfo = obj.hResource.getToolboxInfo();
                toolboxInfo = sprintf('Installed Toolbox: %s %s',toolboxInfo.Name,toolboxInfo.Version);
                
                axInfo = regexprep(obj.hResource.axInfos,'\s*[-=]> Connection.*$','','lineanchors','dotexceptnewline');
                
                info = strjoin([{toolboxInfo} {''} {'Axis Info:'} axInfo],'\n');
                obj.txInfo.String = info;
                
                obj.txInfo.hCtl.BackgroundColor = most.constants.Colors.lightGray;
                obj.pbDownloadToolbox.Visible = false;
            else
                msg = sprintf('This driver requires the Zaber Motion Library Toolbox (v %s or later).' ...
                    ,obj.hResource.MIN_TOOLBOX_VERSION);
                
                if verLessThan('matlab','9.3')
                    msg = sprintf('%s\n(Only available for Matlab 2017b or later)',msg);
                    obj.pbDownloadToolbox.hCtl.Callback = @(varargin)helpdlg('Only available for Matlab 2017b or later');
                end
                
                obj.txInfo.String = msg;
                obj.txInfo.hCtl.BackgroundColor = most.constants.Colors.lightRed;
                obj.pbDownloadToolbox.Visible = true;
            end
            
            obj.etDeviceLibraryPath.String = obj.hResource.deviceLibraryPath;
            deviceLibraryPathValid = isempty(obj.hResource.deviceLibraryPath) ...
                                  || exist(obj.hResource.deviceLibraryPath,'file')>0;
                              
            if deviceLibraryPathValid
                obj.etDeviceLibraryPath.hCtl.BackgroundColor = most.constants.Colors.lightGray;
            else
                obj.etDeviceLibraryPath.hCtl.BackgroundColor = most.constants.Colors.lightRed;
            end
            
            obj.etHomingTimeout_s.String = num2str(obj.hResource.homingTimeout_s);
        end
        
        function apply(obj)
            most.idioms.safeSetProp(obj.hResource,'hCOM',obj.pmhCOM.pmValue);
            most.idioms.safeSetProp(obj.hResource,'baudRate',str2double(obj.pmBaudRate.pmValue));
            most.idioms.safeSetProp(obj.hResource,'communicationProtocol',obj.pmCommunicationProtocol.pmValue);
            most.idioms.safeSetProp(obj.hResource,'deviceLibraryPath',obj.etDeviceLibraryPath.String);
            most.idioms.safeSetProp(obj.hResource,'homingTimeout_s',str2double(obj.etHomingTimeout_s.String));
            
            obj.hResource.saveMdf();
            obj.hResource.reinit();
        end
        
        function remove(obj)
            obj.hResource.deleteAndRemoveMdfHeading();
        end
        
        function downloadToolbox(obj)
            web('www.zaber.com','-browser');
            web(obj.hResource.TOOLBOX_URL,'-browser');
        end
        
        function selectDeviceLibraryPath(obj)
            [file,folder] = uigetfile({'*.sqlite','Zaber Device Library (*.sqlite)'},obj.etDeviceLibraryPath.String,'Select Zaber Device Library File');
            if ischar(file)
                file = fullfile(folder,file);
                obj.hResource.deviceLibraryPath = file;
                obj.redraw();
            end
        end
        
        function clearDeviceLibraryPath(obj)
            obj.hResource.deviceLibraryPath = '';
            obj.redraw();
        end
        
        function downloadDeviceLibrary(obj)
            web(obj.hResource.DEVICE_LIBRARY_URL,'-browser');
            
            pause(1);
            msg = sprintf('Note: the Zaber Device Library is downloaded as an ''LZMA'' archive.\nUse 7-ZIP to extract the archive.');
            answer = questdlg(msg,'Starting download...','Done','Download 7-zip','Download 7-zip');
            
            if strcmpi(answer,'Download 7-zip')
                web('https://7-zip.org','-browser');
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
