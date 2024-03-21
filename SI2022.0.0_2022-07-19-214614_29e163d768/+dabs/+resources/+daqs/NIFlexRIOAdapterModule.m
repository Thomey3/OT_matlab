classdef NIFlexRIOAdapterModule < dabs.resources.DAQ
    properties (SetAccess = private)
        hNIRIO
        serial
        
        productType
        productTypeLong
    end
    
    properties (SetAccess = private, Hidden)
        PHYSICAL_CHANNEL_COUNT = containers.Map({'NI5732','NI5733','NI5734','NI5751','NI517x','NI5771','NI5772'},{2,2,4,4,4,2,2});
    end
    
    properties (Dependent, SetAccess = protected)
        hDevice;
    end
    
    methods (Access = ?dabs.resources.daqs.NIRIO)
        function obj = NIFlexRIOAdapterModule(hNIRIO,adapterModuleName,serial)
            moduleNumber = regexpi(adapterModuleName,'([0-9]{4,4})','match','once');
            name = ['/' hNIRIO.name '/' 'NI' moduleNumber];
            
            obj@dabs.resources.DAQ(name);
            
            obj.hNIRIO = hNIRIO;
            obj.productType = ['NI' moduleNumber];
            obj.productTypeLong = adapterModuleName;
            obj.serial = serial;
            
            if obj.PHYSICAL_CHANNEL_COUNT.isKey(obj.productType)
                channelCount = obj.PHYSICAL_CHANNEL_COUNT(obj.productType);
                hDigitizerAIs_ = arrayfun(@(idx)dabs.resources.ios.DigitizerAI(sprintf('%s/DigitizerAI%d',obj.name,idx),obj),0:channelCount-1,'UniformOutput',false);
                obj.hDigitizerAIs = horzcat(hDigitizerAIs_{:});
            end
            
%             hDIs_ = arrayfun(@(idx)dabs.resources.ios.DI(sprintf('%s/DIO0.%d',obj.name,idx),obj),0:3,'UniformOutput',false);
%             obj.hDIs = horzcat(hDIs_{:});
%             
%             hDOs_ = arrayfun(@(idx)dabs.resources.ios.DO(sprintf('%s/DIO1.%d',obj.name,idx),obj),0:3,'UniformOutput',false);
%             obj.hDOs = horzcat(hDOs_{:});
%             
%             hPFIs_ = arrayfun(@(idx)dabs.resources.ios.PFI(sprintf('%s/PFI%d',obj.name,idx),obj),0:3,'UniformOutput',false);
%             obj.hPFIs = horzcat(hPFIs_{:});
        end
    end
    
    methods
        function reset(obj)
            % No-op
        end
    end
    
    methods
        function val = get.hDevice(obj)
            val = obj.hNIRIO.hDevice;
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
