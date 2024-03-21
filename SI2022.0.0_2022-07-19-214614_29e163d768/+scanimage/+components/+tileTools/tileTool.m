classdef tileTool < handle
    properties (Constant, Abstract)
        toolName;
    end
    
        %% Local Properties
    properties
        hFig;
        hAxes;
        hSI;
        hTileView;
        
        hListenersTileTool = event.listener.empty();
        hCurrentObjectListener = event.listener.empty();
        
        hCurrentObject = [];
        hCurrentObjectKeyPressFcn = [];
    end
    
    methods
        % Tile Tool operates on the tile view
        function obj = tileTool(hTileView)
            obj.hTileView = hTileView;
            obj.hSI = hTileView.hModel;
            obj.hFig = hTileView.hFig;
            obj.hAxes = hTileView.hFovAxes;
            
            obj.hListenersTileTool(end+1) = most.ErrorHandler.addCatchingListener(obj.hTileView,'ObjectBeingDestroyed',@(varargin)obj.delete);
            obj.hCurrentObjectListener(end+1) = most.ErrorHandler.addCatchingListener(obj.hFig,'CurrentObject','PostSet',@(varargin)obj.focusChanged);
            obj.setKeyPressFcn();
        end
        
        function delete(obj)
            delete(obj.hListenersTileTool);
            delete(obj.hCurrentObjectListener);
            
            if most.idioms.isValidObj(obj.hCurrentObject)
                obj.hCurrentObject.KeyPressFcn = obj.hCurrentObjectKeyPressFcn;
            end
        end
        
        function focusChanged(obj)            
            
            if obj.hFig.CurrentObject ~= obj.hAxes
                obj.delete(); % if users presses any other ui element, delete tool
            else            
                obj.setKeyPressFcn();
            end
        end
        
        function setKeyPressFcn(obj)
            if most.idioms.isValidObj(obj.hCurrentObject)
                obj.hCurrentObject.KeyPressFcn = obj.hCurrentObjectKeyPressFcn;
            end
            
            currentObject = obj.hFig.CurrentObject;
            if isempty(currentObject) || ~isprop(currentObject,'KeyPressFcn')
                currentObject = obj.hFig;
            end
            
            obj.hCurrentObject = currentObject;
            obj.hCurrentObjectKeyPressFcn = currentObject.KeyPressFcn;
            
            obj.hCurrentObject.KeyPressFcn = @obj.keyPressed;
        end
        
        function keyPressed(obj,src,evt)
            switch evt.Key
                case 'escape'
                    obj.delete();
            end
        end
    end
    
    methods (Static)
        function toolClasses = findAllTools()
            toolsPath = mfilename('fullpath');
            toolsPath = fileparts(toolsPath);
            thisClassName = mfilename('class');
            toolClasses = most.util.findAllClasses(toolsPath,thisClassName);
            
            isAbstractMask = false(size(toolClasses));
            for idx = 1:numel(toolClasses)
                mc = meta.class.fromName(toolClasses{idx});
                isAbstractMask(idx) = mc.Abstract;
            end
            
            toolClasses(isAbstractMask) = [];
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
