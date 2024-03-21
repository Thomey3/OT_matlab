function Voltage_HW_Timed_Single_Point()
%% Hardware Timed Single Point Voltage Input
% This examples demonstrates a continuous hardware timed single point
% acquisition using the dabs.ni.daqmx adapter
% Use single point acquisition, if every acquired sample needs to be
% processed individually

%% Parameters for the acquisition
devName = 'Dev1'; % the name of the DAQ device as shown in MAX

% Channel configuration
physicalChannels = 0:5; % a scalar or an array with the channel numbers
minVoltage = -10;       % channel input range minimum
maxVoltage = 10;        % channel input range maximum

% Task configuration
sampleClockSource = 'OnboardClock'; % the terminal used for the sample Clock; refer to "Terminal Names" in the DAQmx help for valid values
sampleRate = 1000;                  % sample Rate in Hz

% Trigger configuration
triggerType = 'DigEdgeStartTrig'; % one of {'DigEdgeStartTrig', 'AnlgEdgeStartTrig', 'None'}

% Parameters for digital triggering
dTriggerSource = 'PFI1';           % the terminal used for the digital trigger; refer to "Terminal Names" in the DAQmx help for valid values
dTriggerEdge = 'DAQmx_Val_Rising'; % one of {'DAQmx_Val_Rising', 'DAQmx_Val_Falling'}

% Parameters for analog triggering
aTriggerSource = 'AI1';                  % channel to be monitored for the analog trigger
aTriggerLevel = 5;                       % analog trigger level
aTriggerSlope = 'DAQmx_Val_RisingSlope'; % one of {'DAQmx_Val_RisingSlope', 'DAQmx_Val_FallingSlope'}



import dabs.ni.daqmx.* % import the NI DAQmx adapter

try
    % create and configure the task
    hTask = Task('Task'); 
    hTask.createAIVoltageChan(devName,physicalChannels,[],minVoltage,maxVoltage);
    hTask.cfgSampClkTiming(sampleRate,'DAQmx_Val_HWTimedSinglePoint',1,sampleClockSource);
    
    switch triggerType
        case 'DigEdgeStartTrig'
            hTask.cfgDigEdgeStartTrig(dTriggerSource,dTriggerEdge);
        case 'AnlgEdgeStartTrig'
            hTask.cfgAnlgEdgeStartTrig(aTriggerSource,aTriggerLevel,aTriggerSlope);
        case 'None'
            % do not configure trigger, start acquisition immediately
    end
 
    hTask.start();

    % read and plot the acquired data
    for i=0:1000
        data = hTask.readAnalogData(1,'scaled',5);
        disp(data);
    end
    
    % clean up task 
    hTask.stop();
    delete(hTask);
    clear hTask;
    
    disp('Acquisition Finished');
    
catch err % clean up task if error occurs
    if exist('hTask','var')
        delete(hTask);
        clear hTask;
    end
    rethrow(err);
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
