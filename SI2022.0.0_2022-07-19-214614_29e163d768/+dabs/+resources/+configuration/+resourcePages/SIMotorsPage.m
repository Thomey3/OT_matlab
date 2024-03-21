classdef SIMotorsPage < dabs.resources.configuration.ResourcePage
    properties
        tblAxes
        tblAxesAdvanced
        etMoveTimeout_s
    end
    
    methods
        function obj = SIMotorsPage(hResource,hParent)
            obj@dabs.resources.configuration.ResourcePage(hResource,hParent);
        end
        
        function makePanel(obj,hParent)
            hTabGroup = uitabgroup('Parent',hParent);

            hTab = uitab('Parent',hTabGroup,'Title','Basic');
                obj.tblAxes = most.gui.uicontrol('Parent',hTab','Style','uitable','Tag','tblAxes','RelPosition',[10 82 360 80]);
                
                panel = most.gui.uicontrol('Parent',hTab,'Style','uipanel','RelPosition', [10 265 360 180],'Tag','panel');
                dabs.resources.configuration.resourcePages.private.stageCoordinates(panel.hCtl);
            
            hTab = uitab('Parent',hTabGroup,'Title','Advanced');
                obj.tblAxesAdvanced = most.gui.uicontrol('Parent',hTab','Style','uitable','Tag','tblAxes','RelPosition',[10 82 200 80]);

                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [20 114 110 20],'Tag','txMoveTimeout_s','String','Move timeout [s]','HorizontalAlignment','right');
                obj.etMoveTimeout_s = most.gui.uicontrol('Parent',hTab,'Style','edit','String','','RelPosition', [140 112 40 20],'Tag','etMoveTimeout_s');
        end
        
        function redraw(obj)
            obj.hResource.validateConfiguration();
            
            hMotors = obj.hResourceStore.filterByClass('dabs.resources.devices.MotorController');
            numMotors = numel(hMotors);
            
            axisNames = {};
            for motorIdx = 1:numMotors
                hMotor = hMotors{motorIdx};
                for axIdx = 1:hMotor.numAxes
                    axisNames{end+1} = sprintf('%s - motor %d',hMotor.name,axIdx);
                end
            end

            obj.tblAxes.hCtl.RowName = [];
            obj.tblAxes.hCtl.ColumnName = {'Sample','Motor assignment','Scale'};
            obj.tblAxes.hCtl.ColumnFormat = {'char',[{' '}, axisNames],'numeric'};
            obj.tblAxes.hCtl.ColumnEditable = [false,true,true];
            obj.tblAxes.hCtl.ColumnWidth = {50 260 40};
            obj.tblAxes.hCtl.Data = makeTableData();
            
            obj.tblAxesAdvanced.hCtl.RowName = [];
            obj.tblAxesAdvanced.hCtl.ColumnName = {'Sample','Backlash Compensation'};
            obj.tblAxesAdvanced.hCtl.ColumnFormat = {'char','numeric'};
            obj.tblAxesAdvanced.hCtl.ColumnEditable = [false,true];
            obj.tblAxesAdvanced.hCtl.ColumnWidth = {50 140};
            obj.tblAxesAdvanced.hCtl.Data = makeTableDataAdvanced();

            obj.etMoveTimeout_s.String = num2str(obj.hResource.moveTimeout_s);

            %%% Nested functions
            function data = makeTableData()
                rowNameXYZ = {'X Axis';'Y Axis';'Z Axis'};

                numAxes = numel(obj.hResource.hMotorXYZ);
                nameXYZ = cell(numAxes,1);
                for idx = 1:numAxes
                    nameXYZ{idx} = sprintf('%s - motor %d',obj.hResource.hMotorXYZ{idx}.name,obj.hResource.motorAxisXYZ(idx));
                end

                scaleXYZ = num2cell(obj.hResource.scaleXYZ(:));

                data = [rowNameXYZ,nameXYZ,scaleXYZ];
            end

            function data = makeTableDataAdvanced()
                rowNameXYZ = {'X Axis';'Y Axis';'Z Axis'};
                backlashCompensation = num2cell(obj.hResource.backlashCompensation(:));

                data = [rowNameXYZ,backlashCompensation];
            end
        end
        
        function apply(obj)
            [motorNameXYZ,motorAxisXYZ,scaleXYZ] = parseTable();
            
            most.idioms.safeSetProp(obj.hResource,'hMotorXYZ',motorNameXYZ);
            most.idioms.safeSetProp(obj.hResource,'motorAxisXYZ',motorAxisXYZ);
            most.idioms.safeSetProp(obj.hResource,'scaleXYZ',scaleXYZ);

            backlashCompensation = parseAdvancedTable();
            most.idioms.safeSetProp(obj.hResource,'backlashCompensation',backlashCompensation);

            most.idioms.safeSetProp(obj.hResource,'moveTimeout_s',str2double(obj.etMoveTimeout_s.String));
             
            obj.hResource.saveMdf();
            obj.hResource.reinit();
            obj.hResource.validateConfiguration();
            
            %%% Nested function
            function [motorNameXYZ,motorAxisXYZ,scaleXYZ] = parseTable()
                data = obj.tblAxes.hCtl.Data;
                numMotors = size(data,1);
                rowNameXYZ = data(:,1);
                nameXYZ    = data(:,2);
                scaleXYZ   = data(:,3);

                motorNameXYZ = cell(1,numMotors);
                motorAxisXYZ = 1:numMotors;
                for idx = 1:numMotors
                    name = nameXYZ{idx};
                    if ~strcmp(name,' ')
                        match = regexpi(name,'(.*) - motor ([0-9]+)','tokens','once');
                        motorNameXYZ{idx} = match{1};
                        motorAxisXYZ(idx) = str2double(match{2});
                    end
                end

                scaleXYZ = cell2mat(scaleXYZ');
            end

            function backlashCompensation = parseAdvancedTable()
                data = obj.tblAxesAdvanced.Data;
                rowNameXYZ = data(:,1);
                backlashCompensation = data(:,2);
                backlashCompensation = cell2mat(backlashCompensation');
            end
        end
        
        function remove(obj)
            % No-op
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
