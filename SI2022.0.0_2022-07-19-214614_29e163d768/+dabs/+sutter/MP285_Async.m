classdef MP285_Async < dabs.resources.devices.MotorController & dabs.resources.configuration.HasConfigPage & most.HasMachineDataFile
    % dabs.resources.devices.MotorController
    properties (SetObservable, SetAccess=protected, AbortSet)
        lastKnownPosition;      % [numeric] [1 x numAxes] sized vector with the last known position of all motors
        isMoving = false;       % [logical] Scalar that is TRUE only if a move initiated by obj.move OR obj.moveAsync has not finished
        isHomed = true;        % [logical] Scalar that is TRUE if the motor's absolute position is known relative to its home position
    end
    
    properties (SetObservable)
        hCOM = dabs.resources.SerialPort.empty(0,1);
        baudRate = 19200;
    end
    
    properties (SetAccess=protected, SetObservable,Hidden)
        ConfigPageClass = 'dabs.resources.configuration.resourcePages.SutterMP285MotorPage';
        numAxes = 3;
        autoPositionUpdate = false; % [logical] indicates if lastKnownPosition automatically updates when position of motor changes
    end
    
    methods (Static)
        function names = getDescriptiveNames()
            names = {'Motor Controller\Sutter MP285 (deprecated)' 'Sutter Instrument\Sutter MP285 (deprecated)'};
        end
    end
    
    properties (SetAccess=private, Hidden)
        hAsyncSerialQueue;
        hPositionTimer;
    end
    
    %%% Abstract property realizations (most.HasMachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'MP285';
        
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
        postResetDelay = 0.2; %Time, in seconds, to wait following a reset command before proceeding
        initialVelocity = 1300; %Start at max velocity in fine resolution mode       
        maxVelocityFine = 1300; %Max velocity in fine resolution mode
        resolutionBestRaw = 1e-6;
    end
       
    % TODO: These props may be dup-ing hardware state.
    properties (SetAccess=private,Hidden)
        fineVelocity; % cached velocity for resolutionMode = 'fine'
        coarseVelocity; % cached velocity for resolutionMode = 'coarse'        
    end
    
    properties (Hidden,SetAccess=protected)
        resolutionModeMap = getResolutionModeMap();
    end
    
    properties
        resolutionMode;
    end

    properties (Dependent)
        manualMoveMode; %Specifies if 'continuous' or 'pulse' mode is currently configured for manual moves, e.g. joystick or ROE
        inputDeviceResolutionMode; %Specifies if 'fine' or 'coarse' resolutionMode is being used for manual moves, e.g. with joystick or ROE
        displayMode; %Specifies if 'absolute' or 'relative' coordinates, with respect to linear controller itself, are currently being displayed        
        velocityRaw;
        resolutionRaw;
        maxVelocityRaw;
    end
   
    %% CONSTRUCTOR/DESTRUCTOR
    methods
        function obj = MP285_Async(name)
            obj = obj@dabs.resources.devices.MotorController(name);
            obj = obj@most.HasMachineDataFile(true);
            
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
            
            if ~success
                obj.errorMsg = 'Error loading config';
            end
        end
        
        function saveMdf(obj)
            obj.safeWriteVarToHeading('comPort', obj.hCOM);
            obj.safeWriteVarToHeading('baudRate', obj.baudRate);
        end
    end
    
    methods
        function deinit(obj)
            try
                obj.stop();
            catch ME
                most.ErrorHandler.logError(ME);
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
                assert(most.idioms.isValidObj(obj.hCOM),'No com port is defined');
                obj.hCOM.reserve(obj);
                
                obj.hAsyncSerialQueue = dabs.generic.AsyncSerialQueue(obj.hCOM.name,'BaudRate',obj.baudRate);
                obj.hAsyncSerialQueue.ErrorFcn = @obj.errorFcn;
                
                obj.hPositionTimer = timer('Name','MP285 position query timer',...
                    'ExecutionMode','fixedRate',...
                    'Period',1,...
                    'TimerFcn',@obj.positionTimerFcn);
                
                obj.errorMsg = '';
                
                obj.stop();
                %start(obj.hPositionTimer); % this causes the stage controller to crash
                
                info = obj.infoHardware();
                fprintf('MP285 Stage controller initialized: %s\n',info);
                
                % Sets the device velocity for each resolution mode so that it
                % will update appropriately when you change resolution mode.
                % Otherwise this will not change.
                resolutionModes = obj.resolutionModeMap.keys;
                for i = 1:numel(resolutionModes)
                    resMode = resolutionModes{i};
                    resModeVelocity = obj.initialVelocity * obj.resolutionModeMap(resMode);
                    obj.([resMode 'Velocity']) = resModeVelocity;
                    obj.resolutionMode = resMode;
                end
                
                obj.resolutionMode = 'coarse';
            catch ME
                obj.deinit();
                obj.errorMsg = sprintf('%s: initialization error: %s',obj.name,ME.message);
                most.ErrorHandler.logError(ME,obj.errorMsg);
            end
        end
    end
    
    methods        
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
            obj.hAsyncSerialQueue.writeReadAsync(req,native2unicode(uint8(13)),@callback_);
            
            function callback_(rsp)                
                v = typecast(rsp(1:end-1),'int32');
                v = double(v);
                v = v(:)'.*4e-2;
                
                callback(v);
            end
        end
        
        function tf = queryMoving(obj)
            % MP285: No Explicit command to query if axes are active.
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
            
            assert(~obj.isMoving,'MP285: Move is already in progress');
            
            if any(isnan(position))
                % fill in commands for position
               pos = obj.queryPosition();
               position(isnan(position)) = pos(isnan(position));
            end
            
            obj.isMoving = true;
            
            steps = position./4e-2;
            cmd = [uint8('m'), typecast(int32(steps),'uint8'), uint8(13)];%steps(:)'];
            % Move command does not expect a response...?
%             rspBytes = [];
            rspBytes = 1;
            try
%                 obj.hAsyncSerialQueue.writeRead(cmd,rspBytes);
                obj.hAsyncSerialQueue.writeReadAsync(cmd,rspBytes,@callback_);%native2unicode(uint8(13)),@callback_);
            catch ME
                obj.isMoving = false;
                rethrow(ME);
            end
            
            function callback_(rsp)
                % Async read fails because expected bytes and bytesAvail
                % dont match so this callback never executes and isMoving
                % does not get set to false causing move timeout errors
                obj.isMoving = false;
