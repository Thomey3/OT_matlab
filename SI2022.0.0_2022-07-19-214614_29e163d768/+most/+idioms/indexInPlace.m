function x = indexInPlace(x,filter)
    % indexing into an array creates a memory copy of the array, which is
    % inefficient for large arrays
    % x = x(1:10,:,[2 4])                   % creates a copy of x
    % x = indexInPlace(x,{1:10,':',[2 4]})  % indexes in place

    validateattributes(filter,{'cell'},{'vector','numel',numel(size(x))});    
    final_size = cellfun(@(f,sz)most.idioms.ifthenelse(strcmpi(f,':'),sz,numel(f)),filter,num2cell(size(x)));
    assert(prod(final_size) <= numel(x),'The number of elements in the output array needs to be smaller or equal the number of elements in the input array.');
    
    blocks = findContiguousMemory(x,filter);
    
    if size(blocks,2) == 1 && ...
       blocks(1,1) == 1 && blocks(2,1) == numel(x)
        
        % x is already of correct shape
        return
    end
    
    write_idx = 0;
    for block_idx = 1:size(blocks,2)
        read_start = blocks(1,block_idx);
        read_end   = blocks(2,block_idx);
        for read_idx = read_start:read_end
            write_idx = write_idx+1;
            x(write_idx) = x(read_idx);
        end
    end
    
    % this still allocates. is there a way to truncate an existing array
    % with out making a copy?
    %x(w+1:end) = []; % truncate array
    x = x(1:write_idx);
    x = reshape(x,final_size);
end

function blocks = findContiguousMemory(x,filter)

% find contiguous blocks in filter
for dimIdx = 1:length(filter)
   f = filter{dimIdx};
   if strcmpi(f,':')
       filter{dimIdx} = [1;size(x,dimIdx)];
   elseif ~isempty(f)
       d = diff(f);
       dIdxs = find(d~=1);
       dIdxs = dIdxs(:)';
       idxs = [horzcat(1,dIdxs);horzcat(dIdxs,numel(f))];
       idxs = reshape(f(idxs),size(idxs));
       filter{dimIdx} = idxs;
   end
end

% get contiguous memory blocks
blocks = getMemIdxs(zeros(2,0),filter);
end

function blocks = getMemIdxs(blocks,filter)

f = filter{end};

if length(filter) == 1
    blocks = f;
else
    idxs_ = getMemIdxs(blocks,filter(1:end-1));
    for idx = 1:size(f,2)
        blocks = horzcat(blocks,bsxfun(@times,idxs_,f(:,idx))); %#ok<AGROW>
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
