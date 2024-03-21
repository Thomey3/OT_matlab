function str = structOrObj2Assignments(obj,varname,props,numericPrecision)
%STRUCTOROBJ2ASSIGNMENTS Convert a struct or object to a series of
% assignment statements.
%
% str = structOrObj2Assignments(obj,varname,props)
% obj: (scalar) ML struct or object
% varname: (char) base variable name in assignment statements (see below).
% props: (optional cellstr) list of property names to encode. Defaults to all
% properties of obj. Property names can include dot notation for nested object/structure values.
% numericPrecision: (optional integer) specifies max number of digits to use in output string for numeric assignments. (Default value used otherwise)
%
% str is returned as:
% <varname>.prop1 = value1
% <varname>.prop2 = value2
% <varname>.structProp1 = value3
% <varname>.structProp2 = value4
% ... etc

if nargin < 3 || isempty(props)
    props = fieldnames(obj);
end

if nargin < 4 
    numericPrecision = []; %Use default
end


if ~isscalar(obj)
    str = sprintf('%s = <nonscalar struct/object>\n',varname);
    return;
end

str = [];

if isempty(varname)
    separator = '';
else
    separator = '.';
end

for c = 1:numel(props);
    pname = props{c};        
    
    [base,rem] = strtok(pname,'.');
    
    if isempty(rem)
        val = obj.(pname);
    else
        val = eval(['obj.' pname]);                
    end
        
    qualname = sprintf('%s%s%s',varname,separator,pname);
    if isenum(val)
        str = lclAddPVPair(str,qualname,most.util.toString(val,numericPrecision));
    elseif isobject(val)
        str = lclNestedObjStructHelper(str,val,qualname);
    elseif isstruct(val)
        str = lclNestedObjStructHelper(str,val,qualname);
    else
        str = lclAddPVPair(str,qualname,most.util.toString(val,numericPrecision));
    end
end

end

function s = lclAddPVPair(s,pname,strval)
s = [s pname ' = ' strval sprintf('\n')];
end

function str = lclNestedObjStructHelper(str,val,qualname)
if isempty(val)
    str = [str qualname ' = []' sprintf('\n')]; 
elseif numel(val) > 1
    for c = 1:numel(val)
        qualnameidx = sprintf('%s__%d',qualname,c);
        str = [str most.util.structOrObj2Assignments(val(c),qualnameidx)]; %#ok<AGROW>
    end
else
    str = [str most.util.structOrObj2Assignments(val,qualname)]; 
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
