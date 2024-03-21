classdef FastZPureAnalog < dabs.resources.devices.FastZAnalog & most.HasMachineDataFile & dabs.resources.configuration.HasConfigPage
    %% ABSTRACT PROPERTY REALIZATIONS (most.HasMachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'FastZ Analog';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
        
        mdfDefault = defaultMdfSection();
    end
    
    properties (SetAccess = protected,Hidden)
        ConfigPageClass = 'dabs.resources.configuration.resourcePages.FastZAnalogPage';
    end
    
    methods (Static)
        function names = getDescriptiveNames()
            names = {'Fast Focus\Analog FastZ', 'Fast Focus\Revibro mirror'};
        end
    end
    
    methods
        function obj = FastZPureAnalog(name)
            obj@dabs.resources.devices.FastZAnalog(name);
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
            obj.reinit@dabs.resources.devices.FastZAnalog();
        end
        
        function deinit(obj)
            obj.deinit@dabs.resources.devices.FastZAnalog();
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
            success = success & obj.safeSetPropFromMdf('hAOControl', 'AOControl');
            success = success & obj.safeSetPropFromMdf('hAIFeedback', 'AIFeedback');
            success = success & obj.safeSetPropFromMdf('hFrameClockIn', 'FrameClockIn');

            success = success & obj.safeSetPropFromMdf('voltsPerDistance', 'voltsPerUm');
            success = success & obj.safeSetPropFromMdf('distanceVoltsOffset', 'voltsOffset');
            success = success & obj.safeSetPropFromMdf('travelRange', 'travelRangeUm');
            success = success & obj.safeSetPropFromMdf('parkPosition', 'parkPositionUm');
            
            success = success & obj.loadCalibration();
            
            if ~success
                obj.errorMsg = 'Error loading config';
            end
        end
        
        function saveMdf(obj)
            obj.safeWriteVarToHeading('AOControl', obj.hAOControl);
            obj.safeWriteVarToHeading('AIFeedback', obj.hAIFeedback);
            obj.safeWriteVarToHeading('FrameClockIn', obj.hFrameClockIn);
            
            obj.safeWriteVarToHeading('voltsPerUm',     obj.voltsPerDistance);
            obj.safeWriteVarToHeading('voltsOffset',    obj.distanceVoltsOffset);
            obj.safeWriteVarToHeading('travelRangeUm',  obj.travelRange);
            obj.safeWriteVarToHeading('parkPositionUm', obj.parkPosition);
            
            obj.saveCalibration();
        end
    end
end

function s = defaultMdfSection()
s = [...
    most.HasMachineDataFile.makeEntry('AOControl' ,'','control terminal  e.g. ''/vDAQ0/AO0''')...
    most.HasMachineDataFile.makeEntry('AIFeedback','','feedback terminal e.g. ''/vDAQ0/AI0''')...
    most.HasMachineDataFile.makeEntry('FrameClockIn','','frame clock input terminal e.g. ''/Dev1/PFI0''')...
    most.HasMachineDataFile.makeEntry()... % blank line
    most.HasMachineDataFile.makeEntry('parkPositionUm',0,'park position in micron')...
    most.HasMachineDataFile.makeEntry('travelRangeUm',[0 100],'travel range in micron')...
    most.HasMachineDataFile.makeEntry()... % blank line
    most.HasMachineDataFile.makeEntry('voltsPerUm',0.1,'volts per micron')...
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
