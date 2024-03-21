classdef GalvoPureAnalog < dabs.resources.devices.GalvoAnalog & dabs.resources.configuration.HasConfigPage & most.HasMachineDataFile
    %% ABSTRACT PROPERTY REALIZATIONS (most.HasMachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'Galvo Analog';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
        
        mdfDefault = defaultMdfSection();
    end
    
    properties (SetAccess = protected,Hidden)
        ConfigPageClass = 'dabs.resources.configuration.resourcePages.GalvoAnalogPage';
    end
    
    methods (Static)
        function names = getDescriptiveNames()
            names = {'Scanner\Analog Galvo'};
        end
    end
    
    methods
        function obj = GalvoPureAnalog(name)
            obj@dabs.resources.devices.GalvoAnalog(name);
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
            % this definition is here so it can be easily overloaded
            obj.reinit@dabs.resources.devices.GalvoAnalog();
        end
        
        function deinit(obj)
            % this definition is here so it can be easily overloaded
            obj.deinit@dabs.resources.devices.GalvoAnalog();
        end
    end
    
    methods        
        function success = loadCalibration(obj)
            success = true;
            success = success & obj.safeSetPropFromMdf('feedbackVoltLUT', 'feedbackVoltLUT');
            success = success & obj.safeSetPropFromMdf('offsetVoltScaling', 'offsetVoltScaling');
        end
        
        function saveCalibration(obj)
            obj.safeWriteVarToHeading('feedbackVoltLUT', obj.feedbackVoltLUT);
            obj.safeWriteVarToHeading('offsetVoltScaling', obj.offsetVoltScaling);
        end
        
        function loadMdf(obj)
            success = true;

            success = success & obj.loadChannelsFromMdf();            
            success = success & obj.safeSetPropFromMdf('voltsPerDistance', 'voltsPerOpticalDegrees');
            success = success & obj.safeSetPropFromMdf('travelRange', 'angularRange', @(v)v*[-1/2 1/2]);
            success = success & obj.safeSetPropFromMdf('parkPosition', 'parkPosition');
            success = success & obj.safeSetPropFromMdf('slewRateLimit_V_per_s', 'slewRateLimit');
            if isfield(obj.mdfData,'voltsOffset')
                success = success & obj.safeSetPropFromMdf('distanceVoltsOffset', 'voltsOffset');
            end
            
            success = success & obj.loadCalibration();
            
            if ~success
                obj.errorMsg = 'Error loading config';
            end
        end
        
        function saveMdf(obj)
            obj.saveChannelsToMdf();
            obj.safeWriteVarToHeading('voltsPerOpticalDegrees', obj.voltsPerDistance);
            obj.safeWriteVarToHeading('voltsOffset', obj.distanceVoltsOffset);
            obj.safeWriteVarToHeading('angularRange', diff(obj.travelRange));
            obj.safeWriteVarToHeading('parkPosition', obj.parkPosition);
            obj.safeWriteVarToHeading('slewRateLimit', obj.slewRateLimit_V_per_s);
            
            obj.saveCalibration();
        end
    end
    
    methods (Hidden)
        function saveChannelsToMdf(obj)
            % this is in a separate function so that it can be overloaded
            % by child classes (i.e. the Thor ECU galvo class)
            obj.safeWriteVarToHeading('AOControl', obj.hAOControl);
            obj.safeWriteVarToHeading('AIFeedback', obj.hAIFeedback);
            obj.safeWriteVarToHeading('AOOffset' , obj.hAOOffset);
        end
        
        function success = loadChannelsFromMdf(obj)
            % this is in a separate function so that it can be overloaded
            % by child classes (i.e. the Thor ECU galvo class)
            success = true;
            success = success & obj.safeSetPropFromMdf('hAOControl', 'AOControl');
            success = success & obj.safeSetPropFromMdf('hAIFeedback', 'AIFeedback');
            success = success & obj.safeSetPropFromMdf('hAOOffset', 'AOOffset');
        end
    end
end

function s = defaultMdfSection()
    s = [...
        most.HasMachineDataFile.makeEntry('AOControl' ,'','control terminal  e.g. ''/vDAQ0/AO0''')...
        most.HasMachineDataFile.makeEntry('AOOffset' ,'','control terminal  e.g. ''/vDAQ0/AO0''')...
        most.HasMachineDataFile.makeEntry('AIFeedback','','feedback terminal e.g. ''/vDAQ0/AI0''')...
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('angularRange',40,'total angular range in optical degrees (e.g. for a galvo with -20..+20 optical degrees, enter 40)')...
        most.HasMachineDataFile.makeEntry('voltsPerOpticalDegrees',0.5,'volts per optical degrees for the control signal')...
        most.HasMachineDataFile.makeEntry('voltsOffset',0,'voltage to be added to the output')...
        most.HasMachineDataFile.makeEntry('parkPosition',20,'park position in optical degrees')...
        most.HasMachineDataFile.makeEntry('slewRateLimit',Inf,'Slew rate limit of the analog output in Volts per second')...
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('Calibration settings')... %comment
        most.HasMachineDataFile.makeEntry('feedbackVoltLUT',[],'[Nx2] lut translating feedback volts into position volts')...
        most.HasMachineDataFile.makeEntry('offsetVoltScaling',1,'scalar factor for offset volts')...
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
