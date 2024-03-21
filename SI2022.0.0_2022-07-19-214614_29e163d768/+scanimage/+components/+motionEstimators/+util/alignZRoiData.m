function alignedRoiData = alignZRoiData(roiData)
    % roiData validation
    validateattributes(roiData,{'scanimage.mroi.RoiData'},{'vector'});
    assert(numel(unique([roiData.hRoi]))==1,'All roiData must reference the same roi for alignment');
    assert(numel(roiData(1).channels) == 1 &&...
        all(cellfun(@(ch)isequal(ch,roiData(1).channels),{roiData.channels})),...
        'The channels for all roiData need to be the same. There can only be one channel.');
    assert(all(cellfun(@(zs)isequal(zs,roiData(1).zs),{roiData.zs})),...
        'The zs for all roiData need to be the same for alignment');

    if isscalar(roiData)
        alignedRoiData = roiData; % Nothing to do here
        return
    end

    roiName = roiData(1).hRoi.name;
    cancel = false;
    hWb = waitbar(0,sprintf('Aligning Z Stacks for Roi %s...',roiName), ...
        'Name', 'Z-Stack Alignment',...
        'CreateCancelBtn',@(src,evt)cancelFcn(true),...
        'CloseRequestFcn',@(src,evt)cancelFcn(true));

    try
        % assume referenceRoiData is an array of roiData, containing
        % multiple repetitions
        % roiData.imageData{chidx}{zidx}
        chIdx = 1; % channel index
        refIms = arrayfun(@(rD)cat(3,rD.imageData{chIdx}{:}),roiData,'UniformOutput',false);
        refIms = cat(4,refIms{:}); % 4D array [resX,resY,slice,volume]
        refIms = single(refIms);

        % save std and mean
        for zIdx = 1:size(refIms,3)
            refIm = refIms(:,:,zIdx,:);
            expectedStd(1,1,zIdx)  = std(refIm(:));  %#ok<AGROW>
            expectedMean(1,1,zIdx) = mean(refIm(:)); %#ok<AGROW>
        end
        
        % perform alignment
        Z = scanimage.components.motionEstimators.util.alignZStacks(refIms,@progressFcn,@cancelFcn);
        
        % restore std and mean
        Z = bsxfun(@times,Z,expectedStd./std(reshape(Z,[],1,size(Z,3))));
        Z = bsxfun(@plus,Z,expectedMean-mean(reshape(Z,[],1,size(Z,3))));

        alignedRoiData = roiData(1).copy();
        alignedRoiData.imageData{chIdx} = mat2cell(Z,size(Z,1),size(Z,2),ones(1,size(Z,3)));
        
    catch ME
        most.idioms.safeDeleteObj(hWb);
        rethrow(ME);
    end
    
    most.idioms.safeDeleteObj(hWb);
    
    function cancel_ = cancelFcn(varargin)
        if nargin > 0
            cancel = varargin{1};
        end
        cancel_ = cancel;
    end

    function progressFcn(progress)
        if ~isempty(hWb) && isvalid(hWb)
            waitbar(progress,hWb);
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
