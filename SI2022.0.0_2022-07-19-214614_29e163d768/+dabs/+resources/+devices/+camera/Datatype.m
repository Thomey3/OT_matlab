classdef Datatype
    %DATATYPE Available pixel types of camera
    
    enumeration
        U8;
        I8;
        U16;
        I16;
        Unknown;
    end
    
    methods
        function matType = toMatlabType(obj)
            import dabs.resources.devices.camera.Datatype;
            switch (obj)
                case Datatype.U8
                    matType = 'uint8';
                case Datatype.I8
                    matType = 'int8';
                case Datatype.U16
                    matType = 'uint16';
                case Datatype.I16
                    matType = 'int16';
                otherwise
                    matType = 'unknown';
            end
        end
        
        function max = getMaxValue(obj)
            max = double(intmax(obj.toMatlabType()));
        end
        
        function min = getMinValue(obj)
            min = double(intmin(obj.toMatlabType()));
        end
        
        function nb = getNumBits(obj)
            import dabs.resources.devices.camera.Datatype;
            switch (obj)
                case {Datatype.U8, Datatype.I8}
                    nb = 8;
                case {Datatype.U16, Datatype.I16}
                    nb = 16;
                otherwise
                    nb = NaN;
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
