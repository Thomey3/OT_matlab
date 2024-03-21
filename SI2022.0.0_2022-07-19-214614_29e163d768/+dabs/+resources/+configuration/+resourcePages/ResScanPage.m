classdef ResScanPage < dabs.resources.configuration.ResourcePage
    properties
        pmhDAQAcq
        pmhDAQAux
        pmhResonantScanner
        pmxGalvo
        pmyGalvo
        tableChannels
        tablehFastZ
        tablehShutters
        tablehBeams
        pmLaserTriggerPort
        cbAuxTriggersEnable
        cbExtendedRggFov
        cbKeepResonantScannerOn
        cbReverseLineRead
        cbExternalSampleClock
        etExternalSampleClockRateMHz
    end
    
    methods
        function obj = ResScanPage(hResource,hParent)
            obj@dabs.resources.configuration.ResourcePage(hResource,hParent);
        end
        
        function makePanel(obj,hParent)
            hTabGroup = uitabgroup('Parent',hParent);
            hTab = uitab('Parent',hTabGroup,'Title','Basic');
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [10 32 90 26],'Tag','txhDAQAcq','String','Acquisition board','HorizontalAlignment','right');
                obj.pmhDAQAcq = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [110 22 130 20],'Tag','pmhDAQAcq');
                
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [10 52 90 20],'Tag','txhDAQAux','String','Digital IO board','HorizontalAlignment','right');
                obj.pmhDAQAux = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [110 52 130 25],'Tag','pmhDAQAux');
                
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [0 82 100 26],'Tag','txhResonantScanner','String','Resonant Scanner','HorizontalAlignment','right');
                obj.pmhResonantScanner = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [110 72 130 20],'Tag','pmhResonantScanner');
                
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [20 112 80 31],'Tag','txxGalvo','String','X-Galvo','HorizontalAlignment','right');
                obj.pmxGalvo = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [110 102 130 25],'Tag','pmxGalvo');
                
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [20 132 80 26],'Tag','txyGalvo','String','Y-Galvo','HorizontalAlignment','right');
                obj.pmyGalvo = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [110 132 130 30],'Tag','pmyGalvo');
                
                obj.tableChannels  = most.gui.uicontrol('Parent',hTab,'Style','uitable','ColumnFormat',{'char','logical'},'ColumnEditable',[false,true],'ColumnName',{'Channel','Invert'},'ColumnWidth',{60 40},'RowName',[],'RelPosition', [260 102 110 100],'Tag','tableChannels');
                obj.tablehShutters = most.gui.uicontrol('Parent',hTab,'Style','uitable','ColumnFormat',{'char','logical'},'ColumnEditable',[false,true],'ColumnName',{'Shutter','Use'},'ColumnWidth',{80 30},'RowName',[],'RelPosition', [10 252 115 110],'Tag','tablehShutters');
                obj.tablehFastZ    = most.gui.uicontrol('Parent',hTab,'Style','uitable','ColumnFormat',{'char','logical'},'ColumnEditable',[false,true],'ColumnName',{'FastZ','Use'},'ColumnWidth',{80 30},'RowName',[],'RelPosition', [260 252 115 110],'Tag','tablehFastZ');
                obj.tablehBeams    = most.gui.uicontrol('Parent',hTab,'Style','uitable','ColumnFormat',{'char','logical'},'ColumnEditable',[false,true],'ColumnName',{'Beam','Use'},'ColumnWidth',{80 30},'RowName',[],'RelPosition', [140 252 115 110],'Tag','tablehBeams');
            
            hTab = uitab('Parent',hTabGroup,'Title','Advanced');   
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [20 32 90 26],'Tag','txLaserTriggerPort','String','Laser trigger in','HorizontalAlignment','right');
                obj.pmLaserTriggerPort = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [120 22 130 20],'Tag','pmLaserTriggerPort');
                
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [50 55 120 20],'Tag','txAuxTriggersEnable','String','Enable AUX triggers','HorizontalAlignment','right');
                obj.cbAuxTriggersEnable = most.gui.uicontrol('Parent',hTab,'Style','checkbox','RelPosition', [180 52 20 20],'Tag','cbAuxTriggersEnable');
                
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [50 75 120 20],'Tag','txExtendedRggFov','String','Extended RGG FOV','HorizontalAlignment','right');
                obj.cbExtendedRggFov = most.gui.uicontrol('Parent',hTab,'Style','checkbox','RelPosition', [180 72 20 20],'Tag','cbExtendedRggFov');                
                
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [10 95 160 20],'Tag','txKeepResonantScannerOn','String','Keep resonant scanner on','HorizontalAlignment','right');
                obj.cbKeepResonantScannerOn = most.gui.uicontrol('Parent',hTab,'Style','checkbox','RelPosition', [180 92 20 20],'Tag','cbKeepResonantScannerOn');                
                
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [50 115 120 20],'Tag','txReverseLineRead','String','Reverse line read','HorizontalAlignment','right');
                obj.cbReverseLineRead = most.gui.uicontrol('Parent',hTab,'Style','checkbox','RelPosition', [180 112 20 20],'Tag','cbReverseLineRead');                
                
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [40 145 130 20],'Tag','txExternalSampleClock','String','Use external sample clock','HorizontalAlignment','right');
                obj.cbExternalSampleClock = most.gui.uicontrol('Parent',hTab,'Style','checkbox','RelPosition', [180 142 20 20],'Tag','cbExternalSampleClock');
                
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [10 165 160 20],'Tag','txExternalSampleClockRateMHz','String','External sample clock rate [MHz]','HorizontalAlignment','right');
                obj.etExternalSampleClockRateMHz = most.gui.uicontrol('Parent',hTab,'Style','edit','RelPosition', [180 162 70 20],'Tag','etExternalSampleClockRateMHz'); 
        end
        
        function redraw(obj)
            obj.hResource.validateConfiguration();
            
            hFlexRIOs = obj.hResourceStore.filter(@(hR)isa(hR,'dabs.resources.daqs.NIRIO')&&most.idioms.isValidObj(hR.hAdapterModule));
            obj.pmhDAQAcq.String = [{''}, hFlexRIOs];
            obj.pmhDAQAcq.pmValue = obj.hResource.hDAQAcq;
            obj.pmhDAQAcq.Enable = ~obj.hResource.mdlInitialized;
            
            obj.pmhDAQAux.String = [{''}, obj.hResourceStore.filterByClass('dabs.resources.daqs.NIDAQ')];
            obj.pmhDAQAux.pmValue = obj.hResource.hDAQAux;
            obj.pmhDAQAux.Enable = ~obj.hResource.mdlInitialized;
            
            obj.pmhResonantScanner.String = [{''}, obj.hResourceStore.filterByClass('dabs.resources.devices.SyncedScanner')];
            obj.pmhResonantScanner.pmValue = obj.hResource.hResonantScanner;
            obj.pmhResonantScanner.Enable = ~obj.hResource.mdlInitialized;
            
            obj.pmxGalvo.String = [{''}, obj.hResourceStore.filterByClass('dabs.resources.devices.GalvoAnalog')];
            obj.pmxGalvo.pmValue = obj.hResource.xGalvo;
            obj.pmxGalvo.Enable = ~obj.hResource.mdlInitialized && scanimage.SI.PREMIUM;
            
            obj.pmyGalvo.String = [{''}, obj.hResourceStore.filterByClass('dabs.resources.devices.GalvoAnalog')];
            obj.pmyGalvo.pmValue = obj.hResource.yGalvo;
            obj.pmyGalvo.Enable = ~obj.hResource.mdlInitialized;
            
            channelNames = arrayfun(@(chIdx)sprintf('Channel %d',chIdx),1:numel(obj.hResource.channelsInvert),'UniformOutput',false);
            channelInvert = obj.hResource.channelsInvert;
            obj.tableChannels.Data = most.idioms.horzcellcat(channelNames,num2cell(channelInvert));
            
            allFastZs = obj.hResourceStore.filterByClass('dabs.resources.devices.FastZAnalog');
            allFastZNames = cellfun(@(hR)hR.name,allFastZs,'UniformOutput',false);
            fastZNames = cellfun(@(hR)hR.name,obj.hResource.hFastZs,'UniformOutput',false);
            selected = ismember(allFastZNames,fastZNames);
            obj.tablehFastZ.Data = most.idioms.horzcellcat(allFastZNames,num2cell(selected));
            obj.tablehFastZ.Enable = ~obj.hResource.mdlInitialized;
            
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
            obj.tablehBeams.Enable = ~obj.hResource.mdlInitialized;
            
            % Advanced panel
            obj.pmLaserTriggerPort.String = {'','DIO0.0','DIO0.1','DIO0.2','DIO0.3'};
            obj.pmLaserTriggerPort.pmValue = obj.hResource.laserTriggerPort;
            obj.pmLaserTriggerPort.Enable = scanimage.SI.PREMIUM;
            
            obj.cbAuxTriggersEnable.Value = obj.hResource.auxTriggersEnable;
            obj.cbAuxTriggersEnable.Enable = scanimage.SI.PREMIUM;
            
            obj.cbExtendedRggFov.Value = obj.hResource.extendedRggFov;
            obj.cbExtendedRggFov.Enable = scanimage.SI.PREMIUM;
            
            obj.cbKeepResonantScannerOn.Value = obj.hResource.keepResonantScannerOn;
            
            obj.cbReverseLineRead.Value = obj.hResource.reverseLineRead;
            
            obj.cbExternalSampleClock.Value = obj.hResource.externalSampleClock;
            obj.cbExternalSampleClock.Enable = ~obj.hResource.mdlInitialized;
            obj.etExternalSampleClockRateMHz.String = num2str( obj.hResource.externalSampleClockRate/1e6 );
            obj.etExternalSampleClockRateMHz.Enable = ~obj.hResource.mdlInitialized;
        end
        
        function apply(obj)
            most.idioms.safeSetProp(obj.hResource,'hDAQAcq',obj.pmhDAQAcq.pmValue);
            most.idioms.safeSetProp(obj.hResource,'hDAQAux',obj.pmhDAQAux.pmValue);
            most.idioms.safeSetProp(obj.hResource,'hResonantScanner',obj.pmhResonantScanner.pmValue);
            most.idioms.safeSetProp(obj.hResource,'xGalvo',obj.pmxGalvo.pmValue);
            most.idioms.safeSetProp(obj.hResource,'yGalvo',obj.pmyGalvo.pmValue);
            
            channelsInvert = [obj.tableChannels.Data{:,2}];
            most.idioms.safeSetProp(obj.hResource,'channelsInvert',channelsInvert);
            
            fastZNames = obj.tablehFastZ.Data(:,1)';
            selected   = [obj.tablehFastZ.Data{:,2}];
            fastZNames = fastZNames(selected);
            most.idioms.safeSetProp(obj.hResource,'hFastZs',fastZNames);
            
            shutterNames = obj.tablehShutters.Data(:,1)';
            selected   = [obj.tablehShutters.Data{:,2}];
            shutterNames = shutterNames(selected);
            most.idioms.safeSetProp(obj.hResource,'hShutters',shutterNames);
            
            beamNames = obj.tablehBeams.Data(:,1)';
            selected   = [obj.tablehBeams.Data{:,2}];
            beamNames = beamNames(selected);
            most.idioms.safeSetProp(obj.hResource,'hBeams',beamNames);
            
            most.idioms.safeSetProp(obj.hResource,'laserTriggerPort',obj.pmLaserTriggerPort.pmValue);
            most.idioms.safeSetProp(obj.hResource,'auxTriggersEnable',obj.cbAuxTriggersEnable.Value);
            most.idioms.safeSetProp(obj.hResource,'extendedRggFov',obj.cbExtendedRggFov.Value);
            most.idioms.safeSetProp(obj.hResource,'keepResonantScannerOn',obj.cbKeepResonantScannerOn.Value);
            most.idioms.safeSetProp(obj.hResource,'reverseLineRead',obj.cbReverseLineRead.Value);
            
            most.idioms.safeSetProp(obj.hResource,'externalSampleClock',obj.cbExternalSampleClock.Value);
            most.idioms.safeSetProp(obj.hResource,'externalSampleClockRate',str2double(obj.etExternalSampleClockRateMHz.String)*1e6);            
            
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
