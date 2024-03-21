classdef CSZAffineLut < scanimage.mroi.coordinates.CoordinateSystem
    properties
        toParentLutEntries   = scanimage.mroi.coordinates.cszaffinelut.LUTEntry.empty();
        fromParentLutEntries = scanimage.mroi.coordinates.cszaffinelut.LUTEntry.empty();
    end
    
    properties (SetAccess = protected)
        forwardable = true;
        reversible  = true;
    end
    
    methods
        function obj = CSZAffineLut(name,dimensions,hParent)
            if nargin < 3 || isempty(hParent)
                hParent = [];
            end
            assert(dimensions==3,'CSZAffineLUT only works with 3 dimensions');
            obj = obj@scanimage.mroi.coordinates.CoordinateSystem(name,dimensions,hParent);
        end
    end
    
    methods (Access = protected)
        function pts = applyTransforms(obj,reverse,pts)
            for idx = 1:numel(obj)
                hCS = obj(idx);
                if reverse(idx)
                    if ~isempty(hCS.toParentLutEntries)
                        pts = hCS.toParentLutEntries.interpolateReverse(pts);
                    elseif ~isempty(hCS.fromParentLutEntries)
                        pts = hCS.fromParentLutEntries.interpolate(pts);
                    end
                else
                    if ~isempty(hCS.toParentLutEntries)
                        pts = hCS.toParentLutEntries.interpolate(pts);
                    elseif ~isempty(hCS.fromParentLutEntries)
                        pts = hCS.fromParentLutEntries.interpolateReverse(pts);
                    end
                end
            end
        end
        
        function s = toStructInternal(obj)
            s = struct();
            s.toParentLutEntries   = obj.toParentLutEntries.toStruct();
            s.fromParentLutEntries = obj.fromParentLutEntries.toStruct();
        end
        
        function fromStructInternal(obj,s)
            obj.toParentLutEntries   = scanimage.mroi.coordinates.cszaffinelut.LUTEntry.fromStruct(s.toParentLutEntries);
            obj.fromParentLutEntries = scanimage.mroi.coordinates.cszaffinelut.LUTEntry.fromStruct(s.fromParentLutEntries);
        end
        
        function resetInternal(obj)
            obj.toParentLutEntries   = [];
            obj.fromParentLutEntries = [];
        end
    end
    
    methods
        function set.toParentLutEntries(obj,val)
            if isempty(val)
                val = scanimage.mroi.coordinates.cszaffinelut.LUTEntry.empty();
            else
                validateattributes(val,{'scanimage.mroi.coordinates.cszaffinelut.LUTEntry'},{'vector'});
                val = val.validate();
            end
            
            if ~isequal(val,obj.toParentLutEntries)
                obj.toParentLutEntries = val;
                
                if ~isempty(val)
                    obj.fromParentLutEntries = [];
                end
                
                notify(obj,'changed');
            end
        end
        
        function set.fromParentLutEntries(obj,val)
            if isempty(val)
                val = scanimage.mroi.coordinates.cszaffinelut.LUTEntry.empty();
            else
                validateattributes(val,{'scanimage.mroi.coordinates.cszaffinelut.LUTEntry'},{'vector'});
                val = val.validate();
            end
            
            if ~isequal(val,obj.fromParentLutEntries)
                obj.fromParentLutEntries = val;
                
                if ~isempty(val)
                    obj.toParentLutEntries = [];
                end
                
                notify(obj,'changed');
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
