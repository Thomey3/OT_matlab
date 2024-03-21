classdef SyncedScanner < dabs.resources.Device
    %SYNCEDSCANNER Scanner whose line rate "drives" acquisition.
    %   Historically named resonant scanning Scan2D objects such as 
    %   RggScan and ResScan utilize a 
    %   scanner whose sync signal is the master clock for which all
    %   other tasks timing must abide by. Other types of scanners (e.g.
    %   polygonal scanner) also have a synchronization signal. This class
    %   is a base class for such devices
    
    properties (Abstract,SetObservable)
        hDISync;
        
        settleTime_s;
        nominalFrequency_Hz;
        currentFrequency_Hz;
        angularRange_deg;
    end
    
    methods
        function obj = SyncedScanner(name)
            %SYNCEDSCANNER Construct an instance of this class
            %   Detailed explanation goes here
            obj@dabs.resources.Device(name);
        end
    end
    
    methods(Abstract)
        %waitSettlingTime Pause for transient start up of scanner.
        %   Pauses execution of Matlab thread while scanner achieves
        %   steady state.
        waitSettlingTime(obj)
        park(obj)
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