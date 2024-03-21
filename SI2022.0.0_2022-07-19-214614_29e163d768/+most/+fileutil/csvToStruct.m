function data = csvToStruct(filename,delimiter,delimiterIsRegex)
    % parses a csv file with a header into a struct
    
    if nargin < 2 || isempty(delimiter)
        delimiter = ',';
    end

    if nargin < 3 || isempty(delimiterIsRegex)
        delimiterIsRegex = false;
    end

    % read the csv file
    csvCell = most.fileutil.csvToCell(filename,delimiter,delimiterIsRegex);
    
    % parse the csv header
    headers = csvCell(1,:);
    headers = cellfun(@(h)str2ValidName(h),headers,'UniformOutput',false);
    
    % parse the csv values
    values = csvCell(2:end,:);
    numericMask = regexpi(values,'^[\d\.+-]+$');
    numericMask = cellfun(@(c)~isempty(c),numericMask);
    matMask = regexpi(values,'^\[.*\]$');
    matMask = cellfun(@(c)~isempty(c),matMask);
    nanMask = strcmpi(values,'NaN');
    
    values(numericMask) = cellfun(@(v)sscanf(v,'%f',1),values(numericMask),'UniformOutput',false);
    values(matMask) = cellfun(@(v)str2num(v),values(matMask),'UniformOutput',false);
    values(nanMask) = {NaN};
    
    %convert into struct array
    values = mat2cell(values,size(values,1),ones(1,size(values,2)));
    structDef = vertcat(headers(:)',values(:)');
    data = struct(structDef{:});
end

function strOut = str2ValidName(strIn)
    strOut = regexprep(strIn,'[^\w\d]',''); % remove all invalid characters
    strOut = regexprep(strOut,'^[\d_]*',''); % remove numeric characters and underscore from front of name
    assert(~isempty(strOut),'Invalid header name: %s',strIn);
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
