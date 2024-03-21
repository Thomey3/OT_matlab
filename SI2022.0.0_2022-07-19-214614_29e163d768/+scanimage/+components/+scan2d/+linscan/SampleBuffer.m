classdef SampleBuffer < handle
    properties (SetAccess = private)
        startSample = 0;
        endSample = 0;
        bufferSize = 0;
        numChannels = 0;
        buffer;
    end
    
    methods
        function obj = SampleBuffer(varargin)
            if nargin
                obj.initialize(varargin{:});
            end
        end
        
        function delete(~)
        end
        
        function initialize(obj,numSamples,numChannels,datatype)
            obj.buffer = zeros(numSamples,numChannels,datatype);
            obj.bufferSize = numSamples;
            obj.numChannels = numChannels;
            obj.startSample = 0;
            obj.endSample = 0;
        end
        
        function appendData(obj,data)
            [newDataSize,numChs] = size(data);
            assert(newDataSize <= obj.bufferSize && numChs == obj.numChannels);
            
            if obj.endSample == 0
                obj.endSample = newDataSize;
            else
                obj.endSample = mod(obj.endSample+newDataSize-1,obj.bufferSize)+1;
            end
            
            if obj.startSample == 0
                obj.startSample = 1;
            else
                obj.startSample = mod(obj.startSample+newDataSize-1,obj.bufferSize)+1;
            end
            
            assert(obj.startSample <= obj.endSample && obj.endSample <= obj.bufferSize); % sanity check
            
            if newDataSize == obj.bufferSize
                obj.buffer = data; % performance tweak for non-striping display: avoid memory copy
            else
                obj.buffer(obj.startSample:obj.endSample,:) = data;
            end
            
        end
        
        function [data,startSample,endSample] = getData(obj)
            data = obj.buffer;
            [startSample,endSample] = obj.getPositionInFrame();
        end
        
        function [startSample,endSample] = getPositionInFrame(obj)
            startSample = obj.startSample;
            endSample = obj.endSample;
        end
        
        function reset(obj)
            obj.endSample = 0;
            obj.startSample = 0;
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
