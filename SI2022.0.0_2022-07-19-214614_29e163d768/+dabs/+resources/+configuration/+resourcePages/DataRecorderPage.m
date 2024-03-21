classdef DataRecorderPage < dabs.resources.configuration.ResourcePage
    % gui handles
    properties
        hListeners = event.listener.empty(0,1);

        hPmTrigger;
        hEtSampleRate;
        hEtSampleDuration;
        hEtFileBaseName;
        hEtFileDirectory;
        hCbAutoStart;
        hCbAllowRetrigger;
        hCbUseTrigger;
        hCbUseCompression;
        hTblSignals;

        hFigChannelAdd;
        hTblAvailableSignals;
        hAvailableSignals = dabs.resources.Resource.empty();

        txtUpgradeMessage;
        pbUpgradeContact;
    end

    % state
    properties (SetObservable)
        selectedRow = 1;
        configuration = dabs.generic.datarecorder.ChannelConfiguration.empty();
    end
    
    %% lifecycle methods
    methods
        function obj = DataRecorderPage(hResource,hParent)
            obj@dabs.resources.configuration.ResourcePage(hResource,hParent);
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hListeners);
            obj.hListeners = event.listener.empty();
        end
        
        function makePanel(obj,hParent)
            hTabGroup = uitabgroup('Parent',hParent);
            hTableTab = uitab('Parent',hTabGroup,'Title','Signals');
            hControlsTab = uitab('Parent',hTabGroup,'Title','Controls');

            obj.makeTable(hTableTab);
            obj.makeControls(hControlsTab);
            obj.makeListeners();
        end

        function makeTable(obj,hParent)
            columnFormat = {'char' 'char' 'char' 'numeric'};
            columnEditable = [false true true true];
            columnName = {'Signal' 'Recorded Name' 'Units' 'Multiplier'};
            columnWidth = {74 139 70 65};
            
            obj.hTblSignals = most.gui.uicontrol('Parent',hParent,'Style','uitable','Tag','tblSignals','ColumnFormat',columnFormat,'ColumnEditable',columnEditable,'ColumnName',columnName,'ColumnWidth',columnWidth,'RowName',[],'RelPosition', [24 190 350 178],'CellSelectionCallback',@obj.cellSelected,'CellEditCallback',@obj.cellEdited);

            most.gui.uicontrol('Parent',hParent,'Style','pushbutton','String','+','Callback',@(varargin)obj.addChannel,'Tag','pbPlus','RelPosition', [2 30 20 20]);
            most.gui.uicontrol('Parent',hParent,'Style','pushbutton','String',most.constants.Unicode.ballot_x,'Callback',@(varargin)obj.removeRow,'Tag','pbRemove','RelPosition', [2 50 20 20]);
            most.gui.uicontrol('Parent',hParent,'Style','pushbutton','String',most.constants.Unicode.black_up_pointing_triangle,'Callback',@(varargin)obj.moveRow(-1),'Tag','pbMoveUp','RelPosition', [2 70 20 20]);
            most.gui.uicontrol('Parent',hParent,'Style','pushbutton','String',most.constants.Unicode.black_down_pointing_triangle,'Callback',@(varargin)obj.moveRow(+1),'Tag','pbMoveDown','RelPosition', [2 90 20 20]);

            obj.txtUpgradeMessage = most.gui.uicontrol('Parent',hParent,'Style','text','String','','Tag','txtUpgradeMessage','HorizontalAlignment','left','FontSize', 10, 'BackgroundColor', [0.94 0.94 0], 'RelPosition', [30 263 339 68]);
            obj.pbUpgradeContact = most.gui.uicontrol('Parent',hParent,'Style','pushbutton','String','Contact Us','Callback',@obj.goToSupport,'Tag','pbUpgradeContact','RelPosition', [137 257 119 28]);

            obj.txtUpgradeMessage.Visible = 'off';
            obj.pbUpgradeContact.Visible = 'off';
        end

        function makeControls(obj,hParent)
            most.gui.uicontrol('Parent',hParent,'Style','text','String','Recording Trigger','Tag','txRecordingTrigger','HorizontalAlignment','right','RelPosition', [5 38 106 19]);
            obj.hPmTrigger = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','Tag','pmRecordingTrigger','String',{''},'RelPosition', [121 37 142 22]);
            obj.hPmTrigger.TooltipString = sprintf('Recording Trigger\nDigital signal to use as a hardware trigger for the data recorder.');

            most.gui.uicontrol('Parent',hParent,'Style','text','String','Sample Rate [Hz]','Tag','txSampleRate','HorizontalAlignment','right','RelPosition', [5 69 106 20]);
            obj.hEtSampleRate = most.gui.uicontrol('Parent',hParent,'Style','edit','Tag','etSampleRate','RelPosition', [121 67 142 20]);

            most.gui.uicontrol('Parent',hParent,'Style','text','String','Sample Duration [s]','Tag','txSampleDuration','HorizontalAlignment','right','RelPosition', [5 95 106 14]);
            obj.hEtSampleDuration = most.gui.uicontrol('Parent',hParent,'Style','edit','Tag','etSampleDuration','RelPosition', [121 97 142 20],'Callback',@obj.controlConfigState);
            obj.hEtSampleDuration.TooltipString = sprintf(['Sample Duration [s]\n'...
                'The duration to record in seconds. Set to Inf to record\n'...
                'until "stop" is pressed. When there is a trigger specified\n'...
                'and the duration is Inf, the recorder will wait until the\n'...
                'trigger and then record the inputs until "stop" is pressed.\n'...
                'If the duration is finite, the recorder will only record\n'...
                'the specified duration and then stop. If "Allow Retrigger"\n'...
                'is enabled, the recorder will record for the duration again\n'...
                'when it encounters another trigger.\n']);
            
            obj.hCbAutoStart = most.gui.uicontrol('Parent',hParent,'Style','checkbox','String','Auto Start','Tag','cbAutoStart','RelPosition', [279 39 95 21]);
            obj.hCbAutoStart.TooltipString = sprintf('Auto Start\nWhether to start/stop when acquisition is started/stopped\n(i.e. the Grab button is pressed)');

            obj.hCbUseTrigger = most.gui.uicontrol('Parent',hParent,'Style','checkbox','String','Use Trigger','Tag','cbUseTrigger','RelPosition', [279 63 95 21]);
            obj.hCbUseTrigger.TooltipString = sprintf('Use Trigger\nWhether to use a digital signal trigger, or to start\ncapturing signals as soon as "Start" is pressed.');

            obj.hCbAllowRetrigger = most.gui.uicontrol('Parent',hParent,'Style','checkbox','String','Allow Retrigger','Tag','cbAllowRetrigger','RelPosition', [279 87 95 21]);
            obj.hCbAllowRetrigger.TooltipString = sprintf('Allow Retrigger\nWhether to continue capturing samples after\nthe first trigger on subsequent triggers.');

            obj.hCbUseCompression = most.gui.uicontrol('Parent',hParent,'Style','checkbox','String','Compression','Tag','cbUseCompression','RelPosition', [279 128 95 21]);
            obj.hCbUseCompression.TooltipString = sprintf('Compression\nWhether to compress the data in the\noutput file, useful for large datasets.');

            most.gui.uicontrol('Parent',hParent,'Style','text','String','File Basename','Tag','txFileBaseName','HorizontalAlignment','right','RelPosition', [5 132 106 22]);
            obj.hEtFileBaseName = most.gui.uicontrol('Parent',hParent,'Style','edit','Tag','etFileBaseName','RelPosition', [121 127 142 20]);
            
            most.gui.uicontrol('Parent',hParent,'Style','text','String','File Directory','Tag','txFileDirectory','HorizontalAlignment','right','RelPosition', [5 162 106 22]);
            obj.hEtFileDirectory = most.gui.uicontrol('Parent',hParent,'Style','edit','Tag','etFileDirectory','RelPosition', [121 157 112 20],'Callback',@obj.validateDirectory);
            obj.hEtFileDirectory.TooltipString = sprintf('File Directory\nThe directory to store the output files.');
            hBnDir = most.gui.uicontrol('Parent',hParent,'Style','pushbutton','String','Dir','Callback',@(varargin)obj.chooseDirectory,'Tag','pbDir','RelPosition', [234 157 30 20]);
            hBnDir.TooltipString = obj.hEtFileDirectory.TooltipString;
            
        end
        
        function makeListeners(obj)
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'autoStart','PostSet',@obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'allowRetrigger','PostSet',@obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'useTrigger','PostSet',@obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'useCompression','PostSet',@obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'triggerEdge','PostSet',@obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'hTrigger','PostSet',@obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'sampleRate','PostSet',@obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'sampleDuration','PostSet',@obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'fileBaseName','PostSet',@obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'fileDirectory','PostSet',@obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'configuration','PostSet',@obj.redraw);
        end

        function makeAddChannelFigure(obj)
            if ~isempty(obj.hFigChannelAdd) && ishghandle(obj.hFigChannelAdd)
                obj.hFigChannelAdd.Visible = true;
                most.idioms.figure(obj.hFigChannelAdd)
                return
            end

            obj.hFigChannelAdd = most.idioms.figure('Name','Add Channel','NumberTitle','off','MenuBar','none','Position',most.gui.centeredScreenPos([200 300]));
            most.gui.uicontrol('Parent',obj.hFigChannelAdd,'Style','text','Tag','txAvailSigTitle','String','Click Signal','HorizontalAlignment','right','RelPosition',[31 20 100 14]);
            obj.hTblAvailableSignals = most.gui.uicontrol('Parent',obj.hFigChannelAdd,'Style','uitable','Tag','tblAvailableSignals','ColumnFormat',{'char'},'ColumnEditable',[false],'ColumnName',{'Signal'},'ColumnWidth',{176},'RowName',[],'RelPosition',[4 296 195 275],'CellSelectionCallback',@obj.signalSelected);
        end

        function drawAddChannelFigure(obj)
            % hDIs = obj.hResourceStore.filterByClass(?dabs.resources.ios.DI);
            hAIs = obj.hResourceStore.filter(@(r)isa(r,'dabs.resources.ios.AI')&&isa(r.hDAQ,'dabs.resources.daqs.vDAQ'));
            
            % don't add digital channels for now
            hList = hAIs';

            % hAvailableSignals will always have the same index as hTblAvailableSignals
            obj.hTblAvailableSignals.Data = hList;
            obj.hAvailableSignals = hList;
        end
        
        function redraw(obj,varargin)            
            hDIs = obj.hResourceStore.filter(@(r)most.idioms.isa(r,?dabs.resources.ios.DI) && isa(r.hDAQ,'dabs.resources.daqs.vDAQ'));
            
            % set values from resource
            obj.hPmTrigger.String = [{''}, hDIs];
            obj.hPmTrigger.pmValue = obj.hResource.hTrigger;
            obj.hEtSampleRate.String = num2str(obj.hResource.sampleRate);
            obj.hEtSampleDuration.String = num2str(obj.hResource.sampleDuration);
            obj.hEtFileBaseName.String = obj.hResource.fileBaseName;
            obj.hEtFileBaseName.TooltipString = sprintf(['File Base Name\n'...
                'Files are suffixed with the acquisition number.\n'...
                'Current full filepath:\n%s'],obj.hResource.currentFullname);
            obj.hEtFileDirectory.String = obj.hResource.fileDirectory;
            obj.hCbAutoStart.Value = obj.hResource.autoStart;
            obj.hCbAllowRetrigger.Value = obj.hResource.allowRetrigger;
            obj.hCbUseTrigger.Value = obj.hResource.useTrigger;
            obj.hCbUseCompression.Value = obj.hResource.useCompression;

            % set sample rate tooltip
            sampleRateTip = 'Sample Rate [Hz]\nThe rate to sample the inputs.';
            sampleRateTipArgs = {};
            if obj.hResource.maxSampleRate > 0
                sampleRateTip = [sampleRateTip '\nThe max rate is %d Hz.'];
                sampleRateTipArgs{end+1} = obj.hResource.maxSampleRate;
            end
            sampleRateTip = [sampleRateTip '\nThe min rate is %d Hz.'];
            sampleRateTipArgs{end+1} = obj.hResource.MIN_SAMPLE_RATE;
            obj.hEtSampleRate.TooltipString = sprintf(sampleRateTip,sampleRateTipArgs{:});
            
            obj.controlConfigState();

            obj.configuration = obj.hResource.configuration;
        end

        function controlConfigState(obj,varargin)
            % disable configuration based on state
            if isinf(str2double(obj.hEtSampleDuration.String))
                obj.hCbAllowRetrigger.Enable = false;
                obj.hCbAllowRetrigger.Value = false;
            else
                obj.hCbAllowRetrigger.Enable = true;
            end
        end
        
        function apply(obj)
            setListenersEnabled(false);

            try
                most.idioms.safeSetProp(obj.hResource,'hTrigger',obj.hPmTrigger.pmValue);
                most.idioms.safeSetProp(obj.hResource,'sampleRate',str2double(obj.hEtSampleRate.String));
                most.idioms.safeSetProp(obj.hResource,'sampleDuration',str2double(obj.hEtSampleDuration.String));
                most.idioms.safeSetProp(obj.hResource,'fileBaseName',obj.hEtFileBaseName.String);
                most.idioms.safeSetProp(obj.hResource,'fileDirectory',obj.hEtFileDirectory.String);
                most.idioms.safeSetProp(obj.hResource,'autoStart',obj.hCbAutoStart.Value);
                most.idioms.safeSetProp(obj.hResource,'allowRetrigger',obj.hCbAllowRetrigger.Value);
                most.idioms.safeSetProp(obj.hResource,'useTrigger',obj.hCbUseTrigger.Value);
                most.idioms.safeSetProp(obj.hResource,'useCompression',obj.hCbUseCompression.Value);
                most.idioms.safeSetProp(obj.hResource,'configuration',obj.configuration);
                
                obj.hResource.saveMdf();
                obj.hResource.reinit();

                setListenersEnabled(false);
                obj.checkVdaq();
            catch ME
                setListenersEnabled(false);
                rethrow(ME)
            end
            
            function setListenersEnabled(status)
                for idx = 1:numel(obj.hListeners)
                    obj.hListeners(idx).Enabled = status;
                end
            end
        end
        
        function remove(obj)
            obj.hResource.deleteAndRemoveMdfHeading();
        end
    end

    %% callbacks/listeners
    methods
        function addChannel(obj)
            obj.makeAddChannelFigure();
            obj.drawAddChannelFigure();
        end

        function moveRow(obj,inc)
            if isempty(obj.selectedRow) || obj.selectedRow>numel(obj.configuration)
                return
            end
            
            configuration_ = obj.configuration;
            
            if obj.selectedRow == 1 && inc==-1
                return
            end
            
            if obj.selectedRow == numel(configuration_) && inc==1
                return
            end
            
            swapIdx1 = obj.selectedRow;
            swapIdx2 = obj.selectedRow+inc;
            
            configuration_([swapIdx1,swapIdx2]) = configuration_([swapIdx2,swapIdx1]);
            
            obj.configuration = configuration_;

            obj.selectedRow = swapIdx2;
        end

        function removeRow(obj)
            if isempty(obj.selectedRow) || obj.selectedRow>numel(obj.configuration)
                return
            end
            
            selection = obj.selectedRow;
            obj.configuration(obj.selectedRow) = [];
            
            numRows = numel(obj.configuration);
            selection = min(selection,numRows);
            
            if selection<1
                selection = [];
            end
            
            obj.selectedRow = selection;
        end

        function cellEdited(obj,src,evt)
            % set data based on column index
            if isempty(evt.Indices)
                return
            end

            try
                assert(isnumeric(evt.Indices) && isvector(evt.Indices) && numel(evt.Indices) == 2, 'evt.Indices must be numeric vector in the format [row col]');
                assert(evt.Indices(2) >= 2 && evt.Indices(2) <= 4, 'Invalid column %d', evt.Indices(2));
                assert(evt.Indices(1) >= 1 && evt.Indices(1) <= numel(obj.configuration), 'Invalid row %d, must be within %d', evt.Indices(1), numel(obj.configuration));

                switch evt.Indices(2)
                    % case 1
                    %     obj.configuration(evt.Indices(1)).hIO = evt.NewData;
                    case 2
                        obj.configuration(evt.Indices(1)).name = evt.NewData;
                    case 3
                        obj.configuration(evt.Indices(1)).unit = evt.NewData;
                    case 4
                        obj.configuration(evt.Indices(1)).conversionMultiplier = evt.NewData;
                end
            catch ME
                % TODO: better warn, like in a dialog or something
                most.ErrorHandler.logAndReportError(false,ME);
                errordlg(ME.message);
            end
            
            obj.selectedRow = evt.Indices(1);
        end

        function cellSelected(obj,src,evt)
            if ~isempty(evt.Indices) && evt.Indices(2) == 1
                obj.selectedRow = evt.Indices(1);
            end
        end

        function signalSelected(obj,src,evt)
            if isempty(evt.Indices)
                return
            end

            obj.hFigChannelAdd.Visible = false;
            signal = obj.hAvailableSignals{evt.Indices(1)};

            if obj.configuration.containsSignal(signal)
                ME = most.ErrorHandler.logAndReportError(false,'Already recording signal %s',signal.name);
                errordlg(ME.message);
                return
            end

            conf = dabs.generic.datarecorder.ChannelConfiguration();
            conf.hIO = signal;
            obj.configuration(end+1) = conf;
            obj.selectedRow = numel(obj.configuration);
        end

        function formatTable(obj,varargin)
            % get the configuration table
            table = obj.configuration.toTable();

            % shorten the input names to just the resource name
            % (user information was presented in the add signal dialog)
            table(:,1) = cellfun(@(r)r.name,table(:,1),'UniformOutput',false);

            % bold the selected row
            if size(table,1) >= obj.selectedRow
                table{obj.selectedRow,1} = [...
                    '<html><span style="font-weight:bold;">',...
                    htmlEncode(table{obj.selectedRow,1}),...
                    '</span></html>'];
            end
            obj.hTblSignals.Data = table;
            
            function d = htmlEncode(d)
                d = replace(d,{'<' '>'},{'&lt;' '&gt;'});
            end
        end

        function chooseDirectory(obj,varargin)
            selpath = uigetdir();
            
            if ~isempty(selpath)
                obj.hEtFileDirectory.String = selpath;
            end
        end

        function validateDirectory(obj,src,evt)
            if ~isempty(obj.hEtFileDirectory.String) && exist(obj.hEtFileDirectory.String,'dir') ~= 7
                warndlg('The directory must be present on the system before clicking apply.','Directory not found');
            end
        end
    end

    %% property methods
    methods
        function set.configuration(obj,v)
            obj.configuration = v;
            obj.formatTable();
        end

        function set.selectedRow(obj,v)
            obj.selectedRow = v;
            obj.formatTable();
        end
    end

    %% Util
    methods
        function checkVdaq(obj)
            showUpgradeMessage = false;

            if ~isempty(obj.hResource.hDAQ)
                assert(most.idioms.isa(obj.hResource.hDAQ,?dabs.resources.daqs.vDAQ),'DAQ must be a vDAQ');
                
                hardwareInfo = dabs.vidrio.vDAQ.lookupHardwareInfo(obj.hResource.hDAQ);
                showUpgradeMessage = ~isempty(hardwareInfo) ...
                        && (hardwareInfo.lsadcVersion < obj.hResource.PREFERRED_LSADC_VER ...
                        || hardwareInfo.dacVersion < obj.hResource.PREFERRED_DAC_VER);
            end

            if showUpgradeMessage
                upgradeMessage = ['There is a hardware upgrade available for this vDAQ which\n'...
                    'improves the performance of the Data Recorder.'];
                obj.txtUpgradeMessage.String = sprintf(upgradeMessage);
                obj.txtUpgradeMessage.Visible = 'on';
                obj.pbUpgradeContact.Visible = 'on';
            else
                obj.txtUpgradeMessage.Visible = 'off';
                obj.pbUpgradeContact.Visible = 'off';
            end
        end

        function goToSupport(obj, varargin)
            web('https://vidriotechnologies.com/contact-us/', '-browser')
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
