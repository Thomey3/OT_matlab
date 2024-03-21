classdef PolygonalScannerGenericPage < dabs.resources.configuration.ResourcePage
    properties
        pmhDOFreq
        pmhDISync
        pmhDOEnable
        cbInvertEnable
        etLineRate2ModFreqFunc
        etNumFacets
        etNominalFrequency
        etSettleTime
    end
    
    methods
        function obj = PolygonalScannerGenericPage(hResource,hParent)
            obj@dabs.resources.configuration.ResourcePage(hResource,hParent);
        end
        
        function makePanel(obj,hParent)
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [20 25 170 20],'Tag','txhDISync','String','Sync Channel','HorizontalAlignment','right');
            obj.pmhDISync = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [200 23 120 20],'Tag','pmhDISync');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [19 49 170 20],'Tag','txhDOFreq','String','Speed Control Channel (optional)','HorizontalAlignment','right');
            obj.pmhDOFreq  = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [200 46 120 20],'Tag','pmhDOFreq');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [20 73 170 20],'Tag','txhDOEnable','String','Enable Channel (optional)','HorizontalAlignment','right');
            obj.pmhDOEnable = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [200 70 120 20],'Tag','pmhDOEnable');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [20 96 170 20],'Tag','txInvertEnable','String','Invert Enable Logic','HorizontalAlignment','right');
            obj.cbInvertEnable = most.gui.uicontrol('Parent',hParent,'Style','checkbox','RelPosition', [200 96 40 20],'Tag','cbInvertEnable');
            
            tooltip = sprintf(['The speed of the polygonal scanner is controlled by a digital square wave.\n' ...
                     'The frequency of the square wave defines the rotational speed of the scanner.\n' ...
                     'The line rate is translated to the square wave frequency via a simple factor OR a function\n' ...
                     'Factor: enter factor (e.g. 10)\n' ...
                     'Function: enter function name OR enter anonymous function of form @(linerate)linerate*5+10']);
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [20 122 170 20],'Tag','txLineRate2ModFreqFunc','String','Output Frequency/Line Rate Ratio','HorizontalAlignment','right');
            obj.etLineRate2ModFreqFunc = most.gui.uicontrol('Parent',hParent,'Style','edit','String','@(f)f','RelPosition', [200 122 120 20],'Tag','etLineRate2ModFreqFunc','ToolTipString',tooltip);
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [21 147 170 20],'Tag','txNumFacets','String','Number of Facets','HorizontalAlignment','right');
            obj.etNumFacets = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [200 147 120 20],'Tag','etNumFacets');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [22 172 170 20],'Tag','txSettleTime','String','Settle time [s]','HorizontalAlignment','right');
            obj.etSettleTime = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [200 172 120 20],'Tag','etSettleTime');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [22 200 170 20],'Tag','txNominalFrequency','String','Nominal Line Rate [Hz]','HorizontalAlignment','right');
            obj.etNominalFrequency = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [200 200 120 20],'Tag','etNominalFrequency');
        end
        
        function redraw(obj)            
            hIOs = obj.hResourceStore.filter(@(hR)(isa(hR,'dabs.resources.ios.DI')&&isa(hR.hDAQ,'dabs.resources.daqs.vDAQ'))||isa(hR,'dabs.resources.ios.PFI'));
            obj.pmhDISync.String = [{''}, hIOs];
            obj.pmhDISync.pmValue = obj.hResource.hDISync;
            
            hIOs = obj.hResourceStore.filter(@(hR)(isa(hR,'dabs.resources.ios.DO')&&isa(hR.hDAQ,'dabs.resources.daqs.vDAQ'))||isa(hR,'dabs.resources.ios.DO'));
            obj.pmhDOFreq.String = [{''}, hIOs];
            obj.pmhDOFreq.pmValue = obj.hResource.hDOFreq;
            obj.pmhDOEnable.String = [{''}, hIOs];
            obj.pmhDOEnable.pmValue = obj.hResource.hDOEnable;
            
            obj.cbInvertEnable.Value = obj.hResource.invertEnable;
            
            funcStr = func2str(obj.hResource.lineRate2ModFreqFunc);
            factor = regexp(funcStr,'^@\(([A-Za-z][A-Za-z0-9_]*)\)\1\.?\*([0-9]+(\.[0-9]+)?)$','tokens','once');
            
            if isempty(factor)
                obj.etLineRate2ModFreqFunc.String = funcStr;
            else
                obj.etLineRate2ModFreqFunc.String = factor{2};
            end
            
            obj.etNumFacets.String = num2str(obj.hResource.numFacets);
            obj.etNominalFrequency.String = num2str(obj.hResource.nominalFrequency_Hz);
            obj.etSettleTime.String = num2str(obj.hResource.settleTime_s);
        end
        
        function apply(obj)
            most.idioms.safeSetProp(obj.hResource,'hDOFreq',obj.pmhDOFreq.pmValue);
            most.idioms.safeSetProp(obj.hResource,'hDISync',obj.pmhDISync.pmValue);
            most.idioms.safeSetProp(obj.hResource,'hDOEnable',obj.pmhDOEnable.pmValue);
            most.idioms.safeSetProp(obj.hResource,'invertEnable',logical(obj.cbInvertEnable.Value));
            most.idioms.safeSetProp(obj.hResource,'numFacets',str2double(obj.etNumFacets.String));
            most.idioms.safeSetProp(obj.hResource,'nominalFrequency_Hz', str2double(obj.etNominalFrequency.String));
            most.idioms.safeSetProp(obj.hResource,'settleTime_s', str2double(obj.etSettleTime.String));
            
            factor = str2double(obj.etLineRate2ModFreqFunc.String);
            if isnan(factor)
                most.idioms.safeSetProp(obj.hResource,'lineRate2ModFreqFunc',obj.etLineRate2ModFreqFunc.String);
            else
                most.idioms.safeSetProp(obj.hResource,'lineRate2ModFreqFunc',sprintf('@(lineRate)lineRate*%g',factor));
            end
            
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
