classdef LinearScanner < dabs.resources.Device
    properties
        hAOControl  = dabs.resources.ios.AO.empty(1,0);
        hAOOffset   = dabs.resources.ios.AO.empty(1,0);
        hAIFeedback = dabs.resources.ios.AI.empty(1,0);
    end
    
    properties (SetAccess = protected, SetObservable)
        units = ''; % unit description
    end
    
    properties (SetAccess = private, Dependent)
        isPXI
        isvDAQ
        simulated
    end
    
    properties (SetAccess = private, GetAccess = private)
        hAOControlListener = event.listener.empty(0,1);
    end
    
    methods
        function obj = LinearScanner(name)
            obj@dabs.resources.Device(name);
            obj.deinit();
            obj.reinit();
        end
        
        function delete(obj)
            try
                obj.forceUnreserve();
                
                try
                    if obj.zeroPositionOnDelete
                        obj.pointPosition_V(0);
                    end
                end
                
                obj.deinit();
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
        end
    end
    
    methods
        function reinit(obj)
            try
                obj.deinit();
                obj.errorMsg = '';
                
                assert(most.idioms.isValidObj(obj.hAOControl),'No analog output for scanner control specified');
                
                obj.hAOControl.reserve(obj);
                obj.hAOControl.slewRateLimit_V_per_s = obj.slewRateLimit_V_per_s;
                obj.validateSlewRateLimit();
                
                if most.idioms.isValidObj(obj.hAIFeedback)
                    obj.hAIFeedback.termCfg = obj.feedbackTermCfg;
                end
                
                if most.idioms.isValidObj(obj.hAOOffset)
                    obj.hAOOffset.reserve(obj);
                end
                
                obj.hAOControlListener = most.ErrorHandler.addCatchingListener(obj.hAOControl,'lastKnownValueChanged',@(varargin)updateLastKnownPositionOutput_V);
                updateLastKnownPositionOutput_V();
                
                obj.readPositionOutput();
                
            catch ME
                obj.deinit();
                obj.errorMsg = sprintf('%s: initialization error: %s',obj.name,ME.message);
                most.ErrorHandler.logError(ME,obj.errorMsg);
            end
            
            %%% Nested function
            function updateLastKnownPositionOutput_V()
                obj.lastKnownPositionOutput = NaN; % for UI update
            end
        end
        
        function deinit(obj)
            obj.errorMsg = 'Uninitialized';
            
            try
                if most.idioms.isValidObj(obj.hAOControl)
                    obj.hAOControl.unreserve(obj);
                    obj.hAOControl.slewRateLimit_V_per_s = Inf;
                end
                
                delete(obj.hAOControlListener);
                obj.hAOControlListener = event.listener.empty(0,1);
                
                if most.idioms.isValidObj(obj.hAIFeedback)
                    obj.hAIFeedback.unreserve(obj);
                    obj.hAIFeedback.termCfg = 'Default';
                end
                
                if most.idioms.isValidObj(obj.hAOOffset)
                    obj.hAOOffset.unreserve(obj);
                end
                
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
        end
    end
    
    methods        
        function set.hAOControl(obj,val)
            val = obj.hResourceStore.filterByName(val);
            
            if ~isequal(val,obj.hAOControl)
                if most.idioms.isValidObj(val)
                    validateattributes(val,{'dabs.resources.ios.AO'},{'scalar'});
                end
                
                obj.deinit();
                obj.hAOControl.unregisterUser(obj);
                obj.hAOControl = val;
                obj.hAOControl.registerUser(obj,'Control');
            end
        end
        
        function set.hAOOffset(obj,val)
            val = obj.hResourceStore.filterByName(val);
            
            if ~isequal(val,obj.hAOOffset)
                if most.idioms.isValidObj(val)
                    validateattributes(val,{'dabs.resources.ios.AO'},{'scalar'});
                end
                
                obj.deinit();
                obj.hAOOffset.unregisterUser(obj);
                obj.hAOOffset = val;
                obj.hAOOffset.registerUser(obj,'Offset');
            end
        end
        
        function set.hAIFeedback(obj,val)
            val = obj.hResourceStore.filterByName(val);
            
            if ~isequal(val,obj.hAIFeedback)
                if most.idioms.isValidObj(val)
                    validateattributes(val,{'dabs.resources.ios.AI'},{'scalar'});
                end
                
                obj.deinit();
                obj.hAIFeedback.unregisterUser(obj);
                obj.hAIFeedback = val;
                obj.hAIFeedback.registerUser(obj,'Feedback');
            end
        end
    end

    %%% copied from dabs.interfaces.LinearScanner
    properties (SetObservable)
        travelRange;
        parkPosition = -9;
        daqOutputRange;
        
        positionLUT = zeros(0,2);
        feedbackVoltLUT = zeros(0,2); % translates feedback Volts into position Volts
    end
    
    properties        
        feedbackTermCfg = '';
        voltsPerDistance = 0.5;
        distanceVoltsOffset = 0;
        
        positionMaxSampleRate = [];
        
        offsetVoltScaling = NaN;
        
        slewRateLimit_V_per_s = Inf;
        zeroPositionOnDelete = false;
        calibrationData;
    end
    
    properties (SetObservable, AbortSet)
        targetPosition              = 0;    % updated by function point
        lastKnownPositionOutput     = NaN;  % updated by function readPositionOutput
        lastKnownPositionFeedback   = NaN;  % updated by function readPositionFeedback
        lastKnownPositionFeedback_V = NaN;  % updated by function readPositionFeedback
    end
    
    properties (SetObservable, AbortSet)
        lastKnownPositionOutput_V   = NaN;  % this is updated by LinScan
    end
    
    properties (Hidden, SetAccess = private)        
        parkPositionVolts;
    end
    
    properties (Hidden)
        numSmoothTransitionPoints = 100;
    end
    
    properties (Dependent)
        positionAvailable;
        feedbackAvailable;
        offsetAvailable;
        offsetSecondaryTask;
        feedbackCalibrated;
        offsetCalibrated;
    end

    
    %% Setter / Getter methods
    methods
        function val = get.isPXI(obj)
            hDAQ = obj.hAOControl.hDAQ;
            val = isa(hDAQ,'dabs.resources.daqs.NIDAQ') && ~isnan(hDAQ.pxiNumber);
        end
        
        function val = get.isvDAQ(obj)
            val = isa(obj.hAOControl.hDAQ,'dabs.resources.daqs.vDAQ');
        end
        
        function val = get.simulated(obj)
            val = obj.hAOControl.hDAQ.simulated;
        end
        
        function set.travelRange(obj,val)
            validateattributes(val,{'numeric'},{'finite','size',[1,2]});
            val = sort(val);
            obj.travelRange = val; 
        end
        
        function val = get.daqOutputRange(obj)
            val = obj.hAOControl.outputRange_V;
        end
        
        function val = get.positionMaxSampleRate(obj)
            val = obj.hAOControl.maxSampleRate_Hz;
        end
        
        function v = get.travelRange(obj)
            if isempty(obj.travelRange)
                if obj.positionAvailable
                    v = obj.volts2Position(obj.daqOutputRange);
                    v = sort(v);
                else
                    v = [-10 10]; %default
                end
            else
                v = obj.travelRange;
            end
        end
        
        function set.voltsPerDistance(obj,val)
            validateattributes(val,{'numeric'},{'finite','scalar','nonnan','real'});
            obj.voltsPerDistance = val;
        end
        
        function set.positionLUT(obj,val)
            if isempty(val)
                val = zeros(0,2);
            end
            
            val = validateLUT(val);
            obj.positionLUT = val;
        end
        
        function set.feedbackVoltLUT(obj,val)
            if isempty(val)
                val = zeros(0,2);
            end
            
            val = validateLUT(val);
            obj.feedbackVoltLUT = val;
        end
        
        function set.distanceVoltsOffset(obj,val)
            validateattributes(val,{'numeric'},{'finite','scalar','nonnan','real'});
            obj.distanceVoltsOffset = val;
        end
        
        function set.parkPosition(obj,val)
            validateattributes(val,{'numeric'},{'finite','scalar','nonnan','real'});
            obj.parkPosition = val;
        end
        
        function val = get.parkPosition(obj)
            val = max(min(obj.parkPosition,obj.travelRange(2)),obj.travelRange(1));
        end
        
        function set.offsetVoltScaling(obj,val)
            validateattributes(val,{'numeric'},{'finite','scalar','nonnan','real'});
            obj.offsetVoltScaling = val;
        end
        
        function set.numSmoothTransitionPoints(obj,val)
            validateattributes(val,{'numeric'},{'scalar','integer','nonnan','finite','positive'});
            obj.numSmoothTransitionPoints = val;
        end
        
        function set.feedbackTermCfg(obj,val)
            if isempty(val)
                val = '';
            else
                assert(ismember(val,{'Differential','RSE','NRSE'}),'Invalid terminal configuration ''%s''.',val);
            end
            
            obj.feedbackTermCfg = val;
            
            if most.idioms.isValidObj(obj.hAIFeedback)
                obj.hAIFeedback.termCfg = val;
            end
        end
        
        function val = get.positionAvailable(obj)
            val = isempty(obj.errorMsg) && most.idioms.isValidObj(obj.hAOControl);
        end
        
        function val = get.feedbackAvailable(obj)
            val = isempty(obj.errorMsg) && most.idioms.isValidObj(obj.hAIFeedback);
        end
        
        function val = get.offsetSecondaryTask(obj)
            val = isempty(obj.errorMsg) && most.idioms.isValidObj(obj.hAOOffset);
        end
        
        function val = get.offsetAvailable(obj)
            val = obj.offsetSecondaryTask || (obj.positionAvailable && obj.hAOControl.supportsOffset);
        end
        
        function val = get.feedbackCalibrated(obj)
            val = ~isempty(obj.feedbackVoltLUT);
        end
        
        function val = get.offsetCalibrated(obj)
            if obj.offsetSecondaryTask
                val = ~isempty(obj.offsetVoltScaling) && ~isnan(obj.offsetVoltScaling);
            else
                val = obj.offsetAvailable;
            end
        end
        
        function v = get.parkPositionVolts(obj)
            v = obj.position2Volts(obj.parkPosition);
        end
        
        function set.lastKnownPositionFeedback_V(obj,v)
            obj.lastKnownPositionFeedback_V = v; 
            obj.lastKnownPositionFeedback = NaN; % for UI update
        end
        
        function v = get.lastKnownPositionFeedback(obj)
            v = obj.feedbackVolts2Position(obj.lastKnownPositionFeedback_V);
        end
        
        function set.lastKnownPositionOutput_V(obj,val)
            if ~isnan(val)
                obj.hAOControl.lastKnownValue = val;
            end
        end
        
        function val = get.lastKnownPositionOutput_V(obj)
            val = obj.hAOControl.lastKnownValue;
        end
        
        function v = get.lastKnownPositionOutput(obj)
            if most.idioms.isValidObj(obj.hAOControl)
                v = obj.volts2Position(obj.hAOControl.lastKnownValue);
            else
                v = 0;
            end
        end
        
        function set.slewRateLimit_V_per_s(obj,v)
            validateattributes(v,{'numeric'},{'scalar','nonnan','positive'});
            
            obj.slewRateLimit_V_per_s = v;
            
            if obj.positionAvailable && obj.hAOControl.supportsSlewRateLimit
                obj.hAOControl.slewRateLimit_V_per_s = v;
            end
            
            obj.validateSlewRateLimit();
        end
        
        function validateSlewRateLimit(obj)
            if ~isinf(obj.slewRateLimit_V_per_s)
                if obj.positionAvailable && ~obj.hAOControl.supportsSlewRateLimit
                    try
                        error('%s: slew rate limit for position task is set to %fV/s, but device does not support slew rate limiting.',obj.name,obj.slewRateLimit_V_per_s);
                    catch ME
                        most.ErrorHandler.logError(ME);
                    end
                end
            end
        end
    end
    
    %% Public methods
    methods        
        function val = volts2Position(obj,val)
            val = (val - obj.distanceVoltsOffset) ./ obj.voltsPerDistance;
            val = obj.lookUpPosition(val,true);
        end
        
        function val = position2Volts(obj,val)
            val = obj.lookUpPosition(val);
            val = val .* obj.voltsPerDistance + obj.distanceVoltsOffset;
        end
        
        function val = feedbackVolts2PositionVolts(obj,val)
            if ~isempty(obj.feedbackVoltLUT)
                lut = obj.feedbackVoltLUT;
                val = interp1Flex(lut(:,1),lut(:,2),val,'linear','extrap');
            else
                val = nan(size(val));
            end
        end
        
        function val = feedbackVolts2Position(obj,val)
            val = obj.feedbackVolts2PositionVolts(val);
            val = obj.volts2Position(val);
        end
        
        function val = position2OffsetVolts(obj,val)
            val = obj.position2Volts(val);
            val = val.* obj.offsetVoltScaling;
        end
        
        function val = lookUpPosition(obj,val,reverse)
            if nargin < 3 || isempty(reverse)
                reverse = false;
            end
            
            x = obj.positionLUT(:,1);
            v = obj.positionLUT(:,2);
            
            if reverse
                [x,v] = deal(v,x);
            end
            
            val = interp1Flex(x,v,val,'linear','extrap');
        end
        
        function plotPositionLUT(obj)
            dabs.resources.devices.private.LinearScannerCalibrator(obj);
        end
        
        function park(obj)
            obj.pointPosition(obj.parkPosition);
        end
        
        function center(obj)
            obj.pointPosition(sum(obj.travelRange)./2);
        end
        
        function pointPosition(obj,position)
            extendedTravelRange = obj.travelRange + [-0.01 0.01] * diff(obj.travelRange);
            validateattributes(position,{'numeric'},{'scalar','finite','nonnan'});
            assert(position>=extendedTravelRange(1) && position<=extendedTravelRange(2),'%s: Position %f is outside the allowed travel range [%f %f].',obj.name,position,obj.travelRange(1),obj.travelRange(2));
            voltage = obj.position2Volts(position);
            obj.pointPosition_V(voltage);
            obj.targetPosition = position;
        end
        
        function pointPosition_V(obj,voltage)
            assert(isempty(obj.errorMsg));
            assert(obj.positionAvailable,'%s: Position output not initialized', obj.name);
            
            obj.smoothTransitionVolts(voltage);
            
            if obj.offsetAvailable
                obj.pointOffsetPosition(0);
            end
        end
        
        function pointOffsetPosition(obj,position)
            assert(obj.offsetAvailable,'%s: Offset output not initialized', obj.name);
            if obj.offsetSecondaryTask
                volt = obj.position2OffsetVolts(position);
                obj.hAOOffset.setValue(volt);
            else
                volt = obj.position2Volts(position);
                obj.hAOControl.setOffset(volt);
            end
        end
        
        function [voltMean, voltSamples] = readPositionFeedback_V(obj,n)
            if nargin < 2 || isempty(n)
                n = 100;
            end
            
            voltMean = NaN;
            voltSamples = nan(n,1);
            
            if obj.feedbackAvailable && obj.feedbackCalibrated
                voltSamples = obj.readNFeedbackValues(n);
                voltMean = mean(voltSamples);
            end
            
            obj.lastKnownPositionFeedback_V = voltMean;
        end
         
        function [positionMean, positionSamples] = readPositionFeedback(obj,n)
            if nargin < 2 || isempty(n)
                n = 100;
            end
            
            [voltMean, voltSamples] = obj.readPositionFeedback_V(n);
            
            positionSamples = obj.feedbackVolts2Position(voltSamples);
            positionMean = mean(positionSamples);
        end
        
        % this function is only used for NI boards that don't support output readback
        % after a task finishes, we can set the last known output here
        function defineLastKnownPositionOutput(obj,v)
            if most.idioms.isValidObj(obj.hAOControl)
                obj.hAOControl.lastKnownValue = v;
            end
        end
        
        function volts = readPositionOutput_V(obj)
            volts = obj.hAOControl.queryValue();
            if isnan(volts)
                volts = obj.hAOControl.lastKnownValue;
            end
            
            obj.lastKnownPositionOutput_V = volts;
        end
        
        function v = readPositionOutput(obj)
            v = obj.readPositionOutput_V();
            v = obj.volts2Position(v);
        end
        
        function tf = isMoving(obj)
            if obj.feedbackAvailable && obj.feedbackCalibrated
                numReadings = 300;
                samples = obj.readNFeedbackValues(numReadings);
                
                std_data = std(samples);
                
                if std_data > 1e-9
                    tf = std_data > 3*std(detrend(samples));
                else
                    % guard against rounding errors
                    tf = false;
                end
            else
                tf = false;
            end
        end
        
        function elapsedTime_s = waitMoveComplete(obj,timeout_s)
            if nargin < 2 || isempty(timeout_s)
                timeout_s = 1;
            end
            
            s = tic();
            
            isMoving_ = true;
            while toc(s)<=timeout_s && isMoving_
                isMoving_ = obj.isMoving();
                pause(0.01);
            end
            
            elapsedTime_s = toc(s);
            
            assert(~isMoving_,'%s: move wait complete timed out after %fs',elapsedTime_s);
        end
        
        function v = readNFeedbackValues(obj,N)
            if nargin<2 || isempty(N)
                N = 1;
            end
            
            assert(most.idioms.isValidObj(obj.hAIFeedback),'Feedback is not configured');
            
            needsReservation = ~isa(obj.hAIFeedback.hDAQ,'dabs.resources.daqs.vDAQ');
            if needsReservation
                obj.hAIFeedback.reserve(obj);
            end
            
            try
                v = obj.hAIFeedback.readValue(N);
                cleanup();
            catch ME
                cleanup();
                ME.rethrow();
            end
            
            function cleanup()
                if needsReservation
                    obj.hAIFeedback.unreserve(obj);
                end
            end
        end
        
        function calibrate(obj,hWb)
            if nargin<2 || isempty(hWb)
                msg = sprintf('%s: Calibrating feedback',obj.name);
                hWb = waitbar(0,msg);
                deleteWaitbar = true;
            else
                deleteWaitbar = false;
            end
            
            try
                if obj.positionAvailable && obj.feedbackAvailable
                    fprintf('%s: calibrating feedback',obj.name);
                    obj.calibrateFeedback(true,hWb);
                    if obj.offsetSecondaryTask
                        fprintf(', offset');
                        obj.calibrateOffset(true,hWb);
                    end
                    fprintf(' ...done!\n');
                else
                    error('%s: feedback not configured - nothing to calibrate\n',obj.name);
                end
            catch ME
                cleanup();
                rethrow(ME);
            end
            cleanup();
            
            function cleanup()
                if deleteWaitbar
                    most.idioms.safeDeleteObj(hWb);
                end
            end
        end
        
        function calibrateFeedback(obj,preventTrip,hWb)
            if nargin < 2 || isempty(preventTrip)
                preventTrip = true;
            end
            
            if nargin < 3 || isempty(hWb)
                hWb = [];
            end
            
            if ~isempty(hWb)
                if ~isvalid(hWb)
                    return
                else
                    msg = sprintf('%s: calibrating feedback',obj.name);
                    waitbar(0,hWb,msg);
                end
            end
            
            assert(obj.positionAvailable,'Position output not initialized');
            assert(obj.feedbackAvailable,'Feedback input not initialized');
            
            if obj.offsetAvailable
                obj.pointOffsetPosition(0);
            end
            
            numTestPoints = 10;
            rangeFraction = 1;
            
            travelRangeMidPoint = sum(obj.travelRange)/2;
            travelRangeCompressed = diff(obj.travelRange)*rangeFraction;
            
            outputPositions = linspace(travelRangeMidPoint-travelRangeCompressed/2,travelRangeMidPoint+travelRangeCompressed/2,numTestPoints)';
            
            % move to first position
            obj.smoothTransitionPosition(outputPositions(1));
            if preventTrip && ~obj.hAOControl.supportsOutputReadback
                pause(3); % we assume we were at the park position initially, but we cannot know for sure. If galvo trips, wait to make sure they recover
            else
                pause(0.5);
            end
            
            feedbackVolts = zeros(length(outputPositions),1);
            
            cancelled = false;
            for idx = 1:length(outputPositions)
                if idx > 1
                    obj.smoothTransitionPosition(outputPositions(idx));
                    pause(0.5); %settle
                end
                averageNSamples = 100;
                samples = obj.readNFeedbackValues(averageNSamples);
                feedbackVolts(idx) = mean(samples);
                
                if ~isempty(hWb)
                    if ~isvalid(hWb)
                        cancelled = true;
                        break
                    else
                        waitbar(idx/length(outputPositions),hWb,msg);
                    end
                end
            end
            
            % park the galvo
            obj.smoothTransitionPosition(obj.parkPosition);
            
            if cancelled
                return
            end
            
            outputVolts = obj.position2Volts(outputPositions);

            
            [feedbackVolts_lut,sortIdx] = sort(feedbackVolts);
            outputVolts_lut = outputVolts(sortIdx);
            
            lut = [feedbackVolts_lut,outputVolts_lut];
            try
                validateLUT(lut);
                obj.feedbackVoltLUT = lut;
                plotCalibrationCurve();
            catch ME
                plotCalibrationCurveUnsuccessful();
                rethrow(ME);
            end
                
            %%% local functions
            function plotCalibrationCurve()
                hFig = most.idioms.figure('NumberTitle','off','Name','Scanner Calibration');
                hAx = most.idioms.axes('Parent',hFig,'box','on');
                plot(hAx,outputVolts,feedbackVolts,'o-');
                title(hAx,sprintf('%s Feedback calibration',obj.name));
                xlabel(hAx,'Position Output [Volt]');
                ylabel(hAx,'Position Feedback [Volt]');
                grid(hAx,'on');
                drawnow();
            end
            
            function plotCalibrationCurveUnsuccessful()
                hFig = most.idioms.figure('NumberTitle','off','Name','Scanner Calibration');
                hAx = most.idioms.axes('Parent',hFig,'box','on');
                plot(hAx,[outputVolts,feedbackVolts],'o-');
                legend(hAx,'Command Voltage','Feedback Voltage');
                title(hAx,sprintf('%s Feedback calibration\nunsuccessful',obj.name));
                xlabel(hAx,'Position Output [Volt]');
                ylabel(hAx,'Position Feedback [Volt]');
                grid(hAx,'on');
                drawnow();
            end
        end
        
        function calibrateOffset(obj,preventTrip,hWb)
            if nargin < 2 || isempty(preventTrip)
                preventTrip = true;
            end
            
            if nargin < 3 || isempty(hWb)
                hWb = [];
            end
            
            assert(obj.positionAvailable,'Position output not initialized');
            assert(obj.feedbackAvailable,'Feedback input not initialized');
            assert(obj.offsetAvailable,'Offset output not initialized');
            
            if ~isempty(hWb)
                if ~isvalid(hWb)
                    return
                else
                    msg = sprintf('%s: calibrating offset',obj.name);
                    waitbar(0,hWb,msg);
                end
            end
            
            % center the galvo
            obj.smoothTransitionPosition(0);
            
            numTestPoints = 10;
            rangeFraction = 0.25;
            
            outputPositions = linspace(obj.travelRange(1),obj.travelRange(2),numTestPoints)';
            outputPositions = outputPositions .* rangeFraction;
            
            % move offset to first position
            obj.pointOffsetPosition(outputPositions(1));
            if preventTrip
                pause(3); % if galvos trip, make sure they recover before continuing
            end
            
            feedbackVolts = zeros(length(outputPositions),1);
            
            cancelled = false;
            for idx = 1:length(outputPositions)
                if idx > 1
                    obj.pointOffsetPosition(outputPositions(idx));
                    pause(0.5); %settle
                end
                averageNSamples = 100;
                samples = obj.readNFeedbackValues(averageNSamples);
                feedbackVolts(idx) = mean(samples);
                
                if ~isempty(hWb)
                    if ~isvalid(hWb)
                        cancelled = true;
                        break
                    else
                        waitbar(idx/length(outputPositions),hWb,msg);
                    end
                end
            end
            
            % park the galvo
            obj.pointOffsetPosition(0);
            obj.park();
            
            if cancelled
                return
            end
            
            outputVolts = obj.position2Volts(outputPositions);
            outputVolts(:,2) = 1;
            
            feedbackVolts = obj.feedbackVolts2PositionVolts(feedbackVolts); % pre-scale the feedback
            feedbackVolts(:,2) = 1;
            
            offsetTransform = outputVolts' * pinv(feedbackVolts'); % solve in the least square sense
            
            offsetVoltOffset = offsetTransform(1,2);
            assert(offsetVoltOffset < 10e-3,'Offset Calibration failed because Zero Position and Zero Offset are misaligned.');  % this should ALWAYS be in the noise floor
            obj.offsetVoltScaling = offsetTransform(1,1);
        end
        
        function feedback = testWaveformVolts(obj,waveformVolts,sampleRate,preventTrip,startVolts,goToPark,hWb)
            assert(obj.positionAvailable,'Position output not initialized');
            assert(obj.feedbackAvailable,'Feedback input not configured');
            assert(obj.feedbackCalibrated,'Feedback input not calibrated');
            
            if nargin < 4 || isempty(preventTrip)
                preventTrip = true;
            end
            
            if nargin < 5 || isempty(startVolts)
                startVolts = waveformVolts(1);
            end
            
            if nargin < 6 || isempty(goToPark)
                goToPark = true;
            end
            
            if nargin < 7 || isempty(hWb)
                hWb = waitbar(0,'Preparing Waveform and DAQs...','CreateCancelBtn',@(src,evt)delete(ancestor(src,'figure')));
                deletewb = true;
            else
                deletewb = false;
            end
            
            try
                if obj.offsetAvailable
                    obj.pointOffsetPosition(0);
                end
                
                %move to first position
                obj.pointPosition_V(startVolts);
                
                if preventTrip && ~obj.hAOControl.supportsOutputReadback
                    pause(2); % if galvos trip, ensure we recover before proceeding
                end
                
                positionTask = dabs.vidrio.ddi.AoTask(obj.hAOControl.hDAQ.hDevice,'Position Task');
                positionTask.addChannel(obj.hAOControl.channelID);
                positionTask.sampleMode = 'finite';
                positionTask.startTrigger = '';
                positionTask.triggerOnStart = true;
                positionTask.allowRetrigger = false;
                positionTask.autoStartStopSyncedTasks = true;
                positionTask.allowEarlyTrigger = false;
                positionTask.sampleRate = sampleRate;
                positionTask.samplesPerTrigger = length(waveformVolts);
                
                obj.hAIFeedback.reserve(obj);
                
                feedbackTask = dabs.vidrio.ddi.AiTask(obj.hAIFeedback.hDAQ.hDevice,'Feedback Task');
                feedbackTask.addChannel(obj.hAIFeedback.channelID,[],obj.hAIFeedback.termCfg);
                feedbackTask.syncTo(positionTask);
                
                positionTask.writeOutputBuffer(waveformVolts(:));
                positionTask.start();
                
                duration = length(waveformVolts)/sampleRate;
                if duration > .4
                    start = tic();
                    while toc(start) < duration
                        pause(0.1);
                        if ~updateCheckWb(hWb, toc(start)./duration, sprintf('%s: executing waveform test...',obj.name))
                            abort();
                            error('Waveform test cancelled by user');
                        end
                    end
                end
                
                if deletewb
                    most.idioms.safeDeleteObj(hWb);
                end
                
                assert(feedbackTask.waitUntilTaskDone(3), 'Failed to read data.');
                feedbackVolts = feedbackTask.readInputBuffer(length(waveformVolts));
                
                abort();
                
                % might not be accurate if process was aborted early!!
                obj.lastKnownPositionOutput_V = waveformVolts(end);
                
                if goToPark
                    % park the galvo
                    obj.pointPosition_V(obj.position2Volts(obj.parkPosition));
                end
                
                % scale the feedback
                feedback = obj.feedbackVolts2PositionVolts(feedbackVolts);
            catch ME
                abort();
                obj.park();
                if deletewb
                    most.idioms.safeDeleteObj(hWb);
                end
                rethrow(ME);
            end
            
            function abort()
                if most.idioms.isValidObj(feedbackTask)
                    feedbackTask.abort();
                    feedbackTask.delete();
                end
                
                if most.idioms.isValidObj(obj.hAIFeedback)
                    obj.hAIFeedback.unreserve(obj);
                end
                
                if most.idioms.isValidObj(positionTask)
                    positionTask.abort();
                    positionTask.delete();
                end
            end
            
            function continuetf = updateCheckWb(wb,prog,msg)
                if isa(wb,'function_handle')
                    continuetf = wb(prog,msg);
                else
                    continuetf = isvalid(hWb);
                    if continuetf
                        waitbar(toc(start)./duration,hWb,sprintf('%s: executing waveform test...',obj.name));
                    end
                end
            end
        end
        
        function smoothTransitionPosition(obj,new)
            obj.smoothTransitionVolts(obj.position2Volts(new));
        end
        
        function smoothTransitionVolts(obj,newV)
            assert(obj.positionAvailable);
            
            if obj.hAOControl.supportsSlewRateLimit
                transition_limit_slew_rate(newV);
            else
                transition_stepwise(newV);
            end
            
            %%% Nested functions
            function transition_limit_slew_rate(newV)
                outputRange = obj.hAOControl.outputRange_V;
                newV = min(max(outputRange(1),newV),outputRange(2));
                
                oldSlewRateLimit_V_per_s = obj.hAOControl.slewRateLimit_V_per_s;
                
                try
                    if isinf(obj.hAOControl.slewRateLimit_V_per_s)
                        obj.hAOControl.slewRateLimit_V_per_s = 1000;
                    end
                    
                    oldV = obj.hAOControl.queryValue();
                    obj.hAOControl.setValue(newV);
                    
                    dV = abs(oldV-newV);
                    t = dV/obj.hAOControl.slewRateLimit_V_per_s;
                    
                    pause(t);
                catch ME
                    obj.hAOControl.slewRateLimit_V_per_s = oldSlewRateLimit_V_per_s;
                    ME.rethrow();
                end
                
                obj.hAOControl.slewRateLimit_V_per_s = oldSlewRateLimit_V_per_s;
            end
            
            function transition_stepwise(newV)
                oldV = obj.hAOControl.queryValue();
                if isnan(oldV)
                    oldV = obj.lastKnownPositionOutput_V;
                end
                
                if isempty(oldV) || isnan(oldV)
                    oldV = obj.parkPositionVolts;
                    most.idioms.warn('Scanner %s attempted a smooth transition, but last position was unknown. Assumed park position.',obj.name);
                end
                
                if oldV==newV
                    numPoints = 1;
                else
                    numPoints = obj.numSmoothTransitionPoints;
                end
                
                sequence = oldV + (newV-oldV) * linspace(0,1,numPoints);
                outputRange = obj.hAOControl.outputRange_V;
                
                for output = sequence
                    output_coerced = min(max(outputRange(1),output),outputRange(2));
                    obj.hAOControl.setValue(output_coerced);
                end
            end
        end
    end

    %% former scanimage.mroi.scanners.LinearScanner    
    properties
        waveformCacheBasePath = '';
        optimizationFcn = @scanimage.mroi.scanners.optimizationFunctions.deconvOptimization;
    end
    
    properties
        hDevice;
        deviceSelfInit = false;
        sampleRateHz = 500e3;
    end
    
    properties (Dependent)
        waveformCacheScannerPath;
    end
    
    %% Setter / Getter methods
    methods
        function val = get.waveformCacheScannerPath(obj)
            if isempty(obj.waveformCacheBasePath) || isempty(obj.name)
                val = [];
            else
                val = fullfile(obj.waveformCacheBasePath, obj.name);
            end
        end
    end
    
    %% Public methods
    methods
        function [path,hash] = computeWaveformCachePath(obj,sampleRateHz,desiredWaveform)
            hash = computeWaveformHash(sampleRateHz,desiredWaveform);
            if isempty(obj.waveformCacheScannerPath)
                path = [];
            else
                path = fullfile(obj.waveformCacheScannerPath,hash);
            end
        end
        
        %%
        % Caches the original waveform, sample rate, optimized waveform and
        % feedback (for error calculation) associated with the original
        % waveform. Original waveform and sample rate are used to create an
        % identifier hash to label the .mat file which stores the
        % associated data.        
        function cacheOptimizedWaveform(obj,sampleRateHz,desiredWaveform,outputWaveform,feedbackWaveform,optimizationData,info)
            if nargin<6 || isempty(optimizationData)
                optimizationData = [];
            end
            
            if nargin<7 || isempty(info)
                info = [];
            end
            
            [workingDirectory,hash] = obj.computeWaveformCachePath(sampleRateHz,desiredWaveform);
            if isempty(workingDirectory)
                warning('Could not cache waveform because waveformCacheBasePath or scanner name is not set');
                return
            end
            
            if ~exist(workingDirectory,'dir')
                [success,message] = mkdir(workingDirectory);
                if ~success
                    warning('Creating a folder to cache the optimized waveform failed:\n%s',message);
                    return
                end
            end
            
            metaDataFileName = 'metaData.mat';
            metaDataFileName = fullfile(workingDirectory,metaDataFileName);
            hMetaDataFile = matfile(metaDataFileName,'Writable',true);
            
            idx = 1;
            metaData = struct();
            if isfield(whos(hMetaDataFile),'metaData')
                metaData = hMetaDataFile.metaData;
                idx = numel(metaData)+1;
            end
            
            uuid = most.util.generateUUID;
            metaData(idx).linearScannerName = obj.name;
            metaData(idx).hash = hash;
            metaData(idx).clock = clock();
            metaData(idx).optimizationFcn = func2str(obj.optimizationFcn);
            metaData(idx).sampleRateHz = sampleRateHz;
            metaData(idx).desiredWaveformFileName  = 'desiredWaveform.mat';
            metaData(idx).outputWaveformFileName   = sprintf('%s_outputWaveform.mat',uuid);
            metaData(idx).feedbackWaveformFileName = sprintf('%s_feedbackWaveform.mat',uuid);
            metaData(idx).optimizationDataFileName = sprintf('%s_optimizationData.mat',uuid);
            metaData(idx).info = info;
            
            desiredWaveformFileName  = fullfile(workingDirectory,metaData(idx).desiredWaveformFileName);
            outputWaveformFileName   = fullfile(workingDirectory,metaData(idx).outputWaveformFileName);
            feedbackWaveformFileName = fullfile(workingDirectory,metaData(idx).feedbackWaveformFileName);
            optimizationDataFileName = fullfile(workingDirectory,metaData(idx).optimizationDataFileName);
            
            if exist(desiredWaveformFileName,'file')
                delete(desiredWaveformFileName);
            end
            if exist(outputWaveformFileName,'file')
                delete(outputWaveformFileName);
            end
            if exist(feedbackWaveformFileName,'file')
                delete(feedbackWaveformFileName);
            end
            if exist(optimizationDataFileName,'file')
                delete(optimizationDataFileName);
            end
            
            hDesiredWaveformFile      = matfile(desiredWaveformFileName, 'Writable',true);
            hOutputWaveformFile       = matfile(outputWaveformFileName,  'Writable',true);
            hFeedbackWaveformFile     = matfile(feedbackWaveformFileName,'Writable',true);
            hOptimizationDataFileName = matfile(optimizationDataFileName,'Writable',true);
            
            hDesiredWaveformFile.sampleRateHz = sampleRateHz;
            hDesiredWaveformFile.volts = desiredWaveform;
            
            hOutputWaveformFile.sampleRateHz = sampleRateHz;
            hOutputWaveformFile.volts = outputWaveform;
            
            hFeedbackWaveformFile.sampleRateHz = sampleRateHz;
            hFeedbackWaveformFile.volts = feedbackWaveform;
            
            hOptimizationDataFileName.data = optimizationData;
            
            hMetaDataFile.metaData = metaData; % update metaData file
        end
        
        % Clears every .mat file in the caching directory indicated by dir
        % or if dir is left empty the default caching directory under
        % [MDF]\..\ConfigData\Waveforms_Cache\LinScanner_#_Galvo\
        function clearCache(obj)
            if isempty(obj.waveformCacheScannerPath)
                warning('Could not clear waveform cache because waveformCacheBasePath or scanner name is not set');
            else
                rmdir(obj.waveformCacheScannerPath,'s');
            end
        end

        % Clears a specific .mat file associated with the provided original
        % waveform and sample rate from the default directory or a specifc
        % caching directory (not yet implememted)
        function clearCachedWaveform(obj,sampleRateHz,originalWaveform)
            [available,metaData] = obj.isCached(sampleRateHz,originalWaveform);
            if available
                workingDirectory = metaData.path;
                
                desiredWaveformFileName  = fullfile(metaData.path,metaData.desiredWaveformFileName);
                outputWaveformFileName   = fullfile(metaData.path,metaData.outputWaveformFileName);
                feedbackWaveformFileName = fullfile(metaData.path,metaData.feedbackWaveformFileName);
                optimizationDataFileName = fullfile(metaData.path,metaData.optimizationDataFileName);
                
                if exist(outputWaveformFileName,'file')
                    delete(outputWaveformFileName)
                end
                
                if exist(feedbackWaveformFileName,'file')
                    delete(feedbackWaveformFileName)
                end
                
                if exist(optimizationDataFileName,'file')
                    delete(optimizationDataFileName)
                end
                
                metaDataFileName = fullfile(workingDirectory,'metaData.mat');
                m = matfile(metaDataFileName,'Writable',true);
                metaData_onDisk = m.metaData;
                metaData_onDisk(metaData.metaDataIdx) = [];
                m.metaData = metaData_onDisk;
                
                if isempty(metaData_onDisk)
                   rmdir(workingDirectory,'s');
                end
            end
        end
        
        % Checks whether a cached version of the associated waveform exists
        function [available,metaData] = isCached(obj,sampleRateHz,desiredWaveform)
            available = false;
            metaData = [];
            
            if ~isvector(desiredWaveform)
                return
            end
            %assert(isvector(desiredWaveform),'Cannot cache empty/multi-dimensional waveforms');
            
            [desiredWaveform,numPeriods] = compressWaveform(desiredWaveform);
            
            workingDirectory = obj.computeWaveformCachePath(sampleRateHz,desiredWaveform);
            if isempty(workingDirectory)
                warning('Could not check waveform cache because waveformCacheBasePath or scanner name is not set');
                return
            end
            
            metaDataFileName = fullfile(workingDirectory,'metaData.mat');
            
            if ~exist(metaDataFileName,'file')
                return % did not file metadata
            end
            
            m = matfile(metaDataFileName);
            metaData = m.metaData;
            optFunctions = {metaData.optimizationFcn};
            [tf,idx] = ismember(func2str(obj.optimizationFcn),optFunctions);
            
            if ~tf
                return % did not find optimization for current optimization function
            else
                available = true;
                metaData = metaData(idx);
                metaData.path = workingDirectory;
                metaData.metaDataIdx = idx;
                metaData.periodCompressionFactor = numPeriods;
                metaData.linearScanner = obj;
            end            
        end
        
        % Using an original waveform and sample rate this function double
        % checks the existence of a cached version of the optimized
        % waveform and if it exists loads that cached waveform and the
        % associated error (feedback?)
        function [metaData, outputWaveform, feedbackWaveform, optimizationData] = getCachedOptimizedWaveform(obj,sampleRateHz,desiredWaveform)
            outputWaveform = [];
            feedbackWaveform = [];
            optimizationData = [];
            
            [available,metaData] = obj.isCached(sampleRateHz,desiredWaveform);
            
            if available
                outputWaveformFileName   = fullfile(metaData.path,metaData.outputWaveformFileName);
                feedbackWaveformFileName = fullfile(metaData.path,metaData.feedbackWaveformFileName);
                optimizationDataFileName = fullfile(metaData.path,metaData.optimizationDataFileName);
                
                numPeriods = metaData.periodCompressionFactor;
                if nargout>1
                    assert(logical(exist(outputWaveformFileName,'file')),'The file %s was not found on disk.',outputWaveformFileName);
                    hFile = matfile(outputWaveformFileName);
                    outputWaveform = hFile.volts;
                    outputWaveform = repmat(outputWaveform,numPeriods,1);
                end
                
                if nargout>2
                    assert(logical(exist(feedbackWaveformFileName,'file')),'The file %s was not found on disk.',feedbackWaveformFileName);
                    hFile = matfile(feedbackWaveformFileName);
                    feedbackWaveform = hFile.volts;
                    feedbackWaveform = repmat(feedbackWaveform,numPeriods,1);
                end
                
                if nargout>3
                    assert(logical(exist(optimizationDataFileName,'file')),'The file %s was not found on disk.',optimizationDataFileName);
                    hFile = matfile(optimizationDataFileName);
                    optimizationData = hFile.volts;
                end
            end
        end
        
        
        function feedback = testWaveformAsync(obj, outputWaveform, sampleRateHz, guiCallback)
            assert(guiCallbackInternal('start',[],outputWaveform),'Waveform test cancelled by user');
            
            assert(obj.positionAvailable,'%s: Position output not initialized', obj.name);
            assert(obj.feedbackAvailable,'%s: Feedback input not initialized', obj.name);
            assert(obj.feedbackCalibrated,'%s: Feedback input not calibrated', obj.name);
            
            feedbackRaw = obj.testWaveformVolts(processSignal('expand',outputWaveform),sampleRateHz,true,outputWaveform(1),false,@guiCallbackInternal);
            feedback = processSignal('decimate',feedbackRaw);
            guiCallbackInternal('done',feedback);
            
            function tfContinue = guiCallbackInternal(varargin)
                tfContinue = isempty(guiCallback(obj,varargin{:}));
            end
        end
        
        %%
        % desiredWaveform is the desired trajectory, feedback is what the galvos
        % actually do, optimized is the adjusted AO out to make feedback ==
        % desired.
        function [optimizedWaveform,err] = optimizeWaveformIterativelyAsync(obj, desiredWaveform, sampleRateHz, guiCallback, cache) % Perhaps call reCache reOptimize instead? Better clarity maybe. 
            if nargin<5 || isempty(cache)
                cache = true;
            end

            assert(guiCallbackInternal('start',desiredWaveform),'Waveform test cancelled by user');
            
            acceptEarly = false;
            p_cont = true;
            
            assert(obj.positionAvailable,'%s: Position output not initialized', obj.name);
            assert(obj.feedbackAvailable,'%s: Feedback input not initialized', obj.name);
            assert(obj.feedbackCalibrated,'%s: Feedback input not calibrated', obj.name);
            
            [desiredWaveform,numPeriods] = compressWaveform(desiredWaveform);
            
            try
                feedback = obj.testWaveformVolts(processSignal('expand',desiredWaveform),sampleRateHz,true,desiredWaveform(1),false,@guiCallbackInternal);
                feedbackHistory = processSignal('decimate',feedback);
                errHistory = feedbackHistory - desiredWaveform;
                optimizedWaveformHistory = desiredWaveform;
                errRmsHistory = rms(errHistory);
                
                done = ~guiCallbackInternal(repmat(optimizedWaveformHistory,numPeriods,1),repmat(feedbackHistory,numPeriods,1),errRmsHistory);
                
                optimizationData = [];
                
                iterationNumber  = 0;
                while ~done
                    iterationNumber = iterationNumber+1;
                    [done,optimizedWaveform_new,optimizationData] = obj.optimizationFcn(obj,iterationNumber,sampleRateHz,desiredWaveform,optimizedWaveformHistory(:,end),feedbackHistory(:,end),optimizationData);
                    optimizedWaveform_new = min(max(optimizedWaveform_new,-10),10); % clamp output
                    
                    feedback_new = obj.testWaveformVolts(processSignal('expand',optimizedWaveform_new),sampleRateHz,false,optimizedWaveform_new(1),false,@guiCallbackInternal);
                    feedback_new = processSignal('decimate',feedback_new);
                    
                    err_new = feedback_new - desiredWaveform;
                    
                    optimizedWaveformHistory(:,end+1) = optimizedWaveform_new;
                    feedbackHistory(:,end+1) = feedback_new;
                    errHistory(:,end+1) = err_new;
                    
                    errRmsHistory(end+1) = rms(err_new);
                    
                    done = done || ~guiCallbackInternal(repmat(optimizedWaveformHistory,numPeriods,1),repmat(feedbackHistory,numPeriods,1),errRmsHistory);
                    pause(0.01);
                    
                    voltageRange = obj.position2Volts(obj.travelRange);
                    voltageRange = sort(voltageRange);
                    rangePp = diff(voltageRange);
                    tolerance = rangePp*0.01;
                    
                    assert(errRmsHistory(end)<=errRmsHistory(1)+tolerance,'Tracking error unexpectedly increased. Optimization stopped to prevent damage to actuator.');
                    assert(p_cont,'Waveform test cancelled by user')
                end
                
                % park the galvo
                obj.hAOControl.lastKnownValue = desiredWaveform(end);
                obj.smoothTransitionVolts(obj.position2Volts(obj.parkPosition));
            catch ME
                try
                    % park the galvo
                    obj.hAOControl.lastKnownValue = desiredWaveform(end);
                    obj.smoothTransitionVolts(obj.position2Volts(obj.parkPosition));
                catch
                end
                
                if ~acceptEarly
                    rethrow(ME);
                end
            end
            
            if exist('optimizedWaveformHistory','var')
                optimizedWaveform = optimizedWaveformHistory(:,end);
                feedback = feedbackHistory(:,end);
                err = errHistory(:,end);
                
                if cache
                    cacheWf(optimizedWaveform,feedback,iterationNumber);
                end
            else
                optimizedWaveform = repmat(desiredWaveform,numPeriods,1);
                err = nan(size(optimizedWaveform));
            end
            
            optimizedWaveform = repmat(optimizedWaveform,numPeriods,1);
            err = repmat(err,numPeriods,1);

            guiCallbackInternal('done');
            
            function tfContinue = guiCallbackInternal(varargin)
                cmd = guiCallback(obj,varargin{:});
                tfContinue = isempty(cmd);
                acceptEarly = strcmp(cmd,'accept');
                p_cont = tfContinue;
            end
            
            %%% local functions
            function cacheWf(Wf,Fb,N)
                nfo = struct;
                nfo.numIterations = N;
                nfo.feedbackVoltLUT = obj.feedbackVoltLUT;
                obj.cacheOptimizedWaveform(sampleRateHz,desiredWaveform,Wf,Fb,[],nfo);
            end
            
            function signal = processSignal(mode,signal)
                numReps = 5; % minimum of 3
                
                signal = signal(:);                
                switch mode
                    case 'expand'
                        signal = repmat(signal,numReps,1);
                    case 'decimate'
                        signal = reshape(signal,[],numReps);
                        signal = mean(signal(:,2:end),2);
                    otherwise
                        assert(false);
                end
            end
            
            function v = rms(err)
                v = sqrt(sum(err.^2) / numel(err));
            end
        end
        
        %%
        % desiredWaveform is the desired trajectory, feedback is what the galvos
        % actually do, optimized is the adjusted AO out to make feedback ==
        % desired.
        function [optimizedWaveform,err] = optimizeWaveformIteratively(obj, desiredWaveform, sampleRateHz, cache) % Perhaps call reCache reOptimize instead? Better clarity maybe. 
            if nargin<4 || isempty(cache)
                cache = true;
            end
            
            acceptEarly = false;
            p_cont = true;
            runInd = nan;
            
            assert(obj.positionAvailable,'%s: Position output not initialized', obj.name);
            assert(obj.feedbackAvailable,'%s: Feedback input not initialized', obj.name);
            assert(obj.feedbackCalibrated,'%s: Feedback input not calibrated', obj.name);
            
            [desiredWaveform,numPeriods] = compressWaveform(desiredWaveform);
            
            tt = linspace(0,(length(desiredWaveform)-1)/sampleRateHz,length(desiredWaveform))';
            
            hFig = most.idioms.figure('NumberTitle','off','units','pixels','position',most.gui.centeredScreenPos([1200 900]),'MenuBar','none',...
                'Toolbar','figure','Name',sprintf('%s waveform optimization',obj.name),'WindowButtonMotionFcn',@motion);
            mf = most.gui.uiflowcontainer('Parent',hFig,'FlowDirection','BottomUp','margin',0.00001);
                hBf = most.gui.uiflowcontainer('Parent',mf,'FlowDirection','LeftToRight','HeightLimits',44,'margin',8);
                    most.gui.uicontrol('parent',hBf,'String','Abort','BackgroundColor',[1 .9 .5],'WidthLimits',60,'callback',@lcl_cancel);
                    most.gui.uicontrol('parent',hBf,'String','Accept Current Waveform','BackgroundColor',[.65 .94 .65],'WidthLimits',180,'callback',@lcl_accept);
                    most.gui.uipanel('Parent',hBf,'Bordertype','none','WidthLimits',20);
                    hTxt = most.gui.staticText('parent',hBf,'String',sprintf('%s: Preparing waveform...',obj.name),'WidthLimits',300,'HorizontalAlignment','center');

                hPanel = most.gui.uipanel('Parent',mf,'Bordertype','none');
                    most.idioms.axes('parent',hPanel);
            
            hMenu = uicontextmenu('Parent',hFig);
                uimenu('Parent',hMenu,'Label','Use This Waveform','Callback',@useWavfm);
            
            hAx1 = most.idioms.subplot(4,1,[1,2],'NextPlot','add','Box','on','Parent',hPanel);
            ylabel(hAx1,'Signal [V]')
            hPlotDesired = plot(hAx1,tt,nan(size(tt)),'LineWidth',2);
            hPlotFeedback = plot(hAx1,tt,nan(size(tt)));
            hPlotOutput = plot(hAx1,tt,nan(size(tt)),'--');
            legend(hAx1,'Desired','Feedback','Output');
            hAx1.XTickLabel = {[]};
            grid(hAx1,'on');
            
            hAx2 = most.idioms.subplot(4,1,3,'Box','on','Parent',hPanel);
            hPlotError = plot(hAx2,tt,nan(size(tt)));
            linkaxes([hAx1,hAx2],'x')
            legend(hAx2,'Error');
            xlabel(hAx2,'Time [s]');
            ylabel(hAx2,'Error [V]');
            grid(hAx2,'on');
            
            XLim = [tt(1),tt(end)*1.02];
            if diff(XLim)==0
                XLim = [tt(1) tt(1)+1];
            end
            set([hAx1,hAx2],'XLim',XLim);
            
            hAx3 = most.idioms.subplot(4,1,4,'Box','on','Parent',hPanel);
            hPlotRms = plot(hAx3,NaN,NaN,'o-','UIContextMenu',hMenu,'ButtonDownFcn',@rmsLineHit);
            hPlotRmsMarker = line('Parent',hAx3,'XData',NaN,'YData',NaN,'ZData',-1,'MarkerSize',12,'Marker','o','MarkerEdgeColor','red','MarkerFaceColor',[1, 0.9, 0.9],'hittest','off');
            hAx3.YScale = 'log';
            xlabel(hAx3,'Iteration Number');
            ylabel(hAx3,'RMS [V]');
            hAx3.XLim = [0 10];
            grid(hAx3,'on');
            
            hTxt.String = sprintf('%s: Optimizing waveform',obj.name);
            
