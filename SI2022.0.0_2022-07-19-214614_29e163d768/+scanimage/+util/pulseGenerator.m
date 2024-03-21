classdef pulseGenerator < handle
    %LINECLOCKSIM Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        freq = 7910;
        destination = '';
    end
    
    properties (Hidden)
        hTask;
        hRouteRegistry;
    end
    
    properties (Hidden, SetAccess = private)
        dev;
        chan;
    end
    
    methods
        function obj = pulseGenerator(varargin)
            % dev, ctr chan, freq, destination, start
            
            if nargin > 0
                obj.dev = varargin{1};
            else
                obj.dev = 'PXI1Slot3';
            end
            
            if nargin > 1
                obj.chan = varargin{2};
            else
                obj.chan = 2;
            end
            
            if nargin > 2
                obj.freq = varargin{3};
            else
                obj.freq = 7910;
            end
            
            if nargin > 3
                dest = varargin{4};
            else
                dest = '';
            end
            
            if nargin > 4
                strt = varargin{5};
            else
                strt = false;
            end
            
            if nargin > 5
                name = varargin{6};
            else
                name = 'Pulse Generator';
            end
            
            obj.hTask = most.util.safeCreateTask(name);
            obj.hTask.createCOPulseChanFreq(obj.dev, obj.chan, '', obj.freq);
            obj.hTask.cfgImplicitTiming('DAQmx_Val_ContSamps');
            
            obj.hRouteRegistry = dabs.ni.daqmx.util.triggerRouteRegistry;
            
            if ~isempty(dest)
                obj.destination = dest;
            end
            
            if strt
                obj.hTask.start();
            end
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hTask);
            most.idioms.safeDeleteObj(obj.hRouteRegistry);
        end
        
        function start(obj)
            obj.hTask.start();
        end
        
        function stop(obj)
            obj.hTask.abort();
        end
        
        function set.freq(obj,v)
            if most.idioms.isValidObj(obj.hTask)
                set(obj.hTask.channels(1),'pulseFreq',v);
            end
            obj.freq = v;
        end
        
        function set.destination(obj,v)
            if ~isempty(obj.destination)
                obj.hRouteRegistry.disconnectTerms(sprintf('/%s/Ctr%dInternalOutput',obj.dev,obj.chan), obj.destination);
            end
            
            obj.destination = '';
            
            if ~isempty(v)
                obj.hRouteRegistry.connectTerms(sprintf('/%s/Ctr%dInternalOutput',obj.dev,obj.chan), v);
                obj.destination = v;
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
