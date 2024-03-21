function DaqmxAsyncWriteDemo
    global hTask;
    global taskReadyForNewWrite;
    taskReadyForNewWrite = true;
    hTask = dabs.ni.daqmx.Task();
    hTask.createAOVoltageChan('Dev1',0);
    hTask.cfgSampClkTiming(1000,'DAQmx_Val_ContSamps');
    hTask.writeAnalogData(rand(10000,1),[],[],[]);
    hTask.start();
    
    hTimer = timer();
    hTimer.TimerFcn = @writeNewData;
    hTimer.Period = 0.5;
    hTimer.ExecutionMode = 'fixedSpacing';
    
    start(hTimer);
    assignin('base','hTimer',hTimer);
    assignin('base','hTask',hTask);
end

function writeNewData(src,evt)
    global taskReadyForNewWrite
    global hTask
    if taskReadyForNewWrite
       taskReadyForNewWrite = false;
       start = tic;
       hTask.writeAnalogDataAsync(rand(5000,1),[],[],[],@callback);
       fprintf('Timer is sending new data: (took %fs)\n',toc(start));
    end
end


function callback(src,evt)
    global taskReadyForNewWrite
    sampsWritten = evt.sampsWritten;
    status = evt.status;
    errorString = evt.errorString;
    extendedErrorInfo = evt.extendedErrorInfo;
    
    fprintf('Task %d refreshed %d samples\n',src.taskID,sampsWritten);
    if status
        fprintf(2,'writeAnalogData encountered an error: %d\n%s\n=============================\n%s\n',status,errorString,extendedErrorInfo);
    else
        taskReadyForNewWrite = true;
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
