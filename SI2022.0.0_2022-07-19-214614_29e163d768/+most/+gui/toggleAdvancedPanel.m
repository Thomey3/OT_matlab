function toggleAdvancedPanel(hObject,offset,orientation)
%% TOGGLEADVANCEDPANEL Resizes a graphics panel to display hidden or advanced features.
%% SYNTAX
%   toggleAdvancedPanel(hObject,offset,orientation)
%       hObject: the calling uicontrol
%       offset: the number of units by which to grow the panel
%       orientation: the direction in which the panel should grow (one of {'x' 'y'})

    if nargin < 3 || isempty(orientation)
        if nargin < 2
            error('Not enough arguments given; the first two arguments must be supplied.')
        end
        orientation = 'y';
    end
    
    if ~isnumeric(offset)
       error('''offset'' must be numeric.');
    end
    
    if ~ismember(orientation,{'x' 'y'})
       error('''orientation'' must be ''x'' or ''y'''); 
    end
    
    % determine the control's parent and all its siblings
    parentFig = ancestor(hObject,'figure');
    parentPos = get(parentFig,'Position');
    siblings = [findobj(parentFig,'Type','uicontrol'); findobj(parentFig,'Type','uitable'); findobj(parentFig,'Type','uipanel')];
    
    % toggle the button state (and invert 'offset', if necessary)
    if get(hObject,'Value')
        if strcmp(orientation,'y')
            set(hObject,'String','/\');
        elseif strcmp(orientation,'x')
            set(hObject,'String','<<');
        end
    else
        if strcmp(orientation,'y')
            set(hObject,'String','\/');
        elseif strcmp(orientation,'x')
            set(hObject,'String','>>');
        end
        offset = -offset;
    end
    
    % resize the main figure
    if strcmp(orientation,'y')
        parentPos(2) = parentPos(2) - offset;
        parentPos(4) = parentPos(4) + offset;
    elseif strcmp(orientation,'x')
        parentPos(3) = parentPos(3) + offset;
    end
    set(parentFig,'Position',parentPos);
    
    % because of Matlab's coordinate-system, a 'y'-oriented resize requires
    % a bit more work; shift all the GUI elements vertically to keep 
    % everything in the right place.
    if strcmp(orientation,'y')
        for hUI = siblings'
            if ~strcmpi(get(hUI,'Type'),'uipanel') && isempty(ancestor(hUI,'uipanel'))
                childPos = get(hUI,'Position');
                childPos(2) = childPos(2) + offset;
                set(hUI,'Position',childPos);
            elseif strcmpi(get(hUI,'Type'),'uipanel')
                childPos = get(hUI,'Position');
                childPos(2) = childPos(2) + offset;
                set(hUI,'Position',childPos);
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
