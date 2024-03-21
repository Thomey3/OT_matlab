classdef RoiTree < matlab.mixin.Copyable & most.util.Uuid
    %% Parent class of RoiGroup, Roi and ScanField    
    properties (Hidden, SetAccess = private)
        statusId = uint32(0);  % random number that increments when obj.fireChangedEvent() is executed; used to detect a change in gui
    end
    
    properties (SetAccess = protected)
        delayChangedEvent = false;
    end
    
    properties (SetObservable,Dependent)
        name            % [string] description of roi. if unset, first 8 characters of uuid are returned
    end
    
    properties (Hidden, SetAccess = protected)
        name_ = ''; 
    end
    
    properties (Hidden)
        UserData = [];  % used to store additional data
    end
    
    %% Events
    events (NotifyAccess = protected)
        changed;
    end
    
    %% lifecycle
    methods
        function obj = RoiTree()            
            obj.updateStatusId();
            updateObjectCount(obj,'add');
        end
        
        function delete(obj)
            updateObjectCount(obj,'remove');
        end
    end
    
    methods
        function s = saveobj(obj,s)
            if nargin < 2 || isempty(s)
                s = struct();
            end
            s.ver = 1;
            s.classname = class(obj);
            s.name = obj.name_;
            
            % added with ScanImage 2018b
            s.UserData = obj.UserData;
            s.roiUuid = obj.uuid;
            s.roiUuiduint64 = obj.uuiduint64;
        end
        
        function obj = loadobj(obj,s)
            if nargin < 2
                error('Missing paramter in loadobj: Cannot create new object within RoiTree');
            end
            
            if ~isfield(s,'ver')
                if isfield(s,'name_') % for backward compatibility
                    obj.name_ = s.name_;
                else
                    obj.name=s.name;
                end
            else
                % at this time the only version is v=1;
                obj.name = s.name;
                if isfield(s,'UserData')
                    obj.UserData = s.UserData;
                end
            end
        end
    end
    
    methods (Hidden)
        function obj = copyobj(obj,other)
            obj.name_ = other.name_;
        end
    end
        
    methods (Access = protected)
        function cpObj = copyElement(obj,cpObj)
            assert(~isempty(cpObj) && isvalid(cpObj));
            
            if ~isempty(obj.name_)
                ctr = regexpi(obj.name_,'[0-9]+$','match','once');
                if ~isempty(ctr)
                    newCtr = sprintf(['%0' int2str(length(ctr)) 'd'],str2double(ctr)+1);
                    newName = [obj.name_(1:end-length(ctr)) newCtr];
                    cpObj.name_ = newName;
                else
                    cpObj.name_ = [obj.name_ '-01'];
                end
            end
        end
        
        function fireChangedEvent(obj,varargin)            
            obj.fireChangedEventInternal(varargin{:});
        end
        
        function updateStatusId(obj)
            newId = getNewId();
            while newId == obj.statusId % ensure the ID actually changes
                newId = getNewId();
            end
            obj.statusId = newId;
            
            function newId = getNewId()
                newId = uint32(rand()*4294967295);
            end
        end
    end
    
    methods (Access = private)
        function fireChangedEventInternal(obj,evtData)
            if obj.delayChangedEvent
                return
            end
            
            obj.updateStatusId();
            
            if nargin < 2
                notify(obj,'changed');
            else
                notify(obj,'changed',evtData);
            end
        end
    end
    
    methods
        function set.name(obj,val)
            if isempty(val)
                val = '';
            else
                validateattributes(val,{'char'},{'row'});
            end
            
            obj.name_ = val;
            updateObjectCount(obj,'update');
            notify(obj,'changed');
        end
        
        function val = get.name(obj)
            val = obj.name_;
            if isempty(obj.name_) && ~isempty(obj.uuid)
               val = obj.uuid(1:8);
            end            
        end
        
        function set.delayChangedEvent(obj,val)
            validateattributes(val,{'numeric','logical'},{'binary'});
            oldVal = obj.delayChangedEvent;
            
            obj.delayChangedEvent = val;
            
            reactivated = ~val && oldVal;
            if reactivated
                obj.fireChangedEventInternal();
            end
        end
    end
    
    methods (Static)
        function val = objectcount()
            val = updateObjectCount();
        end
    end
    
    methods (Abstract)
        tf = isequalish(objA, objB);
        h = hashgeometry(obj);
    end
end

%% Local functions
function val = updateObjectCount(obj,action)
    persistent count
    if isempty(count)
        count = struct();
    end

    if nargin < 1 || isempty(obj)
        val = count;
        return
    end

    classname = regexprep(class(obj),'\.','_');
    if ~isfield(count,classname)
        count.(classname) = 0;
        count.([classname '_uuids']) = {};
        count.([classname '_names']) = {};
    end

    mask = strcmp(count.([classname '_uuids']),obj.uuid);
    
    switch action
        case {'add','update'}
            if any(mask)
                updateObjectCount(obj,'remove');
            end
            
            count.(classname) = count.(classname) + 1;
            count.([classname '_uuids']){end+1} = obj.uuid;
            count.([classname '_names']){end+1} = obj.name;
        case 'remove'
            if any(mask)
                count.(classname) = count.(classname) - 1;
                count.([classname '_uuids'])(mask) = [];
                count.([classname '_names'])(mask) = [];
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
