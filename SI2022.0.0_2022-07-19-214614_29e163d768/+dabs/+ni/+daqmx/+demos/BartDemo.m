function BartDemo()

%%%%EDIT IF NEEDED%%%%
devName = 'PXI1Slot3';
aiChans = 0:2;
sampRate = 1000;
everyNSamples = 2000;
acqTime=10; %seconds
%%%%%%%%%%%%%%%%%%%%%%

import dabs.ni.daqmx.*

hTask = Task('Bart Task1');
hTask.createAIVoltageChan(devName,aiChans);

hTask.cfgSampClkTiming(sampRate,'DAQmx_Val_ContSamps');

hTask.registerEveryNSamplesEvent(@BartCallback,everyNSamples);

hTimer = timer('StartDelay',acqTime,'TimerFcn',@timerFcn);

hTask.start();
start(hTimer);

    function BartCallback(~,~)
        persistent hFig
        
        if isempty(hFig)
            hFig = figure;
        end       
        
        d = hTask.readAnalogData(everyNSamples);
        figure(hFig);
        plot(d);
        drawnow expose;                
    end

    function timerFcn(~,~)
        hTask.stop();
        delete(hTask); 
        delete(hTimer);
        disp('All done!');
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
