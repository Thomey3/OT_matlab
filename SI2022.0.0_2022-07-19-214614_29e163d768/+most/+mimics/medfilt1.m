%
% Simple replacement function for medfilt1
%

function [y] = medfilt1(varargin)
	%% Handle parameters
	% Ignore parameters after the second argument

	% Validate and parse arguments
	if nargin == 1
		x = varargin{1};		% Signal
		N = 3;					% Order
	elseif nargin == 2
		x = varargin{1};		% Signal
		N = varargin{2};		% Order
	else
		disp('Error: Unexpected number of arguments');
		return;
	end

	%Apply the median filter of size 5 to signal x 
    %Just as in the official toolbox version, zeros are assumed 
	%to the left and right of X. 
	y = zeros(size(x)); 	% Preallocate 

    %For N odd, Y(k) is the median of X( k-(N-1)/2 : k+(N-1)/2 ).
    %For N even, Y(k) is the median of X( k-N/2 : k+N/2-1 ).
	if mod(N,2) == 0
		winN = round(N/2);
		% Pad x array
		x = [zeros(1,winN), x, zeros(1,winN)];
		for k = 1:length(y)
			tmp = sort(x(k:k+2*winN-1)); 
			y(k) = (tmp(winN)+tmp(winN+1))/2;
		end 
	else
		winN = round((N-1)/2);
		% Pad x array
		x = [zeros(1,winN), x, zeros(1,winN)];
		for k = 1:length(y)
			tmp = sort(x(k:k+2*winN)); 
			y(k) = tmp(winN+1);
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
