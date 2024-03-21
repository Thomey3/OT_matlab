function [xx,yy,zz] = zspiral(tt,varargin)
% logarithmic spiral stimulus

% the following line will be parsed by the ROI editor to present a list of
% options. should be in the format: parameter1 (comment), parameter2 (comment)
%% parameter options: revolutions (Number of revolutions), zrepeats (Number of times to repeat the spiral as scanner travels through Z)

%% parse inputs
inputs = scanimage.mroi.util.parseInputs(varargin);

if ~isfield(inputs,'revolutions') || isempty(inputs.revolutions)
    inputs.revolutions = 5;
else
    if ischar(inputs.revolutions)
        inputs.revolutions = str2double(inputs.revolutions); %convert string to the intended type for the function
    end
end

if ~isfield(inputs,'a') || isempty(inputs.a)
    inputs.a = 0;
else
    if ischar(inputs.a)
        inputs.a = str2double(inputs.a); %convert string to the intended type for the function
    end
end

if ~isfield(inputs,'zrepeats') || isempty(inputs.zrepeats)
    inputs.zrepeats = 1;
else
    if ischar(inputs.zrepeats)
        inputs.zrepeats = str2double(inputs.zrepeats); %convert string to the intended type for the function
    end
end

mxn = numel(tt);
zz = tt ./ tt(mxn);

N = ceil(mxn * .5 / inputs.zrepeats);
thtt = linspace(0,2,2*N);
rtt = [1:N N:-1:1] / N;


%% generate output
if inputs.a == 0;
    xx = rtt .* sin(inputs.revolutions .* 2*pi .* thtt);
    yy = rtt .* cos(inputs.revolutions .* 2*pi .* thtt);
else
    rtt = rtt-max(rtt);
    xx = exp(inputs.a .* rtt) .* sin(inputs.revolutions .* 2*pi .* thtt);
    yy = exp(inputs.a .* rtt) .* cos(inputs.revolutions .* 2*pi .* thtt);
end


xx = repmat(xx, 1, inputs.zrepeats);
xx(mxn+1:end) = [];

yy = repmat(yy, 1, inputs.zrepeats);
yy(mxn+1:end) = [];





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
