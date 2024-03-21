classdef AdvancedPanelToggler 
% Stateless class that knows how to resize GUIs for advanced-panel-ness,
% update UIControl toggle-buttons, etc. All necessary state is stored in
% figure UserData. This state is conceptually opaque, ie this class should
% handle all toggle-related actions.
    
    methods (Static)
        
        function tf = isFigToggleable(hFig)
            tf = most.gui.AdvancedPanelToggler.isFigToggleInitted(hFig);
        end
        
        % initialize size toggability for a gui figure.
        % hFig: handle to GUI figure
        % hToggleCtrl: handle to uicontrol togglebutton
        % deltaPos: change in figure size
        function init(hFig,hToggleCtrl,deltaPos)
            assert(ishandle(hFig) && isscalar(hFig));
            assert(ishandle(hToggleCtrl) && isscalar(hToggleCtrl) && ...
                strcmp(get(hToggleCtrl,'Type'),'uicontrol') && ...
                strcmp(get(hToggleCtrl,'Style'),'togglebutton'));
            validateattributes(deltaPos,{'numeric'},{'scalar' 'real'});

            orientation = most.gui.AdvancedPanelToggler.getToggleOrientation(hToggleCtrl);

            % write toggle state to hFig userData
            currentUserData = get(hFig,'UserData');            
            assert(isempty(currentUserData) || ...
                isstruct(currentUserData) && ~isfield(currentUserData,'toggle'), ...
                'Unexpected figure userdata.');
            
            currentUserData.toggle.toggleCtrlTag = get(hToggleCtrl,'Tag');
            currentUserData.toggle.orientation = orientation;
            currentUserData.toggle.deltaPos = deltaPos;
            set(hFig,'UserData',currentUserData);
        end
        
        % Toggle advanced-panel situation for hFig.
        % The toggle-button should already be "clicked" (to the new,
        % desired value) before making this call.
        function toggle(hFig)
            % For now use toggleAdvancedPanel; at some point
            % toggleAdvancedPanel may become obsolete and then we can
            % cut+paste that code here.

            assert(most.gui.AdvancedPanelToggler.isFigToggleInitted(hFig), ...
                'Figure has not been toggle-initted.');
            ud = get(hFig,'UserData');
            
            hToggleCtrl = findobj(hFig,'Tag',ud.toggle.toggleCtrlTag);                       
            offset = ud.toggle.deltaPos;
            orientation = ud.toggle.orientation;            
            most.gui.toggleAdvancedPanel(hToggleCtrl,offset,orientation);
        end  
        
        % This first "pushes" the toggle uicontrol button, then calls
        % toggle(). This method is the programmatic equivalent of
        % actually pushing the button.
        function pushToggleButtonAndToggle(hFig)            
            assert(most.gui.AdvancedPanelToggler.isFigToggleInitted(hFig), ...
                'Figure has not been toggle-initted.');
            ud = get(hFig,'UserData');
            
            hToggleCtrl = findobj(hFig,'Tag',ud.toggle.toggleCtrlTag);
            
            % "push" togglebutton
            val = get(hToggleCtrl,'Value');
            val = mod(val+1,2);
            set(hToggleCtrl,'Value',val);
            
            most.gui.AdvancedPanelToggler.toggle(hFig);
        end
        
        % return a struct to be used with loadToggleState.
        function s = saveToggleState(hFig)
            assert(most.gui.AdvancedPanelToggler.isFigToggleInitted(hFig), ...
                'Figure has not been toggle-initted.');
            ud = get(hFig,'UserData');

            s = ud.toggle;
            
            % figure out current state of toggle button
            hToggleCtrl = findobj(hFig,'Tag',ud.toggle.toggleCtrlTag);
            s.toggleCtrlVal = get(hToggleCtrl,'Value');
        end
        
        % restore advanced-panel-toggleness to state saved in s.
        function loadToggleState(hFig,s)
            assert(most.gui.AdvancedPanelToggler.isFigToggleInitted(hFig), ...
                'Figure has not been toggle-initted.');            
            ud = get(hFig,'UserData');
            
            assert(isequal(rmfield(s,'toggleCtrlVal'),ud.toggle));
            hToggleCtrl = findobj(hFig,'Tag',ud.toggle.toggleCtrlTag);
            val = get(hToggleCtrl,'value');
            if val~=s.toggleCtrlVal
                most.gui.AdvancedPanelToggler.pushToggleButtonAndToggle(hFig);
            end
        end        
        
    end
    
    methods (Static,Access=private)
        
        function tf = isFigToggleInitted(hFig)
            ud = get(hFig,'UserData');
            tf = isstruct(ud) && isfield(ud,'toggle');
        end
        
        function orientation = getToggleOrientation(hCtrl)
            lbl = get(hCtrl,'String');
            switch lbl
                case {'/\' '\/'}
                    orientation = 'y';
                case {'<<' '>>'}
                    orientation = 'x';
                otherwise
                    assert(false);
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
