classdef CSLut < scanimage.mroi.coordinates.CoordinateSystem
    properties
        toParentInterpolant = {};
        fromParentInterpolant = {};
    end
    
    properties (SetAccess = protected)
        forwardable = true;
        reversible  = true;
    end
    
    methods
        function obj = CSLut(name,dimensions,hParent)
            if nargin < 3 || isempty(hParent)
                hParent = [];
            end
            obj = obj@scanimage.mroi.coordinates.CoordinateSystem(name,dimensions,hParent);
            
            obj.toParentInterpolant   = cell(1,obj.dimensions);
            obj.fromParentInterpolant = cell(1,obj.dimensions);
        end
    end
    
    methods (Access = protected)
        function pts = applyTransforms(obj,reverse,pts)            
            for idx = 1:numel(obj)
                if reverse(idx)
                    interpolant = obj(idx).fromParentInterpolant;
                else
                    interpolant = obj(idx).toParentInterpolant;
                end
                
                if ~isempty(interpolant)
                    pts_temp = pts;
                    for dim_idx = 1:numel(interpolant)
                        dimInterpolant = interpolant{dim_idx};
                        if ~isempty(dimInterpolant)
                            singularDimension = ( isa(dimInterpolant,'griddedInterpolant') && numel(dimInterpolant.GridVectors) == 1 ) || ...
                                                 ~isa(dimInterpolant,'griddedInterpolant') && size(dimInterpolant.Points,2) == 1;
                            
                            if singularDimension
                                pts(:,dim_idx) = dimInterpolant(pts_temp(:,dim_idx));
                            else
                                pts(:,dim_idx) = dimInterpolant(pts_temp);
                            end
                        end
                    end
                end
            end
        end
        
        function s = toStructInternal(obj)
            s = struct();
            s.toParentInterpolant = cellfun(@(hInterpolant)interpolantToStruct(hInterpolant),obj.toParentInterpolant,'UniformOutput',false);
            s.fromParentInterpolant = cellfun(@(hInterpolant)interpolantToStruct(hInterpolant),obj.fromParentInterpolant,'UniformOutput',false);
            
            function s = interpolantToStruct(hInterpolant)
                if isempty(hInterpolant)
                    s = struct.empty(1,0);
                else
                    s = struct();
                    switch class(hInterpolant)
                        case 'griddedInterpolant'
                            s.GridVectors = hInterpolant.GridVectors();
                            s.Values = hInterpolant.Values;
                            s.Method = hInterpolant.Method;
                            s.ExtrapolationMethod = hInterpolant.ExtrapolationMethod;
                        case 'most.math.polynomialInterpolant'
                            s = hInterpolant.toStruct();
                        case 'scatteredInterpolant'
                            s.Points = hInterpolant.Points;
                            s.Values = hInterpolant.Values;
                            s.Method = hInterpolant.Method;
                            s.ExtrapolationMethod = hInterpolant.ExtrapolationMethod;
                        otherwise
                            error('Converting %s to struct not implemented',class(hInterpolant));
                    end
                    s.class = class(hInterpolant);
                end
            end
        end
        
        function fromStructInternal(obj,s)
            obj.toParentInterpolant = cellfun(@(s)structToInterpolant(s),s.toParentInterpolant,'UniformOutput',false);
            obj.fromParentInterpolant = cellfun(@(s)structToInterpolant(s),s.fromParentInterpolant,'UniformOutput',false);
            
            function hInterpolant = structToInterpolant(s)
                if isempty(s)
                    hInterpolant = [];
                else
                    constructorFcnhdl = str2func(s.class);
                    hInterpolant = constructorFcnhdl();
                    s = rmfield(s,'class');
                    fields = fieldnames(s);
                    
                    for idx = 1:numel(fields)
                        field = fields{idx};
                        hInterpolant.(field) = s.(field);
                    end
                end
            end
        end
        
        function resetInternal(obj)
            obj.toParentInterpolant = {};
            obj.fromParentInterpolant = {};
        end
    end
    
    methods        
        function set.toParentInterpolant(obj,val)
            oldVal = obj.toParentInterpolant;
            
            val = obj.validateInterpolant(val);
            obj.toParentInterpolant = val;
            
            obj.updateDirections();
            
            if ~isequal(oldVal,obj.toParentInterpolant)
                notify(obj,'changed');
            end
        end
        
        function set.fromParentInterpolant(obj,val)
            oldVal = obj.fromParentInterpolant;
            
            val = obj.validateInterpolant(val);
            obj.fromParentInterpolant = val;
            
            obj.updateDirections();
            
            if ~isequal(oldVal,obj.fromParentInterpolant)
                notify(obj,'changed');
            end
        end
    end
    
    methods (Access = private)
        function val = validateInterpolant(obj,val)
            if isempty(val)
                val = cell(1,obj.dimensions);
            else
                validateattributes(val,{'cell'},{'vector','size',[1,obj.dimensions]});
                
                for idx = 1:numel(val)
                    v = val{idx};
                    if ~isempty(v)
                        assert(isscalar(v));
                        
                        switch class(v)
                            case 'griddedInterpolant'
                                gridDimensions = numel(v.GridVectors);
                                assert(gridDimensions==1 || gridDimensions==obj.dimensions,...
                                    'Gridded Interpolant has incorrect number of dimensions. Expected: 1 OR %d; Actual: %d',...
                                    obj.dimensions,gridDimensions);
                                
                            case {'scatteredInterpolant', 'most.math.polynomialInterpolant'}
                                pointDimensions = size(v.Points,2);
                                assert(pointDimensions==obj.dimensions,...
                                    'Interpolant has incorrect number of dimensions. Expected: %d; Actual: %d',...
                                    obj.dimensions,pointDimensions);                                
                                
                            otherwise
                                error('Interpolant must be of type {''griddedInterpolant'' ''scatteredInterpolant'' ''most.math.polynomialInterpolant'' }');
                        end                        
                    end                    
                end
            end 
        end
        
        function updateDirections(obj)
            obj.forwardable = ~isempty(obj.toParentInterpolant) || ...
                              (isempty(obj.toParentInterpolant) && isempty(obj.fromParentInterpolant));
                          
            obj.reversible = ~isempty(obj.fromParentInterpolant) || ...
                              (isempty(obj.toParentInterpolant) && isempty(obj.fromParentInterpolant));
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
