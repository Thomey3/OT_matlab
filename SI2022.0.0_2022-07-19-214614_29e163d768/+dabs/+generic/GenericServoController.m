classdef GenericServoController < handle 
    properties (SetObservable)
        minAngle = 0;
        maxAngle = 1.75*360;
        minPulseDuration = 1.5e-3;
        maxPulseDuration = 1.9e-3;
        pulseRepeatPeriod = 20e-3;
        
        angle = 0;
        outputTerminal = 'PFI13';
    end
    
    properties (SetAccess = private,SetObservable)
        started = false;
    end
    
    properties (Hidden)
        hTask;
    end
    
    %% Lifecycle
    methods
        function obj = GenericServoController(devName,ctrChannel)
            try
                name = sprintf('ServoController-%s-Ctr%d',devName,ctrChannel);
                obj.hTask = most.util.safeCreateTask(name);
                lowTime = 1;  % preliminary, changed later
                highTime = 1; % preliminary, changed later
                obj.hTask.createCOPulseChanTime(devName,ctrChannel,'Servo PWM channel',lowTime,highTime);
                obj.hTask.cfgImplicitTiming('DAQmx_Val_ContSamps');
            catch ME
                obj.delete();
                rethrow(ME);
            end
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hTask);
        end
    end
    
    %% Class methods
    methods
        function start(obj)
            if ~obj.started
                obj.stop();
                obj.configure(true);
                obj.hTask.start();
                obj.started = true;
            end
        end
        
        function abort(obj)
            obj.stop();
        end
        
        function stop(obj)
            obj.hTask.abort();
            obj.started = false;
        end
    end
    
    methods (Hidden)
        function [lowTime,highTime] = angleToPulseTime(obj,angle)
            assert(obj.minPulseDuration < obj.maxPulseDuration);
            assert(obj.minAngle <= angle <= obj.maxAngle);
            
            highTime = obj.minPulseDuration + (obj.maxPulseDuration-obj.minPulseDuration)/(obj.maxAngle-obj.minAngle) * (angle-obj.minAngle);
            lowTime = obj.pulseRepeatPeriod - highTime;
            
            assert(highTime > 0); %Sanity check
        end
    end
    
    %% Property Getter/Setter
    methods
        function set.angle(obj,val)
            obj.angle = val;
            
            if obj.started
                [lowTime,highTime] = obj.angleToPulseTime(obj.angle);
                obj.hTask.writeCounterTimeScalar(highTime,lowTime,1);
            end
        end
        
        function set.outputTerminal(obj,val)
            obj.outputTerminal = val;
            obj.configure();
        end
        
        function set.maxAngle(obj,val)
            obj.maxAngle = val;
            obj.angle = obj.angle;
        end
        
        function set.minAngle(obj,val)
            obj.minAngle = val;
            obj.angle = obj.angle;
        end
        
        function set.maxPulseDuration(obj,val)
            obj.maxPulseDuration = val;
            obj.angle = obj.angle;
        end
        
        function set.minPulseDuration(obj,val)
            obj.minPulseDuration = val;
            obj.angle = obj.angle;
        end
        
        function configure(obj,force)
            if nargin < 2 || isempty(force)
                force = false;
            end
            
            if ~obj.started && ~force
                return
            end
            
            wasStarted = obj.started;
            obj.stop();
            
            [lowTime,highTime] = obj.angleToPulseTime(obj.angle);
            obj.hTask.channels(1).set('pulseHighTime',highTime);
            obj.hTask.channels(1).set('pulseLowTime',lowTime);
            obj.hTask.channels(1).set('pulseTerm',obj.outputTerminal);
            
            if wasStarted
                obj.start();
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
