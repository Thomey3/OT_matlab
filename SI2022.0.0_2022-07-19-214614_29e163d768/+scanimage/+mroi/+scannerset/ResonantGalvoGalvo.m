classdef ResonantGalvoGalvo < scanimage.mroi.scannerset.ScannerSet

    properties
        fillFractionSpatial;
        extendedRggFov = true;
        angularRange;
        modifiedTimebaseSecsPerSec = 1;
        useScannerTimebase = false;
    end
    
    properties (Hidden)
        CONSTRAINTS = struct(...
            'scanimage_mroi_scanfield_ImagingField',...
              {{@scanimage.mroi.constraints.maxHeight @scanimage.mroi.constraints.maxWidth @scanimage.mroi.constraints.positiveWidth...
                @scanimage.mroi.constraints.sameWidth @scanimage.mroi.constraints.yCenterInRange @scanimage.mroi.constraints.sameRotation...
                @scanimage.mroi.constraints.samePixelsPerLine @scanimage.mroi.constraints.evenPixelsPerLine}}...
            );
    end
    
    properties (Constant)
        optimizableScanners = {'G','Z'};
    end

    methods(Static)
        function obj=default()
            %% Construct a default version of this scanner set for testing
            r=scanimage.mroi.scanners.Resonant.default();
            g=scanimage.mroi.scanners.Galvo.default();
            z=scanimage.mroi.scanners.FastZ.default();
            obj=scanimage.mroi.scannerset.ResonantGalvoGalvo(r,g,g,z);
            obj.refToScannerTransform = eye(3);
        end
    end
    
    methods
        function obj = ResonantGalvoGalvo(name,resonantx,galvox,galvoy,fastBeams,slowBeams,fastz,fillFractionSpatial)
            %% Describes a resonant-galvo-galvo scanner set.
            obj = obj@scanimage.mroi.scannerset.ScannerSet(name,fastBeams,slowBeams,fastz);
            
            scanimage.mroi.util.asserttype(resonantx,'scanimage.mroi.scanners.Resonant');
            if ~isempty(galvox)
                scanimage.mroi.util.asserttype(galvox,'scanimage.mroi.scanners.Galvo');
                obj.CONSTRAINTS.scanimage_mroi_scanfield_ImagingField{end+1} = @scanimage.mroi.constraints.xCenterInRange;
            else
                obj.CONSTRAINTS.scanimage_mroi_scanfield_ImagingField{end+1} = @scanimage.mroi.constraints.centeredX;
            end
            scanimage.mroi.util.asserttype(galvoy,'scanimage.mroi.scanners.Galvo');
            
            obj.name = name;
            obj.scanners={resonantx,galvox,galvoy};
            obj.fillFractionSpatial = fillFractionSpatial;
        end
        
        function path_FOV = refFovToScannerFov(obj,path_FOV)
            % transform to scanner space
            % assumes there is no rotation and pathFOV.R is unique (except for NANs)
            
            path_FOV.R = path_FOV.R * obj.refToScannerTransform(1);
            path_FOV.G = scanimage.mroi.util.xformPoints(path_FOV.G,obj.refToScannerTransform);
            
            % ensure we are scanning within the angular range of the scanners
            tol = 0.0001; % tolerance to account for rounding errors
            
            rng = obj.scanners{1}.fullAngleDegrees;
            assert(all(path_FOV.R >= 0-tol) && all(path_FOV.R <= rng+tol), 'Attempted to scan outside resonant scanner FOV.');
            path_FOV.R(path_FOV.R < 0) = 0;
            path_FOV.R(path_FOV.R > rng) = rng;
            
            if isempty(obj.scanners{2})
                rng = zeros(1,2);
            else
                rng = obj.scanners{2}.hDevice.travelRange;
            end
            assert(all(path_FOV.G(:,1) >= rng(1)-tol) && all(path_FOV.G(:,1) <= rng(2)+tol), 'Attempted to scan outside X galvo scanner FOV.');
            path_FOV.G(path_FOV.G(:,1) < rng(1),1) = rng(1);
            path_FOV.G(path_FOV.G(:,1) > rng(2),1) = rng(2);
            
            rng = obj.scanners{3}.hDevice.travelRange;
            assert(all(path_FOV.G(:,2) >= rng(1)-tol) && all(path_FOV.G(:,2) <= rng(2)+tol), 'Attempted to scan outside Y galvo scanner FOV.');
            path_FOV.G(path_FOV.G(:,2) < rng(1),2) = rng(1);
            path_FOV.G(path_FOV.G(:,2) > rng(2),2) = rng(2);
        end
        
        function ao_volts = pathFovToAo(obj,path_FOV)
            % transform to scanner space
            path_FOV = obj.refFovToScannerFov(path_FOV);
            
            % scanner space to volts
            ao_volts.R = obj.degrees2volts(path_FOV.R,1);
            ao_volts.G(:,1) = obj.degrees2volts(path_FOV.G(:,1),2);
            ao_volts.G(:,2) = obj.degrees2volts(path_FOV.G(:,2),3);
            
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
                if obj.hasPowerBox
                    ao_volts.Bpb(:,idx) = hBeam.hDevice.convertPowerFraction2Volt(path_FOV.Bpb(:,idx));
                end
            end
            
            for idx = 1:numel(obj.fastz)                
                ao_volts.Z(:,idx) = obj.fastz(idx).refPosition2Volts(path_FOV.Z(:,idx));
            end
        end
            
        function [path_FOV, seconds] = scanPathFOV(obj,scanfield,roi,actz,actzRelative,dzdt,zActuator,maxPtsPerSf)
            %% Returns struct. Each field has ao channel data in column vectors
            % 
            % ao_volts.R: resonant amplitude
            % ao_volts.G: galvo (columns are X,Y)
            % ao_volts.B: beams (columns are beam1,beam2,...,beamN)
            %
            % Output should look like:
            % 1.  Resonant_amplitude is constant.  Set for width of scanned
            %     field
            % 2.  Galvo_x is constant at center of scanned field
            % 3.  Galvo_y is continuously moving down the field.
            assert(isa(scanfield,'scanimage.mroi.scanfield.ScanField'));
            seconds=obj.scanTime(scanfield);
            
            if obj.scanners{3}.useScannerTimebase
                secondsG = seconds * obj.modifiedTimebaseSecsPerSec;
            else
                secondsG = seconds;
            end
            
            gsamples=round(secondsG*obj.scanners{3}.sampleRateHz);
            
            rfov = scanfield.sizeXY(1);
            
            gfov(:,1)= scanfield.centerXY(1) * ones(gsamples,1);

            hysz = scanfield.sizeXY(2)/2;
            gfov(:,2)=linspace(scanfield.centerXY(2)-hysz,scanfield.centerXY(2)+hysz,gsamples);
            
            path_FOV.R = round(rfov * 1000000 / obj.fillFractionSpatial) / 1000000;
            path_FOV.G(:,1) = gfov(:,1);
            path_FOV.G(:,2) = gfov(:,2);
            
            %% Beams AO
            for beamIdx = 1:numel(obj.beams)
                hBeam = obj.beams(beamIdx);
                
                % get roi specific beam settings
                hBeam = hBeam.applySettingsFromRoi(roi);
                
				if(isa(hBeam,'scanimage.mroi.scanners.FastBeam'))
	                fillFractionSpatial_ = obj.scanners{1}.fillFractionSpatial;
	                fillFractionTemporal_ = obj.scanners{1}.fillFractionTemporal;
                
	                % determine number of samples
	                [~,lineAcquisitionPeriod] = obj.linePeriod(scanfield);
	                lineScanPeriod = lineAcquisitionPeriod / fillFractionTemporal_;
                
	                bSamplesPerLine = ceil((lineAcquisitionPeriod + hBeam.beamClockDelay + hBeam.beamClockExtend)*hBeam.sampleRateHz) + 1;
	                npixels = scanfield.pixelResolution(1);
	                nlines  = scanfield.pixelResolution(2);

	                powerFraction = hBeam.powerFraction;
	                pzAdjust = hBeam.pzAdjust;
	                interlaceDecimation = hBeam.interlaceDecimation;
	                interlaceOffset = hBeam.interlaceOffset;
                
	                % start with nomimal power fraction sample array for single line                
	                timestep = 1/hBeam.sampleRateHz;
	                beamSampletimes = (0:(bSamplesPerLine-1)) * timestep + (lineScanPeriod-lineAcquisitionPeriod)/2;
	                beamSamplepositionsXX = sin(pi*beamSampletimes/lineScanPeriod - pi/2) / 2 + 0.5;
	                beamSamplepositionsXX = (beamSamplepositionsXX - (1-fillFractionSpatial_)/2) / fillFractionSpatial_;
                    beamSamplepositionsXX = round(beamSamplepositionsXX,6); % this is necessary to force the leftmost xx to 0 (otherwise it might be something like -1E-17), and it won't get masked out
                
	                [beamSamplePositionXX,beamSamplePositionYY] = ndgrid(beamSamplepositionsXX,linspace(0,1,nlines));
                
	                if obj.scanners{1}.bidirectionalScan
	                    beamSamplePositionXX(:,2:2:end) = 1-beamSamplePositionXX(:,2:2:end);
	                end
                
	                powerFracs = repmat(powerFraction,size(beamSamplePositionXX));
	                powerFracsPb = powerFracs;
                
	                for pb = hBeam.powerBoxes
                        if ~isempty(pb.zs) && ~any(pb.zs==actz)
                            continue
                        end

	                    if isnan(pb.powers)
	                        pb.powers = powerFraction;
	                    end
                    
	                    if isempty(pb.mask)
	                        mask = nan(size(beamSamplePositionXX));
	                        mask(beamSamplePositionXX>=pb.rect(1) & beamSamplePositionXX<=pb.rect(1)+pb.rect(3) ...
	                           & beamSamplePositionYY>=pb.rect(2) & beamSamplePositionYY<=pb.rect(2)+pb.rect(4) ) = 1;
	                    else
	                        mask = pb.mask';
	                        maskResXY = [size(mask,1),size(mask,2)];
	                        x = pb.rect(1);
	                        y = pb.rect(2);
	                        w = pb.rect(3);
	                        h = pb.rect(4);
	                        pixw = w/maskResXY(1);
	                        pixh = h/maskResXY(2);
	                        [maskXX,maskYY] = ndgrid(linspace(x+pixw/2,x+w-pixw/2,maskResXY(1)) ...
	                                                ,linspace(y+pixh/2,y+h-pixh/2,maskResXY(2)));
                        
	                        interpolationMethod = 'nearest';
	                        extrapolationMethod = 'nearest';
	                        hInt = griddedInterpolant(maskXX,maskYY,mask,interpolationMethod,extrapolationMethod);
	                        mask = hInt(beamSamplePositionXX,beamSamplePositionYY);
                        
	                        mask(beamSamplePositionXX<pb.rect(1) | beamSamplePositionXX>pb.rect(1)+pb.rect(3) ...
	                           | beamSamplePositionYY<pb.rect(2) | beamSamplePositionYY>pb.rect(2)+pb.rect(4) ) = NaN;
	                    end
                    
	                    if ~pb.oddLines
	                        mask(:,1:2:end) = NaN;
	                    end
                    
	                    if ~pb.evenLines
	                        mask(:,2:2:end) = NaN;
                        end
	                    powerFracsPb(~isnan(mask)) = mask(~isnan(mask)) .* pb.powers;
	                end
                
                
	                % zero last sample of line if blanking flyback. beam decimation requires blanking
	                if hBeam.flybackBlanking || interlaceDecimation>1
	                    powerFracs(beamSamplepositionsXX>1,:) = 0;
	                    powerFracsPb(beamSamplepositionsXX>1,:) = 0;
	                end
                
	                % filter interlace decimation
	                lineEnableMask = interlaceOffset+1:interlaceDecimation:nlines;
	                powerFracs(:,~lineEnableMask) = powerFracs(:,~lineEnableMask) * 0; % preserve NaNs
	                powerFracsPb(:,~lineEnableMask) = powerFracsPb(:,~lineEnableMask) * 0; % preserve NaNs

	                if pzAdjust
	                    actzBeam = actz;
                    
	                    if numel(actzRelative) >= beamIdx
	                        % if there are multiple fastZ, assign each beam to the
	                        % corresponding fastZ
	                        deltaZ = actzRelative(beamIdx)-actzRelative(1);
	                        actzBeam = actz + deltaZ;
	                    end
                    
	                    beamSampleTimes = repmat(beamSampletimes(:),1,nlines);
	                    beamSampleTimes = bsxfun(@plus,beamSampleTimes,(0:(nlines-1))*lineScanPeriod);
	                    lineSampleZs = actzBeam + beamSampleTimes * dzdt;
                    
	                    nanMask = isnan(powerFracs);
	                    nanMaskPb = isnan(powerFracsPb);
                    
	                    powerFracs = hBeam.powerDepthCorrectionFunc(powerFracs(:), lineSampleZs(:));
	                    powerFracs = reshape(powerFracs,size(lineSampleZs));
	                    if obj.hasPowerBox
	                        powerFracsPb = hBeam.powerDepthCorrectionFunc(powerFracsPb(:), lineSampleZs(:));
	                        powerFracsPb = reshape(powerFracsPb,size(lineSampleZs));
	                    end
                    
	                    % preserve NaNs
	                    powerFracs(nanMask) = NaN;
	                    powerFracsPb(nanMaskPb) = NaN;
	                end
					
					if ~isfield(path_FOV,'B')
                        path_FOV.B = [];
					end	
					
	                path_FOV.B(:,end+1) = powerFracs(:);
                
	                if obj.hasPowerBox
                        if ~isfield(path_FOV,'Bpb')
                            path_FOV.Bpb = [];
                        end
	                    path_FOV.Bpb(:,end+1) = powerFracsPb(:);
	                end
				end
            end
            
            for fastzIdx = 1:numel(obj.fastz)
                if obj.fastz(fastzIdx).useScannerTimebase
                    seconds = secondsG;
                    dzdt = dzdt / obj.modifiedTimebaseSecsPerSec;
                end
                
                path_FOV.Z(:,fastzIdx) = obj.fastz(fastzIdx).scanPathFOV(obj,actz,actzRelative(fastzIdx),dzdt,seconds,path_FOV.G);
            end
        end
        
        function calibrateScanner(obj,scanner,hWb)
            if nargin < 3 || isempty(hWb)
                hWb = [];
            end
            
            switch upper(scanner)
                case 'G'
                    if ~isempty(obj.scanners{2})
                        obj.scanners{2}.hDevice.calibrate(hWb);
                    end
                    obj.scanners{3}.hDevice.calibrate(hWb);
                case 'Z'
                    for idx = 1:numel(obj.fastz)
                        obj.fastz(idx).hDevice.calibrate(hWb);
                    end
                otherwise
                    error('Cannot optimized scanner %s', scanner);
            end
        end
        
        %% Optimization Functions
        
        function ClearCachedWaveform(obj, scanner, ao_volts, sampleRateHz)
            switch upper(scanner)
                case 'G'
                    assert(size(ao_volts,2)==2);
                    
                    if ~isempty(obj.scanners{2})
                        if nargin < 4 || isempty(sampleRateHz)
                            sampleRateHz = obj.scanners{2}.sampleRateHz;
                        end
                        obj.scanners{2}.hDevice.clearCachedWaveform(sampleRateHz, ao_volts(:,1));
                    end
                    
                    if nargin < 4 || isempty(sampleRateHz)
                        sampleRateHz = obj.scanners{3}.sampleRateHz;
                    end
                    obj.scanners{3}.hDevice.clearCachedWaveform(sampleRateHz, ao_volts(:,2));
                case 'Z'
                    if nargin < 4 || isempty(sampleRateHz)
                        sampleRateHz = obj.fastz(1).sampleRateHz;
                    end
                    assert(size(ao_volts,2)==1);
                    obj.fastz.hDevice.clearCachedWaveform(sampleRateHz, ao_volts);
                otherwise
                    error('Cannot clear optimized ao for scanner %s', scanner);
            end
            
        end
        
        function ClearCache(obj, scanner)
           switch upper(scanner)
               case 'G'
                   if ~isempty(obj.scanners{2})
                       obj.scanners{2}.hDevice.clearCache();
                   end
                   obj.scanners{3}.hDevice.clearCache();
               case 'Z'
                   obj.fastz.hDevice.clearCache();
               otherwise
                   error('Cannot clear cache for scanner %s', scanner);
           end
        end
        
        
        function [ao_volts_out,metaData] = retrieveOptimizedAO(obj, scanner, ao_volts, sampleRateHz) 
            ao_volts_out = [];
            metaData = [];
            switch upper(scanner)
                case 'G'
                    % Check for 2 columns
                    assert(size(ao_volts,2)==2);
                    % Check for provided sample rate
                    if nargin < 4 || isempty(sampleRateHz)
                        sampleRateHz = obj.scanners{3}.sampleRateHz;
                    end
                    
                    if isempty(obj.scanners{2})
                        metaData_X = [];
                        ao_volts_optimized_X = [];
                    else
                        [metaData_X,ao_volts_optimized_X] = obj.scanners{2}.hDevice.getCachedOptimizedWaveform(sampleRateHz,ao_volts(:,1));
                    end
                    
                    if isempty(obj.scanners{3})
                        metaData_Y = [];
                        ao_volts_optimized_Y = [];
                    else
                        [metaData_Y,ao_volts_optimized_Y] = obj.scanners{3}.hDevice.getCachedOptimizedWaveform(sampleRateHz,ao_volts(:,2));
                    end
                    
                    % generate output
                    ao_volts_out = [];
                    metaData = [];
                    
                    if isempty(obj.scanners{2})
                        % RG: no x galvo present
                        if ~isempty(metaData_Y)
                            ao_volts_out(:,2) = ao_volts_optimized_Y;
                            metaData = metaData_Y;
                        end
                    else
                        % RGG x and y galvos present
                        if ~isempty(metaData_X) && ~isempty(metaData_Y)
                            ao_volts_out = horzcat(ao_volts_optimized_X,ao_volts_optimized_Y);
                            metaData = [metaData_X metaData_Y];
                        end
                    end                    
                    
                case 'Z'
                    if nargin < 4 || isempty(sampleRateHz)
                        sampleRateHz = obj.fastz.sampleRateHz;
                    end
                    %assert(size(ao_volts,2)==1);
                    
                    metaData = {};
                    
                    for idx = 1:numel(obj.fastz)
                        [metaData_,ao_volts_temp] = obj.fastz(idx).hDevice.getCachedOptimizedWaveform(sampleRateHz,ao_volts(:,idx));
                        if ~isempty(metaData_)
                            ao_volts_out(:,idx) = ao_volts_temp;
                            metaData{idx} = metaData_;
                        end
                    end
                    
                    metaData = horzcat(metaData{:});
                    
                otherwise
                    error('Cannot get cached optimized ao for scanner %s',scanner);
            end
        end
        
        function ao_volts = optimizeAO(obj,scanner,ao_volts,updateCallback,sampleRateHz)
            if nargin > 3 && ~isempty(updateCallback)
                optFunc = @(varargin)optimizeWaveformIterativelyAsync(varargin{:},updateCallback);
            else
                optFunc = @(varargin)optimizeWaveformIteratively(varargin{:});
            end
            
            switch upper(scanner)
                case 'G'
                    assert(size(ao_volts,2)==2);
                    if ~isempty(obj.scanners{2})
                        if nargin < 5 || isempty(sampleRateHz)
                            rate = obj.scanners{2}.sampleRateHz;
                        end
                        ao_volts(:,1) = optFunc(obj.scanners{2}.hDevice,ao_volts(:,1),rate);
                    end
                    
                    if nargin < 5 || isempty(sampleRateHz)
                        rate = obj.scanners{3}.sampleRateHz;
                    end
                    ao_volts(:,2) = optFunc(obj.scanners{3}.hDevice,ao_volts(:,2),rate);
                case 'Z'
                    if nargin < 5 || isempty(sampleRateHz)
                        rate = obj.fastz(1).sampleRateHz;
                    end
                    assert(size(ao_volts,2)==1);
                    ao_volts = optFunc(obj.fastz.hDevice,ao_volts,rate);
                otherwise
                    error('Cannot optimize ao for scanner %s',scanner);
            end
        end
        
        function feedback = testAO(obj, scanner, ao_volts, updateCallback, sampleRateHz)
            % take scanner name, convert to upper case, handle differently
            % for each option (galvo, piezo)
            switch upper(scanner)
                case 'G'
                    assert(size(ao_volts,2)==2);
                    feedback = nan(size(ao_volts));
                    if ~isempty(obj.scanners{2})
                        if nargin < 5 || isempty(sampleRateHz)
                            rate = obj.scanners{2}.sampleRateHz;
                        end
                        feedback(:,1) = obj.scanners{2}.hDevice.testWaveformAsync(ao_volts(:,1),rate,updateCallback);
                    end
                    
                    if nargin < 5 || isempty(sampleRateHz)
                        rate = obj.scanners{3}.sampleRateHz;
                    end
                    feedback(:,2) = obj.scanners{3}.hDevice.testWaveformAsync(ao_volts(:,2),rate,updateCallback);
                    
                case 'Z'
                    if nargin < 5 || isempty(sampleRateHz)
                        sampleRateHz = obj.fastz(1).sampleRateHz;
                    end
                    assert(size(ao_volts,2)==1);
                    feedback = obj.fastz.hDevice.testWaveformAsync(ao_volts,sampleRateHz,updateCallback);
                otherwise
                    error('Cannot optimize ao for scanner %s',scanner);
            end
        end
        
        function v = hasSensor(obj, scanner)
            switch upper(scanner)
                case 'G'
                    v = isempty(obj.scanners{2}) || obj.scanners{2}.hDevice.feedbackAvailable;
                    v = v && obj.scanners{3}.hDevice.feedbackAvailable;
                case 'Z'
                    v = logical.empty(1,0);
                    for idx = 1:numel(obj.fastz)
                        v(idx) = obj.fastz(idx).hDevice.feedbackAvailable;
                    end
                otherwise
                    error('No sensor for scanner %s',scanner);
            end
        end
        
        function v = sensorCalibrated(obj, scanner)
            switch upper(scanner)
                case 'G'
                    v = isempty(obj.scanners{2}) || obj.scanners{2}.hDevice.feedbackCalibrated;
                    v = v && obj.scanners{3}.hDevice.feedbackCalibrated;
                case 'Z'
                    v = logical.empty(1,0);
                    for idx = 1:numel(obj.fastz)
                        v = obj.fastz(idx).hDevice.feedbackCalibrated;
                    end
                otherwise
                    error('No sensor for scanner %s',scanner);
            end
        end
        
        
        %%
        function position_FOV = mirrorsActiveParkPosition(obj)
            position_FOV=zeros(1,3);
            position_FOV(:,1) = NaN; % we can't really calculate that here. the resonant scanner amplitude should not be touched for the flyback. NaN makes sure that nobody accidentally tries to use this value.
            if ~isempty(obj.scanners{2})
                position_FOV(:,2) = obj.scanners{2}.hDevice.parkPosition;
            else
                position_FOV(:,2) = 0;
            end
            position_FOV(:,3) = obj.scanners{3}.hDevice.parkPosition;
            position_FOV(:,2:3) = scanimage.mroi.util.xformPoints(position_FOV(:,2:3),obj.scannerToRefTransform);
        end

        function path_FOV = interpolateTransits(obj,path_FOV,tuneZ,zWaveformType)
            if nargin < 3
                tuneZ = true;
            end
            if nargin < 4
                zWaveformType = '';
            end
            
            if ~isempty(obj.scanners{2})
                xrg = diff(obj.scanners{2}.hDevice.travelRange);
            else
                xrg = 0;
            end
            
            pts = [xrg diff(obj.scanners{3}.hDevice.travelRange)];
            pts = [-pts; pts] * .5;
            pts = scanimage.mroi.util.xformPoints(pts,obj.scannerToRefTransform);
            
            xGalvoRg = [pts(1,1) pts(2,1)];
            yGalvoRg = [pts(1,2) pts(2,2)];
            
            path_FOV.R = max(path_FOV.R);
            path_FOV.G(:,1) = scanimage.mroi.util.interpolateCircularNaNRanges(path_FOV.G(:,1),xGalvoRg);
            path_FOV.G(:,2) = scanimage.mroi.util.interpolateCircularNaNRanges(path_FOV.G(:,2),yGalvoRg);
            
            % beams ao
            for idx = 1:numel(obj.beams)
                hBeam = obj.beams(idx);
                if hBeam.flybackBlanking || hBeam.interlaceDecimation>1
                    nanMask = isnan(path_FOV.B(:,idx));
                    path_FOV.B(nanMask,idx) = 0;
                else
                    path_FOV.B(:,idx) = scanimage.mroi.util.expInterpolateCircularNaNRanges(path_FOV.B(:,idx),hBeam.Lz);
                    path_FOV.B(end,idx) = 0;
                end
                
                if obj.hasPowerBox
                    if hBeam.flybackBlanking || hBeam.interlaceDecimation>1
                        nanMask = isnan(path_FOV.Bpb(:,idx));
                        path_FOV.Bpb(nanMask,idx) = 0;
                    else
                        path_FOV.Bpb(:,idx) = scanimage.mroi.util.expInterpolateCircularNaNRanges(path_FOV.Bpb(:,idx),hBeam.Lz);
                        path_FOV.Bpb(end,idx) = 0;
                    end
                end
            end
            
            for idx = 1:numel(obj.fastz)
                path_FOV.Z(:,idx) = obj.fastz(idx).interpolateTransits(obj,path_FOV.Z(:,idx),tuneZ,zWaveformType);
            end
        end

        function [path_FOV, dt] = transitNaN(obj,scanfield_from,scanfield_to)
            assert(scanimage.mroi.util.transitArgumentTypeCheck(scanfield_from,scanfield_to));
            
            dt = obj.transitTime(scanfield_from,scanfield_to);
            if isnan(scanfield_to)
                dt = 0; % flyback time is added in padFrameAO
            end      
            
            path_FOV.R = nan;
            
            gsamples = round(dt*obj.scanners{3}.sampleRateHz);
            path_FOV.G = nan(gsamples,2);
            
            if obj.hasBeams
                [lineScanPeriod,lineAcquisitionPeriod] = obj.linePeriod([]);
                bSamplesPerLine = ceil((lineAcquisitionPeriod + obj.beams(1).beamClockDelay + obj.beams(1).beamClockExtend).*obj.beams(1).sampleRateHz) + 1;
                nlines = round(dt/lineScanPeriod);
                path_FOV.B = nan(bSamplesPerLine*nlines,numel(obj.beams));
                if obj.hasPowerBox
                    path_FOV.Bpb = path_FOV.B;
                end
            end
            
            for idx = 1:numel(obj.fastz)
                path_FOV.Z(:,idx) = obj.fastz(idx).transitNaN(obj,dt);
            end
        end
        
        function path_FOV = zFlybackFrame(obj, frameTime)
            frameTimeRTB = frameTime * obj.modifiedTimebaseSecsPerSec;
            
            if obj.scanners{3}.useScannerTimebase
                path_FOV.R = [];
                path_FOV.G = nan(round(obj.nsamples(obj.scanners{3},frameTimeRTB)),2);
            else
                path_FOV.R = [];
                path_FOV.G = nan(round(obj.nsamples(obj.scanners{3},frameTime)),2);
            end
            
            % Beams AO
            for idx = 1:numel(obj.beams)
                hBeam = obj.beams(idx);
                [lineScanPeriod,lineAcquisitionPeriod] = obj.linePeriod([]);
                bSamplesPerLine = ceil((lineAcquisitionPeriod + hBeam.beamClockDelay + hBeam.beamClockExtend)*hBeam.sampleRateHz) + 1;
                nlines = round(frameTime/lineScanPeriod);
                
                path_FOV.B(:,idx) = NaN(bSamplesPerLine*nlines,1);
                
                if hBeam.flybackBlanking
                    path_FOV.B(:,idx) = 0;
                end
                
                if obj.hasPowerBox
                    path_FOV.Bpb(:,idx) = path_FOV.B(:,idx);
                end
            end
            
            for idx = 1:numel(obj.fastz)
                if obj.fastz(idx).useScannerTimebase
                    frameTime = frameTimeRTB;
                end
                path_FOV.Z(:,idx)= obj.fastz(idx).zFlybackFrame(obj,frameTime);
            end
        end
        
        function path_FOV = padFrameAO(obj, path_FOV, frameTime, flybackTime, zWaveformType)
            waveformTime = frameTime + flybackTime;
            waveformTimeRTB = waveformTime * obj.modifiedTimebaseSecsPerSec;
            
            if obj.useScannerTimebase
                Ns = ceil(obj.nsamples(obj.scanners{3},frameTime + flybackTime));
            elseif obj.scanners{3}.useScannerTimebase
                % 40us gap between waveforms to allow for period drift
                % and scan phase adjustments
                marg = 40e-6 * obj.scanners{3}.sampleRateHz;
                Ns = ceil(obj.nsamples(obj.scanners{3},waveformTimeRTB)-marg);
            else
                Ns = ceil(obj.nsamples(obj.scanners{3},frameTime + flybackTime/2));
            end
            padSamples = Ns - size(path_FOV.G,1); % cut off half of the flyback time to leave some breathing room to receive the next frame trigger
            if padSamples > 0
                path_FOV.G(end+1:end+padSamples,:) = NaN;
            end
            
            % Beams AO
            if obj.hasBeams
                hBeam = obj.beams(1);
                [lineScanPeriod,lineAcquisitionPeriod] = obj.linePeriod([]);
                bSamplesPerLine = ceil((lineAcquisitionPeriod + hBeam.beamClockDelay + hBeam.beamClockExtend)*hBeam.sampleRateHz) + 1;
                
                if hBeam.includeFlybackLines
                    t = frameTime + flybackTime;
                else
                    t = frameTime;
                end
                nlines = round(t/lineScanPeriod);
                
                nTotalSamples = bSamplesPerLine * nlines;
                padSamples = nTotalSamples - size(path_FOV.B,1);
                if padSamples > 0
                    path_FOV.B(end+1:end+padSamples,:) = NaN;
                    if obj.hasPowerBox
                        path_FOV.Bpb(end+1:end+padSamples,:) = NaN;
                    end
                end
            end
            
            if ~isempty(obj.fastz)
                Z_ = {};
                for idx = 1:numel(obj.fastz)
                    if obj.fastz(idx).useScannerTimebase
                        waveformTime = waveformTimeRTB - 1/obj.fastz(idx).sampleRateHz;
                    end
                    Z_{idx} = obj.fastz(idx).padFrameAO(obj, path_FOV.Z(:,idx), waveformTime, zWaveformType);
                end
                path_FOV.Z = horzcat(Z_{:});
            end
        end
        
        function v = frameFlybackTime(obj)
            v = obj.scanners{3}.flybackTimeSeconds;
        end

        function seconds = scanTime(obj,scanfield)
            %% Returns the time required to scan the scanfield in seconds
            if isa(scanfield,'scanimage.mroi.scanfield.fields.IntegrationField')
                seconds = 0;
            else
                numLines = scanfield.pixelResolution(2);
                seconds = (numLines/2^(obj.scanners{1}.bidirectionalScan))*obj.scanners{1}.scannerPeriod; %eg 512 lines / (7920 lines/s)
                % dont coerce to galvo sample rate
