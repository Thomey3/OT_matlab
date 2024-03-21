classdef SlmSpatialCalibration < most.Gui
    properties (SetAccess = private, Hidden)
        guiInitted = false;
        
        images = [];
        calibrationPoints = [];
        fastZInitialPosition = [];
        centroids = [];
        
        hAx;
        hSurf;
        hLineMarker;
        
        hCSImage;
        
        viewPortSize = 10;
        viewPortCenter = [0 0];
        
        hChannelLutListener
    end
    
    properties (SetObservable)
        burnPower_percent = 100;
        burnDuration_ms = 100;
        
        zRange = [-10 10];
        zSteps = 10;
        
        gridSize = 3;
        gridSpan_um = 100;
        imageUsingFastZ = false;
        moveWithFastZ = false;
        
        channel = 1;
    end
    
    properties (Dependent)
        hCSReference;
        zs;
        hSlmScan;
        hSlm;
        
        image;
    end
    
    %% Lifecycle
    methods
        function obj = SlmSpatialCalibration(hModel, hController)
            size = [200,50];
            obj = obj@most.Gui(hModel,hController,size,'characters');
        end
        
        function delete(obj)
            try
                most.idioms.safeDeleteObj(obj.hChannelLutListener);
                most.idioms.safeDeleteObj(obj.hCSImage);
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
        end
    end
    
    %% Gui methods
    methods (Access = protected)
        function initGui(obj)
            obj.hFig.Name = 'SLM Spatial Calibration';
            obj.hCSImage = scanimage.mroi.coordinates.CSLinear('Slm Spatial Calibration Image Pixels',3,obj.hCSReference);
            
            if isempty(obj.hSlmScan)
                uicontrol('Parent',obj.hFig,'Style','text','String','No SLM found in system','HorizontalAlignment','center','Units','normalized','Position',[0 0 1 1]);
                return
            end
            
            obj.hFig.WindowScrollWheelFcn = @obj.zoom;
            
            mainFlow = most.gui.uiflowcontainer('Parent',obj.hFig,'FlowDirection','LeftToRight');
            leftFlow  = most.gui.uiflowcontainer('Parent',mainFlow,'FlowDirection','TopDown');
            set(leftFlow,'WidthLimits',[150 150]);
            rightFlow = most.gui.uiflowcontainer('Parent',mainFlow,'FlowDirection','TopDown');
            
            panelFlow = most.gui.uiflowcontainer('Parent',leftFlow,'FlowDirection','LeftToRight','HeightLimits',[200 200]);
            hButtonPanel = uipanel('Parent', panelFlow);
            hButtonPanelFlow = most.gui.uiflowcontainer('Parent',hButtonPanel,'FlowDirection','TopDown');
            
            obj.addUiControl('Parent',hButtonPanelFlow,'Style','pushbutton','String','Burn Test Pattern','Callback',@(varargin)obj.burnTestPattern);
            obj.addUiControl('Parent',hButtonPanelFlow,'Style','pushbutton','String','Start Calibration','Callback',@(varargin)obj.startCalibration);
            obj.addUiControl('Parent',hButtonPanelFlow,'Style','pushbutton','String','Save Calibration','Callback',@(varargin)obj.saveCalibration);
            obj.addUiControl('Parent',hButtonPanelFlow,'Style','pushbutton','String','Reset Saved Calibration','Callback',@(varargin)obj.resetCalibration);
            
            panelFlow = most.gui.uiflowcontainer('Parent',leftFlow,'FlowDirection','LeftToRight','HeightLimits',[230 230]);
            hConfigPanel = uipanel('Parent', panelFlow);
            hConfigPanelFlow = most.gui.uiflowcontainer('Parent',hConfigPanel,'FlowDirection','TopDown');
            
            container = most.gui.uiflowcontainer('Parent',hConfigPanelFlow,'FlowDirection','LeftToRight');
            obj.addUiControl('Parent',container,'Style','text','String','Burn Power [%]','WidthLimits',[95 95],'HorizontalAlignment','right');
            obj.addUiControl('Parent',container,'Style','edit','Bindings',{obj 'burnPower_percent' 'value'});
            
            container = most.gui.uiflowcontainer('Parent',hConfigPanelFlow,'FlowDirection','LeftToRight');
            obj.addUiControl('Parent',container,'Style','text','String','Burn Duration [ms]','WidthLimits',[95 95],'HorizontalAlignment','right');
            obj.addUiControl('Parent',container,'Style','edit','Bindings',{obj 'burnDuration_ms' 'value'});
            
            container = most.gui.uiflowcontainer('Parent',hConfigPanelFlow,'FlowDirection','LeftToRight');
            obj.addUiControl('Parent',container,'Style','text','String','Grid Size','WidthLimits',[95 95],'HorizontalAlignment','right');
            obj.addUiControl('Parent',container,'Style','edit','Bindings',{obj 'gridSize' 'value'});
            
            container = most.gui.uiflowcontainer('Parent',hConfigPanelFlow,'FlowDirection','LeftToRight');
            obj.addUiControl('Parent',container,'Style','text','String','Grid Span [um]','WidthLimits',[95 95],'HorizontalAlignment','right');
            obj.addUiControl('Parent',container,'Style','edit','Bindings',{obj 'gridSpan_um' 'value'});
            
            container = most.gui.uiflowcontainer('Parent',hConfigPanelFlow,'FlowDirection','LeftToRight');
            obj.addUiControl('Parent',container,'Style','text','String','Imaging Channel','WidthLimits',[95 95],'HorizontalAlignment','right');
            obj.addUiControl('Parent',container,'Style','edit','Bindings',{obj 'channel' 'value'});
            
            container = most.gui.uiflowcontainer('Parent',hConfigPanelFlow,'FlowDirection','LeftToRight');
            obj.addUiControl('Parent',container,'Style','text','String','Number of Z Steps','WidthLimits',[95 95],'HorizontalAlignment','right');
            obj.addUiControl('Parent',container,'Style','edit','Bindings',{obj 'zSteps' 'value'});
            
            container = most.gui.uiflowcontainer('Parent',hConfigPanelFlow,'FlowDirection','LeftToRight');
            obj.addUiControl('Parent',container,'Style','text','String','Z Range','WidthLimits',[70 70],'HorizontalAlignment','right');
            obj.addUiControl('Parent',container,'Style','edit','Bindings',{obj 'zRange' 'value'});
            
            obj.addUiControl('Parent',hConfigPanelFlow,'Style','checkbox','string','Use Fast Z for Focus','Bindings',{obj 'moveWithFastZ' 'value'},'HeightLimits',[20 20]);
            obj.addUiControl('Parent',hConfigPanelFlow,'Style','checkbox','string','Use Fast Z for Imaging','Bindings',{obj 'imageUsingFastZ' 'value'},'HeightLimits',[20 20]);
            
            obj.hAx = most.idioms.axes('Parent',rightFlow,'DataAspectRatio',[1 1 1],'XTick',[],'YTick',[],'Color',[0 0 0]);
            obj.hAx.ButtonDownFcn = @obj.pan;
            box(obj.hAx,'on');
            
            view(obj.hAx,0,-90);
            colormap(obj.hAx,'gray');
            
            pink = [1 0 0.5647];
            obj.hSurf = surface('Parent',obj.hAx,'FaceColor','texturemap','EdgeColor','none','CData',[],'Hittest','off','PickableParts','none');
            obj.hLineMarker = line('Parent',obj.hAx,'Color',pink,'LineStyle','none','Marker','+','XData',[],'YData',[],'LineWidth',1.5);
            
            obj.hChannelLutListener = most.ErrorHandler.addCatchingListener(obj.hModel.hChannels,'channelLUT','PostSet',@(varargin)obj.lutChanged);
            obj.lutChanged();
            
            obj.updateViewPort(obj.viewPortCenter,obj.viewPortSize);
            
            obj.guiInitted = true;
        end
        
        function pan(obj,src,evt)
            startPoint = obj.hAx.CurrentPoint(1,1:2);
            
            WindowButtonMotionFcn = obj.hFig.WindowButtonMotionFcn;
            WindowButtonUpFcn = obj.hFig.WindowButtonUpFcn;
            
            obj.hFig.WindowButtonMotionFcn = @move;
            obj.hFig.WindowButtonUpFcn = @abort;
            
            function move(varargin)
                try
                    pt = obj.hAx.CurrentPoint(1,1:2);
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
            pt = obj.hAx.CurrentPoint(1,1:2);
            
            if most.gui.isMouseInAxes(obj.hAx,pt)
                zoom = 2^evt.VerticalScrollCount;
                
                vpSize = obj.viewPortSize * zoom;
                
                d = pt-obj.viewPortCenter;
                vpCenter = obj.viewPortCenter + d * zoom;
                
                obj.updateViewPort(vpCenter, vpSize);
            end
        end
        
        function updateViewPort(obj,vpCenter,vpSize)
            xx = obj.hSurf.XData;
            yy = obj.hSurf.YData;
            
            sfXSpan = [min(xx(:)) max(xx(:))] * 1.2;
            sfYSpan = [min(yy(:)) max(yy(:))] * 1.2;
            sfCenter = [sum(sfXSpan)/2 sum(sfYSpan)/2];
            
            vpSize = min(vpSize,max([diff(sfXSpan) diff(sfYSpan)]));
            
            vpCenter(1) = max(min(vpCenter(1),sfCenter(1)+diff(sfXSpan)/2-vpSize/2),sfCenter(1)-diff(sfXSpan)/2+vpSize/2);
            vpCenter(2) = max(min(vpCenter(2),sfCenter(2)+diff(sfYSpan)/2-vpSize/2),sfCenter(2)-diff(sfYSpan)/2+vpSize/2);
            
            obj.hAx.XLim = vpCenter(1) + vpSize * [-0.5 0.5];
            obj.hAx.YLim = vpCenter(2) + vpSize * [-0.5 0.5];
            
            obj.viewPortSize = vpSize;
            obj.viewPortCenter = vpCenter;
        end
        
        function lutChanged(obj)
            luts = obj.hModel.hChannels.channelLUT;
            
            if numel(luts) >= obj.channel
                lut = luts{obj.channel};
                obj.hAx.CLim = lut;
            end
        end
    end
    
    %% Public methods
    methods
        function resetCalibration(obj)
            obj.hModel.hSlmScan.scannerToRefTransform = eye(3);
            obj.hModel.hSlmScan.hCSSlmAlignmentLut.fromParentInterpolant = {};
            obj.hModel.hSlmScan.hCSSlmAlignmentLut.toParentInterpolant = {};
        end
        
        function [T,zs] = startCalibration(obj)
            obj.clearCache();
            
            if obj.imageUsingFastZ
                fastZInitialPosition_ = obj.hModel.hFastZ.currentFastZs{1}.targetPosition;
            else
                fastZInitialPosition_ = 0;
            end
            
            if obj.moveWithFastZ
                motorStartZ = obj.hModel.hFastZ.currentFastZs{1}.targetPosition;
            else
                motorStartZ = obj.hModel.hMotors.samplePosition(3);
            end
            
            gridPts = obj.makeGrid();
            
            stop = false;
            hWb = waitbar(0,'Calibrating...','CreateCancelBtn',@(varargin)cancel);
            
            try
                images_{1} = obj.grabSIImage();
                %images_{1} = makeTestImages(images_{1},0,0);
                
                for zIdx = 1:size(gridPts,3)
                    assert(~stop,'Calibration cancelled by user');
                    
                    z = gridPts(1,3,zIdx);
                    obj.hModel.hMotors.moveSample([NaN, NaN, motorStartZ-z]);
                    
                    for ptIdx = 1:size(gridPts,1)
                        assert(~stop,'Calibration cancelled by user');
                        pt = gridPts(ptIdx,:,zIdx);
                        
                        % move into position for burning
                        if obj.moveWithFastZ
                            obj.hModel.hFastZ.currentFastZs{1}.move(motorStartZ - z);
                        else
                            if obj.imageUsingFastZ
                                obj.hModel.hFastZ.currentFastZs{1}.move(fastZInitialPosition_);
                            else
                                obj.hModel.hMotors.moveSample([NaN, NaN, motorStartZ-z]);
                            end
                        end
                        
                        obj.burnPoint(pt);
                        
                        % move into position for imaging
                        if obj.moveWithFastZ
                            obj.hModel.hFastZ.currentFastZs{1}.move(motorStartZ);
                        else
                            if obj.imageUsingFastZ
                                obj.hModel.hFastZ.currentFastZs{1}.move(fastZInitialPosition_ + z);
                            else
                                obj.hModel.hMotors.moveSample([NaN NaN motorStartZ]);
                            end
                        end
                        
                        image_ = obj.grabSIImage();
                        %image_ = makeTestImages(image_,zIdx,ptIdx);
                        images_{end+1} = image_;
                        
                        waitbar((zIdx-1)/numel(obj.zs)+(ptIdx-1)/size(gridPts,1)/numel(obj.zs),hWb);
                    end
                end
                
            catch ME
                delete(hWb);
                if obj.moveWithFastZ
                    obj.hModel.hFastZ.currentFastZs{1}.move(motorStartZ);
                else
                    obj.hModel.hMotors.moveSample([NaN NaN motorStartZ]);
                    if obj.imageUsingFastZ
                        obj.hModel.hFastZ.currentFastZs{1}.move(fastZInitialPosition_);
                    end
                end
                rethrow(ME);
            end
            
            delete(hWb);
            obj.hModel.hMotors.moveSample([NaN NaN motorStartZ]);
            
            if obj.moveWithFastZ
                obj.hModel.hFastZ.currentFastZs{1}.move(motorStartZ);
            else
                if obj.imageUsingFastZ
                    obj.hModel.hFastZ.currentFastZs{1}.move(fastZInitialPosition_);
                end
            end
            
            obj.images = cat(3,images_{:});
            gridPtsxx = gridPts(:,1,:);
            gridPtsyy = gridPts(:,2,:);
            gridPtszz = gridPts(:,3,:);
            obj.calibrationPoints = [gridPtsxx(:) gridPtsyy(:) gridPtszz(:)];
            obj.fastZInitialPosition = fastZInitialPosition_;
            
            obj.process();
            
            %%% local functions
            function cancel()
                stop = true;
            end
            
            function image = makeTestImages(image,zIdx,ptIdx)
                sz = size(image);
                
                if zIdx == 0
                    image = zeros(sz);
                else
                    pts = obj.makeGrid();
                    
                    xSpan = [min(reshape(pts(:,1,:),[],1)),max(reshape(pts(:,1,:),[],1))];
                    ySpan = [min(reshape(pts(:,2,:),[],1)),max(reshape(pts(:,2,:),[],1))];
                    
                    pts(:,1,:) = round((pts(:,1,:)-sum(xSpan)/2)/diff(xSpan)*sz(1)/2 + sz(1)/2);
                    pts(:,2,:) = round((pts(:,2,:)-sum(ySpan)/2)/diff(ySpan)*sz(2)/2 + sz(2)/2);
                    
                    numPts = size(pts,1);
                    
                    pts = pts(:,:,1:zIdx);
                    xx = pts(:,1,:);
                    yy = pts(:,2,:);
                    xx = xx(:);
                    yy = yy(:);
                    xx = xx(1:end-numPts+ptIdx);
                    yy = yy(1:end-numPts+ptIdx);
                    
                    idxs = sub2ind(sz,xx,yy);
                    image = zeros(sz);
                    image(idxs) = 1;
                end
                
                kernel = ones(10);
                image = filter2(kernel,image);
                image = image + rand(size(image))*0.3;
                image = image * double(intmax('uint16'))/2;
                image = cast(image,'uint16');
            end
        end
        
        function saveCalibration(obj)
            obj.resetCalibration();
            obj.process();
            
            % create and save Interpolants
            modelterms =[0 0 0; 1 0 0; 0 1 0; 0 0 1;...
                1 1 0; 1 0 1; 0 1 1; 1 1 1; 2 0 0; 0 2 0; 0 0 2;];
            
            hCentroids = obj.centroids.transform(obj.hSlmScan.hCSSlmAlignmentLut.hParent);
            centroids_ = hCentroids.points;
            
            obj.hSlmScan.hCSSlmAlignmentLut.toParentInterpolant = ...
                {most.math.polynomialInterpolant(obj.calibrationPoints,centroids_(:,1),modelterms),...
                most.math.polynomialInterpolant(obj.calibrationPoints,centroids_(:,2),modelterms),...
                most.math.polynomialInterpolant(obj.calibrationPoints,centroids_(:,3),modelterms)};
            
            obj.hSlmScan.hCSSlmAlignmentLut.fromParentInterpolant = ...
                {most.math.polynomialInterpolant(centroids_,obj.calibrationPoints(:,1),modelterms),...
                most.math.polynomialInterpolant(centroids_,obj.calibrationPoints(:,2),modelterms),...
                most.math.polynomialInterpolant(centroids_,obj.calibrationPoints(:,3),modelterms)};
            
            msgbox('Calibration saved','Info','help');
        end
        
        function burnTestPattern(obj)
            pts = obj.makeTestPattern();
            pts(:,3) = 0;
            
            for idx = 1:size(pts,1)
                pt = pts(idx,:);
                obj.burnPoint(pt);
            end
            
            obj.grabSIImage();
            
            msgbox('You should see 4 burnt points','Info','help');
        end
        
        function abort(obj)
            obj.hModel.abort();
        end
    end
    
    %% Internal methods
    methods (Access = private)
        function [im,roiData] = grabSIImage(obj)
            assert(~obj.hModel.hRoiManager.mroiEnable,'Cannot operate in mRoi mode');
            
            roiData = [];
            average = 10;
            
            timeout = average/obj.hModel.hRoiManager.scanFrameRate + 5;
            
            obj.hModel.hDisplay.displayRollingAverageFactor = 10;
            obj.hModel.startFocus();
            try
                t_start = tic();
                
                while toc(t_start) < timeout
                    pause(0.01);
                    
                    if ~isempty(obj.hModel.hDisplay.getRoiDataArray)
                        roiData = obj.hModel.hDisplay.getRoiDataArray;
                        if roiData(end).frameNumberAcq >= average
                            break
                        else
                            roiData = [];
                        end
                    end
                end
            catch ME
                obj.hModel.abort();
                rethrow(ME);
            end
            
            obj.hModel.abort();
            
            assert(~isempty(roiData),'Failed to grab data from ScanImage');
            assert(numel(roiData(1).zs)==1,'Detected multiple zs. Disable stacks');
            
            z = roiData(1).zs;
            sf = roiData(1).hRoi.get(z);
            
            obj.hCSImage.toParentAffine = scanimage.mroi.util.affine2Dto3D(sf.pixelToRefTransform);
            [xx,yy] = sf.meshgridOutline(10);
            obj.hSurf.XData = xx';
            obj.hSurf.YData = yy';
            obj.hSurf.ZData = zeros(size(xx));
            
            im = roiData(1).imageData{obj.channel}{1};
            im = repmat(im,1,1,average);
            for idx = 2:average
                im(:,:,idx) = roiData(idx).imageData{obj.channel}{1};
            end
            im = single(mean(im,3,'double'));
            
            obj.image = im;
            obj.lutChanged();
            
            obj.hAx.CLim = obj.hModel.hChannels.channelLUT{obj.channel};
        end
        
        function clearCache(obj)
            obj.images = [];
            obj.calibrationPoints = [];
            obj.centroids = [];
        end
        
        function burnPoint(obj,pt)
            if isnumeric(pt)
                pt = scanimage.mroi.coordinates.Points(obj.hSlmScan.hCSSlmAlignmentLut,pt);
            end
            
            obj.hSlm.pointScanner(pt);
            pause(0.05);
            
            try
                obj.hSlmScan.openShutters();
                setBeamsPowerFraction(obj.burnPower_percent/100);
                burnDuration_s = obj.burnDuration_ms / 1e3;
                pause(burnDuration_s); % software timing should be fine for this
                setBeamsPowerFraction(0);
                obj.hSlmScan.closeShutters();
            catch ME
                obj.hModel.abort();
                rethrow(ME);
            end
            
            obj.hSlm.parkScanner();
            
            function setBeamsPowerFraction(powerFraction)
                hBeams = obj.hSlmScan.hBeams;
                for idx = 1:numel(hBeams)
                    try
                        hBeams{idx}.setPowerFraction(powerFraction);
                    catch ME
                        most.ErrorHandler.logAndReportError(ME);
                    end
                end
            end
        end
        
        function process(obj)
            centroids_ = obj.processImages();
            obj.image = obj.images(:,:,end);
            
            centroids_(:,3) = obj.calibrationPoints(:,3);
            hCentroids = scanimage.mroi.coordinates.Points(obj.hCSImage,centroids_);
            hCentroids = hCentroids.transform(obj.hCSReference);
            centroids_ref = hCentroids.points;
            obj.hLineMarker.XData = centroids_ref(:,1);
            obj.hLineMarker.YData = centroids_ref(:,2);
            
            obj.centroids = hCentroids;
        end
        
        function centroids = processImages(obj)
            assert(~isempty(obj.images));
            
            stack = filterStack(obj.images);
            
            % first image in stack is reference
            for idx = 1:size(stack,3)
                slice = stack(:,:,idx);
                slice = (slice-mean(slice(:))) ./ std(slice(:));
                stack(:,:,idx) = slice;
            end
            
            stackd = diff(stack,1,3);
            stackd = abs(stackd);
            stackda = stackd;
            
            stackMed = median(stackd(:));
            stackMax = max(stackd(:));
            
            threshold = stackMed + 0.3 * (stackMax-stackMed);
            
            % binarize
            stackd = stackd > threshold;
            stackd = uint16(stackd);
            
            % label
            for idx = 1:size(stackd,3)
                stackd(:,:,idx) = most.math.anodeg_bwlabel(stackd(:,:,idx));
            end
            
            % get centroids
            centroids = zeros(0,2);
            for idx = 1:size(stackd,3)
                im = stackd(:,:,idx);
                im = getBiggestRegion(im);
                if ~any(im(:))
                    figure('Name', ['bad image=' num2str(idx) ' thr=' num2str(threshold)])
                    subplot(1,2,1)
                    imagesc(stackda(:,:,idx))
                    subplot(1,2,2)
                    imagesc(stack(:,:,idx))
                else
                    
                end 
                centroids(idx,:) = imageCentroid(im);
            end
            
            %%% Local function
            function im = getBiggestRegion(im)
                nRegions = max(im(:));
                nPixels = zeros(1,nRegions);
                for ridx = 1:nRegions
                    im_r = im==ridx;
                    nPixels(ridx) = sum(im_r(:));
                end
                
                if ~isempty(nPixels)
                    [~,ridx] = max(nPixels);
                    im = im==ridx;
                end
            end
            
            function pt = imageCentroid(im)
                im = single(im);
                im = im./sum(im(:)); % normalize im
                [I,J]=ndgrid(1:size(im,1),1:size(im,2));
                pt=[dot(I(:),im(:)),  dot(J(:),im(:))];
            end
            
            function stack = filterStack(stack)
                imClass = class(stack);
                kernel = most.math.gaussianKernel([5 5],3);
                
                stack = single(stack);
                for zIdx = 1:size(stack,3)
                    stack(:,:,zIdx) = filter2(kernel,stack(:,:,zIdx));
                end
                
                stack = cast(stack,imClass);
            end
        end
        
        function pts = makeTestPattern(obj)
            [xx,yy] = ndgrid([-0.5 0.5],[-0.5 0.5]);
            pts = [xx(:) yy(:)];
            
            pts(:,1) = pts(:,1) * obj.gridSpan_um;
            pts(:,2) = pts(:,2) * obj.gridSpan_um;
        end
        
        function pts = makeGrid(obj)
            xx = linspace(0,1,obj.gridSize);
            yy = linspace(0,1,obj.gridSize);
            
            xSpacing = xx(2)-xx(1);
            ySpacing = yy(2)-yy(1);
            
            d = ceil(sqrt(numel(obj.zs)));
            
            xs = linspace(0,xSpacing,d+1);
            ys = linspace(0,ySpacing,d+1);
            
            xs = xs(1:end-1);
            ys = ys(1:end-1);
            
            [xo,yo] = ndgrid(xs,ys);
            
            offsets = [xo(:) yo(:)];
            offsets = offsets(1:numel(obj.zs),:);
            
            xo = shiftdim(offsets(:,1),-2);
            yo = shiftdim(offsets(:,2),-2);
            
            [xx,yy] = ndgrid(xx,yy);
            
            xx = bsxfun(@plus,xx,xo);
            yy = bsxfun(@plus,yy,yo);
            
            % center grid around 0
            xxmax = max(xx(:));
            yymax = max(yy(:));
            
            xx = xx .* (obj.gridSpan_um/xxmax);
            yy = yy .* (obj.gridSpan_um/yymax);
            
            xx = xx - (obj.gridSpan_um/2);
            yy = yy - (obj.gridSpan_um/2);
            
            xx = reshape(xx,[],1,numel(obj.zs));
            yy = reshape(yy,[],1,numel(obj.zs));
            zz = repmat(shiftdim(obj.zs(:),-2),size(xx,1),1,1);
            
            pts = [xx,yy,zz];
        end
    end
    
    %% Property Getter/Setter
    methods
        function set.burnPower_percent(obj,val)
            validateattributes(val,{'numeric'},{'scalar','finite','nonnan','real','nonnegative','<=',100});
            obj.burnPower_percent = val;
        end
        
        function set.burnDuration_ms(obj,val)
            validateattributes(val,{'numeric'},{'scalar','finite','nonnan','real','nonnegative'});
            obj.burnDuration_ms = val;
        end
        
        function set.zRange(obj,val)
            validateattributes(val,{'numeric'},{'finite','nonnan','real','numel',2});
            val = sort(val);
            obj.zRange = val;
        end
        
        function set.zSteps(obj,val)
            validateattributes(val,{'numeric'},{'positive','integer','real','scalar'});
            obj.zSteps = val;
        end
        
        function set.gridSize(obj,val)
            validateattributes(val,{'numeric'},{'positive','integer','real','scalar'});
            obj.gridSize = val;
        end
        
        function set.gridSpan_um(obj,val)
            validateattributes(val,{'numeric'},{'positive','finite','nonnan','real','scalar'});
            obj.gridSpan_um = val;
        end
        
        function set.imageUsingFastZ(obj,val)
            validateattributes(val,{'numeric','logical'},{'scalar','binary'});
            obj.imageUsingFastZ = logical(val);
        end
        
        function set.channel(obj,val)
            validateattributes(val,{'numeric'},{'positive','integer','real','scalar'});
            obj.channel = val;
        end
        
        function val = get.hCSReference(obj)
            val = obj.hModel.hCoordinateSystems.hCSReference;
        end
        
        function val = get.zs(obj)
            val = linspace(obj.zRange(1),obj.zRange(2),obj.zSteps);
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
        
        function set.image(obj,val)
            obj.hSurf.CData = val;
            obj.hLineMarker.XData = [];
            obj.hLineMarker.YData = [];
        end
        
        function val = get.image(obj)
            val = obj.hSurf.CData;
        end
    end
end



% ----------------------------------------------------------------------------
% Copyright (C) 2021 Vidrio Technologies, LLC
% 
% ScanImage (R) 2021 is software to be used under the purchased terms
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
