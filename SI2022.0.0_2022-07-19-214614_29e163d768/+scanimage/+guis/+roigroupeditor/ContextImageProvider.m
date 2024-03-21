classdef ContextImageProvider < matlab.mixin.SetGet & matlab.mixin.Heterogeneous
    %CONTEXTIMAGEPROVIDER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetObservable)
        name = '';
        source = '';
        visible = false;
        color = [0 0 1];
        z;
        zs;
        channels = {};
        channelSelIdx = 1;
        luts = {[0 100]};
        channelMergeColors = {{}};
        
        zTolerance;
        fillIntermediateZ;
    end
    
    properties (Hidden)
        hEditorGui;
        hSurfs = matlab.graphics.primitive.Surface.empty;
        hProjectionLines;
        hListeners = event.listener.empty;
        pmImageChannel;
        
        visibleSurfs;
        currZIdx;
        surfZMask;
        zRange;
        
        roiCPs = {{}};
        roiAffines = {{}};
        imgs = {{}};
        colorIdx;
        
        allowDelete = true;
    end
    
    %% Lifecycle
    methods
        function obj = ContextImageProvider(hEditorGui)
            obj.hEditorGui = hEditorGui;
            
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(hEditorGui, 'projectionMode', 'PostSet', @obj.updateProjectionLines);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(hEditorGui, 'editorZ', 'PostSet', @(varargin)obj.updateToZ(hEditorGui.editorZ));
        end
        
        function delete(obj)
            delete(obj.hListeners);
            delete(obj.hSurfs);
            delete(obj.hProjectionLines);
        end
    end
    
    %% Friend
    methods
        function s = getLegendAttributes(obj)
            s = struct(...
                'name', obj.name,...
                'lineColor', obj.color,...
                'lineStyle', '-',...
                'fillColor', [1 1 1],...
                'localBinding', '');
        end
        
        function decorateLegendItem(obj, itemHandles)
            itemHandles.hCb.bindings = {obj 'visible' 'value'};
            
            hFlw = most.gui.uiflowcontainer('parent',itemHandles.hContainer,'margin',3,'flowdirection','righttoleft');
            set(hFlw, 'WidthLimits', [58 58]);
            
            if obj.allowDelete
                hDelete = most.gui.uicontrol(...
                    'parent', hFlw,'tag','pbDeleteSS',...
                    'string', most.constants.Unicode.ballot_x,...
                    'callback', @obj.removeContextImage);
                set(hDelete, 'WidthLimits', [20 20]);
                hFlw.WidthLimits = hFlw.WidthLimits + 24;
            end
            
            obj.pmImageChannel = most.gui.uicontrol('parent',hFlw,'string', obj.channels, 'style','popupmenu',...
                'Bindings', {obj 'channelSelIdx' 'Value'}, 'visible', obj.hEditorGui.tfMap(numel(obj.channels) > 1),...
                'WidthLimits', [54 54],'KeyPressFcn', @obj.hEditorGui.keyPressFcn,'tag','pmSelectSSChan');
        end
        
        function removeContextImage(obj,varargin)
            try
                nm = obj.name;
                hRGE = obj.hEditorGui;
                hRGE.hContextImages(obj.hEditorGui.hContextImages == obj) = [];
                delete(obj);
                
                hRGE.updateMaxViewFov();
                hRGE.rebuildLegend();
                hRGE.scrollLegendToBottom();
            catch ME
                msg = sprintf('Error occured while deleting ''%s'' context image: %s', nm, ME.message);
                most.ErrorHandler.logAndReportError(ME, msg);
            end
        end
        
        function updateProjectionLines(obj, varargin)
            projectionZLayer = 0.3;
            nz = numel(obj.zs);
            nrz = numel(obj.roiCPs);
            if nz && (nz == nrz)
                if most.idioms.isValidObj(obj.hProjectionLines)
                    fh = @setProps;
                    vars = {obj.hProjectionLines};
                else
                    fh = @line;
                    vars = {'Parent' obj.hEditorGui.h2DProjectionViewAxes 'Color' obj.color,...
                        'linewidth' 8 'ButtonDownFcn' @obj.ctxImProjHit};
                end
                
                proj2DlinesXD = [];
                proj2DlinesYD = [];
                
                for i = 1:numel(obj.zs)
                    zi = obj.zs(i);
                    zRois = obj.roiCPs{i};
                    
                    for roiIdx = 1:numel(zRois)
                        pts = zRois{roiIdx}(:, obj.hEditorGui.projectionDim);
                        proj2DlinesXD = [proj2DlinesXD min(pts) max(pts) nan];
                        proj2DlinesYD = [proj2DlinesYD zi zi nan];
                    end
                end
                
                vars = [vars {'visible', obj.hEditorGui.tfMap(obj.visible) 'xdata' proj2DlinesXD...
                    'ydata' proj2DlinesYD 'zdata' projectionZLayer*ones(size(proj2DlinesXD))}];
                obj.hProjectionLines = fh(vars{:});
            else
                delete(obj.hProjectionLines);
                obj.hProjectionLines = [];
            end
            
            function h = setProps(varargin)
                set(varargin{:});
                h = varargin{1};
            end
        end
        
        function ctxImProjHit(obj,~,evt)
            obj.hEditorGui.editorZ = evt.IntersectionPoint(2);
        end
        
        function v = show(obj)
            v = ~isempty(obj.zs) && (numel(obj.zs) == numel(obj.roiCPs));
        end
        
        function v = setChannelIdx(obj,v)
            obj.updateImageData();
        end
        
        function jumpEditorToNearestZ(obj)
            [dist,i] = min(abs(obj.hEditorGui.editorZ - obj.zs));
            if dist
                obj.hEditorGui.editorZ = obj.zs(i);
            end
        end
        
        function idx = hitZ(obj,z)
            [minDist,idx] = min(abs(z - obj.zs));
            if isempty(obj.zs) || ~((minDist <= obj.zTolerance) ||...
                    (obj.fillIntermediateZ && (z > obj.zRange(1)) && (z < obj.zRange(2))))
                idx = [];
            end
        end
        
        function updateToZ(obj,v)
            mainZLayer = 0.3;
            zRois = [];
            obj.currZIdx = obj.hitZ(v);
            if ~isempty(obj.currZIdx)
                zRois = obj.roiCPs{obj.currZIdx};
            end
            
            nRois = numel(zRois);
            obj.surfZMask = [true(1,nRois) false(1,max(0,numel(obj.hSurfs)-nRois))];
            viz = obj.hEditorGui.tfMap(obj.visible);
            set(obj.hSurfs(~obj.surfZMask), 'visible','off');
            
            for iRoi = 1:nRois
                if (numel(obj.hSurfs) < iRoi) || ~most.idioms.isValidObj(obj.hSurfs(iRoi))
                    fh = @surface;
                    vars = {'Parent', obj.hEditorGui.h2DMainViewAxes, 'Hittest', 'off','linewidth', 1,...
                        'FaceColor', 'texturemap','CData', zeros(2, 2, 3, 'uint8'), 'AlphaData',0,...
                        'EdgeColor', obj.color, 'FaceAlpha','texturemap'};
                else
                    fh = @setProps;
                    vars = {obj.hSurfs(iRoi)};
                end
                
                xx = [zRois{iRoi}(1:2,1) zRois{iRoi}([4 3],1)];
                yy = [zRois{iRoi}(1:2,2) zRois{iRoi}([4 3],2)];
                
                vars = [vars {'visible' viz 'xdata' xx 'ydata' yy...
                    'zdata' mainZLayer*ones(2,2)} 'UserData' obj.roiAffines{obj.currZIdx}{iRoi}];
                obj.hSurfs(iRoi) = fh(vars{:});
            end
            
            obj.updateImageData();
            
            function h = setProps(varargin)
                set(varargin{:});
                h = varargin{1};
            end
        end
        
        function updateImageData(obj)
            if ~isempty(obj.currZIdx)
                if strcmp(obj.channels{obj.channelSelIdx}, 'Merge')
                    nchans = numel(obj.channels) - 1;
                    mergeEn = ~strcmp(obj.channelMergeColors, 'none');
                    
                    for iRoi = 1:numel(obj.imgs{obj.currZIdx})
                        imSz = size(obj.imgs{obj.currZIdx}{iRoi}{1});
                        alphaData = zeros(imSz,'single');
                        imSz(3) = 3;
                        colorData = zeros(imSz,'uint8');
                        for c = 1:nchans
                            if mergeEn(c)
                                img = obj.imgs{obj.currZIdx}{iRoi}{c};
                                [cdata, adata] = obj.scaleAndColorCData(img,obj.channelMergeColors{c},obj.luts{c});
                                colorData = colorData + cdata;
                                alphaData = alphaData | adata;
                            end
                        end
                        obj.hSurfs(iRoi).CData = colorData;
                        obj.hSurfs(iRoi).AlphaData = alphaData;
                    end
                else
                    lut = obj.luts{obj.channelSelIdx};
                    for iRoi = 1:numel(obj.imgs{obj.currZIdx})
                        imageData = obj.imgs{obj.currZIdx}{iRoi}{obj.channelSelIdx};
                        [colorData, alphaData] = obj.scaleAndColorCData(imageData,'gray',lut);
                        obj.hSurfs(iRoi).CData = colorData;
                        obj.hSurfs(iRoi).AlphaData = alphaData;
                    end
                end
            end
