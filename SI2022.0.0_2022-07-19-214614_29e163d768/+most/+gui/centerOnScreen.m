function centerOnScreen(hFig)
    drawnow(); % required to get correct figure size

    oldFigUnits = hFig.Units;
    hFig.Units = 'pixels';

    oldRootUnits = get(0,'Units');
    set(0,'Units','pixels');

    pos = hFig.Position;
    center = [2*pos(1)+pos(3) 2*pos(2)+pos(4)]/2;

    mpos = get(0,'MonitorPositions');

    onMonitor = center(1) >= mpos(:,1) & center(1)<=mpos(:,1)+mpos(:,3) ...
              & center(2) >= mpos(:,2) & center(2)<=mpos(:,2)+mpos(:,4);

    if ~any(onMonitor)
        onMonitor(1) = 1;
    end

    mpos = mpos(onMonitor,:);

    mposCenter = [2*mpos(1)+mpos(3) 2*mpos(2)+mpos(4)]/2;


    pos(1) = mposCenter(1)-pos(3)/2;
    pos(2) = mposCenter(2)-pos(4)/2;

    hFig.Position = pos;

    hFig.Units = oldFigUnits;
    set(0,'Units',oldRootUnits);
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
