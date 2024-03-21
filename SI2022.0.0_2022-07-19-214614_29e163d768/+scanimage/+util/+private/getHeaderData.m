function [fileHeader, frameDescs] = getHeaderData(tifObj)
% Returns a cell array of strings for each TIFF header
% If the number of images is desired one can call numel on frameStringCell or use the 
% second argument (the latter approach is preferrable)
%
    switch class(tifObj)
        case 'Tiff'
            [fileHeaderStr,frameDescs] = getHeaderDataFromTiff(tifObj);
        case 'scanimage.util.ScanImageTiffReader'
            [fileHeaderStr,frameDescs] = getHeaderDataFromScanImageTiffObj(tifObj);
        otherwise
            error('Not a valid Tiff object: ''%s''',class(tifObj));
    end
    
    [fileHeaderStr, frameDescs] = checkForLegacyFileFormat(fileHeaderStr,frameDescs);
    
    try
        if fileHeaderStr(1) == '{'
            s = most.json.loadjson(fileHeaderStr);
            
            %known incorrect handling of channel luts!
            n = size(s.SI.hChannels.channelLUT,1);
            c = cell(1,n);
            for i = 1:n
                c{i} = s.SI.hChannels.channelLUT(i,:);
            end
            s.SI.hChannels.channelLUT = c;
            
            fileHeader.SI = s.SI;
        else
            % legacy style
            fileHeaderStr = strrep(fileHeaderStr, 'scanimage.SI.','SI.');
            rows = textscan(fileHeaderStr,'%s','Delimiter','\n');
            rows = rows{1};
            
            for idxLine = 1:numel(rows)
                if strncmp(rows{idxLine},'SI.',3)
                    break;
                end
            end
            
            fileHeader = scanimage.util.private.decodeHeaderLines(rows(idxLine:end));
        end
    catch
        fileHeader = struct();
    end
end

function [fileHeaderStr,frameDescs] = getHeaderDataFromTiff(tifObj)
    numImg = 0;

    % Before anything else, see if the tiff file has any image-data
    try
        %Parse SI from the first frame
        numImg = 1;
        while ~tifObj.lastDirectory()
            tifObj.nextDirectory();
            numImg = numImg + 1;
        end
    catch
        warning('The tiff file may be corrupt.')
        % numImg will have the last valid value, so we can keep going and 
        % deliver as much data as we can
    end
    tifObj.setDirectory(1);

    %Make sure the tiff file's ImageDescription didn't go over the limit set in 
    %Acquisition.m:LOG_TIFF_HEADER_EXPANSION
    try
        if ~isempty(strfind(tifObj.getTag('ImageDescription'), '<output truncated>'))
            most.idioms.warn('Corrupt header data');
            return;
        end
    catch
        most.idioms.warn('Corrupt or incomplete tiff header');
        return
    end

    frameDescs = cell(1,numImg);
    
    % This will crash if more than 65535 frames -> int16 limitation in Tiff
    % library for directory count. If numImg > 65535,
    % tifObj.currentDirectory returns 65535 when on that directory (from
    % nextDirectory command) and tifObj.lastDirectory returns false
    % indicating this is not the last image. However subsequent calls to
    % nextDirectory cause this to roll over - i.e. when you call
    % currentDirectory it will be 0. Oddly this only seems to crash in this
    % function. The same lines in a command window script seemt to work
    % fine.
    for idxImg = 1:numImg
%         fprintf('idxImg: %d of %d\n', idxImg, numImg);
        frameDescs{1,idxImg} = tifObj.getTag('ImageDescription');
        if idxImg == numImg
%             disp('Break condition met');
            break;
        end  % Handles last case
%         evalin('base', 'clc');
        tifObj.nextDirectory();
    end
    
    try
        fileHeaderStr = tifObj.getTag('Software');
    catch
        % legacy style
        fileHeaderStr = frameDescs{1};
    end
end

function [fileHeaderStr,frameDescs] = getHeaderDataFromScanImageTiffObj(tifObj)
frameDescs = tifObj.descriptions();
isemptyMask = cellfun(@(d)isempty(d),frameDescs);
frameDescs(isemptyMask) = [];

fileHeaderStr = tifObj.metadata();
end

function [fileHeader, frameDescs] = checkForLegacyFileFormat(fileHeader,frameDescs)
if ~isempty(frameDescs)
    fD = frameDescs{1};
    if ~isempty(strfind(fD,'scanimage.SI.TIFF_FORMAT_VERSION'))
        % we got an old Tiff file, where the fileHeader and frameDescs are
        % combined in the frameDescs. we need to separate them out
        frameDescs = regexp(frameDescs,'\n(?=scanimage.SI.TIFF_FORMAT_VERSION)','split');
        frameDescs = vertcat(frameDescs{:});
        fileHeader = frameDescs{1,2};
        frameDescs = frameDescs(:,1);
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
