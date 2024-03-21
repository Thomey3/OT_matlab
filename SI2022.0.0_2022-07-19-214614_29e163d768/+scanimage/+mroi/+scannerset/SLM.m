classdef SLM < scanimage.mroi.scannerset.ScannerSet    
    properties (Hidden)
        CONSTRAINTS = struct(...
            'scanimage_mroi_scanfield_ImagingField',{{}},...
            'scanimage_mroi_scanfield_fields_StimulusField',{{@scanimage.mroi.constraints.zeroedXY}}...
            );
    end 
    
    properties (Constant)
        optimizableScanners = {};
    end
    
    properties (Dependent)
        angularRange;
        zeroOrderBlockRadius;
    end
    
    properties
        galvoReferenceAngleXY = [];
    end

    methods(Static)
        function obj=default()
            obj.refToScannerTransform = eye(3);
        end
    end
    
    methods
        function obj = SLM(name,SLM,fastBeams,slowBeams)
            %% Describes a resonant-galvo-galvo scanner set.
            obj = obj@scanimage.mroi.scannerset.ScannerSet(name,fastBeams,slowBeams,[]);
            obj.scanners={SLM};
            obj.slm = obj; % circular reference, but is required by photostim
        end
        
        function path_FOV = refFovToScannerFov(obj,path_FOV)
            error('Not implemented');
        end
        
        function ao_volts = multiPointFovToAo(obj,path_FOV)         
            hSLM = obj.scanners{1};
            
            if size(path_FOV,2) <= 4
                if size(path_FOV,2)<4
                    weights = ones(size(path_FOV,1),1);
                else
                    weights = path_FOV(:,4);
                    path_FOV(:,4) = [];
                end
                
                % currently we need to treat xy and z separately
                hPtsZ = scanimage.mroi.coordinates.Points(obj.hCSSampleRelative,path_FOV);
                hPtsZ = hPtsZ.transform(obj.hCSReference);
                pointsZ = hPtsZ.points(:,3);
                
                hPts = scanimage.mroi.coordinates.Points(obj.hCSReference,[path_FOV(:,1:2),pointsZ]);
                hPts = hPts.transform(hSLM.hCoordinateSystem);
                path_SLM = hPts.points;
                
                [slmPhaseMaskRad,efficiency] = obj.scanners{1}.computeMultiPointPhaseMask(path_SLM,weights);
            else
                % calculate bitmap
                path_SLM = path_FOV;
                [slmPhaseMaskRad,efficiency] = obj.scanners{1}.computeBitmapPhaseMask(path_FOV);
                weights = [];
            end
            
            ao_volts = struct();
            ao_volts.fov = path_SLM;
            ao_volts.weights = weights;
            ao_volts.phase = obj.scanners{1}.rad2PixelVal(slmPhaseMaskRad);
            ao_volts.efficiency = efficiency;
        end
        
        function ao_volts = pathFovToAo(obj,path_FOV)
            hSLM = obj.scanners{1};

            if isfield(path_FOV,'SLMxyz')
                % this is an imaging path. SLMxyz is a Nx3 matrix representing
                % a series of points to be sequentially acquired
                hPts = scanimage.mroi.coordinates.Points(obj.hCSReference,path_FOV.SLMxyz);
                hPts = hPts.transform(hSLM.hCoordinateSystem);
                ao_volts = struct('SLMxyz',hPts.points);
            else
                % this is a photostim path. SLM is a structure array. Each
                % element consists of a field 'pattern' which lists points
                % to be simultaneously excited and 'duration' representing
                % the duration for which that pattern should be output
                ao_volts.SLM = arrayfun(@(x)struct('duration',x.duration,'mask',obj.multiPointFovToAo(x.pattern)),path_FOV.SLM);
            end
            
            for idx = 1:numel(obj.beamRouters)
                beamsInBeamRouter = false;
                for c = obj.beamRouters{idx}.hBeams
                    beamsInBeamRouter = any(c{1} == [obj.beams.hDevice]);
                    if beamsInBeamRouter
                        break;
                    end
                end

                if beamsInBeamRouter
                    if obj.hasBeams
                        path_FOV.B = obj.beamRouters{idx}.route({obj.beams.hDevice},path_FOV.B);
                    end

                    if obj.hasPowerBox
                        path_FOV.Bpb = obj.beamRouters{idx}.route({obj.beams.hDevice},path_FOV.Bpb);
                    end
                end
            end
            
            for idx = 1:numel(obj.beams)
                hBeam = obj.beams(idx);
                ao_volts.B(:,idx) = hBeam.hDevice.convertPowerFraction2Volt(path_FOV.B(:,idx));
            end
        end
            
        function [path_FOV, seconds] = scanPathFOV(obj,scanfield,roi,actz,actzRelative,dzdt,zActuator,maxPtsPerSf)
            assert(isa(scanfield,'scanimage.mroi.scanfield.ScanField'));
            if isa(scanfield,'scanimage.mroi.scanfield.ImagingField')
                [xx,yy] = scanfield.meshgrid();
                if obj.scanners{1}.bidirectionalScan
                    xx(2:2:end,:) = fliplr(xx(2:2:end,:));
                    yy(2:2:end,:) = fliplr(yy(2:2:end,:));
                end
                
                actzRelative = 0;
                
                xx = xx';
                yy = yy';
                xx = xx(:);
                yy = yy(:);
                zz = repmat(actzRelative,numel(xx),1);
                
                path_FOV.SLMxyz = [xx,yy,zz];
                
                %% Beams AO
                if obj.hasBeams
                    % determine number of samples
                    % get roi specific beam settings
                    [powerFractions, pzAdjust, Lzs, interlaceDecimation, interlaceOffset] = obj.getRoiBeamProps(...
                        roi, 'powerFraction', 'pzAdjust', 'Lz', 'interlaceDecimation', 'interlaceOffset');
                    
                    assert(~any(interlaceDecimation~=1),'Beam interlace decimation is unsupported in SlmScan');
                    
                    % start with nomimal power fraction sample array for single line
                    assert(~any(pzAdjust),'Pz Adjust is unsupported in SlmScan');
                    
                    % IDs of the beams actually being used in this acq                    
                    for i = 1:numel(obj.beams)
                        path_FOV.B(:,i) = powerFractions(:,i);
                    end
                end
                
                seconds=obj.scanTime(scanfield);
            elseif isa(scanfield,'scanimage.mroi.scanfield.fields.StimulusField')
                if obj.hasBeams
                    % normalize duration to sample rate of beams
                    seconds = round(round(scanfield.duration * obj.beams(1).sampleRateHz) * scanfield.repetitions)/ obj.beams(1).sampleRateHz;
                else
                    seconds = scanfield.duration * scanfield.repetitions;
                end
                
                [path_FOV.SLM, parkfunctiondetected] = obj.generateSlmPathStimulus(scanfield,seconds);
                
                for idx = 1:numel(obj.beams)
                    repetitionsInteger = fix(scanfield.repetitions);
                    durationPerRepetitionInt = round(scanfield.duration * obj.beams(idx).sampleRateHz) / obj.beams(idx).sampleRateHz;
                    durationPerRepetitionFrac = round(scanfield.duration * obj.beams(idx).sampleRateHz * (scanfield.repetitions - durationPerRepetitionInt)) / obj.beams(idx).sampleRateHz;
                    beamAO = obj.beams.generateBeamsPathStimulus(path_FOV,scanfield,parkfunctiondetected,repetitionsInteger,durationPerRepetitionInt,durationPerRepetitionFrac,seconds);
                    path_FOV.B(:,idx) = single(beamAO);
                end
            end
        end
        
        function [path_FOV, parkfunctiondetected] = generateSlmPathStimulus(~,scanfield,totalDuration)
            parkfunctiondetected = false;
            if ~isempty(scanfield.slmPattern)
                path_FOV = struct('duration',totalDuration,'pattern',scanfield.slmPattern);
            elseif scanfield.isPause || scanfield.isPark
                path_FOV = struct('duration',totalDuration,'pattern',nan);
                parkfunctiondetected = true;
            else
                path_FOV = struct('duration',totalDuration,'pattern',[0 0 0]);
            end
        end
        
        function emptyArray = retrieveOptimizedAO(varargin)
            emptyArray = [];
        end
        
        function varargout = optimizeAO(varargin)
            varargout = varargin;
        end

        function position_FOV = mirrorsActiveParkPosition(obj)
            position_FOV = obj.scanners{1}.parkPosition;
            position_FOV(1:2) = scanimage.mroi.util.xformPoints(position_FOV(1:2),obj.scannerToRefTransform);
        end

        function path_FOV = interpolateTransits(obj,path_FOV,tuneZ,zWaveformType)
            if isfield(path_FOV,'SLMxyz')
                % this is an imaging path. SLMxyz is a Nx3 matrix representing
                % a series of points to be sequentially acquired
                if isfield(path_FOV,'B')
                    mask = ~isnan(path_FOV.B);
                    vals = path_FOV.B(mask);
                    assert(all(vals==vals(1)),'Beam cannot change intensity value during SLM scan');
                    path_FOV.B(~mask) = vals(1);
                end
            else
                % this is a photostim path. SLM is a structure array. Each
                % element consists of a field 'pattern' which lists points
                % to be simultaneously excited and 'duration' representing
                % the duration for which that pattern should be output
                N = numel(path_FOV.SLM);
                
                % replace nans with next pattern
                i = 0;
                t = 0;
                newSeq = struct('duration',{},'pattern',{});
                
                while i < N
                    i = i + 1;
                    t = t + path_FOV.SLM(i).duration;
                    
                    if ~any(isnan(path_FOV.SLM(i).pattern))
                        % non nan pattern found add it to sequence and
                        % encompass duration of preceding nans
                        newSeq(end+1) = struct('duration',t,'pattern',path_FOV.SLM(i).pattern);
                        t = 0;
                    elseif i == N
                        % sequence ends with a nan. make it an extension of
                        % the last pattern
                        if numel(newSeq) > 0
                            newSeq(end).duration = newSeq(end).duration + t;
                        else
                            % there were no non-nan patterns. use default
                            % pattern for entire duration
                            newSeq = struct('duration',t,'pattern',[0 0 0]);
                        end
                    end
                end
                
                %check for duplicates
                N = numel(newSeq);
                i = 1;
                while i < N
                    if all(size(newSeq(i).pattern) == size(newSeq(i+1).pattern)) && all(newSeq(i).pattern(:) == newSeq(i+1).pattern(:))
                        newSeq(i+1).duration = newSeq(i+1).duration + newSeq(i).duration;
                        newSeq(i) = [];
                        N = N - 1;
                    else
                        i = i+1;
                    end
                end
                
                path_FOV.SLM = newSeq;
            end
        end

        function [path_FOV, dt] = transitNaN(obj,scanfield_from,scanfield_to)
            path_FOV.SLMxyz = double.empty(0,3);
            dt = obj.transitTime(scanfield_from,scanfield_to);
            
            for idx = 1:numel(obj.beams)
                path_FOV.B(:,idx) = nan;
            end
        end
        
        function path_FOV = zFlybackFrame(obj, frameTime)
        end
        
        function path_FOV = padFrameAO(obj, path_FOV, frameTime, flybackTime, zWaveformType)
            % No-op
        end
        
         function v = frameFlybackTime(obj)
            v = 0;
        end

        function seconds = scanTime(obj,scanfield)
            %% Returns the time required to scan the scanfield in seconds
            if isa(scanfield,'scanimage.mroi.scanfield.fields.IntegrationField')
                seconds = 0;
                durationPerRepetitionInt = 0;
                durationPerRepetitionFrac = 0;
            elseif isa(scanfield, 'scanimage.mroi.scanfield.fields.StimulusField')
                seconds = scanfield.duration * scanfield.repetitions;
            else
                numPixels = prod(scanfield.pixelResolution);
                seconds = numPixels / obj.scanners{1}.sampleRateHz;
            end
        end

        function [lineScanPeriod,lineAcquisitionPeriod] = linePeriod(obj,scanfield)
            % Definition of lineScanPeriod:
            %   * scanPeriod is lineAcquisitionPeriod + includes the turnaround time for MROI scanning
            % Definition of lineAcquisitionPeriod:
            %   * lineAcquisitionPeriod is the period that is actually used for the image acquisition

            % These are set to the line scan period of the resonant scanner. Since the resonant scanner handles image
            % formation, these parameters do not have the same importance as in Galvo Galvo scanning.
            lineScanPeriod = scanfield.pixelResolution(1) / obj.scanners{1}.sampleRateHz;
            lineAcquisitionPeriod = lineScanPeriod;
        end

        function [startTimes, endTimes] = acqActiveTimes(obj,scanfield)
            % TODO: implement this
            startTimes = [NaN];
            endTimes   = [NaN];
        end

        function seconds = transitTime(obj,scanfield_from,scanfield_to)
            %% Returns the estimated time required to position the scanners when
            % moving from scanfield to scanfield.
            % Must be a multiple of the line time
            assert(scanimage.mroi.util.transitArgumentTypeCheck(scanfield_from,scanfield_to));
            seconds = 0;
        end
        
        function samplesPerTrigger = samplesPerTriggerForAO(obj,outputData)
            % input: unconcatenated output for the stack
            samplesPerTrigger = 0;
        end
        
        function cfg = beamsTriggerCfg(obj)
            cfg = struct();
            if obj.hasBeams
                cfg.triggerType = 'static';
                cfg.requiresReferenceClk = false;
            else
                cfg.triggerType = '';
                cfg.requiresReferenceClk = [];
            end
        end
    end
    
    %% Property Getter/Setter methods
    methods
        function v = get.angularRange(obj)
            v = obj.scanners{1}.angularRangeXY;
        end
        
        function v = get.zeroOrderBlockRadius(obj)
            v = obj.scanners{1}.zeroOrderBlockRadius;
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
