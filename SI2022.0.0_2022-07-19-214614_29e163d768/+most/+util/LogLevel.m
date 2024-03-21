classdef (Sealed = true) LogLevel < double
    %LogLevel Enumeration of command line and log file verbosity levels.
    %
    %   Log levels are fairly self explanatory.  Although MATLAB supports builtin
    %   warning and error functionality, log levels of Warn and Error allow logging
    %   or output classes to send warning or error information to log files or other
    %   destinations other than the command line.
    %
    %   The enumeration is ordered with the assumption that typically functionality
    %   using this enumeration would output the information at its log level and
    %   any level below it (i.e., in order of increasing detail/diagnostic value).
    %
    %   See also most.Diagnostics.
    
    enumeration
        Silent(0); %Do not generate any output.
        Info(1);   %Output general diagnostic information.
        Warn(2);   %Output warnings.  Could be used to suppress all most or most-derived app warnings rather than having to tweak several individual warning identifiers.
        Error(3);  %Output errors.
        Debug(4);  %Output debugging-specific information.
        Trace(5);  %Output information sufficient for detailed function and behavior tracing.
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
