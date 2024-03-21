function s = extractHeaderData(header, verInfo)
    if isfield(header,'SI')
        localHdr = header.SI;
    elseif isfield(header.scanimage,'SI')
        localHdr = header.scanimage.SI;
    else
        assert(false);  % We no longer support the original SI5 format
    end

    % If it's any of the currently supported SI2015 versions 
    if verInfo.infoFound
        if verInfo.TIFF_FORMAT_VERSION <= 3
            s.savedChans = localHdr.hChannels.channelSave(:);
            s.numPixels = localHdr.hRoiManager.pixelsPerLine;
            s.numLines = localHdr.hRoiManager.linesPerFrame;

            if localHdr.hFastZ.enable
                s.numVolumes = localHdr.hFastZ.numVolumes;
                try
                    s.numSlices = localHdr.hStackManager.slicesPerAcq;
                catch
                    s.numSlices = max(localHdr.hStackManager.numSlices, numel(localHdr.hStackManager.zs));
                end
                s.numFrames = 1;

                % Assuming that we only have discard frames during FastZ acquisitions
                s.discardFlybackframesEnabled = localHdr.hFastZ.discardFlybackFrames;
                s.numDiscardFrames = localHdr.hFastZ.numDiscardFlybackFrames; 
                s.numFramesPerVolume = localHdr.hFastZ.numFramesPerVolume;  %Includes flyback frames
            else
                s.numVolumes = 1;
                s.numFrames = localHdr.hStackManager.framesPerSlice / localHdr.hScan2D.logAverageFactor;
                try
                    s.numSlices = localHdr.hStackManager.slicesPerAcq;
                catch
                    s.numSlices = localHdr.hStackManager.numSlices;
                end
                s.discardFlybackframesEnabled = false;
                s.numDiscardFrames = 0;    
                s.numFramesPerVolume = s.numFrames * s.numSlices;
            end
        else
            s.savedChans = localHdr.hChannels.channelSave(:);
            s.numPixels = localHdr.hRoiManager.pixelsPerLine;
            s.numLines = localHdr.hRoiManager.linesPerFrame;
            
            hSM = localHdr.hStackManager;
            
            s.numVolumes = hSM.actualNumVolumes;
            s.numSlices  = hSM.actualNumSlices;
            s.numFrames  = hSM.framesPerSlice / localHdr.hScan2D.logAverageFactor;
            s.numFramesPerVolume = hSM.numFramesPerVolumeWithFlyback;
            s.numDiscardFrames = hSM.numFramesPerVolumeWithFlyback - hSM.numFramesPerVolume;
        end
    else
        assert(false);
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
