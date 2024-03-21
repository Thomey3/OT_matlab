function checkSystemRequirements()
%% Validate 64bit Matlab and Windows is required
assert(strcmp(computer('arch'),'win64'), ...
    'ScanImage:InvalidArchitecture', ...
    'Error: ScanImage requires Matlab 64bit on Windows 64bit. This computer architecture is %s.',computer('arch'));

%% Validate minimum required SI version is Matlab 2017a
assert(~verLessThan('matlab','9.2.0'), ...
    'ScanImage:InvalidMatlabVersion', ...
    'Error: ScanImage requires Matlab 2017a or later. This Matlab version is %s.',regexprep(getfield(ver('matlab'),'Release'),'[\(\)]',''));

%% Check for multiple scanimage versions on path
scanimageInstallationPaths = which('scanimage','-all');
if numel(scanimageInstallationPaths) > 1
    msgbox('Multiple ScanImage installations were found on the path.','Error','error');
    folders = strjoin(scanimageInstallationPaths,'\n\t');
    error( ...
        'ScanImage:AmbiguousInstallPath', ...
        ['Multiple ScanImage installations were found on the path:\n' ...
        '\t%s\nRemove the redundant instances from the path and restart Matlab.'], ...
        folders);
end

%% Check duplicate gui folders
mainControls = which('mainControlsV4','-all');
invalidDirMask = ~ismember(mainControls,fullfile(scanimage.util.siRootDir,'guis','mainControlsV4.m'));
if any(invalidDirMask)
    msgbox('Multiple ScanImage GUI folders were found on the path.','Error','error');
    folders = strjoin(mainControls(invalidDirMask),'\n\t');
    error( ...
        'ScanImage:AmbiguousGUIPath', ...
        ['Multiple ScanImage installations were found on the path:\n' ...
        '\t%s\nRemove the redundant instances from the path and restart Matlab.'], ...
        folders);
end

%% Check License registry
missingDllErrorId = 'ScanImage:License:MissingDll';
try
    dllUri = winqueryreg('HKEY_LOCAL_MACHINE', ...
        'SOFTWARE\Classes\CLSID\{0012593E-4A7F-4494-AA24-0F293A86DC1D}\InprocServer32', ...
        'CodeBase');
    % If the dll is registered by another executable, we're actually okay
    % with that since only that version can actually be registered.
    % The only time we want to register the dll
    assert(2 == exist(dllUri, 'file'), missingDllErrorId, ...
        ['License DLL is not registered. This error should not be visible. ' ...
        'Please contact support at support@mbfbioscience.com']);
catch ME
    regQueryMissingKeyErrorId = 'MATLAB:WINQUERYREG:invalidkey';
    if any(strcmp(ME.identifier, {regQueryMissingKeyErrorId, missingDllErrorId}))
        registerDllCommandPath = fullfile(scanimage.util.siRootDir(), ...
            '+scanimage', '+util', '+private', 'private', 'QLMRegister.cmd');
        system(registerDllCommandPath);
        pause(0.5);
        try
            winqueryreg('HKEY_LOCAL_MACHINE', ...
                'SOFTWARE\Classes\CLSID\{0012593E-4A7F-4494-AA24-0F293A86DC1D}\InprocServer32', ...
                'CodeBase');
        catch ME
            error('ScanImage:License:RegistrationRequired', ...
                'Registering the DLL for license use is required for ScanImage usage.');
        end
    else
        rethrow(ME);
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
