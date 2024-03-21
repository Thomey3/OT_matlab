classdef Print3D < dabs.resources.Device & dabs.resources.widget.HasWidget & most.HasMachineDataFile & dabs.resources.configuration.HasConfigPage
    properties (SetAccess = protected)
        WidgetClass = 'dabs.resources.widget.widgets.Print3DWidget';
    end
    
    %% ABSTRACT PROPERTY REALIZATIONS (most.HasMachineDataFile) 
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'Print3D';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
        
        mdfDefault = defaultMdfSection();
    end
    
    properties (SetObservable)
        imageStack = {};
        numRepeats = 1;
        zStep_um = 1;
        startScript;
        endScript;
        stackMode = scanimage.types.StackMode.slow;
        stackActuator = scanimage.types.StackActuator.motor;
        beamPowerFractions = [];
        beamPowerFractionsBuffer = [];
        loggingEnableBuffer = [];
    end
    
    properties (SetObservable, SetAccess = private)
        slicesDone = 0;
        hListeners = event.listener.empty();
        hWaitbar = [];
        
        active = false;
        startPosition = 0;
        
        cache_pmtAutoPower;
        cache_pmtPowerState;
    end
    
    properties (Dependent, Hidden)
        hSI
        hFastZ
    end
    
    properties (SetAccess = protected,Hidden)
        ConfigPageClass = 'dabs.resources.configuration.resourcePages.BlankPage';
    end
    
    methods (Static)
        function names = getDescriptiveNames()
            names = {'Print 3D'};
        end
    end
    
    methods
        function obj = Print3D(name)
            obj@dabs.resources.Device(name);
            obj = obj@most.HasMachineDataFile(true);
            
            obj.deinit();
            obj.loadMdf();
            obj.reinit();
        end
        
        function delete(obj)
            obj.deinit();
        end
    end
    
    methods
        function reinit(obj)
            try
                obj.deinit();
                obj.errorMsg = '';
            catch ME
                obj.deinit();
                obj.errorMsg = sprintf('%s: initialization error: %s',obj.name,ME.message);
                most.ErrorHandler.logError(ME,obj.errorMsg);
            end
        end
        
        function deinit(obj)
            obj.errorMsg = 'Uninitialized';
        end
    end
    
    methods
        function loadMdf(obj)
            success = true;
            success = success & obj.safeSetPropFromMdf('startScript', 'startScript');
            success = success & obj.safeSetPropFromMdf('endScript', 'endScript');
            success = success & obj.safeSetPropFromMdf('beamPowerFractions', 'beamPowerFractions');
            
            if ~success
                obj.errorMsg = 'Error loading config';
            end
        end
        
        function saveMdf(obj)
            obj.safeWriteVarToHeading('startScript', obj.startScript);
            obj.safeWriteVarToHeading('endScript', obj.endScript);
            obj.safeWriteVarToHeading('beamPowerFractions', obj.beamPowerFractions);
        end
    end
    
    methods
        function start(obj)            
            assert(most.idioms.isValidObj(obj.hSI),'ScanImage is not initialized');
            assert(strcmpi(obj.hSI.acqState,'idle'),'ScanImage is currently imaging');
            assert(~isempty(obj.imageStack),'No images loaded');
            
            obj.abort();
            
            if isa(obj.hSI.hScan2D,'scanimage.components.scan2d.RggScan')
                obj.hSI.hScan2D.sampleRateCtlMax = 2e6;
                obj.hSI.hScan2D.sampleRateCtl = 2e6;
            end
            
            obj.cacheAndDeactivatePmts();
            obj.cacheBeamPowerFractions();
            obj.cacheLoggingEnable();
            
            try
                if obj.stackMode == scanimage.types.StackMode.slow
                    startSlowPrint();
                else
                    startFastPrint();
                end
            catch ME
                obj.abort();
                most.ErrorHandler.logAndReportError(ME);
            end
            
            function startFastPrint()
                hWb = waitbar(0.2,'Starting Fast Print...');
                
                try
                    obj.hSI.hStackManager.stackMode = 'fast';
                    obj.hSI.hStackManager.stackActuator = 'fastZ';
                    obj.hSI.hStackManager.enable = true;
                    obj.hSI.hStackManager.framesPerSlice = 1;
                    obj.hSI.extTrigEnable = false;
                    obj.hSI.hRoiManager.mroiEnable = false;
                    obj.hSI.hMotors.queryPosition();
                    
                    focusZ = obj.hSI.hCoordinateSystems.focalPoint.transform(obj.hSI.hCoordinateSystems.hCSSampleRelative);
                    
                    zs = (0:numel(obj.imageStack)-1)' * obj.zStep_um;
                    zs = zs + focusZ.points(3);
                    
                    obj.hSI.hStackManager.stackDefinition = 'arbitrary';
                    obj.hSI.hStackManager.stackFastWaveformType = 'step';
                    obj.hSI.hStackManager.arbitraryZs = zs;
                    obj.hSI.hStackManager.numVolumes = obj.numRepeats;
                    
                    zs = obj.hSI.hStackManager.zs; % get the actual z values to make sure we don't have any rounding errors)
                    
                    pb = scanimage.components.beams.PowerBox(obj.hSI.hBeams);
                    pb.rect = [0 0 1 1];
                    pb.powers = NaN;
                    pb.name = 'Print 3D PowerBox';
                    pb.oddLines = true;
                    pb.evenLines = true;
                    pb.mask = [];
                    pb.zs = [];
                    
                    pb = repmat(pb,1,numel(obj.imageStack));
                    
                    for idx = 1:numel(pb)
                        pb(idx).name = sprintf('Print3D z=%f',zs(idx));
                        pb(idx).mask = obj.imageStack{idx};
                        pb(idx).zs   = zs(idx);
                    end
                    
                    obj.hSI.hBeams.powerBoxes = pb;
                    obj.hSI.hBeams.enablePowerBox = true;
                    
                    obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hSI.hUserFunctions,'acqModeDone',@(varargin)obj.abort());
                    
                    obj.active = true;
                    obj.hSI.startGrab();
                    
                    most.idioms.safeDeleteObj(hWb);
                
                catch ME__
                    most.idioms.safeDeleteObj(hWb);
                    ME__.rethrow();
                end
            end

            function startSlowPrint()
                obj.hSI.hStackManager.enable = false;
                obj.hSI.hStackManager.framesPerSlice = obj.numRepeats;
                obj.hSI.extTrigEnable = false;
                obj.hSI.hRoiManager.mroiEnable = false;
 

                if isprop(obj.hSI.hScan2D,'keepResonantScannerOn')
                    obj.hSI.hScan2D.keepResonantScannerOn = true;
                end

                if obj.stackActuator == scanimage.types.StackActuator.motor
                    obj.hSI.hMotors.queryPosition();
                    obj.startPosition = obj.hSI.hMotors.samplePosition;
                else
                    obj.startPosition = obj.hFastZ.targetPosition;
                end

                obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hSI.hUserFunctions,'acqModeDone',@(varargin)obj.nextSlice);

                obj.hWaitbar = waitbar(0,sprintf('Progress: 0/%d',numel(obj.imageStack)),'Name','Ablating...','CreateCancelBtn',@(varargin)obj.abort);

                obj.active = true;
                obj.slicesDone = -1;

                if ~isempty(obj.startScript)
                    try
                        evalin('base',obj.startScript);
                    catch ME_
                        most.ErrorHandler.logAndReportError(ME_,['Error occurred running start script: ' ME_.message]);
                    end
                end

                obj.nextSlice();
            end
        end
        
        function cacheAndDeactivatePmts(obj)
            obj.cache_pmtAutoPower  = obj.hSI.hPmts.autoPower;
            obj.cache_pmtPowerState = obj.hSI.hPmts.powersOn;
            
            obj.hSI.hPmts.autoPower = false(1,numel(obj.hSI.hPmts.hPMTs));
            obj.hSI.hPmts.powersOn  = false(1,numel(obj.hSI.hPmts.hPMTs));
        end
        
        function restorePmts(obj)
            try
                if ~isempty(obj.cache_pmtAutoPower)
                    obj.hSI.hPmts.autoPower = obj.cache_pmtAutoPower;
                    obj.cache_pmtAutoPower = [];
                end
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
            
            try
                if ~isempty(obj.cache_pmtPowerState)
                    obj.hSI.hPmts.powersOn  = obj.cache_pmtPowerState;
                    obj.cache_pmtPowerState = [];
                end
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
        end

        function expandBeamPowerFractions(obj)
            if ~most.idioms.isValidObj(obj.hSI)
                return
            end

            numBeams = numel(obj.hSI.hBeams.powerFractions);
            beamPowerFractions_ = obj.beamPowerFractions;
            beamPowerFractions_(end+1:numBeams) = NaN;
            beamPowerFractions_(numBeams+1:end) = [];

            obj.beamPowerFractions = beamPowerFractions_;
        end

        function cacheBeamPowerFractions(obj)
            obj.expandBeamPowerFractions();
            obj.beamPowerFractionsBuffer = obj.hSI.hBeams.powerFractions;
            mask = ~isnan(obj.beamPowerFractions);
            
            obj.hSI.hBeams.powerFractions(mask) = obj.beamPowerFractions(mask);
        end
        
        function restoreBeamPowerFractions(obj)
            try
                if isempty(obj.beamPowerFractionsBuffer)
                    return
                end
                
                beamPowerFractionsBuffer_ = obj.beamPowerFractionsBuffer;
                obj.beamPowerFractionsBuffer = [];
                numBeams = numel(obj.hSI.hBeams.powerFractions);
                beamPowerFractionsBuffer_(end+1:numBeams) = [];
                beamPowerFractionsBuffer_(numBeams+1:end) = [];
                mask = ~isnan(beamPowerFractionsBuffer_);
                obj.hSI.hBeams.powerFractions(mask) = beamPowerFractionsBuffer_(mask);
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
        end
        
        function cacheLoggingEnable(obj)
            obj.loggingEnableBuffer = obj.hSI.hChannels.loggingEnable;
            obj.hSI.hChannels.loggingEnable = false;
        end
        
        function restoreLoggingEnable(obj)
            try
                if ~isempty(obj.loggingEnableBuffer)
                     obj.hSI.hChannels.loggingEnable = obj.loggingEnableBuffer;
                     obj.loggingEnableBuffer = [];
                end
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
        end
        
        function nextSliceDelayed(obj)
            % this is necessary because of the weird calling order that
            % happens with the user events that indicate a complete
            % acquisition.
            
            hTimer = timer('Name','Delayed Nxt Slice');
            hTimer.ExecutionMode = 'SingleShot';
            hTimer.StartDelay = 0.01;
            hTimer.TimerFcn = @(varargin)timerFcn(hTimer);
            
            function timerFcn(hTimer)
                most.idioms.safeDeleteObj(hTimer);
                obj.nextSlice();
            end
        end
        
        function nextSlice(obj)
            if ~obj.active
                return
            end      
            
            obj.slicesDone = obj.slicesDone + 1;
            
            waitbar(obj.slicesDone/numel(obj.imageStack),obj.hWaitbar,sprintf('Progress: %d/%d',obj.slicesDone,numel(obj.imageStack)));
            
            if obj.slicesDone == numel(obj.imageStack)
                obj.abort();
                return
            end
            
            % set up power box
            powerbox = scanimage.components.beams.PowerBox(obj.hSI.hBeams);
            powerbox.rect = [0 0 1 1];
            powerbox.powers = NaN;
            powerbox.name = 'Ablation';
            powerbox.oddLines = true;
            powerbox.evenLines = true;
            powerbox.mask = obj.imageStack{obj.slicesDone + 1};
            
            obj.hSI.hBeams.powerBoxes = powerbox;
            obj.hSI.hBeams.enablePowerBox = true;
            
            dz = obj.zStep_um * obj.slicesDone;
            
            if obj.stackActuator == scanimage.types.StackActuator.motor
                nextZ = obj.startPosition(3) + dz;
                nextMotorPosition = [obj.startPosition(1:2) nextZ];
                obj.hSI.hMotors.moveSample(nextMotorPosition);
            else
                assert(most.idioms.isValidObj(obj.hFastZ),'No FastZ configured for scan system ''%s''',obj.hSI.hScan2D.name);
                nextZ = obj.startPosition + dz;
                obj.hFastZ.moveBlocking(nextZ);
            end
            
            try
                obj.hSI.startGrab();                
            catch ME
                obj.abort();
                most.ErrorHandler.logAndReportError(ME);
            end
        end
        
        function abort(obj)
            wasActive = obj.active;
            obj.active = false;
            
            delete(obj.hListeners);
            obj.hListeners = event.listener.empty();
            
            most.idioms.safeDeleteObj(obj.hWaitbar);
            
            if most.idioms.isValidObj(obj.hSI)
                obj.hSI.abort();
                
                if isprop(obj.hSI.hScan2D,'keepResonantScannerOn')
                    obj.hSI.hScan2D.keepResonantScannerOn = false;
                end
                
                obj.hSI.hBeams.enablePowerBox = false;
                obj.hSI.hStackManager.enable = false;
                
                obj.restorePmts();
                obj.restoreBeamPowerFractions();
                obj.restoreLoggingEnable();
            end
            
            if wasActive && ~isempty(obj.endScript)
                try
                    evalin('base',obj.endScript);
                catch ME
                    most.ErrorHandler.logAndReportError(ME,['Error occurred running end script: ' ME.message]);
                end
            end
        end
        
        function loadImageStack(obj,fileNames)
            if nargin < 2 || isempty(fileNames)
                [files,paths] = uigetfile('*.*','Select image files','MultiSelect','on');
                
                if isnumeric(files)
                    return
                end
                
                if ~iscell(files)
                    files = {files};
                    paths = {paths};
                end
                
                fileNames = fullfile(paths,files);
            end
            
            imageStack_ = cell(numel(fileNames),1);
            
            hWb = waitbar(0,'Loading images');
            
            try
                for idx = 1:numel(fileNames)
                    [data,map,transparency] = imread(fileNames{idx});
                    
                    if isinteger(data)
                        dataClass = class(data);
                        dataRange = single( [intmin(dataClass) intmax(dataClass)] );
                        
                        data = single(data);
                        data = (data - dataRange(1)) ./ diff(dataRange);
                    end
                    
                    data = mean(data,3);
                    
                    imageStack_{idx} = data;
                    
                    waitbar(idx/numel(fileNames),hWb);
                end
            catch ME
                most.idioms.safeDeleteObj(hWb);
                ME.rethrow();
            end
            
            most.idioms.safeDeleteObj(hWb);
            
            obj.imageStack = imageStack_;
        end
        
        function showImages(obj)
            hListeners_ = event.listener.empty();
            hListeners_(end+1) = most.ErrorHandler.addCatchingListener(obj,'ObjectBeingDestroyed',@(varargin)close);
            hListeners_(end+1) = most.ErrorHandler.addCatchingListener(obj,'imageStack','PostSet',@(varargin)showImage(1));
            
            hFig = most.idioms.figure('NumberTitle','off','Menubar','none','Name','Ablation Images','CloseRequestFcn',@(varargin)close,'WindowScrollWheelFcn',@scroll);
            hFlow = most.gui.uiflowcontainer('Parent',hFig,'FlowDirection','TopDown','margin',0.001);
                hRowFlow = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','LeftToRight','margin',0.001);
                    hAx = most.idioms.axes('Parent',hRowFlow,'Visible',false);
                hRowFlow = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','LeftToRight','margin',0.001,'HeightLimits',[20 20]);
                    uicontrol('Parent',hRowFlow,'String','Load Images','Callback',@(varargin)obj.loadImageStack);
            
            imageIdx = 1;
            hIm = [];
            showImage();
            
            function scroll(~,evt)
                imageIdx = imageIdx + sign(evt.VerticalScrollCount);
                showImage();
            end
            
            function showImage(idx)
                if nargin>0
                    imageIdx = idx;
                end
                
                numImages = numel(obj.imageStack);
                if numImages == 0
                    most.idioms.safeDeleteObj(hIm);
                    hAx.Visible = false;
                    return
                end

                imageIdx = max(min(numImages,imageIdx),1);
                hIm = imagesc(hAx,obj.imageStack{imageIdx});
                axis(hAx,'image');
                colormap(hFig,gray);
                hAx.CLim = [0,1];
                hAx.XTick = [];
                hAx.YTick = [];
                title(hAx,sprintf('%d/%d',imageIdx,numImages));
                xlabel('Use scroll wheel to flip through images');
            end
            
            function close()
                most.idioms.safeDeleteObj(hListeners_);
                most.idioms.safeDeleteObj(hFig);
            end
        end
    end
    
    methods
        function set.imageStack(obj,val)
            if isempty(val)
                val = {};
            else
                validateattributes(val,{'cell'},{'vector'});
                for idx = 1:numel(val)
                    validateattributes(val{idx},{'single','double'},{'2d','>=',0,'<=',1});
                end
            end
            
            obj.imageStack = val;
        end
        
        function set.numRepeats(obj,val)
            validateattributes(val,{'numeric'},{'positive','integer','scalar','nonnan','finite','real'});
            obj.numRepeats = val;
        end
        
        function set.zStep_um(obj,val)
            validateattributes(val,{'numeric'},{'scalar','nonnan','finite','real'});
            assert(val~=0,'zStep_um most not be zero');
            obj.zStep_um = val;
        end
        
        function val = get.hSI(obj)
            val = obj.hResourceStore.filterByClass('scanimage.SI');
            if isempty(val) || ~val{1}.mdlInitialized
                val = [];
            else
                val = val{1};
            end
        end
        
        function val = get.hFastZ(obj)
            hFastZs = obj.hSI.hScan2D.hFastZs;
            
            if isempty(hFastZs)
                val = [];
            else
                val = hFastZs{1};
            end
        end
        
        function set.startScript(obj,v)
            validateattributes(v,{'char'},{});
            obj.startScript = v;
        end
        
        function set.endScript(obj,v)
            validateattributes(v,{'char'},{});
            obj.endScript = v;
        end
        
        function set.stackMode(obj,val)
            val = most.idioms.string2Enum(val,'scanimage.types.StackMode'); 
            validateattributes(val,{'scanimage.types.StackMode'},{'scalar'});
            
            if obj.stackMode ~= val
                assert(~obj.active,'Cannot change stack mode while printing is active');
                obj.stackMode = val;
            end
        end

        function set.stackActuator(obj,val)
            val = most.idioms.string2Enum(val,'scanimage.types.StackActuator'); 
            validateattributes(val,{'scanimage.types.StackActuator'},{'scalar'});
            
            if obj.stackActuator ~= val
                assert(~obj.active,'Cannot change stack actuator while printing is active');
                obj.stackActuator = val;
            end
        end

        function set.beamPowerFractions(obj,val)
            if isempty(val)
                val = [];
            else
                nonnanmask = ~isnan(val);
                validateattributes(val(nonnanmask),{'numeric'},{'>=',0,'<=',1});
            end

            obj.beamPowerFractions = val(:)';
        end
    end
end

function s = defaultMdfSection()
s = [...
    most.HasMachineDataFile.makeEntry('startScript', '','Script that runs at the beginning of the Print')...
    most.HasMachineDataFile.makeEntry('endScript',   '','Script that runs at the end of the Print')...
    most.HasMachineDataFile.makeEntry('beamPowerFractions', [],'Power fractions used while illuminating sample')...
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
