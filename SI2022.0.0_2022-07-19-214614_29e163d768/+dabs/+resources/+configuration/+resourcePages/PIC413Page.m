classdef PIC413Page < dabs.resources.configuration.ResourcePage
    properties
        pmControllerName
        tableEnabledAxes
    end
    
    methods
        function obj = PIC413Page(hResource,hParent)
            obj@dabs.resources.configuration.ResourcePage(hResource,hParent);
        end
        
        function makePanel(obj,hParent)
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [-20 32 80 20],'Tag','txControllerName','String','Controller','HorizontalAlignment','right');
            obj.pmControllerName = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [10 52 360 20],'Tag','pmControllerName');
            
            obj.tableEnabledAxes = most.gui.uicontrol('Parent',hParent,'Style','uitable','ColumnFormat',{'char','logical'},'ColumnEditable',[false,true],'ColumnName',{'Axis','Enable'},'ColumnWidth',{60 40},'RowName',[],'RelPosition', [10 172 110 100],'Tag','tableEnabledAxes');
        end
        
        function redraw(obj)            
            obj.pmControllerName.String = unique([{''} obj.hResource.enumerateControllers {obj.hResource.controllerName}]);
            obj.pmControllerName.pmValue = obj.hResource.controllerName;
            
            axNames = arrayfun(@(ax)sprintf('Axis %d',ax),1:obj.hResource.numAxes,'UniformOutput',false)'';
            axEnabled = false(obj.hResource.numAxes,1);
            axEnabled(obj.hResource.enabledAxes) = true;
            obj.tableEnabledAxes.Data = most.idioms.horzcellcat(axNames,num2cell(axEnabled));
        end
        
        function apply(obj)
            most.idioms.safeSetProp(obj.hResource,'controllerName',obj.pmControllerName.pmValue);
           
            enabledAxes = [obj.tableEnabledAxes.Data{:,2}];
            enabledAxes = find(enabledAxes);
            most.idioms.safeSetProp(obj.hResource,'enabledAxes',enabledAxes(:)');
            
            obj.hResource.saveMdf();
            obj.hResource.reinit();
        end
        
        function remove(obj)
            obj.hResource.deleteAndRemoveMdfHeading();
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
