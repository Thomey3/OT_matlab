classdef Beams < scanimage.interfaces.Component
    %% Beams Component
    % Manages properties and functionality related to beam power modulation.

    %% USER PROPS
    properties (SetObservable)
        powers;                     % [Numeric] legacy property: 1xN array of nominal power percentage for each beam
        powerFractions;             % [Numeric] 1xN array of nominal power fractions for each beam
        lengthConstants;            % [Numeric] 1xN array of power depth length constants for each beam
        pzAdjust = scanimage.types.BeamAdjustTypes([]);
                                    % [scanimage.types.BeamAdjustTypes] 1xN array indicating type of power depth adjustment for each beam
        
        interlaceDecimation;        % [Numeric] 1xN array indicating for each beam that beam should only be on every n'th line
        interlaceOffset;            % [Numeric] 1xN array indicating for each beam the offset line to start interlace
        
        flybackBlanking = true;     % [Logical] Indicates whether to blank beam outside of fill fraction and during galvo flyback
        
        enablePowerBox = false;     % [Logical] Enables the power box feature
        powerBoxes = scanimage.components.beams.PowerBox.empty(); % Array of PowerBox objects.
                                    % Contains the following properties:
                                    %  - rect:      [Numeric] 1x4 array indicating the left, top, width, and height of the power box expressed as fraction of the scanfield
                                    %  - powers:    [Numeric] 1xN array indicating the power for each laser within the box
                                    %  - name:      [string] a name for the power box for display purposes
                                    %  - oddLines:  [Logical] indicates if the box should be on for even scan lines
                                    %  - evenLines: [Logical] indicates if the box should be on for odd scan lines
                                    %  - mask:      [Numeric] contains
                                    %  2D Matrix of power fractions that should be applied at each index of the Matrix as though it were stretched to fit the powerbox
        powerBoxStartFrame = 1;     % [Numeric] Specifies what frame the power box should turn on at
        powerBoxEndFrame = inf;     % [Numeric] Specifies what frame the power box should turn off at
    end
    
    properties (SetObservable)
        pzFunction = {};    % Variable Cell Array with num elements = num beams. Elements are power/Z functions
        pzLUTSource = {};   % Variable Cell Array with num elements = num beams. Elements are LUT filepaths corresponding to pzLUT elements if applicable.
    end
    
    properties (Transient, SetAccess = private)
        pzLUT = {};         % Variable Cell Array with num elements = num beams. Elements are power/Z LUTs
    end
    
    properties (Hidden,SetObservable,SetAccess=private)
        displayNames;       % cell array containing display names for all beams
        maxSampleRate = [];
    end
    
    properties (Transient, SetAccess = private, SetObservable)
        hBeams = {};
        hBeamRouters = {};
        hResourceStoreListener = event.listener.empty();
    end
    
    properties (Dependent, Transient)
        powerFractionLimits
    end

    properties(Dependent,Transient,SetAccess = private)
        totalNumBeams;
    end
    
    properties (Hidden,Dependent)
        currentBeams
        scanners
        currentScanners
    end
    
    properties (Hidden,Constant)
        DEFAULT_POWER_FUNCTION = @scanimage.util.defaultPowerFunction;
    end
    
    %% INTERNAL PROPS
    properties (Hidden,SetAccess=?most.Model,Dependent)
        hasPowerBoxes;
    end
    
    properties (Hidden,SetAccess=private)
        flybackBlankData;                   %Array of beam output data for each scanner period for flyback blanking mode. Array has one column for each beam.
        flybackBlankDataMask;               %Mask representation of flybackBlankData, with 1 values representing beam ON and NaN representing beam OFF.
        powersNominal;                      %Last-set values of beamPowers, which may be at higher precision than calibration-constrained beamPowers value
        internalSetFlag = false;            %Flag signifying that a public property set is happening internally, rather than by external class user
        sliceUpdateFlag = false;
        
        sharingScannerDaq = false;  % indicates the active acquisition is using the galvo DAQ for beam output. Possible for linear scanning
        
        hTask;
    end
    
    properties (Hidden,SetAccess=private)
        beamBufferUpdatingAsyncRetries = 0;
        beamBufferUpdatingAsyncNow = false;
        beamBufferNeedsUpdateAsync = false;
        beamBufferNeedsUpdateRegenerate = false;
    end
    
    properties (Hidden)
        streamingBuffer;
        aoSlices;
        nominalStreamingBufferTime = 1;
        streamingBufferFrames;
        streamingBufferSamples;
        frameSamps;
        samplesWritten;
        samplesGenerated;
        framesGenerated;
        framesWritten;
        nSampCbN;
    end
    
    %%% ABSTRACT PROPERTY REALIZATION (most.Model)
    properties (Hidden,SetAccess=protected)
        mdlPropAttributes = ziniInitPropAttributes();
        mdlHeaderExcludeProps = {'pzLUT','hBeams','hBeamRouters'};
    end
    
    %%% ABSTRACT PROPERTY REALIZATION (scanimage.interfaces.Component)
    properties (SetAccess = protected, Hidden)
        numInstances = 0;
    end
    
    properties (Constant, Hidden)
        COMPONENT_NAME = 'Beams';                       %[char array] short name describing functionality of component e.g. 'Beams' or 'FastZ'
        PROP_TRUE_LIVE_UPDATE = ...                     %Cell array of strings specifying properties that can be set while the component is active
            {'powers' 'powerFractions' 'flybackBlanking' 'interlaceDecimation' 'interlaceOffset' 'enablePowerBox' 'powerBoxes' 'powerBoxStartFrame' 'powerBoxEndFrame'};
        PROP_FOCUS_TRUE_LIVE_UPDATE = {};               % Cell array of strings specifying properties that can be set while focusing
        DENY_PROP_LIVE_UPDATE = {};                     %Cell array of strings specifying properties for which a live update is denied (during acqState = Focus)
        FUNC_TRUE_LIVE_EXECUTION = {};         % Cell array of strings specifying functions that can be executed while the component is active
        FUNC_FOCUS_TRUE_LIVE_EXECUTION = {};            % Cell array of strings specifying functions that can be executed while focusing
        DENY_FUNC_LIVE_EXECUTION = {};                  % Cell array of strings specifying functions for which a live execution is denied (during acqState = Focus)
    end
    
    properties (Hidden)
       tfExtForceStreaming = 0;
       extPowerScaleFnc = [];
    end
    
    %% LIFECYCLE
    methods (Access = ?scanimage.SI)
        function obj = Beams()
            obj@scanimage.interfaces.Component('SI Beams');
            obj.numInstances = numel(obj.hBeams);
        end
    end
        
    methods
        function delete(obj)
            obj.deinit();
        end
    end
    
    methods (Hidden)        
        function deinit(obj)
            most.idioms.safeDeleteObj(obj.hResourceStoreListener);
            most.idioms.safeDeleteObj(obj.hTask)
        end
        
        function reinit(obj)
            obj.hResourceStoreListener = most.ErrorHandler.addCatchingListener(obj.hResourceStore,'hResources','PostSet',@(varargin)obj.searchForBeams);
            obj.searchForBeams();
            obj.deactivateAllBeams();
            obj.powerBoxes = scanimage.components.beams.PowerBox(obj);
        end
        
        function searchForBeams(obj)
            hBeams_       = obj.hResourceStore.filterByClass('dabs.resources.devices.BeamModulator');
            hBeamRouters_ = obj.hResourceStore.filterByClass('dabs.generic.BeamRouter');
            
            if ~isequal(obj.hBeams,hBeams_) || ~isequal(obj.hBeamRouters,hBeamRouters_) 
                obj.hBeams = hBeams_;
                obj.hBeamRouters = hBeamRouters_;
                obj.numInstances  = numel(obj.hBeams);
                obj.displayNames = NaN;
            end
        end
    end
    
    %% PROP ACCESS
    %%% Getter/Setter
    methods
        function set.displayNames(~,~)
            % No-op, for UI update only
        end
        
        function val = get.displayNames(obj)
            val = cellfun(@(hB)hB.name,obj.hBeams,'UniformOutput',false);
        end
        
        function v = get.currentBeams(obj) 
            v = obj.hSI.hScan2D.hBeams;
        end

        function v = get.totalNumBeams(obj)
            v = numel(obj.hBeams);
        end
        
        function val = get.currentScanners(obj)
            [fastBeams, slowBeams] = obj.wrapBeams(obj.currentBeams); 
            val = struct();
            val.fastBeams = fastBeams;
            val.slowBeams = slowBeams;
        end
        
        function val = get.scanners(obj)
            [~, ~, val] = obj.wrapBeams(obj.currentBeams); 
        end
        
        function v = get.powerFractions(obj)
            v = obj.expandVal(obj.powerFractions,0);
        end
        
        function set.powerFractions(obj,v)          
            validateattributes(v,{'numeric'},{'>=',0,'<=',1,'nonnan','finite','real'});
            
            v = obj.expandVal(v,0);
            v = min(v,obj.powerFractionLimits);
            
            obj.powerFractions = v;
            obj.powers = NaN; % dummy set legacy property
            
            % side effect
            if obj.hSI.active && ~obj.sliceUpdateFlag
                fastBeams = obj.currentScanners.fastBeams;
                if ~isempty(fastBeams)
                    obj.updateBeamBufferAsync(true);
                end
                
                slowBeams = obj.currentScanners.slowBeams;
                for idx = 1:length(slowBeams)
                    slowBeam = slowBeams(idx);
                    beamMask = cellfun(@(hBeam)hBeam==slowBeam.hDevice,obj.hBeams);
                    thisV = v(beamMask);
                    slowBeamDevice = slowBeams(idx).hDevice;
                    slowBeamDevice.setPowerFractionAsync(thisV);
                end
            end
        end
        
        function v = get.powers(obj)
            v = obj.powerFractions * 100;
        end
        
        function set.powers(obj,val)
            if isnan(val)
                return
            end
            
            obj.powerFractions = val/100;
        end
        
        function v = get.pzAdjust(obj)
            v = obj.expandVal(obj.pzAdjust,scanimage.types.BeamAdjustTypes.None);
        end
        
        function set.pzAdjust(obj,v)
            if isempty(v)
                v = scanimage.types.BeamAdjustTypes.empty();
            elseif ischar(v)
                v = most.idioms.string2Enum(v,'scanimage.types.BeamAdjustTypes');
            elseif iscell(v)
                v = cellfun(@(c)most.idioms.string2Enum(c,'scanimage.types.BeamAdjustTypes'),v);
            end
            
            if ~isempty(v)
                validateattributes(v,{'scanimage.types.BeamAdjustTypes'},{'vector'});
            end
            
            obj.pzAdjust = obj.expandVal(v,scanimage.types.BeamAdjustTypes.None);
        end
        
        function v = get.lengthConstants(obj)
            v = obj.expandVal(obj.lengthConstants,Inf);
        end
        
        function set.lengthConstants(obj,v)
            validateattributes(v,{'numeric'},{});
            obj.lengthConstants = obj.expandVal(v,Inf);
        end
        
        function v = get.pzFunction(obj)
            v = obj.expandVal(obj.pzFunction,{obj.DEFAULT_POWER_FUNCTION});
        end
        
        function set.pzFunction(obj,v)
            if isempty(v)
                v = {};
            end
            
            validateattributes(v,{'cell'},{});
            
            for i = 1:numel(v)
                if isempty(v{i})
                    v{i} = obj.DEFAULT_POWER_FUNCTION;
                elseif ischar(v{i})
                    v{i} = str2func(v{i});
                end
                
                scanimage.util.validateFunctionHandle(v{i});
            end
            
            obj.pzFunction = obj.expandVal(v,{obj.DEFAULT_POWER_FUNCTION});
        end
        
        function val = get.pzLUT(obj)
            val = obj.expandVal(obj.pzLUT,{zeros(0,2)});
        end
        
        function v = get.pzLUTSource(obj)
            v = obj.expandVal(obj.pzLUTSource,{''});
        end
        
        function set.pzLUTSource(obj,v)
            validateattributes(v,{'cell'},{});
            cellfun(@(c)assert(ischar(c)||isnumeric(c),'Each LUT source must be a string which represents the path to the .mat file containing the lookup table for the z depth power adjustment'),v);
            val = obj.expandVal(v,{''});
            
            for idx = 1:numel(val)
                src = val{idx};
                if ischar(src) && ~isempty(src)
                    assert(exist(src,'file')>0,'File not found on disk: %s',src);
                end
            end
            
            obj.pzLUTSource = val;
            
            obj.load_pzLut();
        end
        
        function v = get.interlaceDecimation(obj)
            v = obj.expandVal(obj.interlaceDecimation,1);
        end
        
        function set.interlaceDecimation(obj,v)
            validateattributes(v,{'numeric'},{'integer','positive'});
            obj.interlaceDecimation = obj.expandVal(v,1);
        end
        
        function v = get.interlaceOffset(obj)            
            v = obj.expandVal(obj.interlaceOffset,0);
        end
        
        function set.interlaceOffset(obj,v)
            validateattributes(v,{'numeric'},{'integer','nonnegative'});
            obj.interlaceOffset = obj.expandVal(v,0);
        end
        
        function [fastBeams, slowBeams, allBeams] = wrapBeams(obj,hBeams)
            allBeams = {};
            fastBeams = scanimage.mroi.scanners.FastBeam.empty();
            slowBeams = scanimage.mroi.scanners.SlowBeam.empty();
            
            for idx = 1:numel(hBeams)
                hBeam = hBeams{idx};
                siBeamIdx = find(cellfun(@(hR)isequal(hR,hBeam),obj.hBeams),1);

                [powerFraction,lengthConstant,zPowerReference] = getPowerAndLengthConstant(siBeamIdx);
                
                if isa(hBeam, 'dabs.resources.devices.BeamModulatorFast')
                    scanner = scanimage.mroi.scanners.FastBeam(hBeam);
                elseif isa(hBeam, 'dabs.resources.devices.BeamModulatorSlow')
                    scanner = scanimage.mroi.scanners.SlowBeam(hBeam);
                else
                    error('Unknown beam class: %s',class(hBeam));
                end
                
                scanner.beamIdx             = idx;
                scanner.siBeamIdx           = siBeamIdx;
                scanner.powerFraction       = powerFraction;
                scanner.pzAdjust            = obj.pzAdjust(siBeamIdx);
                scanner.Lz                  = lengthConstant;
                scanner.pzFunction          = obj.pzFunction{siBeamIdx};
                scanner.pzLUT               = obj.pzLUT{siBeamIdx};
                scanner.pzReferenceZ        = zPowerReference;
                
                if isa(hBeam, 'dabs.resources.devices.BeamModulatorFast')
                    scanner.interlaceDecimation = obj.interlaceDecimation(siBeamIdx);
                    scanner.interlaceOffset     = obj.interlaceOffset(siBeamIdx);                
                    scanner.powerBoxes          = getPowerBoxes(siBeamIdx);
                    scanner.sampleRateHz        = NaN; % filled out by Scan2D
                    scanner.flybackBlanking     = obj.flybackBlanking;
                    
					fastBeams(end+1) = scanner;
                    
                elseif isa(hBeam, 'dabs.resources.devices.BeamModulatorSlow')
                    slowBeams(end+1) = scanner;
                else
                    error('Unknown beam class: %s',class(hBeam));
                end
                
                allBeams{end+1} = scanner;
            end
            
            %%% Nested function
            function [powerFraction,lengthConstant,zPowerReference] = getPowerAndLengthConstant(beamIdx)
                if obj.hSI.hStackManager.overrideLZs
                    startPowerFraction = obj.hSI.hStackManager.stackStartPowerFraction(beamIdx);
                    endPowerFraction   = obj.hSI.hStackManager.stackEndPowerFraction(beamIdx);
                    
                    % If 0 , pratio will be inf due to division by 0 which
                    % then causes lengthConstant to be 0 due to division
                    % by inf
                    startPowerFraction = max(startPowerFraction,0.001);
                    endPowerFraction   = max(endPowerFraction,  0.001);
                    
                    startPos = obj.hSI.hStackManager.stackZStartPos;
                    endPos   = obj.hSI.hStackManager.stackZEndPos;
                    
                    % For calculating correct lengthConstant
                    dz = endPos - startPos;
                    
                    Pratio = endPowerFraction/startPowerFraction;
                    lengthConstant = dz/log(Pratio);
                    
                    powerFraction = startPowerFraction;
                    zPowerReference = startPos;
                else
                    powerFraction = obj.powerFractions(beamIdx);
                    lengthConstant = obj.lengthConstants(beamIdx);
                    
                    zPowerReference = obj.hSI.hStackManager.zPowerReference;
                    zPowerReference(end+1:beamIdx) = zPowerReference(1); % expand
                    zPowerReference = zPowerReference(beamIdx);
                end
            end
            
            function pbxs = getPowerBoxes(siBeamIdx)
                if isempty(obj.powerBoxes)
                    pbxs = [];
                    return;
                end
                
                if obj.enablePowerBox
                    numPbxs = length(obj.powerBoxes);
                    for pbxIdx = 1:numPbxs
                        if isstruct(obj.powerBoxes(pbxIdx))
                            pbxs(pbxIdx) = obj.powerBoxes(pbxIdx);
                        else
                            pbxs(pbxIdx) = obj.powerBoxes(pbxIdx).struct();
                        end
                        pbxs(pbxIdx).powers = obj.powerBoxes(pbxIdx).powers(siBeamIdx);
                    end
                else
                    pbxs = [];
                end
            end
        end
        
        function val = get.powerFractionLimits(obj)
            hBeams_ = obj.hBeams;
            
            val = ones(1,numel(hBeams_));
            for idx = 1:numel(hBeams_)
                try
                    val(idx) = hBeams_{idx}.powerFractionLimit;
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
            end
        end
        
        function set.powerFractionLimits(obj,val)
            hBeams_ = obj.hBeams;
            for idx = 1:numel(hBeams_)
                try
                    hBeams_{idx}.powerFractionLimit = val(idx);
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
            end
        end
        
        function set.flybackBlanking(obj,val)
            val = obj.validatePropArg('flybackBlanking',val);
            if obj.componentUpdateProperty('flybackBlanking',val)
                obj.flybackBlanking = val;
                if obj.hSI.active
                    obj.updateBeamBufferAsync(true);
                end
            end
        end
        
        function set.enablePowerBox(obj,val)
            val = obj.validatePropArg('enablePowerBox',val);
            if obj.componentUpdateProperty('enablePowerBox',val)
                obj.enablePowerBox = logical(val);
                
                if obj.hSI.active
                    if obj.enablePowerBox && ~obj.streamingBuffer && ((obj.powerBoxStartFrame > 1) || (~isinf(obj.powerBoxEndFrame)))
                        most.idioms.warn('Cannot change to a time varying power box mid-acquisition. Power box will be always on');
                    end
                    obj.updateBeamBufferAsync(true);
                end
            end
        end
        
        function set.powerBoxes(obj,val)
            if isstruct(val) %for backwards compatibility
                [val, valid] = validateStructPowerBox(val);
                if ~valid
                    return;
                end
            else
                assert(all(isa(val, 'scanimage.components.beams.PowerBox')),'powerBoxes must be of class scanimage.components.beams.PowerBox');
            end
            
            if obj.componentUpdateProperty('powerBoxes',val)
                obj.powerBoxes = val;
                if obj.hSI.active
                    obj.updateBeamBufferAsync(true);
                end
            end
            
            %Nested Function
            function [val, valid] = validateStructPowerBox(val)
                valid = false;
                assert(all(isfield(val, {'rect' 'powers'})), 'Invalid powerbox format.');
                if ~isfield(val, 'oddLines')
                    val = arrayfun(@(s)setfield(s,'oddLines',true),val);
                end
                if ~isfield(val, 'evenLines')
                    val = arrayfun(@(s)setfield(s,'evenLines',true),val);
                end
                if ~isfield(val, 'mask')
                    val = arrayfun(@(s)setfield(s,'mask',[]),val);
                end
                if ~isfield(val, 'zs')
                    val = arrayfun(@(s)setfield(s,'zs',[]),val);
                end
                
                for i = 1:numel(val)
                    val(i).powers = obj.zprpBeamScalarExpandPropValue(val(i).powers,'powerBoxes.powers');
                    if length(val(i).rect) ~= 4
                        most.idioms.dispError('WARNING: Powerbox rect has to be defined by 4 points');
                        return
                    end
                    
                    if any(val(i).rect(3:4)<0)
                        most.idioms.dispError('WARNING: Powerbox rect width and height needs to be positive');
                        return
                    end
                    
                    r = min(1,max(0,[val(i).rect([1 2]) val(i).rect([3 4])+val(i).rect([1 2])]));
                    val(i).rect = [r([1 2]) r([3 4])-r([1 2])];
                    
                    if ~isempty(val(i).mask)
                        mask = val(i).mask;
                        if ~isnumeric(mask) || numel(size(mask))>2 || any(mask(:)<0) || any(mask(:)>1)
                            most.idioms.dispError('WARNING: Powerbox mask must be numeric 2D array with all values >=0 and <=1');
                            return;
                        end
                    end
                end
                
                powers_ = vertcat(val.powers);
                if any(powers_(:)<0) || any(powers_(:)>100)
                    most.idioms.dispError('WARNING: Powerbox power values have to lie between 0 and 100%%');
                    return;
                end
                valid = true;
            end
        end
        
        function val = get.powerBoxes(obj)
            val = obj.powerBoxes;
            
            fastBeamMask = cellfun(@(hB)isa(hB,'dabs.resources.devices.BeamModulatorFast'),obj.hBeams);
            for idx = 1:numel(val)
                powers_ = val(idx).powers;
                powers_(end+1:obj.totalNumBeams) = NaN;
                powers_ = powers_(1:obj.totalNumBeams);
                powers_(~fastBeamMask) = NaN; % only fast beams can use power boxes
                val(idx).powers = powers_;
            end
        end
        
        function set.powerBoxStartFrame(obj,val)
            val = obj.validatePropArg('powerBoxStartFrame',val);
            if obj.componentUpdateProperty('powerBoxStartFrame',val)
                obj.powerBoxStartFrame = val;
                if obj.hSI.active
                    if obj.enablePowerBox && ~obj.streamingBuffer && ((obj.powerBoxStartFrame > 1) || (~isinf(obj.powerBoxEndFrame)))
                        most.idioms.warn('Cannot change to a time varying power box mid-acquisition. Power box will be always on');
                    end
                    obj.updateBeamBufferAsync(true);
                end
            end
        end
        
        function set.powerBoxEndFrame(obj,val)
            val = obj.validatePropArg('powerBoxEndFrame',val);
            if obj.componentUpdateProperty('powerBoxEndFrame',val)
                obj.powerBoxEndFrame = val;
                if obj.hSI.active
                    if obj.enablePowerBox && ~obj.streamingBuffer && ((obj.powerBoxStartFrame > 1) || (~isinf(obj.powerBoxEndFrame)))
                        most.idioms.warn('Cannot change to a time varying power box mid-acquisition. Power box will be always on');
                    end
                    obj.updateBeamBufferAsync(true);
                end
            end
        end
        
        function v = get.hasPowerBoxes(obj)
            v = obj.enablePowerBox && numel(obj.powerBoxes);
        end
    end
    
    %% FRIEND METHODS
    methods (Hidden)        
        function updateSliceAO(obj)
            if ~obj.active || ~most.idioms.isValidObj(obj.hTask)
                return
            end
            
            if ~isempty(obj.currentScanners.fastBeams) && ~obj.sharingScannerDaq
                obj.sliceUpdateFlag = true;
                
                try
                    obj.hTask.abort();
                    
                    if any(obj.pzAdjust)
                        % dont need to regenerate the AO here, this is done in Scan2D
                        zPowerReference = obj.hSI.hStackManager.zPowerReference;
                        slc = obj.hSI.hStackManager.slicesDone + 1;
                        z = obj.hSI.hStackManager.zs(slc);
                        %obj.zprvBeamsDepthPowerCorrection(obj.activeBeamDaqID,obj.powers(obj.activeBeamDaqID),zPowerReference,z,obj.acqLengthConstants); 
                    end
                    
                    % update the ao
                    obj.samplesGenerated = 0;
                    obj.samplesWritten = 0;
                    obj.framesGenerated = 0;
                    obj.framesWritten = 0;
                    obj.updateBeamBufferAsync(false, 3);
                    if ~obj.hSI.hScan2D.simulated
                        obj.hTask.start();
                    end
                    obj.sliceUpdateFlag = false;
                catch ME
                    obj.sliceUpdateFlag = false;
                    ME.rethrow();
                end
            end
        end
        
        function updateBeamBufferAsync(obj, reGenerateAO, timeout)
            if nargin < 3 || isempty(timeout)
                timeout = nan;
            end
            
            if obj.sharingScannerDaq
                %hScan2D.updateLiveValues always updates AO so disregards
                %the reGenerateAO parameter
                obj.hSI.hScan2D.updateLiveValues(true, 'B');
            else
                if obj.beamBufferUpdatingAsyncNow
                    % async call currently in progress. schedule update after current update finishes
                    obj.beamBufferNeedsUpdateAsync = true;
                    obj.beamBufferNeedsUpdateRegenerate = obj.beamBufferNeedsUpdateRegenerate || reGenerateAO;
                else
                    if reGenerateAO
                        obj.hSI.hWaveformManager.updateWaveforms();
                    end

                    obj.beamBufferNeedsUpdateAsync = false;
                    obj.beamBufferNeedsUpdateRegenerate = false;
                    
                    % For motorized beam devices there is no B field in
                    % scanner AO
                    if ~isfield(obj.hSI.hWaveformManager.scannerAO.ao_volts, 'B') || ~isfield(obj.hSI.hWaveformManager.scannerAO.pathFOV, 'B')
                        return;
                    end
                    
                    if ~isempty(obj.currentBeams)
                        beamCfg = obj.hSI.hScan2D.scannerset.beamsTriggerCfg();
                        if strcmpi(beamCfg.triggerType,'static')
                            framesToWrite = 1;
                            aoVolts = obj.hSI.hWaveformManager.scannerAO.ao_volts.B;
                            pathFOV = obj.hSI.hWaveformManager.scannerAO.pathFOV.B;
                            
                            % all sample points have to be the same
                            assert(size(unique(aoVolts,'rows'),1)==1);
                            assert(size(unique(pathFOV,'rows'),1)==1);
                            
                            aoVolts = aoVolts(1,:);
                            pathFOV = pathFOV(1,:);
                            
                            bufsz = obj.streamingBufferSamples; % make sure we write data for the entire buffer
                            aoVolts = repmat(aoVolts,bufsz,1); % can't write a single point to the output buffer
                        elseif obj.streamingBuffer
                            framesToWrite = obj.streamingBufferFrames + obj.framesGenerated - obj.framesWritten;
                            startFrame = obj.framesWritten + 1;
                            
                            obj.hTask.writeRelativeTo = 'DAQmx_Val_CurrWritePos';
                            obj.hTask.writeOffset = 0;
                            if framesToWrite > 0
                                [aoVolts,pathFOV] = obj.calcStreamingBuffer(startFrame, framesToWrite);
                            end
                        else
                            framesToWrite = 1;
                            obj.hTask.writeRelativeTo = 'DAQmx_Val_FirstSample';
                            obj.hTask.writeOffset = 0;
                            
                            if obj.hasPowerBoxes
                                aoVolts = obj.hSI.hWaveformManager.scannerAO.ao_volts.Bpb;
                                pathFOV = obj.hSI.hWaveformManager.scannerAO.pathFOV.Bpb;
                            else
                                aoVolts = obj.hSI.hWaveformManager.scannerAO.ao_volts.B;
                                pathFOV = obj.hSI.hWaveformManager.scannerAO.pathFOV.B;
                            end
                        end
                        
                        if framesToWrite > 0
                            if ~obj.hSI.hScan2D.simulated
                                obj.beamBufferUpdatingAsyncNow = true;
                                obj.hTask.writeAnalogDataAsync(double(aoVolts),[],[],[],@(src,evt)obj.updateBeamBufferAsyncCallback(src,evt));
                            end
                        end
                    end
                end
                
                if ~isnan(timeout)
                    t = tic;
                    while obj.beamBufferUpdatingAsyncNow
                        pause(.01);
                        assert(toc(t) < timeout, 'Beam buffer write timed out.');
                    end
                end
            end
        end
        
        function updateBeamBufferAsyncCallback(obj,~,evt)
            obj.beamBufferUpdatingAsyncNow = false; % this needs to be the first call in the function in case there are errors below
            
            if obj.streamingBuffer
                obj.samplesWritten = obj.samplesWritten + evt.sampsWritten;
                obj.framesWritten = obj.samplesWritten / obj.frameSamps;
            end
            
            if evt.status ~= 0 && evt.status ~= 200015 && obj.active
                fprintf(2,'Error updating beams buffer: %s\n%s\n',evt.errorString,evt.extendedErrorInfo);
                
                if ~obj.streamingBuffer && (obj.beamBufferUpdatingAsyncRetries < 3 || obj.beamBufferNeedsUpdateAsync)
                    obj.beamBufferUpdatingAsyncRetries = obj.beamBufferUpdatingAsyncRetries + 1;
                    fprintf(2,'Scanimage will retry update...\n');
                    obj.updateBeamBufferAsync(obj.beamBufferNeedsUpdateRegenerate);
                else
                    obj.beamBufferUpdatingAsyncRetries = 0;
                end
            else
                obj.beamBufferUpdatingAsyncRetries = 0;

                if obj.beamBufferNeedsUpdateAsync
                    obj.updateBeamBufferAsync(obj.beamBufferNeedsUpdateRegenerate);
                end
            end
        end
        
        function [aoVolts,pathFOV] = calcStreamingBuffer(obj, bufStartFrm, nFrames)
            bufEndFrm = (bufStartFrm+nFrames-1);
            if obj.aoSlices > 1
                % the generated AO is for multiple slices. for each frame we
                % need to extract the correct slice from the correct buffer
                frms = bufStartFrm:(bufStartFrm+nFrames-1);
                for ifr = numel(frms):-1:1
                    ss = 1 + (ifr-1)*obj.frameSamps;
                    es = ifr*obj.frameSamps;
                    
                    slcInd = mod(frms(ifr)-1,obj.aoSlices)+1;
                    aoSs = 1 + (slcInd-1)*obj.frameSamps;
                    aoEs = slcInd*obj.frameSamps;
                    
                    if (frms(ifr) >= obj.powerBoxStartFrame) && (frms(ifr) <= obj.powerBoxEndFrame) && obj.hasPowerBoxes
                        aoVolts(ss:es,:) = obj.hSI.hWaveformManager.scannerAO.ao_volts.Bpb(aoSs:aoEs,:);
                        pathFOV(ss:es,:) = obj.hSI.hWaveformManager.scannerAO.pathFOV.Bpb(aoSs:aoEs,:);
                    else
                        aoVolts(ss:es,:) = obj.hSI.hWaveformManager.scannerAO.ao_volts.B(aoSs:aoEs,:);
                        pathFOV(ss:es,:) = obj.hSI.hWaveformManager.scannerAO.pathFOV.B(aoSs:aoEs,:);
                    end
                end
            else
                if (bufStartFrm >= obj.powerBoxStartFrame) && (bufEndFrm <= obj.powerBoxEndFrame) && obj.hasPowerBoxes
                    % power box is on the whole time
                    aoVolts = repmat(obj.hSI.hWaveformManager.scannerAO.ao_volts.Bpb, nFrames, 1);
                    pathFOV = repmat(obj.hSI.hWaveformManager.scannerAO.pathFOV.Bpb,  nFrames, 1);
                else
                    aoVolts = repmat(obj.hSI.hWaveformManager.scannerAO.ao_volts.B, nFrames, 1);
                    pathFOV = repmat(obj.hSI.hWaveformManager.scannerAO.pathFOV.B, nFrames, 1);
                    if (bufStartFrm <= obj.powerBoxEndFrame) && (bufEndFrm >= obj.powerBoxStartFrame) && obj.hasPowerBoxes
                        % power box is on at lease some of the time
                        onStartFr = max(bufStartFrm, obj.powerBoxStartFrame);
                        onEndFr = min(bufEndFrm, obj.powerBoxEndFrame);
                        ss = (onStartFr-bufStartFrm)*length(obj.hSI.hWaveformManager.scannerAO.ao_volts.B) + 1;
                        se = (onEndFr-bufStartFrm+1)*length(obj.hSI.hWaveformManager.scannerAO.ao_volts.B);
                        aoVolts(ss:se,:) = repmat(obj.hSI.hWaveformManager.scannerAO.ao_volts.Bpb, onEndFr-onStartFr+1, 1);
                        pathFOV(ss:se,:) = repmat(obj.hSI.hWaveformManager.scannerAO.pathFOV.Bpb, onEndFr-onStartFr+1, 1);
                    end
                end
            end
            
            % For the Tiberius Power Update with changing wavelengths. 
            if ~isempty(obj.extPowerScaleFnc)
                aoVolts = obj.extPowerScaleFnc(aoVolts, bufStartFrm, nFrames);
                pathFOV = obj.extPowerScaleFnc(pathFOV, bufStartFrm, nFrames);
            end
            
        end
        
        function val = getExtLineClockTerminal(obj)
            % This routine configures the start trigger for hTask
            % it first tries to connect the start trigger to the internal
            % beamsclock output of Scan2D. If this route fails, it uses the
            % external trigger terminal configured in the MDF
            
            if isempty(obj.hTask)
                val = '';
            else
                try
                    % Try internal routing
                    pxiTrig = obj.hSI.hScan2D.trigBeamClkOutInternalTerm;
                    obj.hTask.cfgDigEdgeStartTrig(pxiTrig);
                    obj.hTask.control('DAQmx_Val_Task_Reserve'); % if no internal route is available, this call will throw an error
                    obj.hTask.control('DAQmx_Val_Task_Unreserve');
                    val = pxiTrig;
                    % fprintf('Beams: internal modified line clock trigger route found: %s\n',val);
                catch ME
                    % Error -89125 is expected: No registered trigger lines could be found between the devices in the route.
                    % Error -89139 is expected: There are no shared trigger lines between the two devices which are acceptable to both devices.
                    if isempty(strfind(ME.message, '-89125')) && isempty(strfind(ME.message, '-89139')) % filter error messages
                        rethrow(ME)
                    end
                    
                    val = obj.currentBeams{1}.hModifiedLineClockIn;
                    assert(~isempty(val), 'Beams: modifiedLineClock was empty for one or more beams and no internal trigger route was found.');
                    val = val.name;
                end
            end
        end
        
        function val = getExtFrameClockTerminal(obj)
            % This routine configures the start trigger for hTask
            % it first tries to connect the start trigger to the internal
            % framesclock output of Scan2D. If this route fails, it uses the
            % external trigger terminal configured in the MDF
            
            if isempty(obj.hTask)
                val = '';
            else
                try
                    % Try internal routing
                    internalTrigTerm = obj.hSI.hScan2D.trigFrameClkOutInternalTerm;
                    obj.hTask.cfgDigEdgeStartTrig(internalTrigTerm);
                    obj.hTask.control('DAQmx_Val_Task_Reserve'); % if no internal route is available, this call will throw an error
                    obj.hTask.control('DAQmx_Val_Task_Unreserve');
                    obj.hTask.disableStartTrig();
                    
                    val = internalTrigTerm;
                    % fprintf('Beams: internal frame clock trigger route found: %s\n',val);
                catch ME
                    % Error -89125 is expected: No registered trigger lines could be found between the devices in the route.
                    % Error -89139 is expected: There are no shared trigger lines between the two devices which are acceptable to both devices.
                    if isempty(strfind(ME.message, '-89125')) && isempty(strfind(ME.message, '-89139')) % filter error messages
                        rethrow(ME)
                    end
                    obj.hTask.control('DAQmx_Val_Task_Unreserve');
                    obj.hTask.disableStartTrig();

                    % No internal route available - use MDF settings
                    val = obj.currentBeams{1}.hFrameClockIn;
                    assert(~isempty(val), 'Beams: frameClockIn was empty for beam %s and no internal trigger route was found.', obj.currentBeams{1}.name);
                    val = obj.currentBeams{1}.hFrameClockIn.name;
                end
            end
        end
        
        function [term, rate] = getExtReferenceClock(obj)
            if isempty(obj.hTask)
                term = '';
                rate = [];
            else
                try
                    set(obj.hTask,'sampClkTimebaseSrc',obj.hSI.hScan2D.trigReferenceClkOutInternalTerm);
                    set(obj.hTask,'sampClkTimebaseRate',obj.hSI.hScan2D.trigReferenceClkOutInternalRate);
                    
                    obj.hTask.control('DAQmx_Val_Task_Reserve'); % if no internal route is available, this call will throw an error
                    obj.hTask.control('DAQmx_Val_Task_Unreserve');
                    
                    set(obj.hTask,'sampClkTimebaseSrc','');
                    
                    term = obj.hSI.hScan2D.trigReferenceClkOutInternalTerm;
                    rate = obj.hSI.hScan2D.trigReferenceClkOutInternalRate;
                catch ME
                    % Error -89125 is expected: No registered trigger lines could be found between the devices in the route.
                    % Error -89139 is expected: There are no shared trigger lines between the two devices which are acceptable to both devices.
                    if isempty(strfind(ME.message, '-89125')) && isempty(strfind(ME.message, '-89139')) % filter error messages
                        rethrow(ME)
                    end
                    obj.hTask.control('DAQmx_Val_Task_Unreserve');
                    set(obj.hTask,'sampClkTimebaseSrc','100MHzTimebase');
                    set(obj.hTask,'sampClkTimebaseRate',100e6);
                    
                    daqBusType = obj.currentBeams{1}.hAOControl.hDAQ.busType;
                    if ismember(daqBusType, {'DAQmx_Val_PXI','DAQmx_Val_PXIe'})
                        term = 'PXI_CLK10';
                        rate = 10e6;
                    else
                        
                        term = obj.currentBeams{1}.hReferenceClockIn;
                        rate = obj.currentBeams{1}.referenceClockRate;
                        
                        if isempty(term)
                            most.idioms.warn('Beams: referenceClockIn was empty for beam %d and no internal trigger route was found. Beam output will drift over time.', obj.currentBeams{1}.name);
                            term = '';
                        else
                            term.name;                  
                        end
                    end
                end
            end
        end
        
        function streamingBufferNSampCB(obj,~,~)
            obj.samplesGenerated = obj.samplesGenerated + obj.nSampCbN;
            obj.framesGenerated = obj.samplesGenerated / obj.frameSamps;
            obj.updateBeamBufferAsync(false);
        end
        
        function bufsz = configureStreaming(obj,sampleRate)
            if obj.enablePowerBox && ((obj.powerBoxStartFrame > 1) || (~isinf(obj.powerBoxEndFrame))) || obj.tfExtForceStreaming
                obj.streamingBuffer = true;
                
                if obj.hSI.hStackManager.isFastZ
                    obj.aoSlices = numel(obj.hSI.hStackManager.zs) + obj.hSI.hFastZ.numDiscardFlybackFrames;
                else
                    obj.aoSlices = 1;
                end
                L = length(obj.hSI.hWaveformManager.scannerAO.ao_volts(1).B);
                assert(mod(L,obj.aoSlices) == 0,'AO length is not divisible by number of slices.')
                obj.frameSamps = L/obj.aoSlices;
                
                frameTime = obj.frameSamps / sampleRate;
                n = ceil(obj.nominalStreamingBufferTime / frameTime);
                obj.streamingBufferFrames = ceil(n/2)*2;
                obj.streamingBufferSamples = obj.streamingBufferFrames * obj.frameSamps;
                obj.nSampCbN = obj.streamingBufferSamples / 2;
                
                obj.samplesGenerated = 0;
                obj.samplesWritten = 0;
                obj.framesGenerated = 0;
                obj.framesWritten = 0;
                
                if ~isempty(obj.hTask)
                    obj.hTask.set('writeRegenMode','DAQmx_Val_DoNotAllowRegen');
                    obj.hTask.registerEveryNSamplesEvent(@obj.streamingBufferNSampCB,obj.nSampCbN,false);
                end
            else
                obj.streamingBuffer = false;
                obj.streamingBufferFrames = 1;
                obj.streamingBufferSamples = length(obj.hSI.hWaveformManager.scannerAO.ao_volts.B);
                
                if ~isempty(obj.hTask)
                    obj.hTask.set('writeRegenMode','DAQmx_Val_AllowRegen');
                    obj.hTask.registerEveryNSamplesEvent([],[],false);
                end
            end
            
            bufsz = obj.streamingBufferSamples;
        end
        
        function rearm(obj)
            if ~isempty(obj.currentBeams.fastBeams)
                assert(obj.active);
                obj.beamBufferNeedsUpdateAsync = false;
                if ~obj.sharingScannerDaq
                    obj.hTask.abort();
                end
                obj.beamBufferUpdatingAsyncNow = false;
                
                if ~obj.sharingScannerDaq
                    obj.configureBeamsTask();
                    if ~obj.hSI.hScan2D.simulated
                        obj.hTask.start();
                    end
                end
            end
        end

        function configureBeamsTask(obj)
            obj.recreateBeamDaqTask();
            
            if isempty(obj.hTask)
                return
            end
            % set up reference clock if needed
            
            ss = obj.hSI.hScan2D.scannerset;
            beamCfg = ss.beamsTriggerCfg();
            sampleRate = ss.beams(1).sampleRateHz;
            
            % reset sampClkTimebase to default and preconfigure
            % sampleRate. otherwise, getExtReferenceClock can throw and
            % error if sampleRate and sampClkTimebaseRate conflict
            set(obj.hTask,'sampClkTimebaseSrc','OnboardClock');
            set(obj.hTask,'sampClkRate',sampleRate);
            
            if beamCfg.requiresReferenceClk
                [refTerm, refRate] = obj.getExtReferenceClock();
                if ~isempty(refTerm)                    
                    set(obj.hTask,'sampClkTimebaseSrc',refTerm);
                    set(obj.hTask,'sampClkTimebaseRate',refRate);
                end
            end
            
            % set up trigger
            switch beamCfg.triggerType
                case 'lineClk'
                    obj.hTask.cfgDigEdgeStartTrig(obj.getExtLineClockTerminal);
                    obj.hTask.set('startTrigRetriggerable',true);
                    sampleQuantity = 'DAQmx_Val_FiniteSamps';
                    samplesPerTrigger = obj.hSI.hWaveformManager.scannerAO.ao_samplesPerTrigger.B;
                    
                    bufsz = obj.configureStreaming(sampleRate);
                case 'frameClk'
                    obj.hTask.cfgDigEdgeStartTrig(obj.getExtFrameClockTerminal);
                    obj.hTask.set('startTrigRetriggerable',true);
                    sampleQuantity = 'DAQmx_Val_FiniteSamps';
                    samplesPerTrigger = obj.hSI.hWaveformManager.scannerAO.ao_samplesPerTrigger.B;
                    
                    bufsz = obj.configureStreaming(sampleRate);
                case 'static'
                    obj.hTask.disableStartTrig;
                    obj.hTask.set('startTrigRetriggerable',false);
                    sampleQuantity = 'DAQmx_Val_ContSamps';
                    samplesPerTrigger = 10e3;
                    
                    assert(~obj.enablePowerBox,'Power box unsupported during static beam output');
                    obj.configureStreaming(sampleRate);
                    obj.streamingBufferSamples = 10e3;  %overwrite streamingBufferSamples
                    bufsz = obj.streamingBufferSamples;
                otherwise 
                    error('Unsupported trigger type: %s',triggerType);
            end
            
            ao = obj.hSI.hWaveformManager.scannerAO.ao_volts.B;
            assert(size(ao,1) > 0, 'AO generation error. Beams AO waveform length is zero.');
            
            if ~obj.hSI.hScan2D.simulated
                obj.hTask.cfgSampClkTiming(sampleRate,sampleQuantity,samplesPerTrigger);
                assert(obj.hTask.sampClkRate == sampleRate,'Beams sample rate could not be satisfied'); % read sample clock back to verify configuration
                obj.hTask.cfgOutputBuffer(bufsz);
            end
            
            obj.updateBeamBufferAsync(false, 5);
            
            if ~obj.hSI.hScan2D.simulated
                obj.hTask.control('DAQmx_Val_Task_Verify'); % verify task configuration (mostly for trigger routing)
            end
        end
        
        function recreateBeamDaqTask(obj)
            most.idioms.safeDeleteObj(obj.hTask);
            obj.hTask = [];
            obj.maxSampleRate = [];
            
            fastBeams = obj.currentScanners.fastBeams;
            
            if isempty(fastBeams)
                obj.sharingScannerDaq = false;
                return
            end
            
            arrayfun(@(s)s.hDevice.assertNoError(),fastBeams);
            
            hDAQs = arrayfun(@(s)s.hDevice.hAOControl.hDAQ,fastBeams,'UniformOutput',false);
            hDAQ = hDAQs{1};
            assert( all(cellfun(@(daq)daq == hDAQ,hDAQs)), 'All Beams have to be on the same DAQ board.');
            
            isvDAQ = isa(hDAQ,'dabs.resources.daqs.vDAQ');
            isSlmScan = isa(obj.hSI.hScan2D,'scanimage.components.scan2d.SlmScan');
            sharingDAQ = isprop(obj.hSI.hScan2D,'yGalvo') && obj.hSI.hScan2D.yGalvo.hAOControl.hDAQ == hDAQ;
            
            if isvDAQ || sharingDAQ || isSlmScan
                obj.sharingScannerDaq = true;
                return
            else
                obj.sharingScannerDaq = false; 
            end
            
            obj.hTask = most.util.safeCreateTask('Beam Modulation');
            
            %make props exist
            get(obj.hTask, 'writeRelativeTo');
            get(obj.hTask, 'writeOffset');
            
            for idx = 1:numel(fastBeams)
                scanner = fastBeams(idx);
                hAO = scanner.hDevice.hAOControl;
                obj.hTask.createAOVoltageChan(hAO.hDAQ.name,hAO.channelID);
            end
            
            supportedSampleRate = scanimage.util.daqTaskGetMaxSampleRate(obj.hTask);
            supportedSampleRate = supportedSampleRate * 0.9; % clamp sample rate to 90% of max rate to avoid DAC conversion errors
            
            obj.hTask.cfgSampClkTiming(supportedSampleRate,'DAQmx_Val_FiniteSamps');
            obj.maxSampleRate = obj.hTask.sampClkRate;
        end
        
        function val = zprpBeamScalarExpandPropValue(obj,val,propName)
            if isempty(val)
                val = NaN;
            end
            
            if isscalar(val)
                val = repmat(val,1,obj.totalNumBeams);
            else
                assert(numel(val)==obj.totalNumBeams,...
                    'The ''%s'' value must be a vector of length %d -- one value for each beam',...
                    propName,obj.totalNumBeams);
                s = size(val);
                if s(1) > s(2)
                    val = val';
                end
            end
        end
        
         function load_pzLut(obj)
            v = obj.pzLUTSource;
            
            for i = 1:numel(v)
                v{i} = loadLut(v{i});
            end
            
            obj.pzLUT = v;
            
            %%% Nested function
            function v = loadLut(v)
                try
                    if isempty(v)
                        v = zeros(0,2);
                    elseif isnumeric(v)
                        % No-op
                    elseif ischar(v)
                        % load lut from disk
                        assert(exist(v,'file')==2,'Could not find file ''%s'', please ensure the path is correct.',v);
                        v = importdata(v);
                        v(:,2) = v(:,2) / 100; % convert from percent to fraction
                    end
                    
                    assert(isnumeric(v),'A Beams LUT must be a numeric matrix representing the lookup table for the z depth power adjustment');
                    vSize = size(v);
                    assert(numel(vSize)==2 && vSize(2)==2,'A Beams LUT must be a 2-column matrix')
                    assert(~any(isinf(v(:))) && ~any(isnan(v(:))) && isreal(v), 'LUT contains invalid data. Must be numeric, finite, real values.');
                    assert(issorted(v(:,1)),'First column of LUT needs to be sorted');
                    
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                    v = zeros(0,2);
                end
            end
        end
        
        function val = expandVal(obj,val,defaultVal)
            numBeams = numel(obj.hBeams);
            val(end+1:numBeams) = defaultVal;
            val(numBeams+1:end) = [];
        end
    end
    
    %%%Abstract method impementations (most.Model)
    methods (Access=protected, Hidden)
        function mdlInitialize(obj)
            %Property eigensets
            mdlInitialize@most.Model(obj);
        end
    end
    
    %%% Abstract method implementations (scanimage.interfaces.Component)
    methods (Hidden,Access = protected)
        function componentStart(obj)
        %   Runs code that starts with the global acquisition-start command
        
            assert(~obj.enablePowerBox || ~obj.hSI.hStackManager.isFastZ || ~obj.sharingScannerDaq || ((obj.powerBoxStartFrame == 1) && isinf(obj.powerBoxEndFrame)),...
                'Time varying power box is not supported with FastZ enabled when beams and galvos are on the same DAQ.');
            
            fastBeamsMask = cellfun(@(b)isa(b,'dabs.resources.devices.BeamModulatorFast'), obj.hBeams);
            fastBeams = obj.hBeams(fastBeamsMask);
            obj.deactivateBeams(fastBeams);
            
            obj.configureBeamsTask();
            if ~obj.hSI.hScan2D.simulated && ~isempty(obj.hTask)
                obj.hTask.start();
            end
            
            obj.hSI.hStackManager.modulateSlowBeams(obj.hSI.hStackManager.hZs.subset(1));
        end
        
        function componentAbort(obj)
        %   Runs code that aborts with the global acquisition-abort command
            %Turns off beam channel(s)
            obj.beamBufferNeedsUpdateAsync = false;
            
            if most.idioms.isValidObj(obj.hTask)
                try
                    obj.hTask.abort();
                    obj.hTask.control('DAQmx_Val_Task_Unreserve');
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
            end
            
            obj.beamBufferUpdatingAsyncNow = false;
            obj.sharingScannerDaq = false;
            
            obj.deactivateCurrentBeams();
        end
    end
    
    methods
        function deactivateCurrentBeams(obj)
            obj.deactivateBeams(obj.currentBeams);
        end
        
        function deactivateAllBeams(obj)
            obj.deactivateBeams(obj.hBeams);
        end
        
        function deactivateBeams(obj,beams)
            slowBeamsMask = cellfun(@(b)isa(b,'dabs.resources.devices.BeamModulatorSlow'),beams);
            slowBeams = beams(slowBeamsMask);
            fastBeams = beams(~slowBeamsMask);
            
            for idx = 1:numel(fastBeams)
                try
                    fastBeams{idx}.setPowerFraction(0);
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
            end
            
            for idx = 1:numel(slowBeams)
                try
                    slowBeams{idx}.setPowerFractionAsync(0);
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
            end
            
            for idx = 1:numel(slowBeams)
                try
                    slowBeams{idx}.modulateWaitForFinish();
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
            end
            
            for idx = 1:numel(obj.hBeamRouters)
                try
                    obj.hBeamRouters{idx}.setPowerFractionsZero();
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
            end
        end
    end
end

function s = ziniInitPropAttributes()
    s = struct;
    s.flybackBlanking = struct('Classes','binaryflex');
    s.interlaceDecimation = struct('Attributes',{{'positive' 'vector'}},'AllowEmpty',1);
    s.interlaceOffset = struct('Attributes',{{'nonnegative' 'vector'}},'AllowEmpty',1);
    s.lengthConstants = struct('Attributes',{{'vector'}},'AllowEmpty',1);
    s.enablePowerBox = struct('Classes','binaryflex');
    s.powerBoxStartFrame = struct('Attributes',{{'scalar','finite','positive','integer'}});
    s.powerBoxEndFrame = struct('Attributes',{{'scalar','nonnegative'}});
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
