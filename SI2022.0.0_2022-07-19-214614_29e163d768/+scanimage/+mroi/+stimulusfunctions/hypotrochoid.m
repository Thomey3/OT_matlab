function [xx,yy] = hypotrochoid(tt,varargin)
% hypotrochoid stimulus function

% the following line will be parsed by the ROI editor to present a list of
% options. should be in the format: parameter1 (comment), parameter2 (comment)
%% parameter options: r1, r2, d

%% parse inputs
inputs = scanimage.mroi.util.parseInputs(varargin);

if ~isfield(inputs,'r1') || isempty(inputs.r1)
   inputs.r1 = 5; % integer number
else
    if ischar(inputs.r1)
        inputs.r1 = str2double(inputs.r1); %convert string to the intended type for the function
    end
end

if ~isfield(inputs,'r2') || isempty(inputs.r2)
   inputs.r2 = 3; % integer number
else
    if ischar(inputs.r2)
        inputs.r2 = str2double(inputs.r2); %convert string to the intended type for the function
    end
end

if ~isfield(inputs,'d') || isempty(inputs.d)
   inputs.d = 5; % integer number
   else
    if ischar(inputs.d)
        inputs.d = str2double(inputs.d); %convert string to the intended type for the function
    end
end

r1 = inputs.r1;
r2 = inputs.r2;
d =  inputs.d;

%% generate output
tt = tt ./ tt(end); %normalize tt
phi = 2*pi*r2/gcd(r1,r2) .* tt;

xx = (r1-r2) .* cos(phi) + d .* cos( ((r1-r2)/r2) .* phi);
yy = (r1-r2) .* sin(phi) - d .* sin( ((r1-r2)/r2) .* phi);

% scale output to fill the interval [-1, 1]
scalefactor = max(abs([min(xx),max(xx),min(yy),max(yy)]));
xx = xx ./ scalefactor;
yy = yy ./ scalefactor;
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
