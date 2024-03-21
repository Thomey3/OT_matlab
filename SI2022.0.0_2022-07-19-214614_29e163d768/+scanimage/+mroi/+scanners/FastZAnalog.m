classdef FastZAnalog < scanimage.mroi.scanners.FastZ
    properties
        flybackTime;
        actuatorLag;
        useScannerTimebase = 1;
        sampleRateHz;
    end
    
    properties (Dependent)
        simulated;
    end
    
    methods
        function obj=FastZAnalog(hDevice)
            obj = obj@scanimage.mroi.scanners.FastZ(hDevice);
        end
        
        function path_FOV = scanPathFOV(obj,ss,actz,actzRelative,dzdt,seconds,slowPathFov)
            % This doesn't handle the end of a stack correctly because it
            % adds dzdt to it - but this is necessary for interpolating all
            % other zs to the next Z. 
            path_FOV = linspace(actzRelative,actzRelative+dzdt*seconds,ss.nsamples(obj,seconds))';

            if obj.enableFieldCurveCorr && ~isempty(obj.fieldCurvature)
                zs =  obj.fieldCurvature.zs;
                rxs = obj.fieldCurvature.rxs;
                rys = obj.fieldCurvature.rys;
                tip = obj.fieldCurvature.tip;
                tilt = obj.fieldCurvature.tilt;
                
                assert(numel(zs)==numel(rxs) && numel(rxs)==numel(rys) ...
                     ,'Incorrect settings for field curvature correction. zs,rxs,rys must have same length');
                
                thxs = resamp(slowPathFov(:,1), numel(path_FOV))';
                thys = resamp(slowPathFov(:,2), numel(path_FOV))';
                
                if isempty(zs)
                    d = zeros(size(path_FOV));
                else
                    as = interp1(zs, rxs, path_FOV, 'linear', 'extrap');
                    bs = interp1(zs, rys, path_FOV, 'linear', 'extrap');
                    cs = (as + bs) * .5;
                    
                    ths = atand(thys./thxs);
                    ths(isnan(ths)) = 0;
                    
                    phis = (thxs.^2 + thys.^2).^.5;
                    rs = ( (((cosd(ths).*sind(phis)).^2)./(as.^2)) + (((sind(ths).*sind(phis)).^2)./(bs.^2)) + (((cosd(phis)).^2)./(cs.^2)) ).^(-.5);
                    zs = rs .* cosd(phis);
                    
                    d = cs - zs;
                end
                
                thxs_um = thxs .* ss.objectiveResolution;
                thys_um = thys .* ss.objectiveResolution;
                
                tipPlane  = thxs_um .* tand(tip);
                tiltPlane = thys_um .* tand(tilt);
                
                tipTilt = tipPlane + tiltPlane;
                
                path_FOV = path_FOV + d + tipTilt;
            end
            
            function wvfm = resamp(owvfm,N)
                w = warning('off','MATLAB:chckxy:IgnoreNaN');
                wvfm = pchip(linspace(0,1,numel(owvfm)),owvfm,linspace(0,1,N));
                warning(w.state,'MATLAB:chckxy:IgnoreNaN');
            end
        end
        
        function path_FOV = scanStimPathFOV(obj,ss,startz,endz,seconds,maxPoints)
            if nargin < 6 || isempty(maxPoints)
                maxPoints = inf;
            end
            
            N = min(maxPoints,ss.nsamples(obj,seconds));
            
            if ~isscalar(startz)
                hGI = griddedInterpolant(linspace(1,N,length(startz)),startz);
                path_FOV = hGI(1:N);
                path_FOV = path_FOV(:);
            elseif isinf(startz)
                path_FOV = nan(N,1);
                path_FOV(ceil(N/2)) = endz;
            else
                path_FOV = linspace(startz,endz,N)';
                if isnan(startz) && ~isnan(endz)
                    path_FOV(end-2:end) = endz;
                end
            end
        end
        
        function path_FOV = interpolateTransits(obj,ss,path_FOV,tune,zWaveformType)
            if length(path_FOV) < 1
                return
            end

            switch zWaveformType
                case 'sawtooth'
                    %flyback frames
                    if any(isinf(path_FOV))
                        N = numel(find(isinf(path_FOV)));
                        assert(all(isinf(path_FOV(end-N+1:end))));
                        
                        Nfb = min(N,ss.nsamples(obj,obj.flybackTime));
                        Nramp = N-Nfb;
                        dz = path_FOV(2) - path_FOV(1);
                        
                        path_FOV(end-N+1:end-Nramp) = nan;
                        path_FOV(end-Nramp+1:end) = linspace(path_FOV(1)-dz*Nramp,path_FOV(1),Nramp);
                    end
                    
                case 'step'
                    % replace Infs
                    path_FOV = scanimage.mroi.util.interpolateCircularNaNRanges(path_FOV,[],'linearwithsettle',Inf);
            end
            
            assert(~any(isinf(path_FOV)),'Unexpected infs in data.');
            path_FOV = scanimage.mroi.util.interpolateCircularNaNRanges(path_FOV);
            
            if tune
                nSample = ss.nsamples(obj,obj.actuatorLag);
                path_FOV = circshift(path_FOV,-nSample);
            end
            
            if most.idioms.isValidObj(obj.hDevice)
                allowedTravelRange = sort(obj.hDevice.travelRange);
            else
                % called from si dataview
                allowedTravelRange = [-Inf Inf];
            end
            
            % This used to be allowedTravelRange -/+
            % diff(travelRange)*toleraance back when we were working with
            % Voltages directly
            if any(path_FOV < allowedTravelRange(1)) || any(path_FOV > allowedTravelRange(2))
                most.idioms.warn('FastZ waveform exceeded actuator range. Clamped to max and min.');
                path_FOV(path_FOV < allowedTravelRange(1)) = allowedTravelRange(1);
                path_FOV(path_FOV > allowedTravelRange(2)) = allowedTravelRange(2);
            end
        end
        
        function path_FOV = transitNaN(obj,ss,dt)
            path_FOV = nan(ss.nsamples(obj,dt),1);
        end
        
        function path_FOV = zFlybackFrame(obj,ss,frameTime)
            path_FOV = inf(ss.nsamples(obj,frameTime),1);
        end
        
        function path_FOV = padFrameAO(obj, ss, path_FOV, waveformTime, zWaveformType)
            padSamples = ss.nsamples(obj, waveformTime) - size(path_FOV,1);
            
            if strcmp(zWaveformType,'step') || ~isempty(path_FOV) && isinf(path_FOV(end))
                app = inf;
            else
                app = nan;
            end
            
            path_FOV(end+1:end+padSamples,:) = app;
        end
        
        function samplesPerTrigger = samplesPerTriggerForAO(obj,ss,outputData)
            samplesPerTrigger = sum(cellfun(@(frameAO)size(frameAO.Z,1),outputData));
        end
    end
    
    methods
        function v = feedbackVolts2RefPosition(obj,v) % defined in scanimage.mroi.scanners.FastZ
            v = obj.hDevice.feedbackVolts2PositionVolts(v);
        end
        
        function v = volts2RefPosition(obj,v)        	% defined in scanimage.mroi.scanners.FastZ
            v = obj.hDevice.volts2Position(v);
        end
        
        function v = volts2Position(obj,v)        	% defined in scanimage.mroi.scanners.FastZ
            v = obj.hDevice.volts2Position(v);
        end
        
        function v = refPosition2Volts(obj,v)        	% defined in scanimage.mroi.scanners.FastZ
            v = obj.hDevice.position2Volts(v);
        end
    end
    
    % Property getter/setter
    methods
        function val = get.simulated(obj)
            val = obj.hDevice.simulated;
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
