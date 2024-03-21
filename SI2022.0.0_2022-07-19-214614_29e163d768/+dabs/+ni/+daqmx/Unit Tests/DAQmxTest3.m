
global callbackStruct3
import Devices.NI.DAQmx.*

device = 'Dev1';
sampleRate = 5e6;
acqTime = 3;
pixelsPerLine = 512;
linesPerFrame = 512;
linesPerStripe = 128;
samplesPerPixel = 4; %This determines frame rate
lutLow = 0;
lutHigh = 30; 
numIterations = 2;

dataBufferTime = 3; %Buffering of data

dummyString = repmat('a',[1 512]);
samplesPerStripe = round(pixelsPerLine * linesPerStripe * samplesPerPixel);
samplesPerFrame = samplesPerStripe * (linesPerFrame/linesPerStripe); %Assume that # of stripes is already an integer
timePerFrame = samplesPerFrame / sampleRate;
timePerStripe = samplesPerStripe / sampleRate;
numFrames = round(acqTime*sampleRate/samplesPerFrame);
acqTime =  numFrames * timePerFrame; %Make an integer number of frames
acqTimeStripes = numFrames * (timePerFrame/timePerStripe);
numChannels = 4;

disp(['Frame Rate: ' num2str(1/timePerFrame)]);

hTask = Task('ScanImage Task');
hChans = hTask.createAIVoltageChan(device, 0:3);
for i=1:length(hChans)
    set(hChans(i),'min',-10);
    set(hChans(i),'max',10);
end    
 

hTask.cfgSampClkTiming(sampleRate, 'DAQmx_Val_ContSamps', round(sampleRate * dataBufferTime / samplesPerStripe) * samplesPerStripe);
hTask.registerEveryNSamplesCallback('test3Callback',samplesPerStripe);


%Create structure of info for callback
callbackStruct3.task = hTask;
callbackStruct3.numChannels = numChannels;
callbackStruct3.samplesPerStripe = samplesPerStripe;
callbackStruct3.timePerStripe = timePerStripe;
callbackStruct3.samplesPerPixel = samplesPerPixel;
callbackStruct3.pixelsPerLine = pixelsPerLine;
callbackStruct3.linesPerStripe = linesPerStripe;
callbackStruct3.linesPerFrame = linesPerFrame;
callbackStruct3.stripesPerFrame = linesPerFrame/linesPerStripe; %Should be an integer
callbackStruct3.figHandles = zeros(numChannels,1); 
callbackStruct3.axesHandles = zeros(numChannels,1); 
callbackStruct3.imageHandles = zeros(numChannels,1); 
callbackStruct3.dataBuffer = zeros(samplesPerStripe*numChannels,1,'int16'); %DAta is obtained in int16 format from NI, like it or not
callbackStruct3.sampleRate = sampleRate;
callbackStruct3.stripeCount = 0;   
callbackStruct3.acqTimeStripes = acqTimeStripes;


%Create image figures for data plotting
width = 350;
for i=1:numChannels
    callbackStruct3.figHandles(i) = figure('Colormap',gray(256),'DoubleBuffer','on','MenuBar','none','Name',['Channel ' num2str(i)],'NumberTitle','off','Position',[100+width*(i-1) 400 width width]);
    callbackStruct3.axesHandles(i) = gca;
    callbackStruct3.imageHandles(i) = image('CData',zeros(linesPerFrame, pixelsPerLine, 'uint16'),'CDataMapping','scaled');
    if callbackStruct3.stripesPerFrame == 1
        set(callbackStruct3.imageHandles(i),'EraseMode','normal'); %This gives best performance, and should be used if there's no striping
    else
        set(callbackStruct3.imageHandles(i),'EraseMode','none'); %This must be used if striping is used
    end
    set(callbackStruct3.axesHandles(i),'CLim',[lutLow lutHigh],'Position',[0 0 1 1],'DataAspectRatio',[1 1 1],'XTickLabel',[], 'YTickLabel', [],'XLim',[1 pixelsPerLine],'YLim',[1 linesPerFrame]);
end


%Run through task for specified # of iterations
for i=1:numIterations
    callbackStruct3.stripeCount = 0;   
    disp(['Starting iteration #' num2str(i) '...']);
    hTask.start();
    
    %Wait for task completion
    while ~hTask.isDone() 
        pause(1);
    end    
    
    %hTask.stop(); %This allows Task to be started again
    
    if i < numIterations
        reply = input(['Press any key to start iteration #' num2str(i+1) ', or q to quit: '],'s');
        if strcmpi(strtrim(reply),'q')
            break;
        end
    end
end

hTask.clear();



    




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