%             [optimizedWaveform,err] = obj.optimizeWaveformIterativelyAsync(desiredWaveform, sampleRateHz, @guiCallback, cache);
% 
%             function tfContinue = guiCallback(~,varargin)
%             end
            
            try
                feedback = obj.testWaveformVolts(processSignal('expand',desiredWaveform),sampleRateHz,true,desiredWaveform(1),false,@progressCb);
                feedbackHistory = processSignal('decimate',feedback);
                errHistory = feedbackHistory - desiredWaveform;
                optimizedWaveformHistory = desiredWaveform;
                errRmsHistory = rms(errHistory);
                plotWvfs();
                
                optimizationData = [];
                
                done = false;
                iterationNumber  = 0;
                while ~done
                    iterationNumber = iterationNumber+1;
                    [done,optimizedWaveform_new,optimizationData] = obj.optimizationFcn(obj,iterationNumber,sampleRateHz,desiredWaveform,optimizedWaveformHistory(:,end),feedbackHistory(:,end),optimizationData);
                    optimizedWaveform_new = min(max(optimizedWaveform_new,-10),10); % clamp output
                    
                    feedback_new = obj.testWaveformVolts(processSignal('expand',optimizedWaveform_new),sampleRateHz,false,optimizedWaveform_new(1),false,@progressCb);
                    feedback_new = processSignal('decimate',feedback_new);
                    
                    err_new = feedback_new - desiredWaveform;
                    
                    optimizedWaveformHistory(:,end+1) = optimizedWaveform_new;
                    feedbackHistory(:,end+1) = feedback_new;
                    errHistory(:,end+1) = err_new;
                    
                    errRmsHistory(end+1) = rms(err_new);
                    
                    plotWvfs();
                    
                    voltageRange = obj.position2Volts(obj.travelRange);
                    voltageRange = sort(voltageRange);
                    rangePp = diff(voltageRange);
                    tolerance = rangePp*0.01;
                    
                    assert(errRmsHistory(end)<=errRmsHistory(1)+tolerance,'Tracking error unexpectedly increased. Optimization stopped to prevent damage to actuator.');
                    assert(p_cont,'Waveform test cancelled by user')
                end
                
                % park the galvo
                obj.hAOControl.lastKnownValue = desiredWaveform(end);
                obj.smoothTransitionVolts(obj.position2Volts(obj.parkPosition));
            catch ME
                try
                    % park the galvo
                    obj.hAOControl.lastKnownValue = desiredWaveform(end);
                    obj.smoothTransitionVolts(obj.position2Volts(obj.parkPosition));
                catch
                end
                
                if ~acceptEarly
                    rethrow(ME);
                end
            end
            
            if exist('optimizedWaveformHistory','var')
                optimizedWaveform = optimizedWaveformHistory(:,end);
                feedback = feedbackHistory(:,end);
                err = errHistory(:,end);

                hTxt.String = sprintf('%s: Caching waveform',obj.name);
                drawnow('nocallbacks');
                
                if cache
                    cacheWf(optimizedWaveform,feedback,iterationNumber);
                end
            else
                optimizedWaveform = repmat(desiredWaveform,numPeriods,1);
                err = nan(size(optimizedWaveform));
            end
            
            optimizedWaveform = repmat(optimizedWaveform,numPeriods,1);
            err = repmat(err,numPeriods,1);
            
            hBf.Visible = 'off';
            
            %%% local functions
            function cacheWf(Wf,Fb,N)
                nfo = struct;
                nfo.numIterations = N;
                nfo.feedbackVoltLUT = obj.feedbackVoltLUT;
                obj.cacheOptimizedWaveform(sampleRateHz,desiredWaveform,Wf,Fb,[],nfo);
            end
            
            function continuetf = progressCb(pct,msg)
                continuetf = p_cont && most.idioms.isValidObj(hFig);
                if continuetf
                    hTxt.String = msg;
                    hS.XData(:,2) = pct;
                end
            end
            
            function lcl_cancel(varargin)
                p_cont = false;
                hTxt.String = sprintf('%s: Optimization aborted',obj.name);
            end
            
            function lcl_accept(varargin)
                p_cont = false;
                acceptEarly = true;
            end
            
            function useWavfm(varargin)
                optimizedWaveform = optimizedWaveformHistory(:,runInd);
                feedback = feedbackHistory(:,runInd);
                cacheWf(optimizedWaveform,feedback,runInd);
            end
            
            function rmsLineHit(~,evt)
                runInd = round(evt.IntersectionPoint(1))+1;
            end
            
            function plotWvfs(idx)
                if ~exist('feedbackHistory','var') || isempty(feedbackHistory)
                    return
                end
                
                if nargin < 1 || isempty(idx)
                    idx = size(feedbackHistory,2);
                end
                
                idx = max(1,min(idx,size(feedbackHistory,2)));
                
                if isvalid(hPlotDesired) && isvalid(hPlotFeedback) && isvalid(hPlotOutput)
                    hPlotDesired.YData = desiredWaveform;
                    hPlotFeedback.YData = feedbackHistory(:,idx);
                    hPlotOutput.YData = optimizedWaveformHistory(:,idx);
                end
                
                if isvalid(hPlotError)
                    hPlotError.YData = errHistory(:,idx);
                end
                
                if isvalid(hPlotRms)
                    hPlotRms.XData = 0:length(errRmsHistory)-1;
                    hPlotRms.YData = errRmsHistory;
                    hPlotRmsMarker.XData = idx-1;
                    hPlotRmsMarker.YData = errRmsHistory(idx);                    
                    hAx_ = ancestor(hPlotRms,'axes');
                    hAx_.XLim = [0 max(length(errRmsHistory)-1,hAx_.XLim(2))];
                end
                drawnow('limitrate');
            end
            
            function v = rms(err)
                v = sqrt(sum(err.^2) / numel(err));
            end
            
            function motion(src,evt)
                if exist('hAx3','var') && ~isempty(hAx3) && isvalid(hAx3) 
                    pt = hAx3.CurrentPoint(1,1:2);
                    if pt(1) >= hAx3.XLim(1) && pt(1) <= hAx3.XLim(2) && pt(2) >= hAx3.YLim(1) && pt(2) <= hAx3.YLim(2)
                        plotWvfs(round(pt(1))+1);
                    end
                end
            end
        end
    end
