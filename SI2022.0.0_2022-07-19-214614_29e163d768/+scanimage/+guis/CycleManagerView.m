classdef CycleManagerView < handle
% CYCLEMANAGER View class for cycle mode
    properties
        gui
        model
        controller
    end

    methods
        function obj = CycleManagerView(controller)
            obj.controller = controller;
            obj.model = controller.model;
            policy = 'reuse';
            visibility = false;
            obj.gui = cycleModeControlsV5(policy,visibility,controller);


            most.ErrorHandler.addCatchingListener(obj.model,'enabled','PostSet',...
                @(src,evnt)scanimage.guis.CycleManagerView.handlePropEvents(obj,src,evnt));

            most.ErrorHandler.addCatchingListener(obj.model,'cyclesCompleted','PostSet',...
                @(src,evnt)scanimage.guis.CycleManagerView.handlePropEvents(obj,src,evnt));
            most.ErrorHandler.addCatchingListener(obj.model,'totalCycles','PostSet',...
                @(src,evnt)scanimage.guis.CycleManagerView.handlePropEvents(obj,src,evnt));
            most.ErrorHandler.addCatchingListener(obj.model,'itersCompleted','PostSet',...
                @(src,evnt)scanimage.guis.CycleManagerView.handlePropEvents(obj,src,evnt));
            % cycleIterIdxTotal doesn't need a listener, since it's dependent on cycleDataGroup.cycleIters

            most.ErrorHandler.addCatchingListener(obj.model,'cycleDataGroup','PostSet',...
                @(src,evnt)scanimage.guis.CycleManagerView.handlePropEvents(obj,src,evnt));

            most.ErrorHandler.addCatchingListener(obj.controller,'showAdvancedParameters','PostSet',...
                @(src,evnt)scanimage.guis.CycleManagerView.handlePropEvents(obj,src,evnt));

            % Refresh the model to trigger listeners for GUI initialization (reduces code duplication)
            obj.model.refresh;
        end

        function delete(obj)
            if ishandle(obj.gui)
                close(obj.gui);
                delete(obj.gui);
            end
        end
    end

    methods (Static)
        function handlePropEvents(obj,src,evnt)
            evntobj = evnt.AffectedObject;
            handles = guidata(obj.gui);

            switch src.Name
                case 'enabled'
                    hCtl = obj.model.hSI.hController{1};
                    
                    if most.idioms.isValidObj(hCtl)
                        hB = hCtl.hGUIData.mainControlsV4.startLoopButton;
                        if evntobj.enabled
                            hB.String = 'CYCLE';
                        else
                            hB.String = 'LOOP';
                        end
                    end
                    set(handles.cbCycleOn, 'Value', evntobj.enabled);
                case 'cyclesCompleted'
                    set(handles.etCycleCount, 'String',num2str(obj.model.cyclesCompleted));
                case 'totalCycles'
                    set(handles.etNumCycleRepeats, 'String',num2str(obj.model.totalCycles));
                case 'itersCompleted'
                    set(handles.etCycleIteration, 'String',num2str(evntobj.itersCompleted));
                case 'cycleDataGroup'
                    % Populate uitable
                    tableData = scanimage.guis.CycleManagerView.cycleDataGroupIterationsToTableData(evntobj.cycleDataGroup.cycleIters);
                    set(handles.tblCycle, 'Data',tableData);
                    set(handles.etCycleLength, 'String',num2str(obj.model.cycleIterIdxTotal));
                    set(handles.cbGoHomeAtCycleEnd, 'Value', evntobj.cycleDataGroup.goHomeAtCycleEndEnabled);
                    %autoResetModeEnabled
                    set(handles.cbCycleAutoReset, 'Value', evntobj.cycleDataGroup.autoResetModeEnabled);
                    if evntobj.cycleDataGroup.autoResetModeEnabled
                        set(handles.etIterationsPerLoop, 'Enable', 'off');
                        set(handles.pbCycleReset, 'Enable', 'off');
                    else
                        set(handles.etIterationsPerLoop, 'Enable', 'on');
                        set(handles.pbCycleReset, 'Enable', 'on');
                    end
                    %restoreOriginalCFGEnabled
                    set(handles.cbRestoreOriginalCFG, 'Value', evntobj.cycleDataGroup.restoreOriginalCFGEnabled);
                    %name
                    [~,fname,~] = fileparts(evntobj.cycleDataGroup.name);
                    set(handles.etCycleName, 'String', fname);
                case 'showAdvancedParameters'
                    rectPrev = get(handles.output,'Position');
                    if evntobj.showAdvancedParameters
                        set(handles.output,'Position',[rectPrev(1) rectPrev(2) 195.5 rectPrev(4)]);
                        set(handles.tbShowAdvanced,'String','<<');
                    else
                        set(handles.output,'Position',[rectPrev(1) rectPrev(2) 41.5 rectPrev(4)]);
                        set(handles.tbShowAdvanced,'String','>>');
                    end
            end
        end

        function tableData = cycleDataGroupIterationsToTableData(cycleIterGroup)
            if isempty(cycleIterGroup)
                % This is an artifice.
                %tableData = {blanks(0) [] 'Posn #' blanks(0) [] [] [] [] [] blanks(0) [] [] []};
                tableData = {};
                return;
            end

            %+++ CAREFUL! Setting manually for now
            numCols = 13;
            numRows = numel(cycleIterGroup);
            tableData = cell([numRows, numCols]);

            for i = 1:numRows
                cycleIter = cycleIterGroup(i);
                if cycleIter.cfgName
                    [~,fname,~] = fileparts(cycleIter.cfgName);
                else
                    fname = '';
                end
                tableData{i,1} = fname;
                tableData{i,2} = cycleIter.iterDelay;
                tableData{i,3} = cycleIter.motorAction;
                tableData{i,4} = cycleIter.motorStep;
                tableData{i,5} = cycleIter.repeatPeriod;
                tableData{i,6} = cycleIter.numRepeats;
                tableData{i,7} = cycleIter.numSlices;
                tableData{i,8} = cycleIter.zStepPerSlice;
                tableData{i,9} = cycleIter.numFrames;
                tableData{i,10} = cycleIter.power;
                tableData{i,11} = cycleIter.numAvgFrames;
                tableData{i,12} = cycleIter.framesPerFile;
                tableData{i,13} = cycleIter.lockFramesPerFile;
            end
        end


    end
end

%% +++ Make a static method to parse CycldeDataGroup into strings for the uitable
%'ColumnName',{  'Config|Name'; 'Iteration|Delay'; 'Motor|Action'; 'Motor Step/|Posn #/ROI #'; 'Repeat|Period'; '#|Repeats'; '#|Slices'; 'Z Step|/Slice'; '#|Frames'; 'Power'; '# Avg|Frames'; 'Frames|/File'; 'Lock|Frames/File' },...
%'ColumnFormat',{  'char' 'numeric' {  'Posn #' 'ROI #' 'Step' } 'char' 'numeric' 'numeric' 'numeric' 'numeric' 'numeric' 'char' 'numeric' 'numeric' 'logical' },...
%'Data',{  blanks(0) [] 'Posn #' blanks(0) [] [] [] [] [] blanks(0) [] [] []; blanks(0) [] 'Posn #' blanks(0) [] [] [] [] [] blanks(0) [] [] [] },...





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
