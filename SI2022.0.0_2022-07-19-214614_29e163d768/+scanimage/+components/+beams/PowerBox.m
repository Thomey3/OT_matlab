classdef PowerBox
    %POWERBOX class to wrap and validate attributes of power box properties
    %   Class to wrap and validate attributes of power box properties.
    %   Power boxes historically were structs, but since powerFractions
    %   were often given as percents (0-100) rather than decimals (0-1),
    %   properties must be checked.
    
    properties
        hBeams = scanimage.components.Beams.empty();
        
        rect = [0.25 0.25 0.5 0.5]; %normalized [x location, y location, width height]
        powers = NaN;
        name = '';
        oddLines = true;
        evenLines = true;
        mask = [];
        zs = [];
     end
    
    methods
        function obj = PowerBox(hBeams)
            obj.hBeams = hBeams;
        end
    end
    
    %% Conversion to struct
    
    methods
        function s = struct(obj) %to convert object to struct
            s = struct('rect', obj.rect,  ...
            'powers'    , obj.powers,     ...
            'name'      , obj.name,       ...
            'oddLines'  , obj.oddLines,   ...
            'evenLines' , obj.evenLines,  ...
            'mask'      , obj.mask,        ...
            'zs'        , obj.zs);
        end
    end
    
    %% PROP ACCESS
    methods
        function obj = set.rect(obj,val)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            validateattributes(val,{'numeric'},{'vector','real','ncols',4});
            val = most.idioms.ifthenelse(iscolumn(val), val', val);
            
            if any(val<0)
                val(find(val<0)) = 0;
            end
            
            % 0.05 is the min value for clear delineation and selection of
            % corner pts in GUI.
            if ~val(3)
                val(3) = 0.05;
            end
            
            if ~val(4)
                val(4) = 0.05;
            end
                        
            % coerce to fit in normalized scanfield
            r = min(1,max(0,[val([1 2]) val([3 4])+ val([1 2])]));
            val = [r([1 2]) r([3 4])-r([1 2])];
            
            obj.rect = val;
        end
        
        function obj = set.powers(obj, val)
            nanMask = isnan(val);
            validateattributes(val(~nanMask),{'numeric'},{'nonnegative','<=',1, 'real'});
            val = obj.hBeams.zprpBeamScalarExpandPropValue(val,'PowerBox.powers');
            obj.powers = val;
        end
        
        function obj = set.mask(obj, val)
            assert(isnumeric(val) && numel(size(val))<= 2 && all(val(:)>=0) && all(val(:)<= 1),'Powerbox mask must be numeric 2D array with all values >=0 and <=1');
            obj.mask = val;
        end
        
        function obj = set.name(obj, val)
            validateattributes(val,{'char'},{'row'});
            obj.name = val;
        end
        
        function obj = set.oddLines(obj, val)
            validateattributes(val,{'logical'},{'scalar'});
            obj.oddLines = val;
        end
        
        function obj = set.evenLines(obj, val)
            validateattributes(val,{'logical'},{'scalar'});
            obj.evenLines = val;
        end
        
        function obj = set.zs(obj, val)
            validateattributes(val,{'numeric'},{'vector', 'real'});
            obj.zs = val;
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
