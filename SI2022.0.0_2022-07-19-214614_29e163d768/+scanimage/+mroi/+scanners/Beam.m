classdef Beam
    properties
        beamIdx
        siBeamIdx
        powerFraction = 0;
        
        pzAdjust;
        Lz;
        pzFunction;
        pzLUT;
        pzReferenceZ;
        
        powerFracToVoltageFunc;
        
        includeFlybackLines = false;
        
        hDevice
    end
    
    properties (Dependent,SetAccess = private)
        powerFractionLimit
    end

    methods(Static,Abstract)
        obj = default()
    end
    
    methods
        function obj=Beam(hDevice)
            obj.hDevice = hDevice;
        end
        
        function obj = applySettingsFromRoi(obj,hRoi)
            obj.pzAdjust            = choosePzAdjust(obj.pzAdjust,hRoi.pzAdjust );
            obj.powerFraction       = choose(obj.powerFraction,hRoi.powerFractions );
            obj.Lz                  = choose(obj.Lz,hRoi.Lzs);
            obj.interlaceDecimation = choose(obj.interlaceDecimation,hRoi.interlaceDecimation);
            obj.interlaceOffset     = choose(obj.interlaceOffset,hRoi.interlaceOffset);
            
            %%% NestedFunction
            function val = choosePzAdjust(val,roiVal)
                assert(isa(val,'scanimage.types.BeamAdjustTypes'));
                
                roiVal(end+1:obj.beamIdx) = scanimage.types.BeamAdjustTypes.None;
                roiVal = roiVal(obj.beamIdx);
                
                if roiVal ~= scanimage.types.BeamAdjustTypes.None
                    val = roiVal;
                end
            end
            
            function val = choose(val,roiVal) 
                assert(isnumeric(val));
                roiVal(end+1:obj.beamIdx) = NaN;
                roiVal = roiVal(obj.beamIdx);
                
                if ~isnan(roiVal)
                    val = roiVal;
                end
            end
        end
        
        function powers = enforcePowerLimit(obj,powers)
            upperLimit = min(1,obj.hDevice.powerFractionLimit);
            powers = max(powers,0);
            powers = min(powers,upperLimit);
        end
        
        function powers = powerDepthCorrectionFunc(obj,powers,zs, varargin)
            try
                switch obj.pzAdjust
                    case scanimage.types.BeamAdjustTypes.None
                        powers = powers.*ones(numel(zs),1);
                        
                    case scanimage.types.BeamAdjustTypes.Exponential
                        powers = powers .* exp( (zs-obj.pzReferenceZ) ./ obj.Lz );
                        
                    case scanimage.types.BeamAdjustTypes.Function
                        if isscalar(powers)
                            powers = repmat(powers,size(zs));
                        end
                        
                        powers = obj.pzFunction(powers,zs,obj, varargin);
                        
                        assert(isequal(size(powers),size(zs)),'Custom power function returned vector of incorrect length. Expected length: %d. Actual:%d',numel(zs),numel(powers));
                        
                    case scanimage.types.BeamAdjustTypes.LUT
                        if isempty(obj.pzLUT)
                            powers = zeros(size(zs));
                        elseif size(obj.pzLUT,1) == 1
                            powers = repmat(obj.pzLUT(1,2),size(zs));
                        else
                            interpolationMethod = 'linear';
                            extrapolationMethod = 'nearest';
                            hInt = griddedInterpolant(obj.pzLUT(:,1),obj.pzLUT(:,2),interpolationMethod,extrapolationMethod);
                            powers = hInt(zs);
                        end
                        
                    otherwise
                        error('Unknown value for pzAdjust: %s',char(obj.pzAdjust));
                end
                
                powers = obj.enforcePowerLimit(powers);
            
            catch ME
                most.ErrorHandler.logAndReportError(ME);
                powers = zeros(size(zs));
            end
        end
    end
    
    methods
        function val = get.powerFractionLimit(obj)
            val = obj.hDevice.powerFractionLimit;
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
