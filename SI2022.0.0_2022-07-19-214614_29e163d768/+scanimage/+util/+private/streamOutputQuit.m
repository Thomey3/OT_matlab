function [Aout,imgInfo] = streamOutputQuit(hTif,numImages,si_ver,silent)
% This function returns available data and should be followed by an exit call
% The header is assumed to have been set prior to calling this method
%
    if nargin < 4
        silent = false;
    end
    
    %% Preallocate image data
    switch hTif.getTag('SampleFormat')
        case 1
            imageDataType = 'uint16';
        case 2
            imageDataType = 'int16';
        otherwise
            error('Unrecognized or unsupported SampleFormat tag found');
    end

    numLines = hTif.getTag('ImageLength');
    numPixels = hTif.getTag('ImageWidth');

    Aout = zeros(numLines,numPixels,numImages,imageDataType);    
    imgInfo.numImages = numImages;	% Only the number of images is reliable
    imgInfo.filename = hTif.FileName;	% As well as the filename, of course
    imgInfo.si_ver = si_ver;	% ScanImage version 

    for idx = 1:numImages
        hTif.setDirectory(idx);
        Aout(:,:,idx) = hTif.read();
    end

    if ~silent
        most.idioms.warn('Returning default, uncategorized stream of Tiff frames');
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
