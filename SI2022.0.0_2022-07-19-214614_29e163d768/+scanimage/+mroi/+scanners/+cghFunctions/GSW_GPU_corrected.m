function [phi,efficiency] = GSW_GPU_corrected(scanner,pts,w)
    startTime = tic();

    if nargin < 3 || isempty(w)
        w = ones(size(pts,1),1);
    end
    
    % remove points with 0 power
    zeroPowerMask = w == 0;
    pts(zeroPowerMask,:) = [];
    w(zeroPowerMask) = [];
    
    M = size(pts,1);
    
    wavelength_um  = scanner.wavelength_um;
    focalLength_um = scanner.focalLength_um;    
    n = scanner.objectiveMediumRefractiveIdx;
    
    x_scaled_gpu = gpuArray(single( pts(:,1)*2*pi / (wavelength_um * focalLength_um  ) ));
    y_scaled_gpu = gpuArray(single( pts(:,2)*2*pi / (wavelength_um * focalLength_um  ) ));
    z_scaled_gpu = gpuArray(single( pts(:,3)*2*pi*n / (wavelength_um) ));
    
    pixPosXX_gpu = gpuArray(single(scanner.geometryBuffer.xj));
    pixPosYY_gpu = gpuArray(single(scanner.geometryBuffer.yj));
    r_squared_gpu = gpuArray(single(scanner.geometryBuffer.rSquared));
    pixFactorZZ_gpu = - sqrt( complex(1 - r_squared_gpu/(n*focalLength_um)^2) ) - 1;
    beamProfile_gpu = gpuArray(single(scanner.geometryBuffer.beamProfileNormalized));
    
    w = single( w(:)/sum(w) );  % normalize weights so that sum(wm)=1
    w_c = single(ones(M,1));    % weights that are being adjusted during GSW iterations
    
    if M <= 1
        numIterations = 1;
    elseif M <= 2
        numIterations = 2;
    else
        numIterations = 10;
    end
    
    randPhase = 2*pi*scanimage.mroi.scanners.cghFunctions.private.predictableRand(M,1);
    randPhase = randPhase-randPhase(1); % ensure first random phase is 0    
    F = exp(1i*randPhase); % initial guess for GSW
    
    for k = 1:numIterations % iterative optimization
        if k>1
            V_c_w = V_c ./ sqrt(w);
            w_c = w_c .* mean(abs(V_c_w)) ./ abs(V_c_w); % calculate new weights
            F = w_c.*V_c./abs(V_c);
        end
        
        phaseMask = calculatePhaseMask(pixPosXX_gpu,pixPosYY_gpu,pixFactorZZ_gpu,x_scaled_gpu,y_scaled_gpu,z_scaled_gpu,F);
        V_c = calculateV_c(phaseMask,pixPosXX_gpu,pixPosYY_gpu,pixFactorZZ_gpu,beamProfile_gpu,x_scaled_gpu,y_scaled_gpu,z_scaled_gpu);
    end
    
    [I,e,u,s] = stats(V_c,w);
    phi = phaseMask;
    efficiency = e;
    
    duration = toc(startTime);

    if M > 1
        fprintf('Phase mask efficiency=%f,  uniformity=%f  std=%f, GPU compute time: %0.3fs for %d iterations\n',e,u,s,duration,numIterations);
    end    
end

function phaseMask = calculatePhaseMask(pixPosXX,pixPosYY,pixFactorZZ,x_scaled,y_scaled,z_scaled,F)
    M = uint32(numel(x_scaled));
    F = cast(F,'like',x_scaled);
    F = complex(F); % ensure F is complex (otherwise performance goes down)
    
    phaseMask = arrayfun(@calculatePixelPhase,pixPosXX,pixPosYY,pixFactorZZ,M);

    %%% GPU stencil function
    function pixPhase = calculatePixelPhase(pixPosX,pixPosY,pixFactorZZ,M)
        pixPhase_complex = complex(single(0));
        pt_idx = uint32(1);
                
        while pt_idx <= M
            pt_pix_Phase = x_scaled(pt_idx)*pixPosX + y_scaled(pt_idx)*pixPosY + z_scaled(pt_idx)*pixFactorZZ;
            pt_pix_Phase_complex = exp(1i*pt_pix_Phase) * F(pt_idx);
            pixPhase_complex = pixPhase_complex + pt_pix_Phase_complex;
            pt_idx = pt_idx+1;
        end
        
        pixPhase = angle(pixPhase_complex);
    end
end

function V_c = calculateV_c(phaseMask,pixPosXX,pixPosYY,pixFactorZZ,beamProfile,x_scaled,y_scaled,z_scaled)
    M = numel(x_scaled);    
    V_c = complex(zeros(M,1,'like',x_scaled));
    
    for m = 1:M
        V_c_2D = arrayfun(@calculateV_c_2D,pixPosXX,pixPosYY,pixFactorZZ,phaseMask,beamProfile,x_scaled(m),y_scaled(m),z_scaled(m));
        V_c(m) = sum(sum(V_c_2D));
    end
    
    V_c = gather(V_c);
    
    %%% GPU stencil function
    function V_c_pix = calculateV_c_2D(pixPosX,pixPosY,pixFactorZZ,phaseMask,beamPower,x_scaled,y_scaled,z_scaled)
        pixPhase = x_scaled*pixPosX + y_scaled*pixPosY + z_scaled*pixFactorZZ;
        V_c_pix = beamPower * exp(1i*(phaseMask-pixPhase));
    end
end

function [I,e,u,s] = stats(V_c,w)
    I = abs(V_c).^2; % intensity
    e = sum(I);      % efficiency
    I_w = I./w;      % respect weights for calculating uniformity and standard deviation
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
