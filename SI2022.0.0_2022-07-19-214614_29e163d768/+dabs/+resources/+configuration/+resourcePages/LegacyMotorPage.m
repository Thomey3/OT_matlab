classdef LegacyMotorPage < dabs.resources.configuration.ResourcePage
    properties
        pmControllerType
        pmhCOM
        etCustomArgs
        etInvertDim
        etPositionDeviceUnits
        etVelocitySlow
        etVelocityFast
        etMoveCompleteDelay
        etMoveTimeout
        etMoveTimeoutFactor
    end
    
    methods
        function obj = LegacyMotorPage(hResource,hParent)
            obj@dabs.resources.configuration.ResourcePage(hResource,hParent);
        end
        
        function makePanel(obj,hParent)            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [20 28 120 20],'Tag','txControllerType','String','Controller Type','HorizontalAlignment','right');
            obj.pmControllerType  = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [150 27 120 20],'Tag','pmControllerType');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [20 52 120 20],'Tag','txhComPort','String','Serial Port','HorizontalAlignment','right');
            obj.pmhCOM  = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [150 50 120 20],'Tag','pmhCOM');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [20 75 120 20],'Tag','txCustomArgs','String','Additional Parameters','HorizontalAlignment','right');
            obj.etCustomArgs = most.gui.uicontrol('Parent',hParent,'Style','edit','String','','RelPosition', [150 73 120 20],'Tag','etCustomArgs');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [20 100 120 20],'Tag','txInvertDim','String','Invert Dimensions','HorizontalAlignment','right');
            obj.etInvertDim = most.gui.uicontrol('Parent',hParent,'Style','edit','String','','RelPosition', [150 97 120 20],'Tag','etInvertDim');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [20 125 120 20],'Tag','txPositionDeviceUnits','String','Position Device Units','HorizontalAlignment','right');
            obj.etPositionDeviceUnits = most.gui.uicontrol('Parent',hParent,'Style','edit','String','','RelPosition', [150 122 120 20],'Tag','etPositionDeviceUnits');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [20 149 120 20],'Tag','txVelocitySlow','String','Velocity Slow','HorizontalAlignment','right');
            obj.etVelocitySlow = most.gui.uicontrol('Parent',hParent,'Style','edit','String','','RelPosition', [150 147 120 20],'Tag','etVelocitySlow');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [20 174 120 20],'Tag','txVelocityFast','String','Velocity Fast','HorizontalAlignment','right');
            obj.etVelocityFast = most.gui.uicontrol('Parent',hParent,'Style','edit','String','','RelPosition', [150 171 120 20],'Tag','etVelocityFast');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [20 197 120 20],'Tag','txMoveCompleteDelay','String','Move Complete Delay','HorizontalAlignment','right');
            obj.etMoveCompleteDelay = most.gui.uicontrol('Parent',hParent,'Style','edit','String','','RelPosition', [150 194 120 20],'Tag','etMoveCompleteDelay');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [20 221 120 20],'Tag','txMoveTimeout','String','Move Timeout','HorizontalAlignment','right');
            obj.etMoveTimeout = most.gui.uicontrol('Parent',hParent,'Style','edit','String','','RelPosition', [150 218 120 20],'Tag','etMoveTimeout');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [20 243 120 20],'Tag','txMoveTimeoutFactor','String','Move Timeout Factor','HorizontalAlignment','right');
            obj.etMoveTimeoutFactor = most.gui.uicontrol('Parent',hParent,'Style','edit','String','','RelPosition', [150 242 120 20],'Tag','etMoveTimeoutFactor');
        end
        
        function redraw(obj)
            obj.pmControllerType.String = [{''}, dabs.legacy.motor.MotorRegistry.getStageNames];
            if isempty(obj.hResource.mdfData.controllerType)
                controllerType = '';
            elseif ~ismember(obj.hResource.mdfData.controllerType,dabs.legacy.motor.MotorRegistry.getStageNames)
                controllerType = '';
            else
                controllerType = obj.hResource.mdfData.controllerType;
            end
            obj.pmControllerType.pmValue = controllerType;
            
            hCOMs = obj.hResourceStore.filterByClass(?dabs.resources.SerialPort);
            obj.pmhCOM.String = [{''}, hCOMs];
            if isempty(obj.hResource.mdfData.comPort)
                comPort = '';
            elseif ismember(obj.hResource.mdfData.comPort,cellfun(@(hCOM)hCOM.number,hCOMs))
                comPort = sprintf('COM%d',obj.hResource.mdfData.comPort);
            else
                comPort = '';
            end
            obj.pmhCOM.pmValue = comPort;
            
            if isempty(obj.hResource.mdfData.customArgs)
                params = {};
            else
                params = cellfun(@(p)renderParam(p),obj.hResource.mdfData.customArgs,'UniformOutput',false);
            end
            obj.etCustomArgs.String = ['{' strjoin(params,', ') '}'];
            
            obj.etInvertDim.String = obj.hResource.mdfData.invertDim;
            obj.etPositionDeviceUnits.String = mat2str(obj.hResource.mdfData.positionDeviceUnits);
            obj.etVelocitySlow.String = num2str(obj.hResource.mdfData.velocitySlow);
            obj.etVelocityFast.String = num2str(obj.hResource.mdfData.velocityFast);
            obj.etMoveCompleteDelay.String = num2str(obj.hResource.mdfData.moveCompleteDelay);
            obj.etMoveTimeout.String = num2str(obj.hResource.mdfData.moveTimeout);
            obj.etMoveTimeoutFactor.String = num2str(obj.hResource.mdfData.moveTimeoutFactor);
            
            function p = renderParam(p)
                if isnumeric(p)
                    p = num2str(p);
                elseif ischar(p)
                    p = sprintf('''%s''',p);
                else
                    p = '''''';
                end
            end
        end
        
        function apply(obj)
            obj.hResource.mdfData.controllerType = obj.pmControllerType.pmValue;
            
            if isempty(obj.pmhCOM.pmValue)
                obj.hResource.mdfData.comPort = '';
            else
                obj.hResource.mdfData.comPort = str2double(regexpi(obj.pmhCOM.pmValue,'[0-9]+$','match','once'));
            end
            
            if isempty(obj.etCustomArgs.String)
                obj.hResource.mdfData.customArgs = '';
            else
                obj.hResource.mdfData.customArgs = eval(obj.etCustomArgs.String);
            end
            obj.hResource.mdfData.invertDim = obj.etInvertDim.String;
            
            if isempty(obj.etPositionDeviceUnits.String)
                obj.hResource.mdfData.positionDeviceUnits = [];
            else
                obj.hResource.mdfData.positionDeviceUnits = eval(obj.etPositionDeviceUnits.String);
            end
            
            obj.hResource.mdfData.velocitySlow = safeStr2double(obj.etVelocitySlow.String);
            obj.hResource.mdfData.velocityFast = safeStr2double(obj.etVelocityFast.String);
            obj.hResource.mdfData.moveCompleteDelay = safeStr2double(obj.etMoveCompleteDelay.String);
            obj.hResource.mdfData.moveTimeout = obj.etMoveTimeout.String;
            obj.hResource.mdfData.moveTimeoutFactor = obj.etMoveTimeoutFactor.String;
            
            obj.hResource.saveMdf();
            obj.hResource.reinit();
        end
        
        function remove(obj)
            obj.hResource.deleteAndRemoveMdfHeading();
        end
    end
end

%%% local function            
function v = safeStr2double(v)
    v = str2double(v);
    if isnan(v)
        v = [];
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
