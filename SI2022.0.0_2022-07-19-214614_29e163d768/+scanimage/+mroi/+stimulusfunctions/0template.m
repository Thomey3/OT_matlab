function [xx,yy] = template(tt,varargin)
% describe type of stimulus here

% the following line will be parsed by the ROI editor to present a list of
% options. should be in the format: parameter1 (comment), parameter2 (comment)
%% parameter options: myparameter1 (Comment about myparameter1), myparameter2 (Comment about myparameter2)

%% parse inputs
inputs = scanimage.mroi.util.parseInputs(varargin);

% add optional parameters
if ~isfield(inputs,'myparameter1') || isempty(inputs.myparameter1)
   inputs.myparameter1 = 10; % standard value for myparameter1
else
    if ischar(inputs.myparameter1)
        inputs.myparameter1 = str2double(inputs.myparameter1); %convert string to the intended type for the function
    end
end

if ~isfield(inputs,'myparameter2') || isempty(inputs.myparameter2)
    inputs.myparameter2 = 20; % standard value for myparameter2
else
    if ischar(inputs.myparameter2)
        inputs.myparameter2 = str2double(inputs.myparameter2); %convert string to the intended type for the function
    end
end

%% generate output
% tt is an evenly spaced, zero based time series in the form of a time, so that
%       dt = 1 / sample frequency
%       min(tt) = 0
%       max(tt) = (numsamples - 1) * dt
%
% implement the parametric function of time, so that
%       length(xx) == length(tt)  and  length(yy) == length(tt)
%       xx,yy are row vectors
%
% this function will be called frequently by ScanImage;
% it is advised to optimize for performance

% (optional) if required, normalize tt
tt = tt ./ tt(end);

xx = xfunction_of(tt) * inputs.myparameter1;
yy = yfunction_of(tt) - inputs.myparameter2;

%% (optional) normalize output to interval [-1,1]
% for optimal performance, the output generation should produce values in
% the interval [-1,1] natively, instead of scaling the output in an
% additional step
[xx,yy] = normalize(xx,yy);
end

function normalize(xx,yy)
xxrange = [min(xx) max(xx)];
yyrange = [min(yy) max(yy)];

%center
xx = xx - sum(xxrange)/2;
yy = yy - sum(yyrange)/2;

%scale
factor = 1 / max(abs([xxrange - sum(xxrange)/2 , yyrange - sum(yyrange)/2]));
xx = xx .* factor;
yy = yy .* factor;
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
