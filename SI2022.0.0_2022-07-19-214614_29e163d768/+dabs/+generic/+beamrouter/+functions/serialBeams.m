function pockelsPowerFractions = serialBeams(beamPowerFractions,hBeams,hBeamRouter)
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
    %
    % beamFractions is an Nx2 matrix
    %     - Column 1 is beam 1 powerfraction
    %     - Column 2 is beam 2 powerfraction
    %     - power fractions are values between 0 and 1
    
    beam1 = beamPowerFractions(:,1);
    beam2 = beamPowerFractions(:,2);

    pockels1 = beam1 + beam2;          % Pockels Cell 1 determines the total power
    pockels2 = beam1 ./ (beam1+beam2); % Pockels Cell 2 determines the splitting ratio

    % correct unachievable values
    if any(pockels1>1)
        most.idioms.warn('serialBeams: Unachievable power detected: %f%%', max(pockels1)*100);
        pockels1(pockels1>1) = 1;
    end
    
    pockels2(isnan(pockels2)) = 0; % if in1 AND in2 are zero in1./(in1+in2) = 0./(0+0) = NaN

    % assemble output waveform
    pockelsPowerFractions = [pockels1, pockels2];
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
