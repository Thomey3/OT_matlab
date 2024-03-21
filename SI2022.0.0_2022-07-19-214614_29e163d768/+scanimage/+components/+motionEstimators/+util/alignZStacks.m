function Z = alignZStacks(refIms,progressFcn,cancelFcn)
persistent gpuComputingAvailable

import scanimage.components.motionEstimators.suite2P.*

if nargin < 2 || isempty(progressFcn)
    progressFcn = @(varargin)false;
end

if nargin < 3 || isempty(cancelFcn)
    cancelFcn = @(varargin)false;
end

validateattributes(progressFcn,{'function_handle'},{'scalar'});
validateattributes(cancelFcn,{'function_handle'},{'scalar'});

if isempty(gpuComputingAvailable)
    gpuComputingAvailable = most.util.gpuComputingAvailable(); % buffer for performance
end

useGPU = gpuComputingAvailable;

refIms = single(refIms);

Lx = size(refIms,1);
Ly = size(refIms,2);
nPlanes = size(refIms,3);
nReps = size(refIms,4);

Z0 = reshape(refIms, Lx*Ly, nReps * nPlanes);

if useGPU
    Z0 = gpuArray(Z0);
end

% z-score
Z0 = bsxfun(@minus, Z0 , mean(Z0, 1));
Z0 = bsxfun(@rdivide, Z0 , sum(Z0.^2, 1).^.5);
Z0 = reshape(Z0, Lx, Ly, nPlanes, nReps);

% F is current plane, start at 1
F = squeeze(Z0(:,:,1,:));
ops.mimg = F(:,:,1); % first reference image mimg is first frame of first plane
%GJ TODO: Is this correct?
ops.Lx = Lx;
ops.Ly = Ly;
ops.kriging = false;
ops.useGPU = useGPU;
removeMean = 1;
ds = regoffKriging(F, ops, removeMean); % from Suite2p, third input is GPU_FLAG
% ds is number of frames by 2 (y and x offsets)
regdata  = rigidRegFrames(F,ops,ds); % aligns the frames using ds
mimg1 = sum(regdata, 3);  % new reference image

% preallocate Z
Z = zeros(numel(mimg1),nPlanes,'like',mimg1);
Z(:,1) = mimg1(:);

progressFcn(1/nPlanes);
for iz = 2:nPlanes
    assert(~cancelFcn(),'Alignment canceled by user.');
    
    % F is current plane
    F = squeeze(Z0(:,:,iz,:));
    
    % align F to mimg1 (previous reference) and take average
    ds = regoffKriging(F, ops, removeMean);
    % shift the data by computed offsets
    regdata = rigidRegFrames(F, ops, ds);
    
    % compute new reference
    mimg1 = sum(regdata, 3);
    ops.mimg = mimg1; % put it into ops
    
    Z(:,iz) = mimg1(:);  % set aligned image into Z
    
    progressFcn(iz/nPlanes);
end

Z = reshape(Z, Lx, Ly, nPlanes);
progressFcn(1);
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
