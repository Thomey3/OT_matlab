function rgb = wavelengthToRGB(lambda_nm)
    [hGiR,hGiG,hGiB] = makeInterpolants;
    
    r = hGiR(lambda_nm(:));
    g = hGiG(lambda_nm(:));
    b = hGiB(lambda_nm(:));
    
    rgb = [r,g,b];
end

function [hGiR,hGiG,hGiB] = makeInterpolants()
lambda_rgb = [...
        415  0.5    0    1 % violet
        467    0    0    1 % blue
        492    0    1    1 % cyan
        532    0    1    0 % green
        577    1    1    0 % yellow
        607    1  0.5    0 % orange
        682    1    0    0 % red
        ];
    
    method = 'pchip';
    extrapolationMethod = 'nearest';
    hGiR = griddedInterpolant(lambda_rgb(:,1),lambda_rgb(:,2),method,extrapolationMethod);
    hGiG = griddedInterpolant(lambda_rgb(:,1),lambda_rgb(:,3),method,extrapolationMethod);
    hGiB = griddedInterpolant(lambda_rgb(:,1),lambda_rgb(:,4),method,extrapolationMethod);
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
