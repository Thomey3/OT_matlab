classdef BeamModulatorSlow < dabs.resources.devices.BeamModulator
    properties(Abstract, SetObservable, SetAccess = private)
        isModulating;
    end
    
    %% Lifecycle Methods
    methods
        function obj = BeamModulatorSlow(name)
            obj@dabs.resources.devices.BeamModulator(name);
        end
    end
    
    %% Abstract Class Methods
    methods(Abstract)

        % setPowerFractionAsync(powerFraction,callback,timeout)
        % initiates a change in beam power but returns immediately, not waiting for the modulation 
        % to complete. throws if a modulation is already in progress
        %
        % parameters
        %   powerFraction: a scalar number between 0 and 1 representing
        %   the amount of power as a fraction of the maximum power.
        
        %   callback:  [function handle] function to be called when the
        %              modulation completes
        setPowerFractionAsync(obj);

        
        % modulateWaitForFinish(timeout_s)
        % waits until isMoving == false
        %
        % parameters
        %   timeout_s: [numeric,scalar] (optional) if not specified, the default timeout should be used
        %              after the timeout expires, stop() is called
        modulateWaitForFinish(obj, timeout_s);
        
        % stops the actuator movement
        stop(obj);
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
