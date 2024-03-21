classdef Resource < handle
    properties (SetAccess = immutable, Transient)
        name = '';
    end
    
    properties (SetAccess = immutable, Hidden)
        superClasses = {};
    end
    
    properties (SetAccess = protected, SetObservable, AbortSet, Transient)
        errorMsg = '';
        warnMsg = '';
    end
    
    properties (SetAccess = private, SetObservable, Transient, Hidden)
        reserved = false;
        hReserver = [];
        
        hUsers = {};
        allowMultipleUsers = false(0);
    end
    
    properties (SetAccess = private, Transient, Hidden)
        userDescriptions = {}; % this should not be SetObservable. listen to hUsers instead
    end
    
    properties (SetAccess = private, Dependent, Transient)
        userInfo
        reserverInfo
    end
    
    properties (SetAccess = private, Hidden, Transient)
        hResourceStore
    end
    
    properties (SetAccess = private, GetAccess = private)
        hListenersUserDeleted = event.listener.empty(1,0);
    end
    
    methods
        function obj = Resource(name)
            try
                assert(nargin==1,'Require name as constructor input');
                validateattributes(name,{'char'},{'row'});
                
                obj.name = name;
                obj.superClasses = [{class(obj)};superclasses(obj)]; % cache superclasses for performance
                
                obj.hResourceStore = dabs.resources.ResourceStore();
                obj.hResourceStore.add(obj);
                
            catch ME
                obj.delete();
                rethrow(ME);
            end
        end
        
        function delete(obj)
            delete(obj.hListenersUserDeleted);
            if most.idioms.isValidObj(obj.hResourceStore)
                obj.hResourceStore.remove(obj);
            end
        end
    end
    
    methods
        function reinit(obj)
            % overload this method if needed
            % this method reserves all resources, and initalizes the hardware
            % this method must not throw!
            % if an error occurs, it must instead set the errorMsg property
            obj.errorMsg = '';
        end
        
        function deinit(obj)
            % overload this method if needed
            % this method unreserves all resources, and deinitalizes the hardware
            % this method must not throw!
            % at the end it sets errorMsg to 'uninitialized'
        end
        
        function reserve(obj,hUser)
            if ~most.idioms.isValidObj(obj)
                return
            end
            
            assert(isempty(obj.errorMsg),'%s: ''%s'' is trying to reserve resource, but resource is in an error state: %s',...
                obj.name,getName(hUser),obj.errorMsg);
            
            assert(~isempty(hUser));
            assert(obj.isUser(hUser),'%s: ''%s'' is trying to reserve resource, but is not a registered user.',...
                   obj.name,getName(hUser));
            
            if obj.reserved && isequal(obj.hReserver,hUser)
                return % Nothing to do
            end
            
            assert(~obj.reserved,'%s: reservation attempt by %s failed. Resource is already reserved by %s:%s',...
                   obj.name,getName(hUser),getName(obj.hReserver),obj.getUserDescription(obj.hReserver));
            
            if ~obj.reserved
                obj.hReserver = hUser;
                obj.reserved = true;
            end
        end
        
        function unreserve(obj,hUser)
            if most.idioms.isValidObj(obj)
                if obj.reserved && isequal(hUser,obj.hReserver)
                    obj.hReserver = [];
                    obj.reserved = false;
                end
            end
        end
        
        function forceUnreserve(obj,hUser)
            if nargin < 2 || isempty(hUser)
                hUser = [];
            end
            
            if ~most.idioms.isValidObj(obj)
                return
            end
            
            if obj.reserved
                if ~isequal(hUser,obj.hReserver)
                    most.idioms.warn('%s was reserved by %s:%s, but just forced to be unreserved by %s',...
                        obj.name,getName(obj.hReserver),obj.getUserDescription(obj.hReserver),getName(hUser));
                end
                
                obj.unreserve(obj.hReserver);
            end
        end
        
        function assigninBase(obj)
            assignin('base','hResource',obj);
            msg = sprintf('''%s'' assigned in base: <a href ="matlab:dabs.resources.Resource.tryAssignInBase(''%s'')">hResource</a>' ...
                ,obj.name,obj.name);
            
            if ~isa(obj,'dabs.resources.SIComponent')
                msg = sprintf(['%s' ...
                    ' [<a href ="matlab:dabs.resources.Resource.tryReinitResource(''%s'')">Reinit</a>]' ...
                    ' [<a href ="matlab:dabs.resources.Resource.tryDeinitResource(''%s'')">Deinit</a>]'] ...
                    ,msg,obj.name,obj.name);
            end
            
            if isa(obj,'dabs.resources.configuration.HasConfigPage') && ~isempty(obj.ConfigPageClass)
                msg = sprintf(['%s' ...
                    ' [<a href ="matlab:dabs.resources.Resource.tryConfigureResource(''%s'')">Configure</a>]'] ...
                    ,msg,obj.name);
            end
            
            fprintf('%s\n',msg);
            
            if ~isempty(obj.errorMsg)
                fprintf(2,'%s Error Message: %s\n\n',obj.name,obj.errorMsg);
            end
        end
    end
    
    methods (Static, Hidden)
        function tryAssignInBase(name)
            hResource = dabs.resources.ResourceStore.filterByNameStatic(name);
            
            if isempty(hResource)
                fprintf(2,'''%s'' not found in system',name);
                return
            end
            
            assignin('base','hResource',hResource);
            evalin('base','hResource');
        end
        
        function tryReinitResource(name)
            hResource = dabs.resources.ResourceStore.filterByNameStatic(name);
            
            if isempty(hResource)
                fprintf(2,'''%s'' not found in system',name);
                return
            end
            
            hResource.reinit();
            
            if isempty(hResource.errorMsg)
                fprintf('''%s'' reinitted\n',name);
            else
                fprintf(2,'''%s'' init failed with error:\n',name);
                fprintf(2,'%s\n\n',hResource.errorMsg);
            end
        end
        
        function tryDeinitResource(name)
            hResource = dabs.resources.ResourceStore.filterByNameStatic(name);
            
            if isempty(hResource)
                fprintf(2,'''%s'' not found in system',name);
                return
            end
            
            hResource.deinit();
            fprintf('''%s'' deinitted\n',name);
        end
        
        function tryConfigureResource(name)
            hResource = dabs.resources.ResourceStore.filterByNameStatic(name);
            
            if isempty(hResource)
                fprintf(2,'''%s'' not found in system',name);
                return
            end
            
            assert(isa(hResource,'dabs.resources.configuration.HasConfigPage'),'''%s'' cannot be configured.',name);
            hResource.showConfig();
        end
    end
    
    %% Overloads
    methods
        function tf = isequal(varargin)
            % overloading isequal;
            % if two empty arrays are compared, the builtin isequal returns
            % 'true' even if the array classes are different
            % this overloaded function checks the array classes in addition
            
            if isempty(varargin{1})
                classNames = cellfun(@(c)class(c),varargin,'UniformOutput',false);
                
                tf = isUnique(classNames);
                tf = tf && builtin('isequal',varargin{:});
            else
                tf = builtin('isequal',varargin{:});
            end
            
            %%% Nested function
            function tf = isUnique(s)
                tf = numel(unique(s))<=1;
            end
        end        
    end
    
    methods
        function registerUser(obj,hUser,description,allowMultipleUsers)
            if nargin<4 || isempty(allowMultipleUsers)
                allowMultipleUsers = false;
            end

            if most.idioms.isValidObj(obj)
                obj.unregisterUser(hUser);
                
                validateattributes(description,{'char'},{'row'});
                validateattributes(allowMultipleUsers,{'logical','numeric'},{'binary','scalar'});
                
                obj.userDescriptions{end+1} = description;
                obj.allowMultipleUsers(end+1) = logical(allowMultipleUsers);
                obj.hUsers{end+1} = hUser;
            end
        end
        
        function unregisterUser(obj,hUser)
            if most.idioms.isValidObj(obj)
                obj.unreserve(hUser);
                
                [~,mask] = obj.isUser(hUser);
                obj.userDescriptions(mask) = [];
                obj.allowMultipleUsers(mask) = [];
                obj.hUsers(mask) = [];
            end
        end
        
        function [tf,conflictUsers] = hasUserConflict(obj)
            tf = numel(obj.hUsers)>1 && ~all(obj.allowMultipleUsers);

            if tf
                conflictUsers = obj.hUsers(~obj.allowMultipleUsers);
            else
                conflictUsers = {};
            end
        end
        
        function description = getUserDescription(obj,hUser)
            description = '';
            
            [tf,mask] = obj.isUser(hUser);
            if tf
                description = obj.userDescriptions(mask);
                description = description{1};
            end
        end
        
        function [tf,mask] = isUser(obj,hUser)
            if most.idioms.isValidObj(obj)
                mask = cellfun(@(u)isequal(u,hUser),obj.hUsers);
                tf = any(mask);
            else
                tf = false;
                mask = false(1,0);
            end
        end
        
        function assertNoError(obj)
            if most.idioms.isValidObj(obj)
                most.ErrorHandler.assert(isempty(obj.errorMsg),'%s is in error state: %s',obj.name,obj.errorMsg);
            else
                most.ErrorHandler.error('Invalid resource');
            end
        end
    end
    
    methods
        function val = get.userInfo(obj)
            val = cell(1,numel(obj.hUsers));
            for idx = 1:numel(obj.hUsers)
                hUser = obj.hUsers{idx};
                userDescription = obj.userDescriptions{idx};
                val{idx} = sprintf('<%s: %s>',getName(hUser),userDescription);
            end
            
            val = strjoin(val,' ');
        end
        
        function val = get.reserverInfo(obj)
            val = '';
            if ~isempty(obj.hReserver)
                val = sprintf('<Reserved: %s>',getName(obj.hReserver));
            end
        end
    end
    
    methods
        function set.errorMsg(obj,val)
            if isempty(val)
                val = '';
            else
                validateattributes(val,{'char'},{'row'});
            end
            
            obj.errorMsg = deblank(val);
        end
        
        function set.hUsers(obj,val)
            obj.hUsers = val;
            obj.attachUserListeners();
        end
    end
    
    methods (Access = private)
        function attachUserListeners(obj)
            % attach listeners to hUsers to detect when user is being
            % deleted. when a user is deleted unregister that user
            
            delete(obj.hListenersUserDeleted)
            obj.hListenersUserDeleted = event.listener.empty();
            
            for idx = 1:numel(obj.hUsers)
                hUser = obj.hUsers{idx};
                if most.idioms.isValidObj(hUser)
                    obj.hListenersUserDeleted(end+1) = most.ErrorHandler.addCatchingListener(...
                        hUser,'ObjectBeingDestroyed',@(varargin)obj.unregisterUser(hUser));
                end
            end
        end
    end
    
    methods (Static)
        function hResources = instantiateFromMdf(mdfPath,hWaitbar)
            if nargin<1 || isempty(mdfPath)
                mdfPath = '';
            end
            
            if nargin<2 || isempty(hWaitbar)
                hWaitbar = [];
            end
            
            hResourceStore = dabs.resources.ResourceStore();
            hResourceStore.scanSystem();
            
            status = most.HasMachineDataFile.ensureMDFExists(mdfPath);
            hMdf = most.MachineDataFile.getInstance();
            
            most.ErrorHandler.assert(hMdf.isLoaded,'No Machine Data File is loaded');
            hMdf.reload();
            
            headings = {hMdf.fHData.heading};
            
            entries = struct('className',{},'name',{},'isDAQ',{},'isNormalResource',{},'isSI',{},'isScan2D',{},'isOtherSIComponent',{});
            for idx = 1:numel(headings)
                [className_,name_,isResource,isConstructable] = dabs.resources.Resource.mdfHeadingToClassAndName(headings{idx});
                if isResource && isConstructable
                    entry = struct();
                    entry.className = className_;
                    entry.name = name_;
                    entry.isDAQ = most.idioms.isa(className_,'dabs.resources.DAQ');
                    entry.isNormalResource = ~most.idioms.isa(className_,'dabs.resources.SIComponent') && ~entry.isDAQ;
                    entry.isSI = most.idioms.isa(className_,'scanimage.SI');
                    entry.isScan2D = most.idioms.isa(className_,'scanimage.components.Scan2D');
                    entry.isOtherSIComponent = ~entry.isNormalResource && ~entry.isSI && ~entry.isScan2D;
                    entries(end+1) = entry;
                end
            end
            
            % reorder entries
            daqEntries = entries([entries.isDAQ]);
            resourceEntries = entries([entries.isNormalResource]);
            siEntry = entries([entries.isSI]);
            scan2DEntries = entries([entries.isScan2D]);
            otherSIComponentEntries = entries([entries.isOtherSIComponent]); % no need to load these explicitly. They are instantiated in the SI constructor
            
            entries = [daqEntries,resourceEntries,scan2DEntries,siEntry];
            
            hResources = {};
            
            numStartEntries = numel(entries);
            while ~isempty(entries)
                processEntry(entries(1));
            end
            
            %%% Nested function
            function processEntry(entry)
                % remove entry from entries list
                mask = strcmp(entry.name,{entries.name});
                entries(mask) = [];
                
                alreadyInstantiated = ~isempty(hResourceStore.filterByName(entry.name));
                if alreadyInstantiated
                    return
                end
                
                loadAdditionalClasses(entry);
                
                if most.idioms.isValidObj(hWaitbar)
                    try
                        numStartEntries = max(numStartEntries,1);
                        progress = (numStartEntries-numel(entries))/numStartEntries;
                        msg = sprintf('Loading %s\n(%s)' ...
                             ,most.idioms.latexEscape(entry.name) ...
                             ,most.idioms.latexEscape(entry.className));
                         
                        waitbar(progress,hWaitbar,msg);
                    catch ME
                        most.ErrorHandler.logAndReportError(ME);
                    end
                end
                
                try                    
                    constructor = str2func(entry.className);
                    hResources{end+1} = constructor(entry.name);
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
            end
            
            function loadAdditionalClasses(entry)
                try
                    classes = [];
                    if most.idioms.isa(entry.className,'dabs.resources.configuration.HasConfigPage')
                        getClassesToLoadFirstFcn = str2func([entry.className '.getClassesToLoadFirst']);
                        classes = getClassesToLoadFirstFcn();
                    end
                catch ME
                    classes = {};
                    most.ErrorHandler.logAndReportError(ME);
                end
                
                if isempty(classes)
                    return
                end
                
                if ~iscell(classes)
                    classes = {classes};
                end
                
                entries_ = entries; % make a local copy
                for entryIdx = 1:numel(entries_)
                    entry_ = entries_(entryIdx);
                    
                    matches = cellfun(@(c)most.idioms.isa(entry_.className,c),classes);
                    
                    if any(matches)
                        processEntry(entry_);
                    end
                end
            end
        end
        
        function [classname,name,isResource,isConstructable] = mdfHeadingToClassAndName(heading)
            classname = '';
            name = '';
            isResource = false;
            isConstructable = false;
            
            [match,tokens] = regexpi(heading,'^\s*([a-z]+[a-z0-9_.]*)\s+\((.+)\)\s*$','match','tokens','once');
            
            if isempty(match)
                return
            end
            
            classname_ = tokens{1};
            name_ = tokens{2};
            
            if exist(classname_,'class')
                try
                    isResource = most.idioms.isa(classname_,mfilename('class'));
                    isConstructable = most.util.isClassConstructorPublic(classname_);
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                    return
                end
                
                if isResource
                    classname = classname_;
                    name      = name_;
                end
            end
        end
    end
end

%% Local Functions
function name = getName(obj)
    name = 'Unknown';

    if isempty(obj)
        % no-op
    elseif isprop(obj,'name')
        name = obj.name;
    elseif ischar(obj)
        name = obj;
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
