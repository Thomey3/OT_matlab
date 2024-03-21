classdef SlmAlignmentWithMotionCorrection < most.Gui
    properties
        hSlmScan
        hSI
        hSICtl
        hFlowPoints
        
        hListeners = event.listener.empty();
    end
    
    methods
        function obj = SlmAlignmentWithMotionCorrection(hSlmScan)
            obj = obj@most.Gui([],[],[40 20],'characters');
            obj.hSlmScan = hSlmScan;
        end
        
        function delete(obj)
            delete(obj.hListeners);
        end
    end
    
    methods (Access = protected)
        function initGui(obj)
            obj.hSI = obj.hSlmScan.hSI;
            obj.hSICtl = obj.hSI.hController{1};
            
            set(obj.hFig,'Name',sprintf('%s ALIGNMENT',obj.hSlmScan.name),'Resize','off');
            
            mainFlow = most.gui.uiflowcontainer('Parent',obj.hFig,'FlowDirection','TopDown');
            hPanel = uipanel('Parent',mainFlow,'Title',sprintf('%s Lateral Alignment',obj.hSlmScan.name));
            
            flow = most.gui.uiflowcontainer('Parent',hPanel,'FlowDirection','TopDown');
            obj.addUiControl('Parent',flow,'HeightLimits',[30 30],'Tag','pbStartFocus','String','Start Focus','Callback',@(varargin)obj.startFocus);
            obj.addUiControl('Parent',flow,'HeightLimits',[30 30],'Tag','txStatus1','Style','text','HorizontalAlignment','left');
            obj.addUiControl('Parent',flow,'HeightLimits',[30 30],'Tag','pbStartAlignment','String','Start Alignment','Callback',@(varargin)obj.activateMotionCorrection);
            obj.addUiControl('Parent',flow,'HeightLimits',[70 70],'Tag','txStatus2','Style','text','HorizontalAlignment','left');
            obj.addUiControl('Parent',flow,'HeightLimits',[30 30],'Tag','pbAddAlignmentPoint','String','Add Alignment Point','Callback',@(varargin)obj.addAlignmentPoint);
            
            obj.hFlowPoints = most.gui.uiflowcontainer('Parent',flow,'FlowDirection','LeftToRight','HeightLimits',[20 20]);
            obj.addUiControl('Parent',obj.hFlowPoints,'Style','text','Tag','txNumberAlignmentPoints');
            obj.addUiControl('Parent',obj.hFlowPoints,'String','Reset','Callback',@(varargin)obj.resetAlignmentPoints,'WidthLimits',[35 35]);
            
            obj.addUiControl('Parent',flow,'HeightLimits',[85 85],'Tag','txStatus3','Style','text','HorizontalAlignment','left');
            obj.addUiControl('Parent',flow,'HeightLimits',[30 30],'Tag','pbFinishAlignment','String','Finish Alignment','Callback',@(varargin)obj.finishAlignment);
            
            obj.addUiControl('Parent',flow,'HeightLimits',[30 30],'String','View Alignment Matrix','Callback',@(varargin)obj.viewAlignmentMatrix);
            
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hSI,'acqState','PostSet',@(varargin)obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hSI.hMotionManager,'enable','PostSet',@(varargin)obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hSlmScan,'alignmentPoints','PostSet',@(varargin)obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hSlmScan,'ObjectBeingDestroyed',@(varargin)obj.delete);
            
            obj.redraw();
        end
    end
    
    methods
        function startFocus(obj)
            if ~strcmpi(obj.hSI.acqState,'idle')
                obj.hSlmScan.abortAlignment();
            else
                obj.hSI.abort();
                
                if obj.hSI.hScan2D ~= obj.hSlmScan.hLinScan
                    obj.hSI.imagingSystem = obj.hSlmScan.hLinScan.name;
                end
                
                if isa(obj.hSI.hScan2D,'scanimage.components.scan2d.RggScan')
                    obj.hSI.hScan2D.scanMode = 'linear';
                end
                
                obj.hSI.hScan2D.stripingEnable = false;
                
                obj.hSI.abort();
                obj.hSI.startFocus();
            end
        end
        
        function activateMotionCorrection(obj)
            assert(strcmpi(obj.hSI.acqState,'focus'));
            assert(obj.hSI.hScan2D == obj.hSlmScan.hLinScan);
            
            obj.hSICtl.hMotionDisplay.raise();
            obj.hSlmScan.showPhaseMaskDisplay();
            
            %most.gui.tetherGUIs(obj.hFig,obj.hSICtl.hMotionDisplay.hFig,'righttop');
            %most.gui.tetherGUIs(obj.hSICtl.hMotionDisplay.hFig,obj.hSlmScan.hSlm.hPhaseMaskDisplay.hFig,'righttop');
            
            if obj.hSI.hScan2D.stripingEnable
                obj.hSI.abort();
                obj.hSI.hScan2D.stripingEnable = false;
                obj.hSI.startFocus();
                pause(2); % wait for a frame to be acquired
            end
            
            obj.hSlmScan.setAlignmentReference();
            
            obj.raise();
        end
        
        function addAlignmentPoint(obj)
            obj.hSlmScan.addAlignmentPoint();
        end
        
        function finishAlignment(obj)
            obj.hSlmScan.createAlignmentMatrix();
        end
        
        function viewAlignmentMatrix(obj)
            T = obj.hSlmScan.scannerToRefTransform;
            assignin('base','scannerToRefTransform',T);
            msg = sprintf('%s scannerToRefTransform:\n%s',obj.hSlmScan.name,mat2str(T,3));
            helpdlg(msg);
            
            fprintf('%s\n',msg);
        end
        
        function resetAlignmentPoints(obj)
            obj.hSlmScan.resetAlignmentPoints();
        end
        
        function redraw(obj)
            enablePbStartFocus = true;
            enablePbStartAlignment = false;
            enablePbAddAlignmentPoint = false;
            enablePbFinishAlignment = false;
            
            obj.txStatus1.String = sprintf('Start a focus using imaging system ''%s'' (Linear)',obj.hSlmScan.hLinScan.name);
            obj.txStatus2.String = 'Focus onto the sample and find a region with sufficient structure for the automated motion correction to lock onto. Then select ''Start Alignment''';
            obj.txStatus3.String = 'Use the ''Phase Mask Display'' to move the SLM focal point laterally. Then select ''Add Alignment Point''. A minimum of two alignment points is needed to finish the alignment.';
            obj.txNumberAlignmentPoints.String = sprintf('Number of points: %d',size(obj.hSlmScan.alignmentPoints,1));
            
            if ~strcmpi(obj.hSI.acqState,'idle')
                obj.pbStartFocus.String = 'Abort';
            else
                obj.pbStartFocus.String = 'Start Focus';
            end
            
            if strcmpi(obj.hSI.acqState,'focus') && obj.hSI.hScan2D == obj.hSlmScan.hLinScan
                enablePbStartAlignment = true;
            end
            
            if enablePbStartAlignment && obj.hSI.hMotionManager.enable
                enablePbAddAlignmentPoint = true;
            end
            
            if enablePbAddAlignmentPoint && size(obj.hSlmScan.alignmentPoints,1)>=2
                enablePbFinishAlignment = true;
            end
            
            obj.pbStartFocus.Enable = enablePbStartFocus;
            obj.txStatus1.Visible = enablePbStartFocus && ~enablePbStartAlignment;
            obj.pbStartAlignment.Enable = enablePbStartAlignment;
            obj.txStatus2.Visible = enablePbStartAlignment && ~enablePbAddAlignmentPoint;
            obj.pbAddAlignmentPoint.Enable = enablePbAddAlignmentPoint;
            obj.hFlowPoints.Visible = enablePbAddAlignmentPoint || enablePbFinishAlignment;
            obj.txStatus3.Visible = enablePbAddAlignmentPoint || enablePbFinishAlignment;
            obj.pbFinishAlignment.Enable = enablePbFinishAlignment;
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
