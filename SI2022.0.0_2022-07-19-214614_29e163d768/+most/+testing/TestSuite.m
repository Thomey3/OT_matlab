classdef TestSuite < most.DClass
    %TESTSUITE Summary of this class goes here
    %   Detailed explanation goes here
    
    %% ABSTRACT PROPERTIES
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    properties (Abstract, Constant)
        classUnderTest; % An evaluable expression pointing to the class/program being tested.
        constructionPVArgs; % A cell array of args to be passed to 'classUnderTest'.
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
 
    %% CLASS PROPERTIES
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    properties (Access=protected)
        hTestFixture; % A handle to the constructed object of the class under test.
        tests; % A map containing all tests in this test suite.
               % maps 'testGroupString' --> {cell array of tests}
    end
    
    properties (Hidden, Access=protected)
        isClass; % A logical indicating, if true, that classUnderTest represents a constructable object (as opposed to, say, Scanimage, which does not return an object handle).
                 % If false, 'classUnderTest' will be evaluated, but no object handle will be expected or stored.
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    
    %% CONSTRUCTOR/DESTRUCTOR
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    methods
        function obj = TestSuite(varargin)
            
            optionalArgs = obj.filterPropValArgs(varargin,{'isClass'});
            if ~isempty(optionalArgs)
                obj.set(optionalArgs(1:2:end),optionalArgs(2:2:end));
            end
            
            if isempty(obj.isClass)
               obj.isClass = true; 
            end
            
            try
                if obj.isClass == true
                    obj.hTestFixture = feval(obj.classUnderTest,obj.constructionPVArgs{:});
                else
                    feval(obj.classUnderTest,obj.constructionPVArgs{:});
                    obj.hTestFixture = [];
                end
            catch ME
                 
            end
            
            obj.tests = containers.Map('KeyType','char','ValueType','any');
            obj.tests('all') = {};
        end
        
        function delete(obj)
            if ~isempty(obj.hTestFixture) && isvalid(obj.hTestFixture)
                delete(obj.hTestFixture);
            end
        end
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    
    %% ABSTRACT METHODS
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    methods(Abstract,Access=protected)
        setup(obj); 
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    
    %% CLASS METHODS
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    methods(Access=public)
        
        function addTest(obj,test,testGroup)
            % Adds a Test to this TestSuite.  
            % 'test': the Test to be added.
            % 'testGroup': An (optional) string specifying a group for this test to be associated with.  Default is 'all'.
            
            if nargin < 3 || isempty(testGroup)
                testGroup = 'all';
            else
                testGroup = lower(testGroup);
            end
            
            if obj.tests.isKey(testGroup)
                obj.tests(testGroup) = [obj.tests(testGroup) {test}];
            else
                obj.tests(testGroup) = test;
            end
        end
        
        function run(obj,testGroup)
            % Executes a set of tests.
            % 'testGroup': An (optional) string specifying the test group to execute.  Default is 'all'.
            
            if nargin < 2 || isempty(testGroup)
               testGroup = 'all'; 
            else
                testGroup = lower(testGroup);
            end
            
            % Pre-loop initialization
            i = 1;
            output = ['Beginning test of ' obj.classUnderTest '...'];
            if strcmp(testGroup,'all')
                output = [output 'executing all tests.'];
            else
                output = [output 'executing ' testGroup ' tests.'];
            end
            disp(output);
                
            for test=obj.tests(testGroup)
                test = test{:};
                try
                    [didPass,testOutput] = test.run();
                catch ME
                    
                end
                
                % Initialize this test's output
                tempOutput = sprintf('\n\rTest #%d ',i);
                if ~isempty(test.getName())
                   tempOutput = [tempOutput '(''' test.getName() ''')']; 
                end
                
                if didPass
                    tempOutput = [tempOutput ' passed: ' testOutput];
                else
                    tempOutput = [tempOutput ' failed with the following output: ' testOutput];
                end
                disp(tempOutput);
                output = [output tempOutput];
                
                i = i + 1;
            end
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
