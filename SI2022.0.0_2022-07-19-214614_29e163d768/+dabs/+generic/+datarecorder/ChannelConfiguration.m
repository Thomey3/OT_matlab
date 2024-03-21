classdef ChannelConfiguration
    properties
        hIO = dabs.resources.Resource.empty();
        name char = '';
        unit char = '';
        conversionMultiplier single = 1;
    end

    properties (Dependent)
        % null terminated character array for unit
        unitFull;
    end

    properties (Access=private,Transient)
        hResourceStore = [];
    end

    methods (Static)
        function obj = fromTable(v)
            if most.idioms.isa(v,?dabs.generic.datarecorder.ChannelConfiguration)
                obj = v;
                return;
            end

            if iscell(v) && isempty(v)
                obj = dabs.generic.datarecorder.ChannelConfiguration.empty();
                return;
            end

            validateattributes(v,{'cell'},{'2d','ncols',4})
            len = size(v,1);

            obj(1,len) = dabs.generic.datarecorder.ChannelConfiguration();
            for i = 1:len
                obj(i).hIO = v{i,1};
                obj(i).name = v{i,2};
                obj(i).unit = v{i,3};
                obj(i).conversionMultiplier = v{i,4};
            end
        end
    end

    methods
        function v = toTable(obj)
            if ~isempty(obj)
                assert(isvector(obj),'To store as a table, must be a vector.');
            end

            len = numel(obj);
            v = cell(len,4);
            for i = 1:len
                v{i,1} = obj(i).hIO;
                v{i,2} = obj(i).name;
                v{i,3} = obj(i).unit;
                v{i,4} = obj(i).conversionMultiplier;
            end
        end

        function v = containsSignal(obj,signal)
            if most.idioms.isa(signal,?dabs.resources.ios.AI)||most.idioms.isa(signal,?dabs.resources.ios.DI)
                signal = signal.name;
            end

            assert(ischar(signal),'must be a char');

            for cfg = obj
                if strcmp(cfg.hIO.name,signal)
                    v = true;
                    return;
                end
            end
            v = false;
        end
    end

    %% property methods
    methods
        % todo: validate each one
        function obj = set.hIO(obj,v)
            if ischar(v)
                v = obj.hResourceStore.filterByName(v);
            end

            assert(most.idioms.isa(v,?dabs.resources.ios.AI)||most.idioms.isa(v,?dabs.resources.ios.DI),'Must be either AI or DI resources');

            obj.hIO = v;
        end

        function obj = set.name(obj,v)
            assert(ischar(v),'name must be char');
            % to be a valid dataset name, v must not have slashes
            assert(~contains(v,'/'),'name must be not have slashes');
            obj.name = v;
        end

        function obj = set.unit(obj,v)
            assert(ischar(v),'unit must be char');
            assert(numel(v)<=dabs.generic.datarecorder.DataRecorder.MAX_UNITS_LEN,'unit must be <= %d characters, please consider abbreviating',dabs.generic.datarecorder.DataRecorder.MAX_UNITS_LEN);
            obj.unit = v;
        end

        function v = get.hResourceStore(obj)
            if ~most.idioms.isValidObj(obj.hResourceStore)
                obj.hResourceStore = dabs.resources.ResourceStore();
            end

            v = obj.hResourceStore;
        end

        function v = get.unitFull(obj)
            v = obj.unit;
            v(end+1:dabs.generic.datarecorder.DataRecorder.MAX_UNITS_LEN) = 0;
            % don't need to worry about it being bigger due to assert in set
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
