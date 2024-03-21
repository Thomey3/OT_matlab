classdef LUTEntry
    properties
        zfrom
        zto
        affine2D
    end
    
    properties (Hidden, SetAccess = private)
        invAffine2D
    end
    
    properties (Hidden,Constant)
        interpolationMethod = 'linear';
        extrapolationMethod = 'linear';
    end
    
    methods
        function obj = LUTEntry(zfrom,zto,affine2D)
            assert(numel(zfrom)==numel(zto) && numel(zto)==size(affine2D,3));
            
            if numel(zfrom) > 1
                obj = scanimage.mroi.coordinates.cszaffinelut.LUTEntry.empty();
                for idx = 1:numel(zfrom)
                    obj(end+1) = scanimage.mroi.coordinates.cszaffinelut.LUTEntry(zfrom(idx),zto(idx),affine2D(:,:,idx));
                end
                
                obj = obj.sort();
            else
                obj.zfrom = zfrom;
                obj.zto = zto;
                obj.affine2D = affine2D;
            end
        end
    end
    
    methods
        function obj = set.zfrom(obj,val)
            validateattributes(val,{'numeric'},{'scalar','finite','nonnan','real'});
            obj.zfrom = val;
        end
        
        function obj = set.zto(obj,val)
            validateattributes(val,{'numeric'},{'scalar','finite','nonnan','real'});
            obj.zto = val;
        end
        
        function obj = set.affine2D(obj,val)
            validateattributes(val,{'numeric'},{'size',[3 3],'nonnan','real'});
            assert(isequal(val(end,:),[0 0 1]));
            assert(det(val)~=0);
            obj.affine2D = val;
            obj.invAffine2D = inv(val);
        end
    end
    
    methods        
        function tf = isequal(obj,other)
            if numel(obj)~=numel(other)
                tf = false;
                return
            end
            
            obj = obj.sort();
            other = other.sort();
            
            tf =       isequal([obj.zfrom],[other.zfrom]);
            tf = tf && isequal([obj.zto],  [other.zto]);
            tf = tf && isequal(cat(3,obj.affine2D), cat(3,other.affine2D));
        end
        
        function obj = validate(obj)
            obj = obj.sort();
            
            assert(all(diff([obj.zfrom])>0),'LUTEntry:zFromNotUnique','zfrom is not unique'); % check for strictly rising
            
            dzto = diff([obj.zto]);
            assert(all(dzto>0) || all(dzto<0),'LUTEntry:zToNotStrictlyMonotonic','zto is not strictly monotonic'); % check for strict monotonicity
        end
        
        function obj = sort(obj,reverse)
            if nargin<2 || isempty(reverse)
                reverse = false;
            end
                
            if reverse
                [~,idx] = sort([obj.zto]);
                obj = obj(idx);
            else
                [~,idx] = sort([obj.zfrom]);
                obj = obj(idx);
            end
        end
        
        function pts = interpolate(obj,pts)
            if isempty(obj) || isempty(pts)
                return
            end
            
            obj = obj.sort();
            xy = pts(:,1:2);
            z = pts(:,3);
            
            if numel(obj)==1
                dz = obj.zto-obj.zfrom;
                z = z + dz;
                xy = scanimage.mroi.util.xformPoints(xy,obj.affine2D);
                pts = [xy,z];
                return
            end
            
            uniqueZ = all(z==z(1)); % optimization
            if uniqueZ
                z = z(1);
            end
            
            T = obj.makeZAffines(z);
            
            hInt = griddedInterpolant([obj.zfrom],[obj.zto],obj(1).interpolationMethod,obj(1).extrapolationMethod);
            z = hInt(z);
            
            if uniqueZ
                pts = scanimage.mroi.util.xformPoints(xy,T);
                pts(:,3) = z;
            else
                xy = xy';
                xy(3,:) = 1;
                xy = reshape(xy,3,1,[]);
                xy = pagemtimes_(T,xy);
                xy(3,:,:) = z;
                pts = reshape(xy,3,[])';
            end
        end
        
        function pts = interpolateReverse(obj,pts)
            if isempty(obj) || isempty(pts)
                return
            end
            
            reverse = true;
            obj = obj.sort(reverse);
            xy = pts(:,1:2);
            z = pts(:,3);
            
            if numel(obj)==1
                dz = obj.zto-obj.zfrom;
                z = z - dz;
                reverse = true;
                xy = scanimage.mroi.util.xformPoints(xy,obj.affine2D,reverse);
                pts = [xy,z];
                return
            end
            
            uniqueZ = all(z==z(1)); % optimization
            if uniqueZ
                z = z(1);
            end
            
            hInt = griddedInterpolant([obj.zto],[obj.zfrom],obj(1).interpolationMethod,obj(1).extrapolationMethod);
            z = hInt(z);
            
            T = obj.makeZAffines(z,reverse);
            
            if uniqueZ
                pts = scanimage.mroi.util.xformPoints(xy,T);
                pts(:,3) = z;
            else
                xy = xy';
                xy(3,:) = 1;
                xy = reshape(xy,3,1,[]);
                xy = pagemtimes_(T,xy);
                xy(3,:,:) = z;
                pts = reshape(xy,3,[])';
            end
        end
    end
    
    methods
        function T = makeZAffines(obj,z,reverse)
            if nargin<3 || isempty(reverse)
                reverse = false;
            end
            
            obj = obj.sort();
            
            affines = {obj.affine2D};
            affines = cat(3,affines{:});
            
            if isempty(affines)
                T = eye(3);
                return
            elseif size(affines,3) == 1
                T = affines(:,:,1);
                return
            end
            
            hInt = griddedInterpolant({1:3,1:3,[obj.zfrom]},affines,obj(1).interpolationMethod,obj(1).extrapolationMethod);
            T = zeros(3,3,numel(z));
            
            ones_ = ones(size(z));
            T(1,1,:) = hInt(1*ones_,1*ones_,z);
            T(2,1,:) = hInt(2*ones_,1*ones_,z);
            T(3,1,:) = hInt(3*ones_,1*ones_,z);
            T(1,2,:) = hInt(1*ones_,2*ones_,z);
            T(2,2,:) = hInt(2*ones_,2*ones_,z);
            T(3,2,:) = hInt(3*ones_,2*ones_,z);
            T(1,3,:) = hInt(1*ones_,3*ones_,z);
            T(2,3,:) = hInt(2*ones_,3*ones_,z);
            T(3,3,:) = hInt(3*ones_,3*ones_,z);
            
            if reverse
                for idx = 1:size(T,3)
                    T(:,:,idx) = inv(T(:,:,idx));
                end
            end
        end
    end
    
    %% Loading/saving
    methods
        function structOut = toStruct(obj)
            structOut = struct('zfrom',{},'zto',{},'affine2D',{});
            
            for idx = 1:numel(obj)
                structOut(end+1) = struct('zfrom',obj(idx).zfrom,'zto',obj(idx).zto,'affine2D',obj(idx).affine2D);
            end
        end
    end
    
    methods (Static)
        function obj = fromStruct(structIn)
            obj = scanimage.mroi.coordinates.cszaffinelut.LUTEntry.empty();
            
            for idx = 1:numel(structIn)
                obj(end+1) = scanimage.mroi.coordinates.cszaffinelut.LUTEntry(structIn(idx).zfrom,structIn(idx).zto,structIn(idx).affine2D);
            end
        end
    end
end

function Z = pagemtimes_(X,Y)
    if verLessThan('matlab','9.9')
        assert(size(X,2)==size(Y,1),'Incorrect dimensions for matrix multiplication. Check that the number of columns in the first array matches the number of rows in the second array.');
        assert(size(X,3)==size(Y,3),'Arrays have incompatible sizes. For every dimension beyond the first two, the dimension sizes for both arrays must be the same');
        Z = zeros(size(X,1),size(Y,2),size(X,3),'like',X);
        
        for i = 1:size(X,3)
            Z(:,:,i) = X(:,:,i)*Y(:,:,i);
        end
    
    else
        % pagemtimes was introduced in Matlab2020b
        Z = pagemtimes(X,Y);
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
