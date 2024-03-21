classdef Test < most.DClass
    %TEST Summary of this class goes here
    %   Detailed explanation goes here
    
    
    %% CLASS PROPERTIES
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    properties (Access=protected)
        testName; % An optional human-readable name for this test.
        hFunction; % A function handle to the method under test.
        successCondition; % An evaluable (logical) expression that encodes the success condition for the method under test.
        fncArgs = {}; % A cell array of arguments to be passed to the method under test.
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    
    %% CONSTRUCTOR/DESTRUCTOR
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    methods
        
        function obj = Test(testFunction,varargin)
            % hTestFunction - a function handle or a string containing a function name (DEQ20101220 - not reliably working)
            % optional:
            %   'testFixture' - an object on which to make the function call (DEQ20101220 - not reliably working)
            %   'successCondition' - an evaluable expression to verify test success
            %   'testName' - a human-readable name for this test.
            %   'fncArgs' - a cell array of values to be passed to the the method under test.
            
            % Handle optional arg/val pairs
            pvargs = obj.filterPropValArgs(varargin,{'testFixture' 'successCondition' 'testName' 'fncArgs'});
            if ~isempty(pvargs)
                obj.set(pvargs(1:2:end),pvargs(2:2:end));
            end
            
            if isempty(obj.successCondition)
                obj.successCondition = 'true';
            end
            
            if isempty(obj.testName)
                obj.testName = '';
            end
            
            if isempty(obj.fncArgs)
                obj.fncArgs = {};
            end
            
            % 'hTestFunction': accept either a function handle or a function
            % name (string). If a name is given, it is assumed to exist as
            % a method of 'testFixture'.
            %
            % TODO (DEQ): As of now, the 'string' form of this does not (reliably) 
            % work, as I can't figure out a way to accept a variable number 
            % of output arguments from an anonymous function handle...the
            % consequence of this is that any tested class method must be 
            % wrapped by a 'testXXX()' function (in whatever class inherits
            % from TestSuite).  
            if isa(testFunction,'function_handle')
                obj.hFunction = testFunction;
            elseif isa(testFunction,'char') % DEQ20101220 - this works if 'testFunction' returns a single var, but problems occur later when you encounter functions with multiple output args
                obj.hFunction = @(varargin)testFixture.(testFunction)(varargin);
            else
                error('Invalid ''testFunction''.'); 
            end
            
        end
        
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    
    %% CLASS METHODS
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    methods (Access = public)
        
        function [didPass,output] = run(obj)            
            % Execute the method under test.
            try
                [didPass, output] = feval(obj.hFunction,obj.fncArgs{:});
            catch ME
                didPass = false;
                output = ME.message;
                return;
            end
            
            % Confirm the success condition.
            if didPass == true
                try
                    assert(eval(obj.successCondition),'The test''s success condition was not met.');
                catch ME
                    didPass = false;
                    output = ME.message;
                    return;
                end
            else
               return; 
            end
            
            didPass = true;
            output = 'Success.';
            return;
        end
        
        function val = getName(obj)
           val = obj.testName; 
        end

    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    
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
