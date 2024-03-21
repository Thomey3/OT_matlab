classdef vDAQ < dabs.resources.DAQ & dabs.resources.daqs.FPGA & dabs.resources.widget.HasWidget
    properties (SetAccess = protected)
        hFpga = scanimage.fpga.vDAQ_SI.empty(0,1);
    end
    
    properties (SetAccess = protected)
        WidgetClass = 'dabs.resources.widget.widgets.vDAQWidget';
        
        hardwareRevision = 0;
        firmwareVersion = '';
        productName = '';
    end
    
    properties (SetObservable)
        passiveMode = false; % prevents loading bitfile to FPGA if FPGA is already instantiated by other Matlab instance
        bitfileName = '';
    end
    
    properties (SetAccess = protected, Dependent)
        vDAQNumber
        hDevice
        
        serial
        fpgaSerial
        fpgaInitialized
        
        externalUsers;
    end
    
    methods
        function obj = vDAQ(name)
            obj@dabs.resources.DAQ(name);
            assert(dabs.vidrio.rdi.Device.isRdiDeviceName(name),'Not a vDAQ name: %s',name);
            
            s = dabs.vidrio.rdi.Device.getDeviceInfo(obj.vDAQNumber);
            obj.simulated = isempty(s);
            
            if ~obj.simulated
                s = dabs.vidrio.rdi.Device.getDeviceInfo(obj.vDAQNumber);
                obj.hardwareRevision = s.hardwareRevision;
                obj.firmwareVersion = s.firmwareVersion;
                obj.productName = s.productName;
            end
        end
    end
    
    methods (Abstract)
        showBreakout(obj);
        hideBreakout(obj);
        queryDigitalPorts(obj);
    end
    
    methods
        function showTestpanel(obj)
            if obj.simulated
                most.ErrorHandler.logAndReportError('Testpanel is not supported for simulated vDAQ');
            else
                scanimage.guis.VdaqTestPanel(obj.vDAQNumber);
            end
        end
    end
    
    %% Getter/Setter
    methods
        function val = get.vDAQNumber(obj)
            id = regexpi(obj.name,'[0-9]+$','match','once');
            assert(~isempty(id),'%s: Could not get vDAQ ID from name',obj.name);
            
            val = str2double(id);
        end
        
        function val = get.hDevice(obj)
            val = obj.initFPGA();
        end
        
        function val = get.serial(obj)
            if obj.simulated
                val = '';
            else
                obj.initFPGA();
                val = obj.hFpga.deviceSerialNumber;
            end
        end
        
        function val = get.fpgaSerial(obj)
            if obj.simulated
                val = '';
            else
                obj.initFPGA();
                val = obj.hFpga.fpgaSerialNumber;
            end
        end
        
        function set.passiveMode(obj,val)
            validateattributes(val,{'numeric','logical'},{'scalar'});
            obj.passiveMode = val;
        end
        
        function v = get.externalUsers(obj)
            s = dabs.vidrio.rdi.Device.getDeviceInfo(obj.vDAQNumber);
            v = s.numClients - double(most.idioms.isValidObj(obj.hFpga));
        end

        function val = get.fpgaInitialized(obj)
            val = ~isempty(obj.hFpga) && obj.hFpga.initialized;
        end
    end
    
    %% Abstract methods realization from dabs.resources.daqs.FPGA
    methods
        function hFpga = initFPGA(obj)
            if ~most.idioms.isValidObj(obj.hFpga)
                obj.hFpga = scanimage.fpga.vDAQ_SI(obj.vDAQNumber,obj.simulated);
                if ~obj.passiveMode || ~obj.hFpga.deviceInfo.designLoaded
                    
                    if ~isempty(obj.bitfileName)
                        bitfileDir = fullfile(fileparts(which('scanimage.fpga.vDAQ_SI')),'bitfiles');
                        obj.hFpga.bitfilePath = fullfile(bitfileDir, obj.bitfileName);
                    end
                    
                    obj.hFpga.run();
                else
                    obj.hFpga.initializeDesign();
                end
            end
            
            hFpga = obj.hFpga;
        end
        
        function deinitFPGA(obj)
            if most.idioms.isValidObj(obj.hFpga)
                obj.hFpga.delete();
            end
            
            obj.hFpga = [];
        end
        
        function reset(obj)
            if most.idioms.isValidObj(obj.hFpga)
                most.idioms.warn('GJ: Need to implement vDAQ reset');
            end
        end
    end
    
    %% Static methods
    methods (Static)
        function r = scanSystem()            
            hResourceStore = dabs.resources.ResourceStore();
            
            nVdaq = double( dabs.vidrio.rdi.Device.getDriverInfo.numDevices );
            
            for vDAQNumber = 0:(nVdaq-1)
                name = sprintf('vDAQ%d',vDAQNumber);
                if isempty(hResourceStore.filterByName(name))
                    s = dabs.vidrio.rdi.Device.getDeviceInfo(vDAQNumber);
                    
                    try
                        if s.hardwareRevision
                            dabs.resources.daqs.vDAQR1(name);
                        else
                            dabs.resources.daqs.vDAQR0(name);
                        end
                    catch ME
                        most.ErrorHandler.logAndReportError(ME,'Failed to instantiate vDAQ ''%s''',name);
                    end
                end
            end
            
            r = hResourceStore.filterByClass(mfilename('class'));
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