%             if obj.selectedChannelIsScanner
%                 lut = single(obj.hSI.hChannels.channelLUT{obj.channelSelIdx}) * obj.rollingAverageFactor;
%                 
%                 for i = 1:numel(stripeData.roiData)
%                     img = stripeData.roiData{i}.imageData{obj.channelSelIdx}{1};
%                     [colorData, alphaData] = obj.scaleAndColorCData(img,'gray',lut);
%                     obj.hSurfs(i).CData = colorData;
%                     obj.hSurfs(i).AlphaData = alphaData;
%                 end
%             else
%                 % merge
%                 nchans = numel(obj.scannerChans);
%                 mergeColors = obj.hSI.hChannels.channelMergeColor(obj.scannerChans);
%                 mergeEn = ~strcmp(mergeColors, 'none');
%                 luts = single(obj.hSI.hChannels.channelLUT{obj.scannerChans}) * obj.rollingAverageFactor;
%                 
%                 for i = 1:numel(stripeData.roiData)
%                     imSz = size(stripeData.roiData{i}.imageData{1}{1});
%                     alphaData = zeros(imSz,'single');
%                     imSz(3) = 3;
%                     colorData = zeros(imSz,'uint8');
%                     for c = 1:nchans
%                         if mergeEn(c)
%                             img = stripeData.roiData{i}.imageData{c}{1};
%                             [cdata, adata] = obj.scaleAndColorCData(img,mergeColors{c},luts{c});
%                             colorData = colorData + cdata;
%                             alphaData = alphaData | adata;
%                         end
%                     end
%                     obj.hSurfs(i).CData = colorData;
%                     obj.hSurfs(i).AlphaData = alphaData;
%                 end
%             end
        end
        
        function [cData, aData] = scaleAndColorCData(obj,data,clr,lut)
            lut = single(lut);
            maxVal = single(255);
            scaledData = uint8((single(data) - lut(1)) .* (maxVal / (lut(2)-lut(1))));
            
            switch lower(clr)
                case 'red'
                    cData = zeros([size(scaledData) 3],'uint8');
                    cData(:,:,1) = scaledData;
                case 'green'
                    cData = zeros([size(scaledData) 3],'uint8');
                    cData(:,:,2) = scaledData;
                case 'blue'
                    cData = zeros([size(scaledData) 2],'uint8');
                    cData(:,:,3) = scaledData;
                case 'gray'
                    cData(:,:,:) = repmat(scaledData,[1 1 3]);
                case 'none'
                    cData = zeros([size(scaledData) 3]);
                otherwise
                    assert(false);
            end
            
            if obj.hEditorGui.contextImageTransparency
                aData = double(scaledData > 0);
            else
                aData = 1;
            end
        end
    end
    
    %% Prop Access
    methods
        function v = get.visibleSurfs(obj)
            v = obj.hSurfs(strcmp({obj.hSurfs.Visible}, 'on'));
        end
        
        function set.visible(obj,v)
            try
                oldv = obj.visible;
                v = v && obj.show();
                obj.visible = v;
                
                if ~oldv && v && isempty(obj.hitZ(obj.hEditorGui.editorZ))
                    obj.jumpEditorToNearestZ();
                end
                
                if isempty(obj.z)
                    obj.z = obj.hEditorGui.editorZ;
                end
                
                vis = obj.hEditorGui.tfMap(v);
                set(obj.hSurfs(obj.surfZMask), 'Visible', vis);
                set(obj.hProjectionLines, 'Visible', vis);
            catch ME
                msg = sprintf('Error occured while setting ''%s'' context image visibility: %s', obj.name, ME.message);
                most.ErrorHandler.logAndReportError(ME, msg);
            end
        end
        
        function set.channelSelIdx(obj,v)
            try
                obj.channelSelIdx = v;
                obj.setChannelIdx(v);
            catch ME
                msg = sprintf('Error occured while setting ''%s'' context image channel: %s', obj.name, ME.message);
                most.ErrorHandler.logAndReportError(ME, msg);
            end
        end
        
        function set.z(obj,v)
            obj.updateToZ(v);
            obj.z = v;
        end
        
        function set.zs(obj,v)
            obj.zs = unique(v);
            if ~isempty(v)
                obj.zRange = [min(v) max(v)];
            end
            obj.updateProjectionLines();
        end
        
        function set.roiCPs(obj,v)
            obj.roiCPs = v;
            obj.updateProjectionLines();
        end
        
        function set.channels(obj,v)
            obj.channels = v;
            
            if most.idioms.isValidObj(obj.pmImageChannel)
                obj.pmImageChannel.Visible = obj.hEditorGui.tfMap(numel(v) > 1);
                obj.pmImageChannel.String = v;
            end
        end
        
        function v = get.zTolerance(obj)
            v = obj.zTolerance;
            if isempty(v)
                v = obj.hEditorGui.contextImageZTolerance;
            end
        end
        
        function v = get.fillIntermediateZ(obj)
            v = obj.fillIntermediateZ;
            if isempty(v)
                v = obj.hEditorGui.contextImageFillIntermediateZ;
            end
        end
    end
    
    methods (Sealed)
        function tf = eq(varargin)
            tf = eq@handle(varargin{:});
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
