% this code was developed by Marius Pachitariu and Carsen Stringer as part of the software package Suite2p

function K = kernelD(xp0,yp0,len)

D  = size(xp0,1);
N  = size(xp0,2); 
M  = size(yp0,2);

% split M into chunks if on GPU to reduce memory usage
if isa(xp0,'gpuArray') 
    K=gpuArray.zeros(N,M);
    cs  = 60;
elseif N > 10000
    K = zeros(N,M);
    cs = 10000;
else
    K= zeros(N,M);
    cs  = M;
end

for i = 1:ceil(M/cs)
    ii = [((i-1)*cs+1):min(M,i*cs)];
    mM = length(ii);
    xp = repmat(xp0,1,1,mM);
    yp = reshape(repmat(yp0(:,ii),N,1),D,N,mM);

    Kn = exp( -sum(bsxfun(@times,(xp - yp).^2,1./(len.^2))/2,1));
    K(:,ii)  = squeeze(Kn); 
    
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
