classdef vDAQ_Config < dabs.resources.Device & dabs.resources.DAQ & most.HasMachineDataFile & dabs.resources.configuration.HasConfigPage
    
    %% ABSTRACT PROPERTY REALIZATIONS (most.HasMachineDataFile) 
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'vDAQ Configuration'; 
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
        
        mdfDefault = defaultMdfSection();
    end
    
    properties (SetAccess = protected,Hidden)
        ConfigPageClass = 'dabs.resources.configuration.resourcePages.vDAQ_Config';
    end
    
    methods (Static)
        function names = getDescriptiveNames()
            names = {'Vidrio\vDAQ Advanced Parameters'};
        end
    end
    
    properties (SetObservable)
        vdaqNumber;
        passiveMode;
        bitfileName;
        serialNumber;
        
        hVdaq;
    end
    
    properties (Dependent)
        availableBitfiles
    end
    
    properties (SetAccess = protected)
        hDevice;
    end
    
    methods
        function obj = vDAQ_Config(name)
            obj@dabs.resources.Device(name);
            obj@dabs.resources.DAQ(name);
            obj = obj@most.HasMachineDataFile(true);
            
            obj.loadMdf();
            obj.reinit();
        end
    end
    
    methods
        function reinit(obj)
            try
                if isempty(obj.vdaqNumber) || (obj.vdaqNumber > (dabs.vidrio.rdi.Device.getDriverInfo().numDevices - 1))
                    obj.errorMsg = 'No vDAQ to configure';
                    return
                end

                bitfilePath = fullfile(scanimage.util.siRootDir(),'+scanimage\+fpga\bitfiles',obj.bitfileName);
                assert(exist(bitfilePath,'file')==2,'Selected bitfile ''%s'' does not exist',obj.bitfileName);
                
                hFpga = scanimage.fpga.vDAQ_SI(obj.vdaqNumber);
                nfo = hFpga.deviceInfo;
                if ~nfo.designLoaded
                    hFpga.loadInitialDesign();
                end
                devSn = hFpga.deviceSerialNumber;
                delete(hFpga);
                
                if ~isempty(obj.serialNumber) && ~strcmp(obj.serialNumber, devSn)
                    % warn user that serial number has changed. this could
                    % happen if PCIe slots were changed
                    warndlg(sprintf('vDAQ%d has changed from SN:%s to SN:%s. Verify wiring configuration is correct.', obj.vdaqNumber, obj.serialNumber, devSn), 'vDAQ Configuration');
                end
                
                obj.serialNumber = devSn;
                
                obj.hVdaq = obj.hResourceStore.filterByName(sprintf('vDAQ%d',obj.vdaqNumber));
                if ~isempty(obj.hVdaq)
                    obj.hVdaq.passiveMode = obj.passiveMode;
                    obj.hVdaq.bitfileName = obj.bitfileName;
                end
                obj.errorMsg = '';
            catch ME
                obj.errorMsg = sprintf('%s: initialization error: %s',obj.name,ME.message);
                most.ErrorHandler.logAndReportError(ME,obj.errorMsg);
            end
        end
        
        function loadMdf(obj)
            success = true;
            success = success & obj.safeSetPropFromMdf('vdaqNumber', 'vdaqNumber');
            success = success & obj.safeSetPropFromMdf('passiveMode', 'passiveMode');
            success = success & obj.safeSetPropFromMdf('bitfileName', 'bitfileName');
            success = success & obj.safeSetPropFromMdf('serialNumber', 'serialNumber');
            
            if ~success
                obj.errorMsg = 'Error loading config';
            end
        end
        
        function saveMdf(obj)
            obj.safeWriteVarToHeading('vdaqNumber', obj.vdaqNumber);
            obj.safeWriteVarToHeading('passiveMode', obj.passiveMode);
            obj.safeWriteVarToHeading('bitfileName', obj.bitfileName);
            obj.safeWriteVarToHeading('serialNumber', obj.serialNumber);
        end
        
        function reset(~)
        end
    end
    
    methods
        function set.vdaqNumber(obj,val)
            if isempty(val)
                val = [];
            else
                num_vDAQs_found = dabs.vidrio.rdi.Device.getDriverInfo().numDevices;
                validateattributes(val,{'numeric'},{'integer','scalar','nonnegative','<',num_vDAQs_found});
            end
            
            obj.vdaqNumber = val;
        end
        
        function val = get.availableBitfiles(obj)
            bitfileDir = dir(fullfile(fileparts(which('scanimage.fpga.vDAQ_SI')),'bitfiles'));
            f = {bitfileDir.name};
            rem = cellfun(@(s)(s(1)=='.')||strncmp(s,'vDAQR0_',6)||strncmp(fliplr(s),fliplr('_Firmware.dbs'),13),f);
            val = f(~rem);
        end
    end
end


function s = defaultMdfSection()
s = [...    
    most.HasMachineDataFile.makeEntry('vdaqNumber'  , []     , 'ID number of vDAQ board this configuration should apply to')...
    most.HasMachineDataFile.makeEntry('serialNumber', ''    , 'Serial number of vDAQ board')...
    most.HasMachineDataFile.makeEntry('bitfileName' , ''    , 'Custom bitfile to load')...
    most.HasMachineDataFile.makeEntry('passiveMode' , false , 'Prevent re-initializing of vDAQ if there is already a loaded design')...
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
