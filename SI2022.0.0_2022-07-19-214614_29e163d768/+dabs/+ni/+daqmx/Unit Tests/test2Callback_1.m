function test1Callback_1()
global CBDATA

'yo'
CBDATA.count = CBDATA.count + 1;


idx = 1;
%%%Put this section in, if using 2 tasks...need this for demo purposes, until we implement passing the task handle as an argument to callback
if ~mod(CBDATA.count,2)
    idx = 2;
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
task = CBDATA.task(idx);
everyNSamples = CBDATA.everyNSamples(idx);

disp(['Visit #' num2str(CBDATA.count) ' to callback']);

[sampsRead, outputData] = readAnalogData(task, everyNSamples, everyNSamples, 'native', 2);
disp(['Read ' num2str(sampsRead) ' samples into a ' num2str(size(outputData,1)) ' X ' num2str(size(outputData,2)) ' matrix of CLASS ''' class(outputData) '''']);
% sampsRead = readAnalogData(CBDATA.task, CBDATA.everyNSamples, CBDATA.everyNSamples, 'scaled', 2);
% disp(['Read ' num2str(sampsRead) ' samples']);

assignin('base','outputData',outputData);




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
