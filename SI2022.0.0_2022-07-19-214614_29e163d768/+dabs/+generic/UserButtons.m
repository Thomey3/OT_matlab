classdef UserButtons < dabs.resources.Device & most.HasMachineDataFile & dabs.resources.configuration.HasConfigPage & dabs.resources.widget.HasWidget
    %% ABSTRACT PROPERTY REALIZATIONS (most.HasMachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'UserButtons';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
        
        mdfDefault = defaultMdfSection();
    end
    
    properties (SetAccess=protected,Hidden)
        WidgetClass = 'dabs.resources.widget.widgets.UserButtonsWidget'; 
        ConfigPageClass = 'dabs.resources.configuration.resourcePages.UserButtonsPage';
    end
    
    methods (Static, Hidden)
        function names = getDescriptiveNames()
            names = {'User Buttons'};
        end
    end
    
    properties (SetObservable)
        userButtons = cell(0,2);
    end
    
    methods
        function obj = UserButtons(name)
            obj@dabs.resources.Device(name);
            obj@most.HasMachineDataFile(true);
            
            obj.deinit();
            obj.loadMdf();
            obj.reinit();
        end
        
        function delete(obj)
            obj.deinit();
        end
    end
    
    methods
        function deinit(obj)
            % No-Op
        end
        
        function reinit(obj)
            % No-Op
        end
    end
    
    methods
        function executeFunction(obj,buttonName)
            names = cellfun(@(entry)entry{1},obj.userButtons,'UniformOutput',false);
            fcns  = cellfun(@(entry)entry{2},obj.userButtons,'UniformOutput',false);
            mask = strcmp(names,buttonName);
            
            fcn = fcns(mask);
            
            assert(~isempty(fcn),'Unknown buttonName: %s',buttonName);
            fcn = fcn{1};
            fcn();
        end
        
        function loadMdf(obj)
            success = true;
            success = success & obj.safeSetPropFromMdf('userButtons', 'userButtons');
            
            if ~success
                obj.errorMsg = 'Error loading config';
            end
        end
        
        function saveMdf(obj)
            obj.safeWriteVarToHeading('userButtons', obj.userButtons);
        end
    end
    
    methods        
        function set.userButtons(obj,val)
            if isempty(val)
                val = cell(1,0);
            end
            
            validMask = false(1,numel(val));
            for idx = 1:numel(val)
                entry = val{idx};
                
                valid = iscell(entry) && numel(entry)==2;
                valid = valid && ~isempty(entry{1}) && ischar(entry{1}); %check name
                valid = valid && ~isempty(entry{2}) && (ischar(entry{2}) || isa(entry{2},'function_handle'));
                                
                if valid && ischar(entry{2})
                    val{idx}{2} = str2func(entry{2});
                end
                
                validMask(idx) = valid;
            end
            
            val(~validMask)= [];
            
            obj.userButtons = val;            
        end
    end
end

function s = defaultMdfSection()
s = [...
    most.HasMachineDataFile.makeEntry('userButtons',{{}},'user buttons')...
    ];
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
