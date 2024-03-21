classdef (InferiorClasses = { ?char,?single,?double,?logical,...
                             ?uint8,?uint16,?uint32,?uint64,...
                              ?int8, ?int16, ?int32, ?int64})...
                   ServerVar < handle
               
    properties (SetAccess = immutable, Hidden)
        hClient__
        uuid__
        descriptor__
        
        hBeingDisconnectedListener__
    end
    
    %% LifeCycle
    methods (Access = ?most.network.matlabRemote.Client)
        function obj = ServerVar(hClient,descriptor)
            obj.hClient__ = hClient;
            obj.descriptor__ = descriptor;
            obj.uuid__ = descriptor.uuid;
            
            % listener(...) was introduced in Matlab 2017b
            assert(~verLessThan('matlab','9.3'),'Minimum required Matlab version for ServerVar is 2017b');
            
            % do not use addlistener here; we want the listener object to be independent of the lifecycle of hClient
            obj.hBeingDisconnectedListener__ = listener(obj.hClient__,'beingDisconnected',@(varargin)obj.delete);
            
            obj.initialize__();
        end
    end
    
    methods                
        function delete(obj)
            if isvalid(obj.hClient__)
                obj.hClient__.remove(obj);
            end
            
            delete(obj.hBeingDisconnectedListener__);
        end
    end
    
    methods
        function C = classUnderlying(obj)
            C = obj.descriptor__.className;
        end
        
        function S = sizeUnderlying(obj)
            S = obj.descriptor__.size;
        end
        
        function deleteOnServer(obj)
            if isvalid(obj.hClient__)
                obj.hClient__.feval('delete',obj);
                obj.delete();
            end
        end
    end
    
    %% Internal methods
    methods (Access = private)
        function initialize__(obj)
            if firstCall()
                try
                    obj.addMethodOverloads__();
                catch
                    % No-op
                end
            end
        end
        
        function addMethodOverloads__(obj)
            basicMethods = getMethodsFromBasicClasses;
            
            % filter some functions
            filteredMethods = {'subsasgn','subsref','disp','delete','plot','numel','size','length','isscalar'};
            basicMethods = setdiff(basicMethods,filteredMethods);
            
            mc = metaclass(obj);
            existingMethods = {mc.MethodList.Name};
            
            methodsToAdd = setdiff(basicMethods,existingMethods);
            
            if isempty(methodsToAdd)
               return 
            end            
            
            methodBlock = makeMethodBlock(basicMethods);            
            writeMethodBlock(methodBlock);
            
            function methodNames = getMethodsFromBasicClasses()
                classes = getRawDataClasses();
                methodNames = {};
                for idx = 1:numel(classes)
                    class = classes{idx};
                    mc = meta.class.fromName(class);
                    methodNames = horzcat(methodNames,{mc.MethodList.Name}); %#ok<AGROW>
                end
                
                methodNames = unique(methodNames);
            end
            
            function writeMethodBlock(methodBlock)
                filePath = mfilename('fullpath');
                filePath = [filePath '.m'];
                
                if ~exist(filePath,'file')
                    % file is p-coded
                    return
                end
                
                hFile = fopen(filePath,'r');
                str_orig = fread(hFile,Inf,'char=>char')';
                fclose(hFile);
                
                startStr = [char(37) char(37) ' Matlab Operator overload'];
                endStr   = [char(37) char(37) ' End Matlab Operator overload'];
                str = regexprep(str_orig,['(?<=' startStr ').*(?=' endStr ')'],methodBlock);
                
                if ~strcmp(str_orig,str)
                    hFile = fopen(filePath,'w');
                    fprintf(hFile,'%s',str);
                    fclose(hFile);
                    
                    rehash();
                end
            end
            
            function methodBlock = makeMethodBlock(methodNames)
                methods = cellfun(@(m)makeFunctionStr(m),methodNames,'UniformOutput',false);
                methods = strjoin(methods,'\n');
                
                methodBlock = sprintf([...
                    '\n    methods (Hidden)\n',...
                    '%s',...
                    '    end\n'],...
                    methods);
            end
            
            function str = makeFunctionStr(name)
                str = sprintf([...
                    '        function varargout = %s(obj,varargin)\n',...
                    '            [varargout{1:nargout}] = forwardFunctionCall(''%s'',obj,varargin{:});\n',...
                    '        end\n'],...
                    name,name);
            end
        end
    end
    
    %% Public Methods
    methods        
        function var = download(obj)
            var = obj.hClient__.download(obj);
        end        
    end
    
    %% Internal Methods
    methods (Hidden)
        function disp(obj)
            fprintf('ServerVariable on server %s:%d\n\n',obj.hClient__.serverAddress,obj.hClient__.serverPort);
            fprintf('\tClass:\t%s\n',obj.descriptor__.className);
            fprintf('\tSize:\t%s\n',mat2str(obj.descriptor__.size));
        end
        
        function varargout = subsref(obj, S)
            try
                [varargout{1:nargout}] = builtin('subsref',obj,S);
            catch ME
                if strcmp(ME.identifier,'MATLAB:noPublicFieldForClass') || strcmp(ME.identifier,'MATLAB:noSuchMethodOrField') || strcmp(ME.identifier,'MATLAB:cellRefFromNonCell')
                    %[varargout{1:nargout}] = obj.hClient__.feval('subsref',obj,S);
                    [varargout{1:nargout}] = obj.hClient__.subsref_(obj,S);
                else
                    rethrow(ME);
                end
            end
        end
        
        function varargout = subsasgn(obj,S,B)
            try
                [varargout{1:nargout}] = builtin('subsasgn',obj,S,B);
            catch ME
                if strcmp(ME.identifier,'MATLAB:noPublicFieldForClass') || strcmp(ME.identifier,'MATLAB:noSuchMethodOrField') || strcmp(ME.identifier,'MATLAB:cellRefFromNonCell')
                    %[varargout{1:nargout}] = obj.hClient__.feval('subsasgn',obj,S,B);
                    [varargout{1:nargout}] = forwardFunctionCall('subsasgn',obj,S,B);
                else
                    rethrow(ME);
                end
            end
        end
    end
    
