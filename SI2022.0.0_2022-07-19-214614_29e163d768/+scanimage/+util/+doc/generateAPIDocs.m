function generateAPIDocs(dir2Doc, shouldStripHref)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%GENERATEAPIDOCS Generates the API documentation for scanimage
% Performs a recursive search for .m files through all the directories starting from the
% current Matlab directory.  Uses the function saveHtmlDoc to produce HTML
% files for the .m files.  Function processDir starts from the current root
% directory and descends through the directory tree to make the cell array
% mFileList which contains all m file names and their locations.  This
% program requires jsoup.jar so that the function parserHtml will work.
% jsoup-1.11.3.jar is in a private folder that gets added more-or-less
% automatically to the java class path.  Hopefully, it doesn't conflict with
% anything.
% generateAPIDocs depends on scanimage\+scanimage\+util\+doc\DocGenExcludedDIRS.txt
% which contains the list of directories to exclude in the document
% generation process.
%
%
% You may need to change the following in order to get things to work:
%
% In dabs.ni.daqmx.private.DAQmxClass.m (line 1).  Change:
%
%       classdef DAQmxClass < most.APIWrapper & most.PDEPPropDynamic
%
% to
%
%       classdef DAQmxClass < handle
%
% run the documentation generator and then change things back.  The above
% solution provided a clue about the origin of the problem.  When the HTML
% documentation for AIChan.m is being produced, the handle to the
% instantiation of the class is lost.  The handle is lost because a which
% statement appears to alter the class and reset the handles.  It was noted
% that if the class was instantiated on the matlab command line before
% running generateAPIDocs.m then the error does not happen.  By
% instantiating the AIChan class at the beginning of this program in the
% base space, the error can also be prevented.
% Perhaps Mathworks will automagically do it for us one day.
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if nargin < 1 || isempty(dir2Doc)
    dir2Doc = fileparts(which('scanimage'));
    shouldStripHref = true;
end

if isempty(shouldStripHref)
    shouldStripHref = true;
end

assert(~isempty(dir2Doc),...
        ['Change directories to the ScanImage directory or specify the directory you '...
        'want to document on the command line.']);

% Sets the path to Jsoup for the HTML parsing functions
jsoupPath = fullfile(fileparts(mfilename('fullpath')), 'private', 'jsoup-1.11.3.jar');
javaaddpath(jsoupPath);

% Instantiates the AIChan class so an error is prevented in the document
% generation process.  See comments above for more details.
evalin('base', 'hChan = dabs.ni.daqmx.AIChan;');

% Read in directories to eliminate from document generation
scanimageLocation = fileparts(which('scanimage'));
docLocation = fullfile(scanimageLocation, '+scanimage', '+util', '+doc');
excludeDirLocation = fullfile(docLocation, 'DocGenExcludedDIRS.txt');

assert(2 == exist(excludeDirLocation, 'file'),...
    'The exclusion file DocGenExcludedDIRS.txt does not exist in directory `%s`',...
    docLocation);

% +scanimage\+util\+doc\DocGenExcludedDIRS.txt
% contains the list of directories to exclude.
fileId = fopen(excludeDirLocation);
excludedDirs = textscan(fileId, '%s', 'Delimiter', '\n');
excludedDirs = excludedDirs{1};
fclose(fileId);

% Get current root directory folder name.  Must start program in the
% directory where you want to generate docs
rootDir = dir2Doc;
docDir = fullfile(rootDir ,'docs'); % Contains the directory name for the HTML documents to be stored

% The resulting cell array mFileList contains all .m file names and
% file locations

MFiles = processDir(rootDir, docDir, [], excludedDirs);

assert(~isempty(MFiles),...
    ['There seems to be no .m files in the directory that you selected for document '...
    'generation']);

%% Generate html documents
% All .m files are passed to saveHtmlDoc with their location
for i = 1:numel(MFiles)
    saveHtmlDoc(MFiles(i).folder, MFiles(i).name, shouldStripHref);
end

evalin('base','clear hChan');
end

% This function recursively descends through the directory tree searching
% for .m files.
function MFileList = processDir(rootDir, docDir, MFileList, excludedDirs)
Children = dir(rootDir); % rootDir becomes child directory names as the descent happens

