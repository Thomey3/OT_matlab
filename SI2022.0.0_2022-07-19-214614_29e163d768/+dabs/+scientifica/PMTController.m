classdef PMTController < dabs.resources.Device & dabs.resources.configuration.HasConfigPage & most.HasMachineDataFile
    properties (SetAccess=protected,Hidden)
        ConfigPageClass = 'dabs.resources.configuration.resourcePages.ScientificaPmtControllerPage';
    end
    
    methods (Static)
        function names = getDescriptiveNames()
            names = {'Scientifica\Scientifica PMT Controller' 'PMT\Scientifica PMT Controller'};
        end
    end
    %%% Abstract property realizations (most.HasMachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'Scientifica PMT Controller';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp; %#ok<MCCPI>
        mdfPropPrefix; %#ok<MCCPI>
        
        mdfDefault = defaultMdfSection();
    end
    
 %% User Props    
    %% CLASS-SPECIFIC PROPERTIES
    properties (Constant,Hidden)
        SERIAL_BAUD_RATE   = 9600;
        SERIAL_TERMINATOR  = 'CR';
        SERIAL_TIMEOUT     = 0.5;
    end
    
    %%% ABSTRACT PROPERTY REALIZATIONS (scaniamge.interfaces.PmtController)
    properties (Constant, Hidden)
        numPmts = 2;                    % [numerical] number of PMTs managed by the PMT controller -- THis needs to be 2
    end
    
    properties (SetObservable)
        hCOM = dabs.resources.Resource.empty();
    end
    
    properties (SetObservable, Dependent)
        autoOn
        wavelength_nm
    end

    %% Internal Properties
    properties (SetAccess = private, Hidden)
        hSerial = [];
        hPMTs = dabs.scientifica.pmtcontroller.PMT.empty();
        TimeoutTimer = [];
        
        replyPending = false;
        commandQueue = {};
        asyncCallback;
        lastCmd = '';
        
        model = '';
        manufacturer = '';
        serialNumber = '';
        firmware = '';
        UID = '';
        desc = '';
        mode = [];
    end
    
    %% Lifecycle
    methods
        function obj = PMTController(name)
            obj@dabs.resources.Device(name);
            obj@most.HasMachineDataFile(true);
            
            for pmtNum = 1:obj.numPmts
                obj.hPMTs(pmtNum) = dabs.scientifica.pmtcontroller.PMT(obj,pmtNum);
            end
            
            obj.deinit();
            obj.loadMdf();
            obj.reinit();
        end
        
        function delete(obj)
            obj.deinit();
            obj.saveCalibration();     
            
            most.idioms.safeDeleteObj(obj.hPMTs);
            obj.hPMTs = dabs.scientifica.pmtcontroller.PMT.empty();
        end
    end
    
    methods
        function loadMdf(obj)
            success = true;
            success = success & obj.safeSetPropFromMdf('hCOM', 'comPort');
            
            success = success & obj.loadCalibration();
            
            if ~success
                obj.errorMsg = 'Error loading config';
            end
        end
        
        function success = loadCalibration(obj)
            success = true;
            success = success & obj.safeSetPropFromMdf('autoOn', 'autoOn');
            success = success & obj.safeSetPropFromMdf('wavelength_nm', 'wavelength_nm');
        end
        
        function saveMdf(obj)
            obj.safeWriteVarToHeading('comPort', obj.hCOM);
            obj.saveCalibration();
        end
        
        function saveCalibration(obj)
            obj.safeWriteVarToHeading('autoOn', obj.autoOn);
            obj.safeWriteVarToHeading('wavelength_nm', obj.wavelength_nm);
        end
    end
    
    methods
        function deinit(obj)
            obj.errorMsg = 'Uninitialized';
            
            for pmtNum = 1:numel(obj.hPMTs)
                hPMT = obj.hPMTs(pmtNum);
                if most.idioms.isValidObj(hPMT)
                    hPMT.deinit();
                end
            end
            
            most.idioms.safeDeleteObj(obj.TimeoutTimer);
            obj.TimeoutTimer = [];
            
            if most.idioms.isValidObj(obj.hSerial)
                fclose(obj.hSerial);
            end
            most.idioms.safeDeleteObj(obj.hSerial);
            obj.hSerial = [];
            
            obj.hCOM.unreserve(obj);
        end
        
        function reinit(obj)
            obj.deinit();
            
            try
                assert(most.idioms.isValidObj(obj.hCOM),'No serial port is specified');                
                obj.hCOM.reserve(obj);
                
                obj.hSerial = serial(obj.hCOM.name, 'BaudRate',obj.SERIAL_BAUD_RATE, 'Terminator', obj.SERIAL_TERMINATOR);
                obj.hSerial.BytesAvailableFcnMode = 'terminator';
                obj.hSerial.BytesAvailableFcn = @obj.replyAvailable;
                fopen(obj.hSerial);
                obj.TimeoutTimer = timer('Name','Scientifica MDU: Async Cmd Timout Timer');
                obj.TimeoutTimer.ExecutionMode = 'singleShot';
                obj.TimeoutTimer.StartDelay = obj.SERIAL_TIMEOUT;
                obj.TimeoutTimer.TimerFcn = @obj.TimeoutFcn;
                
                try
                    fprintf(obj.hSerial, 'SCIENTIFICA');
                    response = fgetl(obj.hSerial);
                catch
                    response = [];
                end
                
                if ~isempty(response) && strcmp(response, 'Y519')
                    fprintf(1,'Done!\n');
                    obj.model = response;
                    obj.manufacturer = 'SCIENTIFICA';
                elseif ~isempty(response) && strcmp(response, 'E,1')
                    fprintf(1,'\nIntitialization Error! Handshake Failed. Device may or may not have initialized properly.\n');
                else
                    error('\nInitialization Failed! This not a Scientifica PMT Controller or it is not powered on.');
                end
                
                try
                    fprintf(obj.hSerial, 'SERIAL');
                    obj.serialNumber = fgetl(obj.hSerial);
                catch
                    obj.serialNumber = [];
                    warning('Failed to get MDU Serial #. Device connection suspect!');
                end
                
                try
                    fprintf(obj.hSerial, 'VER');
                    obj.firmware = fgetl(obj.hSerial);
                catch
                    obj.firmware = [];
                    warning('Failed to get MDU Firmware Ver. Device connection suspect!');
                end
                
                try
                    fprintf(obj.hSerial, 'UID');
                    obj.UID = fgetl(obj.hSerial);
                catch
                    obj.UID = [];
                    warning('Failed to get MDU UID. Device connection suspect!');
                end
                
                try
                    fprintf(obj.hSerial, 'DESC');
                    obj.desc = fgetl(obj.hSerial);
                catch
                    obj.desc = [];
                    warning('Failed to get MDU Description. Device connection suspect!');
                end
                
                obj.errorMsg = ''; % this needs to happen before setMode because writeCommand checks for errors
                
                try
                    obj.setMode(3);
                catch
                    warning('Failed to set MDU Gain Control Mode. Device connection suspect!');
                end
                
                for pmtNum = 1:numel(obj.hPMTs)
                    obj.hPMTs(pmtNum).reinit();
                end
                
            catch ME
                obj.deinit();
                obj.errorMsg = sprintf('%s: initialization error: %s',obj.name,ME.message);
                most.ErrorHandler.logError(ME,obj.errorMsg);
            end
        end
    end
    %% USER METHODS
    methods
        function queryStatus(obj)
            % enable
            obj.writeCommand('ENABLE',@obj.processPMTUpdate);
            
            % gain
            obj.writeCommand('A',@obj.processPMTUpdate);
            obj.writeCommand('B',@obj.processPMTUpdate);

            % current tripped
            obj.writeCommand('V',@obj.processPMTUpdate);
            
            % Mode
            obj.writeCommand('SOURCE', @obj.processPMTUpdate);
        end
    end
    
    %% Internal methods
    methods (Hidden)
        function setMode(obj, mode)
            assert(isnumeric(mode) && mode < 4 && mode >= 0, '\nSource must be 0, 1, 2, or 3. Please refer to documentation for further details.\n');
            cmd = sprintf('SOURCE %d',mode);
            obj.writeCommand(cmd, []);
        end
        
        function TimeoutFcn(obj, ~,~)
            if obj.hSerial.BytesAvailable
                obj.replyAvailable();
            else
                stop(obj.TimeoutTimer);
%                 most.idioms.warn(['Timeout occurred while waiting for reply to ''' obj.lastCmd ''' cmd from Scientifica MDU']);
                obj.replyPending = false;
                obj.lastCmd = '';
                pause(obj.SERIAL_TIMEOUT);
                flushinput(obj.hSerial);
                
                % send next command in commandQueue
                obj.sendNextCmd();
            end
        end
        
        function writeCommand(obj, cmd, callback)
            obj.assertNoError();
            assert(isa(cmd,'char'));
           
            obj.commandQueue{end + 1} = {cmd, callback};
            obj.sendNextCmd();
        end
        
        function sendNextCmd(obj)
            if ~obj.replyPending
                % send next command in commandQueue
                if ~isempty(obj.commandQueue)
                    nextCommand = obj.commandQueue{1};
                    obj.commandQueue(1) = [];
                    
                    obj.lastCmd = nextCommand{1};
                    obj.asyncCallback = nextCommand{2};
                    
                    flushinput(obj.hSerial);
                    fprintf(obj.hSerial, obj.lastCmd);
                    stop(obj.TimeoutTimer);
                    start(obj.TimeoutTimer);
                    if strcmp(obj.lastCmd, 'RESTART')
                        obj.replyPending = false;
                        pause(5.5);
%                         fprintf(1, '...Done\n');
                    else
                        obj.replyPending = true;
                    end
                end
            end
        end
        
        function replyAvailable(obj,~,~)
            try
                if strcmp(obj.lastCmd, 'RESTART')
                    obj.replyPending = false;
                    obj.commandQueue = {};
                    flushinput(obj.hSerial);
                end
                
                if obj.replyPending
                    stop(obj.TimeoutTimer);
                    reply = fgetl(obj.hSerial);
                    obj.replyPending = false;

                    % process answer
                    if ~isempty(obj.asyncCallback)
                        obj.asyncCallback(reply);
                        obj.asyncCallback = [];
                    end
                    obj.lastCmd = '';
                    obj.replyPending = false;
                end
                
                obj.sendNextCmd();
            catch ME
                ME.stack(1)
                fprintf(2,'Error while processing response from PMT: %s\n', ME.message);
            end
        end
        
        function processPMTUpdate(obj,reply)
            switch(obj.lastCmd)
                case 'ENABLE'
                    for idx = 1:numel(obj.hPMTs)
                        obj.hPMTs(idx).setProp('powerOn',str2double(reply));
                    end
                    
                case 'A'
                    obj.hPMTs(1).setProp('gain_V',str2double(reply));
                    
                case 'B'
                    obj.hPMTs(2).setProp('gain_V',str2double(reply));
                    
                case 'V'
                    volatile = str2double(reply(end));
                    volatile = dec2bin(volatile, 9);
                    v = [str2double(volatile(4)) str2double(volatile(3))];
                    
                    for idx = 1:numel(obj.hPMTs)
                        obj.hPMTs(idx).setProp('tripped',v(idx));
                    end
                    
                case 'SOURCE'
                    obj.mode = str2double(reply);
            end
        end
    end
    
    methods
        function set.hCOM(obj,val)
            if isnumeric(val) && ~isempty(val)
                val = sprintf('COM%d',val);
            end
            
            val = obj.hResourceStore.filterByName(val);
            
            if ~isequal(val,obj.hCOM)
                if most.idioms.isValidObj(val)
                    validateattributes(val,{'dabs.resources.SerialPort'},{'scalar'});
                end
                
                obj.deinit();
                obj.hCOM.unregisterUser(obj);
                obj.hCOM = val;
                val.registerUser(obj,'COM Port');
            end
        end
        
        function set.autoOn(obj,val)
            validateattributes(val,{'logical','numeric'},{'numel',2,'binary'});
            
            for idx = 1:numel(obj.hPMTs)
                obj.hPMTs(idx).autoOn = logical(val(idx));
            end
        end
        
        function val = get.autoOn(obj)
            val = false(1,numel(obj.hPMTs));
            for idx = 1:numel(obj.hPMTs)
                val(idx) = obj.hPMTs(idx).autoOn;
            end
        end
        
        function set.wavelength_nm(obj,val)
            validateattributes(val,{'numeric'},{'numel',2,'positive','nonnan','finite','real'});
            
            for idx = 1:numel(obj.hPMTs)
                obj.hPMTs(idx).wavelength_nm = val(idx);
            end
        end
        
        function val = get.wavelength_nm(obj)
            val = zeros(1,numel(obj.hPMTs));
            for idx = 1:numel(obj.hPMTs)
                val(idx) = obj.hPMTs(idx).wavelength_nm;
            end
        end
    end
end

function s = defaultMdfSection()
    s = [...
            most.HasMachineDataFile.makeEntry('comPort','','Serial port the stage is connected to (e.g. ''COM3'')')...
            most.HasMachineDataFile.makeEntry('autoOn',[false false],'Determines for each PMT if it should automatically be switched on during an acquisition.')...
            most.HasMachineDataFile.makeEntry('wavelength_nm',[509 509],'Wavelength for each PMT in nanometer')...
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
