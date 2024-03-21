function filename = generateSIReport(attemptSILaunch,filename)
%generateSIReport: Report generator for ScanImage 2015.
%   Saves the following properties:
%       cpuInfo             Struct with CPU information
%       NI_MAX_Report       Report generated using the NI's reporting API
%       REF                 Commit number, if available
%       mSessionHistory     Current session history as a Matlab string
%       mFullSession        Current session history as a Matlab string, including console output
%       searchPath
%       matlabVer
%       usrMem
%       sysMem
%       openGLInfo
%
%   If attemptSILaunch is enabled and ScanImage is not currently loaded, it attempts to launch ScanImage
%

    if nargin < 1 || isempty(attemptSILaunch)
        attemptSILaunch = false;
    end
    
    if nargin < 2 || isempty(filename)
        n = sprintf('SIReport_%s.zip', datestr(now,'yyyymmdd_HHMMSS'));
        [filename,pathname] = uiputfile('.zip','Choose path to save report',n);
        if filename==0;return;end
    
        filename = fullfile(pathname,filename);
    end

    fileList = {};
    fileListCleanUp = {};

    [fpath,fname,fext] = fileparts(filename);
    if isempty(fpath)
        fpath = pwd;
    end
    
    if isempty(fname)
        fname = 'SIReport';
    end


    disp('Generating ScanImage report...');
    wb = waitbar(0,'Generating ScanImage report');
    
    try
        % Check if ScanImage is running
        siAccessible = false;
        if evalin('base','exist(''hSI'')') && evalin('base','isvalid(hSI)')
            siAccessible = true;
        end

        if attemptSILaunch && ~siAccessible
            siAccessible = true;
            try
                scanimage;
            catch
                siAccessible = false;
            end
        end

        % Re-attempt to load hSI
        if siAccessible && evalin('base','exist(''hSI'')')
            hSILcl = evalin('base','hSI');
        end

        if siAccessible
            try
                % Save currently loaded MDF file
                mdf = most.MachineDataFile.getInstance;
                if mdf.isLoaded && ~isempty(mdf.fileName)
                    fileList{end+1} = mdf.fileName;
                end

                % Save current usr and cfg files
                fullFileUsr = fullfile(tempdir,[fname '.usr']);
                fullFileCfg = fullfile(tempdir,[fname '.cfg']);
                fullFileHeader = fullfile(tempdir,'TiffHeader.txt');
                fullFileErr = fullfile(tempdir,'ErrorLog.txt');
                fullFileEvt = fullfile(tempdir,'EventLog.txt');

                hSILcl.hConfigurationSaver.usrSaveUsrAs(fullFileUsr,'',1);
                fileList{end+1} = fullFileUsr;
                fileListCleanUp{end+1} = fullFileUsr;

                hSILcl.hConfigurationSaver.cfgSaveConfigAs(fullFileCfg, 1);
                fileList{end+1} = fullFileCfg;
                fileListCleanUp{end+1} = fullFileCfg;
                
                try
                    s = hSILcl.mdlGetHeaderString();
                    
                    fileID = fopen(fullFileHeader,'W');
                    fwrite(fileID,s,'char');
                    fclose(fileID);
                    fileList{end+1} = fullFileHeader;
                    fileListCleanUp{end+1} = fullFileHeader;
                catch
                end
                
                try
                    s = hSILcl.hController{1}.hUiLogger.printLog();
                    
                    fileID = fopen(fullFileEvt,'W');
                    fwrite(fileID,s,'char');
                    fclose(fileID);
                    fileList{end+1} = fullFileEvt;
                    fileListCleanUp{end+1} = fullFileEvt;
                catch
                end
                
                [MEs, ts] = most.ErrorHandler.errorHistory();
                errN = numel(MEs);
                if errN
                    fileID = fopen(fullFileErr,'W');
                    
                    for i = 1:errN
                        errString = MEs{i}.getReport('extended','hyperlinks','off');
                        timestamp = datestr(ts(i),'yyyy-mm-dd HH:MM:SS:FFF');
                        
                        out = sprintf('========== %s ==========', timestamp);
                        fprintf(fileID,'%s\n%s\n\n',out,errString);
                    end
                    
                    fclose(fileID);
                    fileList{end+1} = fullFileErr;
                    fileListCleanUp{end+1} = fullFileErr;
                end
                
                % ConfigData
                try
                    datDir = fileparts(hSILcl.classDataDir);
                    tfn = datDir(find(datDir == filesep(),1,'last')+1:end);
                    fileNameCfgData = fullfile(tempdir,[tfn '.zip']);
                    zip(fileNameCfgData, datDir);
                    fileList{end+1} = fileNameCfgData;
                    fileListCleanUp{end+1} = fileNameCfgData;
                catch
                end
            catch
                disp('Warning: SI could not be accessed properly');
            end
        end
        
        waitbar(0.2,wb);
        
        % detect vDAQs
        vDAQInfo = struct();
        vDAQInfo.driver = dabs.vidrio.rdi.Device.getDriverInfo();
        vDAQInfo.vDAQs = {};
        
        vDAQIdx = 0;
        while true
            info = dabs.vidrio.rdi.Device.getDeviceInfo(vDAQIdx);
            if isempty(info)
                break;
            else
                vDAQInfo.vDAQs{end+1} = info;
                vDAQIdx = vDAQIdx + 1;
            end
        end
        
        filenamevDAQ = fullfile(tempdir,[fname '_vDAQInfo.mat']);
        save(filenamevDAQ, 'vDAQInfo');
        fileList{end+1} = filenamevDAQ;
        fileListCleanUp{end+1} = filenamevDAQ;
        
        % get license info
        hLM = scanimage.util.private.LM();
        fileName = fullfile(tempdir,'HostID.txt');
        fid = fopen(fileName,'w+');
        fprintf(fid,'%s',hLM.hostID);
        fclose(fid);
        fileList{end+1} = fileName;
        fileListCleanUp{end+1} = fileName;
        
        if ~isempty(hLM.licenseText)
            fileName = fullfile(tempdir,'License.txt');
            fid = fopen(fileName,'w+');
            fprintf(fid,'%s',hLM.licenseText);
            fclose(fid);
            fileList{end+1} = fileName;
            fileListCleanUp{end+1} = fileName;
        end

        % create MAX report
        filenameNIMAX = fullfile(tempdir,[fname '_NIMAX.zip']); % extension has to be .zip, otherwise NISysCfgGenerateMAXReport will throw error
        NIMAXSuccess = true;
        try
            dabs.ni.configuration.generateNIMaxReport(filenameNIMAX);
        catch
            NIMAXSuccess = false;
        end

        if NIMAXSuccess
            fileList{end+1} = filenameNIMAX;
            fileListCleanUp{end+1} = filenameNIMAX;
        end
        
        waitbar(0.6,wb);

        % Open a temporary mat file to store any relevant information
        tmpFilename = fullfile(tempdir,[fname '_tmp.mat']);

        % CPU info
        cpuInfo = most.idioms.cpuinfo;
        save(tmpFilename, 'cpuInfo');
        fileListCleanUp{end+1} = tmpFilename;
        
        % ScanImage version
        siVersion = scanimage.SI.version();
        save(tmpFilename,'siVersion','-append');
        
        % Get current session history
        if ismcc || isdeployed
            mSessionHistory = evalin('base', 'hSICtl.hStatusWindow.getHistory()');
        else
            jSessionHistory = com.mathworks.mlservices.MLCommandHistoryServices.getSessionHistory;
            mSessionHistory = cellstr(char(jSessionHistory));
        end
        save(tmpFilename, 'mSessionHistory','-append');
        
        % Get current current text from the standard output
        if ismcc || isdeployed
            mFullSession = evalin('base', 'hSICtl.hStatusWindow.getBuffer()');
        else
            % NOTE: Clearing the window will prevent this function from showing the errors. It's still a good candidate
            %       to be called within ScanImage when being presented with an error
            drawnow;
            cmdWinDoc = com.mathworks.mde.cmdwin.CmdWinDocument.getInstance;
            jFullSession = cmdWinDoc.getText(cmdWinDoc.getStartPosition.getOffset,cmdWinDoc.getLength);
            mFullSession = char(jFullSession);    
        end
        save(tmpFilename, 'mFullSession','-append');
        % Get current search path
        searchPath = path; 
        save(tmpFilename, 'searchPath','-append');

        % Get Matlab and Java versions
        matlabVer = version();
        javaVer = version('-java'); 
        save(tmpFilename,'matlabVer','javaVer','-append');
        
        % Get Windows version
        [~,winVer] = system('ver');
        save(tmpFilename,'winVer','-append');        

        % Get memory info
        [usrMem sysMem] = memory;
        save(tmpFilename,'usrMem','sysMem','-append');

        % Get OpenGL information
        openGLInfo = opengl('data');
        save(tmpFilename,'openGLInfo','-append');
        
        if siAccessible
            hSICtl = evalin('base','hSICtl');
            uiLog = hSICtl.hUiLogger.printLog;
            save(tmpFilename,'uiLog','-append');
        end
        
        try
            %save separate files for convenience
            fn = fullfile(tempdir,'mSessionHistory.txt');
            fidt = fopen(fn,'w');
            for i=1:length(mSessionHistory)
                fprintf(fidt, '%s\n', mSessionHistory{i});
            end
            fclose(fidt);
            fileListCleanUp{end+1} = fn;
            fileList{end+1} = fn;

            fn = fullfile(tempdir,'mFullSession.txt');
            fidt = fopen(fn,'w');
            fprintf(fidt,'%s', mFullSession);
            fclose(fidt);
            fileListCleanUp{end+1} = fn;
            fileList{end+1} = fn;
        catch
        end
        
        waitbar(0.8,wb);

        % Add the tmp file to the zip list
        fileList{end+1} = tmpFilename;

        % Zip important information
        zip(filename, fileList);

        % Clean directory
        cellfun(@(f)delete(f),fileListCleanUp);
        
        waitbar(1,wb);

        disp('ScanImage report ready');
    catch ME
        delete(wb);
        most.ErrorHandler.logAndReportError(ME,['Failed to generate support report. Error: ' ME.message]);
    end
    
    delete(wb); % delete the waitbar
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
