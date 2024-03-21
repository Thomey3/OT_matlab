classdef (Abstract) ValueComparable < handle
    methods (Abstract=true)
        value=isequal(self,other)
            % Custom isequal.  This generally just calls the isequalHelper()
            % method, which needs to know the name of the class.  (Where
            % "the class" means the class of the classdef containing the
            % isequal() implementation.  It seems like there should be a
            % way to determine this automatically...
    end
    
    methods (Access=protected)        
        function value=isequalHelper(self,other,className)
            % Helper for custom isequal.  Doesn't work for 3D, 4D, etc arrays.
            % This should generally _not_ be overridden.
            if ~isa(other,className) ,
                value=false;
                return
            end
            dims=size(self);
            if any(dims~=size(other))
                value=false;
                return;
            end
            n=numel(self);
            for i=1:n ,
                if ~isequalElement(self(i),other(i)) ,
                    value=false;
                    return
                end
            end
            value=true;
        end  % function
    end  % protected methods block
    
    methods (Abstract=true, Access=protected)
        value=isequalElement(self,other)  % to be implemented by subclasses
    end
    
    methods (Access=protected)
       function value=isequalElementHelper(self,other,propertyNamesToCompare)
            % Helper to test for "value equality" of two scalars.
            % propertyNamesToCompare should be a row vector of property names to compare using isequal()
            % This should generally _not_ be overridden.
            nPropertyNamesToCompare=length(propertyNamesToCompare);
            for i=1:nPropertyNamesToCompare ,
                propertyName=propertyNamesToCompare{i};
                if ~isequal(self.(propertyName),other.(propertyName)) ,
                    %keyboard
                    value=false;
                    return
                end
            end
            value=true;
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
