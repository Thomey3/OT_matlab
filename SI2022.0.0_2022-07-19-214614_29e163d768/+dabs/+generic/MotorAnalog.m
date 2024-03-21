classdef MotorAnalog < dabs.resources.devices.MotorController & dabs.resources.configuration.HasConfigPage & most.HasMachineDataFile
    %% Abstract Methods (dabs.resources.configuration.HasConfigPage)
    methods (Static)
        function names = getDescriptiveNames()
            names = {'Motor Controller\Analog Motor Controller'};
        end
    end
    
    properties (SetObservable)
        commandVoltsPerMicron; %Conversion factor for command signal to analog linear stage controller
        commandVoltsOffset; %Offset value, in volts, for command signal to analog linear stage controller
        
        hAOPosition = dabs.resources.Resource.empty();
        
        timeSinceLastMove = tic();
        settlingTime_s = 0.1;
        travelRange_um = [0 100];
    end
    
    %% Abstract Property Realization (dabs.resources.devices.MotorController)
    properties(SetObservable, SetAccess=protected, AbortSet)
        lastKnownPosition = 0;  % [numeric] [1 x numAxes] sized vector with the last known position of all motors
        isHomed = true;         % [logical] Scalar that is TRUE if the motor's absolute position is known relative to its home position
        isMoving = false;
    end
    
    properties (SetAccess = private,GetAccess = private)
        hTimer = [];
        TimerFcn;
        hListeners = event.listener.empty(0,1);
    end
    
    properties(SetAccess=protected, SetObservable)
        numAxes = 1;            % [numeric] Scalar integer describing the number of axes of the MotorController
        autoPositionUpdate = true; % [logical] indicates if lastKnownPosition automatically updates when position of motor changes
    end
    
    %% Abstract Property Realization (most.HasMachineDataFile)
    properties(Constant,Hidden)
        mdfClassName = mfilename('class');
        mdfHeading = 'Motors';
        
        mdfDefault = defaultMdfSection;
    end
    
    properties (Constant,Hidden)
        mdfDependsOnClasses;  %#ok<MCCPI> 
        mdfDirectProp;        %#ok<MCCPI>
        mdfPropPrefix;        %#ok<MCCPI>
    end
    
    %% Abstract Property Realization (dabs.resources.configuration.HasConfigPage)
    properties (SetAccess=protected,Hidden)
        ConfigPageClass = 'dabs.resources.configuration.resourcePages.MotorAnalogPage';
    end
    
    %% Lifecycle Methods
    methods
        function obj = MotorAnalog(name)
            obj = obj@dabs.resources.devices.MotorController(name);
            obj = obj@most.HasMachineDataFile(true);
            
            obj.deinit();
            obj.loadMdf();
            obj.reinit();
        end
        
        function delete(obj)
            obj.deinit();
        end
    end

%% MDF Functions
methods
    function loadMdf(obj)
        success = true;
        
        success = success & obj.safeSetPropFromMdf('hAOPosition', 'AOPosition');
        success = success & obj.safeSetPropFromMdf('commandVoltsPerMicron', 'commandVoltsPerMicron');
        success = success & obj.safeSetPropFromMdf('commandVoltsOffset', 'commandVoltsOffset');
        success = success & obj.safeSetPropFromMdf('travelRange_um', 'travelRange_um');
        success = success & obj.safeSetPropFromMdf('settlingTime_s', 'settlingTime_s');
        
        if ~success
            obj.deinit();
            obj.errorMsg = 'Error loading settings from machine data file';
        end
    end
    
    function saveMdf(obj)
        obj.safeWriteVarToHeading('AOPosition', obj.hAOPosition);        
        obj.safeWriteVarToHeading('commandVoltsPerMicron', obj.commandVoltsPerMicron);
        obj.safeWriteVarToHeading('commandVoltsOffset', obj.commandVoltsOffset);
        obj.safeWriteVarToHeading('travelRange_um', obj.travelRange_um);
        obj.safeWriteVarToHeading('settlingTime_s', obj.settlingTime_s);
    end
    
end
%% Helper Funtions
methods
    function voltage = posn2volt(obj, posn)
        voltage = posn * obj.commandVoltsPerMicron + obj.commandVoltsOffset;
    end
    
    function posn = volt2posn(obj, voltage)
        posn = (voltage-obj.commandVoltsOffset)/obj.commandVoltsPerMicron;
    end
    
    function updateLastKnownPosition(obj)
        voltage = obj.hAOPosition.lastKnownValue; % convert it to position
        obj.lastKnownPosition = obj.volt2posn(voltage);
    end
