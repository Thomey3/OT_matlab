classdef PolygonalScannerGeneric < dabs.resources.devices.PolygonalScanner & dabs.resources.configuration.HasConfigPage & most.HasMachineDataFile
    %% ABSTRACT PROPERTY REALIZATIONS (most.HasMachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'Polygonal Scanner Generic';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
        
        mdfDefault = defaultMdfSection();
    end
    
    properties (SetAccess = protected,Hidden)
        ConfigPageClass = 'dabs.resources.configuration.resourcePages.PolygonalScannerGenericPage';
    end
    
    methods (Static)
        function names = getDescriptiveNames()
            names = {'Scanner\Generic Polygonal Scanner'};
        end
    end
    
    properties (SetObservable)
        settleTime_s = 5;                %Amount of time to wait before starting acquisition while waiting for the mirror to spin up
        numFacets = 28;                  %Number of facets of polygonal mirror
        nominalFrequency_Hz = 10e3;      %Units of lines per second
        currentCommandedLineRate_Hz = 0; %Commanded line rate - either nominalFrequency_Hz or 0
        currentFrequency_Hz = 0;         %Current frequency as measured by the sync line
        invertEnable = false;
        
        lineRate2ModFreqFunc = @(lineRate)lineRate*1 %function handle taking the line rate in Hz as input and modulation frequency in Hz as output
        
        simulated = true;
    end
    
    properties (SetObservable,AbortSet,SetAccess = private)
        currentAmplitude_deg = 0;
        lastTransitionEvent = tic();
        hFreqTask = dabs.vidrio.ddi.Task.empty();
    end
    
    properties (SetObservable)
        hDOFreq = dabs.resources.ios.DO.empty();
        hDISync = dabs.resources.ios.DI.empty();
        hDOEnable = dabs.resources.ios.DO.empty();
    end
    
    properties (SetAccess = private, GetAccess = private)
        hIOListeners = event.listener.empty(0,1);
    end
    
    properties (Dependent)
        modRate_Hz;
        angularRange_deg;               %Determined by user input number of facets of polygonal mirror
    end
    
    methods
        function obj = PolygonalScannerGeneric(name)
            obj@dabs.resources.devices.PolygonalScanner(name);
            obj = obj@most.HasMachineDataFile(true);
            
            obj.deinit();
            obj.loadMdf();
            obj.reinit();
        end
        
        function delete(obj)
            obj.deinit();
            obj.hDOFreq = dabs.resources.ios.DO.empty();
            obj.hDISync = dabs.resources.ios.DI.empty();
            obj.hDOEnable = dabs.resources.ios.DO.empty();
        end
    end
    
    methods
       
        function loadMdf(obj)
            success = true;
            success = success & obj.safeSetPropFromMdf('hDOFreq', 'DOFreq');
            success = success & obj.safeSetPropFromMdf('hDOEnable', 'DOEnable');
            success = success & obj.safeSetPropFromMdf('invertEnable','invertEnable');
            success = success & obj.safeSetPropFromMdf('hDISync', 'DISync');
            success = success & obj.safeSetPropFromMdf('nominalFrequency_Hz', 'nominalFrequency');
            success = success & obj.safeSetPropFromMdf('settleTime_s', 'settleTime');
                        
            success = success & obj.safeSetPropFromMdf('numFacets', 'numFacets');
            success = success & obj.safeSetPropFromMdf('lineRate2ModFreqFunc', 'lineRate2ModFreqFunc');
            
            if ~success
                obj.errorMsg = 'Error loading config';
            end
        end
        
        function saveMdf(obj)
            obj.safeWriteVarToHeading('DOFreq', obj.hDOFreq);
            obj.safeWriteVarToHeading('DOEnable', obj.hDOEnable);
            obj.safeWriteVarToHeading('invertEnable',obj.invertEnable);
            obj.safeWriteVarToHeading('DISync', obj.hDISync);
            obj.safeWriteVarToHeading('nominalFrequency', obj.nominalFrequency_Hz);
            obj.safeWriteVarToHeading('numFacets', obj.numFacets);
            obj.safeWriteVarToHeading('settleTime',   obj.settleTime_s);
            obj.safeWriteVarToHeading('lineRate2ModFreqFunc', func2str(obj.lineRate2ModFreqFunc));
        end
    end
    
    methods
        function reinit(obj)
            obj.deinit();
            
            try
                assert(~isempty(obj.hDISync),'No sync terminal is defined for the resonant scanner.');
                
                if most.idioms.isValidObj(obj.hDISync)
                    obj.hDISync.reserve(obj);
                    obj.hDISync.tristate();
                end
                                
                if most.idioms.isValidObj(obj.hDOFreq)
                    obj.hDOFreq.reserve(obj);
                    configureFreqTask();
                    obj.currentCommandedLineRate_Hz = 0;
                end
                
                if most.idioms.isValidObj(obj.hDOEnable)
                    obj.hDOEnable.reserve(obj);
                    obj.hDOEnable.setValue(obj.invertEnable); %start in disabled state
                end
                
                obj.errorMsg = '';
            catch ME
                obj.deinit();
                obj.errorMsg = sprintf('initialization error: %s',obj.name,ME.message);
                most.ErrorHandler.logError(ME,obj.errorMsg);
            end
            
            function configureFreqTask()
                taskName = sprintf('%s Control DO task',obj.name);
                obj.hFreqTask = dabs.vidrio.ddi.Task.createDoTask(obj.hDOFreq.hDAQ, taskName);
                obj.hFreqTask.addChannel(obj.hDOFreq);
                
                isSimulatedvDAQ = isa(obj.hDISync.hDAQ, 'dabs.simulated.vDAQR1');
                isSimulatedNI = isprop(obj.hDISync.hDAQ.hDevice, 'isSimulated') && obj.hDISync.hDAQ.hDevice.isSimulated;
                obj.simulated = isSimulatedvDAQ || isSimulatedNI;
                
                modFreq = obj.lineRate2ModFreqFunc(obj.nominalFrequency_Hz);
                    
                if ~obj.simulated
                    %NI DO tasks will produce below error unless buffer
                    %is upsampled.
                    %  NI DAQmx error (-200621) in call to API function 'DAQmxIsTaskDone':
                    %  Onboard device memory underflow. Because of system and/or bus-bandwidth limitations,
                    %  the driver could not write data to the device fast enough to keep up with the device
                    %  output rate.
                    % Reduce your sample rate. If your data transfer method is interrupts, try using DMA or
                    % USB Bulk. You can also reduce the number of programs your computer is executing
                    % concurrently.

                    sampleBuffer = zeros(10000,1);
                    sampleBuffer(1:2:end) = 1;

                    obj.hFreqTask.writeOutputBuffer(sampleBuffer);
                    obj.hFreqTask.sampleRate = 2 * modFreq;
                    obj.hFreqTask.sampleMode = 'continuous';
                end
            end
        end
        
        function deinit(obj)
            try
                obj.setLineRate_Hz(0);
            catch
            end
            
            obj.errorMsg = 'Uninitialized';
            
            delete(obj.hIOListeners);
            obj.hIOListeners = event.listener.empty(0,1);

            if most.idioms.isValidObj(obj.hFreqTask)
                try
                obj.hFreqTask.abort();
                catch
                end
                most.idioms.safeDeleteObj(obj.hFreqTask)
            end
            
            if most.idioms.isValidObj(obj.hDOFreq)
                obj.hDOFreq.unreserve(obj);
            end
            
            if most.idioms.isValidObj(obj.hDOEnable)
                try
                    obj.hDOEnable.tristate();
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
                obj.hDOEnable.unreserve(obj);
            end
            
            if most.idioms.isValidObj(obj.hDISync)
                obj.hDISync.unreserve(obj);
            end
        end
    end
    
    methods
        function setLineRate_Hz(obj, lineRate)
            obj.assertNoError();

            if obj.simulated
                obj.currentCommandedLineRate_Hz = lineRate;
                
                if ~isempty(obj.hDOEnable) && most.idioms.isValidObj(obj.hDOEnable)
                    enable = obj.currentCommandedLineRate_Hz > 0;
                    outputState = xor(enable,obj.invertEnable);
                    obj.hDOEnable.setValue(outputState);
                end
                
                return;
            end
            
            needsUpdate = false;
            if nargin < 2
                most.idioms.warn('%s''s setLineRate_Hz function requires line rate [Hz] as an input argument.');
                return;
            elseif lineRate ~= obj.currentCommandedLineRate_Hz
                needsUpdate = true;
                obj.currentCommandedLineRate_Hz = lineRate;
            end
            
            if ~isempty(obj.hDOEnable) && most.idioms.isValidObj(obj.hDOEnable)
                enable = obj.currentCommandedLineRate_Hz > 0;
                outputState = xor(enable,obj.invertEnable); 
                obj.hDOEnable.setValue(outputState);
            end
            
            if most.idioms.isValidObj(obj.hDOFreq) && most.idioms.isValidObj(obj.hFreqTask) && needsUpdate
                newModFreq_Hz = obj.modRate_Hz; %trigger get method
                
                obj.hFreqTask.abort();
                if newModFreq_Hz > 0
                    obj.hFreqTask.sampleRate = 2 * newModFreq_Hz;
                    obj.hFreqTask.start();
                else
                    obj.hDOFreq.setValue(false);
                end
                
                obj.lastTransitionEvent = tic();
            end
        end
        
        function waitSettlingTime(obj)
            while toc(obj.lastTransitionEvent) < obj.settleTime_s
                pause(0.001);
            end
        end   
        
        function disable(obj)
            obj.setLineRate_Hz(0);
            
            if most.idioms.isValidObj(obj.hDOEnable)
                outputState = obj.invertEnable;
                obj.hDOEnable.setValue(outputState);
            end
        end
    end
    
    %% Property Getter/Setter
    methods
        function modRate_Hz = get.modRate_Hz(obj)
            modRate_Hz = obj.lineRate2ModFreqFunc(obj.currentCommandedLineRate_Hz);
        end
        
        function set.settleTime_s(obj,val)
            validateattributes(val,{'numeric'},{'nonnegative','scalar','finite','nonnan','real'});
            obj.settleTime_s = val;
        end
        
        function set.currentCommandedLineRate_Hz(obj,val)
            validateattributes(val,{'numeric'},{'nonnegative','scalar','finite','nonnan','real'});
            obj.currentCommandedLineRate_Hz = val;
        end
        
        function set.currentFrequency_Hz(obj,val)
            validateattributes(val,{'numeric'},{'nonnegative','scalar','finite','nonnan','real'});
            obj.currentFrequency_Hz = val;
        end
        
        function set.nominalFrequency_Hz(obj,val)
            validateattributes(val,{'numeric'},{'positive','scalar','finite','nonnan','real'});
            obj.nominalFrequency_Hz = val;
        end
        
        function angularRange_deg = get.angularRange_deg(obj)
            angularRange_deg = 2*360/obj.numFacets;
        end
        
        function set.hDOFreq(obj,val)
            val = obj.hResourceStore.filterByName(val);
            
            if isempty(val)
                val = dabs.resources.ios.DO.empty();
            end
            
            if ~isequal(val,obj.hDOFreq)
                if most.idioms.isValidObj(val)
                    validateattributes(val,{'dabs.resources.ios.DO' 'dabs.resources.ios.PFI'},{'scalar'});
                end

                obj.deinit();
                obj.hDOFreq.unregisterUser(obj);
                obj.hDOFreq = val;
                obj.hDOFreq.registerUser(obj,'Frequency Control');
            end
        end
        
        function set.hDISync(obj,val)
            val = obj.hResourceStore.filterByName(val);
            
            if ~isequal(val,obj.hDISync)
                if most.idioms.isValidObj(val)
                    validateattributes(val,{'dabs.resources.ios.DI','dabs.resources.ios.PFI'},{'scalar'});
                end
                
                obj.deinit();
                obj.hDISync.unregisterUser(obj);
                obj.hDISync = val;
                obj.hDISync.registerUser(obj,'Sync');
            end
        end
        
        function set.hDOEnable(obj,val)
            val = obj.hResourceStore.filterByName(val);
            
            if isempty(val)
                val = dabs.resources.ios.DO.empty();
            end
            
            if ~isequal(val,obj.hDOEnable)
                if most.idioms.isValidObj(val)
                    validateattributes(val,{'dabs.resources.ios.DO','dabs.resources.ios.PFI'},{'scalar'});
                end
                
                obj.deinit();
                obj.hDOEnable.unregisterUser(obj);
                obj.hDOEnable = val;
                obj.hDOEnable.registerUser(obj,'Enable');
            end
        end
        
        function set.invertEnable(obj, val)
            validateattributes(val,{'logical'},{'scalar'});
            obj.invertEnable = val;
        end
        
        function set.lineRate2ModFreqFunc(obj, val)
            if ischar(val)
                val = str2func(val);
            end
            
            validateattributes(val,{'function_handle'},{'scalar'});
            
            obj.lineRate2ModFreqFunc = val;
        end
        
        function set.numFacets(obj,val)
            validateattributes(val,{'numeric'},{'positive','scalar','integer'});
            obj.numFacets = val;
        end
        
        function currentAmplitude_deg = get.currentAmplitude_deg(obj)
            hSI = obj.hResourceStore.filterByName('ScanImage');
            if ~isempty(hSI)
                if obj.currentFrequency_Hz > 0
                    currentAmplitude_deg = obj.angularRange_deg * hSI.hScan2D.fillFractionSpatial;
                else
                    currentAmplitude_deg = 0;
                end
            end
        end
    end
end

function s = defaultMdfSection()
s = [...
    most.HasMachineDataFile.makeEntry('DOFreq' ,'','zoom control terminal  e.g. ''/vDAQ0/AO0''')...
    most.HasMachineDataFile.makeEntry('DOEnable','','digital enable terminal e.g. ''/vDAQ0/D0.1''')...
    most.HasMachineDataFile.makeEntry('invertEnable',false,'Invert logic of digital output assigned for DOEnable, e.g. true/false')...
    most.HasMachineDataFile.makeEntry('DISync','','digital sync terminal e.g. ''/vDAQ0/D0.0''')...
    most.HasMachineDataFile.makeEntry()... % blank line
    most.HasMachineDataFile.makeEntry('nominalFrequency',10e3,'nominal resonant frequency in Hz')...
    most.HasMachineDataFile.makeEntry('numFacets',28,'total angular range in optical degrees (e.g. for a resonant scanner with -13..+13 optical degrees, enter 26)')...
    most.HasMachineDataFile.makeEntry('settleTime',5,'settle time in seconds to allow the resonant scanner to turn on')...
    most.HasMachineDataFile.makeEntry()... % blank line
    most.HasMachineDataFile.makeEntry('lineRate2ModFreqFunc','@(lineRate)lineRate*1','stringified function handle to calculate the mod frequency given the nominal line rate. E.g. "@(f)f^2"')...
    most.HasMachineDataFile.makeEntry()... % blank line
    most.HasMachineDataFile.makeEntry('Calibration Settings')... % comment only
    most.HasMachineDataFile.makeEntry('amplitudeToLinePhaseMap',[],'translates an amplitude (degrees) to a line phase (seconds)')...
    most.HasMachineDataFile.makeEntry('amplitudeToFrequencyMap',[],'translates an amplitude (degrees) to a resonant frequency (Hz)')...
    most.HasMachineDataFile.makeEntry('amplitudeLUT',[],'translates a nominal amplitude (degrees) to an output amplitude (degrees)')...
    ];
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
