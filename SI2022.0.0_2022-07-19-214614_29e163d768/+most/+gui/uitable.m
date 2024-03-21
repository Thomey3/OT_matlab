classdef uitable < handle
    %UICONTROL Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        UserData;
        CellEditCallback;
        CellSelectionCallback;
        DeleteFcn;
        Data;
        selection = [];
        Visible;
    end
    
    properties (Hidden)
        hPnl;
        hCtl;
        hScrl;
        hBindingListener;
        
        data_;
        numRows = 0;
        numVisibleRows;
        maxTopRow;
        firstRowIdx = 1;
        needSizeCalc = true;
    end
    
    methods
        function obj = uitable(varargin)
            obj.hCtl = uitable(varargin{:});
            obj.hPnl = uipanel('Parent',obj.hCtl.Parent,'Units',obj.hCtl.Units,'Position',obj.hCtl.Position,'BorderType','none');
            obj.hCtl.Parent = obj.hPnl;
            obj.hCtl.Units = 'normalized';
            obj.hCtl.Position = [0 0 1 1];
            
            obj.hScrl = most.gui.uicontrol('Parent',obj.hPnl,'style','slider','callback',@obj.scrlCB,'LiveUpdate',true);
            
            obj.hPnl.SizeChangedFcn = @obj.szCallback;
            obj.szCallback();
            
            obj.UserData = get(obj.hCtl, 'userdata');
            obj.CellEditCallback = get(obj.hCtl, 'CellEditCallback');
            obj.CellSelectionCallback = get(obj.hCtl, 'CellSelectionCallback');
            obj.DeleteFcn = get(obj.hCtl, 'DeleteFcn');
            set(obj.hCtl, 'userdata', obj);
            set(obj.hCtl, 'CellEditCallback', @obj.editCallback);
            set(obj.hCtl, 'CellSelectionCallback', @obj.selCallback);
            set(obj.hCtl, 'DeleteFcn', @obj.delFcn);
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hBindingListener);
        end
        
        function v = get.Data(obj)
            v = obj.data_;
        end
        
        function set.Data(obj, val)
            if iscell(val)
                for idx = 1:numel(val)
                    if most.idioms.isValidObj(val{idx}) && isprop(val{idx},'name')
                        comment = '';
                        if isprop(val{idx},'userInfo') && ~isempty(val{idx}.userInfo)
                            comment = [' ' val{idx}.userInfo];
                        end
                        
                        val{idx} = [val{idx}.name comment];
                    end
                end
            end

            obj.needSizeCalc = true;
            obj.data_ = val;
            obj.numRows = size(val,1);
            obj.maxTopRow = max(1,obj.numRows - obj.numVisibleRows + 1);
            obj.firstRowIdx = min(obj.firstRowIdx, obj.maxTopRow);
        end
        
        function set.firstRowIdx(obj,v)
            obj.firstRowIdx = v;
            obj.redrawTable();
        end
        
        function v = get.Visible(obj)
            v = obj.hPnl.Visible;
        end
        
        function set.Visible(obj, val)
            obj.hPnl.Visible = val;
        end
    end
    
    methods (Hidden)
        function editCallback(obj,varargin)
            % update obj.data
            nd = min(obj.numRows, obj.firstRowIdx+obj.numVisibleRows-1);
            obj.data_(obj.firstRowIdx:nd,:) = obj.hCtl.Data;
            
            if ~isempty(obj.CellEditCallback)
                obj.CellEditCallback(varargin{:});
            end
        end
        
        function selCallback(obj,hTbl,data)
            % update cell selectionid
            if numel(data.Indices) == 1
                obj.selection = data.Indices + [obj.firstRowIdx-1 0];
                
                if ~isempty(obj.CellSelectionCallback)
                    evt.Indices = obj.selection;
                    evt.Source = obj;
                    evt.EventName = 'CellSelection';
                    obj.CellSelectionCallback(hTbl,evt);
                end
            else
                obj.selection = [];
            end
        end
        
        function szCallback(obj,varargin)
            obj.hCtl.Units = 'pixels';
            obj.numVisibleRows = max(1,floor((obj.hCtl.Position(4) - 22) / 18));
            obj.needSizeCalc = true;
            obj.redrawTable();
            
            obj.hPnl.Units = 'pixels';
            obj.hScrl.hCtl.Units = 'pixels';
            obj.hCtl.Units = 'normalized';
            p = obj.hPnl.Position;
            w = 18;
            obj.hScrl.hCtl.Position = [p(3)-w+1 1 w p(4)-1];
            obj.hCtl.Position = [0 0 1 1];
        end
        
        function scrlCB(obj,varargin)
            obj.firstRowIdx = floor(obj.maxTopRow-obj.hScrl.hCtl.Value+1);
            obj.hScrl.hCtl.Value = obj.maxTopRow - obj.firstRowIdx + 1;
        end
        
        function delFcn(obj,varargin)
            if ~isempty(obj.DeleteFcn)
                obj.DeleteFcn(varargin{:});
            end
            delete(obj);
        end
        
        function redrawTable(obj)
            if ~isempty(obj.data_)
                nd = min(obj.numRows, obj.firstRowIdx+obj.numVisibleRows-1);
                obj.hCtl.Data = obj.data_(obj.firstRowIdx:nd,:);
                
                if obj.needSizeCalc
                    if size(obj.Data,1) > obj.numVisibleRows
                        obj.hScrl.hCtl.Min = 1;
                        obj.hScrl.hCtl.Max = obj.maxTopRow;
                        a = obj.numVisibleRows / (obj.numRows - obj.numVisibleRows);
                        obj.hScrl.hCtl.SliderStep = [1/(obj.maxTopRow-1) a];
                        obj.hScrl.hCtl.Value = obj.maxTopRow - obj.firstRowIdx + 1;
                        obj.hScrl.hCtl.Enable = 'on';
                    else
                        obj.hScrl.hCtl.Enable = 'off';
                    end
                    obj.needSizeCalc = false;
                end
            else
                obj.hCtl.Data = [];
                obj.hScrl.hCtl.Enable = 'off';
            end
        end
        
        function set(obj,prop,val)
            switch(lower(prop))
                case 'Celleditcallback'
                    obj.cellEditCallback = val;
                    
                case 'Cellselectioncallback'
                    obj.cellSelectionCallback = val;
                    
                case 'DeleteFcn'
                    obj.DeleteFcn = val;
                    
                case 'userdata'
                    obj.UserData = val;
                    
                case 'data'
                    obj.Data = val;
                    
                case {'visible' 'position'}
                    set(obj.hPnl,prop,val);
                    
                otherwise
                    set(obj.hCtl,prop,val);
            end
        end
        
        function v = get(obj,prop)
            switch(lower(prop))
                case 'Celleditcallback'
                    v = obj.cellEditCallback;
                    
                case 'Cellselectioncallback'
                    v = obj.cellSelectionCallback;
                    
                case 'DeleteFcn'
                    v = obj.DeleteFcn;
                    
                case 'userdata'
                    v = obj.UserData;
                    
                case 'data'
                    v = obj.Data;
                    
                case {'visible' 'position'}
                    v = get(obj.hPnl,prop);
                    
                otherwise
                    v = get(obj.hCtl,prop);
            end
        end
        
        function hL = addlistener(obj,varargin)
            hL = most.ErrorHandler.addCatchingListener(obj.hCtl,varargin{:});
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
