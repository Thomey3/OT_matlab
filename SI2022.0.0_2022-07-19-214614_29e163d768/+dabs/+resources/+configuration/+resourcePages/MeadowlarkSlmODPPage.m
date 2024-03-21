classdef MeadowlarkSlmODPPage < dabs.resources.configuration.ResourcePage
    properties
        etLUT
        etRegionalLUT
        pbRegionalLUT
        cbOverdriveEnable
    end
    
    methods
        function obj = MeadowlarkSlmODPPage(hResource,hParent)
            obj@dabs.resources.configuration.ResourcePage(hResource,hParent);
        end
        
        function makePanel(obj,hParent)
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [10 25 90 17],'Tag','txLUT','String','Look Up Table File','HorizontalAlignment','left');
            obj.etLUT = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [10 45 290 20],'Tag','etLUT','HorizontalAlignment','left');
            most.gui.uicontrol('Parent',hParent,'RelPosition', [310 45 70 20],'String','Open','Tag','pbLUT','Callback',@(varargin)obj.openFile('*.*','lutFile'));
            
            tooltip = sprintf('When Overdrive is disabled, the ''regular'' LUT is used.\nWhen Overdrive is enabled, the regional LUT is used.');
            obj.cbOverdriveEnable = most.gui.uicontrol('Parent',hParent,'Style','checkbox','RelPosition', [10 79 140 16],'Tag','cbOverdriveEnable','String','Enable Overdrive','TooltipString',tooltip,'Callback',@(varargin)obj.toggleRegionalLutVisibility);
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [10 101 140 16],'Tag','txRegionalLUT','String','Regional Look Up Table File','HorizontalAlignment','left');
            obj.etRegionalLUT = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [10 122 290 20],'Tag','etRegionalLUT','HorizontalAlignment','left');
            obj.pbRegionalLUT = most.gui.uicontrol('Parent',hParent,'RelPosition', [310 122 70 20],'String','Open','Tag','pbRegionalLUT','Callback',@(varargin)obj.openFile('*.*','regionalLutFile'));
            
            msg = sprintf(['==================  Note  ==================\n' ...
                           'The Meadowlark 512x512 SLM is End of Life and the driver is no longer maintained by Meadowlark Optics.\n' ...
                           'The driver for the Meadowlark ODP SLM does not support hardware triggering.\n' ...
                           'Please install the driver provided below.']);

            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [50 250 260 100],'Tag','txInfo','String',msg,'HorizontalAlignment','left','BackgroundColor',most.constants.Colors.lightRed);
            most.gui.uicontrol('Parent',hParent,'RelPosition', [130 280 100 25],'String','Show driver installer','Tag','pbDriverInstaller','Callback',@(varargin)obj.hResource.openDriverDirectory());
        end
        
        function redraw(obj)
            obj.etRegionalLUT.String = obj.hResource.regionalLutFile;
            obj.etLUT.String = obj.hResource.lutFile;
            obj.cbOverdriveEnable.Value = obj.hResource.overdriveEnable;
            
            obj.toggleRegionalLutVisibility();
        end
        
        function apply(obj)
            most.idioms.safeSetProp(obj.hResource,'regionalLutFile',obj.etRegionalLUT.String);
            most.idioms.safeSetProp(obj.hResource,'lutFile',obj.etLUT.String);
            most.idioms.safeSetProp(obj.hResource,'overdriveEnable',obj.cbOverdriveEnable.Value);
            
            obj.hResource.saveMdf();
            obj.hResource.reinit();
        end
        
        function remove(obj)
            obj.hResource.deleteAndRemoveMdfHeading();
        end
        
        function toggleRegionalLutVisibility(obj)
            if obj.cbOverdriveEnable.Value
                obj.etRegionalLUT.Enable = 'on';
                obj.pbRegionalLUT.Enable = 'on';
            else
                obj.etRegionalLUT.Enable = 'off';
                obj.pbRegionalLUT.Enable = 'off';
            end
        end
        
        function openFile(obj,filter,propName)
            meadowlarkInstallationFolder = 'C:\Program Files\Meadowlark Optics\Blink OverDrive Plus\LUT Files\';
            
            if exist(meadowlarkInstallationFolder,'dir')
                defaultFolder = meadowlarkInstallationFolder;
            else
                defaultFolder = pwd();
            end
            
            [file,path] = uigetfile(filter,'Select LUT File',defaultFolder);
            
            if isnumeric(file)
                return % user cancelled
            end
            
            file = fullfile(path,file);
            
            switch propName
                case 'lutFile'
                    obj.etLUT.String = file;
                case 'regionalLutFile'
                    obj.etRegionalLUT.String = file;
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
