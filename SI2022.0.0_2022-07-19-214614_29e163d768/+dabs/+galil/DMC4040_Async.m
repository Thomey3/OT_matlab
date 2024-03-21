classdef DMC4040_Async < dabs.resources.devices.MotorController & dabs.resources.configuration.HasConfigPage & most.HasMachineDataFile
    properties (SetAccess=protected,Hidden)
        ConfigPageClass = 'dabs.resources.configuration.resourcePages.DMC4040page';
    end
    
    methods (Static,Hidden)
        function names = getDescriptiveNames()
            names = {'Motor Controller\Galil DMC4040' 'Galil\Galil DMC4040'};
        end
    end
    
    properties (SetObservable)
        hCOM = dabs.resources.Resource.empty();
        initCmd = [];
        deinitCmd = [];
        AVAILABLE_BAUD_RATES = [9600 19200 38400 115200];
        baudRate = 115200;
    end
    
    properties (SetObservable, SetAccess=protected, AbortSet)
        lastKnownPosition = 0;                  % [numeric] [1 x numAxes] sized vector with the last known position of all motors
        isMoving = false;                       % [logical] Scalar that is TRUE only if a move initiated by obj.move OR obj.moveAsync has not finished
        isHomed = true;                         % [logical] Scalar that is TRUE if the motor's absolute position is known relative to its home position
    end
    
    properties (SetAccess=protected, SetObservable)
        numAxes = 3;                            % [numeric] Scalar integer describing the number of axes of the MotorController
        autoPositionUpdate = true;              % [logical] indicates if lastKnownPosition automatically updates when position of motor changes
    end
    
     %%% Abstract property realizations (most.HasMachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'DMC 4040';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp; %#ok<MCCPI>
        mdfPropPrefix; %#ok<MCCPI>
        
        mdfDefault = defaultMdfSection();
    end
    
    properties (SetAccess=private, Hidden)
        hAsyncSerialQueue;
        hPositionTimer;
        hMoveCompletionTimer;
    end
    
    %% CLASS-SPECIFIC PROPERTIES       
    properties (SetAccess = private, SetObservable)
        activeAxes;
        initted = false;
    end
    
    methods
        function obj = DMC4040_Async(name)
            obj@dabs.resources.devices.MotorController(name);
            obj@most.HasMachineDataFile(true);
            
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
            success = success & obj.safeSetPropFromMdf('initCmd', 'initCmd');
            success = success & obj.safeSetPropFromMdf('deinitCmd', 'deinitCmd');
            
            if ~success
                obj.errorMsg = 'Error loading config';
            end
        end
        
        function saveMdf(obj)
            obj.safeWriteVarToHeading('comPort', obj.hCOM);
            obj.safeWriteVarToHeading('baudRate', obj.baudRate);
            obj.safeWriteVarToHeading('initCmd', obj.initCmd);
            obj.safeWriteVarToHeading('deinitCmd', obj.deinitCmd);
        end
    end
    
    methods
        function deinit(obj)
            try
                obj.stop();
            catch ME
                most.ErrorHandler.logError(ME);
            end
            
            most.idioms.safeDeleteObj(obj.hMoveCompletionTimer);
            obj.hMoveCompletionTimer = [];
            most.idioms.safeDeleteObj(obj.hPositionTimer);
            obj.hPositionTimer = [];
            
            if obj.initted && ~isempty(obj.deinitCmd)
                obj.hAsyncSerialQueue.writeRead([uint8(obj.deinitCmd) uint8(13) uint8(10)], []);
                pause(1);
                obj.hAsyncSerialQueue.flushInputBuffer();
            end
            obj.initted = false;
            
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
                
                obj.hPositionTimer = timer('Name','DMC4040 position query timer',...
                    'ExecutionMode','fixedRate',...
                    'Period',0.3,...
                    'TimerFcn',@obj.positionTimerFcn);
                
                obj.hMoveCompletionTimer = timer('Name','DMC4040 is moving polling timer',...
                    'ExecutionMode','fixedSpacing','Period',0.1);
                
                obj.errorMsg = '';
                
                if ~isempty(obj.initCmd)
                    obj.hAsyncSerialQueue.writeRead([uint8(obj.initCmd) uint8(13) uint8(10)], []);
                    pause(1);
                    obj.hAsyncSerialQueue.flushInputBuffer();
                    obj.hAsyncSerialQueue.writeRead([uint8('EO 0') uint8(13) uint8(10)], []);
                    pause(1);
                    obj.hAsyncSerialQueue.flushInputBuffer();
                end
                
                obj.initted = true;
                
                obj.stop();
                if obj.autoPositionUpdate
                    start(obj.hPositionTimer);
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
            cmd = [uint8('MG _BGA, _BGB, _BGC') uint8(13) uint8(10)];
            rspByte = ':';
            
            rsp = obj.hAsyncSerialQueue.writeRead(cmd, rspByte);
            
            mv = native2unicode(rsp(1:end-1));
            
            tf = any(str2num(mv));
            
            obj.isMoving = tf;
        end
        
        function position = queryPosition(obj)
            cmd = [uint8('MG _TDA, _TDB, _TDC') uint8(13) uint8(10)];
            rspByte = ':';
            rsp = obj.hAsyncSerialQueue.writeRead(cmd, rspByte);
            position = str2num(native2unicode(rsp(1:end-1)));
            obj.lastKnownPosition = position;
        end
        
        % function queryHomed
        
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
            
            obj.startMove(position);
            
            obj.startMoveCompletionTimer(callback);
        end
        
        function moveWaitForFinish(obj, timeout_s)
            if nargin < 2 || isempty(timeout_s)
                timeout_s = obj.defaultTimeout_s;
            end
            
            pause(0.1); % ensure stage has time to start move
            
            s = tic();
            while toc(s) <= timeout_s
                if obj.queryMoving()
                    pause(0.1); % still moving
                    obj.queryPosition();
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
            cmd = [uint8('ST') uint8(13) uint8(10)];
            rspByte = ':';
            rsp = obj.hAsyncSerialQueue.writeRead(cmd, rspByte);
            
            % Check the response should be either : or ? dont know if there
            % is a another byte like LF or CR.
        end
        
        function startHoming(obj)
            %No Op
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
        
        function v = getPositionAsync(obj,callback)
            cmd = [uint8('MG _TDA, _TDB, _TDC') uint8(13) uint8(10)];
            rspByte = ':';
            
            obj.hAsyncSerialQueue.writeReadAsync(cmd, rspByte, @callback_);
            
            function callback_(rsp)
                v = str2num(native2unicode(rsp(1:end-1)));
                callback(v);
            end
        end
        
        function startMove(obj,position)
            assert(~obj.queryMoving(),'A move is already in progress')
            obj.isMoving = true;
            
            cmd = [uint8('AM ABC;') uint8(sprintf('PAA= %f;PAB= %f;PAC= %f;', position)) uint8('BG ABC;') uint8(13) uint8(10)];
            rspByte = 6;%':';
            
            obj.hAsyncSerialQueue.writeRead(cmd,rspByte);
        end
        
        function startMoveCompletionTimer(obj,callback)
            stop(obj.hMoveCompletionTimer);
            obj.hMoveCompletionTimer.TimerFcn = @poll;
            obj.hMoveCompletionTimer.StartDelay = 0.1; % give stage sufficient time to start moving
            start(obj.hMoveCompletionTimer);
            
            function poll(varargin)
                try
                    if ~obj.hAsyncSerialQueue.busy
                        obj.queryMoving();
                    end
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
                
                if ~obj.isMoving
                    stop(obj.hMoveCompletionTimer);
                    
                    if ~isempty(callback)
                        callback();
                    end
                end
            end
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
        
        function set.baudRate(obj,val)
            validateattributes(val,{'numeric'},{'scalar','positive','integer','nonnan','finite'});
            assert(ismember(val,obj.AVAILABLE_BAUD_RATES),'Invalid baudrate. Allowed values are: %s',mat2str(obj.AVAILABLE_BAUD_RATES));
            
            if val ~= obj.baudRate
                obj.deinit();
                obj.baudRate = val;
            end
        end
        
    end
end

function s = defaultMdfSection()
    s = [...
        most.HasMachineDataFile.makeEntry('comPort','','Serial port the stage is connected to (e.g. ''COM3'')')...
        most.HasMachineDataFile.makeEntry('baudRate',115200,'Baudrate for serial communication')...
        most.HasMachineDataFile.makeEntry('initCmd','','Initialization Command for Galil')...
        most.HasMachineDataFile.makeEntry('deinitCmd','','Deinitialization Command for Galil')...
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
