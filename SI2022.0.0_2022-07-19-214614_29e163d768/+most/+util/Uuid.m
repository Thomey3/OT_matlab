classdef Uuid < handle
    % simple class that defines a uuid
    % inherit from this class to uniquley identify objects without relying
    % on equality of handlesw
    
    properties (SetAccess = immutable, Hidden)
        uuiduint64 % uint64: represents the first 8 bytes from the uuid. should still be unique for all practical purposes
        uuid       % string: human readable uuid
    end
    
    methods
        function obj = Uuid()
            [obj.uuiduint64,obj.uuid] = most.util.generateUUIDuint64();
        end
    end
    
    methods (Hidden)
        function tf = isequal(obj,other)
            tf = isa(other,class(obj));
            tf = tf && isequal(size(obj),size(other));
            tf = tf && all(isequal([obj(:).uuiduint64],[other(:).uuiduint64]));
        end
        
        function tf = eq(obj,other)             
            if isa(other,class(obj))
                obj   = reshape([  obj(:).uuiduint64],size(obj));
                other = reshape([other(:).uuiduint64],size(other));
            else
                % making obj true and other false will make the following
                % equal check return false
                obj   = true(size(obj));
                other = false(size(other));
            end
            
            tf = obj==other;
        end
        
        function tf = neq(obj,other)
            tf = ~obj.eq(other);
        end
        
        function tf = uuidcmp(obj,other)
            thisclassname = mfilename('class');
            
            if numel(obj)==0 || numel(other)==0
                tf = [];
            elseif isscalar(obj) && iscell(other)
                validationFcn = @(o)isa(o,thisclassname) && isscalar(o) && obj.uuidcmp(o); % don't check for validity here (checked in getUuid below)
                tf = cellfun(validationFcn,other);
            else
                assert(isa(other,thisclassname),'Expected input to be a ''%s''',thisclassname);
                assert(numel(obj)==1 || numel(other)==1,'Expected one input to be scalar');
                tf = arrayfun(@getUuid,obj) == arrayfun(@getUuid,other);
            end
            
            function uuid = getUuid(obj)
                % workaround for isvalid function behavior:
                % isvalid returns false if called within an object's delete
                % function. There is no good way to check if an object is
                % actually invalid or if we are still inside the delete
                % function. All we can do is to query a property and see if it
                % errors
                try
                    uuid = obj.uuiduint64;
                catch
                    uuid = NaN; % the object is not valid anymore
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
