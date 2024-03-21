import dabs.ni.daqmx.*
import dabs.ni.daqmx.demos.*

ctrValues = [];

hEdge1 = PulseGenerator('Dev3',3); %PO.3 -- connected to PFI7
hEdge2 = PulseGenerator('Dev3',4); %P0.4 -- connected to PFI6


hCtr = Task('Two-edge Sep counter');
hCtr.createCITwoEdgeSepChan('Dev3',3); %Ctr3 uses PFI7/6 by default for two-edge separation measurements
hCtr.cfgImplicitTiming('DAQmx_Val_ContSamps');

hCtr.start();

edgeSepValues = [1:10 30];

for i=1:length(edgeSepValues);
    hEdge1.go();
    pause(edgeSepValues(i));
    hEdge2.go();
    ctrValues(end+1) = hCtr.readCounterDataScalar();
    fprintf(1,'Read edge-separation value: %g\n',ctrValues(end));
end

delete(hCtr);
delete(hEdge1);
delete(hEdge2);




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
