classdef IntegrationRoiOutputChannelPage < dabs.resources.configuration.ResourcePage
    properties
        pmhOutputControl
    end
    
    methods
        function obj = IntegrationRoiOutputChannelPage(hResource,hParent)
            obj@dabs.resources.configuration.ResourcePage(hResource,hParent);
        end
        
        function makePanel(obj,hParent)
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [24 30 120 20],'Tag','txhOutput','String','Output channel','HorizontalAlignment','right');
            obj.pmhOutputControl  = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [150 27 160 20],'Tag','pmhOutputControl');
        end
        
        function redraw(obj)            
            hIOs = obj.hResourceStore.filter(...
                @(hR)isa(hR,'dabs.resources.ios.DO') ...
                ||isa(hR,'dabs.resources.ios.PFI') ...
                ||isa(hR,'dabs.resources.ios.AO'));
            
            obj.pmhOutputControl.String = [{'Software output'}, hIOs];
            if isempty(obj.hResource.hOutput)
                outputname = 'Software output';
            else
                outputname = obj.hResource.hOutput.name;
            end
            obj.pmhOutputControl.pmValue = outputname;
        end
        
        function apply(obj)
            outputName = obj.pmhOutputControl.pmValue;
            if strcmp(outputName,'Software output')
                outputName = '';
            end
            
            most.idioms.safeSetProp(obj.hResource,'hOutput',outputName);
            
            obj.hResource.saveMdf();
            obj.hResource.reinit();
        end
        
        function remove(obj)
            obj.hResource.deleteAndRemoveMdfHeading();
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
