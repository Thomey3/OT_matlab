classdef MOM < dabs.resources.MicroscopeSystem    
    properties (Constant)
        manufacturer = 'Sutter Instrument';
        detailedName = '<html><center><b> Sutter MOM System</b> <br /> Shutter, pockels cell, piezo, MP-285 stage </center></html>';
    end
    
    methods (Static)
        function names = getDescriptiveNames()
            names = {'Complete Microscopes\Sutter MOM, shutter, pockels cell, and piezo, MP285'};
        end
    end
    
    %% LIFECYCLE
    methods
        function obj = MOM(varargin)
            % No-op
        end
    end
    
    methods
        function reinit(obj)
            hS = makeShutter();
            hR = makeResonantScanner();
            hGy = makeGalvoY();
            hP = makePockels();
            hZ = makePiezo();
            makeRggScanner(hR, [], hGy, hS, hP, hZ);
            
            hStage = dabs.sutter.MP285_Async('XYZ Stage');
            
            if most.idioms.isValidObj(obj.hMotors)
                for mtr = 1:3
                    obj.hMotors.hMotorXYZ{mtr} = hStage;
                    obj.hMotors.motorAxisXYZ(mtr) = mtr;
                end
                
                obj.hMotors.saveMdf();
            end
            
            %%% Nested functions
            function hShutter = makeShutter()
                try
                    shutterName = 'Imaging Shutter';
                    hShutter = [];
                    if isempty(obj.hResourceStore.filterByName(shutterName))
                        hShutter = dabs.generic.DigitalShutter(shutterName);
                        if hShutter.mdfHeadingCreated
                            % set defaults
                            if obj.vdaqPresent
                                hShutter.hDOControl = obj.hVdaq.hDOs(2);
                            end
                            
                            hShutter.saveMdf();
                            hShutter.reinit();
                        end
                    end
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
            end
            
            function hResonantScanner = makeResonantScanner()
                try
                    resonantScannerName = 'Res Scanner';
                    hResonantScanner = [];
                    if isempty(obj.hResourceStore.filterByName(resonantScannerName))
                        hResonantScanner = dabs.generic.ResonantScannerAnalog(resonantScannerName);
                        if hResonantScanner.mdfHeadingCreated
                            % set defaults
                            hResonantScanner.settleTime_s = 0.5;
                            hResonantScanner.nominalFrequency_Hz = 7910;
                            hResonantScanner.angularRange_deg = 26;
                            hResonantScanner.voltsPerOpticalDegrees = 5/26;
                            
                            if obj.vdaqPresent
                                hResonantScanner.hAOZoom = obj.hVdaq.hAOs(5);
                                hResonantScanner.hDISync = obj.hVdaq.hDIs(1);
                                hResonantScanner.hDOEnable = obj.hVdaq.hDOs(1);
                            end
                            
                            hResonantScanner.saveMdf();
                            hResonantScanner.reinit();
                        end
                    end
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
            end
            
            function hGalvoY = makeGalvoY()
                try
                    galvoYName = 'Y Galvo';
                    hGalvoY = [];
                    if isempty(obj.hResourceStore.filterByName(galvoYName))
                        hGalvoY = dabs.generic.GalvoPureAnalog(galvoYName);
                        if hGalvoY.mdfHeadingCreated
                            % set defaults
                            hGalvoY.voltsPerDistance = 1;
                            hGalvoY.travelRange = [-10 10];
                            hGalvoY.parkPosition = -9;
                            hGalvoY.slewRateLimit_V_per_s = Inf;
                            
                            if obj.vdaqPresent
                                hGalvoY.hAOControl = obj.hVdaq.hAOs(2);
                                hGalvoY.hAIFeedback = obj.hVdaq.hAIs(2);
                            end
                            
                            hGalvoY.saveMdf();
                            hGalvoY.reinit();
                        end
                    end
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
            end
            
            function hPockels = makePockels()
                try
                    pockelsName = 'Imaging Beam';
                    hPockels = [];
                    if isempty(obj.hResourceStore.filterByName(pockelsName))
                        hPockels = dabs.generic.BeamModulatorFastAnalog(pockelsName);
                        if hPockels.mdfHeadingCreated
                            % set defaults
                            if obj.vdaqPresent
                                hPockels.hAOControl = obj.hVdaq.hAOs(3);
                                hPockels.hAIFeedback = obj.hVdaq.hAIs(3);
                            end
                            
                            hPockels.saveMdf();
                            hPockels.reinit();
                        end
                    end
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
            end
            
            function hPiezo = makePiezo()
                try
                    piezoName = 'Imaging Piezo';
                    hPiezo = [];
                    if isempty(obj.hResourceStore.filterByName(piezoName))
                        hPiezo = dabs.generic.FastZPureAnalog(piezoName);
                        if hPiezo.mdfHeadingCreated
                            % set defaults
                            if obj.vdaqPresent
                                hPiezo.hAOControl = obj.hVdaq.hAOs(4);
                                hPiezo.hAIFeedback = obj.hVdaq.hAIs(4);
                            end
                            
                            hPiezo.saveMdf();
                            hPiezo.reinit();
                        end
                    end
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
            end
            
            function makeRggScanner(hR, hGx, hGy, hS, hP, hZ)
                try
                    scannerName = 'ImagingScanner';
                    if obj.createScanner && isempty(obj.hResourceStore.filterByName(scannerName))
                        if obj.useFlexRio
                            hScan = scanimage.components.scan2d.ResScan(scannerName);
                        else
                            hScan = scanimage.components.scan2d.RggScan(scannerName);
                        end
                        if hScan.mdfHeadingCreated
                            % set defaults
                            hScan.hResonantScanner = hR;
                            hScan.xGalvo = hGx;
                            hScan.yGalvo = hGy;
                            hScan.hBeams = {hP};
                            hScan.hFastZs = {hZ};
                            hScan.hShutters = {hS};
                            
                            if obj.useFlexRio
                                hScan.hDAQAcq = obj.hNIRIO;
                            elseif obj.vdaqPresent
                                hScan.hDAQ = obj.hVdaq;
                            end
                            
                            hScan.saveMdf();
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
