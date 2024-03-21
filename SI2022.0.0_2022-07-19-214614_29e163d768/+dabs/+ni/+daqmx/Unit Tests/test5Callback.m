function test5Callback()

global callbackStruct5

% if callbackStruct5.task.isDone() %Flush excess callbacks. Ideally should find a better way (without clearing Task). Should at least make isTaskDone() a MEX function.
%     return;
% end

%disp(['CPU Time @ Callback Start: ' num2str(cputime())]);
callbackStruct5.stripeCount = callbackStruct5.stripeCount + 1;
disp(['Chunk Count: ' num2str(callbackStruct5.stripeCount)]);

%Read data
tic;
%dataBuffer = ReadRaw(callbackStruct5.task, callbackStruct5.samplesPerStripe,  callbackStruct5.timePerStripe * .8);
[sampsRead, dataBuffer] = callbackStruct5.task.readAnalogData(callbackStruct5.samplesPerStripe, callbackStruct5.samplesPerStripe, 'native', callbackStruct5.timePerStripe * .8);
getTime = toc();
%disp(['Obtained buffer of size ' num2str(size(dataBuffer,1)) ' rows  by ' num2str(size(dataBuffer,2)) 'columns']);

%Stop task, if required
if callbackStruct5.stripeCount >= callbackStruct5.acqTimeStripes
    callbackStruct5.task.stop(); 
end
%     cleanUp = true;
% else
%     cleanUp = false;
% end

%Extract channel data  (data is interleaved)
tic;
channelData = cell(3,1);
for i=1:callbackStruct5.numChannels
    %Doing the following in one step not only reduces the 'Extract Time', but also the 'Get time' variance (?!?)
    %chanIndices = i:callbackStruct5.numChannels:length(dataBuffer);
    %channelData{i} = reshape(sum(reshape(dataBuffer(chanIndices), callbackStruct5.samplesPerPixel, length(chanIndices)/callbackStruct5.samplesPerPixel)), callbackStruct5.pixelsPerLine, callbackStruct5.linesPerStripe)';
    %channelData{i} = reshape(sum(reshape(dataBuffer(i:callbackStruct5.numChannels:end), callbackStruct5.samplesPerPixel, (length(dataBuffer)/(callbackStruct5.numChannels * callbackStruct5.samplesPerPixel)))), callbackStruct5.pixelsPerLine, callbackStruct5.linesPerStripe)';
    if callbackStruct5.samplesPerPixel > 1
        channelData{i} = reshape(sum(reshape(dataBuffer(:,i), callbackStruct5.samplesPerPixel, (length(dataBuffer)/callbackStruct5.samplesPerPixel))), callbackStruct5.pixelsPerLine, callbackStruct5.linesPerStripe)';
    else
        channelData{i} = reshape(dataBuffer(:,i), callbackStruct5.pixelsPerLine, callbackStruct5.linesPerStripe)';
    end
end

computeTime = toc();

%Determine line indices
lineIndices = (1:callbackStruct5.linesPerStripe) + mod(callbackStruct5.stripeCount-1,callbackStruct5.stripesPerFrame)  * callbackStruct5.linesPerStripe;

%Refresh data on plot(s)
tic;
for i=1:callbackStruct5.numChannels
    set(callbackStruct5.imageHandles(i),'CData',channelData{i}, 'YData',lineIndices)
end
plotTime = toc();
drawnow expose;


fprintf(1,'GetTime=%05.2f \t ComputeTime=%05.2f \t PlotTime=%05.2f \t \n',1000*getTime,1000*computeTime,1000*plotTime);    
% %Clean up if needed
% if cleanUp
%     callbackStruct5.task.stop(); %Unfortunately thi
%     %     calllib('nicaiu','DAQmxClearTask', callbackStruct5.task);
%     %     unloadlibrary('nicaiu');
% end




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
