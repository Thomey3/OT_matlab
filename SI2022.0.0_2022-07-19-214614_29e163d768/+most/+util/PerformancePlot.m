classdef PerformancePlot < handle
    properties
        averaging = 30;
        changedCallback = function_handle.empty(0,1);
    end
    
    properties (Dependent)
        visible;
    end
    
    properties (Access = private)
        lastTic;
        tHistory;
        hTimePlot;
    end
    
    events
        changed
    end
    
    %% Lifecycle
    methods
        function obj = PerformancePlot(name, visible)
            if nargin < 1 || isempty(name)
                name = 'Performance Plot';
            end
            
            if nargin < 2 || isempty(visible)
                visible = true;
            end
            
            obj.hTimePlot = most.util.TimePlot(name,visible);
            obj.hTimePlot.xLabel = 'Execution #';
            obj.hTimePlot.yLabel = 'Execution time [ms]';
            obj.hTimePlot.changedCallback = @obj.changedCallbackInternal;
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hTimePlot);
        end
    end
    
    %% Public methods
    methods
        function tic(obj)
            if obj.visible
                obj.lastTic = tic();
            end
        end
        
        function toc(obj)
            if obj.visible && ~isempty(obj.lastTic) 
                t = toc(obj.lastTic);
                obj.lastTic = [];
                
                obj.addTimePoint(t);
            end
        end
        
        function reset(obj)
            obj.lastTic = [];
            obj.tHistory = [];
            obj.hTimePlot.reset();
        end
    end
    
    %% Private methods
    methods (Access = private)
        function addTimePoint(obj,t)
            obj.tHistory = append(obj.tHistory,t,obj.averaging);
            obj.hTimePlot.addTimePoint( mean(obj.tHistory) * 1000 ); % plot in milliseconds
        end
    end
    
    methods (Hidden)
        function changedCallbackInternal(obj,varargin)
            obj.notify('changed');
            
            if ~isempty(obj.changedCallback)
                obj.changedCallback(obj,varargin);
            end
        end
    end
    
    %% Property Getter/Setter
    methods
        function set.visible(obj,val)
            obj.hTimePlot.visible = val;
        end
        
        function val = get.visible(obj)
            val = obj.hTimePlot.visible;
        end
        
        function set.changedCallback(obj,val)
            if isempty(val)
                val = function_handle.empty(0,1);
            else
                validateattributes(val,{'function_handle'},{'scalar'});
            end
            
            obj.changedCallback = val; 
        end
    end
end

function vec = append(vec,v,veclength)
    if isempty(vec)
        vec = v;
    elseif numel(vec) < veclength
        vec(end+1) = v;
    else
        vec = vec(end-veclength+1:end);
        vec = circshift(vec,-1);
        vec(end) = v;
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