%                 numSamples = round(seconds * obj.scanners{3}.sampleRateHz);
%                 seconds = numSamples / obj.scanners{3}.sampleRateHz;
            end
        end

        function [lineScanPeriod,lineAcquisitionPeriod] = linePeriod(obj,scanfield)
            % Definition of lineScanPeriod:
            %   * scanPeriod is lineAcquisitionPeriod + includes the turnaround time for MROI scanning
            % Definition of lineAcquisitionPeriod:
            %   * lineAcquisitionPeriod is the period that is actually used for the image acquisition

            % These are set to the line scan period of the resonant scanner. Since the resonant scanner handles image
            % formation, these parameters do not have the same importance as in Galvo Galvo scanning.
            lineScanPeriod = obj.scanners{1}.scannerPeriod / 2^(obj.scanners{1}.bidirectionalScan);
            lineAcquisitionPeriod = obj.scanners{1}.scannerPeriod / 2 * obj.scanners{1}.fillFractionTemporal;
        end

        function [startTimes, endTimes] = acqActiveTimes(obj,scanfield)
            % TODO: implement this
            startTimes = NaN;
            endTimes   = NaN;
        end

        function seconds = transitTime(obj,scanfield_from,scanfield_to)
            %% Returns the estimated time required to position the scanners when
            % moving from scanfield to scanfield.
            % Must be a multiple of the line time
            assert(scanimage.mroi.util.transitArgumentTypeCheck(scanfield_from,scanfield_to));

            % FIXME: compute estimated transit time for reals
            % caller should constraint this to be an integer number of periods
            if isnan(scanfield_from)
                seconds = 0; % do not scan first flyto in plane
            elseif isnan(scanfield_to)
                seconds = max(obj.scanners{3}.flybackTimeSeconds,obj.scanners{3}.flybackTimeSeconds);
            else
                seconds = max(obj.scanners{3}.flytoTimeSeconds,obj.scanners{3}.flytoTimeSeconds);
            end
        end
        
        function samplesPerTrigger = samplesPerTriggerForAO(obj,outputData)
            % input: unconcatenated output for the stack
            samplesPerTrigger.G = max( cellfun(@(frameAO)size(frameAO.G,1),outputData) );
            
            if obj.hasBeams
                [~,lineAcquisitionPeriod] = obj.linePeriod([]);
                samplesPerTrigger.B = ceil((lineAcquisitionPeriod + obj.beams(1).beamClockDelay + obj.beams(1).beamClockExtend)*obj.beams(1).sampleRateHz) + 1;
            end
            
            if obj.hasFastZ
                samplesPerTrigger.Z = obj.fastz.samplesPerTriggerForAO(obj,outputData);
            end
        end
        
        function cfg = beamsTriggerCfg(obj)
            cfg = struct();
            if obj.hasBeams
                cfg.triggerType = 'lineClk';
                cfg.requiresReferenceClk = false;
            else
                cfg.triggerType = '';
                cfg.requiresReferenceClk = [];
            end
        end
        
        function v = resonantScanFov(obj, roiGroup)
            % returns the resonant fov that will be used to scan the
            % roiGroup. Assumes all rois will have the same x fov
            if ~isempty(roiGroup.activeRois) && ~isempty(roiGroup.activeRois(1).scanfields)
                %avoid beam and fast z ao generation
                b = obj.beams;
                z = obj.fastz;
                obj.beams = [];
                obj.fastz = [];
                
                try
                    [path_FOV,~] = obj.scanPathFOV(roiGroup.activeRois(1).scanfields(1),roiGroup.activeRois(1),0,0,0,'');
                    path_FOV = obj.refFovToScannerFov(path_FOV);
                    v = path_FOV.R(1);
                catch ME
                    obj.beams = b;
                    obj.fastz = z;
                    ME.rethrow;
                end
                
                obj.beams = b;
                obj.fastz = z;
            else
                v = 0;
            end
        end
        
        function v = resonantScanVoltage(obj, roiGroup)
            % returns the resonant voltage that will be used to scan the
            % roiGroup. Assumes all rois will have the same x fov
            if ~isempty(roiGroup.activeRois) && ~isempty(roiGroup.activeRois(1).scanfields)
                %avoid beam and fast z ao generation
                b = obj.beams;
                z = obj.fastz;
                obj.beams = {};
                obj.fastz = {};
                
                try
                    [path_FOV,~] = obj.scanPathFOV(roiGroup.activeRois(1).scanfields(1),roiGroup.activeRois(1),0,0,0);
                    ao_volts = obj.pathFovToAo(path_FOV);
                    v = ao_volts.R(1);
                catch ME
                    obj.beams = b;
                    obj.fastz = z;
                    ME.rethrow;
                end
                
                obj.beams = b;
                obj.fastz = z;
            else
                v = 0;
            end
        end
    end

    methods
        function volts=degrees2volts(obj,fov,iscanner)
            s=obj.scanners{iscanner};
            if isa(s,'scanimage.mroi.scanners.Resonant')
                volts = fov;
            elseif (iscanner == 2) && isempty(s)
                volts = fov;
            else
                volts = s.hDevice.position2Volts(fov);
            end
        end
    end
    
    %% Property access methods
    methods
        function v = get.angularRange(obj)
            if obj.extendedRggFov && ~isempty(obj.scanners{2})
                v = [obj.scanners{1}.fullAngleDegrees+diff(obj.scanners{2}.hDevice.travelRange) diff(obj.scanners{3}.hDevice.travelRange)];
            else
                v = [obj.scanners{1}.fullAngleDegrees diff(obj.scanners{3}.hDevice.travelRange)];
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
