classdef vDAQR1 < dabs.resources.daqs.vDAQ
    properties (SetAccess = protected)
        hBreakout
    end
    
    properties (SetAccess = private, GetAccess = private)
        hListeners = event.listener.empty(0,1);
    end
    
    methods
        function obj = vDAQR1(name)
            obj@dabs.resources.daqs.vDAQ(name);
            
            if ~obj.simulated
                % sanity check
                s = dabs.vidrio.rdi.Device.getDeviceInfo(obj.vDAQNumber);
                assert(s.hardwareRevision==1);
            end
            
            numAOs = 12;
            numAIs = 12;
            terminalsPerBank = 8;
            iobanks = [0 1];
            ibanks  = [2];
            obanks  = [3];
            digitizerInputs = 4;
            
            hDigitizerAIs_ = arrayfun(@(idx)dabs.resources.ios.DigitizerAI(sprintf('/%s/DigitizerAI%d',obj.name,idx),obj),0:digitizerInputs-1,'UniformOutput',false);
            obj.hDigitizerAIs = horzcat(hDigitizerAIs_{:});
            
            hAOs_ = arrayfun(@(x)dabs.resources.ios.AO(sprintf('/%s/AO%d',obj.name,x),obj),0:numAOs-1,'UniformOutput',false);
            obj.hAOs = horzcat(hAOs_{:});
            
            hAIs_ = arrayfun(@(x)dabs.resources.ios.AI(sprintf('/%s/AI%d',obj.name,x),obj),0:numAIs-1,'UniformOutput',false);
            obj.hAIs = horzcat(hAIs_{:});
            
            [p,l] = meshgrid(iobanks,0:terminalsPerBank-1);     
            hDIOs_ = arrayfun(@(p,l)dabs.resources.ios.DIO(sprintf('/%s/D%d.%d',obj.name,p,l),obj),p(:),l(:),'UniformOutput',false);
            obj.hDIOs = horzcat(hDIOs_{:});
            [obj.hDIOs.supportsHardwareTiming] = deal(true);
            
            [p,l] = meshgrid(ibanks,0:terminalsPerBank-1);
            hDIs_ = arrayfun(@(p,l)dabs.resources.ios.DI(sprintf('/%s/D%d.%d',obj.name,p,l),obj),p(:),l(:),'UniformOutput',false);
            obj.hDIs = horzcat(hDIs_{:});
            [obj.hDIs.supportsHardwareTiming] = deal(true);
            
            [p,l] = meshgrid(obanks,0:terminalsPerBank-1);     
            hDOs_ = arrayfun(@(p,l)dabs.resources.ios.DO(sprintf('/%s/D%d.%d',obj.name,p,l),obj),p(:),l(:),'UniformOutput',false);
            obj.hDOs = horzcat(hDOs_{:});
            [obj.hDOs.supportsHardwareTiming] = deal(true);
            
            obj.hCLKIs = dabs.resources.ios.CLKI(sprintf('/%s/CLK_IN', obj.name),obj);
            obj.hCLKOs = dabs.resources.ios.CLKO(sprintf('/%s/CLK_OUT',obj.name),obj);
            
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hResourceStore.hSystemTimer,'beacon_QueryIO',@(varargin)obj.queryDigitalPorts);
        end
        
        function delete(obj)
            delete(obj.hListeners);
        end
    end
    
    methods
        function queryDigitalPorts(obj)
            if isempty(obj.hFpga) || ~obj.hFpga.initialized
                return
            end
            
            if ~obj.simulated
                register = obj.hFpga.dio_i;
                mask = uint32(2).^uint32(0:31);
                d = logical(bitand(mask,register));
                
                port0 = d(1:8);
                port1 = d(9:16);
                port2 = d(17:24);
                port3 = d(25:32);
                
                for idx = 1:8
                    obj.hDIOs(idx).lastKnownValue = port0(idx);
                end
                
                for idx = 1:8
                    obj.hDIOs(idx+8).lastKnownValue = port1(idx);
                end
                
                for idx = 1:numel(obj.hDIs)
                    obj.hDIs(idx).lastKnownValue = port2(idx);
                end
                
                for idx = 1:numel(obj.hDOs)
                    obj.hDOs(idx).lastKnownValue = port3(idx);
                end
            else
                for idx = 1:numel(obj.hDIOs)
                    str = num2str(idx-1);
                    obj.hDIOs(idx).lastKnownValue = obj.hFpga.simRegs.(['digital_o_' str])>1;
                end
                
                for idx = 1:numel(obj.hDIs)
                    str = num2str(idx-1+16);
                    obj.hDIs(idx).lastKnownValue = obj.hFpga.simRegs.(['digital_o_' str])>1;
                end
                
                for idx = 1:numel(obj.hDOs)
                    str = num2str(idx-1+24);
                    obj.hDOs(idx).lastKnownValue = obj.hFpga.simRegs.(['digital_o_' str])>1;
                end
            end
        end
    end
    
    %%% Abstract methods realization dabs.resources.daqs.vDAQ
    methods
        function showBreakout(obj)
            if most.idioms.isValidObj(obj.hBreakout)
                obj.hBreakout.raise();
            else
                obj.hBreakout = dabs.resources.configuration.private.vDAQR1Breakout(obj);
            end
        end
        
        function hideBreakout(obj)
            most.idioms.safeDeleteObj(obj.hBreakout);
            obj.hBreakout = [];
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
