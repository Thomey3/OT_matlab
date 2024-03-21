function serialBeamsCalibration(hBeams)
    % example for using two Pockels cells in series:
    %     - Pockels Cell 1 determines total power
    %     - Pockels Cell 2 determines the splitting ratio between Beam1 and Beam 2
    %
    %            ----------------           ---------------
    %    >----- | Pockels Cell 1 | ------ | Pockels Cell 2 |--------\------> Beam 1
    %            ----------- | --           --------- | --          |
    %                        |                        |             |
    %                   Photodiode 1                  |        Photodiode 2
    %                                                 |
    %                                                 ---------------------> Beam 2
    %
    
    % calibrate pockels cell 1
    hBeams{1}.calibrate;
    
    % calibrate pockels cell 2
    %     - to calibrate pockels cell 2, pockels cell 1 needs to transmit light
    hBeams{1}.setPowerFraction(1);
    
    try
        hBeams{2}.calibrate();
    catch ME
        % set beam1 to 0 when an error happens during calibration of beam 2
        hBeams{1}.setPowerFraction(0);
        ME.rethrow();
    end
    
    hBeams{1}.setPowerFraction(0);
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
