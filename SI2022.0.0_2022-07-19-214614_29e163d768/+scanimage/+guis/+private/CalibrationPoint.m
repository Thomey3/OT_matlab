classdef CalibrationPoint < handle
    properties
        slmTargetXYZ = [0 0 0];
        stageZ = 0;
        fastZ = false;
        
        croppedImageSizePixels = 100;
        
        psfExtent = [-40 40];
        psfNumSlices = 13;
    end
    
    properties (SetAccess = private)
        croppedImagePosition = []; % 4 element vector: [xPosition yPosition xSize ySize]
        stackImages = {};
        stackSlmXYZ = zeros(0,3);
        stackImagesSaturated = [];
        
        cameraActualXY;
        slmActualZ;
        emission = [];
        calibrationValid = false;
    end
    
    properties (Dependent)
        dataAvailable
    end
    
    %% Lifecycle
    methods
        function obj = CalibrationPoint(slmTargetXYZ)
            if nargin < 1 || isempty(slmTargetXYZ)
                slmTargetXYZ = [];
            end
            
            obj.slmTargetXYZ = slmTargetXYZ;
        end
    end
    
    %% User Methods
    methods
        function reset(obj)
            obj.stackImages = {};
            obj.stackSlmXYZ = zeros(0,3);
            obj.croppedImagePosition = [];
            obj.cameraActualXY = [];
            obj.slmActualZ = [];
            obj.calibrationValid = false;
            obj.emission = [];
            obj.stackImagesSaturated = [];
        end
        
        function invalidate(obj)
            obj.calibrationValid = false;
        end
        
        function addCameraImage(obj,slmXYZ,image,saturated)
            image = obj.cropImageToSize(image);
            
            obj.stackImages{end+1} = image;
            obj.stackSlmXYZ(end+1,:) = slmXYZ;
            obj.stackImagesSaturated(end+1,:) = saturated;
        end
        
        function stackImages_filtered = getFilteredStack(obj)            
            stackImages_filtered = cellfun(@(im)obj.filterImage(im),obj.stackImages,'UniformOutput',false);
        end
        
        function im = filterImage(obj,im)
            kernel = most.math.gaussianKernel([5 5],3);
            for idx = 1:size(im,3)
                im(:,:,idx) = filter2(kernel,im(:,:,idx));
            end
        end
        
        function [Is,zs,I_max,z_max,Is_up,zs_up] = getZEmissionProfile(obj)
            stack_filtered = obj.getFilteredStack();
            
            stack_filtered = cat(3,stack_filtered{:});
            Is = squeeze(max(max(stack_filtered)));
            zs = obj.stackSlmXYZ(:,3);
            
            [zs,sortIdxs] = sort(zs);
            Is = Is(sortIdxs);
            
            upScalingFactor = 100;
            zs_up = linspace(min(zs),max(zs),upScalingFactor*numel(zs));
            Is_up = interp1(zs,Is,zs_up,'spline');
            
            [I_max,I_max_idx] = max(Is_up);
            z_max = zs_up(I_max_idx);
        end
        
        function finalize(obj)
            if numel(obj.stackImages) < 4
                return
            end
            
            peakAtEdgeOfCamera = obj.crop();
            
            [Is,zs,I_max,z_max] = obj.getZEmissionProfile();
            
            obj.emission = I_max;
            obj.slmActualZ = z_max;
            
            zs = sort(obj.stackSlmXYZ(:,3));
            zAtEdgeOfStack = z_max < zs(2) || z_max > zs(end-1);
            
            stack = cat(3,obj.stackImages{:});
            zMaxProj = max(stack,[],3);
            [~,idx] = max(zMaxProj(:));
            [x,y] = ind2sub(size(zMaxProj),idx);
            
            if isempty(obj.croppedImagePosition)
                obj.cameraActualXY = [x,y];
            else
                obj.cameraActualXY = [x,y] + obj.croppedImagePosition(1:2) - [1,1];
            end
            
            saturated = any(obj.stackImagesSaturated);
            
            obj.calibrationValid = ~zAtEdgeOfStack && ~peakAtEdgeOfCamera && ~saturated;
        end
        
        function nextSlmXYZ = getNextSlmStep(obj)           
            zs = obj.slmTargetXYZ(3) + linspace(obj.psfExtent(1),obj.psfExtent(2),obj.psfNumSlices);
            nextZIdx = size(obj.stackSlmXYZ,1) + 1;
            
            if nextZIdx > numel(zs)
                nextSlmXYZ = [];
            else
                nextZ = zs (nextZIdx); 
                nextSlmXYZ = [obj.slmTargetXYZ(1:2) nextZ];
            end
        end
        
        function peakAtEdgeOfCamera = crop(obj)
            if ~(isempty(obj.croppedImagePosition))
                % Image stack is already cropped
                return
            end
            
            if isempty(obj.stackImages)
                return
            end
            
            zProjection = cellplus(obj.stackImages);
            zProjection = obj.filterImage(zProjection);
            
            [~,maxIdx] = max(zProjection(:));
            [centerX,centerY] = ind2sub(size(zProjection),maxIdx);
            center = [centerX,centerY];
            
            % check if peak is too close to edge of camera image
            peakAtEdgeOfCamera = centerX<obj.croppedImageSizePixels/2 || centerX > size(zProjection,1)-obj.croppedImageSizePixels/2 || ...
                                 centerY<obj.croppedImageSizePixels/2 || centerY > size(zProjection,2)-obj.croppedImageSizePixels/2;
            
            startXY =  ceil(center - obj.croppedImageSizePixels/2);
            endXY   = floor(center + obj.croppedImageSizePixels/2);
            
            startXY = max(startXY, [1 1]);
            endXY   = min(endXY,   [size(zProjection,1), size(zProjection,2)]);
            
            obj.croppedImagePosition = [startXY, endXY-startXY+[1,1]];
            obj.stackImages = cellfun(@(im)obj.cropImageToSize(im),obj.stackImages,'UniformOutput',false);
            
            function out = cellplus(cellIn)
                out = cellIn{1};
                for idx = 2:numel(cellIn)
                    out = out + cellIn{idx};
                end
            end
        end
    end
    
    methods (Access = private)
        function im = cropImageToSize(obj,im)
            if ~isempty(obj.croppedImagePosition)                
                xStart = obj.croppedImagePosition(1);
                xEnd   = obj.croppedImagePosition(1) + obj.croppedImagePosition(3) - 1;
                
                yStart = obj.croppedImagePosition(2);
                yEnd   = obj.croppedImagePosition(2) + obj.croppedImagePosition(4) - 1;
                
                im = im(xStart:xEnd, yStart:yEnd, :);
            end
        end
    end
    
    %% Methods for loading/saving
    methods
        function s = toStruct(obj)
            s = struct();
            s.class = class(obj);
            
            s.fastZ = obj.fastZ;
            s.stageZ = obj.stageZ;
            s.slmTargetXYZ = obj.slmTargetXYZ;
            s.croppedImageSizePixels = obj.croppedImageSizePixels;
            s.psfExtent = obj.psfExtent;
            s.psfNumSlices = obj.psfNumSlices;
            s.stackImages = obj.stackImages;
            s.stackSlmXYZ = obj.stackSlmXYZ;
            s.croppedImagePosition = obj.croppedImagePosition;
            s.cameraActualXY = obj.cameraActualXY;
            s.slmActualZ = obj.slmActualZ;
            s.calibrationValid = obj.calibrationValid;
            s.emission = obj.emission;
            s.stackImagesSaturated = obj.stackImagesSaturated;
        end
        
        function fromStruct(obj,s)
            assert(strcmp(s.class,class(obj)));
            s = rmfield(s,'class');
            
            fields = fieldnames(s);
            for idx = 1:numel(fields)
                field = fields{idx};
                
                try
                    obj.(field) = s.(field);
                catch
                    fprintf(2,'CalibrationPoint: Could not load field ''%s''.\n',field);                    
                end
            end
        end
    end
    
    %% Property Getter/Setter
    methods
        function val = get.dataAvailable(obj)
            val = ~isempty(obj.stackImages);            
        end
        
        function set.psfExtent(obj,val)
            validateattributes(val,{'numeric'},{'row','numel',2,'nonnan','finite'});
            obj.psfExtent = sort(val);
        end
        
        function set.psfNumSlices(obj,val)
            validateattributes(val,{'numeric'},{'scalar','positive','integer'});
            obj.psfNumSlices = val;
        end
        
        function set.slmTargetXYZ(obj,val)
            if ~isempty(val)
                validateattributes(val,{'numeric'},{'row','numel',3,'nonnan','finite'});
            end
            obj.slmTargetXYZ = val;
        end
        
        function set.stageZ(obj,val)
            validateattributes(val,{'numeric'},{'scalar','nonnan','finite'});
            obj.stageZ = val;
        end
        
        function set.croppedImageSizePixels(obj,val)
            validateattributes(val,{'numeric'},{'scalar','positive','integer'});
            obj.croppedImageSizePixels = val;
        end
        
        function set.fastZ(obj,val)
            validateattributes(val,{'numeric','logical'},{'scalar','binary'});
            obj.fastZ = logical(val);
        end
        
        function set.calibrationValid(obj,val)
            validateattributes(val,{'numeric','logical'},{'scalar','binary'});
            obj.calibrationValid = logical(val);
        end
    end
    
    %% GUI
    methods
        function plot(obj)
            if nargin < 2 || isempty(hParent)
                figName = sprintf('Calibration Point %s',mat2str(obj.slmTargetXYZ));
                hFig = most.idioms.figure('NumberTitle','off','Name',figName);
                hFig.Position(3) = hFig.Position(3)*2;
            end
            
            hAx1 = most.idioms.subplot(2,3,1,'Parent',hFig);
            hIm1 = imagesc(hAx1,zeros(10));
            hAx1.DataAspectRatio = [1 1 1];
            hAx1.YDir = 'normal';
            colorbar(hAx1);
            colormap(hAx1,gray);
            hAx1Title = title(hAx1,'Z Max Projection');
            xlabel(hAx1,'Camera X [pixel]');
            ylabel(hAx1,'Camera Y [pixel]');
            view(hAx1,0,-90);
            
            hAx2 = most.idioms.subplot(2,3,2,'Parent',hFig);
            hIm2 = imagesc(hAx2,zeros(10));
            hAx2.YDir = 'normal';
            %hAx2.DataAspectRatio = [1 1 1];
            colorbar(hAx2);
            colormap(hAx2,gray);
            title(hAx2,'X Max Projection');
            xlabel(hAx2,'Camera Y [pixel]');
            ylabel(hAx2,'SLM Z [um]');
            view(hAx2,0,-90);
            
            hAx3 = most.idioms.subplot(2,3,3,'Parent',hFig);
            hIm3 = imagesc(hAx3,zeros(10));
            hAx3.YDir = 'normal';
            %hAx3.DataAspectRatio = [1 1 1];
            colorbar(hAx3);
            colormap(hAx3,gray);
            title(hAx3,'Y Max Projection');
            xlabel(hAx3,'Camera X [pixel]');
            ylabel(hAx3,'SLM Z [um]');
            view(hAx3,0,-90);
            
            hAx4 = most.idioms.subplot(2,3,[4 5 6],'Parent',hFig);
            hAx4.Box = 'on';
            hLine = line('Parent',hAx4,'XData',[],'YData',[],'Marker','o','LineStyle','none','Color','blue');
            hLineInterpolated = line('Parent',hAx4,'XData',[],'YData',[],'Color','blue');
            hLineMax = line('Parent',hAx4,'XData',[],'YData',[],'Marker','x','MarkerEdgeColor','red','MarkerSize',8,'LineWidth',1);
            hLineSelection = line('Parent',hAx4,'XData',[],'YData',[],'Marker','o','MarkerEdgeColor','red','MarkerFaceColor',[1 0.8 0.8]);
            title(hAx4,'Emission Profile');
            xlabel(hAx4,'SLM Z [um]');
            ylabel(hAx4,'Max Emission [pixel value]');
            grid(hAx4,'on');

            hFig.WindowButtonMotionFcn = @move;
            
            [Is,zs,I_max,z_max,Is_up,zs_up] = obj.getZEmissionProfile();
            zSelection = [];
            
            hLine.XData = zs;
            hLine.YData = Is;
            
            hLineInterpolated.XData = zs_up;
            hLineInterpolated.YData = Is_up;
            
            if obj.isvalid
                hLineMax.XData = obj.slmActualZ;
                hLineMax.YData = obj.emission;
            end
            
            stack = cat(3,obj.stackImages{:});
            
            stackZs = [min(obj.stackSlmXYZ(:,3)),max(obj.stackSlmXYZ(:,3))];
            maxXProj = max(stack,[],1);
            maxXProj = permute(maxXProj,[2 3 1]);
            hIm2.CData = maxXProj';
            hIm2.XData = [1 size(maxXProj,1)] - 0.5;
            hIm2.YData = stackZs;
            hAx2.XLim  = [1 size(maxXProj,1)] - 0.5;
            hAx2.YLim  = stackZs;
            
            maxYProj = max(stack,[],2);
            maxYProj = permute(maxYProj,[1 3 2]);
            hIm3.CData = maxYProj';
            hIm3.XData = [1 size(maxYProj,1)] - 0.5;
            hIm3.YData = stackZs;
            hAx3.XLim  = [1 size(maxYProj,1)] - 0.5;
            hAx3.YLim  = stackZs;
            
            maxZProj = max(stack,[],3);
            
            maxValue = max(stack(:));
            
