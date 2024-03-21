classdef SlmScanPage < dabs.resources.configuration.ResourcePage
    properties
        pmhDAQ
        pmhSlm
        pmhLinScan
        tableChannels
        tablehShutters
        tablehBeams
        etFocalLength_mm
        etSlmMediumRefractiveIdx
        etObjectiveMediumRefractiveIdx
        etZeroOrderBlockRadius_mm
        etSlmMagnificationOntoGalvos
    end
    
    methods
        function obj = SlmScanPage(hResource,hParent)
            obj@dabs.resources.configuration.ResourcePage(hResource,hParent);
        end
        
        function makePanel(obj,hParent)
            hTabGroup = uitabgroup('Parent',hParent);
            hTab = uitab('Parent',hTabGroup,'Title','Basic');
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [70 26 80 20],'Tag','txhDAQ','String','DAQ board','HorizontalAlignment','right');
                obj.pmhDAQ = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [160 22 130 20],'Tag','pmhDAQ');
                
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [50 56 100 20],'Tag','txhSlm','String','SLM','HorizontalAlignment','right');
                obj.pmhSlm = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [160 52 130 20],'Tag','pmhSlm');
                
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [20 85 130 20],'Tag','txhLinScan','String','Linear scanner (optional)','HorizontalAlignment','right');
                obj.pmhLinScan = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [160 82 130 20],'Tag','pmhLinScan');
                
                obj.tableChannels  = most.gui.uicontrol('Parent',hTab,'Style','uitable','ColumnFormat',{'char','logical'},'ColumnEditable',[false,true],'ColumnName',{'Channel','Invert'},'ColumnWidth',{60 40},'RowName',[],'RelPosition', [260 242 110 110],'Tag','tableChannels');
                obj.tablehShutters = most.gui.uicontrol('Parent',hTab,'Style','uitable','ColumnFormat',{'char','logical'},'ColumnEditable',[false,true],'ColumnName',{'Shutter','Use'},'ColumnWidth',{80 30},'RowName',[],'RelPosition', [10 242 115 110],'Tag','tablehShutters');
                obj.tablehBeams    = most.gui.uicontrol('Parent',hTab,'Style','uitable','ColumnFormat',{'char','logical'},'ColumnEditable',[false,true],'ColumnName',{'Beam','Use'},'ColumnWidth',{80 30},'RowName',[],'RelPosition', [135 242 115 110],'Tag','tablehBeams');
                
                hlp = sprintf([
                    'Effective focal length of the SLM imaging system.\nf ... effective focal length f of the SLM system\nf_o ... focal length of the objective\nM_so ... Magnification of the SLM onto the objective back aperture\nf = f_o / M_so', ... 
                    '\r\n\r\n', ...
                    'Hint: the focal length f_o of the objective can be calculated as follows\nf_o = f_t / M_o\nf_t ... focal length of tube lens\nM_o ... magnification of the objective'
                    ]);
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [60 113 90 20],'Tag','txFocalLength_mm','String','Focal length [mm]','HorizontalAlignment','right');
                obj.etFocalLength_mm = most.gui.uicontrol('Parent',hTab,'Style','edit','RelPosition', [160 112 130 20],'Tag','etFocalLength_mm','TooltipString',hlp);
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [294 114.333333333333 10 20],'Tag','hlpFocalLength_mm','String','?','TooltipString',hlp);
            
            hTab = uitab('Parent',hTabGroup,'Title','Advanced');
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [30 34 150 20],'Tag','txSlmMediumRefractiveIdx','String','SLM medium refractive index','HorizontalAlignment','right');
                obj.etSlmMediumRefractiveIdx = most.gui.uicontrol('Parent',hTab,'Style','edit','RelPosition', [200 32 130 20],'Tag','etSlmMediumRefractiveIdx');
                
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [10 64 170 20],'Tag','txObjectiveMediumRefractiveIdx','String','Objective medium refractive index','HorizontalAlignment','right');
                obj.etObjectiveMediumRefractiveIdx = most.gui.uicontrol('Parent',hTab,'Style','edit','RelPosition', [200 62 130 20],'Tag','etObjectiveMediumRefractiveIdx');
                
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [40 94 140 20],'Tag','txZeroOrderBlockRadius_mm','String','Zero order block radius [mm]','HorizontalAlignment','right');
                obj.etZeroOrderBlockRadius_mm = most.gui.uicontrol('Parent',hTab,'Style','edit','RelPosition', [200 92 130 20],'Tag','etZeroOrderBlockRadius_mm');
                
                hlp = sprintf('Magnification of the SLM onto the galvos.\nExample: The SLM is demagnified onto the galvos by a factor of 4. The value should then be set to 0.25.\nIf SLM is not paired with any galvos, set value to 1');
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [15 124 165 20],'Tag','txSlmMagnificationOntoGalvos','String','Magnification of SLM onto galvos','HorizontalAlignment','right');
                obj.etSlmMagnificationOntoGalvos = most.gui.uicontrol('Parent',hTab,'Style','edit','RelPosition', [200 122 130 20],'Tag','etSlmMagnificationOntoGalvos','TooltipString',hlp);
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [335 125 10 20],'Tag','hlpSlmMagnificationOntoGalvos','String','?','TooltipString',hlp);
        end
        
        function redraw(obj)
            obj.hResource.validateConfiguration();
            
            % basic tab
            hvDAQs  = obj.hResourceStore.filterByClass('dabs.resources.daqs.vDAQ');
            hNIRIOs = obj.hResourceStore.filter(@(hR)isa(hR,'dabs.resources.daqs.NIRIO')&&most.idioms.isValidObj(hR.hAdapterModule));
            hNIDAQs = obj.hResourceStore.filterByClass('dabs.resources.daqs.NIDAQ');
            obj.pmhDAQ.String = [{''}, hvDAQs, hNIRIOs, hNIDAQs];
            obj.pmhDAQ.pmValue = obj.hResource.hDAQ;
            obj.pmhDAQ.Enable = ~obj.hResource.mdlInitialized;
            
            obj.pmhSlm.String = [{''}, obj.hResourceStore.filterByClass('dabs.resources.devices.SLM')];
            obj.pmhSlm.pmValue = obj.hResource.hSlmDevice;
            obj.pmhSlm.Enable = ~obj.hResource.mdlInitialized;
            
            hLinScans = obj.hResourceStore.filterByClass('scanimage.components.scan2d.LinScan');
            hRggScans = obj.hResourceStore.filter(@(hR)isa(hR,'scanimage.components.scan2d.RggScan')&&~isempty(hR.yGalvo));
            obj.pmhLinScan.String = [{''}, hLinScans, hRggScans];
            obj.pmhLinScan.pmValue = obj.hResource.hLinScan;
            obj.pmhLinScan.Enable = ~obj.hResource.mdlInitialized;
            
            channelNames = arrayfun(@(chIdx)sprintf('Channel %d',chIdx),1:numel(obj.hResource.channelsInvert),'UniformOutput',false);
            channelInvert = obj.hResource.channelsInvert;
            obj.tableChannels.Data = most.idioms.horzcellcat(channelNames,num2cell(channelInvert));
            
            allShutters = obj.hResourceStore.filterByClass('dabs.resources.devices.Shutter');
            allShutterNames = cellfun(@(hR)hR.name,allShutters,'UniformOutput',false);
            shutterNames = cellfun(@(hR)hR.name,obj.hResource.hShutters,'UniformOutput',false);
            selected = ismember(allShutterNames,shutterNames);
            obj.tablehShutters.Data = most.idioms.horzcellcat(allShutterNames,num2cell(selected));
            
            allBeams = obj.hResourceStore.filterByClass('dabs.resources.devices.BeamModulator');
            allBeamNames = cellfun(@(hR)hR.name,allBeams,'UniformOutput',false);
            beamNames = cellfun(@(hR)hR.name,obj.hResource.hBeams,'UniformOutput',false);
            selected = ismember(allBeamNames,beamNames);
            obj.tablehBeams.Data = most.idioms.horzcellcat(allBeamNames,num2cell(selected));
            
            obj.etFocalLength_mm.String = num2str(obj.hResource.focalLength * 1e3);
            
            % Advanced tab
            obj.etSlmMediumRefractiveIdx.String = num2str(obj.hResource.slmMediumRefractiveIdx);
            obj.etObjectiveMediumRefractiveIdx.String = num2str(obj.hResource.objectiveMediumRefractiveIdx);
            obj.etZeroOrderBlockRadius_mm.String = num2str(obj.hResource.zeroOrderBlockRadius * 1e3);
            obj.etSlmMagnificationOntoGalvos.String = num2str(obj.hResource.slmMagnificationOntoGalvos);
        end
        
        function apply(obj)
            % basic tab
            if obj.pmhDAQ.Enable
                most.idioms.safeSetProp(obj.hResource,'hDAQ',obj.pmhDAQ.pmValue);
            end
            
            if obj.pmhSlm.Enable
                most.idioms.safeSetProp(obj.hResource,'hSlmDevice',obj.pmhSlm.pmValue);
            end
            
            if obj.pmhLinScan.Enable
                most.idioms.safeSetProp(obj.hResource,'hLinScan',obj.pmhLinScan.pmValue);
            end
            
            channelsInvert = [obj.tableChannels.Data{:,2}];
            most.idioms.safeSetProp(obj.hResource,'channelsInvert',channelsInvert);
            
            shutterNames = obj.tablehShutters.Data(:,1)';
            selected   = [obj.tablehShutters.Data{:,2}];
            shutterNames = shutterNames(selected);
            most.idioms.safeSetProp(obj.hResource,'hShutters',shutterNames);
            
            beamNames = obj.tablehBeams.Data(:,1)';
            selected   = [obj.tablehBeams.Data{:,2}];
            beamNames = beamNames(selected);
            most.idioms.safeSetProp(obj.hResource,'hBeams',beamNames);
            
            most.idioms.safeSetProp(obj.hResource,'focalLength',str2double(obj.etFocalLength_mm.String) / 1e3);
            
            % Advanced tab
            most.idioms.safeSetProp(obj.hResource,'slmMediumRefractiveIdx',str2double(obj.etSlmMediumRefractiveIdx.String));
            most.idioms.safeSetProp(obj.hResource,'objectiveMediumRefractiveIdx',str2double(obj.etObjectiveMediumRefractiveIdx.String));
            most.idioms.safeSetProp(obj.hResource,'zeroOrderBlockRadius',str2double(obj.etZeroOrderBlockRadius_mm.String) / 1e3);
            most.idioms.safeSetProp(obj.hResource,'slmMagnificationOntoGalvos',str2double(obj.etSlmMagnificationOntoGalvos.String));
            
            obj.hResource.saveMdf();
            obj.hResource.validateConfiguration();
        end
        
        function remove(obj)
            if obj.hResource.mdlInitialized
                msg = sprintf('Cannot remove %s after ScanImage is started.',obj.hResource.name);
                msgbox(msg,'Info','help');
            else
                obj.hResource.deleteAndRemoveMdfHeading();
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
