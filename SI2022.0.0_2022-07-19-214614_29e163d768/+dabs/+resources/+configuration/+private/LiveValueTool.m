classdef LiveValueTool < handle
    properties
        hBreakOut
        motionFcnHdl
        hFig
        hAx
        hBNCPlotter

        quadrant = 1;
        hListeners = event.listener.empty();
    end
    
    methods
        function obj = LiveValueTool(hBreakOut)
            obj.hBreakOut = hBreakOut;
            
            obj.hFig = obj.hBreakOut.hFig;
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hBreakOut,'ObjectBeingDestroyed',@(varargin)obj.delete);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hFig,'ObjectBeingDestroyed',@(varargin)obj.delete);

            obj.motionFcnHdl = @obj.motionFcn;
            obj.hFig.WindowButtonMotionFcn = obj.motionFcnHdl;
        end

        function delete(obj)
            if most.idioms.isValidObj(obj.hFig) && isequal(obj.hFig.WindowButtonMotionFcn,obj.motionFcnHdl)
                obj.hBreakOut.hFig.WindowButtonMotionFcn = [];
            end
            most.idioms.safeDeleteObj(obj.hListeners);
            most.idioms.safeDeleteObj(obj.hAx);

            most.idioms.safeDeleteObj(obj.hBNCPlotter);
        end

        function motionFcn(obj,src,evt)
            hBNC = getCurrentBNC();

            deletePlotterIfNecessary(hBNC);
            createPlotterIfNecessary(hBNC);
            updatePlotterIfNecessary();

            %%% Nested functions
            function hBNC = getCurrentBNC()
                if isempty(obj.hBreakOut.hBNCs)
                    hBNC = [];
                    return
                end

                positions = vertcat(obj.hBreakOut.hBNCs.Position);
                hBNCAx = ancestor(obj.hBreakOut.hBNCs(1).hParent,'axes');
                pt = hBNCAx.CurrentPoint(1,1:2);

                d = positions-pt;
                d = sqrt( d(:,1).^2 + d(:,2).^2 );

                [d,idx] = min(d);
                hBNC = obj.hBreakOut.hBNCs(idx);
                if d>hBNC.radius
                    hBNC = [];
                end
            end
            
            function deletePlotterIfNecessary(hBNC)
                if isempty(hBNC)
                    most.idioms.safeDeleteObj(obj.hBNCPlotter);
                elseif most.idioms.isValidObj(obj.hBNCPlotter)
                    if ~isequal(obj.hBNCPlotter.hBNC,hBNC)
                        most.idioms.safeDeleteObj(obj.hBNCPlotter);
                    end
                end
            end

            function createPlotterIfNecessary(hBNC)
                if ~isempty(hBNC) && ~most.idioms.isValidObj(obj.hBNCPlotter)
                    obj.hBNCPlotter = dabs.resources.configuration.private.BNCPlotter(obj.hFig,hBNC);
                end
            end

            function updatePlotterIfNecessary()
                if most.idioms.isValidObj(obj.hBNCPlotter)
                    obj.hBNCPlotter.updatePosition();
                end
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
