classdef CSDimConversion < scanimage.mroi.coordinates.CoordinateSystem
    properties (SetAccess = private)
        parentDimensions;
    end
     
    properties (SetAccess = immutable)
        dimensionSelection;
    end
    
    properties (SetAccess = protected)
        forwardable = true;
        reversible = true;
    end
    
    methods
        function obj = CSDimConversion(name,dimensions,hParent,parentDimensions,dimensionSelection)
            obj = obj@scanimage.mroi.coordinates.CoordinateSystem(name,dimensions,[]);
            
            if nargin < 5 || isempty(dimensionSelection)
               dimensionSelection = 1:min(dimensions,parentDimensions);
            end
            
            validateattributes(dimensionSelection,{'numeric'},{'vector','integer','positive'});
            validateattributes(parentDimensions,  {'numeric'},{'scalar','integer','positive'});
            
            minDimNum = min(dimensions,parentDimensions);
            assert(numel(dimensionSelection) == minDimNum,'dimensionSelection must have %d number of elements.',minDimNum);
            assert(all(dimensionSelection <= minDimNum),'All elements of dimensionSelection need to be smaller or equal to %d.',minDimNum);
            
            obj.parentDimensions = parentDimensions;
            obj.dimensionSelection = dimensionSelection;
            
            obj.hParent = hParent;
        end
        
        function delete(obj)
        end
    end
    
    methods (Access = protected)
        function pts = applyTransforms(obj,reverse,pts)
            numPoints = size(pts,1);
            
            for idx = 1:numel(obj)
                if ~reverse(idx)
                    if obj(idx).dimensions >= obj(idx).parentDimensions
                        pts = pts(:,obj(idx).dimensionSelection);
                    else
                        pts_ = zeros(numPoints,obj(idx).parentDimensions,'like',pts);
                        pts_(:,obj(idx).dimensionSelection) = pts;
                        pts = pts_;
                    end
                else
                    if obj(idx).dimensions <= obj(idx).parentDimensions
                        pts = pts(:,obj(idx).dimensionSelection);
                    else
                        pts_ = zeros(numPoints,obj(idx).dimensions,'like',pts);
                        pts_(:,obj(idx).dimensionSelection) = pts;
                        pts = pts_;
                    end
                end
            end
        end
        
        function s = toStructInternal(obj)
            s = struct();
            s.parentDimensions   = obj.parentDimensions;
            s.dimensionSelection = obj.dimensionSelection;
        end
        
        function fromStructInternal(obj,s)
            % Cannot load properties, since they need are parameters of
            % constructor and are immutable. Just check and issue warning
            % if params do not match
            
            if ~isequal(s.parentDimensions,obj.parentDimensions)
                warning('Coordinate System %s');
            end
            
            if ~isequal(s.dimensionSelection,obj.dimensionSelection)
                
            end
        end
        
        function resetInternal(obj)
            % No-op
        end
    end
    
    methods (Access = protected)
        function validateParentCS(obj,hNewParent)            
            assert(hNewParent.dimensions == obj.parentDimensions, ...
                'Dimensions mismatch between coordinatesystems. Expected %s to have %d dimensions; instead it has %d dimensions', ...
                hNewParent.name, obj.parentDimensions, hNewParent.dimensions);
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
