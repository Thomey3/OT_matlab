classdef PMTAnalog < dabs.resources.devices.PMT & dabs.resources.configuration.HasConfigPage & most.HasMachineDataFile
    properties (SetAccess=protected,Hidden)
        ConfigPageClass = 'dabs.resources.configuration.resourcePages.GenericPmtPage';
    end
    
    methods (Static)
        function names = getDescriptiveNames()
            names = {'PMT\Analog PMT Controller'};
        end
    end
    
    %%% ABSTRACT PROPERTY REALIZATIONS (most.HasMachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'PMT';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
        
        mdfDefault = defaultMdfSection();
    end
    
    properties
        hAOGain = dabs.resources.Resource.empty();
        hDOPower = dabs.resources.Resource.empty();
        hDITripDetect = dabs.resources.Resource.empty();
        hDOTripReset = dabs.resources.Resource.empty();
    end
    
    properties (SetAccess=protected, AbortSet, SetObservable)
        powerOn = false;
        gain_V = 0;
        bandwidth_Hz = 0;
        gainOffset_V = 0;
    end
    
    properties
        aoRange_V = [0 5];
        pmtSupplyRange_V = [0 1250];
    end
    
    properties (SetAccess = protected, Hidden)
        lastQuery = tic();
    end
    
    properties (SetAccess=protected, SetObservable, AbortSet)
        tripped = false;
    end
    
    properties (SetAccess=private, GetAccess=private)
        hIOListeners = event.listener.empty(0,1);
    end
    
    %% FRIEND PROPS    
    properties (Hidden, SetAccess = private)
    end
    
    methods 
        function obj = PMTAnalog(name)
            obj@dabs.resources.devices.PMT(name);
            obj = obj@most.HasMachineDataFile(true);
            
            obj.deinit();
            obj.loadMdf();
            obj.reinit();
        end
        
        function delete(obj)
            try
                obj.setPower(false);
                obj.saveCalibration();
                obj.deinit();
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
        end
        
        function deinit(obj)
            try
                delete(obj.hIOListeners);
                obj.hIOListeners = event.listener.empty(0,1);
                
                try
                    obj.setPower(0);
                end
                
                if most.idioms.isValidObj(obj.hAOGain)
                    obj.hAOGain.unreserve(obj);
                end
                
                if most.idioms.isValidObj(obj.hDOPower)
                    try
                        obj.hDOPower.tristate();
                    catch ME
                        most.ErrorHandler.logAndReportError(ME);
                    end
                    obj.hDOPower.unreserve(obj);
                end
                
                if most.idioms.isValidObj(obj.hDITripDetect)
                    obj.hDITripDetect.unreserve(obj);
                end
                
                if most.idioms.isValidObj(obj.hDOTripReset)
                    try
                        obj.hDOTripReset.tristate();
                    catch ME
                        most.ErrorHandler.logAndReportError(ME);
                    end
                    obj.hDOTripReset.unreserve(obj);
                end
                
                obj.errorMsg = 'uninitialized';
            catch ME
                most.ErrorHandler.logAndReportError(ME);
                obj.errorMsg = sprintf('Error deinitializing: %s',ME.message);
            end
        end
        
        function reinit(obj)
            obj.deinit();
            
            try
                if most.idioms.isValidObj(obj.hAOGain)
                    obj.hAOGain.reserve(obj);
                end
                
                if most.idioms.isValidObj(obj.hDOPower)
                    obj.hDOPower.reserve(obj);
                end
                
                if most.idioms.isValidObj(obj.hDITripDetect)
                    obj.hDITripDetect.reserve(obj);
                    obj.hDITripDetect.tristate();
                    obj.hIOListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hDITripDetect,'lastKnownValueChanged',@(varargin)obj.updateTripped);
                end
                
                if most.idioms.isValidObj(obj.hDOTripReset)
                    obj.hDOTripReset.reserve(obj);
                end
                
                obj.errorMsg = '';
                
                obj.resetTrip();
                obj.setPower(obj.powerOn);
                obj.setGain(obj.gain_V);
            catch ME
                obj.deinit();
                obj.errorMsg = sprintf('%s: initialization error: %s',obj.name,ME.message);
                most.ErrorHandler.logError(ME,obj.errorMsg);
            end
        end
    end
    
    %% MDF methods
    methods
        function loadMdf(obj)
            success = true;
            success = success & obj.safeSetPropFromMdf('hAOGain', 'AOGain');
            success = success & obj.safeSetPropFromMdf('hDOPower', 'DOPower');
            success = success & obj.safeSetPropFromMdf('hDITripDetect', 'DITripDetect');
            success = success & obj.safeSetPropFromMdf('hDOTripReset', 'DOTripReset');
            success = success & obj.safeSetPropFromMdf('aoRange_V', 'AOOutputRange');
            success = success & obj.safeSetPropFromMdf('pmtSupplyRange_V', 'SupplyVoltageRange');
            
            success = success & obj.loadCalibration();
            
            if ~success
                obj.errorMsg = 'Error loading config';
            end
        end
        
        function success = loadCalibration(obj)
            success = true;
            success = success & obj.safeSetPropFromMdf('autoOn', 'autoOn');
            success = success & obj.safeSetPropFromMdf('wavelength_nm', 'wavelength_nm');
            success = success & safeSetGain();
            
            
            function success = safeSetGain()
                success = true;
                try
                    obj.gain_V = obj.mdfData.gain_V;
                catch
                    success = false;
                end
            end
        end
        
        function saveMdf(obj)
            obj.safeWriteVarToHeading('AOGain', obj.hAOGain);
            obj.safeWriteVarToHeading('DOPower', obj.hDOPower);
            obj.safeWriteVarToHeading('DITripDetect', obj.hDITripDetect);
            obj.safeWriteVarToHeading('DOTripReset', obj.hDOTripReset);
            obj.safeWriteVarToHeading('AOOutputRange', obj.aoRange_V);
            obj.safeWriteVarToHeading('SupplyVoltageRange', obj.pmtSupplyRange_V);
            
            obj.saveCalibration();
        end
        
        function saveCalibration(obj)
            obj.safeWriteVarToHeading('autoOn', obj.autoOn);
            obj.safeWriteVarToHeading('wavelength_nm', obj.wavelength_nm);
            obj.safeWriteVarToHeading('gain_V', obj.gain_V);
        end
    end
    
    methods
        function setPower(obj,val)
            validateattributes(val,{'logical','numeric'},{'scalar','binary'});
            val = logical(val);
            
            if most.idioms.isValidObj(obj.hDOPower)
                    obj.hDOPower.setValue(val && ~obj.tripped);
            end
            
            obj.powerOn = val;
            obj.setGain(obj.gain_V);
        end
        
        function setGain(obj,val)
            validateattributes(val,{'numeric'},{'scalar','nonnegative','finite','nonnan','real'});
            
            if most.idioms.isValidObj(obj.hAOGain)
                if obj.powerOn && ~obj.tripped
                    val = max(min(val,max(obj.pmtSupplyRange_V)),min(obj.pmtSupplyRange_V));
                    val_ao = interp1(obj.pmtSupplyRange_V,obj.aoRange_V,val,'linear');
                else
                    val_ao = obj.aoRange_V(1);
                end
                obj.hAOGain.setValue(val_ao);
            else
                val = 0;
            end
            
            obj.gain_V = val;
        end
        
        function setGainOffset(obj,val)
            % Not supported
        end
        
        function setBandwidth(obj,bandwidth_Hz)
            % Not supported
        end
        
        function resetTrip(obj)
            if most.idioms.isValidObj(obj.hDOTripReset)
                obj.hDOTripReset.setValue(1);
                pause(0.25);
                obj.hDOTripReset.setValue(0);
            else
                % perform a soft reset by powercycling the PMT
                oldPower = obj.powerOn;
                
                obj.setPower(false);
                
                if oldPower
                    pause(0.25);
                    obj.setPower(oldPower);
                end
            end
            
            obj.queryStatus();
        end
        
        function queryStatus(obj)
            if most.idioms.isValidObj(obj.hDITripDetect)
               if isa(obj.hDITripDetect.hDAQ,'dabs.resources.daqs.vDAQ')
                    % no need to query here, vDAQ automatically updates its IO
               else
                   try
                       if most.idioms.isValidObj(obj.hDITripDetect)
                           obj.tripped = obj.hDITripDetect.readValue();
                       else
                           obj.tripped = false;
                       end
                   catch ME
                       most.ErrorHandler.logAndReportError(ME);
                   end
               end
            end
        end
        
        function updateTripped(obj)
            obj.tripped = obj.hDITripDetect.lastKnownValue;
            obj.setPower(0);
        end
    end
    
    %% Property Setter/Getter
    methods
        function set.aoRange_V(obj,val)
            validateattributes(val,{'numeric'},{'vector','numel',2,'finite','nonnan','real'});
            assert(val(1)~=val(2));
            obj.aoRange_V = val;
        end
        
        function set.pmtSupplyRange_V(obj,val)
            validateattributes(val,{'numeric'},{'vector','numel',2,'finite','nonnan','real'});
            assert(val(1)<val(2),'pmtSupplyRange_V must be sorted');
            obj.pmtSupplyRange_V = val;
        end
        
        function set.hAOGain(obj,val)
            val = obj.hResourceStore.filterByName(val);
            
            if ~isequal(val,obj.hAOGain)                
                if most.idioms.isValidObj(val)
                    validateattributes(val,{'dabs.resources.ios.AO'},{'scalar'});
                end

                obj.deinit();
                obj.hAOGain.unregisterUser(obj);
                obj.hAOGain = val;
                obj.hAOGain.registerUser(obj,'Gain Control');
            end
        end
        
        function set.hDOPower(obj,val)
            val = obj.hResourceStore.filterByName(val);
            
            if ~isequal(val,obj.hDOPower)
                if most.idioms.isValidObj(val)
                    validateattributes(val,{'dabs.resources.ios.DO','dabs.resources.ios.PFI'},{'scalar'});
                end
                
                obj.deinit();
                obj.hDOPower.unregisterUser(obj);
                obj.hDOPower = val;
                obj.hDOPower.registerUser(obj,'Power');
            end
        end
        
        function set.hDITripDetect(obj,val)
            val = obj.hResourceStore.filterByName(val);
            
            if ~isequal(val,obj.hDITripDetect)
                if most.idioms.isValidObj(val)
                    validateattributes(val,{'dabs.resources.ios.DI','dabs.resources.ios.PFI'},{'scalar'});
                end
                
                obj.deinit();
                obj.hDITripDetect.unregisterUser(obj);
                obj.hDITripDetect = val;
                obj.hDITripDetect.registerUser(obj,'Trip Detect');
            end
        end
        
        function set.hDOTripReset(obj,val)
            val = obj.hResourceStore.filterByName(val);
            
            if ~isequal(val,obj.hDOTripReset)
                if most.idioms.isValidObj(val)
                    validateattributes(val,{'dabs.resources.ios.DO','dabs.resources.ios.PFI'},{'scalar'});
                end
                
                obj.deinit();
                obj.hDOTripReset.unregisterUser(obj);
                obj.hDOTripReset = val;
                obj.hDOTripReset.registerUser(obj,'Trip Reset');
            end
        end
    end
