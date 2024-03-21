function maxRate = daqTaskGetMaxSampleRate(hTask,numChans)
% workaround for bug in DAQmx 9.8.0f3: 'sampClkMaxRate' reports
% faster clock rates for multichannel AOs than supported by
% hardware (observed with PCIe-6321)

% GJ: tested with DAQmx 14.5: bug still exists

if nargin < 2 || isempty(numChans)
    numChans = length(hTask.channels);
end

reportedMaxRate = get(hTask,'sampClkMaxRate');

if isempty(reportedMaxRate)
    maxRate = [];
    return % DAQ Device/Task does not support hardware timed acquisition
end

if ~strcmpi(hTask.taskType,'AnalogOutput')
    % DAQmx reports the correct maximum rate for Analog Inputs
    maxRate = reportedMaxRate;
    return
end

deviceNames = hTask.deviceNames;

maxRates = zeros(1,length(deviceNames));
for idx = 1:length(deviceNames)
    hDevice = dabs.ni.daqmx.Device(deviceNames{idx});
    if ~isempty(strfind(hDevice.productType,'6363'))
        freqMap = containers.Map(...
            {0,   1,        2,   3,      4},...
            {NaN, 2.8571e6, 2e6, 1.54e6, 1.25e6}); % values from NI 6363 spec sheet
        maxRate = freqMap(numChans);
    elseif ~isempty(strfind(hDevice.productType,'6356'))
        maxRate = reportedMaxRate;
    else
        factorMap = containers.Map(...
            {0, 1,  2  ,  3  ,  4  },... % number of channels
            {1, 1, 0.92, 0.85, 0.78});   % reduction factor: these values are safe estimates (actual values may vary from devices to device)
        
        reductionFactor = factorMap(numChans);
        maxRate = reportedMaxRate * reductionFactor;
        
        if numChans>1
            timeBaseRate = get(hTask,'sampClkTimebaseRate');
            fraction = ceil(timeBaseRate/maxRate);
            maxRate = timeBaseRate/fraction; % round to actually achievable rate
        end
    end
    maxRates(idx) = maxRate;
end

maxRate = min(maxRates);

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Communication with NI in Service Request #7414989       %
% NI confirmed bug in Corrective Action Request ID 482143 %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Hardware: PCIe-6321, PXIe-6341
% DAQmx version: 9.8.0f3
% System configuration: see attached MAX Report
% 
% Problem description:
% According to the specifications, the PCIe-632x and PXIe-634x support the following AO sample rates:
% 
% 1 channel: 900 kS/s
% 2 channels: 840 kS/s per channel
% 3 channels: 775 kS/s per channel
% 4 channels: 719 kS/s per channel
% 
% When configuring an AO task with multiple channels on one of these cards, the maximum sample rate of 917431.19 Hz is returned by the property SampClock.MaxRate, regardless of the number of channels within the task.
% 
% If then the sample rate of a task with multiple AO channels is set to the value of SampClock.MaxRate, it will abort with error -200018: 'DAC conversion attempted before data to be converted was available.'
% 
% Expected behavior: SampClock.MaxRate should return the maximum sample rate for the AO task that is actually achievable. (For AI tasks, this works already in DAQmx 9.8)
% Setting a sample clock that is too high should coerce the value to an achievable rate and/or return an error.
% 
% Steps to reproduce:
% Install a PCIe-632x or PXIe-634x. Open the attached VI.
% 1. Run it with one channel -> no error occurs
% 2. Configure 2 channels and start -> error -200018 occurs. Note that the maximum reported sample rate is incorrect (according to the specs)
% 3. Workaround: Set the Sample Clock Reduction Factor to 0.92 and run the task again -> the task should be executable now.




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
