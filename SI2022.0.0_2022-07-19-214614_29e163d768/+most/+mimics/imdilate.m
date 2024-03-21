%
% Simple replacement function for imdilate
%
%	WARNING: Assumes input strel is of type "disk" with and argument of 2
%			 This is meant to work only with the cell selection routines for now
%

function [imgOut] = imdilate(varargin)
	%% Handle parameters
	% Ignore parameters after the second argument

	if nargin ~= 2
		disp('Error: Unexpected number of arguments');
		return;
	end

	% parse arguments
	imgIn = varargin{1};
	ignoreMe = varargin{2};

	imgInSize = size(imgIn);
	binImg = most.mimics.im2bw(imgIn);
	%imgTemp = false(imgInSize+4);
	imgTemp = zeros(imgInSize+4);
	imgTemp(3:end-2, 3:end-2) = binImg(:,:);

	%Reenable for mex speed-ups
	%If you do, comment the code after the following line
	imgOut = most.mimics.imdilate_helper(imgTemp);

	%% stel is the morphological structuring element
	%stel = ones(5,5);
	%stel(1,1) = 0;	stel(1,4) = 0;	stel(4,1) = 0; stel(4,5) = 0;
	%stel(1,2) = 0;	stel(1,5) = 0;	stel(5,1) = 0; stel(5,4) = 0;
	%stel(2,1) = 0;	stel(2,5) = 0;	stel(5,2) = 0; stel(5,5) = 0;

	%[rowStrel colStrel]=size(stel);
	%[rows cols]=size(binImg);
	%imgOut = zeros(imgInSize);
	%for i=1:rows
		%for j=1:cols
			%imgOut(i,j) = sum(sum(bitand(stel, imgTemp(i:i+4,j:j+4))));
			%if imgOut(i,j) > 0.1
				%imgOut(i,j) = 1;
			%else
				%imgOut(i,j) = 0;
			%end
		%end
	%end
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
