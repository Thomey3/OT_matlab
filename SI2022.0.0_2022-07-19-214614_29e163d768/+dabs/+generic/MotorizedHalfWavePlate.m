classdef MotorizedHalfWavePlate < dabs.resources.devices.BeamModulatorSlow & most.HasMachineDataFile & dabs.resources.configuration.HasConfigPage
    properties (SetAccess=protected,Hidden)
        ConfigPageClass = 'dabs.resources.configuration.resourcePages.MotorizedHalfWavePlatePage';
    end
    
    methods (Static)
        function names = getDescriptiveNames()
            names = {'Beam Modulator\Motorized Half Wave Plate'};
        end
        
        function classes = getClassesToLoadFirst()
            classes = {'dabs.resources.devices.Shutter', 'dabs.resources.devices.MotorController'};
        end
    end
    
    %% ABSTRACT PROPERTY REALIZATIONS (most.HasMachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'Slow Beam';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
        
        mdfDefault = defaultMdfSection();
    end
    
    properties (SetObservable)
        hMotor = dabs.resources.Resource.empty();
        motorAxis = 1;
        hAIFeedback = dabs.resources.Resource.empty();
        hListeners = event.listener.empty();
        
        hCalibrationOpenShutters = {};
        
        devUnitsPerDegree = 1;
        outputRange_deg = [0, 360];
        feedbackUsesRejectedLight = false;
        
        powerFraction2FeedbackVoltLut    = zeros(0,2);
        powerFraction2ModulationAngleLut = zeros(0,2);
        powerFraction2PowerWattLut       = zeros(0,2);
        
        calibrationOpenShutters = {};
        
        feedbackOffset_V = 0;
        
        calibrationNumPoints = 100;
        calibrationNumRepeats = 1;
        calibrationAverageSamples = 5;
        calibrationMotorSettlingTime_s = 0.001;

        moveTimeout_s = 10;
    end
    
    properties (Dependent, Hidden)
        powerFraction2ModulationAngleLutDefault
        outputRange_devUnits
    end
    
    %% Abstract Property Realization (dabs.resources.devices.BeamModulator)
    properties (SetObservable, SetAccess = private)
        lastKnownPowerFraction = 0;
    end
    
    properties (SetAccess = private)
        lastKnownPower_W = 0 % don't attach a listener to this. instead, listen to lastKnownPowerFraction
    end
    
    properties (SetObservable)
        powerFractionLimit = 1;
    end
    
    %% Abstract Property Realization (dabs.resources.devices.BeamModulatorSlow)
    properties(SetObservable, SetAccess = private)
        isModulating = false;
    end
    
    %% Lifecycle Methods
    
    methods
        function obj = MotorizedHalfWavePlate(name)
            obj@dabs.resources.devices.BeamModulatorSlow(name);
            obj@most.HasMachineDataFile(true);
            
            obj.deinit();
            obj.loadMdf();
            obj.reinit();
        end
        
        function delete(obj)
            obj.deinit();
            obj.saveCalibration();
        end
        
        function deinit(obj)
            try
                if most.idioms.isValidObj(obj.hMotor)
                    obj.setPowerFraction(0);
                    obj.hMotor.unreserve(obj);
                    obj.hMotor.unregisterUser(obj);
                end
                
                delete(obj.hListeners);
                obj.hListeners = event.listener.empty(0,1);
                
                if most.idioms.isValidObj(obj.hAIFeedback)
                    obj.hAIFeedback.unreserve(obj);
                end
                
                obj.errorMsg = 'uninitialized';
            catch ME
                obj.errorMsg = sprintf('%s: deinitialization error: %s',obj.name,ME.message);
                most.ErrorHandler.logError(ME,obj.errorMsg);
            end
        end
        
        function reinit(obj)
            obj.deinit();
            try
                assert(most.idioms.isValidObj(obj.hMotor),'No Motor Controller Device specified');
                obj.hMotor.registerUser(obj, 'Motorized Slow Beam Attenuation Device');
                obj.hMotor.reserve(obj);
                
                obj.hMotor.reinit();
                obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hMotor,'lastKnownPosition','PostSet',@(varargin)obj.setLastKnownPowerFraction);
                
                obj.errorMsg = '';
                
                if obj.hMotor.isMoving()
                    obj.hMotor.moveWaitForFinish(obj.moveTimeout_s);
                end
                obj.setPowerFraction(0);
            catch ME
                obj.deinit();
                obj.errorMsg = sprintf('%s: initialization error: %s', obj.name, ME.message);
                most.ErrorHandler.logError(ME,obj.errorMsg);
            end
        end
    end
    
    methods
        function success = loadCalibration(obj)
            success = true;
            success = success & obj.safeSetPropFromMdf('powerFraction2ModulationAngleLut', 'powerFraction2ModulationAngleLut');
            success = success & obj.safeSetPropFromMdf('powerFraction2PowerWattLut', 'powerFraction2PowerWattLut');
            success = success & obj.safeSetPropFromMdf('powerFraction2FeedbackVoltLut', 'powerFraction2FeedbackVoltLut');
            success = success & obj.safeSetPropFromMdf('feedbackOffset_V', 'feedbackOffset_V');
        end
        
        function saveCalibration(obj)
            obj.safeWriteVarToHeading('powerFraction2ModulationAngleLut',obj.powerFraction2ModulationAngleLut);
            obj.safeWriteVarToHeading('powerFraction2PowerWattLut', obj.powerFraction2PowerWattLut);
            obj.safeWriteVarToHeading('powerFraction2FeedbackVoltLut', obj.powerFraction2FeedbackVoltLut);
            obj.safeWriteVarToHeading('feedbackOffset_V',     obj.feedbackOffset_V);
        end
        
        function loadMdf(obj)
            success = true;
            success = success & obj.safeSetPropFromMdf('hMotor', 'rotationStage');
            success = success & obj.safeSetPropFromMdf('motorAxis', 'motorAxis');
            success = success & obj.safeSetPropFromMdf('hAIFeedback', 'AIFeedback');
            
            success = success & obj.safeSetPropFromMdf('outputRange_deg', 'outputRange_deg');
            success = success & obj.safeSetPropFromMdf('devUnitsPerDegree', 'devUnitsPerDegree');
            success = success & obj.safeSetPropFromMdf('feedbackUsesRejectedLight', 'feedbackUsesRejectedLight');
            
            success = success & obj.safeSetPropFromMdf('hCalibrationOpenShutters', 'calibrationOpenShutters');
            success = success & obj.safeSetPropFromMdf('powerFractionLimit', 'powerFractionLimit');
            
            success = success & obj.safeSetPropFromMdf('calibrationNumPoints', 'calibrationNumPoints');
            success = success & obj.safeSetPropFromMdf('calibrationNumRepeats', 'calibrationNumRepeats');
            success = success & obj.safeSetPropFromMdf('calibrationAverageSamples', 'calibrationAverageSamples');
            success = success & obj.safeSetPropFromMdf('calibrationMotorSettlingTime_s', 'calibrationMotorSettlingTime_s');

            if isfield(obj.mdfData,'moveTimeout_s')
                success = success & obj.safeSetPropFromMdf('moveTimeout_s', 'moveTimeout_s');
            end
            
            success = success & obj.loadCalibration();
            
            if ~success
                obj.errorMsg = 'Error loading config';
            end
        end
        
        function saveMdf(obj)
            obj.safeWriteVarToHeading('rotationStage', obj.hMotor);
            obj.safeWriteVarToHeading('motorAxis', obj.motorAxis);
            obj.safeWriteVarToHeading('AIFeedback', obj.hAIFeedback);
            
            obj.safeWriteVarToHeading('moveTimeout_s', obj.moveTimeout_s);
            obj.safeWriteVarToHeading('outputRange_deg', obj.outputRange_deg);
            obj.safeWriteVarToHeading('devUnitsPerDegree', obj.devUnitsPerDegree);
            obj.safeWriteVarToHeading('feedbackUsesRejectedLight', obj.feedbackUsesRejectedLight);
            
            obj.safeWriteVarToHeading('calibrationOpenShutters', cellfun(@(hS)hS.name,obj.hCalibrationOpenShutters,'UniformOutput',false));
            obj.safeWriteVarToHeading('powerFractionLimit', obj.powerFractionLimit);
            
            obj.safeWriteVarToHeading('calibrationNumPoints', obj.calibrationNumPoints);
            obj.safeWriteVarToHeading('calibrationNumRepeats', obj.calibrationNumRepeats);
            obj.safeWriteVarToHeading('calibrationAverageSamples', obj.calibrationAverageSamples);
            obj.safeWriteVarToHeading('calibrationMotorSettlingTime_s', obj.calibrationMotorSettlingTime_s);
            
            obj.saveCalibration();
        end
    end
    
    %% Abstract Methods Implementation (dabs.resources.devices.BeamModulator)
    methods
        function setPowerFraction(obj, val)
            obj.setPowerFractionAsync(val);
            obj.modulateWaitForFinish();
        end
    end
    
    %% Abstract Methods Implementation (dabs.resources.devices.BeamModulatorSlow)
    methods
        function stop(obj)
            obj.hMotor.stop();
        end
        
        function setPowerFractionAsync(obj, fraction)
            obj.assertNoError();
            validateattributes(fraction,{'numeric'},{'>=',0,'<=',1,'scalar','real','nonnan'});
            
            fraction = min(fraction,obj.powerFractionLimit);
            angle_devUnits = obj.powerFraction2Angle_devUnits(fraction);
            
            angleVector = NaN(1, obj.hMotor.numAxes);
            angleVector(obj.motorAxis) = angle_devUnits;
            obj.hMotor.moveAsync(angleVector);
        end
        
        function modulateWaitForFinish(obj, timeout_s)
            obj.assertNoError();
                        
            if nargin < 2
                timeout_s = obj.moveTimeout_s;
            else
                validateattributes(timeout_s,{'numeric'},{'scalar','nonnegative','real','nonnan','finite'});
            end
            
            obj.hMotor.moveWaitForFinish(timeout_s);
        end
    end
    
    %% Class Methods
    methods
        function setLastKnownPowerFraction(obj)
            lut = obj.powerFraction2ModulationAngleLut;
            
            if isempty(obj.powerFraction2ModulationAngleLut)
                lut = obj.powerFraction2ModulationAngleLutDefault;
            end
            
            pf = interp1_extended(lut(:,2), lut(:,1),obj.hMotor.lastKnownPosition,'linear','extrap');

            % clip range
            pf = max([pf,0]);
            pf = min([pf,1]);
            
            obj.lastKnownPowerFraction = pf;
        end
        
        function angle_deg = powerFraction2Angle_deg(obj, fraction)
            angle_deg = obj.powerFraction2Angle_devUnits(fraction) / obj.devUnitsPerDegree;
        end
        
        function angle_devUnits = powerFraction2Angle_devUnits(obj, fraction)
            lut = obj.powerFraction2ModulationAngleLut;
            
            if isempty(obj.powerFraction2ModulationAngleLut)
                lut = obj.powerFraction2ModulationAngleLutDefault;
            end
            
            angle_devUnits = interp1_extended(lut(:,1),lut(:,2),fraction,'linear','extrap');
            
            % clip voltage range
            angle_devUnits = max(angle_devUnits,obj.outputRange_devUnits(1));
            angle_devUnits = min(angle_devUnits,obj.outputRange_devUnits(2));
        end
        
        function fraction = convertFeedbackVolt2PowerFraction(obj,voltage)
            lut = obj.powerFraction2FeedbackVoltLut;
            
            if isempty(obj.powerFraction2ModulationAngleLut)
                fraction = nan(size(voltage));
            else
                fraction = interp1_extended(lut(:,2),lut(:,1),voltage,'linear','extrap');
                fraction = min(max(fraction,0),1);
            end
        end
        
        function power_W = convertPowerFraction2PowerWatt(obj,fraction)
            lut = obj.powerFraction2PowerWattLut;
            
            validateattributes(fraction,{'numeric'},{'vector'});
            
            nonNanFraction = fraction(~isnan(fraction));
            most.ErrorHandler.assert(all(nonNanFraction>=0 & nonNanFraction<=1),'Fractions must between 0 and 1');
            
            if isempty(obj.powerFraction2PowerWattLut)
                power_W = nan(size(fraction));
            else
                power_W = interp1_extended(lut(:,1),lut(:,2),fraction,'linear','extrap');
            end
        end
        
        function v = readFeedbackFraction(obj,nSamples)
            if nargin<2 || isempty(nSamples)
                nSamples = 1;
            end
            
            v = obj.readFeedbackVoltage(nSamples);
            v = obj.convertFeedbackVolt2PowerFraction(v);
        end
        
        function v = readFeedbackVoltage(obj,nSamples)
            if ~isempty(obj.errorMsg)
                most.ErrorHandler.error('%s: Calibration failed because beam is in error state: %s',obj.name,obj.errorMsg);
            end
            
            if ~most.idioms.isValidObj(obj.hAIFeedback)
                most.ErrorHandler.error('%s: Calibration failed because no feedback is specified',obj.name);
            end
            
            if nargin<2 || isempty(nSamples)
                nSamples = 1;
            end
            
            validateattributes(nSamples,{'numeric'},{'positive','integer','scalar'});

            obj.hAIFeedback.reserve(obj);
            
            try
                v = obj.hAIFeedback.readValue(nSamples);
            catch ME
                cleanup();
                ME.rethrow();
            end

            cleanup();

            %%% Nested functions
            function cleanup()
                obj.hAIFeedback.unreserve(obj);
            end
        end
        
        function calibrate(obj,ignorePowerLimit)
            if nargin < 2 || isempty(ignorePowerLimit)
                ignorePowerLimit = false;
            end
            
            validateattributes(ignorePowerLimit,{'logical','numeric'},{'scalar','binary'});
            
            if ~isempty(obj.errorMsg)
                most.ErrorHandler.error('%s: Calibration failed because beam is in error state: %s',obj.name,obj.errorMsg);
            end
            
            if ~most.idioms.isValidObj(obj.hAIFeedback)
                most.ErrorHandler.error('%s: Calibration failed because no feedback is specified',obj.name);
            end
            
            if ~ignorePowerLimit && obj.powerFractionLimit<1
                most.ErrorHandler.error('''%s'' power limit is set to %.2f%%. Cannot perform calibration over full analog output range.',obj.name,obj.powerFractionLimit*100);
            end
            
            is_vDAQ = isa(obj.hAIFeedback.hDAQ,'dabs.resources.daqs.vDAQ');
            hFeedbackTask = [];
            
            if is_vDAQ
                obj.hAIFeedback.reserve(obj); % reservation for NI hardware is done in obj.readFeedbackVoltage
                hFeedbackTask = dabs.vidrio.ddi.Task.createAiTask(obj.hAIFeedback.hDAQ);
                hFeedbackTask.addChannel(obj.hAIFeedback);
                hFeedbackTask.sampleRate = hFeedbackTask.maxSampleRate;
                hFeedbackTask.sampleMode = 'finite';
                
                vDAQSampleTime_s = 1e-3;
                vDAQnumFeedbackSamples = round(vDAQSampleTime_s*hFeedbackTask.sampleRate) * obj.calibrationAverageSamples;
                
                hFeedbackTask.samplesPerTrigger = vDAQnumFeedbackSamples;
            end
            
            angle_devUnits = linspace(obj.outputRange_devUnits(1),obj.outputRange_devUnits(2),obj.calibrationNumPoints)';
            
            h = waitbar(0,sprintf('Calibrating beam modulator %s',obj.name),'Name','Calibration');
            try
                feedbackV = zeros(numel(angle_devUnits),obj.calibrationNumRepeats);
                
                obj.transitionShutters(true);
                
                for rptIdx = 1:obj.calibrationNumRepeats
                    for idx = 1:numel(angle_devUnits)
                        obj.hMotor.move(angle_devUnits(idx),obj.moveTimeout_s);
                        pause(obj.calibrationMotorSettlingTime_s);
                        
                        if is_vDAQ
                            hFeedbackTask.start();
                            hFeedbackTask.waitUntilTaskDone(1);
                            samples = hFeedbackTask.readInputBuffer(vDAQnumFeedbackSamples);
                        else
                            samples = obj.readFeedbackVoltage(obj.calibrationAverageSamples);
                        end
                        
                        feedbackV(idx,rptIdx) = mean(samples);
                        assert(most.idioms.isValidObj(h),'User cancelled calibration');
                    end
                    
                    waitbar(rptIdx/obj.calibrationNumRepeats,h);
                end
                
                feedbackV = mean(feedbackV,2);
                
            catch ME
                cleanup();
                ME.rethrow();
            end
            
            cleanup();
            obj.processCalibrationData(angle_devUnits,feedbackV);
            
            %%% Nested functions
            function cleanup()
                obj.transitionShutters(false);
                obj.setPowerFraction(0);
                most.idioms.safeDeleteObj(hFeedbackTask);
                obj.hAIFeedback.unreserve(obj);
                most.idioms.safeDeleteObj(h);
            end
        end
        
        function calibrateFeedbackOffset(obj)
            obj.transitionShutters(false);
            
            msg = sprintf('Measuring the feedback sensor offset.\nEnsure no laser light reaches the sensor.');
            answer = questdlg(msg,obj.name,'Proceed','Cancel','Proceed');
            
            if ~strcmpi(answer,'Proceed')
                return
            end
            
            obj.feedbackOffset_V = mean(obj.readFeedbackVoltage(10000));
            msg = sprintf('Feedback sensor offset:\n%f V',obj.feedbackOffset_V);
            msgbox(msg,obj.name,'help');
        end
        
        function transitionShutters(obj,tf)
            for shutterIdx = 1:numel(obj.hCalibrationOpenShutters)
                hShutter = obj.hCalibrationOpenShutters{shutterIdx};
                if most.idioms.isValidObj(hShutter)
                    try
                        hShutter.transition(tf);
                    catch ME
                        most.ErrorHandler.logAndReportError(ME);
                    end
                end
            end
        end
        
        function processCalibrationData(obj,angle_devUnits,feedback_V)
            assert(isvector(angle_devUnits) && isvector(feedback_V));
            assert(numel(feedback_V)==numel(angle_devUnits));
            
            angle_devUnits = angle_devUnits(:);
            feedback_V = feedback_V(:);
            
            try
                [idx1,idx2] = findLargestInterval(feedback_V);
                validateInterval(feedback_V,idx1,idx2);
                
                angle_devUnits   = angle_devUnits(idx1:idx2);
                feedback_V = feedback_V(idx1:idx2);
                
                minFeedback = min(feedback_V);
                maxFeedback = max(feedback_V);
                
                powerFraction = (feedback_V - minFeedback) / (maxFeedback-minFeedback);
                
                if obj.feedbackUsesRejectedLight
                    powerFraction = 1-powerFraction;
                end
                
                outputLut = [powerFraction, angle_devUnits];
                feedbackLut = [powerFraction([1,end]), feedback_V([1,end])];
                
                obj.powerFraction2ModulationAngleLut = outputLut;
                obj.powerFraction2FeedbackVoltLut = feedbackLut;
            catch ME
                plotFailedCalibration(angle_devUnits,feedback_V,idx1,idx2);
            end
            
            %%% Nested functions
            function [idx1,idx2] = findLargestInterval(feedback)
                feedback = feedback(:);
                dFeedback = diff(feedback);
                dSigns = sign(dFeedback);
                ddSigns = diff(dSigns);
                edgeIdxs = find(ddSigns~=0) + 1; % changes in monotonicity
                
                intervalStart = [1; edgeIdxs];
                intervalEnd   = [edgeIdxs; numel(feedback)];
                intervalIdxs     = [intervalStart, intervalEnd];
                
                intervalEdgeValues = zeros(size(intervalIdxs));
                intervalEdgeValues(:) = feedback(intervalIdxs(:));
                intervalSwings = diff(intervalEdgeValues,1,2);
                [~,maxInterValIdx] = max(abs(intervalSwings));
                
                maxInterval = intervalIdxs(maxInterValIdx,:);
                idx1 = maxInterval(1);
                idx2 = maxInterval(2);
            end
            
            function validateInterval(feedback,idx1,idx2)
                % check if found interval is roughly the minimum and maximum of the feedback
                intervalMin = min(feedback([idx1,idx2]));
                intervalMax = max(feedback([idx1,idx2]));
                
                tolerance = 0.01;
                feedbackRange = max(feedback)-min(feedback);
                assert(abs(intervalMin-min(feedback)) <= tolerance*feedbackRange);
                assert(abs(intervalMax-max(feedback)) <= tolerance*feedbackRange);
            end
            
            function plotFailedCalibration(angle_deg,feedbackV,idx1,idx2)
                hFig = most.idioms.figure('Name',sprintf('%s: Calibration failed',obj.name),'NumberTitle','off','MenuBar','none');
                hAx = most.idioms.subplot(2,1,1,'Parent',hFig,'Color',most.constants.Colors.lightRed);
                hAxDiff = most.idioms.subplot(2,1,2,'Parent',hFig,'Color',most.constants.Colors.lightRed);
                grid(hAx,'on');grid(hAxDiff,'on');
                box(hAx,'on');box(hAxDiff,'on');
                line('Parent',hAx,'XData',angle_deg,'YData',feedbackV,'LineWidth',1);
                line('Parent',hAx,'XData',angle_deg(idx1:idx2),'YData',feedbackV(idx1:idx2),'LineWidth',3);
                line('Parent',hAxDiff,'XData',angle_deg(2:end),'YData',diff(feedbackV),'LineWidth',1);
                xlabel(hAxDiff,'Output [V]')
                ylabel(hAx,'Feedback [V]');
                ylabel(hAxDiff,'Feedback diff [V]');
                title(hAx,sprintf('%s: Calibration failed',obj.name));
            end
        end
        
        function plotLUT(obj)            
            hListeners = event.listener.empty(0,1);
            
            figureName = sprintf('%s LUT',obj.name);
            hFig = most.idioms.figure('Name',figureName,'NumberTitle','off','MenuBar','none','CloseRequestFcn',@closeFigure);
            hFig.Position(3) = hFig.Position(3)*1.3;
            
            hTopFlow = most.gui.uiflowcontainer('Parent',hFig,'FlowDirection','LeftToRight');
                hFlow = most.gui.uiflowcontainer('Parent',hTopFlow,'FlowDirection','TopDown');
                    hAxFlow = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','LeftToRight');
                        hAxPanel = uipanel('Parent',hAxFlow);
                    hButtonFlow = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','LeftToRight','HeightLimits',[30 30]);
                hTableFlow = most.gui.uiflowcontainer('Parent',hTopFlow,'FlowDirection','TopDown');
                    hTableFlow.WidthLimits = [165 165];
            
            hTable = most.gui.LutTable(hTableFlow,obj,'powerFraction2ModulationAngleLut');
            hTable.columnNames = {'Power %',['Angle ' most.constants.Unicode.degree_sign]};
            hTable.lutScaling = [100,1];
            
            hAx2 = most.idioms.axes('Parent',hAxPanel,'XTick',[],'YAxisLocation','right');
            hAx = most.idioms.axes('Parent',hAxPanel,'XLim',[0,100],'Color','none');
            linkprop([hAx,hAx2],'Position');
            
            grid(hAx,'on');
            box(hAx,'on');
            hLine = line('Parent',hAx,'XData',[],'YData',[],'LineWidth',1.5);
            hLineLimits = line('Parent',hAx,'XData',[],'YData',[],'LineWidth',1,'LineStyle','--');
            hLineFraction = line('Parent',hAx,'XData',[],'YData',[],'LineWidth',1,'Marker','o','Color',most.constants.Colors.red,'MarkerSize',8);
            hText = text('Parent',hAx,'VerticalAlignment','top','FontWeight','bold');
            
            title(hAx,figureName);
            xlabel(hAx,'Modulation Angle [deg]');
            ylabel(hAx,'Beam fraction [%]');
            ylabel(hAx2,'Power [W]');
            
            h = uicontrol('Parent',hButtonFlow,'String','Measure Feedback Offset','Callback',@(varargin)obj.calibrateFeedbackOffset);
            set(h,'WidthLimits',[150 150]);
            uicontrol('Parent',hButtonFlow,'String','Calibrate','Callback',@(varargin)obj.calibrate);
            uicontrol('Parent',hButtonFlow,'String','Reset',    'Callback',@(varargin)obj.resetLUT);
            uicontrol('Parent',hButtonFlow,'String','Save',     'Callback',@(varargin)obj.saveLUT);
            uicontrol('Parent',hButtonFlow,'String','Load',     'Callback',@(varargin)obj.loadLUT);
            
            hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj,'ObjectBeingDestroyed',@closeFigure);
            hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj,'lastKnownPowerFraction','PostSet',@redraw);
            hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj,'powerFraction2ModulationAngleLut','PostSet',@redraw);
            hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj,'powerFraction2PowerWattLut','PostSet',@redraw);
            
            redraw();
            
            function redraw(varargin)
                ff = linspace(0,1,1000);
                vv = obj.powerFraction2Angle_deg(ff);
                
                hLine.XData = vv;
                hLine.YData = ff*100;
                
                hLineLimits.XData = [vv(1) vv(1) NaN vv(end) vv(end)];
                hLineLimits.YData = [0 1 NaN 0 1]*100;
                
                hLineFraction.XData = obj.powerFraction2Angle_deg(obj.lastKnownPowerFraction);
                hLineFraction.YData = obj.lastKnownPowerFraction*100;
                
                hAx.XLim = obj.outputRange_deg;
                power_Lim = obj.convertPowerFraction2PowerWatt([0 1]);
                if any(isnan(power_Lim))
                    hAx2.YTick = [];
                else
                    hAx2.YLim = power_Lim;
                    hAx2.YTickMode = 'auto';
                end
                
                if isempty(obj.powerFraction2ModulationAngleLut)
                    description = sprintf('\n    UNCALIBRATED');
                else
                    feedback_V = obj.powerFraction2FeedbackVoltLut(:,2);
                    extinctionRatio = ( max(feedback_V)-obj.feedbackOffset_V ) / ( min(feedback_V)-obj.feedbackOffset_V );
                    description = sprintf('\n    Feedback Offset: %.2fV\n    Min Feedback Voltage: %.2fV\n    Max Feedback Voltage: %.2fV\n    Max Extinction Ratio: %.2f',...
                        obj.feedbackOffset_V,min(feedback_V),max(feedback_V),extinctionRatio);
                end
                hText.String = description;
                hText.Position = [hAx.XLim(1),hAx.YLim(2)];
            end
            
            function closeFigure(varargin)
                most.idioms.safeDeleteObj(hListeners);
                most.idioms.safeDeleteObj(hFig);
            end
        end
        
        function saveLUT(obj,filePath)
            most.ErrorHandler.assert(~isempty(obj.powerFraction2ModulationAngleLut),'%s LUT is not calibrated',obj.name);
            
            if nargin < 2 || isempty(filePath)
                defaultName = sprintf('%s.beamlut',obj.name);
                filter = {'*.beamlut','ScanImage Beam LUT file (*.beamlut)';
                          '*.csv'    ,'CSV file (*.csv)'};
                [fileName,filePath] = uiputfile(filter,'Select look up table file name',defaultName);
                if isequal(fileName,0)
                    return % cancelled by user
                end
                filePath = fullfile(filePath,fileName);
            end
            
            [~,~,fileExtension] = fileparts(filePath);
            
            if strcmpi(fileExtension,'.beamlut')
                text = saveJsonLut();
            else
                text = saveCsvLut();
            end
            
            fid = fopen(filePath,'w');
            most.ErrorHandler.assert(fid>0,'Error creating file %s.',filePath);
            try                
                fprintf(fid,text);
                fclose(fid);
            catch ME
                fclose(fid);
                rethrow(ME);
            end
            
            % nested function
            function text = saveJsonLut()
                lutInfo = struct();
                lutInfo.beamModulatorName = obj.name;
                lutInfo.powerFraction2ModulationAngleLut = obj.powerFraction2ModulationAngleLut;
                lutInfo.powerFraction2PowerWattLut = obj.powerFraction2PowerWattLut;
                lutInfo.powerFraction2FeedbackVoltLut = obj.powerFraction2FeedbackVoltLut;
                lutInfo.feedbackOffset_V = obj.feedbackOffset_V;
                
                text = most.json.savejson('',lutInfo);
            end
            
            function text = saveCsvLut()
                lut = obj.powerFraction2ModulationAngleLut;
                numRows = size(lut,1);
                
                text = sprintf('PowerFraction, ModulationAngle\n');
                for idx = 1:numRows
                    row = lut(idx,:);
                    text = sprintf('%s%f, %f\n',text,row(1),row(2));
                end
                
                text = strtrim(text);
            end
        end
        
        function lut = loadLUT(obj,filePath)
            lut = [];
            if nargin < 2 || isempty(filePath)
                defaultName = sprintf('%s.beamlut',obj.name);
                [fileName,filePath] = uigetfile('*.beamlut;*.csv','Select look up table file',defaultName);
                if isequal(fileName,0)
                    return % cancelled by user
                end
                filePath = fullfile(filePath,fileName);
            end
            
            hFile = fopen(filePath,'r');
            most.ErrorHandler.assert(hFile>0,'Error opening file %s.',filePath);
            
            try
                data = fread(hFile,Inf,'*char')';
                fclose(hFile);
                
                isJSON = ~isempty(regexpi(data,'^\s*{.*}\s*$','once'));

                if isJSON
                    parseJSON(data);
                else
                    parseCSV(data);
                end
            catch ME
                try
                    fclose(hFile);
                catch
                end
                most.ErrorHandler.rethrow(ME);
            end
            
            lut = obj.powerFraction2ModulationAngleLut;
            
            %%% nested functions            
            function parseCSV(data)
                data = strtrim(data);
                lines = strsplit(data,{'\r','\n'});
                
                lut_ = zeros(0,2);
                
                for idx = 1:numel(lines)
                    line = strtrim(lines{idx});
                    lineStrings = strsplit(line,{' ',',',';','\t'});
                    
                    lutEntry = [NaN NaN];
                    
                    if numel(lineStrings) >= 2
                        lutEntry = [str2double(lineStrings{1}) str2double(lineStrings{2})];
                    end
                    
                    if any(isnan(lutEntry))
                        % don't warn on line 1 since it could be a header
                        if idx > 1
                            most.idioms.warn('Could not parse line ''%s''',line);
                        end
                    else
                        lut_(end+1,:) = lutEntry;
                    end
                end
                
                safeSetProp('powerFraction2ModulationAngleLut',lut_);
            end
            
            function parseJSON(data)
                data = most.json.loadjson(data);
                
                if isfield(data,'beamModulatorName') ...
                        && ~strcmpi(data.beamModulatorName,obj.name)
                    msg = sprintf('LUT file was saved for beam modulator ''%s'', but is loaded into modulator ''%s''\n\nDo you want to continue?' ...
                        ,data.beamModulatorName,obj.name);
                    answer = questdlg(msg,'Warning');
                    
                    if ~strcmpi(answer,'Yes')
                        return
                    end
                end
                
                safeSetProp('powerFraction2ModulationAngleLut',data.powerFraction2ModulationAngleLut);
                safeSetProp('powerFraction2FeedbackVoltLut',data.powerFraction2FeedbackVoltLut);
                safeSetProp('powerFraction2PowerWattLut',data.powerFraction2PowerWattLut);
                safeSetProp('feedbackOffset_V',data.feedbackOffset_V);
            end
            
            function safeSetProp(propName,val)
                try
                    obj.(propName) = val;
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
            end
        end
        
        function resetLUT(obj)
            obj.powerFraction2ModulationAngleLut= [];
            obj.powerFraction2FeedbackVoltLut   = [];
            obj.powerFraction2PowerWattLut      = [];
            obj.feedbackOffset_V = 0;
        end
    end
    
    %% Setters and Getters Validation
    methods
        function set.hCalibrationOpenShutters(obj,val)
            for idx = 1:numel(obj.hCalibrationOpenShutters)
                hShutter = obj.hCalibrationOpenShutters{idx};
                if most.idioms.isValidObj(hShutter)
                    hShutter.unregisterUser(obj);
                end
            end
            
            hShutters = {};
            for idx = 1:numel(val)
                hShutter = obj.hResourceStore.filterByName(val{idx});
                if most.idioms.isValidObj(hShutter) && isa(hShutter,'dabs.resources.devices.Shutter')
                    hShutter.registerUser(obj,'Shutter');
                    hShutters{end+1} = hShutter;
                end
            end
            
            obj.hCalibrationOpenShutters = hShutters;
        end
        
        function val = get.hCalibrationOpenShutters(obj)
            validMask = cellfun(@(hS)most.idioms.isValidObj(hS),obj.hCalibrationOpenShutters);
            val = obj.hCalibrationOpenShutters(validMask);
        end
        
        function set.hMotor(obj,val)
            val = obj.hResourceStore.filterByName(val);
            
            if ~isequal(val,obj.hMotor)
                obj.deinit();
                
                if most.idioms.isValidObj(obj.hMotor)
                    obj.hMotor.unregisterUser(obj);
                end
                
                if most.idioms.isValidObj(val)
				    validateattributes(val,{'dabs.resources.devices.MotorController'},{'scalar'});
					val.registerUser(obj,'Beam Motor');
			    end
                
                obj.hMotor = val;
            end
        end
        
        function set.hAIFeedback(obj,val)
            val = obj.hResourceStore.filterByName(val);
            
            if ~isequal(val,obj.hAIFeedback)
                obj.deinit();
                
                if most.idioms.isValidObj(obj.hAIFeedback)
                    obj.hAIFeedback.unregisterUser(obj);
                end
                
                if most.idioms.isValidObj(val)
                    validateattributes(val,{'dabs.resources.ios.AI'},{'scalar'});
                    allowMultipleUsers = true;
                    val.registerUser(obj,'Feedback',allowMultipleUsers);
                end
                
                obj.hAIFeedback = val;
            end
        end
        
        function set.outputRange_deg(obj,val)
            validateattributes(val,{'numeric'},{'size',[1,2],'>=',0,'<=',360,'real','nonnan'});

            val = sort(val);
            assert(val(1) < val(2),'Angular range must be increasing');
            assert(all(val>=0) && all(val<=360), 'Angular range must be within 0-360 degrees');
            obj.outputRange_deg = val;
        end
        
        function set.powerFraction2ModulationAngleLut(obj,val)
            if isempty(val)
                val = zeros(0,2);
            else
                val = validateLut(val);
            end
            
            obj.powerFraction2ModulationAngleLut = val;
        end
        
        function set.powerFraction2FeedbackVoltLut(obj,val)
            if isempty(val)
                val = zeros(0,2);
            else
                val = validateLut(val);
            end
            
            obj.powerFraction2FeedbackVoltLut = val;
        end
        
        %Power fraction to angle in stage units
        function val = get.powerFraction2ModulationAngleLutDefault(obj)
            val = [0, obj.outputRange_devUnits(1), obj.outputRange_devUnits(1); ...
                   1, obj.outputRange_devUnits(2), obj.outputRange_devUnits(2)];
        end
        
        function val = get.outputRange_devUnits(obj)
            val = obj.outputRange_deg * obj.devUnitsPerDegree;
        end
        
        function set.feedbackUsesRejectedLight(obj,val)
            validateattributes(val,{'numeric','logical'},{'scalar','binary'});
            obj.feedbackUsesRejectedLight = logical(val);
        end
        
        function set.powerFraction2PowerWattLut(obj,val)
            if isempty(val)
                val = zeros(0,2);
            else
                val = validateLut(val);
            end
            
            obj.powerFraction2PowerWattLut = val;
        end
        
        function set.lastKnownPowerFraction(obj,val)
            obj.lastKnownPower_W = obj.convertPowerFraction2PowerWatt(val); %#ok<MCSUP>
            obj.lastKnownPowerFraction = val;
        end
        
        function set.powerFractionLimit(obj,val)
            validateattributes(val,{'numeric'},{'nonnegative','<=',1,'scalar','finite','nonnan','real'});
            obj.powerFractionLimit = val;
        end
        
        function set.calibrationNumPoints(obj,val)
            validateattributes(val,{'numeric'},{'scalar','integer','positive'});
            obj.calibrationNumPoints = val;
        end
        
        function set.calibrationNumRepeats(obj,val)
            validateattributes(val,{'numeric'},{'scalar','integer','positive'});
            obj.calibrationNumRepeats = val;
        end
        
        function set.calibrationAverageSamples(obj,val)
            validateattributes(val,{'numeric'},{'scalar','integer','positive'});
            obj.calibrationAverageSamples = val;
        end
        
        function set.calibrationMotorSettlingTime_s(obj,val)
            validateattributes(val,{'numeric'},{'scalar','nonnegative','finite','nonnan','real'});
            obj.calibrationMotorSettlingTime_s = val;
        end

        function set.moveTimeout_s(obj,val)
            validateattributes(val,{'numeric'},{'scalar','positive','nonnan','finite','real'});
            obj.moveTimeout_s = val;
        end
    end
