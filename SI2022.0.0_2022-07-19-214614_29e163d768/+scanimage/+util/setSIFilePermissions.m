function setSIFilePermissions()
    siPath = scanimage.util.siRootDir();

    %% set user permissions to full access
     fprintf('Setting user permissions for folder %s ...\n',siPath);
%     [~,currentUser] = system('whoami');
%     currentUser = regexprep(currentUser,'\n','');
%     cmd = ['icacls "' siPath '" /grant "' currentUser '":(OI)(CI)F /T'];

    cmd = ['icacls "' siPath '" /grant "Users":(OI)(CI)F /T'];
    [status,cmdout] = system(cmd);
    if status == 0
        statusLine = regexpi(cmdout,'^.*(Successfully|Failed).*$','lineanchors','dotexceptnewline','match','once');
        if isempty(statusLine)
            disp(cmdOut)
        else
            disp(statusLine)
        end
    else
        fprintf(2,'Setting user file permissions failed with error code %d\n',status);
    end

    %% remove file attributes 'hidden' and 'read-only'
    fprintf('Setting file attributes for folder %s ...\n',siPath);
    cmd = ['attrib -H -R /S "' fullfile(siPath,'*') '"'];
    [status,cmdout] = system(cmd);
    if status == 0
        if ~isempty(cmdout)
            disp(cmdout);
        end
    else
        fprintf(2,'Setting file attributes failed with error code %d\n',status);
    end
    
    fprintf('Done\n');
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
