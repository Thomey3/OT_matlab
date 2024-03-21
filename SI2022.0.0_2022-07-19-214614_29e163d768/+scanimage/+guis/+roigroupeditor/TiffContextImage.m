classdef TiffContextImage < scanimage.guis.roigroupeditor.ContextImageProvider
    
    %% Lifecycle
    methods
        function obj = TiffContextImage(hEditorGui,fn)
            obj = obj@scanimage.guis.roigroupeditor.ContextImageProvider(hEditorGui);
            
            if nargin < 2
                [filename,pathname] = uigetfile('.tif','Choose file to load image from');
                if filename==0;return;end
                fn = fullfile(pathname,filename);
            else
                assert(exist(fn,'file')>0,'Could not find specified file.');
                [~, filename , ext] = fileparts('J:\Vidrio\repo\mymatlab\ex\file_00002.tif');
                filename = [filename ext];
            end
            
            try
                obj.hEditorGui.hFig.Pointer = 'watch';
                drawnow();
                [roiData, ~, header] = scanimage.util.getMroiDataFromTiff(fn);
                
                zs = header.SI.hStackManager.zs;
                chans = roiData{1}.channels;
                chansMrgs = header.SI.hChannels.channelMergeColor(chans);
                rois = {};
                affs = {};
                imgs = {};
                
                % determine where all the image surfs need to be
                for slcIdx = 1:numel(zs)
                    z = zs(slcIdx);
                    zRois = {};
                    zAffs = {};
                    zImgs = {};
                    
                    for roiIdx = 1:numel(roiData)
                        [tf,roiZIdx] = ismember(z, roiData{roiIdx}.zs);
                        if tf
                            sf = roiData{roiIdx}.hRoi.get(z);
                            zRois{end+1} = sf.cornerpoints();
                            zAffs{end+1} = sf.affine;
                            
                            roiImgs = {};
                            %get the images
                            for chIdx = 1:numel(chans)
                                img = roiData{roiIdx}.imageData{chIdx}{end}{roiZIdx}';
                                if iscell(img)
                                    roiImgs{end+1} = img{end}';
                                else
                                    roiImgs{end+1} = img;
                                end
                                 
                            end
                            
                            zImgs{end+1} = roiImgs;
                        end
                    end
                    
                    rois{end+1} = zRois;
                    affs{end+1} = zAffs;
                    imgs{end+1} = zImgs;
                end
                
                luts = header.SI.hChannels.channelLUT(chans);
                
                newColorIdx = obj.hEditorGui.pickMostUniqueCtxImColor();
                newColor = obj.hEditorGui.contextImageEdgeColorList{newColorIdx};
                
                obj.name = filename;
                obj.source = fn;
                obj.colorIdx = newColorIdx;
                obj.color = newColor;
                obj.channels = arrayfun(@(ch){sprintf('CH%d',ch)},chans);
                obj.channelSelIdx = 1;
                obj.luts = luts;
                obj.roiCPs = rois;
                obj.roiAffines = affs;
                obj.zs = zs;
                obj.imgs = imgs;
                obj.channelMergeColors = chansMrgs;
                
                if (numel(obj.channels) > 1) && any(~strcmp(chansMrgs,'None'))
                    obj.channels{end+1} = 'Merge';
                end
                
                obj.hEditorGui.hContextImages(end+1) = obj;
                obj.hEditorGui.updateMaxViewFov();
                obj.hEditorGui.rebuildLegend();
                obj.hEditorGui.setZProjectionLimits();
                obj.hEditorGui.scrollLegendToBottom();
                
                obj.visible = true;
                
                obj.hEditorGui.hFig.Pointer = 'arrow';
            catch ME
                obj.hEditorGui.hFig.Pointer = 'arrow';
                delete(obj);
                warndlg(sprintf('Failed to load file. %s',ME.message),'Import Context Image');
                ME.rethrow;
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
