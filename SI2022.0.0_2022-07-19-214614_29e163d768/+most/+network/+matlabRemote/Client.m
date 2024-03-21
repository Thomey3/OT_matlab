classdef Client < handle
    properties (SetAccess = immutable)
        serverAddress;
        serverPort;
    end
    
    properties (Constant, Hidden)
        rawDataClasses = getRawDataClasses();
        protocol_version = '1';
        handshake_message_size_bytes = 1000;
    end
    
    properties
        timeout_s = 60;
    end
    
    events
        beingDisconnected
    end
    
    properties (Access = private)
        hTcpIpClient
        sendInProgress = false;
    end
    
    %% LifeCycle
    methods
        function obj = Client(serverAddress,serverPort)
            if nargin < 1 || isempty(serverAddress)
                serverAddress = '127.0.0.1';
            end
            
            if nargin < 2 || isempty(serverPort)
                serverPort = 5555;
            end
            
            % ServerVar uses the function listener(...) which was introduced in Matlab 2017b
            assert(~verLessThan('matlab','9.3'),'Minimum required Matlab version for ServerVar is 2017b');
            
            validateattributes(serverAddress,{'char'},{'row'});
            validateattributes(serverPort,{'numeric'},{'scalar','integer','positive'});
            obj.serverAddress = serverAddress;
            obj.serverPort = serverPort;
                        
            obj.connect();
        end
        
        function delete(obj)
            obj.disconnect();
        end
    end
    
    %% Protocol methods
    methods        
        function info = serverInfo(obj)
            msg = most.network.matlabRemote.message.make('serverInfo_get',[]);
            rsp = obj.sendMessage(msg);
            assert(strcmp(rsp.message,'serverInfo_got'));
            info = rsp.data;
        end
        
        function duration = ping(obj,nData)
            if nargin < 2 || isempty(nData)
                nData = 0;
            end
            
            validateattributes(nData,{'numeric'},{'nonnegative','integer'});
            
            payload = randi(255,1,nData,'uint8'); % this is a bit slow for larger datasets
            
            msg = most.network.matlabRemote.message.make('ping',[]);
            
            s = tic();
            [rsp,data] = obj.sendMessage(msg,payload);
            duration = toc(s);
            
            assert(strcmp(rsp.message,'pinged'));

            data = data{1};
            data = reshape(data,size(payload));
            assert(isequal(data,payload),'Data packet was corrupted in transer.');
            
            if nargout < 1
                fprintf('Ping roundtrip duration for %d bytes was %fms\n', nData, duration*1000);
            end
        end
        
        function serverVar = upload(obj,var)
            assert(~isa(var,'most.network.matlabRemote.ServerVar'));
            
            if ~isscalar(var) && any(strcmp(class(var),obj.rawDataClasses))
                description = struct('class',{class(var)},'size',{size(var)});
                msg = most.network.matlabRemote.message.make('var_upload_raw',description);
                var = reshape(var,[],1);
                var = typecast(var,'uint8');
                rsp = obj.sendMessage(msg,var);
            else
                msg = most.network.matlabRemote.message.make('var_upload',var);
                rsp = obj.sendMessage(msg);
            end     
            
            assert(strcmp(rsp.message,'var_uploaded'));
            descriptor = rsp.data;
            
            serverVar = most.network.matlabRemote.ServerVar(obj,descriptor);
        end
        
        function var = download(obj,var)
            obj.validateServerVar(var);
            
            msg = most.network.matlabRemote.message.make('var_download',var.uuid__);
            [rsp,rsp_data] = obj.sendMessage(msg);
            
            switch rsp.message
                case 'var_downloaded'
                    var = rsp.data;                    
                case 'var_downloaded_raw'
                    description = rsp.data;
                    var = rsp_data{1};
                    var = typecast(var,description.class);
                    var = reshape(var,description.size);
                otherwise
                    error('Incorrect response');
            end
        end
        
        function remove(obj,var)
            obj.validateServerVar(var);
            
            msg = most.network.matlabRemote.message.make('var_remove',var.uuid__);
            rsp = obj.sendMessage(msg);
            
            assert(strcmp(rsp.message,'var_removed'));
        end
        
        function varargout = eval(obj,expression)
            validateattributes(expression,{'char'},{'row'});
            
            data = struct('expression',{expression},'nargout',{nargout});
            msg = most.network.matlabRemote.message.make('eval',data);
            rsp = obj.sendMessage(msg);
            
            assert(strcmp(rsp.message,'evaled'));
            descriptors = rsp.data;
            varargout = cellfun(@(d)most.network.matlabRemote.ServerVar(obj,d),descriptors,'UniformOutput',false);
        end
        
        function varargout = feval(obj,varargin)
            sizes   = cellfun(@(v)size(v),varargin,'UniformOutput',false);
            classes = cellfun(@(v)class(v),varargin,'UniformOutput',false);
            
            isaServerVar = cellfun(@(v)isa(v,'most.network.matlabRemote.ServerVar'),varargin);
            cellfun(@(v)obj.validateServerVar(v),varargin(isaServerVar));
            
            isRaw = cellfun(@(v)any(strcmp(class(v),obj.rawDataClasses)),varargin);
            isEncoded = ~(isaServerVar | isRaw);
            
            varargin(isaServerVar) = cellfun(@(v)typecast(v.uuid__,'uint8'),varargin(isaServerVar),'UniformOutput',false); % translate ServerVars into uuids
            varargin(isRaw)        = cellfun(@(v)typecast(reshape(v,[],1),'uint8'),varargin(isRaw),'UniformOutput',false); % encode data
            varargin(isEncoded)    = cellfun(@(v)most.network.matlabRemote.message.encode(v),varargin(isEncoded),'UniformOutput',false); % encode data
            
            data = struct();
            data.nargout = nargout;
            data.isaServerVar = isaServerVar;
            data.isRaw = isRaw;
            data.isEncoded = isEncoded;
            data.sizes = sizes;
            data.classes = classes;
            
            msg = most.network.matlabRemote.message.make('feval',data);
            rsp = obj.sendMessage(msg,varargin{:});
            
            assert(strcmp(rsp.message,'fevaled'));
            descriptors = rsp.data;
            varargout = cellfun(@(d)most.network.matlabRemote.ServerVar(obj,d),descriptors,'UniformOutput',false);
        end
        
        function varargout = subsref_(obj,hServerVar,S)
            data = struct();
            
            varargin = S(end).subs;
            S(end).subs = [];
            
            if iscell(varargin)
                data.sSubsIsCell = true; 
            else
                data.sSubsIsCell = false;
                varargin = {varargin};
            end
            
            sizes   = cellfun(@(v)size(v),varargin,'UniformOutput',false);
            classes = cellfun(@(v)class(v),varargin,'UniformOutput',false);
            
            isaServerVar = cellfun(@(v)isa(v,'most.network.matlabRemote.ServerVar'),varargin);
            cellfun(@(v)obj.validateServerVar(v),varargin(isaServerVar));
            
            isRaw = cellfun(@(v)any(strcmp(class(v),obj.rawDataClasses)),varargin);
            isEncoded = ~(isaServerVar | isRaw);
            
            varargin(isaServerVar) = cellfun(@(v)typecast(v.uuid__,'uint8'),varargin(isaServerVar),'UniformOutput',false); % translate ServerVars into uuids
            varargin(isRaw)        = cellfun(@(v)typecast(reshape(v,[],1),'uint8'),varargin(isRaw),'UniformOutput',false); % encode data
            varargin(isEncoded)    = cellfun(@(v)most.network.matlabRemote.message.encode(v),varargin(isEncoded),'UniformOutput',false); % encode data
            
            data.nargout = nargout;
            data.isaServerVar = isaServerVar;
            data.isRaw = isRaw;
            data.isEncoded = isEncoded;
            data.sizes = sizes;
            data.classes = classes;
            data.S = most.network.matlabRemote.message.encode(S);
            data.serverVarUuid = hServerVar.uuid__;
            
            msg = most.network.matlabRemote.message.make('subsref',data);
            rsp = obj.sendMessage(msg,varargin{:});
            
            assert(strcmp(rsp.message,'subsrefed'));
            descriptors = rsp.data;
            varargout = cellfun(@(d)most.network.matlabRemote.ServerVar(obj,d),descriptors,'UniformOutput',false);
        end
    end
    
    %% Network methods
    methods (Access = private)
        function handshake(obj)
            %%% send handshake
            msg = sprintf(['most.network.matlabRemote.Client\r\n',...
                           'protocol_version = %s\r\n'],...
                            obj.protocol_version);
                 
            msg_uint8 = typecast(msg,'uint8');
            
            assert(numel(msg_uint8) <= obj.handshake_message_size_bytes);
            msg_uint8(end+1:obj.handshake_message_size_bytes) = uint8(0); % pad message
            assert(numel(msg_uint8)==obj.handshake_message_size_bytes);
            
            obj.hTcpIpClient.send(msg_uint8);
            
            %%% get handshake
            timeout = 1;
            rsp = obj.read(obj.handshake_message_size_bytes,timeout);
            rsp = typecast(rsp,'char');
            
            assert(~isempty(regexp(rsp,'^most\.network\.matlabRemote\.Server', 'once')),'Server is not a valid most.network.matlabRemote.Server');
            protocol_version_ = regexptranslate('escape',obj.protocol_version);
            v = regexp(rsp,['protocol_version *= *(', protocol_version_, ')'],'tokens');
            assert(~isempty(v) && ~isempty(v{1}) && strcmp(v{1}{1},obj.protocol_version),'Protocol version mismatch');
        end
        
        function [rsp,data] = sendMessage(obj,msg,varargin)            
            assert (~obj.sendInProgress,'Already waiting for a response from server.');
            
            obj.sendInProgress = true;
            
            % send message            
            msg_encoded = most.network.matlabRemote.message.encode(msg);
            
            obj.send(msg_encoded,varargin{:});
            
            [rsp_encoded,data] = obj.waitForMessage(obj.timeout_s);
            rsp = most.network.matlabRemote.message.decode(rsp_encoded);
            assert(msg.uuid == rsp.uuid);
            
            if strcmp(rsp.message,'error')
                ME = rsp.data;
                obj.sendInProgress = false;
                rethrow(ME);
            end
            
            obj.sendInProgress = false;            
        end
        
        function send(obj,varargin)
            data = cell(1,1+numel(varargin)*2);
            
            numMsgs = numel(varargin);
            data{1} = typecast(uint64(numMsgs),'uint8');
            
            for idx = 1:numel(varargin)
                szMsg = numel(varargin{idx});
                data{2*(idx-1) + 2} = typecast(uint64(szMsg),'uint8');
                data{2*(idx-1) + 3} = varargin{idx};
            end
            obj.hTcpIpClient.sendMultiple(data{:});           
        end
        
        function [rsp,data] = waitForMessage(obj,timeout_s)
            numMsgs = obj.read(8,timeout_s);
            numMsgs = typecast(numMsgs,'uint64');
            
            szMsg = obj.read(8,timeout_s);
            szMsg = typecast(szMsg,'uint64');
            rsp = obj.read(szMsg,timeout_s);
            
            data = cell(1,numMsgs-1);            
            for idx = 1:numel(data)
                szMsg = obj.read(8,timeout_s);
                szMsg = typecast(szMsg,'uint64');
                data{idx} = obj.read(szMsg,timeout_s);
            end            
        end
        
        function data = read(obj,nBytes,timeout_s)
            start_time = tic();
            
            if nBytes > 0
                blockingWait_s = 0.1;
                % the pause in the loop below can cause the GUI event queue
                % to be served. This means that there is no guarantee that
                % the pause is actually onle one millisecond.
                while ~obj.hTcpIpClient.bytesAvailable(blockingWait_s)
                    assert(toc(start_time) < timeout_s,'Server did not respond within timeout.');                  
                    pause(0.001);
                end
            end
            
            data = obj.hTcpIpClient.read(nBytes);
        end
        
        function connect(obj)
            obj.hTcpIpClient = most.network.tcpip.Client(obj.serverAddress, obj.serverPort);
            obj.handshake();
            serverInfo_ = obj.serverInfo();
            fprintf('Connected to server running Matlab %s\n',serverInfo_.version);
        end
        
        function disconnect(obj)
            if ~isempty(obj.hTcpIpClient)
                notify(obj,'beingDisconnected');
                obj.hTcpIpClient.delete();
            end
        end
    end
    
    methods
        function set.timeout_s(obj,val)            
            validateattributes(val,{'numeric'},{'scalar','nonnan','finite','nonnegative'});
            obj.timeout_s = val;
        end
    end
    
    %% Internal methods
    methods (Access = private)
        function validateServerVar(obj,var)
            assert(isa(var,'most.network.matlabRemote.ServerVar'));
            assert(isscalar(var));
            assert(var.hClient__ == obj);
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
