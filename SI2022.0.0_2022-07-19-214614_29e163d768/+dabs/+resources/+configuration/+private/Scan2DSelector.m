classdef Scan2DSelector < handle
    properties (SetAccess = private)
        hFig
    end
    
    methods
        function obj = Scan2DSelector()
            obj.hFig = most.idioms.figure('Name','Select scan system','CloseRequestFcn',@(varargin)obj.delete,'NumberTitle','off','MenuBar','none');
            obj.hFig.Position = most.gui.centeredScreenPos([800,280]);
            
            hMainFlow = most.gui.uiflowcontainer('Parent',obj.hFig,'FlowDirection','LeftToRight','Margin',10);    
                obj.makePanel(hMainFlow,'RggScan.png','vDAQ Scan System','scanimage.components.scan2d.RggScan');
                obj.makePanel(hMainFlow,'ResScan.png','NI Resonant Scan System','scanimage.components.scan2d.ResScan');
                obj.makePanel(hMainFlow,'LinScan.png','NI Linear Scan System','scanimage.components.scan2d.LinScan');
                obj.makePanel(hMainFlow,'SlmScan.png','SLM Scan System','scanimage.components.scan2d.SlmScan');
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hFig);
        end
        
        function makePanel(obj,hParent,imageFile,title,className)
            hPanel = uipanel('Parent',hParent);
            hMainFlow = most.gui.uiflowcontainer('Parent',hPanel,'FlowDirection','TopDown');
            hTitleFlow = most.gui.uiflowcontainer('Parent',hMainFlow,'FlowDirection','LeftToRight','HeightLimits',[30 30]);
            hAxFlow = most.gui.uiflowcontainer('Parent',hMainFlow,'FlowDirection','LeftToRight');
            hButtonFlow = most.gui.uiflowcontainer('Parent',hMainFlow,'FlowDirection','LeftToRight','HeightLimits',[30 30]);
            
            hAx = most.idioms.axes('Parent',hAxFlow,'DataAspectRatio',[1,1,1],'Color','white','XTick',[],'YTick',[],'ButtonDownFcn',@(varargin)obj.createResource(className));
            view(hAx,0,-90);
            axis(hAx,'tight');
            box(hAx,'on');
            filePath = fileparts(mfilename('fullpath'));
            imageFile = fullfile(filePath,imageFile);
            [im,~,transparency] = imread(imageFile);
            imagesc('Parent',hAx,'CData',im,'AlphaData',transparency,'Hittest','off');
            
            uicontrol('Parent',hTitleFlow,'Style','text','String',title,'FontWeight','bold');
            uicontrol('Parent',hButtonFlow,'String','Add','Callback',@(varargin)obj.createResource(className));
        end
        
        function createResource(obj,className)            
            resourceName = dabs.resources.configuration.private.queryUserForName();
            
            if isempty(resourceName)
                return
            end
            
            if ~isvarname(resourceName)
                msg = sprintf('Invalid name for imaging system ''%s''.\nName must be a valid Matlab variable name.\n(i.e. no white spaces or special characters)\nExample: ResonantImaging',resourceName);
                warndlg(msg,'Info')
                return
            end
            
            obj.delete();
            
            constructor = str2func(className);
            hResource = constructor(resourceName);
            hResource.showConfig();
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
