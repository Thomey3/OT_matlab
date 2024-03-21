classdef Singleton < handle
    % Class that implements Singleton behavior
    % inherit from Singleton and call Singleton constructor
    properties (SetAccess=private, Hidden)
        singletonTrash = false;
        hClearAllDetector;
    end
    
    methods (Access = protected)
        function obj = Singleton()
            oldObj = obj;
            obj = singleton(obj,'create',class(obj));
            
            newInstance = isequal(oldObj,obj);
            if newInstance
                obj.hClearAllDetector = most.util.clearAllDetector(@(varargin)most.idioms.safeDeleteObj(obj));
            end
        end
    end
    
    methods        
        function delete(obj)
            if ~obj.singletonTrash
                singleton(obj,'delete',class(obj));
                most.idioms.safeDeleteObj(obj.hClearAllDetector);
            end
        end
    end
    
    methods (Static)
        function tf = isInstantiated(className)
            obj = singleton([],'fetch',className);
            tf = ~isempty(obj);
        end
    end
end

%%% local function
function obj = singleton(obj,action,className)
    % Notes: isvalid is a slow function. instead of checking if object is
    % valid we explicitly remove the object from the storage
    
    persistent classStorage
    persistent objectStorage

    mask = strcmp(className,classStorage);
    stored = any(mask);

    switch action
        case 'create'
            if stored
                % don't need to explicitly delete new object,
                % Matlab garbage collector will take care of that
                obj.singletonTrash = true;
                obj = objectStorage{mask};
            else
                classStorage{end+1} = className;
                objectStorage{end+1} = obj;
            end
        case 'delete'
            if stored
                classStorage(mask) = [];
                objectStorage(mask) = [];
            end
        case 'fetch'
            if stored
                obj = objectStorage{mask};
            else
                obj = [];
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
