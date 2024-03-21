% data_out = DPAPICryptProtectData(data_in,protect_flag)
% this function uses the Microsoft Windows Data Protection API to protect
% binary data from being accessed on a different computer or user account
% inputs:
%   protect_flag                 : logical
%                      true : data_in is encrypted to data_out
%                      false: data_in is decrypted to data_out
%   data_in                      : (1xN) uint8 array
%   additional_entropy (optional): (1xN) uint8 array
%   local_machine (optional)     : logical scalar; When this flag is set, it associates the data encrypted with the current computer instead of with an individual user. Any user on the computer on which CryptProtectData is called can use CryptUnprotectData to decrypt the data.
%
% outputs:
%   data_out: (1xM) uint8 array
%
%
% example:
% 
% msg = 'This is my secret message';
% msg_bytes = unicode2native(msg,'UTF-8');
% msg_protected = scanimage.util.private.DPAPICryptProtectData(true,msg_bytes);
% ...
% msg_bytes_unprotected = scanimage.util.private.DPAPICryptProtectData(false,msg_protected);
% msg_unprotected = native2unicode(msg_bytes_unprotected,'UTF-8');                             



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
