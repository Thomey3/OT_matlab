function list = structOrObj2List(obj,props)
%STRUCTOROBJ2LIST Convert a struct or object to a string cell array listing all properties/fields
%
% str = structOrObj2List(obj,varname,props)
% obj: (scalar) ML struct or object
% props: (optional cellstr) list of properties to encode. Defaults to all
% properties of obj.
%
% list is returned as:
% {
% prop1
% prop2
% struct.prop1
% struct.prop2
% ... etc
% }

if nargin < 2 || isempty(props)
    props = fieldnames(obj);
end

str = most.util.structOrObj2Assignments(obj,'',props);

if isempty(str)
    list = {};
else
    C = textscan(str,'%s %*[^\n]');
    list = C{1};
end



% 
% 
% list={};
% 
% if ~isscalar(obj)
%     list = [list sprintf('%s = <nonscalar struct/object>\n',varname)];
%     return;
% end
% 
% for c = 1:numel(props);
%     pname = props{c};
%     val = obj.(pname);
%     if isobject(val) 
%         list = lclNestedObjStructHelper(list,val,pname);
%     elseif isstruct(val)
%         list = lclNestedObjStructHelper(list,val,pname);
%     else
%         list = [list pname];
%     end
% end
% 
% end
% 
% function cell = lclNestedObjStructHelper(cell,val,qualname)
% if ischar(qualname)
%     qualname = {qualname};
% end
% 
% if numel(val) > 1
%     for c = 1:numel(val)
%         cell = [cell strcat(qualname,'.',most.util.structOrObj2List(val(c),qualname))]; %#ok<AGROW>
%     end
% else
%     cell = [cell strcat(qualname,'.',most.util.structOrObj2List(val,qualname))]; 
% end
% end




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
