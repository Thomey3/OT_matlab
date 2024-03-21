classdef GenericActuator < dabs.resources.devices.LinearScanner & most.HasMachineDataFile & dabs.resources.configuration.HasConfigPage
    %% ABSTRACT PROPERTY REALIZATIONS (most.HasMachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'Generic Actuator';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
        
        mdfDefault = defaultMdfSection();
    end
    
    properties (SetAccess = protected,Hidden)
        ConfigPageClass = 'dabs.resources.configuration.resourcePages.GenericActuatorPage';
    end
    
    methods (Static)
        function names = getDescriptiveNames()
            names = {'Generic Actuator'};
        end
    end
    
    methods
        function obj = GenericActuator(name)
            obj@dabs.resources.devices.LinearScanner(name);
            obj = obj@most.HasMachineDataFile(true);
            
            obj.deinit();
            obj.loadMdf();
            obj.reinit();
        end
        
        function delete(obj)
            obj.saveCalibration();
        end
    end
    
    methods
        function reinit(obj)
            obj.reinit@dabs.resources.devices.LinearScanner();
        end
        
        function deinit(obj)
            obj.deinit@dabs.resources.devices.LinearScanner();
        end
    end
    
    methods        
        function success = loadCalibration(obj)
            success = true;
            success = success & obj.safeSetPropFromMdf('feedbackVoltLUT', 'feedbackVoltLUT');
            success = success & obj.safeSetPropFromMdf('positionLUT', 'positionLUT');
        end
        
        function saveCalibration(obj)
            obj.safeWriteVarToHeading('feedbackVoltLUT', obj.feedbackVoltLUT);
            obj.safeWriteVarToHeading('positionLUT', obj.positionLUT);
        end
        
        function success = loadMdf(obj)
            success = true;
            success = success & obj.setUnitsFromMDF();
            success = success & obj.safeSetPropFromMdf('hAOControl', 'AOControl');
            success = success & obj.safeSetPropFromMdf('hAIFeedback', 'AIFeedback');

            success = success & obj.safeSetPropFromMdf('voltsPerDistance', 'voltsPerUnit');
            success = success & obj.safeSetPropFromMdf('distanceVoltsOffset', 'voltsOffset');
            success = success & obj.safeSetPropFromMdf('travelRange', 'travelRange');
            success = success & obj.safeSetPropFromMdf('parkPosition', 'parkPosition');
            
            success = success & obj.loadCalibration();
            
            if ~success
                obj.errorMsg = 'Error loading config';
            end
        end
        
        function setUnits(obj, val)
            validateattributes(val,{'char'},{'scalartext'});
           obj.units = val; 
        end
        
        function success = setUnitsFromMDF(obj)
            mdfVariableName = 'units';
            success = false;
            
            if ~isfield(obj.mdfData,mdfVariableName)
                prefix = '';
                if isprop(obj,'name')
                    prefix = sprintf('%s: ',obj.name);
                end
                
                most.idioms.warn('%sMachine Data File does not contain a variable named ''%s''.',prefix,mdfVariableName);
                success = true;
                return
            end
            
            try
                v = obj.mdfData.(mdfVariableName);
                obj.units = v;
                success = true;
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
        end
        
        function saveMdf(obj)
            obj.safeWriteVarToHeading('units', obj.units);
            obj.safeWriteVarToHeading('AOControl', obj.hAOControl);
            obj.safeWriteVarToHeading('AIFeedback', obj.hAIFeedback);
            
            obj.safeWriteVarToHeading('voltsPerUnit',     obj.voltsPerDistance);
            obj.safeWriteVarToHeading('voltsOffset',    obj.distanceVoltsOffset);
            obj.safeWriteVarToHeading('travelRange',  obj.travelRange);
            obj.safeWriteVarToHeading('parkPosition', obj.parkPosition);
            
            obj.saveCalibration();
        end
    end
end

function s = defaultMdfSection()
s = [...
    most.HasMachineDataFile.makeEntry('units' ,'','Unit of the actuator output used when setting voltage scaling  e.g. ''deg''')...
    most.HasMachineDataFile.makeEntry('AOControl' ,'','control terminal  e.g. ''/vDAQ0/AO0''')...
    most.HasMachineDataFile.makeEntry('AIFeedback','','feedback terminal e.g. ''/vDAQ0/AI0''')...
    most.HasMachineDataFile.makeEntry()... % blank line
    most.HasMachineDataFile.makeEntry('parkPosition',0,'park position in micron')...
    most.HasMachineDataFile.makeEntry('travelRange',[0 100],'travel range in micron')...
    most.HasMachineDataFile.makeEntry()... % blank line
    most.HasMachineDataFile.makeEntry('voltsPerUnit',0.1,'volts per micron')...
    most.HasMachineDataFile.makeEntry('voltsOffset',0,'volts that sets actuator to zero position')...
    most.HasMachineDataFile.makeEntry()...
    most.HasMachineDataFile.makeEntry('Calibration Data')...
    most.HasMachineDataFile.makeEntry('positionLUT',[],'Position LUT')...
    most.HasMachineDataFile.makeEntry('feedbackVoltLUT',[],'[Nx2] lut translating feedback volts into position volts')...
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