%% Matlab Operator overload
    methods (Hidden)
        function varargout = abs(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('abs',obj,varargin{:});
        end

        function varargout = accumarray(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('accumarray',obj,varargin{:});
        end

        function varargout = acos(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('acos',obj,varargin{:});
        end

        function varargout = acosd(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('acosd',obj,varargin{:});
        end

        function varargout = acosh(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('acosh',obj,varargin{:});
        end

        function varargout = acot(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('acot',obj,varargin{:});
        end

        function varargout = acotd(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('acotd',obj,varargin{:});
        end

        function varargout = acoth(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('acoth',obj,varargin{:});
        end

        function varargout = acsc(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('acsc',obj,varargin{:});
        end

        function varargout = acscd(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('acscd',obj,varargin{:});
        end

        function varargout = acsch(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('acsch',obj,varargin{:});
        end

        function varargout = airy(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('airy',obj,varargin{:});
        end

        function varargout = all(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('all',obj,varargin{:});
        end

        function varargout = amd(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('amd',obj,varargin{:});
        end

        function varargout = and(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('and',obj,varargin{:});
        end

        function varargout = anonymousFunction(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('anonymousFunction',obj,varargin{:});
        end

        function varargout = any(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('any',obj,varargin{:});
        end

        function varargout = asec(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('asec',obj,varargin{:});
        end

        function varargout = asecd(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('asecd',obj,varargin{:});
        end

        function varargout = asech(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('asech',obj,varargin{:});
        end

        function varargout = asin(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('asin',obj,varargin{:});
        end

        function varargout = asind(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('asind',obj,varargin{:});
        end

        function varargout = asinh(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('asinh',obj,varargin{:});
        end

        function varargout = atan(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('atan',obj,varargin{:});
        end

        function varargout = atan2(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('atan2',obj,varargin{:});
        end

        function varargout = atan2d(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('atan2d',obj,varargin{:});
        end

        function varargout = atand(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('atand',obj,varargin{:});
        end

        function varargout = atanh(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('atanh',obj,varargin{:});
        end

        function varargout = balance(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('balance',obj,varargin{:});
        end

        function varargout = bandwidth(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('bandwidth',obj,varargin{:});
        end

        function varargout = besselh(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('besselh',obj,varargin{:});
        end

        function varargout = besseli(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('besseli',obj,varargin{:});
        end

        function varargout = besselj(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('besselj',obj,varargin{:});
        end

        function varargout = besselk(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('besselk',obj,varargin{:});
        end

        function varargout = bessely(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('bessely',obj,varargin{:});
        end

        function varargout = betainc(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('betainc',obj,varargin{:});
        end

        function varargout = betaincinv(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('betaincinv',obj,varargin{:});
        end

        function varargout = bitand(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('bitand',obj,varargin{:});
        end

        function varargout = bitcmp(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('bitcmp',obj,varargin{:});
        end

        function varargout = bitget(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('bitget',obj,varargin{:});
        end

        function varargout = bitor(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('bitor',obj,varargin{:});
        end

        function varargout = bitset(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('bitset',obj,varargin{:});
        end

        function varargout = bitshift(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('bitshift',obj,varargin{:});
        end

        function varargout = bitxor(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('bitxor',obj,varargin{:});
        end

        function varargout = bsxfun(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('bsxfun',obj,varargin{:});
        end

        function varargout = cat(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('cat',obj,varargin{:});
        end

        function varargout = ceil(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('ceil',obj,varargin{:});
        end

        function varargout = cell(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('cell',obj,varargin{:});
        end

        function varargout = char(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('char',obj,varargin{:});
        end

        function varargout = chol(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('chol',obj,varargin{:});
        end

        function varargout = cholupdate(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('cholupdate',obj,varargin{:});
        end

        function varargout = circshift(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('circshift',obj,varargin{:});
        end

        function varargout = colon(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('colon',obj,varargin{:});
        end

        function varargout = complex(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('complex',obj,varargin{:});
        end

        function varargout = conj(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('conj',obj,varargin{:});
        end

        function varargout = conv2(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('conv2',obj,varargin{:});
        end

        function varargout = cos(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('cos',obj,varargin{:});
        end

        function varargout = cosd(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('cosd',obj,varargin{:});
        end

        function varargout = cosh(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('cosh',obj,varargin{:});
        end

        function varargout = cospi(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('cospi',obj,varargin{:});
        end

        function varargout = cot(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('cot',obj,varargin{:});
        end

        function varargout = cotd(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('cotd',obj,varargin{:});
        end

        function varargout = coth(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('coth',obj,varargin{:});
        end

        function varargout = csc(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('csc',obj,varargin{:});
        end

        function varargout = cscd(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('cscd',obj,varargin{:});
        end

        function varargout = csch(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('csch',obj,varargin{:});
        end

        function varargout = ctranspose(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('ctranspose',obj,varargin{:});
        end

        function varargout = cummax(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('cummax',obj,varargin{:});
        end

        function varargout = cummin(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('cummin',obj,varargin{:});
        end

        function varargout = cumprod(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('cumprod',obj,varargin{:});
        end

        function varargout = cumsum(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('cumsum',obj,varargin{:});
        end

        function varargout = det(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('det',obj,varargin{:});
        end

        function varargout = diag(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('diag',obj,varargin{:});
        end

        function varargout = diff(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('diff',obj,varargin{:});
        end

        function varargout = dmperm(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('dmperm',obj,varargin{:});
        end

        function varargout = double(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('double',obj,varargin{:});
        end

        function varargout = eig(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('eig',obj,varargin{:});
        end

        function varargout = empty(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('empty',obj,varargin{:});
        end

        function varargout = end(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('end',obj,varargin{:});
        end

        function varargout = eps(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('eps',obj,varargin{:});
        end

        function varargout = eq(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('eq',obj,varargin{:});
        end

        function varargout = erf(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('erf',obj,varargin{:});
        end

        function varargout = erfc(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('erfc',obj,varargin{:});
        end

        function varargout = erfcinv(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('erfcinv',obj,varargin{:});
        end

        function varargout = erfcx(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('erfcx',obj,varargin{:});
        end

        function varargout = erfinv(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('erfinv',obj,varargin{:});
        end

        function varargout = exp(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('exp',obj,varargin{:});
        end

        function varargout = expm1(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('expm1',obj,varargin{:});
        end

        function varargout = fft(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('fft',obj,varargin{:});
        end

        function varargout = fftn(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('fftn',obj,varargin{:});
        end

        function varargout = filter(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('filter',obj,varargin{:});
        end

        function varargout = find(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('find',obj,varargin{:});
        end

        function varargout = fix(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('fix',obj,varargin{:});
        end

        function varargout = flip(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('flip',obj,varargin{:});
        end

        function varargout = floor(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('floor',obj,varargin{:});
        end

        function varargout = full(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('full',obj,varargin{:});
        end

        function varargout = function_handle(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('function_handle',obj,varargin{:});
        end

        function varargout = gamma(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('gamma',obj,varargin{:});
        end

        function varargout = gammainc(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('gammainc',obj,varargin{:});
        end

        function varargout = gammaincinv(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('gammaincinv',obj,varargin{:});
        end

        function varargout = gammaln(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('gammaln',obj,varargin{:});
        end

        function varargout = ge(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('ge',obj,varargin{:});
        end

        function varargout = gt(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('gt',obj,varargin{:});
        end

        function varargout = hess(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('hess',obj,varargin{:});
        end

        function varargout = horzcat(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('horzcat',obj,varargin{:});
        end

        function varargout = hypot(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('hypot',obj,varargin{:});
        end

        function varargout = ichol(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('ichol',obj,varargin{:});
        end

        function varargout = ifft(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('ifft',obj,varargin{:});
        end

        function varargout = ifftn(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('ifftn',obj,varargin{:});
        end

        function varargout = ilu(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('ilu',obj,varargin{:});
        end

        function varargout = imag(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('imag',obj,varargin{:});
        end

        function varargout = int16(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('int16',obj,varargin{:});
        end

        function varargout = int32(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('int32',obj,varargin{:});
        end

        function varargout = int64(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('int64',obj,varargin{:});
        end

        function varargout = int8(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('int8',obj,varargin{:});
        end

        function varargout = inv(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('inv',obj,varargin{:});
        end

        function varargout = isbanded(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('isbanded',obj,varargin{:});
        end

        function varargout = iscolumn(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('iscolumn',obj,varargin{:});
        end

        function varargout = isdiag(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('isdiag',obj,varargin{:});
        end

        function varargout = isempty(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('isempty',obj,varargin{:});
        end

        function varargout = isequal(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('isequal',obj,varargin{:});
        end

        function varargout = isequaln(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('isequaln',obj,varargin{:});
        end

        function varargout = isequalwithequalnans(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('isequalwithequalnans',obj,varargin{:});
        end

        function varargout = isfinite(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('isfinite',obj,varargin{:});
        end

        function varargout = isfloat(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('isfloat',obj,varargin{:});
        end

        function varargout = isinf(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('isinf',obj,varargin{:});
        end

        function varargout = isinteger(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('isinteger',obj,varargin{:});
        end

        function varargout = islogical(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('islogical',obj,varargin{:});
        end

        function varargout = ismatrix(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('ismatrix',obj,varargin{:});
        end

        function varargout = isnan(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('isnan',obj,varargin{:});
        end

        function varargout = isnumeric(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('isnumeric',obj,varargin{:});
        end

        function varargout = isreal(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('isreal',obj,varargin{:});
        end

        function varargout = isrow(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('isrow',obj,varargin{:});
        end

        function varargout = issorted(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('issorted',obj,varargin{:});
        end

        function varargout = issortedrows(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('issortedrows',obj,varargin{:});
        end

        function varargout = issparse(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('issparse',obj,varargin{:});
        end

        function varargout = istril(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('istril',obj,varargin{:});
        end

        function varargout = istriu(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('istriu',obj,varargin{:});
        end

        function varargout = isvector(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('isvector',obj,varargin{:});
        end

        function varargout = java_array(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('java_array',obj,varargin{:});
        end

        function varargout = ldivide(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('ldivide',obj,varargin{:});
        end

        function varargout = ldl(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('ldl',obj,varargin{:});
        end

        function varargout = le(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('le',obj,varargin{:});
        end

        function varargout = linsolve(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('linsolve',obj,varargin{:});
        end

        function varargout = log(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('log',obj,varargin{:});
        end

        function varargout = log10(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('log10',obj,varargin{:});
        end

        function varargout = log1p(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('log1p',obj,varargin{:});
        end

        function varargout = log2(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('log2',obj,varargin{:});
        end

        function varargout = logical(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('logical',obj,varargin{:});
        end

        function varargout = lt(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('lt',obj,varargin{:});
        end

        function varargout = ltitr(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('ltitr',obj,varargin{:});
        end

        function varargout = lu(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('lu',obj,varargin{:});
        end

        function varargout = max(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('max',obj,varargin{:});
        end

        function varargout = maxk(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('maxk',obj,varargin{:});
        end

        function varargout = min(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('min',obj,varargin{:});
        end

        function varargout = mink(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('mink',obj,varargin{:});
        end

        function varargout = minus(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('minus',obj,varargin{:});
        end

        function varargout = mldivide(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('mldivide',obj,varargin{:});
        end

        function varargout = mod(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('mod',obj,varargin{:});
        end

        function varargout = mrdivide(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('mrdivide',obj,varargin{:});
        end

        function varargout = mtimes(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('mtimes',obj,varargin{:});
        end

        function varargout = ndims(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('ndims',obj,varargin{:});
        end

        function varargout = ne(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('ne',obj,varargin{:});
        end

        function varargout = nnz(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('nnz',obj,varargin{:});
        end

        function varargout = nonzeros(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('nonzeros',obj,varargin{:});
        end

        function varargout = norm(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('norm',obj,varargin{:});
        end

        function varargout = not(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('not',obj,varargin{:});
        end

        function varargout = nzmax(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('nzmax',obj,varargin{:});
        end

        function varargout = or(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('or',obj,varargin{:});
        end

        function varargout = ordeig(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('ordeig',obj,varargin{:});
        end

        function varargout = ordqz(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('ordqz',obj,varargin{:});
        end

        function varargout = ordschur(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('ordschur',obj,varargin{:});
        end

        function varargout = permute(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('permute',obj,varargin{:});
        end

        function varargout = plus(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('plus',obj,varargin{:});
        end

        function varargout = pow2(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('pow2',obj,varargin{:});
        end

        function varargout = power(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('power',obj,varargin{:});
        end

        function varargout = prod(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('prod',obj,varargin{:});
        end

        function varargout = psi(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('psi',obj,varargin{:});
        end

        function varargout = qr(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('qr',obj,varargin{:});
        end

        function varargout = qrupdate(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('qrupdate',obj,varargin{:});
        end

        function varargout = qz(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('qz',obj,varargin{:});
        end

        function varargout = rcond(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('rcond',obj,varargin{:});
        end

        function varargout = rdivide(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('rdivide',obj,varargin{:});
        end

        function varargout = real(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('real',obj,varargin{:});
        end

        function varargout = rem(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('rem',obj,varargin{:});
        end

        function varargout = repelem(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('repelem',obj,varargin{:});
        end

        function varargout = repmat(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('repmat',obj,varargin{:});
        end

        function varargout = reshape(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('reshape',obj,varargin{:});
        end

        function varargout = round(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('round',obj,varargin{:});
        end

        function varargout = schur(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('schur',obj,varargin{:});
        end

        function varargout = sec(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('sec',obj,varargin{:});
        end

        function varargout = secd(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('secd',obj,varargin{:});
        end

        function varargout = sech(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('sech',obj,varargin{:});
        end

        function varargout = sign(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('sign',obj,varargin{:});
        end

        function varargout = sin(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('sin',obj,varargin{:});
        end

        function varargout = sind(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('sind',obj,varargin{:});
        end

        function varargout = single(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('single',obj,varargin{:});
        end

        function varargout = sinh(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('sinh',obj,varargin{:});
        end

        function varargout = sinpi(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('sinpi',obj,varargin{:});
        end

        function varargout = sort(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('sort',obj,varargin{:});
        end

        function varargout = sortrowsc(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('sortrowsc',obj,varargin{:});
        end

        function varargout = sparse(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('sparse',obj,varargin{:});
        end

        function varargout = sparsfun(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('sparsfun',obj,varargin{:});
        end

        function varargout = sqrt(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('sqrt',obj,varargin{:});
        end

        function varargout = subsindex(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('subsindex',obj,varargin{:});
        end

        function varargout = sum(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('sum',obj,varargin{:});
        end

        function varargout = superiorfloat(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('superiorfloat',obj,varargin{:});
        end

        function varargout = svd(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('svd',obj,varargin{:});
        end

        function varargout = symrcm(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('symrcm',obj,varargin{:});
        end

        function varargout = tan(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('tan',obj,varargin{:});
        end

        function varargout = tand(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('tand',obj,varargin{:});
        end

        function varargout = tanh(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('tanh',obj,varargin{:});
        end

        function varargout = times(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('times',obj,varargin{:});
        end

        function varargout = transpose(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('transpose',obj,varargin{:});
        end

        function varargout = tril(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('tril',obj,varargin{:});
        end

        function varargout = triu(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('triu',obj,varargin{:});
        end

        function varargout = uint16(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('uint16',obj,varargin{:});
        end

        function varargout = uint32(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('uint32',obj,varargin{:});
        end

        function varargout = uint64(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('uint64',obj,varargin{:});
        end

        function varargout = uint8(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('uint8',obj,varargin{:});
        end

        function varargout = uminus(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('uminus',obj,varargin{:});
        end

        function varargout = uplus(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('uplus',obj,varargin{:});
        end

        function varargout = vecnorm(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('vecnorm',obj,varargin{:});
        end

        function varargout = vertcat(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('vertcat',obj,varargin{:});
        end

        function varargout = xor(obj,varargin)
            [varargout{1:nargout}] = forwardFunctionCall('xor',obj,varargin{:});
        end
    end
%% End Matlab Operator overload
end

function varargout = forwardFunctionCall(funName,varargin)
% find server variables to extract hClient
tf = cellfun(@(v)isa(v,'most.network.matlabRemote.ServerVar'),varargin);
hServerVars = varargin(tf);
hClient = hServerVars{1}.hClient__;

[varargout{1:nargout}] = hClient.feval(funName,varargin{:});
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