end
 
function s = defaultMdfSection()
    s = [...
        most.HasMachineDataFile.makeEntry('AOGain','','<optional> resource name of the analog output channel that controls the PMT gain (e.g. /vDAQ0/AO0)')...
        most.HasMachineDataFile.makeEntry('AOOutputRange',[0 5],'<required if AOGain is defined> array of 1x2 numeric array specifying the minimum and maximum analog output voltage on the DAQ board that controls the PMT gain.')...
        most.HasMachineDataFile.makeEntry('SupplyVoltageRange',[0 1250],'<required if AOGain is defined> array of 1x2 specifying the minimum and maximum for the PMT power supply in Volts.')...
        most.HasMachineDataFile.makeEntry()...
        most.HasMachineDataFile.makeEntry('DOPower','','<optional> resource name of the digital output channel that switches the PMT on/off (e.g. /vDAQ0/D0.0)')...
        most.HasMachineDataFile.makeEntry('DITripDetect','','<optional> resource name of the analog output channel that controls the PMT gain (e.g. /vDAQ0/D0.1)')...
        most.HasMachineDataFile.makeEntry('DOTripReset','','<optional> resource name of the analog output channel that controls the PMT gain (e.g. /vDAQ0/D0.2)')...
        most.HasMachineDataFile.makeEntry()...
        most.HasMachineDataFile.makeEntry('Calibration settings')... %comment
        most.HasMachineDataFile.makeEntry('wavelength_nm',509,'wavelength in nanometer')...
        most.HasMachineDataFile.makeEntry('autoOn',false,'powers the PMT automatically on for the duration of a scan')...
        most.HasMachineDataFile.makeEntry('gain_V',0,'PMT power supply voltage')...
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
