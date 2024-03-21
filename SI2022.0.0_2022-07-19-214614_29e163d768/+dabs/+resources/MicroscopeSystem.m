classdef MicroscopeSystem < dabs.resources.Device & dabs.resources.configuration.HasConfigPage
    properties (SetAccess=protected,Hidden)
        ConfigPageClass = 'dabs.resources.configuration.resourcePages.BlankPage';
    end
    
    properties (Abstract, Constant)
        manufacturer;
        detailedName;
    end
    
    properties
        vdaqR1Present;
        vdaqPresent;
        useFlexRio;
        useNidaq;
        createScanner;
        
        hVdaq;
        hNIRIO;
        hSI;
        hMotors;
        hPhotostim;
    end
    
    %% LIFECYCLE
    methods
        function obj = MicroscopeSystem(name)
            if nargin < 1 || isempty(name)
                name = 'Microscope Template';
            end
            
            obj@dabs.resources.Device(name);
            
            vdaqs = obj.hResourceStore.filterByClass('dabs.resources.daqs.vDAQR1');
            
            obj.vdaqR1Present = ~isempty(vdaqs);
            if ~obj.vdaqR1Present
                vdaqs = obj.hResourceStore.filterByClass('dabs.resources.daqs.vDAQ');
            end
            
            obj.vdaqPresent = ~isempty(vdaqs);
            if obj.vdaqPresent
                obj.hVdaq = vdaqs{1};
            end
            
            hAM = obj.hResourceStore.filterByClass('dabs.resources.daqs.NIFlexRIOAdapterModule');
            amPresent = ~isempty(hAM);
            if amPresent
                obj.hNIRIO = hAM{1}.hNIRIO;
            end
            
            obj.useFlexRio = ~obj.vdaqPresent && amPresent;
            obj.useNidaq = ~obj.useFlexRio && ~obj.vdaqPresent && ~isempty(obj.hResourceStore.filterByClass('dabs.resources.daqs.NIDAQ'));
            
            hSI = obj.hResourceStore.filterByClass('scanimage.SI');
            obj.createScanner = isempty(hSI) || ~hSI{1}.mdlInitialized;
            if isempty(hSI)
                obj.hSI = scanimage.SI();
            else
                obj.hSI = hSI{1};
            end
            
            obj.hMotors = obj.hSI.hMotors;
            if isprop(obj.hSI, 'hPhotostim')
                obj.hPhotostim = obj.hSI.hPhotostim;
            end
            
            try
                obj.reinit();
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
            
            obj.delete();
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
