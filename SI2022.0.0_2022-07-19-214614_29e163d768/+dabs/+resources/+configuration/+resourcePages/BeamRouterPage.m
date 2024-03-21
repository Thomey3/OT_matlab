classdef BeamRouterPage < dabs.resources.configuration.ResourcePage
    properties
        tablehBeams
        pmFunctionHandle
        pmFunctionHandleCalibration
    end
    
    methods
        function obj = BeamRouterPage(hResource,hParent)
            obj@dabs.resources.configuration.ResourcePage(hResource,hParent);
        end
        
        function makePanel(obj,hParent)
            obj.tablehBeams    = most.gui.uicontrol('Parent',hParent,'Style','uitable','ColumnFormat',{'char','logical'},'ColumnEditable',[false,true],'ColumnName',{'Beam','Use'},'ColumnWidth',{80 30},'RowName',[],'RelPosition', [10 223 115 110],'Tag','tablehBeams');

            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [10 23 100 17],'Tag','txFunctionHandle','String','Function handle','HorizontalAlignment','left');
            obj.pmFunctionHandle = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String','passThrough','RelPosition', [10 42 310 20],'Tag','pmFunctionHandle','HorizontalAlignment','left');
            most.gui.uicontrol('Parent',hParent,'String','Edit','RelPosition', [330 42 40 20],'Tag','pbEditFunction','Callback',@(varargin)obj.editFunction);
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [10 73 130 20],'Tag','txFunctionHandleCalibration','String','Calibration function handle','HorizontalAlignment','left');
            obj.pmFunctionHandleCalibration = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String','defaultCalibration','RelPosition', [10 88 310 20],'Tag','etFunctionHandleCalibration','HorizontalAlignment','left');
            most.gui.uicontrol('Parent',hParent,'String','Edit','RelPosition', [330 88 40 20],'Tag','pbEditCalibrationFunction','Callback',@(varargin)obj.editCalibrationFunction);
            
            most.gui.uicontrol('Parent',hParent,'String','Use example functions','Callback',@(varargin)obj.useExampleFunctions,'RelPosition', [230 132 140 30],'Tag','pbExamples');
        end
        
        function redraw(obj)            
            allBeams = obj.hResourceStore.filterByClass('dabs.resources.devices.BeamModulatorFast');
            allBeamNames = cellfun(@(hR)hR.name,allBeams,'UniformOutput',false);
            beamNames = cellfun(@(hR)hR.name,obj.hResource.hBeams,'UniformOutput',false);
            selected = ismember(allBeamNames,beamNames);
            obj.tablehBeams.Data = most.idioms.horzcellcat(allBeamNames,num2cell(selected));

            mFiles = what('+dabs\+generic\+beamrouter\+functions');
            mFiles = mFiles.m;
            functionNames = cellfun(@(c)c(1:end-2),mFiles,'UniformOutput',false);
            obj.pmFunctionHandle.String = [{''}; functionNames];
            
            functionString = func2str(obj.hResource.functionHandle);
            if ~isempty(functionString)
                obj.pmFunctionHandle.pmValue = obj.shortenFunctionName(functionString);
            end

            mFiles = what('+dabs\+generic\+beamrouter\+calibrations');
            mFiles = mFiles.m;
            calibrationNames = cellfun(@(c)c(1:end-2),mFiles,'UniformOutput',false);
            obj.pmFunctionHandleCalibration.String = [{''}; calibrationNames];
            obj.pmFunctionHandleCalibration.pmValue = func2str(obj.hResource.functionHandleCalibration);
            
            calibrationString = func2str(obj.hResource.functionHandleCalibration);
            obj.pmFunctionHandleCalibration.pmValue = obj.shortenFunctionName(calibrationString);
        end

        function str = shortenFunctionName(obj,str)
            str = regexpi(str,'[a-z][a-z0-9_]*$','match','once');
        end
        
        function apply(obj)
            beamNames = obj.tablehBeams.Data(:,1)';
            selected   = [obj.tablehBeams.Data{:,2}];
            beamNames = beamNames(selected);
            most.idioms.safeSetProp(obj.hResource,'hBeams',beamNames);
            
            if ~isempty(obj.pmFunctionHandle.pmValue)
                most.idioms.safeSetProp(obj.hResource,'functionHandle',['dabs.generic.beamrouter.functions.' obj.pmFunctionHandle.pmValue]);
            else
                most.idioms.safeSetProp(obj.hResource,'functionHandle',['dabs.generic.beamrouter.functions.passThrough']);
            end
            
            if ~isempty(obj.pmFunctionHandleCalibration.pmValue)
                most.idioms.safeSetProp(obj.hResource,'functionHandleCalibration',['dabs.generic.beamrouter.calibrations.' obj.pmFunctionHandleCalibration.pmValue]);
            else
                most.idioms.safeSetProp(obj.hResource,'functionHandleCalibration','dabs.generic.beamrouter.calibrations.defaultCalibration');
            end
            
            obj.hResource.saveMdf();
            obj.hResource.reinit();
        end
        
        function useExampleFunctions(obj)
            try
                obj.hResource.useExampleFunctions();
                obj.redraw();
                obj.editFunction();
                obj.editCalibrationFunction();
            catch ME
                most.ErrorHandler.logAndReportError(ME);
                obj.redraw();
            end
        end
        
        function editFunction(obj)
            edit(['dabs.generic.beamrouter.functions.' obj.pmFunctionHandle.pmValue]);
            drawnow();
            obj.raise();
        end
        
        function editCalibrationFunction(obj)
            edit(['dabs.generic.beamrouter.functions.' obj.pmFunctionHandleCalibration.pmValue]);
            drawnow();
            obj.raise();    
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
