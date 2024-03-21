function changedList = recolorGuis(newColor)
    % Utility to change SI gui background color. Three modes:
    %
    % call with a color (1x3 vector) to change SI gui backgrounds to a new
    % color. returns a list of gui objects that were modified and the
    % original color value
    %
    % call with only a return value to retrieve list of gui objects that were modified and the
    % original color value
    % 
    % call with no input or output arguments to restore guis to
    % original color.
    
    persistent changed;
    
    changedList = changed;
    
    if ~isempty(changed) && (~nargout || nargin)
        for ii = 1:numel(changed)
            item = changed{ii};
            if most.idioms.isValidObj(item{1})
                item{1}.(item{2}) = item{3};
            end
        end
        changed = {};
    end
    
    if nargin
        try
            recolorGuisInt(evalin('base','hSICtl.hGUIsArray'));
        catch
            error('Could not find ScanImage GUI');
        end
        try
            changedList = changed;
        catch ME
            error('Failed to change SI GUI color. Error message: %s',ME.message);
        end
    end
    
    function recolorGuisInt(guis)
        n = numel(guis);
        for i = 1:n
            gui = guis(i);
            
            if isa(gui,'matlab.ui.Figure')
                tryProp(gui,'Color',true);
            elseif isa(gui,'matlab.ui.container.Panel') || isa(gui,'matlab.ui.container.internal.UIFlowContainer')
                tryProp(gui,'BackgroundColor',true);
            elseif ~isbutton(gui)
                tryProp(gui,'BackgroundColor',false);
%                 tryProp(gui,'Color',false);
%                 tryProp(gui,'ForegroundColor',false);
            end
            
            if isprop(gui,'Children')
                recolorGuisInt(gui.Children);
            end
        end
    end
    
    function tryProp(obj,prop,changeEmpty)
        defCol = .94*ones(1,3);
        if isprop(obj,prop)
            c = obj.(prop);
            if (changeEmpty && isempty(c)) || (isnumeric(c) && (numel(c) == 3) && (sum(abs(c-defCol)) < .1))
                obj.(prop) = newColor;
                changed{end+1} = {obj prop c};
            end
        end
    end
    
    function v = isbutton(obj)
        v = isa(obj,'matlab.ui.control.UIControl') && (strcmp(obj.Style,'pushbutton') || strcmp(obj.Style,'togglebutton'));
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
