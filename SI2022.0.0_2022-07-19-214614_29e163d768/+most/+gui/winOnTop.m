% Copyright (c) 2015, Igor
% All rights reserved.
% 
% Redistribution and use in source and binary forms, with or without
% modification, are permitted provided that the following conditions are
% met:
% 
%     * Redistributions of source code must retain the above copyright
%       notice, this list of conditions and the following disclaimer.
%     * Redistributions in binary form must reproduce the above copyright
%       notice, this list of conditions and the following disclaimer in
%       the documentation and/or other materials provided with the distribution
% 
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
% LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
% POSSIBILITY OF SUCH DAMAGE.

function WasOnTop = winOnTop( FigureHandle, IsOnTop )
%WINONTOP allows to trigger figure's "Always On Top" state
% INPUT ARGUMENTS:
% * FigureHandle - Matlab's figure handle, scalar
% * IsOnTop      - logical scalar or empty array
%
% USAGE:
% * WinOnTop( hfigure, bool );
% * WinOnTop( hfigure );            - equal to WinOnTop( hfigure,true);
% * WinOnTop();                     - equal to WinOnTop( gcf, true);
% * WasOnTop = WinOnTop(...);       - returns boolean value "if figure WAS on top"
% * IsOnTop  = WinOnTop(hfigure,[]) - gets "if figure is on top" property
% 
% LIMITATIONS:
% * java enabled
% * figure must be visible
% * figure's "WindowStyle" should be "normal"
%
%
% Written by Igor
% i3v@mail.ru
%
% 16 June 2013 - Initial version
% 27 June 2013 - removed custom "ishandle_scalar" function call
%

%% Parse Inputs

if ~exist('FigureHandle','var');FigureHandle = gcf; end
assert(...
          isscalar( FigureHandle ) && ishandle( FigureHandle ) &&  strcmp(get(FigureHandle,'Type'),'figure'),...
          'WinOnTop:Bad_FigureHandle_input',...
          '%s','Provided FigureHandle input is not a figure handle'...
       );

% figure must be visible to get java frame
wasVisible = get(FigureHandle,'Visible');
set(FigureHandle,'Visible','on');

assert(...
            strcmp('on',get(FigureHandle,'Visible')),...
            'WinOnTop:FigInisible',...
            '%s','Figure Must be Visible'...
       );

assert(...
            strcmp('normal',get(FigureHandle,'WindowStyle')),...
            'WinOnTop:FigWrongWindowStyle',...
            '%s','WindowStyle Must be Normal'...
       );
   
if ~exist('IsOnTop','var');IsOnTop=true;end
assert(...
          islogical( IsOnTop ) &&  isscalar( IsOnTop) || isempty( IsOnTop ), ...
          'WinOnTop:Bad_IsOnTop_input',...
          '%s','Provided IsOnTop input is neither boolean, nor empty'...
      );
%% Pre-checks

error(javachk('swing',mfilename)) % Swing components must be available.
   
  
%% Action

% Flush the Event Queue of Graphic Objects and Update the Figure Window.
drawnow expose

warnStruct=warning();
warning('off','MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
warning('off','MATLAB:ui:javaframe:PropertyToBeRemoved'); % R2019b compatibility
jFrame = get(handle(FigureHandle),'JavaFrame');
warning(warnStruct);

drawnow();

if verLessThan('matlab','8.4');
    jFrame_fHGxClient = jFrame.fHG1Client;
else
    jFrame_fHGxClient = jFrame.fHG2Client;
end

WasOnTop = jFrame_fHGxClient.getWindow.isAlwaysOnTop;

if ~isempty(IsOnTop)
    jFrame_fHGxClient.getWindow.setAlwaysOnTop(IsOnTop);
end

if ~IsOnTop
    set(FigureHandle,'Visible',wasVisible);
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
