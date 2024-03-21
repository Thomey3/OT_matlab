function tetherGUIs(parent,child,relPosn,spacing)
%% function tetherGUIs(parent,child,relPosn)
% Tethers specified child GUI to specified parent GUI, according to relPosn
%
%% SYNTAX
%   tetherGUIs(parent,child,relPosn)
%       parent,child: Valid GUI figure handles
%       relPosn: String from set {'righttop' 'rightcenter' 'rightbottom' 'bottomleft' 'bottomcenter' 'bottomright'} indicating desired location of child GUI relative to parent GUI
%       spacing: (optional) leaves space (defined in pixels) between tethered GUIs
if nargin < 4 || isempty(spacing)
    spacing = 0;
end

assert(ishandle(child),'Child argument must be a Matlab figure handle');

% ensure pixel units
childOrigUnits = get(child,'Units');
set(child,'Units','pixels');

childOrigOuterPosn = get(child,'OuterPosition');
childOrigPosn = get(child,'Position');
childNewOuterPosn = childOrigOuterPosn;
childNewPosn = childOrigPosn;

if isempty(parent)
    switch relPosn
        case 'northwest'
            scr = get(0, 'ScreenSize');
            childNewOuterPosn(1) = 1;
            childNewOuterPosn(2) = scr(4) - childOrigOuterPosn(4) - 5;
    end
else
    assert(ishandle(parent) && ishandle(child),'Parent argument must be a Matlab figure handle');
    
    % ensure pixel units
    parOrigUnits = get(parent,'Units');
    set(parent,'Units','pixels');
    
    %Only tether if it hasn't been previously tethered (or otherwise had position defined)
    parOuterPosn = get(parent,'OuterPosition');
    
    switch relPosn
        case 'righttop'
            childNewOuterPosn(1) = sum(parOuterPosn([1 3])) + spacing;
            childNewOuterPosn(2) = sum(parOuterPosn([2 4])) - childOrigOuterPosn(4);
        case 'rightcenter'
            childNewOuterPosn(1) = sum(parOuterPosn([1 3])) + spacing;
            childNewOuterPosn(2) = parOuterPosn(2) + parOuterPosn(4)/2 - childOrigOuterPosn(4)/2;
        case 'rightbottom'
            childNewOuterPosn(1) = sum(parOuterPosn([1 3])) + spacing;
            childNewOuterPosn(2) = parOuterPosn(2);
        case 'bottomleft'
            childNewOuterPosn(1) = parOuterPosn(1);
            childNewOuterPosn(2) = parOuterPosn(2) - childOrigOuterPosn(4) - spacing;
        case {'bottomcenter' 'bottom'}
            childNewOuterPosn(1) = parOuterPosn(1) + parOuterPosn(3)/2 - childOrigOuterPosn(3)/2;
            childNewOuterPosn(2) = parOuterPosn(2) - childOrigOuterPosn(4) - spacing;
        case 'bottomright'
            childNewOuterPosn(1) = parOuterPosn(1) + parOuterPosn(3) - childOrigOuterPosn(3);
            childNewOuterPosn(2) = parOuterPosn(2) - childOrigOuterPosn(4) - spacing;
        otherwise
            assert(false,'Unrecognized expression provided for ''relPosn''');
    end
    
    % restore original units
    set(parent,'Units',parOrigUnits);
end

childNewPosn(1:2) = childOrigPosn(1:2) + childNewOuterPosn(1:2) - childOrigOuterPosn(1:2);
set(child,'Position',round(childNewPosn));
% set(child,'OuterPosition',round(childNewOuterPosn));

% restore original units
set(child,'Units',childOrigUnits);




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
