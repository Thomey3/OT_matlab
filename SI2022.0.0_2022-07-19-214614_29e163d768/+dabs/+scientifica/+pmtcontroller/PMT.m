classdef PMT < dabs.resources.devices.PMT

%% FRIEND PROPS
    properties (SetAccess=protected, AbortSet, SetObservable)
        powerOn = false;    % [logical]   scalar containing power status for PMT
        gain_V = 0;         % [numerical] scalar containing gain setting for PMT
        gainOffset_V = 0;   % [numeric]   scalar containing offset for PMT
        bandwidth_Hz = 0;   % [numeric]   scalar containing amplifier bandwidth for PMT
        tripped = false;    % [logical] scalar containing trip status for Pmt
    end
    
    properties (SetAccess = protected, Hidden)
        lastQuery = 0;   % time of last pmt status query (tic)
    end
    
    properties (SetAccess = immutable)
        hPMTController
        pmtNum
        pmtLetter
    end
    
    methods (Access = ?dabs.scientifica.PMTController)
        function obj = PMT(hPMTController,pmtNum)
            pmtLetter = 'AB';
            pmtLetter = pmtLetter(pmtNum);
            
            name = sprintf('%s PMT-%s',hPMTController.name,pmtLetter);
            obj@dabs.resources.devices.PMT(name);
            obj.hPMTController = hPMTController;
            obj.pmtNum = pmtNum;
            obj.pmtLetter = pmtLetter;
            
            obj.deinit();
        end
    end
    
    methods
        function delete(obj)
            obj.deinit();
        end
    end
    
    methods
        function deinit(obj)
            obj.errorMsg = 'uninitialized';
        end
        
        function reinit(obj)
            obj.deinit();
            
            if ~most.idioms.isValidObj(obj.hPMTController)
                return
            end
            
            if isempty(obj.hPMTController.errorMsg)
                obj.errorMsg = '';
            else
                obj.errorMsg = 'PMT Controller is in error state: %s';
            end
        end
    end
    
    methods
        function setPower(obj,tf)
            if tf
                obj.hPMTController.writeCommand('ENABLE 1', []);
            else
                obj.hPMTController.writeCommand('ENABLE 0', []);
            end
            
            if obj.hPMTController.mode ~= 3
                obj.hPMTController.setMode(3);
            end
        end
        
        function setGain(obj,gain_V)
            cmd = sprintf('%s %d',obj.pmtLetter, gain_V);
            obj.hPMTController.writeCommand(cmd, []);
        end
        
        function setGainOffset(obj,offset_V)
            % not supported
        end
        
        function setBandwidth(obj,bandwidth_Hz)
            % not supported
        end
        
        function resetTrip(obj)
            obj.hPMTController.writeCommand('RESTART', []);
        end
    end
    
    
    methods (Hidden)
        function setProp(obj,propName,val)
            obj.(propName) = val;
        end        
    end
     
    methods
        function queryStatus(obj)
            if ~most.idioms.isValidObj(obj.hPMTController)...
              || ~isempty(obj.hPMTController.errorMsg)...
              || ~isempty(obj.errorMsg)
                return
            end
            
            if obj.pmtNum > 1
                return
            end
            
            try
                obj.hPMTController.queryStatus();
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
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
