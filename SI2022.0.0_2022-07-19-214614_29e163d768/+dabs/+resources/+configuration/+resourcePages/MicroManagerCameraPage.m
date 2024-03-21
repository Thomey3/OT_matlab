classdef MicroManagerCameraPage < dabs.resources.configuration.ResourcePage
    properties
        etmmInstallDir;
        etmmConfigFile;
        pbOnSearchPath;
    end
    
    methods
        function obj = MicroManagerCameraPage(hResource,hParent)
            obj@dabs.resources.configuration.ResourcePage(hResource,hParent);
        end
        
        function makePanel(obj,hParent)
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [10 42 220 20],'Tag','txmmInstallDir','String','MicroManager installation directory','HorizontalAlignment','left');
            obj.etmmInstallDir  = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [10 62 310 20],'Tag','etmmInstallDir','HorizontalAlignment','left');
            most.gui.uicontrol('Parent',hParent,'RelPosition', [320 62 50 20],'String','Browse','Tag','pbmmInstallDir','Callback',@(varargin)obj.selectInstallDir);
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [10 102 120 20],'Tag','txmmConfigFile','String','MicroManager config file','HorizontalAlignment','left');
            obj.etmmConfigFile = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [10 122 310 20],'Tag','etmmConfigFile','HorizontalAlignment','left');
            most.gui.uicontrol('Parent',hParent,'RelPosition', [320 122 50 20],'String','Browse','Tag','pbmmConfigFile','Callback',@(varargin)obj.selectConfigFile);
            
            obj.pbOnSearchPath = most.gui.uicontrol('Parent',hParent,'String','Add MicroManager to Windows search path','RelPosition', [50 192 240 40],'Tag','pbOnSearchPath','HorizontalAlignment','left','BackgroundColor',most.constants.Colors.lightRed,'Callback',@(varargin)obj.openEnvironmentalVariablesEditor);
        end
        
        function redraw(obj)            
            obj.etmmInstallDir.String = obj.hResource.mmInstallDir;
            obj.etmmConfigFile.String = obj.hResource.mmConfigFile;
            obj.redrawOnPath();
        end
        
        function isOnPath = redrawOnPath(obj)
            installPath = obj.etmmInstallDir.String;
            
            isOnPath = dabs.micromanager.MicroManager.isOnWindowsPath(installPath);
            
            if isempty(installPath) || isOnPath
                obj.pbOnSearchPath.Visible = 'off';
            else
                obj.pbOnSearchPath.Visible = 'on';
            end
        end
        
        function apply(obj)
            most.idioms.safeSetProp(obj.hResource,'mmInstallDir',obj.etmmInstallDir.String);
            most.idioms.safeSetProp(obj.hResource,'mmConfigFile',obj.etmmConfigFile.String);
            
            obj.hResource.saveMdf();
            obj.hResource.reinit();
        end
        
        function remove(obj)
            obj.hResource.deleteAndRemoveMdfHeading();
        end
        
        function selectInstallDir(obj)
            selpath = uigetdir(obj.etmmInstallDir.String,'Select MicroManager installation directory.');
            if ischar(selpath)
                obj.etmmInstallDir.String = selpath;
            end
            
            obj.redrawOnPath();
        end
        
        function selectConfigFile(obj)
            [fileName,filePath] = uigetfile('*.cfg','Select system configuration file');
            if ischar(fileName)
                obj.etmmConfigFile.String = fullfile(filePath,fileName);
            end
            
            obj.redrawOnPath();
        end
        
        function openEnvironmentalVariablesEditor(obj)
            isOnPath = obj.redrawOnPath();
            
            if ~isOnPath
                system('rundll32 sysdm.cpl,EditEnvironmentVariables');
                helpdlg('A restart of Matlab is required to apply the changed environmental variables');
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
