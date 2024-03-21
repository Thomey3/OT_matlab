function test8Callback2()
%   Function called at end of each iteration

global callbackStruct8

%Increment iteration counter
callbackStruct8.iterationCounter2 = callbackStruct8.iterationCounter2 + 1;

%Prepare the data for the next iteration, and start the tasks
if callbackStruct8.iterationCounter2 < callbackStruct8.numIterations
    
    %Stop the tasks -- this is needed so they can be restarted
    callbackStruct8.hCtr(2).stop()
    callbackStruct8.hAI(2).stop();
    callbackStruct8.hAO(2).stop();
    callbackStruct8.hDO(2).stop()
            
    %Determine which signal to draw from during this iteration
    signalIdx = mod(callbackStruct8.iterationCounter2-1,callbackStruct8.numSignals)+1;

    %Write AO data for rig 2 (signals are 2x wrt first)
    callbackStruct8.hAO(2).writeAnalogData(2*callbackStruct8.aoSignals{signalIdx});

    %Write DO data for 2 rigs; 2'nd rig signals are inverted wrt first 
    callbackStruct8.hDO(2).writeDigitalData(uint32(~callbackStruct8.doSignals{signalIdx}));
    
    %Start the tasks so they can await trigger. 
    callbackStruct8.hAI(2).start();
    callbackStruct8.hAO(2).start();
    callbackStruct8.hDO(2).start();
    callbackStruct8.hCtr(2).start()
    
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
