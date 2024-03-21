
%Demo of using CTR Input as means of signalling that a trigger input 
%NOTE: It does not seem possible to have DO Task (hTrigger) signal Done Event on its own. 
%If AutoStart=True, then error -200985 results if a DAQmx event is registered. 
%On other hand, if AutoStart=False, Task does not complete until user specifies StopTask().

import Devices.NI.DAQmx.*

hSys = Devices.NI.DAQmx.System.getHandle();
delete(hSys.tasks);

deviceName = 'Dev1';
sampleRate = 1.25e6;

if ~exist('hDevice') || ~isvalid(hDevice)
    hDevice = Device(deviceName);
end

hTrigger = Task('Trigger Task');
hTrigger.createDOChan(deviceName,'line0');

hAI = Task('AI Task');
hAI.createAIVoltageChan(deviceName,0);
hAI.cfgSampClkTiming(sampleRate,'DAQmx_Val_ContSamps');
hAI.cfgDigEdgeStartTrig('PFI0');

hCtr = Task('Counter Task');
hCtr.createCOPulseChanFreq(deviceName,0,[],hDevice.get('COMaxTimebase')/4); %Not sure best way to directly query the Max CO Frequency
hCtr.cfgImplicitTiming('DAQmx_Val_FiniteSamps',2);
hCtr.cfgDigEdgeStartTrig('PFI0');
hCtr.registerDoneEvent('test10Callback');

while true    
    reply = input('Press any key to start or ''q'' to quit: ', 's');
    if strcmpi(reply,'q')
        break;
    else
        disp('Starting...');
        hAI.start(); 
        hCtr.start();
        hTrigger.writeDigitalData(logical([0;1;0]),inf,true);        
        pause(.1);
        hAI.stop();
        hCtr.stop();
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
