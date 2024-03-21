classdef Server < handle
    properties (SetAccess = immutable)
        port;
    end
    
    properties (Constant, Hidden)
        rawDataClasses = getRawDataClasses();
        protocol_version = '1';
        handshake_message_size_bytes = 1000;
        timeout_s = 1;
    end
    
    properties (Access = private)
        hAsyncServer = [];
        workspace;
        
        hListeners;
    end
    
    properties (Dependent)
        IPWhitelist;
    end
    
    %% LifeCycle
    methods
        function obj = Server(port,IPWhitelist)
            if nargin < 1 || isempty(port)
                port = 5555;
            end
            
            if nargin < 2  || isempty(IPWhitelist)
                IPWhitelist = {'127.0.0.1/32'}; % By default only allow local connections
            end
            
            validateattributes(port,{'numeric'},{'scalar','integer','positive'});
            
            obj.port = port;
            obj.workspace = containers.Map('KeyType','uint64','ValueType','any');
            
            obj.hAsyncServer = most.network.tcpip.AsyncServer(obj.port);
            obj.IPWhitelist = IPWhitelist;
            obj.hAsyncServer.callback = @obj.handshake;
            
            obj.hListeners = [obj.hListeners most.ErrorHandler.addCatchingListener(obj.hAsyncServer,'disconnected',@obj.gotDisconnected)];
        end
        
        function delete(obj)
            if ~isempty(obj.hAsyncServer)
                obj.hAsyncServer.delete();
            end
        end
    end
    
    %% Protocol methods
    methods (Access = private)
        function disconnect(obj)
            obj.hAsyncServer.disconnectClient();
        end
        
        function gotDisconnected(obj,varargin)
            %%% get ready for next connetion
            obj.hAsyncServer.callback = @obj.handshake;
        end
        
        function handshake(obj,src,evt)
            try
                msg = obj.read(obj.handshake_message_size_bytes,10);
                msg = typecast(msg,'char');
                assert(~isempty(regexp(msg,'^most\.network\.matlabRemote\.Client', 'once')),'Connected client is not a valid most.network.matlabRemote.Client');
                protocol_version_ = regexptranslate('escape',obj.protocol_version);
                v = regexp(msg,['protocol_version *= *(', protocol_version_, ')'],'tokens');
                assert(~isempty(v) && ~isempty(v{1}) && strcmp(v{1}{1},obj.protocol_version),'Protocol version mismatch');
            catch ME
                obj.disconnect();
                fprintf('Handshake failed\n');
                rethrow(ME);
            end                      
            
            rsp = sprintf(['most.network.matlabRemote.Server\r\n',...
                           'protocol_version = %s\r\n'],...
                           obj.protocol_version);
            
            rsp_uint8 = typecast(rsp,'uint8');
            
            assert(numel(rsp_uint8) <= obj.handshake_message_size_bytes);
            rsp_uint8(end+1:obj.handshake_message_size_bytes) = uint8(0); % pad message
            assert(numel(rsp_uint8)==obj.handshake_message_size_bytes);
            
            obj.hAsyncServer.send(rsp_uint8);
            
            %%% handshake succeeded, hand data over to dataCallback
            obj.hAsyncServer.callback = @obj.dataCallback;
        end
        
        function [rsp,data_rsp] = parseMessage(obj,msg,varargin)
            data_rsp = {};
            
            switch msg.message
                case 'serverInfo_get'
                    info = struct();
                    info.computer = computer();
                    info.memory = memory();
                    info.version = version();
                    info.workingDirectory = pwd();
                    info.workspaceSize_Variables = obj.workspace.Count();
                    workspace_ = obj.workspace; %#ok<NASGU>
                    ws_whos = whos('workspace_');
                    info.workspaceSize_Bytes = ws_whos.bytes;
                    
                    rsp = most.network.matlabRemote.message.make('serverInfo_got',info,msg.uuid);
                
                case 'ping'
                    rsp = most.network.matlabRemote.message.make('pinged',[],msg.uuid);
                    data_rsp = varargin;

                case 'var_upload'
                    var = msg.data;
                    descriptor = obj.setWorkspaceVar(var);
                    rsp = most.network.matlabRemote.message.make('var_uploaded',descriptor,msg.uuid);
                    
                case 'var_upload_raw'
                    description = msg.data;
                    varargin = varargin{1};
                    varargin = typecast(varargin,description.class);
                    varargin = reshape(varargin,description.size);
                    descriptor = obj.setWorkspaceVar(varargin);
                    
                    rsp = most.network.matlabRemote.message.make('var_uploaded',descriptor,msg.uuid);

                case 'var_download'
                    uuid = msg.data;
                    var = obj.getWorkspaceVar(uuid);
                    if ~isscalar(var) && any(strcmp(class(var),obj.rawDataClasses))
                        description = struct('class',{class(var)},'size',{size(var)});
                        rsp = most.network.matlabRemote.message.make('var_downloaded_raw',description,msg.uuid);
                        var = reshape(var,[],1);
                        data_rsp{1} = typecast(var,'uint8');
                    else
                        rsp = most.network.matlabRemote.message.make('var_downloaded',var,msg.uuid);
                    end
                    
                case 'var_remove'
                    uuid = msg.data;
                    obj.removeWorkSpaceVar(uuid);
                    rsp = most.network.matlabRemote.message.make('var_removed',uuid,msg.uuid);
                    
                case 'eval'
                    expression = msg.data.expression;
                    outputs = cell(1,msg.data.nargout);
                    [outputs{:}] = eval(expression);
                    descriptors = cellfun(@(o)obj.setWorkspaceVar(o),outputs,'UniformOutput',false);
                    rsp = most.network.matlabRemote.message.make('evaled',descriptors,msg.uuid);
                    
                case 'feval'
                    % translate ServerVar uuids into variables                    
                    varargin(msg.data.isaServerVar) = cellfun(@(v)obj.getWorkspaceVar(typecast(v,'uint64')), varargin(msg.data.isaServerVar), 'UniformOutput',false);
                    varargin(msg.data.isEncoded)    = cellfun(@(v)most.network.matlabRemote.message.decode(v), varargin(msg.data.isEncoded), 'UniformOutput',false);
                    varargin(msg.data.isRaw)        = cellfun(@(v,c,s)reshape(typecast(v,c),s), varargin(msg.data.isRaw),msg.data.classes(msg.data.isRaw),msg.data.sizes(msg.data.isRaw), 'UniformOutput',false);
                    
                    outputs = cell(1,msg.data.nargout);
                    [outputs{:}] = feval(varargin{:});
                    descriptors = cellfun(@(o)obj.setWorkspaceVar(o),outputs,'UniformOutput',false);
                    rsp = most.network.matlabRemote.message.make('fevaled',descriptors,msg.uuid);
                    
                case 'subsref'
                    % translate ServerVar uuids into variables
                    varargin(msg.data.isaServerVar) = cellfun(@(v)obj.getWorkspaceVar(typecast(v,'uint64')), varargin(msg.data.isaServerVar), 'UniformOutput',false);
                    varargin(msg.data.isEncoded)    = cellfun(@(v)most.network.matlabRemote.message.decode(v), varargin(msg.data.isEncoded), 'UniformOutput',false);
                    varargin(msg.data.isRaw)        = cellfun(@(v,c,s)reshape(typecast(v,c),s), varargin(msg.data.isRaw),msg.data.classes(msg.data.isRaw),msg.data.sizes(msg.data.isRaw), 'UniformOutput',false);
                    
                    S = most.network.matlabRemote.message.decode(msg.data.S);
                    
                    if msg.data.sSubsIsCell
                        S(end).subs = varargin;
                    else
                        S(end).subs = varargin{1};
                    end
                    
                    hServerVar = obj.getWorkspaceVar(msg.data.serverVarUuid);
                    
                    outputs = cell(1,msg.data.nargout);
                    [outputs{:}] = feval('subsref',hServerVar,S);
                    descriptors = cellfun(@(o)obj.setWorkspaceVar(o),outputs,'UniformOutput',false);
                    rsp = most.network.matlabRemote.message.make('subsrefed',descriptors,msg.uuid);
                    
                otherwise
                    error('Unknown message command');
            end
        end
    end
    
    
    %% Network Methods
    methods (Hidden)
        function dataCallback(obj,src,evt)
            read_timeout = 10;
            
            numMsgs = obj.read(8,read_timeout);
            numMsgs = typecast(numMsgs,'uint64');
            
            szMsg = obj.read(8,read_timeout);
            szMsg = typecast(szMsg,'uint64');
            msg_encoded = obj.read(szMsg,read_timeout);
            
            msg_data = cell(1,numMsgs-1);            
            for idx = 1:numel(msg_data)
                szMsg = obj.read(8,read_timeout);
                szMsg = typecast(szMsg,'uint64');
                msg_data{idx} = obj.read(szMsg,read_timeout);
            end
            
            msg = most.network.matlabRemote.message.decode(msg_encoded);
            
            try
                [rsp,rsp_data] = obj.parseMessage(msg,msg_data{:});
            catch ME
                rsp = most.network.matlabRemote.message.make('error',ME,msg.uuid);
                rsp_data = {};
            end
            
            rsp_encoded = most.network.matlabRemote.message.encode(rsp);
            obj.send(rsp_encoded,rsp_data{:});
        end
        
        function data = read(obj,nBytes,timeout_s)
            if nargin<3 || isempty(timeout_s)
                timeout_s = obj.timeout_s;                
            end
            
            start_time = tic();
            
            if nBytes > 0
                blockingWait_s = 0.1;
                % the pause in the loop below can cause the GUI event queue
                % to be served. This means that there is no guarantee that
                % the pause is actually onle one millisecond.
                while ~obj.hAsyncServer.bytesAvailable(blockingWait_s)
                    assert(toc(start_time) < timeout_s,'Server did not respond within timeout.');                  
                    pause(0.001);
                end
            end
            
            data = obj.hAsyncServer.read(nBytes);
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
            
            obj.hAsyncServer.sendMultiple(data{:});
        end
    end
    
    %% Workspace methods
    methods (Access = private)
        function val = getWorkspaceVar(obj,uuid)
            val = obj.workspace(uuid);
        end
        
        function descriptor = setWorkspaceVar(obj,var)
            uuid = most.util.generateUUIDuint64();
            obj.workspace(uuid) = var;
            
            descriptor = struct();
            descriptor.uuid = uuid;
            descriptor.className = class(var);
            descriptor.size = size(var);
        end
        
        function removeWorkSpaceVar(obj,uuid)
            if isKey(obj.workspace,uuid)
               remove(obj.workspace,uuid);
            end
        end
    end
    
    %% Property Getter/Setter
    methods
        function val = get.IPWhitelist(obj)
            val = obj.hAsyncServer.IPWhitelist;
        end
        
        function set.IPWhitelist(obj,val)
            obj.hAsyncServer.IPWhitelist = val;
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
