classdef RoiDataSimple < handle & matlab.mixin.Copyable
    % class defining image data for one roi at multiple z depths
    properties
        hRoi;                          % handle to roi
        zs;                            % [numeric] array of zs
        channels;                      % [numeric] array of channelnumbers in imageData
        imageData;                     % cell of cell arrays of image data for
                                       %      channels (1st index) 
                                       %      volume (2nd index) 
                                       %      zs (3rd index)
    end
    
    methods
        %+++Test me
        function obj = castImageData(obj,newType)
            for iterChannels = 1:length(obj.imageData)
                for iterVolumes = 1:length(obj.imageData{iterChannels})
                    for iterZs = 1:length(obj.imageData{iterChannels}{iterVolumes})
                        obj.imageData{iterChannels}{iterVolumes}{iterZs} = cast(obj.imageData{iterChannels}{iterVolumes}{iterZs},newType);
                    end
                end
            end
        end
        
        %+++Test me
        function obj = multiplyImageData(obj,factor)
            for iterChannels = 1:length(obj.imageData)
                for iterVolumes = 1:length(obj.imageData{iterChannels})
                    for iterZs = 1:length(obj.imageData{iterChannels}{iterVolumes})
                        obj.imageData{iterChannels}{iterVolumes}{iterZs} = obj.imageData{iterChannels}{iterVolumes}{iterZs} .* cast(factor,'like',obj.imageData{iterChannels}{iterVolumes}{iterZs});
                    end
                end
            end
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
