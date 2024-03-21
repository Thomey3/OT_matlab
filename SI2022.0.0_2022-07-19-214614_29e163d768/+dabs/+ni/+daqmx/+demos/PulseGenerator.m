classdef PulseGenerator
    %PULSEGENERATOR Summary of this class goes here
    
    properties
        deviceName=''; %DAQmx device name, as set/seen in MAX tool, e.g. 'Dev1'
        lineNumber=0;  %Digital Output line number on which pulses will be generated        
        portNumber=0;  %Digital Output port number on which the line to generate output pulses on resides
        restingState=0; %Logical level at which     
        pulseWidth = 0; %Time in seconds to dwell at non-resting state before returning to rest. If 0, shortest possible pulse duration used.
    end
    
    properties (Hidden)
        hTask;
        timeout = 0.2;
    end
    
    properties (Access=private,Dependent)
        outputPattern;        
    end
    
    methods
        
        %% CONSTRUCTOR/DESTRUCTOR
        function obj = PulseGenerator(deviceName,lineNumber,varargin)
            import dabs.ni.daqmx.*
                        
            %Parse required/suggested input arguments
            obj.deviceName = deviceName;
            if nargin >=2 && ~isempty(lineNumber)
                obj.lineNumber = lineNumber;                
            end
            
            %Handle optional arguments
            if ~isempty(varargin)
                for i=1:2:length(varargin)
                    obj.(varargin{i}) = varargin{i+1};
                end
            end
            
            %Create DO Task/Channel & initialize            
            obj.hTask = Task();  
            obj.hTask.createDOChan(obj.deviceName,sprintf('port%d/line%d',obj.portNumber,obj.lineNumber));           
            obj.hTask.writeDigitalData(logical(obj.restingState),obj.timeout,true);            

        end
        
%         function delete(obj)
%             delete(obj.hTask);        
%         end
        
    end
    
    %% PROPERTY ACCESS METHODS
    methods
        function outputPattern = get.outputPattern(obj)
            
            if obj.restingState
                outputPattern = logical([1;0;1]);
            else
                outputPattern = logical([0;1;0]);
            end           
        end
        
    end
    
    
    methods
        function go(obj)
            if obj.pulseWidth == 0
                obj.hTask.writeDigitalData(obj.outputPattern,obj.timeout,true);
            else
                obj.hTask.writeDigitalData(obj.outputPattern(1:2),obj.timeout,true);
                pause(obj.pulseWidth);
                obj.hTask.writeDigitalData(obj.outputPattern(3),obj.timeout,true);
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
