classdef Print3DWidget < dabs.resources.widget.Widget
    properties
        hListeners = event.listener.empty(0,1);
        etNumRepeats
        etZStep_um
        pbLoadImages
        pbShowImages
        pbStartStop
        pmStackMode
        pmStackActuator
        etBeamPowerFractions
    end
    
    methods
        function obj = Print3DWidget(hResource,hParent)
            obj@dabs.resources.widget.Widget(hResource,hParent);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'active','PostSet',@(varargin)obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'stackActuator','PostSet',@(varargin)obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'stackMode','PostSet',@(varargin)obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'beamPowerFractions','PostSet',@(varargin)obj.redraw);

            try
                obj.redraw();
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
        end
        
        function delete(obj)
            obj.hListeners.delete();
        end
    end
    
    methods
        function makePanel(obj,hParent)
            hFlow = most.gui.uiflowcontainer('Parent',hParent,'FlowDirection','TopDown');
                hRowFlow = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','LeftToRight','margin',0.001);
                    most.gui.uicontrol('Parent',hRowFlow,'Style','text','String','Repeats ','HorizontalAlignment','right');
                    obj.etNumRepeats = most.gui.uicontrol('Parent',hRowFlow,'Style','edit','String','','Bindings',{obj.hResource 'numRepeats' 'value' '%.0f'});
                hRowFlow = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','LeftToRight','margin',0.001);
                    most.gui.uicontrol('Parent',hRowFlow,'Style','text','String','Z Step um ','HorizontalAlignment','right');
                    obj.etZStep_um = most.gui.uicontrol('Parent',hRowFlow,'Style','edit','String','','Bindings',{obj.hResource 'zStep_um' 'value' '%.2f'});                    
                hRowFlow = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','LeftToRight','margin',0.001);
                    most.gui.uicontrol('Parent',hRowFlow,'Style','text','String','Mode ','HorizontalAlignment','right');
                    obj.pmStackMode = most.gui.uicontrol('Parent',hRowFlow,'Style','popupmenu','String',{''},'Callback',@obj.changeStackMode);
                hRowFlow = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','LeftToRight','margin',0.001);
                    most.gui.uicontrol('Parent',hRowFlow,'Style','text','String','Actuator ','HorizontalAlignment','right');
                    obj.pmStackActuator = most.gui.uicontrol('Parent',hRowFlow,'Style','popupmenu','String',{''},'Callback',@obj.changeStackActuator);
                hRowFlow = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','LeftToRight','margin',0.001);
                    h = most.gui.uicontrol('Parent',hRowFlow,'Style','text','String','Powers%');
                    h.WidthLimits = [50 50];
                    obj.etBeamPowerFractions = most.gui.uicontrol('Parent',hRowFlow,'Style','edit','String','','Callback',@(varargin)obj.changeBeamPowerFractions);
                hRowFlow = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','LeftToRight','margin',0.001);
                    obj.pbShowImages = most.gui.uicontrol('Parent',hRowFlow,'Style','pushbutton','String','Images','Callback',@(varargin)obj.hResource.showImages);
                    obj.pbStartStop = most.gui.uicontrol('Parent',hRowFlow,'Style','pushbutton','String','START','Callback',@(varargin)obj.startStop,'FontWeight','bold');
                    
            obj.redraw();
        end
        
        function redraw(obj)
            obj.pmStackMode.String = enumMembers(obj.hResource.stackMode);
            obj.pmStackMode.pmValue = char(obj.hResource.stackMode);

            obj.pmStackActuator.String = enumMembers(obj.hResource.stackActuator);
            obj.pmStackActuator.pmValue = char(obj.hResource.stackActuator);

            obj.etBeamPowerFractions.String = mat2str(obj.hResource.beamPowerFractions*100);
            
            if obj.hResource.active
                obj.etNumRepeats.Enable    = 'off';
                obj.etZStep_um.Enable      = 'off';
                obj.pbLoadImages.Enable    = 'off';
                obj.pbShowImages.Enable    = 'off';
                obj.pmStackMode.Enable     = 'off';
                obj.pmStackActuator.Enable = 'off';
                obj.pbStartStop.String     = 'ABORT';
            else
                obj.etNumRepeats.Enable    = 'on';
                obj.etZStep_um.Enable      = 'on';
                obj.pbLoadImages.Enable    = 'on';
                obj.pbShowImages.Enable    = 'on';
                obj.pmStackMode.Enable     = 'on';
                switch obj.hResource.stackMode
                    case scanimage.types.StackMode.slow
                        obj.pmStackActuator.Enable = 'on';
                    case scanimage.types.StackMode.fast
                        obj.pmStackActuator.Enable = 'off';
                end
                obj.pbStartStop.String     = 'START';
            end
        end
        
        function changeNumRepeats(obj)
            try
                obj.hResource.numRepeats = str2double(obj.etNumRepeats.String);
            catch ME
                obj.redraw();
                most.ErrorHandler.logAndReportError(ME);
            end
        end
        
        function changeStackMode(obj,varargin)
            try
                obj.hResource.stackMode = obj.pmStackMode.pmValue;
            catch ME
                obj.redraw();
                most.ErrorHandler.logAndReportError(ME);
            end
        end
        
        function changeStackActuator(obj,varargin)
            try
                obj.hResource.stackActuator = obj.pmStackActuator.pmValue;
            catch ME
                obj.redraw();
                ME.rethrow();
            end
        end

        function changeBeamPowerFractions(obj)
            try
                obj.hResource.beamPowerFractions = str2num(obj.etBeamPowerFractions.String) / 100;
                obj.hResource.expandBeamPowerFractions();
                obj.hResource.saveMdf();
            catch ME
                obj.redraw();
                most.ErrorHandler.logAndReportError(ME);
            end
        end
        
        function startStop(obj)
            if obj.hResource.active
                obj.hResource.abort();
            else
                obj.hResource.start();
            end
        end
    end
end

function members = enumMembers(enum)
    className = class(enum);
    metaClass = meta.class.fromName(className);
    assert(metaClass.Enumeration,'Not an enum: %s',className);
    members = {metaClass.EnumerationMemberList.Name};
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
