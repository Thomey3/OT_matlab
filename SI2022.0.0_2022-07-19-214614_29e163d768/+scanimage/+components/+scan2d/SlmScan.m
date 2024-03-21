classdef SlmScan < scanimage.components.Scan2D & most.HasMachineDataFile & dabs.resources.configuration.HasConfigPage & most.HasClassDataFile 
    % SlmScan - subclass of Scan2D for SLM scanning
    %   - controls a SLM for scanning XYZ points
    %   - handles data acquisition to collect data from PMT
    %   - format PMT data into images
    %   - handles acquistion timing and acquisition state
    %   - export timing signal
    
    methods (Static)
        function classes = getClassesToLoadFirst()
            classes = {'scanimage.components.scan2d.LinScan','scanimage.components.scan2d.RggScan'};
        end
    end
    
    properties (SetAccess=protected,Hidden)
        ConfigPageClass = 'dabs.resources.configuration.resourcePages.SlmScanPage';
    end
    
    methods (Static)
        function names = getDescriptiveNames()
            names = {'SlmScan'};
        end
    end
    
    
    %% USER PROPS
    properties (SetObservable)
        wavelength = 635e-9;            % [double] excitation wavelength in m
        galvoReferenceAngleXY = [0,0];  % [nx2 double] XY reference angle for galvo. this is the zero point for the SLM
        
        scanMode = 'slm';
    end
    
    properties (SetObservable, Transient)
        sampleRate = Inf;               % [Hz] sample rate of the digitizer; cannot be set
        channelOffsets;                 % Array of integer values; channelOffsets defines the dark count to be subtracted from each channel if channelsSubtractOffsets is true
        zeroOrderBlockRadius = 0;       % [double] radius of non-addressable area at center of FOV
    end
    
    properties (SetObservable, Hidden)
        recordScannerFeedback = false;  % not used in SlmScan, but required anyway
    end   
    
    properties (SetObservable, Transient, Dependent)        
        focalLength;                    % [double] focal length of SLM imaging lens
        slmMediumRefractiveIdx;         % [double] refractive index of medium SLM works in. (typically air, 1.000293)
        objectiveMediumRefractiveIdx;   % [double] refractive index of medium objective works in. (typically water, 1.333)
        
        parkPosition_um;                % [1x3 double] Park Position in um
        
        wavefrontCorrectionNominal;       % [mxn double] SLM wavefront correction for current wavelength
        wavefrontCorrectionNominalWavelength_um; % [numeric] wavelength in microns, at which nominal wavefront correction was measured
        wavefrontCorrectionNominalWavelength; % (legacy property for backward compatibility) [numeric] wavelength in meter, at which nominal wavefront correction was measured
        
        lut;
        
        slmMagnificationOntoGalvos;
    end
    
    properties (SetObservable, Hidden)
        calibratedWavelengths;          % [1xn] array of wavelengths for which luts are available
    end
    
    properties (Constant, Hidden)
        MAX_NUM_CHANNELS = 4;
        logFilePerChannel = false;
    end
    
    % Needs to be set observable for compatibility. See set function
    % comment
    properties (SetObservable, Hidden)
        uniformSampling = true;
    end 
    
    properties (Hidden, Access = private)
        cancelSaveClassData = false;
    end
    
    properties (Hidden, SetAccess = private)
        hZernikeGenerator;
        hClient;
        
        hCSCoordinateSystem;
        hCSSlmZAlignmentLut;
        hCSScannerToRef;
        hCSSlmDegToUm;
        hCSSlmAlignmentLut;
        hCSSlmZAlignmentLut3D;
        
        laserTriggerFilterSupport = false;
        laserTriggerDemuxSupport = false;
        
        classDataFileName;
        
        hAlignmentOverview;
        hZAlignmentControls;
        hLateralAlignmentControls;
    end
    
    properties (SetObservable,Hidden,SetAccess = private)
        alignmentPoints = cell(0,2);
        alignmentReference = [];
    end
    
    %% FRIEND PROPS
    properties (Hidden)
        hSlm;
        hAcq;
        hLog;
        hSlmDevice = dabs.resources.Resource.empty();
        hLinScan = dabs.resources.Resource.empty();
        hDAQ = dabs.resources.Resource.empty();
        hLutCalibrationAI = dabs.resources.Resource.empty();
    end
    
    properties (Hidden, SetAccess = protected)
        defaultRoiSize;
        angularRange;
        supportsRoiRotation = true;
        lutMap;
    end
    
    %% Private Props
    properties (Access = private)
        channelsDataType_;
    end
    
    %%% Abstract prop realizations (most.Model)
    properties (Hidden,SetObservable)
        channelsInvert = [];
        pixelBinFactor = 1;
        keepResonantScannerOn = false;
    end
    
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = zlclAppendDependsOnPropAttributes(scanimage.components.Scan2D.scan2DPropAttributes());
        mdlHeaderExcludeProps = {'hBeams' 'hFastZ' 'hShutters' 'lut' 'wavefrontCorrectionNominal'};
    end    
        
    %%% Abstract property realizations (most.HasMachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'SlmScan';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp; %#ok<MCCPI>
        mdfPropPrefix; %#ok<MCCPI>
        
        mdfDefault = defaultMdfSection();
    end
    
    %%% Abstract prop realization (scanimage.interfaces.Component)
    properties (SetAccess = protected, Hidden)
        numInstances = 0;
        linePhaseStep = 1;
    end        
    
    properties (Transient, Hidden, SetObservable)
        hBeams = {};
        hFastZs = {};
        hShutters = {};
        hDataScope;
    end
    
    %%% Abstract property realizations (scanimage.subystems.Scan2D)
    properties (Constant, Hidden)
        builtinFastZ = true;
    end
    
    properties (SetAccess = protected)
        scannerType = 'SLM';
        hasXGalvo = false;                   % logical, indicates if scanner has a resonant mirror
        hasResonantMirror = false;           % logical, indicates if scanner has a resonant mirror
        isPolygonalScanner = false;          % logical, indicates if resonant scanner is a polygonal scanner.
    end
    
    properties (Constant, Hidden)
        linePhaseUnits = 'pixels';
    end
    
    %%% Constants
    properties (Constant, Hidden)        
        COMPONENT_NAME = 'SlmScan';               % [char array] short name describing functionality of component e.g. 'Beams' or 'FastZ'
        PROP_TRUE_LIVE_UPDATE = {'linePhase','channelsAutoReadOffsets'}     % Cell array of strings specifying properties that can be set while the component is active
        PROP_FOCUS_TRUE_LIVE_UPDATE = {};         % Cell array of strings specifying properties that can be set while focusing
        DENY_PROP_LIVE_UPDATE = {'framesPerAcq','trigAcqTypeExternal',...  % Cell array of strings specifying properties for which a live update is denied (during acqState = Focus)
            'trigAcqTypeExternal','trigNextStopEnable','trigAcqInTerm',...
            'trigNextInTerm','trigStopInTerm','trigAcqEdge','trigNextEdge',...
            'trigStopEdge','stripeAcquiredCallback','logAverageFactor','logFilePath',...
            'logFileStem','logFramesPerFile','logFramesPerFileLock','logNumSlices'};
        
        FUNC_TRUE_LIVE_EXECUTION = {'updateLiveValues','readStripeData'}; % Cell array of strings specifying functions that can be executed while the component is active
        FUNC_FOCUS_TRUE_LIVE_EXECUTION = {};           % Cell array of strings specifying functions that can be executed while focusing
        DENY_FUNC_LIVE_EXECUTION = {'pointScanner','parkScanner','centerScanner'};  % Cell array of strings specifying functions for which a live execution is denied (during acqState = Focus)
    end    
    
    %% Lifecycle
    methods
        function obj = SlmScan(name)
            % SlmScan constructor for scanner object
            %  obj = SlmScan(name)
            obj = obj@scanimage.components.Scan2D(name);
            obj = obj@most.HasMachineDataFile(true);
            
            obj.hAcq = scanimage.components.scan2d.slmscan.Acquisition(obj);
            obj.hLog = scanimage.components.scan2d.linscan.Logging(obj);
            
            obj.hSlm = scanimage.mroi.scanners.SLM([obj.name ' SLM-Scanner']);
            obj.initCoordinateSystems();
            
            obj.numInstances = 1; % some properties won't set correctly if numInstances == 0 (e.g. scannerToRefTransform)
            obj.loadMdf();
        end
        
        function validateConfiguration(obj)            
            try
                most.ErrorHandler.assert(most.idioms.isValidObj(obj.hSlmDevice),'SLM is invalid',obj.name);
                most.ErrorHandler.assert(most.idioms.isValidObj(obj.hDAQ),'%s: Acquisition device is invalid',obj.name);
                obj.hSlmDevice.assertNoError();
                
                if most.idioms.isValidObj(obj.hLinScan)
                    assert(most.idioms.isValidObj(obj.hLinScan.xGalvo),'Linear scan system has no x-Galvo specified.');
                    assert(most.idioms.isValidObj(obj.hLinScan.yGalvo),'Linear scan system has no y-Galvo specified.');
                end
                
                beamErrors = cellfun(@(hB)~isempty(hB.errorMsg),obj.hBeams);
                assert(~any(beamErrors),'Beams %s are in error state', strjoin(cellfun(@(hB)hB.name,obj.hBeams(beamErrors),'UniformOutput',false)));

                shutterErrors = cellfun(@(hSh)~isempty(hSh.errorMsg),obj.hShutters);
                assert(~any(shutterErrors),'Shutters %s are in error state', strjoin(cellfun(@(hSh)hSh.name,obj.hShutters(shutterErrors),'UniformOutput',false)));
                
                obj.errorMsg = '';
            catch ME
                obj.errorMsg = ME.message;                
            end
        end
        
        function reinit(obj)
            try
                obj.validateConfiguration();
                obj.assertNoError();
                
                obj.hCSCoordinateSystem.hParent = obj.hSI.hCoordinateSystems.hCSReference;
                
                obj.hSlm.hDevice = obj.hSlmDevice;
                
                obj.simulated = obj.hDAQ.simulated;
                
                obj.hAcq.reinit();
                obj.hLog.reinit();
                
                obj.numInstances = 1; % This has to happen _before_ any properties are set
                
                %Initialize Scan2D props (not initialized by superclass)
                obj.channelsInputRanges = repmat({[-1,1]},1,obj.channelsAvailable);
                obj.channelOffsets = zeros(1, obj.channelsAvailable);
                obj.channelsSubtractOffsets = true(1, obj.channelsAvailable);
                obj.fillFractionSpatial = 1;
                
                obj.lutMap = containers.Map('KeyType','double','ValueType','any');
                
                % Determine CDF name and path
                if isempty(obj.hSI.classDataDir)
                    pth = most.util.className(class(obj),'classPrivatePath');
                else
                    pth = obj.hSI.classDataDir;
                end
                classNameShort = most.util.className(class(obj),'classNameShort');
                classNameShort = [classNameShort '_' obj.name];
                obj.classDataFileName = fullfile(pth, [classNameShort '_classData.mat']);
                
                %Initialize class data file (ensure props exist in file)
                obj.zprvEnsureClassDataFileProps();
                
                %Initialize the scan maps (from values in Class Data File)
                obj.loadClassData();
                
                obj.parkScanner();
                
                obj.hZernikeGenerator = scanimage.util.ZernikeGenerator(obj.hSlm,false);
                
                obj.loadCalibration();
            catch ME
                most.ErrorHandler.rethrow(ME);
            end
        end
        
        function delete(obj)
            obj.saveClassData();
            
            most.idioms.safeDeleteObj(obj.hZernikeGenerator);
            most.idioms.safeDeleteObj(obj.hAcq);
            most.idioms.safeDeleteObj(obj.hSlm);
            most.idioms.safeDeleteObj(obj.hLog);
            most.idioms.safeDeleteObj(obj.hClient);
            
            obj.saveCalibration();
        end
    end
    
    methods
        function loadMdf(obj)
            success = true;
            success = success & obj.safeSetPropFromMdf('hSlmDevice', 'slm');
            success = success & obj.safeSetPropFromMdf('hLinScan', 'linearScannerName');
            success = success & obj.safeSetPropFromMdf('hDAQ', 'deviceNameAcq');
            success = success & obj.safeSetPropFromMdf('channelsInvert', 'channelsInvert');
            success = success & obj.safeSetPropFromMdf('hShutters', 'shutters');
            success = success & obj.safeSetPropFromMdf('hBeams', 'beams');
            success = success & obj.safeSetPropFromMdf('focalLength', 'focalLength', @(v)v/1e3);
            success = success & obj.safeSetPropFromMdf('slmMediumRefractiveIdx', 'slmMediumRefractiveIdx');
            success = success & obj.safeSetPropFromMdf('objectiveMediumRefractiveIdx', 'objectiveMediumRefractiveIdx');
            success = success & obj.safeSetPropFromMdf('zeroOrderBlockRadius', 'zeroOrderBlockRadius', @(v)v/1e3);
            
            if isfield(obj.mdfData,'slmMagnificationOntoGalvos')
                success = success & obj.safeSetPropFromMdf('slmMagnificationOntoGalvos', 'slmMagnificationOntoGalvos');
            end
            
            success = success & obj.loadCalibration();
            
            if ~success
                obj.errorMsg = 'Error loading config';
            end
        end
        
        function saveMdf(obj)
            obj.safeWriteVarToHeading('slm', obj.hSlmDevice);
            obj.safeWriteVarToHeading('linearScannerName', obj.hLinScan);
            obj.safeWriteVarToHeading('deviceNameAcq', obj.hDAQ);
            obj.safeWriteVarToHeading('channelsInvert', obj.channelsInvert);
            obj.safeWriteVarToHeading('beams', resourceCellToNames(obj.hBeams));
            obj.safeWriteVarToHeading('shutters', resourceCellToNames(obj.hShutters));
            obj.safeWriteVarToHeading('focalLength', obj.focalLength*1e3);
            obj.safeWriteVarToHeading('slmMediumRefractiveIdx', obj.slmMediumRefractiveIdx);
            obj.safeWriteVarToHeading('objectiveMediumRefractiveIdx', obj.objectiveMediumRefractiveIdx);
            obj.safeWriteVarToHeading('zeroOrderBlockRadius', obj.zeroOrderBlockRadius*1e3);
            obj.safeWriteVarToHeading('slmMagnificationOntoGalvos',obj.slmMagnificationOntoGalvos);
            
            obj.saveCalibration();
            
            %%% Nested functions
            function names = resourceCellToNames(hResources)
               names = {};
               for idx = 1:numel(hResources)
                   if most.idioms.isValidObj(hResources{idx})
                       names{end+1} = hResources{idx}.name;
                   end
               end
            end
        end
    end
    
    methods
        function success = loadCalibration(obj)
            success = true;
            success = success & obj.safeSetPropFromMdf('scannerToRefTransform', 'scannerToRefTransform');
            success = success & obj.safeSetPropFromMdf('hLutCalibrationAI', 'lutCalibrationAI');
        end
        
        function saveCalibration(obj)
            obj.safeWriteVarToHeading('scannerToRefTransform', obj.scannerToRefTransform);
            obj.safeWriteVarToHeading('lutCalibrationAI', obj.hLutCalibrationAI);
        end
    end
    
    methods (Access=protected, Hidden)
        function mdlInitialize(obj)
            mdlInitialize@scanimage.components.Scan2D(obj);
            
            if most.idioms.isValidObj(obj.hLinScan)
                obj.hLinScan.hSlmScan = obj;
            end
        end
    end
    
    methods (Hidden)    
        function updateLiveValues(obj,regenAO,~)
            if nargin < 2 || isempty(regenAO)
                regenAO = true;
            end
            
            % waveforms parameter currently ignored. all waveforms updated
            
            if obj.active && obj.componentExecuteFunction('updateLiveValues')
                if regenAO
                    obj.hSI.hWaveformManager.updateWaveforms();
                end
                
                if strcmpi(obj.hSI.acqState,'focus')
                    obj.hAcq.bufferAcqParams();
                end
            end
        end
        
        function updateSliceAO(obj)
            error('UpdateSliceAO currently unsupported');
        end
    end
    
    %% PROP ACCESS METHODS
    methods        
        function set.hSlmDevice(obj,val)
            val = obj.hResourceStore.filterByName(val);
            
            if ~isequal(val,obj.hSlmDevice)
                if most.idioms.isValidObj(val)
                    validateattributes(val,{'dabs.resources.devices.SLM'},{'scalar'});
                end
                
                obj.deinit();
                
                obj.hSlmDevice.unregisterUser(obj);
                obj.hSlmDevice = val;
                obj.hSlmDevice.registerUser(obj,'SLM');
            end
        end
        
        function val = get.hSlmDevice(obj)
            val = obj.hSlmDevice;
            if ~isempty(val) && ~most.idioms.isValidObj(val)
                val = dabs.resources.InvalidResource.empty();
            end
        end
        
        function set.hDAQ(obj,val)
            val = obj.hResourceStore.filterByName(val);
            
            if ~isequal(val,obj.hDAQ)
                if most.idioms.isValidObj(val)
                    validateattributes(val,{'dabs.resources.daqs.vDAQ','dabs.resources.daqs.NIDAQ','dabs.resources.daqs.NIRIO'},{'scalar'});
                end
                
                obj.deinit();
                
                obj.hDAQ.unregisterUser(obj);
                obj.hDAQ = val;
                obj.hDAQ.registerUser(obj,'DAQ');
            end
        end
        
        function val = get.hDAQ(obj)
            val = obj.hDAQ;
            if ~isempty(val) && ~most.idioms.isValidObj(val)
                val = dabs.resources.InvalidResource.empty();
            end
        end
        
        function set.hLinScan(obj,val)
            val = obj.hResourceStore.filterByName(val);
            
            if ~isequal(val,obj.hLinScan)
                if most.idioms.isValidObj(val)
                    validateattributes(val,{'scanimage.components.scan2d.LinScan','scanimage.components.scan2d.RggScan'},{'scalar'});
                end
                
                obj.deinit();
                
                obj.hLinScan.unregisterUser(obj);
                obj.hLinScan = val;
                obj.hLinScan.registerUser(obj,'LinearScanner');
            end
        end
        
        function val = get.hLinScan(obj)
            val = obj.hLinScan;
            if ~isempty(val) && ~most.idioms.isValidObj(val)
                val = dabs.resources.InvalidResource.empty();
            end
        end
        
        function set.hDataScope(obj,val)
            % Not supported
            obj.hDataScope = [];
        end
        
        function set.hFastZs(obj,val)
            % Not supported
            obj.hFastZs = {};
        end
        
        function set.hShutters(obj,val)
            validateattributes(val,{'cell'},{});
            [val,validMask] = obj.hResourceStore.filterByName(val);
            val = val(validMask);
            
            for idx = 1:numel(val)
                validateattributes(val{idx},{'dabs.resources.devices.Shutter'},{'scalar'});
            end
            
            obj.hShutters = val;                
        end
        
        function val = get.hShutters(obj)
            validMask = cellfun(@(h)most.idioms.isValidObj(h),obj.hShutters);
            val = obj.hShutters(validMask);
        end
        
        function set.hBeams(obj,val)
            validateattributes(val,{'cell'},{});
            [val,validMask] = obj.hResourceStore.filterByName(val);
            val = val(validMask);
            
            for idx = 1:numel(val)
                validateattributes(val{idx},{'dabs.resources.devices.BeamModulator'},{'scalar'});
            end
            
            obj.hBeams = val;
        end
        
        function val = get.hBeams(obj)
            validMask = cellfun(@(h)most.idioms.isValidObj(h),obj.hBeams);
            val = obj.hBeams(validMask);
        end
        
        function set.hLutCalibrationAI(obj,val)
            val = obj.hResourceStore.filterByName(val);
            
            if ~isequal(val,obj.hLutCalibrationAI)
                if most.idioms.isValidObj(val)
                    validateattributes(val,{'dabs.resources.ios.AI'},{'scalar'});
                end
                
                obj.hLutCalibrationAI.unregisterUser(obj);
                obj.hLutCalibrationAI = val;
                obj.hLutCalibrationAI.registerUser(obj,'LUT Calibration');
            end
        end
        
        function val = get.hLutCalibrationAI(obj)
            val = obj.hLutCalibrationAI;
            if ~isempty(val) && ~most.idioms.isValidObj(val)
                val = dabs.resources.InvalidResource.empty();
            end
        end
        
        function set.channelsInvert(obj,val)
            if isempty(val)
                val = false;
            end
            validateattributes(val,{'numeric','logical'},{'binary','vector'});
            obj.channelsInvert = val;
        end
        
        function val = get.channelsInvert(obj)
            val = obj.channelsInvert;
            val(end+1:obj.channelsAvailable) = false;
            val(obj.channelsAvailable+1:end) = [];
        end
        
        function set.recordScannerFeedback(obj,val)
            % Unsupported in SlmScan
        end
        
        function set.focalLength(obj,val)
            val = obj.validatePropArg('focalLength',val);
            obj.hSlm.focalLength_um = val * 1e6;
        end
        
        function val = get.focalLength(obj)
            val = obj.hSlm.focalLength_um / 1e6; % conversion from um to m
        end
        
        function set.slmMediumRefractiveIdx(obj,val)
            val = obj.validatePropArg('slmMediumRefractiveIdx',val);
            obj.hSlm.slmMediumRefractiveIdx = val;
        end
        
        function val = get.slmMediumRefractiveIdx(obj)
            val = obj.hSlm.slmMediumRefractiveIdx;
        end
        
        function set.objectiveMediumRefractiveIdx(obj,val)
            val = obj.validatePropArg('objectiveMediumRefractiveIdx',val);
            obj.hSlm.objectiveMediumRefractiveIdx = val;
        end
        
        function val = get.objectiveMediumRefractiveIdx(obj)
            val = obj.hSlm.objectiveMediumRefractiveIdx;
        end
        
        function set.zeroOrderBlockRadius(obj,val)
            val = obj.validatePropArg('zeroOrderBlockRadius',val);
            
            obj.zeroOrderBlockRadius = val;
            obj.hSlm.zeroOrderBlockRadius = val;
        end
        
        function set.wavelength(obj,val)
            val = obj.validatePropArg('wavelength',val);
            
            val = round(val * 10e12)/10e12; % round to picometer
            
            obj.wavelength = val;
            obj.hSlm.wavelength_um = val * 1e6;
            lut_ = obj.retrieveLutFromCache(obj.wavelength);
            obj.lut = lut_;
        end
        
        function val = get.wavelength(obj)
            val = obj.hSlm.wavelength_um / 1e6;
        end
        
        function set.parkPosition_um(obj,val)
            val = obj.wrapPoints(val,obj.hCSSlmZAlignmentLut.hParent); % apply offset to park position
            obj.hSlm.hParkPosition = val;
        end
        
        function val = get.parkPosition_um(obj)
             val = obj.hSlm.hParkPosition;
             val = val.points;
        end
        
        function set.lut(obj,val)            
            obj.hSlm.lut = val;
            
            if ~isempty(val)                
                obj.lutMap(obj.wavelength) = obj.hSlm.lut;
                obj.saveClassData();
            elseif obj.lutMap.isKey(obj.wavelength)
                obj.lutMap.remove(obj.wavelength);
            end
        end
        
        function val = get.lut(obj)
            val = obj.hSlm.lut;
        end
        
        function val = get.slmMagnificationOntoGalvos(obj)
            val = obj.hSlm.slmMagnificationOntoGalvos;
        end        
        
        function set.slmMagnificationOntoGalvos(obj,val)
            obj.hSlm.slmMagnificationOntoGalvos = val;
        end
        
        function set.wavefrontCorrectionNominal(obj,val)
            val = obj.validatePropArg('wavefrontCorrectionNominal',val);
            obj.hSlm.wavefrontCorrectionNominal = val;
            
            obj.saveClassData();
        end
        
        function val = get.wavefrontCorrectionNominal(obj)
            val = obj.hSlm.wavefrontCorrectionNominal;
        end
        
        function set.wavefrontCorrectionNominalWavelength_um(obj,val)
            val = obj.validatePropArg('wavefrontCorrectionNominalWavelength_um',val);
            obj.hSlm.wavefrontCorrectionNominalWavelength_um = val;
            
            obj.saveClassData();
        end
        
        function val = get.wavefrontCorrectionNominalWavelength_um(obj)
            val = obj.hSlm.wavefrontCorrectionNominalWavelength_um;
        end
        
        function set.wavefrontCorrectionNominalWavelength(obj,val)
            obj.wavefrontCorrectionNominalWavelength_um = val * 1e6;
            obj.saveClassData();
        end
        
        function val = get.wavefrontCorrectionNominalWavelength(obj)
            val = obj.wavefrontCorrectionNominalWavelength_um * 1e-6;
        end
        
        function set.channelOffsets(obj,val)
            obj.channelOffsets = val;
        end        
        
        function set.sampleRate(obj,val)
            validateattributes(val,{'numeric'},{'scalar','positive','nonnan'});
            val = min(val,obj.hSlm.hDevice.maxRefreshRate);
            obj.sampleRate = val;
        end        

        % This property should be constant and set to True. However,
        % most.controller tries to re-apply property listeners to common
        % properties between scanner sets when changing scanner sets. In
        % other scanner sets unifromSampling can be True or False and
        % results in different consequences.In order to prevent errors 
        % when most.controller tries to re-apply listened to properties 
        % this is declared set observable but the set method ignores values
        % and always makes it true. 
        function set.uniformSampling(obj, val)
            obj.uniformSampling = true;
        end
        
        function sz = get.defaultRoiSize(obj)
            % the way this is calculated is not very principled at this
            % point. set to inf for the moment to ignore this setting
            %sz = min(obj.angularRange .* abs(obj.scannerToRefTransform([1 5])));
            sz = Inf;
        end
        
        function range = get.angularRange(obj)
            range = obj.scannerset.angularRange;
        end
        
        function val = get.calibratedWavelengths(obj)
            val = cell2mat(obj.lutMap.keys);
            val = unique(val);
        end
    end
      
    %%% Abstract method implementations (scanimage.components.Scan2D)
    % AccessXXX prop API for Scan2D
    methods (Access = protected, Hidden)        
        function val = fillFracTempToSpat(obj,val)
        end
        
        function val = fillFracSpatToTemp(obj,val)
        end
    
        function val = accessScannersetPostGet(obj,val)
            % Define beam hardware
            
            [fastBeams, slowBeams] = obj.hSI.hBeams.wrapBeams(obj.hBeams);
            for idx = 1:numel(fastBeams)
                fastBeams(idx).sampleRateHz = 100e3;
            end
            
            val = scanimage.mroi.scannerset.SLM(obj.name,obj.hSlm,fastBeams, slowBeams);
            val.galvoReferenceAngleXY = obj.galvoReferenceAngleXY;
            val.hCSSampleRelative = obj.hSI.hMotors.hCSSampleRelative;
            val.hCSReference = obj.hSI.hCoordinateSystems.hCSReference;
            val.beamRouters = obj.hSI.hBeams.hBeamRouters;
        end
        
        function accessBidirectionalPostSet(obj,~)
            obj.hSlm.bidirectionalScan = obj.bidirectional;
        end
        
        function val = accessStripingEnablePreSet(~,val)
            % unsupported in SlmScan
            val = false;
        end
        
        function val = accessLinePhasePreSet(obj,val)
        end
        
        function accessLinePhasePostSet(obj)
        end
        
        function val = accessLinePhasePostGet(obj,val)
        end
        
        function val = accessChannelsFilterPostGet(~,val)
        end
        
        function val = accessChannelsFilterPreSet(obj,val)
        end
        
        function accessBeamClockDelayPostSet(obj,~)
        end
        
        function accessBeamClockExtendPostSet(obj,~)
        end
        
        function accessChannelsAcquirePostSet(obj,~)
        end
        
        function val = accessChannelsInputRangesPreSet(obj,val)
            if obj.hAcq.isVdaq
                val = cellfun(@(v)v(2),val);
                val = obj.hAcq.hFpga.setChannelsInputRanges(val);
                val = arrayfun(@(v)[-v v],val,'UniformOutput',false);
            else
                val = obj.hAcq.hAI.setInputRanges(val);
            end
        end
        
        function val = accessChannelsInputRangesPostGet(obj,val)
            if ~obj.hAcq.isVdaq
                val = obj.hAcq.hAI.getInputRanges();
            end
        end
        
        function val = accessChannelsAvailablePostGet(obj,val)
            if obj.hAcq.isVdaq
                val = numel(obj.hDAQ.hDigitizerAIs);
            elseif most.idioms.isValidObj(obj.hAcq.hAI)
                val = obj.hAcq.hAI.getNumAvailChans;
            else
                val = obj.MAX_NUM_CHANNELS;
            end
        end
        
        function val = accessChannelsAvailableInputRangesPostGet(obj,val)
            if obj.hAcq.isVdaq
                val = arrayfun(@(f){[-f f]},[1.2 1 .5 .25]);
            else
                val = obj.hAcq.hAI.getAvailInputRanges();
            end
        end
                     
        function val = accessFillFractionSpatialPreSet(obj,val)
        end
                     
        function accessFillFractionSpatialPostSet(obj,~)
        end
        
        function val = accessSettleTimeFractionPostSet(obj,val)
        end
        
        function val = accessFlytoTimePerScanfieldPostGet(obj,val)
            val = 0;
        end
        
        function val = accessFlybackTimePerFramePostGet(obj,val)
            val = 0;
        end
        
        function accessLogAverageFactorPostSet(obj,~)
        end
        
        function accessLogFileCounterPostSet(obj,~)
        end
        
        function accessLogFilePathPostSet(obj,~)
        end
        
        function accessLogFileStemPostSet(obj,~)
        end
        
        function accessLogFramesPerFilePostSet(obj,~)
        end
        
        function accessLogFramesPerFileLockPostSet(obj,~)
        end
        
        function val = accessLogNumSlicesPreSet(obj,val)
        end
        
        function val = accessTrigFrameClkOutInternalTermPostGet(obj,val)
        end
        
        function val = accessTrigBeamClkOutInternalTermPostGet(obj,val)
        end
        
        function val = accessTrigAcqOutInternalTermPostGet(obj,val)
        end
        
        function val = accessTrigReferenceClkOutInternalTermPostGet(obj,val)
        end
        
        function val = accessTrigReferenceClkOutInternalRatePostGet(obj,val)
        end
        
        function val = accessTrigReferenceClkInInternalTermPostGet(obj,val)
        end
        
        function val = accessTrigReferenceClkInInternalRatePostGet(obj,val)
        end
        
        function val = accessTrigAcqInTermAllowedPostGet(obj,val)
            val = {''};
        end
        
        function val = accessTrigNextInTermAllowedPostGet(obj,val)
            val = {''};
        end
        
        function val = accessTrigStopInTermAllowedPostGet(obj,val)
            val = {''};
        end
             
        function val = accessTrigAcqEdgePreSet(obj,val)
        end
        
        function accessTrigAcqEdgePostSet(~,~)
        end
        
        function val = accessTrigAcqInTermPreSet(obj,val)
        end
        
        function accessTrigAcqInTermPostSet(~,~)
        end
        
        function val = accessTrigAcqInTermPostGet(obj,val)
        end
        
        function val = accessTrigAcqTypeExternalPreSet(obj,val)
            if val
                error('SlmScan does not support external triggering.');
            end
        end
        
        function accessTrigAcqTypeExternalPostSet(~,~)
        end
        
        function val = accessTrigNextEdgePreSet(obj,val)
        end
        
        function val = accessTrigNextInTermPreSet(obj,val)
        end
        
        function val = accessTrigNextStopEnablePreSet(obj,val)
        end
        
        function val = accessTrigStopEdgePreSet(obj,val)
        end
        
        function val = accessFunctionTrigStopInTermPreSet(obj,val)
        end
        
        function val = accessMaxSampleRatePostGet(obj,val)
        end
        
        function accessScannerFrequencyPostSet(obj,~)
        end
        
        function val = accessScannerFrequencyPostGet(~,val)
        end

        function val = accessScanPixelTimeMeanPostGet(obj,val)
        end
        
        function val = accessScanPixelTimeMaxMinRatioPostGet(obj,val)
        end
        
        function val = accessChannelsAdcResolutionPostGet(obj,~)
            % assume all channels on the DAQ board have the same resolution
            if obj.hAcq.isVdaq
                val = 16;
            else
                val = obj.hAcq.hAI.adcResolution;
            end                
        end
        
        function val = accessChannelsDataTypePostGet(obj,~)
            if isempty(obj.channelsDataType_)
                singleSample = obj.acquireSamples(1);
                val = class(singleSample);
                obj.channelsDataType_ = val;
            else
                val = obj.channelsDataType_;
            end
        end
        
        % Component overload function
        function val = componentGetActiveOverride(obj,val)
        end
        
        function val = accessScannerToRefTransformPreSet(obj,val)
            assert(~scanimage.mroi.util.isTransformPerspective(val),...
                'ScanImage does not support perspective transforms for SLMs');
            
            val_3D = scanimage.mroi.util.affine2Dto3D(val);
            
            obj.hCSScannerToRef.toParentAffine = val_3D;
        end
        
        function val = accessScannerToRefTransformPostGet(obj,val)
            val = obj.hCSScannerToRef.toParentAffine;
            val(:,3) = [];
            val(3,:) = [];
        end
        
        function accessChannelsSubtractOffsetsPostSet(obj)
        end
    end
    
    %% USER METHODS
    
    %%% Abstract methods realizations (scanimage.interfaces.Scan2D)
    methods        
        function showAlignmentOverview(obj)
            if ~most.idioms.isValidObj(obj.hAlignmentOverview)
                obj.hAlignmentOverview = scanimage.guis.SlmAlignmentOverview(obj);
            end
            
            obj.hAlignmentOverview.raise();
        end
        
        function showZAlignmentControls(obj)
            if ~most.idioms.isValidObj(obj.hZAlignmentControls)
                obj.hZAlignmentControls = scanimage.guis.SlmZAlignmentControls(obj);
            end
            
            obj.hZAlignmentControls.raise();
        end
        
        function showLaterAlignmentControls(obj)
            if ~most.idioms.isValidObj(obj.hLateralAlignmentControls)
                obj.hLateralAlignmentControls = scanimage.guis.SlmAlignmentWithMotionCorrection(obj);
            end
            
            obj.hLateralAlignmentControls.raise();
        end
        
        function showZernikeGenerator(obj)
            obj.hZernikeGenerator.showGUI();
        end
        
        % methods to issue software triggers
        % these methods should only be effective if specified trigger type
        % is 'software'
        function trigIssueSoftwareAcq(obj)
            obj.hAcq.trigIssueSoftwareAcq();
        end
        
        function trigIssueSoftwareNext(obj)
            errror('Next Trigger is unsupported in SLMScan');
        end
        
        function trigIssueSoftwareStop(obj)
            errror('Stop Trigger is unsupported in SLMScan');
        end
        
        % point SLM to position
        function pointScanner(obj,x,y,z)
            if nargin < 4 || isempty(z)
                z = 0;
            end
            
            if obj.componentExecuteFunction('pointScanner',x,y,z)
                obj.pointSlm([x,y,z]);
                obj.pointLinScan(obj.galvoReferenceAngleXY);
            end
        end
        
        % center SLM
        function centerScanner(obj)
            if obj.componentExecuteFunction('centerScanner')
                obj.pointScanner(0,0,0);
            end
        end
        
        % park SLM
        function parkScanner(obj)
            if obj.componentExecuteFunction('parkScanner')
                obj.hSlm.parkScanner();
                obj.parkLinScan();
            end
        end
        
        function pointSlm(obj,hPt)
            hPt = obj.wrapPoints(hPt);
            obj.hSlm.pointScanner(hPt);
        end
        
        function hPts = wrapPoints(obj,hPts,hCS)
            if nargin < 3 || isempty(hCS)
                hCS = obj.hCSCoordinateSystem;
            end
            
            if ~isa(hPts,'scanimage.mroi.coordinates.Points')
                hPts = scanimage.mroi.coordinates.Points(hCS,hPts);
            end
        end
        
        % load LUT for current wavelength from file
        % usage:
        %    obj.loadLutFromFile(fileName)
        %    obj.loadLutFromFile(fileName)
        function lut = loadLutFromFile(obj,fileName)
            if nargin < 2 || isempty(fileName)
                fileName = [];
            end
            
            lut = obj.hSlm.loadLutFromFile(fileName);
            
            if isempty(lut)
                return
            end
            
            lut.plot();
            
            button = questdlg('Do you want to use this look up table?');
            if strcmpi(button,'Yes')
                obj.lut = lut;
                obj.parkScanner();
            end
        end
        
        % save current SLM LUT to file
        % usage:
        %   obj.saveLutToFile()
        %   obj.saveLutToFile(fileName)
        function saveLutToFile(obj,fileName)
            if nargin < 2 || isempty(fileName)
                fileName = [];
            end
            
            obj.hSlm.saveLutToFile(fileName);
        end
        
        % plot SLM LUT
        % usage:
        %   obj.plotLut()                 plots lut for current wavelength
        function plotLut(obj)
            obj.hSlm.lut.plot();
        end
        
        % get SLM LUT from cache
        % usage:
        %   lut = obj.retrieveLutFromCache()              get LUT for current wavelength
        %   lut = obj.retrieveLutFromCache(wavelength)    get LUT for specified wavelength
        %
        %   if no lut for specified wavelength is in cache, return value is
        %   empty array
        function lut = retrieveLutFromCache(obj,wavelength)
            if nargin < 2 || isempty(wavelength)
                wavelength = obj.wavelength;
            end
            
            lut = [];
            
            if obj.lutMap.isKey(wavelength)
                lut = obj.lutMap(wavelength);
            end
        end
        
        
        % load Wavefront Correction for current wavelength from file
        % usage:
        %    obj.loadWavefrontCorrectionFromFile(fileName)
        %    obj.loadWavefrontCorrectionFromFile(fileName)
        function wc = loadWavefrontCorrectionFromFile(obj,fileName)
            if nargin < 2 || isempty(fileName)
                fileName = [];
            end
            
            [wc,wavelength_um] = obj.hSlm.loadWavefrontCorrectionFromFile(fileName);
            
            if isempty(wc)
                return
            end
            
            obj.wavefrontCorrectionNominal = wc;
            obj.hSlm.wavefrontCorrectionNominalWavelength_um = wavelength_um;
            obj.parkScanner();
            obj.plotWavefrontCorrection();
        end
        
        % plot SLM Wavefront Correction
        % usage:
        %   obj.plotLut()                 plots lut for current wavelength
        %   obj.plotLut(lut,wavelength)   where lut is a nx2 array
        function plotWavefrontCorrection(obj,wc_um,wl_um,wcNominal,wlNominal_um)
            if nargin < 4 || isempty(wcNominal)
                wc_um = obj.hSlm.wavelength_um;
            end
            
            if nargin < 5 || isempty(wlNominal_um)
                wl_um = obj.hSlm.wavelength_um;
            end
            
            if nargin < 4 || isempty(wcNominal)
                wcNominal = obj.hSlm.wavefrontCorrectionNominal;
            end
            
            if nargin < 5 || isempty(wlNominal_um)
                wlNominal_um = obj.hSlm.wavefrontCorrectionNominalWavelength_um;
            end
            
            if isempty(wcNominal) || isempty(wc_um)
                return
            end
            
            hFig = most.idioms.figure('NumberTitle','off','Name','Wavefront Correction');
            
            tabgp = uitabgroup(hFig);
            tabCurrentWl     = uitab(tabgp,'Title','Current Wavelength');
            tabCalibrationWl = uitab(tabgp,'Title','Calibration Wavelength');
            
            currentWavefrontCorrection = obj.hSlm.geometryBuffer.wavefrontCorrection;
            if obj.hSlm.hDevice.computeTransposedPhaseMask
                currentWavefrontCorrection = currentWavefrontCorrection';
            end
            
            currentWavefrontCorrection = currentWavefrontCorrection-min(min(currentWavefrontCorrection));
            currentWavefrontCorrection = mod(currentWavefrontCorrection,2*pi);
            
            hAxCurrentWl = most.idioms.axes('Parent',tabCurrentWl,'Box','on');
            imagesc('Parent',hAxCurrentWl,'CData',currentWavefrontCorrection);
            axis(hAxCurrentWl,'image');
            box(hAxCurrentWl,'on');
            view(hAxCurrentWl,0,-90);
            hCb1 = colorbar(hAxCurrentWl);
            
            wcNominal = wcNominal-min(min(wcNominal));
            wcNominal = mod(wcNominal,2*pi);
            
            hAxCalibrationWl = most.idioms.axes('Parent',tabCalibrationWl,'Box','on');
            imagesc('Parent',hAxCalibrationWl,'CData',wcNominal);
            axis(hAxCalibrationWl,'image');
            box(hAxCalibrationWl,'on');
            view(hAxCalibrationWl,0,-90);
            hCb2 = colorbar(hAxCalibrationWl);
            
            range = [0 2*pi];
            
            hAxCurrentWl.CLim = range;
            hAxCalibrationWl.CLim = range;
            
            ticks = linspace(range(1),range(2),round(diff(range)/(2*pi))*2+1);
            tickLabels = sprintf('%.1f\\pi\n',ticks/pi);
            set([hCb1,hCb2],'Ticks',ticks,'TickLabels',tickLabels);
            
            title(hAxCurrentWl,sprintf('SLM Wavefront Correction (Radians) at %.1fnm',wl_um*1e3));
            xlabel(hAxCurrentWl,'x');
            ylabel(hAxCurrentWl,'y');
            
            title(hAxCalibrationWl,sprintf('SLM Wavefront Correction (Radians) at %.1fnm',wlNominal_um*1e3));
            xlabel(hAxCalibrationWl,'x');
            ylabel(hAxCalibrationWl,'y');
        end
        
        function showPhaseMaskDisplay(obj)
            obj.hSlm.showPhaseMaskDisplay();
        end
        
        function writePhaseMask(obj,phaseMask_)
            slmRes = obj.hSlm.hDevice.pixelResolutionXY;
            
            assert(isequal(size(phaseMask_),fliplr(slmRes)),...
                'phaseMask must be of size [%d,%d]',slmRes(2),slmRes(1));
            
            if obj.hSlm.hDevice.computeTransposedPhaseMask
                phaseMask_ = phaseMask_';
            end
            
            obj.hSlm.writePhaseMaskRad(phaseMask_);
        end
        
        %%% Alignment routines
        function setAlignmentReference(obj)
            assert(~isempty(obj.hLinScan),'Cannot use this alignment method without a linear scanner defined');
            assert(strcmpi(obj.hSI.acqState,'focus'),'SLM alignment is only available during active Focus');
            assert(obj.hSI.hScan2D == obj.hLinScan,'Wrong scanner selected. Select linear scanner (galvo-galvo) for imaging, that is in path with SLM');
            assert(~obj.hSI.hScan2D.stripingEnable,'Cannot enable alignment when striping acquisition is enabled.');
            
            obj.resetAlignmentPoints();
            
            hSlmPosition = obj.hSlm.hPtLastWritten;
            
            obj.hSI.hMotionManager.activateMotionCorrectionSimple();
            obj.alignmentReference = hSlmPosition;
        end
        
        function addAlignmentPoint(obj,slmPosition, motion)
            assert(~isempty(obj.hLinScan),'Cannot use this alignment method without a linear scanner defined');
            assert(~isempty(obj.alignmentReference),'Set alignment reference first.');
            
            if nargin < 2 || isempty(slmPosition)
                slmPosition = obj.hSlm.lastWrittenPoint;
            end
            
            if nargin < 3 || isempty(motion)
                assert(strcmpi(obj.hSI.acqState,'focus'),'SLM alignment is only available during active Focus');
                assert(obj.hSI.hScan2D == obj.hLinScan,'Wrong scanner selected. Select linear scanner (galvo-galvo) for imaging, that is in path with SLM');
                
                if ~obj.hSI.hMotionManager.enable
                    assert(~isempty(obj.hSI.hChannels.channelDisplay),'Cannot activate motion correction if no channels are displayed.');
                    obj.hSI.hMotionManager.activateMotionCorrectionSimple();
                end
                
                assert(~isempty(obj.hSI.hMotionManager.motionHistory(end)),'Cannot add alignment point because the motion history is empty.');
                motion = obj.hSI.hMotionManager.motionHistory(end).drRef;
                assert(~any(isnan(motion(1:2))),'Cannot add alignment point because the motion vector is invalid');
            end
            
            obj.alignmentPoints(end+1,:) = {slmPosition, motion(1:2)};
            
            pts = vertcat(obj.alignmentPoints{:,1});
            d = max(pts(:,3:end),[],1)-min(pts(:,3:end),[],1);
            
            if any(d > 1)
                warning('SLM alignment points are taken at different z depths.');
            end
        end
        
        function createAlignmentMatrix(obj)
            assert(~isempty(obj.hLinScan),'Cannot calculate alignment matrix without a linear scanner defined');
            assert(~isempty(obj.alignmentReference),'No alignment reference has been set');
            assert(size(obj.alignmentPoints,1)>=2,'At least two points are needed to perform the alignment');
            
            slmPoints = vertcat(obj.alignmentPoints{:,1});
            if size(slmPoints,2) >= 3
                assert(all(abs(slmPoints(:,3)-slmPoints(1,3)) < 1),'All points for alignment need to be taken on the same z plane and at the same rotation');
            end
            
            SlmPoints = scanimage.mroi.coordinates.Points(obj.hSlm.hCoordinateSystem,slmPoints);
            SlmPoints = SlmPoints.transform(obj.hCSScannerToRef);
            slmPoints = SlmPoints.points(:,1:2);
            
            motionPoints = obj.alignmentPoints(:,2);
            motionPoints = -vertcat(motionPoints{:});
            
            % we are only solving for rotation and scaling, with the
            % constraints that translation and perspective is zero
            T = motionPoints' * pinv(slmPoints');
            
            % expand to affine matrix
            T(:,3) = [0;0];
            T(3,:) = [0 0 1];
            
            obj.abortAlignment();
            
            obj.scannerToRefTransform = T;
            
            obj.saveCalibration();
        end
        
        function resetAlignmentPoints(obj)
            obj.alignmentPoints = cell(0,2);
        end
        
        function abortAlignment(obj)
            obj.alignmentReference = [];
            obj.resetAlignmentPoints();
            
            if obj.hSI.hMotionManager.enable
                obj.hSI.hMotionManager.enable = false;
            end
            
            obj.hSI.abort();
        end
    end
    
    %% INTERNAL METHODS
    methods (Hidden)
        function initCoordinateSystems(obj)
            obj.hCSCoordinateSystem   = scanimage.mroi.coordinates.CSLinear  ([obj.name ' Coordinate System'],     3, []); % Parent is set in reinit
            obj.hCSSlmZAlignmentLut   = scanimage.mroi.coordinates.CSZAffineLut ([obj.name ' SLM Lut Z Alignment'],   3, obj.hCSCoordinateSystem);
            obj.hCSScannerToRef       = scanimage.mroi.coordinates.CSLinear ([obj.name ' SLM Scanner To Ref Alignment'], 3, obj.hCSSlmZAlignmentLut);
            obj.hCSSlmDegToUm         = scanimage.mroi.coordinates.CSFunction([obj.name ' SLM Deg to microns'],    3, obj.hCSScannerToRef);
            obj.hCSSlmAlignmentLut    = scanimage.mroi.coordinates.CSLut     ([obj.name ' SLM Lut Alignment'],     3, obj.hCSSlmDegToUm);
            obj.hCSSlmZAlignmentLut3D = scanimage.mroi.coordinates.CSLut     ([obj.name ' SLM Lut Z Alignment 3D'],3, obj.hCSSlmAlignmentLut); % 3DShot style sub stage camera alignment
            obj.hSlm.hCoordinateSystem.hParent = obj.hCSSlmZAlignmentLut3D;
            
            hSlm_ = obj.hSlm;
            obj.hCSSlmDegToUm.toParentFunction   = @hSlm_.distanceObjectiveUmToAngleDegCSReference;
            obj.hCSSlmDegToUm.fromParentFunction = @hSlm_.angleDegCSReferenceToObjectiveDistanceUm;
            obj.hCSSlmDegToUm.lock = true; % disable loading/saving
            
            obj.hCSCoordinateSystem.lock = true; % disable loading/saving
            obj.hCSScannerToRef.lock = true;
        end
        
        function reinitRoutes(obj)
            % no-op
        end
        
        function deinitRoutes(obj)
            obj.abort();
        end
        
        function frameAcquiredFcn(obj,src,evnt) %#ok<INUSD>
            if obj.active
                obj.stripeAcquiredCallback(obj,[]);
            end
        end
    end
    
    %%% Abstract methods realizations (scanimage.interfaces.Scan2D)    
    methods (Hidden)
        function calibrateLinePhase(obj,varargin)
            msgbox('Auto adjusting the line phase is unsupported in SlmScan','Unsupported','error');
            error('Calibrating the line phase is unsupported in SlmScan');
        end
        
        function arm(obj,activateStaticScanners)
            obj.pointLinScan(obj.galvoReferenceAngleXY);
        end
        
        function data = acquireSamples(obj,numSamples)
            data = obj.hAcq.acquireSamples(numSamples);
        end
        
        function data = acquireLutCalibrationSample(obj,nSamples)
            if nargin < 1 || isempty(nSamples)
                nSamples = 1; 
            end
            
            most.ErrorHandler.assert(most.idioms.isValidObj(obj.hLutCalibrationAI),'No valid calibration input channel is selected');
            data = obj.hLutCalibrationAI.readValue(nSamples);
        end
        
        function signalReadyReceiveData(obj)
        end
                
        function [success,stripeData] = readStripeData(obj)
            % remove the componentExecute protection for performance
            %if obj.componentExecuteFunction('readStripeData')
                [success,stripeData] = obj.hAcq.readStripeData();
                if stripeData.endOfAcquisitionMode
                    obj.abort(); %self abort if acquisition is done
                end
            %end
        end
        
        function pointLinScan(obj,positionXY)
            if ~isempty(obj.hLinScan)
                obj.hLinScan.pointScannerRef(positionXY);
            end
        end
        
        function parkLinScan(obj)
            if ~isempty(obj.hLinScan) && ~obj.hSI.active
                obj.hLinScan.parkScanner();
            end
        end
    end
    
    %% Abstract methods realizations (scanimage.interfaces.Component)
    methods (Access = protected, Hidden)
        function componentStart(obj,varargin)
            assert(~obj.robotMode);
            %assert(~obj.hSI.hChannels.loggingEnable,'Currently Logging is not supported in SlmScan');
            
            % pointing the linearscanner needs to be done in obj.arm
            % otherwise we run into a resource conflict with the beams
            % task if the beams and galvos are on the same board
            
            ss = obj.scannerset;
            for idx = 1:numel(ss.beams)
                ss.beams(idx).hDevice.setPowerFraction(ss.beams(idx).powerFraction);
            end
            
            obj.hLog.start();
            obj.hAcq.start();
        end
        
        function componentAbort(obj,varargin)
            for idx = 1:numel(obj.hBeams)
                try
                    obj.hBeams{idx}.setPowerFraction(0);
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
            end
            
            obj.hAcq.abort();
            obj.hLog.abort();
            obj.parkScanner();
        end
    end
    
    %% Private methods
    methods %(Access = private)
        function zprvEnsureClassDataFileProps(obj)
            obj.ensureClassDataFile(struct('lutMap',struct('keys',{{}},'values',{{}})),obj.classDataFileName);
            obj.ensureClassDataFile(struct('wavefrontCorrectionNominal',[]),obj.classDataFileName);
            obj.ensureClassDataFile(struct('wavefrontCorrectionNominalWavelength',[]),obj.classDataFileName);
            obj.ensureClassDataFile(struct('wavelength',double(635e-9)),obj.classDataFileName);
        end
        
        function loadClassData(obj)
            try
                obj.cancelSaveClassData = true;
                
                lutMapStruct = obj.getClassDataVar('lutMap',obj.classDataFileName);
                if ~isempty(lutMapStruct.keys)
                    lutMap_ = containers.Map('KeyType','double','ValueType','any');
                    for idx = 1:length(lutMapStruct.keys)
                        wavelength_ = lutMapStruct.keys{idx};
                        v = lutMapStruct.values{idx};
                        if isstruct(v)
                            v = scanimage.mroi.scanners.slmLut.SlmLut.load(v);
                            v.wavelength_um = wavelength_*1e6;
                        elseif isnumeric(v)
                            % support backwards compatiblity
                            v = scanimage.mroi.scanners.slmLut.SlmLutGlobal(v);
                            v.wavelength_um = wavelength_*1e6;
                        end
                        lutMap_(wavelength_) = v;
                    end
                    obj.lutMap = lutMap_;
                end
                
                obj.wavefrontCorrectionNominal = obj.getClassDataVar('wavefrontCorrectionNominal',obj.classDataFileName);
                obj.wavefrontCorrectionNominalWavelength = obj.getClassDataVar('wavefrontCorrectionNominalWavelength',obj.classDataFileName);
                obj.wavelength = obj.getClassDataVar('wavelength',obj.classDataFileName);
                
                obj.cancelSaveClassData = false;
            catch ME
                obj.cancelSaveClassData = false;
                rethrow(ME);
            end
        end
        
        function saveClassData(obj)
            if isempty(obj.classDataFileName)
                return
            end
            
            if isempty(obj.lutMap) || obj.cancelSaveClassData
                return
            end
            
            lutMapStruct = struct('keys',{obj.lutMap.keys},'values',{obj.lutMap.values});
            for idx = 1:numel(lutMapStruct.keys)
                lut_ = lutMapStruct.values{idx};
                if isa(lut_,'scanimage.mroi.scanners.slmLut.SlmLutGlobal')
                    % support backwards compatiblity
                    s = lut_.lut;
                else
                    s = lut_.save();
                end
                
                lutMapStruct.values{idx} = s;
            end
            
            obj.setClassDataVar('lutMap',lutMapStruct,obj.classDataFileName);
            obj.setClassDataVar('wavefrontCorrectionNominal',obj.wavefrontCorrectionNominal,obj.classDataFileName);
            obj.setClassDataVar('wavefrontCorrectionNominalWavelength',obj.wavefrontCorrectionNominalWavelength,obj.classDataFileName);
            obj.setClassDataVar('wavelength',obj.wavelength,obj.classDataFileName);
        end
    end
