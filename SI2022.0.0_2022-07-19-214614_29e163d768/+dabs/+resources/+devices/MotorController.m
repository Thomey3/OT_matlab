classdef MotorController < dabs.resources.Device & dabs.resources.widget.HasWidget
    % Interface class to communicate with a MotorController
    %
    % preferred units are micrometer for linear axes
    % or degree for rotation axes
    
    properties (SetAccess=protected)
        WidgetClass = 'dabs.resources.widget.widgets.MotorControllerWidget';
    end
    
    properties
        defaultTimeout_s = 10 % [numeric] scalar that defines the default timeout for a blocking move in seconds
        initSuccessful;
    end
    
    properties (Abstract, SetObservable, SetAccess=protected, AbortSet)
        lastKnownPosition;  % [numeric] [1 x numAxes] sized vector with the last known position of all motors
        isMoving;           % [logical] Scalar that is TRUE only if a move initiated by obj.move OR obj.moveAsync has not finished
        isHomed;            % [logical] Scalar that is TRUE if the motor's absolute position is known relative to its home position
    end
    
    properties (Abstract, SetAccess=protected, SetObservable)
        numAxes;            % [numeric] Scalar integer describing the number of axes of the MotorController
        autoPositionUpdate  % [logical] indicates if lastKnownPosition automatically updates when position of motor changes
    end
    
    methods
        function obj = MotorController(name)
            obj@dabs.resources.Device(name);
        end
    end
    
    methods (Abstract)
        % constructor
        % construct object and attempt to init motor. constructor should return successfully even if
        % communication with motor failed. gracefully clean up in the case of failure and set 
        % errorMsg nonempty so that connection can be reattempted by calling reinit.
        
        % reinit
        % reinitializes the communication interface to the motor
        % controller. Should never throw!!!!
        % Instead set errorMsg if reinit fails
        % reinit(obj);
        
        % queryMoving
        % queries the controller. if any motor axis is moving, returns true.
        % if all axes are idle, returns false. also updates isMoving
        %
        % returns
        %   tf: [logical scalar] TRUE if any axis is moving, FALSE if all
        %                        axes are idle
        tf = queryMoving(obj);
        
        % queryPosition
        % queries all axis positions and returns a [1 x numAxes] containing
        % the axes positions. also updates lastKnownPosition
        %
        % returns
        %   position: [1 x numAxes] sized numeric vector containing the
        %             current positions of all axes
        position = queryPosition(obj);
        
        % move(position,timeout)
        % moves the axes to the specified position. blocks until the move
        % is completed. should be interruptible by UI callbacks for
        % stopping. throws if a move is already in progress
        %
        % parameters
        %   position: [1 x numAxes] sized numeric vector containing the target
        %             positions for all axes. Vector can contain NaNs to
        %             indicate axes that shall not be moved
        %   timeout_s: [numeric,scalar] (optional) if not specified, the default timeout should be used
        move(obj,position,timeout_s);
        
        % moveAsync(position,callback,timeout)
        % initiates a move but returns immediately, not waiting for the move to complete
        % throws if a move is already in progress
        %
        % parameters
        %   position: a [1 x numAxes] sized vector containing the target
        %             positions for all axes. Vector can contain NaNs to
        %             indicate axes that shall not be moved
        %   callback:  [function handle] function to be called when the
        %              move completes
        moveAsync(obj,position,callback);
        
        % moveWaitForFinish(timeout_s)
        % waits until isMoving == false
        %
        % parameters
        %   timeout_s: [numeric,scalar] (optional) if not specified, the default timeout should be used
        %              after the timeout expires, stop() is called
        moveWaitForFinish(obj,timeout_s)
        
        % stop
        % stops the movement of all axes
        stop(obj);
        
        % startHoming()
        % starts the motor's homing routine. Blocks until the homing
        % routine completes. throws if motor does not support homing
        startHoming(obj);
    end
    
    methods
        function set.defaultTimeout_s(obj,val)
            validateattributes(val,{'numeric'},{'scalar','positive','nonnan','real'});
            obj.defaultTimeout_s = val;
        end
        
        function v = get.initSuccessful(obj)
            v = isempty(obj.errorMsg);
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
