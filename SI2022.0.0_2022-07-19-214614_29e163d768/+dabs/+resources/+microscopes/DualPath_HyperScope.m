classdef DualPath_HyperScope < dabs.resources.MicroscopeSystem    
    properties (Constant)
        manufacturer = 'Scientifica';
        detailedName = '<html><center><b> Dual Scan Path Scientifica Hyperscope</b> <br /> Shutter and pockels cell on each path, piezo, stage, and PMT controller </center></html>';
    end
    
    methods (Static)
        function names = getDescriptiveNames()
            names = {'Complete Microscopes\Dual path Scientifica HyperScope; shutter and pockels cell on each path; fastZ piezo, stage, and PMT'};
        end
    end
    
    %% LIFECYCLE
    methods
        function obj = DualPath_HyperScope(varargin)
            % No-op
        end

        function reinit(obj)
            hS = makeShutter('Imaging Shutter',2);
            hR = makeResonantScanner();
            hGx = makeGalvo('Imaging X Galvo',1,1,1);
            hGy = makeGalvo('Imaging Y Galvo',1,2,2);
            hP = makePockels('Imaging Beam',3,3);
            hZ = makePiezo('FastZ Piezo',4,4);
            makeRggScanner(hR, hGx, hGy, hS, hP, hZ);
            
            hS = makeShutter('Stim Shutter',3);
            hGx = makeGalvo('Stim X Galvo',1,6,6);
            hGy = makeGalvo('Stim Y Galvo',1,7,7);
            hP = makePockels('Stim Beam',8,8);
            hSScan = makeStimScanner(hGx, hGy, hS, hP, hZ);
            
            hStage = dabs.scientifica.Motion2('XYZ Stage');
            
            if most.idioms.isValidObj(obj.hMotors)
                for mtr = 1:3
                    obj.hMotors.hMotorXYZ{mtr} = hStage;
                    obj.hMotors.motorAxisXYZ(mtr) = mtr;
                end
                
                obj.hMotors.saveMdf();
            end
            
            dabs.scientifica.PMTController('PMT Controller');
            
            if most.idioms.isValidObj(obj.hPhotostim)
                obj.hPhotostim.hScan = hSScan;
                obj.hPhotostim.saveMdf();
            end
            
            %%% Nested functions
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
            
            function hResonantScanner = makeResonantScanner()
                try
                    if obj.vdaqPresent
                        ao = obj.hVdaq.hAOs(5);
                        di = obj.hVdaq.hDIs(1);
                        do = obj.hVdaq.hDOs(1);
                    else
                        ao = [];
                        di = [];
                        do = [];
                    end
                    hResonantScanner = createResource('Imaging Res Scanner','dabs.generic.ResonantScannerAnalog','settleTime_s',0.5,...
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
                        hPiezo = dabs.generic.FastZPureAnalog(piezoName);
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
