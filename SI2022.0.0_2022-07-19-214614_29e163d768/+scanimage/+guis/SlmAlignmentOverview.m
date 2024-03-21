classdef SlmAlignmentOverview < most.Gui
    properties
        hSlmScan
        hListeners = event.listener.empty();
    end
    
    properties (Dependent)
        hSI
        hSICtl
    end
    
    methods
        function obj = SlmAlignmentOverview(hSlmScan)
            obj = obj@most.Gui([],[],[40 15],'characters');
            obj.hSlmScan = hSlmScan;
        end
        
        function delete(obj)
            delete(obj.hListeners);
        end
    end
    
    methods (Access = protected)
        function initGui(obj)
            set(obj.hFig,'Name',sprintf('%s ALIGNMENT',obj.hSlmScan.name),'Resize','off');
            
            mainFlow = most.gui.uiflowcontainer('Parent',obj.hFig,'FlowDirection','TopDown');
                hPanel = uipanel('Parent',mainFlow,'Title',sprintf('%s Alignment',obj.hSlmScan.name));
                panelFlow = most.gui.uiflowcontainer('Parent',hPanel,'FlowDirection','TopDown');
                    hTabGroup = uitabgroup('Parent',panelFlow);
                    hTab = uitab('Parent',hTabGroup,'Title','SLM+Galvos');
                        flow = most.gui.uiflowcontainer('Parent',hTab,'FlowDirection','TopDown');
                        obj.addUiControl('Parent',flow,'Tag','pbGGToImaging','String',['Galvos ' most.constants.Unicode.rightwards_arrow ' Imaging Path'],'Callback',@(varargin)obj.showGGAlignment);
                        obj.addUiControl('Parent',flow,'Tag','pbSlmToGG','String',['SLM ' most.constants.Unicode.rightwards_arrow ' Galvos'],'Callback',@(varargin)obj.showLateralAlignment);
                        obj.addUiControl('Parent',flow,'Tag','pbSlmZToStage','String',['SLM Z ' most.constants.Unicode.rightwards_arrow ' Stage'],'Callback',@(varargin)obj.showZAlignment);
                        obj.addUiControl('Parent',flow,'Tag','pbSlmDiffractionEfficiency1','String','SLM Diffraction efficiency','Callback',@(varargin)obj.showDiffractionEfficiencyTool(false));

                    hTab = uitab('Parent',hTabGroup,'Title','SLM (standalone)');
                        flow = most.gui.uiflowcontainer('Parent',hTab,'FlowDirection','TopDown');
                        obj.addUiControl('Parent',flow,'Tag','pbSlmDiffractionEfficiency2','String','SLM Diffraction efficiency','Callback',@(varargin)obj.showDiffractionEfficiencyTool(true));
                        obj.addUiControl('Parent',flow,'Tag','pbSlmSpatialCalibrationTool','String','SLM Battern burn tool','Callback',@(varargin)obj.showSlmSpatialCalibrationTool);
                
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hSlmScan,'ObjectBeingDestroyed',@(varargin)obj.delete);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hSlmScan.hCSScannerToRef,'changed',@(varargin)obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hSlmScan.hCSSlmZAlignmentLut,'changed',@(varargin)obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hSlmScan.hSlm.hCSDiffractionEfficiency,'changed',@(varargin)obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hSlmScan.hCSSlmAlignmentLut,'changed',@(varargin)obj.redraw);
            
            if most.idioms.isValidObj(obj.hSlmScan.hLinScan)
                obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hSlmScan.hLinScan,'scannerToRefTransform','PostSet',@(varargin)obj.redraw);
            end
            
            obj.redraw();
        end
    end
    
    methods
        function showGGAlignment(obj)            
            obj.hSICtl.hAlignmentControls.showWindow = true;
            obj.hSICtl.hAlignmentControls.raise();
            obj.hSICtl.hAlignmentControls.Visible = true;
            obj.hSICtl.hAlignmentControls.videoImToRefImTransform = eye(3);
            most.idioms.figure(obj.hSICtl.hAlignmentControls.hAlignmentFig);
            
            most.gui.tetherGUIs(obj.hFig,obj.hSICtl.hAlignmentControls.hFig,'righttop');
            most.gui.tetherGUIs(obj.hSICtl.hAlignmentControls.hFig,obj.hSICtl.hAlignmentControls.hAlignmentFig,'righttop');
            
            msg = sprintf(['1) Copy a channel from the imaging path into the alignment window.\n' ...
                           '2) Start imaging with scanner ''%s''\n' ...
                           '3) Add alignment points by right clicking into the alignment window\n' ...
                           '4) Drag the alignment points to overlay the two images\n' ...
                           '5) Select ''Save Scanner Alignment'' to save the alignment'] ...
                           ,obj.hSI.hSlmScan.hLinScan.name);
            
            msgbox(msg,'Galvo Alignment','help');
        end
        
        function showLateralAlignment(obj)
            obj.hSlmScan.showLaterAlignmentControls();
            most.gui.tetherGUIs(obj.hFig,obj.hSlmScan.hLateralAlignmentControls.hFig,'righttop');
        end
        
        function showDiffractionEfficiencyTool(obj,allowSavingZCalibration)
            hTool = obj.hSICtl.hGuiClasses.SubStageCameraSlmCalibration;
            hTool.allowSavingZCalibration = allowSavingZCalibration;
            hTool.raise();
        end
        
        function showSlmSpatialCalibrationTool(obj)
            obj.hSICtl.hGuiClasses.SlmSpatialCalibration.raise();
        end
        
        function showZAlignment(obj)
            obj.hSlmScan.showZAlignmentControls();
        end
        
        function redraw(obj)
            redrawPbGGToImaging();
            redrawPbSlmToGG();
            redrawPbSlmZToStage();
            redrawPbSlmDiffractionEfficiency();
            redrawPbSlmSpatialCalibrationTool();
            
            function redrawPbGGToImaging()
                if most.idioms.isValidObj(obj.hSlmScan.hLinScan)
                    enable = true;
                    T = obj.hSlmScan.hLinScan.scannerToRefTransform;
                    if isequal(T,eye(size(T)))
                        color = most.constants.Colors.lightGray;
                    else
                        color = most.constants.Colors.lightGreen;
                    end
                    
                    tooltip = mat2str_(T);
                else
                    enable = false;
                    color = most.constants.Colors.lightGray;
                    tooltip = '';
                end
                
                obj.pbGGToImaging.Enable = enable;
                obj.pbGGToImaging.hCtl.BackgroundColor = color;
                obj.pbGGToImaging.hCtl.TooltipString = tooltip;
            end
            
            function redrawPbSlmToGG()
                hCS = obj.hSlmScan.hCSScannerToRef;
                isSetToParentAffine   = ~isempty(hCS.toParentAffine)   && ~isequal(hCS.toParentAffine,  eye(4));
                isSetFromParentAffine = ~isempty(hCS.fromParentAffine) && ~isequal(hCS.fromParentAffine,eye(4));
                
                if isSetToParentAffine
                    color = most.constants.Colors.lightGreen;
                    T = hCS.toParentAffine;
                    tooltip = mat2str_(T);
                elseif isSetFromParentAffine
                    color = most.constants.Colors.lightGreen;
                    T = hCS.fromParentAffine;
                    tooltip = mat2str_(T);
                else
                    color = most.constants.Colors.lightGray;
                    tooltip = '';
                end
                
                obj.pbSlmToGG.hCtl.BackgroundColor = color;
                obj.pbSlmToGG.hCtl.TooltipString = tooltip;
            end
            
            function redrawPbSlmZToStage()
                hCS = obj.hSlmScan.hCSSlmZAlignmentLut;
                if isempty(hCS.toParentLutEntries) && isempty(hCS.fromParentLutEntries)
                    color = most.constants.Colors.lightGray;
                else
                    color = most.constants.Colors.lightGreen;
                end
                
                obj.pbSlmZToStage.hCtl.BackgroundColor = color;
            end
            
            function redrawPbSlmDiffractionEfficiency()
                hCS = obj.hSlmScan.hSlm.hCSDiffractionEfficiency;
                hInterpolant = hCS.fromParentInterpolant{1};
                unCalibrated = isa(hInterpolant,'griddedInterpolant');
                
                if unCalibrated
                    color = most.constants.Colors.lightGray;
                else
                    color = most.constants.Colors.lightGreen;
                end
                
                obj.pbSlmDiffractionEfficiency1.hCtl.BackgroundColor = color;
                obj.pbSlmDiffractionEfficiency2.hCtl.BackgroundColor = color;
            end
            
            function redrawPbSlmSpatialCalibrationTool()
                hCS = obj.hSlmScan.hCSSlmAlignmentLut;
                
                toParentInterpolantSet   = all(cellfun(@(c)isempty(c),{hCS.toParentInterpolant}));
                fromParentInterpolantSet = all(cellfun(@(c)isempty(c),{hCS.fromParentInterpolant}));
                
                if toParentInterpolantSet || fromParentInterpolantSet
                    color = most.constants.Colors.lightGreen;
                else
                    color = most.constants.Colors.lightGray;
                end
                
                obj.pbSlmSpatialCalibrationTool.hCtl.BackgroundColor = color;
            end
        end
    end
    
    methods
        function val = get.hSI(obj)
            val = obj.hSlmScan.hSI;
        end
        
        function val = get.hSICtl(obj)
            val = obj.hSlmScan.hSI.hController{1};
        end
    end
end

%%% Local function
function str = mat2str_(T)
    str = mat2str(T,3);
    str = regexprep(str,';',';\n');
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
