classdef MotionController < dabs.resources.devices.MotorController & dabs.resources.configuration.HasConfigPage & most.HasMachineDataFile
    properties (Abstract, Constant)
        stepsPerMicron
        baudRate
    end
    
    properties (SetAccess=protected,Hidden)
        ConfigPageClass = 'dabs.resources.configuration.resourcePages.SerialMotorPage';
    end
 
    %%% Abstract property realizations (dabs.resources.devices.MotorController)
    properties (SetObservable, SetAccess=protected, AbortSet)
        lastKnownPosition;      % [numeric] [1 x numAxes] sized vector with the last known position of all motors
        isMoving = false;       % [logical] Scalar that is TRUE only if a move initiated by obj.move OR obj.moveAsync has not finished
        isHomed = true;        % [logical] Scalar that is TRUE if the motor's absolute position is known relative to its home position
    end
    
    properties (SetObservable)
        hCOM = dabs.resources.Resource.empty();
    end
    
    properties (SetAccess=protected, SetObservable)
        numAxes = 3;
        autoPositionUpdate = true; % [logical] indicates if lastKnownPosition automatically updates when position of motor changes
    end
        
    properties (SetAccess=private, Hidden)
        hAsyncSerialQueue;
        hPositionTimer;
        hMoveCompletionTimer;
        lastConnectionClosedTime = uint64(0);
    end
    
    %%% Abstract property realizations (most.HasMachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'Scientifica LSC2';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp; %#ok<MCCPI>
        mdfPropPrefix; %#ok<MCCPI>
        
        mdfDefault = defaultMdfSection();
    end
    
    %% CLASS-SPECIFIC PROPERTIES    
    properties (SetAccess=protected,Dependent)
        infoHardware;
    end
    
    properties (Dependent,Hidden)
        positionUnitsScaleFactor; %These are the UUX/Y/Z properties. %TODO: Determine if there is any reason these should be user-settable to be anything other than their default values (save for inverting). At moment, none can be determined. Perhaps related to steps.
        limitReached;
    end
        
    properties (Hidden)
        defaultPositionUnitsScaleFactor; %Varies based on stage type. This effectively specifies the resolution of that stage type.
    end   

    
    properties(Hidden, SetAccess = protected)
        axisMap = {'X', 'Y', 'Z'};
    end
   

    %% CONSTRUCTOR/DESTRUCTOR
    methods
        function obj = MotionController(name)
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
    
    %%% I don't know that the # of response bytes is constant...
    %% DEVICE PROPERTY ACCESS METHODS 
    methods
        function val = get.infoHardware(obj)
            req = uint8(['DATE' uint8(13)]);
            rspBytes = 44;
            rsp = obj.hAsyncSerialQueue.writeRead(req,rspBytes);
            val = deblank(native2unicode(rsp'));
        end

%         function val = get.positionUnitsScaleFactor(obj)
%             val = zeros(1,obj.numAxes); 
%             for i = 1:obj.numAxes 
%                 req = uint8([sprintf('UU%s', obj.axisMap{i}) uint8(13)]);
%                 rspBytes = 6;
%                 rsp = obj.hAsyncSerialQueue.writeRead(req,rspBytes);
%                 val(i) = str2double(native2unicode(rsp'));
%             end
%         end
        
        % throws (hware). If this happens, the state of the UU (User Units)
        % vars is indeterminate.
%         function set.positionUnitsScaleFactor(obj,val)
%             assert(isnumeric(val) && (isscalar(val) || numel(val)==obj.numAxes)); 
%             if isscalar(val)
%                 val = repmat(val,1,obj.numAxes);
%             end
%             for i = 1:obj.numAxes
%                 req = uint8([sprintf('UU%s %s', obj.axisMap{i}, num2str(val(i))) uint8(13)]);
%                 rspBytes = 2;
%                 obj.hAsyncSerialQueue.writeRead(req,rspBytes);
%             end
%         end
        
        function val = get.limitReached(obj)
            %TODO(5AM): Improve decoding of 6 bit (2 byte) data 
            req = uint8(['LIMITS' uint8(13)]);
            rspBytes = 2;
            rsp = obj.hAsyncSerialQueue.writeRead(req,rspBytes);
            resp = uint8(hex2dec(deblank(native2unicode(rsp'))));
            val = zeros(1,obj.numAxes);
            for i = 1:obj.numAxes
                val(i) = (bitget(resp,2*i-1) || bitget(resp,2*i));
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
                val.registerUser(obj,'COM Port');
            end
        end
    end   
    
    %% ABSTRACT METHOD IMPLEMENTATIONS
    methods        
        function deinit(obj)
            try
                obj.stop();
            catch
            end
            
            most.idioms.safeDeleteObj(obj.hPositionTimer);
            obj.hPositionTimer = [];
            
            most.idioms.safeDeleteObj(obj.hMoveCompletionTimer);
            obj.hMoveCompletionTimer = [];
            
            if most.idioms.isValidObj(obj.hAsyncSerialQueue)
                obj.lastConnectionClosedTime = tic();
                most.idioms.safeDeleteObj(obj.hAsyncSerialQueue);
            end
            obj.hAsyncSerialQueue = [];
            
            obj.hCOM.unreserve(obj);
            
            obj.errorMsg = 'uninitialized';
        end
        
        function reinit(obj)
            obj.deinit();
            
            try
                assert(most.idioms.isValidObj(obj.hCOM),'No serial port is specified');
                obj.hCOM.reserve(obj);
                
                if toc(obj.lastConnectionClosedTime)<0.5
                    % the motion controller does not appreciate closing and
                    % opening connections within a short time period
                    pause(0.5);
                end
                
                obj.hAsyncSerialQueue = dabs.generic.AsyncSerialQueue(obj.hCOM.name,'BaudRate',obj.baudRate);
                obj.hAsyncSerialQueue.ErrorFcn = @obj.errorFcn;
                
                obj.hPositionTimer = timer('Name','Scientifica LSC position query timer',...
                    'ExecutionMode','fixedRate',...
                    'Period',0.3,...
                    'TimerFcn',@obj.positionTimerFcn);
                
                obj.hMoveCompletionTimer = timer('Name','Scientifica moving polling timer',...
                    'ExecutionMode','fixedSpacing','Period',0.1);
                
                obj.errorMsg = '';
                
                obj.stop();                
                start(obj.hPositionTimer);
            catch ME
                obj.deinit();
                obj.errorMsg = sprintf('%s: initialization error: %s',obj.name,ME.message);
                most.ErrorHandler.logError(ME,obj.errorMsg);
            end
        end
    end
    
    methods        
        function tf = queryMoving(obj)
            req = uint8(['S' uint8(13)]);
            rspBytes = 2;
            rsp = obj.hAsyncSerialQueue.writeRead(req,rspBytes);
            tf = str2double(deblank(native2unicode(rsp')));
            tf = logical(tf);
            obj.isMoving = tf;
        end
        
        function v = queryPosition(obj)
            req = uint8(['POS' uint8(13)]);
            rspBytes = char(13);
            rsp = obj.hAsyncSerialQueue.writeRead(req,rspBytes);
            v = str2num(deblank(native2unicode(rsp))) / obj.stepsPerMicron;
            
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
            
            assert(~obj.queryMoving(),'Scientifica LSC: Move is already in progress');
            
            if any(isnan(position))
                % fill in commands for position
               pos = obj.queryPosition();
               position(isnan(position)) = pos(isnan(position));
            end
            
            posSteps = round(position * obj.stepsPerMicron);
            posStepsStr = arrayfun(@(p)num2str(p),posSteps,'UniformOutput',false);
            posStepsStr = strjoin(posStepsStr,' ');
            
            cmd = uint8( ['ABS ' posStepsStr char(13)] );
            
            rspBytes = 2;
            try
                obj.isMoving = true;
                rsp = obj.hAsyncSerialQueue.writeRead(cmd,rspBytes);
                obj.startMoveCompletionTimer(callback);
            catch ME
                obj.stop();
                rethrow(ME);
            end
        end
        
        function moveWaitForFinish(obj,timeout_s)
            if nargin < 2 || isempty(timeout_s)
                timeout_s = obj.defaultTimeout_s;
            end
            
            pause(0.1); % ensure stage has time to start move
            
            s = tic();
            while toc(s) <= timeout_s                
                if obj.queryMoving()
                    obj.queryPosition();
                    pause(0.1);
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
                req = uint8(['STOP' uint8(13)]);
                rspBytes = 2;
                obj.hAsyncSerialQueue.writeRead(req,rspBytes);
                obj.isMoving = false;
            end
        end
        
        function startHoming(obj)
            % No Op
        end
    end
    
    methods (Hidden)
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
            if nargin < 2
               callback = []; 
            end
            
            req = uint8(['POS' uint8(13)]);% uint8(13)];
            rspBytes = char(13);
            obj.hAsyncSerialQueue.writeReadAsync(req,rspBytes,@callback_);
            
            function callback_(rsp) 
                v = str2num(deblank(native2unicode((rsp)))) / obj.stepsPerMicron;
                if ~isempty(callback)
                    callback(v);
                end
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
