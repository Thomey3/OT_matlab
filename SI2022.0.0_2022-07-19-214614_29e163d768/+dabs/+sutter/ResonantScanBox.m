classdef ResonantScanBox < dabs.resources.Device & dabs.resources.configuration.HasConfigPage
    properties (SetAccess=protected,Hidden)
        ConfigPageClass = 'dabs.resources.configuration.resourcePages.BlankPage';
    end
    
    methods (Static)
        function names = getDescriptiveNames()
            names = {'Scanner\Sutter Resonant Scan Box' 'Sutter Instrument\Sutter Resonant Scan Box'};
        end
    end
    
    %% LIFECYCLE
    methods
        function obj = ResonantScanBox(name)
            obj@dabs.resources.Device(name);
            obj.reinit();
            obj.delete();
        end
    end
    
    methods
        function reinit(obj)
            makeResonantScanner()
            makeGalvoY();
            
            %%% Nested functions
            function makeResonantScanner()
                try
                    resonantScannerName = [obj.name ' Resonant Scanner'];
                    if isempty(obj.hResourceStore.filterByName(resonantScannerName))
                        hResonantScanner = dabs.generic.ResonantScannerAnalog(resonantScannerName);
                        if hResonantScanner.mdfHeadingCreated
                            % set defaults
                            hResonantScanner.settleTime_s = 0.5;
                            hResonantScanner.nominalFrequency_Hz = 7910;
                            hResonantScanner.angularRange_deg = 26;
                            hResonantScanner.voltsPerOpticalDegrees = 5/26;
                            hResonantScanner.saveMdf();
                        end
                    end
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
            end
            
            function makeGalvoY()
                try
                    galvoYName = [obj.name ' Y-Galvo'];
                    if isempty(obj.hResourceStore.filterByName(galvoYName))
                        hGalvoY = dabs.generic.GalvoPureAnalog(galvoYName);
                        if hGalvoY.mdfHeadingCreated
                            % set defaults
                            hGalvoY.voltsPerDistance = .5;
                            hGalvoY.travelRange = [-20 20];
                            hGalvoY.parkPosition = -18;
                            hGalvoY.slewRateLimit_V_per_s = Inf;
                            hGalvoY.saveMdf();
                        end
                    end
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
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
