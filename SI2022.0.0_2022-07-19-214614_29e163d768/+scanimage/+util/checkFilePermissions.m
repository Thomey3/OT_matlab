function checkFilePermissions()
    siPath = scanimage.util.siRootDir();
    fileName = fullfile(siPath,[most.util.generateUUID '.si']);
    
    if ~makeTestFile(fileName)
        button = questdlg(sprintf('ScanImage does not have write permissions in its installation folder.\nDo you want to fix the file permissions automatically?'));
        switch lower(button)
            case 'yes'
                scanimage.util.setSIFilePermissions();
                if ~makeTestFile(fileName);
                    msgbox('ScanImage could not set the folder permissions automatically.','Warning','warn');
                end
            otherwise
                msgbox('Without write access in the installation folder ScnaImage might not function correctly.','Warning','warn');
                return
        end
    end
end

function success = makeTestFile(fileName)
    success = false;
    try
        hFile = fopen(fileName,'w+');
        if hFile < 0
            return
        end
        fprintf(hFile,'my test string');
        fclose(hFile);
        success = true;
    catch
        success = false;
    end
    
    if exist(fileName,'file');
        delete(fileName);
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
