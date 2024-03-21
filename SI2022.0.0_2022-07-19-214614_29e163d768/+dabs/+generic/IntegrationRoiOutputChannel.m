classdef IntegrationRoiOutputChannel < dabs.resources.Device & dabs.resources.configuration.HasConfigPage & most.HasMachineDataFile
    properties (SetAccess = protected,Hidden)
        ConfigPageClass = 'dabs.resources.configuration.resourcePages.IntegrationRoiOutputChannelPage';
    end
    
    methods (Static)
        function names = getDescriptiveNames()
            names = {'Online Analysis\Integration ROI Output Channel'};
        end
    end
    
        %%% ABSTRACT PROPERTY REALIZATIONS (most.HasMachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'IntegrationRoiOutputChannel';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
        
        mdfDefault = defaultMdfSection();
    end
    
    properties (SetObservable)
        hOutput = dabs.resources.Resource.empty();
        enable = false;
        hIntegrationRois = scanimage.mroi.Roi.empty(1,0);       % array of integration Rois to be used for generating the output
        outputFunction;         % handle to function that generates output from roi integrators
    end
    
    properties (SetObservable, SetAccess = private)
        lastWrittenVal = [];
    end
    
    properties (SetAccess = private)
        outputMode; % digital or analog
        hIntegrationRoisUuiduint64 = uint64([]);
    end
    
    properties (SetAccess = private, GetAccess = private)
        hOutputListeners = event.listener.empty(0,1);
    end
    
    properties (Dependent)
        physicalChannelName
    end
    
    events
        changed;
    end
    
    %% Lifecycle
    methods
        function obj = IntegrationRoiOutputChannel(name)
            obj@dabs.resources.Device(name);
            obj@most.HasMachineDataFile(true);
            
            obj.deinit();
            obj.loadMdf();
            obj.reinit();
        end
        
        function delete(obj)
            obj.deinit();
        end
    end
    
    methods
       function loadMdf(obj)
            success = true;
            success = success & obj.safeSetPropFromMdf('hOutput', 'OutputChannel');
            
            if ~success
                obj.errorMsg = 'Error loading config';
            end
        end
        
        function saveMdf(obj)
            obj.safeWriteVarToHeading('OutputChannel', obj.hOutput);
        end
    end
    
    methods
        function reinit(obj)
            obj.deinit();
            
            try
                if most.idioms.isValidObj(obj.hOutput)
                    if isa(obj.hOutput,'dabs.resources.ios.AO')
                        obj.outputFunction = @(vals,varargin)mean(vals);
                        obj.outputMode = 'analog';
                    else
                        obj.outputMode = 'digital';
                        obj.outputFunction = @(vals,varargin)mean(vals)>100;
                    end
                    obj.hOutputListeners = most.ErrorHandler.addCatchingListener(obj.hOutput,'lastKnownValueChanged',@(varargin)obj.updateLastWrittenVal);
                    obj.hOutput.reserve(obj);
                else
                    obj.outputMode = 'software';
                    obj.outputFunction = @(vals,varargin)fprintf('Mean integration value %f\n',mean(vals));
                end
                
                obj.errorMsg = '';
                obj.resetOutput();
                
            catch ME
                obj.deinit();
                obj.errorMsg = sprintf('%s: initialization error: %s',obj.name,ME.message);
                most.ErrorHandler.logError(ME,obj.errorMsg);
            end
            
        end
        
        function deinit(obj)
            try
                obj.resetOutput()
            catch
            end
            
            if most.idioms.isValidObj(obj.hOutput)
                if isa(obj.hOutput,'dabs.resources.ios.D')
                    try
                        obj.hOutput.tristate();
                    catch ME
                        most.ErrorHandler.logAndReportError(ME);
                    end
                end
                
                obj.hOutput.unreserve(obj);
            end
            
            delete(obj.hOutputListeners);
            obj.hOutputListeners = event.listener.empty(0,1);
            
            obj.errorMsg = 'uninitialized';            
        end
    end
    
    %% User Functions
    methods        
        function start(obj)
            % No-op
        end
        
        function abort(obj)
            obj.resetOutput();
        end
        
        function updateOutput(obj,integrationRois,integrationDone,integrationValuesHistory,timestampHistory,arrayIdxs)
            if ~obj.enable || isempty(obj.hIntegrationRois) || ~isempty(obj.errorMsg)
                return
            end
            
            uuiduint64s = [integrationRois.uuiduint64];
            if ~issorted(uuiduint64s) % should be pre-sorted already, but just to make sure
                [uuiduint64s,sortIdxs] = sort(uuiduint64s);
                idxs = ismembc2(obj.hIntegrationRoisUuiduint64,uuiduint64s);
                idxs = sortIdxs(idxs);
            else
                idxs = ismembc2(obj.hIntegrationRoisUuiduint64,uuiduint64s);
            end
            
            if any(idxs<=0)
                most.idioms.warn('Not all IntegrationRois found need for output');
            end
            integrationDone = integrationDone(idxs);
            
            if any(integrationDone)
                arrayIdxs = arrayIdxs(idxs);
                values = integrationValuesHistory(arrayIdxs);
                timestamps = timestampHistory(arrayIdxs);                
                try
                    newVal = obj.outputFunction(values,timestamps,obj.hIntegrationRois,integrationValuesHistory,timestampHistory,idxs);
                    obj.writeOutputValue(newVal);
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
            end
        end
        
        function deleteOutdatedRois(obj,roiGroup)
            [~,idx] = setdiff(obj.hIntegrationRois,roiGroup.rois);
            obj.hIntegrationRois(idx) = []; %remove non-existing rois            
        end
        
        function resetOutput(obj)
            obj.writeOutputValue(0,true);
        end
        
        function writeOutputValue(obj,val,force)
            if nargin < 3 || isempty(force)
                force = false;
            end
            
            if isempty(val) || ~(isnumeric(val)||islogical(val)) || isnan(val(1))
                return
            end
            
            val = val(1); % in case the output is a matrix
            
            if isequal(obj.lastWrittenVal,val) && ~force
                return
            end            
                
            switch obj.outputMode
                case 'analog'
                    val = min(max(val,-10),10); % coerce to output range
                    obj.hOutput.setValue(val);
                case 'digital'
                    val = logical(val);
                    obj.hOutput.setValue(val);
                case 'software'
                    obj.lastWrittenVal = val;
                otherwise
                    assert(false);
            end
        end
    end
    
    methods (Hidden)
        function updateLastWrittenVal(obj)
            obj.lastWrittenVal = obj.hOutput.lastKnownValue;
        end        
    end
    
    
    %% Property setter/getter
    methods        
        function set.outputMode(obj,val)
            val = lower(val);
            assert(ismember(val,{'analog','digital','software'}));
            obj.outputMode = val;
        end
        
        function set.enable(obj,val)
            obj.enable = val;
            notify(obj,'changed');
        end
        
        function set.outputFunction(obj,val)
            if isempty(val)
                val = @(varargin)0;
            elseif ischar(val)
                val = str2func(val);
            else
                assert(isa(val,'function_handle'),'The property ''outputFunction'' needs to be a string or a function handle');
            end
            
            validateattributes(val,{'function_handle'},{'scalar'});
            obj.outputFunction = val;
            notify(obj,'changed');
        end
        
        function set.hIntegrationRois(obj,val)
            if isempty(val)
                val = scanimage.mroi.Roi.empty(1,0);
            end
            validateattributes(val,{'scanimage.mroi.Roi'},{});
            obj.hIntegrationRois = val;
            obj.hIntegrationRoisUuiduint64 = uint64([obj.hIntegrationRois.uuiduint64]); % pre cache for performance
            notify(obj,'changed');
        end
        
        function val = get.physicalChannelName(obj)
            if most.idioms.isValidObj(obj.hOutput)
                val = obj.hOutput.name;
            else
                val = 'software';
            end
        end
        
        function set.hOutput(obj,val)
            val = obj.hResourceStore.filterByName(val);
            
            if ~isequal(val,obj.hOutput)
                if most.idioms.isValidObj(val)
                    validateattributes(val,{'dabs.resources.ios.AO','dabs.resources.ios.DO','dabs.resources.ios.PFI'},{'scalar'});
                end
                
                obj.deinit();
                obj.hOutput.unregisterUser(obj);
                obj.hOutput = val;
                obj.hOutput.registerUser(obj,'Control');
            end
        end
    end
end

function s = defaultMdfSection()
s = [...
    most.HasMachineDataFile.makeEntry('OutputChannel' ,'','output channel for the integration roi (leave empty for software output)  e.g. ''/vDAQ0/AO0''')...
    ];
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
