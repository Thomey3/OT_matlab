classdef Server < handle
    properties (SetAccess = immutable)
        port;
    end
    
    properties (Access = private)
        hAsyncServer = [];
        hListeners = [];
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
            
            obj.hAsyncServer = most.network.tcpip.AsyncServer(obj.port);
            obj.IPWhitelist = IPWhitelist;
            obj.hAsyncServer.callback = @obj.dataCallback;
            
            obj.hListeners = [obj.hListeners addlistener(obj.hAsyncServer,'disconnected',@obj.gotDisconnected)];
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
        end
        
        function rsp = parseMessage(obj,msg,varargin)
            try
                try
                    msg = jsondecode(native2unicode(msg,'UTF-8'));
                catch ME
                    rsp = struct();
                    rsp.message = msg;
                    rsp.error = ME.getReport('extended','hyperlinks','off');
                    rsp = jsonencode(rsp);
                    return
                end
                
                switch msg.command
                    case 'set'
                        % some acrobatics to pack data for the eval string
                        data = getByteStreamFromArray(msg.value);
                        data = matlab.net.base64encode(data);
                        evalin('base',sprintf('%s = getArrayFromByteStream(matlab.net.base64decode(''%s''));',msg.property,data));
                        
                        msg.actual = evalin('base',msg.property);
                        rsp = jsonencode(msg);
                    case 'get'
                        val = evalin('base',msg.property);
                        msg.value = val;
                        rsp = jsonencode(msg);
                    case 'eval'
                        out = cell(1,msg.num_outputs);
                        [out{1:msg.num_outputs}] = evalin('base',msg.function);
                        msg.outputs = struct();
                        for idx = 1:numel(out)
                            msg.outputs.(sprintf('output%d',idx)) = out{idx};
                        end
                        rsp = jsonencode(msg);
                    case 'feval'
                        fcn_hdl = evalin('base',sprintf('@%s',msg.function));
                        
                        inputs = {};
                        
                        if isempty(msg.inputs)
                            inputs = {};
                        else
                            inputs = fieldnames(msg.inputs);
                            for idx = 1:numel(inputs)
                                inputs{idx} = msg.inputs.(inputs{idx});
                            end
                        end
                        
                        out = cell(1,msg.num_outputs);
                        [out{1:msg.num_outputs}] = fcn_hdl(inputs{:});
                        
                        msg.outputs = struct();
                        for idx = 1:numel(out)
                            msg.outputs.(sprintf('output%d',idx)) = out{idx};
                        end
                        rsp = jsonencode(msg);
                    otherwise
                        rsp = struct();
                        rsp.message = msg;
                        rsp.error = 'Invalid message format.';
                        rsp = jsonencode(rsp);
                end
            catch ME
                msg.error = ME.getReport('extended','hyperlinks','off');
                rsp = jsonencode(msg);
            end
        end
    end
    
    
    %% Network Methods
    methods (Hidden)
        function dataCallback(obj,src,evt)
            read_timeout = 10;
            
            szMsg = obj.read(8,read_timeout);
            szMsg = typecast(szMsg,'uint64');
            
            data = obj.read(szMsg,read_timeout);
            data = native2unicode(data,'UTF-8');
            
            rsp = obj.parseMessage(data);
            
            rsp = unicode2native(rsp,'UTF-8');
            obj.send(rsp);
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
        
        function send(obj,rsp)
            if isempty(rsp)
                return
            end
            
            data = cell(1,2);
            data{1} = typecast(uint64(numel(rsp)),'uint8');
            data{2} = rsp;
            
            obj.hAsyncServer.sendMultiple(data{:});
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
