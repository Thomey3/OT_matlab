classdef ConfigDiscriminator < most.gui.GuiElement
    properties
        hLabel;
        hPhotonDiscriminator;
    end
    
    methods
        function obj = ConfigDiscriminator(hParent,hPhotonDiscriminator)
            obj = obj@most.gui.GuiElement(hParent);
            obj.hPhotonDiscriminator = hPhotonDiscriminator;
            obj.hUIPanel.Title = 'Photon Discriminator';
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
            str = sprintf('Peak Threshold: %d\nPeak Window: %d\nDebounce: %d\nPhase: %d',...
                obj.hPhotonDiscriminator.peakThreshold,...
                obj.hPhotonDiscriminator.peakDetectionWindowSize,...
                obj.hPhotonDiscriminator.peakDebounceSamples,...
                obj.hPhotonDiscriminator.phase);
            obj.hLabel.String = str;
        end
        
        function openInputDialog(obj,varargin)
            answer = inputdlg({'Peak Threshold','Peak Detection Window Size','Peak Debounce Samples','Phase'},'Photon Discriminator Conficuration',1,...
                {num2str(obj.hPhotonDiscriminator.peakThreshold),...
                num2str(obj.hPhotonDiscriminator.peakDetectionWindowSize),...
                num2str(obj.hPhotonDiscriminator.peakDebounceSamples),...
                num2str(obj.hPhotonDiscriminator.phase)});
            if ~isempty(answer)
                try
                    obj.hPhotonDiscriminator.peakThreshold = str2double(answer{1});
                    obj.hPhotonDiscriminator.peakDetectionWindowSize = str2double(answer{2});
                    obj.hPhotonDiscriminator.peakDebounceSamples = str2double(answer{3});
                    obj.hPhotonDiscriminator.phase = str2double(answer{4});
                catch ME
                    obj.configurationChanged();
                    rethrow(ME);
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
