classdef DualPath_BScopeECU2 < dabs.resources.MicroscopeSystem    
    properties (Constant)
        manufacturer = 'Thorlabs';
        detailedName = '<html><center><b>Dual Scan Path Thorlabs Bergamo (ECU2)</b> <br />Shutter and pockels cell on each path, piezo, MCM3000, PMT2100''s, BCM</center></html>';
    end
    
    methods (Static)
        function names = getDescriptiveNames()
            names = {'Complete Microscopes\Dual path Thorlabs Bergamo (ECU2); shutter and pockels cell on each path; piezo, MCM3000, and PMTs'};
        end
    end
    
    %% LIFECYCLE
    methods
        function obj = DualPath_BScopeECU2(varargin)
            % No-op
        end
    end

    methods
        function reinit(obj)
            hECU = dabs.thorlabs.ECU2('ECU','createPmts',false);
            if obj.vdaqPresent
                hECU.hDAQ_Reso = obj.hVdaq;
                hECU.hDAQ_Galvo = obj.hVdaq;
                hECU.saveMdf();
            end
            
            hS = makeShutter('Imaging Shutter',1);
            hR = hECU.hResonantScanner;
            hGy = hECU.hGalvo;
            hP = makePockels('Imaging Beam',1,1);
            hZ = makePiezo('FastZ Piezo',2,2);
            makeRggScanner(hR, [], hGy, hS, hP, hZ);
            
            hS = makeShutter('Stim Shutter',2);
            hGx = hECU.hGalvoX;
            hGy = hECU.hGalvoY;
            hP = makePockels('Stim Beam',3,3);
            hSScan = makeStimScanner(hGx, hGy, hS, hP, hZ);
            
            hStage = dabs.thorlabs.MCM3000_Async('XYZ Stage');
            
            if most.idioms.isValidObj(obj.hMotors)
                for mtr = 1:3
                    obj.hMotors.hMotorXYZ{mtr} = hStage;
                    obj.hMotors.motorAxisXYZ(mtr) = mtr;
                end
                
                obj.hMotors.saveMdf();
            end
            
            dabs.thorlabs.PMT('PMT A');
            dabs.thorlabs.PMT('PMT B');
            
            dabs.thorlabs.BCM('GR');
            dabs.thorlabs.BCM('GG');
            dabs.thorlabs.BCM('Flipper');
            
            if most.idioms.isValidObj(obj.hPhotostim)
                obj.hPhotostim.hScan = hSScan;
                obj.hPhotostim.saveMdf();
            end
            
            %%% Nested functions
            function [h, tfFound] = getResource()
            end
            
            function h = createResource(newName,type,varargin)
                tfCreate = isempty(obj.hResourceStore.filterByName(newName));
                h = [];
                
                if tfCreate
                    h = feval(type,newName);
                    
                    nd = numel(varargin)-1;
                    for i = 1:2:nd
                        if ~isempty(varargin{i+1})
                            h.(varargin{i}) = varargin{i+1};
                        end
                    end
                    h.saveMdf();
                    h.reinit();
                end
            end
            
            function hShutter = makeShutter(shutterName,doInd)
                try
                    if obj.vdaqPresent
                        do = obj.hVdaq.hDOs(doInd);
                    else
                        do = [];
                    end
                    hShutter = createResource(shutterName,'dabs.generic.DigitalShutter','hDOControl',do);
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
            end
            
            function hResonantScanner = makeResonantScanner(resName,aoInd)
                try
                    if obj.vdaqPresent
                        ao = obj.hVdaq.hAOs(aoInd);
                        di = obj.hVdaq.hDIs(1);
                        do = obj.hVdaq.hDOs(1);
                    else
                        ao = [];
                        di = [];
                        do = [];
                    end
                    hResonantScanner = createResource(resName,'dabs.generic.ResonantScannerAnalog','settleTime_s',0.5,...
                        'nominalFrequency_Hz',7910,'angularRange_deg',26,'voltsPerOpticalDegrees',5/26,'hAOZoom',ao,'hDISync',di,'hDOEnable',do);
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
            end
            
            function hGalvo = makeGalvo(galvoName,mult,ao,ai)
                try
                    if obj.vdaqPresent && (ao <= numel(obj.hVdaq.hAOs))
                        ao = obj.hVdaq.hAOs(ao);
                        ai = obj.hVdaq.hAIs(ai);
                    else
                        ao = [];
                        ai = [];
                    end
                    hGalvo = createResource(galvoName,'dabs.generic.GalvoPureAnalog','voltsPerDistance',1/mult,...
                        'travelRange',[-10 10]*mult,'parkPosition',-9*mult,'slewRateLimit_V_per_s',inf,'hAOControl',ao,'hAIFeedback',ai);
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
            end
            
            function hPockels = makePockels(pockelsName,ao,ai)
                try
                    hPockels = [];
                    if isempty(obj.hResourceStore.filterByName(pockelsName))
                        hPockels = dabs.generic.BeamModulatorFastAnalog(pockelsName);
                        if hPockels.mdfHeadingCreated
                            % set defaults
                            if obj.vdaqPresent && (ao <= numel(obj.hVdaq.hAOs))
                                hPockels.hAOControl = obj.hVdaq.hAOs(ao);
                                hPockels.hAIFeedback = obj.hVdaq.hAIs(ai);
                            end
                            
                            hPockels.saveMdf();
                            hPockels.reinit();
                        end
                    end
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
            end
            
            function hPiezo = makePiezo(piezoName,ao,ai)
                try
                    hPiezo = [];
                    if isempty(obj.hResourceStore.filterByName(piezoName))
                        hPiezo = dabs.thorlabs.PFM450(piezoName);
                        if hPiezo.mdfHeadingCreated
                            % set defaults
                            if obj.vdaqPresent && (ao <= numel(obj.hVdaq.hAOs))
                                hPiezo.hAOControl = obj.hVdaq.hAOs(ao);
                                hPiezo.hAIFeedback = obj.hVdaq.hAIs(ai);
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
                            else
                                if obj.vdaqPresent
                                    hScan.hDAQ = obj.hVdaq;
                                end
                                hScan.defaultFlybackTimePerFrame = 2e-3;
                            end
                            
                            hScan.saveMdf();
                        end
                    end
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
            end
            
            function hScan = makeStimScanner(hGx, hGy, hS, hP, hZ)
                try
                    scannerName = 'StimScanner';
                    if obj.createScanner && isempty(obj.hResourceStore.filterByName(scannerName))
                        if obj.useFlexRio || obj.useNidaq
                            hScan = scanimage.components.scan2d.LinScan(scannerName);
                        else
                            hScan = scanimage.components.scan2d.RggScan(scannerName);
                        end
                        if hScan.mdfHeadingCreated
                            % set defaults
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
