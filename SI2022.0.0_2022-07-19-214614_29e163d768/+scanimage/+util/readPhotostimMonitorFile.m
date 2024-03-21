function out = readPhotostimMonitorFile(filename)
    %% get photostim geometry
    hFile = fopen(filename,'r');
    phtstimdata = fread(hFile,'single');
    fclose(hFile);

    % sanity check for file size
    % each data record consists of three entries of type single: x,y,beam power
    datarecordsize = 3;
    lgth = length(phtstimdata);
    if mod(lgth,datarecordsize) ~= 0
        most.idioms.warn('Unexpected size of photostim log file');
        lgth = floor(lgth/datarecordsize) * datarecordsize;
        phtstimdata = phtstimdata(1:lgth);
    end
    phtstimdata = reshape(phtstimdata',3,[])';

    % x,y are in reference coordinate space, beam power is in [V], native readout of photo diode
    out.X = phtstimdata(:,1);
    out.Y = phtstimdata(:,2);
    out.Beam = phtstimdata(:,3);

    %the monitoring rate is saved to the tiff header
    %phstimrate = header.SI.hPhotostim.monitoringSampleRate;
    %phtstimtimeseries = linspace(0,lgth/phstimrate-1/phstimrate,lgth);
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
