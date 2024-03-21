function [photonPeaks, differentiatedAnalogData] = detectPhotons(analogData,mode,threshold,diffWidth,enableDeadTime)
    diffIsPositive = [analogData(2:end) - analogData(1:end-1);nan] > 0;
    differentiatedAnalogData = [nan(diffWidth-1,1);analogData((diffWidth+1):end) - analogData(1:end-diffWidth);nan];
    
    if strcmp(mode,'peak detect')
        diffOverThresh = find((differentiatedAnalogData > threshold) & diffIsPositive);
        diffZeroCrossings = find(~diffIsPositive);
        diffIsNan = find(isnan(differentiatedAnalogData));
        inhibit = false(size(diffOverThresh));
        
        photonPeaks = nan(size(analogData));
        for id = 1:numel(diffOverThresh)
            if inhibit(id)
                continue
            end
            threshCrossing = diffOverThresh(id);
            zeroCrossingInds = diffZeroCrossings(diffZeroCrossings>threshCrossing);
            nans = diffIsNan(diffIsNan>threshCrossing);
            if ~isempty(zeroCrossingInds) && (isempty(nans) || (zeroCrossingInds(1) < nans(1)))
                photonPeaks(zeroCrossingInds(1)) = 1;
                inhibit(diffOverThresh == (zeroCrossingInds(1)+1)) = enableDeadTime;
            end
        end
    else
        photonPeaks = single(analogData > threshold);
        photonPeaks(2:end) = photonPeaks(2:end) .* ~photonPeaks(1:end-1);
        photonPeaks(1,:) = 0;
        photonPeaks(photonPeaks==0) = nan;
        photonPeaks(isnan(analogData)) = nan;
    end
    
    isP = ~isnan(photonPeaks);
    photonPeaks(isP) = analogData(isP);
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
