classdef MotorizedHalfWavePlatePage < dabs.resources.configuration.ResourcePage
    properties
        pmhMotor
        pmAxis
        pmhAIFeedback
        etPowerFractionLimit
        etOutputRange_deg_A1
        etOutputRange_deg_A2
        etDevUnitPerDeg
        cbFeedbackUsesRejectedLight
        tablehShutters

        etPowerRange_W0
        etPowerRange_W1

        etMoveTimeout_s
        
        etCalibrationNumPoints
        etCalibrationNumRepeats
        etCalibrationAverageSamples
        etCalibrationMotorSettlingTime_ms
    end
    
    methods
        function obj = MotorizedHalfWavePlatePage(hResource,hParent)
            obj@dabs.resources.configuration.ResourcePage(hResource,hParent);
        end
        
        function makePanel(obj,hParent)
            hTabGroup = uitabgroup('Parent',hParent);
            hTab = uitab('Parent',hTabGroup,'Title','Basic');
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [30 25 120 20],'Tag','txhMotor','String','Motor Controller','HorizontalAlignment','right');
                obj.pmhMotor = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [160 22 120 20],'Tag','pmhMotor', 'callback', @obj.updateAxes);

                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [30 46 120 20],'Tag','txhAxis','String','Axis','HorizontalAlignment','right');
                obj.pmAxis = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [160 46 120 20],'Tag','pmAxis');

                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [176 76 30 20],'Tag','txMin','String','Min','HorizontalAlignment','left');
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [221 76 30 20], 'Tag','txMax','String','Max','HorizontalAlignment','left');

                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [0 93 150 20],'Tag','txOutputRange_deg','String','Control output [degrees]','HorizontalAlignment','right');
                obj.etOutputRange_deg_A1 = most.gui.uicontrol('Parent',hTab,'Style','edit','RelPosition', [160 92 50 20],'Tag','etOutputRange_deg_A1');
                obj.etOutputRange_deg_A2 = most.gui.uicontrol('Parent',hTab,'Style','edit','RelPosition', [211 92 50 20],'Tag','etOutputRange_deg_A2');

                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [303 64 150 22],'Tag','txScalingFactor','String','Scaling','HorizontalAlignment','left');
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [275 76 150 20],'Tag','txScalingFactorUnits','String','[Stage units per deg]','HorizontalAlignment','left');
                obj.etDevUnitPerDeg = most.gui.uicontrol('Parent',hTab,'Style','edit','RelPosition', [298 92 50 20],'Tag','etDevUnitPerDeg');

                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [0 114 150 20],'Tag','txpowerRange_W','String','Power output [W]','HorizontalAlignment','right');
                obj.etPowerRange_W0 = most.gui.uicontrol('Parent',hTab,'Style','edit','RelPosition', [160 114 50 20],'Tag','etPowerRange_W0');
                obj.etPowerRange_W1 = most.gui.uicontrol('Parent',hTab,'Style','edit','RelPosition', [211 114 50 20],'Tag','etPowerRange_W1');

                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [0 142 150 20],'Tag','txFractionLimit','String','Beam output limit [%]','HorizontalAlignment','right');
                obj.etPowerFractionLimit = most.gui.uicontrol('Parent',hTab,'Style','edit','RelPosition', [159 141 102 20],'Tag','etPowerFractionLimit');
                
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [0 170 150 20],'Tag','txMoveTimeout_s','String','Motor move timeout [s]','HorizontalAlignment','right');
                obj.etMoveTimeout_s = most.gui.uicontrol('Parent',hTab,'Style','edit','RelPosition', [159 168 102 20],'Tag','etMoveTimeout_s');
                
            hTab = uitab('Parent',hTabGroup,'Title','Calibration Settings');
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [40 27 140 20],'Tag','txhAIFeedback','String','Feedback Channel (optional)','HorizontalAlignment','right');
                obj.pmhAIFeedback = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [190 25 120 20],'Tag','pmhAIFeedback');

                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [30 47 150 20],'Tag','txFeedbackUsesRejectedLight','String','Feedback uses rejected light','HorizontalAlignment','right');
                obj.cbFeedbackUsesRejectedLight = most.gui.uicontrol('Parent',hTab,'Style','checkbox','RelPosition', [190 47 120 20],'Tag','cbFeedbackUsesRejectedLight','String','');

                tooltip = sprintf('The angular range of the motor is subdivided into N calibration points. For each point, the feedback of the photodiode is measured.');
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [-20 72 200 20],'Tag','txCalibrationNumPoints','String','Number of calibration points','HorizontalAlignment','right');
                obj.etCalibrationNumPoints = most.gui.uicontrol('Parent',hTab,'Style','edit','RelPosition', [190 69 120 20],'Tag','etCalibrationNumPoints','TooltipString',tooltip);
                
                tooltip = sprintf('For each calibration point, N analog feedback samples are averaged to reduce noise.');
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [-20 92 200 20],'Tag','txCalibrationAverageSamples','String','Average N samples','HorizontalAlignment','right');
                obj.etCalibrationAverageSamples = most.gui.uicontrol('Parent',hTab,'Style','edit','RelPosition', [190 91 120 20],'Tag','etCalibrationAverageSamples','TooltipString',tooltip);
                
                tooltip = sprintf('The calibration is repeated N times. The final calibration result is the average of all runs.');
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [-20 115 200 20],'Tag','txCalibrationNumRepeats','String','Number of calibration runs','HorizontalAlignment','right');
                obj.etCalibrationNumRepeats = most.gui.uicontrol('Parent',hTab,'Style','edit','RelPosition', [190 113 120 20],'Tag','etCalibrationNumRepeats','TooltipString',tooltip);
                
                tooltip = sprintf('After moving the motor, wait N milliseconds before the feedback is measured.');
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [-20 136 200 20],'Tag','txCalibrationMotorSettlingTime_ms','String','Modulator settling time [ms]','HorizontalAlignment','right');
                obj.etCalibrationMotorSettlingTime_ms = most.gui.uicontrol('Parent',hTab,'Style','edit','RelPosition', [190 135 120 20],'Tag','etCalibrationMotorSettlingTime_ms','TooltipString',tooltip);

                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [30 167 150 20],'Tag','txhCalibrationOpenShutters','String','Open shutters for calibration','HorizontalAlignment','right');
                obj.tablehShutters = most.gui.uicontrol('Parent',hTab,'Style','uitable','ColumnFormat',{'char','logical'},'ColumnEditable',[false,true],'ColumnName',{'Shutter','Open'},'ColumnWidth',{100 40},'RowName',[],'RelPosition', [190 237.333333333333 160 90],'Tag','tablehShutters');
        end
        
        function redraw(obj)
            hMotors = obj.hResourceStore.filterByClass('dabs.resources.devices.MotorController');
            obj.pmhMotor.String = [{''}, hMotors];
            if ~isempty(obj.hResource.hMotor)
                obj.pmhMotor.pmValue = obj.hResource.hMotor.name;
            end
            
            if ~isempty(obj.hResource.hMotor)
                axes = obj.hResource.hMotor.numAxes;
                obj.pmAxis.String = {''};
                for axis = 1:axes
                    obj.pmAxis.String(end+1) = {num2str(axis)};
                end
                if ~isempty(obj.hResource.motorAxis)
                    obj.pmAxis.pmValue = num2str(obj.hResource.motorAxis);
                end
            end
            
            hAIs = obj.hResourceStore.filterByClass('dabs.resources.ios.AI');
            obj.pmhAIFeedback.String = [{''}, hAIs];
            obj.pmhAIFeedback.pmValue = obj.hResource.hAIFeedback;
            
            obj.etOutputRange_deg_A1.String = num2str(obj.hResource.outputRange_deg(1));
            obj.etOutputRange_deg_A2.String = num2str(obj.hResource.outputRange_deg(2));
            
            obj.etDevUnitPerDeg.String = num2str(obj.hResource.devUnitsPerDegree);
            
            powerLut = obj.hResource.convertPowerFraction2PowerWatt([0,1]);
            obj.etPowerRange_W0.String = most.idioms.ifthenelse(isnan(powerLut(1)),'',num2str(powerLut(1)));
            obj.etPowerRange_W1.String = most.idioms.ifthenelse(isnan(powerLut(2)),'',num2str(powerLut(2)));
            
            obj.etPowerFractionLimit.String = num2str(obj.hResource.powerFractionLimit*100);
            
            obj.cbFeedbackUsesRejectedLight.Value = obj.hResource.feedbackUsesRejectedLight;
                        
            allShutters = obj.hResourceStore.filterByClass('dabs.resources.devices.Shutter');
            allShutterNames = cellfun(@(hR)hR.name,allShutters,'UniformOutput',false);
            shutterNames = cellfun(@(hR)hR.name,obj.hResource.hCalibrationOpenShutters,'UniformOutput',false);
            selected = ismember(allShutterNames,shutterNames);
            obj.tablehShutters.Data = [allShutterNames',num2cell(selected)'];

            obj.etMoveTimeout_s.String = num2str(obj.hResource.moveTimeout_s);
            
            % Calibration Tab
            obj.etCalibrationNumPoints.String      = obj.hResource.calibrationNumPoints;
            obj.etCalibrationNumRepeats.String     = obj.hResource.calibrationNumRepeats;
            obj.etCalibrationAverageSamples.String = obj.hResource.calibrationAverageSamples;
            obj.etCalibrationMotorSettlingTime_ms.String = obj.hResource.calibrationMotorSettlingTime_s * 1e3;
        end
        
        function apply(obj)
            most.idioms.safeSetProp(obj.hResource,'hMotor',obj.pmhMotor.String{obj.pmhMotor.Value});
            most.idioms.safeSetProp(obj.hResource,'motorAxis',str2double(obj.pmAxis.String{obj.pmAxis.Value}));
            most.idioms.safeSetProp(obj.hResource,'hAIFeedback',obj.pmhAIFeedback.String{obj.pmhAIFeedback.Value});
            
            most.idioms.safeSetProp(obj.hResource,'outputRange_deg',[str2double(obj.etOutputRange_deg_A1.String) str2double(obj.etOutputRange_deg_A2.String)]);
            most.idioms.safeSetProp(obj.hResource,'devUnitsPerDegree', str2double(obj.etDevUnitPerDeg.String));
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

            most.idioms.safeSetProp(obj.hResource,'moveTimeout_s',str2double(obj.etMoveTimeout_s.String));
            
            most.idioms.safeSetProp(obj.hResource,'calibrationNumPoints',str2double(obj.etCalibrationNumPoints.String));
            most.idioms.safeSetProp(obj.hResource,'calibrationNumRepeats',str2double(obj.etCalibrationNumRepeats.String));
            most.idioms.safeSetProp(obj.hResource,'calibrationAverageSamples',str2double(obj.etCalibrationAverageSamples.String));
            most.idioms.safeSetProp(obj.hResource,'calibrationMotorSettlingTime_s',str2double(obj.etCalibrationMotorSettlingTime_ms.String) / 1e3);

            obj.hResource.saveMdf();
            obj.hResource.reinit();
        end
        
        function updateAxes(obj, varargin)
            hMotors = obj.hResourceStore.filterByClass('dabs.resources.devices.MotorController');
            hMotor = hMotors{obj.pmhMotor.Value - 1}; % -1 for the blank space.

            axes = hMotor.numAxes;
            obj.pmAxis.String = {''};
            for axis = 1:axes
                obj.pmAxis.String(end+1) = {num2str(axis)};
            end
            if ~isempty(obj.hResource.motorAxis)
                obj.pmAxis.pmValue = num2str(obj.hResource.motorAxis);
            end
            
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
