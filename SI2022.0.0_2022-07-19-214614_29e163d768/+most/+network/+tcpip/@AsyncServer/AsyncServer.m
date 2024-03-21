classdef AsyncServer < handle
    %% User properties / event
    properties (SetAccess = private)
        isConnected = false;
        port;
    end
    
    properties
        IPWhitelist = {}; % if IP Whitelist is empty, connections from all addresses are allowed.
    end
    
    properties
        callback = function_handle.empty(1,0);
    end
    
    properties (Dependent)
        TCP_NODELAY;
        ClientIP;
        ClientPort;
    end
    
    events
        connected
        disconnected
    end
    
    %% Internal properties
    properties (Access = private)
        hWinSockServer
    end
    
    %% LifeCycle
    methods
        function obj = AsyncServer(port,IPWhitelist)
            if nargin < 1 || isempty(port)
                port = 5555;
            end
            
            if nargin < 2 || isempty(IPWhitelist)
                IPWhitelist = {};
            end
            
            obj.port = port;
            obj.IPWhitelist = IPWhitelist;
            
            port_ = sprintf('%d',port);            
            obj.hWinSockServer = WinSockServer('open',port_,@obj.statusCallback,@obj.dataCallback);
        end
        
        function delete(obj)
            WinSockServer('close',obj.hWinSockServer);
            obj.hWinSockServer = [];
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
            WinSockServer('send',obj.hWinSockServer,buffer,uint64(nBytes));
        end
        
        function sendMultiple(obj,varargin)
            if numel(varargin) < 1
                return
            end
            
            cellfun(@(v)assert(isa(v,'uint8')),varargin);
            WinSockServer('sendMultiple',obj.hWinSockServer,varargin{:});
        end
        
        function data = read(obj,nBytes)
            validateattributes(nBytes,{'numeric'},{'nonnegative','scalar','integer'});
            data = WinSockServer('read',obj.hWinSockServer,uint64(nBytes));
        end
        
        function readIntoBuffer(obj,nBytes,buffer)
            validateattributes(buffer,{'uint8'},{});
            validateattributes(nBytes,{'numeric'},{'nonnegative','scalar','integer'});
            WinSockServer('readIntoBuffer',obj.hWinSockServer,uint64(nBytes),buffer);
        end
        
        function nBytes = bytesAvailable(obj,timeout_s)
            if nargin < 2 || isempty(timeout_s)
                timeout_s = 0;
            end
            
            validateattributes(timeout_s,{'numeric'},{'nonnegative','scalar','finite','nonnan'});
            timeout_us = uint64(round(timeout_s * 1e6));
            nBytes = WinSockServer('bytesAvailable',obj.hWinSockServer,timeout_us);
        end
        
        function disconnectClient(obj)
            WinSockServer('disconnectClient',obj.hWinSockServer);
        end
    end
    
    %% Internal methods
    methods (Hidden)
        function statusCallback(obj,status)
            switch status
                case 0
                    fprintf('Client disconnected\n');
                    obj.isConnected = false;
                    notify(obj,'disconnected');
                case 1
                    allowed = obj.checkIPWhitelist();
                    if allowed
                        fprintf('Client connected\n');
                        obj.isConnected = true;
                        notify(obj,'connected')
                    else
                        ClientIP_ = obj.ClientIP;
                        ClientPort_ = obj.ClientPort;
                        obj.disconnectClient();
                        fprintf(2,'Connection from address %s port %d was blocked. To allow connection add this address to IPWhitelist.\n',ClientIP_,ClientPort_);
                    end
                otherwise
                    fprintf('Client disconnected because of error\n');
                    obj.isConnected = false;
                    notify(obj,'disconnected');
            end
        end
        
        function allowed = checkIPWhitelist(obj)
            if isempty(obj.IPWhitelist)
                allowed = true;
            else
                allowed = any(strcmpi(obj.ClientIP,obj.IPWhitelist)); % literal check for IPV6
                allowed = allowed || addressCheck(obj.ClientIP,obj.IPWhitelist); % subnet check for IPV4
            end
        end
        
        function dataCallback(obj)
            if ~obj.isConnected
                return
            end
            
            if isempty(obj.callback)
                numBytes = obj.bytesAvailable();
                obj.read(numBytes);
                fprintf('AsyncServer: Received and discarded %d bytes (No callback set for reading).\n',numBytes);
            else
                evt = [];
                obj.callback(obj,evt);
            end
        end   
    end
    
    %% Property Getter/Setter
    methods
        function set.callback(obj,val)
            if isempty(val)
                val = function_handle.empty(1,0);
            else
                validateattributes(val,{'function_handle'},{'scalar'});
            end
            
            obj.callback = val;
        end
        
        function set.TCP_NODELAY(obj,val)
            validateattributes(val,{'logical','numeric'},{'scalar','binary'});
            val = logical(val);
            WinSockServer('setNoDelay',obj.hWinSockServer,val);
        end
        
        function val = get.TCP_NODELAY(obj)
            val = WinSockServer('getNoDelay',obj.hWinSockServer);
        end
        
        function val = get.ClientIP(obj)
            val = WinSockServer('getClientIP',obj.hWinSockServer);
        end
        
        function val = get.ClientPort(obj)
            val = WinSockServer('getClientPort',obj.hWinSockServer);
        end
        
        function set.port(obj,val)
            validateattributes(val,{'numeric'},{'positive','integer','scalar','<=',65535});
            obj.port = val;
        end
        
        function set.IPWhitelist(obj,val)
            if ischar(val)
                val = {val};
            end
            
            assert(iscellstr(val),'IPWhiteList must be a cell string');
            
            patternIPV6 = '^([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}$';
            patternIPV4 = '^([0-9]{1,3}\.){3,3}[0-9]{1,3}(\/[0-9]{1,2}){0,1}$';
            
            ipV4mask = cellfun(@(ip)~isempty(regexpi(ip,patternIPV4,'match','once')),val);
            ipV6mask = cellfun(@(ip)~isempty(regexpi(ip,patternIPV6,'match','once')),val);
            validmask = ipV4mask | ipV6mask;
            
            if ~all(validmask)
                invalidIPs = val(~validmask);
                error('The following IPs are not valid: %s',strjoin(invalidIPs,'  '));
            end
            
            obj.IPWhitelist = val;
        end
    end
