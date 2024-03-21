classdef SlmZAlignmentControls < most.Gui
    properties (SetObservable)
        lutInputIncrement  = 10;
        lutOutputIncrement = 1;
        linkToLateralAlignmentControls = false;
    end
    
    properties (SetAccess = private)
        hSlmScan = [];
        hAx
        hLine
        hLineMarkers
        hPositionMarker
        hCS
        hListeners = event.listener.empty();
        currentSlmInZ;
        currentSlmOutZ;
        hSI
        lockAxLims = false;
        hLateralAlignmentControls
    end
    
    methods
        function obj = SlmZAlignmentControls(hSlmScan)
            obj = obj@most.Gui([], [], [100 30], 'characters');
            obj.hSlmScan = hSlmScan;
        end
        
        function delete(obj)
            delete(obj.hListeners);
            obj.saveCalibration();
        end
    end
    
    methods (Access = protected)
        function initGui(obj)
            set(obj.hFig,'Name',sprintf('%s Z ALIGNMENT CONTROLS',obj.hSlmScan.name),'Resize','off',...
                'KeyPressFcn',@obj.figKeyPressed,'Interruptible','off','BusyAction','cancel');
            
            flowmain = most.gui.uiflowcontainer('Parent',obj.hFig,'FlowDirection','TopDown');
            flowT = most.gui.uiflowcontainer('Parent',flowmain,'FlowDirection','LeftToRight');
            flowAx = most.gui.uiflowcontainer('Parent',flowmain,'FlowDirection','LeftToRight');
            flow1 = most.gui.uiflowcontainer('Parent',flowmain,'FlowDirection','LeftToRight');
            
            makeLateralAlignmentInfo(flowT)
            makeAxes(flowAx);
            makeArrowButtons(flow1);
            
            obj.setSlmScan(obj.hSlmScan);
            
            %%% Nested functions
            function makeLateralAlignmentInfo(hParent)
                hParent.HeightLimits = [20 20];
                obj.addUiControl('Parent',hParent,'Style','checkbox','WidthLimits',[180 180],'String','Show lateral alignment window.','Bindings',{obj 'linkToLateralAlignmentControls' 'Value'});
                obj.addUiControl('Parent',hParent,'Style','text','HorizontalAlignment','center','Tag','txLateralAlignment');
            end
            
            function makeAxes(hParent)
                cmenu = uicontextmenu(ancestor(hParent,'figure'));
                uimenu(cmenu,'Label','Goto','Callback',@(varargin)obj.gotoPoint);
                uimenu(cmenu,'Label','Delete','Callback',@(varargin)obj.deletePoint);
                
                obj.hAx = most.idioms.axes('Parent',hParent);
                grid(obj.hAx,'on');
                box(obj.hAx,'on');
                obj.hLine = line('Parent',obj.hAx,'XData',NaN','YData',NaN,'Color','blue','Marker','none','Hittest','off','PickableParts','none');
                obj.hPositionMarker = line('Parent',obj.hAx,'XData',NaN','YData',NaN,'ZData',1,'Color','red','Marker','o','MarkerSize',10,'LineWidth',1.5,'ButtonDownFcn',@obj.startDrag);
                obj.hLineMarkers = line('Parent',obj.hAx,'XData',NaN','YData',NaN,'Color','blue','LineStyle','none','Marker','o','MarkerFaceColor',[0.75 0.75 1],'UIContextMenu',cmenu,'ButtonDownFcn',@obj.startDrag);
                xlabel(obj.hAx,'SLM Z-LUT Input [um]');
                ylabel(obj.hAx,'SLM Z-LUT Output [um]');
            end
            
            function makeArrowButtons(hParent)
                hParent.HeightLimits = [50,50];
                pnlSlmIn = uipanel('Parent',hParent,'Title','LUT Input');
                pnlSlmIn.WidthLimits = [230 Inf];
                flowSlmIn = most.gui.uiflowcontainer('Parent',pnlSlmIn,'FlowDirection','LeftToRight');
                pnlSlmOut = uipanel('Parent',hParent,'Title','LUT Output');
                flowSlmOut = most.gui.uiflowcontainer('Parent',pnlSlmOut,'FlowDirection','LeftToRight');
                pnlAddPt = uipanel('Parent',hParent,'Title','Position');
                pnlAddPt.WidthLimits = [70 70];
                flowAddPt = most.gui.uiflowcontainer('Parent',pnlAddPt,'FlowDirection','LeftToRight');
                
                obj.addUiControl('Parent',flowSlmIn,'Style','pushbutton','String','Goto Zero','Callback',@(src,evt)obj.gotoZero());
                obj.addUiControl('Parent',flowSlmIn,'Style','pushbutton','String',most.constants.Unicode.leftwards_arrow,'Callback',@(src,evt)obj.incrementSlmIn(-1));
                obj.addUiControl('Parent',flowSlmIn,'Style','edit','Bindings',{obj 'lutInputIncrement' 'value' '%.2f'});
                obj.addUiControl('Parent',flowSlmIn,'Style','pushbutton','String',most.constants.Unicode.rightwards_arrow,'Callback',@(src,evt)obj.incrementSlmIn(+1));
                
                obj.addUiControl('Parent',flowSlmOut,'Style','pushbutton','String',most.constants.Unicode.downwards_arrow,'Callback',@(src,evt)obj.incrementSlmOut(-1));
                obj.addUiControl('Parent',flowSlmOut,'Style','edit','Bindings',{obj 'lutOutputIncrement' 'value' '%.2f'});
                obj.addUiControl('Parent',flowSlmOut,'Style','pushbutton','String',most.constants.Unicode.upwards_arrow,'Callback',@(src,evt)obj.incrementSlmOut(+1));
                
                obj.addUiControl('Parent',flowAddPt,'Style','pushbutton','String','Reset LUT','Callback',@(varargin)obj.reset());
            end
        end
    end
    
    methods        
        function saveCalibration(obj)
            if most.idioms.isValidObj(obj.hSI)
                if most.idioms.isValidObj(obj.hSI.hCoordinateSystems)
                    try
                        obj.hSI.hCoordinateSystems.save();
                    catch ME
                        most.ErrorHandler.logAndReportError(ME);
                    end
                end
            end
        end
    end
    
    methods
        function figKeyPressed(obj,src,evt)
            controlKeyPressed = any(strcmpi(evt.Modifier,'control'));
            scale = 0.1^controlKeyPressed;
            
            switch evt.Key
                case 'leftarrow'
                    obj.incrementSlmIn(-1*scale);
                case 'rightarrow'
                    obj.incrementSlmIn(+1*scale);
                case 'uparrow'
                    obj.incrementSlmOut(+1*scale);
                case 'downarrow'
                    obj.incrementSlmOut(-1*scale);
                case {'0','numpad0'}
                    obj.gotoZero();
                case {'backspace','delete'}
                    zIn = obj.currentSlmInZ;
                    lutEntries = obj.hCS.fromParentLutEntries;
                    zsFrom = [lutEntries.zfrom];
                    
                    [d,idx] = min(abs(zsFrom-zIn));
                    if d<0.01
                        lutEntries(idx) = [];
                    end
                    obj.hCS.fromParentLutEntries = lutEntries;
                    obj.saveCalibration();
            end
        end
        
        function startDrag(obj,src,evt)
            if evt.Button~=1
                return
            end
            
            prevWindowButtonMotionFcn = obj.hFig.WindowButtonMotionFcn;
            prevWindowButtonUpFcn = obj.hFig.WindowButtonUpFcn;
            
            zIn = obj.hAx.CurrentPoint(1,1);
            
            lutEntries = obj.hCS.fromParentLutEntries;
            zsFrom = [lutEntries.zfrom];
            zsFrom = [obj.currentSlmInZ zsFrom];
            [~,idx] = min(abs(zsFrom-zIn));
            zIn = zsFrom(idx);
            
            obj.goto(zIn);
            obj.redraw();
            
            obj.lockAxLims = true;
            obj.hFig.WindowButtonUpFcn = @stop;
            obj.hFig.WindowButtonMotionFcn = @drag;
            
            function drag(varargin)
                zOut = obj.hAx.CurrentPoint(1,2);
                zOut = round(zOut,1);
                obj.addPoint(zIn,zOut);
                obj.goto(zIn);
            end
            
            function stop(varargin)
                obj.hFig.WindowButtonMotionFcn = prevWindowButtonMotionFcn;
                obj.hFig.WindowButtonUpFcn     = prevWindowButtonUpFcn;
                obj.lockAxLims = false;
                obj.redraw();
            end
        end
        
        function reset(obj)
            obj.hCS.fromParentLutEntries = [];
            obj.saveCalibration();
        end
        
        function gotoZero(obj)
            obj.goto(0);
        end
        
        function gotoPoint(obj)
            pt = obj.hAx.CurrentPoint;
            zIn = pt(1,1);
            
            lutRefZs = [obj.hCS.fromParentLutEntries.zfrom];
            [~,idx] = min(abs(lutRefZs-zIn));
            zIn = obj.hCS.fromParentLutEntries(idx).zfrom;
            
            obj.goto(zIn);
        end
        
        function goto(obj,zIn)
            pt = obj.hSlmScan.hSlm.hPtLastWritten;
            pt = pt.transform(obj.hCS);
            xy = pt.points(1,1:2); % we do not want the lateral matrix to take effect here. buffer xy and fill it back in later
            
            pt = pt.transform(obj.hCS.hParent);
            pt = pt.points;
            pt(3) = zIn;
            
            pt = scanimage.mroi.coordinates.Points(obj.hCS.hParent,pt);
            pt = pt.transform(obj.hCS);
            
            xyz = pt.points;
            xyz(1,1:2) = xy;
            pt = scanimage.mroi.coordinates.Points(obj.hCS,xyz);
            
            obj.hSlmScan.hSlm.pointScanner(pt);
        end
        
        function addPoint(obj,zfrom,zto,affine)
            currentLutEntries = obj.hCS.fromParentLutEntries;
            
            if nargin<4 || isempty(affine)
                affine = currentLutEntries.makeZAffines(zfrom);
            end
            
            if zfrom==0 && ~isEye(affine)
                affine = eye(size(affine,1));
                most.idioms.warn('Lateral affine at position z=0 must be identity matrix.');
            end
            
            refZs = [currentLutEntries.zfrom];
            tolerance = 0.5;
            removeMask = abs(refZs-zfrom) < tolerance;
            currentLutEntries(removeMask) = [];
            
            lutEntry = scanimage.mroi.coordinates.cszaffinelut.LUTEntry(zfrom,zto,affine);
            
            try
                obj.hCS.fromParentLutEntries = [currentLutEntries lutEntry];
                obj.saveCalibration();
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
            
            function tf = isEye(T)
                T_eye = eye(size(T,1));
                tf = isequal(T,T_eye);
            end
        end
        
        function deletePoint(obj)
            pt = obj.hAx.CurrentPoint;
            refZ = pt(1,1);
            
            lutEntries = obj.hCS.fromParentLutEntries;
            
            lutRefZs = [lutEntries.zfrom];
            [~,idx] = min(abs(lutRefZs-refZ));
            
            lutEntries(idx) = [];
            obj.hCS.fromParentLutEntries = lutEntries;
            obj.saveCalibration();
        end
        
        function incrementSlmIn(obj,val)
            pt = obj.hSlmScan.hSlm.hPtLastWritten;
            pt = pt.transform(obj.hCS.hParent);
            pt = pt.points;
            zIn = pt(3) + obj.lutInputIncrement*val;
            obj.goto(zIn);
        end
        
        function incrementSlmOut(obj,direction)
            pt = obj.hSlmScan.hSlm.hPtLastWritten;
            ptIn = pt.transform(obj.hCS.hParent);
            ptOut  = pt.transform(obj.hCS);
            
            zFrom = ptIn.points(3);
            zTo = ptOut.points(3) + obj.lutOutputIncrement * direction;
            
            obj.addPoint(zFrom,zTo);
            
            zIn = ptIn.points(3);
            obj.goto(zIn);
        end
        
        function setSlmScan(obj,val)
            obj.hSlmScan = val;
            
            delete(obj.hListeners);
            obj.hListeners = event.listener.empty();
            
            if most.idioms.isValidObj(obj.hCS)
                obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hSlmScan.hSlm,'hPtLastWritten','PostSet',@(varargin)obj.redraw);
                obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hCS,'changed',@(varargin)obj.redraw);
                obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hSlmScan,'ObjectBeingDestroyed',@(varargin)obj.delete);
                obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hLateralAlignmentControls,'videoImToRefImTransform','PostSet',@(varargin)obj.changeLateralAlignment);
            end
            
            obj.redraw();
        end
        
        function updateLateralAlignment(obj)
            currentLutEntries = obj.hCS.fromParentLutEntries;
            T = currentLutEntries.makeZAffines(obj.currentSlmInZ);
            
            obj.txLateralAlignment.String = sprintf('Lateral alignment: %s', mat2str(T,3));
            
            if obj.linkToLateralAlignmentControls
                T_ = inv(T);
                if ~isequal(obj.hLateralAlignmentControls.videoImToRefImTransform,T_)
                    enableListeners(false);
                    obj.hLateralAlignmentControls.videoImToRefImTransform = T_;
                    enableListeners(true);
                end
            end
            
            %%% Nested function
            function enableListeners(tf)
                for idx = 1:numel(obj.hListeners)
                    obj.hListeners(idx).Enabled = tf;
                end
            end
        end
        
        function changeLateralAlignment(obj)
            if obj.linkToLateralAlignmentControls
                T = obj.hLateralAlignmentControls.videoImToRefImTransform;
                T = inv(T);
                obj.addPoint(obj.currentSlmInZ,obj.currentSlmOutZ,T);
            end
        end
        
        function showAligmentControls(obj)
            obj.hLateralAlignmentControls.Visible = true;
            obj.hLateralAlignmentControls.showWindow = true;
            most.gui.tetherGUIs(obj.hFig,obj.hLateralAlignmentControls.hFig,'righttop');
            most.gui.tetherGUIs(obj.hLateralAlignmentControls.hFig,obj.hLateralAlignmentControls.hAlignmentFig,'bottomleft');
            most.idioms.figure(obj.hFig);
            most.idioms.figure(obj.hLateralAlignmentControls.hAlignmentFig);
            most.idioms.figure(obj.hLateralAlignmentControls.hFig);
        end
        
        function redraw(obj)
            if ~most.idioms.isValidObj(obj.hCS)
                deleteLine();
                return
            end
            
            lutEntries = obj.hCS.fromParentLutEntries;
            
            zsFrom = [lutEntries.zfrom];
            zsTo = [lutEntries.zto];
            
            allSlmZsIn  = [zsFrom,obj.currentSlmInZ];
            allSlmZsOut = [zsTo,obj.currentSlmOutZ];
            
            refLims = unique([min(allSlmZsIn) max(allSlmZsIn)]);
            slmLims = unique([min(allSlmZsOut) max(allSlmZsOut)]);
            
            xlabel(obj.hAx,sprintf('SLM Z-LUT Input: %.2f um',obj.currentSlmInZ));
            ylabel(obj.hAx,sprintf('SLM Z-LUT Output: %.2f um',obj.currentSlmOutZ));
            
            if isscalar(refLims)
                refLims = refLims + [-100 100];
            end
            
            if isscalar(slmLims)
                slmLims = slmLims + [-100 100];
            end
            
            XLim = sum(refLims)/2 + [-0.5 0.5]*diff(refLims)*1.4;
            YLim = sum(slmLims)/2 + [-0.5 0.5]*diff(slmLims)*1.4;
            
            if diff(XLim)<1e-3
                XLim = XLim(1)+ [-100 100];
            end
            
            if diff(YLim)<1e-3
                YLim = YLim(1)+ [-100 100];
            end
            
            if ~obj.lockAxLims
                obj.hAx.XLim = XLim;
                obj.hAx.YLim = YLim;
            end
            
            lineZsFrom = sort([zsFrom,obj.hAx.XLim]);
            ptsZsFrom = zeros(numel(lineZsFrom),3);
            ptsZsFrom(:,3) = lineZsFrom;
            lineZsTo = lutEntries.interpolate(ptsZsFrom);
            lineZsTo = lineZsTo(:,3)';
            
            obj.hLine.XData = lineZsFrom;
            obj.hLine.YData = lineZsTo;
            obj.hLine.ZData = zeros(size(lineZsTo));
            
            obj.hPositionMarker.XData = obj.currentSlmInZ;
            obj.hPositionMarker.YData = obj.currentSlmOutZ;
            obj.hPositionMarker.ZData = 1;
            
            obj.hLineMarkers.XData = zsFrom;
            obj.hLineMarkers.YData = zsTo;
            obj.hLineMarkers.ZData = repmat(2,size(zsTo));
            
            obj.updateLateralAlignment();
            
            %%% Nested function
            function deleteLine()
                obj.hLine.XData = NaN;
                obj.hLine.YData = NaN;
                obj.hLineMarkers.XData = NaN;
                obj.hLineMarkers.YData = NaN;
                obj.hPositionMarker.XData = NaN;
                obj.hPositionMarker.YData = NaN;
            end
        end
    end
    
    methods
        function set.lutInputIncrement(obj,val)
            validateattributes(val,{'numeric'},{'scalar','positive','finite','nonnan','real'});
            obj.lutInputIncrement = val;
        end
        
        function set.hSlmScan(obj,val)
            if ~isempty(val)
                validateattributes(val,{'scanimage.components.scan2d.SlmScan'},{'scalar'});
                assert(most.idioms.isValidObj(val));
            end
            
            obj.hSlmScan = val;
        end
        
        function val = get.hCS(obj)
            if most.idioms.isValidObj(obj.hSlmScan)
                val = obj.hSlmScan.hCSSlmZAlignmentLut;
            else
                val = [];
            end
        end
        
        function z = get.currentSlmInZ(obj)
            pt = obj.hSlmScan.hSlm.hPtLastWritten;
            if isempty(pt)
                z = 0;
            else
                pt = pt.transform(obj.hCS.hParent);
                z = pt.points(3);
            end
        end
        
        function z = get.currentSlmOutZ(obj)
            pt = obj.hSlmScan.hSlm.hPtLastWritten;
            if isempty(pt)
                z = 0;
            else
                pt = pt.transform(obj.hCS);
                z = pt.points(3);
            end
        end
        
        function val = get.hSI(obj)
            if most.idioms.isValidObj(obj.hSlmScan)
                val = obj.hSlmScan.hSI;
            else
                val = [];
            end
        end
        
        function val = get.hLateralAlignmentControls(obj)
            hSICtl = obj.hSlmScan.hSI.hController{1};
            val = hSICtl.hAlignmentControls;
        end
        
        function set.linkToLateralAlignmentControls(obj,val)
            val = logical(val);
            
            if val~=obj.linkToLateralAlignmentControls
                obj.linkToLateralAlignmentControls = val;
                if val
                    obj.showAligmentControls();
                end
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
