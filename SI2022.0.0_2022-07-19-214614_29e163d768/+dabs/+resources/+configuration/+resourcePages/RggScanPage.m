classdef RggScanPage < dabs.resources.configuration.ResourcePage
    properties
        pmhDAQ
        pmhResonantScanner
        pmxGalvo
        pmyGalvo
        tableChannels
        tablehFastZ
        tablehShutters
        tablehBeams
        cbExtendedRggFov
        cbKeepResonantScannerOn
        cbReverseLineRead
        
        pmAuxTrig1
        pmAuxTrig2
        pmAuxTrig3
        pmAuxTrig4
        
        pmFrameClockOut
        pmLineClockOut
        pmVolumeTriggerOut
        
        cbExternalSampleClock
        etExternalSampleClockRateMHz
        etExternalSampleClockMultiplier
        
        cbI2cEnable
        pmI2cSdaPort
        pmI2cSclPort
        etI2cAddress
        etI2cDebounce
        cbI2cStoreAsChar
        cbI2cSendAck
    end
    
    methods
        function obj = RggScanPage(hResource,hParent)
            obj@dabs.resources.configuration.ResourcePage(hResource,hParent);
        end
        
        function makePanel(obj,hParent)
            hTabGroup = uitabgroup('Parent',hParent);
            hTab = uitab('Parent',hTabGroup,'Title','Basic');
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [20 25 80 20],'Tag','txhDAQ','String','DAQ board','HorizontalAlignment','right');
                obj.pmhDAQ = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [110 22 130 20],'Tag','pmhDAQ');
                
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [0 56 100 20],'Tag','txhResonantScanner','String','Resonant Scanner','HorizontalAlignment','right');
                obj.pmhResonantScanner = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [110 52 130 20],'Tag','pmhResonantScanner');
                
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [20 86 80 20],'Tag','txxGalvo','String','X-Galvo','HorizontalAlignment','right');
                obj.pmxGalvo = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [110 82 130 20],'Tag','pmxGalvo');
                
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [20 116 80 20],'Tag','txyGalvo','String','Y-Galvo','HorizontalAlignment','right');
                obj.pmyGalvo = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [110 112 130 20],'Tag','pmyGalvo');
                
                obj.tableChannels  = most.gui.uicontrol('Parent',hTab,'Style','uitable','ColumnFormat',{'char','logical'},'ColumnEditable',[false,true],'ColumnName',{'Channel','Invert'},'ColumnWidth',{60 40},'RowName',[],'RelPosition', [260 102 110 100],'Tag','tableChannels');
                obj.tablehShutters = most.gui.uicontrol('Parent',hTab,'Style','uitable','ColumnFormat',{'char','logical'},'ColumnEditable',[false,true],'ColumnName',{'Shutter','Use'},'ColumnWidth',{80 30},'RowName',[],'RelPosition', [10 242 115 110],'Tag','tablehShutters');
                obj.tablehFastZ    = most.gui.uicontrol('Parent',hTab,'Style','uitable','ColumnFormat',{'char','logical'},'ColumnEditable',[false,true],'ColumnName',{'FastZ','Use'},'ColumnWidth',{80 30},'RowName',[],'RelPosition', [260 242 115 110],'Tag','tablehFastZ');
                obj.tablehBeams    = most.gui.uicontrol('Parent',hTab,'Style','uitable','ColumnFormat',{'char','logical'},'ColumnEditable',[false,true],'ColumnName',{'Beam','Use'},'ColumnWidth',{80 30},'RowName',[],'RelPosition', [135 242 115 110],'Tag','tablehBeams');
            
            hTab = uitab('Parent',hTabGroup,'Title','Triggers');                
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [30 63 70 30],'Tag','txAuxTrig1','String','Aux trigger 1','HorizontalAlignment','right');
                obj.pmAuxTrig1 = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [110 59 100 30],'Tag','pmAuxTrig1');
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [30 89 70 30],'Tag','txAuxTrig2','String','Aux trigger 2','HorizontalAlignment','right');
                obj.pmAuxTrig2 = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [110 84 100 30],'Tag','pmAuxTrig2');
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [30 114 70 30],'Tag','txAuxTrig3','String','Aux trigger 3','HorizontalAlignment','right');
                obj.pmAuxTrig3 = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [110 109 100 30],'Tag','pmAuxTrig3');
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [30 138 70 30],'Tag','txAuxTrig4','String','Aux trigger 4','HorizontalAlignment','right');
                obj.pmAuxTrig4 = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [110 134 100 30],'Tag','pmAuxTrig4');
                
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [10 161 90 30],'Tag','txLineClockOut','String','Frame clock out','HorizontalAlignment','right');
                obj.pmFrameClockOut = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [110 159 100 30],'Tag','pmFrameClockOut');
                
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [10 187 90 30],'Tag','txFrameClockOut','String','Line clock out','HorizontalAlignment','right');
                obj.pmLineClockOut = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [110 184 100 30],'Tag','pmLineClockOut');
                
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [10 213 90 30],'Tag','txVolumeTriggerOut','String','Volume clock out','HorizontalAlignment','right');
                obj.pmVolumeTriggerOut = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [110 209 100 30],'Tag','pmVolumeTriggerOut');
                
            hTab = uitab('Parent',hTabGroup,'Title','Advanced');
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [50 72 100 17],'Tag','txExtendedRggFov','String','Extended RGG FOV','HorizontalAlignment','right');
                obj.cbExtendedRggFov = most.gui.uicontrol('Parent',hTab,'Style','checkbox','String','','RelPosition', [160 72 20 20],'Tag','cbExtendedRggFov');
                
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [10 32 140 18],'Tag','txKeepResonantScannerOn','String','Keep resonant scanner on','HorizontalAlignment','right');
                obj.cbKeepResonantScannerOn = most.gui.uicontrol('Parent',hTab,'Style','checkbox','String','','RelPosition', [160 32 20 20],'Tag','cbKeepResonantScannerOn');
                
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [50 52 100 17],'Tag','txReverseLineRead','String','Reverse line read','HorizontalAlignment','right');
                obj.cbReverseLineRead = most.gui.uicontrol('Parent',hTab,'Style','checkbox','String','','RelPosition', [160 52 20 20],'Tag','cbReverseLineRead');
                
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [40 145 130 20],'Tag','txExternalSampleClock','String','Use external sample clock','HorizontalAlignment','right');
                obj.cbExternalSampleClock = most.gui.uicontrol('Parent',hTab,'Style','checkbox','RelPosition', [180 142 20 20],'Tag','cbExternalSampleClock');
                
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [10 165 160 20],'Tag','txExternalSampleClockRateMHz','String','External sample clock rate [MHz]','HorizontalAlignment','right');
                obj.etExternalSampleClockRateMHz = most.gui.uicontrol('Parent',hTab,'Style','edit','RelPosition', [180 162 70 20],'Tag','etExternalSampleClockRateMHz');
                
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [10 187 160 20],'Tag','txExternalSampleClockMultiplier','String','External sample clock multiplier','HorizontalAlignment','right');
                obj.etExternalSampleClockMultiplier = most.gui.uicontrol('Parent',hTab,'Style','edit','RelPosition', [180 185 70 20],'Tag','etExternalSampleClockMultiplier'); 
                
            hTab = uitab('Parent',hTabGroup,'Title',['I' most.constants.Unicode.superscript_two 'C']);
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [20 34 160 20],'Tag','txI2cEnable','String','I2C Enable','HorizontalAlignment','right');
                obj.cbI2cEnable = most.gui.uicontrol('Parent',hTab,'Style','checkbox','String','','RelPosition', [190 30.3333333333333 20 20],'Tag','cbI2cEnable');
                
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [110 70.3333333333333 70 30],'Tag','txI2cSdaPort','String','SDA Port','HorizontalAlignment','right');
                obj.pmI2cSdaPort = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [190 57.3333333333333 130 20],'Tag','pmI2cSdaPort');
                
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [110 91.3333333333333 70 30],'Tag','txI2cSclPort','String','SCL Port','HorizontalAlignment','right');
                obj.pmI2cSclPort = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [190 78.3333333333333 130 20],'Tag','pmI2cSclPort');
                
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [20 106.333333333333 160 20],'Tag','txI2cAddress','String','vDAQ I2C Address','HorizontalAlignment','right');                obj.etI2cAddress = most.gui.uicontrol('Parent',hTab,'Style','edit','RelPosition', [190 103.333333333333 70 20],'Tag','etI2cAddress');
                
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [20 127.333333333333 160 20],'Tag','txI2cDebounce','String','I2C Debounce Time (ns)','HorizontalAlignment','right');
                obj.etI2cDebounce = most.gui.uicontrol('Parent',hTab,'Style','edit','RelPosition', [190 125.333333333333 70 20],'Tag','etI2cDebounce');
                
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [-20 170.333333333333 200 17],'Tag','txI2cStoreAsChar','String','Store I2C data as ASCII characters','HorizontalAlignment','right');
                obj.cbI2cStoreAsChar = most.gui.uicontrol('Parent',hTab,'Style','checkbox','String','','RelPosition', [190 169.333333333333 20 20],'Tag','cbI2cStoreAsChar');
                                
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [80 152.333333333333 100 17],'Tag','txI2cSendAck','String','Send Ack','HorizontalAlignment','right');
                obj.cbI2cSendAck = most.gui.uicontrol('Parent',hTab,'Style','checkbox','String','','RelPosition', [190 151.333333333333 20 20],'Tag','cbI2cSendAck');
        end
        
        function redraw(obj)
            obj.hResource.validateConfiguration();
            
            % basic tab
            obj.pmhDAQ.String = [{''}, obj.hResourceStore.filterByClass('dabs.resources.daqs.vDAQ')];
            obj.pmhDAQ.pmValue = obj.hResource.hDAQ;
            obj.pmhDAQ.Enable = ~obj.hResource.mdlInitialized;
            
            obj.pmhResonantScanner.String = [{''}, obj.hResourceStore.filterByClass('dabs.resources.devices.SyncedScanner')];
            obj.pmhResonantScanner.pmValue = obj.hResource.hResonantScanner;
            obj.pmhResonantScanner.Enable = ~obj.hResource.mdlInitialized;
            
            obj.pmxGalvo.String = [{''}, obj.hResourceStore.filterByClass('dabs.resources.devices.GalvoAnalog')];
            obj.pmxGalvo.pmValue = obj.hResource.xGalvo;
            obj.pmxGalvo.Enable = ~obj.hResource.mdlInitialized;
            
            obj.pmyGalvo.String = [{''}, obj.hResourceStore.filterByClass('dabs.resources.devices.GalvoAnalog')];
            obj.pmyGalvo.pmValue = obj.hResource.yGalvo;
            obj.pmyGalvo.Enable = ~obj.hResource.mdlInitialized;
            
            channelNames = arrayfun(@(chIdx)sprintf('Channel %d',chIdx),1:obj.hResource.physicalChannelsAvailable,'UniformOutput',false);
            channelInvert = obj.hResource.channelsInvert;
            obj.tableChannels.Data = most.idioms.horzcellcat(channelNames,num2cell(channelInvert));
            
            allFastZs = obj.hResourceStore.filterByClass('dabs.resources.devices.FastZAnalog');
            allFastZNames = cellfun(@(hR)hR.name,allFastZs,'UniformOutput',false);
            fastZNames = cellfun(@(hR)hR.name,obj.hResource.hFastZs,'UniformOutput',false);
            selected = ismember(allFastZNames,fastZNames);
            obj.tablehFastZ.Data = most.idioms.horzcellcat(allFastZNames,num2cell(selected));
            
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
            
            % triggers tab
            triggerInputOptions = [{''}, obj.hResourceStore.filter(@(hR)isa(hR,'dabs.resources.ios.DI')&&isa(hR.hDAQ,'dabs.resources.daqs.vDAQ'))];
            obj.pmAuxTrig1.String = triggerInputOptions;
            obj.pmAuxTrig1.pmValue = obj.hResource.auxTrigger1In;
            obj.pmAuxTrig1.Enable = scanimage.SI.PREMIUM;
            obj.pmAuxTrig2.String = triggerInputOptions;
            obj.pmAuxTrig2.pmValue = obj.hResource.auxTrigger2In;
            obj.pmAuxTrig2.Enable = scanimage.SI.PREMIUM;
            obj.pmAuxTrig3.String = triggerInputOptions;
            obj.pmAuxTrig3.pmValue = obj.hResource.auxTrigger3In;
            obj.pmAuxTrig3.Enable = scanimage.SI.PREMIUM;
            obj.pmAuxTrig4.String = triggerInputOptions;
            obj.pmAuxTrig4.pmValue = obj.hResource.auxTrigger4In;
            obj.pmAuxTrig4.Enable = scanimage.SI.PREMIUM;
            
            triggerOutputOptions = [{''}, obj.hResourceStore.filter(@(hR)isa(hR,'dabs.resources.ios.DO')&&isa(hR.hDAQ,'dabs.resources.daqs.vDAQ'))];
            obj.pmFrameClockOut.String = triggerOutputOptions;
            obj.pmFrameClockOut.pmValue = obj.hResource.frameClockOut;
            obj.pmLineClockOut.String = triggerOutputOptions;
            obj.pmLineClockOut.pmValue = obj.hResource.lineClockOut;
            obj.pmVolumeTriggerOut.String = triggerOutputOptions;
            obj.pmVolumeTriggerOut.pmValue = obj.hResource.volumeTriggerOut;
            
            % advanced tab
            obj.cbExtendedRggFov.Value = obj.hResource.extendedRggFov;
            obj.cbExtendedRggFov.Enable = scanimage.SI.PREMIUM;
            obj.cbKeepResonantScannerOn.Value = obj.hResource.keepResonantScannerOn;
            obj.cbReverseLineRead.Value = obj.hResource.reverseLineRead;
            
            obj.cbExternalSampleClock.Value = obj.hResource.externalSampleClock;
            obj.cbExternalSampleClock.Enable = ~obj.hResource.mdlInitialized;
            obj.etExternalSampleClockRateMHz.String = num2str( obj.hResource.externalSampleClockRate/1e6 );
            obj.etExternalSampleClockRateMHz.Enable = ~obj.hResource.mdlInitialized;
            obj.etExternalSampleClockMultiplier.String = num2str( obj.hResource.externalSampleClockMultiplier );
            obj.etExternalSampleClockMultiplier.Enable = ~obj.hResource.mdlInitialized;
            
            % I2C Tab
            obj.cbI2cEnable.Value = obj.hResource.i2cEnable;
            
            hDIOs = obj.hResourceStore.filter(@(hR)isa(hR,'dabs.resources.ios.DIO')&&isa(hR.hDAQ,'dabs.resources.daqs.vDAQ'));
            obj.pmI2cSdaPort.String = [{''}, hDIOs];
            obj.pmI2cSdaPort.pmValue = obj.hResource.i2cSdaPort;
            obj.pmI2cSdaPort.Enable = scanimage.SI.PREMIUM;
            
            obj.pmI2cSclPort.String = [{''}, hDIOs];
            obj.pmI2cSclPort.pmValue = obj.hResource.i2cSclPort;
            obj.pmI2cSclPort.Enable = scanimage.SI.PREMIUM;
            
            obj.etI2cAddress.String = num2str(obj.hResource.i2cAddress);
            obj.etI2cAddress.Enable = scanimage.SI.PREMIUM;
            obj.etI2cDebounce.String = num2str(obj.hResource.i2cDebounce*1e9);
            obj.etI2cDebounce.Enable = scanimage.SI.PREMIUM;
            obj.cbI2cStoreAsChar.Value = obj.hResource.i2cStoreAsChar;
            obj.cbI2cStoreAsChar.Enable = scanimage.SI.PREMIUM;
            obj.cbI2cSendAck.Value = obj.hResource.i2cSendAck;
            obj.cbI2cSendAck.Enable = scanimage.SI.PREMIUM;
        end
        
        function apply(obj)
            % basic tab
            most.idioms.safeSetProp(obj.hResource,'hDAQ',obj.pmhDAQ.pmValue);
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
            
            % triggers tab
            most.idioms.safeSetProp(obj.hResource,'auxTrigger1In',obj.pmAuxTrig1.pmValue);
            most.idioms.safeSetProp(obj.hResource,'auxTrigger2In',obj.pmAuxTrig2.pmValue);
            most.idioms.safeSetProp(obj.hResource,'auxTrigger3In',obj.pmAuxTrig3.pmValue);
            most.idioms.safeSetProp(obj.hResource,'auxTrigger4In',obj.pmAuxTrig4.pmValue);
            
            most.idioms.safeSetProp(obj.hResource,'frameClockOut',obj.pmFrameClockOut.pmValue);
            most.idioms.safeSetProp(obj.hResource,'lineClockOut',obj.pmLineClockOut.pmValue);
            most.idioms.safeSetProp(obj.hResource,'volumeTriggerOut',obj.pmVolumeTriggerOut.pmValue);
            
            % advanced tab
            most.idioms.safeSetProp(obj.hResource,'extendedRggFov',obj.cbExtendedRggFov.Value);
            most.idioms.safeSetProp(obj.hResource,'keepResonantScannerOn',obj.cbKeepResonantScannerOn.Value);
            most.idioms.safeSetProp(obj.hResource,'reverseLineRead',obj.cbReverseLineRead.Value);
            
            most.idioms.safeSetProp(obj.hResource,'externalSampleClock',obj.cbExternalSampleClock.Value);
            most.idioms.safeSetProp(obj.hResource,'externalSampleClockRate',str2double(obj.etExternalSampleClockRateMHz.String)*1e6);
            most.idioms.safeSetProp(obj.hResource,'externalSampleClockMultiplier',str2double(obj.etExternalSampleClockMultiplier.String));
            
            %I2C tab
            most.idioms.safeSetProp(obj.hResource,'i2cEnable',obj.cbI2cEnable.Value);
            most.idioms.safeSetProp(obj.hResource,'i2cSdaPort',obj.pmI2cSdaPort.pmValue);
            most.idioms.safeSetProp(obj.hResource,'i2cSclPort',obj.pmI2cSclPort.pmValue);
            most.idioms.safeSetProp(obj.hResource,'i2cAddress',uint8(str2double(obj.etI2cAddress.String)));
            most.idioms.safeSetProp(obj.hResource,'i2cDebounce',str2double(obj.etI2cDebounce.String)*1e-9);
            most.idioms.safeSetProp(obj.hResource,'i2cStoreAsChar',obj.cbI2cStoreAsChar.Value);
            most.idioms.safeSetProp(obj.hResource,'i2cSendAck',obj.cbI2cSendAck.Value);
            
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
