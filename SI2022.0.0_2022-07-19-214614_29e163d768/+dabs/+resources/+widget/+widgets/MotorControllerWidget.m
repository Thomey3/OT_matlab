classdef MotorControllerWidget < dabs.resources.widget.Widget
    properties (SetAccess = protected)
        hListeners = event.listener.empty();
        hAx
        hText
        hReinitButton
        hHomeButton
        hPbToggleJoystick
        hStopButton
    end
    
    methods
        function obj = MotorControllerWidget(hResource,hParent)
            obj@dabs.resources.widget.Widget(hResource,hParent);

            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'lastKnownPosition','PostSet',@(varargin)obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'numAxes',          'PostSet',@(varargin)obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'errorMsg',         'PostSet',@(varargin)obj.redrawButtons);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'isHomed',          'PostSet',@(varargin)obj.redrawButtons);
            
            if isprop(obj.hResource, 'enableJoystick')
                obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'enableJoystick','PostSet',@(varargin)obj.redrawToggleJoystickButton);
            end
            
            try
                obj.redraw();
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
        end
        
        function delete(obj)
            obj.hListeners.delete();
        end
       
       function makePanel(obj,hParent)
           hFlow = most.gui.uiflowcontainer('Parent',hParent,'FlowDirection','TopDown','margin',1);
               hAxFlow = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','LeftToRight','margin',2);
               hJoystickButtonFlow = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','LeftToRight','margin',1,'HeightLimits',[22 22],'Visible','off');
               hButtonFlow = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','LeftToRight','margin',1,'HeightLimits',[22 22]);
            
           obj.hAx = most.idioms.axes('Parent',hAxFlow,'XLim',[0 1],'YLim',[0 1],'XTick',[],'YTick',[],'XLimSpec','tight','YLimSpec','tight','ButtonDownFcn',@(varargin)obj.queryPosition,'Color','none');
           obj.hAx.XColor = 'none';
           obj.hAx.YColor = 'none';
           obj.hText = text('Parent',obj.hAx,'Position',[0 1],'HorizontalAlignment','left','VerticalAlignment','top','Hittest','off','PickableParts','none');
           
           if isprop(obj.hResource, 'enableJoystick')
               hJoystickButtonFlow.Visible = 'on';
               obj.hPbToggleJoystick = uicontrol('Parent',hJoystickButtonFlow,'String','Joystick disabled','Callback',@(varargin)obj.toggleJoystick);
               obj.redrawToggleJoystickButton();
           end
           
           obj.hStopButton   = uicontrol('Parent',hButtonFlow,'String','Stop'  ,'Callback',@(varargin)obj.hResource.stop());
           obj.hReinitButton = uicontrol('Parent',hButtonFlow,'String','Reinit','Callback',@obj.reinit);
           obj.hHomeButton   = uicontrol('Parent',hButtonFlow,'String','Home'  ,'Callback',@(varargin)obj.startHoming());
           obj.redrawButtons();
           
           obj.hAx.Position = [0 0 1 1];
       end
        
       function redraw(obj)
           pos = obj.hResource.lastKnownPosition;
           if ~isrow(pos)
               pos = pos';
           end
           
           axes = 1:numel(pos);
           
           obj.hText.String = sprintf('Ax%d: %.2f\n',[axes;pos]);          
       end
       
       function redrawButtons(obj)
           if isempty(obj.hResource.errorMsg)
               obj.hReinitButton.BackgroundColor = most.constants.Colors.lightGray;
               obj.hReinitButton.String = 'Deinit';
           else
               obj.hReinitButton.BackgroundColor = most.constants.Colors.lightRed;
               obj.hReinitButton.String = 'Reinit';
           end
           
           if obj.hResource.isHomed
               obj.hHomeButton.BackgroundColor = most.constants.Colors.lightGray;
           else
               obj.hHomeButton.BackgroundColor = most.constants.Colors.yellow;
           end
       end
       
       function redrawToggleJoystickButton(obj)
           if obj.hResource.enableJoystick %Indicate whether Joystick is enabled
               obj.hPbToggleJoystick.BackgroundColor = most.constants.Colors.green;
               obj.hPbToggleJoystick.String = 'Joystick enabled';
           else
               obj.hPbToggleJoystick.BackgroundColor = most.constants.Colors.lightGray;
               obj.hPbToggleJoystick.String = 'Joystick disabled';
           end
       end
       
       function queryPosition(obj)
           obj.hResource.queryPosition();
       end
       
       function startHoming(obj)
           msg = sprintf('The stage will start a homing move.\nEnsure there are no obstructions in the path');
           
           h = most.gui.nonBlockingDialog('Homing move',msg ...
               ,{{'OK',@(varargin)executeWithWatchMousePointer(@homingFunc)}, {'Cancel',@false}} ...
               ,'Position',[0 0 400 150],'Name','Homing');
           
           most.gui.centerOnScreen(h.hFig);
           
           %%% Nested function
           function homingFunc()
               try
                   obj.hHomeButton.Enable = 'inactive';
                   obj.hHomeButton.BackgroundColor = most.constants.Colors.lightBlue;
                   drawnow();
                   obj.hResource.startHoming();
                   obj.hHomeButton.Enable = 'on';
               catch ME
                   obj.hHomeButton.Enable = 'on';
                   obj.redrawButtons();
                   ME.rethrow();
               end
               
               obj.redrawButtons();
           end
       end
       
       function reinit(obj,src,evt)
           executeWithWatchMousePointer(@reinitFunc);
           
           %%% Nested function
           function reinitFunc()
               if isempty(obj.hResource.errorMsg)
                   obj.hResource.deinit();
               else
                   obj.hResource.reinit();
                   if ~isempty(obj.hResource.errorMsg)
                       h = errordlg(obj.hResource.errorMsg);
                       most.gui.centerOnScreen(h);
                   end
               end
           end
       end
       
       function toggleJoystick(obj)
           obj.hResource.enableJoystick = ~obj.hResource.enableJoystick;
       end
   end
end

function executeWithWatchMousePointer(func)
    hFig = gcf();

    oldPointer = hFig.Pointer;
    hFig.Pointer = 'watch';
    drawnow();
    
    try
        func();
    catch ME
        most.ErrorHandler.logAndReportError(ME);
    end

    if most.idioms.isValidObj(hFig)
        hFig.Pointer = oldPointer;
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
