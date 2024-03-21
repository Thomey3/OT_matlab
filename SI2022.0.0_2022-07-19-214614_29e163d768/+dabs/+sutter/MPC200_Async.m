classdef MPC200_Async < dabs.resources.devices.MotorController & dabs.resources.configuration.HasConfigPage & most.HasMachineDataFile
    properties (SetAccess=protected,Hidden)
        ConfigPageClass = 'dabs.resources.configuration.resourcePages.SerialMotorPage';
    end
    
    methods (Static)
        function names = getDescriptiveNames()
            names = {'Motor Controller\Sutter MPC200' 'Sutter Instrument\Sutter MPC200'};
        end
    end
    
    properties (SetObservable)
        hCOM = dabs.resources.Resource.empty();
    end
    
    properties (SetObservable, SetAccess=protected, AbortSet)
        lastKnownPosition;      % [numeric] [1 x numAxes] sized vector with the last known position of all motors
        isMoving = false;       % [logical] Scalar that is TRUE only if a move initiated by obj.move OR obj.moveAsync has not finished
        isHomed = true;        % [logical] Scalar that is TRUE if the motor's absolute position is known relative to its home position
    end
    
    properties (SetAccess=protected, SetObservable)
        numAxes = 3;
        autoPositionUpdate = true; % [logical] indicates if lastKnownPosition automatically updates when position of motor changes
    end
        
    properties (SetAccess=private, Hidden)
        hAsyncSerialQueue;
        hPositionTimer;
    end
    
    %%% Abstract property realizations (most.HasMachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'MPC200';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp; %#ok<MCCPI>
        mdfPropPrefix; %#ok<MCCPI>
        
        mdfDefault = defaultMdfSection();
    end
    
    %% Lifecycle
    methods
        function obj = MPC200_Async(name)
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
            success = true;
            success = success & obj.safeSetPropFromMdf('hCOM', 'comPort');
            
            if ~success
                obj.errorMsg = 'Error loading config';
            end
        end
        
        function saveMdf(obj)
            obj.safeWriteVarToHeading('comPort', obj.hCOM);
        end   
    end
    
    methods
        function deinit(obj)
            try
                obj.stop();
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
            
            most.idioms.safeDeleteObj(obj.hPositionTimer);
            obj.hPositionTimer = [];
            most.idioms.safeDeleteObj(obj.hAsyncSerialQueue);
            obj.hAsyncSerialQueue = [];
            
            if most.idioms.isValidObj(obj.hCOM)
                obj.hCOM.unreserve(obj);
            end
            
            obj.errorMsg = 'uninitialized';
        end
        
        function reinit(obj)
            try
                assert(most.idioms.isValidObj(obj.hCOM),'No serial port is specified');
                obj.hCOM.reserve(obj);
                
                obj.hAsyncSerialQueue = dabs.generic.AsyncSerialQueue(obj.hCOM.name,'BaudRate',128000);
                obj.hAsyncSerialQueue.ErrorFcn = @obj.errorFcn;
                
                obj.hPositionTimer = timer('Name','MPC200 position query timer',...
                    'ExecutionMode','fixedRate',...
                    'Period',0.3,...
                    'TimerFcn',@obj.positionTimerFcn);
                
                obj.errorMsg = '';
                obj.stop();
                obj.setRoeMode(1);
                
                start(obj.hPositionTimer);
                
                info = obj.infoHardware();
                fprintf('MPC200 Stage controller initialized: %s\n',info);
            catch ME
                obj.deinit();
                obj.errorMsg = sprintf('%s: initialization error: %s',obj.name,ME.message);
                most.ErrorHandler.logError(ME,obj.errorMsg);
            end
        end
    end
    
    methods        
        function positionTimerFcn(obj,varargin)            
            try
                if ~obj.hAsyncSerialQueue.busy
                    obj.getPositionAsync(@setPosition);
                end
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
            
            function setPosition(position)
                obj.lastKnownPosition = position;
            end
        end
        
        function getPositionAsync(obj,callback)
            req = uint8('C');
            rspBytes = 1+3*4+1;
            obj.hAsyncSerialQueue.writeReadAsync(req,rspBytes,@callback_);
            
            function callback_(rsp)                
                v = typecast(rsp(2:end-1),'int32');
                v = obj.stepsToMicrons(v);
                
                callback(v);
            end
        end
        
        function tf = queryMoving(obj)
            % MPC200: there is no explicit command to query if axes are
            % active
            tf = obj.isMoving;
        end
        
        function v = queryPosition(obj)
            req = uint8('C');
            rspBytes = 1+3*4+1;
            rsp = obj.hAsyncSerialQueue.writeRead(req,rspBytes);
            v = typecast(rsp(2:end-1),'int32');
            v = obj.stepsToMicrons(v);
            
            obj.lastKnownPosition = v;
        end
        
        function move(obj,position,timeout_s)
            if nargin < 3 || isempty(timeout_s)
                timeout_s = obj.defaultTimeout_s;
            end
            
            obj.moveAsync(position);
            obj.moveWaitForFinish(timeout_s);
        end
        
        function moveAsync(obj,position,callback)
            if nargin < 3 || isempty(callback)
                callback = [];
            end
            
            % Setting a position less than 0 can result in inf move
            % sequence
            if any(position<0)
                return;
            end
            
            assert(~obj.isMoving,'MPC200: Move is already in progress');
            
            if any(isnan(position))
                % fill in commands for position
               pos = obj.queryPosition();
               position(isnan(position)) = pos(isnan(position));
            end
            
            obj.isMoving = true;
            
            steps = obj.micronsToSteps(position);
            
            steps = typecast(int32(steps),'uint8');
            cmd = [uint8('M'), steps(:)'];
            
            rspBytes = 1;
            try
                obj.hAsyncSerialQueue.writeReadAsync(cmd,rspBytes,@callback_);
            catch ME
                obj.isMoving = false;
                rethrow(ME);
            end
            
            function callback_(rsp)
                obj.isMoving = false;
                
                if ~isempty(callback)
                    callback();
                end
            end
        end
        
        function moveWaitForFinish(obj,timeout_s)
            if nargin < 2 || isempty(timeout_s)
                timeout_s = obj.defaultTimeout_s;
            end
            
            s = tic();
            while toc(s) <= timeout_s
                if obj.isMoving
                    pause(0.1); % still moving
                    obj.hAsyncSerialQueue.processCallbackSafe();
                    % do not query position here!!!
                else
                    obj.queryPosition();
                    return;
                end
            end
            
            % if we reach this, the move timed out
            obj.stop();
            obj.queryPosition();
            error('Motor %s: Move timed out.\n',obj.name);
        end
        
        function stop(obj)
            if most.idioms.isValidObj(obj.hAsyncSerialQueue) && obj.isMoving
                req = uint8(3); % ^C
                rspBytes = 1;
                rsp = obj.hAsyncSerialQueue.writeRead(req,rspBytes);
                assert(rsp==uint8(13));
                obj.isMoving = false;
            end
        end
        
        function startHoming(obj)
            req = uint8('H');
            rspBytes = 1;
            rsp = obj.hAsyncSerialQueue.writeRead(req,rspBytes);
            assert(rsp==uint8(13));
        end
        
        function calibrate(obj)
            req = uint8('N');
            rspBytes = 1;
            rsp = obj.hAsyncSerialQueue.writeRead(req,rspBytes, 8);
            assert(rsp==uint8(13));
        end
    end
    
    %% Internal methods
    methods (Hidden)
        function errorFcn(obj,varargin)
            stop(obj.hPositionTimer);
            obj.errorMsg = sprintf('MPC200: Serial communication error\n');
            fprintf(2,'%s',obj.errorMsg);
        end
    end
    
    methods (Access = private)
        function steps = micronsToSteps(obj,um)
            steps = um * 16;
            steps(steps>400e3)  =  400e3;
            steps(steps<-400e3) = -400e3;
            steps = int32(steps);
        end
        
        function um = stepsToMicrons(obj,steps)
            um = double(steps)/16;
        end
        
        % throws
        function val = infoHardware(obj)            
            MAX_NUM_DRIVES = 4;
            rspBytes = 1+MAX_NUM_DRIVES+1;
            rsp = obj.hAsyncSerialQueue.writeRead(uint8('U'),rspBytes);
            numDrives   = rsp(1);
            driveStatus = rsp(2:5);
            
            rspBytes = 4;
            rsp = obj.hAsyncSerialQueue.writeRead(uint8('K'),rspBytes);
            activeDrive  = rsp(1);
            majorVersion = rsp(2);
            minorVersion = rsp(3);
            
            val = sprintf('Firmware version %d.%d - Drive %d of %d active',majorVersion,minorVersion,activeDrive,numDrives);
        end
        
        function setRoeMode(obj, val)
            assert(isnumeric(val) && any(ismember(0:1:9, val)), 'Invalid Mode! Roe Modes range from 0-9');
            req = [uint8('L') uint8(val)];
            rspBytes = 1;
            rsp = obj.hAsyncSerialQueue.writeRead(req,rspBytes);
            assert(rsp==uint8(13));
        end
    end
    
    methods
        function set.hCOM(obj,val)
            if isnumeric(val) && ~isempty(val)
                val = sprintf('COM%d',val);
            end
            
            val = obj.hResourceStore.filterByName(val);
            
            if ~isequal(val,obj.hCOM)
                
                if most.idioms.isValidObj(val)
                    validateattributes(val,{'dabs.resources.SerialPort'},{'scalar'});
                end
                
                obj.deinit();
                obj.hCOM.unregisterUser(obj);
                obj.hCOM = val;
                obj.hCOM.registerUser(obj,'COM Port');
            end
        end
    end
end

function s = defaultMdfSection()
    s = [...
            most.HasMachineDataFile.makeEntry('comPort','','Serial port the stage is connected to (e.g. ''COM3'')')...
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
