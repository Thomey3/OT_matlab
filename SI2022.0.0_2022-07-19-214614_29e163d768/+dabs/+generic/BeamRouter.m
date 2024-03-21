classdef BeamRouter < dabs.resources.Device & most.HasMachineDataFile & dabs.resources.configuration.HasConfigPage & dabs.resources.widget.HasWidget
    %% ABSTRACT PROPERTY REALIZATIONS (most.HasMachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'BeamRouter';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
        
        mdfDefault = defaultMdfSection();
    end
    
    properties (SetObservable, AbortSet)
        lastKnownPowerFractions = [];
        lastKnownPowerFractionsBeams = [];
    end
    
    properties (SetAccess=protected,Hidden)
        WidgetClass = 'dabs.resources.widget.widgets.BeamRouterWidget'; 
        ConfigPageClass = 'dabs.resources.configuration.resourcePages.BeamRouterPage';
    end
    
    properties (Hidden, SetAccess = private)
        hListeners = event.listener.empty();
        hDelayedListeners = most.util.DelayedEventListener.empty();
    end
    
    methods (Static, Hidden)
        function names = getDescriptiveNames()
            names = {'Beam Modulator\Beam Router'};
        end
        
        function classes = getClassesToLoadFirst()
            classes = {'dabs.resources.devices.BeamModulator'};
        end
    end
    
    properties
        hBeams = {};
        functionHandle = function_handle.empty();
        functionHandleCalibration = function_handle.empty();
    end
    
    methods
        function obj = BeamRouter(name)
            obj@dabs.resources.Device(name);
            obj@most.HasMachineDataFile(true);
            
            obj.deinit();
            obj.loadMdf();
            obj.reinit();
        end
        
        function delete(obj)
            obj.deinit();
        end
    end
    
    methods
        function deinit(obj)
            obj.errorMsg = 'Uninitialized';
            
            most.idioms.safeDeleteObj(obj.hDelayedListeners);
            obj.hDelayedListeners = most.util.DelayedEventListener.empty();
            
            most.idioms.safeDeleteObj(obj.hListeners);
            obj.hListeners = event.listener.empty();
        end
        
        function reinit(obj)            
            try
                obj.deinit();
                
                for idx = 1:numel(obj.hBeams)
                    hBeam = obj.hBeams{idx};
                    obj.hDelayedListeners(end+1) = most.util.DelayedEventListener(0.2,hBeam,'lastKnownPowerFraction','PostSet',@(varargin)obj.beamFractionChanged);
                    obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(hBeam,'ObjectBeingDestroyed',@(varargin)obj.deinit);
                end
                
                try
                    obj.setUnknownPowerFractions();
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
                
                obj.errorMsg = '';
            catch ME
                obj.deinit();
                obj.errorMsg = sprintf('%s: initialization error: %s',obj.name,ME.message);
                most.ErrorHandler.logError(ME,obj.errorMsg);
            end
        end
    end
    
    methods
        function useExampleFunctions(obj)            
            obj.functionHandle = @dabs.generic.beamrouter.functions.serialBeams;
            obj.functionHandleCalibration = @dabs.generic.beamrouter.calibrations.serialBeamsCalibration;
            
            if numel(obj.hBeams)<1
                hPockels1 = obj.hResourceStore.filterByName('Pockels 1');
                if ~most.idioms.isValidObj(hPockels1)
                    hPockels1 = dabs.generic.BeamModulatorFastAnalog('Pockels 1');
                    hPockels1.feedbackUsesRejectedLight = true;
                end
            else
                hPockels1 = obj.hBeams{1};
            end
            
            if numel(obj.hBeams)<2
                hPockels2 = obj.hResourceStore.filterByName('Pockels 2');
                if ~most.idioms.isValidObj(hPockels2)
                    hPockels2 = dabs.generic.BeamModulatorFastAnalog('Pockels 2');
                    hPockels1.feedbackUsesRejectedLight = false;
                end
            else
                hPockels2 = obj.hBeams{2};
            end
            
            obj.hBeams = {hPockels1,hPockels2};
        end
        
        function setPowerFractionsZero(obj)
            fractions = zeros(1,numel(obj.hBeams));
            obj.setPowerFractions(fractions);
        end
        
        function setPowerFractions(obj,fractions)
            validateattributes(fractions,{'numeric'},{'size',size(obj.hBeams),'>=',0,'<=',1});
            
            routedFractions = obj.route(obj.hBeams,fractions);
            assert(~any(isnan(routedFractions(:))) ...
                ,'Error in function %s: output waveform contains NaNs',func2str(obj.functionHandle));
            assert(all(routedFractions(:)>=0) && all(routedFractions(:)<=1) ...
                ,'Error in function %s: output waveform contains must be in range [0,1]',func2str(obj.functionHandle));
            
            for idx = 1:numel(obj.hBeams)
                hBeam = obj.hBeams{idx};
                fraction = routedFractions(idx);
                hBeam.setPowerFraction(fraction);
            end
            
            obj.lastKnownPowerFractions = fractions;
            obj.lastKnownPowerFractionsBeams = routedFractions;
        end
        
        function beamFractionChanged(obj)
            newBeamPowerFractions = cellfun(@(hB)hB.lastKnownPowerFraction,obj.hBeams);
            
            delta = max(abs(newBeamPowerFractions - obj.lastKnownPowerFractionsBeams));
            
            if delta > 1e-2
                obj.setUnknownPowerFractions();
            end
        end
        
        function setUnknownPowerFractions(obj)
            obj.lastKnownPowerFractions = [];
            obj.lastKnownPowerFractionsBeams = [];
        end
    end
    
    methods
        function waveformOut = route(obj,hBeamsIn,waveformIn)           
            assert(~isempty(obj.functionHandle),'A beam router function has not been configured');
            assert(~isempty(obj.hBeams),'No beam modulators have been paired with this beam router');
            
            beamNamesIn = cellfun(@(hB)hB.name,hBeamsIn,'UniformOutput',false);
            beamNames   = cellfun(@(hB)hB.name,obj.hBeams,'UniformOutput',false);
            
            [Lia,Locb] = ismember(beamNames,beamNamesIn);
            assert(all(Lia),['Not all routed pockels cells are paired with the relevant scanner.\n' ...
                'For the following pockels cell(s), please either pair them with the relevant scanner or deselect them for routing in the beam router:\n\n%s'],strjoin(beamNames(~Lia),'\n'));

            try
                waveform_ = obj.functionHandle(waveformIn(:,Locb),obj.hBeams,obj);
                
                samplesIn = size(waveformIn,1);
                samplesOut = size(waveform_,1);
                ratio = samplesOut/samplesIn;
                assert(~mod(ratio,1),'The new sample buffer length must be an integer multiple of the original number of samples.');
                
                % Alter only routed waveforms. Repeat unrouted if routed
                % waveform takes multiple frames.
                waveformIn = repmat(waveformIn,ratio,1);
                waveformIn(:,Locb) = waveform_;
            catch ME
                most.ErrorHandler.logAndReportError(ME,'%s: error in function ''%s'': %s',func2str(obj.functionHandle),ME.message);
            end
            
            waveformOut = waveformIn;
        end
        
        function calibrate(obj)
            assert(~isempty(obj.functionHandleCalibration),'No valid function handle for calibration specified');
            obj.functionHandleCalibration(obj.hBeams);
        end
        
        function loadMdf(obj)
            success = true;
            success = success & obj.safeSetPropFromMdf('hBeams', 'beams');
            success = success & obj.safeSetPropFromMdf('functionHandle', 'functionHandle');
            success = success & obj.safeSetPropFromMdf('functionHandleCalibration', 'functionHandleCalibration');
            
            if ~success
                obj.errorMsg = 'Error loading config';
            end
        end
        
        function saveMdf(obj)
            obj.safeWriteVarToHeading('beams', resourceCellToNames(obj.hBeams));
            obj.safeWriteVarToHeading('functionHandle', function2Str(obj.functionHandle));
            obj.safeWriteVarToHeading('functionHandleCalibration', function2Str(obj.functionHandleCalibration));
            
            %%% Nested functions
            function names = resourceCellToNames(hResources)
               names = {};
               for idx = 1:numel(hResources)
                   if most.idioms.isValidObj(hResources{idx})
                       names{end+1} = hResources{idx}.name;
                   end
               end
            end
            
            function str = function2Str(fun)
                if isempty(fun)
                    str = '';
                else
                    str = func2str(fun);
                end
            end
        end
    end
    
    methods        
        function set.hBeams(obj,val)
            if isempty(val)
                val = {};
            else
                validateattributes(val,{'cell'},{'row'});
            end
            
            [val,valid] = cellfun(@(v)obj.hResourceStore.filterByName(v),val,'UniformOutput',false);
            val = val([valid{:}]);
            
            if ~isequal(val,obj.hBeams)
                if ~isempty(val)
                    cellfun(@(v)validateattributes(v,{'dabs.resources.devices.BeamModulatorFast'},{'scalar'}),val);
                    names = cellfun(@(v)v.name,val,'UniformOutput',false);
                    [~,ia] = unique(names,'stable');
                    val = val(ia); % filter duplicate entries
                end
                
                cellfun(@(v)v.unregisterUser(obj),obj.hBeams);
                obj.hBeams = val;
                cellfun(@(v)v.registerUser(obj,'Routed Beam'),obj.hBeams);
                
                obj.reinit();
            end
        end
        
        function val = get.hBeams(obj)
            validMask = cellfun(@(hB)most.idioms.isValidObj(hB),obj.hBeams);
            val = obj.hBeams(validMask);
        end
        
        function set.functionHandle(obj,val)
            if ischar(val)
                val = strtrim(val);
            end
            
            if isempty(val)
                val = function_handle.empty();
            end
            
            if ischar(val)
                validateattributes(val,{'char'},{'row'});
                val = str2func(val);
            end
            
            if ~isempty(val)
                validateattributes(val,{'function_handle'},{'scalar'});
            end
            
            obj.functionHandle = val;
        end
        
        function set.functionHandleCalibration(obj,val)
            if ischar(val)
                val = strtrim(val);
            end
            
            if isempty(val)
                val = function_handle.empty();
            end
            
            if ischar(val)
                validateattributes(val,{'char'},{'row'});
                val = str2func(val);
            end
            
            if ~isempty(val)
                validateattributes(val,{'function_handle'},{'scalar'});
            end
            
            obj.functionHandleCalibration = val;
        end
        
        function val = get.lastKnownPowerFractions(obj)
            val = obj.lastKnownPowerFractions;
            if numel(val)~=numel(obj.hBeams)
                val = nan(1,numel(obj.hBeams));
            end
        end
        
        function val = get.lastKnownPowerFractionsBeams(obj)
            val = obj.lastKnownPowerFractionsBeams;
            if numel(val)~=numel(obj.hBeams)
                val = nan(1,numel(obj.hBeams));
            end
        end
    end
end

function s = defaultMdfSection()
s = [...
    most.HasMachineDataFile.makeEntry('beams',{{}},'beam device names')...
    most.HasMachineDataFile.makeEntry('functionHandle','dabs.generic.beamrouter.functions.passThrough','function')...
    most.HasMachineDataFile.makeEntry('functionHandleCalibration','dabs.generic.beamrouter.calibrations.defaultCalibration','function')...
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
