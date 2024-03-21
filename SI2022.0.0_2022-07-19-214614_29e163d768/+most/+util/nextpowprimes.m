function [P,A] = nextpowprimes(A,primes,direction)
    % like nextpow2, but allows to specify the prime factors
    if nargin<3 || isempty(direction)
        direction = 1;
    end
    
    validateattributes(A,{'numeric'},{'positive','integer','real'},'Input A needs to be a positive integer');
    validateattributes(primes,{'numeric'},{'>=',2,'integer','increasing','vector','real'},'primes input vector needs to be sorted prime numbers');
    assert(all(isprime(primes)),'primes input vector needs to be prime');
    validateattributes(direction,{'numeric','logical'},{'scalar','nonnan','real'},'Direction needs to be -1 OR 1 OR true OR false');
    
    P = zeros(size(primes),'like',primes);
    if A == 1
        return;
    end
    
    if direction > 0
        increment = 1;
    else
        increment = -1;
    end
    
    while true
        factors = factor(A);
        undesired_factors = setdiff(factors,primes);
        if isempty(undesired_factors)
            break % found a match
        else
            A = A+increment;
        end
    end
    
    for idx = 1:numel(primes)
        P(idx) = sum(factors == primes(idx));
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
