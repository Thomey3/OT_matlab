classdef StaticHeightText < handle & dynamicprops
    properties (Hidden)
        hText
        hListeners = event.listener.empty(1,0);
    end
    
    properties
        FontSize = 1; % in axes units
    end
    
    methods
        function obj = StaticHeightText(varargin)
            mask = strcmpi('FontSize',varargin);
            if any(mask)
                idx = find(mask,1);
                FontSize_ = varargin{idx+1};
                varargin(idx:idx+1) = [];
            else
                FontSize_ = obj.FontSize;
            end
            
            obj.hText = text(varargin{:});
            
            obj.addTextProperties();
            
            hAx = ancestor(obj.hText,'axes');
            
            obj.hListeners(end+1) = addlistener(hAx,'SizeChanged',@obj.resize);
            obj.hListeners(end+1) = addlistener(hAx,'YLim','PostSet',@obj.resize);
            obj.hListeners(end+1) = addlistener(obj.hText,'ObjectBeingDestroyed',@(varargin)obj.delete);
            
            obj.FontSize = FontSize_;
        end
        
        function delete(obj)
            delete(obj.hListeners);
            delete(obj.hText);
        end
    end
    
    methods (Access = private)        
        function addTextProperties(obj)            
            propNames = properties(obj.hText);
            propNames = setdiff(propNames,properties(obj)); % filter out properties of StaticHeightText
            cellfun(@(p)obj.addTextProperty(p),propNames);
        end
        
        function addTextProperty(obj,propName)
            hP = obj.addprop(propName);
            hP.SetMethod = @(obj,val)setMethod(obj,propName,val);
            hP.GetMethod = @(obj)getMethod(obj,propName);
            
            function setMethod(obj,propName,val)
                obj.hText.(propName) = val;
            end
            
            function val = getMethod(obj,propName)
                val = obj.hText.(propName);
            end
        end
        
        function resize(obj,varargin)
            hAx = ancestor(obj.hText,'axes');
            
            units_ = hAx.Units;
            hAx.Units = 'points';
            pos = hAx.Position;
            hAx.Units = units_;
            
            xdataSz = diff(hAx.XLim);
            ydataSz = diff(hAx.YLim);
            
            posAspectRatio = pos(3)/pos(4);
            dataAspectRatio = xdataSz/ydataSz;
            
            if dataAspectRatio > posAspectRatio
                pos(4) = pos(3) / dataAspectRatio;
            else
                pos(3) = pos(4) * dataAspectRatio;
            end
            
            ydataSz = diff(hAx.YLim);            
            sz =  obj.FontSize * pos(4) / ydataSz;
            obj.hText.FontSize = sz;
        end
    end
    
    methods
        function set.FontSize(obj,val)
            validateattributes(val,{'numeric'},{'scalar','positive','finite','nonnan'});
            obj.FontSize = val;
            obj.resize();            
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
