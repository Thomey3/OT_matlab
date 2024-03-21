classdef Shutters < scanimage.interfaces.Component
% Shutters     Functionality for managing shutters and shutter state transitions.    
    % ABSTRACT PROPERTY REALIZATION (scanimage.interfaces.Component)
    properties (Hidden, SetAccess = protected)
        numInstances = 0;
    end
    
    properties (Constant, Hidden)
        COMPONENT_NAME = 'Shutters';                       % [char array] short name describing functionality of component e.g. 'Beams' or 'FastZ'
        PROP_TRUE_LIVE_UPDATE = {};                        % Cell array of strings specifying properties that can be set while the component is active
        PROP_FOCUS_TRUE_LIVE_UPDATE = {};                  % Cell array of strings specifying properties that can be set while focusing
        DENY_PROP_LIVE_UPDATE = {};                        % Cell array of strings specifying properties for which a live update is denied (during acqState = Focus)
        FUNC_TRUE_LIVE_EXECUTION = {'shuttersTransition'}; % Cell array of strings specifying functions that can be executed while the component is active
        FUNC_FOCUS_TRUE_LIVE_EXECUTION = {};               % Cell array of strings specifying functions that can be executed while focusing
        DENY_FUNC_LIVE_EXECUTION = {};                     % Cell array of strings specifying functions for which a live execution is denied (during acqState = Focus)
    end
    
    % Abstract prop realizations (most.Model)
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = zlclInitPropAttributes();
        mdlHeaderExcludeProps = {'hShutters'};
    end
    
    properties (Dependent,SetAccess=private,Transient)
        hShutters
    end
    
    %% LIFECYCLE
    methods (Access = ?scanimage.SI)
        function obj = Shutters()
            obj@scanimage.interfaces.Component('SI Shutters');
        end

    end

    methods        
        function reinit(obj)
            obj.numInstances = 1;
            obj.shuttersTransitionAll(false);
        end
        
        function delete(obj)
            % Close shutters at deletion
            try
                silent = true;
                obj.shuttersTransitionAll(false,silent);
            catch ME
            end
        end
    end
    
    %% USER METHODS
    methods
        function shuttersTransitionAll(obj,openTF,silent)
            if nargin<3 || isempty(silent)
                silent = false;
            end

            for idx=1:numel(obj.hShutters)
                try
                    if isempty(obj.hShutters{idx}.errorMsg)
                        obj.hShutters{idx}.transition(openTF);
                    end
                catch ME
                    if ~silent
                        most.ErrorHandler.logAndReportError(ME);
                    end
                end
            end
        end
        
        function shuttersTransition(obj,shutterIDs,openTF,applyShutterOpenTime)
            if nargin < 4 || isempty(applyShutterOpenTime)
                applyShutterOpenTime = false;
            end
            
            % Todo: implement applyShutterOpenTime
            
            validateattributes(shutterIDs,{'numeric'},{'integer','positive','vector','<=',numel(obj.hShutters)});
            validateattributes(openTF,{'logical','numeric'},{'binary','scalar'});
            validateattributes(applyShutterOpenTime,{'logical','numeric'},{'binary','scalar'});
            
            for idx = 1:numel(shutterIDs)
                shutterId = shutterIDs(idx);
                hShutter = obj.hShutters{shutterId};
                try
                    hShutter.transition(openTF);
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
            end
        end
    end
    
    %% INTERNAL METHODS
    % Abstract method implementation (scanimage.interfaces.Component)
    methods (Hidden, Access=protected)
        function componentStart(obj)
        %   Runs code that starts with the global acquisition-start command. Note: For this component see shuttersTransition method
            assert(false, 'Shutters nolonger implements start/abort functionality. Use the shutters transition function instead.');
        end
        
        function componentAbort(obj)
        %   Runs code that aborts with the global acquisition-abort command
            obj.shuttersTransitionAll(false); % Close all shutters
        end
    end
    
    methods
        function val = get.hShutters(obj)
            val = obj.hResourceStore.filterByClass('dabs.resources.devices.Shutter');
        end
    end
end

%% LOCAL 
function s = zlclInitPropAttributes()
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
