classdef ResourceSelector < handle
    properties
        hFig;
        hListBox;
        hTabGroup;
        hTxStatus;
        lastSelection = [];
        lastSelectionTime = tic();
    end
    
    methods
        function obj = ResourceSelector()
            obj.hFig = most.idioms.figure('Name','Select Device','Numbertitle','off','Menubar','none','CloseRequestFcn',@(varargin)obj.delete);
            setFigureSize(obj.hFig,560,470);
            
            hFlow = most.gui.uiflowcontainer('Parent',obj.hFig,'FlowDirection','TopDown');
                obj.hTabGroup = uitabgroup('Parent',hFlow,'TabLocation','left','SelectionChangedFcn',@(varargin)obj.redraw);
                hButtonFlow = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','RightToLeft','HeightLimits',[30,30]);
                
            obj.makeTabs();
            
            most.gui.uicontrol('Parent',hButtonFlow,'String','Cancel','WidthLimits',[100 100],'Callback',@(varargin)obj.delete);
            most.gui.uicontrol('Parent',hButtonFlow,'String','Add','WidthLimits',[100 100],'Callback',@(varargin)obj.createResource);
            obj.hTxStatus = most.gui.uicontrol('Parent',hButtonFlow,'Style','text','Enable','inactive','HorizontalAlignment','right','ButtonDownFcn',@(varargin)obj.editClass);
            
            obj.redraw();
            
            %%% Nested functions
            function setFigureSize(hFig,w,h)
                pos = hFig.Position;
                center = [pos(1)+pos(3)/2, pos(2)+pos(4)/2];
                pos = [center(1)-w/2, center(2)-h/2, w, h];
                hFig.Position = pos;
            end
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hFig);
        end
        
        function makeTabs(obj)
            classStruct = dabs.resources.configuration.private.findAllConfigClasses();
            
            % dont show microscope templates in "all" category
            isMicroscope = cellfun(@(s)ismember('dabs.resources.MicroscopeSystem',superclasses(s)), {classStruct.className});
            
            uitab('Parent',obj.hTabGroup,'Title','All','UserData',removeDuplicates(classStruct(~isMicroscope)));
            
            categories = sort(unique({classStruct.category}));
            for idx = 1:numel(categories)
                category = categories{idx};
                if ~isempty(category)
                    categoryMask = strcmp(category,{classStruct.category});
                    classStruct_ = classStruct(categoryMask);
                    classStruct_ = removeDuplicates(classStruct_);
                    uitab('Parent',obj.hTabGroup,'Title',category,'UserData',classStruct_);
                end
            end
            
            uncategorizedMask = strcmp('',{classStruct.category});
            classStruct_ = classStruct(uncategorizedMask);
            classStruct_ = removeDuplicates(classStruct_);
            uitab('Parent',obj.hTabGroup,'Title','Miscellaneous','UserData',classStruct_);
            
            obj.hListBox = uicontrol('Parent',[],'Style','listbox','Units','normalized','Position',[0.01 0.01 0.98 0.98],'Callback',@(varargin)obj.selectionChanged);
            
            % filter duplicate entries
            function classStruct = removeDuplicates(classStruct)
                qualifiedName = arrayfun(@(cS)[cS.className,'/',cS.descriptiveName],classStruct,'UniformOutput',false);
                [~,uniqueIdxs] = unique(qualifiedName);
                classStruct = classStruct(uniqueIdxs);
                [~,sortIdx] = sort({classStruct.descriptiveName});
                classStruct = classStruct(sortIdx);
            end
        end
        
        function selectionChanged(obj)
            dTime = toc(obj.lastSelectionTime);
            currentSelection = obj.hListBox.Value;
            doubleClickTimeout_s = 0.5;
            
            obj.updateStatus();
            
            if dTime < doubleClickTimeout_s ...
               && isequal(obj.lastSelection,currentSelection)
                    obj.createResource(); % double click to add
            else
                obj.lastSelection = currentSelection;
                obj.lastSelectionTime = tic();
            end
        end
        
        function updateStatus(obj)
            classInfo = obj.hListBox.UserData(obj.hListBox.Value);
            obj.hTxStatus.String = sprintf('Driver class: %s    ',classInfo.className);
            obj.hTxStatus.UserData = classInfo.className;
        end
        
        function editClass(obj)
            if isempty(obj.hTxStatus.UserData)
                return
            end
            
            className = obj.hTxStatus.UserData;
            try
                edit(className);
            catch ME
                if strcmpi(ME.identifier,'MATLAB:Editor:PFile')
                    msgbox('Driver is protected and cannot be edited.', 'Protected','help');
                else
                    most.ErrorHandler.rethrow(ME);
                end
            end
        end
        
        function redraw(obj)
            obj.hListBox.Parent = obj.hTabGroup.SelectedTab;
            classStruct = obj.hTabGroup.SelectedTab.UserData;
            
            obj.hListBox.String = {classStruct.descriptiveName};
            obj.hListBox.Value = 1;
            obj.hListBox.UserData = classStruct;
            
            obj.updateStatus();
        end
        
        function createResource(obj)
            classInfo = obj.hListBox.UserData(obj.hListBox.Value);
            
            if ismember('dabs.resources.MicroscopeSystem', superclasses(classInfo.className))
                resourceName = 'Adding components...';
            else
                resourceName = dabs.resources.configuration.private.queryUserForName();
            end
            
            if isempty(resourceName)
                return
            end
            
            obj.delete();
            
            constructor = str2func(classInfo.className);
            hResource = constructor(resourceName);
            
            if most.idioms.isValidObj(hResource)
                hResource.showConfig();
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