end

function s = zlclAppendDependsOnPropAttributes(s)
    s.wavelength            = struct('Classes','numeric','Attributes',{{'positive','finite','scalar','<',2e-6}});
    s.focalLength           = struct('Classes','numeric','Attributes',{{'positive','finite','scalar','nonnan'}});
    s.slmMediumRefractiveIdx = struct('Classes','numeric','Attributes',{{'positive','finite','scalar','nonnan','>=',1}});
    s.objectiveMediumRefractiveIdx = struct('Classes','numeric','Attributes',{{'positive','finite','scalar','nonnan','>=',1}});
    s.zeroOrderBlockRadius  = struct('Classes','numeric','Attributes',{{'nonnegative','finite','scalar'}});
    s.lut                   = struct('Classes','numeric','Attributes',{{'ncols',2}},'AllowEmpty',1);
    s.wavefrontCorrectionNominal = struct('Classes','numeric','Attributes',{{'2d'}},'AllowEmpty',1);
    s.wavefrontCorrectionNominalWavelength_um = struct('Classes','numeric','Attributes',{{'positive','finite','scalar'}},'AllowEmpty',1);
end

function s = defaultMdfSection()
    s = [...
        most.HasMachineDataFile.makeEntry('slm','','name of the slm in use')...
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('linearScannerName','','Name of galvo-galvo-scanner (from first MDF section) to use in series with the SLM. Must be a linear scanner')...
        most.HasMachineDataFile.makeEntry('deviceNameAcq','','String identifying NI DAQ board for PMT channels input')...
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('channelsInvert',false,'Scalar or vector identifiying channels to invert. if scalar, the value is applied to all channels')...
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('shutters',{{}},'shutter device names')...
        most.HasMachineDataFile.makeEntry('beams',{{}},'Numeric: ID of the beam DAQ to use with the linear scan system')...
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('focalLength',100,'[mm] Focal length of the image forming lens of the SLM.')...
        most.HasMachineDataFile.makeEntry('slmMediumRefractiveIdx',1.000293,'Refractive index of medium SLM works in. (typically air, 1.000293).')...
        most.HasMachineDataFile.makeEntry('objectiveMediumRefractiveIdx',1.333,'Refractive index of medium objective works in. (typically water, 1.333).')...        
        most.HasMachineDataFile.makeEntry('zeroOrderBlockRadius',0.1,'[mm] Radius of area at center of SLM FOV that cannot be excited, usually due to presence of zero-order beam block')...
        most.HasMachineDataFile.makeEntry('slmMagnificationOntoGalvos',1,'Magnification of SLM onto galvos. E.g. if SLM is demagnified onto galvo by a factor of 4, the value should be 0.25')...
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry()... % blank line
        most.HasMachineDataFile.makeEntry('Calibration data')...
        most.HasMachineDataFile.makeEntry('scannerToRefTransform',eye(3),'')...
        most.HasMachineDataFile.makeEntry('lutCalibrationAI','','Name of AI channel for measuring zero order spot for LUT calibration')...
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