end

function allowed = addressCheck(address,whitelist)
    allowed = false;
    
    ip = address2bytes([address,'/32']);
    if isempty(ip)
        return
    end
    
    [subnets,subnetmasks] = cellfun(@(w)address2bytes(w),whitelist,'UniformOutput',false);
    
    for idx = 1:numel(subnets)
        subnet = subnets{idx};
        subnetmask = subnetmasks{idx};
        
        if ~isempty(subnet)
            subnet = bitand(subnet,subnetmask);
            ip_ = bitand(ip,subnetmask);
            
            allowed = subnet == ip_;
        end
        
        if allowed
            break;
        end
    end
end

function [subnet,subnetmask] = address2bytes(address)
    subnet = [];
    subnetmask = [];

    [~,matches] = regexp(address,'^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\/([0-9]{1,2})$','match','tokens','once');
    
    if numel(matches)==5
        subnet_ = matches(1:4);
        subnet_ = str2double(subnet_);
        
        if any(subnet_>255)
            return
        end
        
        subnet_ = subnet_ .* 2.^[3 2 1 0];
        subnet_ = uint32(sum(subnet_));
        
        subnetclass = matches(5);
        subnetclass = str2double(subnetclass);
        if subnetclass>32
            return
        end
        
        subnetmask_ = intmax('uint32');
        for idx = 1:(32-subnetclass)
            subnetmask_ = bitset(subnetmask_,idx,0);
        end
        
        subnet = subnet_;
        subnetmask = subnetmask_;
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
