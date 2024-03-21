classdef Motors < scanimage.interfaces.Component & most.HasMachineDataFile & dabs.resources.configuration.HasConfigPage
    properties (SetAccess=protected,Hidden)
        ConfigPageClass = 'dabs.resources.configuration.resourcePages.SIMotorsPage';
    end
    
    methods (Static)
        function names = getDescriptiveNames()
            names = {'ScanImage stage system'}; % returns cell string of descriptive names; this is a function so it can be overloaded
        end
    end
    
    %%% ABSTRACT PROPERTY REALIZATION (most.Model)
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = initPropAttributes();
        mdlHeaderExcludeProps = {'hMotors'};
    end
    
    %%% ABSTRACT PROPERTY REALIZATIONS (most.HasMachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'Motors';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
        
        mdfDefault = defaultMdfSection();
    end
    
    %%% ABSTRACT PROPERTY REALIZATION (scanimage.interfaces.Component)
    properties (SetAccess = protected, Hidden)
        numInstances = 0;
    end
    
    properties (Constant, Hidden)
        COMPONENT_NAME = 'Motors';               % [char array] short name describing functionality of component e.g. 'Beams' or 'FastZ'
        PROP_TRUE_LIVE_UPDATE = {};              % Cell array of strings specifying properties that can be set while the component is active
        PROP_FOCUS_TRUE_LIVE_UPDATE = {};        % Cell array of strings specifying properties that can be set while focusing
        DENY_PROP_LIVE_UPDATE = {};              % Cell array of strings specifying properties for which a live update is denied (during acqState = Focus)
        
        FUNC_TRUE_LIVE_EXECUTION = {}; % Cell array of strings specifying functions that can be executed while the component is active
        FUNC_FOCUS_TRUE_LIVE_EXECUTION = {};         % Cell array of strings specifying functions that can be executed while focusing
        DENY_FUNC_LIVE_EXECUTION = {'saveUserDefinedPositions' 'loadUserDefinedPositions'};    % Cell array of strings specifying functions for which a live execution is denied (during acqState = Focus)
    end
    
    %% USER PROPS
    properties (SetObservable)
        moveTimeout_s = 10;
        axesPosition = [];
        userDefinedPositions = repmat(struct('name','','coords',[]),0,1); % struct containing positions defined by users
        minPositionQueryInterval_s = 1e-3;
        
        maxZStep = inf;
    end
    
    % MDF variables
    properties (SetObservable,Transient,Hidden)
        hMotorXYZ = cell(1,3);
        motorAxisXYZ = [1,1,1];
        scaleXYZ = [1,1,1];
        backlashCompensation = [0 0 0];
        
        hPtMinZLimit = scanimage.mroi.coordinates.Points.empty();
        hPtMaxZLimit = scanimage.mroi.coordinates.Points.empty();
    end
    
    properties (Dependent,SetObservable,Transient)
        samplePosition;
        moveInProgress;
        isRelativeZeroSet;
        motorErrorMsg;
        isHomed;
        errorTf;
        isAligned;
    end        
        
    properties (Dependent,SetObservable)
        azimuth
        elevation
    end
    
    properties (SetObservable, SetAccess = private, Transient)
        markers = scanimage.components.motors.MotorMarker.empty(1,0);
        simulatedAxes = [false false false];
    end
    
    %% Internal properties
    properties (SetAccess = private,Hidden, SetObservable)
        hMotors = {};
        hSimulatedMotor = [];
        motorDimMap = {};
        motorAxes;
        
        hCSCoordinateSystem;
        hCSRotation;
        hCSMicron;
        hCSAlignment;
        hCSAntiAlignment;
        hCSAxesScaling;
        hCSAxesPosition;
        hCSSampleAbsolute
        hCSSampleRelative
        
        hCSListeners = event.listener.empty(1,0);
        hMotorListeners = event.listener.empty(1,0);
        
        lastPositionQuery = tic();
    end
    
    properties (Access = private)
        hCSAntiRotation
        hCSAxesAntiScaling
    end
    
    properties (Hidden,SetObservable,SetAccess = private)
        calibrationPoints = cell(0,2);
    end
    
    properties (Hidden)
        hErrorCallBack;
        mdfHasChanged;
    end
    
    %% Lifecycle
    methods (Access = ?scanimage.SI)
        function obj = Motors(~)
            obj@scanimage.interfaces.Component('SI Motors');
            obj@most.HasMachineDataFile(true);
            
            try
                obj.hSimulatedMotor = dabs.simulated.Motor('SI simulated motor');
                obj.initCoordinateSystems();
            catch ME
                most.ErrorHandler.logAndReportError(ME);
                obj.errorMsg = 'Error during construction.';
            end
            
            obj.loadMdf();
        end
    end
    
    methods        
        function delete(obj)
            obj.deinit();
            most.idioms.safeDeleteObj(obj.hCSListeners);
            most.idioms.safeDeleteObj(obj.hSimulatedMotor);
        end
    end
    
    methods        
        function deinit(obj)            
            most.idioms.safeDeleteObj(obj.hMotorListeners);
            obj.hMotorListeners = event.listener.empty(0,1);
            
            obj.hMotors = {};
            obj.motorDimMap = {};
        end
        
        function reinit(obj)
            obj.deinit();
            
            try                 
                validateMotors(obj.hMotorXYZ,obj.motorAxisXYZ);
                [hMotors_,motorDimMap_] = makeDimMap(obj.hMotorXYZ,obj.motorAxisXYZ);
                obj.motorDimMap = motorDimMap_; % set this before motorDimMap because of listener dependency
                obj.hMotors = hMotors_;
                
                obj.simulatedAxes = cellfun(@(hM)isa(hM,'dabs.simulated.Motor'),obj.hMotorXYZ);
                
                addCellArrayListeners(obj.hMotors,'lastKnownPosition','PostSet',@obj.motorPositionChanged);
                addCellArrayListeners(obj.hMotors,'isMoving','PostSet',@obj.motorIsMovingChanged);
                addCellArrayListeners(obj.hMotors,'errorMsg','PostSet',@obj.errorMsgChanged);
                addCellArrayListeners(obj.hMotors,'isHomed','PostSet',@obj.isHomedChanged);
                addCellArrayListeners(obj.hMotors,'ObjectBeingDestroyed',@(varargin)obj.reinit);
                
                obj.errorMsg = '';
                obj.numInstances = numel(obj.hMotors);
                obj.queryPosition();
                obj.setPositionTargetToCurrentPosition();                
            catch ME
                obj.deinit();
                obj.errorMsg = ME.message;
                most.ErrorHandler.logAndReportError(ME,'Error initializing: %s',obj.errorMsg);
            end
            
            %%% Local functions
            function validateMotors(hMotorsXYZ,motorAxisXYZ)
                assert(all( cellfun(@(hM)most.idioms.isValidObj(hM),hMotorsXYZ) ));
                
                pairs = {{hMotorsXYZ{1}.name,motorAxisXYZ(1)}...
                        ,{hMotorsXYZ{2}.name,motorAxisXYZ(2)}...
                        ,{hMotorsXYZ{3}.name,motorAxisXYZ(3)}};
                
                conflict = isequal(pairs{1},pairs{2}) ...
                        || isequal(pairs{1},pairs{3}) ...
                        || isequal(pairs{2},pairs{3}); 
                
                assert(~conflict,'Double assignment of motor axis');
            end
            
            function [hMotors,dimMaps] =  makeDimMap(hMotorsXYZ,motorAxisXYZ)                
                hMotors = cellUnique(hMotorsXYZ);
                dimMaps = cell(size(hMotors));
                
                for idx = 1:numel(hMotors)
                    hMotor = hMotors{idx};
                    dimMap = nan(1,hMotor.numAxes);
                    
                    for siAxis = 1:numel(motorAxisXYZ)
                        if hMotor == hMotorsXYZ{siAxis}
                            motorAxis = motorAxisXYZ(siAxis);
                            dimMap(motorAxis) = siAxis;
                        end
                    end
                    
                    dimMaps{idx} = dimMap;
                end
            end
            
            function validateMotorDimMap(dimMaps)
                % ensure there are no double assignments of dimensions
                allDims = horzcat(dimMaps{:});
                
                Xs = sum(allDims==1);
                Ys = sum(allDims==2);
                Zs = sum(allDims==3);
                
                assert(numel(Xs)<=1,'Motors: Double assignment of X-axes.');
                assert(numel(Ys)<=1,'Motors: Double assignment of Y-axes.');
                assert(numel(Zs)<=1,'Motors: Double assignment of Z-axes.');
            end
            
            function addCellArrayListeners(objects,varargin)
                for idx_ = 1:numel(objects)
                    obj.hMotorListeners(end+1) = most.ErrorHandler.addCatchingListener(objects{idx_},varargin{:});
                end
            end
            
            function out = cellUnique(in)
                out = {};
                for idx = 1:numel(in)
                    mask = cellfun(@(o)isequal(o,in{idx}),out);
                    if ~any(mask)
                        out{end+1} = in{idx};
                    end
                end
            end
        end
    end
    
    %% MDF methods
    methods (Hidden)
        function loadMdf(obj)
            success = true;
            success = success & obj.safeSetPropFromMdf('hMotorXYZ', 'motorXYZ');
            success = success & obj.safeSetPropFromMdf('motorAxisXYZ', 'motorAxisXYZ');
            success = success & obj.safeSetPropFromMdf('scaleXYZ', 'scaleXYZ');
            success = success & obj.safeSetPropFromMdf('backlashCompensation', 'backlashCompensation');
            
            if isfield(obj.mdfData,'moveTimeout_s')
                success = success & obj.safeSetPropFromMdf('moveTimeout_s', 'moveTimeout_s');
            end
            
            if ~success
                obj.errorMsg = 'Error loading config';
            end
        end
        
        function saveMdf(obj)            
            motorNames = cell(1,3);
            for idx = 1:numel(obj.hMotorXYZ)
                hMotor = obj.hMotorXYZ{idx};
                if most.idioms.isValidObj(hMotor)
                    motorNames{idx} = hMotor.name;
                else
                    motorNames{idx} = '';
                end
            end
            
            obj.safeWriteVarToHeading('motorXYZ', motorNames);
            obj.safeWriteVarToHeading('motorAxisXYZ', obj.motorAxisXYZ);
            obj.safeWriteVarToHeading('scaleXYZ', obj.scaleXYZ);
            obj.safeWriteVarToHeading('backlashCompensation', obj.backlashCompensation);
            obj.safeWriteVarToHeading('moveTimeout_s', obj.moveTimeout_s);
        end
    end
    
    methods (Access = private)
        function initCoordinateSystems(obj)
           % initialize coordinate systems
            obj.hCSCoordinateSystem  = scanimage.mroi.coordinates.CSLinear('Motor Root Coordinates',  3, obj.hSI.hCoordinateSystems.hCSReference);
            
            obj.hCSMicron           = scanimage.mroi.coordinates.CSLinear('Motor Micron', 3, obj.hCSCoordinateSystem);
            
            obj.hCSAlignment         = scanimage.mroi.coordinates.CSLinear('Motor Alignment',        3, obj.hCSMicron);
            
            obj.hCSRotation          = scanimage.mroi.coordinates.CSLinear('Motor Rotation',         3, obj.hCSAlignment);
            obj.hCSRotation.lock     = true;
            obj.hCSAxesScaling       = scanimage.mroi.coordinates.CSLinear('Motor Scaling',          3, obj.hCSRotation);
            obj.hCSAxesScaling.lock  = true;
            obj.hCSAxesPosition      = scanimage.mroi.coordinates.CSLinear('Motor Axes Coordinates', 3, obj.hCSAxesScaling);
            obj.hCSAxesPosition.fromParentAffine = eye(4);
            obj.hCSAxesPosition.lock = true;
            obj.hCSAxesAntiScaling   = scanimage.mroi.coordinates.CSLinear('Motor Anti Scaling',     3, obj.hCSAxesPosition);
            obj.hCSAxesAntiScaling.lock = true;
            obj.hCSAntiRotation      = scanimage.mroi.coordinates.CSLinear('Motor Anti Rotation',    3, obj.hCSAxesAntiScaling);
            obj.hCSAntiRotation.lock = true;
            
            obj.hCSAntiAlignment      = scanimage.mroi.coordinates.CSLinear('Motor Anti Alignment',    3, obj.hCSAntiRotation);
            obj.hCSAntiAlignment.lock = true;
            
            obj.hCSSampleAbsolute    = scanimage.mroi.coordinates.CSLinear('Sample Absolute',        3, obj.hCSAntiAlignment);
            obj.hCSSampleRelative    = scanimage.mroi.coordinates.CSLinear('Sample Relative',        3, obj.hCSSampleAbsolute);
            
            addEventListeners('changed',@obj.csUpdateAntiCS,{obj.hCSRotation,obj.hCSAlignment,obj.hCSAxesScaling});
            addEventListeners('changed',@obj.csChanged,{obj.hCSCoordinateSystem,...
                obj.hCSRotation,obj.hCSAxesScaling,obj.hCSMicron,obj.hCSAlignment,obj.hCSAxesPosition,...
                obj.hCSSampleAbsolute,obj.hCSSampleRelative});
            
            obj.updateScaling();
            
            %%% local function
            function addEventListeners(eventName,callback,objects)
                for idx = 1:numel(objects)
                    obj.hCSListeners(end+1) = most.ErrorHandler.addCatchingListener(objects{idx},eventName,callback);
                end
            end
        end
    end
    
    %% Friend methods
    methods (Hidden)        
        function updateScaling(obj)            
            % apply Scaling. Anti-Scaling is going to be set
            % automatically through listeners
            if most.idioms.isValidObj(obj.hCSAxesScaling)
                scaleT = eye(4);
                scaleT([1 6 11]) = obj.scaleXYZ;
                obj.hCSAxesScaling.toParentAffine = scaleT;
            end
        end
        
        function tf = isContinuousMoveAllowed(obj)
            % continuos move is allowed if all axes are Zaber or Simulated axes
            motorIsZaber     = cellfun(@(hMotor)isa(hMotor,'dabs.zaber.ZaberMultiDevice'),obj.hMotors);
            motorIsSimulated = cellfun(@(hMotor)isa(hMotor,'dabs.simulated.Motor'),obj.hMotors);
            
            tf = all(motorIsZaber | motorIsSimulated);
        end
    end
    
    %% Abstract method implementation (scanimage.interfaces.Component)
    methods (Access = protected, Hidden)
        function componentStart(~)
        end
        
        function componentAbort(~)
        end
    end
    
    %% Public methdos
    methods
        function addMarker(obj,name)
            if nargin < 2 || isempty(name)
                name = inputdlg('Marker Name');
                if isempty(name) || isempty(name{1})
                    return
                end
                name = name{1};
            end
                
            obj.queryPosition();
            pos = obj.samplePosition;
            hPt = scanimage.mroi.coordinates.Points(obj.hCSSampleRelative,pos);
            hPt = hPt.transform(obj.hCSSampleAbsolute);
            
            powers = obj.hSI.hBeams.powers;            
            hMotorMarker = scanimage.components.motors.MotorMarker(name,hPt,powers);
            obj.markers(end+1) = hMotorMarker;
        end
        
        function deleteMarker(obj,id)
            if isa(id,'uint64')
                mask = [obj.markers.uuiduint64] == id;
            elseif isnumeric(id)
                mask = false(1,numel(obj.markers));
                mask(id) = true;
            elseif isa(id,'scanimage.components.motors.Marker')
                mask = obj.markers.uuidcmp(id);
            else
                mask = strcmpi(id,{obj.markers.name});
                mask = mask | strcmpi(id,{obj.markers.uuid});
            end
            
            obj.markers(mask) = [];
        end
        
        function clearMarkers(obj)
            obj.markers(:) = [];
        end
        
        function setRelativeZero(obj,newCenterPt)            
            if nargin < 2 || isempty(newCenterPt)
                newCenterPt = [0 0 0];
            end
            
            validateattributes(newCenterPt,{'numeric'},{'numel',3});
            
            obj.queryPosition();
            hPt_Ref = scanimage.mroi.coordinates.Points(obj.hSI.hCoordinateSystems.hCSReference,[0 0 0]);
            
            % set sample relative zero
            hPt = hPt_Ref.transform(obj.hCSSampleRelative.hParent);
            pt = hPt.points;
            
            T = obj.hCSSampleRelative.toParentAffine;
            
            newOffset = pt - newCenterPt;
            
            if ~isnan(newCenterPt(1))
                T(1,4) = newOffset(1);
            end
            
            if ~isnan(newCenterPt(2))
                T(2,4) = newOffset(2);
            end
            
            if ~isnan(newCenterPt(3))
                T(3,4) = newOffset(3);
            end

            obj.hCSSampleRelative.toParentAffine = T;
        end
        
        function clearRelativeZero(obj)
            obj.hCSSampleRelative.reset();
        end
        
        function success = reinitMotors(obj,failedOnly)
            if nargin < 2
                failedOnly = false;
            end
            
            
            for idx = 1:numel(obj.hMotors)
                if ~failedOnly || ~obj.hMotors{idx}.initSuccessful
                    obj.hMotors{idx}.reinit();
                end
            end
            
            obj.queryPosition();
            success = ~obj.errorTf;
        end
    end
    
    %% Internal functions
    methods (Hidden)        
        function csChanged(obj,src,evt)
            % if any of the coordinate systems changed, trigger a dummy set
            % to update the GUI
            obj.samplePosition = NaN;
            obj.axesPosition = NaN;
            
            obj.checkLimits();
        end
        
        function csUpdateAntiCS(obj,src,evt)
            % link Alignment to AntiAlignment
            if ~isempty(obj.hCSAlignment.toParentAffine)
                obj.hCSAntiAlignment.toParentAffine = inv(obj.hCSAlignment.toParentAffine);
            elseif ~isempty(obj.hCSAlignment.fromParentAffine)
                obj.hCSAntiAlignment.fromParentAffine = inv(obj.hCSAlignment.fromParentAffine);
            else
                obj.hCSAntiAlignment.reset();
            end
            
            % link Rotation to AntiRotation
            if ~isempty(obj.hCSRotation.toParentAffine)
                obj.hCSAntiRotation.toParentAffine = inv(obj.hCSRotation.toParentAffine);
            elseif ~isempty(obj.hCSRotation.fromParentAffine)
                obj.hCSAntiRotation.fromParentAffine = inv(obj.hCSRotation.fromParentAffine);
            else
                obj.hCSAntiRotation.reset();
            end
            
            % link Scaling to AntiScaling
            if ~isempty(obj.hCSAxesScaling.toParentAffine)
                obj.hCSAxesAntiScaling.toParentAffine = inv(obj.hCSAxesScaling.toParentAffine);
            elseif ~isempty(obj.hCSAxesScaling.fromParentAffine)
                obj.hCSAxesAntiScaling.fromParentAffine = inv(obj.hCSAxesScaling.fromParentAffine);
            else
                obj.hCSAxesAntiScaling.reset();
            end
            
            obj.csChanged();
            
            % update UI
            obj.azimuth = NaN;
            obj.elevation = NaN;
        end
        
        function setRotationAngles(obj,yaw,pitch,roll)
            % order of operation is important here. first yaw, then pitch, then roll
            M = makehgtform('zrotate',yaw,'yrotate',pitch,'xrotate',roll);
            
            obj.hCSRotation.fromParentAffine = M;
        end
        
        function [yaw,pitch,roll] = getRotationAngles(obj)
            M = obj.hCSRotation.fromParentAffine;
            if isempty(M)
                M = inv(obj.hCSRotation.toParentAffine);
            end
            
            % see http://planning.cs.uiuc.edu/node103.html
            yaw   = atan2(  M(2,1), M(1,1) );
            pitch = atan2( -M(3,1), sqrt(M(3,2)^2+M(3,3)^2) );
            roll  = atan2(  M(3,2), M(3,3) );
        end
        
        function rotationSet = getRotationSet(obj)
            fromT = obj.hCSRotation.fromParentAffine;
            toT   = obj.hCSRotation.toParentAffine;
            
            rotationSet = (~isempty(fromT) && ~iseye(fromT)) ...
                       || (~isempty(toT)   && ~iseye(toT));
            
            %%% Nested function
            function tf = iseye(T)
                tf = isequal(T,eye(size(T)));
            end
        end
        
        function checkLimits(obj)
            % motor limits don't work well when the coordinate system is
            % rotated. Depending on the order of the axis movement, the
            % motor trajectory might pass through the limit area
            % before settling at the target
            
            if obj.getRotationSet()
                if ~isinf(obj.maxZStep)
                    most.idioms.warn('Motor system: Limiting the z-step is only supported if coordinate system is not rotated. Removed z-step limit.');
                    obj.maxZStep = inf;
                end
                
                if ~isempty(obj.hPtMinZLimit)
                    most.idioms.warn('Motor system: Setting a minimum z-limit is only supported if coordinate system is not rotated. Removed minimum z-limit.');
                    obj.clearMinZLimit();
                end
                
                if ~isempty(obj.hPtMaxZLimit)
                    most.idioms.warn('Motor system: Setting a maximum z-limit is only supported if coordinate system is not rotated. Removed maximum z-limit.');
                    obj.clearMaxZLimit();
                end
            end
        end
        
        function motorPositionChanged(obj,src,evt)
            obj.decodeMotorPosition();
        end
        
        function motorIsMovingChanged(obj,src,evt)
            obj.moveInProgress = NaN; % trigger UI update
        end
        
        function errorMsgChanged(obj,src,evt)
            obj.motorErrorMsg = NaN; % for ui update
            errorMsgs = obj.motorErrorMsg;
            
            if isempty(errorMsgs)
                obj.errorMsg = '';
            else
                obj.errorMsg = strjoin(errorMsgs); % trigger UI update
            end
            
            if ~isempty(obj.errorMsg) && ~isempty(obj.hErrorCallBack)
                try
                    obj.hErrorCallBack();
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
            end
        end
        
        function isHomedChanged(obj,sr,evt)
            obj.isHomed = NaN;
        end
    end
    
    methods
        function setPositionTargetToCurrentPosition(obj)
            obj.queryPosition();
        end
        
        function hPt = getPosition(obj,hCS)
            autoUpdate = all(cellfun(@(hM)hM.autoPositionUpdate,obj.hMotors));
            if ~autoUpdate
                % legacy motors do not automatically update
                % lastKnownPosition needs to be updated here
                obj.queryPosition();
            end
            
            hPt = scanimage.mroi.coordinates.Points(obj.hSI.hCoordinateSystems.hCSReference,[0 0 0]);
            hPt = hPt.transform(hCS);
        end
        
        function xyz = queryPosition(obj)
            % explicitly queries the motor positions. this method should
            % not need to be called because motors are expected to publish
            % their positions via the lastKnownPosition property
            
            if ~isempty(obj.errorMsg)
                return
            end
            
            if toc(obj.lastPositionQuery) < obj.minPositionQueryInterval_s
                return;
            end
            
            for idx = 1:numel(obj.hMotors)
                % this updates the lastKnownPosition property of the motor
                if obj.hMotors{idx}.initSuccessful
                    try
                        obj.hMotors{idx}.queryPosition();
                    catch ME
                        most.ErrorHandler.logAndReportError(ME,sprintf('Motor %s threw an error when attempting to wait for move to finish.',obj.hMotors{idx}.name));
                    end
                end
            end
            
            obj.lastPositionQuery = tic();
            
            % this reads the lastKnownPosition property of the motors and
            % transforms it into SI coordinates
            xyz = obj.decodeMotorPosition();
        end
             
        function xyz = decodeMotorPosition(obj)
            % reads the lastKnownPosition property of the motors and
            % transforms it into SI coordinates
            
            xyz = obj.hCSAxesPosition.fromParentAffine(13:15);
            
            for idx = 1:numel(obj.hMotors)
                hMotor = obj.hMotors{idx};
                
                if hMotor.initSuccessful
                    try
                        pos = hMotor.lastKnownPosition;
                        
                        motorDimMap_ = obj.motorDimMap{idx};
                        axesMask = ~isnan(motorDimMap_);
                        dimIdxs = motorDimMap_(axesMask);
                        
                        pos = pos(~isnan(pos));
                        
                        isValid = isPositionValid(pos,axesMask);
                        
                        if isValid
                            xyz(dimIdxs) = pos(axesMask);
                        else
                            most.ErrorHandler.logAndReportError('Motor %s returned an invalid position: %s',hMotor.name,mat2str(pos));
                        end
                    catch ME
                        most.ErrorHandler.logAndReportError(ME,sprintf('Motor %s threw an error when attempting to retrieve last known position.',hMotor.name));
                    end
                end
            end
            
            obj.hCSAxesPosition.fromParentAffine(13:15) = double(xyz);
            
            
            %%% Nested function
            function isValid = isPositionValid(pos,axesMask)
                isValid = true;
                
                if ~isempty(axesMask)
                    isValid = isValid & numel(pos)<=numel(axesMask); % ensure that size of pos is adequat
                    pos = pos(axesMask);
                    isValid = isValid & ~any(isnan(pos)) & ~any(isinf(pos)) & all(isreal(pos));                    
                end
            end
        end
        
        function movePtToPosition(obj,hPt1,hPt2)
            hPt1 = hPt1.transform(obj.hSI.hCoordinateSystems.hCSReference);
            hPt2 = hPt2.transform(obj.hSI.hCoordinateSystems.hCSReference);
            
            hPt = hPt2-hPt1;
            
            obj.move(hPt);
        end
        
        function moveSample(obj,position,async)
            if nargin<3 || isempty(async)
                async = false;
            end
            
            if all(isnan(position))
                return
            end
            
            % fill in NaNs with current motor position
            if any(isnan(position))
                nanMask = isnan(position);
                obj.queryPosition();
                pos = obj.samplePosition;
                position(nanMask) = pos(nanMask);
            end
            
            validateattributes(position,{'numeric'},{'vector','numel',3,'nonnan','finite','real'});
            
            hPt = scanimage.mroi.coordinates.Points(obj.hCSSampleRelative, position); % wrap point
            
            obj.move(hPt,async);
        end
        
        function move(obj,hPt,async,axes)
            if nargin<3 || isempty(async)
                async = false;
            end
            
            if nargin<4 || isempty(axes)
                axes = [true true true];
            end
            
            % moves the motor to a point specified by scanimage.mroi.coordinates.Points
            assert(isa(hPt,'scanimage.mroi.coordinates.Points'));
            validateattributes(axes,{'numeric','logical'},{'binary','size',[1,3]});
            
            if ~isinf(obj.maxZStep)
                obj.queryPosition();
                hCurrentPt = obj.getPosition(obj.hCSSampleAbsolute);
                hNextPt = hPt.transform(obj.hCSSampleAbsolute);
                dz = abs(hCurrentPt.points(3)-hNextPt.points(3));
                assert(dz <= obj.maxZStep,'Move exceeds maximum allowed z step. Allowed: %.2fum. Requested: %.2fum',obj.maxZStep,dz);
            end
            
            hPt_SampleAbsolute = hPt.transform(obj.hCSSampleAbsolute);
            
            if ~all(axes)
                obj.queryPosition();
                hPt_SampleAbsolute = hPt.transform(obj.hCSSampleAbsolute);
                hCurrentPt = obj.getPosition(obj.hCSSampleAbsolute);
                pt = hPt_SampleAbsolute.points();
                pt(~axes) = hCurrentPt.points(~axes);
                hPt_SampleAbsolute = scanimage.mroi.coordinates.Points(obj.hCSSampleAbsolute,pt);
            end
            
            ptZSampAbs = hPt_SampleAbsolute.points(3);
            
            if ~isempty(obj.hPtMinZLimit)
                ptMinZ = obj.hPtMinZLimit.transform(obj.hCSSampleAbsolute);
                minZ = ptMinZ.points(3);
                assert(ptZSampAbs >= minZ,'Move exceeds z bounding box');
            end
            
            if ~isempty(obj.hPtMaxZLimit)
                ptMaxZ = obj.hPtMaxZLimit.transform(obj.hCSSampleAbsolute);
                maxZ = ptMaxZ.points(3);
                assert(ptZSampAbs <= maxZ,'Move exceeds z bounding box');
            end
            
            hPt_SampleAbsolute = hPt_SampleAbsolute.transform(obj.hCSAxesPosition);
            val = hPt_SampleAbsolute.points;
            assert(~any(isnan(val)|isinf(val)),'Position vector contains NaNs');
            
            obj.moveAxesWithBacklashCompensation(val,async);
        end
        
        function stop(obj)
            for idx = 1:numel(obj.hMotors)
                try
                    if obj.hMotors{idx}.initSuccessful
                        obj.hMotors{idx}.stop();
                    end
                catch ME
                    most.ErrorHandler.logAndReportError(ME,sprintf('Motor %s threw an error when attempting to stop move.',obj.hMotors{idx}.name));
                end
            end
        end
    end
    
    methods (Hidden)
        function moveAxesWithBacklashCompensation(obj,axesXYZ,async)
            if nargin<3 || isempty(async)
                async = false;
            end
            
            if ~async && any(obj.backlashCompensation)
                currentXYZ = obj.queryPosition();
                moveDirection = sign(axesXYZ-currentXYZ);
                applyCompensation = moveDirection ~= sign(obj.backlashCompensation);
                
                if any(applyCompensation)
                    compensatedXYZ = axesXYZ - obj.backlashCompensation.*applyCompensation;
                    obj.moveAxes(compensatedXYZ);
                end 
            end
            
            obj.moveAxes(axesXYZ,async);
        end
        
        function moveAxes(obj,axesXYZ,async)
            if nargin<3 || isempty(async)
                async = false;
            end
            validateattributes(async,{'logical','numeric'},{'scalar','binary'});
            % moves the motors in absolute raw XYZ units
            
            assert(~obj.errorTf,'Cannot move axes. The motor is in an error state.');
            
            if ~async
                assert(~obj.moveInProgress,'A move is already in progress');
            end
            
            nMotors = numel(obj.hMotors);
            activeMotorMask = false(1,nMotors);
            
            for idx = 1:nMotors
                hMotor = obj.hMotors{idx};
                
                motorDimMap_ = obj.motorDimMap{idx};
                axesMask = ~isnan(motorDimMap_);
                dimIdxs = motorDimMap_(axesMask);
                
                pos = nan(1,numel(motorDimMap_));
                
                pos(axesMask) = axesXYZ(dimIdxs);
                
                if any(~isnan(pos))
                    activeMotorMask(idx) = true;
                    try
                        hMotor.moveAsync(pos);
                    catch ME
                        most.ErrorHandler.logAndReportError(ME,sprintf('Motor %s threw an error when attempting to move.',hMotor.name));
                    end
                end
            end
            
            if ~async
                activeMotors = obj.hMotors(activeMotorMask);
                for idx = 1:numel(activeMotors)
                    try
                        activeMotors{idx}.moveWaitForFinish(obj.moveTimeout_s);
                    catch ME
                        most.ErrorHandler.logAndReportError(ME,sprintf('Motor %s threw an error when attempting to wait for move to finish.',activeMotors{idx}.name));
                    end
                end
                
                autoUpdate = all(cellfun(@(hM)hM.autoPositionUpdate,obj.hMotors));
                if ~autoUpdate
                    obj.queryPosition();
                end
            end
        end
    end
    
    %% Alignment methods
    methods
        function abortCalibration(obj)
            obj.resetCalibrationPoints();
            
            if obj.hSI.hMotionManager.enable
                obj.hSI.hMotionManager.enable = false;
            end
        end
        
        function resetCalibrationPoints(obj)
            obj.calibrationPoints = cell(0,2);
        end
        
        function addCalibrationPoint(obj,motorPosition, motion)
            obj.queryPosition();
            
            motorPt = scanimage.mroi.coordinates.Points(obj.hCSAxesPosition,[0 0 0]);
            motorPt = motorPt.transform(obj.hCSAlignment);
            motorPt = motorPt.points;
            
            if nargin < 3 || isempty(motion)
                assert(strcmpi(obj.hSI.acqState,'focus'),'Motor alignment is only available during active Focus');
                
                if ~obj.hSI.hMotionManager.enable                    
                    obj.hSI.hMotionManager.activateMotionCorrectionSimple();
                end
                
                assert(~isempty(obj.hSI.hMotionManager.motionHistory),'Motion History is empty.');
                motion = obj.hSI.hMotionManager.motionHistory(end).drRef(1:2);
                motion = scanimage.mroi.coordinates.Points(obj.hSI.hCoordinateSystems.hCSReference,[motion 0]);
                motion = motion.transform(obj.hCSMicron.hParent);
                motion = motion.points(1:2);
            end
            
            obj.calibrationPoints(end+1,:) = {motorPt, motion};
            
            pts = vertcat(obj.calibrationPoints{:,1});
            d = max(pts(:,3:end),[],1)-min(pts(:,3:end),[],1);
            
            if any(d > 1)
                warning('Motor alignment points are taken at different z depths. For best results, do not move the z stage during motor calibration');
            end
        end
        
        function createCalibrationMatrix(obj)
            assert(size(obj.calibrationPoints,1)>=3,'At least three calibration Points are needed to perform the calibration');
            
            motorPoints = vertcat(obj.calibrationPoints{:,1});
            if size(motorPoints,2) >= 3
                assert(all(abs(motorPoints(:,3)-motorPoints(1,3)) < 1),'All calibration points need to be taken on the same z plane and at the same rotation');
            end
            
            motorPoints = motorPoints(:,1:2);
            
            motionPoints = obj.calibrationPoints(:,2);
            motionPoints = vertcat(motionPoints{:});
            
            motorPoints(:,3) = 1;
            motionPoints(:,3) = 1;
            
            % motor to ref space alignment
            T = motionPoints' * pinv(motorPoints');
            T([3,6,7,8]) = 0;
            T(9) = 1;
            
            % T  = scanimage.mroi.util.affine2Dto3D(T);
            % obj.hCSAlignment.toParentAffine = T;
            
            % extract um to deg conversion factors
            
            % how does a unit vector in reference space
            % change length when transformed into motor space?
            
            xV_deg = [1 0 1]';
            yV_deg = [0 1 1]';
            
            xV_um = T \ xV_deg;
            yV_um = T \ yV_deg;
            
            xScaleFactor = norm(xV_um(1:2));
            yScaleFactor = norm(yV_um(1:2));
            
            % matrix for converting microns to deg
            Ts = eye(3);
            Ts([1,5]) = [1/xScaleFactor, 1/yScaleFactor];
            
            % correct T accordingly
            T = Ts \ T;
            
            % sanity check 
            T  = scanimage.mroi.util.affine2Dto3D(T);
            Ts = scanimage.mroi.util.affine2Dto3D(Ts);
            
            obj.abortCalibration();
            
            most.ErrorHandler.assert(det(T)~=0,'Alignment matrix is singular. Alignment unsuccessful');
            most.ErrorHandler.assert(det(Ts)~=0,'Alignment matrix is singular. Alignment unsuccessful');
            
            obj.hCSAlignment.toParentAffine = T;
            obj.hCSMicron.toParentAffine = Ts;
            
            obj.hSI.hCoordinateSystems.save();
        end
        
        function resetCalibrationMatrix(obj)
            obj.hCSAlignment.reset();
        end
        
         function correctObjectiveResolution(obj)            
            T = obj.hCSMicron.toParentAffine;
            
            if isequal(T,eye(size(T,1)))
                error('Run the motor alignment first to obtain info about the objective resolution');
            end
            
            x_umPerDeg = 1/T(1);
            y_umPerDeg = 1/T(6);
            
            aspectRatio = x_umPerDeg/y_umPerDeg;
            if aspectRatio < 0.95 || aspectRatio > 1.05
                error('The scan aspect ratio (X/Y) is %.2f\nFix the mirror settings in the machine configuration to achieve a scan with an aspect ration of 1, then rerun the calibration.',aspectRatio);
            end
            
            obj.hSI.objectiveResolution = mean([x_umPerDeg, y_umPerDeg]);
            obj.hSI.saveMdf();
            
            msg = sprintf('New Objective Resolution: %.2f um/deg',obj.hSI.objectiveResolution);
            msgbox(msg, 'Resolution update','help');
        end
    end
    
    %% User defined positions
    methods
        function defineUserPosition(obj,name,posn)
            % defineUserPosition   add current motor position, or specified posn, to
            %   motorUserDefinedPositions array at specified idx
            %
            %   obj.defineUserPosition()          add current position to list of user positions
            %   obj.defineUserPosition(name)      add current position to list of user positions, assign name
            %   obj.defineUserPosition(name,posn) add posn to list of user positions, assign name
            
            if nargin < 2 || isempty(name)
                name = '';
            end
            if nargin < 3 || isempty(posn)
                obj.queryPosition();
                posn = obj.samplePosition;
            end
            obj.userDefinedPositions(end+1) = struct('name',name,'coords',posn);
        end
        
        function clearUserDefinedPositions(obj)
        % clearUserDefinedPositions  Clears all user-defined positions
        %
        %   obj.clearUserDefinedPositions()   returns nothing
        
            obj.userDefinedPositions = repmat(struct('name','','coords',[]),0,1);
        end
        
        function gotoUserDefinedPosition(obj,posn)
            % gotoUserDefinedPosition   move motors to user defined position
            %
            %   obj.gotoUserDefinedPosition(posn)  move motor to posn, where posn is either the name or the index of a position
            
            %Move motor to stored position coordinates
            if ischar(posn)
                posn = ismember(posn, {obj.userDefinedPositions.name});
            end
            assert(posn > 0 && numel(obj.userDefinedPositions) >= posn, 'Invalid position selection.');
            obj.moveSample(obj.userDefinedPositions(posn).coords);
        end
        
        function saveUserDefinedPositions(obj)
            % saveUserDefinedPositions  Save contents of motorUserDefinedPositions array to a position (.POS) file
            %
            %   obj.saveUserDefinedPositions()  opens file dialog and saves user positions to selected file
            
            if obj.componentExecuteFunction('motorSaveUserDefinedPositions')
                [fname, pname]=uiputfile('*.pos', 'Choose position list file'); % TODO starting path
                if ~isnumeric(fname)
                    periods=strfind(fname, '.');
                    if any(periods)
                        fname=fname(1:periods(1)-1);
                    end
                    s.userDefinedPositions = obj.userDefinedPositions; %#ok<STRNU>
                    save(fullfile(pname, [fname '.pos']),'-struct','s','-mat');
                end
            end
        end
        
        function loadUserDefinedPositions(obj)
            % loadUserDefinedPositions  loads contents of a position (.POS) file to the motorUserDefinedPositions array (overwriting any previous contents)
            %
            %   obj.loadUserDefinedPositions()  opens file dialog and loads user positions from selected file
            if obj.componentExecuteFunction('motorLoadUserDefinedPositions')
                [fname, pname]=uigetfile('*.pos', 'Choose position list file');
                if ~isnumeric(fname)
                    periods=strfind(fname,'.');
                    if any(periods)
                        fname=fname(1:periods(1)-1);
                    end
                    s = load(fullfile(pname, [fname '.pos']), '-mat');
                    obj.userDefinedPositions = s.userDefinedPositions;
                end
            end
        end
        
        function setMinZLimit(obj)
            hPt = obj.getPosition(obj.hCSSampleAbsolute);
            obj.hPtMinZLimit = hPt;
        end
        
        function clearMinZLimit(obj)
            obj.hPtMinZLimit = scanimage.mroi.coordinates.Points.empty();
        end
        
        function setMaxZLimit(obj)
            hPt = obj.getPosition(obj.hCSSampleAbsolute);
            obj.hPtMaxZLimit = hPt;
        end
        
        function clearMaxZLimit(obj)
            obj.hPtMaxZLimit = scanimage.mroi.coordinates.Points.empty();
        end
    end
    
    %% Property Getter/Setter
    methods
        function set.userDefinedPositions(obj,val)
            assert(all(isfield(val,{'name' 'coords'})), 'Invalid setting for userDefinedPositions');
            obj.userDefinedPositions = val;
        end
        
        function val = get.isAligned(obj)
            tPA = obj.hCSAlignment.toParentAffine;
            fPA = obj.hCSAlignment.fromParentAffine;
            
            val = ~isIdentity(tPA) || ~isIdentity(fPA);
            
            function tf = isIdentity(T)
                I = eye(size(T,1),class(T));
                tf = isequal(I,T);
            end
        end
        
        function val = get.isRelativeZeroSet(obj)
            isIdentity = isequal(obj.hCSSampleRelative.toParentAffine,eye(4));
            val = ~isIdentity;
        end
        
        function set.isRelativeZeroSet(obj,val)
            % No op, used for ui update
        end
        
        function val = get.samplePosition(obj)
            % return the objective's primary focus point in relative stage coordinates            
            hPt = obj.getPosition(obj.hCSSampleRelative);
            val = hPt.points;
        end
        
        function set.samplePosition(obj,val)
            if ~obj.mdlInitialized
                return
            end
            
            if ~all(isnan(val))
                error('Setting the sample position is not allowed. Use hSI.hMotors.moveSample([x,y,z]) instead.');
            end
        end
        
        function val = get.moveInProgress(obj)
            if isempty(obj.hMotors)
                val = false;
            else
                val = false(1,numel(obj.hMotors));
                for idx = 1:numel(obj.hMotors)
                    try
                        val(idx) = obj.hMotors{idx}.isMoving;
                    catch ME
                        most.ErrorHandler.logAndReportError(ME,sprintf('Motor %s threw an error when attempting to retrieve property moveInProgress.',obj.hMotors{idx}.name));
                    end
                end
                val = any(val);
            end
        end
        
        function set.moveInProgress(obj,val)
            % No-op, used for UI update only
        end
        
        function val = get.axesPosition(obj)
            val = obj.hCSAxesPosition.fromParentAffine(13:15);
        end
        
        function set.axesPosition(obj,val)
            % No-op, used for UI update only
        end
        
        function val = get.motorErrorMsg(obj)
            nMotors = numel(obj.hMotors);
            val = cell(1,nMotors);
            for idx = 1:nMotors
                try
                    val{idx} = obj.hMotors{idx}.errorMsg;
                catch ME
                    val{idx} = sprintf('Motor %s threw an error when attempting to read motor''s error status.',obj.hMotors{idx}.name);
                    most.ErrorHandler.logAndReportError(ME,val{idx});
                end
            end
        end
        
        function set.isHomed(obj,val)
            % No-op, for UI update only
        end
        
        function val = get.isHomed(obj)
            val = false(1,numel(obj.hMotors));
            
            for idx = 1:numel(obj.hMotors)
                val(idx) = obj.hMotors{idx}.isHomed;
            end
        end
        
        function set.motorErrorMsg(obj,val)
            % No-op, used for UI update only
            obj.errorTf = NaN;
        end
        
        function val = get.errorTf(obj)
            val = any(cellfun(@(e)~isempty(e),obj.motorErrorMsg));
        end
        
        function set.errorTf(obj,val)
            % No-op used for UI update only
        end
        
        function set.hErrorCallBack(obj,val)
            if isempty(val)
                val = function_handle.empty(0,1);
            else
                validateattributes(val,{'function_handle'},{'scalar'});
            end
            
            obj.hErrorCallBack = val;
        end
        
        function set.azimuth(obj,val)
            if isnan(val)
                return % used for UI update
            end
            
            val = obj.validatePropArg('azimuth',val);
            
            % rotation around z axis => yaw
            [yaw,pitch,roll] = obj.getRotationAngles();
            yaw = val * pi/180;
            obj.setRotationAngles(yaw,pitch,roll);
        end
        
        function val = get.azimuth(obj)
            [yaw,pitch,roll] = obj.getRotationAngles();
            val = yaw * 180/pi;
        end
        
        function set.elevation(obj,val)
            if isnan(val)
                return % used for UI update
            end
            
            val = obj.validatePropArg('elevation',val);
            
            % rotation around y axis => pitch
            [yaw,pitch,roll] = obj.getRotationAngles();
            pitch = val * pi/180;
            obj.setRotationAngles(yaw,pitch,roll);
        end
        
        function val = get.elevation(obj)
            [yaw,pitch,roll] = obj.getRotationAngles();
            val = pitch * 180/pi;
        end
        
        function set.backlashCompensation(obj,val)
            if isempty(val)
                val = zeros(1,3);
            end
                
            if isscalar(val)
                val = repmat(val,1,3);
            end
            
            val = obj.validatePropArg('backlashCompensation',val);
            
            obj.backlashCompensation = val(:)';
        end
        
        function set.hPtMinZLimit(obj,val)
            if isempty(val)
                val = scanimage.mroi.coordinates.Points.empty();
            else
                validateattributes(val,{'scanimage.mroi.coordinates.Points'},{'scalar'});
                validateattributes(val.points,{'numeric'},{'size',[1 3],'nonnan','finite'});
            end
            
            obj.hPtMinZLimit = val;
            obj.checkLimits();
        end
        
        function set.hPtMaxZLimit(obj,val)
            if isempty(val)
                val = scanimage.mroi.coordinates.Points.empty();
            else
                validateattributes(val,{'scanimage.mroi.coordinates.Points'},{'scalar'});
                validateattributes(val.points,{'numeric'},{'size',[1 3],'nonnan','finite','real'});
            end
            
            obj.hPtMaxZLimit = val;
            obj.checkLimits();
        end
        
        function set.maxZStep(obj,val)
            if isempty(val)
                val = inf;
            else
                validateattributes(val,{'numeric'},{'scalar','positive','nonnan','real'});
            end
            
            obj.maxZStep = val;
            obj.checkLimits();
        end
        
        function set.hMotorXYZ(obj,val)
            validateattributes(val,{'cell'},{'size',[1,3]});
            
            for idx = 1:numel(val)
                val{idx} = obj.hResourceStore.filterByName(val{idx});
                
                if ~most.idioms.isValidObj(val{idx})
                    val{idx} = obj.hSimulatedMotor;
                end
            end
            
            oldVal = obj.hMotorXYZ;
            obj.hMotorXYZ = val;
            
            if ~isequal(oldVal,obj.hMotorXYZ)
                obj.deinit();
            end
        end
        
        function val = get.hMotorXYZ(obj)
            val = obj.hMotorXYZ;
            
            for idx = 1:numel(val)
                if ~most.idioms.isValidObj(val{idx})
                    val{idx} = obj.hSimulatedMotor;
                end
            end
        end
        
        function set.motorAxisXYZ(obj,val)
            validateattributes(val,{'numeric'},{'positive','integer','size',[1,3]});
            
            for idx = 1:numel(val)
                val(idx) = min(val(idx),obj.hMotorXYZ{idx}.numAxes);
            end
            
            oldVal = obj.motorAxisXYZ;
            obj.motorAxisXYZ = val;
            
            if ~isequal(oldVal,obj.motorAxisXYZ)
                obj.deinit();
            end
        end
        
        function val = get.motorAxisXYZ(obj)
            val = obj.motorAxisXYZ;
            for idx = 1:numel(val)
                if isa(obj.hMotorXYZ{idx},'dabs.simulated.Motor')
                    val(idx) = idx;
                end
            end
        end
        
        function set.scaleXYZ(obj,val)
            if isempty(val)
                val = [1 1 1];
            end
                
            if isscalar(val)
                val = repmat(val,1,3);
            end
            
            validateattributes(val,{'numeric'},{'finite','nonnan','real','size',[1,3]});
            assert(~any(val==0),'Scale cannot be zero');
            obj.scaleXYZ = val;
            
            obj.updateScaling();
        end
        
        function val = get.motorAxes(obj)
            val = struct('hMotor',{},'axis',{});
            
            for axIdx = 1:3
                for motorIdx = 1:numel(obj.hMotors)
                    hMotor = obj.hMotors{motorIdx};
                    dimMap = obj.motorDimMap{motorIdx};
                    
                    ax = find(dimMap==axIdx,1,'first');
                    
                    if ~isempty(ax)
                        val(axIdx).hMotor = hMotor;
                        val(axIdx).axis = ax;
                    end
                end
            end
        end
    end
end

%% LOCAL
function s = initPropAttributes()
s = struct();
s.backlashCompensation = struct('Classes','numeric','Attributes',{{'numel',3,'finite','nonnan','real'}});
s.azimuth = struct('Classes','numeric','Attributes',{{'scalar','finite','nonnan','real'}});
s.elevation = struct('Classes','numeric','Attributes',{{'scalar','>=',-90,'<=',90,'finite','nonnan','real'}});
end

function s = defaultMdfSection()
    s = [...
        most.HasMachineDataFile.makeEntry('SI Stage/Motor Component.')... % comment only
        most.HasMachineDataFile.makeEntry('motorXYZ',{{'','',''}},'Defines the motor for ScanImage axes X Y Z.')...
        most.HasMachineDataFile.makeEntry('motorAxisXYZ',[1 2 3],'Defines the motor axis used for Scanimage axes X Y Z.')...
        most.HasMachineDataFile.makeEntry('scaleXYZ',[1 1 1],'Defines scaling factors for axes.')...
        most.HasMachineDataFile.makeEntry('backlashCompensation',[0 0 0],'Backlash compensation in um (positive or negative)')...
        most.HasMachineDataFile.makeEntry('moveTimeout_s',10,'Move timeout in seconds')...
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
