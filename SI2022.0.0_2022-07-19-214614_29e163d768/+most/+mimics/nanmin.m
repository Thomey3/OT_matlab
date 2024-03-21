function [y,idx] = nanmin(a,dim,b)
% FORMAT: [Y,IDX] = NANMIN(A,DIM,[B])
% 
%    Minimum ignoring NaNs
%
%    This function enhances the functionality of NANMIN as distributed in
%    the MATLAB Statistics Toolbox and is meant as a replacement (hence the
%    identical name).
%
%    If fact NANMIN simply rearranges the input arguments to MIN because
%    MIN already ignores NaNs.
%
%    NANMIN(A,DIM) calculates the minimum of A along the dimension DIM of
%    the N-D array X. If DIM is omitted NANMIN calculates the minimum along
%    the first non-singleton dimension of X.
%
%    NANMIN(A,[],B) returns the minimum of the N-D arrays A and B.  A and
%    B must be of the same size.
%
%    Comparing two matrices in a particular dimension is not supported,
%    e.g. NANMIN(A,2,B) is invalid.
%    
%    [Y,IDX] = NANMIN(X,DIM) returns the index to the minimum in IDX.
%    
%    Similar replacements exist for NANMAX, NANMEAN, NANSTD, NANMEDIAN and
%    NANSUM which are all part of the NaN-suite.
%
%    See also MIN

% -------------------------------------------------------------------------
%    author:      Jan Gläscher
%    affiliation: Neuroimage Nord, University of Hamburg, Germany
%    email:       glaescher@uke.uni-hamburg.de
%    
%    $Revision: 1.1 $ $Date: 2004/07/15 22:42:14 $

if nargin < 1
	error('Requires at least one input argument')
end

if nargin == 1
	if nargout > 1
		[y,idx] = min(a);
	else
		y = min(a);
	end
elseif nargin == 2
	if nargout > 1
		[y,idx] = min(a,[],dim);
	else
		y = min(a,[],dim);
	end
elseif nargin == 3
	if ~isempty(dim)
		error('Comparing two matrices along a particular dimension is not supported')
	else
		if nargout > 1
			[y,idx] = min(a,b);
		else
			y = min(a,b);
		end
	end
elseif nargin > 3
	error('Too many input arguments.')
end

% $Id: nanmin.m,v 1.1 2004/07/15 22:42:14 glaescher Exp glaescher $




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