%             hAx1.CLim = [0 maxValue];
%             hAx2.CLim = [0 maxValue];
%             hAx3.CLim = [0 maxValue];
            hAx4.YLim = [0 maxValue*1.2];
            
            update();
            
            %%% Local functions
            function move(src,evt)
                [inAxis, pt] = most.gui.isMouseInAxes(hAx4);
                if inAxis
                    dz = zs-pt(1);
                    [~,idx] = min(abs(dz));
                    zSelection = zs(idx);
                else
                    zSelection = [];
                end
                update();
            end
            
            function update()                
                if ~isempty(zSelection)
                    zIdx = find(zs == zSelection,1);
                    hLineSelection.XData = zs(zIdx);
                    hLineSelection.YData = Is(zIdx);
                else
                    hLineSelection.XData = [];
                    hLineSelection.YData = [];
                end
                
                if isempty(zSelection)              
                    hIm1.CData = maxZProj';
                    hIm1.XData = [1 size(maxZProj,1)] - 0.5;
                    hIm1.YData = [1 size(maxZProj,2)] - 0.5;
                    hAx1.XLim  = [1 size(maxZProj,1)] - 0.5;
                    hAx1.YLim  = [1 size(maxZProj,2)] - 0.5;
                    hAx1Title.String = 'Z Max Projection';
                else
                    
                    slice = stack(:,:,zIdx);
                    hIm1.CData = slice';
                    hIm1.XData = [1 size(slice,1)] - 0.5;
                    hIm1.YData = [1 size(slice,2)] - 0.5;
                    hAx1.XLim  = [1 size(slice,1)] - 0.5;
                    hAx1.YLim  = [1 size(slice,2)] - 0.5;
                    hAx1Title.String = sprintf('Z = %g',zSelection);
                end
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
