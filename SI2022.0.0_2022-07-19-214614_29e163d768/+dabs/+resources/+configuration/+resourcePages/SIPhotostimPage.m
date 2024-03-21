classdef SIPhotostimPage < dabs.resources.configuration.ResourcePage
    properties
        pmhScan
        pmLoggingStartTrigger
        pmBeamAiId
        pmStimActiveOutputChannel
        pmBeamActiveOutputChannel
        pmSlmTriggerOutputChannel
    end
    
    methods
        function obj = SIPhotostimPage(hResource,hParent)
            obj@dabs.resources.configuration.ResourcePage(hResource,hParent);
        end
        
        function makePanel(obj,hParent)
            hTabGroup = uitabgroup('Parent',hParent);
            hTab = uitab('Parent',hTabGroup,'Title','Basic');
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [60 32 120 20],'Tag','txhScan','String','Scan System','HorizontalAlignment','right');
                obj.pmhScan  = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [190 32 120 20],'Tag','pmhScan');

            hTab = uitab('Parent',hTabGroup,'Title','Advanced');
                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [20 62 160 20],'Tag','txLoggingStartTrigger','String','Logging start trigger (optional)','HorizontalAlignment','right');
                obj.pmLoggingStartTrigger  = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [190 62 140 20],'Tag','pmLoggingStartTrigger');

                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [60 92 120 20],'Tag','txBeamAiId','String','Beam monitor (optional)','HorizontalAlignment','right');
                obj.pmBeamAiId  = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [190 92 140 20],'Tag','pmBeamAiId');

                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [40 122 140 20],'Tag','txStimActiveOutputChannel','String','Stim active output (optional)','HorizontalAlignment','right');
                obj.pmStimActiveOutputChannel  = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [190 122 140 20],'Tag','pmStimActiveOutputChannel');

                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [30 152 150 20],'Tag','txBeamActiveOutputChannel','String','Beam active output (optional)','HorizontalAlignment','right');
                obj.pmBeamActiveOutputChannel  = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [190 152 140 20],'Tag','pmBeamActiveOutputChannel');

                most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [40 182 140 20],'Tag','txmSlmTriggerOutputChannel','String','Slm update trigger (optional)','HorizontalAlignment','right');
                obj.pmSlmTriggerOutputChannel  = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [190 182 140 20],'Tag','pmSlmTriggerOutputChannel');
        end
        
        function redraw(obj) 
            hRggScans = obj.hResourceStore.filterByClass('scanimage.components.scan2d.RggScan');
            hLinScans = obj.hResourceStore.filterByClass('scanimage.components.scan2d.LinScan');
            hSlmScans = obj.hResourceStore.filterByClass('scanimage.components.scan2d.SlmScan');
            
            obj.pmhScan.String = [{''}, hRggScans, hLinScans, hSlmScans];
            obj.pmhScan.pmValue = obj.hResource.hScan;
            obj.pmhScan.Enable = ~obj.hResource.mdlInitialized;
            
            isvDAQ = isa(obj.hResource.hScan,'scanimage.components.scan2d.RggScan');
            if isvDAQ
                obj.pmLoggingStartTrigger.Enable = 'off';
                obj.pmBeamAiId.Enable = 'off';
            else
                obj.pmLoggingStartTrigger.Enable = 'on';
                obj.pmBeamAiId.Enable = 'on';
            end
            
            obj.pmLoggingStartTrigger.String = [{''}, obj.hResourceStore.filterByClass('dabs.resources.ios.PFI')];
            obj.pmLoggingStartTrigger.pmValue = obj.hResource.loggingStartTrigger;
            
            obj.pmBeamAiId.String = [{''}, obj.hResourceStore.filterByClass('dabs.resources.ios.AI')];
            obj.pmBeamAiId.pmValue = obj.hResource.BeamAiId;
            
            obj.pmStimActiveOutputChannel.String = [{''}, obj.hResourceStore.filter(@(hR)isa(hR,'dabs.resources.ios.DO')&&hR.supportsHardwareTiming)];
            obj.pmStimActiveOutputChannel.pmValue = obj.hResource.stimActiveOutputChannel;
            
            obj.pmBeamActiveOutputChannel.String = [{''}, obj.hResourceStore.filter(@(hR)isa(hR,'dabs.resources.ios.DO')&&hR.supportsHardwareTiming)];
            obj.pmBeamActiveOutputChannel.pmValue = obj.hResource.beamActiveOutputChannel;
            
            obj.pmSlmTriggerOutputChannel.String = [{''}, obj.hResourceStore.filter(@(hR)isa(hR,'dabs.resources.ios.DO')&&hR.supportsHardwareTiming)];
            obj.pmSlmTriggerOutputChannel.pmValue = obj.hResource.slmTriggerOutputChannel;
        end
        
        function apply(obj)
            most.idioms.safeSetProp(obj.hResource,'hScan',obj.pmhScan.pmValue);
            most.idioms.safeSetProp(obj.hResource,'loggingStartTrigger',obj.pmLoggingStartTrigger.pmValue);
            most.idioms.safeSetProp(obj.hResource,'BeamAiId',obj.pmBeamAiId.pmValue);
            most.idioms.safeSetProp(obj.hResource,'stimActiveOutputChannel',obj.pmStimActiveOutputChannel.pmValue);
            most.idioms.safeSetProp(obj.hResource,'beamActiveOutputChannel',obj.pmBeamActiveOutputChannel.pmValue);
            most.idioms.safeSetProp(obj.hResource,'slmTriggerOutputChannel',obj.pmSlmTriggerOutputChannel.pmValue);
            
            obj.hResource.saveMdf();
            obj.hResource.validateConfiguration();
        end
        
        function remove(obj)
            % No-Op
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
