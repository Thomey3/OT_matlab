classdef CoordinateSystem < scanimage.mroi.util.TreeNode
    properties (SetAccess = private)
        dimensions;
    end
    
    properties (Abstract, SetAccess = protected)
        forwardable;
        reversible;
    end
    
    properties (SetAccess = immutable)
        name = '';
    end
    
    properties (SetAccess = immutable, Hidden)
        csClassName = mfilename('class');
    end
    
    properties
        % when lock == true, loading and resetting coordinate system are
        % disabled. changing coordinate system properties is still possible
        lock = false;
        resetFcnHdl = []; % allows to override reset function with custom function handle
    end
    
    events
        % fires when the definition of the coordinate system changed
        changed
    end
    
    methods
        function obj = CoordinateSystem(name,dimensions,hParent)
            if nargin < 3 || isempty(hParent)
                hParent = [];
            end
            
            validateattributes(name,{'char'},{'row'});
            validateattributes(dimensions,{'numeric'},{'scalar','integer','positive'});

            obj.dimensions = dimensions;
            obj.name = name;
            obj.hParent = hParent;
        end
        
        function delete(obj)
            % No-op
        end
    end
    
    methods (Abstract, Access = protected)
        pts = applyTransforms(obj,reverse,pts);
        
        s = toStructInternal(obj);
        fromStructInternal(obj);
        resetInternal(obj);
    end
    
    methods (Sealed)
        function s = toStruct(obj)
            s = obj.toStructInternal();
            
            s.class__ = class(obj);
            s.dimensions__ = obj.dimensions;
            s.name__ = obj.name;
            if ~isempty(obj.hParent)
                s.parentName__ = obj.hParent.name;
            end
        end
        
        function fromStruct(obj,s)
            if obj.lock
                return
            end
            
            assert(isstruct(s),'Not a valid struct: %s',class(s));
            assert(isfield(s,'class__'),'Not a valid struct for loading');
            assert(strcmp(s.class__,class(obj)),'Invalid struct given for loading. Expected struct for class %s. Instead struct was for class %s.',class(obj),s.class__);
            assert(s.dimensions__ == obj.dimensions);
            
            if ~strcmp(s.name__,obj.name)
                warning('Loading data for coordinate system %s from a struct for coordinate system %s.',obj.name,s.name__);
            end
            
            if ~isempty(obj.hParent) && isfield(s,'parentName__') && ~strcmp(obj.hParent.name,s.parentName__)
                warning('Coordinate system %s has parent %s, but loaded struct specifies parent %s',obj.name,obj.hParent.name,s.parentName__);
            end
            
            s = rmfield(s,'class__');
            s = rmfield(s,'dimensions__');
            s = rmfield(s,'name__');
            
            if isfield(s,'parentName__')
                s = rmfield(s,'parentName__');
            end
            
            obj.fromStructInternal(s);
        end
        
        function reset(obj)
            if ~obj.lock
                if isempty(obj.resetFcnHdl)
                    obj.resetInternal();
                else
                    obj.resetFcnHdl(obj);
                end
            end
        end
    end
    
    methods (Hidden)
        function str = getDisplayInfo(obj)
            %overload method in scanimage.mroi.coordinates.TreeNode
            classname = class(obj);
            classname = regexpi(classname,'[^\.]*$','match','once');
            
            str = sprintf('%s\n%s',obj.name,classname);
        end
    end
    
    methods        
        function hPoints = transform(obj,hPoints)
            hPointsCS = hPoints.hCoordinateSystem;
            [path,toParent,commonAncestorIdx] = hPointsCS.getRelationship(obj);
            
            transforms_reverse = ~toParent;
            
            % handle special cases
            assert(~isempty(path),'No relationship found between coordinate systems %s and %s',hPointsCS.name,obj.name);
            
            if isempty(transforms_reverse)
                return % same coordinate system, no transform required
            end
            
            % extract transforms from path
            transforms = path;
            transforms(commonAncestorIdx) = [];
            
            validateTransforms(transforms,transforms_reverse);
            [transforms_groups,transforms_reverse_groups] = groupTransformsByClasses(transforms,transforms_reverse);
            pts = applyTransformGroups(transforms_groups,transforms_reverse_groups,hPoints.points);
            
            hPoints = scanimage.mroi.coordinates.Points(path{end},pts,hPoints.UserData);
            
            
            %%%%%%%%% Local functions %%%%%%%%%
            function validateTransforms(transforms,transforms_reverse)
                [transforms_forwardable,transforms_reversible] = cellfun(@(n)deal(n.forwardable,n.reversible),transforms);
                
                forward_violation = ~transforms_reverse & ~transforms_forwardable;
                reverse_violation =  transforms_reverse & ~transforms_reversible;
                
                if any(forward_violation) || any(reverse_violation)
                    forward_violation_names = strjoin(cellfun(@(t)t.name,transforms(forward_violation),'UniformOutput',false), ',');
                    reverse_violation_names = strjoin(cellfun(@(t)t.name,transforms(reverse_violation),'UniformOutput',false), ',');
                    error('Coordinate Systems ''%s'' are not forwardable. Coordinate Systems ''%s'' are not reversible.',forward_violation_names,reverse_violation_names);
                end
            end
            
            function [transforms_groups,transforms_reverse_groups] = groupTransformsByClasses(transforms,transforms_reverse)
                % find class breaks
                transforms_class = cellfun(@(t)class(t),transforms,'UniformOutput',false);
                if numel(transforms_class) == 1
                    classBreaks = false;
                else
                    classBreaks = ~strcmp(transforms_class(1:end-1),transforms_class(2:end));
                end
                
                classBreakIdxs = find(classBreaks);
                
                % split transforms along class breaks
                ranges_start  = [1 classBreakIdxs+1];
                ranges_end    = [classBreakIdxs, numel(transforms)];
                ranges_length = ranges_end - ranges_start + 1;
                
                transforms_groups = mat2cell(transforms,1,ranges_length);
                transforms_reverse_groups = mat2cell(transforms_reverse,1,ranges_length);
            end
            
            function pts = applyTransformGroups(transforms_groups,transforms_reverse_groups,pts)
                for idx = 1:numel(transforms_groups)
                    transforms_ = transforms_groups{idx};
                    transforms_ = [transforms_{:}]; % at this point all of the transforms are of the same class, so we can concatenate them
                    transforms_reverse_ = transforms_reverse_groups{idx};
                    
                    pts = transforms_.applyTransforms(transforms_reverse_,pts);
                end
            end
        end
    end
    
    methods (Access = protected, Sealed)
        function validateParent(obj,hNewParent)            
            assert(isa(hNewParent,obj.csClassName),'%s is not a valid coordinate system',class(hNewParent));
            ensureCoordinateSystemNamesAreUniqueInTree();
            obj.validateParentCS(hNewParent);
            
            function ensureCoordinateSystemNamesAreUniqueInTree()
                [~,parentTreeNodes] = hNewParent.getTree();
                [~,objTreeNodes] = obj.getTree();
                
                parentNodeNames = cellfun(@(n)n.name,parentTreeNodes,'UniformOutput',false);
                objNodeNames = cellfun(@(n)n.name,objTreeNodes,'UniformOutput',false);
                
                commonNames = intersect(parentNodeNames,objNodeNames);
                assert(isempty(commonNames),'The coordinate system names {%s} are not unique.',strjoin(commonNames,', '));
            end
        end
    end
    
    methods (Access = protected)
        function validateParentCS(obj,hNewParent)
            % Overload this method if coordinate system needs to translate number of dimensions
            
            assert(obj.dimensions == hNewParent.dimensions, ...
                'Dimensions mismatch between coordinatesystems %s (%d) and %s (%d)', ...
                obj.name, obj.dimensions, hNewParent.name, hNewParent.dimensions);
        end
    end
    
    methods
        function set.lock(obj,val)
            validateattributes(val,{'numeric','logical'},{'binary','scalar'});
            obj.lock = val;
        end
        
        function set.resetFcnHdl(obj,val)
            if isempty(val)
                val = [];
            else
                validateattributes(val,{'function_handle'},{'scalar'});
            end
            
            obj.resetFcnHdl = val;
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
