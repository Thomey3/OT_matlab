function JohannesDemo()

%%%%EDIT IF NEEDED%%%%
AIDevice = 'Dev1';
AIChans = 0:1; %Must be 2 channels
AODevice = 'Dev1';
AOChan = 0; %Must be 1 channel

sampleRate = 10e3; %Hz
updatePeriod = 2e-3; %s
%%%%%%%%%%%%%%%%%%%%%%

import dabs.ni.daqmx.*

updatePeriodSamples = round(updatePeriod * sampleRate);

hTask = Task('Johannes Task');
hAOTask = Task('Smart Task');

hTask.createAIVoltageChan(AIDevice,AIChans);
hAOTask.createAOVoltageChan(AODevice,AOChan);

hTask.cfgSampClkTiming(sampleRate,'DAQmx_Val_ContSamps');

hTask.registerEveryNSamplesEvent(@JohannesCallback,updatePeriodSamples);

callbackCounter = 0;

tic;
hAOTask.start();
hTask.start();


    function JohannesCallback(~,~)
        
        callbackCounter = callbackCounter + 1;
        
        inData = readAnalogData(hTask,updatePeriodSamples,'scaled');
        
        %Compute difference between input chans
        meanDifference = mean(inData(:,2)-inData(:,1));
        
        %Output difference value on D/A channel
        hAOTask.writeAnalogData(meanDifference);
        %toc,tic;
        
        %Display difference value, periodically
        if ~mod(callbackCounter ,10)
            fprintf(1,'Mean Difference: %g\n',meanDifference);
        end
        
        %Hard-code ending of Task here...in reality would do this from command-line or application
        if ~mod(callbackCounter ,1000)
            disp('Acquisition done!');
            hTask.stop();
            
            hTask.clear();
            hAOTask.clear();
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
