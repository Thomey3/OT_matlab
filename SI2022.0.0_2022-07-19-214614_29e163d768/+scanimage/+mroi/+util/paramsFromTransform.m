function [offsetX,offsetY,scaleX,scaleY,rotation,shear] = paramsFromTransform(T,tolerance)
if scanimage.mroi.util.isTransformPerspective(T)
%     offsetX = NaN;
%     offsetY = NaN;
%     scaleX = NaN;
%     scaleY = NaN;
%     rotation = NaN;
%     shear = NaN;
%     return
    
    T([3,6]) = 0; % ignoring perspective entries for the moment. TODO: find better solution
end

if nargin < 2 || isempty(tolerance)
    tolerance = 1e-10;
end

ctr = scanimage.mroi.util.xformPoints([0 0],T);
offsetX = applyTolerance(ctr(1));
offsetY = applyTolerance(ctr(2));

toOrigin = eye(3);
toOrigin([7,8]) = [-ctr(1),-ctr(2)];

T = toOrigin * T;

[ux,~] = getUnitVectors(T);
rot = atan2(ux(2),ux(1));
rotation = applyTolerance(rot * 180 / pi);

toUnRotated = [cos(rot) sin(rot) 0; ...
              -sin(rot) cos(rot) 0; ...
               0         0         1];

T = toUnRotated * T;

[ux,uy] = getUnitVectors(T);
scaleX = applyTolerance(norm(ux));
scaleY = applyTolerance(dot(uy,[0,1]));

toUnScaled = eye(3);
toUnScaled([1,5]) = [1/scaleX,1/scaleY];
T = toUnScaled * T;

[~,uy] = getUnitVectors(T);
shear = applyTolerance(uy(1));

function [ux,uy] = getUnitVectors(T)
% returns transformed unit vectors
X = [1,0];
Y = [0,1];
O = [0,0];
pts = scanimage.mroi.util.xformPoints([X;Y;O],T);
X = pts(1,:);
Y = pts(2,:);
O = pts(3,:);
ux = X-O;
uy = Y-O;
end

function x = applyTolerance(x)
    if abs(x) < tolerance
        x = 0;
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
