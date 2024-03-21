classdef MicroManager < handle
    %% MicroManager Class
    %
    % This class creates a Matlab accessible interface for MicroManager to
    % access and control MicroManager supported hardware.
    %
    
    properties (SetAccess = private)
        mmc;                    % Handle to the MicroManager core java object
        configFile;             % String containing the path to, and name of, the config file for the device being operated.
    end
    
    %% LIFECYCLE METHODS
    methods
        %% Constructor
        function obj = MicroManager(configFile, mManagerInstallationPath)
            if nargin < 2 || isempty(mManagerInstallationPath)
                mManagerInstallationPath = [];
            end
            
            %opens file dialog if mManagerInstallationPath is empty
            install(mManagerInstallationPath);
            
            importlist = import();
            if ~ismember('mmcorej.*',importlist)
                import('mmcorej.*');
            end
            
            assert(exist('CMMCore','class')==8,'Java Class CMMCore could not be found');
            
            if ~obj.isOnWindowsPath(mManagerInstallationPath)
                most.idioms.warn('MicroManager is not on the Windows search path. Some drivers might not work as expected.');
            end
                
            obj.mmc = CMMCore(); % construct micromanager object
            
            if nargin < 1 || isempty(configFile)
                [fileName,filePath] = uigetfile('*.cfg','Select system configuration file');
                if fileName <= 0
                   obj.delete();
                   return
                end
                
                configFile = fullfile(filePath,fileName);
            end
            
            assert(2==exist(configFile,'file'),'File %s does not exist',configFile);
            obj.configFile = configFile;
            obj.mmc.loadSystemConfiguration(obj.configFile);
        end
        
        %% Destructor
        function delete(obj) 
            try
                obj.mmc.unloadAllDevices();
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
            most.idioms.safeDeleteObj(obj.mmc);
            % clear('java'); is this safe to do?
        end
    end
    
    %% UTILITY METHODS
    methods
        function [data, meta] = getNextImages(obj)
            import('mmcorej.Metadata');
            imageCount = obj.mmc.getRemainingImageCount();
            data = cell(imageCount, 1);
            
            for iImage=1:imageCount
                mmMetadata = Metadata();
                data{iImage} = obj.mmc.popNextImageMD(mmMetadata);
                meta(iImage) = dabs.micromanager.ImageMetaData(mmMetadata);
            end
            if isempty(data)
                meta = struct([]);
            end
        end
    end
    
    methods (Static)
        function tf = isOnWindowsPath(mManagerInstallationPath)
            [status,output] = system('echo %path%');
            output = strsplit(output,';');
            output = strtrim(output);
            mask = strcmpi(output,mManagerInstallationPath);
            
            tf = status==0 && any(mask);
        end        
    end
end

function install(mManagerInstallationPath,static)
    [tf,installPath] = isinstalled();
    
    if tf
        return
    end

    if nargin < 1 || isempty(mManagerInstallationPath)
        programFilesFolder = getenv('PROGRAMFILES');
        
        if exist(fullfile(programFilesFolder,'Micro-Manager-2.0'),'dir')
            defaultPath = fullfile(programFilesFolder,'Micro-Manager-2.0');
        elseif exist(fullfile(programFilesFolder,'Micro-Manager-2.0gamma'),'dir')
            defaultPath = fullfile(programFilesFolder,'Micro-Manager-2.0gamma');
        elseif exist(fullfile(programFilesFolder,'Micro-Manager-1.4'),'dir')
            defaultPath = fullfile(programFilesFolder,'Micro-Manager-1.4');
        else
            defaultPath = programFilesFolder;
        end
        
        mManagerInstallationPath = uigetdir(defaultPath,'Select the micromanager installation directory');
        if mManagerInstallationPath==0
            error('Invalid path to MicroManager installation directory.');
        end
    end

    if nargin < 2 || istempty(static)
        static = false;
    end
    
    assert(7==exist(mManagerInstallationPath,'dir'),'Path %s not found in system.',mManagerInstallationPath);
    assert(2==exist(fullfile(mManagerInstallationPath,'MMCoreJ_wrap.dll'),'file'),'Micromanager was not found at %s',mManagerInstallationPath);
    
    [~,jars] = system(['dir "' mManagerInstallationPath '\plugins\Micro-Manager\*.jar" /S /B']);
    jars = strsplit(strtrim(jars),'\n');
    jars{end+1} = fullfile(mManagerInstallationPath,'ij.jar');
    strrep(jars,'\','/');

    if static
        classpath_file = fullfile([prefdir '/javaclasspath.txt']);
        hFile = fopen(classpath_file,'a');
        assert(hFile>=0,'Could not open file %s',classpath_file);
        for idx = 1:length(jars)
            fprintf(hFile,'\n%s',jars{idx});
        end
        fclose(hFile);
        addpath(mManagerInstallationPath);
        savepath();
    else
        javaaddpath(jars);
        addpath(mManagerInstallationPath);
    end
end

function [tf,installPath] = isinstalled()
    javaclasspath_ = vertcat(javaclasspath('-static'),javaclasspath('-dynamic'));
    javaclasspath_ = regexp(javaclasspath_,'.*MMCoreJ.*','match','once');
    mask = cellfun(@(p)~isempty(p),javaclasspath_);
    javaclasspath_ = javaclasspath_(mask);
    
    if ~isempty(javaclasspath_)
        tf = true;
        installPath = javaclasspath_{1};
        installPath = fileparts(fileparts(fileparts(installPath)));
    else
        tf = false;
        installPath = '';
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
