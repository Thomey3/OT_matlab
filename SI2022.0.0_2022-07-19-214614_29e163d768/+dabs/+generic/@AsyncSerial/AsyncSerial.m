classdef AsyncSerial < handle
    %ASYNCSERIAL Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = immutable)
        Port
        BaudRate
        DataBits
        Parity
        StopBits
    end
    
    properties
        BytesAvailableFcn = [];
        ErrorFcn = [];
    end
    
    properties (Dependent)
        BytesAvailable
        BytesToOutput
        ValuesSent
        ValuesReceived
        InputBufferSize
        OutputBufferSize
    end
    
    properties (GetAccess = private, SetAccess = private)
        ParityNumber
        hAsyncSerial = uint64(0);
    end
    
    methods
        function obj = AsyncSerial(Port, varargin)
            validateattributes(Port,{'char'},{'vector'});
            
            p = inputParser;
            addRequired(p,'Port',@(x)ischar(x) && isvector(x));
            addOptional(p,'BaudRate', 9600,@(x) isnumeric(x) && isscalar(x) && (x > 0) && mod(x,1)==0);
            addOptional(p,'DataBits',    8,@(x)ismember(x,5:8));
            addOptional(p,'Parity', 'none',@(x)any(strcmpi(x,{'','none','odd','even','mark','space'})));
            addOptional(p,'StopBits',    1,@(x)ismember(x,[1,1.5,2]));
            
            parse(p,Port,varargin{:});
            
            obj.Port     = p.Results.Port;
            obj.BaudRate = p.Results.BaudRate;
            obj.DataBits = p.Results.DataBits;
            obj.Parity   = p.Results.Parity;
            obj.StopBits = p.Results.StopBits;            
            
            obj.open();
        end
        
        function delete(obj)
            obj.close();
        end
    end
    
    methods
        function fwrite(obj,data)
            %str = strrep(char(data(:)'),char(13),char(9166));
            %fprintf('Write data: %s\t(%s)\n',dec2hex(data'),str);

            AsyncSerialMex('write',obj.hAsyncSerial,data);
        end
        
        function data = fread(obj,numBytes,timeout_s)
            if nargin < 2 || isempty(numBytes)
                numBytes = Inf;
            end
            
            if nargin < 3 || isempty(timeout_s)
                timeout_s = 1;
            end
            
            data = AsyncSerialMex('read',obj.hAsyncSerial,numBytes,timeout_s);
            
            %str = strrep(char(data(:)'),char(13),char(9166));
            %fprintf('Read data: %s\t(%s)\n',dec2hex(data'),str);
        end
        
        function [nBytes,data] = flushInputBuffer(obj)
            nBytes = AsyncSerialMex('getNumBytesAvailable',obj.hAsyncSerial);
            
            if nBytes > 0
                data = obj.fread(Inf);
            else
                data = zeros(0,1,'uint8');
            end
        end
        
        function err = getError(obj)
            err = AsyncSerialMex('getError',obj.hAsyncSerial);
        end
    end
    
    methods (Hidden)
        function dataAvailableCallback(obj,varargin)
            if ~isempty(obj.BytesAvailableFcn)
                try
                    obj.BytesAvailableFcn(obj,[]);
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
            end
        end
        
        function errorCallback(obj,varargin)
            if ~isempty(obj.ErrorFcn)
                try
                    obj.ErrorFcn(obj,[]);
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
            end
        end
    end
    
    methods (Access = private)
        function open(obj)
            % Port syntax:
            % https://support.microsoft.com/en-ie/help/115831/howto-specify-serial-ports-larger-than-com9#appliesto
            if obj.Port > 9
                port_ = sprintf('\\\\.\\%s',obj.Port);
            else
                port_ = obj.Port;
            end
            
            obj.hAsyncSerial = AsyncSerialMex('openPort',port_,obj.BaudRate,obj.DataBits,obj.ParityNumber,obj.StopBits);
            AsyncSerialMex('setDataCallback',obj.hAsyncSerial,@obj.dataAvailableCallback);
            AsyncSerialMex('setErrorCallback',obj.hAsyncSerial,@obj.errorCallback);
        end
        
        function close(obj)
            if (obj.hAsyncSerial~=0)
                AsyncSerialMex('closePort',obj.hAsyncSerial);
                obj.hAsyncSerial = uint64(0);
            end
        end
    end
    
    methods
        function val = get.BytesAvailable(obj)
            val = AsyncSerialMex('getNumBytesAvailable',obj.hAsyncSerial);
        end
        
        function val = get.BytesToOutput(obj)
            val = AsyncSerialMex('getBytesToOutput',obj.hAsyncSerial);
        end
        
        function val = get.ValuesSent(obj)
            val = AsyncSerialMex('getValuesSent',obj.hAsyncSerial);
        end
        
        function val = get.ValuesReceived(obj)
            val = AsyncSerialMex('getValuesReceived',obj.hAsyncSerial);
        end
        
        function val = get.InputBufferSize(obj)
            val = AsyncSerialMex('getInputBufferSize',obj.hAsyncSerial);
        end
        
        function val = get.OutputBufferSize(obj)
            val = AsyncSerialMex('getOutputBufferSize',obj.hAsyncSerial);
        end
        
        function val = get.ParityNumber(obj)
            % https://docs.microsoft.com/en-us/windows/win32/api/winbase/ns-winbase-dcb
            switch lower(obj.Parity)
                case {'','none'}
                    val = 0;
                case 'odd'
                    val = 1;
                case 'even'
                    val = 2;
                case 'mark'
                    val = 3;
                case 'space'
                    val = 4;
                otherwise
                    error('Unknown parity');
            end
        end
        
        function set.BytesAvailableFcn(obj,val)
            if isempty(val)
                val = function_handle.empty(0,1);
            else
                validateattributes(val,{'function_handle'},{'scalar'});
            end
            
            obj.BytesAvailableFcn = val;
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
