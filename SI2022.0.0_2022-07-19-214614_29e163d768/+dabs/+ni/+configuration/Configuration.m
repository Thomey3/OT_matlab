classdef Configuration < most.util.Singleton
    properties
        experthandle = [];
        sessionhandle = [];
    end
    
    methods
        function obj = Configuration()
            try
                if ~obj.singletonTrash && (isempty(obj.experthandle) || isempty(obj.sessionhandle))
                    % NISysCfgInitializeSession takes about ~150ms. this is
                    % wrapped into a Singleton to cache the experthandle
                    % and session handle this improves the performance of
                    % the function findFlexRios
                    %
                    % initialize NI system configuration session
                    [~,~,~,experthandle_,sessionhandle_] = dabs.ni.configuration.private.nisyscfgCall('NISysCfgInitializeSession','localhost','','',1033,false,100,libpointer,libpointer);
                    obj.experthandle = experthandle_;
                    obj.sessionhandle = sessionhandle_;
                end
            catch
                obj.delete(); % RIO is not installed
            end
        end
        
        function delete(obj)
            if ~obj.singletonTrash
                try
                    if ~isempty(obj.sessionhandle)
                        dabs.ni.configuration.private.nisyscfgCall('NISysCfgCloseHandle',obj.sessionhandle);
                        obj.sessionhandle = [];
                    end
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
                
                try
                    if ~isempty(obj.experthandle)
                        dabs.ni.configuration.private.nisyscfgCall('NISysCfgCloseHandle',obj.experthandle);
                        obj.experthandle = [];
                    end
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
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
