classdef StartupConfig < most.HasClassDataFile
    properties
        hFig;
        mdfPath;
        usrPath;
        runSI = false;
        hStartWb;
        hSI;
    end
    
    %control handles
    properties
        etMdfPath;
        etUsrPath;
        
        lastCSusr;
    end
    
    methods
        function obj = StartupConfig(mdfPath, usrPath, showConfig, hWb)
            if nargin < 3
                showConfig = false;
            end
            if nargin < 4
                hWb = [];
            end
            
            obj.loadLastCSdata();
            obj.ensureClassDataFile(struct('lastUsrFile',obj.lastCSusr));
            if isempty(usrPath)
                usrPath = obj.getClassDataVar('lastUsrFile');
            end
            if strcmp(usrPath, '.usr')
                usrPath = '';
            end
            
            %figure out center
            p = most.gui.centeredScreenPos([80, 46],'characters');
            kpf = {'KeyPressFcn', @obj.keyFcn};
            
            obj.hFig = most.idioms.figure(...
                'Units','characters',kpf{:},...
                'Color',most.constants.Colors.lightGray,...
                'MenuBar','none',...
                'Name',scanimage.SI.version(),...
                'NumberTitle','off',...
                'Position',p,...
                'Resize','off',...
                'Visible','off');
            
            logoPanel = uipanel(...
                'Parent',obj.hFig,...
                'Units','characters',...
                'Clipping','on',...
                'BorderType','none',...
                'Position',[0 37 80 10],...
                'Tag','logopanel');
            
            hLogo = scanimage.util.ScanImageLogo(logoPanel,false);
            matrix = eye(3);
            matrix(2,2) = -1;
            matrix(1,3) = 5;
            matrix(2,3) = -0.2;
            most.idioms.MBFLogo(hLogo.hAx,matrix,true);
            
            infoPanel = uipanel(...
                'Parent',obj.hFig,...
                'Units','characters',...
                'Clipping','on',...
                'BorderType','none',...
                'Position',[0 16 80 21],...
                'Tag','infopanel');

            hLM = scanimage.util.private.LM();
            hLM.showInfo(infoPanel);
            
            mdfPanel = uipanel(...
                'Parent',obj.hFig,...
                'Units','characters',...
                'Title','Machine Data File',...
                'Clipping','on',...
                'Position',[1.6 9.3846153846154 76 5.61538461538462],...
                'Tag','uipanel1');
            
            uicontrol(...
                'Parent',mdfPanel,...
                'Units','characters',...
                'Callback',@(varargin)obj.pbBrowseMdf(varargin{1}),...
                'Position',[1.6 0.538461538461542 13.8 1.69230769230769],...
                'String','Browse...',...
                'TooltipString','Select an existing machine data file from disk.',...
                'Tag','pbBrowseMdf');
            
            uicontrol(...
                'Parent',mdfPanel,...
                'Units','characters',...
                'Callback',@(varargin)obj.pbCreateMdf(varargin{1}),...
                'Position',[15.8 0.538461538461542 13.8 1.69230769230769],...
                'String','New...',...
                'TooltipString','Create a new machine data file.',...
                'Tag','pbCreateMdf');
            
            uicontrol(...
                'Parent',mdfPanel,...
                'Units','characters',...
                'Callback',@(varargin)obj.pbEditMdf(varargin{1}),...
                'Position',[30 0.538461538461542 13.8 1.69230769230769],...
                'String','Modify...',...
                'TooltipString','Modify the selected machine data file.',...
                'Tag','pbEditMdf');
            
            obj.etMdfPath = uicontrol(...
                'Parent',mdfPanel,kpf{:},...
                'Units','characters',...
                'BackgroundColor',[1 1 1],...
                'HorizontalAlignment','left',...
                'Position',[1.6 2.38461538461539 71.2 1.69230769230769],...
                'String',mdfPath,...
                'Style','edit',...
                'Tag','etMdfPath');
            
            usrPanel = uipanel(...
                'Parent',obj.hFig,...
                'Units','characters',...
                'Title','User Settings File',...
                'Clipping','on',...
                'Position',[1.6 3.07692307692308 76.2 5.61538461538462],...
                'Tag','uipanel2');
            
            uicontrol(...
                'Parent',usrPanel,...
                'Units','characters',...
                'Callback',@(varargin)obj.pbBrowseUsr(varargin{1}),...
                'Position',[1.6 0.538461538461542 13.8 1.69230769230769],...
                'String','Browse...',...
                'TooltipString','Select a user settings file from disk.',...
                'Tag','pbBrowseUsr');
            
            obj.etUsrPath = uicontrol(...
                'Parent',usrPanel,kpf{:},...
                'Units','characters',...
                'BackgroundColor',[1 1 1],...
                'HorizontalAlignment','left',...
                'Position',[1.6 2.38461538461539 71.2 1.69230769230769],...
                'String',usrPath,...
                'Style','edit',...
                'Tag','etUsrPath');
            
            uicontrol(...
                'Parent',obj.hFig,...
                'Units','characters',...
                'Callback',@(varargin)obj.pbLoadSI(),...
                'FontWeight','bold',...
                'Position',[1.8 0.769230769230769 20 1.69230769230769],...
                'String','Start ScanImage',...
                'TooltipString','Load scanimage with the selected configuration.',...
                'Tag','pbLoadSI');
            
            uicontrol(...
                'Parent',obj.hFig,...
                'Units','characters',...
                'Callback',@(varargin)obj.pbAbortSI(),...
                'Position',[22.0 0.76923076923077 13.8 1.69230769230769],...
                'String','Cancel',...
                'TooltipString','Abort loading of scanimage application.',...
                'Tag','pbAbortSI');
            
            
            if showConfig
                obj.mdfPath = mdfPath;
                obj.showConfigEditor(hWb);
            end
            
            set(obj.hFig,'Visible','on');
            hLogo.animate();
        end
        
        function delete(obj)
            obj.hidevDAQBreakouts();
        end
        
        function hidevDAQBreakouts(obj)
            if dabs.resources.ResourceStore.isInstantiated()
                hResourceStore = dabs.resources.ResourceStore();
                hvDAQs = hResourceStore.filterByClass('dabs.resources.daqs.vDAQ');
                for idx = 1:numel(hvDAQs)
                    hvDAQs{idx}.hideBreakout();
                end
            end
        end
        
        function pbLoadSI(obj)
            try
                hLm = scanimage.util.private.LM();
                hLm.validate();
            catch ME
                msg = sprintf('License validation has failed.\n%s', ME.message);
                warndlg(msg, 'ScanImage');
                return
            end
            
            obj.mdfPath = get(obj.etMdfPath, 'String');
            obj.usrPath = get(obj.etUsrPath, 'String');
            
            if ~logical(exist(obj.mdfPath,'file'))
                warndlg('Specified machine data file not found.','ScanImage');
                return
            end
            
            if ~scanimage.SI.isMdfCompatible(obj.mdfPath)
                msg = sprintf('Selected Machine Data File is not compabtible with ScanImage.\nSelect a different MDF or create a new configuration.');
                warndlg(msg,'Incompatible MDF');
                return
            end
            
            if isempty(obj.usrPath)
                obj.usrPath = '.usr';
            else
                if ~logical(exist(obj.usrPath,'file'))
                    warndlg('Specified user file not found.','ScanImage');
                    return
                end
            end
            
            obj.hStartWb = waitbar(0,'Loading Machine Data File','Name','ScanImage startup');
            try
                
                hResourceStore = dabs.resources.ResourceStore();
                hResourceStore.instantiateFromMdf(obj.mdfPath,obj.hStartWb);
                hSIi = hResourceStore.filterByClass('scanimage.SI');
            catch ME
                most.idioms.safeDeleteObj(obj.hStartWb);
                most.ErrorHandler.rethrow(ME);
            end
            
            if isempty(hSIi)
                most.idioms.safeDeleteObj(obj.hStartWb);
                warndlg('ScanImage is not configured in Machine Data File','ScanImage');
                obj.showConfigEditor();
                return
            end
            
            obj.hSI = hSIi{1};
            obj.hSI.validateConfiguration();
            
            if ~isempty(obj.hSI.errorMsg)
                most.idioms.safeDeleteObj(obj.hStartWb);
                answer = questdlg('ScanImage cannot be started because of configuration issues.', ...
                    'Configuration issue.', ...
                    'Show config','Cancel','Show config');
                
                if strcmp(answer,'Show config')
                    obj.showConfigEditor();
                end
                
                return
            end            
            
            obj.runSI = true;
            delete(obj.hFig);
            drawnow
        end
        
        function pbAbortSI(obj)
            delete(obj.hFig);
        end
        
        function pbBrowseMdf(obj, uiObj)
            mdfpath = get(obj.etMdfPath, 'String');
            
            if isempty(mdfpath)
                mdfpath = '*.m';
            end
            
            [mdffile, mdfpath] = uigetfile(mdfpath,'Select machine data file...');
            if ~isequal(mdffile,0) && ~isequal(mdfpath,0)
                set(obj.etMdfPath, 'String', fullfile(mdfpath,mdffile));
                dabs.resources.ResourceStore.clear();
                most.MachineDataFile.clear();
            end
            
            obj.clearFocus(uiObj);
        end
        
        function pbCreateMdf(obj, uiObj)
            mdfpath = get(obj.etMdfPath, 'String');
            if isempty(mdfpath)
                mdfpath = '*.m';
            else
                mdfpath = fileparts(mdfpath);
            end
            
            [newMdfName, hWb] = scanimage.guis.StartupConfig.newMdf(mdfpath);
            
            if ~isempty(newMdfName)
                set(obj.etMdfPath, 'String', newMdfName);
                set(obj.etUsrPath, 'String', '');
                obj.mdfPath = newMdfName;
                obj.showConfigEditor(hWb);
            end
            
            obj.clearFocus(uiObj);
        end
        
        function pbEditMdf(obj, uiObj)
            obj.mdfPath = get(obj.etMdfPath, 'String');
            if ~logical(exist(obj.mdfPath,'file'))
                warndlg('Specified machine data file not found.','ScanImage');
            else
                obj.showConfigEditor();
            end
            
            obj.clearFocus(uiObj);
        end
        
        function pbBrowseUsr(obj, uiObj)
            pth = get(obj.etUsrPath, 'String');
            if isempty(pth)
                pth = obj.lastCSusr;
            end
            if isempty(pth)
                pth = '*.usr';
            end
            
            [usrfile, usrpath] = uigetfile(pth,'Select machine data file...');
            if ~isequal(usrfile,0) && ~isequal(usrpath,0)
                set(obj.etUsrPath, 'String', fullfile(usrpath,usrfile));
            end
            
            obj.clearFocus(uiObj);
        end
        
        function keyFcn(obj,~,evt)
            switch evt.Key
                case 'return'
                    drawnow(); % make sure changes to entry are committed
                    obj.pbLoadSI();
                    
                case 'escape'
                    obj.pbAbortSI();
            end
        end
        
        function clearFocus(~,uiObj)
            if most.idioms.isValidObj(uiObj)
                set(uiObj, 'Enable', 'off');
                drawnow update;
                set(uiObj, 'Enable', 'on');
            end
        end
    end
    
    methods (Hidden)
        function loadLastCSdata(obj)
            classPrivatePath = most.util.className('scanimage.components.ConfigurationSaver','classPrivatePath');
            classNameShort   = most.util.className('scanimage.components.ConfigurationSaver','classNameShort');
            classDataFileName = fullfile(classPrivatePath, [classNameShort '_classData.mat']);
            if exist(classDataFileName, 'file')
                e = load(classDataFileName);
                try
                    obj.lastCSusr = e.lastUsrFile;
                catch
                    obj.lastCSusr = '';
                end
            end
        end
        
        function showConfigEditor(obj,hWb)
            if ~exist(obj.mdfPath,'file')
                msg = 'Machine Data File not found on disk.';
                warndlg(msg,'MDF not found');
                most.ErrorHandler.logAndReportError(msg);
                return
            end
            
            if ~scanimage.SI.isMdfCompatible(obj.mdfPath)
                msg = sprintf('Selected Machine Data File is not compabtible with ScanImage.\nSelect a different MDF or create a new configuration.');
                warndlg(msg,'Incompatible MDF');
                most.ErrorHandler.logAndReportError(msg);
                return
            end
            
            if nargin < 2 || isempty(hWb)
                hWb = waitbar(0,'Loading Machine Data File...');
            end
            
            try
                hResourceStore = dabs.resources.ResourceStore();
                dabs.resources.ResourceStore.instantiateFromMdf(obj.mdfPath,hWb);
                
                waitbar(0.9,hWb,'Loading ScanImage');
                
                hSI = hResourceStore.filterByClass('scanimage.SI');
                if isempty(hSI)
                    try
                        hSI = scanimage.SI(); % instantiate scanimage
                    catch ME
                        most.ErrorHandler.logAndReportError(ME);
                    end
                end
                hConfigEditor = dabs.resources.ResourceStore.showConfig();
                most.ErrorHandler.addCatchingListener(hConfigEditor,'ObjectBeingDestroyed',@(varargin)configEditorDestroyed());
                
                dabs.resources.ResourceStore.showWidgetBar();
                
                hvDAQs = hResourceStore.filterByClass('dabs.resources.daqs.vDAQ');
                if ~isempty(hvDAQs)
                    hvDAQs{1}.showBreakout;
                end
                
                most.idioms.safeDeleteObj(hWb);
            catch ME
                rethrow(ME);
            end
            
            function configEditorDestroyed()
                obj.hidevDAQBreakouts();
                raiseFigure();
            end
            
            function raiseFigure()
                if most.idioms.isValidObj(obj) && most.idioms.isValidObj(obj.hFig)
                    most.idioms.figure(obj.hFig);
                end
            end
        end
    end
    
    methods
        function set.mdfPath(obj,val)
            oldVal = obj.mdfPath;
            obj.mdfPath = val;
            
            if ~isequal(val,oldVal)
                hMdf = most.MachineDataFile.getInstance();
                if ~hMdf.isLoaded || ~strcmp(hMdf.fileName, val)
                    dabs.resources.ResourceStore.clear();
                end
            end
        end
    end
    
    methods (Static)        
        function [newFileName, hWb] = newMdf(mdfpath)
            newFileName = [];
            hWb = [];
            
            [mdffile, mdfpath] = uiputfile('*.m','Save new machine data file...',mdfpath);
            if isequal(mdffile,0) || isequal(mdfpath,0)
                return
            end
            
            s = scanimage.guis.MdfCreator.doModal();
            if isempty(s)
                return;
            end
            
            hWb = waitbar(0.25,'Creating new configuration...');
            try
                % first close out current MDF/SI instance
                dabs.resources.ResourceStore.clear();
                most.MachineDataFile.clear();
                most.idioms.figure(hWb);
                
                % add header to mdf
                newFileName = fullfile(mdfpath,mdffile);
                fid = fopen(newFileName,'w+');
                most.MachineDataFile.writeHeader(fid);
                fclose(fid);
                
                % add components to configuration
                dabs.resources.ResourceStore.instantiateFromMdf(newFileName);
                scanimage.SI;
                
                if ~isempty(s.className)
                    feval(s.className,'Adding components...');
                end
            catch ME
                most.ErrorHandler.logAndReportError(ME);
                delete(hWb);
                newFileName = [];
                hWb = [];
            end
        end
        
        function [mdfPath, usrPath, runSI, hWb, hSI] = doModalConfigPrompt(mdfPath, usrPath)
            
            if nargin < 1 || isempty(mdfPath)
                mdfPath = '';
                runSI = false;
                showConfig = false;
                hWb = [];
                hSI = [];
                
                %find last mdf
                classPrivatePath = most.util.className('most.HasMachineDataFile','classPrivatePath');
                classNameShort   = most.util.className('most.HasMachineDataFile','classNameShort');
                classDataFileName = fullfile(classPrivatePath, [classNameShort '_classData.mat']);
                if exist(classDataFileName, 'file')
                    try
                        e = load(classDataFileName);
                        mdfPath = e.lastMachineDataFilePath;
                    catch
                    end
                end
                
                if ~exist(mdfPath, 'file')
                    a = questdlg(['A previously loaded machine data file was not found. If this is the first time running '...
                        'ScanImage, a machine data file must be created. Select "create" to do this now or select "browse"'...
                        ' to locate an existing machine data file.'],'ScanImage','Create...','Browse...','Cancel','Create...');
                    
                    switch a
                        case 'Create...'
                            [mdfPath, hWb] = scanimage.guis.StartupConfig.newMdf('MicroscopeMDF.m');
                            if isempty(mdfPath)
                                return;
                            end
                            usrPath = '.usr';
                            showConfig = true;
                            
                        case 'Browse...'
                            [mdffile, mdfpath] = uigetfile('*.m','Select machine data file...');
                            if isequal(mdffile,0) || isequal(mdfpath,0)
                                return;
                            end
                            mdfPath = fullfile(mdfpath,mdffile);
                            
                        case 'Cancel'
                            return;
                    end
                end
            end
            
            if nargin < 2 || isempty(usrPath)
                usrPath = '';
            end
            
            obj = scanimage.guis.StartupConfig(mdfPath, usrPath, showConfig, hWb);
            
            waitfor(obj.hFig);
            
            mdfPath = obj.mdfPath;
            usrPath = obj.usrPath;
            runSI = obj.runSI;
            hWb = obj.hStartWb;
            hSI = obj.hSI;
            
            if runSI
                obj.setClassDataVar('lastUsrFile',usrPath);
                most.HasMachineDataFile.updateMachineDataFile(mdfPath);
                fprintf('%s\n',scanimage.SI.version());
%                 disp(['Machine Data File: <a href="matlab: edit ''' mdfPath '''">' mdfPath '</a>']);
            end
            
            delete(obj);
        end
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
