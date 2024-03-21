classdef Motor < dabs.resources.devices.MotorController
    properties (SetAccess = protected, SetObservable, AbortSet)
        lastKnownPosition = [0 0 0];
        isMoving = false;
        isHomed = true;
    end
    
    properties (SetAccess=protected, SetObservable)
        numAxes = 3;
        autoPositionUpdate = true; % [logical] indicates if lastKnownPosition automatically updates when position of motor changes
    end
    
    properties (SetAccess=private, Hidden)
        hTransition
    end
    
    properties
        velocity_um_per_s = 500;
    end
    
    properties (Hidden,Dependent)
        lastKnownPositionInternal; % lastKnownPosition is SetAccess=protected and can't be modified by most.gui.Transition
    end
    
    %% LIFECYCLE
    methods
        function obj = Motor(name)
            obj = obj@dabs.resources.devices.MotorController(name);
            obj.WidgetClass = '';
            
            obj.deinit();
            obj.reinit();
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hTransition);
        end
    end
    
    %% ABSTRACT METHOD IMPLEMENTATIONS (dabs.resources.devices.MotorController)
    methods
        function deinit(obj)
            try
                obj.stop();
                obj.errorMsg = 'uninitialized';
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
        end
        
        function reinit(obj)
            try
                obj.errorMsg = '';
                obj.stop();
                obj.queryPosition();
            catch ME
                obj.deinit();
                obj.errorMsg = sprintf('%s: initialization error: %s',obj.name,ME.message);
                most.ErrorHandler.logError(ME,obj.errorMsg);
            end
        end
        
        function tf = queryMoving(obj)
            tf = obj.isMoving;
        end
        
        function v = queryPosition(obj)
            v = obj.lastKnownPosition;
        end
        
        function move(obj,position,timeout_s)
            if nargin < 3 || isempty(timeout_s)
                timeout_s = obj.defaultTimeout_s;
            end
            
            obj.moveAsync(position);
            obj.moveWaitForFinish(timeout_s)
        end
        
        function moveWaitForFinish(obj,timeout_s)
            if nargin < 2 || isempty(timeout_s)
                timeout_s = obj.defaultTimeout_s;
            end
            
            s = tic();
            while toc(s) <= timeout_s
                if obj.isMoving
                    pause(0.01); % still moving
                else
                    return;
                end
            end
            
            obj.stop();
            error('Motor %s: Move timed out.',obj.name); % if we reach this line, the move timed out
        end
        
        %%% local function
        function moveAsync(obj,position,callback)
            if nargin < 3 || isempty(callback)
                callback = [];
            end
            
            if ~isempty(obj.errorMsg)
                return
            end
            
            % filter NaNs
            position(isnan(position)) = obj.lastKnownPosition(isnan(position));
            
            d = max(abs(obj.lastKnownPosition-position));
            duration = d / obj.velocity_um_per_s;
            trajectory = [];
            
            obj.isMoving = true;
            
            updatePeriod = 0.3;
            obj.hTransition = most.gui.Transition(duration,obj,'lastKnownPositionInternal',position,trajectory,@moveCompleteCallback,updatePeriod);
            
            function moveCompleteCallback(varargin)
                obj.isMoving = false;
                if ~isempty(callback)
                    callback();
                end
            end
        end
        
        function stop(obj)
            most.idioms.safeDeleteObj(obj.hTransition);
            obj.isMoving = false;
        end
        
        function startHoming(obj)
            obj.move([0,0,0]);
            obj.isHomed = true;
        end
    end
    
    %% Property Getter/Setter
    methods
        function set.lastKnownPositionInternal(obj,val)
            obj.lastKnownPosition = val;
        end
        
        function val = get.lastKnownPositionInternal(obj)
            val = obj.lastKnownPosition;
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
