classdef ImagePyramid < most.util.Uuid
    properties (Constant)
        path = fullfile(tempdir(),'ScanImage_ImagePyramid');
    end
    
    properties (SetAccess = private)
        imageSize
        imageClass
        bytesPerPixel
        imageInfo
        filePath
        
        fid = -1;
        lods = zeros(0,2);
        lodFileOffsets = [];
        lodFileBytes = [];
    end
    
    methods
        function obj = ImagePyramid(image)
            if ~exist(obj.path,'dir')
                mkdir(obj.path);
            end
            
            if nargin < 1 || isempty(image)
               image = []; 
            end
            
            obj.filePath = fullfile(obj.path,[obj.uuid '.bin']);
            
            obj.createPyramid(image);
        end
        
        function delete(obj)
            if obj.fid > -1
                fclose(obj.fid);
            end
            
            if exist(obj.filePath,'file')
                delete(obj.filePath);
            end
        end
    end
    
    methods (Static)
        function cleanup()
            files = dir(ImagePyramid.path);
            for idx = 1:numel(files)
                file = fullfile(files(idx).folder,files(idx).name);
                try
                    delete(file);
                catch ME
                end
            end
        end
    end
    
    methods
        function data = getImage(obj,pixelSzXY) 
            level = obj.determineLOD(pixelSzXY);
            data = obj.getLod(level);
        end
        
        function level = determineLOD(obj,pixelSzXY)
            if isempty(obj.lods)
                level = 1;
                return;
            end
            
            mask = obj.lods(:,1)>=pixelSzXY(1) & obj.lods(:,2)>=pixelSzXY(2);
            level = find(mask,1,'last');
            
            if isempty(level)
                level = 1;
            end
        end
        
        function data = getLod(obj,level)
            if isempty(obj.lods)
                data = [];
            else
                level = min(level,numel(obj.lods));
                sz = obj.lods(level,:);
                offset = obj.lodFileOffsets(level);

                if obj.fid<0
                    obj.fid = fopen(obj.filePath,'r');
                end

                fseek(obj.fid,offset,'bof');
                data = fread(obj.fid,sz,['*' obj.imageClass]);
            end
        end

        function createPyramid(obj,image)
            obj.imageSize = size(image);
            obj.imageClass = class(image);
            obj.imageInfo = whos('image');
            obj.bytesPerPixel = obj.imageInfo.bytes / numel(image);
            obj.lodFileOffsets = 0;
            obj.lodFileBytes = [];
            
            obj.fid = fopen(obj.filePath,'W');
            assert(obj.fid>-1,'Could not open file %s',obj.filePath);
            
            obj.lods = zeros(0,2);
            
            try                
                while all(size(image)>0)
                    obj.lods(end+1,:) = size(image);
                    obj.lodFileBytes(end+1) = obj.bytesPerPixel * numel(image);
                    obj.lodFileOffsets(end+1) = obj.lodFileOffsets(end) + obj.lodFileBytes(end);
                    
                    fwrite(obj.fid,image,obj.imageClass);
                    
                    image = image(2:2:end,2:2:end);
                end
            catch ME
                ME.rethrow();
            end
            
            fclose(obj.fid); % flush data to disk
            obj.fid = -1;
        end
        
        function hImagePyramid = copy(obj)
            if isempty(obj.lods)
                hImagePyramid = scanimage.util.ImagePyramid([]);
            else
                hImagePyramid = scanimage.util.ImagePyramid(obj.getLod(1));
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
