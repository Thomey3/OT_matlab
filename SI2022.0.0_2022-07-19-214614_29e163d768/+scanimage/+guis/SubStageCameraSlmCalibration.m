classdef SubStageCameraSlmCalibration < most.Gui
    properties
        useFastZ = true;
        twoPhotonExcitation = true;
        allowSavingZCalibration = true;
    end
    
    properties (Hidden, SetAccess = private)
        hCameraWrapper
        
        hAx
        hScatterPlotCalibrated;
        hLinePlotUncalibrated;
        hLineSelectedPts;
        hTable;
        jTable;
        hStatusText;
        hStartButton;
        
        tableData = [];
        
        hCalibrationPoints = scanimage.guis.private.CalibrationPoint.empty(0,1);
        selectedPtIdx = [];
        
        started = false;
        abortFlag = false;
        
        cameraBackground = [];
        cameraThreshold = 0;
        
        hPbSaveZCalibration
    end
    
    properties (Dependent)
        hSlm
        hSlmScan
    end
    
    %% Lifecycle
    methods
        function obj = SubStageCameraSlmCalibration(hModel, hController)
            size = [200,50];
            obj = obj@most.Gui(hModel,hController,size,'characters');
            
            if ~isempty(obj.hModel.hCameraManager.hCameraWrappers)
                obj.hCameraWrapper = obj.hModel.hCameraManager.hCameraWrappers(1);
            end
        end
    end
    
    %% User methods
    methods
        function savePoints(obj,filePath)
            if isempty(obj.hCalibrationPoints)
                return
            end
            
            if nargin < 2 || isempty(filePath)
                [f, p] = uiputfile({'*.mat'},'Select calibration file.','Calibration Points.mat');
                if isequal(f,0)
                    return; % user abort
                end
                filePath = fullfile(p,f);
            end
            
            
            hWb = waitbar(0.1,'Saving calibration points');
            
            try
                calibrationPoints = arrayfun(@(pt)pt.toStruct(),obj.hCalibrationPoints,'UniformOutput',false);
                waitbar(0.2,hWb);
                save(filePath,'calibrationPoints');                
                waitbar(1,hWb);
                delete(hWb);
            catch ME
                most.idioms.safeDeleteObj(hWb);
                rethrow(ME);
            end
        end
        
        function loadPoints(obj,filePath)
            if nargin < 2 || isempty(filePath)
                [f, p] = uigetfile({'*.mat'},'Select calibration file.','Calibration Points.mat');
                if isequal(f,0)
                    return; % user abort
                end
                filePath = fullfile(p,f);
            end
            
            assert(exist(filePath,'file')>0,'File %s could not be accessed.',filePath);
            
            hWb = waitbar(0.1,'Loading calibration points');
            
            try
                S = load(filePath,'-mat');
                assert(isfield(S,'calibrationPoints'),'Could not find calibrationPoints in file');
                calibrationPoints = S.calibrationPoints;
                
                waitbar(0.2,hWb);
                
                hPoints = scanimage.guis.private.CalibrationPoint.empty(0,1);
                for idx = 1:numel(calibrationPoints)
                    hPoint = scanimage.guis.private.CalibrationPoint();
                    hPoint.fromStruct(calibrationPoints{idx});
                    hPoints(end+1) = hPoint;
                end
                
                waitbar(0.9,hWb);
                
                obj.clearCalibrationPoints();
                obj.hCalibrationPoints = hPoints;
                
                waitbar(1,hWb);
                delete(hWb);
            catch ME
                most.idioms.safeDeleteObj(hWb);
                rethrow(ME);
            end
        end
        
        function configurePointSet(obj)            
            type = questdlg('What type of calibration points?','Select type','Random','Grid','Cancel','Random');
            if ~any(strcmpi(type,{'random','grid'}))
                return
            end
            
            % default ranges:
            calibrationRangeX_um = obj.hSlm.scanDistanceRangeXYObjective(1) .* [-0.5 0.5];
            calibrationRangeY_um = obj.hSlm.scanDistanceRangeXYObjective(2) .* [-0.5 0.5];
            
            calibrationRangeXY_um = [max([calibrationRangeX_um(1) calibrationRangeY_um(1)]) min([calibrationRangeX_um(2) calibrationRangeY_um(2)])];
            calibrationRangeZ_um  = calibrationRangeXY_um;
            
            calibrationRangeXY_um = 100 * fix(calibrationRangeXY_um/100);
            calibrationRangeZ_um  = 100 * fix(calibrationRangeZ_um/100);
            
            
            switch lower(type)
                case 'grid'
                    answer = inputdlg({'Enter number of calibration points for [XY Z]','Enter SLM XY range (um):','Enter SLM Z range (um):','Enter radius of zero order beam block (um):'}, ...
                        'Enter calibration range',1, ...
                        {mat2str([100 10]), mat2str(calibrationRangeXY_um), mat2str(calibrationRangeZ_um), num2str(obj.hSlm.zeroOrderBlockRadius*1e6)});
                    
                    if isempty(answer)
                        % user cancellecd
                        return
                    end
                    
                    for idx = 1:numel(answer)
                        answer{idx} = eval(answer{idx});
                    end
                    
                    numPointsXY = answer{1}(1);
                    numPointsX = round(sqrt(numPointsXY));
                    numPointsY = round(sqrt(numPointsXY));
                    numPointsZ = answer{1}(2);
                    
                    numPoints = [numPointsX numPointsY numPointsZ];
                    ranges = vertcat(answer{2},answer{2},answer{3});
                    zeroOrderBlockRadius = answer{4};
                    
                case 'random'
                    answer = inputdlg({'Enter total number of calibration points','Enter SLM XY range (um):','Enter SLM Z range (um):','Enter radius of zero order beam block (um):'}, ...
                        'Enter calibration range',1, ...
                        {'1000', mat2str(calibrationRangeXY_um), mat2str(calibrationRangeZ_um), num2str(obj.hSlm.zeroOrderBlockRadius*1e6)});
                    
                    for idx = 1:numel(answer)
                        answer{idx} = eval(answer{idx});
                    end
                    
                    if isempty(answer)
                        % user cancellecd
                        return
                    end
                    
                    numPoints = answer{1};
                    ranges = vertcat(answer{2},answer{2},answer{3});
                    zeroOrderBlockRadius = answer{4};
            end
            
            obj.createCalibrationPointSet(type,numPoints,ranges,zeroOrderBlockRadius);
        end
        
        function createCalibrationPointSet(obj,type,numPoints,ranges,zeroOrderBlockRadius)            
            switch lower(type)
                case 'grid'
                    pts = grid();
                case 'random'
                    pts = randomSet();
                otherwise
                    error('Unknown point type: %s',type);
            end
            
            hPoints = scanimage.guis.private.CalibrationPoint.empty(0,1);
            for idx = 1:size(pts,1)
                pt = pts(idx,:);
                hPoints(end+1) = scanimage.guis.private.CalibrationPoint(pt); %#ok<AGROW>
            end
            
            obj.hCalibrationPoints = hPoints;
            
            function pts = randomSet()
                pts = zeros(0,3);
                
                while size(pts,1) < numPoints
                    pts_ = rand(numPoints-size(pts,1),3);
                    pts_ = pts_ .* diff(ranges,1,2)' + ranges(:,1)';                    
                    pts_ = round(pts_);
                    
                    % mask out zeroOrderDiameter
                    if zeroOrderBlockRadius
                        d = sqrt(sum(pts_.^2,2));
                        mask = d <= zeroOrderBlockRadius;
                        pts_(mask,:) = [];
                    end
                    pts = vertcat(pts,pts_);
                end
                
                % sort in z direction
                [~,idxs] = sort(pts(:,3));
                pts = pts(idxs,:);
            end
            
            function pts = grid()
                if isscalar(numPoints)
                    numPoints = repmat(numPoints,1,3);
                end
                
                xx = linspace(ranges(1,1),ranges(1,2),numPoints(1));
                yy = linspace(ranges(2,1),ranges(2,2),numPoints(2));
                zz = linspace(ranges(3,1),ranges(3,2),numPoints(3));
                
                [xx,yy,zz] = ndgrid(xx,yy,zz);
                pts = [xx(:), yy(:), zz(:)];
                
                if zeroOrderBlockRadius
                    d = sqrt(sum(pts.^2,2));
                    mask = d <= zeroOrderBlockRadius;
                    pts(mask,:) = [];
                end
            end
        end
        
        function resetCalibrationPoints(obj)
            arrayfun(@(cp)cp.reset(),obj.hCalibrationPoints);
            obj.updateGui();
        end
        
        function clearCalibrationPoints(obj)
            obj.hCalibrationPoints = scanimage.guis.private.CalibrationPoint.empty(0,1);
        end
        
        function calibrateCamera(obj)
            msg = sprintf('Measuring camera dark current.\nEnsure no light is reaching the camera sensor.');
            answer = questdlg(msg,'Camera dark current','OK','Cancel','OK');
            if ~strcmpi(answer,'OK')
                error('User aborted calibration routine.');
            end
            
            nFrames = 5;
            
            [images,saturated] = obj.grabCameraImages(nFrames);
            assert(~any(saturated),'Camera Image is saturated. Ensure no light reaches camera.');
            images = single(images);

            meanBgd = mean(images(:));
            stdBgd  =  std(images(:));
            
            obj.cameraBackground = mean(images,3);
            obj.cameraThreshold = meanBgd+3*stdBgd;
            obj.showCameraCalibration();
        end
        
        function resetCameraCalibration(obj)
            obj.cameraBackground = [];            
            obj.cameraThreshold = 0;
        end
        
        function showCameraCalibration(obj)
            assert(~isempty(obj.cameraBackground),'Camera is not calibrated');
            
            hFig_ = most.idioms.figure('NumberTitle','off','Name','Camera Background');
            hAx_1 = most.idioms.subplot(2,1,1,'Parent',hFig_);
            imagesc(hAx_1,obj.cameraBackground');
            axis(hAx_1,'image');
            colormap(hAx_1,gray());
            colorbar(hAx_1);
            
            if isprop(hAx_1,'ColorScale')
                hAx_1.ColorScale = 'log';
                title(hAx_1,'Camera Background [log color scale]');
            else
                title(hAx_1,'Camera Background');
            end
            
            
            hAx_2 = most.idioms.subplot(2,1,2,'Parent',hFig_);
            histogram(obj.cameraBackground(:),'Parent',hAx_2,'NumBins',150);
            hAx_2.YScale = 'log';
            title(hAx_2,'Histogram');
            xlabel(hAx_2,'Pixel Value');
            ylabel(hAx_2,'Pixel Count [log]');
            grid(hAx_2,'on');
        end
        
        function openCameraWindow(obj)
            hCtl = obj.hModel.hController{1};
            cameraGuis = hCtl.cameraGuis;
            
            mask = cellfun(@(cw)isequal(cw,obj.hCameraWrapper),{cameraGuis.hCameraWrapper});
            idx = find(mask,1,'first');
            
            if isempty(idx)
                error('No Camera Window available');
            end
            
            cameraGui = cameraGuis(idx);
            cameraGui.raise();
        end
        
        function configurePSF(obj)
            psfExtent = obj.hCalibrationPoints(1).psfExtent;
            psfNumSlices = obj.hCalibrationPoints(1).psfNumSlices;

            answer = inputdlg({'Enter Z range for measuring PSF [SLM um]','Enter number of slices for measuring PSF:'}, ...
                               'Point Spread Function Configuration',1, ...
                              {mat2str(psfExtent), num2str(psfNumSlices)});
            
            if isempty(answer)
                return
            end
            
            psfExtent = eval(answer{1});
            psfNumSlices = eval(answer{2});
            
            for idx = 1:numel(obj.hCalibrationPoints)
                hCalibrationPoint = obj.hCalibrationPoints(idx);
                
                hCalibrationPoint.psfExtent = psfExtent;
                hCalibrationPoint.psfNumSlices = psfNumSlices;
            end
        end
        
        function startCalibration(obj)
            assert (~obj.started,'Calibration is already running.');
            assert(~isempty(obj.hCalibrationPoints),'No set of calibration points is available');
            
            if isempty(obj.cameraBackground)
                answer = questdlg('The camera is not calibrated. Defective Pixels can invalidate calibration.',...
                         'Camera Calibration','Continue','Cancel','Cancel');
                switch answer
                    case 'Cancel'
                        return                        
                end
            end
            
            answer = questdlg('Which Z actuator should be used?','Select Actuator','FastZ','Stage','Cancel','FastZ');
            switch answer
                case 'FastZ'
                    obj.useFastZ = true;
                case 'Stage'     
                    obj.useFastZ = false;
                otherwise
                    return
            end
                
            obj.configurePSF();
            
            obj.abortFlag = false;
            obj.started = true;
            
            try
                obj.resetCalibrationPoints();
                
                hPoints = obj.hCalibrationPoints;

                % ensure the first two points in the series are the max and min
                % z point. We need to do this because the finding the first two
                % focal points is a manual procedure, and the points need to be
                % separated far enough.

                targetPts = vertcat(hPoints.slmTargetXYZ);
                targetZs = targetPts(:,3);

                [minZ,minZIdx] = min(targetZs);
                [maxZ,maxZIdx] = max(targetZs);

                hPointMinZ = hPoints(minZIdx);
                hPointMaxZ = hPoints(maxZIdx);

                hPoints([minZIdx, maxZIdx]) = [];
                hPoints = horzcat([hPointMinZ hPointMaxZ], hPoints(:)');
                
                if most.idioms.isValidObj(obj.hSlmScan.hLinScan)
                    obj.hSlmScan.hLinScan.pointScannerRef([0,0]);
                end
            
                for idx = 1:numel(hPoints)                    
                    if idx <= 3
                        updateStatus('Finding Point: %d (%d%%)',idx,round(idx/numel(hPoints)*100));
                        s = tic();
                    else
                        totalNumPoints = numel(hPoints)-3;
                        currentPoint = idx-3;
                        elapsedTime = toc(s);
                        timePerPoint = elapsedTime / currentPoint;
                        
                        timeRemaining_s = (totalNumPoints-currentPoint) * timePerPoint;
                        timeRemaining_h = floor(timeRemaining_s/60/60);
                        timeRemaining_m = ceil(mod(timeRemaining_s/60,60));
                        updateStatus('Calibrating Point: %d (%d%%) %dh %dm remaining',...
                            idx,round(idx/numel(hPoints)*100),timeRemaining_h,timeRemaining_m);
                    end
                    
                    obj.calibratePoint(hPoints(idx));
                    
                    obj.updateGui();
                    
                    drawnow('limitrate');
                    if obj.abortFlag
                        break;
                    end
                end            
            catch ME
                cleanup();
                rethrow(ME);
            end
            
            cleanup();
            
            function updateStatus(varargin)
                status = sprintf(varargin{:});
                obj.hStatusText.String = status;
            end
            
            function cleanup()
                obj.abortFlag = false;
                updateStatus('IDLE');
                obj.hSlmScan.hSlm.parkScanner();
                
                if most.idioms.isValidObj(obj.hSlmScan.hLinScan)
                    obj.hSlmScan.hLinScan.parkScanner();
                end
                
                obj.started = false;
            end
        end
        
        function abort(obj)
            obj.abortFlag = true;
        end
        
        function viewCalibration(obj)
            E = obj.createEfficiencyInterpolant();
            most.math.InterpolantPlot3D(E,[],'Excitation intensity',{'SLM X [um]','SLM Y [um]','SLM Z [um]','Intensity'});
        end
        
        function saveCalibration(obj)
            E = obj.createEfficiencyInterpolant();
            obj.hSlmScan.hSlm.hCSDiffractionEfficiency.fromParentInterpolant{1} = E;
            obj.saveCoordinateSystems();
            msgbox('Calibration saved successfully.','Success','help');
        end
        
        function viewSavedCalibration(obj)
            Es = obj.hSlmScan.hSlm.hCSDiffractionEfficiency.fromParentInterpolant;
            if isempty(Es) || isempty(Es{1})
                msgbox('No Calibration has been set in Scanimage.','Success','error');
                return
            end
            
            E = Es{1};
            most.math.InterpolantPlot3D(E,[],'Excitation intensity',{'SLM X [um]','SLM Y [um]','SLM Z [um]','Intensity'});
        end
        
        function resetCalibration(obj)
            obj.hSlmScan.hSlm.hCSDiffractionEfficiency.reset();
            obj.saveCoordinateSystems();
            msgbox('Calibration reset successfully.','Success','help');
        end
        
        function saveZCalibration(obj)
            hPoints = obj.hCalibrationPoints( [obj.hCalibrationPoints.calibrationValid] );
            assert(numel(hPoints) > 10,'Not enough valid calibration points to generate calibration.');
            
            stageZs = -vertcat(hPoints.stageZ); % during calibration slm and fastz/stage work in opposite directions
            
            slmXYZs = vertcat(hPoints.slmTargetXYZ);
            slmXYZs(:,3) = [hPoints.slmActualZ];
            
            modelterms = [...
                0 0 0; 1 0 0; 0 1 0; 0 0 1;...
                1 1 0; 1 0 1; 0 1 1 ; 1 1 1 ;...
                2 0 0; 0 2 0; 0 0 2;  ...
                2 0 1; 2 1 0; 0 2 1; 1 2 0; 0 1 2;  1 0 2;
                2 2 0; 2 0 2; 0 2 2; 2 1 1; 1 2 1; 1 1 2;];
            
            if ~obj.useFastZ
                % find stage reference
                slmXYZtoStageZ = most.math.polynomialInterpolant(slmXYZs,stageZs,modelterms);
                stageReference = slmXYZtoStageZ([0,0,0]);
                stageZs = stageZs - stageReference;
            end
            
            % create interpolants
            slmXYZtoStageZ = most.math.polynomialInterpolant(slmXYZs,stageZs,modelterms);
            stageXYZtoSlmZ = most.math.polynomialInterpolant([slmXYZs(:,1:2) stageZs],slmXYZs(:,3),modelterms);
            
            obj.hSlmScan.hCSSlmZAlignmentLut3D.toParentInterpolant = {[],[],slmXYZtoStageZ};
            obj.hSlmScan.hCSSlmZAlignmentLut3D.fromParentInterpolant = {[],[],stageXYZtoSlmZ};
            
            obj.saveCoordinateSystems();
        end
        
        function viewSavedZCalibration(obj)
            Zs = obj.hSlmScan.hCSSlmZAlignmentLut3D.fromParentInterpolant;
            if isempty(Zs) || isempty(Zs{3})
                msgbox('No Calibration has been set in Scanimage.','Success','error');
                return
            end
            
            Z = Zs{3};
            most.math.InterpolantPlot3D(Z,[],'SLM Z Calibration',{'SLM X [um]','SLM Y [um]','Stage Z [um]','SLM Z [um]'});
        end
        
        function resetZCalibration(obj)
            obj.hSlmScan.hCSSlmZAlignmentLut3D.reset();
            obj.saveCoordinateSystems();
        end
        
        function saveCoordinateSystems(obj)
            try
                obj.hSlmScan.hSI.hCoordinateSystems.save();
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
        end
        
        function E = createEfficiencyInterpolant(obj)
            hPoints = obj.hCalibrationPoints( [obj.hCalibrationPoints.calibrationValid] );
            assert(numel(hPoints) > 10,'Not enough valid calibration points to generate calibration.');
            
            mask = cellfun(@(i)~isempty(i),{hPoints.emission});
            hPoints = hPoints(mask);
            
            slmTargetXYZs = vertcat(hPoints.slmTargetXYZ);
            slmActualZs = vertcat(hPoints.slmActualZ);
            
            % convert to double for better calculation of gradients during
            % gradient ascent
            slmXYZs = double([slmTargetXYZs(:,1:2), slmActualZs]);
            emissions = double(vertcat(hPoints.emission));
            
            if obj.twoPhotonExcitation
                excitations = sqrt(emissions); % compensate for 2P effect
            else
                excitations = emissions;
            end
            
            modelterms = [...
                0 0 0; 1 0 0; 0 1 0; 0 0 1;...
                1 1 0; 1 0 1; 0 1 1; 1 1 1; 2 0 0; 0 2 0; 0 0 2];
            
            E = most.math.polynomialInterpolant(...
                slmXYZs,excitations,modelterms);
            
%             % find maximum using gradient ascent
%             [~,idx] = max(excitations);
%             initPt = slmXYZs(idx,:);
%             maxPt = gradientAscent(initPt);
%             maxExcitation = E(maxPt);

            maxExcitation = E([0 0 0]); % use zero order as power reference
            
            E.Points = single(E.Points);
            E.Values = single(E.Values./maxExcitation); % normalize diffraction efficiency by maximum Excitation
            
%             %% local function
%             function pt = gradientAscent(pt)
%                 d = 1e-6;
%                 
%                 maxIterations = 1e4;
%                 for iter = 1:maxIterations
%                     E_pt = E(pt);           
%                     E_pt_dx = E(pt + [d 0 0]);
%                     E_pt_dy = E(pt + [0 d 0]);
%                     E_pt_dz = E(pt + [0 0 d]);
%                     D = ([E_pt_dx E_pt_dy E_pt_dz] - E_pt) / d; % gradient
%                     
%                     %fprintf('iteration: %d, normD: %f D: %s pt: %s\n',iter,norm(D),mat2str(D),mat2str(pt));
%                     if norm(D) < 1e-5
%                         break;
%                     else
%                         pt = pt + D * 5;
%                     end
%                 end
%             end
        end
    end
    
    %% Internal Methods
    methods (Hidden)
        function calibratePoint(obj,hCalibrationPoint)
            % move motor to position
            hCalibrationPoint.reset();
            nextSlmXYZ = hCalibrationPoint.slmTargetXYZ;
            
            stageZ = getStageEstimate(hCalibrationPoint.slmTargetXYZ(3));
            
            if isempty(stageZ)
                obj.hSlmScan.hSlm.pointScanner(nextSlmXYZ);
                
                if obj.useFastZ
                    actuator = 'Fast Z';
                else
                    actuator = 'Stage Z';
                end
                
                obj.openCameraWindow();
                
                msg = sprintf('SLM is pointing to %s.\n\nUse %s controls to find focal point\non camera, then click OK.\n\nDo not to move X and Y stages.',mat2str(nextSlmXYZ),actuator);
                OK = most.gui.blockingMsgbox(msg,'Manual focus','help');
                
                if ~OK
                    error('User aborted calibration routine');
                end
            elseif isnan(stageZ)
                most.idioms.warn('Was not able to estimate valid stage Z for Calibration Point %s',mat2str(hCalibrationPoint.slmTargetXYZ));
                return
            else
                if obj.useFastZ
                    fastZ = obj.hModel.hFastZ.hFastZs{1};
                    fastZ.move(stageZ);
                else
                    obj.hModel.hMotors.moveSample([NaN NaN stageZ]);
                end
            end
            
            if obj.useFastZ
                stageZ = obj.hModel.hFastZ.position; % read position back
            else
                stageZ = obj.hModel.hMotors.samplePosition(3); % read position back
            end
            
            hCalibrationPoint.stageZ = stageZ;
            hCalibrationPoint.fastZ = obj.useFastZ;
            
            nextSlmXYZ = hCalibrationPoint.getNextSlmStep();
            
            while ~isempty(nextSlmXYZ)
                obj.hSlmScan.hSlm.pointScanner(nextSlmXYZ);
                pause(0.01); % wait for SLM to settle
                
                nFrames = 5;
                [images,saturated] = obj.grabCameraImages(nFrames);
                images = single(images);
                image = mean(images,3);
                saturated = any(saturated);

                if isempty(obj.cameraBackground)
                    most.idioms.warn('Cannot subtract camera background. No camera background data is available.');
                else
                    image = image - single(obj.cameraBackground);
                end
                
                hCalibrationPoint.addCameraImage(nextSlmXYZ,image,saturated);
                nextSlmXYZ = hCalibrationPoint.getNextSlmStep();
                
                drawnow('limitrate');
                
                if obj.abortFlag()
                    hCalibrationPoint.reset();
                    return;
                end
            end
            
            hCalibrationPoint.finalize();
            
            if hCalibrationPoint.calibrationValid && hCalibrationPoint.emission < obj.cameraThreshold
                % this point is below the noise threshold. ignore
                most.idioms.warn('Emission for point %s is within noise floor.',mat2str(hCalibrationPoint.slmTargetXYZ));
                hCalibrationPoint.invalidate();
            end
                
            %%% local function
            function stageZ = getStageEstimate(slmActualZ)
                validMask = [obj.hCalibrationPoints.calibrationValid];
                hCalibPoints = obj.hCalibrationPoints(validMask);
                
                slmActualZs = [hCalibPoints.slmActualZ]';
                stageZs = [hCalibPoints.stageZ]';
                
                [~,idxs] = unique(slmActualZs);
                
                slmActualZs = slmActualZs(idxs);
                stageZs = stageZs(idxs);
                
                if numel(slmActualZs) < 2
                    stageZ = [];
                else
                    stageZ = interp1(slmActualZs(idxs),stageZs(idxs),slmActualZ,'linear','extrap');
                end
            end
        end
        
        function [images,saturated] = grabCameraImages(obj,nFrames)
            if nargin < 2 || isempty(nFrames)
                nFrames = 1;
            end
            
            hCamera = obj.hCameraWrapper.hDevice;
            maxIntVal = intmax(hCamera.datatype);
            
            wasAcquiring = hCamera.isAcquiring;
            
            if ~wasAcquiring
                hCamera.start();
            end
            
            hCamera.flush(); % flush buffer
            
            try 
                images = cell(0,1);
                timeout = 10;
                
                s = tic();
                while numel(images)<nFrames && toc(s) < timeout
                    [data,meta] = hCamera.getAcquiredFrames();
                    images = vertcat(images,data(:));
                    
                    if isempty(data)
                        pause(0.01);
                    end
                end
            catch ME
                if hCamera.isAcquiring
                    hCamera.stop();
                end
                rethrow(ME);
            end
            
            if ~wasAcquiring
                hCamera.stop();
            end
            
            images(nFrames+1:end) = []; % truncate additional frames
            assert(numel(images)==nFrames,'Acquiring %d images timed out',nFrames);
            
            % remove singular dimensions; video driver returns images 
            % with dimensions [color,x,y]; color dimension needs to be removed
            images = cellfun(@(im)squeeze(im),images,'UniformOutput',false);
            
            images = cat(3,images{:});
            saturated = squeeze(any(any(images==maxIntVal,1),2));
        end
    end
    
    %% GUI
    methods (Access = protected)
        function initGui(obj)
            obj.hFig.Name = 'SLM Efficiency Calibration';
            
            if isempty(obj.hSlmScan)
                uicontrol('Parent',obj.hFig,'Style','text','String','No SLM found in system','HorizontalAlignment','center','Units','normalized','Position',[0 0 1 1]);
                return
            end
            
            if isempty(obj.hModel.hCameraManager.hCameraWrappers)
                uicontrol('Parent',obj.hFig,'Style','text','String','No Camera found in system','HorizontalAlignment','center','Units','normalized','Position',[0 0 1 1]);
                return
            end
            
            mainFlow = most.gui.uiflowcontainer('Parent', obj.hFig,'FlowDirection','LeftToRight');
                leftFlow = most.gui.uiflowcontainer('Parent', mainFlow,'FlowDirection','TopDown');
                    axFlow = most.gui.uiflowcontainer('Parent', leftFlow,'FlowDirection','LeftToRight');
                    viewPanelFlow = most.gui.uiflowcontainer('Parent', leftFlow,'FlowDirection','LeftToRight');
                        set(viewPanelFlow,'HeightLimits',[50,50]);
                        hViewButtonPanel = uipanel('Parent',viewPanelFlow,'Title','Standard Views');
                            viewButtonFlow = most.gui.uiflowcontainer('Parent',hViewButtonPanel,'FlowDirection','LeftToRight');
                rightFlow = most.gui.uiflowcontainer('Parent', mainFlow,'FlowDirection','TopDown');
                    set(rightFlow,'WidthLimits',[400 400]);
                    topPanelFlow = most.gui.uiflowcontainer('Parent', rightFlow,'FlowDirection','LeftToRight');
                        hPtPanel = uipanel('Parent',topPanelFlow,'Title','Configuration Points');
                            hPtPanelFlow = most.gui.uiflowcontainer('Parent',hPtPanel,'FlowDirection','TopDown');
                                ptButtonFlow = most.gui.uiflowcontainer('Parent',hPtPanelFlow,'FlowDirection','LeftToRight');
                                set(ptButtonFlow,'HeightLimits',[30,30]);
                                tableFlow = most.gui.uiflowcontainer('Parent',hPtPanelFlow,'FlowDirection','LeftToRight');
                    statusPanelFlow = most.gui.uiflowcontainer('Parent', rightFlow,'FlowDirection','LeftToRight');
                        set(statusPanelFlow,'HeightLimits',[45 45]);
                        hStatusPanel = uipanel('Parent',statusPanelFlow,'Title','Status');
                            hStatusFlow = most.gui.uiflowcontainer('Parent', hStatusPanel,'FlowDirection','TopDown');
                    bottomPanelFlow = most.gui.uiflowcontainer('Parent', rightFlow,'FlowDirection','LeftToRight');
                        set(bottomPanelFlow,'HeightLimits',[200 200]);
                        bottomPanelFlowV = most.gui.uiflowcontainer('Parent', bottomPanelFlow,'FlowDirection','TopDown');
                            hCameraPanel = uipanel('Parent',bottomPanelFlowV,'Title','Camera');
                                hCameraPanelFlow = most.gui.uiflowcontainer('Parent', hCameraPanel,'FlowDirection','TopDown');
                                    hCameraButtonFlow = most.gui.uiflowcontainer('Parent', hCameraPanelFlow,'FlowDirection','LeftToRight');
                            hCalibrationPanel = uipanel('Parent',bottomPanelFlowV,'Title','SLM Calibration');
                                hCalibrationPanelFlow = most.gui.uiflowcontainer('Parent', hCalibrationPanel,'FlowDirection','TopDown');
                                    hCalibrationButtonFlow = most.gui.uiflowcontainer('Parent', hCalibrationPanelFlow,'FlowDirection','LeftToRight');
                            hSIPanel = uipanel('Parent',bottomPanelFlowV,'Title','ScanImage');
                            set(hSIPanel,'HeightLimits',[80 80]);
                                hSIPanelFlow = most.gui.uiflowcontainer('Parent', hSIPanel,'FlowDirection','TopDown');
                                    hSIButtonFlow = most.gui.uiflowcontainer('Parent', hSIPanelFlow,'FlowDirection','LeftToRight');
                                    hSIButtonFlow2 = most.gui.uiflowcontainer('Parent', hSIPanelFlow,'FlowDirection','LeftToRight');
            
            obj.initPlots(axFlow);
            obj.hTable = uitable('Parent',tableFlow,'CellEditCallback',@obj.tableEdit);
            obj.hTable.ColumnName = {'Sel','Target XYZ','Calibrated','Emission'};
            obj.hTable.ColumnEditable  = [true false false false];
            obj.hTable.ColumnWidth = {'auto' 120 'auto' 'auto'};            
            
            uicontrol('Parent',viewButtonFlow,'String','Top',      'Callback',@(varargin)obj.view('top'));
            uicontrol('Parent',viewButtonFlow,'String','Front',    'Callback',@(varargin)obj.view('front'));
            uicontrol('Parent',viewButtonFlow,'String','Left',     'Callback',@(varargin)obj.view('left'));
            uicontrol('Parent',viewButtonFlow,'String','Isometric','Callback',@(varargin)obj.view('isometric'));
            
            uicontrol('Parent',ptButtonFlow,'String','Generate','Callback',@(varargin)obj.configurePointSet);
            uicontrol('Parent',ptButtonFlow,'String','Clear', 'Callback',@(varargin)obj.clearCalibrationPoints);
            uicontrol('Parent',ptButtonFlow,'String','Save',  'Callback',@(varargin)obj.savePoints);
            uicontrol('Parent',ptButtonFlow,'String','Load',  'Callback',@(varargin)obj.loadPoints);
            
            cameraNames = obj.getSICameraNames();
            if isempty(cameraNames)
                cameraNames = {''};
            end
            uicontrol('Parent',hCameraButtonFlow,'Style','popupmenu','String',cameraNames,'Callback',@selectCamera);
            uicontrol('Parent',hCameraButtonFlow,'String','Open Window','Callback',@(varargin)obj.openCameraWindow);
            uicontrol('Parent',hCameraButtonFlow,'String','Calibrate','Callback',@(varargin)obj.calibrateCamera);
            uicontrol('Parent',hCameraButtonFlow,'String','Show Background','Callback',@(varargin)obj.showCameraCalibration);
            
            obj.hStartButton = uicontrol('Parent',hCalibrationButtonFlow,'String','Start Calibration','Callback',@(varargin)obj.toggleStarted);
            uicontrol('Parent',hCalibrationButtonFlow,'String','Reset Points', 'Callback',@(varargin)obj.resetCalibrationPoints);
            uicontrol('Parent',hCalibrationButtonFlow,'String','View Calibration','Callback',@(varargin)obj.viewCalibration);
            
            uicontrol('Parent',hSIButtonFlow,'String','Save Calibration','Callback',@(varargin)obj.saveCalibration);
            uicontrol('Parent',hSIButtonFlow,'String','View Saved Calibration','Callback',@(varargin)obj.viewSavedCalibration);
            uicontrol('Parent',hSIButtonFlow,'String','Reset Saved Calibration','Callback',@(varargin)obj.resetCalibration);
            
            obj.hPbSaveZCalibration = uicontrol('Parent',hSIButtonFlow2,'String','Save Z Calibration','Callback',@(varargin)obj.saveZCalibration);
            uicontrol('Parent',hSIButtonFlow2,'String','View Saved Z Calibration','Callback',@(varargin)obj.viewSavedZCalibration);
            uicontrol('Parent',hSIButtonFlow2,'String','Reset Saved Z Calibration','Callback',@(varargin)obj.resetZCalibration);
            
            obj.hStatusText = uicontrol('Parent',hStatusFlow,'Style','text','String','IDLE','FontWeight','bold');
            
            drawnow();
            
            jscrollpane = javaObjectEDT(most.gui.findjobj(obj.hTable));
            viewport    = javaObjectEDT(jscrollpane.getViewport);
            obj.jTable  = javaObjectEDT( viewport.getView );
            
            obj.updateGui();
            obj.view('isometric');
            
            function selectCamera(src,evt)
                hCameraWrappers = obj.hModel.hCameraManager.hCameraWrappers;
                if isempty(hCameraWrappers)
                    % no camera in system
                    return
                end
                
                cameraName = src.String{src.Value};
                SICameraNames = obj.getSICameraNames();
                
                mask = strcmp(cameraName,SICameraNames);
                obj.hCameraWrapper = obj.hModel.hCameraManager.hCameraWrappers(mask);
            end
        end
    end
    
    methods (Access = private)
        function initPlots(obj,hParent)
            obj.hAx = most.idioms.axes('Parent',hParent);
            
            obj.hScatterPlotCalibrated = scatter3(NaN,NaN,NaN,'Parent',obj.hAx,'filled','ButtonDownFcn',@obj.clickedPt);
            
            obj.hLinePlotUncalibrated = line('Parent',obj.hAx,'XData',[],'YData',[],'ZData',[]);
            obj.hLinePlotUncalibrated.Marker = 'o';
            obj.hLinePlotUncalibrated.LineStyle = 'none';
            obj.hLinePlotUncalibrated.Color = [0 0.4470 0.7410];
            obj.hLinePlotUncalibrated.ButtonDownFcn = @obj.clickedPt;
            
            obj.hLineSelectedPts = line('Parent',obj.hAx,'XData',NaN,'YData',NaN,'ZData',NaN);
            obj.hLineSelectedPts.Marker = 'o';
            obj.hLineSelectedPts.LineStyle = 'none';
            obj.hLineSelectedPts.Color = 'white';
            obj.hLineSelectedPts.LineWidth = 4;
            obj.hLineSelectedPts.MarkerSize = 13;
            obj.hLineSelectedPts.HitTest = 'off';
            obj.hLineSelectedPts.PickableParts = 'none';
            
            obj.hAx.Color = [0 0 0];
            obj.hAx.GridColor = [1 1 1];
            obj.hAx.ButtonDownFcn = @(varargin)obj.startdrag(@obj.orbit);
            obj.hAx.DataAspectRatio = [1 1 1];
            
            xlabel(obj.hAx,'SLM X [um]');
            ylabel(obj.hAx,'SLM Y [um]');
            zlabel(obj.hAx,'SLM Z [um]');
        end
        
        function updateGui(obj)
            % sanity check
            if ~isempty(obj.selectedPtIdx) && ...
                    obj.selectedPtIdx > numel(obj.hCalibrationPoints)
                obj.selectedPtIdx = [];
                return
            end
            
            obj.updateTable();
            obj.updatePlot();
        end
        
        function updatePlot(obj)
            slmTargetXYZ = vertcat(obj.hCalibrationPoints.slmTargetXYZ);
            emission = {obj.hCalibrationPoints.emission}';
            emissionEmptyMask = cellfun(@(e)isempty(e),emission);
            emission(emissionEmptyMask) = {NaN};
            emission = vertcat(emission{:});
            
            calibrationValidMask = [obj.hCalibrationPoints.calibrationValid]';
            emission(~calibrationValidMask) = NaN;
            dataAvailableMask = [obj.hCalibrationPoints.dataAvailable]';
            
            limits = [];
            if ~isempty(slmTargetXYZ)
                limits = max(abs(slmTargetXYZ),[],1);
                limits = ceil(limits * 1.3);
                
                limit = max(limits(1:2));
                limits = [-1 1] * limit;
                
                if diff(limits)<=0
                    limits = [];
                end
            end
            
            if isempty(limits)
                obj.hAx.XLimMode = 'auto';
                obj.hAx.YLimMode = 'auto';
                obj.hAx.ZLimMode = 'auto';
            else
                obj.hAx.XLim = limits;
                obj.hAx.YLim = limits;
                obj.hAx.ZLim = limits;
            end
            
            if any(dataAvailableMask)
                slmTargetXYZDataAvailable = slmTargetXYZ;
                slmTargetXYZDataAvailable(~dataAvailableMask,:) = [];                
                colors = colorMap(emission(dataAvailableMask));
            else
                slmTargetXYZDataAvailable = [NaN NaN NaN];
                colors = [0 0 0];
            end
            
            obj.hScatterPlotCalibrated.XData = slmTargetXYZDataAvailable(:,1);
            obj.hScatterPlotCalibrated.YData = slmTargetXYZDataAvailable(:,2);
            obj.hScatterPlotCalibrated.ZData = slmTargetXYZDataAvailable(:,3);
            obj.hScatterPlotCalibrated.CData = colors;
            
            if any(~dataAvailableMask)
                slmTargetXYZNoData = slmTargetXYZ;
                slmTargetXYZNoData(dataAvailableMask,:) = [];
            else
                slmTargetXYZNoData = [NaN NaN NaN];
            end
            
            obj.hLinePlotUncalibrated.XData = slmTargetXYZNoData(:,1);
            obj.hLinePlotUncalibrated.YData = slmTargetXYZNoData(:,2);
            obj.hLinePlotUncalibrated.ZData = slmTargetXYZNoData(:,3);
            
            if isempty(obj.selectedPtIdx)
                pt = [NaN NaN NaN];
            else
                pt = slmTargetXYZ(obj.selectedPtIdx,:);
            end
            
            obj.hLineSelectedPts.XData = pt(1);
            obj.hLineSelectedPts.YData = pt(2);
            obj.hLineSelectedPts.ZData = pt(3);
            
            %%% local function
            function colors = colorMap(emission)                
                maxEmission = max(emission,[],'omitnan');
                minEmission = min(emission,[],'omitnan');
                
                if maxEmission == minEmission
                    minEmission = maxEmission - 1;
                end
                
                map = parula();
                
                colors = zeros(numel(emission),3);
                for idx = 1:numel(emission)
                    if isnan(emission(idx))
                        colors(idx,:) = [1 0 0];
                    else
                        frac = (emission(idx)-minEmission) / (maxEmission-minEmission);
                        mapIdx = round ( (frac) * (size(map,1)-1) + 1 );
                        mapIdx = min(max(mapIdx,1),size(map,1));
                        colors(idx,:) = map(mapIdx,:);
                    end
                end
            end
        end
        
        function view(obj,direction)
            switch lower(direction)
                case 'top'
                    view(obj.hAx,0,-90);
                case 'front'
                    view(obj.hAx,0,180);
                case 'left'
                    view(obj.hAx,90,180);
                case 'isometric'
                    view(obj.hAx,135,-10);
                    obj.hAx.CameraUpVector = [0 0 -1];
                otherwise
                    error('Unknown view: %s',direction);
            end
        end
        
        function clickedPt(obj,src,evt)
            coords = evt.IntersectionPoint;
            slmTargetXYZ = vertcat(obj.hCalibrationPoints.slmTargetXYZ);
            d = bsxfun(@minus,coords,slmTargetXYZ);
            d = sqrt(sum(d.^2,2));
            
            [~,newSelection] = min(d);
            oldSelection = obj.selectedPtIdx;
            
            obj.selectedPtIdx = newSelection;
            
            if isequal(oldSelection,newSelection)
                % double click
                hPoint = obj.hCalibrationPoints(obj.selectedPtIdx);
                if hPoint.dataAvailable
                    hPoint.plot();
                end
            end
        end
        
        function startdrag(obj,dragtype)
            pt = obj.getPoint();
            dragdata = struct(...
                'figStartPoint',pt,...
                'figLastPoint',pt,...
                'WindowButtonMotionFcn',obj.hFig.WindowButtonMotionFcn,...
                'WindowButtonUpFcn',obj.hFig.WindowButtonUpFcn);
            obj.hFig.WindowButtonMotionFcn = @(src,evt)motion(dragtype,src,evt);
            obj.hFig.WindowButtonUpFcn = @stopdrag;
            
            function motion(dragtype,varargin)
                pt = obj.getPoint();
                deltaPix = pt - dragdata.figLastPoint;
                dragdata.figLastPoint = pt;
                dragtype(deltaPix);
            end
            
            function stopdrag(varargin)
                obj.hFig.WindowButtonMotionFcn = dragdata.WindowButtonMotionFcn;
                obj.hFig.WindowButtonUpFcn = dragdata.WindowButtonUpFcn;
            end
        end
        
        function orbit(obj,deltaPix)
            camorbit(obj.hAx,deltaPix(1),-deltaPix(2),'data',[0 0 1])
        end
        
        function pt = getPoint(obj)
            pt = hgconvertunits(obj.hFig,[0 0 obj.hFig.CurrentPoint],...
				obj.hFig.Units,'pixels',0);
            pt = pt(3:4);
        end
        
        function updateTable(obj)
            selected = false(numel(obj.hCalibrationPoints),1);            
            selected(obj.selectedPtIdx) = true;
            selected = num2cell(selected);
            
            slmTargetXYZ = {obj.hCalibrationPoints.slmTargetXYZ};
            slmTargetXYZ = cellfun(@(m)sprintf('[%g %g %g]',m(1),m(2),m(3)),slmTargetXYZ,'UniformOutput',false)';
            
            calibrationValid = [obj.hCalibrationPoints.calibrationValid]';
            calibrationValid = num2cell(calibrationValid);
            
            emission = {obj.hCalibrationPoints.emission};
            emission = cellfun(@(i)sprintf('%g',i),emission,'UniFormOutput',false)';
            
            newData = [selected,slmTargetXYZ,calibrationValid,emission];
            
            if ~isequal(obj.tableData,newData)
                selectedRow = obj.jTable.getSelectedRows();
                
                obj.hTable.Data = newData;
                obj.tableData = newData;
                
                drawnow('nocallbacks');
                                
                if ~isempty(selectedRow)
                    %obj.jTable.setRowSelectionInterval(selectedRow,selectedRow);
                    obj.jTable.scrollRowToVisible(selectedRow);
                elseif ~isempty(obj.selectedPtIdx)
                    obj.jTable.scrollRowToVisible(obj.selectedPtIdx);
                end
            end
        end
        
        function tableEdit(obj,src,evt)
            idx = evt.Indices(1);
            
            obj.tableData{evt.Indices(1),evt.Indices(2)} = evt.NewData;
            
            if evt.NewData
                obj.selectedPtIdx = idx;
            else
                obj.selectedPtIdx = [];
            end
        end
        
        function toggleStarted(obj)
            if obj.started
                obj.abort();
            else
                obj.startCalibration();
            end
        end
        
        function cameraNames = getSICameraNames(obj)
            cameraNames = arrayfun(@(w)w.cameraName,obj.hModel.hCameraManager.hCameraWrappers,'UniformOutput',false);
        end
    end
    
    %% Property getter/setter
    methods
        function set.allowSavingZCalibration(obj,val)
            validateattributes(val,{'numeric','logical'},{'scalar','binary'});
            obj.allowSavingZCalibration = val;
            
            if val
                obj.hPbSaveZCalibration.Enable = 'on';
            else
                obj.hPbSaveZCalibration.Enable = 'off';
            end
        end
        
        function set.useFastZ(obj,val)
            validateattributes(val,{'numeric','logical'},{'scalar','binary'});
            
            obj.useFastZ = logical(val);
        end
        
        function set.twoPhotonExcitation(obj,val)
            validateattributes(val,{'numeric','logical'},{'scalar','binary'});
            
            obj.twoPhotonExcitation = logical(val);
        end
        
        function set.hCalibrationPoints(obj,val)
            if isempty(val)
                val = scanimage.guis.private.CalibrationPoint.empty(0,1);
            else
                validateattributes(val,{'scanimage.guis.private.CalibrationPoint'},{'vector'});
            end
            
            if ~isempty(obj.selectedPtIdx) && obj.selectedPtIdx > numel(val)
                obj.selectedPtIdx = [];
            end
            
            obj.hCalibrationPoints = val;
            obj.updateGui();
            obj.view('isometric');
        end
        
        function set.selectedPtIdx(obj,val)            
            if ~isempty(val)
                validateattributes(val,{'numeric'},{'scalar','positive','integer'});
                assert(val<=numel(obj.hCalibrationPoints));
            end
            
            obj.selectedPtIdx = val;
            obj.updateGui();
        end
        
        function set.started(obj,val)
            obj.started = val;
            
            if obj.started
                obj.hStartButton.String = 'Abort';
                obj.hStartButton.BackgroundColor = most.constants.Colors.lightRed;
            else
                obj.hStartButton.String = 'Start Calibration';
                obj.hStartButton.BackgroundColor = most.constants.Colors.lightGray;
            end            
        end
        
        function set.hCameraWrapper(obj,val)            
            oldVal = obj.hCameraWrapper;
            
            if ~strcmp(oldVal,val)
                assert(~obj.started,'Cannot change camera while calibration is running.');
                obj.hCameraWrapper = val;
                obj.resetCameraCalibration();
            end
        end
        
        function val = get.hSlmScan(obj)
            val = obj.hModel.hSlmScan;
        end
           
        function val = get.hSlm(obj)
            if isempty(obj.hSlmScan)
                val = [];
            else
                val = obj.hSlmScan.hSlm;
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
