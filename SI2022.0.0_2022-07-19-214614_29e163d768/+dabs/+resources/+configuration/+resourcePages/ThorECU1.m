classdef ThorECU1 < dabs.resources.configuration.ResourcePage
    properties
        pmhCOM
        pmhDAQ
        cbPmts
        tableAutoOn
    end
    
    methods
        function obj = ThorECU1(hResource,hParent)
            obj@dabs.resources.configuration.ResourcePage(hResource,hParent);
        end
        
        function makePanel(obj,hParent)
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [60 33 50 20],'Tag','txhCOM','String','COM Port','HorizontalAlignment','right');
            obj.pmhCOM  = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [120 33 150 20],'Tag','pmhCOM');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [50 63 60 20],'Tag','txhDAQ','String','DAQ Board','HorizontalAlignment','right');
            obj.pmhDAQ  = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [120 63 150 20],'Tag','pmhDAQ');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [-10 93 120 20],'Tag','txpmt','String','Enable PMT Control','HorizontalAlignment','right');
            obj.cbPmts = most.gui.uicontrol('Parent',hParent,'Style','checkbox','RelPosition', [120 93 20 20],'Tag','cbPmts');
            
            obj.tableAutoOn = most.gui.uicontrol('Parent',hParent,'Style','uitable','ColumnFormat',{'logical','numeric'},'ColumnEditable',[true true],'ColumnName',{'Auto on','Wavelength [nm]'},'ColumnWidth',{60 100},'RelPosition', [120 173 240 70],'Tag','tableAutoOn');
            
            most.gui.uicontrol('Parent',hParent,'String','Show vDAQ wiring diagram','RelPosition', [120 233 150 30],'Tag','pbWiringDiagram','Callback',@(varargin)obj.showvDAQWiringDiagram);
        end
        
        function redraw(obj)            
            hCOMs = obj.hResourceStore.filterByClass(?dabs.resources.SerialPort);
            obj.pmhCOM.String = [{''}, hCOMs];
            obj.pmhCOM.pmValue = obj.hResource.hCOM;
            
            hDAQs = obj.hResourceStore.filterByClass(?dabs.resources.DAQ);            
            obj.pmhDAQ.String = [{''}, hDAQs];
            obj.pmhDAQ.pmValue = obj.hResource.hDAQ;
            
            obj.cbPmts.Value = obj.hResource.usePmts;
            
            rowNames = {'PMT1','PMT2'};
            obj.tableAutoOn.hCtl.RowName = rowNames;
            obj.tableAutoOn.Data = most.idioms.horzcellcat(num2cell(obj.hResource.autoOn(:)),num2cell(obj.hResource.wavelength_nm(:)));
            obj.tableAutoOn.Enable = obj.hResource.usePmts;
        end
        
        function apply(obj)
            most.idioms.safeSetProp(obj.hResource,'hCOM',obj.pmhCOM.pmValue);
            most.idioms.safeSetProp(obj.hResource,'hDAQ',obj.pmhDAQ.pmValue);
            most.idioms.safeSetProp(obj.hResource,'usePmts',obj.cbPmts.Value);
            
            autoOn = cell2mat(obj.tableAutoOn.Data(:,1))';
            most.idioms.safeSetProp(obj.hResource,'autoOn',autoOn);
            
            wavelength_nm = cell2mat(obj.tableAutoOn.Data(:,2))';
            most.idioms.safeSetProp(obj.hResource,'wavelength_nm',wavelength_nm);
            
            obj.hResource.saveMdf();
            obj.hResource.reinit();
        end
        
        function remove(obj)
            obj.hResource.deleteAndRemoveMdfHeading();
        end
        
        function showvDAQWiringDiagram(obj)            
            p = fileparts( mfilename('fullpath') );
            p = fullfile(p,'+private','vDAQ Thor ECU1.PNG');
            
            hFig = most.idioms.figure('NumberTitle','off','Menubar','none','name','Wiring Diagram');
            hAx = most.idioms.axes('Parent',hFig);
            hIm = imshow(p,'Parent',hAx);
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
