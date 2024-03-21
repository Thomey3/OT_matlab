classdef LegacyMotor < dabs.resources.devices.MotorController & dabs.resources.configuration.HasConfigPage & most.HasMachineDataFile
    properties (SetAccess=protected,Hidden)
        ConfigPageClass = 'dabs.resources.configuration.resourcePages.LegacyMotorPage';
    end
    
    methods (Static)
        function names = getDescriptiveNames()
            names = dabs.legacy.motor.MotorRegistry.getStageNames();
            names = cellfun(@(sN)['Motor Controller\{legacy driver} ' sN],names,'UniformOutput',false);
            
            names = [{'Motor Controller\Legacy Motor'} names];
        end
    end
    
    %%% Abstract property realizations (most.HasMachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'LegacyMotor';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp; %#ok<MCCPI>
        mdfPropPrefix; %#ok<MCCPI>
        
        mdfDefault = defaultMdfSection();
    end
    
    properties
        hMotor
    end
    
    properties (Dependent)
        hLSC
    end
    
    %%% dabs.interfaces.MotorController properties
    properties (SetObservable, SetAccess=protected, AbortSet)
        lastKnownPosition;  % [numeric] [1 x numAxes] sized vector with the last known position of all motors
        isMoving;           % [logical] Scalar that is TRUE only if a move initiated by obj.move OR obj.moveAsync has not finished
        isHomed = true;     % [logical] Scalar that is TRUE if the motor's absolute position is known relative to its home position
    end
    
    properties (SetAccess=protected, SetObservable)
        numAxes = 3;            % [numeric] Scalar integer describing the number of axes of the MotorController
        autoPositionUpdate = false; % [logical] indicates if lastKnownPosition automatically updates when position of motor changes
    end
    
    properties (SetAccess = private, GetAccess = private)
        hListeners = event.listener.empty(0,1);
    end
    
    %%% LifeCycle
    methods
        function obj = LegacyMotor(name)
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
    
    methods        
        function loadMdf(obj)
            obj.deinit();
        end
        
        function saveMdf(obj)
            fields = fieldnames(obj.mdfData);
            
            for idx = 1:numel(fields)
                field = fields{idx};
                obj.safeWriteVarToHeading(field, obj.mdfData.(field));
            end            
        end        
    end
    
    methods
        function deinit(obj)
            delete(obj.hListeners);
            obj.hListeners = event.listener.empty(0,1);
            
            most.idioms.safeDeleteObj(obj.hMotor);
            obj.hMotor = [];
            
            obj.errorMsg = 'uninitialized';
        end
        
        function reinit(obj)
            obj.deinit();
            
            try
                obj.errorMsg = '';
                
                assert(~isempty(obj.mdfData.controllerType),'No controller type specified.');
                obj.hMotor = dabs.legacy.motor.StageController(obj.mdfData);
                obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hMotor,'LSCError',@obj.lscErrorUpdate);
                obj.lscErrorUpdate();
                
                obj.numAxes = obj.hMotor.numDeviceDimensions;
                
                if isempty(obj.hMotor.hLSC)
                    error('Error instantiating Motor');
                end
                
                if isempty(obj.errorMsg)
                    obj.queryPosition();
                end
                
            catch ME
                obj.deinit();
                obj.errorMsg = sprintf('%s: initialization error: %s',obj.name,ME.message);
                most.ErrorHandler.logError(ME,obj.errorMsg);
            end
        end
    end
    
    methods        
        function tf = queryMoving(obj)
            tf = obj.hMotor.hLSC.isMoving;
        end
        
        function pos = queryPosition(obj)
            pos = obj.hMotor.positionAbsolute;
            pos = pos(1:obj.hMotor.numDeviceDimensions);
            
            obj.lastKnownPosition = pos;
        end
        
        function move(obj,position,timeout_s)
            if nargin > 3 && ~isempty(timeout_s)
                obj.hMotor.moveTimeout = timeout_s;
            end
            
            obj.moveCompleteAbsolute(position);
        end
        
        function moveAsync(obj,position,callback)
            if nargin > 2 && ~isempty(callback)
                error('Motor %s does not support async move with a callback',obj.name);
            end
            obj.hMotor.moveStartAbsolute(position);
        end
        
        function stop(obj)
            obj.moveInterrupt();
        end
        
        function startHoming(obj)
            error('Motor %s does not support homing',obj.name);
        end
    end
    
    methods
        function moveWaitForFinish(obj, timeout_s)
            if nargin < 2 || isempty(timeout_s)
                timeout_s = obj.defaultTimeout_s;
            end
            
            obj.hMotor.moveWaitForFinish(timeout_s);
        end
        
        function lscErrorUpdate(obj,varargin)
            if obj.hMotor.lscErrPending
                obj.errorMsg = sprintf('Motor %s is in an error state',obj.name);
            end
        end
    end
    
    methods
        function val = get.hLSC(obj)
            val = obj.hMotor.hLSC;
        end
        
        function val = get.isMoving(obj)
            val = obj.initSuccessful && obj.queryMoving();
        end
    end
end

function s = defaultMdfSection()
    s = [...
        most.HasMachineDataFile.makeEntry('Motor used for X/Y/Z motion, including stacks.')... % comment only
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('controllerType','','If supplied, one of {''sutter.mp285'', ''sutter.mpc200'', ''thorlabs.mcm3000'', ''thorlabs.mcm5000'', ''scientifica'', ''pi.e665'', ''pi.e816'', ''npoint.lc40x'', ''bruker.MAMC''}.')...
        most.HasMachineDataFile.makeEntry('comPort',[],'Integer identifying COM port for controller, if using serial communication')...
        most.HasMachineDataFile.makeEntry('customArgs',{{}},'Additional arguments to stage controller. Some controller require a valid stageType be specified')...
        most.HasMachineDataFile.makeEntry('invertDim','','string with one character for each dimension specifying if the dimension should be inverted. ''+'' for normal, ''-'' for inverted')...
        most.HasMachineDataFile.makeEntry('positionDeviceUnits',[],'1xN array specifying, in meters, raw units in which motor controller reports position. If unspecified, default positionDeviceUnits for stage/controller type presumed.')...
        most.HasMachineDataFile.makeEntry('velocitySlow',[],'Velocity to use for moves smaller than motorFastMotionThreshold value. If unspecified, default value used for controller. Specified in units appropriate to controller type.')...
        most.HasMachineDataFile.makeEntry('velocityFast',[],'Velocity to use for moves larger than motorFastMotionThreshold value. If unspecified, default value used for controller. Specified in units appropriate to controller type.')...
        most.HasMachineDataFile.makeEntry('moveCompleteDelay',[],'Delay from when stage controller reports move is complete until move is actually considered complete. Allows settling time for motor')...
        most.HasMachineDataFile.makeEntry('moveTimeout',[],'Default: 2s. Fixed time to wait for motor to complete movement before throwing a timeout error')...
        most.HasMachineDataFile.makeEntry('moveTimeoutFactor',[],'(s/um) Time to add to timeout duration based on distance of motor move command')...
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
