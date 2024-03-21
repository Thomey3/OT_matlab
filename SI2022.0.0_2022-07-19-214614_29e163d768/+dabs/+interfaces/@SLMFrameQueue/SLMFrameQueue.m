classdef SLMFrameQueue < handle
    properties (Dependent, SetAccess = private)
        framesWritten
    end
    
    properties (SetAccess = private)
        numBytesPerFrame = 0;
    end

    properties (Dependent, SetAccess = private)
        queueLength;
        running;
    end
    
    properties (Access = private)
        hFrameQueue;
    end
    
    methods
        function obj = SLMFrameQueue(slmDeviceHandle,numBytesPerFrame)
            assert(isa(slmDeviceHandle,'uint64'),'Expect slmDeviceHandle to be of type uint64');
            obj.hFrameQueue = SlmFrameQueue('make',slmDeviceHandle);
            obj.numBytesPerFrame = numBytesPerFrame;
        end
        
        function delete(obj)
            if obj.running
                obj.abort();
            end
            SlmFrameQueue('delete',obj.hFrameQueue);
        end
    end
    
    methods        
        function start(obj)
            assert(obj.queueLength>0, 'Frame queue is empty');
            assert(~obj.running,'Frame queue is already running');
            SlmFrameQueue('start',obj.hFrameQueue);
        end
        
        function abort(obj)
            SlmFrameQueue('abort',obj.hFrameQueue);
        end
        
        function write(obj,frames,frameOutputIdxs)
            nFrames = size(frames,3);

            if nargin<3 || isempty(frameOutputIdxs)
                frameOutputIdxs = 1:nFrames;
            end

            validateattributes(frameOutputIdxs,{'numeric'},{'integer','vector','>=',1,'<=',nFrames});
            validateattributes(frames,{'uint8' 'uint16' 'uint32' 'uint64' 'int8' 'int16' 'int32' 'int64'},{'nonempty'});
            frames = frames(:);
            frames = typecast(frames,'uint8');
            assert(numel(frames) == nFrames * obj.numBytesPerFrame,'Data size mismatch');
            frameSizeBytes = uint64(obj.numBytesPerFrame);
            frameOutputIdxs = uint64(frameOutputIdxs) - 1; % convert to zero based indexing for C
            SlmFrameQueue('write',obj.hFrameQueue,frames,frameSizeBytes,frameOutputIdxs);
        end
    end
    
    methods (Access = private)
        function [running,queueLength,framesWritten] = getStatus(obj)
            [running,queueLength,framesWritten] = SlmFrameQueue('getStatus',obj.hFrameQueue);
        end
    end
    
    %% Property Getter/Setter
    methods
        function val = get.running(obj)
            [val,~,~] = obj.getStatus();
        end
        
        function val = get.queueLength(obj)
            [~,val,~] = obj.getStatus();
        end
        
        function val = get.framesWritten(obj)
            [~,~,val] = obj.getStatus();
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
