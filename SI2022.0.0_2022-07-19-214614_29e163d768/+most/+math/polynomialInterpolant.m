classdef polynomialInterpolant < handle
    % most.math.polynomialInterpolant(X,v) mimicks scatteredInterpolant
    % but uses most.math.polyfitn as the backend. see most.math.polyfitn
    % for description of parameter 'modelterms'
    %
    %   F = most.math.polynomialInterpolant(X,v) creates an interpolant that fits a
    %   surface of the form v = F(X) to the sample data set (X,v). The sample
    %   points X must have size NPTS-by-N in N-D, where NPTS is the number
    %   of points. Each row of X contains the coordinates of one sample point.
    %  The values v must be a column vector of length NPTS.
    %
    %   F = most.math.polynomialInterpolant(...,modelterms) specifies model
    %   terms for the polynomial fits. See most.math.polyfitn for details
    %
    %   polynomialInterpolant methods:
    %       vq = F(Xq) evaluates the scatteredInterpolant F at scattered query
    %       points Xq and returns a column vector of interpolated values vq.
    %       Each row of Xq contains the coordinates of one query point.
    %
    %       vq = F(D1q,D2q,...DNq)  also allow the scattered query
    %       points to be specified as column vectors of coordinates.
    
    properties
        Points = [];
        Values = [];
        ModelTerms = [];
    end
    
    properties (Hidden, SetAccess = private)
        polymodel;
    end
    
    methods
        function obj = polynomialInterpolant(X,v,modelterms)
            if nargin < 1 || isempty(X)
                X = [];
            end
            
            if nargin < 2 || isempty(v)
                v = [];
            end
            
            if nargin < 3 || isempty(modelterms)
                modelterms = [];
            end
            
            obj.Points = X;
            obj.Values = v;
            obj.ModelTerms = modelterms;
            
            if ~isempty(obj.Points) || ~isempty(obj.Values)
                obj.validateParameters();
            end
        end
    end
    
    methods
        function B = subsref(A,S)
            if numel(A)==1 && numel(S)==1 && strcmp(S.type,'()')
                B = A.interpolate(S.subs{:});
            else
                B = builtin('subsref',A,S);
            end
        end
        
        function v = interpolate(obj,varargin)
            points = horzcat(varargin{:});
            
            if isempty(obj.polymodel)
                obj.createPolyModel();
            end
            
            v = most.math.polyvaln(obj.polymodel,points);
        end
        
        function s = toStruct(obj)
            s = struct();
            s.Points = obj.Points;
            s.Values = obj.Values;
            s.ModelTerms = obj.ModelTerms;
        end
        
        function fromStruct(obj,s)
            obj.Points = s.Points;
            obj.Values = s.Values;
            obj.ModelTerms = s.ModelTerms;
        end
    end
    
    methods (Access = private)
        function createPolyModel(obj)
            obj.validateParameters();
            
            if isempty(obj.ModelTerms)
                modelTerms = size(obj.Points,2)-1;
            else
                modelTerms = obj.ModelTerms;
            end
            
            obj.polymodel = most.math.polyfitn(obj.Points,obj.Values,modelTerms);
        end
        
        function validateParameters(obj)
            assert(any(strcmp(class(obj.Points),{'single','double'})),'Points must be of class single or double');
            assert(any(strcmp(class(obj.Values),{'single','double'})),'Points must be of class single or double');
            assert(any(strcmp(class(obj.ModelTerms),{'single','double'})),'ModelTerms must be of class single or double');
            
            assert(~isempty(obj.Points) && ~isempty(obj.Values),'Points and Values cannot be empty');
            assert(size(obj.Points,1)==size(obj.Values,1),'Points and Values must have same number of entries');
            
            assert(size(obj.Values,2)==1,'Values must be a column vector');
        end
    end
    
    methods
        function set.Points(obj,val)
            if ~isequal(obj.Points,val)
                obj.Points = val;
                obj.polymodel = [];
            end
        end
        
        function set.Values(obj,val)
            if ~isequal(obj.Values,val)
                obj.Values = val;
                obj.polymodel = [];
            end
        end
        
        function set.ModelTerms(obj,val)
            if ~isequal(obj.ModelTerms,val)
                obj.ModelTerms = val;
                obj.polymodel = [];
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
