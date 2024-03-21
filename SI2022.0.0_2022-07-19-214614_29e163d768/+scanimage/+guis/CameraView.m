classdef CameraView < most.Gui
    properties(SetObservable)
        live = 0;
        refreshRate = 20;   % in Hertz
        enableRois = false; % toggle for ROI viewing
        enableCrosshair = false; %toggle for camera surface crosshair
        estimateMotion = false;
    end
    
    properties(SetObservable, Hidden)
        hCameraWrapper;     % Handle to current CameraWrapper
        refUndocked = false;
    end
    
    properties(SetObservable, Dependent)
        blackLevel;
        blackLevelNormal; % black level scaled to 0..1
        whiteLevel;               
        whiteLevelNormal; % white level scaled to 0..1
        roiAlpha;
        refAlpha;
    end
    
    properties(Hidden)
        channelIdx;         % ROI Channel Index
        hAxes;              % Handle to figure Axes
        hPixelDatatype;     % Handle to pixel type popupmenu
        hBlackLevelSlider;  % black level slider
        hWhiteLevelSlider;  % white level slider
        hCameraOutline;     % Handle to Camera Surface Outline
        hCameraRefGroup;    % Handle to group holding ref surface and ref xHairRef
        hCameraSurf;        % Handle to Camera Surface
        hCameraRefColor;    % Handle to Camera Reference Color Selection
        hCameraRefFig;      % Handle to Camera Reference Figure
        hCameraRefSurf = matlab.graphics.primitive.Surface.empty(0,1); % Handle to Reference Camera Surface
        hCameraRefSel;      % Handle to Camera Reference Selection
        hCameraRefDockToggle; % Handle to Camera Reference Dock/Undock Toggle
        hMotionEntries;
        hListeners = event.listener.empty;
        hLiveHistograms = scanimage.mroi.LiveHistogram.empty;       % Handle to live histograms
        hLiveHistogramListeners = event.listener.empty;             %listeners to histogram lut
        hLiveToggle;        % Handle to live togglebutton control
        hRefSpace;          % Handle to RefSpace dropdown uicontrol
        hRefTogglable = most.gui.uicontrol.empty(0,1);              % list of handles dependent on hCameraRefSel
        hRoiOutline = matlab.graphics.primitive.Line.empty(0,1);    % Handle to Roi outline
        hRoiSurface = matlab.graphics.primitive.Surface.empty(0,1); % Handle to Roi Surface
        hRoiTogglable = most.gui.uicontrol.empty(0,1);              % list of handles dependent on enableRois
        hStatusBar = most.gui.uicontrol.empty(0,1);
        hTable;             % uitable
        refImg;             % Reference Image Data
        scaleRefImg = true; % specifies if reference image is scaled with lut
        refSpace;           % should be a value in REFSPACE
        zRoi;               % Roi Z position Index
        hXhair;            % Handle array for crosshair on camera surface
        hXhairRef;         % Handle array for crosshair on reference surface
        hXhairMenu;         % Handle to menu toggling crosshair on camera surface
        hFlipHMenu;         % Handle to menu flipping view horizontally
        hFlipVMenu;         % Handle to menu flipping view vertically
        hRotateMenu;        % Handle to menu rotating view
        hMotionEstimator;   % Handle to motion estimator for reference data
        hDummyRoi;          % Dummy Roi used for motion estimator
        displayToRefTransform = eye(3);
        prevSavePath = '.';
    end
    
    properties(Hidden, SetAccess=private)
        fovPos_Ref;
        panPos_Ref = [0 0]; % current camera pan location
        fovFit_Ref;
        posFit_Ref;
        refSelPrevIdx = 1;
    end
    
    properties(Constant, Access=private)
        LUT_AUTOSCALE_SATURATION_PERCENTILE = [.1 .01];
        REFSPACES = {'Camera' 'ROI'};
        COLORSELECT = {'Gray' 'Red' 'Green' 'Blue'};
        ZOOMSCALE = 1.2; %scaling constant used for zoom calculation
        REFSELEXTRA = {'None';'Browse...'};
    end
    
    %% LIFECYCLE
    methods
        function obj = CameraView(hModel, hController, hWrapper)
            if nargin < 1
                hModel = [];
            end
            
            if nargin < 2
                hController = [];
            end
            
            resolution = [800 600];
            obj = obj@most.Gui(hModel, hController, resolution);
            
            if nargin < 3
                hWrapper = [];
            end
            
            obj.hCameraWrapper = hWrapper;
            obj.hCameraWrapper.hCameraView = obj;
            obj.hCameraRefSurf = [];
            obj.channelIdx = 1;
            obj.zRoi = 1;
            obj.refSpace = 'Camera';
            
            obj.hDummyRoi = scanimage.mroi.Roi();
            scanfield = scanimage.mroi.scanfield.fields.RotatedRectangle();
            scanfield.pixelResolutionXY = obj.hCameraWrapper.hDevice.resolutionXY;
            obj.hDummyRoi.add(0,scanfield);
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hCameraRefFig);
            most.idioms.safeDeleteObj(obj.hTable);
            most.idioms.safeDeleteObj(obj.hListeners);
            most.idioms.safeDeleteObj(obj.hLiveHistograms);
            most.idioms.safeDeleteObj(obj.hLiveHistogramListeners);
        end
    end
    
    %% GUI
    methods
        function val = get.roiAlpha(obj)
            val = obj.hCameraWrapper.roiAlpha;
        end
        
        function set.roiAlpha(obj, val)
            if ischar(val)
                val = str2double(val);
            end
            obj.hCameraWrapper.roiAlpha = val;
            obj.roiLutChanged(obj.channelIdx);
        end
        
        function val = get.refAlpha(obj)
            val = obj.hCameraWrapper.refAlpha;
        end
        
        function set.refAlpha(obj, val)
            if ischar(val)
                val = str2double(val);
            end
            
            obj.hCameraWrapper.refAlpha = val;
            if ~isempty(obj.hCameraRefSurf) && ~obj.refUndocked
                obj.hCameraRefSurf.FaceAlpha = val;
            end
        end
        
        function val = get.blackLevel(obj)
            val = obj.hCameraWrapper.lut(1);
        end
        
        function set.blackLevel(obj, val)
            if obj.whiteLevel <= val
                return;
            end
            if ischar(val)
                val = str2double(val);
            end
            obj.hCameraWrapper.lut(1) = val;
            obj.updateHistogramLut();
            set(obj.hBlackLevelSlider(2), 'Value', obj.blackLevelNormal); % update slider gui
        end
        
        function val = get.blackLevelNormal(obj)
            pixelType = obj.hCameraWrapper.hDevice.datatype;
            val = (obj.blackLevel - pixelType.getMinValue()) /...
                (pixelType.getMaxValue() - pixelType.getMinValue());
        end
        
        function set.blackLevelNormal(obj, val)
            pixelType = obj.hCameraWrapper.hDevice.datatype;
            obj.blackLevel = val * (pixelType.getMaxValue() - pixelType.getMinValue()) +...
                pixelType.getMinValue();
        end
        
        function buttonDownCallback(obj)
            if strcmp(obj.hFig.SelectionType, 'normal')
                obj.startPan();
            end
        end
        
        function startPan(obj)
            previousMousePoint = getCurrentMousePoint();
            WindowButtonMotionFcn = obj.hFig.WindowButtonMotionFcn;
            WindowButtonUpFcn = obj.hFig.WindowButtonMotionFcn;
            
            obj.hFig.WindowButtonMotionFcn = @move;
            obj.hFig.WindowButtonUpFcn = @abort;
            
            function move(varargin)
                try
                    mousePoint = getCurrentMousePoint();
                    obj.panPos_Ref = obj.panPos_Ref + previousMousePoint - mousePoint;
                    obj.updateView();
                    previousMousePoint = getCurrentMousePoint();
                catch ME
                    abort();
                    rethrow(ME);
                end
            end
            
            function abort(varargin)
                obj.hFig.WindowButtonMotionFcn = WindowButtonMotionFcn;
                obj.hFig.WindowButtonMotionFcn = WindowButtonUpFcn;
            end
            
            function spacePoint = getCurrentMousePoint()
                axesPoint = obj.hAxes.CurrentPoint(1, 1:2);
                spacePoint = obj.axesPointToSpace(axesPoint);
            end
        end
        
        function [referencePoint,pixelPoint] = axesPointToSpace(obj,point)
            referencePoint =...
                scanimage.mroi.util.xformPoints(point,obj.displayToRefTransform);
            ref2pixelT = inv(obj.hCameraWrapper.pixelToRefTransform);
            pixelPoint = scanimage.mroi.util.xformPoints(referencePoint,ref2pixelT);
        end
        
        function cameraFrameAcq(obj, img)
            if nargin < 2 || isempty(img)
                return;
            end
            obj.hCameraSurf.CData = img;
            
            % garbage collect deleted live histograms
            validHistogramMask = isvalid(obj.hLiveHistograms);
            obj.hLiveHistograms(~validHistogramMask) = [];
            
            motionEstimatorIsOn = obj.estimateMotion && ~isempty(obj.hMotionEstimator);
            if motionEstimatorIsOn
                roiData = obj.imToRoiData(img);
                result = obj.hMotionEstimator.estimateMotion(roiData);
                timeout_s = 0;
                assert(result.wait(timeout_s),...
                    'Cannot use an asynchronous motion estimator for camera motion');
                motionDelta = result.fetch();
                %confidence = result.confidence(1:2);
                motionXLabel = num2str(motionDelta(1));
                motionYLabel = num2str(motionDelta(2));
            else
                motionXLabel = '';
                motionYLabel = '';
            end
            
            obj.hMotionEntries(3).String = motionXLabel;
            obj.hMotionEntries(5).String = motionYLabel;
            
            for i=1:length(obj.hLiveHistograms)
                obj.hLiveHistograms(i).updateData(img);
            end
        end
        
        function cameraLutUpdated(obj, ~)
            set(obj.hAxes, 'CLim', obj.hCameraWrapper.lut);
            if ~isempty(obj.hCameraRefSurf)
                obj.hCameraRefSurf.CData = obj.refSurfDisplay();
            end
        end
        
        function cameraRefSelect(obj, src)
            %None
            if src.Value == 1
                obj.refImg = [];
                obj.hCameraRefSurf.CData = [];
                set(obj.hRefTogglable, 'Enable', 'off');
                obj.refSelPrevIdx = 1;
                return;
            end
            
            %Browse
            if src.Value == length(obj.hCameraRefSel.String)
                [f, path] = uigetfile({'*.tiff;*.tif;*.png'},...
                    'Select a Reference Image File');
                if f == 0
                    src.Value = obj.refSelPrevIdx;
                    return;
                end
                fullpath = fullfile(path, f);
                obj.hCameraWrapper.referenceImages =...
                    vertcat(fullpath,obj.hCameraWrapper.referenceImages);
                
                %reference image list self corrects so there's no guarantee that
                % the file we put in actually exists
                idx = strcmp(obj.hCameraWrapper.referenceImages, fullpath);
                if any(idx)
                    src.Value = find(idx,1) + 1;
                    obj.updateRefSelect();
                else
                    src.Value = 1;
                    obj.refImg = [];
                    obj.hCameraRefSurf.CData = [];
                    obj.refSelPrevIdx = 1;
                    set(obj.hRefTogglable, 'Enable', 'off');
                    obj.updateRefSelect();
                    return;
                end
            end
            
            imgpath = obj.hCameraWrapper.referenceImages{src.Value-1};
            refImg_ = imread(imgpath);
            assert(size(refImg_,3)==1,'Color images are not supported.');
            
            if obj.hCameraWrapper.hDevice.isTransposed
                obj.refImg = refImg_.';
            else
                obj.refImg = refImg_;
            end
            
            [~,~,fileextension] = fileparts(imgpath);
            switch lower(fileextension)
                case {'.tiff','.tif'}
                    obj.scaleRefImg = true;
                otherwise
                    obj.scaleRefImg = false;
            end
            obj.hCameraRefSurf.CData = obj.refSurfDisplay();
            set(obj.hRefTogglable, 'Enable', 'on');
            obj.refSelPrevIdx = src.Value;
        end
        
        function close(obj)
            %figure is not killed when closed
            set(obj.hFig, 'Visible', 'off');
            if obj.live
                obj.live = false;
                obj.refreshToggled();
            end
        end
        
        function set.enableCrosshair(obj, val)
            if val
                obj.hXhairMenu.Label = 'Hide Crosshair';
                visibility = 'on';
            else
                obj.hXhairMenu.Label = 'Show Crosshair';
                visibility = 'off';
            end
            set([obj.hXhair, obj.hXhairRef], 'Visible', visibility);
            obj.enableCrosshair = val;
        end
        
        function set.enableRois(obj, val)
            if val
                enable = 'on';
            else
                enable = 'off';
            end
            set(obj.hRoiTogglable, 'Enable', enable);
            obj.enableRois = val;
            obj.refreshRois();
        end
        
        function frameAcquired(obj)
            if ~obj.enableRois
                return;
            end
            roidata = obj.hModel.hDisplay.rollingStripeDataBuffer{obj.zRoi}{1}.roiData;
            for i=1:length(roidata)
                if obj.hModel.hStackManager.zs(obj.zRoi) == roidata{i}.zs &&...
                        obj.channelIdx == roidata{i}.channels
                    surf = obj.hRoiSurface(i);
                    surf.AlphaData = roidata{i}.imageData{obj.zRoi}{1};
                end
            end
        end
        
        function cm = getColor(obj, idx, data)
            switch lower(obj.COLORSELECT{idx})
                case 'gray'
                    zeroIdx = [];
                case 'red'
                    zeroIdx = 2:3;
                case 'green'
                    zeroIdx = [1,3];
                case 'blue'
                    zeroIdx = 1:2;
                otherwise
                    error('Unknown color: %s',obj.COLORSELECT{idx});
            end
            
            if nargin < 3
                cm = gray();
                cm(:,zeroIdx) = 0;
            else
                assert(ismatrix(data));
                cm = repmat(data, [1 1 3]);
                cm(:,:,zeroIdx) = 0;
            end
        end
        
        function histLutChanged(obj, val)
            obj.blackLevel = val(1);
            obj.whiteLevel = val(2);
        end
        
        function hover(obj,varargin)
            [isInAxes,axesPoint] = most.gui.isMouseInAxes(obj.hAxes);
            if ~isInAxes
                return
            end
            
            [referencePoint,pixelPoint] = obj.axesPointToSpace(axesPoint);
            pixelPoint = round(pixelPoint);
            pixelX = pixelPoint(1);
            pixelY = pixelPoint(2);
            
            resolution = obj.hCameraWrapper.hDevice.resolutionXY;
            resolutionX = resolution(1);
            resolutionY = resolution(2);
            
            pixelValue = 0;
            xIsInRange = pixelX >= 1 && pixelX <= resolutionX;
            yIsInRange = pixelY >= 1 && pixelY <= resolutionY;
            if xIsInRange && yIsInRange
                if obj.hCameraWrapper.hDevice.isTransposed
                    frameIndices = pixelPoint;
                else
                    frameIndices = flip(pixelPoint);
                end
                frameX = frameIndices(1);
                frameY = frameIndices(2);
                
                lastFrame = obj.hCameraWrapper.lastFrame;
                if ~isempty(lastFrame) && all(size(lastFrame) > [frameX frameY])
                    pixelValue = obj.hCameraWrapper.lastFrame(frameX, frameY);
                end
            end
            
            %             pixelStr = fprintf('X: %d, Y: %d\n',pixel_pt(1),pixel_pt(2));
            %             refStr = fprintf('Angles: [%d, %d]\n',ref_pt(1),ref_pt(2));
            %             valStr = fprintf('Pixel Value: %d\n',pixelVal);
            referenceX = referencePoint(1);
            referenceY = referencePoint(2);
            status = sprintf(...
                'Pixel: (%+d, %+d)    Angles: [%+.4f, %+.4f]    Value: %d',...
                pixelX, pixelY, referenceX, referenceY, pixelValue);
            
            set(obj.hStatusBar, 'String', status);
        end
        
        function hRoiData = imToRoiData(obj,im)
            hRoiData = scanimage.mroi.RoiData();
            hRoiData.hRoi = obj.hDummyRoi;
            hRoiData.channels = 1;
            hRoiData.zs = 0;
            hRoiData.transposed = obj.hCameraWrapper.hDevice.isTransposed;
            hRoiData.imageData{1}{1} = im;
        end
        
        function lutAutoScale(obj)
            pxGradient = sort(obj.hCameraWrapper.lastFrame(:));
            if isempty(pxGradient)
                return;
            end
            npx = numel(pxGradient);
            newlut = ceil(npx .* obj.LUT_AUTOSCALE_SATURATION_PERCENTILE);
            newlut(2) = npx - newlut(2); %invert white idx
            
            obj.blackLevel = pxGradient(newlut(1));
            if newlut(2) > 0
                obj.whiteLevel = pxGradient(newlut(2));
            else
                obj.whiteLevel = pxGradient(newlut(1));
            end
        end
        
        function set.refUndocked(obj,val)
            if val
                obj.hCameraRefDockToggle.String = 'Dock';
                
                if isempty(obj.hCameraRefFig) || ~isvalid(obj.hCameraRefFig)
                    obj.hCameraRefFig = most.idioms.figure('NumberTitle','off',...
                        'Name','Reference Image',...
                        'Menubar','none',...
                        'DeleteFcn',@(~,~)set(obj, 'refUndocked', false));
                    hAx = most.idioms.axes('Parent', obj.hCameraRefFig, 'Visible', 'off');
                    hAx.DataAspectRatio = [1 1 1];
                    hAx.XTick = [];
                    hAx.YTick = [];
                    hAx.LooseInset = [1,1,1,1]*0.02;
                    view(hAx,0,-90);
                end
                obj.hCameraRefGroup.Parent = obj.hCameraRefFig.CurrentAxes;
                obj.hCameraRefSurf.FaceAlpha = 1;
            else
                obj.hCameraRefDockToggle.String = 'View';
                obj.hCameraRefGroup.Parent = obj.hAxes;
                if isvalid(obj.hCameraWrapper)
                    obj.hCameraRefSurf.FaceAlpha = obj.refAlpha;
                end
                if ~isempty(obj.hCameraRefFig)
                    if isvalid(obj.hCameraRefFig)
                        close(obj.hCameraRefFig);
                    end
                    obj.hCameraRefFig = [];
                end
            end
            obj.refUndocked = val;
        end
        
        function set.refImg(obj,val)
            if ~isempty(val)
                expectedRes = flip(obj.hCameraWrapper.hDevice.resolutionXY);
                if obj.hCameraWrapper.hDevice.isTransposed
                    expectedRes = flip(expectedRes);
                end
                validateattributes(val,{'numeric'},{'size',expectedRes},...
                    'The reference image has the wrong resolution.');
            end
            
            obj.refImg = val;
            
            if isempty(obj.refImg)
                most.idioms.safeDeleteObj(obj.hMotionEstimator);
                obj.hMotionEstimator = [];
            else
                refRoiData = obj.imToRoiData(obj.refImg);
                obj.hMotionEstimator = scanimage.components.motionEstimators.SimpleMotionEstimator(refRoiData);
                obj.hMotionEstimator.phaseCorrelation = false;
            end
        end
        
        function refreshRois(obj)
            if ~isempty(obj.hRoiSurface)
                delete(obj.hRoiSurface);
                obj.hRoiSurface = matlab.graphics.primitive.Surface.empty(0,1);
            end
            
            if ~isempty(obj.hRoiOutline)
                delete(obj.hRoiOutline);
                obj.hRoiOutline = matlab.graphics.primitive.Line.empty(0,1);
            end
            
            if obj.enableRois
                numRg = numel(obj.hModel.hRoiManager.currentRoiGroup.rois);
            else
                numRg = 0;
            end
            
            for i=1:numRg
                obj.hRoiSurface(i) = surface('parent', obj.hAxes, 'HitTest', 'off',...
                    'PickableParts', 'none', 'FaceColor','texturemap',...
                    'EdgeColor','none','FaceAlpha', 'texturemap',...
                    'XData',[],'YData',[],'ZData',[]);
                obj.hRoiOutline(i) = line(NaN,NaN,NaN,'Parent',obj.hAxes,...
                    'HitTest','off','PickableParts','none',...
                    'Color','b','XData',[],'YData',[],'ZData',[]);
            end
            
            %reset transforms
            obj.updateXforms();
            
            obj.frameAcquired();
        end
        
        function refreshToggled(obj)
            cameraIsAcquiring = obj.hCameraWrapper.isRunning();
            if obj.live
                if ~cameraIsAcquiring
                    obj.hLiveToggle.Value = 0;
                    obj.hLiveToggle.String = 'Starting...';
                    obj.hLiveToggle.Enable = 'off';
                else
                    makeAbortButton();
                end
                drawnow();
                
                if ~cameraIsAcquiring
                    try
                        obj.hCameraWrapper.startAcq(obj.refreshRate);
                        makeAbortButton();
                    catch ME
                        obj.live = false;
                        obj.hLiveToggle.Enable = 'on';
                        ME.rethrow();
                    end
                end
                obj.hPixelDatatype.Enable = 'off';
            else
                obj.hLiveToggle.String = 'LIVE';
                obj.hLiveToggle.hCtl.BackgroundColor = [.94 .94 .94];
                obj.hLiveToggle.hCtl.ForegroundColor = 'k';
                drawnow();
                if cameraIsAcquiring
                    obj.hCameraWrapper.stopAcq();
                end
                obj.hPixelDatatype.Enable = 'on';
            end
            
            function makeAbortButton()
                obj.hLiveToggle.String = 'ABORT';
                obj.hLiveToggle.hCtl.BackgroundColor = [1 0.4 0.4];
                obj.hLiveToggle.hCtl.ForegroundColor = 'w';
                obj.hLiveToggle.Enable = 'on';
                obj.hLiveToggle.Value = 1;
            end
        end
        
        function cdata = refSurfDisplay(obj,colorIdx)
            if nargin < 2 || isempty(colorIdx)
                colorIdx = obj.hCameraRefColor.Value;
            end
            
            if obj.scaleRefImg
                lut = obj.hCameraWrapper.lut;
            else
                refImgClass = class(obj.refImg);
                lut = [intmin(refImgClass),intmax(refImgClass)];
            end
            
            cdata = obj.scaleLut(obj.refImg, lut);
            cdata = obj.getColor(colorIdx,cdata);
        end
        
        function resetView(obj)
            obj.panPos_Ref = obj.posFit_Ref;
            obj.fovPos_Ref = obj.fovFit_Ref;
            obj.updateView();
        end
        
        function roiLutChanged(obj, srcIdx)
            if obj.enableRois && (nargin < 2 || srcIdx == obj.channelIdx)
                if ~isempty(obj.hRoiSurface) && any(isscalar([obj.hRoiSurface.AlphaData]))
                    for i=1:length(obj.hRoiSurface)
                        obj.hRoiSurface(i).AlphaData = repmat(intmin('int16'),...
                            size(obj.hRoiSurface(i).ZData));
                    end
                end
                lut = obj.hModel.hDisplay.(...
                    ['chan' num2str(obj.channelIdx) 'LUT']);
                lut = double(lut) * obj.hModel.hDisplay.displayRollingAverageFactor;
                
                lut(2) = lut(1)+diff(lut)/obj.roiAlpha;
                obj.hAxes.ALim = lut;
            end
        end
        
        function saveFrame2Png(obj)
            img = obj.hCameraWrapper.lastFrame;
            assert(~isempty(img), 'No frame available for saving.');
            if obj.hCameraWrapper.hDevice.isTransposed
                img = img .';
            end
            
            [file, path] = uiputfile({'*.png'},...
                'Select Save Destination',...
                fullfile(obj.prevSavePath, [obj.hCameraWrapper.hDevice.cameraName '_frame']));
            if file == 0
                return;
            end
            
            obj.prevSavePath = path;
            
            img = obj.scaleLut(img, obj.hCameraWrapper.lut);
            
            s = most.json.savejson(obj.hCameraWrapper.saveProps());
            %tab -> spaces.  imwrite complains
            s = strrep(s, char(9), '    ');
            imwrite(img, fullfile(path, file),'Comments',s);
        end
        
        function saveFrame2Tiff(obj)
            import dabs.resources.devices.camera.Datatype;
            
            img = obj.hCameraWrapper.lastFrame;
            
            assert(~isempty(img), 'No frame available for saving.');
            
            hDevice = obj.hCameraWrapper.hDevice;
            if hDevice.isTransposed
                img = img .';
            end
            
            [file, path] = uiputfile({'*.tiff;*.tif'},...
                'Select Save Destination',...
                fullfile(obj.prevSavePath, [hDevice.cameraName '_frame']));
            if file == 0
                return;
            end
            
            obj.prevSavePath = path;
            
            jsonProps = most.json.savejson(obj.hCameraWrapper.saveProps());
            TiffObj = Tiff(fullfile(path, file), 'w8');
            setTag(TiffObj, struct(...
                'ImageDescription', jsonProps,...
                'ImageLength', size(img, 1),...
                'ImageWidth', size(img, 2),...
                'Photometric', Tiff.Photometric.MinIsBlack,...
                'BitsPerSample', hDevice.datatype.getNumBits(),...
                'SamplesPerPixel', 1,...
                'Compression', Tiff.Compression.None,...
                'PlanarConfiguration', Tiff.PlanarConfiguration.Chunky));
            switch (hDevice.datatype)
                case {Datatype.U16, Datatype.U8}
                    setTag(TiffObj, 'SampleFormat', Tiff.SampleFormat.UInt);
                case {Datatype.I16, Datatype.I8}
                    setTag(TiffObj, 'SampleFormat', Tiff.SampleFormat.Int);
            end
            write(TiffObj, img);
            close(TiffObj);
        end
        
        function saveFrame2Workspace(obj)
            cimg = obj.hCameraWrapper.lastFrame;
            if obj.hCameraWrapper.hDevice.isTransposed
                cimg = cimg';
            end
            assignin('base', 'cameraImage', cimg);
            fprintf(['Snapshot from "%s" assigned to ' ...
                '<a href="matlab: ' ...
                'figure(''Colormap'',gray());imagesc(cameraImage);axis(''image'');' ...
                'fprintf(''>> size(cameraImage)\\n'');size(cameraImage)">' ...
                'cameraImage</a> in workspace ''base''\n'], ...
                obj.hCameraWrapper.hDevice.cameraName);
        end
        
        function saveView2Png(obj)
            [img, ~] = frame2im(getframe(obj.hAxes));
            [file, path] = uiputfile({'.png'},...
                'Select Save Destination',...
                fullfile(obj.prevSavePath, [obj.hCameraWrapper.hDevice.cameraName '_view']));
            if file == 0
                return;
            end
            obj.prevSavePath = path;
            s = most.json.savejson(obj.hCameraWrapper.saveProps());
            %tab -> spaces.  imwrite complains
            s = strrep(s, char(9), '    ');
            imwrite(img, fullfile(path, file),'Comments',s);
        end
        
        function scaledData = scaleLut(obj, data, lut)
            % this function is necessary because individual surfaces cannot set CLim
            % so we manually scale the data ourselves.
            maxSize = obj.hCameraWrapper.hDevice.datatype.getMaxValue();
            lut = single(lut);
            ratio = single(maxSize) / diff(lut);
            scaledData = cast((single(data) - lut(1)) .* ratio,...
                obj.hCameraWrapper.hDevice.datatype.toMatlabType());
        end
        
        function scrollWheelCallback(obj, data)
            obj.scrollAxes(data);
        end
        
        function scrollAxes(obj, data)
            if ~most.gui.isMouseInAxes(obj.hAxes)
                return
            end
            
            scrollCnt = double(data.VerticalScrollCount);
            if isempty(get(obj.hFig, 'currentModifier'))
                oldPtPos_Ref = scanimage.mroi.util.xformPoints(obj.hAxes.CurrentPoint(1,1:2),obj.displayToRefTransform);
                
                obj.fovPos_Ref = obj.fovPos_Ref * realpow(obj.ZOOMSCALE, scrollCnt);
                obj.updateView();
                
                ptPos_Ref = scanimage.mroi.util.xformPoints(obj.hAxes.CurrentPoint(1,1:2),obj.displayToRefTransform);
                obj.panPos_Ref = obj.panPos_Ref + oldPtPos_Ref - ptPos_Ref;
                obj.updateView();
            else
                scrollCnt = scrollCnt / 10;
                obj.roiAlpha = min(max(obj.roiAlpha + scrollCnt,0),1);
            end
        end
        
        function setDatatype(obj, src)
            import dabs.resources.devices.camera.Datatype;
            newDatatype = Datatype(src.String{src.Value});
            hDevice = obj.hCameraWrapper.hDevice;
            if newDatatype == hDevice.datatype
                return;
            end
            
            % re-scale lut if the datatype is smaller.
            normalBl = obj.blackLevelNormal;
            if obj.blackLevel < newDatatype.getMinValue()
                obj.blackLevel = newDatatype.getMinValue();
            end
            
            normalWl = obj.whiteLevelNormal;
            if obj.whiteLevel > newDatatype.getMaxValue()
                obj.whiteLevel = newDatatype.getMaxValue();
            end
            
            hDevice.datatype = newDatatype;
            obj.blackLevelNormal = normalBl;
            obj.whiteLevelNormal = normalWl;
        end
        
        function showHistogram(obj)
            hHist = scanimage.mroi.LiveHistogram(obj.hModel);
            hDevice = obj.hCameraWrapper.hDevice;
            hHist.title = [hDevice.cameraName ' Histogram'];
            hHist.dataRange = [hDevice.datatype.getMinValue() hDevice.datatype.getMaxValue()];
            hHist.lut = obj.hCameraWrapper.lut;
            hHist.viewRange = mean(hHist.lut) + [-1.5 1.5] .* diff(hHist.lut) ./ 2;
            hHist.updateData(obj.hCameraWrapper.lastFrame);
            obj.hLiveHistograms = [obj.hLiveHistograms; hHist];
            obj.hLiveHistogramListeners = [obj.hLiveHistogramListeners; ...
                most.ErrorHandler.addCatchingListener(hHist, 'lutUpdated', @(src,~)obj.histLutChanged(src.lut))];
        end
        
        function setReferenceSpace(obj, src)
            obj.refSpace = obj.REFSPACES{src.Value};
            obj.updateXforms();
            obj.updateView();
        end
        
        function updateChan(obj, src)
            %update video stream
            obj.channelIdx = sscanf(src.String{src.Value}, 'Channel %d');
            obj.frameAcquired();
        end
        
        function updateFit(obj)
            allX = obj.hCameraOutline.XData;
            allY = obj.hCameraOutline.YData;
            if ~isempty(obj.hRoiOutline)
                allX = [allX [obj.hRoiOutline.XData]];
                allY = [allY [obj.hRoiOutline.YData]];
            end
            
            all_ = [allX(:) allY(:)];
            all_Ref = scanimage.mroi.util.xformPoints(all_,obj.displayToRefTransform);
            
            maxX_Ref = max(all_Ref(:,1));
            maxY_Ref = max(all_Ref(:,2));
            minX_Ref = min(all_Ref(:,1));
            minY_Ref = min(all_Ref(:,2));
            origin = [(maxX_Ref - minX_Ref) (maxY_Ref - minY_Ref)] ./ 2;
            %fovMax should be one tick above the maximum bounds
            obj.posFit_Ref = [maxX_Ref maxY_Ref] - origin;
            obj.fovFit_Ref = max(origin) * obj.ZOOMSCALE;
        end
        
        function updateHistogramLut(obj)
            %clean invalid histograms in the meantime
            invalidHistIdx = ~isvalid(obj.hLiveHistograms);
            obj.hLiveHistograms(invalidHistIdx) = [];
            delete(obj.hLiveHistogramListeners(invalidHistIdx));
            obj.hLiveHistogramListeners(invalidHistIdx) = [];
            
            for i=1:numel(obj.hLiveHistograms)
                obj.hLiveHistograms(i).lut = obj.hCameraWrapper.lut;
            end
        end
        
        function updateRefSelect(obj)
            refPaths = obj.hCameraWrapper.referenceImages;
            refFiles = cell(size(refPaths));
            for i=1:length(refPaths)
                [~,file,ext] = fileparts(refPaths{i});
                refFiles{i} = [file ext];
            end
            obj.hCameraRefSel.String = [obj.REFSELEXTRA(1);...
                refFiles;obj.REFSELEXTRA(2)];
        end
        
        function updateTable(obj, src, data)
            setRow = data.Indices(1);
            propName = obj.hTable.Data{setRow, 1};
            try
                obj.hCameraWrapper.hDevice.(propName) = eval(data.NewData);
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
            % reset all properties as it is possible that they've changed
            for iRow=1:size(obj.hTable.Data,1)
                propName = obj.hTable.Data{iRow,1};
                src.Data{iRow,2} = dat2str(obj.hCameraWrapper.hDevice.(propName));
            end
        end
        
        function updateView(obj)
            bounds_ref = bsxfun(@plus,obj.panPos_Ref,obj.fovPos_Ref * [-1 -1;-1 1;1 1;1 -1]);
            
            ref2DisplayT = inv(obj.displayToRefTransform);
            panPos = scanimage.mroi.util.xformPoints(obj.panPos_Ref, ref2DisplayT);
            bounds = scanimage.mroi.util.xformPoints(bounds_ref, ref2DisplayT);
            xfov = diff([min(bounds(:,1)),max(bounds(:,1))]);
            yfov = diff([min(bounds(:,2)),max(bounds(:,2))]);
            fov = max(xfov,yfov) / 2;
            
            set(obj.hAxes, ...
                'XLim', fov * [-1 1] + panPos(1), ...
                'YLim', fov * [-1 1] + panPos(2));
        end
        
        function updateXforms(obj)
            switch obj.refSpace
                case 'Camera'
                    camera2RefT = obj.hCameraWrapper.cameraToRefTransform;
                    camera2DisplayT = obj.hCameraWrapper.displayTransform;
                    obj.displayToRefTransform = camera2RefT / camera2DisplayT;
                    set([obj.hFlipHMenu,obj.hFlipVMenu,obj.hRotateMenu],...
                        'Enable','on');
                case 'ROI'
                    obj.displayToRefTransform = eye(3);
                    set([obj.hFlipHMenu,obj.hFlipVMenu,obj.hRotateMenu],...
                        'Enable','off');
            end
            
            % update camera+ref xforms
            [refX, refY] = obj.hCameraWrapper.getRefMeshgrid();
            ref2DisplayT = inv(obj.displayToRefTransform);
            
            [displayX, displayY] =...
                scanimage.mroi.util.xformMesh(refX, refY, ref2DisplayT);
            set(obj.hCameraSurf,...
                'XData', displayX,...
                'YData', displayY,...
                'ZData', ones(size(displayX)));
            if ~isempty(obj.hCameraRefSurf)
                set(obj.hCameraRefSurf,...
                    'XData', displayX,...
                    'YData', displayY,...
                    'ZData', zeros(size(displayX)));
            end
            
            outlineX = mesh2outline(displayX);
            outlineY = mesh2outline(displayY);
            set(obj.hCameraOutline,...
                'XData', outlineX,...
                'YData', outlineY,...
                'ZData', ones(size(outlineX)));
            
            outlineZ = zeros(1,2);
            crossHorizontalX = [outlineX(1)+outlineX(4) outlineX(2)+outlineX(3)] / 2;
            crossHorizontalY = [outlineY(1)+outlineY(4) outlineY(2)+outlineY(3)] / 2;
            
            crossVerticalX = [outlineX(1)+outlineX(2) outlineX(3)+outlineX(4)] / 2;
            crossVerticalY = [outlineY(1)+outlineY(2) outlineY(3)+outlineY(4)] / 2;
            
            crosshairX = [crossHorizontalX NaN crossVerticalX];
            crosshairY = [crossHorizontalY NaN crossVerticalY];
            crosshairZ = [outlineZ NaN outlineZ];
            set([obj.hXhair obj.hXhairRef],...
                'XData', crosshairX,...
                'YData', crosshairY,...
                'ZData', crosshairZ);
            
            % update roi xforms
            roiGroups = obj.hModel.hRoiManager.currentRoiGroup.rois;
            roiZIndex = obj.hModel.hStackManager.zs(obj.zRoi);
            for i=1:length(obj.hRoiSurface)
                [roiX, roiY] = roiGroups(i).get(roiZIndex).meshgrid();
                [displayX, displayY] =...
                    scanimage.mroi.util.xformMesh(roiX, roiY, ref2DisplayT);
                % roi reference space is transposed
                displayX = displayX .';
                displayY = displayY .';
                
                set(obj.hRoiSurface(i),...
                    'XData', displayX, ...
                    'YData', displayY,...
                    'ZData', repmat(-1,size(displayX)), ...
                    'CData', repmat(intmax('uint8'), [size(displayX) 3]));
                
                outlineX = mesh2outline(displayX);
                outlineY = mesh2outline(displayY);
                set(obj.hRoiOutline(i),...
                    'XData', outlineX, ...
                    'YData', outlineY,...
                    'ZData', repmat(-1,size(outlineX)));
            end
            
            %update luts
            obj.roiLutChanged(obj.channelIdx);
            
            %update max fov to fit new rois
            obj.updateFit();
            
            if obj.hCameraWrapper.flipH
                obj.hFlipHMenu.Checked = 'on';
            else
                obj.hFlipHMenu.Checked = 'off';
            end
            
            if obj.hCameraWrapper.flipV
                obj.hFlipVMenu.Checked = 'on';
            else
                obj.hFlipVMenu.Checked = 'off';
            end
            
            obj.hRotateMenu.Label = sprintf('Rotation: %d%s', obj.hCameraWrapper.rotate,most.constants.Unicode.degree_sign);
            
            function linepts = mesh2outline(mesh)
                % returns line-friendly outline of the mesh
                % drawn clockwise from top left corner.
                linepts = [...
                    mesh(1,1);...
                    mesh(1,end);...
                    mesh(end,end);...
                    mesh(end,1);...
                    mesh(1,1)];
            end
        end
        
        function updateZed(obj, src, ~)
            %update z level
            obj.zRoi = src.Value;
            obj.refreshRois();
        end
        
        function val = get.whiteLevel(obj)
            val = obj.hCameraWrapper.lut(2);
        end
        
        function set.whiteLevel(obj, val)
            if obj.blackLevel >= val
                return;
            end
            if ischar(val)
                val = str2double(val);
            end
            obj.hCameraWrapper.lut(2) = val;
            obj.updateHistogramLut();
            set(obj.hWhiteLevelSlider(2), 'Value', obj.whiteLevelNormal); % update slider gui
        end
        
        function val = get.whiteLevelNormal(obj)
            pixelType = obj.hCameraWrapper.hDevice.datatype;
            val = (obj.whiteLevel - pixelType.getMinValue()) /...
                (pixelType.getMaxValue() - pixelType.getMinValue());
        end
        
        function set.whiteLevelNormal(obj, val)
            pixelType = obj.hCameraWrapper.hDevice.datatype;
            obj.whiteLevel = val * (pixelType.getMaxValue() - pixelType.getMinValue()) +...
                pixelType.getMinValue(); 
        end
    end
    
    %% most.GUI
    methods (Access = protected)
        function initGui(obj)
            hCamera = obj.hCameraWrapper.hDevice;
            
            obj.hFig.Name = ['CAMERA [' upper(hCamera.cameraName) ']'];
            obj.hFig.CloseRequestFcn = @(~,~)obj.close();
            
            %root
            rootFlowMargin = 4; %copied from MotionDisplay
            rootContainer = most.gui.uiflowcontainer( ...
                'Parent', obj.hFig, ...
                'FlowDirection', 'LeftToRight', ...
                'Margin', rootFlowMargin);
            
            %sidebar
            sidebarFlowmargin = 4;
            sidebar = most.gui.uiflowcontainer( ...
                'Parent', rootContainer, ...
                'FlowDirection', 'TopDown', ...
                'WidthLimits', [300 300], ...
                'Margin', sidebarFlowmargin);
            
            %sidebar pane
            sidebarPane = uipanel('Parent', sidebar, ...
                'Title', 'Settings', ...
                'Units', 'pixels');
            
            labelW = 97;
            elemW = 185;
            height = 20;
            bwEntrySliderW = [50;109]; %space for autolut
            entrySliderW = [50;132];
            colmargin = 3;
            rowmargin = 5;
            topmargin = 40;
            
            %regular row items
            elems = [...
                struct('label', 'Reference Space',...
                'ctrl',obj.addUiControl('Style','popupmenu',...
                'String',obj.REFSPACES,...
                'Callback', @(src, ~)obj.setReferenceSpace(src)...
                ),'width', elemW,'bind',{{'hRefSpace'}}, 'roitoggle', false,...
                'reftoggle', false);...
                
                struct('label', 'Exposure (ms)',...
                'ctrl',obj.addUiControl('Style','edit',...
                'TooltipString','Set Camera Exposure' ...
                ,'Bindings', {hCamera 'cameraExposureTime' 'value'}...
                ),'width',elemW,'bind',{{}}, 'roitoggle', false,...
                'reftoggle', false);...
                
                struct('label', 'Pixel Type',...
                'ctrl',obj.addUiControl('Style','popupmenu',...
                'TooltipString','Set Camera Pixel Type',...
                'Bindings', {hCamera 'availableDatatypes' 'Choices'},...
                'Callback', @(src, ~)obj.setDatatype(src)),...
                'width', elemW, 'bind', {{'hPixelDatatype'}}, 'roitoggle', false,...
                'reftoggle', false);...
                
                struct('label', 'White','ctrl',[...
                obj.addUiControl('Style', 'edit',...
                'Bindings', {obj 'whiteLevel' 'value'})...
                ;obj.addUiControl('Style', 'slider',...
                'TooltipString', 'Set White LUT',...
                'Bindings', {obj 'whiteLevelNormal' 'value'},'Min', 0, 'Max', 1 ...
                )],'width',bwEntrySliderW, 'bind', {{'hWhiteLevelSlider'}}, 'roitoggle', false,...
                'reftoggle', false);...
                
                struct('label','Black',...
                'ctrl',[...
                obj.addUiControl('Style', 'edit',...
                'Bindings', {obj 'blackLevel' 'value'}...
                );...
                obj.addUiControl('Style', 'slider',...
                'TooltipString', 'Set Black LUT',...
                'Bindings', {obj 'blackLevelNormal' 'value'},'Min', 0, 'Max', 1 ...
                )], 'width',bwEntrySliderW, 'bind', {{'hBlackLevelSlider'}}, 'roitoggle', false,...
                'reftoggle', false);...
                
                struct('label', 'Color Scale',...
                'ctrl', obj.addUiControl('Style', 'popupmenu',...
                'String', obj.COLORSELECT, ...
                'Callback', @(src,~)colormap(obj.hAxes, obj.getColor(src.Value))...
                ), 'width', elemW, 'bind', {{}}, 'roitoggle', false,...
                'reftoggle', false);...
                
                struct('label', 'Reference Image',...
                'ctrl',[...
                obj.addUiControl('Style', 'popupmenu',...
                'String', '',...
                'Callback', @(src, ~)obj.cameraRefSelect(src));...
                obj.addUiControl('Style', 'togglebutton',...
                'String', 'View',... %up arrow from base
                'HorizontalAlignment', 'center',...
                'FontSize', 10,...
                'ToolTipString', 'Dock/Undock Reference Image',...
                'Bindings', {obj 'refUndocked' 'value'})],...
                'width', [122;60], 'bind', {{'hCameraRefSel';'hCameraRefDockToggle'}},...
                'roitoggle', false,'reftoggle', false);...
                
                struct('label', 'Reference Color',...
                'ctrl',obj.addUiControl('Style', 'popupmenu','String',obj.COLORSELECT, ...
                'Callback',@(~,~)set(obj.hCameraRefSurf,'CData',obj.refSurfDisplay()), ...
                'Value',3 ...
                ), 'width', elemW, 'bind', {{'hCameraRefColor'}},...
                'roitoggle', false, 'reftoggle', true);...
                
                struct('label', 'Reference Alpha',...
                'ctrl', [...
                obj.addUiControl('Style', 'edit',...
                'Bindings', {obj,'refAlpha','value'}...
                );...
                obj.addUiControl('Style', 'slider',...
                'Bindings', {obj,'refAlpha','value'},'Min', 0, 'Max', 1 ...
                )], 'width',entrySliderW, 'bind', {{}}, 'roitoggle', false,...
                'reftoggle', true);...
                
                struct('label', 'Estimate Motion',...
                'ctrl', [...
                obj.addUiControl('Style', 'checkbox',...
                'Bindings', {obj, 'estimateMotion', 'value'});
                obj.addUiControl('Style', 'text', 'String', 'dx:');...
                obj.addUiControl('Style', 'edit');...
                obj.addUiControl('Style', 'text', 'String', 'dy:');...
                obj.addUiControl('Style', 'edit')], 'width', [17;18;56;18;56],...
                'bind', {{'hMotionEntries'}}, 'roitoggle', false,...
                'reftoggle', true);
                
                struct('label', 'Enable ROIs',...
                'ctrl', obj.addUiControl('Style', 'checkbox', ...
                'Bindings', {obj 'enableRois' 'value'}...
                ), 'width', elemW, 'bind', {{}}, 'roitoggle', false,...
                'reftoggle', false);...
                
                struct('label', 'Channels',...
                'ctrl', obj.addUiControl('Style', 'popupmenu',...
                'Bindings', {obj.hModel.hChannels 'channelName' 'Choices'},...
                'Callback', @(src, ~)obj.updateChan(src)...
                ), 'width', elemW, 'bind', {{}}, 'roitoggle', true,...
                'reftoggle', false);...
                
                struct('label', 'Zs', 'ctrl', obj.addUiControl('Style', 'popupmenu', ...
                'Bindings', {obj.hModel.hStackManager 'zs' 'Choices'}, ...
                'Callback', @obj.updateZed...
                ), 'width', elemW, 'bind', {{}}, 'roitoggle', true,...
                'reftoggle', false);...
                
                struct('label', 'ROI Alpha',...
                'ctrl',[...
                obj.addUiControl('Style', 'edit',...
                'Bindings', {obj,'roiAlpha','value'}...
                );...
                obj.addUiControl('Style', 'slider',...
                'Bindings', {obj,'roiAlpha','value'},...
                'Min', 0, 'Max', 1 ...
                )], 'width',entrySliderW, 'bind', {{}}, 'roitoggle', true,...
                'reftoggle', false)...
                ];
            nrows = length(elems);
            
            hlim = topmargin + (nrows-1)*height + nrows*rowmargin;
            sidebarPane.HeightLimits = [hlim hlim];
            for i=1:nrows
                rowpos = topmargin + (i-1)*(rowmargin + height);
                e = elems(i);
                label = obj.addUiControl('Parent', sidebarPane ...
                    , 'Style', 'text' ...
                    , 'String', e.label ...
                    , 'HorizontalAlignment', 'right' ...
                    , 'Units', 'pixels' ...
                    , 'RelPosition', [0 rowpos labelW height]);
                set(e.ctrl, 'Parent', sidebarPane);
                set(e.ctrl, 'Units', 'pixels');
                for j=1:length(e.ctrl)
                    xOffset = labelW + sum(e.width(1:j-1)) + j*colmargin;
                    e.ctrl(j).RelPosition = [xOffset rowpos e.width(j) height];
                end
                
                if ~isempty(e.bind)
                    assert(iscellstr(e.bind),'`bind` must be cell array of strings');
                    numBinds = numel(e.bind);
                    for j=1:numBinds-1
                        obj.(e.bind{j}) = e.ctrl(j);
                    end
                    if numBinds <= numel(e.ctrl)
                        obj.(e.bind{end}) = e.ctrl(numBinds:end);
                    end
                end
                
                if all(e.roitoggle)
                    obj.hRoiTogglable = [obj.hRoiTogglable;label;e.ctrl];
                else
                    obj.hRoiTogglable = [obj.hRoiTogglable;e.ctrl(e.roitoggle)];
                end
                
                if all(e.reftoggle)
                    obj.hRefTogglable = [obj.hRefTogglable;label;e.ctrl];
                else
                    obj.hRefTogglable = [obj.hRefTogglable;e.ctrl(e.reftoggle)];
                end
            end
            set([obj.hRoiTogglable;obj.hRefTogglable], 'Enable', 'off');
            obj.updateRefSelect();
            
            % auto lut button
            alutRel = elems(strcmp({elems.label}, 'Black'));
            alutRelSliderPos = alutRel.ctrl(2).RelPosition;
            xOffset = alutRelSliderPos(1) + alutRelSliderPos(3) + colmargin;
            topOffset = alutRelSliderPos(2);
            obj.addUiControl('Parent', sidebarPane ...
                , 'Units', 'pixels' ...
                , 'Style', 'pushbutton' ...
                , 'String', most.constants.Unicode.up_down_arrow ... %up-down arrow
                , 'HorizontalAlignment', 'center' ...
                , 'FontSize', 16 ...
                , 'Callback', @(~,~)obj.lutAutoScale() ...
                , 'RelPosition', [xOffset topOffset 20 (2*height)+rowmargin]);
            
            %Optional Settings
            userProps = hCamera.getUserPropertyList();
            mask = strcmpi(userProps,'cameraExposureTime'); % there is a separate ui control for cameraExposureTime
            userProps = userProps(~mask);
            
            userPropVals = cell(size(userProps));
            for idx=1:numel(userProps)
                propName = userProps{idx};
                userPropVals{idx} = dat2str(hCamera.(propName));
            end
            
            userProp = horzcat(userProps(:), userPropVals(:));
            
            if isempty(userProp)
                uipanel('Parent', sidebar,...
                    'Visible', 'on',...
                    'BorderType', 'none',...
                    'Units', 'pixels');
            else
                obj.hTable = uitable('Parent', sidebar ...
                    , 'Data', userProp ...
                    , 'ColumnName', {'Property Names' 'Property Values'} ...
                    , 'RowName', {} ...
                    , 'ColumnEditable', [false true] ...
                    , 'CellEditCallback', @obj.updateTable ...
                    , 'Units', 'pixels');
            end
            
            %live toggle
            obj.hLiveToggle = most.gui.uicontrol('Parent', sidebar ...
                ,'Style', 'togglebutton' ...
                ,'String', 'LIVE' ...
                ,'Bindings', {obj 'live' 'value'} ...
                ,'HeightLimits', [50 50] ...
                );
            
            %camera view
            camFlow = most.gui.uiflowcontainer( ...
                'Parent', rootContainer, ...
                'FlowDirection', 'TopDown', ...
                'Margin', 5);
            camPane = uipanel('parent', camFlow, 'bordertype','none');
            obj.hAxes = most.idioms.axes('parent', camPane, ...
                'box','off', ...
                'Color','k', ...
                'xgrid','off','ygrid','off', ...
                'units','normalized', ...
                'position',[0 0 1 1], ...
                'GridColor',.9*ones(1,3), ...
                'GridAlpha',.25, ...
                'DataAspectRatio', [1 1 1], ...
                'XTick',[],'XTickLabel',[], ...
                'YTick',[],'YTickLabel',[], ...
                'XLim', [-.5 .5], ...
                'YLim', [-.5 .5],...
                'CLim', obj.hCameraWrapper.lut, ...
                'ALim', [0 intmax('int16')], ...
                'ButtonDownFcn', @(~,~)obj.buttonDownCallback(), ...
                'UIContextMenu', uicontextmenu(obj.hFig));
            uimenu(...
                'Parent',obj.hAxes.UIContextMenu,...
                'Label','Reset View',...
                'Callback',@(~,~)obj.resetView());
            obj.hXhairMenu = uimenu(...
                'Parent',obj.hAxes.UIContextMenu,...
                'Label','Show Crosshair',...
                'Callback',@(~,~)set(obj, 'enableCrosshair', ~obj.enableCrosshair));
            uimenu(...
                'Parent', obj.hAxes.UIContextMenu,...
                'Label', 'View Histograms', ...
                'Callback', @(~,~)obj.showHistogram());
            
            obj.hFlipHMenu = uimenu(...
                'Parent', obj.hAxes.UIContextMenu,...
                'Label', 'Flip Horizontally',...
                'Separator', 'on',...
                'Callback', @(~,~)flipView('H'));
            obj.hFlipVMenu = uimenu(...
                'Parent', obj.hAxes.UIContextMenu,...
                'Label', 'Flip Vertically', ...
                'Callback', @(~,~)flipView('V'));
            obj.hRotateMenu = uimenu(...
                'Parent', obj.hAxes.UIContextMenu,...
                'Label', 'Rotation', ...
                'Callback', @(~,~)flipView('R'));
            
            uimenu(...
                'Parent', obj.hAxes.UIContextMenu,...
                'Separator', 'on', ...
                'Label','Save Current Viewport',...
                'Callback', @(~,~)obj.saveView2Png());
            
            uimenu(...
                'Parent', obj.hAxes.UIContextMenu,...
                'Label', 'Save Current Frame',...
                'Callback', @(~,~)obj.saveFrame2Png());
            
            saveframe = uimenu(...
                'Parent', obj.hAxes.UIContextMenu,...
                'Label', 'Save Raw Frame...');
            uimenu(...
                'Parent', saveframe,...
                'Label', 'to Workspace', ...
                'Callback',@(~,~)obj.saveFrame2Workspace());
            uimenu(...
                'Parent', saveframe,...
                'Label', 'to TIFF',...
                'Callback',@(~,~)obj.saveFrame2Tiff());
            
            %Statusbar
            statusPane = uipanel(...
                'Parent', camFlow, ...
                'Title', '', ...
                'Units', 'pixels',...
                'BorderType', 'line',...
                'HighlightColor', [0.7 0.7 0.7]);
            statusPane.HeightLimits = [17 17];
            obj.hStatusBar = obj.addUiControl(...
                'parent', statusPane,...
                'style', 'text',...
                'HorizontalAlignment', 'left', 'Units', 'Normalized',...
                'Position', [0 0 1 1]);
            
            colormap(obj.hAxes, gray);
            
            view(obj.hAxes,0,-90);
            
            obj.hCameraSurf = surface(...
                'parent', obj.hAxes, ...
                'FaceColor','texturemap',...
                'EdgeColor','none',...
                'HitTest','off',...
                'PickableParts', 'none',...
                'XData',[],'YData',[],'ZData',[], 'CData', '', 'AlphaData', inf);
            
            obj.hCameraRefGroup = hggroup('Parent', obj.hAxes);
            
            obj.hCameraRefSurf = surface(...
                'parent', obj.hCameraRefGroup, ...
                'FaceColor','texturemap',...
                'EdgeColor','none',...
                'HitTest','off',...
                'PickableParts', 'none',...
                'XData',[],'YData',[],'ZData',[], 'CData', obj.refSurfDisplay(), ...
                'FaceAlpha', obj.refAlpha);
            
            obj.hCameraOutline = line(NaN,NaN,NaN,...
                'Parent',obj.hAxes,...
                'HitTest','off',...
                'PickableParts','none',...
                'Color','y',...
                'XData', [], 'YData', [], 'ZData', []);
            
            obj.hXhair = line(NaN,NaN,NaN,...
                'Parent',obj.hAxes,...
                'HitTest','off',...
                'PickableParts','none',...
                'Color','w',...
                'XData', [], 'YData', [], 'ZData', [],...
                'LineWidth', 1,...
                'Visible', 'off');
            
            obj.hXhairRef = line(NaN,NaN,NaN,...
                'Parent',obj.hCameraRefGroup,...
                'HitTest','off',...
                'PickableParts','none',...
                'Color','w',...
                'XData', [], 'YData', [], 'ZData', [],...
                'LineWidth', 1,...
                'Visible', 'off');
            
            obj.hListeners = [...
                most.ErrorHandler.addCatchingListener(obj,'live','PostSet',@(varargin)obj.refreshToggled);...
                most.ErrorHandler.addCatchingListener(obj.hCameraWrapper,'lastFrame', 'PostSet',...
                @(~,~)obj.cameraFrameAcq(obj.hCameraWrapper.lastFrame));
                most.ErrorHandler.addCatchingListener(obj.hCameraWrapper,'lut', 'PostSet', ...
                @(~,evt)obj.cameraLutUpdated(evt));...
                most.ErrorHandler.addCatchingListener(obj.hCameraWrapper,{'flipH','flipV','rotate'}, 'PostSet', ...
                @(~,~)obj.updateXforms())];
            
            if ~isempty(obj.hModel) && ~isempty(obj.hController)
                obj.hListeners = [obj.hListeners;...
                    most.ErrorHandler.addCatchingListener(obj.hModel.hRoiManager,'imagingRoiGroupChanged',...
                    @(~,~)obj.refreshRois());...
                    most.ErrorHandler.addCatchingListener(obj.hModel.hUserFunctions,'frameAcquired',...
                    @(~,~)obj.frameAcquired());...
                    most.ErrorHandler.addCatchingListener(obj.hModel.hDisplay,'chan1LUT','PostSet',@(~,~)obj.roiLutChanged(1));...
                    most.ErrorHandler.addCatchingListener(obj.hModel.hDisplay,'chan2LUT','PostSet',@(~,~)obj.roiLutChanged(2));...
                    most.ErrorHandler.addCatchingListener(obj.hModel.hDisplay,'chan3LUT','PostSet',@(~,~)obj.roiLutChanged(3));...
                    most.ErrorHandler.addCatchingListener(obj.hModel.hDisplay,'chan4LUT','PostSet',@(~,~)obj.roiLutChanged(4));...
                    most.ErrorHandler.addCatchingListener(obj.hModel.hDisplay,'displayRollingAverageFactor','PostSet',@(~,~)obj.roiLutChanged());...
                    most.ErrorHandler.addCatchingListener(obj.hCameraWrapper,'cameraToRefTransform',...
                    'PostSet',@(~,~)obj.updateXforms)];
                
                set(obj.hFig, ...
                    'WindowScrollWheelFcn', @(~,data)obj.scrollWheelCallback(data),...
                    'WindowButtonMotionFcn',@obj.hover);
            end
            obj.refreshRois();
            obj.updateFit();
            obj.resetView();
            
            function flipView(type)
                switch type
                    case 'H'
                        obj.hCameraWrapper.flipH = ~obj.hCameraWrapper.flipH;
                    case 'V'
                        obj.hCameraWrapper.flipV = ~obj.hCameraWrapper.flipV;
                    case 'R'
                        obj.hCameraWrapper.rotate = obj.hCameraWrapper.rotate + 90;
                end
            end
        end
    end
end
function str = dat2str(dat)
if ischar(dat)
    str = ['''' dat ''''];
elseif isnumeric(dat) || islogical(dat)
    str = mat2str(dat, 5);
else
    str = '<cannot render>';
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
