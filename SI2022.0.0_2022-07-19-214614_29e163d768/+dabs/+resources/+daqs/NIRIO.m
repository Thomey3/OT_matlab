classdef NIRIO < dabs.resources.DAQ & dabs.resources.daqs.FPGA
    properties (SetAccess = private)
        serial = '';
        productName = '';
        pxiNumber = NaN;
        hAdapterModule = dabs.resources.daqs.NIFlexRIOAdapterModule.empty();
    end
    
    properties (SetAccess = private)
        hFpga = dabs.ni.rio.NiFPGA.empty();
        bitFilePath = '';
    end
    
    properties (SetAccess = protected, Dependent)
        hDevice
    end
        
    methods
        function obj = NIRIO(name)
            obj@dabs.resources.DAQ(name);
            
            rioInfo = dabs.ni.configuration.findFlexRios();
            
            if isfield(rioInfo,name)
                rioInfo = rioInfo.(name);
            else
                % simulate NI7961+NI5734
                obj.simulated = true;
                rioInfo.productName = 'NI PXIe-7961R';
                rioInfo.pxiNumber = 1;
                rioInfo.serial = '00000000';
                rioInfo.adapterModule = 'NI 5734';
                rioInfo.adapterModuleSerial = '';
            end
            
            if isfield(rioInfo,'productName')
                obj.productName = rioInfo.productName;
            end
            
            if isfield(rioInfo,'pxiNumber')
                obj.pxiNumber = rioInfo.pxiNumber;
            end
            
            if isfield(rioInfo,'serial')
                obj.serial = rioInfo.serial;
            end
            
            if isfield(rioInfo,'adapterModule')
                obj.hAdapterModule = dabs.resources.daqs.NIFlexRIOAdapterModule(obj,rioInfo.adapterModule,rioInfo.adapterModuleSerial);
            elseif ~isempty(regexpi(obj.productName,'517[0-9]','match','once'))
                obj.hAdapterModule = dabs.resources.daqs.NIFlexRIOAdapterModule(obj,'NI517x',obj.serial);
            end
        end
    end
    
    methods
        function hFpga = initFPGA(obj,bitFilePath)
            if nargin < 2 || isempty(bitFilePath)
                hFpga = obj.initSIFPGA();
                return
            end
            
            assert(logical(exist(bitFilePath,'file')),'File not found on disk: ''%s''',bitFilePath);
            
            if strcmp(obj.bitFilePath,bitFilePath)
                return % already initialized
            end
            
            obj.deinitFPGA();
            
            try
                obj.bitFilePath = bitFilePath;
                obj.hFpga = dabs.ni.rio.NiFPGA(bitFilePath,obj.simulated);
                
                if ~obj.simulated
                    obj.openSession(obj.name);
                end
            catch ME
                obj.deinitFPGA();
                hFpga = obj.hFpga;
                rethrow(ME);
            end
            
            hFpga = obj.hFpga;
        end
        
        function hFpga = initSIFPGA(obj)
            obj.deinitFPGA();
            
            fpgaType = regexpi(obj.productName,'[0-9]{4,4}','match','once');
            fpgaType = ['NI' fpgaType];
            
            pathToBitfile = [fileparts(which('scanimage')) '\+scanimage\FPGA\FPGA Bitfiles\Microscopy'];
            
            if ~isempty(fpgaType)
                pathToBitfile = [pathToBitfile ' ' fpgaType];
            end
            
            if most.idioms.isValidObj(obj.hAdapterModule)
                digitizerType = obj.hAdapterModule.productType;
                pathToBitfile = [pathToBitfile ' ' digitizerType];
            else
                digitizerType = '';
            end
            
            pathToBitfile = [pathToBitfile '.lvbitx'];
            assert(logical(exist(pathToBitfile, 'file')), 'The FPGA and digitizer combination specified in the machine data file is not currently supported.');
            
            if strncmp(fpgaType, 'NI517', 5)
                dabs.ni.oscope.clearSession;
                err = dabs.ni.oscope.startSession(obj.name,pathToBitfile);
                assert(err == 0, 'Error when attempting to connect to NI 517x device. Code = %d', err);
                dabs.ni.oscope.configureSampleClock(false,0);
                digitizerType = 'NI517x';
            end
            
            obj.hFpga = scanimage.fpga.flexRio_SI(pathToBitfile,obj.simulated,digitizerType);
            
            if ~obj.simulated
                try
                    obj.hFpga.openSession(obj.name);
                    %Hard-Reset FPGA. This brings the FPGA in a known state after an aborted acquisition
                    obj.hFpga.FpgaResetFcn();
                catch ME
                    obj.deinitFPGA();
                    most.ErrorHandler.error('Scanimage:Acquisition',['Failed to start FPGA. Ensure the FPGA and digitizer module settings in the machine data file match the hardware.\n' ME.message]);
                end
            end
            
            hFpga = obj.hFpga;
        end
        
        function deinitFPGA(obj)
            most.idioms.safeDeleteObj(obj.hFpga);
            obj.hFpga = dabs.ni.rio.NiFPGA.empty();
            obj.bitFilePath = '';            
        end
        
        function setFpga(obj,val)
            assert(isempty(obj.hFpga),'Cannot override if FPGA is already initialized');
            assert(isa(val,'dabs.ni.rio.NiFPGA'));
            
            if ~obj.simulated
                assert(strcmp(val.rioDeviceID,obj.name));
            end
            
            obj.hFpga = val;
        end
        
        function reset(obj)
            if most.idioms.isValidObj(obj.hFpga) && obj.hFpga.session
                obj.hFpga.reset();
            end
        end
    end
    
    methods
        function val = get.hDevice(obj)
            val = obj.hFpga;
        end
    end
    
    methods (Static)
        function r = scanSystem()
            r = {};
            
            try
                rioInfo = dabs.ni.configuration.findFlexRios();
            catch ME
                return % flexRIO driver is not installed
            end
            
            hResourceStore = dabs.resources.ResourceStore();
            rioNames = fieldnames(rioInfo);            
            for idx = 1:numel(rioNames)
                rioName = rioNames{idx};
                if isempty(hResourceStore.filterByName(rioName))
                    try
                        dabs.resources.daqs.NIRIO(rioName);
                    catch ME
                        most.ErrorHandler.logAndReportError(ME,'Failed to instantiate RIO device ''%s''',rioName);
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
