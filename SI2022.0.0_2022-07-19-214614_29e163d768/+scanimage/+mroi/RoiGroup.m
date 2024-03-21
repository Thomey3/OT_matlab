classdef RoiGroup < scanimage.mroi.RoiTree    
    %% Properties    
    properties(SetAccess = private)
        rois = scanimage.mroi.Roi.empty(1,0);
    end
    
    properties(SetAccess = private,Dependent)
        activeRois;   % subset of rois, where roi.enable  == true
        displayRois;  % subset of rois, where roi.display == true
        zs;           % array containing Z's of Rois in RoiGroup
    end
    
    %% Private properties
    properties (Hidden, SetAccess = private)
        roiStatusIds;
        roiUuiduint64s;
        roiUuiduint64sSorted;
        roiUuiduint64sSortIndx;
    end
    
    properties(Access = private)       
        roisListenerMap;
    end
    
    %% Lifecycle
    methods
        function obj=RoiGroup(nm)
            %% Makes an empty RoiGroup
            obj = obj@scanimage.mroi.RoiTree();
            
            obj.roisListenerMap = containers.Map('KeyType',class(obj.uuiduint64),'ValueType','any');
            obj.roiStatusIds = cast([],'like',obj.statusId);
            obj.roiUuiduint64s = cast([],'like',obj.uuiduint64);
            
            if nargin > 0 && ~isempty(nm)
                obj.name = nm;
            end
        end
        
        function delete(obj)
            obj.roisListenerMap; % Matlab 2016a workaround to prevent obj.scanFieldsListenerMap from becoming invalid
            cellfun(@(lh)delete(lh),obj.roisListenerMap.values); % delete all roi listener handles;
        end
        
        function s=saveobj(obj)
            s = saveobj@scanimage.mroi.RoiTree(obj);
            s.rois = arrayfun(@(r) saveobj(r),obj.rois);
        end
        
        function copyobj(obj,other)
            copyobj@scanimage.mroi.RoiTree(obj,other);
            obj.clear();
            arrayfun(@(roi)obj.add(roi),other.rois,'UniformOutput',false);
        end
    end
    
    methods(Access = protected)
        % Override copyElement method:
        function cpObj = copyElement(obj)
            %cpObj = copyElement@matlab.mixin.Copyable(obj);
            cpObj = scanimage.mroi.RoiGroup();
            copyElement@scanimage.mroi.RoiTree(obj,cpObj);
            arrayfun(@(roi)cpObj.add(roi.copy()),obj.rois,'UniformOutput',false);
        end
    end
    
    %% Public methods for AO generation
    methods        
        % public
        function [ao_volts,samplesPerTrigger,sliceScanTime,path_FOV] = scanStackAO(obj,scannerset,zs,zsRelative,zWaveform,flybackFrames,zActuator,sliceScanTime,tuneZ)
            if nargin < 7 || isempty(zActuator)
                zActuator = 'fast';
            end
            if nargin < 8 || isempty(sliceScanTime)
                sliceScanTime = [];
            end
            if nargin < 9 || isempty(tuneZ)
                tuneZ = true;
            end
            
            [path_FOV,samplesPerTrigger,sliceScanTime] = obj.scanStackFOV(scannerset,zs,zsRelative,zWaveform,flybackFrames,zActuator,sliceScanTime,tuneZ);
            ao_volts = arrayfun(@(fov)scannerset.pathFovToAo(fov),path_FOV);
        end
        
        % private
        function [path_FOV,samplesPerTrigger,sliceScanTime] = scanStackFOV(obj,scannerset,zs,zsRelative,zWaveform,flybackFrames,zActuator,sliceScanTime,tuneZ,maxPtsPerSf,applyConstraints)
            if nargin < 7 || isempty(zActuator)
                zActuator = 'fast';
            end
            if nargin < 8
                sliceScanTime = [];
            end
            if nargin < 9
                tuneZ = true;
            end
            if nargin < 10 || isempty(maxPtsPerSf)
                maxPtsPerSf = inf;
            end
            if nargin < 11 || isempty(applyConstraints)
                applyConstraints = true;
            end
            
            if applyConstraints
                scannerset.satisfyConstraintsRoiGroup(obj);
            end
            
            if isempty(sliceScanTime)
                for idx = numel(zs) : -1 : 1
                    scanTimesPerSlice(idx) = obj.sliceTime(scannerset,zs(idx));
                end
                sliceScanTime = max(scanTimesPerSlice);
            end
            
            if numel(zs) > 1 && strcmp(zWaveform, 'sawtooth')
                dz = (zs(end)-zs(1))/(numel(zs)-1);
                dzdt = dz/sliceScanTime;
            else
                dzdt = 0;
            end
            
            flybackTime = scannerset.frameFlybackTime;
            frameTime = sliceScanTime - flybackTime;
            
            numZActuators = numel(scannerset.fastz);
            if numZActuators > 1
                zsRelative(:,numZActuators+1:end) = [];
                zsRelative(:,end+1:numZActuators) = repmat(zsRelative(:,1),1,numZActuators-size(zsRelative,2));
            end
            
            for idx = numel(zs) : -1 : 1
                [outputData{idx}, slcEmpty(idx)] = obj.scanSliceFOV(scannerset,zs(idx),zsRelative(idx,:),dzdt,zActuator,frameTime,flybackTime,zWaveform,maxPtsPerSf);
            end
            
            outputData(numel(zs)+1:numel(zs)+flybackFrames) = obj.zFlybackFrames(scannerset,flybackFrames,frameTime,flybackTime,zWaveform);

            samplesPerTrigger = scannerset.samplesPerTriggerForAO(outputData);
            
            if strcmp(zWaveform, 'slow')
                assert(~any(slcEmpty),'Some slices did not contain any ROIs to scan.');
                path_FOV = cellfun(@(x)scannerset.interpolateTransits(x,tuneZ,zWaveform),outputData);
            else
                dataPoints = most.util.vertcatfields([outputData{:}]);
                path_FOV = scannerset.interpolateTransits(dataPoints,tuneZ,zWaveform);
            end
        end

        % private
        % (used by scanStackFOV and scanStackAO)
        function [path_FOV, slcEmpty] = scanSliceFOV(obj,scannerset,z,zRelative,dzdt,zActuator,frameTime,flybackTime,zWaveformType,maxPtsPerSf)
            %% ao_volts = scan(obj,scannerset,z,dzdt,frameTime,flybackTime)
            %
            %  Generates the full ao for scanning plane z using the 
            %  specified scannerset
            
            if nargin < 10 || isempty(maxPtsPerSf)
                maxPtsPerSf = inf;
            end
            
            % We only need to call this dependent property once within this method
            activeRois_ = obj.activeRois;
            mask = scanimage.mroi.util.fastRoiHitZ(activeRois_,z);
            scanRois = activeRois_(mask);
            slcEmpty = true;
            paths = {};
            tfStim = false;
            
            if numel(scanRois) > 0
                allf = [scanRois(:).scanfields];
                tfStim = isa(allf(1), 'scanimage.mroi.scanfield.fields.StimulusField');
                if tfStim
                    sfs = arrayfun(@(r)r.scanfields(1),scanRois,'UniformOutput',false);
                else
                    sfs = arrayfun(@(r) r.get(z),scanRois,'UniformOutput',false);
                end
                slcEmpty = isempty(sfs);
                
                actz = z;
                actzRelative = zRelative;
                
                for i = 1:numel(scanRois)
                    [paths{end+1}, dt] = scanRois(i).scanPathFOV(scannerset,z,actz,zRelative,actzRelative,dzdt,zActuator,tfStim,maxPtsPerSf);
                    
                    if ~tfStim
                        if i == numel(scanRois)
                            %end of frame transit
                            [paths{end+1}, ~] = scannerset.transitNaN(sfs{i},NaN);
                        else
                            %transit to next roi
                            [paths{end+1}, dtt] = scannerset.transitNaN(sfs{i},sfs{i+1});
                            
                            %update starting actual z position for next scanfield
                            actz = actz + dzdt * (dt + dtt);
                            actzRelative = actzRelative + dzdt * (dt + dtt);
                        end
                    end
                end
            else
                [paths{end+1}, ~] = scannerset.transitNaN(NaN,NaN);
            end

            path_FOV = most.util.vertcatfields([paths{:}]);
            
            % Padding: 
            if ~tfStim && (frameTime + flybackTime) > 0
                path_FOV = scannerset.padFrameAO(path_FOV,frameTime,flybackTime,zWaveformType);
            end
        end
        
        function data = zFlybackFrames(~,ss,flybackFrames,frameTime,flybackTime,zWaveformType)
            data = [];
            for i = flybackFrames:-1:1
                path_FOV = ss.zFlybackFrame(frameTime);
                data{i} = ss.padFrameAO(path_FOV,frameTime,flybackTime,zWaveformType);
            end
        end
        
        % public (but should look at why)
        function scanTime = scanTimes(obj,scannerset,z)
            % Returns array of seconds with scanTime for each scanfield
            % at a particular z
            scanTime=0;
            if ~isa(scannerset,'scanimage.mroi.scannerset.ScannerSet')
                return;                
            end
                
            scanfields  = obj.scanFieldsAtZ(z);
            scanTime    = cellfun(@(scanfield)double(scannerset.scanTime(scanfield)),scanfields);
        end

        % public (but should look at why)
        function [seconds,flybackseconds] = transitTimes(obj,scannerset,z)
            % Returns array of seconds with transitionTime for each scanfield
            % at a particular z
            % seconds includes the transition from park to the first scanfield of the RoiGroup
            % flybackseconds is the flyback transition from last scanfield to park

            seconds=0;
            flybackseconds=0;            
            if ~isa(scannerset,'scanimage.mroi.scannerset.ScannerSet')
                return;                
            end
            
            scanfields = obj.scanFieldsAtZ(z);
            if isempty(scanfields)
                seconds = [];
                flybackseconds = 0;
            else
                scanfields = [{NaN} scanfields {NaN}]; % pre- and ap- pend "park" to the scan field sequence
                
                tp = scanimage.mroi.util.chain(scanfields); % form pair of scanfields for transition
                seconds = cellfun(@(pair) scannerset.transitTime(pair{1},pair{2}),tp);
                
                flybackseconds = seconds(end); % save flybackseconds separately
                seconds(end) = [];
            end
        end
        
        % public
        function seconds = sliceTime(obj,scannerset,z)
            %% Returns the minimum time [seconds] to scan plane z (does not include any padding)
            scantimes = obj.scanTimes(scannerset,z);
            [transitTimes,flybackTime] = obj.transitTimes(scannerset,z);
            seconds = sum(scantimes) + sum(transitTimes) + flybackTime;
        end
        
        function seconds = pathTime(obj,scannerset)
            r = obj.activeRois;
            if isempty(r)
                seconds = nan;
            else
                allf = [r(:).scanfields];
                seconds = sum(arrayfun(@(sf)double(scannerset.scanTime(sf)),allf));
            end
        end

        % public
        function [scanfields,zrois] = scanFieldsAtZ(obj,z,activeSfsOnly)
            % Queries the roigroup for intersection with the specified z plane
            % Returns
            %   scanfields: a cell array of scanimage.mroi.scanfield.ScanField objects
            %   zrois     : a cell array of the corresponding hit rois
            if nargin < 3 || isempty(activeSfsOnly)
                activeSfsOnly = true;
            end
            
            if activeSfsOnly
                rois_ = obj.activeRois;
            else
                rois_ = obj.rois;
            end
            
            %% Returns cell array of scanfields at a particular z            
            scanfields = arrayfun(@(roi)roi.get(z),rois_,'UniformOutput',false);
            maskEmptyFields = cellfun(@(scanfield)isempty(scanfield),scanfields);
            scanfields(maskEmptyFields) = []; % remove empty entries
            rois_(maskEmptyFields) = [];
            zrois = num2cell(rois_);
        end
    end

    %% Public methods for operating on the roi list -- mostly for UI
    methods
        function clear(obj)
            v = obj.roisListenerMap.values;
            delete([v{:}]);                 % delete all roi listener handles
            obj.roisListenerMap.remove(obj.roisListenerMap.keys); % clear roisListenerMap
            obj.roiStatusIds = cast([],'like',obj.statusId);
            obj.roiUuiduint64s = cast([],'like',obj.uuiduint64);
            obj.rois = scanimage.mroi.Roi.empty(1,0);
        end
        
        function roi = getRoiById(obj,id)
            i = obj.idToIndex(id,true);
            roi = obj.rois(i);
        end

        function idxs = idToIndex(obj,ids,throwError)
            % returns the index of the array obj.rois for roi ids
            % ids: cellstr of uuids OR vector of uuidint64 OR numeric vector
            % throwError: false (standard): does not throw error
            %             true: issues error if one or more rois with given id are
            %                           not found
            % returns idxs: indices of rois in obj.rois; for unknown rois 0
            %               is returned
            
            if nargin < 3 || isempty(throwError)
                throwError = false;
            end
            
            
            if isa(ids,class(obj.uuiduint64))
                % assume id is a uuiduint64
                idxs = ismembc2(ids,obj.roiUuiduint64sSorted); % performance optimization
                idxs(idxs>0) = obj.roiUuiduint64sSortIndx(idxs(idxs>0)); % resort
            elseif isnumeric(ids)
                idxs = ids;
                idxs(idxs<1) = 0;
                idxs(idxs>length(obj.rois)) = 0;
            elseif ischar(ids) || iscellstr(ids)
                % this is relatively slow. better: use uuiduint64
                [~,idxs] = ismember(ids,{obj.rois.uuid});
            else
                error('Unknown id format: %s',class(ids));
            end
            
            if throwError && any(idxs==0)
                if isa(ids,'char')
                    zeroIds = ['''' ids ''''];
                elseif iscellstr(ids)
                    zeroIds = strjoin(ids(idxs==0));
                else
                    zeroIds = mat2str(ids(idxs==0));
                end
                
                error('SI:mroi:StimSeriesIndexNotFound Could not find rois with id(s) %s',zeroIds);
            end
        end
        
        function obj = add(obj, roi, nameOverride)
            assert(isa(roi, 'scanimage.mroi.Roi'),...
                'MROI:TypeError',...
                'Expected an object of type scanimage.mroi.Roi');
            
            if nargin > 2 && ~isempty(nameOverride)
                roi.name = nameOverride;
            elseif isempty(roi.name_)
                roi.name = sprintf('ROI %d', obj.getRoiIndex());
            end
            
            obj.roiStatusIds(end+1) = roi.statusId;
            obj.roiUuiduint64s(end+1) = roi.uuiduint64;
            obj.rois = [obj.rois roi];
            
            % add listeners to roi
            if ~obj.roisListenerMap.isKey(roi.uuiduint64)
                lh = most.ErrorHandler.addCatchingListener(roi,'changed',@obj.roiChanged);
                obj.roisListenerMap(roi.uuiduint64) = lh;
            end
            obj.fireChangedEvent(scanimage.mroi.EventData(roi,'added','',[],[],obj));
        end
        
        function mc=scanfieldMetaclass(obj)
            if(isempty(obj.rois) || isempty(obj.rois(1).scanfields)),
                mc=meta.class.fromName(''); % empty class if no scanfields/not determined
            else
                mc=metaclass(obj.rois(1).scanfields(1));
            end
        end

        function obj=filterByScanfield(obj,f)
            % Disables some scanfields according to f.
            %
            % f must be a function mapping a scanfield to a boolean
            %   if f returns false, then the entire roi will be disabled.            
            for r=obj.rois
                tf=arrayfun(f,r.scanfields);
                if any(~tf)
                    r.enable=false;
                end
            end

        end
        
        function newIdxs = insertAfterId(obj,id,rois)
            i=obj.idToIndex(id,true);
            if nargin < 3 || isempty(rois)
                rois=scanimage.mroi.Roi();
            else
                assert(isa(rois,'scanimage.mroi.Roi'),'Roi must be of type scanimage.mroi.Roi');
            end
            rois = rois(:)'; % assert row vector
            numRois = length(rois);
            newIdxs = (1:numRois) + i;
            
            % add listeners to rois
            for roi = rois
                if ~obj.roisListenerMap.isKey(roi.uuiduint64)
                    lh = most.ErrorHandler.addCatchingListener(roi,'changed',@obj.roiChanged);
                    obj.roisListenerMap(roi.uuiduint64) = lh;
                end
            end
            
            obj.roiStatusIds = [obj.roiStatusIds(1:i) rois.statusId obj.roiStatusIds(i+1:end)];
            obj.roiUuiduint64s = [obj.roiUuiduint64s(1:i) rois.uuiduint64 obj.roiUuiduint64s(i+1:end)];
            obj.rois=[obj.rois(1:i) rois obj.rois(i+1:end)];
        end

        function rois_ = removeById(obj,id)
            i=obj.idToIndex(id,true);
            rois_ = obj.rois(i);
            
            for roi = rois_
                if ~any(ismember(roi.uuiduint64,[obj.rois.uuiduint64]))
                    lh = obj.roisListenerMap(roi.uuiduint64);
                    delete(lh);
                    obj.roisListenerMap.remove(roi.uuiduint64);
                end
            end
            
            obj.roiUuiduint64s(i) = [];
            obj.roiStatusIds(i) = [];
            obj.rois(i) = [];
            obj.fireChangedEvent(scanimage.mroi.EventData([],'removed','',[],[],obj));
        end

        function newIdx = moveById(obj,id,step)
            % changed index of roi from i to i+step
            i=obj.idToIndex(id,true);
            
            if step == 0
                newIdx = i;
                return
            elseif i+step < 1
                idxs = [i, 1:i-1, i+1:length(obj.rois)];
                newIdx = 1;
            elseif i+step > length(obj.rois)
                idxs = [1:i-1, i+1:length(obj.rois), i];
                newIdx = length(obj.rois);
            else
                idxs = 1:length(obj.rois);
                idxs([i,i+step]) = flip(idxs([i,i+step]));
                newIdx = i+step;
            end
            
            obj.roiStatusIds=obj.roiStatusIds(idxs);
            obj.roiUuiduint64s=obj.roiUuiduint64s(idxs);
            obj.rois=obj.rois(idxs);
        end
        
        function newIdx = moveToFrontById(obj,id)
            newIdx = obj.moveById(id,-inf);
        end

        function newIdx = moveToBackById(obj,id)
            newIdx = obj.moveById(id,inf);
        end
        
        % Both of these functions need to be present in the free version to
        % satisfy abstract class.
        function tf = isequalish(obj,other, tfIgnoreZ)
            tf = false(numel(other),1);
            
            for idx = 1:numel(other)
                if ~isempty(obj.rois) && numel(obj.rois)==numel(other(idx).rois)
                    tfmask = arrayfun(@(a,b)a.isequalish(b,tfIgnoreZ),obj.rois,other(idx).rois);
                    tf(idx) = all(tfmask);
                end
            end
        end
        
        function h = hashgeometry(obj)
            % not implemented
            assert(false);
        end
        
        function addZOffset(obj,offset)
            for idx = 1:numel(obj.rois)
                obj.rois(idx).addZOffset(offset);
            end
        end
    end % end public methods
    
    methods (Hidden)
        function roiChanged(obj,src,evt)
            idx = obj.idToIndex(src.uuiduint64);
            if idx
                obj.roiStatusIds(idx) = src.statusId;
                obj.fireChangedEvent(evt);
            end
        end
    end
    
    methods (Hidden, Access = private)
        function idx = getRoiIndex(obj)
            idx = 1;
            if isempty(obj.rois)
                return;
            end
            
            namedRois = false(size(obj.rois));
            for iRois = 1:length(obj.rois)
                namedRois(iRois) = ~isempty(obj.rois(iRois).name_);
            end
            
            if ~any(namedRois)
                return;
            end
            
            idxStr = regexp({obj.rois(namedRois).name},...
                'ROI ([0-9]+)', 'tokens', 'once');
            defaultNamedRois = false(size(idxStr));
            for iNames = 1:length(defaultNamedRois)
                defaultNamedRois(iNames) = ~isempty(idxStr{iNames});
            end
            
            if ~any(defaultNamedRois)
                return;
            end
            
            idx = max(str2double([idxStr{defaultNamedRois}])) + 1;
        end
    end
    
    %% Property access methods
    methods
        function val = get.activeRois(obj)
            if ~isempty(obj.rois)
                val = obj.rois([obj.rois.enable]);
            else
                val = [];
            end
        end
        
        function val = get.displayRois(obj)
            if ~isempty(obj.rois)
                val = obj.rois([obj.rois.enable] & [obj.rois.display]);
            else
                val = [];
            end
        end
        
        function val = get.zs(obj)
            zs = [];
            for roi = obj.rois
                zs = horzcat(zs,roi.zs(:)'); %#ok<AGROW>
            end
            val = sort(unique(zs));
        end
        
        function set.rois(obj,val)
            if isempty(val)
                val = scanimage.mroi.Roi.empty(1,0);
            end
            obj.rois = val;
            obj.fireChangedEvent();
        end
        
        function set.roiUuiduint64s(obj,val)
            if isempty(val)
                val = cast([],'like',obj.uuiduint64);
            end
            
            obj.roiUuiduint64s = val;
            [obj.roiUuiduint64sSorted,obj.roiUuiduint64sSortIndx] = sort(val);
        end
        
        function saveToFile(obj,f)
            %roigroup = obj;
            %save(f,'roigroup','-mat');
            most.json.savejson('',obj,f);
        end
    end
    
    %% Static methods
    methods(Static)
        function obj=loadobj(s)
            obj=scanimage.mroi.RoiGroup();
            loadobj@scanimage.mroi.RoiTree(obj,s);
            if iscell(s.rois)
                s.rois = [s.rois{:}];
            end
            arrayfun(@(r) obj.add(scanimage.mroi.Roi.loadobj(r)),s.rois,'UniformOutput',false);
        end
        
        function obj=loadFromFile(f)
            try
                obj = most.json.loadjsonobj(f);
            catch ME
                % support for old binary roigroup file format
                try
                    data = load(f,'-mat','roigroup');
                    obj = data.roigroup;
                catch
                    rethrow(ME);
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
