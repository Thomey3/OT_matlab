classdef PicoQuantRemoteControllerWidget < dabs.resources.widget.Widget
    properties (SetAccess = private)
        hListeners = event.listener.empty;
        hRefreshTimers = timer.empty;
        hGroupWindow = [];
    end
    
    methods
        function obj = PicoQuantRemoteControllerWidget(hResource, hParent)
            obj@dabs.resources.widget.Widget(hResource, hParent);
            
            try
                obj.redraw();
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hListeners);
            stop(obj.hRefreshTimers);
            most.idioms.safeDeleteObj(obj.hRefreshTimers);
            most.idioms.safeDeleteObj(obj.hGroupWindow);
        end
    end
    
    methods
        function makePanel(obj, hParent)
            import dabs.picoquant.gui.constructWidget;
            import dabs.picoquant.gui.constructGroupConfigurationWindow;
            import dabs.picoquant.gui.bind.findBoundControls;
            
            obj.hGroupWindow = constructGroupConfigurationWindow();
            constructWidget(hParent, obj.hGroupWindow);
            obj.bindControl(findBoundControls(hParent));
            obj.bindControl(findBoundControls(obj.hGroupWindow));
        end
        
        function redraw(~)
        end
    end
    
    methods (Access = private)
        function bindControl(obj, hCtrl)
            import dabs.picoquant.gui.bind.BindingType;
            
            for i = 1:length(hCtrl)
                hControl = hCtrl(i);
                Binding = hControl.userdata;
                
                isViewBinding = isa(Binding, 'dabs.picoquant.gui.bind.ViewBinding');
                isBindingEmpty = isempty(Binding);
                assert(~isBindingEmpty && isViewBinding, 'Missing expected binding data!');
                
                if ischar(Binding.reference) && strcmp(Binding.reference, 'isEnabled')
                    hModel = obj.hResource;
                else
                    hModel = obj.hResource.hConfiguration;
                end
                hTies = Binding.bind(hControl, hModel);
                for iTie = 1:length(hTies)
                    hTie = hTies{iTie};
                    if isa(hTie, 'event.listener')
                        obj.hListeners(end+1) = hTie;
                    elseif isa(hTie, 'timer')
                        obj.hRefreshTimers(end+1) = hTie;
                    end
                end
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
