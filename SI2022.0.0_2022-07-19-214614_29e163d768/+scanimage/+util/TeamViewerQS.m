function TeamViewerQS(forceUpdate,ageLimit)
    if nargin < 1 || isempty(forceUpdate)
        forceUpdate = false;
    end
    
    if nargin < 2 || isempty(ageLimit)
        ageLimit = years(0.5);
    end
    
    try
        validateattributes(forceUpdate,{'numeric','logical'},{'scalar','binary'});
        validateattributes(ageLimit,{'duration'},{'scalar'});
        
        filename = fullfile(tempdir(),'TeamViewerQS.exe');
        
        if ~exist(filename,'file') || forceUpdate
            downloadTeamViewerQS(filename);
        else
            checkUpdate(filename,ageLimit);
        end
        
        f = waitbar(0.25,'Opening TeamViewer Quick Support');

        try
            status = system(filename);
            assert(status == 0,'Could not start TeamViewerQS');
        catch ME
            delete(f);
            rethrow(ME);
        end
        
        waitbar(1,f);
        delete(f);
        
    catch ME
        msgbox({'Could not start remote session.','Check internet connection.'}, 'Error','error');
        rethrow(ME);
    end
end

function checkUpdate(filename,ageLimit)
    try
        s = dir(filename);
        date = s.date;
        date = datetime(date,'InputFormat','dd-MMM-yyyy HH:mm:ss');
        now = datetime('now');
        age = now-date;

        if age > ageLimit
            downloadTeamViewerQS(filename);
        end
    catch
        fprintf(2,'Could not update TeamViewerQS to latest version.\n');
    end
end

function filename = downloadTeamViewerQS(filename)
    url = 'https://download.teamviewer.com/download/TeamViewerQS.exe';
    
    f = waitbar(0.25,'Downloading TeamViewer Quick Support');
    
    try
        filename = websave(filename,url,weboptions('ContentType','binary'));
    catch ME
        delete(f);    
        rethrow(ME);
    end
    
    waitbar(1,f);    
    delete(f);
    
    
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
