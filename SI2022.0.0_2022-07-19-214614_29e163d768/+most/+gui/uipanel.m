function h = uipanel(varargin)
    ip = most.util.InputParser;
    ip.addOptional('WidthLimits',[]);
    ip.addOptional('HeightLimits',[]);
    ip.addOptional('SizeLimits',[]);
    ip.parse(varargin{:});
    [~,otherPVArgs] = most.util.filterPVArgs(varargin,{'WidthLimits' 'HeightLimits' 'SizeLimits'});
    
    h = uipanel(otherPVArgs{:});
    
    if ~isempty(ip.Results.WidthLimits)
        lms = [ip.Results.WidthLimits ip.Results.WidthLimits(1)];
        set(h, 'WidthLimits', lms(1:2));
    end
    if ~isempty(ip.Results.HeightLimits)
        lms = [ip.Results.HeightLimits ip.Results.HeightLimits(1)];
        set(h, 'HeightLimits', lms(1:2));
    end
    if ~isempty(ip.Results.SizeLimits)
        set(h, 'WidthLimits', ip.Results.SizeLimits(1)*ones(1,2));
        set(h, 'HeightLimits', ip.Results.SizeLimits(2)*ones(1,2));
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
