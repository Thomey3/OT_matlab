classdef ParallelMotionEstimatorResult < scanimage.interfaces.IMotionEstimatorResult    
    properties (SetAccess = private)
        futureFinished = false;
        fevalFuture
    end
    
    methods
        function obj = ParallelMotionEstimatorResult(hMotionEstimator,roiData,fevalFuture)
            obj = obj@scanimage.interfaces.IMotionEstimatorResult(hMotionEstimator,roiData);
            obj.fevalFuture = fevalFuture;
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.fevalFuture);
        end
        
        function tf = wait(obj,timeout_s)
            tf = obj.futureFinished || ~isempty(regexpi(obj.fevalFuture.State,'^finished.*','once'));
            if ~tf && timeout_s>0
                % performance fix: only call wait method on fevalFuture if necessary
                tf = obj.fevalFuture.wait('finished',timeout_s);
            end
        end
        
        function dr=fetch(obj)
            if ~obj.futureFinished
                obj.wait(Inf);
                [obj.dr,obj.confidence,obj.correlation] = obj.fevalFuture.fetchOutputs;
            end
            dr = obj.dr;
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
