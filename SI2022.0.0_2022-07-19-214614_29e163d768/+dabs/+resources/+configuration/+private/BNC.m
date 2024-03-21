classdef BNC < handle
    properties
        Position = [0 0];
    end
    
    properties (SetAccess = private, Hidden)
        hResource;
        hParent;
        hListeners = event.listener.empty(0,1);
        
        hGroup
        hPatch
        hPatchHighLight
        hPatchLed
        hText
        radius = 8;
    end
    
    properties (SetAccess = private)
        hHighlightResource
        ledValue = false;
    end
    
    methods
        function obj = BNC(hResource,hParent)
            obj.hResource = hResource;
            obj.hParent = hParent;
            
            obj.hGroup = hggroup('Parent',obj.hParent);
            
            if isa(obj.hResource,'dabs.resources.ios.D')
                obj.hPatchLed = patch('Parent',obj.hGroup,'Faces',[],'Vertices',[],'FaceColor',most.constants.Colors.vidrioBlue,'LineStyle','none','Visible','off');
                obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'lastKnownValueChanged',@(varargin)obj.updateLed);
                
                obj.updateLed();
            end
            
            obj.hPatch = patch('Parent',obj.hGroup,'Faces',[],'Vertices',[],'FaceColor',most.constants.Colors.vidrioBlue,'ButtonDownFcn',@(varargin)obj.configResource,'LineStyle','none');
            obj.hPatchHighLight = patch('Parent',obj.hGroup,'Faces',[],'Vertices',[],'FaceColor',most.constants.Colors.red,'ButtonDownFcn',@(varargin)obj.configResource,'LineStyle','none');
            obj.hText = text('Parent',obj.hGroup,'HorizontalAlignment','center','VerticalAlignment','middle','Color','white','FontSize',10,'Hittest','off','PickableParts','none');
            
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'hUsers','PostSet',@(varargin)obj.redraw);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResource,'ObjectBeingDestroyed',@(varargin)obj.delete);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hParent, 'ObjectBeingDestroyed',@(varargin)obj.delete);
            
            obj.redraw();
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hListeners);
            most.idioms.safeDeleteObj(obj.hGroup);
        end
    end
    
    methods
        function highlightResource(obj,hResource)
            if nargin < 2 || isempty(hResource)
                hResource = [];
            end
            
            obj.hHighlightResource = hResource;
            obj.redraw();
        end
    end
    
    methods (Hidden)
        function WindowButtonMotionFcn(obj,src,evt)
            %obj.redraw();
        end
    end
    
    methods (Access = private)        
        function redraw(obj)
            try
                if isa(obj.hResource,'dabs.resources.ios.D')
                    if isa(obj.hResource.hDAQ,'dabs.resources.daqs.vDAQR0')
                        dxy = [-11 -3];
                    else
                        dxy = [-12.5 -2.5];
                    end
                    r = 1.5;
                    phi = linspace(0,2*pi,20)';
                    xx = sin(phi)*r + obj.Position(1) + dxy(1);
                    yy = cos(phi)*r + obj.Position(2) + dxy(2);
                    zz = zeros(size(xx));
                    obj.hPatchLed.Faces = 1:numel(xx);
                    obj.hPatchLed.Vertices = [xx,yy,zz];
                end
                
                if isempty(obj.hResource.hUsers)
                    obj.hPatch.Visible = 'off';
                    obj.hPatchHighLight.Visible = 'off';
                    obj.hText.Visible = 'off';
                else
                    hUsers = obj.hResource.hUsers;
                    descriptions = obj.hResource.userDescriptions;
                    strs = cellfun(@toString,hUsers,descriptions,'UniformOutput',false);
                    obj.hText.String = most.idioms.latexEscape( strjoin(strs,'\n') );
                    obj.hText.Position = obj.Position;
                    obj.hText.Visible = 'on';
                    
                    phi = linspace(0,2*pi,100)';
                    xx = sin(phi)*obj.radius + obj.Position(1);
                    yy = cos(phi)*obj.radius + obj.Position(2);
                    obj.hPatch.Vertices = [xx yy];
                    obj.hPatch.Faces = 1:numel(phi);
                    obj.hPatch.Visible = 'on';

                    width = 1.5;
                    phi = linspace(0,2*pi,100)';
                    outer = [sin(phi),cos(phi)] * (obj.radius+width/2);
                    inner = flipud([sin(phi),cos(phi)]) * (obj.radius-width/2);
                    v = [outer;inner];
                    v = bsxfun(@plus,v,obj.Position);

                    obj.hPatchHighLight.Vertices = v;
                    obj.hPatchHighLight.Faces = 1:size(v,1);

                    if isHighlighted()
                        obj.hPatchHighLight.Visible = 'on';
                    else
                        obj.hPatchHighLight.Visible = 'off';
                    end

                    if obj.hResource.hasUserConflict()
                        obj.hPatch.FaceColor = most.constants.Colors.lightRed;
                    else
                        obj.hPatch.FaceColor = most.constants.Colors.vidrioBlue;
                    end
                end
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
            
            %%% Nested functions
            function str = toString(hUser,description)
                name = most.idioms.ifthenelse(isprop(hUser,'name'),hUser.name,class(hUser));
                description = most.idioms.ifthenelse(~isempty(description),description,'');
                str = sprintf('%s\n%s',name,description);
            end
            
            function tf = isHighlighted()
                tf = isequal(obj.hHighlightResource,obj.hResource);
                tf = tf || any(cellfun(@(hR)isequal(hR,obj.hHighlightResource),obj.hResource.hUsers));
            end
        end
        
        function configResource(obj)
            hUsers = obj.hResource.hUsers;
            if ~isempty(hUsers)
                hUser = hUsers{1}; % for the moment only worry about first user
                if isa(hUser,'dabs.resources.configuration.HasConfigPage')
                    hUser.showConfig();
                end
            end
        end
        
        function updateLed(obj)
            obj.ledValue = obj.hResource.lastKnownValue;
        end
    end
    
    methods
        function set.Position(obj,val)
            validateattributes(val,{'numeric'},{'size',[1,2]});
            obj.Position = val;
            obj.redraw();
        end
        
        function set.ledValue(obj,val)
            oldVal = obj.ledValue;
            obj.ledValue = val;
            
            if oldVal ~= obj.ledValue
                if isnan(val) || ~val
                    obj.hPatchLed.Visible = 'off';
                else
                    obj.hPatchLed.Visible = 'on';
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
