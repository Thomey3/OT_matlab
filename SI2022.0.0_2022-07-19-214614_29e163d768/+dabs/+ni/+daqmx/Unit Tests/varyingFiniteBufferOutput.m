%Demo of alternating generation of different-sized output patterns on same AO Task

%As of 4/16/13: With older boards (e.g. S series), it's sufficient to use
%writeAnalogData() to determine new buffer size after an unreserve
%operation. A subsequent cfgSampClkTiming() call determines the generation
%size.
%
%With newer boards (e.g. X series), however, this fails. This seems related
%to CAR 250524 where writeAnalogData() calls were failing to reconfigure
%the buffer size. That was seemingly fixed as of 9.3, but not fully. When
%the buffer size varies (i.e. the motif size varies), either the output is
%incorrect or you get buffer underflow errors if you don't follow the
%sequence here.



sampleRate = 100000;
bufferTime1 = 1;
bufferTime2 = 2; 
motifTime1 = 0.2;
motifTime2 = 0.1;
motifNumSamples1 = round(sampleRate * motifTime1);
motifNumSamples2 = round(sampleRate * motifTime2);

if ~exist('hTrig') || ~isvalid(hTrig)
    hTrig = dabs.ni.daqmx.Task('Trig Task');
    hTrig.createDOChan('Dev1','/port0/line0');    
end

if ~exist('hAO') || ~isvalid(hAO)
    hAO = dabs.ni.daqmx.Task('Test AO Task');
    hAO.createAOVoltageChan('Dev2',1);
    hAO.cfgDigEdgeStartTrig('PFI0');
    hAO.cfgSampClkTiming(sampleRate,'DAQmx_Val_FiniteSamps',2); %Establish this as a buffered Task
end

%Buf 1
numSamples = round(bufferTime1 * sampleRate);

%X-Series approach
hAO.cfgOutputBuffer(motifNumSamples1);
hAO.cfgSampClkTiming(sampleRate,'DAQmx_Val_FiniteSamps',motifNumSamples1 * round(numSamples/motifNumSamples1));
hAO.writeAnalogData(linspace(0,5,motifNumSamples1)');
fprintf('BufSize: %d\n',get(hAO,'bufOutputBufSize'));

% %S-Series approach
% hAO.writeAnalogData(rand(motifNumSamples1,1));
% hAO.cfgSampClkTiming(sampleRate,'DAQmx_Val_FiniteSamps',get(hAO,'bufOutputBufSize') * round(numSamples/motifNumSamples1));

hAO.start();
hTrig.writeDigitalData(double([0;1;0]));
hAO.waitUntilTaskDone();

hAO.stop();
hAO.control('DAQmx_Val_Task_Unreserve');
pause(0.5);

%Buf 2
numSamples = round(bufferTime2 * sampleRate);

%X-Series approach
hAO.cfgOutputBuffer(motifNumSamples2);
hAO.cfgSampClkTiming(sampleRate,'DAQmx_Val_FiniteSamps',motifNumSamples2 * round(numSamples/motifNumSamples2));
hAO.writeAnalogData(linspace(0,5,motifNumSamples2)');
fprintf('BufSize: %d\n',get(hAO,'bufOutputBufSize'));

% %S-Series approach
% hAO.writeAnalogData(rand(motifNumSamples2,1));
% hAO.cfgSampClkTiming(sampleRate,'DAQmx_Val_FiniteSamps',get(hAO,'bufOutputBufSize') * round(numSamples/motifNumSamples2));

hAO.start();
hTrig.writeDigitalData(double([0;1;0]));
hAO.waitUntilTaskDone();

hAO.stop();
hAO.control('DAQmx_Val_Task_Unreserve');
pause(0.5);

%Buf 1
numSamples = round(bufferTime1 * sampleRate);

%X-Series approach
hAO.cfgOutputBuffer(motifNumSamples1);
hAO.cfgSampClkTiming(sampleRate,'DAQmx_Val_FiniteSamps',motifNumSamples1 * round(numSamples/motifNumSamples1));
hAO.writeAnalogData(linspace(0,5,motifNumSamples2)');
fprintf('BufSize: %d\n',get(hAO,'bufOutputBufSize'));

% %S-Series approach
% hAO.writeAnalogData(rand(motifNumSamples1,1));
% hAO.cfgSampClkTiming(sampleRate,'DAQmx_Val_FiniteSamps',get(hAO,'bufOutputBufSize') * round(numSamples/motifNumSamples1));

hAO.start();
hTrig.writeDigitalData(double([0;1;0]));
hAO.waitUntilTaskDone();

hAO.stop();
hAO.control('DAQmx_Val_Task_Unreserve');
pause(0.5);

%Buf 2
numSamples = round(bufferTime2 * sampleRate);

%X-Series approach
hAO.cfgOutputBuffer(motifNumSamples2);
hAO.cfgSampClkTiming(sampleRate,'DAQmx_Val_FiniteSamps',motifNumSamples2 * round(numSamples/motifNumSamples2));
hAO.writeAnalogData(linspace(0,5,motifNumSamples2)');
fprintf('BufSize: %d\n',get(hAO,'bufOutputBufSize'));

% %S-Series approach
% hAO.writeAnalogData(rand(motifNumSamples2,1));
% hAO.cfgSampClkTiming(sampleRate,'DAQmx_Val_FiniteSamps',get(hAO,'bufOutputBufSize') * round(numSamples/motifNumSamples2));

hAO.start();
hTrig.writeDigitalData(double([0;1;0]));
hAO.waitUntilTaskDone();

hAO.stop();
hAO.control('DAQmx_Val_Task_Unreserve');
pause(0.5);






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
