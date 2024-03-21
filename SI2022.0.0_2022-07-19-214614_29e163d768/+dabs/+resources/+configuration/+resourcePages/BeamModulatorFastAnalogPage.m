classdef BeamModulatorFastAnalogPage < dabs.resources.configuration.ResourcePage
    properties
        pmhAOControl
        pmhAIFeedback
        etPowerFractionLimit
        etOutputRange_V1
        etOutputRange_V2
        cbFeedbackUsesRejectedLight
        tablehShutters
        
        etPowerRange_W0
        etPowerRange_W1
        
        pmhBeamClockIn
        pmhFrameClockIn
        pmhReferenceClockIn
        etReferenceClockRateMHz
        
        etCalibrationNumPoints
        etCalibrationNumRepeats
        etCalibrationAverageSamples
        etCalibrationSettlingTime_ms
        etCalibrationFlybackTime_ms
    end
    
    methods
        function obj = BeamModulatorFastAnalogPage(hResource,hParent)
            obj@dabs.resources.configuration.ResourcePage(hResource,hParent);
        end
        
        function makePanel(obj,hParent)
            hTabGroup = uitabgroup('Parent',hParent);
            hTab = uitab('Parent',hTabGroup,'Title','Basic');
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [30 25 120 20],'Tag','txhAOControl','String','Control Channel','HorizontalAlignment','right');
                obj.pmhAOControl = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [160 22 120 20],'Tag','pmhAOControl');

                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [176 46 30 20],'Tag','txMin','String','Min','HorizontalAlignment','left');
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [221 46 30 20], 'Tag','txMax','String','Max','HorizontalAlignment','left');
                
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [0 63 150 20],'Tag','txoutputRange_V','String','Control output [Volt]','HorizontalAlignment','right');
                obj.etOutputRange_V1 = most.gui.uicontrol('Parent',hTab,'Style','edit','RelPosition', [160 62 50 20],'Tag','etOutputRange_V1');
                obj.etOutputRange_V2 = most.gui.uicontrol('Parent',hTab,'Style','edit','RelPosition', [211 62 50 20],'Tag','etOutputRange_V2');

                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [0 84 150 20],'Tag','txpowerRange_W','String','Power output [W]','HorizontalAlignment','right');
                obj.etPowerRange_W0 = most.gui.uicontrol('Parent',hTab,'Style','edit','RelPosition', [160 84 50 20],'Tag','etPowerRange_W0');
                obj.etPowerRange_W1 = most.gui.uicontrol('Parent',hTab,'Style','edit','RelPosition', [211 84 50 20],'Tag','etPowerRange_W1');

                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [0 112 150 20],'Tag','txFractionLimit','String','Beam output limit [%]','HorizontalAlignment','right');
                obj.etPowerFractionLimit = most.gui.uicontrol('Parent',hTab,'Style','edit','RelPosition', [160 111 120 20],'Tag','etPowerFractionLimit');

                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [10 140 140 20],'Tag','txhAIFeedback','String','Feedback Channel (optional)','HorizontalAlignment','right');
                obj.pmhAIFeedback = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [160 138 120 20],'Tag','pmhAIFeedback');

                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [0 163 150 20],'Tag','txFeedbackUsesRejectedLight','String','Feedback uses rejected light','HorizontalAlignment','right');
                obj.cbFeedbackUsesRejectedLight = most.gui.uicontrol('Parent',hTab,'Style','checkbox','RelPosition', [160 161 120 20],'Tag','cbFeedbackUsesRejectedLight','String','');            

                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [0 187 150 20],'Tag','txhCalibrationOpenShutters','String','Open shutters for calibration','HorizontalAlignment','right');            
                obj.tablehShutters = most.gui.uicontrol('Parent',hTab,'Style','uitable','ColumnFormat',{'char','logical'},'ColumnEditable',[false,true],'ColumnName',{'Shutter','Open'},'ColumnWidth',{100 40},'RowName',[],'RelPosition', [160 254 160 90],'Tag','tablehShutters');
            
            hTab = uitab('Parent',hTabGroup,'Title','Calibration Settings');
                tooltip = sprintf('The analog output range is subdivided into N calibration points and for each point, the feedback of the photodiode is measured.');
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [10 42.3333333333333 200 20],'Tag','txCalibrationNumPoints','String','Number of calibration points','HorizontalAlignment','right');
                obj.etCalibrationNumPoints = most.gui.uicontrol('Parent',hTab,'Style','edit','RelPosition', [220 39.3333333333333 120 20],'Tag','etCalibrationNumPoints','TooltipString',tooltip);
                
                tooltip = sprintf('For each calibration point, N analog feedback samples are averaged to reduce noise.');
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [10 71.3333333333333 200 20],'Tag','txCalibrationAverageSamples','String','Average N samples','HorizontalAlignment','right');
                obj.etCalibrationAverageSamples = most.gui.uicontrol('Parent',hTab,'Style','edit','RelPosition', [220 69.3333333333333 120 20],'Tag','etCalibrationAverageSamples','TooltipString',tooltip);
                
                tooltip = sprintf('The calibration is repeated N times. The final calibration result is the average of all runs.');
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [10 102.333333333333 200 20],'Tag','txCalibrationNumRepeats','String','Number of calibration runs','HorizontalAlignment','right');
                obj.etCalibrationNumRepeats = most.gui.uicontrol('Parent',hTab,'Style','edit','RelPosition', [220 99.3333333333333 120 20],'Tag','etCalibrationNumRepeats','TooltipString',tooltip);
                
                tooltip = sprintf('After a voltage is applied to the modulator, wait N milliseconds before the feedback is measured.');
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [10 131.333333333333 200 20],'Tag','txCalibrationSettlingTime_s','String','Modulator settling time [ms]','HorizontalAlignment','right');
                obj.etCalibrationSettlingTime_ms = most.gui.uicontrol('Parent',hTab,'Style','edit','RelPosition', [220 129.333333333333 120 20],'Tag','etCalibrationSettlingTime_ms','TooltipString',tooltip);

                tooltip = sprintf('Pause between calibration runs. This can help to reduce any hysteresis in the modulator.');
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [10 159.333333333333 200 20],'Tag','txCalibrationFlybackTime_s','String','Pause between calibration runs [ms]','HorizontalAlignment','right');
                obj.etCalibrationFlybackTime_ms = most.gui.uicontrol('Parent',hTab,'Style','edit','RelPosition', [220 159.333333333333 120 20],'Tag','etCalibrationFlybackTime_ms','TooltipString',tooltip);
            
            hTab = uitab('Parent',hTabGroup,'Title','Advanced');
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [0 40 140 20],'Tag','txhBeamClockIn','String','Beam clock input','HorizontalAlignment','right');
                obj.pmhBeamClockIn = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [150 27.3333333333333 120 10],'Tag','pmhBeamClockIn');
                
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [0 66 140 20],'Tag','txhFrameClockIn','String','Frame clock input','HorizontalAlignment','right');
                obj.pmhFrameClockIn = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [150 62 120 20],'Tag','pmhFrameClockIn');
                
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [0 90 140 20],'Tag','txhReferenceClockIn','String','Reference clock input','HorizontalAlignment','right');
                obj.pmhReferenceClockIn = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [150 92 120 25],'Tag','pmhReferenceClockIn');
                
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [0 114 140 20],'Tag','txReferenceClockRateMHz','String','Reference clock Rate [MHz]','HorizontalAlignment','right');
                obj.etReferenceClockRateMHz = most.gui.uicontrol('Parent',hTab,'Style','edit','RelPosition', [150 112 120 20],'Tag','etReferenceClockRateMHz');
            end
        
        function redraw(obj)
            % Basic Tab
            hAOs = obj.hResourceStore.filterByClass('dabs.resources.ios.AO');
            obj.pmhAOControl.String = [{''}, hAOs];
            obj.pmhAOControl.pmValue = obj.hResource.hAOControl;
            
            hAIs = obj.hResourceStore.filterByClass('dabs.resources.ios.AI');
            obj.pmhAIFeedback.String = [{''}, hAIs];
            obj.pmhAIFeedback.pmValue = obj.hResource.hAIFeedback;
            
            obj.etOutputRange_V1.String = num2str(obj.hResource.outputRange_V(1));
            obj.etOutputRange_V2.String = num2str(obj.hResource.outputRange_V(2));
            
            powerLut = obj.hResource.convertPowerFraction2PowerWatt([0,1]);
            obj.etPowerRange_W0.String = most.idioms.ifthenelse(isnan(powerLut(1)),'',num2str(powerLut(1)));
            obj.etPowerRange_W1.String = most.idioms.ifthenelse(isnan(powerLut(2)),'',num2str(powerLut(2)));
            
            obj.etPowerFractionLimit.String = num2str(obj.hResource.powerFractionLimit*100);
            
            obj.cbFeedbackUsesRejectedLight.Value = obj.hResource.feedbackUsesRejectedLight;
                        
            allShutters = obj.hResourceStore.filterByClass('dabs.resources.devices.Shutter');
            allShutterNames = cellfun(@(hR)hR.name,allShutters,'UniformOutput',false);
            shutterNames = cellfun(@(hR)hR.name,obj.hResource.hCalibrationOpenShutters,'UniformOutput',false);
            selected = ismember(allShutterNames,shutterNames);
            obj.tablehShutters.Data = most.idioms.horzcellcat(allShutterNames,num2cell(selected));
            
            % Advanced Tab
            isvDAQ = most.idioms.isValidObj(obj.hResource.hAOControl) && isa(obj.hResource.hAOControl.hDAQ,'dabs.resources.daqs.vDAQ');
            
            hPFIs = obj.hResourceStore.filterByClass(?dabs.resources.ios.PFI);
            obj.pmhBeamClockIn.String = [{''}, hPFIs];
            obj.pmhBeamClockIn.pmValue = obj.hResource.hModifiedLineClockIn;
            obj.pmhBeamClockIn.Enable = ~isvDAQ;
            
            obj.pmhFrameClockIn.String = [{''}, hPFIs];
            obj.pmhFrameClockIn.pmValue = obj.hResource.hFrameClockIn;
            obj.pmhFrameClockIn.Enable = ~isvDAQ;
            
            obj.pmhReferenceClockIn.String = [{''}, hPFIs];
            obj.pmhReferenceClockIn.pmValue = obj.hResource.hReferenceClockIn;
            obj.pmhReferenceClockIn.Enable = ~isvDAQ;
            
            obj.etReferenceClockRateMHz.String = num2str(obj.hResource.referenceClockRate / 1e6);
            obj.etReferenceClockRateMHz.Enable = ~isvDAQ;
            
            % Calibration Tab
            obj.etCalibrationNumPoints.String      = obj.hResource.calibrationNumPoints;
            obj.etCalibrationNumRepeats.String     = obj.hResource.calibrationNumRepeats;
            obj.etCalibrationAverageSamples.String = obj.hResource.calibrationAverageSamples;
            obj.etCalibrationSettlingTime_ms.String = obj.hResource.calibrationSettlingTime_s * 1e3;
            obj.etCalibrationFlybackTime_ms.String  = obj.hResource.calibrationFlybackTime_s *1e3;
        end
        
        function apply(obj)
            most.idioms.safeSetProp(obj.hResource,'hAOControl',obj.pmhAOControl.String{obj.pmhAOControl.Value});
            most.idioms.safeSetProp(obj.hResource,'hAIFeedback',obj.pmhAIFeedback.String{obj.pmhAIFeedback.Value});
            
            most.idioms.safeSetProp(obj.hResource,'outputRange_V',[str2double(obj.etOutputRange_V1.String) str2double(obj.etOutputRange_V2.String)]);
            most.idioms.safeSetProp(obj.hResource,'powerFractionLimit',str2double(obj.etPowerFractionLimit.String)/100);
            
            powerLut = [0 str2double(obj.etPowerRange_W0.String);
                        1 str2double(obj.etPowerRange_W1.String)];
                    
            if any(isnan(powerLut(:)))
                obj.hResource.powerFraction2PowerWattLut = [];
            else
                most.idioms.safeSetProp(obj.hResource,'powerFraction2PowerWattLut',powerLut);
            end
            
            most.idioms.safeSetProp(obj.hResource,'feedbackUsesRejectedLight',obj.cbFeedbackUsesRejectedLight.Value);
            
            shutterNames = obj.tablehShutters.Data(:,1)';
            selected   = [obj.tablehShutters.Data{:,2}];
            shutterNames = shutterNames(selected);
            most.idioms.safeSetProp(obj.hResource,'hCalibrationOpenShutters',shutterNames);
            
            most.idioms.safeSetProp(obj.hResource,'hModifiedLineClockIn',obj.pmhBeamClockIn.pmValue);
            most.idioms.safeSetProp(obj.hResource,'hFrameClockIn',obj.pmhFrameClockIn.pmValue);
            most.idioms.safeSetProp(obj.hResource,'hReferenceClockIn',obj.pmhReferenceClockIn.pmValue);
            most.idioms.safeSetProp(obj.hResource,'referenceClockRate',str2double(obj.etReferenceClockRateMHz.String)*1e6);
            
            most.idioms.safeSetProp(obj.hResource,'calibrationNumPoints',str2double(obj.etCalibrationNumPoints.String));
            most.idioms.safeSetProp(obj.hResource,'calibrationNumRepeats',str2double(obj.etCalibrationNumRepeats.String));
            most.idioms.safeSetProp(obj.hResource,'calibrationAverageSamples',str2double(obj.etCalibrationAverageSamples.String));
            most.idioms.safeSetProp(obj.hResource,'calibrationSettlingTime_s',str2double(obj.etCalibrationSettlingTime_ms.String) / 1e3);
            most.idioms.safeSetProp(obj.hResource,'calibrationFlybackTime_s',str2double(obj.etCalibrationFlybackTime_ms.String) / 1e3);
            
            obj.hResource.saveMdf();
            obj.hResource.reinit();
        end
        
        function remove(obj)
            obj.hResource.deleteAndRemoveMdfHeading();
        end
        
        function clearShutterSelection(obj)
            obj.lbhCalibrationOpenShutters.Value = [];
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
