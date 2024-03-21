classdef WaveformGeneratorPage < dabs.resources.configuration.ResourcePage
    properties
        pmControlPort;
        pmFeedbackPort;
        pmWvfmFunc;
        
        pmTaskType;
        
        etAmplitude;
        etDefaultVal;
        etStartDelay;
        etPeriod;
        etDutyCycle;
        
        pmStartTriggerEdge;
        pmSampleMode;
        pmStartTriggerPort;
                
        etSampleRate;        
        cbAllowRetrigger;

        isvDAQAvail = true;
    end
    
    methods
        function obj = WaveformGeneratorPage(hResource,hParent)
            obj@dabs.resources.configuration.ResourcePage(hResource,hParent);
        end
        
        function makePanel(obj,hParent)
            obj.isvDAQAvail = ~isempty(obj.hResourceStore.filterByClass('dabs.resources.daqs.vDAQ'));
            if obj.isvDAQAvail
                %% Waveform Control Basics
                most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [-25 26 120 20],'Tag','txTaskType','String','Task Type','HorizontalAlignment','right');
                obj.pmTaskType = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [101 23 106 20],'Tag','pmTaskType','callback',@obj.taskTypeChangedCallback,'HorizontalAlignment','left');
                
                most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [-21 57 120 20],'Tag','txCtrlPort','String','Control Port:','HorizontalAlignment','right');
                obj.pmControlPort = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [101 53 106 20],'Tag','pmCtrlPort','HorizontalAlignment','left');
                
                most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [-20 88 120 20],'Tag','txFdbkPort','String','Feedback Port:','HorizontalAlignment','right');
                obj.pmFeedbackPort = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [101 83 106 20],'Tag','pmFdbkPort','HorizontalAlignment','left');
                
                most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [-20 118 120 20],'Tag','txWvfmFunc','String','Waveform Function:','HorizontalAlignment','right');
                obj.pmWvfmFunc = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [101 114 106 20],'Tag','pmWvfmFunc','HorizontalAlignment','left');
                
                %% Waveform Params
                most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [263 22 70 20],'Tag','txAmplitude','String','Amplitude(v):','HorizontalAlignment','right');
                obj.etAmplitude = most.gui.uicontrol('Parent',hParent,'Style','edit','String',{''},'RelPosition', [334 19 46 20],'Tag','etAmplitude','HorizontalAlignment','left');
                
                most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [247 53 86 20],'Tag','txDefault','String','Default Value(v):','HorizontalAlignment','right');
                obj.etDefaultVal = most.gui.uicontrol('Parent',hParent,'Style','edit','String',{''},'RelPosition', [334 50 46 20],'Tag','etDefaultVal','HorizontalAlignment','left');
                
                most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [248 112 85 20],'Tag','txStartDelay','String','Start Delay(sec):','HorizontalAlignment','right');
                obj.etStartDelay = most.gui.uicontrol('Parent',hParent,'Style','edit','String',{''},'RelPosition', [335 110 46 20],'Tag','etStartDelay','HorizontalAlignment','left');
                
                most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [273 84 61 20],'Tag','txPeriod','String','Period(sec):','HorizontalAlignment','right');
                obj.etPeriod = most.gui.uicontrol('Parent',hParent,'Style','edit','String',{''},'RelPosition', [335 81 46 20],'Tag','etPeriod','HorizontalAlignment','left');
                
                most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [214 143 120 20],'Tag','txDutyCycle','String','Duty Cycle(%):','HorizontalAlignment','right');
                obj.etDutyCycle = most.gui.uicontrol('Parent',hParent,'Style','edit','String',{''},'RelPosition', [335 140 46 20],'Tag','etDutyCycle','HorizontalAlignment','left');
                
                %% Task Control
                % This can just autodetect based on control port.
                
                most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [-21 193 120 20],'Tag','txSamplingRate','String','Sampling Rate [Hz]:','HorizontalAlignment','right');
                obj.etSampleRate = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [104 191 81 20],'Tag','etSampleRate','callback',@obj.updateFrequency);
                
                most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [202 192 70 20],'Tag','txSampleMode','String','Sample Mode:','HorizontalAlignment','right');
                obj.pmSampleMode = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [274 228 81 60],'Tag','pmSampleMode','callback',@obj.sampleModeChangedCallback);
                
                most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [10 225 90 20],'Tag','txStartTriggerPort','String','Start Trigger port:','HorizontalAlignment','right');
                obj.pmStartTriggerPort = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [104 220 81 20],'Tag','pmStartTriggerPort','HorizontalAlignment','right');
                
                most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [202 223 93 20],'Tag','txStartTriggerEdge','String','Start Trigger Edge:','HorizontalAlignment','right');
                obj.pmStartTriggerEdge = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [297 259 60 60],'Tag','pmStartTriggerEdge');
                
               % Gate this for Finite Tasks!
                most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [138 257 80 20],'Tag','txAllowRetrigger','String','Allow Retrigger:','HorizontalAlignment','right');
                obj.cbAllowRetrigger =  most.gui.uicontrol('Parent',hParent,'Style','checkbox','String', 'Allow retrigger', 'RelPosition', [222 254 19 19],'Tag','cbAllowRetrigger','Value',true);
                
            else
                hFlow = most.gui.uiflowcontainer('Parent',hParent,'FlowDirection','TopDown','margin',1);
                hFlowTop    = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','LeftToRight','margin',1);
                hFlowMiddle = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','LeftToRight','margin',1,'HeightLimits',[20 20]);
                hFlowBottom = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','LeftToRight','margin',1);
                
                uicontrol('Parent',hFlowMiddle,'Style','text','String','Waveform Generator is solely compatible with the vDAQ.','HorizontalAlignment','center','FontWeight','bold');
            end
        end
        
        function redraw(obj)
            if obj.isvDAQAvail
                % Potential issue here if somehow hResource.taskType and
                % hResource.hControl are different (AO vs DO)
                % This should not happend as get.hControl gates based on
                % taskType
                obj.pmTaskType.String = {'Digital','Analog'};
                obj.pmTaskType.pmValue = obj.hResource.taskType;
                
                % DO = 0,1,3
                % DIO = 0,1,2,3
                % 2 can't be used for output
                
                obj.updateFeedbackPorts();
                
                obj.updateWaveformPackage();
                obj.updateControlPorts();

                obj.pmStartTriggerEdge.String = {'rising', 'falling'};
                obj.pmStartTriggerEdge.pmValue = obj.hResource.startTriggerEdge;
                
                obj.pmSampleMode.String = {'continuous', 'finite'};
                obj.pmSampleMode.pmValue = obj.hResource.sampleMode;
                
                hDIOs = obj.hResourceStore.filterByClass({?dabs.resources.ios.DO, ?dabs.resources.ios.DI});
                
                obj.pmStartTriggerPort.String = [{''}, hDIOs];
                obj.pmStartTriggerPort.pmValue = most.idioms.ifthenelse(isempty(obj.hResource.startTriggerPort),'',obj.hResource.startTriggerPort.name);
                
                obj.etSampleRate.String = obj.hResource.sampleRate_Hz;
                
                obj.etAmplitude.String = obj.hResource.amplitude;
                obj.etPeriod.String = obj.hResource.periodSec;
                obj.etDefaultVal.String = obj.hResource.defaultValueVolts;
                obj.etStartDelay.String = obj.hResource.startDelay;
                obj.etDutyCycle.String = obj.hResource.dutyCycle;
                
                obj.sampleModeChangedCallback([],[]);
                obj.taskTypeChangedCallback([],[]);
                obj.updateFrequency();
            end
        end
        
        function apply(obj)
            if obj.isvDAQAvail
                most.idioms.safeSetProp(obj.hResource, 'taskType',obj.pmTaskType.String{obj.pmTaskType.Value});

                most.idioms.safeSetProp(obj.hResource, 'hControl', obj.pmControlPort.pmValue);
                most.idioms.safeSetProp(obj.hResource, 'hAIFeedback', obj.pmFeedbackPort.pmValue);

                most.idioms.safeSetProp(obj.hResource, 'startTriggerPort',obj.pmStartTriggerPort.pmValue);
                most.idioms.safeSetProp(obj.hResource, 'startTriggerEdge', obj.pmStartTriggerEdge.String{obj.pmStartTriggerEdge.Value});
                most.idioms.safeSetProp(obj.hResource, 'sampleMode',obj.pmSampleMode.String{obj.pmSampleMode.Value});
                most.idioms.safeSetProp(obj.hResource, 'allowRetrigger', logical(obj.cbAllowRetrigger.Value));
                most.idioms.safeSetProp(obj.hResource, 'sampleRate_Hz', str2double(obj.etSampleRate.String));
                
                most.idioms.safeSetProp(obj.hResource, 'wvfrmFcn', obj.pmWvfmFunc.pmValue);

                most.idioms.safeSetProp(obj.hResource,'amplitude',str2double(obj.etAmplitude.String));
                most.idioms.safeSetProp(obj.hResource,'defaultValueVolts',str2double(obj.etDefaultVal.String));
                most.idioms.safeSetProp(obj.hResource,'periodSec',str2double(obj.etPeriod.String));
                most.idioms.safeSetProp(obj.hResource,'startDelay',str2double(obj.etStartDelay.String));
                most.idioms.safeSetProp(obj.hResource,'dutyCycle',str2double(obj.etDutyCycle.String));

                obj.hResource.saveMdf();
                obj.hResource.reinit();
            end
            
            
        end
        
        function remove(obj)
            obj.hResource.deleteAndRemoveMdfHeading();
        end
        
        function taskTypeChangedCallback(obj, src, evt)
            obj.updateFeedbackPorts();
            obj.updateControlPorts();
            obj.updateWaveformPackage();
        end

        function updateControlPorts(obj, varargin)
            switch obj.pmTaskType.pmValue
                case 'Analog'
                    hCtrlOuts = obj.hResourceStore.filterByClass({?dabs.resources.ios.AO});
                    hCtrlVal = obj.hResource.hAOControl;
                    obj.etAmplitude.String = obj.hResource.amplitude;
                case 'Digital'
                    hCtrlOuts = obj.hResourceStore.filterByClass({?dabs.resources.ios.DO});
                    hCtrlVal = obj.hResource.hDOControl;
                    obj.etAmplitude.String = most.idioms.ifthenelse(str2double(obj.etAmplitude.String)>=1,'1','0');
                    obj.etDefaultVal.String = most.idioms.ifthenelse(str2double(obj.etDefaultVal.String)>=1,'1','0');
                otherwise
            end
            hCtrlOuts = hCtrlOuts(cellfun(@(c)isa(c.hDAQ,'dabs.resources.daqs.vDAQ'),hCtrlOuts));
            obj.pmControlPort.String = [{''}, hCtrlOuts];
            obj.pmControlPort.pmValue = most.idioms.ifthenelse(isa(hCtrlVal, 'dabs.resources.IO'), hCtrlVal, '');
        end

        function updateFeedbackPorts(obj, varargin)
            switch obj.pmTaskType.pmValue
                case 'Analog'
                    hAIs = obj.hResourceStore.filterByClass(?dabs.resources.ios.AI);
                    hAIs = hAIs(cellfun(@(c)isa(c.hDAQ,'dabs.resources.daqs.vDAQ'),hAIs));
       
                    obj.pmFeedbackPort.Enable = 'on';
                    obj.pmFeedbackPort.String =[{''}, hAIs];
                    obj.pmFeedbackPort.pmValue = obj.hResource.hAIFeedback;
                case 'Digital'
                    obj.pmFeedbackPort.String = {''};
                    obj.pmFeedbackPort.pmValue = 1;
                    obj.pmFeedbackPort.Enable = 'off';
            end
        end

        function updateWaveformPackage(obj,varargin)
            switch obj.pmTaskType.pmValue
                case 'Analog'
                    waveFcnPackage = what ('dabs/generic/waveforms/analog');
                case 'Digital'
                    waveFcnPackage = what ('dabs/generic/waveforms/digital');
                otherwise
            end
            fcnNames = cellfun(@(mname)regexprep(mname,'\.m$',''),waveFcnPackage.m,'UniformOutput',false);
            fcnNames = most.idioms.ifthenelse(isrow(fcnNames),fcnNames,fcnNames');
            
            obj.pmWvfmFunc.String = [{''}, fcnNames];
            obj.pmWvfmFunc.pmValue = obj.hResource.wvfrmFcn;
        end
        
        function sampleModeChangedCallback(obj, src, evt)
            switch obj.pmSampleMode.pmValue
                case 'continuous'
                    obj.cbAllowRetrigger.Enable = 'off';
                case 'finite'
                    obj.cbAllowRetrigger.Enable = 'on';
                otherwise
            end
        end
        
        function updateFrequency(obj,varargin)
            desiredVal = str2double(obj.etSampleRate.String);
            if desiredVal < 3052
                str = sprintf('Cannot use a sampling rate less than 3052 Hz on the vDAQ.\n\nTo lower the frequency of output waveform, increase the buffer size');
                most.gui.blockingMsgbox(str,'Sampling Rate Restriction');
                obj.etSampleRate.String = num2str(obj.hResource.sampleRate_Hz);
            elseif desiredVal > obj.hResource.MaxSampleRate
                str = sprintf('Desired sample rate of %f exceeds device IO Max Sample Rate of %f', desiredVal, obj.hResource.MaxSampleRate);
                most.gui.blockingMsgbox(str,'Sampling Rate Restriction');
                obj.etSampleRate.String = num2str(obj.hResource.sampleRate_Hz);
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
