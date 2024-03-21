classdef AsyncSerialQueue < handle    
    properties (SetAccess = private)
        isCallbackPending = false;
        isCallbackProcessing = false;
        isSyncCallInProgress = false;
        pendingCallback = [];
        pendingRspSize = 0;
        pendingRequest = [];
        queue = {};
        rsp = zeros(0,1,'uint8');
    end
    
    properties (Dependent)
        busy
    end
    
    properties
        maxQueueLength = 10;
        ErrorFcn = function_handle.empty(1,0);
        writeDelay_sec = 0;
    end
    
    properties (SetAccess = private, Hidden)
        hAsyncSerial;
        hCallbackTimer;
    end
    
    methods
        function obj = AsyncSerialQueue(varargin)
            try
                obj.hCallbackTimer = timer('Name','AsyncSerialQueueTimer');
                obj.hCallbackTimer.StartDelay = 0;
                obj.hCallbackTimer.ExecutionMode = 'singleShot';
                obj.hCallbackTimer.BusyMode = 'queue';
                obj.hCallbackTimer.TimerFcn = @obj.bytesAvailableCb;
                
                obj.hAsyncSerial = dabs.generic.AsyncSerial(varargin{:});
                obj.hAsyncSerial.BytesAvailableFcn = @obj.startCallbackTimer;
                obj.hAsyncSerial.ErrorFcn = @obj.errorCb;
            catch ME
                obj.delete();
                rethrow(ME);
            end
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hAsyncSerial);
            most.idioms.safeDeleteObj(obj.hCallbackTimer);
        end
    end
    
    %% Public methods
    methods
        function rsp = writeRead(obj,data,numRspBytes, timeout)
            if nargin < 4 || isempty(timeout)
                timeout = 5;
            end
            
            assert(isa(data,'uint8'),'Data must be of type uint8.');
            assert(isvector(data),'Data must be a vector');
            
            if isempty(numRspBytes)
                numRspBytes = 0;
            elseif isnumeric(numRspBytes)
                assert(isnumeric(numRspBytes)&&isscalar(numRspBytes)&&numRspBytes>=0);
            else
                assert(ischar(numRspBytes)&&isscalar(numRspBytes));
            end
            
            assert(~obj.isSyncCallInProgress,'another synchronous call is in progress');
            
            obj.isSyncCallInProgress = true;
            try
                % process outstanding callback (if any) synchronously
                
                timeout_s = 1;
                s = tic();
                while obj.isCallbackPending
                    force = true;
                    obj.processCallback(force);
                    assert(toc(s)<timeout_s,'Timed out while waiting for async callback');
                    pause(0.1);
                end
                
                assert(~obj.isCallbackPending,'A callback is currently pending');
                
                obj.flushInputBuffer();
                
                obj.hAsyncSerial.fwrite(data);
                
                rsp = uint8.empty(0,1);
                
                if ischar(numRspBytes)
                    terminationCharacter = uint8(numRspBytes);
                    s = tic();
                    while isempty(rsp) || ~isequal(rsp(end),terminationCharacter)
                        rsp(end+1) = obj.hAsyncSerial.fread(1,timeout);
                        assert(toc(s)<timeout,'AsyncSerialQueue: Timed out while waiting for response');
                    end
                else
                    rsp = obj.hAsyncSerial.fread(numRspBytes,timeout);
                end
                
                cleanup();
            catch ME
               cleanup();
               rethrow(ME);
            end
            
            function cleanup()
                obj.isSyncCallInProgress = false;                
                obj.checkQueue();
            end
        end
        
        function writeReadAsync(obj,data,numRspBytes,callback)
            assert(isa(data,'uint8'),'Data must be of type uint8.');
            assert(isvector(data),'Data must be a vector');
            if isnumeric(numRspBytes)
                assert(isnumeric(numRspBytes)&&isscalar(numRspBytes)&&numRspBytes>=0);
            else
                assert(ischar(numRspBytes)&&isscalar(numRspBytes));
            end
            assert(isa(callback,'function_handle'));
            
            obj.enqueue(data,numRspBytes,callback);
            obj.checkQueue();
        end
    end
    
    %% Internal methods
    methods (Access = protected)
        function startCallbackTimer(obj,~,~)
            % the bytesAvailableCb should not be interrupted. to ensure
            % that we let a timer call the function (timer callbacks are
            % not interruptible)
            start(obj.hCallbackTimer);
        end
        
        function bytesAvailableCb(obj,~,~)
            obj.processCallbackSafe();
            
            try
                obj.checkQueue();
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
        end
        
        function errorCb(obj,src,evt)
            if ~isempty(obj.ErrorFcn)
                obj.ErrorFcn(obj,evt);
            end
        end
    end
    
    methods        
        function processCallbackSafe(obj)
            if ~obj.isCallbackProcessing
                obj.processCallback();
            end
        end
        
        function processCallback(obj,force)
            if nargin<2 || isempty(force)
                force = false;
            end
            
            if ~force && obj.isSyncCallInProgress
                return
            end
            
            if ~obj.isCallbackPending
               return
            end
            
            try
                assert(~obj.isCallbackProcessing);            
            catch ME
                keyboard;
                ME.rethrow();
            end
            
            obj.isCallbackProcessing = true;
            
            readdata();
            [tfComplete,data] = checkResponseComplete();
            if tfComplete
                executeCallback(data);
            else
                obj.isCallbackProcessing = false;
            end
            
            %%% Nested functions
            function readdata()
                timeout_s = 0;
                newData = obj.hAsyncSerial.fread(obj.hAsyncSerial.BytesAvailable,timeout_s);
                obj.rsp = vertcat(obj.rsp,newData);
            end
            
            function [tfComplete,data] = checkResponseComplete()
                tfComplete = false;
                data = [];
                
                if ischar(obj.pendingRspSize)
                    terminationCharacter = obj.pendingRspSize;
                    characterLocation = find(terminationCharacter==obj.rsp,1,'first');
                    if ~isempty(characterLocation)
                        tfComplete = true;
                        data = obj.rsp(1:characterLocation);
                        obj.rsp(1:characterLocation) = [];
                        obj.flushInputBuffer();
                    end
                else
                    if numel(obj.rsp) >= obj.pendingRspSize
                        tfComplete = true;
                        data = obj.rsp(1:obj.pendingRspSize);
                        obj.rsp(1:obj.pendingRspSize) = [];
                        obj.flushInputBuffer();
                    end
                end
            end
            
            function executeCallback(data)
                callback = obj.pendingCallback;
                
                obj.pendingRequest = [];
                obj.pendingCallback = [];
                obj.pendingRspSize = 0;
                obj.isCallbackPending = false;
                
                obj.isCallbackProcessing = false;
                
                try
                    callback(data(:)');
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
            end
        end
        
        function flushInputBuffer(obj, tfSilent)
            if nargin < 2 || isempty(tfSilent)
               tfSilent = false; 
            end
            
            [nBytes,data] = obj.hAsyncSerial.flushInputBuffer();
            
            obj.rsp = [obj.rsp; data];
            
            if ~tfSilent && ~isempty(obj.rsp)
                most.idioms.warn('Serial communication dropped %d bytes: %s',nBytes,mat2str(obj.rsp'));
            end
            
            obj.rsp = zeros(0,1,'uint8');
        end
        
        function enqueue(obj,data,numRspBytes,callback)
            assert(numel(obj.queue) < obj.maxQueueLength,'Reached maximum queue length of %d.',obj.maxQueueLength);
            obj.queue{end+1} = {data,numRspBytes,callback};
        end
        
        function [data,numRspBytes,callback] = dequeue(obj)
            packet = obj.queue{1};
            obj.queue(1) = [];
            
            data = packet{1};
            numRspBytes = packet{2};
            callback = packet{3};
        end
        
        function checkQueue(obj)
            if ~obj.isCallbackPending && ~obj.isSyncCallInProgress && ~isempty(obj.queue)
                obj.isCallbackPending = true;
                [data,numRspBytes,callback] = obj.dequeue();
                obj.flushInputBuffer();
                obj.pendingRspSize = numRspBytes;
                obj.pendingCallback = callback;
                obj.pendingRequest = data;                
                obj.hAsyncSerial.fwrite(data);
            end
            
            obj.processCallbackSafe();
        end
    end
    
    methods
        function set.maxQueueLength(obj,val)
            validateattributes(val,{'numeric'},{'scalar','integer','positive'});
            obj.maxQueueLength = val;
        end
        
        function set.ErrorFcn(obj,val)
            if isempty(val)
                val = function_handle.empty(1,0);
            else
                validateattributes(val,{'function_handle'},{'scalar'});
            end
            
            obj.ErrorFcn = val;
        end
        
        function v = get.busy(obj)            
            v = obj.isCallbackPending ...
             || obj.isSyncCallInProgress;
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
