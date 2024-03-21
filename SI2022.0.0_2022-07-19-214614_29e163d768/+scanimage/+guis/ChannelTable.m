classdef ChannelTable < handle
    
    properties
        hTable;
        hSI;
        hSIC;
        
        hCIH;
        
        settingsAreSimple = true;
        areSettingsSimple = true;
        nRows;
        cmEditable = true;
        clrmaps = {''};
        inputRgFmt = 'char';
        
        s2dListners;
        listners;
    end
    
    
    %% LIFECYCLE
    methods
        function obj = ChannelTable(hFig)
            obj.hTable = findobj(hFig,'Tag','tblChanConfig');
            obj.hTable.CellEditCallback = @obj.cellEditCb;
            obj.hTable.Data = {};
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.s2dListners);
            most.idioms.safeDeleteObj(obj.listners);
            most.idioms.safeDeleteObj(obj.hTable);
        end
    end
    
    %% EVERYTHING ELSE
    methods
        function imgSysChanged(obj)
            % update listeners
            most.idioms.safeDeleteObj(obj.s2dListners);
            
            if isa(obj.hSI.hScan2D, 'scanimage.components.scan2d.RggScan')
                obj.s2dListners = most.ErrorHandler.addCatchingListener(obj.hSI.hScan2D, 'virtualChannelSettings', 'PostSet', @obj.virtChansChanged);
            end
            
            % set the input ranges to the available ranges of hScan2D
            cellNumRanges = obj.hSI.hChannels.channelAvailableInputRanges;
            obj.inputRgFmt = cellfun(@(numRange)sprintf('[%s %s]',num2str(numRange(1)),num2str(numRange(2))),cellNumRanges,'UniformOutput',false);
            
            obj.virtChansChanged();
        end
        
        function virtChansChanged(obj,varargin)
            obj.updateFullData();
        end
        
        function updateFullData(obj,varargin)
            numChan = obj.hSI.hChannels.channelsAvailable;
            
            saves = ismember(1:numChan, obj.hSI.hChannels.channelSave);
            disps = ismember(1:numChan, obj.hSI.hChannels.channelDisplay);
            mc = obj.hSI.hChannels.channelMergeColor(1:numChan);
            
            if iscolumn(mc)
               mc = mc';
            end
            
            cms = obj.clrmaps;
            cms(numChan+1:end) = [];
            cms(end+1:numChan) = cms(end);
            
            obj.settingsAreSimple = obj.areSettingsSimple;
            if obj.settingsAreSimple
                obj.hTable.ColumnName = {  'Save'; 'Display'; 'Input Range'; 'Offset'; 'Subtract Offset'; 'Merge Color'; 'Colormap' };
                obj.hTable.ColumnWidth = {  'auto' 'auto' 'auto' 'auto' 'auto' 'auto' 180 };
                obj.hTable.ColumnEditable = [true(1,6) obj.cmEditable];
                obj.hTable.ColumnFormat = {  'logical' 'logical' obj.inputRgFmt 'numeric' 'logical' {  'Green' 'Red' 'Blue' 'Gray' 'None' } 'char' };
                
                rgs = cellfun(@(r){sprintf('[%s %s]', num2str(r(1)), num2str(r(2)))}, obj.hSI.hChannels.channelInputRange(1:numChan));
                offs = obj.hSI.hChannels.channelOffset(1:numChan);
                subso = obj.hSI.hChannels.channelSubtractOffset(1:numChan);
                
                d = arrayfun(@(s, d, r, o, so, m, cm){{s d r{1} o so [upper(m{1}(1)) m{1}(2:end)] cm{1}}'}, saves, disps, rgs, offs, subso, mc, cms);
            else
                obj.hTable.ColumnName = {  'Save'; 'Display'; 'Merge Color'; 'Colormap' };
                obj.hTable.ColumnWidth = {  'auto' 'auto' 'auto' 180 };
                obj.hTable.ColumnEditable = [true(1,3) obj.cmEditable];
                obj.hTable.ColumnFormat = {  'logical' 'logical' {  'Green' 'Red' 'Blue' 'Gray' 'None' } 'char' };
                
                d = arrayfun(@(s, d, m, cm){{s d [upper(m{1}(1)) m{1}(2:end)] cm{1}}'}, saves, disps, mc, cms);
            end
            
            obj.hTable.Data = [d{:}]';
            obj.hTable.RowName = arrayfun(@(n){sprintf('Channel %d',n)},1:numChan);
        end
        
        function cellEditCb(obj, ~, evt)
            chanIdx = evt.Indices(1);
            colIdx = evt.Indices(2);
            
            if ~obj.settingsAreSimple && (colIdx > 2)
                colIdx = colIdx + 3;
            end
            
            switch colIdx
                case 1
                    tfSave = [obj.hTable.Data{:,1}];
                    inds = 1:numel(tfSave);
                    obj.hSI.hChannels.channelSave = inds(tfSave);
                case 2
                    tfDisp = [obj.hTable.Data{:,2}];
                    inds = 1:numel(tfDisp);
                    obj.hSI.hChannels.channelDisplay = inds(tfDisp);
                case 3
                    obj.hSI.hChannels.channelInputRange{chanIdx} = str2num(evt.NewData);
                case 4
                    obj.hSI.hChannels.channelOffset(chanIdx) = evt.NewData;
                case 5
                    obj.hSI.hChannels.channelSubtractOffset(chanIdx) = logical(evt.NewData);
                case 6
                    obj.hSI.hChannels.channelMergeColor{chanIdx} = lower(evt.NewData);
                case 7 % colormap
                    if most.idioms.isValidObj(obj.hCIH)
                        obj.hCIH.applyTableColorMapsToImageFigs();
                    end
            end
        end
        
        function setColormapEditability(obj,ce)
            obj.cmEditable = ce;
            obj.hTable.ColumnEditable(4 + obj.settingsAreSimple*3) = ce;
        end
        
        function setColormaps(obj,v)
            obj.clrmaps = v;
            n = min(numel(v),size(obj.hTable.Data,1));
            obj.hTable.Data(1:n,4 + obj.settingsAreSimple*3) = v(1:n);
        end
        
        function v = getColormaps(obj)
            v = obj.hTable.Data(:,4 + obj.settingsAreSimple*3);
        end
    end

    %% MORE STUFF
    methods
        function v = get.areSettingsSimple(obj)
            v = ~isa(obj.hSI.hScan2D, 'scanimage.components.scan2d.RggScan');
            if ~v
                sArray = obj.hSI.hScan2D.virtualChannelSettings;
                Nv = numel(sArray);
                v = Nv == obj.hSI.hScan2D.hAcq.hFpga.hAfe.physicalChannelCount;
                v = v && all(arrayfun(@(s,idx)strcmp(sprintf('AI%d',idx-1),s.source),sArray,1:Nv));
            end
        end
        
        function v = get.nRows(obj)
            v = numel(obj.hTable.RowName);
        end
        
        function set.hSI(obj,v)
            obj.hSI = v;
            
            obj.listners = most.ErrorHandler.addCatchingListener(obj.hTable, 'ObjectBeingDestroyed', @(varargin)delete(obj));
            obj.listners(end+1) = most.ErrorHandler.addCatchingListener(obj.hSI.hChannels, 'channelSave', 'PostSet', @obj.updateFullData);
            obj.listners(end+1) = most.ErrorHandler.addCatchingListener(obj.hSI.hChannels, 'channelDisplay', 'PostSet', @obj.updateFullData);
            obj.listners(end+1) = most.ErrorHandler.addCatchingListener(obj.hSI.hChannels, 'channelMergeColor', 'PostSet', @obj.updateFullData);
            obj.listners(end+1) = most.ErrorHandler.addCatchingListener(obj.hSI.hChannels, 'channelInputRange', 'PostSet', @obj.updateFullData);
            obj.listners(end+1) = most.ErrorHandler.addCatchingListener(obj.hSI.hChannels, 'channelOffset', 'PostSet', @obj.updateFullData);
            obj.listners(end+1) = most.ErrorHandler.addCatchingListener(obj.hSI.hChannels, 'channelSubtractOffset', 'PostSet', @obj.updateFullData);
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
