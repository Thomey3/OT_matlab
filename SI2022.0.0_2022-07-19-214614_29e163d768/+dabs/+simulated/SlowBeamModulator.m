classdef SlowBeamModulator < dabs.resources.devices.BeamModulatorSlow & most.HasMachineDataFile & dabs.resources.configuration.HasConfigPage
    %Simulated slow beam modulator class to test implementation of a slow
    %beam modulator
    
    %% Abstract Property Implementation (dabs.resources.configuration.HasConfigPage)
    properties (SetAccess=protected,Hidden)
        ConfigPageClass = 'dabs.resources.configuration.resourcePages.SimulatedSlowBeamModulatorPage';
    end
    
    methods (Static)
        function names = getDescriptiveNames()
            names = {'Beam Modulator\Simulated Slow Beam Modulator'};
        end
    end
    
    %% Abstract Property Implementation (most.HasMachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'Slow Beam';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
        
        mdfDefault = defaultMdfSection();
    end
    
    %% Abstract Property Implementaion (dabs.resources.devices.BeamModulatorSlow)
     properties (SetObservable, SetAccess = private)
        lastKnownPowerFraction = 0;
        isModulating;
    end
    
    properties (SetAccess = private)
        lastKnownPower_W = 0; % don't attach a listener to this. instead, listen to lastKnownPowerFraction
    end
    
    properties (SetObservable)
        powerFractionLimit = 1;
    end
    
    %% Lifecycle Methods
    methods
        function obj = SlowBeamModulator(name)
            obj@dabs.resources.devices.BeamModulatorSlow(name);
            obj@most.HasMachineDataFile(true);
            
            obj.deinit();
            obj.loadMdf();
            obj.reinit();
        end
        
         function deinit(obj)            
            obj.errorMsg = 'uninitialized';
        end
        
        function reinit(obj)
            obj.deinit();
            try
                obj.errorMsg = ''; 
                obj.setPowerFraction(0);
            catch ME
                obj.deinit();
                obj.errorMsg = sprintf('%s: initialization error: %s',obj.name,ME.message);
                most.ErrorHandler.logError(ME,obj.errorMsg);
            end
        end       
    end
    
    %% Class Methods
    
    methods
        function setPowerFraction(obj,fraction)
            validateattributes(fraction,{'numeric'},{'>=',0,'<=',1,'scalar','real','nonnan'});
            most.ErrorHandler.assert(isempty(obj.errorMsg),'%s is in an error state: %s',obj.name,obj.errorMsg);
            
            fraction = min(fraction,obj.powerFractionLimit);
            obj.lastKnownPowerFraction = fraction;
            obj.isModulating = true;
        end
        
        function power_W = convertPowerFraction2PowerWatt(obj,fraction)
            power_W = fraction;
            obj.lastKnownPower_W = fraction;
        end
        
        function modulateWaitForFinish(obj, timeout_s)
            obj.isModulating = false;
        end
    end
    
    %% Property Validation
    
     methods
        function set.lastKnownPowerFraction(obj,val)
            obj.lastKnownPower_W = obj.convertPowerFraction2PowerWatt(val); %#ok<MCSUP>
            obj.lastKnownPowerFraction = val;
        end
        
        function set.powerFractionLimit(obj,val)
            validateattributes(val,{'numeric'},{'nonnegative','<=',1,'scalar','finite','nonnan','real'});
            obj.powerFractionLimit = val;
        end
    end
    
    %% MDF methods
    methods        
        function loadMdf(obj)
            success = true;
            success = success & obj.safeSetPropFromMdf('powerFractionLimit', 'powerFractionLimit');
            
            if ~success
                obj.errorMsg = 'Error loading config';
            end
        end
        
        function saveMdf(obj)
            obj.safeWriteVarToHeading('powerFractionLimit', obj.powerFractionLimit);
        end
    end
    
end

function s = defaultMdfSection()
s = [...
    most.HasMachineDataFile.makeEntry('powerFractionLimit',1,'Maximum allowed power fraction (between 0 and 1)') ...
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
