classdef Client < handle
    %% User properties / events
    properties (SetAccess = immutable)
        address;
        port;
    end
    
    properties (Dependent)
        TCP_NODELAY;
    end
    
    %% Internal properties
    properties (Access = private)
        hWinSockClient
    end
    
    %% LifeCycle
    methods
        function obj = Client(address,port)
            if nargin < 1 || isempty(address)
                address = '127.0.0.1';
            end
            
            if nargin < 2 || isempty(port)
                port = 5555;
            end
            
            validateattributes(address,{'char'},{'row'});
            validateattributes(port,{'numeric'},{'positive','integer','scalar'});
            obj.address = address;
            obj.port = port;
            
            port_ = sprintf('%d',port);            
            obj.hWinSockClient = WinSockClient('open',address,port_);
        end
        
        function delete(obj)
            WinSockClient('close',obj.hWinSockClient);
            obj.hWinSockClient = [];
        end
    end
    
    %% User methods
    methods  
        function send(obj,buffer,nBytes)
            if nargin < 3 || isempty(nBytes)
                nBytes = uint64(numel(buffer));
            end
            
            validateattributes(buffer,{'uint8'},{});
            validateattributes(nBytes,{'numeric'},{'nonnegative','scalar','integer'});
            WinSockClient('send',obj.hWinSockClient,buffer,uint64(nBytes));
        end
        
        function sendMultiple(obj,varargin)
            if numel(varargin) < 1
                return
            end
            
            cellfun(@(v)assert(isa(v,'uint8')),varargin);
            WinSockClient('sendMultiple',obj.hWinSockClient,varargin{:});
        end
        
        function data = read(obj,nBytes)
            validateattributes(nBytes,{'numeric'},{'nonnegative','scalar','integer'});
            data = WinSockClient('read',obj.hWinSockClient,uint64(nBytes));
        end
        
        function readIntoBuffer(obj,nBytes,buffer)
            validateattributes(buffer,{'uint8'},{});
            validateattributes(nBytes,{'numeric'},{'nonnegative','scalar','integer'});
            WinSockClient('readIntoBuffer',obj.hWinSockClient,uint64(nBytes),buffer);
        end
        
        function nBytes = bytesAvailable(obj,timeout_s)
            if nargin < 2 || isempty(timeout_s)
                timeout_s = 0;
            end
            
            validateattributes(timeout_s,{'numeric'},{'nonnegative','scalar','finite','nonnan'});
            timeout_us = uint64(round(timeout_s * 1e6));
            nBytes = WinSockClient('bytesAvailable',obj.hWinSockClient,timeout_us);
        end
    end
    
    %% Property Getter/Setter
    methods
        function set.TCP_NODELAY(obj,val)
            validateattributes(val,{'logical','numeric'},{'scalar','binary'});
            val = logical(val);
            WinSockClient('setNoDelay',obj.hWinSockClient,val);
        end
        
        function val = get.TCP_NODELAY(obj)
            val = WinSockClient('getNoDelay',obj.hWinSockClient);
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