%                 'fired'
                if ~isempty(callback)
                    callback();
                end
            end
        end
        
        function moveWaitForFinish(obj, timeout_s)
            if nargin < 2 || isempty(timeout_s)
                timeout_s = obj.defaultTimeout_s;
            end
%             timeout_s = 25;
            s = tic();
            while toc(s) <= timeout_s % this while loop blocks the a sync callback?
                if obj.isMoving
%                     'polling...'
                    %If this values is too long then you can get serial
                    %fread error even when numBytes and bytes avail are the
                    %same
                    pause(0.005); % still moving. 
                else
%                     'not moving'
                    obj.queryPosition();
                    return;
                end
            end
            
            % if we reach this, the move timed out
            obj.stop(); % this guy drops a byte.
            obj.queryPosition();
            error('Motor %s: Move timed out.\n',obj.name);
        end
        
        function stop(obj) % this drops a bytes
            if most.idioms.isValidObj(obj.hAsyncSerialQueue) %&& obj.isMoving
                req = [uint8(3) uint8(13)]; % ^C
                rspBytes = 2;
                rsp = obj.hAsyncSerialQueue.writeRead(req,rspBytes);
%                 rsp
%                 if any(rsp ~= [uint8(13) uint8(13)]')
%                     assert(false);
%                 end
                
                obj.isMoving = false;
            end
        end
        
        function startHoming(obj)
            % No Op? 
            fprintf('Homing?\n');
        end
        
    end
    
    %% PROPERTY ACCESS METHODS
    methods
        function set.hCOM(obj,val)
            if isnumeric(val)
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
                obj.hCOM.registerUser(obj,'Control');
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

        % throws
        function v = infoHardware(obj)
           v = obj.zprpGetStatusProperty('infoHardware');             
        end

        function set.velocityRaw(obj,val)
            assert(isscalar(val),'The MP-285 does not support set axis-specific velocities.');
            assert(val <= obj.maxVelocityRaw,'Velocity value provided exceeds maximum permitted value (%.2g)',obj.maxVelocityRaw);
            
            pname = [obj.resolutionMode 'Velocity'];
            obj.(pname) = val;
            obj.zprpSetVelocityAndResolutionOnDevice();
        end
        
        function v = get.velocityRaw(obj)
            pname = [obj.resolutionMode 'Velocity'];
            v = obj.(pname);
        end       
       
        function v = get.resolutionRaw(obj)            
            v = obj.resolutionBestRaw .* obj.resolutionModeMap(obj.resolutionMode);
        end
            
        function v = get.maxVelocityRaw(obj)
            v = obj.maxVelocityFine * obj.resolutionModeMap(obj.resolutionMode); 
        end        

        function set.resolutionMode(obj,val)
            assert(obj.resolutionModeMap.isKey(val)); %#ok<MCSUP>
            obj.resolutionMode = val;
            obj.zprpSetVelocityAndResolutionOnDevice();
        end
        
        function v = get.manualMoveMode(obj)
           v = obj.zprpGetStatusProperty('manualMoveMode');             
        end
        
        function v = get.inputDeviceResolutionMode(obj)
           v = obj.zprpGetStatusProperty('inputDeviceResolutionMode');             
        end
        
        function v = get.displayMode(obj)
           v = obj.zprpGetStatusProperty('displayMode');             
        end
        
    end    
    
    methods (Access=private)
        function val = zprpGetStatusProperty(obj,statusProp)
            status = obj.getStatus();
            val = status.(statusProp);
        end
        
        function zprpSetVelocityAndResolutionOnDevice(obj)
            val = obj.([obj.resolutionMode 'Velocity']);
            
            val = uint16(val);
            switch obj.resolutionMode
                case 'coarse'
                    val = bitset(val,16,0); % set bit 16 to 0
                case 'fine'
                    val = bitset(val,16,1); % set bit 16 to 1
                otherwise
                    error('Unknown resolution mode: %s',obj.resolutionMode)
            end
            
            req = [uint8('V') typecast(uint16(val), 'uint8') uint8(13) ];
            obj.hAsyncSerialQueue.writeRead(req,1);
        end

    end
        
    %% ABSTRACT METHOD IMPLEMENTATIONS
    methods %(Access=protected,Hidden)
        
        function resetHook(obj)
            req = [uint8('r') uint8(13)];
            obj.hAsyncSerialQueue.writeRead(req,[]);
            pause(2);
        end
        
        % Home?
%         function zeroHardHook(obj,coords)
%             assert(all(coords),'Cannot zeroHard individual dimensions.');
%             obj.hRS232.sendCommandSimpleReply('o');
%         end
        
    end
    
    %% HIDDEN METHODS
    methods (Hidden)
        
        % throws
        function statusStruct = getStatus(obj,verbose)
            %function getStatus(obj,verbose)
            %   verbose: Indicates if status information should be displayed to command line. If omitted/empty, false is assumed
            %   statusStruct: Structure containing fields indicating various aspects of the device status...
            %           invertCoordinates: Array in format appropriate for invertCoordinates property
            %           displayMode: One of {'absolute' 'relative'} indicating which display mode controller is in
            %           inputDeviceResolutionMode: One of {'fine','coarse'} indicating resolution mode of input device, e.g. ROE or joystick.
            %           resolutionMode: One of {'fine','coarse'} indicating resolution mode of device with respect to its computer interface -- i.e. the 'resolutionMode' of this class
            %
            
            if nargin < 2 || isempty(verbose)
                verbose = false;
            end
            req = [uint8('s') uint8(13)];
            rspBytes = 33;
            v = obj.hAsyncSerialQueue.writeRead(req,native2unicode(uint8(13)));
            v = v(1:end-1);
            status = double(v);
            
            %Parsing pertinent values based on status return data table in MP-285 manual
            statusStruct.invertCoordinates = [status(2) status(3) status(4)] - [0 2 4];
            statusStruct.infoHardware = word2str(status(31:32));
            
            flags = dec2bin(uint8(status(1)),8);
            flags2 = dec2bin(uint8(status(16)),8);
            
            if str2double(flags(2))
                statusStruct.manualMoveMode = 'continuous';
            else
                statusStruct.manualMoveMode = 'pulse';
            end
            
            if str2double(flags(3))
                statusStruct.displayMode = 'relative'; %NOTE: This is reversed in the documentation (rev 3.13)
            else
                statusStruct.displayMode = 'absolute'; %NOTE: This is reversed in the documentation (rev 3.13)
            end
            
            if str2double(flags2(6))
                statusStruct.inputDeviceResolutionMode = 'fine';
            else
                statusStruct.inputDeviceResolutionMode = 'coarse';
            end
            
            speedval = 2^8*status(30) + status(29);
            if speedval >= 2^15
                statusStruct.resolutionMode = 'fine';
                speedval = speedval - 2^15;
            else
                statusStruct.resolutionMode = 'coarse';
            end
            statusStruct.resolutionModeVelocity = speedval;
            
            if verbose
                disp(['FLAGS: ' num2str(dec2bin(status(1)))]);
                disp(['UDIRX: ' num2str(status(2))]);
                disp(['UDIRY: ' num2str(status(3))]);
                disp(['UDIRZ: ' num2str(status(4))]);
                
                disp(['ROE_VARI: ' word2str(status(5:6))]);
                disp(['UOFFSET: ' word2str(status(7:8))]);
                disp(['URANGE: ' word2str(status(9:10))]);
                disp(['PULSE: ' word2str(status(11:12))]);
                disp(['USPEED: ' word2str(status(13:14))]);
                
                disp(['INDEVICE: ' num2str(status(15))]);
                disp(['FLAGS_2: ' num2str(dec2bin(status(16)))]);
                
                disp(['JUMPSPD: ' word2str(status(17:18))]);
                disp(['HIGHSPD: ' word2str(status(19:20))]);
                disp(['DEAD: ' word2str(status(21:22))]);
                disp(['WATCH_DOG: ' word2str(status(23:24))]);
                disp(['STEP_DIV: ' word2str(status(25:26))]);
                disp(['STEP_MUL: ' word2str(status(27:28))]);
                
                %I'm not sure what happens to byte #28
                
                %Handle the Remote Speed value. Unlike all the rest...it's big-endian.
                speedval = 2^8*status(30) + status(29);
                if strcmpi(statusStruct.resolutionMode,'coarse')
                    disp('XSPEED RES: COARSE');
                else
                    disp('XSPEED RES: FINE');
                end
                disp(['XSPEED: ' num2str(speedval)]);
                
                disp(['VERSION: ' word2str(status(31:32))]);
            end            
            
            function outstr = word2str(bytePair)
                val = 2^8*bytePair(2) + bytePair(1); %value comes in little-endian
                outstr = num2str(val);
            end
        end
    end
    
end

function resolutionModeMap = getResolutionModeMap()
    %Implements a static property containing Map of resolution multipliers to apply for each of the named resolutionModes
    resolutionModeMap = containers.Map();
    resolutionModeMap('fine') = 1;
    resolutionModeMap('coarse') = 5;
end

function s = defaultMdfSection()
    s = [...
            most.HasMachineDataFile.makeEntry('comPort','','Integer identifying COM port for controller')...
            most.HasMachineDataFile.makeEntry('baudRate',19200,'Baud rate setting on MP285')...
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
