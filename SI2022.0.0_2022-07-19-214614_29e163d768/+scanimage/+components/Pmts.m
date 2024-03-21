classdef Pmts < scanimage.interfaces.Component
    % Module handling all functionality associated with remote controllable PMT power supplies and amplifiers.
    
    %% USER PROPS
    properties (SetObservable,Transient,SetAccess = private)
        names;          % [string] Cell array of strings containing display names for all PMT channels
    end
    
    % Non-dependent properties are saved to config file
    properties (SetObservable)
        gains;          % [numeric] 1xN array containing power supply gain setting for each PMT
        offsets;        % [numeric] 1xN array containing signal offset setting for each PMT
        bandwidths;     % [numeric] 1xN array containing amplifier bandwidth setting for each PMT
        
        autoPower;      % [logical] 1xN array indicating which pmts to automatically enable/disable when acquisition starts/ends
        autoPowerOnWaitTime_s = 0.3; % wait time in seconds to give PMTs time to power up
    end
    
    properties (SetObservable,Transient,Dependent)
        powersOn;       % [logical] 1xN array containing indicating power state for each PMT
        tripped;        % [logical] 1xN array containing indicating trip status for each PMT
    end
    
    properties (Dependent,SetAccess=private,Transient)
        hPMTs;
    end
    
    properties (Hidden,SetAccess = private)
        lastAutoPowerOn = uint64(0);
    end
    
    %% INTERNAL PROPS
    
    %%% ABSTRACT PROPERTY REALIZATION (most.Model)
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = ziniInitPropAttributes();
        mdlHeaderExcludeProps = {'hPMTs'};                            
    end
    
    %%% ABSTRACT PROPERTY REALIZATION (scanimage.interfaces.Component)
    properties (SetAccess = protected, Hidden)
        numInstances = 0;
    end
    
    properties (Constant, Hidden)
        COMPONENT_NAME = 'PMTs';                                            % [char array] short name describing functionality of component e.g. 'Beams' or 'FastZ'
        PROP_TRUE_LIVE_UPDATE = {};                                         % Cell array of strings specifying properties that can be set while the component is active
        PROP_FOCUS_TRUE_LIVE_UPDATE = {};                                   % Cell array of strings specifying properties that can be set while focusing
        DENY_PROP_LIVE_UPDATE = {};                                         % Cell array of strings specifying properties for which a live update is denied (during acqState = Focus)
        
        FUNC_TRUE_LIVE_EXECUTION = {};                                      % Cell array of strings specifying functions that can be executed while the component is active
        FUNC_FOCUS_TRUE_LIVE_EXECUTION = {};                                % Cell array of strings specifying functions that can be executed while focusing
        DENY_FUNC_LIVE_EXECUTION = {};                                      % Cell array of strings specifying functions for which a live execution is denied (during acqState = Focus)
    end
    
    %% LIFECYCLE
    methods (Access = ?scanimage.SI)
        function obj = Pmts()
            obj@scanimage.interfaces.Component('SI Pmts');
        end
    end
    
    methods
        function reinit(obj)
            obj.numInstances = 1;
        end
        
        function delete(obj)
            %No op
        end
    end
    
    methods
        function waitAutoPowerComplete(obj)
            d = obj.autoPowerOnWaitTime_s - toc(obj.lastAutoPowerOn);
            d = max(d,0);
            pause(d);
        end
    end
    
    
    %% PROP ACCESS
    methods
        function val = get.hPMTs(obj)
            val = obj.hResourceStore.filterByClass('dabs.resources.devices.PMT');
        end
        
        function val = get.names(obj)
            val = cellfun(@(hPMT)hPMT.name,obj.hPMTs,'UniformOutput',false);
        end
        
        function set.autoPower(obj,val)
            %Validation
            validateattributes(val,{'numeric','logical'},{'size',size(obj.hPMTs),'binary'});
            for idx = 1:numel(obj.hPMTs)
                try
                    obj.hPMTs{idx}.autoOn = val(idx);
                catch ME
                    if obj.mdlInitialized || isempty(obj.hPMTs{idx}.errorMsg)
                        most.ErrorHandler.logAndReportError(ME);
                    end
                end
            end
        end
        
        function val = get.autoPower(obj)
            val = cellfun(@(hPMT)hPMT.autoOn,obj.hPMTs);
        end
        
        function set.autoPowerOnWaitTime_s(obj,val)
            validateattributes(val,{'numeric'},{'scalar','nonnegative','real','finite'});
            obj.autoPowerOnWaitTime_s = val;
        end
        
        function set.powersOn(obj,val)
            %Validation
            validateattributes(val,{'numeric','logical'},{'size',size(obj.hPMTs),'binary'});
            for idx = 1:numel(obj.hPMTs)
                try
                    obj.hPMTs{idx}.setPower(val(idx));
                catch ME
                    if obj.mdlInitialized || isempty(obj.hPMTs{idx}.errorMsg)
                        most.ErrorHandler.logAndReportError(ME);
                    end
                end
            end
        end
        
        function val = get.powersOn(obj)
            val = cellfun(@(hPMT)hPMT.powerOn,obj.hPMTs);
        end
        
        function set.gains(obj,val)
            %Validation
            validateattributes(val,{'numeric'},{'size',size(obj.hPMTs),'finite'});
            for idx = 1:numel(obj.hPMTs)
                try
                    obj.hPMTs{idx}.setGain(val(idx));
                catch ME
                    if obj.mdlInitialized || isempty(obj.hPMTs{idx}.errorMsg)
                        most.ErrorHandler.logAndReportError(ME);
                    end
                end
            end
        end
        
        function val = get.gains(obj)
            val = cellfun(@(hPMT)hPMT.gain_V,obj.hPMTs);
        end
        
        function set.offsets(obj,val)
            %Validation
            validateattributes(val,{'numeric'},{'size',size(obj.hPMTs),'finite'});
            for idx = 1:numel(obj.hPMTs)
                try
                    obj.hPMTs{idx}.setGainOffset(val(idx));
                catch ME
                    if obj.mdlInitialized || isempty(obj.hPMTs{idx}.errorMsg)
                        most.ErrorHandler.logAndReportError(ME);
                    end
                end
            end
        end
        
        function val = get.offsets(obj)
            val = cellfun(@(hPMT)hPMT.gainOffset_V,obj.hPMTs);
        end
        
        function set.bandwidths(obj,val)
            %Validation
            validateattributes(val,{'numeric'},{'size',size(obj.hPMTs),'finite','nonnegative'});
            for idx = 1:numel(obj.hPMTs)
                try
                    obj.hPMTs{idx}.setBandwidth(val(idx));
                catch ME
                    if obj.mdlInitialized || isempty(obj.hPMTs{idx}.errorMsg)
                        most.ErrorHandler.logAndReportError(ME);
                    end
                end
            end
        end
        
        function val = get.bandwidths(obj)
            val = cellfun(@(hPMT)hPMT.bandwidth_Hz,obj.hPMTs);
        end
        
        function val = get.tripped(obj)
            val = cellfun(@(hPMT)hPMT.tripped,obj.hPMTs);
        end
    end    
    
    %% INTERNAL METHODS
    %%% Abstract method implementation (scanimage.interfaces.Component)
    methods (Access = protected, Hidden)
        function componentStart(obj)
            obj.lastAutoPowerOn = uint64(0);
            
            for idx = 1:numel(obj.hPMTs)
                try
                    hPMT = obj.hPMTs{idx};
                    if hPMT.autoOn
                        hPMT.setPower(true);
                        obj.lastAutoPowerOn = tic();
                    end
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
            end
        end
        
        function componentAbort(obj)
            for idx = 1:numel(obj.hPMTs)
                try
                    hPMT = obj.hPMTs{idx};
                    if hPMT.autoOn
                        hPMT.setPower(false);
                    end
                    
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
            end
        end
    end
end

%% LOCAL
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
