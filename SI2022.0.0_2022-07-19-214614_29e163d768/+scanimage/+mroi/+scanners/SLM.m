classdef SLM < handle
    % defines the SLM base functionality
    properties (SetAccess = immutable)
        name;
    end
    
    properties (SetObservable)
        hDevice;
        lut = [];                               % [Nx2 numeric] first column radiants, second column pixel values
        wavefrontCorrectionNominal = [];        % [NxM numeric] wavefront correction image in radians (non transposed)
        wavefrontCorrectionNominalWavelength_um = []; % [numeric] wavelength in micrometer, at which nominal wavefront correction was measured
        wavelength_um  = 635e-3;                % numeric, wavelength of incident light in micrometer
        focalLength_um = 500e3;                 % [numeric] focal length of the SLM imaginglens in micrometer
        slmMediumRefractiveIdx = 1.000293;      % Refractive index of medium SLM works in. (typically air, 1.000293).
        objectiveMediumRefractiveIdx = 1.333;   % Refractive index of medium objective works in. (typically water, 1.333).
        slmMagnificationOntoGalvos = 1;
        
        zeroOrderBlockRadius = 0;
        
        updatedTriggerIn = [];
        sampleRateHz = 100;
        
        computationDatatype = 'single';
        bidirectionalScan = true;
        
        hParkPosition = [];
        beamProfile = [];                       % [MxN]intensity profile of the beam at every pixel location of the SLM
        
        useGPUIfAvailable = true;
    end
    
    properties (Dependent)
        angularRangeXY;
        scanDistanceRangeXYObjective;
        computationDatatypeNumBytes;
    end
    
    properties (Dependent, SetAccess = private)
        wavefrontCorrectionCurrentWavelength;
        gpuActivated;
    end
    
    properties (SetAccess = private,SetObservable)
        lastWrittenPhaseMask;
        hPtLastWritten = scanimage.mroi.coordinates.Points.empty(0,1);
        
        hCoordinateSystem; % Objective
        hCSDiffractionEfficiency;
        hCSPixel
        
        hPhaseMaskDisplay;
    end

    properties (Dependent)
        lastWrittenPoint;
    end
    
    properties (SetAccess = private,Hidden,SetObservable)
        geometryBuffer;
        linearLutBuffer;
    end
    
    %% LifeCycle
    methods
        function obj = SLM(name)
            validateattributes(name,{'char'},{'row'});
            
            obj.name = name;
            
            obj.hCoordinateSystem = scanimage.mroi.coordinates.CSLinear([obj.name ' Objective um'],3); % Hologram under objective
            
            % Note: The diffraction efficiency is measured under the
            % objective. It makes sense defining hCSDiffractionEfficiency
            % relative to the objective space
            obj.hCSDiffractionEfficiency = scanimage.mroi.coordinates.CSLut([obj.name ' Diffraction Efficiency LUT'],3,obj.hCoordinateSystem);
            obj.hCSDiffractionEfficiency.resetFcnHdl = @resetCSDiffractionEfficiency;
            obj.hCSDiffractionEfficiency.reset();
            
            obj.hCSPixel = scanimage.mroi.coordinates.CSLinear([obj.name 'Pixel coordinates'],3,obj.hCoordinateSystem);
            obj.hCSPixel.lock = true;
            
            obj.hParkPosition = obj.wrapPointsCSObjective([0 0 0]);
            
            function resetCSDiffractionEfficiency(hCS)
                hI = griddedInterpolant();
                hI.GridVectors = {[0,1],[0,1],[0,1]};
                hI.Values = ones(2,2,2);
                hCS.fromParentInterpolant{1} = hI;
            end
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hDevice);
        end
    end
    
    %% Abstract methods
    
    %% User methods
    methods
        function showPhaseMaskDisplay(obj)
            if ~most.idioms.isValidObj(obj.hPhaseMaskDisplay)
                obj.hPhaseMaskDisplay = scanimage.guis.SlmPhaseMask(obj);
            end
            
            obj.hPhaseMaskDisplay.raise();
        end
        
        function out = rad2PixelVal(obj,in)
            assert(~isempty(obj.lut),'No lut specified');
            
            if ~isempty(obj.geometryBuffer.wavefrontCorrection)
                in = in + obj.geometryBuffer.wavefrontCorrection;
            end
            
            out = obj.lut.apply(in);
        end
        
        function lut_ = loadLutFromFile(obj,filePath)
            lut_ = [];
            if nargin < 2 || isempty(filePath)
                [fileName,filePath] = uigetfile('*.*','Select look up table file');
                if isequal(fileName,0)
                    % cancelled by user
                    return
                else
                    filePath = fullfile(filePath,fileName);
                end
            end
            
            assert(logical(exist(filePath,'file')),'File %s could not be found on disk.',filePath);
            
            if most.idioms.isMatFile(filePath)
                s = load(filePath,'-mat');
                s = s.s;
                lut_ = scanimage.mroi.scanners.slmLut.SlmLut.load(s);
            else
                lut_ = obj.parseLutFromFile(filePath);
                lut_ = scanimage.mroi.scanners.slmLut.SlmLutGlobal(lut_);
            end
            
            if nargout < 1
                obj.lut = lut_;
            end
        end
        
        function saveLutToFile(obj,filePath)            
            if nargin < 2 || isempty(filePath)
                defaultName = sprintf('%.0fum.lut',obj.wavelength_um);
                [fileName,filePath] = uiputfile('*.lut','Select look up table file name',defaultName);
                if isequal(fileName,0)
                    % cancelled by user
                    return
                else
                    filePath = fullfile(filePath,fileName);
                end
            end
            
            assert(~isempty(obj.lut),'No LUT is available for saving');
            
            if isa(obj.lut,'scanimage.mroi.scanners.slmLut.SlmLutGlobal')
                hFile = fopen(filePath,'w');
                try
                    assert(hFile>0,'Error creating file %s.',filePath);
                    fprintf(hFile,'%f\t%f\n',obj.lut.lut');
                catch ME
                    fclose(hFile);
                    rethrow(ME);
                end
                fclose(hFile);
            else
                s = obj.lut.save();
                save(filePath,'s');
            end
        end
        
        function [wc,wavelength_um] = loadWavefrontCorrectionFromFile(obj,filePath,wavelength_um)
            if nargin < 2 || isempty(filePath)
                [fileName,filePath] = uigetfile('*.*','Select wavefront correction file');
                if isequal(fileName,0)
                    % cancelled by user
                    wc = [];
                    wavelength_um = [];
                    return
                else
                    filePath = fullfile(filePath,fileName);
                end
            end
            
            wc = cast(imread(filePath),obj.computationDatatype);
            wc = mean(wc,3); % reduce RGB to grayscale
            
            if ~isequal(obj.hDevice.pixelResolutionXY,fliplr(size(wc)))
                xRes = obj.hDevice.pixelResolutionXY(1);
                yRes = obj.hDevice.pixelResolutionXY(2);
                wc(:,xRes+1:end) = [];
                wc(:,end+1:xRes) = NaN;
                wc(yRes+1:end,:) = [];
                wc(end+1:yRes,:) = NaN;
                
                most.idioms.warn('Wavefront Correction File was cropped/extended to match resolution of SLM');
            end
            
            wc = 2*pi * wc ./ (2^double(obj.hDevice.pixelBitDepth)); % convert to radians
            
            wc = unwrap(wc,[],1);
            wc = unwrap(wc,[],2);
            
            wc = wc - min(wc(:),[],'omitnan');
            
            if nargin < 3 || isempty(wavelength_um)
                answer = inputdlg('Wavelength (nm) for the wavefront correction:','Wavelength',1,{num2str(obj.wavelength_um*1e3)});
                answer = answer{1};
                
                if isempty(answer)
                    wavelength_um = [];
                else
                    wavelength_um = str2double(answer)*1e-3;
                    validateattributes(wavelength_um,{'numeric'},{'scalar','positive','nonnan','finite'});
                end
            end

            if nargout < 1
                obj.wavefrontCorrectionNominal = wc;
                obj.wavefrontCorrectionNominalWavelength_um = wavelength_um;
            end
        end
        
        function writePhaseMaskRad(obj,phaseMaskRads,waitForTrigger)
            if nargin < 3 || isempty(waitForTrigger)
                waitForTrigger = false;
            end
            
            maskPixelVals = obj.rad2PixelVal(phaseMaskRads);
            obj.writePhaseMaskRaw(maskPixelVals,waitForTrigger);
        end
        
        function writePhaseMaskRaw(obj,maskPixelVals,waitForTrigger)
            if nargin < 3 || isempty(waitForTrigger)
                waitForTrigger = false;
            end
            
            maskPixelVals = cast(maskPixelVals,obj.hDevice.pixelDataType);
            maskPixelVals = gather(maskPixelVals); % collect data from GPU
            
            if isscalar(maskPixelVals)
                maskPixelVals = repmat(maskPixelVals,obj.hDevice.pixelResolutionXY(2),obj.hDevice.pixelResolutionXY(1));
            end
            
            if obj.hDevice.computeTransposedPhaseMask
                assert(isequal(size(maskPixelVals),obj.hDevice.pixelResolutionXY));
            else
                assert(isequal(size(maskPixelVals),fliplr(obj.hDevice.pixelResolutionXY)));
            end
            
            assert(~obj.hDevice.queueStarted,'Cannot write to SLM while queue is started');
            
            obj.hDevice.writeBitmap(maskPixelVals,waitForTrigger);
            obj.lastWrittenPhaseMask = maskPixelVals;
            obj.hPtLastWritten = [];
        end

        function [phi,efficiency,correctedWeights] = computeMultiPointPhaseMask(obj,hPts,weights)            
            hPts = obj.wrapPointsCSObjective(hPts);
            
            hPtsDiffractionEfficiency = hPts.transform(obj.hCSDiffractionEfficiency);
            diffractionEfficiency = hPtsDiffractionEfficiency.points(:,1);
            
            if nargin < 3 || isempty(weights)
                weights = ones(hPts.numPoints,1);
            end
            
            correctedWeights = weights(:) ./ diffractionEfficiency;
            efficiency = sum(weights) / sum(correctedWeights);

            
            hPts = hPts.transform(obj.hCoordinateSystem);
            pts = hPts.points;
            
            if obj.gpuActivated                
                [phi,phaseMaskEfficiency] = scanimage.mroi.scanners.cghFunctions.GSW_GPU(obj,pts,correctedWeights);
            else
                [phi,phaseMaskEfficiency] = scanimage.mroi.scanners.cghFunctions.GSW(obj,pts,correctedWeights);
            end
            
            % efficiency = efficiency * phaseMaskEfficiency; % GJ: phaseMaskEfficiency is calculated incorrectly in GSW_GPU, GSW
        end
        
        function [phi,efficiency] = computeBitmapPhaseMask(obj,bitmap)
            assert(size(bitmap,2)==obj.hDevice.pixelResolutionXY(1) && size(bitmap,1)==obj.hDevice.pixelResolutionXY(2));            
            
            if obj.hDevice.computeTransposedPhaseMask
                bitmap = bitmap';
            end
            
            % Todo: calculate actual efficiency
            efficiency = 1;
            phi =  scanimage.mroi.scanners.cghFunctions.GS(obj,bitmap);
        end
        
        function parkScanner(obj)
            obj.pointScanner(obj.hParkPosition);
        end
        
        function zeroScanner(obj)
            hPt = obj.wrapPointsCSObjective([0 0 0]);
            obj.pointScanner(hPt);
        end
        
        function pointScanner(obj,hPts)
            hPts = obj.wrapPointsCSObjective(hPts);
            
            if isempty(hPts)
                obj.parkScanner();
                return
            else
                phaseMaskRad = obj.computeMultiPointPhaseMask(hPts);
            end
            obj.writePhaseMaskRad(phaseMaskRad);
            obj.hPtLastWritten = hPts;
        end
        
        function [pixelVals,intensities] = measureCheckerPatternResponse(obj,intensityMeasureFcn,checkerSize,numPoints,referenceVal)
            if nargin < 3 || isempty(checkerSize)
                checkerSize = 2;
            end
            
            if nargin < 4 || isempty(numPoints)
                numPoints = 256;
            end
            
            if nargin < 5 || isempty(referenceVal)
                referenceVal = 0;
            end
            
            pattern = scanimage.mroi.util.checkerPattern(obj.hDevice.pixelResolutionXY,checkerSize);
            pattern(pattern == 0) = NaN;
            
            if obj.hDevice.computeTransposedPhaseMask
                pattern = pattern';
            end
            
            minVal = double(intmin(obj.hDevice.pixelDataType));
            maxVal = double(intmax(obj.hDevice.pixelDataType));
            
            pixelVals = round(linspace(minVal,maxVal,numPoints));
            pixelVals = unique(pixelVals);
            
            intensities = zeros(size(pixelVals)); % intensity values
            
            hWb = waitbar(0,'Measuring SLM response');
            
            try
                for idx = 1:numel(pixelVals)
                    pattern_ = pattern * pixelVals(idx);
                    pattern_(isnan(pattern_)) = referenceVal;
                    
                    waitForTrigger = false;
                    obj.writePhaseMaskRaw(pattern_,waitForTrigger);
                    pause(0.06);
                    intensities(idx) = double(intensityMeasureFcn());
                    
                    assert(isvalid(hWb),'Calibration aborted by user');
                    hWb = waitbar(idx/numel(pixelVals),hWb);
                end
                delete(hWb);
            catch ME
                delete(hWb);
                rethrow(ME);
            end
        end
        
        function lut = calculateLut(obj,pixelVals,intensities)
            [pkVal,pkIdx] = obj.findPeak(intensities);            
            
            assert(~isempty(pkIdx),'Did not find peak in data');
            
            % scale Is
            intensities = abs(intensities - pkVal);
            intensities(1:pkIdx) = intensities(1:pkIdx)./intensities(1);
            intensities(pkIdx+1:end) = intensities(pkIdx+1:end)./intensities(end);
            
            intensities(intensities < 0) = 0;
            intensities(intensities > 1) = 1;
            
            phase = zeros(size(intensities));
            phase(1:pkIdx) = 2*acos(sqrt(intensities(1:pkIdx)));
            phase(pkIdx+1:end) = 2*(pi-acos(sqrt(intensities(pkIdx+1:end))));
            
            [phase,idx] = unique(phase);
            pixelVals = pixelVals(idx);
            
            assert(all(isreal(phase)),'Invalid intensities');
            lut = [phase(:),pixelVals(:)];
        end
    end
    
    %% Coordinate System Methods
    methods (Hidden)
        function hPts = wrapPointsCSObjective(obj,hPts)
            if ~isa(hPts,'scanimage.mroi.coordinates.Points')
                hPts = scanimage.mroi.coordinates.Points(obj.hCoordinateSystem,hPts);
            end
        end
        
        function xy = angleDegCSReferenceToObjectiveDistanceUm(obj,xy)
            % this is a bit of a weird conversion because of the way that
            % the reference space in ScanImage is defined:
            % the reference space is defined in angles (lateral) and um
            % (axial). This means we only need to convert XY deg to XY um
            % here and don't need to touch the Z coordinate
            xy(:,1:2) = obj.focalLength_um * obj.slmMagnificationOntoGalvos * tand(xy(:,1:2));
        end
        
        function xy = distanceObjectiveUmToAngleDegCSReference(obj,xy)
            % this is a bit of a weird conversion because of the way that
            % the reference space in ScanImage is defined:
            % the reference space is defined in angles (lateral) and um
            % (axial). This means we only need to convert XY um to XY angle
            % here and don't need to touch the Z coordinate
            xy(:,1:2) = atand( xy(:,1:2) / obj.focalLength_um / obj.slmMagnificationOntoGalvos );
        end
    end
    
    %% Utility methods
    methods (Hidden)        
        function lut = parseLutFromFile(obj,filePath)
            %%%
            % default function for parsing lut from file
            % can be overloaded by child classes
            hFile = fopen(filePath,'r');
            assert(hFile>0,'Error opening file %s.',filePath);
            
            formatSpec = '%f %f';
            sizeLut = [2 Inf];
            lut = fscanf(hFile,formatSpec,sizeLut)';
            fclose(hFile);
            
            if any(lut(:,1)<0 | lut(:,1)>2*pi)
                minVal = 0;
                maxVal = double(intmax(obj.hDevice.pixelDataType));
                lut(:,1) = (lut(:,1)-minVal)./(maxVal-minVal).*2*pi;
            end
        end
        
        function geometryBuffer_ = updateGeometryBuffer(obj)
            if ~most.idioms.isValidObj(obj.hDevice)
                return
            end
            
            if isempty(obj.hDevice.pixelResolutionXY) ...
                    || isempty(obj.wavelength_um) || isempty(obj.computationDatatype)
                % Can't compute geometry buffer, some parameters are missing
                geometryBuffer_ = [];
            else
                slmXSpan_um = (obj.hDevice.pixelResolutionXY(1)-1)*obj.hDevice.pixelPitchXY_um(1);
                slmYSpan_um = (obj.hDevice.pixelResolutionXY(2)-1)*obj.hDevice.pixelPitchXY_um(2);
                
                % center coordinate of pixels
                [xj,yj] = meshgrid(linspace(-slmXSpan_um/2,slmXSpan_um/2,obj.hDevice.pixelResolutionXY(1)),linspace(-slmYSpan_um/2,slmYSpan_um/2,obj.hDevice.pixelResolutionXY(2)));
                rSquared = xj.^2+yj.^2;
                
                if obj.hDevice.computeTransposedPhaseMask
                    % most devices use Row-major order for phase mask
                    xj = xj';
                    yj = yj';
                    rSquared = rSquared';
                end
                
                geometryBuffer_ = struct();
                geometryBuffer_.xj = cast(xj,obj.computationDatatype);
                geometryBuffer_.yj = cast(yj,obj.computationDatatype);
                geometryBuffer_.rSquared  = cast(rSquared,obj.computationDatatype);
                
                geometryBuffer_.beamProfileNormalized = abs(cast(obj.beamProfile / sum(sum(obj.beamProfile)),obj.computationDatatype));
                if obj.hDevice.computeTransposedPhaseMask
                    geometryBuffer_.beamProfileNormalized = geometryBuffer_.beamProfileNormalized';
                end
                
                obj.hCSPixel.toParentAffine = inv( micronToPixelTransform() );
                
                if ~isempty(obj.wavefrontCorrectionNominalWavelength_um)
                    wc = double(obj.wavefrontCorrectionNominal) * obj.wavefrontCorrectionNominalWavelength_um / obj.wavelength_um;
                else
                    wc = obj.wavefrontCorrectionNominal;
                end
                
                geometryBuffer_.wavefrontCorrection = cast(wc,obj.computationDatatype);
                if obj.hDevice.computeTransposedPhaseMask
                    geometryBuffer_.wavefrontCorrection = geometryBuffer_.wavefrontCorrection';
                end
                
                if obj.gpuActivated
                    geometryBuffer_.xj = gpuArray(geometryBuffer_.xj);
                    geometryBuffer_.yj = gpuArray(geometryBuffer_.yj);
                    geometryBuffer_.rSquared = gpuArray(geometryBuffer_.rSquared);
                    geometryBuffer_.beamProfileNormalized = gpuArray(geometryBuffer_.beamProfileNormalized);
                    geometryBuffer_.wavefrontCorrection = gpuArray(geometryBuffer_.wavefrontCorrection);
                end
            end
            obj.geometryBuffer = geometryBuffer_;
            
            function T = micronToPixelTransform()
                S = eye(4);
                S([1,6]) = obj.hDevice.pixelPitchXY_um  .* obj.hDevice.pixelResolutionXY / (obj.focalLength_um*obj.wavelength_um);
                
                O = eye(4);
                O([13,14]) = (obj.hDevice.pixelResolutionXY-1)/2 + 1;
                
                T = O*S;
            end
        end
        
        function [val,idx] = findPeak(obj,intensities)
            d = abs(bsxfun(@minus,[intensities(1),intensities(end)],intensities(:)));
            d = max(d,[],2);
            [~,idx] = max(d);
            val = intensities(idx);
            
            if idx==1 || idx==length(intensities)
                idx = [];
                val = [];
            end
        end
    end
    
   
    
    %% Property Getter/Setter
    methods
        function set.hDevice(obj,hSlm)
            assert(isa(hSlm,'dabs.resources.devices.SLM'));
            
            obj.hDevice = hSlm;
            
            minVal = double(intmin(obj.hDevice.pixelDataType));
            maxVal = double(intmax(obj.hDevice.pixelDataType));
            
            obj.linearLutBuffer = scanimage.mroi.scanners.slmLut.SlmLutGlobal([ [0;2*pi] , [minVal;maxVal] ]);
            
            obj.updateGeometryBuffer();
        end
        
        function set.hCoordinateSystem(obj,val)
            assert(isa(val,'scanimage.mroi.coordinates.CoordinateSystem'));
            assert(isscalar(val));
            assert(val.dimensions == 3);
            
            obj.hCoordinateSystem = val;
        end
        
        function set.hPtLastWritten(obj,val)
            if isempty(val)
                val = scanimage.mroi.coordinates.Points.empty(0,1);
            end
                
            obj.hPtLastWritten = val;
        end
        
        function set.hParkPosition(obj,val)
            val = obj.wrapPointsCSObjective(val);
            
            validateattributes(val,{'scanimage.mroi.coordinates.Points'},{'scalar'});
            assert(val.dimensions == 3);
            
            obj.hParkPosition = val;
        end
        
        function set.wavelength_um(obj,val)
            obj.wavelength_um = val;
            obj.updateGeometryBuffer();
        end
        
        function set.focalLength_um(obj,val)
            obj.focalLength_um = val;
        end
                
        function set.slmMediumRefractiveIdx(obj,val)
            validateattributes(val,{'numeric'},{'finite','nonnan','>=',1,'scalar'});
            obj.slmMediumRefractiveIdx = val;
        end
        
        function set.objectiveMediumRefractiveIdx(obj,val)
            validateattributes(val,{'numeric'},{'finite','nonnan','>=',1,'scalar'});
            obj.objectiveMediumRefractiveIdx = val;
        end
        
        function set.computationDatatype(obj,val)
            obj.computationDatatype = val;
            obj.updateGeometryBuffer();
        end
        
        function set.lut(obj,val)
            if ~isempty(val)
                if isnumeric(val)
                    val = scanimage.mroi.scanners.slmLut.SlmLutGlobal(val);
                end
                
                assert(isa(val,'scanimage.mroi.scanners.slmLut.SlmLut'),...
                    'Not a valid scanimage.mroi.scanners.slmLut.SlmLut');
                
                if isempty(val.wavelength_um)
                    val.wavelength_um = obj.wavelength_um;
                end
            end
            
            obj.lut = val;
        end
        
        function val = get.lut(obj)
            val = obj.lut;
            
            if isempty(val)
                val = obj.linearLutBuffer;
                val.wavelength_um = obj.wavelength_um;
            end
        end
        
        function set.wavefrontCorrectionNominal(obj,val)
            if ~isempty(val)
                assert(isequal(fliplr(size(val)),obj.hDevice.pixelResolutionXY),'Wavefront correction must be a %dx%d matrix',obj.hDevice.pixelResolutionXY(1),obj.hDevice.pixelResolutionXY(2));
            end
            
            obj.wavefrontCorrectionNominal = val;
            obj.updateGeometryBuffer();
        end
        
        function set.wavefrontCorrectionNominalWavelength_um(obj,val)
            if ~isempty(val)
                validateattributes(val,{'numeric'},{'scalar','positive','finite'});
            end
            
            obj.wavefrontCorrectionNominalWavelength_um = val;
            obj.updateGeometryBuffer();
        end
        
        function val = get.wavefrontCorrectionCurrentWavelength(obj)
            val = obj.geometryBuffer.wavefrontCorrection;
            
            if obj.hDevice.computeTransposedPhaseMask
                val = val';
            end
        end
        
        function val = get.computationDatatypeNumBytes(obj)
            sample = zeros(1,obj.computationDatatype);
            info = whos('sample');
            val = info.bytes;
        end
        
        function val = get.angularRangeXY(obj)
            val_um = obj.scanDistanceRangeXYObjective;
            val_um = val_um/2;
            val_deg = obj.distanceObjectiveUmToAngleDegCSReference(val_um);
            val = val_deg*2;
        end
        
        function val_um = get.scanDistanceRangeXYObjective(obj)
            max_deflection = obj.focalLength_um .* (obj.wavelength_um/2) ./ obj.hDevice.pixelPitchXY_um;
            val_um = max_deflection * 2;
        end
        
        function set.beamProfile(obj,val)
            val = cast(val,obj.computationDatatype);
            obj.beamProfile = val;
            obj.updateGeometryBuffer();
        end
        
        function val = get.beamProfile(obj)
            val = obj.beamProfile;
            if isempty(val)
                val = ones(obj.hDevice.pixelResolutionXY(2),obj.hDevice.pixelResolutionXY(1),obj.computationDatatype);
            end
        end
        
        function set.useGPUIfAvailable(obj,val)
            validateattributes(val,{'numeric','logical'},{'binary','scalar'});
            obj.useGPUIfAvailable = val;
            obj.updateGeometryBuffer();
        end

        function val = get.lastWrittenPoint(obj)
            hPt = obj.hPtLastWritten;

            if isempty(hPt)
                val = [];
            else
                hPt = hPt.transform(obj.hCoordinateSystem);
                val = hPt.points(1,:);
            end
        end

        function set.lastWrittenPoint(obj,val)
            error('Cannot set last written pont');
        end
        
        function val = get.gpuActivated(obj)
            val = obj.useGPUIfAvailable && most.util.gpuComputingAvailable();
        end
        
        function set.slmMagnificationOntoGalvos(obj,val)
            validateattributes(val,{'numeric'},{'scalar','finite','nonnan','real'});
            assert(val~=0);
            obj.slmMagnificationOntoGalvos = val;
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
