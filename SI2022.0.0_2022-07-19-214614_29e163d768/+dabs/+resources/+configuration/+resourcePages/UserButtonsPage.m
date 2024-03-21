classdef UserButtonsPage < dabs.resources.configuration.ResourcePage
    properties
        tableUserButtons
        selectedRow;
    end
    
    methods
        function obj = UserButtonsPage(hResource,hParent)
            obj@dabs.resources.configuration.ResourcePage(hResource,hParent);
        end
        
        function makePanel(obj,hParent)
            obj.tableUserButtons = most.gui.uicontrol('Parent',hParent,'Style','uitable','ColumnFormat',{'char','char'},'ColumnEditable',[true,true],'ColumnName',{'Name','Function'},'ColumnWidth',{80 240},'RelPosition', [24 133 350 110],'Tag','tableUserButtons','CellSelectionCallback',@obj.cellSelected);
            
            most.gui.uicontrol('Parent',hParent,'String','+','Callback',@(varargin)obj.addRow,'Tag','pbPlus','RelPosition', [0 43 20 20]);
            most.gui.uicontrol('Parent',hParent,'String',most.constants.Unicode.ballot_x,'Callback',@(varargin)obj.removeRow,'Tag','pbRemove','RelPosition',[0 63 20 20]);
            most.gui.uicontrol('Parent',hParent,'String',most.constants.Unicode.black_up_pointing_triangle,  'Callback',@(varargin)obj.moveRow(-1),'Tag','pbMoveUp','RelPosition', [0 83 20 20]);
            most.gui.uicontrol('Parent',hParent,'String',most.constants.Unicode.black_down_pointing_triangle,'Callback',@(varargin)obj.moveRow(+1),'Tag','pbMoveDown','RelPosition', [0 103 20 20]);
        end
        
        function redraw(obj)
            names = cellfun(@(entry)entry{1},obj.hResource.userButtons,'UniformOutput',false);
            fcns  = cellfun(@(entry)func2str_(entry{2}),obj.hResource.userButtons,'UniformOutput',false);
            obj.tableUserButtons.Data = most.idioms.horzcellcat(names,fcns);
            
            function s = func2str_(func)
                s = func2str(func);
                if ~strcmp(s(1),'@')
                    s = ['@' s];
                end
            end
        end
        
        function apply(obj)
            data = obj.tableUserButtons.Data;
            data = cellfun(@(name,fcn){name,fcn},data(:,1),data(:,2),'UniformOutput',false);
            most.idioms.safeSetProp(obj.hResource,'userButtons',data);
            
            obj.hResource.saveMdf();
            obj.hResource.reinit();
        end
          
        function remove(obj)
            obj.hResource.deleteAndRemoveMdfHeading();
        end
        
        function cellSelected(obj,src,evt)
            if isempty(evt.Indices)
                obj.selectedRow = [];
            else
                obj.selectedRow = evt.Indices(1);
            end
        end
        
        function addRow(obj)
            obj.tableUserButtons.Data(end+1,:) = {'',''};
            drawnow();
            obj.selectedRow = size(obj.tableUserButtons.Data,1);
        end
        
        function removeRow(obj)
            if isempty(obj.selectedRow) || obj.selectedRow>size(obj.tableUserButtons.Data,1)
                return
            end
            
            selection = obj.selectedRow();
            obj.tableUserButtons.Data(obj.selectedRow,:) = [];
            drawnow();
            
            numRows = size(obj.tableUserButtons.Data,1);
            selection = min(selection,numRows);
            
            if selection<1
                selection = [];
            end
            
            obj.selectedRow = selection;
        end
        
        function moveRow(obj,inc)
            if isempty(obj.selectedRow) || obj.selectedRow>size(obj.tableUserButtons.Data,1)
                return
            end
            
            data = obj.tableUserButtons.Data;
            
            if obj.selectedRow == 1 && inc==-1
                return
            end
            
            if obj.selectedRow == size(data,1) && inc==1
                return
            end
            
            swapIdx1 = obj.selectedRow;
            swapIdx2 = obj.selectedRow+inc;
            
            data([swapIdx1,swapIdx2],:) = data([swapIdx2,swapIdx1],:);
            
            obj.tableUserButtons.Data = data;
            drawnow();
            obj.selectedRow = swapIdx2;
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
