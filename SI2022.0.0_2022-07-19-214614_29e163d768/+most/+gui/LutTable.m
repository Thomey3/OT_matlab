classdef LutTable < handle    
    properties (SetAccess = private)
        bindingObj
        bindingPropertyName
        hParent
        hTableFlow
        hTable
        hEtLutIn
        hEtLutOut
        hListeners = event.listener.empty();
    end
    
    properties
        changeCallback = function_handle.empty();
        lutScaling = [1 1];
    end
    
    properties (Dependent)
        lut
        columnNames
        columnWidths
    end
    
    methods
        function obj = LutTable(hParent,bindingObj,bindingPropertyName)
            obj.hParent = hParent;
            obj.bindingObj = bindingObj;
            obj.bindingPropertyName = bindingPropertyName;
            
            obj.hTableFlow = most.idioms.uiflowcontainer('Parent',obj.hParent,'FlowDirection','TopDown');
                obj.hTable = uitable('Parent',obj.hTableFlow,'ColumnFormat',{'char','numeric','numeric'},'ColumnName',{'','LUT In','LUT Out'},'RowName',[],'ColumnEditable',[false,true,true],'ColumnWidth',{15,60,60},'CellEditCallback',@obj.tableEdited,'CellSelectionCallback',@obj.tableCellSelected);
                hAddEntryFlow = most.idioms.uiflowcontainer('Parent',obj.hTableFlow,'FlowDirection','LeftToRight');
                hAddEntryFlow.HeightLimits = [25 25];
                    most.gui.uicontrol('Parent',hAddEntryFlow,'style','pushbutton','Callback',@obj.addEntry,'string','+','WidthLimits',[20 20]);
                    obj.hEtLutIn  = most.gui.uicontrol('Parent',hAddEntryFlow,'style','edit');
                    obj.hEtLutOut = most.gui.uicontrol('Parent',hAddEntryFlow,'style','edit');
            
            obj.hListeners(end+1) = addlistener(obj.hTableFlow,'ObjectBeingDestroyed',@(varargin)obj.delete);
            obj.hListeners(end+1) = addlistener(obj.bindingObj,'ObjectBeingDestroyed',@(varargin)obj.delete);
            obj.hListeners(end+1) = addlistener(obj.bindingObj,bindingPropertyName,'PostSet',@(varargin)obj.redraw);
            
            obj.redraw();
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hListeners);
            most.idioms.safeDeleteObj(obj.hTableFlow);
        end
    end
    
    methods
        function addEntry(obj,src,evt)
            try
                in  = obj.hEtLutIn.String;
                out = obj.hEtLutOut.String;
                
                in = str2double(in);
                out = str2double(out);
                
                lutEntry = [in out];
                
                lut_ = obj.lut;
                lut_(end+1,:) = lutEntry;
                
                [~,idx] = unique(lut_(:,1));
                
                lut_ = lut_(idx,:);
                obj.lut = lut_;
                
                obj.executeChangeCallback();
                
                obj.hEtLutIn.String  = '';
                obj.hEtLutOut.String = '';
            catch ME
                obj.redraw();
                most.ErrorHandler.logAndReportError(ME);
                errordlg(ME.message);
            end
        end
        
        function redraw(obj)
            oldData = obj.hTable.Data;
            
            data = num2cell(obj.lut);
            X = most.constants.Unicode.ballot_x;
            data = [repmat({X},size(data,1),1),data];
            
            if ~isequal(oldData,data)
                obj.hTable.Data = data;
            end
        end
        
        function tableCellSelected(obj,src,evt)            
            if numel(evt.Indices)~=2 || evt.Indices(2)~=1
                return
            end
            
            idx = evt.Indices(1);
            obj.lut(idx,:) = [];
            obj.executeChangeCallback();
        end
        
        function tableEdited(obj,src,evt)
            try
                data = obj.hTable.Data;
                lut_ = data(:,2:3);
                lut_ = cell2mat(lut_);
                
                [~,idx] = unique(lut_(:,1));
                lut_ = lut_(idx,:);
                
                if ~isequal(obj.lut,lut_)
                    obj.lut = lut_;
                    obj.executeChangeCallback();
                end
            catch ME
                obj.redraw();
                most.ErrorHandler.logAndReportError(ME);
                errordlg(ME.message);
            end
        end
        
        function executeChangeCallback(obj)
            try
                if ~isempty(obj.changeCallback)
                   obj.changeCallback();
                end
            catch ME
                most.ErrorHandler.logAndReportError();
            end
        end
    end
    
    methods
        function set.lut(obj,val)
            val = val ./ obj.lutScaling;
            obj.bindingObj.(obj.bindingPropertyName) = val;
        end
        
        function val = get.lut(obj)
            val = obj.bindingObj.(obj.bindingPropertyName);
            val = val .* obj.lutScaling;
        end
        
        function set.hParent(obj,val)
            validateattributes(val,{'matlab.graphics.Graphics'},{'scalar'});
            assert(most.idioms.isValidObj(val));
            obj.hParent = val;
        end
        
        function set.bindingObj(obj,val)
            assert(isscalar(obj));
            assert(most.idioms.isValidObj(val));
            obj.bindingObj = val;
        end
        
        function set.bindingPropertyName(obj,val)
            validateattributes(val,{'char'},{'row'});
            mc = metaclass(obj.bindingObj);
            mask =strcmp(val,{mc.PropertyList.Name});
            assert(any(mask));
            mp = mc.PropertyList(mask);
            assert(mp.SetObservable);
            assert(strcmp(mp.SetAccess,'public'));
            
            obj.bindingPropertyName = val;
        end
        
        function set.changeCallback(obj,val)
            if isempty(val)
                val = function_handle.empty();
            else
                validateattributes(val,{'function_handle'},{'scalar'})
            end
            
            obj.changeCallback = val;
        end
        
        function val = get.columnNames(obj)
           val = obj.hTable.ColumnName(2:3);
        end
        
        function set.columnNames(obj,val)
            assert(iscellstr(val));
            validateattributes(val,{'cell'},{'size',[1,2]});
            obj.hTable.ColumnName(2:3) = val;
        end
        
        function set.lutScaling(obj,val)
            validateattributes(val,{'numeric'},{'size',[1,2],'finite','nonnan','real'});
            assert(all(val));
            obj.lutScaling = val;
            
            obj.redraw();
        end
        
        function val = get.columnWidths(obj)
            val = obj.hTable.ColumnWidth(2:3);
        end
        
        function set.columnWidths(obj,val)
            obj.hTable.ColumnWidth(2:3) = val;
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
