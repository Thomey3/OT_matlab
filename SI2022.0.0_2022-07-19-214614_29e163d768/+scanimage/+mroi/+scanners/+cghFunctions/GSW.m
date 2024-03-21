function [phi,efficiency] = GSW(scanner,pts,w)
    startTime = tic();
    
    M = size(pts,1);
    
    if nargin < 3 || isempty(w)
        w = ones(M,1);
    end
    
    zeroPowerMask = w == 0;
    pts(zeroPowerMask,:) = [];
    w(zeroPowerMask) = [];
    
    w = w/sum(w(:)); % normalize so that sum(wm)=1
    
    phaseMasks = cell(M,1);
    for m = 1:M
        x = pts(m,1);
        y = pts(m,2);
        z = pts(m,3);
        
        n = scanner.objectiveMediumRefractiveIdx;
        lambda = scanner.wavelength_um;
        f = scanner.focalLength_um;
        
        phaseMasks{m} = ( (2*pi*x)/(lambda*f)     ) * scanner.geometryBuffer.xj + ...
                        ( (2*pi*y)/(lambda*f)     ) * scanner.geometryBuffer.yj + ...
                        ( (pi*z)  /(lambda*f^2*n) ) * scanner.geometryBuffer.rSquared;
    end
    
    if M==1
        phi = phaseMasks{1};
        efficiency = 1;
        return
    end
    
    % convert to complex domain
    phaseMasks = cellfun(@(phi)exp(1i*phi),phaseMasks,'UniformOutput',false);
    ptPhaseMask_c_inv_beamProfile = cellfun(@(phi)scanner.geometryBuffer.beamProfileNormalized./phi,phaseMasks,'UniformOutput',false);
    
    phaseMask = RandomSuperposition(phaseMasks); % initial hSI.hSlguess
    
    wk_c = ones(M,1);
    Vk_c = V(phaseMask,ptPhaseMask_c_inv_beamProfile);
    
    if M>2
        numIterations = 10;
    else
        numIterations = 1;
    end
    
    for k = 1:numIterations % iterative optimization
        Vk_c_w = Vk_c ./ sqrt(w);
        wk_c = wk_c .* mean(abs(Vk_c_w)) ./ abs(Vk_c_w); % calculate new weights
        phaseMask(:) = 0;
        for m = 1:M
            phaseMask = phaseMask + phaseMasks{m}*(wk_c(m)*Vk_c(m)/abs(Vk_c(m)));
        end
        phaseMask = phaseMask ./ abs(phaseMask); % normalize
        Vk_c = V(phaseMask,ptPhaseMask_c_inv_beamProfile);
    end
    
    [I,e,u,s] = stats(Vk_c,w);
    phi = angle(phaseMask);
    efficiency = e;
    duration = toc(startTime);
    
    fprintf('Phase mask efficiency=%f,  uniformity=%f  std=%f, CPU compute time: %0.3fs for %d iterations\n',e,u,s,duration,numIterations);
end

function V_c = V(phi_c,ptPhaseMask_c_inv_beamProfile)
    M = numel(ptPhaseMask_c_inv_beamProfile);
    V_c = zeros(M,1,'like',phi_c);
    
    for m_ = 1:M
        v_c = phi_c .* ptPhaseMask_c_inv_beamProfile{m_};
        V_c(m_) = sum(sum(v_c));
    end
end

function phaseMask_c = RandomSuperposition(ptPhaseMask_c)
    % superposition with random phase offset
    M = numel(ptPhaseMask_c);
    phi_rand = exp(1i*2*pi*scanimage.mroi.scanners.cghFunctions.private.predictableRand(M,1));
    phaseMask_c = zeros(size(ptPhaseMask_c{1},1),size(ptPhaseMask_c{1},2));
    for m = 1:M
        phaseMask_c = phaseMask_c + ( ptPhaseMask_c{m} * phi_rand(m) );
    end
    phaseMask_c = phaseMask_c ./ abs(phaseMask_c); % normalize
end

function [I,e,u,s] = stats(V_c,w)
I = abs(V_c).^2; % intensity
e = sum(I);      % efficiency
I_w = I./w;       % respect weights for calculating uniformity and standard deviation
u = 1-(max(I_w)-min(I_w))/(max(I_w)+min(I_w));
s = 100 * sqrt(mean((I_w-mean(I_w)).^2))/mean(I_w);
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
