classdef MP285A_Async < dabs.resources.devices.MotorController & dabs.resources.configuration.HasConfigPage & most.HasMachineDataFile
    properties (SetAccess=protected,Hidden)
        ConfigPageClass = 'dabs.resources.configuration.resourcePages.SutterMP285AMotorPage';
    end
    
    methods (Static)
        function names = getDescriptiveNames()
            names = {'Motor Controller\Sutter MP285A' 'Sutter Instrument\Sutter MP285A'};
        end
    end
    
    %dabs.resources.devices.MotorController
    properties (SetObservable, SetAccess=protected, AbortSet)
        lastKnownPosition;      % [numeric] [1 x numAxes] sized vector with the last known position of all motors
        isMoving = false;       % [logical] Scalar that is TRUE only if a move initiated by obj.move OR obj.moveAsync has not finished
        isHomed = true;         % [logical] Scalar that is TRUE if the motor's absolute position is known relative to its home position
    end
    
    properties (SetObservable)
        hCOM = dabs.resources.Resource.empty();
        baudRate = 9600;
        resolutionMode = 'coarse';
        fineVelocity   =  500;
        coarseVelocity = 1500;
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
        mdfHeading = 'MP285A';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp; %#ok<MCCPI>
        mdfPropPrefix; %#ok<MCCPI>
        
        mdfDefault = defaultMdfSection();
    end
    
    properties (Constant)
        availableBaudRates = [1200 2400 4800 9600 19200];
    end
    
    %% CLASS-SPECIFIC PROPERTIES
    properties (Constant,Hidden)        
        postResetDelay = 2; %Time, in seconds, to wait following a reset command before proceeding
    end
    
    %% CONSTRUCTOR/DESTRUCTOR
    methods
        function obj = MP285A_Async(name)
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
            success = success & obj.safeSetPropFromMdf('baudRate', 'baudRate');
            success = success & obj.safeSetPropFromMdf('resolutionMode', 'resolutionMode');
            success = success & obj.safeSetPropFromMdf('fineVelocity', 'fineVelocity');
            success = success & obj.safeSetPropFromMdf('coarseVelocity', 'coarseVelocity');
            
            if ~success
                obj.errorMsg = 'Error loading config';
            end
        end
        
        function saveMdf(obj)
            obj.safeWriteVarToHeading('comPort', obj.hCOM);
            obj.safeWriteVarToHeading('baudRate', obj.baudRate);
            obj.safeWriteVarToHeading('resolutionMode', obj.resolutionMode);
            obj.safeWriteVarToHeading('fineVelocity', obj.fineVelocity);
            obj.safeWriteVarToHeading('coarseVelocity', obj.coarseVelocity);
        end
    end
    
    methods
        function deinit(obj)
            try
                obj.resetHook()
            catch
            end
            
            try
                obj.stop();
            catch
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
            obj.deinit();
            
            try
                assert(most.idioms.isValidObj(obj.hCOM),'No serial port is specified');
                obj.hCOM.reserve(obj);
                
                obj.hAsyncSerialQueue = dabs.generic.AsyncSerialQueue(obj.hCOM.name,'BaudRate',obj.baudRate);
                obj.hAsyncSerialQueue.ErrorFcn = @obj.errorFcn;
                
                obj.hPositionTimer = timer('Name','MP285A position query timer',...
                    'ExecutionMode','fixedRate',...
                    'Period',1,...
                    'TimerFcn',@obj.positionTimerFcn);
                
                obj.errorMsg = '';
                
                obj.stop();
                obj.setVelocityAndResolutionOnDevice();

                start(obj.hPositionTimer);
            catch ME
                obj.deinit();
                obj.errorMsg = sprintf('%s: initialization error: %s',obj.name,ME.message);
                most.ErrorHandler.logError(ME,obj.errorMsg);
            end
        end
        
        function positionTimerFcn(obj, varargin)
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
        
        function getPositionAsync(obj, callback)
            req = [uint8('c') uint8(13)];
            obj.hAsyncSerialQueue.writeReadAsync(req,13,@callback_);
            
            function callback_(rsp)                
                v = typecast(rsp(1:end-1),'int32');
                v = double(v);
                v = v(:)'.*4e-2;
                
                callback(v);
            end
        end
        
        function tf = queryMoving(obj)
            % MP285A: No Explicit command to query if axes are active.
            % Previous implementation was just chcking whether an
            % asyncReply was pending...
            tf = obj.isMoving;
        end
        
        function v = queryPosition(obj)
            req = [uint8('c') uint8(13)];
            rsp = obj.hAsyncSerialQueue.writeRead(req,native2unicode(uint8(13)));%13);
            v = typecast(rsp(1:end-1),'int32');
            v = double(v);
            v = v(:)'.*4e-2;
            
            obj.lastKnownPosition = v;
        end
        
        function move(obj, position, timeout_s)
            if nargin < 3 || isempty(timeout_s)
                timeout_s = obj.defaultTimeout_s;
            end
            
            obj.moveAsync(position);
            obj.moveWaitForFinish(timeout_s);
        end
        
        function moveAsync(obj, position, callback)
            if nargin < 3 || isempty(callback)
                callback = [];
            end
            
            assert(~obj.isMoving,'MP285A: Move is already in progress');
            
            if any(isnan(position))
                % fill in commands for position
               pos = obj.queryPosition();
               position(isnan(position)) = pos(isnan(position));
            end
            
            obj.isMoving = true;
            
            steps = position./4e-2;
            cmd = [uint8('m'), typecast(int32(steps),'uint8'), uint8(13)];%steps(:)'];

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
        
        function moveWaitForFinish(obj, timeout_s)
            if nargin < 2 || isempty(timeout_s)
                timeout_s = obj.defaultTimeout_s;
            end
            s = tic();
            while toc(s) <= timeout_s 
                if obj.isMoving
                    
                    pause(0.005); % still moving. 
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
            if most.idioms.isValidObj(obj.hAsyncSerialQueue) 
                req = [uint8(3) uint8(13)]; 
                rspBytes = 1;
                rsp = obj.hAsyncSerialQueue.writeRead(req,rspBytes);

                assert(rsp == uint8(13),'%s did not respond to stop command as expected',obj.name);
                
                obj.isMoving = false;
            end
        end
        
        function startHoming(obj)
            % No Op
            fprintf('Homing?\n');
        end
        
    end
    
    %% PROPERTY ACCESS METHODS
    methods        
        function set.fineVelocity(obj, val)
            validateattributes(val,{'numeric'},{'scalar','integer','>=',0,'<=',1310});
            
            if ~isequal(obj.fineVelocity,val)
                obj.fineVelocity = val;
                obj.deinit();
            end
        end
        
        function set.coarseVelocity(obj, val)
            validateattributes(val,{'numeric'},{'scalar','integer','>=',0,'<=',3000});

            if ~isequal(obj.coarseVelocity,val)
                obj.coarseVelocity = val;
                obj.deinit();
            end
        end

        function set.resolutionMode(obj,val)
            assert(ismember(val, {'fine', 'coarse'}), 'Invalid Resolution Mode ''%s''. Valid modes are ''fine'' or ''coarse''', val);
            if ~strcmp(obj.resolutionMode,val)
                obj.resolutionMode = val;
                obj.deinit();
            end
        end        
        
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
        
        function set.baudRate(obj,val)
            validateattributes(val,{'numeric'},{'integer','positive','real','nonnan','finite'});
            assert(ismember(val,obj.availableBaudRates),'Not a valid baudrate. Allowed baud rates are: %s',mat2str(obj.availableBaudRates));
            
            if val ~= obj.baudRate
                obj.deinit();
                obj.baudRate = val;
            end
        end
    end
    
    methods (Access=private)
        function setVelocityAndResolutionOnDevice(obj)
            switch obj.resolutionMode
                case 'coarse'
                    val = uint16(obj.coarseVelocity);
                    val = bitset(val,16,0); % set bit 16 to 0
                case 'fine'
                    val = uint16(obj.fineVelocity);
                    val = bitset(val,16,1); % set bit 16 to 1
                otherwise
                    error('Unknown resolution mode: %s',obj.resolutionMode)
            end

            val = typecast(val,'uint8');
            req = [uint8('V') val uint8(13) ];
            obj.hAsyncSerialQueue.writeRead(req,1);
        end
    end
        
    %% ABSTRACT METHOD IMPLEMENTATIONS
    methods (Access=protected,Hidden)
        function resetHook(obj)
            req = [uint8('r') uint8(13)];
            obj.hAsyncSerialQueue.writeRead(req,[]);
            pause(obj.postResetDelay);
        end        
    end
    
    %% HIDDEN METHODS
    methods (Hidden)
        function status = getStatus(obj)
            obj.assertNoError();

            req = [uint8('s') uint8(13)];
            rspBytes = 33;
            data = obj.hAsyncSerialQueue.writeRead(req,native2unicode(uint8(13)));
            data = data(1:end-1); % remove carriage return

            status = struct();

            flags = bitget(data(1),1:8);
            status.SetupNumber   = flags(1) + 2*flags(2) + 4*flags(3) + 8*flags(4);        % Currently loaded setup number (decimal digit 0-9)
            status.ROE_Direction = most.idioms.ifthenelse(flags(5),'Negative','Positive'); % Last ROE direction
            status.REL_ABS_F     = most.idioms.ifthenelse(flags(6),'Relative','Absolute'); % Display origin NOTE: This is reversed in the documentation (rev 3.13)
            status.MODE_F        = most.idioms.ifthenelse(flags(7),'Continuous','Pulse');  % Manual mode flag
            status.STORE_F       = most.idioms.ifthenelse(flags(8),'Stored','Erased');     % Setup condition

            status.UDIRXYZ = logical([data(2) data(3) data(4)] - uint8([0 2 4]));

            status.ROE_VARI = typecast(data(5:6),'uint16');
            status.UOFFSET  = typecast(data(7:8),'uint16');
            status.URANGE   = typecast(data(9:10),'uint16');
            status.PULSE    = typecast(data(11:12),'uint16');
            status.USPEED   = typecast(data(13:14),'uint16');
            status.INDEVICE = data(15);

            flags_2 = bitget(data(16),1:8);
            status.LOOP_MODE  = most.idioms.ifthenelse(flags_2(1),'Do loops','Execute once'); % Program loops
            status.LEARN_MODE = most.idioms.ifthenelse(flags_2(2),'Learning now','Not learning'); % Learn mode status
            status.STEP_MODE  = most.idioms.ifthenelse(flags_2(3),50,10); % Resolution (microsteps/step)
            status.SW2_MODE   = logical(flags_2(4)); % Joystick side button
            status.SW1_MODE   = logical(flags_2(5)); % Enable FSR/Joystick
            status.SW3_MODE   = logical(flags_2(6)); % ROE switch 
            status.SW4_MODE   = logical(flags_2(7)); % Switches 4 & 5
            status.REVERSE_IT = logical(flags_2(8)); % Program sequence

            status.JUMPSPD   = typecast(data(17:18),'uint16'); % “Jump to max at” speed
            status.HIGHSPD   = typecast(data(19:20),'uint16'); % “Jumped to” speed
            status.DEAD      = typecast(data(21:22),'uint16'); % Dead zone, not saved
            status.WATCH_DOG = typecast(data(23:24),'uint16'); % Programmer’s function (analog input for overload protection)
            status.STEP_DIV  = typecast(data(25:26),'uint16'); % Microns <--> Microsteps conversion factor
            status.STEP_MUL  = typecast(data(27:28),'uint16'); % % Microns <--> Microsteps conversion factor / different for MP285 / MP285A
            status.micronsPerMicroStep = double(status.STEP_DIV)/10/1000;
            status.XSPEED     = bitset(typecast(data(29:30),'uint16'),16,0); % Velocity
            status.XSPEED_RES = most.idioms.ifthenelse(bitget(typecast(data(29:30),'uint16'),16),'fine','coarse');
            status.VERSION   = sprintf('%.2f',double(typecast(data(31:32),'uint16'))/100); % Firmware version
        end
    end
    
end

function s = defaultMdfSection()
    s = [...
            most.HasMachineDataFile.makeEntry('comPort','','Serial port the stage is connected to (e.g. ''COM3'')')...
            most.HasMachineDataFile.makeEntry('baudRate',9600,'Baud rate setting on MP285')...
            most.HasMachineDataFile.makeEntry('resolutionMode','coarse','One of {''coarse'',''fine''}')...
            most.HasMachineDataFile.makeEntry('fineVelocity',500,'Velocity for Fine moves on MP285A')...
            most.HasMachineDataFile.makeEntry('coarseVelocity',1500,'Velocity for Coarse moves on MP285A')...
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
