classdef MeadowlarkSLMPage < dabs.resources.configuration.ResourcePage
    properties
        etSDK
        etLUT
    end
    
    methods
        function obj = MeadowlarkSLMPage(hResource,hParent)
            obj@dabs.resources.configuration.ResourcePage(hResource,hParent);
        end
        
        function makePanel(obj,hParent)
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [10 25 90 17],'Tag','txSDK','String','Meadowlark SDK Folder','HorizontalAlignment','left');
            obj.etSDK = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [10 45 290 20],'Tag','etSDK','HorizontalAlignment','left');
            most.gui.uicontrol('Parent',hParent,'RelPosition', [310 45 70 20],'String','Browse','Tag','pbSDK','Callback',@(varargin)obj.openSDKPath());

            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [10 75 90 17],'Tag','txLUT','String','Look Up Table File','HorizontalAlignment','left');
            obj.etLUT = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [10 95 290 20],'Tag','etLUT','HorizontalAlignment','left');
            most.gui.uicontrol('Parent',hParent,'RelPosition', [310 95 70 20],'String','Open','Tag','pbLUT','Callback',@(varargin)obj.openFile());
        end
        
        function redraw(obj)
            obj.etSDK.String = obj.hResource.SDKPath;
            obj.etLUT.String = obj.hResource.lutFile;
        end
        
        function apply(obj)
            most.idioms.safeSetProp(obj.hResource,'SDKPath',obj.etSDK.String);
            most.idioms.safeSetProp(obj.hResource,'lutFile',obj.etLUT.String);
            
            obj.hResource.saveMdf();
            obj.hResource.reinit();
        end
        
        function remove(obj)
            obj.hResource.deleteAndRemoveMdfHeading();
        end
        
        function openFile(obj)
            meadowlarkInstallationFolder = 'C:\Program Files\Meadowlark Optics\Blink OverDrive Plus\LUT Files\';
            
            if exist(meadowlarkInstallationFolder,'dir')
                defaultFolder = meadowlarkInstallationFolder;
            else
                defaultFolder = pwd();
            end
            
            [file,path] = uigetfile('*.*','Select LUT File',defaultFolder);
            
            if isnumeric(file)
                return % user cancelled
            end
            
            file = fullfile(path,file);
            obj.etLUT.String = file;
        end

        function openSDKPath(obj)
            if exist(obj.hResource.SDKPath,'dir')
                defaultFolder = obj.hResource.SDKPath;
            else
                defaultFolder = pwd();
            end

            selpath = uigetdir(defaultFolder,'Select the Meadowlark SDK folder');
            if isnumeric(selpath)
                return % User aborted
            end

            libpath = fullfile(selpath,[dabs.meadowlark.private1920.SDK.libname '.dll']);
            
            if exist(libpath,'file')
                obj.etSDK.String = selpath;
            else
                msg = sprintf('''%s'' not found on disk. Choose a different folder.',libpath);
                errordlg(msg);
                error(msg);
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
