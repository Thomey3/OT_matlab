classdef ConfigSignalConditioning < most.gui.GuiElement
    properties
        hLabel;
        hPhotonDiscriminator;
    end
    
    methods
        function obj = ConfigSignalConditioning(hParent,hPhotonDiscriminator)
            obj = obj@most.gui.GuiElement(hParent);
            obj.hPhotonDiscriminator = hPhotonDiscriminator;
            obj.hUIPanel.Title = 'Signal Conditioning';
            obj.init();
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hLabel);
        end
        
        function init(obj)
            most.idioms.safeDeleteObj(obj.hLabel);
            obj.hLabel = uicontrol('Parent',obj.hUIPanel,'Style','text','HorizontalAlignment','left','Enable','inactive','ButtonDownFcn',@obj.openInputDialog);
            obj.panelResized();
            
            obj.configurationChanged();
        end
            
        function scrollWheelFcn(obj,varargin)
           % No-Op 
        end
    end
    
    methods
        function configurationChanged(obj)
            obj.updateLabelString();
        end
        
        function panelResized(obj)
            panelPos = obj.getPositionInUnits('pixel');
            obj.hLabel.Units = 'pixel';
            padding = 15;
            obj.hLabel.Position = [padding padding panelPos(3:4)-3*padding];
        end
        
        function str = updateLabelString(obj)
            str = sprintf('Scale: 2^%d\nOffset: %d\nDifferentiate: %d',...
                          obj.hPhotonDiscriminator.rawDataScaleByPowerOf2,...
                          obj.hPhotonDiscriminator.staticNoise(1),...
                          obj.hPhotonDiscriminator.differentiate);
            obj.hLabel.String = str;
        end
        
        function openInputDialog(obj,varargin)
            answer = inputdlg({'Scale 2^x' 'Offset' 'Differentiate'},'Signal Conditioning',1,...
                {num2str(obj.hPhotonDiscriminator.rawDataScaleByPowerOf2),...
                num2str(obj.hPhotonDiscriminator.staticNoise),...
                num2str(obj.hPhotonDiscriminator.differentiate)});
            if ~isempty(answer)
                try
                    obj.hPhotonDiscriminator.rawDataScaleByPowerOf2 = str2double(answer{1});
                    obj.hPhotonDiscriminator.staticNoise = str2double(answer{2});
                    obj.hPhotonDiscriminator.differentiate = str2double(answer{3});
                catch ME
                    most.idioms.rethrowMsgDlg(ME);
                end
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
