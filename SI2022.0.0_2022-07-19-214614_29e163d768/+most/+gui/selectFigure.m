function h = selectFigure(figHandles)
%Allows user a few seconds to select a valid ScanImage image figure to interact with

%Create dummy figure/axes to divert gcf/gca
hf = most.idioms.figure('Visible','off');
axes('Parent',hf);

selTimer = timer('Name','selectFigure','TimerFcn',@nstTimerFcn,'StartDelay',5);
start(selTimer);

aborted = false;
while ~aborted      
	drawnow
    currFig = get(0,'CurrentFigure');
    [tf,loc] = ismember(currFig,figHandles);
    if tf
%         hAx = get(currFig,'CurrentAxes');
%         if loc <= state.init.maximumNumberOfInputChannels
%             chan = loc;
%         end
%         hIm = findobj(hAx,'Type','image'); %VI051310A
        h = currFig;
        break;
    end     
    pause(0.2);
end

if aborted
    h = [];
end

%Clean up
delete(hf);
stop(selTimer);
delete(selTimer);

    function nstTimerFcn(~,~)
        disp('aborting');
        aborted = true;        
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
