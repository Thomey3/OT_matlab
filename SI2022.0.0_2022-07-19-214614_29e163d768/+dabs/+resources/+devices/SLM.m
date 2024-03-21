classdef SLM < dabs.resources.Device & dabs.resources.widget.HasWidget
    properties (Abstract, Constant)
        queueAvailable;
    end
    
    properties (SetAccess = protected)
        WidgetClass = 'dabs.resources.widget.widgets.SLMWidget';
    end
    
    properties (SetObservable)
        maxRefreshRate = Inf;              % [Hz], numeric
        pixelResolutionXY = [512,512];     % [1x2 numeric] pixel resolution of SLM
        pixelPitchXY      = [  1,  1]*1e-6;    % [1x2 numeric] distance from pixel center to pixel center in meter
        interPixelGapXY   = [ 10, 10]*1e-6;    % [1x2 numeric] pixel spacing in x and y in meter
    end
    
    properties (SetObservable, SetAccess = protected)
        pixelBitDepth = 8;                 % numeric, one of {8,16,32,64} corresponds to uint8, uint16, uint32, uint64 data type
        computeTransposedPhaseMask = true;
        lastKnownBitmap = [];
    end
    
    methods (Abstract, Access = protected)
        writeSlmQueue(obj,frames,frameOutputIdxs);
        startSlmQueue(obj);
        abortSlmQueue(obj);
    end
    
    properties (SetObservable, SetAccess = private)
        queueStarted = false;
    end
    
    properties (Dependent, SetAccess = private)
        pixelDataType;
        pixelPitchXY_um;
        interPixelGapXY_um;
    end
    
    methods (Abstract)
        writeBitmap(obj,phaseMaskRaw,waitForTrigger)
    end
    
    methods
        function obj = SLM(name)
            obj@dabs.resources.Device(name);
        end
        function delete(obj)
            if obj.queueStarted
                try
                    obj.abortQueue();
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
            end
        end
    end
    
    methods
        function val = get.pixelPitchXY_um(obj)
            val = obj.pixelPitchXY * 1e6;
        end
        
        function val = get.interPixelGapXY_um(obj)
            val = obj.interPixelGapXY * 1e6;
        end        
        
        function val = get.pixelDataType(obj)
            switch obj.pixelBitDepth
                case 8
                    val = 'uint8';
                case 16
                    val = 'uint16';
                case 32
                    val = 'uint32';
                case 64
                    val = 'uint64';
                otherwise
                    error('Unknown datatype of length %d',obj.pixelBitDepth);
            end
        end
    end
    
    %% User methods
    methods
        function reset(obj)
            obj.assertNoError();
            image = zeros(obj.pixelResolutionXY,obj.pixelDataType);
            if ~obj.computeTransposedPhaseMask
                image = image';
            end
            obj.writeBitmap(image);
        end
        
        function writeQueue(obj,frames,frameOutputIdxs)
            if nargin<3 || isempty(frameOutputIdxs)
                frameOutputIdxs = 1:size(frames,3);
            end
            
            assert(obj.queueAvailable,'Queue is not available for SLM');
            if obj.computeTransposedPhaseMask
                assert(size(frames,2)==obj.pixelResolutionXY(2) && size(frames,1) == obj.pixelResolutionXY(1),'Incorrect frame pixel resolution');
            else
                assert(size(frames,2)==obj.pixelResolutionXY(1) && size(frames,1) == obj.pixelResolutionXY(2),'Incorrect frame pixel resolution');
            end
            frames = cast(frames,obj.pixelDataType);
            
            obj.writeSlmQueue(frames,frameOutputIdxs);
        end
        
        function startQueue(obj)
            assert(obj.queueAvailable,'Queue is not available for SLM');
            obj.startSlmQueue();
            obj.queueStarted = true;
        end
        
        function abortQueue(obj)
            assert(obj.queueAvailable,'Queue is not available for SLM');
            obj.queueStarted = false;
            obj.abortSlmQueue();
        end
    end
    
    methods         
         function set.maxRefreshRate(obj,val)
            validateattributes(val,{'numeric'},{'positive','nonnan','scalar','real'});
            obj.maxRefreshRate = val;
         end
         
         function set.pixelResolutionXY(obj,val)
             validateattributes(val,{'numeric'},{'positive','integer','numel',2,'nonnan','finite','real'});
             obj.pixelResolutionXY = val;
             obj.deinit();
         end
         
         function set.pixelPitchXY(obj,val)
             validateattributes(val,{'numeric'},{'positive','numel',2,'nonnan','finite','real'});
             obj.pixelPitchXY = val;
         end
         
         function set.interPixelGapXY(obj,val)
             validateattributes(val,{'numeric'},{'positive','numel',2,'nonnan','finite','real'});
             obj.interPixelGapXY = val;
         end
         
         function set.pixelBitDepth(obj,val)
             validateattributes(val,{'numeric'},{'positive','integer','scalar'});
             obj.pixelBitDepth = val;
             obj.deinit();
         end
         
         function set.computeTransposedPhaseMask(obj,val)
             validateattributes(val,{'numeric','logical'},{'scalar','binary'});
             obj.computeTransposedPhaseMask = logical(val);
             obj.deinit();
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
