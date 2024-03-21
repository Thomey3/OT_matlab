classdef TreeNode < most.util.Uuid
    properties
        hParent;
    end
    
    properties (SetAccess = private)
        hChildren = {};
    end
    
    properties (Access = private)
        hParentBeingDestroyedListener;
        hChildBeingDestroyedListeners;
        
        tnClassName = mfilename('class');
    end
    
    events
        treeChanged;
    end
    
    methods
        function obj = TreeNode()
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hParentBeingDestroyedListener);
            most.idioms.safeDeleteObj(obj.hChildBeingDestroyedListeners);
        end
    end
    
    %% User methods
    methods
        function str = getDisplayInfo(obj)
            str = 'TreeNode';
        end
        
        function plotTree(obj,hParent)
            if nargin < 2 || isempty(hParent)
                hFig = most.idioms.figure('Name','Tree','NumberTitle','off');
                hParent = most.idioms.axes('Parent',hFig,'DataAspectRatio',[1 2 1],'Visible','off');
            end
            
            [parents,nodes] = obj.getTree();
            
            [xx,yy,h,s] = treelayout(parents);
            h = numel(unique(yy))-1;
            pts = [xx(:),yy(:)];
            pts(:,2) = pts(:,2);            
            pts = pts-min(pts);
            maxPts = max(pts);
            maxPts(maxPts==0) = 1;
            pts = pts./max(maxPts);
            
            w = getTreeLayoutWidth(pts(:,1),pts(:,2));
            pts = pts .* [w h]; 
            
            boxSize = [0.75 0.6];
            
            for idx = 1:length(nodes)
                makeInfobox(nodes{idx},pts(idx,:));
                
                if idx >= 2
                    parentIdx = parents(idx);
                    startPt = pts(parentIdx,:);
                    endPt = pts(idx,:);
                    drawConnection(startPt,endPt);
                end
            end
            
            %%% local functions
            function makeInfobox(node,pt)
                hRect = rectangle('Parent',hParent,'Position',[pt-boxSize/2 boxSize],'Curvature',0.1,'FaceColor',[1 1 1]*0.95);
                hRect.ButtonDownFcn = @(varargin)buttonDownFcn(node);
                
                if node.isequal(obj)
                    hRect.FaceColor(1) = 1;
                    hRect.EdgeColor = 'r';
                end
                hText = text('Parent',hParent,'Position',[pt,0],'String',node.getDisplayInfo(),'HorizontalAlignment','center','VerticalAlignment','middle','Hittest','off','PickableParts','none');
                
                function buttonDownFcn(node)
                    assignin('base','node',node);
                    link = '<a href ="matlab:evalin(''base'',''node'');">node</a>';
                    fprintf('------------------------\n');
                    fprintf(2,'Assigned %s in base.\n\n', link);
                    disp(node);
                end
            end
            
            function drawConnection(startPt,endPt)
                if startPt(2)>endPt(2)
                    endPt_ = endPt;
                    endPt = startPt;
                    startPt = endPt_;
                end
                
                startX = startPt(1);
                startY = startPt(2) + boxSize(2)/2;
                endX = endPt(1);
                endY = endPt(2) - boxSize(2)/2;
                
                [xx,yy] = getConnectorSpline();
                
                xx = xx * (endX-startX) + startX;
                yy = yy * (endY-startY) + startY;
                
                line('Parent',hParent,'XDAta',xx,'YData',yy);
            end
            
            function w = getTreeLayoutWidth(xx,yy)
                ys = unique(yy);
                minSpacing = Inf;
                extent = 0;
                for idx_ = 1:length(ys)
                    mask = ismember(yy,ys(idx_));
                    xs = xx(mask);
                    xs = sort(xs);
                    minSpacing_ = min(diff(xs));
                    extent_ = max(xs)-min(xs);
                    if minSpacing_ < minSpacing
                        minSpacing = minSpacing_';
                        extent = extent_;
                    end
                end
                w = extent / minSpacing;
            end
        end
        
        function [parents,nodes] = getTree(obj)
            path = obj.getAncestorList();
            root = path{end};
            [parents,nodes] = getTree([0],{root});
            
            function [parents,nodes] = getTree(parents,nodes)
                nodeIdx = numel(parents);
                node = nodes{end};                
                for idx = 1:numel(node.hChildren)
                    parents(end+1) = nodeIdx; % assign parent index
                    nodes{end+1} = node.hChildren{idx}; % assign node
                    [parents, nodes] = getTree(parents,nodes);
                end
            end
        end
                
        function [path,path_uuiduint64] = getAncestorList(obj)
            [path,path_uuiduint64] = getAncestors(0,obj);
            
            function [path,path_uuiduint64] = getAncestors(depth,obj)
                depth = depth+1;
                
                if isempty(obj.hParent)
                    path = cell(1,depth);
                    path{depth} = obj;
                    path_uuiduint64 = zeros(1,depth,'uint64');
                    path_uuiduint64(depth) = obj.uuiduint64;
                else
                    [path,path_uuiduint64] = getAncestors(depth,obj.hParent); % recursively traverse through tree
                    path{depth} = obj;
                    path_uuiduint64(depth) = obj.uuiduint64;
                end
            end
            
            % This code implements a proper tail recursion, but it turns out to be ~10% slower
