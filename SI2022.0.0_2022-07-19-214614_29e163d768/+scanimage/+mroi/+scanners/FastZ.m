classdef FastZ < scanimage.mroi.scanners.Scanner
    properties (SetAccess = immutable)
        hDevice;
    end
    
    properties
        enableFieldCurveCorr = false;
        fieldCurvature = struct('zs',[],'rxs',[],'rys',[]);
    end
    
    properties (Dependent)
        name
    end
    
    methods
        function obj=FastZ(hDevice)
            if ~isempty(hDevice)
                assert(isa(hDevice,'dabs.resources.devices.FastZ'));
            end
            
            obj.hDevice = hDevice;
        end
    end
    
    methods (Static)
        function obj = default()
            obj = scanimage.mroi.scanners.FastZAnalog([]);
        end
    end
    
    methods (Abstract)
        path_FOV = scanPathFOV(obj,ss,actz,actzRelative,dzdt,seconds,slowPathFov)
        path_FOV = scanStimPathFOV(obj,ss,startz,endz,seconds,maxPoints)
        path_FOV = interpolateTransits(obj,ss,path_FOV,tune,zWaveformType)
        path_FOV = transitNaN(obj,ss,dt)
        path_FOV = zFlybackFrame(obj,ss,frameTime)
        path_FOV = padFrameAO(obj, ss, path_FOV, frameTime, flybackTime, zWaveformType)
        samplesPerTrigger = samplesPerTriggerForAO(obj,ss,outputData)
        
        volts = refPosition2Volts(obj,zs);
        zs = volts2RefPosition(obj,volts);
        zs = feedbackVolts2RefPosition(obj,volts);
    end
    
    methods
        function val = get.name(obj)
            if isempty(obj.hDevice)
                val = 'Not a device.';
            else
                val = obj.hDevice.name;
            end
        end
    end
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
