%Test demonstrating ability to bind independent callbacks to independent Tasks

import Devices.NI.DAQmx.*
global CBDATA

sampleRate = 50000;
everyNSamples = 50000;
acqTime = 5;
task2Multiplier = 10;

hTasks = Task('a task');
hTasks2 = Task('anotherTask');
try
    %hChans = hTask.addAnalogInputChannels('Dev1',0:2);    
    hChans = hTasks.createAIVoltageChan('Dev1',0:2);
    hChans2 = hTasks2.createAIVoltageChan('Dev3',0:1);
    
    %%%Unforutnately, the following doesn't suffice to correctly configure the timing.
    %Basically, I can't figure out how to replicate the DAQmxCfgSampClkTiming macro
%     set(hTask,'sampClkSrc','ai/SampleClockTimebase');
%     set(hTask,'sampClkTimebaseDiv',round(get(hTask,'sampClkTimebaseRate')/sampleRate));
%     set(hTask,'sampClkRate',sampleRate);
%     set(hTask,'sampQuantSampMode','DAQmx_Val_FiniteSamps');    
%     set(hTask,'sampQuantSampPerChan',round(acqTime*sampleRate));
%     %hTask.control('DAQmx_Val_Task_Verify');
    
    %Use the DAQmx 'macro' to configure the timing properties en masse
    hTasks.cfgSampClkTiming(sampleRate,'DAQmx_Val_FiniteSamps',round(sampleRate*acqTime)); 
    hTasks2.cfgSampClkTiming(sampleRate*task2Multiplier,'DAQmx_Val_FiniteSamps',round(sampleRate*acqTime*task2Multiplier));
   
    %Set voltage range explicitly, ensuring same range for all product categories
    set(hTasks.channels,'min',-10);set(hTasks.channels,'max',10);
    set(hTasks2.channels,'min',-10);set(hTasks2.channels,'max',10);    
    
    hTasks.registerEveryNSamplesCallback('test2Callback_1',everyNSamples)
    hTasks2.registerEveryNSamplesCallback('test2Callback_1',everyNSamples*task2Multiplier)
    
    %Start the task
    CBDATA.task = [hTasks hTasks2];
    CBDATA.everyNSamples = [everyNSamples everyNSamples*task2Multiplier];
    CBDATA.count = 0;
    hTasks.start();
    hTasks2.start();
    'Started tasks!'
    
    %Wait till completion
    while true
        tf =  and(hTasks.isDone(),hTasks2.isDone());
        if tf
            'Finished!'
            break;
        else
            'Still Acquiring'
            pause(1);
        end
    end
    
    %Clean up
    hTasks.clear(); %Avoids deleting the System object
    hTasks2.clear(); %Avoids deleting the System object
catch ME
    hTasks.clear();
    hTasks2.clear(); 
    ME.rethrow();
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
