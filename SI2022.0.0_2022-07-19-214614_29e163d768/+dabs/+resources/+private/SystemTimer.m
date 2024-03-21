classdef SystemTimer < handle
    events
        beacon_QueryIO
        beacon_1Hz
        beacon_15Hz
        beacon_30Hz
        beacon_0_2Hz
    end
    
    properties (SetAccess=private)
        started = false;
    end
    
    properties (SetAccess=private,GetAccess=private)
        hTimers = timer.empty();
    end
    
    methods
        function obj = SystemTimer()
            obj.hTimers(end+1) = timer('ExecutionMode','fixedSpacing','Period',    1,'Name','System Timer 1Hz' , 'TimerFcn',@(varargin)obj.notify('beacon_1Hz'));
            obj.hTimers(end+1) = timer('ExecutionMode','fixedSpacing','Period',0.066,'Name','System Timer 15Hz', 'TimerFcn',@(varargin)obj.notify('beacon_15Hz'));
            obj.hTimers(end+1) = timer('ExecutionMode','fixedSpacing','Period',0.033,'Name','System Timer 30Hz', 'TimerFcn',@(varargin)obj.notify('beacon_30Hz'));
            obj.hTimers(end+1) = timer('ExecutionMode','fixedSpacing','Period',    5,'Name','System Timer 0.2Hz','TimerFcn',@(varargin)obj.notify('beacon_0_2Hz'));
            obj.hTimers(end+1) = timer('ExecutionMode','fixedSpacing','Period',    1,'Name','System Timer Query IO','TimerFcn',@(varargin)obj.notify('beacon_QueryIO'));
        end
        
        function start(obj)
            if obj.started
                return
            end
            start(obj.hTimers);
            obj.started = true;
        end
        
        function stop(obj)
            stop(obj.hTimers);
            obj.started = false;
        end
        
        function delete(obj)
            try
                obj.stop();
                delete(obj.hTimers);
            catch ME
                most.ErrorHandler.logAndReportError(ME);
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
