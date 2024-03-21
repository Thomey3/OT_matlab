classdef FileSystemWatcher < handle
    properties (SetAccess=immutable)
        path
    end
    
    properties (SetAccess=private, GetAccess=private)
        hWatcher;
        hListeners = event.listener.empty(0,1);
    end
    
    events (NotifyAccess=private)
        Changed
    end
    
    methods
        function obj = FileSystemWatcher(path)
            assert(NET.isNETSupported,'.NET Framework is not supported on this machine.');
            
            if exist(path,'file')
                [folder,file,ext] = fileparts(path);
                file = [file ext];
            elseif exist(path,'dir')
                folder = path;
                file = '*.*';
            else
                error('''%s'' is not a valid folder or file',path);
            end
            
            obj.path = path;
            
            obj.hWatcher = System.IO.FileSystemWatcher(folder);
            obj.hWatcher.Filter = file;
            obj.hWatcher.EnableRaisingEvents = true;
            
            obj.hListeners(end+1) = addlistener(obj.hWatcher,'Changed',@obj.fireEvent);
            obj.hListeners(end+1) = addlistener(obj.hWatcher,'Created',@obj.fireEvent);
            obj.hListeners(end+1) = addlistener(obj.hWatcher,'Deleted',@obj.fireEvent);
            obj.hListeners(end+1) = addlistener(obj.hWatcher,'Renamed',@obj.fireEvent);
        end
        
        function delete(obj)
            try
                obj.hWatcher.EnableRaisingEvents = false;
            catch
            end
            most.idioms.safeDeleteObj(obj.hListeners);
            most.idioms.safeDeleteObj(obj.hWatcher);
        end
    end
    
    methods (Access = private)
        function fireEvent(obj,src,evt)
            evt_ = most.util.private.FileSystemWatcherEvent(char(evt.ChangeType),char(evt.FullPath),char(evt.Name));
            notify(obj,'Changed',evt_);
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
