function varargout = dsxy2figxy(varargin)
% dsxy2figxy -- Transform point or position from data space 
% coordinates into normalized figure coordinates 
% Transforms [x y] or [x y width height] vectors from data space
% coordinates to normalized figure coordinates in order to locate
% annotation objects within a figure. These objects are: arrow, 
% doublearrow, textarrow, ellipse line, rectangle, textbox 
%
% Syntax:
%    [figx figy] = dsxy2figxy([x1 y1],[x2 y2])  % GCA is used
%    figpos      = dsxy2figxy([x1 y1 width height])
%    [figx figy] = dsxy2figxy(axes_handle, [x1 y1],[x2 y2])
%    figpos      = dsxy2figxy(axes_handle, [x1 y1 width height])
%
% Usage: Obtain a position on a plot in data space and  
%        apply this function to locate an annotation there, e.g., 
%   [axx axy] = ginput(2); (input is in data space)
%   [figx figy] = dsxy2figxy(gca, axx, axy);  (now in figure space)
%   har = annotation('textarrow',figx,figy); 
%   set(har,'String',['(' num2str(axx(2)) ',' num2str(axy(2)) ')']) 
%
%   Copyright 2006-2009 The MathWorks, Inc. 

% Obtain arguments (limited argument checking is done)
% Determine if axes handle is specified
if length(varargin{1}) == 1 && ishandle(varargin{1}) ...
                            && strcmp(get(varargin{1},'type'),'axes')	
	hAx = varargin{1};
	varargin = varargin(2:end); % Remove arg 1 (axes handle)
else
	hAx = gca;
end;

% Remaining args are either two point locations or a position vector
if length(varargin) == 1        % Assume a 4-element position vector
	pos = varargin{1};
else
	[x,y] = deal(varargin{:});  % Assume two pairs (start, end points)
end

% Get limits
axun = get(hAx,'Units');
set(hAx,'Units','normalized');  % Make axes units normalized 
axpos = get(hAx,'Position');    % Get axes position
axlim = axis(hAx);              % Get the axis limits [xlim ylim (zlim)]
axwidth = diff(axlim(1:2));
axheight = diff(axlim(3:4));

% Transform from data space coordinates to normalized figure coordinates 
if exist('x','var')     % Transform a and return pair of points
	varargout{1} = (x - axlim(1)) * axpos(3) / axwidth + axpos(1);
	varargout{2} = (y - axlim(3)) * axpos(4) / axheight + axpos(2);
else                    % Transform and return a position rectangle
	pos(1) = (pos(1) - axlim(1)) / axwidth * axpos(3) + axpos(1);
	pos(2) = (pos(2) - axlim(3)) / axheight * axpos(4) + axpos(2);
	pos(3) = pos(3) * axpos(3) / axwidth;
	pos(4) = pos(4) * axpos(4 )/ axheight;
	varargout{1} = pos;
end

% Restore axes units
set(hAx,'Units',axun)




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
