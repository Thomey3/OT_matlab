classdef Legal < handle
    properties
        hFig
        hFlow
    end    
    
    methods
        function obj = Legal()
            obj.hFig = most.idioms.figure('Name','Legal','NumberTitle','off','MenuBar','None','CloseRequestFcn',@(varargin)obj.delete);
            
            obj.hFlow = most.gui.uiflowcontainer('Parent',obj.hFig,'FlowDirection','TopDown','margin',5);         
            
            flow = most.gui.uiflowcontainer('Parent',obj.hFlow,'FlowDirection','TopDown','margin',1,'HeightLimits',[30 30]);
            container = most.gui.uiflowcontainer('Parent',flow,'FlowDirection','LeftToRight','margin',1);
            most.gui.uicontrol('Parent',container,'Style','text','String','Legal','FontSize',15,'HorizontalAlignment','left','Enable','inactive');
            container = most.gui.uiflowcontainer('Parent',obj.hFlow,'FlowDirection','LeftToRight','margin',1,'HeightLimits',[1 1]);
            annotation(container,'line',[0 1],zeros(1,2), 'LineWidth', 1);
            
            hText = most.gui.uicontrol('Parent',obj.hFlow,'Style','text','HorizontalAlignment','left','Enable','inactive');
            hText.String = obj.getLegalText();
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hFig);
        end
    end
    
    methods (Static)
        function str = getLegalText()
            str = {
                'VIDRIO TECHNOLOGIES, LLC MAKES NO WARRANTIES, EXPRESS OR IMPLIED, WITH RESPECT TO THIS PRODUCT, AND EXPRESSLY DISCLAIMS ANY WARRANTY OF MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE.'
                'IN NO CASE SHALL VIDRIO TECHNOLOGIES, LLC BE LIABLE TO ANYONE FOR ANY CONSEQUENTIAL OR INCIDENTAL DAMAGES, EXPRESS OR IMPLIED, OR UPON ANY OTHER BASIS OF LIABILITY WHATSOEVER, EVEN IF THE LOSS OR DAMAGE IS CAUSED BY VIDRIO TECHNOLOGIES, LLC''S OWN NEGLIGENCE OR FAULT.'
                'CONSEQUENTLY, VIDRIO TECHNOLOGIES, LLC SHALL HAVE NO LIABILITY FOR ANY PERSONAL INJURY, PROPERTY DAMAGE OR OTHER LOSS BASED ON THE USE OF THE PRODUCT IN COMBINATION WITH OR INTEGRATED INTO ANY OTHER INSTRUMENT OR DEVICE.  HOWEVER, IF VIDRIO TECHNOLOGIES, LLC IS HELD LIABLE, WHETHER DIRECTLY OR INDIRECTLY, FOR ANY LOSS OR DAMAGE ARISING, REGARDLESS OF CAUSE OR ORIGIN, VIDRIO TECHNOLOGIES, LLC''s MAXIMUM LIABILITY SHALL NOT IN ANY CASE EXCEED THE PURCHASE PRICE OF THE PRODUCT WHICH SHALL BE THE COMPLETE AND EXCLUSIVE REMEDY AGAINST VIDRIO TECHNOLOGIES, LLC.'
                };
            
            str = strjoin(str,'\n');
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
