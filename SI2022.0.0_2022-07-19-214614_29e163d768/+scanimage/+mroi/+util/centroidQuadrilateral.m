function ctr = centroidQuadrilateral(pt1,pt2,pt3,pt4)

if nargin < 2
    pt2 = pt1(2,:);
    pt3 = pt1(3,:);
    pt4 = pt1(4,:);
    pt1 = pt1(1,:);
end

validateattributes(pt1,{'numeric'},{'size',[1,2]});
validateattributes(pt2,{'numeric'},{'size',[1,2]});
validateattributes(pt3,{'numeric'},{'size',[1,2]});
validateattributes(pt4,{'numeric'},{'size',[1,2]});

ctr1 = centroidTriangle(pt1,pt2,pt3);
ctr2 = centroidTriangle(pt1,pt3,pt4);
ctr3 = centroidTriangle(pt1,pt2,pt4);
ctr4 = centroidTriangle(pt2,pt3,pt4);

ctr = scanimage.mroi.util.intersectLines(ctr1,ctr2-ctr1,ctr3,ctr4-ctr3);
end

function ctr = centroidTriangle(pt1,pt2,pt3)
pt1_2 = pt1 + (pt2-pt1)./2;
pt2_3 = pt2 + (pt3-pt2)./2;

v1 = pt3-pt1_2;
v2 = pt1-pt2_3;

ctr = scanimage.mroi.util.intersectLines(pt1_2,v1,pt2_3,v2);
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
