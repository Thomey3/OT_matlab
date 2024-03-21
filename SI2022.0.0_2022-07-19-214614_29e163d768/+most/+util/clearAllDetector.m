classdef clearAllDetector < handle
    % this class periodically checks if the 'clear all' command was
    % executed. if it detects that clear all was executed, it destructs
    % iteself and calls 'callback'
    
    properties (SetAccess = immutable)
        callback = [];
        expectedValue;
    end
    
    properties (SetAccess = private, GetAccess = private)
        hTimer;
    end
    
    methods
        function obj = clearAllDetector(callback)
            validateattributes(callback,{'function_handle'},{'scalar'});
            obj.callback = callback;
            
            obj.expectedValue = checkStore();
            
            obj.hTimer = timer(...
                 'Name','clearAllDetector timer'...
                ,'Period',1 ...
                ,'TimerFcn',@(varargin)obj.performCheck ...
                ,'ExecutionMode','fixedSpacing' ...
                ,'ErrorFcn',@(varargin)false);
            
            start(obj.hTimer);
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hTimer);
        end
        
        function performCheck(obj)            
            clearDetected = obj.expectedValue ~= checkStore();
            
            if clearDetected
                callback_ = obj.callback;
                obj.delete();
                
                if ~isempty(callback_)
                    callback_();
                end
            end
        end
    end
end

function val = checkStore()
    persistent store
    
    if isempty(store)
        store = rand();
    end
        
    val = store;
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
