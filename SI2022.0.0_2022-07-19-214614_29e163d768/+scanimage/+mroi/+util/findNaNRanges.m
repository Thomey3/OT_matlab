function [nanRanges,isIdentifierFnc] = findNaNRanges(data,identifier)
% finds the start and end indices of nan ranges in a data stream
% input: data - needs to be a vector of data
% outputs:
%   nanRanges- nx2 matrix, column 1 is start indices column 2 is end indices
%   
% example
%      findNaNRanges([1 2 3 NaN NaN 4 NaN])
%
%             ans =
% 
%                  4     5
%                  7     7
%
if nargin < 2 || isempty(identifier)
    identifier = NaN;
end

if isnan(identifier)
    isIdentifierFnc = @isnan;
elseif isinf(identifier)
    isIdentifierFnc = @isinf;
else
    isIdentifierFnc = @(input)eq(input,identifier);
end

nans = any(isIdentifierFnc(data),2);

%find positive edges
nansshiftright = [false;nans(1:end-1)];
posedge = find(nans > nansshiftright);

nansshiftleft = [nans(2:end);false];
negedge = find(nans > nansshiftleft);

nanRanges = [posedge, negedge];
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
