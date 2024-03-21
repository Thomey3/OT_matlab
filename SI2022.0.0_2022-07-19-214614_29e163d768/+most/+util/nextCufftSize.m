function [A,optimizedPrimes,powers] = nextCufftSize(A,direction,evenflag)
    % cufft is fastest for input sizes that can be written in the form
    % 2^a * 3^b * 5^c * 7^d . In general the smaller the prime factor, the
    % better the performance, i.e., powers of two are fastest.
    % https://docs.nvidia.com/cuda/cufft/index.html
    
    if nargin < 2 || isempty(direction)
        direction = 1;
    end
    
    even = false;
    odd  = false;
    
    if nargin >= 3 && ~isempty(evenflag)
        switch lower(evenflag)
            case 'even'
                even = true;
            case 'odd'
                odd = true;
            otherwise
                error('Unknown flag: %s',evenflag);
        end
    end
    
    direction = sign(direction);
    optimizedPrimes = [2 3 5 7];
    
    nextpowprimes_fun = @most.util.nextpowprimes;
    
    if ~verLessThan('matlab','9.2')
        % memoize for performance in Matlab 2017a or later
        nextpowprimes_fun = memoize(nextpowprimes_fun);
    end
    
    [powers,A] = nextpowprimes_fun(A, optimizedPrimes, direction);
    
    if ( odd && mod(A,2)==0 ) || ( even && mod(A,2)==1 )
        [powers,A] = nextpowprimes_fun(A + 1 * direction, optimizedPrimes, direction);
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
