function [hSI_,hSICtl_] = scanimage(mdf,usr,varargin)
    % SCANIMAGE     starts ScanImage application and its GUI(s)
    %
    %   It places two variables in the base workspace.
    %   hSI is a scanimage.SI object that gives access to the operation and
    %   configuration of the microscope.  hSICtl gives access to the user
    %   interface elements.  There is implicit synchronization between the
    %   microscope configuration and the user interface, so most of the time,
    %   hSICtl can be safely ignored.
    %
    %   See also scanimage.SI and scanimage.SIController

    if nargout > 0
        hSI_ = [];
        hSICtl_ = [];
    end

    hidegui = false;

    scanimage.util.checkSystemRequirements();

    if nargin > 0 && ~isempty(mdf)
        assert(logical(exist(mdf,'file')), 'Specified machine data file not found on disk: ''%s''',mdf);
    else
        mdf = '';
    end

    if nargin > 1 && ~isempty(usr)
        assert(logical(exist(usr,'file')), 'Specified usr file not found on disk: ''%s''',usr);
    else
        usr = '';
    end

    if nargin > 2
        for i = 3:nargin
            if ischar(varargin{i}) && strcmp(varargin{i}, '-hidegui')
                hidegui = true;
            end
        end
    end

    hResourceStore = [];
    hSI = [];
    hSICtl = [];

    if dabs.resources.ResourceStore.isInstantiated()
        hResourceStore = dabs.resources.ResourceStore();
        hSI = hResourceStore.filterByClass(siClassName);

        if isempty(hSI)
            hSI = [];
        else
            hSI = hSI{1};
            assignin('base','hSI',hSI);

            if ~isempty(hSI.hController)
                hSICtl = hSI.hController{1};
                assignin('base','hSICtl',hSICtl);
            end
        end
    else
        try
            scanimage.fpga.vDAQ_SI.checkHardwareSupport();
        catch ME
            warndlg(ME.message,'ScanImage');
            return;
        end
    end
    
    hLM = scanimage.util.private.LM();

    if isempty(hSI)
        if isempty(mdf)
            [mdf,usr,runSI,hWb,hSI] = scanimage.guis.StartupConfig.doModalConfigPrompt(mdf,usr);
        else
            runSI = true;
            hSI = [];
            hWb = waitbar(0,'Starting ScanImage');
        end
        
        if ~runSI
            reset();
            return
        end

        waitbar(.15,hWb,'Initializing ScanImage engine');
        try
            hSI = reinitSI(mdf,hSI);

            if most.idioms.isValidObj(hWb)
                waitbar(0.3,hWb,'Initializing user interface');
            end

            hSICtl = instantiateSICtl(usr,hidegui,hWb,hSI);
            hLM.log();
        catch ME
            hLM.log([],[],ME);
            most.idioms.safeDeleteObj(hWb);
            most.ErrorHandler.logAndReportError(ME, 'ScanImage startup failed: %s', ME.message);
            return;
        end
        most.idioms.safeDeleteObj(hWb);

    elseif isempty(hSICtl)
        try
            hSICtl = instantiateSICtl(usr,hidegui,[],hSI);
            hLM.log();
        catch ME
            hLM.log([],[],ME);
            most.ErrorHandler.logAndReportError(ME, 'ScanImage GUI startup failed: %s', ME.message);
            return;
        end
    else
        most.idioms.warn('ScanImage is already running.');
        evalin('base','hSICtl.raiseAllGUIs')
    end

    if nargout > 0
        hSI_ = hSI;
        hSICtl_ = hSICtl;
    end
end

%% Local functions
function v = siClassName()
v = 'scanimage.SI';
end

function hSI = reinitSI(mdf,hSI)
    try
        fprintf('Initializing ScanImage engine...\n');
        
        if ~most.idioms.isValidObj(hSI)
            assert(scanimage.SI.isMdfCompatible(mdf),'Machine Data File is not compabtible with ScanImage');
            hResourceStore = dabs.resources.ResourceStore();
            hResourceStore.instantiateFromMdf(mdf);
            hSI = hResourceStore.filterByClass(siClassName);
            
            assert(~isempty(hSI),'ScanImage is not configured.');
            hSI = hSI{1};
        end
        
        assignin('base','hSI',hSI);
        hSI.reinit();

        fprintf('ScanImage engine initialized.\n');
    catch ME
        reset();
        rethrow(ME);
    end
end

function hSICtl = instantiateSICtl(usr,hidegui,hWb,hSI)
    if nargin < 1 || isempty(usr)
        usr = '';
    end

    if nargin < 2 || isempty(hidegui)
        hidegui = false;
    end

    if nargin < 3
        hWb = [];
    end

    if nargin < 4
        hSI = [];
    end

    try
        fprintf('Initializing user interface...\n');

        if isempty(hSI)
            hResourceStore = dabs.resources.ResourceStore();
            hResourceStore.instantiateFromMdf();
            hSI = hResourceStore.filterByClass(siClassName);
            
            assert(~isempty(hSI),'ScanImage is not configured.');
            hSI = hSI{1};
        end

        assert(hSI.mdlInitialized,'ScanImage is not initialized.');

        hSICtl = scanimage.SIController(hSI,hWb);
        assignin('base','hSICtl',hSICtl);

        hSICtl.initialize(usr,hidegui);

        fprintf('User interface initialized.\n');
    catch ME
        reset();
        rethrow(ME);
    end
end

function reset()
    if dabs.resources.ResourceStore.isInstantiated()
        hResourceStore = dabs.resources.ResourceStore();
        hSI = hResourceStore.filterByClass(siClassName);
        if ~isempty(hSI)
            delete(hSI{1});
        end
        hResourceStore.delete();
    end

    hMdf = most.MachineDataFile.getInstance();
    hMdf.unload()

    clear('hSI','hSICtl');
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
