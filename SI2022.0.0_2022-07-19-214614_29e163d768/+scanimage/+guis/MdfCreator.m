classdef MdfCreator < most.Gui
    
    properties
        hResourceStore;
        hPnlContainer;
        hMainPanel;
        hSelectedPanel;
        hSubPanels = matlab.ui.container.Panel.empty;
        
        % slide transition
        slideV;
        pnl1;
        pos1;
        pnl2;
        pos2;
        
        selectionCallback;
    end
    
    %% LifeCycle
    methods
        function obj = MdfCreator()
            obj.hFig.Name = 'New Microscope Configuration';
            obj.hFig.CloseRequestFcn = @obj.cancel;
            obj.hFig.Position = most.gui.centeredScreenPos([430 350]);
            
            obj.addUiControl('style','text','position',[7 300 426 45],'fontsize',8.1,'HorizontalAlignment','left','string',[...
                'Select a microscope system template configuration that most closely matches your '...
                'microscope setup or select "Blank Configuration" to start with an empty configuration. '...
                'At the next step you can add/remove components and change parameters.']);
            
            psz = [415 265];
            obj.hPnlContainer = uipanel('parent',obj.hFig,'bordertype','none','units','pixels','position',[8 36 psz]);
            
            obj.addUiControl('position',[8 8 70 24],'string','Cancel','callback',@obj.cancel);
            
            %% create buttons
            classes = dabs.resources.configuration.private.findAllConfigClasses();
            classes = classes(strcmp({classes.category},'Complete Microscopes'));
            manufacturers = cellfun(@(s){eval(s)},cellfun(@(s){[s '.manufacturer']}, {classes.className}));
            detailedNames = cellfun(@(s){eval(s)},cellfun(@(s){[s '.detailedName']}, {classes.className}));
            manufacturerList = unique(manufacturers);
            
            obj.hMainPanel = uipanel('parent',obj.hPnlContainer,'bordertype','none','units','pixels','position',[0 0 psz]);
            h = most.gui.uiflowcontainer('parent',obj.hMainPanel,'flowdirection','topdown','margin',6);
            for i = 0:numel(manufacturerList)
                if i
                    obj.hSubPanels(i) = uipanel('parent',obj.hPnlContainer,'bordertype','none','units','pixels','position',[psz(1) 0 psz]);
                    hSub = most.gui.uiflowcontainer('parent',obj.hSubPanels(i),'flowdirection','topdown','margin',6);
                    inds = strcmp(manufacturers,manufacturerList{i});
                    mfcClasses = classes(inds);
                    mfcDetailedNames = detailedNames(inds);
                    N = numel(mfcClasses);
                    for j = 0:N
                        if j
                            most.gui.uicontrol('parent',hSub,'string',mfcDetailedNames{j},'callback',@(varargin)obj.select(mfcClasses(j)),'HeightLimits',[0 46]);
                        else
                            most.gui.uicontrol('parent',hSub,'string','<html><center><b> Back to main list... </center></html>','callback',@(varargin)obj.switchToPanel(0),'HeightLimits',[0 46]);
                        end
                    end
                    
                    most.gui.uicontrol('parent',h,'string',['<html><center><b>' manufacturerList{i} ' Microscopes</html></center></b>'],'callback',@(varargin)obj.switchToPanel(i),'HeightLimits',[0 46]);
                else
                    most.gui.uicontrol('parent',h,'string',['<html><center><b> Blank Configuration</b> <br />'...
                        'Build your custom configuration by adding all your microscope parts </center></html>'],'callback',@obj.chooseBlank,'HeightLimits',[0 46]);
                end
            end
            
            obj.hSelectedPanel = obj.hMainPanel;
        end
    end
    
    %% internal
    methods
        function switchToPanel(obj,ind)
            outPos = obj.hPnlContainer.Position(3);
            
            obj.pnl1 = obj.hSelectedPanel;
            obj.pos1 = [0 outPos*((-1)^(ind>0))];
            
            if ind
                obj.pnl2 = obj.hSubPanels(ind);
            else
                obj.pnl2 = obj.hMainPanel;
            end
            obj.pos2 = [outPos*((-1)^(ind==0)) -outPos*((-1)^(ind==0))];
            
            most.gui.Transition(0.4,obj,'slideV',1);
            obj.hSelectedPanel = obj.pnl2;
        end
        
        function chooseBlank(obj,varargin)
            s.className = '';
            if ~isempty(obj.selectionCallback)
                obj.selectionCallback(s);
            end
            delete(obj.hFig);
        end
        
        function select(obj,c)
            if ~isempty(obj.selectionCallback)
                obj.selectionCallback(c);
            end
            delete(obj.hFig);
        end
        
        function cancel(obj,varargin)
            if ~isempty(obj.selectionCallback)
                obj.selectionCallback([]);
            end
            delete(obj.hFig);
        end
        
        function set.slideV(obj,v)
            obj.pnl1.Position(1) = obj.pos1(1) + obj.pos1(2)*v;
            obj.pnl2.Position(1) = obj.pos2(1) + obj.pos2(2)*v;
        end
    end
    
    %% prop access
    methods
        function v = get.slideV(obj)
            v = 0;
        end
    end
    
    %% static
    methods (Static)
        function s = doModal()
            s = [];
            obj = scanimage.guis.MdfCreator();
            obj.selectionCallback = @grabSelection;
            obj.Visible = true;
            waitfor(obj.hFig);
            
            function grabSelection(sel)
                s = sel;
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
