classdef DigitalShutterPage < dabs.resources.configuration.ResourcePage
    properties
        pmhDOControl
        etOpenTime
        cbInvertOutput
        pmShutterTarget
    end
    
    methods
        function obj = DigitalShutterPage(hResource,hParent)
            obj@dabs.resources.configuration.ResourcePage(hResource,hParent);
        end
        
        function makePanel(obj,hParent)
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [24 30 120 20],'Tag','txhDOControl','String','Control Channel','HorizontalAlignment','right');
            obj.pmhDOControl  = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [150 27 150 20],'Tag','pmhDOControl');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [23 54 120 20],'Tag','txOpenTime','String','Open time (seconds)','HorizontalAlignment','right');
            obj.etOpenTime = most.gui.uicontrol('Parent',hParent,'Style','edit','RelPosition', [150 52 150 20],'Tag','etOpenTime');
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [22 74 120 20],'Tag','txInvertOutput','String','Invert Output','HorizontalAlignment','right');
            obj.cbInvertOutput = most.gui.uicontrol('Parent',hParent,'Style','checkbox','RelPosition', [150 72 120 20],'Tag','cbInvertOutput');
            
            most.gui.uicontrol('Parent',hParent,'Style','text','RelPosition', [22 105 120 20],'Tag','txShutterTarget','String','Path','HorizontalAlignment','right');
            obj.pmShutterTarget  = most.gui.uicontrol('Parent',hParent,'Style','popupmenu','String',{''},'RelPosition', [150 103 150 20],'Tag','pmShutterTarget');
        end
        
        function redraw(obj)            
            hIOs = obj.hResourceStore.filterByClass({'dabs.resources.ios.DO','dabs.resources.ios.PFI'});
            obj.pmhDOControl.String = [{''}, hIOs];
            obj.pmhDOControl.pmValue = obj.hResource.hDOControl;
            
            obj.etOpenTime.String = num2str(obj.hResource.openTime_s);
            obj.cbInvertOutput.Value = obj.hResource.invertOutput;

            m = arrayfun(@(e)char(e),enumeration(class(obj.hResource.shutterTarget)),'UniformOutput',false);
            obj.pmShutterTarget.String = [{''},m(:)'];
            if isempty(obj.hResource.shutterTarget)
                obj.pmShutterTarget.pmValue = '';
            else
                obj.pmShutterTarget.pmValue = char(obj.hResource.shutterTarget(1));
            end
        end
        
        function apply(obj)
            most.idioms.safeSetProp(obj.hResource,'hDOControl',obj.pmhDOControl.pmValue);
            
            most.idioms.safeSetProp(obj.hResource,'openTime_s',str2double(obj.etOpenTime.String));
            most.idioms.safeSetProp(obj.hResource,'invertOutput',obj.cbInvertOutput.Value);
            most.idioms.safeSetProp(obj.hResource,'shutterTarget',obj.pmShutterTarget.pmValue);
            
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
