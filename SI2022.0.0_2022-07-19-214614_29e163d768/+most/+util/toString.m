function s = toString(v,numericPrecision)
%TOSTRING Convert a MATLAB array to a string
% s = toString(v)
%   numericPrecision: <Default=15> Maximum number of digits to encode into string for numeric values
%
% Unsupported inputs v are returned as '<unencodeable value>'. Notably,
% structs are not supported because at the moment structs are processed
% with structOrObj2Assignments.
%
% At moment - only cell matrices of specific types are encodeable
% Encodable types: Resource (parsed to char), char, numeric, logical

s = '<unencodeable value>';

if nargin < 2 || isempty(numericPrecision)
    numericPrecision = 6;
end

if iscell(v)
    if isempty(v)
        s = '{}';
    elseif isvector(v)
        if iscellstr(v)
            v = strrep(v,'''','''''');
            if size(v,1) > 1 % col vector
                list = sprintf('''%s'';',v{:});
            else
                list = sprintf('''%s'' ',v{:});
            end
            list = list(1:end-1);
            s = ['{' list '}'];
        elseif all(cellfun(@isnumeric,v(:))) || all(cellfun(@islogical,v(:)))
            strv = cellfun(@(x)mat2str(x,numericPrecision),v,'UniformOutput',false);
            if size(v,1)>1 % col vector
                list = sprintf('%s;',strv{:});
            else
                list = sprintf('%s ',strv{:});
            end
            list = list(1:end-1);
            s = ['{' list '}'];
        else
            s = '{';
            for i = 1:numel(v)
                if isa(v{i}, 'function_handle')
                    s = [s functionHandle2Str(v{i}) ' '];
                elseif isenum(v{i})
                    s = [s '''' char(v{i}) ''' '];
                elseif ischar(v{i})
                    s = [s '''' v{i} ''' '];
                else
                    s = [s most.util.toString(v{i}) ' '];
                end
            end
            s(end) = '}';
        end
    elseif numel(size(v)) == 2
        s = '{';
        sz = size(v);
        for i = 1:sz(1)
            cellvec = v(i,:);
            cellvecstr = most.util.toString(cellvec);
            cellvecstr = strrep(cellvecstr,'{','');
            cellvecstr = strrep(cellvecstr,'}','; ');
            s = [s cellvecstr];
        end
        s(end-1) = '}';
        s(end) = '';
    end
    
elseif ischar(v)
    if strfind(v,'''')
       v =  ['$' strrep(v,'''','''''')];
    end
    s = ['''' v ''''];
    
elseif isnumeric(v) || islogical(v)
    if ndims(v) > 2
        s = most.util.array2Str(v);
    else
        s = mat2str(v,numericPrecision);
    end
    
elseif isa(v,'containers.Map')
    s = most.util.map2str(v);
    
elseif isa(v,'function_handle')
    s = functionHandle2Str(v);
    
elseif isenum(v)
    if isempty(v)
        s = '';
    elseif isscalar(v)
        s = ['''' char(v) ''''];
    else
        s = ['''' mat2str(v) ''''];
    end
    
elseif isobject(v)
    if isempty(v)
        s = '''''';
    elseif isscalar(v) && most.idioms.isValidObj(v) && isprop(v,'name')
        s = ['''' v.name ''''];
    end
end

end

function s = functionHandle2Str(v)
    s = func2str(v);
    
    if ~strcmpi(s(1),'@')
        s = ['@' s];
    end
    
    s = ['''' strrep(s, '''', '''''') ''''];
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
