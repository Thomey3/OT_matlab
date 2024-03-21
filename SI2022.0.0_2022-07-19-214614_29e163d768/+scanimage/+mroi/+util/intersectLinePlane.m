function X = intersectLinePlane(ptLn,vLn,ptPn,vPn)
outputSize = size(ptLn);
ptLn = validateVector(ptLn); % point on line
vLn  = validateVector(vLn);  % line vector
ptPn = validateVector(ptPn); % point on plane
vPn  = validateVector(vPn);  % plane normal vector

dot_vLn_vPn = dot(vLn,vPn);

if dot_vLn_vPn == 0
    X = nan(size(ptLn));
    return
end

% dot( vPn, (X-ptPn) ) = 0; % plane equation
% pTLn + U*vLn = X;    % parametric equation for line; U is scalar parameter
%
% dot( vPn, (ptLn-ptPn + U*vLn) ) = 0; % substitute X into plane equation
% dot( vPn, (ptLn-ptPn) ) + U * dot( vPn , vLn ) = 0;
% U = dot( vPn , (ptPn-ptLn) ) / dot( vPn, vLn );

% substitute U into line equation
X = ptLn + vLn * dot( vPn, (ptPn-ptLn) ) / dot_vLn_vPn;
X = reshape(X,outputSize);
end

function v = validateVector(v)
    assert(numel(v)==3);
    v = v(:);
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