% Remove excluded directories from the dirList
childNames = {Children.name};
iExcludedChildren = ismember(childNames, excludedDirs);

Children = Children(~iExcludedChildren);
childNames = childNames(~iExcludedChildren);
iChildDirs = logical([Children.isdir]);
iChildMFiles = false(size(childNames));

if isempty(Children)
    return;
end

% find all child files that end in '.m'
for i = 1:length(childNames)
    [~, ~, ext] = fileparts(childNames{i});
    iChildMFiles(i) = strcmp(ext, '.m');
end

% handle edge case where directory has the `.m` extension.
try
    iChildMFiles = iChildMFiles & ~iChildDirs; 
catch
    keyboard;
end

if 0 == mkdir(docDir)
    most.idioms.warn('Error creating documentation directory');
    return;
end

% populate file list with name and location
MFiles = Children(iChildMFiles);
for i = 1:length(MFiles)
    MFiles(i).folder = docDir;
end

if ~isempty(MFiles)
    if isempty(MFileList)
        MFileList = MFiles;
    else
        MFileList = [MFileList; MFiles];
    end
end

% process child directories recursively
childDirNames = childNames(iChildDirs);
subDirs = fullfile(rootDir, childDirNames);
subDocDirs = fullfile(docDir, childDirNames);
subDocDirs = strrep(subDocDirs, '+', '');
subDocDirs = strrep(subDocDirs, '@', '');
for i = 1:length(childDirNames)
    MFileList = processDir(subDirs{i}, subDocDirs{i}, MFileList, excludedDirs);
end
end

function saveHtmlDoc(rootDir, docName, shouldStripHref)
%   saves the html file corresponding to the docs/help call on docName
%   assumes the directory 'docs' exists within rootDir.  All document
%   directories are made in the processDir function.
%

directoryNames = strsplit(rootDir, filesep);
iDocsDir = find(strcmp(directoryNames, 'docs'), 1);

assert(~isempty(iDocsDir), 'Missing docs directory in rootDir!');

directoryPath = directoryNames(iDocsDir+1:end);
if isempty(directoryPath)
    directoryPathLeaf = '';
else
    directoryPathLeaf = directoryPath{end};
end

rawDocName = strrep(docName, '.m', '');
if strcmp(directoryPathLeaf, rawDocName)
    directoryPath{end} = rawDocName;
else
    directoryPath{end+1} = rawDocName;
end

fullDocName = strjoin(directoryPath, '.');
% fullDocName = strrep(fullDocName, '+', '');
fprintf('Creating--%s...\n', fullDocName);

% HAX (ngc)
% Need to keep an extra reference to the metaclass (when applicable).
% Eventually most.idioms.gendochtml calls some internal Matlab code
% that ends up touching the source file that defines the class.  This
% causes the class to reload invalidating the metaclass reference that
% is being passed around.  Without the following block of code, there
% is no other metaclass reference and so the reference being passed
% around gets invalidated midstream.  By keeping a reference here,
% we ensure the metaclass stays alive even after the class reload.
% mc=[]; %#ok<NASGU>
% % may not need this section because of evalin near the top of the code.
% try % not all fullDocNames correspond to a class name
%     mc = metaclass(fullDocName);
% catch
% end

[~, html] = most.util.doc.gendochtml(fullDocName); % create HTML
if shouldStripHref
    % process HTML to remove links if noHref is true
    html = stripHtml(html); 
end

htmlName = strrep(docName, '.m', '.html');
fid = fopen(fullfile(rootDir, htmlName), 'W'); % open HTML files
fprintf(fid, '%s', html); % write file
fclose(fid); % close file
end

function htmlOut = stripHtml(htmlIn)
% This function removes hrefs and other links.
objJsoup = org.jsoup.Jsoup.parse(htmlIn); % creates a Jsoup object to process HTML
objJsoup.select('a').unwrap(); % removes hrefs
objJsoup.select('table[width=100%]').remove(); % removes links to code and Matlab help
htmlOut = char(objJsoup.toString());
end

%--------------------------------------------------------------------------%
% generateAPIDocs.m                                                        %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%




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
