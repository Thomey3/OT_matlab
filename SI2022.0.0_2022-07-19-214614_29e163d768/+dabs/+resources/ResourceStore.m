classdef ResourceStore < most.util.Singleton & matlab.mixin.CustomDisplay
    properties (SetAccess = private, SetObservable)
        hResources = {};
    end
    
    properties (SetAccess = private)
        hSystemTimer;
    end
    
    properties (Hidden, SetAccess = private)
        initialized = false;
        superClassMap = containers.Map.empty();
        superClassMapDirty = true;
    end
    
    properties (SetAccess = private)
        names = {}; % this should not be SetObservable. instead, attach listener to hResources
    end
    
    methods
        function obj = ResourceStore()
            if ~obj.initialized
                obj.initialized = true;
                obj.hSystemTimer = dabs.resources.private.SystemTimer();
                obj.hSystemTimer.start();
                obj.scanSystem();
            end
        end
        
        function delete(obj)
            if obj.initialized
                most.idioms.safeDeleteObj(obj.hSystemTimer);
                
                % delete resources in reverse order of their creation
                hResources_ = flip(obj.hResources);
                independentResourceMask = cellfun(@(hR)most.util.isClassConstructorPublic(class(hR)),hResources_);
                
                most.idioms.safeDeleteObj(hResources_( independentResourceMask));
                most.idioms.safeDeleteObj(hResources_(~independentResourceMask));
            end
        end
    end
    
    methods (Static)
        function tf = isInstantiated()
            className = mfilename('class');
            tf = isInstantiated@most.util.Singleton(className);
        end
    end
    
    methods (Access = ?dabs.resources.Resource)
        function add(obj,hResource)
            validateattributes(hResource,{'dabs.resources.Resource'},{'scalar'});
            
            existingResource = obj.filterByName(hResource.name);
            
            if isempty(existingResource)
                obj.hResources{end+1} = hResource;
            elseif existingResource ~= hResource
                error('Resource with name ''%s'' already exists.',hResource.name);
            end
        end
        
        function remove(obj,hResource)
            %mask = cellfun(@(r)r==hResource,obj.hResources); % this is slow
            mask = strcmp(hResource.name,obj.names);
            obj.hResources(mask) = [];
        end
    end
    
    methods        
        function [v,names] = filter(obj,filterFcn)
            validateattributes(filterFcn,{'function_handle'},{'scalar'});
            mask = cellfun(@(r)isvalid(r)&&filterFcn(r),obj.hResources);
            v = obj.hResources(mask);
            if nargout > 1
                names = cellfun(@(hR)hR.name,v,'UniformOutput',false);
            end
        end
        
        function [v,names] = filterByClass(obj,classNames)
            if ~iscell(classNames)
                classNames = {classNames};
            end
            
            % this is the naive implementation, but quite slow
            %[v,names] = obj.filter(@(r)isa(r,className));
            
            % user superClassMap for performance
            mask = false(numel(classNames),numel(obj.hResources));
            for idx = 1:numel(classNames)
                className = classNames{idx};
                if ischar(className)
                    % No-op
                elseif isa(className,'meta.class')
                    className = className.Name;
                else
                    className = class(className);
                end
                
                if obj.superClassMap.isKey(className)
                    mask(idx,:) = obj.superClassMap(className);
                end
            end
            
            mask = any(mask,1);
            
            v = obj.hResources(mask);
            if nargout>1
                names = obj.names(mask);
            end
        end
        
        function [v,valid] = filterByName(obj,name)
            if iscell(name)
                v = cellfun(@(n)obj.filterByName(n),name,'UniformOutput',false);
                valid = cellfun(@(h)~isempty(h),v);
            elseif isempty(name)
                v = dabs.resources.Resource.empty();
                valid = [];
            elseif isa(name,'dabs.resources.Resource')
                v = name;
                valid = true;
            elseif ischar(name)
                mask = strcmp(name,obj.names);
                v = obj.hResources(mask);
                
                if isempty(v)
                    v = dabs.resources.InvalidResource.empty();
                    valid = false;
                else
                    v = v{1};
                    valid = true;
                end
            else
                assert(false,'Name must be a character vector');
            end
        end
        
        function [v,names] = filterReserved(obj)
            [v,names] = obj.filter(@(r)r.reserved);
        end
        
        function [v,names] = filterUsed(obj)
            [v,names] = obj.filter(@(r)~isempty(r.hUsers));
        end
    end
    
    methods (Access = protected)
        function displayScalarObject(obj)
            entries = cell(1,numel(obj.hResources));
            
            for idx = 1:numel(obj.hResources)
                hResource = obj.hResources{idx};
                c = mfilename('class');
                entry = ['<a href ="matlab:hResourceStore=' c '();hResource=hResourceStore.filterByName(''' hResource.name ''')">' hResource.name '</a>'];
                entry = strjoin({entry,hResource.reserverInfo,hResource.userInfo},' ');
                entries{idx} = entry;
            end
            
            fprintf('%s\n\n', strjoin(entries,'\n') );
            
            %% Nested Functions
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
        end
    end
    
    methods
        function set.hResources(obj,val)
            obj.names = cellfun(@(r)r.name,val,'UniformOutput',false);
            obj.superClassMapDirty = true;
            obj.hResources = val;
        end
    end
    
    methods (Static)
        function clear()
            if dabs.resources.ResourceStore.isInstantiated()
                hResourceStore = dabs.resources.ResourceStore();
                hResourceStore.delete();
            end
        end
        
        function hConfigEditor = showConfig()
            hConfigEditor = dabs.resources.configuration.ResourceConfigurationEditor.show();
        end
        
        function hWb = showWidgetBar()
            hWb = dabs.resources.widget.WidgetBar();
        end
        
        function scanSystem()
            try
                dabs.resources.SerialPort.scanSystem();
                dabs.resources.DAQ.scanSystem();
                dabs.resources.VISA.scanSystem();
            catch ME
                most.ErrorHandler.reportError(ME);
            end
        end
        
        function scanSystemQuick()
            try
                % this function is used to refresh the VISA / COM ports in
                % the config editor pages
                % do not search for new DAQ systems to make this faster
                dabs.resources.SerialPort.scanSystem();
                dabs.resources.VISA.scanSystem();
            catch ME
                most.ErrorHandler.reportError(ME);
            end
        end
        
        function instantiateFromMdf(mdfPath,hWaitbar)
            if nargin<1 || isempty(mdfPath)
                mdfPath = '';
            end
            
            if nargin<2 || isempty(hWaitbar)
                hWaitbar = [];
            end
            
            dabs.resources.Resource.instantiateFromMdf(mdfPath,hWaitbar);
        end
        
        function [v,names] = filterStatic(filterFcn)
            hResourceStore = dabs.resources.ResourceStore();
            [v,names] = hResourceStore.filter(filterFcn);
        end
        
        function [v,names] = filterByClassStatic(classNames)
            hResourceStore = dabs.resources.ResourceStore();
            [v,names] = hResourceStore.filter(classNames);
        end
        
        function h = filterByNameStatic(name)
            hResourceStore = dabs.resources.ResourceStore();
            h = hResourceStore.filterByName(name);
        end
    end
    
    methods
        function val = get.superClassMap(obj)
            if obj.superClassMapDirty
                obj.superClassMap = makeSuperClassMap(obj.hResources);
                obj.superClassMapDirty = false;
            end
            
            val = obj.superClassMap;
        end
    end
end

%%% Local functions
function superClassMap = makeSuperClassMap(hResources)
    resourceSuperClasses = cellfun(@(r)getResourceSuperClasses(r),hResources,'UniformOutput',false);
    numSuperClasses = cellfun(@(r)numel(r),resourceSuperClasses);
    
    [superClasses,~,ic] = unique(vertcat(resourceSuperClasses{:}));
    
    mask = false(numel(superClasses),numel(hResources));
    
    endIdxs = cumsum(numSuperClasses);
    startIdxs = endIdxs-numSuperClasses+1;
    
    for idx = 1:numel(hResources)
        idxs = ic(startIdxs(idx):endIdxs(idx));
        mask(idxs,idx) = true;
    end
    
    mask = mat2cell(mask,ones(1,numel(superClasses)),numel(hResources));
    
    if isempty(resourceSuperClasses)
        superClassMap = containers.Map.empty();
    else
        superClassMap = containers.Map(superClasses,mask);
    end
    
    %%% Nested functions
    function superClasses = getResourceSuperClasses(hResource)
        try
            superClasses = hResource.superClasses;
        catch ME
            if strcmpi(ME.identifier,'MATLAB:class:InvalidHandle')
                % if hResource is a deleted object, we cannot access its property 'superClasses'
                superClasses = superclasses(class(hResource));
            else
                ME.rethrow();
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
