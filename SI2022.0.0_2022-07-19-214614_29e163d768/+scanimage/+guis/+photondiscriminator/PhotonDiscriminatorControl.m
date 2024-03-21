classdef PhotonDiscriminatorControl < most.gui.GuiElement
    properties (SetAccess = private,Hidden)
        hButtons
        hProcessingPipeline
        hDataPlot
        hPhotonDiscriminator
        hConfigurationChangedListener
    end
    
    properties (Dependent)
        Visible
    end
    
    methods
        function obj = PhotonDiscriminatorControl(hPhotonDiscriminator,visible)
            hFig = most.idioms.figure('MenuBar','none','NumberTitle','off','Visible',visible);
            obj = obj@most.gui.GuiElement(hFig);
            obj.hPhotonDiscriminator = hPhotonDiscriminator;
            obj.hFig.CloseRequestFcn = @(varargin)set(obj.hFig,'Visible','off');
            obj.init();
            
            p = most.gui.centeredScreenPos([900 600]);
            obj.hFig.Position = p;
            name = sprintf('Photon Discriminator AI%d',obj.hPhotonDiscriminator.physicalChannelNumber);
            obj.hFig.Name = name;
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hConfigurationChangedListener);
            most.idioms.safeDeleteObj(obj.hButtons);
            most.idioms.safeDeleteObj(obj.hProcessingPipeline);
            most.idioms.safeDeleteObj(obj.hDataPlot);
            most.idioms.safeDeleteObj(obj.hFig);
        end
        
        function showFigure(obj)
            obj.Visible = true;
            most.idioms.figure(obj.hFig);
        end
        
        function init(obj)
            most.idioms.safeDeleteObj(obj.hConfigurationChangedListener);
            most.idioms.safeDeleteObj(obj.hProcessingPipeline);
            most.idioms.safeDeleteObj(obj.hDataPlot);
            most.idioms.safeDeleteObj(obj.hButtons);
            delete(obj.hUIPanel.Children);
            
            obj.hButtons = scanimage.guis.photondiscriminator.Buttons(obj,obj.hPhotonDiscriminator);
            obj.hProcessingPipeline = scanimage.guis.photondiscriminator.ProcessingPipeline(obj,obj.hPhotonDiscriminator);
            obj.hDataPlot = scanimage.guis.photondiscriminator.DataPlot(obj,obj.hPhotonDiscriminator);
            
            obj.hConfigurationChangedListener = most.util.DelayedEventListener(0.1,obj.hPhotonDiscriminator,'configurationChanged',@obj.configurationChanged);
            obj.panelResized();
        end
        
        function configurationChanged(obj,varargin)
            try
                obj.hButtons.configurationChanged();
                obj.hProcessingPipeline.configurationChanged();
                obj.hDataPlot.configurationChanged();
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
        end
        
        function panelResized(obj)            
            panelDims = obj.getPositionInUnits('pixel');
            l = panelDims(1);
            b = panelDims(2);
            w = panelDims(3);
            h = panelDims(4);
            
            heightProcessingPipeline = 150;
            widthButtons = 150;
            obj.hButtons.setPositionInUnits('pixel',[0,h-heightProcessingPipeline,widthButtons,heightProcessingPipeline]);
            obj.hProcessingPipeline.setPositionInUnits('pixel',[widthButtons h-heightProcessingPipeline w-widthButtons heightProcessingPipeline]);
            heightDataPlot = h-heightProcessingPipeline;
            obj.hDataPlot.setPositionInUnits('pixel',[0 0 w heightDataPlot]);
        end
        
        function scrollWheelFcn(obj,varargin)
            % No-Op
        end
        
        function set.Visible(obj,val)
            if val
                obj.hFig.Visible = 'on';
            else
                obj.hFig.Visible = 'off';
            end
        end
        
        function val = get.Visible(obj)
            val = obj.hFig.Visible;
            val = strcmpi(val,'on');
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
