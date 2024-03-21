classdef FastZAnalog < dabs.resources.devices.FastZ & dabs.resources.devices.LinearScanner & dabs.resources.widget.HasWidget
    properties (SetAccess=protected)
        WidgetClass = 'dabs.resources.widget.widgets.FastZWidget';
    end
    
    properties
        hFrameClockIn = dabs.resources.Resource.empty();
        moveTimeout_s = 1;
    end
    
    methods
        function obj = FastZAnalog(name)
            obj@dabs.resources.devices.FastZ(name);
            obj@dabs.resources.devices.LinearScanner(name);
            obj.units = 'um';
            
            obj.numSmoothTransitionPoints = 1;
        end
    end
    
    methods
        function deinit(obj)
            obj.deinit@dabs.resources.devices.LinearScanner();
        end
        
        function reinit(obj)
            obj.reinit@dabs.resources.devices.LinearScanner();
            
            try
                obj.assertNoError();
                
                if most.idioms.isValidObj(obj.hFrameClockIn)
                    assert(obj.hAOControl.hDAQ==obj.hFrameClockIn.hDAQ ...
                        ,'The frame clock input needs to be on the same DAQ board as the analog control output.')
                end
            catch ME
                obj.deinit();
                obj.errorMsg = sprintf('%s: initialization error: %s',obj.name,ME.message);
                most.ErrorHandler.logError(ME,obj.errorMsg);
            end
        end
    end
    
    methods
        function move(obj,position)
            obj.pointPosition(position);
        end
        
        function moveBlocking(obj,position,timeout)
            if nargin < 3 || isempty(timeout)
                timeout = obj.moveTimeout_s;
            end
            
            obj.move(position);
            obj.waitMoveComplete(timeout);
        end
    end
    
    methods
        function set.hFrameClockIn(obj,val)
            val = obj.hResourceStore.filterByName(val);
            
            if ~isequal(obj.hFrameClockIn,val)
                if most.idioms.isValidObj(val)
                    validateattributes(val,{'dabs.resources.ios.PFI'},{'scalar'});
                end
                
                obj.deinit();
                
                obj.hFrameClockIn.unregisterUser(obj);
                obj.hFrameClockIn = val;
                obj.hFrameClockIn.registerUser(obj,'Frame Clock');                
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
