classdef ScanImageTiffReader < handle
    % ScanimageTiffReader provides fast access to the data in ScanImage Tiff.
    %
    % ScanImage stores different kinds of metadata.  Configuration data and
    % frame-varying data are stored in the image description tags
    % associated with each image plane in the Tiff.  Additionally, we store
    % some metadata in another data block within the tiff.  This metadata
    % is usually a binary-blob that encodes data that needs to be
    % interpreted by scanimage.    
    
    properties(Access=private)
        h_ % A pointer to the internal file context.
    end
    
	methods(Static)
		function out=apiVersion()
			out=mexScanImageTiffReaderAPIVersion;
		end
	end

    methods
        function obj=ScanImageTiffReader(filename)
            % obj=ScanimageTiffReader(filename)
            % Opens the file
            obj.h_=uint64(0);
            if(nargin>0)
                open(obj,filename);
            end
        end
        
        function delete(obj)
            % delete(obj)
            % Closes the file.
            close(obj);
        end
        
        function obj=open(obj,filename)
            % obj=open(filename)
            % Opens the file.  If this object already refers to an open
            % file, it is closed before opening the new one.
            if obj.h_
                close(obj)
            end
            
            assert(2 == exist(filename, 'file'), 'File %s not found on disk.', filename);
            
            listing = dir(filename);
            absoluteFilename = fullfile(listing.folder, listing.name);
            
            % Check if filename is ambiguous and may be the wrong file.
            % since files are not guaranteed to be on the path, it's fine
            % if which returns an empty cell array as we've already
            % verified that the file still exists.
            files = which(filename, '-all');
            assert(isempty(files) || isscalar(files), ['File path %s is ambiguous. '...
                'Cannot decide on multiple files found on path. Please use an absolute path.'],...
                filename);
            
            obj.h_=mexScanImageTiffOpen(absoluteFilename);
        end
                      
        function obj=close(obj)
            % obj=open(filename)
            % Closes the file.
            if(~obj.h_), return; end
            h=obj.h_;
            obj.h_=uint64(0);
            mexScanImageTiffClose(h);
        end
        
        function tf=isOpen(obj)
            % tf=isOpen(obj)
            % returns true if the file is open, otherwise false.
            tf=obj.h_~=0;
        end
        
        function desc=descriptions(obj)
            % desc=descriptions(obj)
            % Returns the image description for each frame in a cell array.
            ensureOpen(obj);
            desc=mexScanImageTiffImageDescriptions(obj.h_);
        end
        
        function desc=metadata(obj)
            % desc=metadata(obj)
            % Returns the metadata as a byte string
            ensureOpen(obj);
            desc=mexScanImageTiffMetadata(obj.h_);
        end
        
        function stack=data(obj)
            % stack=data(obj)
            % Returns the data in the tiff as a stack.
            ensureOpen(obj);
            stack=mexScanImageTiffData(obj.h_);
        end
    end
    
    methods(Access=private)
        function ensureOpen(obj)
            if(~obj.h_)
                error('File is not open for reading.');
            end
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