end

function [waveform,numPeriods] = compressWaveform(waveform)
    waveform = waveform(:);
    
    if numel(waveform) > 10e6
        numPeriods = 1;
    else
        [period,numPeriods] = scanimage.mroi.util.findWaveformPeriodicity(waveform);
        waveform = waveform(1:period);
    end
end

function hash = computeWaveformHash(sampleRateHz,originalWaveform)
    originalWaveform = round(originalWaveform * 1e6); % round to a precision of 1uV to eliminate rounding errors
    hash = most.util.dataHash({originalWaveform,sampleRateHz});
end

function signal = processSignal(mode,signal)
    numReps = 5; % minimum of 3

    signal = signal(:);
    switch mode
        case 'expand'
            signal = repmat(signal,numReps,1);
        case 'decimate'
            signal = reshape(signal,[],numReps);
            signal = mean(signal(:,2:end),2);
        otherwise
            assert(false);
    end
end

function val = validateLUT(val)
validateattributes(val,{'numeric'},{'ncols',2,'finite','nonnan','real'});

xx = val(:,1);
yy = val(:,2);

%sort LUT by first column
[~,sortIdx] = sort(xx);
xx = xx(sortIdx);
yy = yy(sortIdx);

% assert strictly monotonic
assert(all(diff(xx)>0),'LUT column 1 needs to be strictly monotonic');
assert(all(diff(yy)>0) || all(diff(yy)<0),'LUT column 2 needs to be strictly monotonic');
val = [xx,yy];
end

function vq = interp1Flex(x,v,xq,varargin)
if isempty(x)
    vq = xq;
elseif numel(x) == 1
    offset = v-x;
    vq = xq + offset;
else
    vq = interp1(x,v,xq,varargin{:});
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
