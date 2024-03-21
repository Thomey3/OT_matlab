function icon = loadIcon(filename,outputSize,rotation,color)
% LOADICON Reads a BMP and returns an icon with the appropriate
% system-dependent background color, formatted for use as 'CData'.
%
% NOTE: the BMP is assumed to be a binary image--white pixels will be set to the system-depenedent background color.
%
% filename: the filename of the BMP to read.
% size: an integer value indicating the size of the output icon (NOTE: icon is assumed to be square.)
% rotation: an optional integer argument specifying the number of degrees to rotate the icon. (NOTE: rotation is assumed to have a value that is a multiple of 90.)
% color: optionally specifies the foreground color to use for the icon.

    if nargin < 4 || isempty(color) || length(color) ~= 3
        color = [0 0 0]; 
    end

    if nargin < 3 || isempty(rotation)
        rotation = 0;
    end

    bg = get(0,'defaultUIControlBackgroundColor');
    
    iconData = double(imread(filename,'bmp'))./255;
    
    if nargin < 2 || isempty(outputSize)
        outputSize = size(iconData,1);
    end

    if outputSize ~= size(iconData,1)
        doResize = true;
        icon = zeros(outputSize,outputSize,size(iconData,3));
    else
        doResize = false;
        icon = zeros(size(iconData));
    end
    
    for i = 1:size(iconData,3)
        channelData = rot90(iconData(:,:,i).*bg(i),-rotation/90);
        
        if doResize
            channelData = most.util.matResize(channelData,[16 16]);
            
            % thresholds to ensure that we have a binary image, and valid CData, after scaling...
            channelData(channelData < 0.7) = color(i);            
            channelData(channelData > 1.0) = 1.0;
        end

        icon(:,:,i) = channelData;
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