end

    %% Abstract Method Realizations (dabs.interfaces.MotorController)
    methods
        % constructor
        % construct object and attempt to init motor. contructor should return successfully even if
        % communication with motor failed. gracefully clean up in the case of failure and set
        % errorMsg nonempty so that connection can be reattempted by calling reinit.
        
        % reinit
        % reinitializes the communication interface to the motor controller. Should throw if init
        % fails
        function reinit(obj)
            obj.deinit();
            
            try
                assert(most.idioms.isValidObj(obj.hAOPosition),'No position output specified');
                
                obj.hAOPosition.reserve(obj);
                
                obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hAOPosition,'lastKnownValueChanged',@(varargin)obj.updateLastKnownPosition);
                obj.updateLastKnownPosition();
                
                obj.hTimer = timer('Name',sprintf('%s polling timer',obj.name));
                obj.hTimer.ExecutionMode = 'singleShot';
                
                obj.errorMsg = '';
            catch ME
                obj.deinit();
                obj.errorMsg = sprintf('%s: initialization error: %s',obj.name,ME.message);
                most.ErrorHandler.logError(ME,obj.errorMsg);
            end
        end
        
        function deinit(obj)
            obj.errorMsg = 'uninitialized';
            
            delete(obj.hListeners);
            obj.hListeners = event.listener.empty(0,1);
            
            most.idioms.safeDeleteObj(obj.hTimer);
            
            if most.idioms.isValidObj(obj.hAOPosition)
                obj.hAOPosition.unreserve(obj);
            end
        end
        
        
        function tf = queryMoving(obj)
            timeElapsed = toc(obj.timeSinceLastMove);
            moveDone = timeElapsed < obj.settlingTime_s;
            
            if moveDone && strcmpi(obj.hTimer.Running,'on')
                stop(obj.hTimer);
                try
                    fcn = obj.hTimer.TimerFcn;
                    fcn();
                catch ME
                    ME.rethrow();
                end
            end
            
            if moveDone && obj.isMoving
                obj.isMoving = false;
            end
            
            tf = obj.isMoving;
        end
        
        %No feedback, so only update lastKnownPosition in move
        function position = queryPosition(obj)
            position = obj.lastKnownPosition;
        end
        
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
        function move(obj,position,timeout_s)
            if nargin<3 || isempty(timeout_s)
                timeout_s = obj.defaultTimeout_s;
            end
            
            obj.moveAsync(position,timeout_s);
            obj.moveWaitForFinish();
        end
        
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
        function moveAsync(obj,position,callback)
            if nargin<3 || isempty(callback)
                callback = [];
            end
            
            assert(isempty(obj.errorMsg),'Motor %s is in an error state: %s',obj.name,obj.errorMsg);
            
            assert(~obj.queryMoving(),'Motor %s is currently executing a move',obj.name);
            withinRange = position >= obj.travelRange_um(1) && position <= obj.travelRange_um(2);
            assert(withinRange , '%s: Requested motor position %.2f is outside configured range(%.2f .. %.2f)',...
                obj.name,position,obj.travelRange_um(1),obj.travelRange_um(2));
            
            voltage = obj.posn2volt(position);
            withinRange = voltage >= obj.hAOPosition.outputRange_V(1) && voltage <= obj.hAOPosition.outputRange_V(2);
            assert(withinRange , '%s: Requested motor output voltage %.2f is outside DAQ voltage output range(%.2f .. %.2f)',...
                obj.name,voltage,obj.hAOPosition.outputRange_V(1),obj.hAOPosition.outputRange_V(2));
            
            obj.hAOPosition.setValue(voltage);
            obj.isMoving = true;
            obj.timeSinceLastMove = tic;
            
            obj.hTimer.StartDelay = obj.settlingTime_s;
            obj.hTimer.TimerFcn = @(varargin)resetIsMoving(callback);
            
            start(obj.hTimer);
            
            %%% Nested function
            function resetIsMoving(callback)
                obj.isMoving = false;
                if ~isempty(callback)
                    callback();
                end
            end
        end
        
        % moveWaitForFinish(timeout_s)
        % waits until isMoving == false
        %
        % parameters
        %   timeout_s: [numeric,scalar] (optional) if not specified, the default timeout should be used
        %              after the timeout expires, stop() is called
        function moveWaitForFinish(obj,timeout_s)
            if nargin < 2 || isempty(timeout_s)
                timeout_s = obj.defaultTimeout_s;
            end
            
            start = tic();
            while obj.queryMoving()
                pause(0.001);
                if toc(start) >= timeout_s
                    break
                end
            end
        end
        
        % stop
        % stops the movement of all axes
        function stop(obj)
            % can't really stop
        end
        
        % startHoming()
        % starts the motor's homing routine. Blocks until the homing
        % routine completes. throws if motor does not support homing
        function startHoming(obj)
            % No-op
        end
        
    end
    
    %% Getter/Setter Methods
    methods      
        function set.commandVoltsPerMicron(obj,val)
            validateattributes(val,{'numeric'},{'scalar','nonnan','real','finite','nonzero'});
            obj.commandVoltsPerMicron = val;
        end
        
        function set.commandVoltsOffset(obj,val)
            validateattributes(val,{'numeric'},{'scalar','nonnan','real','finite'});
            obj.commandVoltsOffset = val;
        end
        
        function set.hAOPosition(obj,val)
            val = obj.hResourceStore.filterByName(val);
            
            if ~isequal(val,obj.hAOPosition)
                if most.idioms.isValidObj(val)
                    validateattributes(val,{'dabs.resources.ios.AO'},{'scalar'});
                end
                
                obj.deinit();
                obj.hAOPosition.unregisterUser(obj);
                obj.hAOPosition = val;
                obj.hAOPosition.registerUser(obj,'Position');
            end
        end
        
        function set.travelRange_um(obj,val)
            validateattributes(val,{'numeric'},{'finite','nonnan','size',[1 2],'real'});
            assert(val(1) < val(2),'travelRange_um needs to be a sorted array');
            
            obj.travelRange_um = val;
        end
        
        function set.settlingTime_s(obj,val)
            validateattributes(val,{'numeric'},{'finite','nonnan','scalar','real','nonnegative'});
            obj.settlingTime_s = val;
        end
        
    end
end

function s = defaultMdfSection()
    s = [...
            most.HasMachineDataFile.makeEntry('AOPosition', '', 'Name of the channel to control the motor position (e.g. ''/Dev1/AO0'')')...
            most.HasMachineDataFile.makeEntry('commandVoltsPerMicron', 0.1, 'Conversion factor between volts and microns')...
            most.HasMachineDataFile.makeEntry('commandVoltsOffset', 0, 'Voltage when position is at zero')...
            most.HasMachineDataFile.makeEntry('travelRange_um', [0 100], 'Travel range in um')...
            most.HasMachineDataFile.makeEntry('settlingTime_s', 1, 'Settling Time of Motor Analog Device')
        ];
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
