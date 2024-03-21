classdef SlmLutCalibration < most.Gui & most.HasClassDataFile
    properties (Hidden, SetAccess = private)
        hCameraWrapper
        
        guiInitted = false;
        
        hAxCam;
        hSurfCam;
        hLineSlmPixels;
        hLineSlmCorners;
        hLineSlmOutline;
        hTextCam;
        
        hAxIntensity;
        hLineIntensity;
        hLineIntensityFit;
        hLineIntensityMarkers;
        
        hAxLut;
        hLineLutRaw;
        hLineLutFit;
        hPatchLutWindow;
        hTextLut;
        
        image = [];
        
        hCSCamPixels = [];
        hCSSlmPixels = [];
        
        viewPortSize = 1;
        viewPortCenter = [0 0];
        
        started = false;
        
        hPbStartLiveView;
        hPbStartCalibration;
        hTxtPiston;
        hSlPistonVal;
        hPbCalculateFit
        
        slmIntensity = [];
        slmPhi = [];
        slmPixelValues = [];
        
        lutWindow = [100 150];
        
        hLiveViewTimer
        
        classDataFileName;
    end
    
    properties (SetObservable)
        pixelGridVisible = false;
        orientationMarkerVisible = false;
        lutPolyDeg = 5;
    end
    
    properties (Dependent, Hidden)
        camResolutionXY
        cameraImageLut
        
        hSlm
        hSlmScan
        slmResolutionXY
        
        hCam
    end
    
    %% Lifecycle
    methods
        function obj = SlmLutCalibration(hModel, hController)
            size = [200,50];
            obj = obj@most.Gui(hModel,hController,size,'characters');
        end
        
        function delete(obj)
            obj.abort();
            most.idioms.safeDeleteObj(obj.hLiveViewTimer);
            obj.saveClassData();
        end
    end
    
    %% User methods
    methods
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
        
        function [I,slmPixelValues] = startCalibration(obj)
            obj.abort();
            
            [images,slmPixelValues] = obj.measureSlmResponse();
            I = obj.cameraImagesToSlmIntensity(images);
            
            obj.clearCache();
            obj.slmIntensity = I;
            obj.slmPixelValues = slmPixelValues;
        end
    end
    
    %% GUI
    methods (Access = protected)
        function initGui(obj)
            pth = obj.hModel.classDataDir;
            classNameShort = most.util.className(class(obj),'classNameShort');
            obj.classDataFileName = fullfile(pth, [classNameShort '_classData.mat']);
            
            % Initialize class data file (ensure props exist in file)
            obj.zprvEnsureClassDataFileProps()
            
            obj.hCSCamPixels = scanimage.mroi.coordinates.CSLinear('Camera Pixels',2);
            obj.hCSSlmPixels = scanimage.mroi.coordinates.CSLinear('Slm Pixels',2,obj.hCSCamPixels);
            
            obj.makeControls();
            
            modelIsValid = ~isempty(obj.hModel);
            camerasExist = ~isempty(obj.hModel.hCameraManager.hCameraWrappers);
            if modelIsValid && obj.guiInitted && camerasExist
                obj.hCameraWrapper = obj.hModel.hCameraManager.hCameraWrappers(1);
                obj.updateGui();
                
                obj.loadClassData();
            end
        end
        
        function makeControls(obj)
            obj.hFig.Name = 'SLM LUT Calibration';
            
            if isempty(obj.hSlmScan)
                uicontrol('Parent',obj.hFig,'Style','text','String','No SLM found in system','HorizontalAlignment','center','Units','normalized','Position',[0 0 1 1]);
                return
            end
            
            if isempty(obj.hModel) || isempty(obj.hModel.hCameraManager.hCameraWrappers)
                uicontrol('Parent',obj.hFig,'Style','text','String','No camera found in system','HorizontalAlignment','center','Units','normalized','Position',[0 0 1 1]);
                return
            end
            
            obj.hFig.WindowScrollWheelFcn = @obj.zoom;
            obj.hFig.WindowButtonMotionFcn = @obj.hover;
            
            mainFlow = most.gui.uiflowcontainer('Parent',obj.hFig,'FlowDirection','LeftToRight');
            leftFlow  = most.gui.uiflowcontainer('Parent',mainFlow,'FlowDirection','TopDown');
            set(leftFlow,'WidthLimits',[150 150]);
            rightFlow = most.gui.uiflowcontainer('Parent',mainFlow,'FlowDirection','TopDown');
            imageFlow = most.gui.uiflowcontainer('Parent',rightFlow,'FlowDirection','LeftToRight');
            plotsFlow = most.gui.uiflowcontainer('Parent',rightFlow,'FlowDirection','LeftToRight');
            set(plotsFlow,'HeightLimits',[200 200]);
            intensityPlotFlow = most.gui.uiflowcontainer('Parent',plotsFlow,'FlowDirection','TopDown');
            lutPlotFlow = most.gui.uiflowcontainer('Parent',plotsFlow,'FlowDirection','TopDown');
            
            cameraNames = obj.getSICameraNames();
            if isempty(cameraNames)
                cameraNames = {''};
            end
            obj.addUiControl('Parent',leftFlow,'Style','popupmenu','String',cameraNames,'Callback',@selectCamera,'HeightLimits',[25 25]);
            obj.hPbStartLiveView = obj.addUiControl('Parent',leftFlow,'Style','pushbutton','String','Live View','Callback',@toggleLive,'HeightLimits',[40 40]);
            obj.addUiControl('Parent',leftFlow,'Style','pushbutton','String','Open Camera Window','Callback',@(varargin)obj.openCameraWindow,'HeightLimits',[40 40]);
            obj.addUiControl('Parent',leftFlow,'Style','checkbox','string','Show Pixel Grid','tag','cbPixelGrid','Bindings',{obj 'pixelGridVisible' 'value'},'HeightLimits',[20 20]);
            obj.addUiControl('Parent',leftFlow,'Style','checkbox','string','Show Orientation Marker','tag','cbOrientationMarker','Bindings',{obj 'orientationMarkerVisible' 'value'},'HeightLimits',[25 25]);
            
            obj.hTxtPiston = obj.addUiControl('Parent',leftFlow,'Style','text','String','Set SLM Value','HeightLimits',[15 15]);
            obj.hSlPistonVal = obj.addUiControl('Parent',leftFlow,'Style','slider','Callback',@setPistonVal,'HeightLimits',[25 25]);
            obj.hPbStartCalibration = obj.addUiControl('Parent',leftFlow,'Style','pushbutton','String','Start Calibration','Callback',@(src,evt)obj.startCalibration,'HeightLimits',[40 40]);
            obj.addUiControl('Parent',leftFlow,'Style','pushbutton','String','Clear Calibration','Callback',@(src,evt)obj.clearCache,'HeightLimits',[40 40]);
            obj.addUiControl('Parent',leftFlow,'Style','pushbutton','String','Calculate and Save LUT','Callback',@(src,evt)obj.calculateAndSave,'HeightLimits',[40 40]);
            
            polyDegFlow = most.gui.uiflowcontainer('Parent',leftFlow,'FlowDirection','LeftToRight');
            set(polyDegFlow,'HeightLimits',[20 20]);
            obj.addUiControl('Parent',polyDegFlow,'Style','text','String','Polynomial Degree','WidthLimits',[95 95]);
            obj.addUiControl('Parent',polyDegFlow,'Style','edit','Bindings',{obj 'lutPolyDeg' 'value'});
            
            obj.hAxCam = most.idioms.axes('Parent',imageFlow,'DataAspectRatio',[1 1 1],'XTick',[],'YTick',[]);
            obj.hAxCam.ButtonDownFcn = @obj.pan;
            box(obj.hAxCam,'on');
            
            view(obj.hAxCam,0,-90);
            
            pink = [1 0 0.5647];
            lineWidth = 1.5;
            obj.hSurfCam = surface('Parent',obj.hAxCam,'FaceColor','texturemap','EdgeColor','none','CData',[],'Hittest','off','PickableParts','none');
            obj.hLineSlmPixels = line('Parent',obj.hAxCam,'XData',[],'YData',[],'LineStyle','-','Hittest','off','PickableParts','none','Color',pink,'LineWidth',lineWidth);
            obj.hLineSlmCorners = line('Parent',obj.hAxCam,'XData',[],'YData',[],'LineStyle','none','Marker','o','ButtonDownFcn',@obj.dragAlign,'Color',pink,'LineWidth',lineWidth);
            obj.hLineSlmOutline = line('Parent',obj.hAxCam,'XData',[],'YData',[],'LineStyle','-','Hittest','off','PickableParts','none','Color',pink,'LineWidth',lineWidth);
            obj.hTextCam = text('Parent',obj.hAxCam,'String','','VerticalAlignment','top','HorizontalAlignment','right','Color',[1 0 0]);
            
            obj.hAxIntensity = most.idioms.axes('Parent',intensityPlotFlow);
            title(obj.hAxIntensity,'Intensity');
            xlabel(obj.hAxIntensity,'SLM Pixel Value');
            ylabel(obj.hAxIntensity,'SLM Pixel Intensity');
            box(obj.hAxIntensity,'on');
            grid(obj.hAxIntensity,'on');
            
            obj.hLineIntensityFit = line('Parent',obj.hAxIntensity,'XData',[],'YData',[],'Color',[pink 0.5],'LineWidth',2);
            obj.hLineIntensity = line('Parent',obj.hAxIntensity,'XData',[],'YData',[]);
            obj.hLineIntensityMarkers = line('Parent',obj.hAxIntensity,'XData',[],'YData',[],'Color',pink,'LineStyle','none','Marker','o');
            obj.hPatchLutWindow = patch('Parent',obj.hAxIntensity,'LineStyle','none','FaceColor',[0 0 0],'FaceAlpha',0.3,'Vertices',[],'Faces',[],'ButtonDownFcn',@obj.brush);
            
            obj.hAxLut = most.idioms.axes('Parent',lutPlotFlow);
            title(obj.hAxLut,'LUT');
            xlabel(obj.hAxLut,'Phi');
            ylabel(obj.hAxLut,'SLM Pixel Value');
            box(obj.hAxLut,'on');
            grid(obj.hAxLut,'on');
            
            obj.hLineLutFit = line('Parent',obj.hAxLut,'XData',[],'YData',[],'LineWidth',2,'Color',[pink 0.5]);
            obj.hLineLutRaw = line('Parent',obj.hAxLut,'XData',[],'YData',[]);
            obj.hTextLut = text('Parent',obj.hAxLut,'String','','VerticalAlignment','top','HorizontalAlignment','left','Color',[1 1 1]);
            
            obj.hLiveViewTimer = timer('Name','SLM LUT Calibration Live View Timer','ExecutionMode','fixedRate','Period',0.05,'TimerFcn',@obj.liveViewCallback);
            
            obj.guiInitted = true;
            
            %%% local functions
            function toggleLive(varargin)
                if obj.started
                    obj.abort();
                else
                    obj.startLiveMode();
                end
            end
            
            function setPistonVal(src,evt)
                obj.generatePiston(src.Value*double(intmax(obj.hSlm.hDevice.pixelDataType)));
            end
            
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
        
        
        
        function updateGui(obj)
            if obj.guiInitted
                obj.cameraChanged();
                obj.updatePixelGrid();
            end
        end
        
        function cameraChanged(obj)
            datatype = obj.hCam.datatype;
            res = obj.camResolutionXY;
            
            [xx,yy,zz] = meshgrid([1 res(1)],[1 res(2)],0);
            xx = xx';
            yy = yy';
            zz = zz';
            
            obj.hSurfCam.XData = xx;
            obj.hSurfCam.YData = yy;
            obj.hSurfCam.ZData = zz;
            
            colormap(obj.hAxCam,'gray');
            
            vpCenter = (1 + res) / 2;
            vpSize = max(res);
            
            obj.updateViewPort(vpCenter,vpSize);
            obj.cameraImageLut = [datatype.getMinValue() datatype.getMaxValue()];
            obj.image = zeros(res(1), res(2), datatype.toMatlabType());
            
            obj.clearCache();
        end
        
        function startLiveMode(obj)
            assert(~obj.started,'Camera is already active');
            
            obj.startCam();
            
            start(obj.hLiveViewTimer);
        end
        
        function liveViewCallback(obj,src,evt)
            [images,metas] = obj.hCam.getAcquiredFrames();
            
            if ~isempty(images)
                image_ = images{end};
                obj.image = image_;
            end
        end
        
        function displayOrientationMarkers(obj)
            rects = obj.getOrientationMarkers();
            res = obj.slmResolutionXY;
            slmMask = zeros(res(1),res(2),obj.hSlm.hDevice.pixelDataType);
            
            for idx = 1:size(rects,1)
                slmMask(rects(idx,1):rects(idx,1)+rects(idx,3),rects(idx,2):rects(idx,2)+rects(idx,4)) = 1;
            end
            
            markerValue = max(obj.hSlm.hDevice.pixelDataType) * 1;
            
            slmMask = slmMask * markerValue;
            
            obj.hSlm.writePhaseMaskRaw(slmMask);
        end
        
        function abort(obj)
            if ~isempty(obj.hLiveViewTimer)
                stop(obj.hLiveViewTimer);
            end
            obj.stopCam();
            obj.started = false;
        end
        
        function clearCache(obj)
            obj.slmIntensity = [];
            obj.slmPhi = [];
            obj.slmPixelValues = [];
        end
        
        function I = cameraImagesToSlmIntensity(obj,images)
            slmRes = obj.slmResolutionXY();
            [xx,yy] = ndgrid(1:slmRes(1),1:slmRes(2));
            slmPixels = [xx(:),yy(:)];
            
            % transform images to slm Pixel Coordinates
            hSlmPixels = scanimage.mroi.coordinates.Points(obj.hCSSlmPixels,slmPixels);
            hSlmPixels = hSlmPixels.transform(obj.hCSCamPixels);
            slmPixels = hSlmPixels.points;
            
            I = zeros(slmRes(1),slmRes(2),size(images,3),'single'); % intensity
            
            for idx = 1:size(images,3)
                im = images(:,:,idx);
                im = single(im);
                
                im = filterImage(im);
                
                hGI = griddedInterpolant(im);
                slmIm = hGI(slmPixels);
                slmIm = reshape(slmIm,slmRes(1),slmRes(2));
                I(:,:,idx) = slmIm;
            end
            
            function im = filterImage(im)
                kernel = most.math.gaussianKernel([5 5],3);
                im = filter2(kernel,im);
            end
        end
        
        function phi = intensityToPhi(obj,I)
            [maxG,maxIdx] = max(I); % find global maximum
            [min1,min1Idx] = min(I(1:maxIdx-1));
            [min2,min2Idx] = min(I(maxIdx+1:end));
            min2Idx = min2Idx + maxIdx;
            
            I(1:maxIdx)     = normalize(I(1:maxIdx),min1,maxG);
            I(maxIdx+1:end) = normalize(I(maxIdx+1:end),min2,maxG);
            
            phi = real(acos(I));
            phid = diff(phi);
            
            phid(min1Idx:maxIdx-1) = - phid(min1Idx:maxIdx-1);
            phid(min2Idx:end) = - phid(min2Idx:end);
            phi = [phi(1) cumsum(phid)];
            
            function I = normalize(I,Imin,Imax)
                Imid = (Imin+Imax) / 2; % Intensity peak peak
                Ipp = Imax-Imin;
                I = ( I - Imid ) .* ( 2 ./ Ipp ); % scale to -1..1 range
            end
        end
        
        function [images,slmPixelValues] = measureSlmResponse(obj,decimation)
            assert(~obj.started,'Camera is already active.');
            
            if nargin < 2 || isempty(decimation)
                decimation = 1;
            end
            
            slmPixelValues = intmin(obj.hSlm.hDevice.pixelDataType):decimation:intmax(obj.hSlm.hDevice.pixelDataType);
            
            images = zeros(obj.hCam.resolutionXY(1),obj.hCam.resolutionXY(2),numel(slmPixelValues),obj.hCam.datatype);
            
            hWb = waitbar(0,'Measuring SLM Response','CreateCancelBtn',@abort);
            
            aborted = false;
            try
                obj.startCam();
                for idx = 1:numel(slmPixelValues)
                    assert(~aborted,'User aborted SLM Lut measurement');
                    
                    slmValue = slmPixelValues(idx);
                    obj.generatePiston(slmValue);
                    pause(0.01);
                    
                    [im,tfSaturated] = obj.grabNImages(10);
                    assert(~tfSaturated,'Camera image is saturated - aborted calibration. Reduce exposure or laser power.');
                    
                    images(:,:,idx) = im;
                    
                    obj.image = im;
                    
                    waitbar(idx/numel(slmPixelValues),hWb);
                end
                obj.stopCam();
            catch ME
                delete(hWb);
                obj.abort();
                rethrow(ME);
            end
            
            delete(hWb);
            obj.abort();
            
            function abort(varargin)
                aborted = true;
            end
        end
        
        function val = generatePiston(obj,val)
            slmMask = ones(obj.hSlm.hDevice.pixelResolutionXY(1),obj.hSlm.hDevice.pixelResolutionXY(2),obj.hSlm.hDevice.pixelDataType);
            val = cast(val,obj.hSlm.hDevice.pixelDataType);
            slmMask = slmMask * val;
            obj.hSlm.writePhaseMaskRaw(slmMask);
            obj.hSlPistonVal.Value = double(val) / double(intmax(obj.hSlm.hDevice.pixelDataType));
            obj.hTxtPiston.String = sprintf('SLM Value: %d',val);
        end
        
        function startCam(obj)
            if obj.hCam.isAcquiring
                obj.hCam.stop();
            end
            obj.hCam.start();
            obj.hCam.flush();
            
            obj.started = true;
        end
        
        function stopCam(obj)
            obj.started = false;
            
            if ~isempty(obj.hCam)
                obj.hCam.stop();
            end
        end
        
        function [image,tfSaturated] = grabNImages(obj,N,timeout)
            if nargin<3 || isempty(timeout)
                timeout = 100 * N;
            end
            
            wasIdle = ~obj.hCam.isAcquiring;
            if wasIdle
                obj.hCam.start();
            end
            
            obj.hCam.flush();
            
            images = cell(0,1);
            while numel(images) < N
                pause(0.01);
                [images_,meta_] = obj.hCam.getAcquiredFrames();
                images = vertcat(images,images_(:));
            end
            
            if wasIdle
                obj.hCam.stop();
            end
            
            images(N+1:end) = [];
            
            images = cat(3,images{:});
            tfSaturated = max(images(:))==intmax(class(images));
            
            image = mean(double(images),3);
            image = single(image);
        end
        
        function dragAlign(obj,src,evt)
            startPoint = obj.hAxCam.CurrentPoint(1,1:2);
            
            hSlmCornerPts = obj.getSlmCornerPts();
            hSlmCornerPts = hSlmCornerPts.transform(obj.hCSSlmPixels);
            slmCornersSlm = hSlmCornerPts.points;
            hSlmCornerPts = hSlmCornerPts.transform(obj.hCSCamPixels);
            slmCornersCam = hSlmCornerPts.points;
            
            d = bsxfun(@minus,slmCornersCam,startPoint);
            d = sqrt(sum(d.^2,2));
            [~,cornerIdx]=min(d);
            
            WindowButtonMotionFcn = obj.hFig.WindowButtonMotionFcn;
            WindowButtonUpFcn = obj.hFig.WindowButtonUpFcn;
            
            obj.hFig.WindowButtonMotionFcn = @move;
            obj.hFig.WindowButtonUpFcn = @abort;
            
            function move(varargin)
                try
                    obj.clearCache();
                    
                    pt = obj.hAxCam.CurrentPoint(1,1:2);
                    pt(1) = max( min(pt(1),obj.camResolutionXY(1)), 1);
                    pt(2) = max( min(pt(2),obj.camResolutionXY(2)), 1);
                    
                    slmCornersCam_new = slmCornersCam;
                    slmCornersCam_new(cornerIdx,:) = pt;
                    slmCornersCam_new(:,3) = 1;
                    slmCornersCam_new = slmCornersCam_new';
                    
                    slmCornersSlm_ = slmCornersSlm;
                    slmCornersSlm_(:,3) = 1;
                    slmCornersSlm_ = slmCornersSlm_';
                    
                    % inspired by this post:
                    % http://math.stackexchange.com/questions/296794/finding-the-transform-matrix-from-4-projected-points-with-javascript
                    a = slmCornersCam_new(:,1:end-1);
                    b = slmCornersCam_new(:,end);
                    c = a\b;
                    A = bsxfun(@times,a,c');
                    
                    a = slmCornersSlm_(:,1:end-1);
                    b = slmCornersSlm_(:,end);
                    c = a\b;
                    B = bsxfun(@times,a,c');
                    
                    T = A/B;
                    
                    try
                        obj.hCSSlmPixels.toParentAffine = T;
                        obj.updateImageStats();
                    catch ME
                    end
                    
                    obj.updatePixelGrid();
                catch ME
                    abort();
                    rethrow(ME);
                end
            end
            
            function abort(varargin)
                obj.hFig.WindowButtonUpFcn = WindowButtonUpFcn;
                obj.hFig.WindowButtonMotionFcn = WindowButtonMotionFcn;
            end
        end
        
        function pan(obj,src,evt)
            startPoint = obj.hAxCam.CurrentPoint(1,1:2);
            
            WindowButtonMotionFcn = obj.hFig.WindowButtonMotionFcn;
            WindowButtonUpFcn = obj.hFig.WindowButtonUpFcn;
            
            obj.hFig.WindowButtonMotionFcn = @move;
            obj.hFig.WindowButtonUpFcn = @abort;
            
            function move(varargin)
                try
                    pt = obj.hAxCam.CurrentPoint(1,1:2);
                    vpCenter = obj.viewPortCenter - (pt-startPoint);
                    obj.updateViewPort(vpCenter,obj.viewPortSize);
                catch ME
                    abort();
                    rethrow(ME);
                end
            end
            
            function abort(varargin)
                obj.hFig.WindowButtonUpFcn = WindowButtonUpFcn;
                obj.hFig.WindowButtonMotionFcn = WindowButtonMotionFcn;
            end
        end
        
        function zoom(obj,src,evt)
            pt = obj.hAxCam.CurrentPoint(1,1:2);
            
            if most.gui.isMouseInAxes(obj.hAxCam,pt)
                zoom = 2^evt.VerticalScrollCount;
                
                vpSize = obj.viewPortSize * zoom;
                
                d = pt-obj.viewPortCenter;
                vpCenter = obj.viewPortCenter + d * zoom;
                
                obj.updateViewPort(vpCenter, vpSize);
            end
        end
        
        function hover(obj,src,evt)
            if obj.guiInitted
                pt = obj.hAxCam.CurrentPoint(1,1:2);
                
                if most.gui.isMouseInAxes(obj.hAxCam,pt)
                    hPt = scanimage.mroi.coordinates.Points(obj.hCSCamPixels,pt);
                    hPt = hPt.transform(obj.hCSSlmPixels);
                    pt = hPt.points;
                    pt = round(pt);
                    
                    res = obj.slmResolutionXY;
                    xCheck = pt(1)>=1 && pt(1)<=res(1);
                    yCheck = pt(2)>=1 && pt(2)<=res(2);
                    
                    if xCheck && yCheck
                        obj.updateLutPlot(pt);
                    end
                end
            end
        end
        
        function brush(obj,src,evt)
            pt = obj.hAxIntensity.CurrentPoint(1,1);
            [~,idx] = min(abs(obj.lutWindow - pt));
            
            WindowButtonMotionFcn = obj.hFig.WindowButtonMotionFcn;
            WindowButtonUpFcn = obj.hFig.WindowButtonUpFcn;
            
            obj.hFig.WindowButtonMotionFcn = @move;
            obj.hFig.WindowButtonUpFcn = @abort;
            
            function move(varargin)
                try
                    pt = obj.hAxIntensity.CurrentPoint(1,1);
                    obj.lutWindow(idx) = round(pt);
                catch ME
                    abort();
                    rethrow(ME);
                end
            end
            
            function abort(varargin)
                obj.hFig.WindowButtonMotionFcn = WindowButtonMotionFcn;
                obj.hFig.WindowButtonUpFcn = WindowButtonUpFcn;
            end
        end
        
        function updateLutWindow(obj)
            yLim = obj.hAxIntensity.YLim;
            
            obj.hPatchLutWindow.Vertices = [obj.lutWindow(1) yLim(1)
                obj.lutWindow(1) yLim(2)
                obj.lutWindow(2) yLim(2)
                obj.lutWindow(2) yLim(1)];
            obj.hPatchLutWindow.Faces = [1 2 3 4];
        end
        
        function updateLutPlot(obj,pt)
            if isempty(obj.slmIntensity)
                obj.hLineIntensity.XData = [];
                obj.hLineIntensity.YData = [];
                
                obj.hLineIntensityFit.XData = [];
                obj.hLineIntensityFit.YData = [];
                
                obj.hLineIntensityMarkers.XData = [];
                obj.hLineIntensityMarkers.YData = [];
                
                obj.hLineLutRaw.XData = [];
                obj.hLineLutRaw.YData = [];
                
                obj.hLineLutFit.XData = [];
                obj.hLineLutFit.YData = [];
                
                obj.hTextLut.String = '';
                return
            end
            
            info = obj.fitLutToPixel(pt);
            
            obj.hLineIntensity.XData = info.ptSlmVal;
            obj.hLineIntensity.YData = info.ptI;
            
            obj.hAxIntensity.YLim = [0 max(obj.slmIntensity(:))];
            obj.hAxIntensity.XLim = [info.ptSlmVal(1) info.ptSlmVal(end)];
            
            obj.hLineIntensityFit.XData = info.ptSlmValSelection;
            obj.hLineIntensityFit.YData = info.ptISelection;
            
            obj.hLineIntensityMarkers.XData = [info.IminPixVal1,info.IminPixVal2,info.ImaxPixVal];
            obj.hLineIntensityMarkers.YData = [info.Imin1      ,info.Imin2      ,info.Imax];
            
            obj.hAxLut.XLim = [0 2*pi];
            obj.hAxLut.YLim = [0 double(intmax(obj.hSlm.hDevice.pixelDataType))*1.1];
            
            obj.hLineLutRaw.XData = info.lutPhi;
            obj.hLineLutRaw.YData = info.lutPixelVal;
            
            phis = linspace(0,2*pi,100);
            pFit = polyval(info.lutP,phis);
            
            obj.hLineLutFit.XData = phis;
            obj.hLineLutFit.YData = pFit;
            
            obj.hTextLut.Position = [obj.hAxLut.XLim(1),obj.hAxLut.YLim(2) 0];
            obj.hTextLut.String = sprintf(' [%d,%d] MSE: %.2f',pt(1),pt(2),info.lutMSE);
            obj.hTextLut.Color = [0 0 0];
            
            obj.updateLutWindow();
        end
        
        function calculateAndSave(obj)
            hLut = obj.calculateLut();
            obj.hSlmScan.lut = hLut;
            hLut.plot();
            msgbox('LUT saved');
        end
        
        function hLut = calculateLut(obj)
            obj.abort();
            assert(~isempty(obj.slmIntensity),'No data present. Perform Calibration first.');
            
            res = obj.slmResolutionXY;
            lut = zeros(res(1),res(2),obj.lutPolyDeg+1,'single');
            MSE = zeros(res(1),res(2),'single');
            
            abortFlag = false;
            
            hWb = waitbar(0,'Calculating Pixel Lut','CreateCancelBtn',@abort);
            try
                for idx = 1:res(1)
                    for jdx = 1:res(2)
                        info = obj.fitLutToPixel([idx,jdx]);
                        lut(idx,jdx,:) = flipud(info.lutP(:));
                        MSE(idx,jdx,:) = info.lutMSE;
                        if abortFlag
                            error('User aborted calculation of LUT');
                        end
                    end
                    
                    waitbar(idx/res(1),hWb);
                end
            catch ME
                most.idioms.safeDeleteObj(hWb);
                rethrow(ME);
            end
            
            most.idioms.safeDeleteObj(hWb);
            
            %analyzeFittingResiduals(Residuals);
            
            hLut = scanimage.mroi.scanners.slmLut.SlmLutPixelPolynomials(lut);
            hLut.wavelength_um = obj.hSlm.wavelength_um;
            hLut.MSE = MSE;
            
            %%% local functions
            function abort(varargin)
                abortFlag = true;
            end
        end
        
        function info = fitLutToPixel(obj,pt)
            info = struct();
            
            p = double( obj.slmPixelValues(:) );
            I = double( squeeze(obj.slmIntensity(pt(1),pt(2),:)) );
            I = I(:);
            
            info.ptSlmVal = p;
            info.ptI = I;
            
            lutWindow_ = obj.lutWindow + 1; % convert from pixel value (0 based) to index (1 based)
            [IminIdx1,ImaxIdx,IminIdx2] = findFullPeriod(I,lutWindow_);
            Imax = I(ImaxIdx);
            Imin1 = I(IminIdx1);
            Imin2 = I(IminIdx2);
            
            info.IminPixVal1 = p(IminIdx1);
            info.IminPixVal2 = p(IminIdx2);
            info.ImaxPixVal  = p(ImaxIdx);
            info.Imin1 = Imin1;
            info.Imin2 = Imin2;
            info.Imax = Imax;
            
            p = p(IminIdx1:IminIdx2);
            I1 = I(IminIdx1:ImaxIdx);
            I2 = I(ImaxIdx+1:IminIdx2);
            
            info.ptSlmValSelection = p;
            info.ptISelection = [I1;I2];
            
            % perform the fit
            I1 = I1-(Imin1+Imax)/2;
            I1 = I1./(Imax-Imin1)*2;
            
            I2 = I2-(Imin2+Imax)/2;
            I2 = I2./(Imax-Imin2)*2;
            
            phi1 = real(acos(I1(:)));
            phi1_d = diff(phi1);
            phi1_d = -phi1_d;
            phi1 = [phi1(1); phi1(1)+cumsum(phi1_d)];
            phi2 = real(acos(I2(:)));
            phi = vertcat(phi1(:)-pi,phi2(:)+pi);
            
            [phi,ia] = unique(phi,'sorted');
            p = p(ia);
            
            [P,MSE] = polyfitFast(phi,p,obj.lutPolyDeg);
            
            info.lutPhi = phi;
            info.lutPixelVal = p;
            info.lutP = P;
            info.lutMSE = MSE;
            
            function [IminIdx1,ImaxIdx,IminIdx2] = findFullPeriod(I,window)
                % Savitzky-Golay filter for first derivative
                % http://www.statistics4u.info/fundstat_eng/cc_savgol_coeff.html
                kernel_d = -(-7:7)/280;
                
                ISmooth_d = filterKernel(I,kernel_d);
                ISmooth_d_clip = ISmooth_d(window(1):window(2));
                I_clip = I(window(1):window(2));
                
                % find all minima / maxima
                minimaIdxs = find(diff(sign(ISmooth_d_clip))>0); % positive 0 crossings are minima
                maximaIdxs = find(diff(sign(ISmooth_d_clip))<0); % negative 0 crossings are maxima
                
                % get the actual maximum
                [~,idx] = min(abs([I_clip(minimaIdxs),I_clip(minimaIdxs+1)]),[],2);
                minimaIdxs = minimaIdxs + idx - 1;
                
                [~,idx] = min(abs([I_clip(maximaIdxs),I_clip(maximaIdxs+1)]),[],2);
                maximaIdxs = maximaIdxs + idx - 1;
                
                % find biggest maximum
                [~,ImaxIdxIdx] = max(I_clip(maximaIdxs));
                ImaxIdx = maximaIdxs(ImaxIdxIdx);
                
                % find biggest maximum closest to window center
                safetyDistance = 15;
                minimaIdxs1 = minimaIdxs(minimaIdxs<ImaxIdx-safetyDistance);
                minimaIdxs2 = minimaIdxs(minimaIdxs>ImaxIdx+safetyDistance);
                
                if isempty(minimaIdxs1)
                    IminIdx1 = 1;
                else
                    IminIdx1 = minimaIdxs1(end);
                end
                
                if isempty(minimaIdxs2)
                    IminIdx2 = numel(ISmooth_d_clip);
                else
                    IminIdx2 = minimaIdxs2(1);
                end
                
                IminIdx1 = IminIdx1 + window(1) - 1;
                IminIdx2 = IminIdx2 + window(1) - 1;
                ImaxIdx  = ImaxIdx  + window(1) - 1;
            end
        end
        
        function updateViewPort(obj,vpCenter,vpSize)
            res = obj.camResolutionXY;
            vpSize = min( max(vpSize,1), max(res));
            
            xSz = res(1) * vpSize/max(res);
            ySz = res(2) * vpSize/max(res);
            
            vpCenter(1) = min( max(vpCenter(1),1+xSz/2), res(1)-xSz/2);
            vpCenter(2) = min( max(vpCenter(2),1+ySz/2), res(2)-ySz/2);
            
            obj.hAxCam.XLim = vpCenter(1) + xSz * [-0.5 0.5];
            obj.hAxCam.YLim = vpCenter(2) + ySz * [-0.5 0.5];
            
            obj.viewPortSize = vpSize;
            obj.viewPortCenter = vpCenter;
            
            obj.updatePixelGrid();
            
            obj.hTextCam.Position = [obj.hAxCam.XLim(2) obj.hAxCam.YLim(1) 0];
        end
        
        function updatePixelGrid(obj)
            res = obj.slmResolutionXY;
            
            hSlmCornerPts = obj.getSlmCornerPts();
            hSlmCornerPts = hSlmCornerPts.transform(obj.hCSCamPixels);
            slmCorners = hSlmCornerPts.points;
            obj.hLineSlmCorners.XData = slmCorners(:,1);
            obj.hLineSlmCorners.YData = slmCorners(:,2);
            obj.hLineSlmOutline.XData = [slmCorners(:,1); slmCorners(1,1)];
            obj.hLineSlmOutline.YData = [slmCorners(:,2); slmCorners(1,2)];
            
            % pixel grid
            gridPts = zeros(0,2);
            
            if obj.pixelGridVisible
                xxHor = [1-0.5;res(1)+0.5;NaN];
                xxHor = repmat(xxHor,res(2)+1,1);
                yyHor = (0:res(2)) + 0.5;
                yyHor = [yyHor;yyHor];
                yyHor(end+1,:) = NaN;
                yyHor = yyHor(:);
                
                xxVer = (0:res(1)) + 0.5;
                xxVer = [xxVer;xxVer];
                xxVer(end+1,:) = NaN;
                xxVer = xxVer(:);
                yyVer = [1-0.5;res(2)+0.5;NaN];
                yyVer = repmat(yyVer,res(1)+1,1);
                
                pts_ = [NaN  , NaN;
                    xxVer, yyVer;
                    NaN  , NaN;
                    xxHor, yyHor];
                
                gridPts = vertcat(gridPts,pts_);
            end
            
            if obj.orientationMarkerVisible
                rects = obj.getOrientationMarkers();
                
                pts_ = cell(size(rects,1),1);
                
                for idx = 1:size(rects,1)
                    rect = rects(idx,:);
                    pts_{idx} = [rect(1)         rect(2)
                        rect(1)+rect(3) rect(2)
                        rect(1)+rect(3) rect(2)+rect(4)
                        rect(1)         rect(2)+rect(4)
                        rect(1)         rect(2)
                        NaN             NaN];
                end
                
                pts_ = vertcat(pts_{:});
                
                gridPts = vertcat(gridPts,[NaN NaN],pts_);
            end
            
            hPixels = scanimage.mroi.coordinates.Points(obj.hCSSlmPixels,gridPts);
            hPixels = hPixels.transform(obj.hCSCamPixels);
            gridPts = hPixels.points;
            
            obj.hLineSlmPixels.XData = gridPts(:,1);
            obj.hLineSlmPixels.YData = gridPts(:,2);
        end
        
        function rect = getOrientationMarkers(obj)
            res = obj.slmResolutionXY;
            sz = round(min(res) / 16) * 2; % ensure even number
            rect1 = [1 1 sz sz];
            rect2 = [ceil(res(1)/2-sz/2+1) 1 sz sz];
            rect = [rect1;rect2];
        end
        
        function cameraNames = getSICameraNames(obj)
            cameraNames = arrayfun(@(w)w.cameraName,obj.hModel.hCameraManager.hCameraWrappers,'UniformOutput',false);
        end
        
        function hPts = getSlmCornerPts(obj)
            res = obj.slmResolutionXY;
            pts = [1 1
                res(1) 1
                res(1) res(2)
                1      res(2)];
            
            hPts = scanimage.mroi.coordinates.Points(obj.hCSSlmPixels,pts);
        end
        
        function updateImageStats(obj)
            I = obj.cameraImagesToSlmIntensity(obj.image);
            txt = sprintf('SLM Max: %2.f Mean: %.2f Std: %.2f ',max(I(:)),mean(I(:)),std(I(:)));
            obj.hTextCam.String = txt;
        end
        
        function zprvEnsureClassDataFileProps(obj)
            obj.ensureClassDataFile(struct('CSSlmPixels',[]),obj.classDataFileName);
        end
        
        function saveClassData(obj)
            try
                if obj.guiInitted
                    CSSlmPixels = obj.hCSSlmPixels.toStruct();
                    obj.setClassDataVar('CSSlmPixels',CSSlmPixels,obj.classDataFileName);
                end
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
        end
        
        function loadClassData(obj)
            CSSlmPixels = obj.getClassDataVar('CSSlmPixels',obj.classDataFileName);
            if ~isempty(CSSlmPixels)
                obj.hCSSlmPixels.fromStruct(CSSlmPixels);
                obj.updatePixelGrid();
            end
        end
    end
    
    %% Property getter/setter
    methods
        function set.lutPolyDeg(obj,val)
            validateattributes(val,{'numeric'},{'finite','nonnan','integer','positive','scalar'});
            obj.lutPolyDeg = val;
        end
        
        function set.orientationMarkerVisible(obj,val)
            validateattributes(val,{'numeric','logical'},{'binary','scalar'});
            
            obj.orientationMarkerVisible = val;
            obj.updatePixelGrid();
            if val
                obj.displayOrientationMarkers();
            end
        end
        
        function set.lutWindow(obj,val)
            obj.lutWindow = sort(val);
            obj.lutWindow(1) = max(0,obj.lutWindow(1));
            obj.lutWindow(2) = min(intmax(obj.hSlm.hDevice.pixelDataType),obj.lutWindow(2));
            obj.updateLutWindow();
        end
        
        function set.pixelGridVisible(obj,val)
            validateattributes(val,{'numeric','logical'},{'binary','scalar'});
            obj.pixelGridVisible = logical(val);
            obj.updatePixelGrid();
        end
        
        function val = get.camResolutionXY(obj)
            val = double(obj.hCam.resolutionXY);
        end
        
        function val = get.slmResolutionXY(obj)
            val = double(obj.hSlm.hDevice.pixelResolutionXY);
        end
        
        function set.cameraImageLut(obj,val)
            obj.hAxCam.CLim = val;
        end
        
        function val = get.cameraImageLut(obj)
            val = obj.hAxCam.CLim;
        end
        
        function set.hCameraWrapper(obj,val)
            obj.hCameraWrapper = val;
            obj.cameraChanged();
        end
        
        function set.image(obj,val)
            obj.image = val;
            obj.hSurfCam.CData = val;
            
            obj.updateImageStats();
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
        
        function set.started(obj,val)
            obj.started = val;
            
            if obj.started
                obj.hPbStartLiveView.String = 'Abort';
            else
                obj.hPbStartLiveView.String = 'Start Live View';
            end
        end
        
        function val = get.hCam(obj)
            val = [];
            if ~isempty(obj.hCameraWrapper) && isvalid(obj.hCameraWrapper)
                val = obj.hCameraWrapper.hDevice;
            end
        end
    end
end

function [P,MSE] = polyfitFast(x,y,n)
x = x(:);
y = y(:);
M = bsxfun(@power,x,n:-1:0);
P = M\y;

y_ = polyval(P,x);
MSE = mean((y_-y).^2);
end

function ISmooth = filterKernel(I,kernel)
ISmooth = filter(kernel,1,I);
ISmooth = circshift(ISmooth,-floor(numel(kernel)/2)); % remove filter delay
ISmooth(1:floor(numel(kernel)/2)) = ISmooth(floor(numel(kernel)/2)+1); % undo filter boundary effects
ISmooth(end-floor(numel(kernel)/2)+1:end) = ISmooth(end-floor(numel(kernel)/2));
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
