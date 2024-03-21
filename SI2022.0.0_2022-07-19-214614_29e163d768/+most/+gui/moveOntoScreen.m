function moved = moveOntoScreen(hGui)
%MOVEONTOSCREEN move entire gui/figure onto screen so that no parts of
%  the window is outside the monitor boundaries
%
%   hGui: A handle-graphics figure object handle
%
% NOTES
%  only supports moving guis onto primary monitor
%  Todo: implement support for multiple monitors for Matlab 2014b or later using get(0,'MonitorPositions')

oldUnits = get(0,'Units');
set(0,'Units','pixels');
screenSizePx = get(0,'ScreenSize');
set(0,'Units',oldUnits);

oldUnits = get(hGui,'Units');
set(hGui,'Units','pixels');
guiPositionPxOld = get(hGui,'OuterPosition');

guiPositionPxNew = guiPositionPxOld;

%check horizontal position
if guiPositionPxNew(1) < 1
    guiPositionPxNew(1) = 1;
elseif sum(guiPositionPxNew([1,3])) > screenSizePx(3)
    guiPositionPxNew(1) = screenSizePx(3) - guiPositionPxNew(3) + 1;
end

%check vertical position
if sum(guiPositionPxNew([2,4])) > screenSizePx(4)
    guiPositionPxNew(2) = screenSizePx(4) - guiPositionPxNew(4) + 1;
elseif guiPositionPxNew(2) < 1
    guiPositionPxNew(2) = 1;
end

% move the gui
if isequal(guiPositionPxOld,guiPositionPxNew)
    moved = false;
else
    set(hGui,'OuterPosition',guiPositionPxNew);
    moved = true;
end

set(hGui,'Units',oldUnits);
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
