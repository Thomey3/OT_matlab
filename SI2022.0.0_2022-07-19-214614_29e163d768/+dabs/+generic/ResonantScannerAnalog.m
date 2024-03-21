classdef ResonantScannerAnalog < dabs.resources.devices.ResonantScanner & dabs.resources.configuration.HasConfigPage & most.HasMachineDataFile
    %% ABSTRACT PROPERTY REALIZATIONS (most.HasMachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'Resonant Analog';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
        
        mdfDefault = defaultMdfSection();
    end
    
    properties (SetAccess = protected,Hidden)
        ConfigPageClass = 'dabs.resources.configuration.resourcePages.ResonantAnalogPage';
    end
    
    methods (Static)
        function names = getDescriptiveNames()
            names = {'Scanner\Resonant Scanner'};
        end
    end
    
    properties (SetObservable)
        settleTime_s = 0.5;
        angularRange_deg = 26;
        nominalFrequency_Hz = 7910;
        currentFrequency_Hz = 0;
        
        voltsPerOpticalDegrees = 0.1923;
    end
    
    properties (SetObservable,AbortSet,SetAccess = private)
        currentAmplitude_deg = 0;
        lastWrittenOutput_V = 0;
        lastTransitionEvent = tic();
    end
    
    properties (SetObservable)
        hAOZoom = dabs.resources.Resource.empty();
        hDISync = dabs.resources.Resource.empty();
        hDOEnable = dabs.resources.Resource.empty();
    end
    
    properties (SetAccess = private, GetAccess = private)
        hIOListeners = event.listener.empty(0,1);
    end
    
    methods
        function obj = ResonantScannerAnalog(name)
            obj@dabs.resources.devices.ResonantScanner(name);
            obj = obj@most.HasMachineDataFile(true);
            
            obj.deinit();
            obj.loadMdf();
            obj.reinit();
        end
        
        function delete(obj)
            obj.deinit();
            obj.hAOZoom = [];
            obj.hDISync = [];
            obj.hDOEnable = [];
            obj.saveCalibration();
        end
    end
    
    methods
        function saveCalibration(obj)
            obj.safeWriteVarToHeading('amplitudeToLinePhaseMap', obj.amplitudeToLinePhaseMap);
            obj.safeWriteVarToHeading('amplitudeToFrequencyMap', obj.amplitudeToFrequencyMap);
            obj.safeWriteVarToHeading('amplitudeLUT',            obj.amplitudeLUT);
        end
        
        function success = loadCalibration(obj)
            success = true;
            success = success & obj.safeSetPropFromMdf('amplitudeToLinePhaseMap', 'amplitudeToLinePhaseMap');
            success = success & obj.safeSetPropFromMdf('amplitudeToFrequencyMap', 'amplitudeToFrequencyMap');
            success = success & obj.safeSetPropFromMdf('amplitudeLUT', 'amplitudeLUT');
        end
        
        function loadMdf(obj)
            success = true;
            success = success & obj.safeSetPropFromMdf('hAOZoom', 'AOZoom');
            success = success & obj.safeSetPropFromMdf('hDOEnable', 'DOEnable');
            success = success & obj.safeSetPropFromMdf('hDISync', 'DISync');
            
            success = success & obj.safeSetPropFromMdf('nominalFrequency_Hz', 'nominalFrequency');
            success = success & obj.safeSetPropFromMdf('angularRange_deg', 'angularRange');
            success = success & obj.safeSetPropFromMdf('voltsPerOpticalDegrees', 'voltsPerOpticalDegrees');
            success = success & obj.safeSetPropFromMdf('settleTime_s', 'settleTime');
            
            success = success & obj.loadCalibration();
            
            if ~success
                obj.errorMsg = 'Error loading config';
            end
        end
        
        function saveMdf(obj)
            obj.safeWriteVarToHeading('AOZoom', obj.hAOZoom);
            obj.safeWriteVarToHeading('DOEnable', obj.hDOEnable);
            obj.safeWriteVarToHeading('DISync', obj.hDISync);
            
            obj.safeWriteVarToHeading('nominalFrequency', obj.nominalFrequency_Hz);
            obj.safeWriteVarToHeading('voltsPerOpticalDegrees', obj.voltsPerOpticalDegrees);
            obj.safeWriteVarToHeading('angularRange', obj.angularRange_deg);
            obj.safeWriteVarToHeading('settleTime',   obj.settleTime_s);
            
            obj.saveCalibration();
        end
    end
    
    methods
        function reinit(obj)
            obj.deinit();
            
            try
                assert(~isempty(obj.hDISync),'No sync terminal is defined for the resonant scanner.');
                assert(~isempty(obj.hAOZoom),'No analog output for controlling the resonant scanner amplitude is defined.');
                
                if most.idioms.isValidObj(obj.hDISync)
                    obj.hDISync.reserve(obj);
                    obj.hDISync.tristate();
                end
                
                if most.idioms.isValidObj(obj.hAOZoom)
                    obj.hAOZoom.reserve(obj);
                    obj.hIOListeners = most.ErrorHandler.addCatchingListener(obj.hAOZoom,'lastKnownValueChanged',@(varargin)obj.updateLastWrittenOutput);
                end
                
                if most.idioms.isValidObj(obj.hDOEnable)
                    obj.hDOEnable.reserve(obj);
                    obj.hIOListeners = most.ErrorHandler.addCatchingListener(obj.hDOEnable,'lastKnownValueChanged',@(varargin)obj.updateLastWrittenOutput);
                end
                
                obj.errorMsg = '';
            catch ME
                obj.deinit();
                obj.errorMsg = sprintf('%s: initialization error: %s',obj.name,ME.message);
                most.ErrorHandler.logError(ME,obj.errorMsg);
            end
        end
        
        function deinit(obj)
            try
                obj.setAmplitude(0);
            catch
            end
            
            obj.errorMsg = 'Uninitialized';
            
            delete(obj.hIOListeners);
            obj.hIOListeners = event.listener.empty(0,1);
            
            if most.idioms.isValidObj(obj.hAOZoom)
                obj.hAOZoom.unreserve(obj);
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
        function setAmplitude(obj,degrees_pp)
            validateattributes(degrees_pp,{'numeric'}...
                ,{'scalar','nonnegative','real','finite','nonnan','<=',obj.angularRange_deg*1.1});
            
            if most.idioms.isValidObj(obj.hDOEnable)
                enable = degrees_pp > 0;
                obj.hDOEnable.setValue(enable);
            end
            
            if most.idioms.isValidObj(obj.hAOZoom)
                oldOutput_V = obj.lastWrittenOutput_V;
                output_V = obj.deg2Volt(degrees_pp);
                
                obj.hAOZoom.setValue(output_V);
                
                if output_V>0 && abs(oldOutput_V-output_V)>1e-3
                    obj.lastTransitionEvent = tic();
                end
                
                obj.currentAmplitude_deg = degrees_pp;
                
                if output_V > 0
                    obj.currentFrequency_Hz = obj.estimateFrequency(obj.currentAmplitude_deg);
                end
            end
        end
        
        function waitSettlingTime(obj)
            while toc(obj.lastTransitionEvent) < obj.settleTime_s
                pause(0.001);
            end
        end
        
        function V = deg2Volt(obj,degrees_pp)
            degrees_pp = obj.lookUpAmplitude(degrees_pp);
            V = degrees_pp * obj.voltsPerOpticalDegrees;
        end
        
        function degrees_pp = volt2deg(obj,V)
            degrees_pp = V / obj.voltsPerOpticalDegrees;
            
            reverse = true;
            degrees_pp = obj.lookUpAmplitude(degrees_pp,reverse);
        end            
    end
    
    methods (Hidden)
        function updateLastWrittenOutput(obj)
            if ~most.idioms.isValidObj(obj.hAOZoom)
                return
            end
            
            obj.lastWrittenOutput_V = obj.hAOZoom.lastKnownValue;
            currentAmplitude_deg_ = obj.volt2deg(obj.lastWrittenOutput_V);
            
            if most.idioms.isValidObj(obj.hDOEnable)
                currentAmplitude_deg_ = currentAmplitude_deg_ * obj.hDOEnable.lastKnownValue;
            end
            
            obj.currentAmplitude_deg = currentAmplitude_deg_;
        end
    end
    
    %% Property Getter/Setter
    methods
        function set.settleTime_s(obj,val)
            validateattributes(val,{'numeric'},{'nonnegative','scalar','finite','nonnan','real'});
            obj.settleTime_s = val;
        end
        
        function set.currentFrequency_Hz(obj,val)
            validateattributes(val,{'numeric'},{'nonnegative','scalar','finite','nonnan','real'});
            obj.currentFrequency_Hz = val;
        end
        
        function set.nominalFrequency_Hz(obj,val)
            validateattributes(val,{'numeric'},{'positive','scalar','finite','nonnan','real'});
            
            % reset the amplitude to frequency map when the nominal frequency changes
            if (val ~= obj.nominalFrequency_Hz)
                obj.amplitudeToFrequencyMap = zeros(0,2);
            end
            
            obj.nominalFrequency_Hz = val;
            obj.currentFrequency_Hz = val;
        end
        
        function set.angularRange_deg(obj,val)
            validateattributes(val,{'numeric'},{'positive','scalar','finite','nonnan','real'});
            obj.angularRange_deg = val;
        end
        
        function set.voltsPerOpticalDegrees(obj,val)
            validateattributes(val,{'numeric'},{'scalar','finite','nonnan','real'});
            obj.voltsPerOpticalDegrees = val;
        end
        
        function set.hAOZoom(obj,val)
            val = obj.hResourceStore.filterByName(val);
            
            if ~isequal(val,obj.hAOZoom)
                if most.idioms.isValidObj(val)
                    validateattributes(val,{'dabs.resources.ios.AO'},{'scalar'});
                end

                obj.deinit();
                obj.hAOZoom.unregisterUser(obj);
                obj.hAOZoom = val;
                obj.hAOZoom.registerUser(obj,'Zoom Control');
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
    end
end

function s = defaultMdfSection()
s = [...
    most.HasMachineDataFile.makeEntry('AOZoom' ,'','zoom control terminal  e.g. ''/vDAQ0/AO0''')...
    most.HasMachineDataFile.makeEntry('DOEnable','','digital enable terminal e.g. ''/vDAQ0/D0.1''')...
    most.HasMachineDataFile.makeEntry('DISync','','digital sync terminal e.g. ''/vDAQ0/D0.0''')...
    most.HasMachineDataFile.makeEntry()... % blank line
    most.HasMachineDataFile.makeEntry('nominalFrequency',7910,'nominal resonant frequency in Hz')...
    most.HasMachineDataFile.makeEntry('angularRange',26,'total angular range in optical degrees (e.g. for a resonant scanner with -13..+13 optical degrees, enter 26)')...
    most.HasMachineDataFile.makeEntry('voltsPerOpticalDegrees',0.1923,'volts per optical degrees for the control signal')...
    most.HasMachineDataFile.makeEntry('settleTime',0.5,'settle time in seconds to allow the resonant scanner to turn on')...
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
