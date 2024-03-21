classdef FullScreenDisplay < handle
    properties (Access = private)
        mexWindowHandle = [];
    end
    
    methods
        function obj = FullScreenDisplay(monitorID)
            if nargin < 1 || isempty(monitorID)
                monitorID = [];
            end
            
            obj.mexWindowHandle = WindowMex('openWindow');
            
            if ~isempty(monitorID)
                pause(0.1); % weired timing issue: moveToMonitor does not work if window was just opened
                obj.moveToMonitor(monitorID);
            end
        end
        
        function delete(obj)
            WindowMex('close',obj.mexWindowHandle);
        end
        
        function updateBitmap(obj,im,isTransposed)
            if nargin < 3 || isempty(isTransposed)
                isTransposed = false;
            end
            
            if ~isTransposed
                im = im';
            end
            imSize = size(im);
            width = imSize(1);
            height = imSize(2);
            
            % https://msdn.microsoft.com/en-us/library/windows/desktop/dd162974(v=vs.85).aspx
            % The scan lines must be aligned on a DWORD except for RLE-compressed bitmaps.
            assert(mod(width,4)==0 && mod(height,4)==0,'FullScreenDisplay: bitmap width and height must be divisible by 4.');
            
            im = uint8(im);
            WindowMex('updateBitmap',obj.mexWindowHandle,width,height,im(:));
        end
        
        function redraw(obj)
            WindowMex('redraw',obj.mexWindowHandle);
        end
        
        function moveToMonitor(obj,monitorID)
            validateattributes(monitorID,{'numeric'},{'scalar','positive','integer'});
            monitorID = monitorID-1;
            success = WindowMex('moveToMonitor',obj.mexWindowHandle,monitorID);
            if ~success
                most.idioms.warn('Could not move full screen display to monitor %d.',monitorID);
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
