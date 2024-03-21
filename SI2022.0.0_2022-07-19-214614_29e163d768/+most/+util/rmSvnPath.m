% rmSvnPath - Remove the ridiculous Subversion nonsense from the path (Storing meta-data with the real data is a stupid scheme!!!).
%
% SYNTAX
%  rmSvnPath
%
% NOTES
%  Since the idiots who wrote Subversion decided to store the meta-data with the actual data, it tends
%  to get added to the Matlab path (using the 'Add with Subfolders...' button in the 'Set Path' GUI).
%  This function will scrub all the "hidden" Subversion (.svn) directories and their children from the path.
%
%  IMPORTANT: The cleaned path will be saved and rehashed. If you actually wanted those directories,
%             they will be sort of permanently be gone from the path. But you don't want them anyway.
%
%  Remember kids, do not store your meta-data with your actual data, that's just dumb.
%
% CHANGES
%  TO021910A - Changed the comparison from '\.svn\' to '\.svn', to do a more thorough cleaning. -- Tim O'Connor 2/19/10
%  TO030210A - Added extra print statements to indicate saving of the path and completion. -- Tim O'Connor 3/2/10
%  Ben Suter 2010-03-23 - Added optional argument "verbose", since don't want to see each removal notice when running this on each startup
% Created 7/29/08 - Tim O'Connor
% Copyright - Cold Spring Harbor Laboratories/Howard Hughes Medical Institute 2008
function rmSvnPath(varargin)

if ~isempty(varargin)
    verbose = varargin{1};
else
    verbose = true;
end

pathStr = path;
while ~isempty(pathStr)
    [currentPathItem, pathStr] = strtok(pathStr, ';');
    if ~isempty(strfind(lower(currentPathItem), '\.svn'))
        if verbose
            fprintf(1, 'rmSvnPath - Removing ''%s'' from path...\n', currentPathItem);
        end
        rmpath(currentPathItem);
    %else
    %    fprintf(1, 'rmSvnPath - Retaining ''%s'' in path...\n', currentPathItem);
    end
end

fprintf(1, 'rmSvnPath - Saving the modified path...\n');%TO030210A
savepath
rehash path

fprintf(1, 'rmSvnPath - Finished.\n');%TO030210A

return;




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
