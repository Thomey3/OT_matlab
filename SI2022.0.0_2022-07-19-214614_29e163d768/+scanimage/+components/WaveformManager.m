classdef WaveformManager < scanimage.interfaces.Component
    % WaveformManager     Functionality to manage and optimize output waveforms

    %%% User Props
    properties (SetObservable, SetAccess = protected, Transient)
        scannerAO = struct();   % Struct containing command waveforms for scanners
    end
    
    properties (Dependent, Transient)
        optimizedScanners;      % Cell array of strings, indicating the scanners for which optimized waveforms are available
    end
    
    properties (SetAccess = private, Hidden)
        waveformCacheBasePath;
        hListeners = event.listener.empty();
    end
    
    %%% ABSTRACT PROPERTY REALIZATION (most.Model)
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = ziniInitPropAttributes();
        mdlHeaderExcludeProps = {'scannerAO'};
    end
    
    %%% ABSTRACT PROPERTY REALIZATION (scanimage.interfaces.Component)
    properties (SetAccess = protected, Hidden)
        numInstances = 1;
    end
    
    properties (Constant, Hidden)
        COMPONENT_NAME = 'WaveformManager'                  % [char array] short name describing functionality of component e.g. 'Beams' or 'FastZ'
        PROP_TRUE_LIVE_UPDATE = {};                         % Cell array of strings specifying properties that can be set while the component is active
        PROP_FOCUS_TRUE_LIVE_UPDATE = {} ;                  % Cell array of strings specifying properties that can be set while focusing
        DENY_PROP_LIVE_UPDATE = {};                         % Cell array of strings specifying properties for which a live update is denied (during acqState = Focus)
        
        FUNC_TRUE_LIVE_EXECUTION = {};                      % Cell array of strings specifying functions that can be executed while the component is active
        FUNC_FOCUS_TRUE_LIVE_EXECUTION = {};                % Cell array of strings specifying functions that can be executed while focusing
        DENY_FUNC_LIVE_EXECUTION = {'calibrateScanner','clearCachedWaveform','optimizeWaveforms','clearCache'};                      % Cell array of strings specifying functions for which a live execution is denied (during acqState = Focus)
    end
    
    %% LIFECYCLE
    methods (Access = ?scanimage.SI)
        function obj = WaveformManager()
            obj@scanimage.interfaces.Component('SI WaveformManager');
        end
    end

    methods        
        function reinit(obj)
            obj.waveformCacheBasePath = fullfile(obj.hSI.classDataDir, sprintf('Waveforms_Cache'));
            
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResourceStore,'hResources','PostSet',@(varargin)obj.updateWaveformCacheBasePath);
            obj.updateWaveformCacheBasePath();
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hListeners);
        end
    end
    
    %% INTERNAL METHODS
    methods (Access = protected, Hidden)
        function componentStart(obj)
        end
        
        function componentAbort(obj)
        end
    end
    
        
    %% Getter/Setter Methods
    methods
        function val = get.scannerAO(obj)
            obj.scannerAO = obj.updateWaveformsMotionCorrection(obj.scannerAO);
            val = obj.scannerAO;
        end
        
        function val = get.optimizedScanners(obj)
            val = {};
            if isfield(obj.scannerAO,'ao_volts') && isfield(obj.scannerAO.ao_volts,'isOptimized')
                fieldnames_ = fieldnames(obj.scannerAO.ao_volts.isOptimized);
                tf = cellfun(@(fn)obj.scannerAO.ao_volts.isOptimized.(fn),fieldnames_);
                val = fieldnames_(tf);
            end
        end
    end
    
    %% USER METHODS
    methods
        function updateWaveformCacheBasePath(obj)
            hLinearScanners = obj.hResourceStore.filterByClass('dabs.resources.devices.LinearScanner');
            
            for idx = 1:numel(hLinearScanners)
                hLinearScanners{idx}.waveformCacheBasePath = obj.waveformCacheBasePath;
            end
        end
        
        function updateWaveforms(obj,forceOptimizationCheck)
            % function to regenerate command waveforms for scanner control
            % automatically checks waveform cache for optimized waveforms
            % waveforms are stored in hSI.hWaveformManger.scannerAO
            %
            % usage:
            %     hSI.hWaveformManager.updateWaveforms()
            %     hSI.hWaveformManager.updateWaveforms(true)  % checks waveform cache even if command waveform has not changed since last call
            obj.hSI.hStackManager.updateZSeries();
            
            if nargin < 2 || isempty(forceOptimizationCheck)
                forceOptimizationCheck = false;
            end
            
            % generate planes to scan based on motor position etc
            rg = obj.hSI.hScan2D.currentRoiGroup;
            ss = obj.hSI.hScan2D.scannerset;
            sliceScanTime = [];
            if obj.hSI.hStackManager.isFastZ
                zs = obj.hSI.hStackManager.zs;
                zsRelative = obj.hSI.hStackManager.zsRelative;
                flybackFrames = obj.hSI.hFastZ.numDiscardFlybackFrames;
                waveform = obj.hSI.hFastZ.waveformType;
                zActuator = 'fast';
            elseif obj.hSI.hStackManager.isSlowZ
                currentSlc = obj.hSI.hStackManager.slicesDone*obj.hSI.hStackManager.framesPerSlice + obj.hSI.hStackManager.framesDone;
                nextSlc = currentSlc + 1;
                nextSlc = mod(nextSlc-1,numel(obj.hSI.hStackManager.zs))+1;
                zs = obj.hSI.hStackManager.zs(nextSlc);
                zsRelative = obj.hSI.hStackManager.zsRelative(nextSlc,:);
                flybackFrames = 0;
                
                waveform = 'slow';
                switch obj.hSI.hStackManager.stackActuator
                    case scanimage.types.StackActuator.fastZ
                        zActuator = 'fast';
                    case scanimage.types.StackActuator.motor
                        zActuator = 'slow';
                    otherwise
                        error('Unknown z actuator: %s',obj.hSI.hStackManager.stackActuator);
                end
                if nextSlc == 1
                    sliceScanTime = max(arrayfun(@(z)rg.sliceTime(ss,z),obj.hSI.hStackManager.zs));
                else
                    sliceScanTime =  obj.scannerAO.sliceScanTime;
                end
            else
                zs = obj.hSI.hStackManager.zs;
                zsRelative = obj.hSI.hStackManager.zsRelative;
                
                flybackFrames = 0;
                waveform = '';
                zActuator = '';
            end
            
            % generate ao using scannerset
            [ao_volts_raw, ao_samplesPerTrigger, sliceScanTime, pathFOV] = ...
                rg.scanStackAO(ss,zs,zsRelative,waveform,flybackFrames,zActuator,sliceScanTime,[]);

            sampleRates = struct();
            
            if isfield(ao_volts_raw,'G')
                assert(size(ao_volts_raw(1).G,1) > 0, 'Generated AO is empty. Ensure that there are active ROIs with scanfields that exist in the current Z series.');
                switch class(ss)
                    case 'scanimage.mroi.scannerset.ResonantGalvoGalvo'
                        sampleRates.G = ss.scanners{3}.sampleRateHz;
                    case 'scanimage.mroi.scannerset.GalvoGalvo'
                        sampleRates.G = ss.scanners{1}.sampleRateHz;
                    otherwise
                        error('Unknown scannerset class: ''%s''',class(ss));
                end
            end

            if isfield(ao_volts_raw,'B')
                sampleRates.B = ss.beams(1).sampleRateHz;
            end

            if isfield(ao_volts_raw,'Z')
                sampleRates.Z = ss.fastz(1).sampleRateHz;
            end
            
            if ~forceOptimizationCheck && ...
               isfield(obj.scannerAO,'ao_volts_raw') && isequal(obj.scannerAO.ao_volts_raw,ao_volts_raw) && ...
               isfield(obj.scannerAO,'ao_samplesPerTrigger') && isequal(obj.scannerAO.ao_samplesPerTrigger,ao_samplesPerTrigger) && ...
               isfield(obj.scannerAO,'sliceScanTime') && isequal(obj.scannerAO.sliceScanTime,sliceScanTime) && ...
               isfield(obj.scannerAO,'pathFOV') && isequal(obj.scannerAO.pathFOV,pathFOV) && ...
               isfield(obj.scannerAO,'sampleRate') && isequal(obj.scannerAO.sampleRate,sampleRates)
                % the newly generated AO is the same as the previous one.
                % no further action required
                return
            else
                %%% check for optimized versions of waveform
                allScanners = fieldnames(ao_volts_raw);
                
                % initialize isOptimized struct
                isOptimized = struct();
                for idx = 1:length(allScanners)
                    isOptimized.(allScanners{idx}) = false;
                end
                
                ao_volts = ao_volts_raw;
                optimizableScanners = intersect(allScanners,ss.optimizableScanners);
                for idx = 1:length(optimizableScanners)
                    scanner = optimizableScanners{idx};
                    waveform = ss.retrieveOptimizedAO(scanner,ao_volts_raw.(scanner));
                    if ~isempty(waveform)
                        ao_volts.(scanner) = waveform;
                        isOptimized.(scanner) = true;
                    end
                end
            end
            
            scannerAO_ = struct();
            scannerAO_.ao_volts_raw         = ao_volts_raw;
            scannerAO_.ao_volts             = ao_volts;
            scannerAO_.ao_volts.isOptimized = isOptimized;
            scannerAO_.ao_samplesPerTrigger = ao_samplesPerTrigger;
            scannerAO_.sliceScanTime        = sliceScanTime;
            scannerAO_.pathFOV              = pathFOV;
            scannerAO_.sampleRates           = sampleRates;
            
            obj.scannerAO = scannerAO_;
        end
        
        function scannerAO = updateWaveformsMotionCorrection(obj,scannerAO)
            if isempty(scannerAO)
                return
            end
            
            if isempty(obj.hSI.hMotionManager.scannerOffsets)
                scannerAO = obj.clearWaveformsMotionCorrection(scannerAO);
            else
                offsetvolts = obj.hSI.hMotionManager.scannerOffsets.ao_volts;
                scanners = fieldnames(offsetvolts);
                
                for idx = 1:length(scanners)
                    scanner = scanners{idx};
                    if ~isfield(scannerAO.ao_volts,scanner)
                        most.idioms.warn('Scanner ''%s'' waveform could not be updated for motion correction',scanner);
                        continue
                    end
                    
                    if ~isfield(scannerAO,'ao_volts_beforeMotionCorrection') || ...
                       ~isfield(scannerAO.ao_volts_beforeMotionCorrection,scanner)
                        scannerAO.ao_volts_beforeMotionCorrection.(scanner) = scannerAO.ao_volts.(scanner);
                        scannerAO.ao_volts_correction.(scanner) = zeros(1,size(scannerAO.ao_volts.(scanner),2));
                    end
                    if ~isequal(offsetvolts.(scanner),scannerAO.ao_volts_correction.(scanner))
                        scannerAO.ao_volts.(scanner) = bsxfun(@plus,scannerAO.ao_volts_beforeMotionCorrection.(scanner),offsetvolts.(scanner));
                        scannerAO.ao_volts_correction.(scanner) = offsetvolts.(scanner);
                    end
                end
            end            
        end
        
        function scannerAO = clearWaveformsMotionCorrection(obj,scannerAO)
            if isempty(scannerAO)
                return
            end
            
            if isfield(scannerAO,'ao_volts_beforeMotionCorrection')
                scanners = fieldnames(scannerAO.ao_volts_beforeMotionCorrection);
                for idx = 1:length(scanners)
                    scanner = scanners{idx};
                    scannerAO.ao_volts.(scanner) = scannerAO.ao_volts_beforeMotionCorrection.(scanner);
                end
                scannerAO = rmfield(scannerAO,'ao_volts_beforeMotionCorrection');
                scannerAO = rmfield(scannerAO,'ao_volts_correction');
            end
        end
        
        function resetWaveforms(obj)
            % function to clear hSI.hWaveformManager.scannerAO
            %
            % usage:
            %   hSI.hWaveformManager.resetWaveforms()
            obj.scannerAO = [];
        end
        
        function calibrateScanner(obj,scanner)
            % function to calibrate scanner feedback and offset
            %
            % usage:
            %   hSI.hWaveformManager.calibrateScanner('<scannerName>')
            %       where <scannerName> is one of {'G','Z'}
            if obj.componentExecuteFunction('calibrateScanner',scanner)
                msg = 'Calibrating Scanner';
                hWb = waitbar(0,msg,'CreateCancelBtn',@(src,evt)delete(ancestor(src,'figure')));
                hTitle = findall(hWb,'String',msg);
                set(hTitle,'Interpreter','none');
                try
                    ss = obj.hSI.hScan2D.scannerset;    % Used as the base to reference particular scanners.
                    ss.calibrateScanner(scanner,hWb);
                catch ME
                    hWb.delete();
                    rethrow(ME);
                end
                hWb.delete();
            end
        end
        
        % This function does not appear to be used at all - JLF 12/2021
        function plotWaveforms(obj,scanner)
            % function to plot scanner command waveform for specified scanner
            %
            % usage:
            %   hSI.hWaveformManager.plotWaveforms('<scannerName>')
            %       where <scannerName> is one of {'G','Z'}
            
            % ensure waveforms are up to date
            obj.updateWaveforms();
            
            assert(~isempty(obj.scannerAO) && isfield(obj.scannerAO,'ao_volts'),'scannerAO is empty');
            assert(isfield(obj.scannerAO.ao_volts,scanner),'scannerAO is empty');
            
            hFig = most.idioms.figure('NumberTitle','off','Name','Waveform Output');
            if obj.scannerAO.ao_volts.isOptimized.(scanner)
                [optimized,metaData] = obj.retrieveOptimizedAO(scanner);
                desired = obj.scannerAO.ao_volts_raw.(scanner);
                numWaveforms = size(metaData,2);
                
                feedback = zeros(size(desired));
                for idx = 1:numWaveforms
                    if ~isempty(metaData(idx).feedbackWaveformFileName)
                        feedbackWaveformFileName = fullfile(metaData(idx).path,metaData(idx).feedbackWaveformFileName);
                        assert(logical(exist(feedbackWaveformFileName,'file')),'The file %s was not found on disk.',feedbackWaveformFileName);
                        hFile = matfile(feedbackWaveformFileName);
                        feedback(:,idx) = repmat(hFile.volts,metaData(idx).periodCompressionFactor,1);
                    else
                        feedback(:,idx) = 0;
                    end
                end
                
                sampleRateHz = unique([metaData.sampleRateHz]);
                assert(length(sampleRateHz)==1);
                
                tt = (1:size(desired,1))'/sampleRateHz;
                tt = repmat(tt,1,size(desired,2));
                err = feedback - desired;
                
                hAx1 = most.idioms.subplot(4,1,1:3,'Parent',hFig,'NextPlot','add');
                hAx2 = most.idioms.subplot(4,1,  4,'Parent',hFig,'NextPlot','add');
                title(hAx1,'Waveform Output');
                ylabel(hAx1,'Volts');
                xlabel(hAx2,'Time [s]');
                ylabel(hAx2,'Volts');
                set([hAx1,hAx2],'XGrid','on','YGrid','on','Box','on');
                
                linkaxes([hAx1,hAx2],'x');
                set([hAx1,hAx2],'XLim',[tt(1),tt(end)*1.02]);
                
                for idx = 1:numWaveforms
                    scannerName = metaData(idx).linearScannerName;
                    if ~isempty(scannerName)
                        plot(hAx1,tt(:,idx),  desired(:,idx),'--','LineWidth',2,'DisplayName',sprintf('%s desired',scannerName));
                        plot(hAx1,tt(:,idx),optimized(:,idx),'DisplayName',sprintf('%s command',scannerName));
                        plot(hAx1,tt(:,idx), feedback(:,idx),'DisplayName',sprintf('%s feedback',scannerName));
                        
                        plot(hAx2,tt(:,idx),err(:,idx),'DisplayName',sprintf('%s error',scannerName));
                    end
                end
                
                legend(hAx1,'show');
                legend(hAx2,'show');
                
                rms = sqrt(sum(err.^2,1) / size(err,1));
                uimenu('Parent',hFig,'Label','Optimization Info','Callback',@(varargin)showInfo(metaData,rms));
                
            else
                hAx = most.idioms.axes('Parent',hFig,'XGrid','on','YGrid','on','Box','on');
                
                if strcmpi(scanner,'SLMxyz')
                    xy = obj.scannerAO.ao_volts.(scanner);
                    plot(hAx,xy(:,1),xy(:,2),'*-');
                    title(hAx,'SLM Output');
                    hAx.YDir = 'reverse';
                    hAx.DataAspectRatio = [1 1 1];
                    xlabel(hAx,'x');
                    ylabel(hAx,'y');
                    grid(hAx,'on');
                else
                    plot(hAx,obj.scannerAO.ao_volts.(scanner));
                    title(hAx,'Waveform Output');
                    xlabel(hAx,'Samples');
                    ylabel(hAx,'Volts');
                    grid(hAx,'on');
                end
            end
            
            function showInfo(metaData,rms)
                infoTxt = {};
                for i = 1:length(metaData);
                    md = metaData(i);
                    infoTxt{i} = sprintf([...
                        '%s\n'...
                        '    Optimization function: %s\n'...
                        '    Optimization date: %s\n'...
                        '    Sample rate: %.1fkHz\n'...
                        '    Iterations: %d\n'...
                        '    RMS: %fV'
                            ],...
                        md.linearScannerName,regexp(md.optimizationFcn,'[^\.]*$','match','once'),...
                        datestr(md.clock),md.sampleRateHz/1e3,md.info.numIterations,rms(i)...
                        );
                end
                infoTxt = strjoin(infoTxt,'\n\n');
                msgbox(infoTxt,'Optimization Info');
            end
        end
    end
    
    
    methods
        
        function clearCachedWaveform(obj, scanner)
            % function to clear optimized version of current waveform for specified scanner
            %
            % usage:
            %   hSI.hWaveformManager.clearCachedWaveform('<scannerName>')
            %       where <scannerName> is one of {'G','Z'}
            if obj.componentExecuteFunction('clearCachedWaveform',scanner)
                ss = obj.hSI.hScan2D.scannerset;
                obj.updateWaveforms();
                assert(~isempty(obj.scannerAO) && isfield(obj.scannerAO,'ao_volts_raw') && isfield(obj.scannerAO.ao_volts_raw,scanner) && ~isempty(obj.scannerAO.ao_volts_raw.(scanner)))
                ss.ClearCachedWaveform(scanner, obj.scannerAO.ao_volts_raw.(scanner));
                obj.updateWaveforms(true);          % Recreate the waveforms
            end
        end
        
        function clearCache(obj, scanner)
            % function to clear all optimized waveforms for specified scanner
            %
            % usage:
            %   hSI.hWaveformManager.clearCache('<scannerName>')
            %       where <scannerName> is one of {'G','Z'}
            if obj.componentExecuteFunction('clearCache',scanner)
                ss = obj.hSI.hScan2D.scannerset;
                ss.ClearCache(scanner);
                obj.updateWaveforms(true);          % Regenerate waveforms
            end
        end
        
        function optimizeWaveforms(obj,scanner,updateCallback,updateWaveforms)
            if nargin < 3
                updateCallback = [];
            end
            if nargin < 4 || isempty(updateWaveforms) || updateWaveforms
                updateWaveforms = true;
            end
            % function to optimized and cache command waveform for specified scanner
            %
            % usage:
            %   hSI.hWaveformManager.optimizeWaveforms('<scannerName>')
            %       where <scannerName> is one of {'G','Z'}
            if obj.componentExecuteFunction('optimizeWaveforms',scanner)
                if updateWaveforms
                    obj.updateWaveforms();              % Ensure the output waveforms are up to date
                end
                ss = obj.hSI.hScan2D.scannerset;    % Used as the base to reference particular scanners.
                assert(~isempty(obj.scannerAO.ao_volts_raw) && isfield(obj.scannerAO.ao_volts_raw,scanner)&& ~isempty(obj.scannerAO.ao_volts_raw.(scanner)),...
                    'No waveform for scanner %s generated', scanner);
                ss.optimizeAO(scanner, obj.scannerAO.ao_volts_raw.(scanner), updateCallback);
                obj.updateWaveforms(true);          % Recreate the waveforms, force recheck of optimization cache
            end
        end
        
        function [waveform,metaData] = retrieveOptimizedAO(obj, scanner, updateWaveforms)
            % function to retrieve optimized waveform from cache for specified scanner
            %
            % usage:
            %   [waveform,metaData] = hSI.hWaveformManager.retrieveOptimizedAO('<scannerName>')
            %       where <scannerName> is one of {'G','Z'}
            
            if nargin < 3 || isempty(updateWaveforms) || updateWaveforms
                obj.updateWaveforms();
            end
            
            assert(~isempty(obj.scannerAO.ao_volts_raw) && isfield(obj.scannerAO.ao_volts_raw,scanner) && ~isempty(obj.scannerAO.ao_volts_raw.(scanner)))
            
            ss = obj.hSI.hScan2D.scannerset;
            [waveform,metaData] = ss.retrieveOptimizedAO(scanner, obj.scannerAO.ao_volts_raw.(scanner));
        end
        
        
        function feedback = testWaveforms(obj,scanner,updateCallback,updateWaveforms)
            if obj.componentExecuteFunction('optimizeWaveforms',scanner)
                if nargin < 4 || isempty(updateWaveforms) || updateWaveforms
                    obj.updateWaveforms();
                end
                
                ss = obj.hSI.hScan2D.scannerset;    % Used as the base to reference particular scanners.
                
                assert(~isempty(obj.scannerAO.ao_volts_raw) && isfield(obj.scannerAO.ao_volts_raw,scanner)&& ~isempty(obj.scannerAO.ao_volts_raw.(scanner)),...
                    'No waveform for scanner %s generated', scanner);
                
                feedback = ss.testAO(scanner, obj.scannerAO.ao_volts.(scanner), updateCallback);
            end
        end
    end
    
end

%% LOCAL (after classdef)
function s = ziniInitPropAttributes()
s = struct();
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
