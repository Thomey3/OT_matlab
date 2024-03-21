function varargout = functionWrapper(fWrapper_fstruct, varargin)
persistent PARSED_PERSISTENT_VARS;
if isempty(PARSED_PERSISTENT_VARS)
    PARSED_PERSISTENT_VARS = containers.Map;
end

%init if dne
if ~isKey(PARSED_PERSISTENT_VARS, fWrapper_fstruct.name)
    PARSED_PERSISTENT_VARS(fWrapper_fstruct.name) = struct();
end

pvarfnames = fieldnames(PARSED_PERSISTENT_VARS(fWrapper_fstruct.name));
pnames = fWrapper_fstruct.persistnames;
newnames = setxor(pvarfnames, pnames);
oldnames = intersect(pvarfnames, pnames);
%pvars have changed, add new pvars
if ~isempty(newnames)
    oldpstruct = PARSED_PERSISTENT_VARS(fWrapper_fstruct.name);
    pstruct = struct();
    for i=1:numel(oldnames)
        pstruct.(oldnames{i}) = oldpstruct.(oldnames{i});
    end
    for i=1:numel(newnames)
        pstruct.(newnames{i}) = [];
    end
    PARSED_PERSISTENT_VARS(fWrapper_fstruct.name) = pstruct;
end

%unpack persistent vars
pstruct = PARSED_PERSISTENT_VARS(fWrapper_fstruct.name);
for i=1:numel(pnames)
    eval([pnames{i} ' = pstruct.' pnames{i} ';']);
end

%unpack fcn arguments
for i=1:length(fWrapper_fstruct.argnames)
    if strcmp(fWrapper_fstruct.argnames{i}, 'varargin')
        varargin = varargin(i:end);
        break;
    end
    if strcmp(fWrapper_fstruct.argnames{i}, '~')
        continue;
    end
    eval([fWrapper_fstruct.argnames{i} ' = varargin{i};']);
end

eval(fWrapper_fstruct.fcn);

%repack persistent vars
fWrapper_pstruct = PARSED_PERSISTENT_VARS(fWrapper_fstruct.name);
fWrapper_pfields = fieldnames(fWrapper_pstruct);
for i=1:length(fWrapper_pfields)
    fWrapper_pstruct.(fWrapper_pfields{i}) = eval(fWrapper_pfields{i});
end
PARSED_PERSISTENT_VARS(fWrapper_fstruct.name) = fWrapper_pstruct;
%varargout is set automatically by eval so don't pack output args
if ~any(strcmp(fWrapper_fstruct.outnames, 'varargout'))
    for i=1:length(fWrapper_fstruct.outnames)
        outnm = fWrapper_fstruct.outnames{i};
        varargout{i} = eval(fWrapper_fstruct.outnames{i});
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