%             preAllocate = 100;
%             path = cell(1,preAllocate);
%             path_uuiduint64 = zeros(1,preAllocate,'uint64');
%             
%             [idx,path,path_uuiduint64] = getAncestors(obj,0,path,path_uuiduint64);
%             path(idx+1:end) = [];
%             path_uuiduint64(idx+1:end) = [];
%             
%             function [idx,path,path_uuiduint64] = getAncestors(obj,idx,path,path_uuiduint64)
%                 idx = idx+1;
%                 path{idx} = obj;
%                 path_uuiduint64(idx) = obj.uuiduint64;
%                 
%                 if isempty(obj.hParent)
%                     return
%                 end
%                 
%                 [idx,path,path_uuiduint64] = getAncestors(obj.hParent,idx,path,path_uuiduint64); % recursively traverse through tree
%             end
        end
        
        function nodes = filterTree(obj,func)
            [~,nodes] = obj.getTree();
            
            mask = cellfun(@(n)func(n),nodes);
            nodes = nodes(mask);
        end
        
        function [path,toParent,commonAncestorIdx] = getRelationship(obj,other)
            % shortcut for same node for performance
            if isequal(obj,other)
                path = {obj};
                toParent = [];
                commonAncestorIdx = 1;
                return
            end
            
            assert(isscalar(other) && isa(other,obj.tnClassName) && isvalid(other));
            
            [objAncestors,objAncestorsUuid]     = obj.getAncestorList();
            [otherAncestors,otherAncestorsUuid] = other.getAncestorList();
            
            minLength = min(numel(objAncestors),numel(otherAncestors));
            
            % compare ancestors       
            objAncestorsUuid_minLength   =   objAncestorsUuid(end-minLength+1:end);
            otherAncestorsUuid_minLength = otherAncestorsUuid(end-minLength+1:end);
            
            commonAncestorIdxFromBack = minLength-find(objAncestorsUuid_minLength == otherAncestorsUuid_minLength,1,'first');
            
            if isempty(commonAncestorIdxFromBack)
                % no common ancestor
                path = [];
                toParent = [];
                commonAncestorIdx = [];
                return
            end
            
            commonAncestor = objAncestors(end-commonAncestorIdxFromBack);
            objAncestors(end-commonAncestorIdxFromBack:end)   = [];
            otherAncestors(end-commonAncestorIdxFromBack:end) = [];
            
            path = [objAncestors commonAncestor flip(otherAncestors)];
            commonAncestorIdx = numel(objAncestors)+1;
            
            toParent = [true(1,numel(objAncestors)), false(1,numel(otherAncestors))];
        end
        
        function ancestor = getCommonAncestor(obj,other)
            [path,~,commonAncestorIdx] = obj.getRelationship(other);
            ancestor = path(commonAncestorIdx);
        end
    end
    
    %% Property Getter/Setter
    methods
        function set.hParent(obj,val)            
            if isempty(val)
                val = [];
            else
                validateattributes(val,{obj.tnClassName},{'scalar'});
                assert(isvalid(val),'Not a valid coordinate system');
            end
            
            if ~isempty(val)
                ancestorList = val.getAncestorList();
                assert(~any(cellfun(@(a)a.isequal(obj),ancestorList)),...
                    'Circular parenting is not allowed');
            end
            
            if ~isempty(val)
                obj.validateParent(val);
            end
            
            most.idioms.safeDeleteObj(obj.hParentBeingDestroyedListener);
            obj.hParentBeingDestroyedListener = [];
            if ~isempty(obj.hParent) && isvalid(obj.hParent)
                obj.hParent.removeChild(obj);
            end
            
            obj.hParent = val;
            
            if ~isempty(obj.hParent)
                obj.hParentBeingDestroyedListener = most.ErrorHandler.addCatchingListener(obj.hParent,'ObjectBeingDestroyed',@obj.parentDestroyed);
                obj.hParent.addChild(obj);
            end
            
            notify(obj,'treeChanged');
        end
    end
    
    
    %% Internal methods
    methods (Hidden)
        function parentDestroyed(obj,varargin)
            obj.hParent = [];
        end
        
        function childDestroyed(obj,src,~)
            obj.removeChild(src);
        end
    end
    
    methods (Access = protected)
        function validateParent(obj,hNewParent)
            % overload if needed
            % throws if newParent is not valid
        end
    end
        
    methods (Access = private)
        function addChild(obj,hChild)
            obj.removeChild(hChild)
            obj.hChildren{end+1} = hChild;
            obj.addChildListeners();
        end
        
        function removeChild(obj,hChild)
            tf = hChild.uuidcmp(obj.hChildren);
            obj.hChildren(tf) = [];
            obj.addChildListeners();
        end
        
        function addChildListeners(obj)
            most.idioms.safeDeleteObj(obj.hChildBeingDestroyedListeners);
            obj.hChildBeingDestroyedListeners = [];
            for idx = 1:numel(obj.hChildren)
                newListener = most.ErrorHandler.addCatchingListener(obj.hChildren{idx},'ObjectBeingDestroyed',@obj.childDestroyed);
                obj.hChildBeingDestroyedListeners = [obj.hChildBeingDestroyedListeners newListener];
            end
        end
    end
end

function [xx,yy] = getConnectorSpline()
persistent xx_ yy_
if isempty(xx_) || isempty(yy_)
    cs = spline([0 1],[0 0 1 0]);
    yy_ = linspace(0,1,100);
    xx_ = ppval(cs,yy_);
    
    straightFraction = 0.05;
    yy_ = yy_ * (1-2*straightFraction) + straightFraction;
    
    xx_ = [0 xx_ 1];
    yy_ = [0 yy_ 1];
    
end

xx = xx_;
yy = yy_;
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
