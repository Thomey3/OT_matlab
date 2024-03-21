classdef DigitalShutter < dabs.resources.devices.Shutter & most.HasMachineDataFile & dabs.resources.configuration.HasConfigPage
    %% ABSTRACT PROPERTY REALIZATIONS (most.HasMachineDataFile) 
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'Shutter';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
        
        mdfDefault = defaultMdfSection();
    end
    
    properties (SetObservable)
        hDOControl = dabs.resources.Resource.empty();
        invertOutput = false;
        openTime_s = 0;
    end
    
    properties (SetObservable, SetAccess = protected)
        isOpen = false;
        lastTransitionEvent = tic();
    end
    
    properties (GetAccess=private,SetAccess=private)
        hDOListener = event.listener.empty(0,1);
    end
    
    properties (SetAccess = protected,Hidden)
        ConfigPageClass = 'dabs.resources.configuration.resourcePages.DigitalShutterPage';
    end
    
    methods (Static)
        function names = getDescriptiveNames()
            names = {'Shutter\Digital Shutter'};
        end
    end
    
    methods
        function obj = DigitalShutter(name)
            obj@dabs.resources.devices.Shutter(name);
            obj = obj@most.HasMachineDataFile(true);
            
            obj.deinit();
            obj.loadMdf();
            obj.reinit();
        end
        
        function delete(obj)
            obj.deinit();
        end
    end
    
    methods
        function reinit(obj)
            try
                obj.deinit();
                
                if ~most.idioms.isValidObj(obj.hDOControl)
                    obj.errorMsg = 'No digital output for shutter control specified';
                    return
                end
                
                obj.hDOControl.reserve(obj);
                obj.hDOListener(end+1) = most.ErrorHandler.addCatchingListener(obj.hDOControl,'lastKnownValueChanged',@(varargin)obj.updateStatus);
                
                obj.errorMsg = '';
                obj.warnMsg = '';
                
                obj.checkDOFloat();
                obj.transition(false);
            catch ME
                obj.deinit();
                obj.errorMsg = sprintf('%s: initialization error: %s',obj.name,ME.message);
                most.ErrorHandler.logError(ME,obj.errorMsg);
            end
        end
        
        function checkDOFloat(obj)
            obj.transition(false);
            obj.hDOControl.tristate();
            pause(0.001); % should be enough time for the line to float
            floating_DO_level = obj.hDOControl.queryValue();
            expected_DO_floating_level = obj.invertOutput;
            
            floating_DO_opens_shutter = floating_DO_level ~= expected_DO_floating_level;
            
            if floating_DO_opens_shutter
                if obj.invertOutput
                    floatLevel = 'LOW';
                    resistorType = 'up';
                else
                    floatLevel = 'HIGH';
                    resistorType = 'down';
                end
                
                obj.warnMsg = sprintf( ...
                    ['When ScanImage does not actively drive the shutter control line, ' ...
                    'the line floats to %s, which opens the shutter.\n' ...
                    'When ScanImage is not active, or the DAQ board is powered down, ' ...
                    'the shutter will open.\n' ...
                    'Make sure to configure the shutter to be ''NC'' (normally closed) ' ...
                    'or add a pull-%s resistor to the shutter control line.'] ...
                    ,floatLevel ...
                    ,resistorType);
            end
        end
        
        function deinit(obj)
            obj.errorMsg = 'Uninitialized';
            obj.warnMsg = '';
            
            delete(obj.hDOListener);
            obj.hDOListener = event.listener.empty(0,1);
            
            try
                obj.close();
            catch                
            end
            
            if most.idioms.isValidObj(obj.hDOControl)
                try
                    obj.hDOControl.tristate();
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
                obj.hDOControl.unreserve(obj);
            end
        end
    end
    
    methods
        function startTransition(obj,tf)
            most.ErrorHandler.assert(isempty(obj.errorMsg),'Shutter is in an error state: %s',obj.errorMsg);
            validateattributes(tf,{'numeric','logical'},{'scalar','binary'});
            
            applyWaitTime = tf && ~obj.isOpen;
            
            obj.hDOControl.setValue(xor(tf,obj.invertOutput));
            obj.isOpen = tf;
            
            if applyWaitTime
                obj.lastTransitionEvent = tic();
            end
        end
        
        function waitTransitionComplete(obj)
            while toc(obj.lastTransitionEvent) < obj.openTime_s
                pause(0.001);                
            end
        end
    end
    
    methods        
        function set.hDOControl(obj,val)
            val = obj.hResourceStore.filterByName(val);
            
            if ~isequal(val,obj.hDOControl)
                obj.deinit();
                
                if most.idioms.isValidObj(obj.hDOControl)
                    obj.hDOControl.unregisterUser(obj);
                end
                
                if most.idioms.isValidObj(val)
                    validateattributes(val,{'dabs.resources.ios.DO','dabs.resources.ios.PFI'},{'scalar'});
                    val.registerUser(obj,'Control');
                end
                
                obj.hDOControl = val;
            end
        end
        
        function set.invertOutput(obj,val)
            validateattributes(val,{'numeric','logical'},{'scalar','binary'});
            
            if ~isequal(obj.invertOutput,val)
                obj.deinit();
                obj.invertOutput = logical(val);
            end
        end
        
        function set.openTime_s(obj,val)
            validateattributes(val,{'numeric'},{'scalar','nonnegative','finite','real','nonnan'});
            obj.openTime_s = val;
        end
    end
    
    methods        
        function loadMdf(obj)
            success = true;
            success = success & obj.safeSetPropFromMdf('hDOControl', 'DOControl');
            success = success & obj.safeSetPropFromMdf('invertOutput', 'invertOutput');
            success = success & obj.safeSetPropFromMdf('openTime_s', 'openTime_s');
            
            if isfield(obj.mdfData,'shutterTarget')
                success = success & obj.safeSetPropFromMdf('shutterTarget', 'shutterTarget');
            else
                obj.shutterTarget = dabs.resources.devices.shutter.ShutterTarget.Excitation;
            end
            
            if ~success
                obj.errorMsg = 'Error loading config';
            end
        end
        
        function saveMdf(obj)
            obj.safeWriteVarToHeading('DOControl', obj.hDOControl);
            obj.safeWriteVarToHeading('invertOutput', obj.invertOutput);
            obj.safeWriteVarToHeading('openTime_s',   obj.openTime_s);
            obj.safeWriteVarToHeading('shutterTarget',  shutterTargetToChar());

            %%% Nested function
            function val = shutterTargetToChar()
                if isempty(obj.shutterTarget)
                    val = '';
                elseif isscalar(obj.shutterTarget)
                    val = char(obj.shutterTarget);
                else
                    val = arrayfun(@(sT)char(sT),obj.shutterTarget(:)','UniformOutput',false);
                end
            end
        end
    end
    
    methods (Hidden)
        function updateStatus(obj)
            if most.idioms.isValidObj(obj.hDOControl)
                obj.isOpen = xor(obj.hDOControl.lastKnownValue,obj.invertOutput);
            end
        end
    end
end

function s = defaultMdfSection()
s = [...    
    most.HasMachineDataFile.makeEntry('DOControl'   , ''   ,'control terminal  e.g. ''/vDAQ0/DIO0''')...
    most.HasMachineDataFile.makeEntry('invertOutput', false,'invert output drive signal to shutter')...
    most.HasMachineDataFile.makeEntry('openTime_s'  , 0.5  ,'settling time for shutter in seconds')...
    most.HasMachineDataFile.makeEntry('shutterTarget', 'Excitation'  ,'one of {'', ''Excitation'', ''Detection''}')...
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
