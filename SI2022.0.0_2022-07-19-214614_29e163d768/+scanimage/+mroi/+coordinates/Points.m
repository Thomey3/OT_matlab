classdef Points
    properties (SetAccess = immutable)
        hCoordinateSystem
        points
        numPoints
        dimensions
        UserData
    end
    
    methods
        function obj = Points(hCoordinateSystem,points,UserData)
            if nargin < 3 || isempty(UserData)
                UserData = [];
            end
            
            assert(isa(hCoordinateSystem,'scanimage.mroi.coordinates.CoordinateSystem'),'Not a valid scanimage.mroi.coordinates.CoordinateSystem');
            assert(isscalar(hCoordinateSystem) && isvalid(hCoordinateSystem));
            
            assert(isnumeric(points) && size(points,2)==hCoordinateSystem.dimensions,'Points do not have same number of dimensions as coordinate system.');
            
            obj.hCoordinateSystem = hCoordinateSystem;
            obj.points = points;
            obj.numPoints = size(points,1);
            obj.dimensions = size(points,2);
            obj.UserData = UserData;
        end
        
        function objs = transform(objs,hCoordinateSystem)
            assert(isa(hCoordinateSystem,'scanimage.mroi.coordinates.CoordinateSystem'));
            assert(isscalar(hCoordinateSystem) && isvalid(hCoordinateSystem));
            
            for idx = 1:numel(objs)
                objs(idx) = hCoordinateSystem.transform(objs(idx));
            end
        end
        
        function objs = subset(objs,idxs)
            for idx = 1:numel(objs)
                obj = objs(idx);
                pts = obj.points(idxs,:);
                objs(idx) = scanimage.mroi.coordinates.Points(obj.hCoordinateSystem,pts,obj.UserData);
            end
        end
        
        function disp(objs)
            if isscalar(objs)
                fprintf('Coordinate System: %s (%s)\n',objs.hCoordinateSystem.name,class(objs.hCoordinateSystem));
                fprintf('\tNumber Of Points: %d\n\n',objs.numPoints);
                
                if objs.numPoints < 50
                    disp(objs.points);
                else
                    disp(objs.points(1:10,:));
                    fprintf('... [truncated %d points] ...\n\n',objs.numPoints-20);
                    disp(objs.points(end-9:end,:));
                end
            else
                c = class(objs);
                sizeStr = sprintf('%d×',size(objs));
                sizeStr(end) = []; % delete last ×
                fprintf('%s array of %s\n\n',sizeStr,c);
            end
        end
        
        function hPts = insert(obj,pts,idx)
            assert(isscalar(obj));
            
            if isa(pts,class(obj))
                pts = pts.transform(obj.hCoordinateSystem);
                pts = pts.points;
            end
            
            before = obj.points(1:idx-1,:);
            after  = obj.points(idx:end,:);
            
            pts = vertcat(before,pts,after);
            
            hPts = scanimage.mroi.coordinates.Points(obj.hCoordinateSystem,pts,obj.UserData);
        end
        
        function hPts = append(obj,pts)
            assert(isscalar(obj));
            
            if isa(pts,class(obj))
                pts = pts.transform(obj.hCoordinateSystem);
                pts = pts.points;
            end
            
            pts = vertcat(obj.points,pts);
            
            hPts = scanimage.mroi.coordinates.Points(obj.hCoordinateSystem,pts,obj.UserData);
        end
        
        function hPts = remove(obj,idxs)
            assert(isscalar(obj));
            
            pts = obj.points;
            pts(idxs,:) = [];
            
            hPts = scanimage.mroi.coordinates.Points(obj.hCoordinateSystem,pts,obj.UserData);
        end
        
        function hPts = filter(obj,idxs)
            assert(isscalar(obj));
            
            pts = obj.points;
            pts = pts(idxs,:);
            
            hPts = scanimage.mroi.coordinates.Points(obj.hCoordinateSystem,pts,obj.UserData);
        end
        
        function hPt = plus(hPt1,hPt2)
            hCS = hPt1.hCoordinateSystem;
            
            if isnumeric(hPt2)
                points2 = hPt2;
            else
                hPt2 = hPt2.transform(hCS);
                points2 = hPt2.points;
            end
            
            points_ = hPt1.points + points2;
            hPt = scanimage.mroi.coordinates.Points(hCS,points_);            
        end
        
        function hPt = minus(hPt1,hPt2)
            hCS = hPt1.hCoordinateSystem;
            
            if isnumeric(hPt2)
                points2 = hPt2;
            else
                hPt2 = hPt2.transform(hCS);
                points2 = hPt2.points;
            end
            
            points_ = hPt1.points - points2;
            hPt = scanimage.mroi.coordinates.Points(hCS,points_);
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