end

%%% Validate function
function lut = validateLut(lut)
    validateattributes(lut,{'numeric'},{'ncols',2});
    %assert(size(lut,1)>=2,'LUT needs to have at least 2 entries');
    
    [~,sortIdx] = sort(lut(:,1));
    lut = lut(sortIdx,:);
    
    d = diff(lut(:,1));
    isStrictlyIncreasing = all(d>0);
    assert(isStrictlyIncreasing,'LUT(:,1) needs to be strictly increasing');
    
    inRange = min(lut(:,1))>=0 && max(lut(:,1))<=1;
    assert(inRange,'LUT fraction must be in range between 0 and 1');
    
    d = diff(lut(:,2));
    isStrictlyMonotonic = all(d>0) || all(d<0);
    assert(isStrictlyMonotonic,'LUT(:,2) needs to be strictly decreasing or increasing');
end

function vq = interp1_extended(x,v,xq,varargin)
    if isempty(x)
        vq = xq;
    elseif isscalar(x)
        vq = xq-x+v;
    else 
        vq = interp1(x,v,xq,varargin{:});
    end
end

function s = defaultMdfSection()
s = [...
    most.HasMachineDataFile.makeEntry('rotationStage' ,'','Motor Controller user-assigned device name  e.g. ''Rotation Stage''')...
    most.HasMachineDataFile.makeEntry('motorAxis',1,'Number of the axis for on the motor controller for controlling the Rotation Stage')...
    most.HasMachineDataFile.makeEntry('AIFeedback','','feedback terminal e.g. ''/vDAQ0/AI0''')...
    most.HasMachineDataFile.makeEntry()... % blank line
    most.HasMachineDataFile.makeEntry('moveTimeout_s',10,'move timeout in seconds')...
    most.HasMachineDataFile.makeEntry('outputRange_deg',[0 360],'Control angular range in degrees')...
    most.HasMachineDataFile.makeEntry('devUnitsPerDegree',1,'Ratio of stage units per degree of rotation')...
    most.HasMachineDataFile.makeEntry('feedbackUsesRejectedLight',false,'Indicates if photodiode is in rejected path of beams modulator.')...
    most.HasMachineDataFile.makeEntry('calibrationOpenShutters',{{}},'List of shutters to open during the calibration. (e.g. {''Shutter1'' ''Shutter2''}')...
    most.HasMachineDataFile.makeEntry()... % blank line
    most.HasMachineDataFile.makeEntry('powerFractionLimit',1,'Maximum allowed power fraction (between 0 and 1)')... % blank line
    most.HasMachineDataFile.makeEntry()...
    most.HasMachineDataFile.makeEntry('Calibration data')...
    most.HasMachineDataFile.makeEntry('powerFraction2ModulationAngleLut',[],'')...
    most.HasMachineDataFile.makeEntry('powerFraction2PowerWattLut',[],'')...
    most.HasMachineDataFile.makeEntry('powerFraction2FeedbackVoltLut',[],'')...
    most.HasMachineDataFile.makeEntry('feedbackOffset_V',0,'')...
    most.HasMachineDataFile.makeEntry()...
    most.HasMachineDataFile.makeEntry('Calibration settings')...
    most.HasMachineDataFile.makeEntry('calibrationNumPoints',100,'number of equidistant points to measure within the angular ouptut range')...
    most.HasMachineDataFile.makeEntry('calibrationAverageSamples',5,'per calibration point, average N analog input samples. This helps to reduce noise')...
    most.HasMachineDataFile.makeEntry('calibrationNumRepeats',5,'number of times to repeat the calibration routine. the end result is the average of all calibration runs')...
    most.HasMachineDataFile.makeEntry('calibrationMotorSettlingTime_s',0.001,'pause between measurement points. this allows the beam modulation to settle')...
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
