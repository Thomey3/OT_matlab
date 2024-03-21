classdef dbgPlot < handle
    % use to plot change of variables in functions over time
    % MEANT FOR DEBUGGING ONLY! DO NOT USE FOR PRODUCTION PLOTTING
    %
    % usage: most.util.dbgPlot(@plot,rand(512,1));  
    %        most.util.dbgPlot(@imagesc,rand(512,512));  
    
    properties (Access = private)
        hFig
        hAx
        stack
        type
        fcnhdl
        fcnhdl_str
    end
    
    methods
        function obj = dbgPlot(fcnhdl,varargin)
            obj.fcnhdl = fcnhdl;
            obj.fcnhdl_str = func2str(fcnhdl);
            obj.stack = dbstack(2);
            if ~isempty(obj.stack)
                obj.stack = obj.stack(2);
            end
            
            [matched,obj] = matchFromRegistry(obj);
            
            if ~matched
               obj.init(); 
            end
            
            obj.fcnhdl(obj.hAx,varargin{:});
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hFig);
        end
    end
    
    methods
        function init(obj)
            if ~isempty(obj.stack)
                name = obj.stack.name;
            else
                name = 'Command Window';
            end
            
            obj.hFig = most.idioms.figure('NumberTitle','off','Name',name,'CloseRequestFcn',@(varargin)obj.delete());
            obj.hAx = most.idioms.axes('Parent',obj.hFig);
        end
    end
end

function [matched,obj] = matchFromRegistry(obj)
    persistent registry
    
    if isempty(registry)
        fcnhdl = str2func(['@(varargin)' mfilename('class') '.empty(0,1)']);
        registry = fcnhdl();
    end
    
    % garbage collection
    notvalidmask = ~isvalid(registry);
    if any(notvalidmask)
        registry(notvalidmask) = [];
    end

    stack_mask = arrayfun(@(o)isequal(o.stack,obj.stack),registry);
    func_mask  = strcmpi({registry.fcnhdl_str},obj.fcnhdl_str);

    mask = stack_mask & func_mask;
    if any(mask)
        assert(sum(mask)<2,'Multiple entries found');
        obj.delete();
        obj = registry(mask);
        matched = true;
    else
        registry(end+1) = obj;
        matched = false;
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
