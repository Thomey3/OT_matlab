classdef DataRecorderWidget < dabs.resources.widget.Widget
    properties
        hListeners = event.listener.empty(0,1);

        hBnStart;
        hEtFile;
        hEtAcquisitionNumber;
        hPmTrigger;
        hPmEdge;
        hCbAutoStart;
        hCbAllowRetrigger;
        hCbUseTrigger;
    end

    properties (SetAccess = private, Hidden)
        hView; % reference to DataRecorderView;
    end
    
    methods
        function obj = DataRecorderWidget(hResource,hParent)
            obj@dabs.resources.widget.Widget(hResource,hParent);

            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'configuration','PostSet',@(varargin)obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'fileBaseName','PostSet',@(varargin)obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'fileDirectory','PostSet',@(varargin)obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'acquisitionNumber','PostSet',@(varargin)obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'autoStart','PostSet',@(varargin)obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'allowRetrigger','PostSet',@(varargin)obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'useTrigger','PostSet',@(varargin)obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'hTrigger','PostSet',@(varargin)obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'redrawWidget',@(varargin)obj.redraw);
            
            try
                obj.redraw();
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
        end
        
        function delete(obj)
            delete(obj.hView);
            obj.hListeners.delete();
        end
       
        function makePanel(obj,hParent)
            hFlow = most.gui.uiflowcontainer('Parent',hParent,'FlowDirection','TopDown','margin',0.001);

            hCheckboxBufferFlow = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','LeftToRight','margin',0.001);
                most.gui.uiflowcontainer('Parent',hCheckboxBufferFlow,'FlowDirection','TopDown','margin',0.001,'WidthLimits',[2 2]);
                hCheckboxFlow = most.gui.uiflowcontainer('Parent',hCheckboxBufferFlow,'FlowDirection','TopDown','margin',2);
                    obj.hCbAutoStart = most.gui.uicontrol('Parent',hCheckboxFlow,'Style','checkbox','String','Auto Start','Callback',@obj.cbAutoStartClicked);
                    obj.hCbAutoStart.TooltipString = sprintf('Auto Start\nWhether to start/stop when acquisition is started/stopped\n(i.e. the Grab button is pressed)');
                    obj.hCbUseTrigger = most.gui.uicontrol('Parent',hCheckboxFlow,'Style','checkbox','String','Use Trigger','Callback',@obj.cbUseTriggerClicked);
                    obj.hCbUseTrigger.TooltipString = sprintf('Use Trigger\nWhether to use a digital signal trigger, or to start\ncapturing signals as soon as "Start" is pressed.');
                    obj.hCbAllowRetrigger = most.gui.uicontrol('Parent',hCheckboxFlow,'Style','checkbox','String','Allow Retrigger','Callback',@obj.cbAllowRetriggerClicked);
                    obj.hCbAllowRetrigger.TooltipString = sprintf('Allow Retrigger\nWhether to continue capturing samples after\nthe first trigger on subsequent triggers.');
            
            hFileFlow = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','LeftToRight','margin',0.001,'HeightLimits',[18 18]);
                hFileLabelFlow = most.gui.uiflowcontainer('Parent',hFileFlow,'FlowDirection','TopDown','margin',0.001,'WidthLimits',[20 20]);
                    most.gui.uiflowcontainer('Parent',hFileLabelFlow,'FlowDirection','TopDown','margin',0.001,'HeightLimits',[2 2]);
                    most.gui.uicontrol('Parent',hFileLabelFlow,'Style','text','String','File');
                hFileEditFlow = most.gui.uiflowcontainer('Parent',hFileFlow,'FlowDirection','LeftToRight','margin',0.001);
                    obj.hEtFile = most.gui.uicontrol('Parent',hFileEditFlow,'Style','edit','String','Example','Callback',@obj.etFileChanged);
                hFileAcqFlow = most.gui.uiflowcontainer('Parent',hFileFlow,'FlowDirection','LeftToRight','margin',0.001,'WidthLimits',[20 20]);
                    obj.hEtAcquisitionNumber = most.gui.uicontrol('Parent',hFileAcqFlow,'Style','edit','KeyPressFcn',@obj.etAcquisitionNumberKeyPress,'Callback',@obj.etAcquisitionNumberChanged);
                    obj.hEtAcquisitionNumber.TooltipString = sprintf(['Acquisition Number\n'...
                        'This number is appended to the file name and\nincremented each time the Data Recorder is restarted']);

            hTriggerFlow = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','LeftToRight','margin',0.001,'HeightLimits',[18 18]);
                hTriggerLabelFlow = most.gui.uiflowcontainer('Parent',hTriggerFlow,'FlowDirection','TopDown','margin',0.001,'WidthLimits',[20 20]);
                    most.gui.uiflowcontainer('Parent',hTriggerLabelFlow,'FlowDirection','TopDown','margin',0.001,'HeightLimits',[2 2]);
                    most.gui.uicontrol('Parent',hTriggerLabelFlow,'Style','text','String','Trig');
                hTriggerPmFlow = most.gui.uiflowcontainer('Parent',hTriggerFlow,'FlowDirection','LeftToRight','margin',0.001);
                    obj.hPmTrigger = most.gui.uicontrol('Parent',hTriggerPmFlow,'Style','popupmenu','Callback',@obj.pmTriggerSelected);

            hButtonFlow = most.gui.uiflowcontainer('Parent',hFlow,'FlowDirection','LeftToRight','margin',0.001,'HeightLimits',[20 20]);
                obj.hBnStart = most.gui.uicontrol('Parent',hButtonFlow,'Style','pushbutton','String','Start','Callback',@obj.bnStartClicked);
                most.gui.uicontrol('Parent',hButtonFlow,'Style','pushbutton','String','View','Callback',@obj.bnViewClicked);
        end
       
        function redraw(obj)
            obj.hCbAutoStart.Value = obj.hResource.autoStart;
            obj.hCbAllowRetrigger.Value = obj.hResource.allowRetrigger;
            obj.hCbUseTrigger.Value = obj.hResource.useTrigger;

            obj.hEtFile.String = obj.hResource.fileBaseName;
            obj.hEtFile.TooltipString = [sprintf(['File Name\n'...
                'Current full file path:\n'])...
                obj.hResource.currentFullname];

            obj.hEtAcquisitionNumber.String = num2str(obj.hResource.acquisitionNumber);
            obj.hBnStart.String = most.idioms.ifthenelse(obj.hResource.running,'Stop','Start');

            hDIs = obj.hResourceStore.filter(@(r)most.idioms.isa(r,?dabs.resources.ios.DI) && isa(r.hDAQ,'dabs.resources.daqs.vDAQ'));
            
            obj.hPmTrigger.String = [{''},hDIs];
            obj.hPmTrigger.pmValue = obj.hResource.hTrigger;

            obj.controlConfigState();
        end

        function controlConfigState(obj,varargin)
            % disable configuration based on state
            obj.hCbAllowRetrigger.Enable = ~isinf(obj.hResource.sampleDuration);
        end
    end

    %% callbacks
    methods
        function bnStartClicked(obj,src,evt)
            if obj.hResource.running
                obj.hResource.stop();
            else
                hWb = [];
                if obj.hResource.isLongStart
                    hWb = waitbar(.30,'Starting task...');
                end
                obj.hResource.start();
                most.idioms.safeDeleteObj(hWb);
            end
            
            obj.redraw();
        end

        function bnViewClicked(obj,~,~)
            if most.idioms.isValidObj(obj.hView)
                obj.hView.show();
            else
                obj.hView = dabs.generic.datarecorder.DataRecorderView(obj.hResource);
            end
        end

        function cbAutoStartClicked(obj,src,evt)
            obj.hResource.autoStart = obj.hCbAutoStart.Value;
        end

        function cbAllowRetriggerClicked(obj,src,evt)
            try
                obj.hResource.allowRetrigger = obj.hCbAllowRetrigger.Value;
                obj.hResource.reinit();
            catch ME
                most.ErrorHandler.logAndReportError(ME);
                obj.redraw();
            end
        end

        function cbUseTriggerClicked(obj,src,evt)
            try
                obj.hResource.useTrigger = obj.hCbUseTrigger.Value;
                obj.hResource.reinit();
            catch ME
                most.ErrorHandler.logAndReportError(ME);
                obj.redraw();
            end
        end

        function pmTriggerSelected(obj,src,evt)
            if isempty(obj.hResource.hDAQ)
                return
            end
            
            try
                obj.hResource.hTrigger = obj.hPmTrigger.pmValue;
                obj.hResource.reinit();
            catch ME
                most.ErrorHandler.logAndReportError(ME);
                obj.redraw();
            end
        end

        function etFileChanged(obj,src,evt)
            try
                obj.hResource.fileBaseName = obj.hEtFile.String;
                obj.hResource.reinit();
            catch ME
                most.ErrorHandler.logAndReportError(ME);
                obj.redraw();
            end
        end
        
        function etAcquisitionNumberChanged(obj,src,evt)
            try
                newNum = str2double(obj.hEtAcquisitionNumber.String);
                if ~isnan(newNum) && ~isinf(newNum) && floor(newNum) == newNum
                    obj.hResource.acquisitionNumber = newNum;
                else
                    obj.redraw
                end
            catch ME
                most.ErrorHandler.logAndReportError(ME);
                obj.redraw();
            end
        end

        function etAcquisitionNumberKeyPress(obj,src,evt)
            try
                switch evt.Key
                    case {'rightarrow','uparrow'}
                        obj.hResource.acquisitionNumber = obj.hResource.acquisitionNumber + 1;
                    case {'leftarrow','downarrow'}
                        obj.hResource.acquisitionNumber = obj.hResource.acquisitionNumber - 1;
                end
            catch ME
                most.ErrorHandler.logAndReportError(ME);
                obj.redraw();
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
