classdef Logging < scanimage.interfaces.Class
    properties (SetAccess = private, Hidden)
        hLinScan;
        hTifs;
        
        hMetaFile;
        hPmtFile;
        hScannerFile;
        
        active = false;
        
        fileCounter;
        fileFrameCounter;
        fileSubCounter;
        
        blankFrameDescription;
        
        stripeBuffer = [];
        
        tempFrameBuffer = {[]};
        avgFrameBuffer = {[]};
        
        mRoiLogging = false;
        linesPerFrame;
        pixelsPerLine;
        isLineScan;
        channelSave;
        numChannelSave;
        
        useJson;
    end
    
    properties (SetAccess = private)
%    properties (Dependent, SetAccess = private)
       bitsPerSample;
       dataSigned;
       castFrameData;  % This is the cast used to assure the image (frame) data is corrently passed to the Mex TiffStream
    end
    
    properties (Constant)
        FRAME_DESCRIPTION_LENGTH = 2000; % same value as in ResScan       
    end
    
    %% Lifecycle
    methods
        function obj = Logging(hLinScan)
            obj.hLinScan = hLinScan;
            obj.blankFrameDescription = repmat(' ',1,obj.FRAME_DESCRIPTION_LENGTH);
        end
        
        function delete(obj)
            obj.deinit();
        end
        
        function deinit(obj)
            obj.abort();
            obj.closeFiles(); % forces all open file handles to be closed
        end
        
        function reinit(obj)
            obj.deinit();
            % no further action
        end
    end
    
    methods
        function start(obj)
            obj.active = false;
            obj.closeFiles();
            
            if ~obj.hLinScan.hSI.hChannels.loggingEnable;return;end
            if isempty(obj.hLinScan.hSI.hChannels.channelSave);return;end
            
            obj.fileCounter = obj.hLinScan.logFileCounter;
            obj.fileFrameCounter = 0;
            obj.fileSubCounter = 0;
            obj.channelSave = obj.hLinScan.hSI.hChannels.channelSave;
            obj.numChannelSave = numel(obj.channelSave);
            obj.isLineScan = obj.hLinScan.hSI.hRoiManager.isLineScan;
            
            obj.stripeBuffer = [];
            obj.tempFrameBuffer = repmat({[]},1,obj.numChannelSave);
            obj.avgFrameBuffer = obj.tempFrameBuffer;
                        
            %Placing this logic here because this is originally don in the
            %TifStream.m constructor. The dataSigned and bitsPerSample are
            %needed by the new TiffStream.configureImage() method.
            switch obj.hLinScan.channelsDataType
                case 'uint8'
                    obj.dataSigned    = false;
                    obj.bitsPerSample = 8;
                    obj.castFrameData = @uint8;
                case 'int8'
                    obj.dataSigned    = true;
                    obj.bitsPerSample = 8;
                    obj.castFrameData = @int8;
                case 'uint16'
                    obj.dataSigned    = false;
                    obj.bitsPerSample = 16;
                    obj.castFrameData = @uint16;
                case 'int16'
                    obj.dataSigned    = true;
                    obj.bitsPerSample = 16;
                    obj.castFrameData = @int16;
                case 'uint32'
                    obj.dataSigned    = false;
                    obj.bitsPerSample = 32;
                    obj.castFrameData = @uint32;
                case 'int32'
                    obj.dataSigned    = true;
                    obj.bitsPerSample = 32;
                    obj.castFrameData = @int32;
                otherwise
                    error('TifStream: Unsupported datatype: ''%s''',obj.dataType);
            end %switch
            
            if obj.isLineScan
                % create and write metadata file
                obj.hMetaFile = fopen(obj.makeFullFilePath([],'.meta.txt'),'w+t');
                assert(obj.hMetaFile > 0, 'Failed to create log file.');
                dat = char(obj.hLinScan.tifHeaderData');
                dat(obj.hLinScan.tifRoiDataStringOffset) = sprintf('\n');
                fprintf(obj.hMetaFile,'%s\n',dat(obj.hLinScan.tifHeaderStringOffset+1:end-1));
                fclose(obj.hMetaFile);
                obj.hMetaFile = [];
                
                % write mat file with reference images
                if ~isempty(obj.hLinScan.hSI.hController) && isprop(obj.hLinScan.hSI.hController{1}, 'hRoiGroupEditor')
                    hRGE = obj.hLinScan.hSI.hController{1}.hRoiGroupEditor;
                    
                    vis = [hRGE.hContextImages.visible];
                    vis(1) = false;
                    if sum(vis)
                        contextImageLuts = {hRGE.hContextImages(vis).luts};
                        contextImageZs = {hRGE.hContextImages(vis).zs};
                        contextImageRoiCPs = {hRGE.hContextImages(vis).roiCPs};
                        contextImageImgs = {hRGE.hContextImages(vis).imgs};
                        contextImageChans = {hRGE.hContextImages(vis).channels};
                        contextImageChanSel = [hRGE.hContextImages(vis).channelSelIdx];
                        
                        save(obj.makeFullFilePath([],'.ref.dat'), 'contextImageLuts', 'contextImageZs',...
                            'contextImageRoiCPs', 'contextImageImgs', 'contextImageChans', 'contextImageChanSel');
                    end
                end
                
                % create binary pmt data file
                obj.hPmtFile = fopen(obj.makeFullFilePath([],'.pmt.dat'),'w+');
                
                % create galvo logging file
                if obj.hLinScan.recordScannerFeedback
                    obj.hScannerFile = fopen(obj.makeFullFilePath([],'.scnnr.dat'),'w+');
                end
            else
                zs=obj.hLinScan.hSI.hStackManager.zs; % generate planes to scan based on motor position etc
                roiGroup = obj.hLinScan.currentRoiGroup;
                scanFields = arrayfun(@(z)roiGroup.scanFieldsAtZ(z),...
                    zs,'UniformOutput',false);
                
                obj.mRoiLogging = false;
                cumPixelResolutionAtZ = zeros(0,2);
                for zidx = 1:length(scanFields)
                    sfs = scanFields{zidx};
                    pxRes = zeros(0,2);
                    for sfidx = 1:length(sfs)
                        sf = sfs{sfidx};
                        pxRes(end+1,:) = sf.pixelResolution(:)';
                    end
                    obj.mRoiLogging = obj.mRoiLogging || size(pxRes,1) > 1;
                    cumPixelResolutionAtZ(end+1,:) = [max(pxRes(:,1)), sum(pxRes(:,2))];
                end
                
                obj.mRoiLogging = obj.mRoiLogging || any(cumPixelResolutionAtZ(1,1) ~= cumPixelResolutionAtZ(:,1));
                obj.mRoiLogging = obj.mRoiLogging || any(cumPixelResolutionAtZ(1,2) ~= cumPixelResolutionAtZ(:,2));
                obj.linesPerFrame = max(cumPixelResolutionAtZ(:,2));
                obj.pixelsPerLine = max(cumPixelResolutionAtZ(:,1));
                
                sf = scanFields{1}{1};
                resDenoms = 2^30 ./ (1e4 * sf.pixelResolutionXY ./ (sf.sizeXY * obj.hLinScan.hSI.objectiveResolution));
                
                xResolutionNumerator = 2^30;
                xResolutionDenominator = resDenoms(1);
                yResolutionNumerator = 2^30;
                yResolutionDenominator = resDenoms(2);
                
                obj.useJson = obj.hLinScan.hSI.useJsonHeaderFormat;
                
                % create TifStream objects
                if obj.hLinScan.logFilePerChannel
                    obj.hTifs = cell(1,obj.numChannelSave);
                    for i = 1:obj.numChannelSave
                        
                        chan = obj.channelSave(i);
                        obj.hTifs{i} = scanimage.components.scan2d.TiffStream;
                        assert(obj.hTifs{i}.open(obj.makeFullFilePath(chan),obj.hLinScan.tifHeaderData,obj.hLinScan.tifHeaderStringOffset,obj.hLinScan.tifRoiDataStringOffset), 'Failed to create log file.');
                        obj.hTifs{i}.configureImage(obj.pixelsPerLine, obj.linesPerFrame, (obj.bitsPerSample/8), 1, obj.dataSigned,...
                            obj.blankFrameDescription, xResolutionNumerator, xResolutionDenominator, yResolutionNumerator, yResolutionDenominator);
                        
                        %        obj.hTifs{i} = scanimage.components.scan2d.linscan.TifStream(obj.makeFullFilePath(chan),...
                        %            obj.pixelsPerLine, obj.linesPerFrame, obj.blankFrameDescription,...
                        %            'dataType',obj.hLinScan.channelsDataType,'overwrite',true);
                        
                        
                    end
                else
                    obj.hTifs = cell(1,1);
                    
                    obj.hTifs{1} = scanimage.components.scan2d.TiffStream;
                    assert(obj.hTifs{1}.open(obj.makeFullFilePath,obj.hLinScan.tifHeaderData,obj.hLinScan.tifHeaderStringOffset,obj.hLinScan.tifRoiDataStringOffset), 'Failed to create log file.');
                    obj.hTifs{1}.configureImage(obj.pixelsPerLine, obj.linesPerFrame, (obj.bitsPerSample/8), obj.numChannelSave, obj.dataSigned,...
                        obj.blankFrameDescription, xResolutionNumerator, xResolutionDenominator, yResolutionNumerator, yResolutionDenominator);
                    
                    %    obj.hTifs{1} = scanimage.components.scan2d.linscan.TifStream(obj.makeFullFilePath,...
                    %        obj.pixelsPerLine, obj.linesPerFrame, obj.blankFrameDescription,...
                    %        'dataType',obj.hLinScan.channelsDataType,'overwrite',true);
                end
            end
            
            obj.active = true;
        end
        
        function logScannerFdbk(obj,data)            
            if ~obj.active;return;end
            fwrite(obj.hScannerFile, data', 'single');
        end
        
        function logStripe(obj,stripeData)            
            if ~obj.active;return;end
            
            if obj.isLineScan
                fwrite(obj.hPmtFile, stripeData.rawData(:,ismembc2(obj.channelSave,stripeData.channelNumbers))', 'int16');
                obj.fileFrameCounter = obj.fileFrameCounter + numel(stripeData.frameNumberAcq);
                
                newFileFlag = false;
                
                if obj.fileFrameCounter >= obj.hLinScan.logFramesPerFile
                    obj.fileSubCounter = obj.fileSubCounter + 1;
                    newFileFlag = true;
                end
                
                if stripeData.endOfAcquisition && ~stripeData.endOfAcquisitionMode
                    obj.fileCounter = obj.fileCounter + 1;
                    obj.fileSubCounter = 0;
                    newFileFlag = true;
                end
                
                if newFileFlag
                    obj.newFile();
                end
            else % frame Scan
                if stripeData.startOfFrame && stripeData.endOfFrame
                    obj.stripeToDisk(stripeData);
                else
                    assert(~obj.mRoiLogging,'Something bad happened: trying to save a partial frame (''stripe'') while logging mroi data. This is not allowed.');
                    % striped frame coming in
                    if stripeData.startOfFrame
                        obj.stripeBuffer = copy(stripeData); % If start of frame buffer is just a direct copy of first stripe
                    else % ... other wise add new stripe to buffer
                        newStripe = copy(stripeData); % memory copy of entire frame for every stripe -> not good for performance
                        newStripe.merge(obj.stripeBuffer); % newStripe now contains current stripe data and data that was in stripeBuffer
                        obj.stripeBuffer = newStripe; % Update stripeBuffer to reflect addition of new stripe
                    end
                    
                    if stripeData.endOfFrame % If end of frame send it to disk
                        obj.stripeToDisk(obj.stripeBuffer);
                    end
                end
            end
        end
        
        function stripeToDisk(obj,stripeData)
            % write frames to disk
            obj.fileFrameCounter = obj.fileFrameCounter + 1;
            
            frameDescription = sprintf('%s\n',stripeData.getFrameDescription(obj.useJson));
            
            dummyFrame = isempty(stripeData.roiData);
            % if true this is a flyback frame. fill with dummy data so that
            % file has expected number of frames
            
            for i = 1:obj.numChannelSave % write for all channels, stripeData includes image data for all saved channels. 
                chanNum = obj.channelSave(i);

                if obj.hLinScan.logFilePerChannel
                    fileIndex = i;
                else
                    fileIndex = 1;
                end
                
                if ~dummyFrame
                    chIdx = find(stripeData.roiData{1}.channels == chanNum,1,'first');
                end
                
                obj.hTifs{fileIndex}.replaceImageDescription(frameDescription);
                %obj.hTifs{fileIndex}.imageDescription = frameDescription;
                
                imageSize = obj.pixelsPerLine * obj.linesPerFrame * (obj.bitsPerSample/8);
                
                if obj.mRoiLogging
                    line = 1;
                    tempbuf = zeros(obj.pixelsPerLine,obj.linesPerFrame,obj.hLinScan.channelsDataType);
                    for roiIdx = 1:length(stripeData.roiData)
                        imdata = stripeData.roiData{roiIdx}.imageData{chIdx}{1};
                        dims = size(imdata);
                        tempbuf(1:dims(1),line:line+dims(2)-1) = imdata;
                        line = line + dims(2);
                    end
                    
                    obj.hTifs{fileIndex}.appendFrame(obj.castFrameData(tempbuf), imageSize);
                    
                    %obj.hTifs{fileIndex}.appendFrame(tempbuf,true);
 
                else   % Averaging Code           
                    if obj.hLinScan.logAverageFactor > 1
                        if dummyFrame
                            % this should not happen. dummy frame should
                            % only be possible in fastz with flyback frames
                            % enabled. In this case, logAverageFactor must
                            % be 1
                            error('This shouldn''t happen.');
                        end
                        
                        if mod(obj.fileFrameCounter,obj.hLinScan.logAverageFactor)== 0 %Nth frame
                            % Add this frame to the temp frame buffer
                            obj.tempFrameBuffer{i}{end+1} = int32(stripeData.roiData{1}.imageData{chIdx}{1});
                            % Avg the first N frames from temp frame buffer
                            avgFrame = [];
                            for k = 1:obj.hLinScan.logAverageFactor
                                if isempty(avgFrame)
                                    avgFrame = obj.tempFrameBuffer{i}{k};
                                else
                                    avgFrame = avgFrame + obj.tempFrameBuffer{i}{k};
                                end
                            end
                            avgFrame = avgFrame/cast(obj.hLinScan.logAverageFactor,'like',obj.tempFrameBuffer{i}{end});
                            % Add avg frame to the avgFrameBuffer
                            obj.avgFrameBuffer{i}{end+1} = avgFrame;
                            % Empty the Temp frame buffer
                            obj.tempFrameBuffer{i} = [];
                            
                            % Write averages frame to tiff
                            obj.hTifs{fileIndex}.appendFrame(obj.castFrameData(avgFrame), imageSize);
                            
                        else
                            obj.tempFrameBuffer{i}{end+1} = int32(stripeData.roiData{1}.imageData{chIdx}{1}); % add incoming frame data to temp buffer
                        end

                    else
                        if dummyFrame
                            dat = zeros(obj.pixelsPerLine,obj.linesPerFrame,obj.hLinScan.channelsDataType);
                        else
                            dat = obj.castFrameData(stripeData.roiData{1}.imageData{chIdx}{1});
                        end
                        obj.hTifs{fileIndex}.appendFrame(dat, imageSize);
                    end
                end
            end

            % determine if file is split after this frame
            newFileFlag = false;
            sliceFileSplit = false;
            
            % Stack Logic separated because previously fastZ only acquired
            % 1 frame per slice so it was easier/more predictable.
            % Additionally FastZ stripes do not seem to set the
            % endOfAcquisition flag to true at the end of slices.
            
            % FastZ logic
            if obj.hLinScan.hSI.hStackManager.isFastZ
                % Handle File Splitting mid acquisition
                if obj.hLinScan.logAverageFactor > 1
                    % Split according to num averaged frames
                    if numel(obj.avgFrameBuffer{i}) > 0 && mod(numel(obj.avgFrameBuffer{i}),obj.hLinScan.logFramesPerFile)== 0
                        obj.fileSubCounter = obj.fileSubCounter + 1;
                        newFileFlag = true;
                        obj.avgFrameBuffer{i} = [];
                    else
                        newFileFlag = false;
                    end
                else
                    % Split based on raw frame count
                    if obj.fileFrameCounter >= obj.hLinScan.logFramesPerFile
                        obj.fileSubCounter = obj.fileSubCounter + 1;
                        newFileFlag = true;
                    else
                        newFileFlag = false;
                    end
                end
                
                % New file on end of acquisition always.
                if stripeData.endOfAcquisition && ~stripeData.endOfAcquisitionMode
                        obj.fileCounter = obj.fileCounter + 1;
                        obj.fileSubCounter = 0;
                        newFileFlag = true;
                        obj.avgFrameBuffer{i} = [];
                end
            
            % SlowZ logic
            elseif obj.hLinScan.hSI.hStackManager.isSlowZ
                % Handle Split points differently when averaging                
                if obj.hLinScan.logAverageFactor > 1
                    % Split based on num averaged froms
                    if numel(obj.avgFrameBuffer{i}) > 0 && mod(numel(obj.avgFrameBuffer{i}),obj.hLinScan.logFramesPerFile)== 0
                        % Split point reached, but the
                        % stripeData.endOfAcqusition will also be true at
                        % the end of slices. So lets let the end of acq
                        % logic handle flile splitting if the framesPerFile
                        % limit is reached at the end of an acq to avoid
                        % double incrementing counters. However we will set
                        % a split flag to let us know that based on frame
                        % count we should be splitting.
                        sliceFileSplit = true;
                        if ~stripeData.endOfAcquisition
                        % You are in the middle of an acquisition so split
                        % this up into a sub file.
                            obj.fileSubCounter = obj.fileSubCounter + 1;
                            newFileFlag = true;
                            obj.avgFrameBuffer{i} = [];
                        end
                    end
                else
                    % Split based on raw frame counter
                    if obj.fileFrameCounter >= obj.hLinScan.logFramesPerFile
                        obj.fileSubCounter = obj.fileSubCounter + 1;
                        newFileFlag = true;
                    end
                end
                
                % stripeData.endOfAcquisition is true at the end of slices.
                % Must check whether this is actually the end of
                % acquisition or wether it is just the end of a slice
                if stripeData.endOfAcquisition && ~stripeData.endOfAcquisitionMode
                    % Check to see if last slice.
                    if obj.hLinScan.hSI.hStackManager.volumesDone >= obj.hLinScan.hSI.hStackManager.actualNumVolumes
                        % It is the last slice so create a new acq file, not sub file. 
                        obj.fileCounter = obj.fileCounter + 1;
                        obj.fileSubCounter = 0;
                        newFileFlag = true;
                        obj.avgFrameBuffer{i} = [];
                    else
                        % Not the last slice so just the end of the current
                        % slice. Check is frame counting indicated that we
                        % should split file into subfiles
                        if sliceFileSplit
                            obj.fileSubCounter = obj.fileSubCounter + 1;
                            newFileFlag = true;
                            obj.avgFrameBuffer{i} = [];
                        else
                            newFileFlag = false;
                        end
                        
                    end
                end
                
            % Not a stack    
            else
                if ~stripeData.endOfAcquisition
                    % Handle Split points differently when averaging                
                    if obj.hLinScan.logAverageFactor > 1
                        if numel(obj.avgFrameBuffer{i}) > 0 && mod(numel(obj.avgFrameBuffer{i}),obj.hLinScan.logFramesPerFile)== 0
                            obj.fileSubCounter = obj.fileSubCounter + 1;
                            newFileFlag = true;
                            obj.avgFrameBuffer{i} = [];
                        else
                            newFileFlag = false;
                        end
                    else
                        if obj.fileFrameCounter >= obj.hLinScan.logFramesPerFile
                            obj.fileSubCounter = obj.fileSubCounter + 1;
                            newFileFlag = true;
                        else
                            newFileFlag = false;
                        end
                    end
                    
                end
                
                if stripeData.endOfAcquisition && ~stripeData.endOfAcquisitionMode
                    obj.fileCounter = obj.fileCounter + 1;
                    obj.fileSubCounter = 0;
                    newFileFlag = true;
                    obj.avgFrameBuffer{i} = [];
                end
            end

            % Regardless of everything else if you have reached the end of
            % an acquistion mode (loop, grab) do NOT create a new file.
            if stripeData.endOfAcquisitionMode
                newFileFlag = false;
                obj.avgFrameBuffer{i} = [];
            end
  
            if newFileFlag
                obj.newFile();
            end
            
        end
        
        function newFile(obj)
            if ~obj.active;return;end
            
            obj.fileFrameCounter = 0;
            
            if obj.isLineScan
                if ~isempty(obj.hPmtFile)
                    fclose(obj.hPmtFile);
                    obj.hPmtFile = [];
                end

                if ~isempty(obj.hScannerFile)
                    fclose(obj.hScannerFile);
                    obj.hScannerFile = [];
                end
                
                obj.hPmtFile = fopen(obj.makeFullFilePath([],'.pmt.dat'),'w+');
                
                % create galvo logging file
                if obj.hLinScan.recordScannerFeedback
                    obj.hScannerFile = fopen(obj.makeFullFilePath([],'.scnnr.dat'),'w+');
                end
            else
                if obj.hLinScan.logFilePerChannel
                    for i = 1:obj.numChannelSave
                        chan = obj.channelSave(i);
                        
                        if ~obj.hTifs{i}.newFile(obj.makeFullFilePath(chan))
                            obj.hLinScan.abort();
                            error('Failed to create log file.');
                        end
                    end
                else
                    if ~obj.hTifs{1}.newFile(obj.makeFullFilePath())
                        obj.hLinScan.abort();
                        error('Failed to create log file.');
                    end
                end
            end
        end
        
        function abort(obj)            
            obj.closeFiles();
            obj.active = false;
        end
    end
    
    methods (Access = private)
        function closeFiles(obj)
            if ~isempty(obj.hMetaFile) && obj.hMetaFile > 0
                fclose(obj.hMetaFile);
            end
            obj.hMetaFile = [];
            
            if ~isempty(obj.hPmtFile) && obj.hPmtFile > 0
                fclose(obj.hPmtFile);
            end
            obj.hPmtFile = [];
            
            if ~isempty(obj.hScannerFile) && obj.hScannerFile > 0
                fclose(obj.hScannerFile);
            end
            obj.hScannerFile = [];
            
            if ~isempty(obj.hTifs)
                for i = 1:length(obj.hTifs)
                    try
                        hTif = obj.hTifs{i};
                        if ~isempty(hTif) && isvalid(hTif)
                            hTif.close();
                            hTif.cleanUp();
                        end
                    catch ME
                        most.ErrorHandler.logAndReportError(ME);
                    end
                end
            end
            obj.hTifs = {};
        end
        
        function fullPath = makeFullFilePath(obj,channelNum,ext)
            if nargin < 2
                channelNum = [];
            end
            if nargin < 3
                ext = '.tif';
            end
            
            stringFileCounter = sprintf('_%05u',obj.fileCounter);
            
            % No extra number if Inf
            if isinf(obj.hLinScan.logFramesPerFile)
                stringFileSubCounter = '';
            else
                stringFileSubCounter = sprintf('_%05u',obj.fileSubCounter+1);
            end
            
            if isempty(channelNum)
                stringChannelNum = '';
            else
                stringChannelNum = sprintf('_chn%u',channelNum);
            end
            
            fileName = [obj.hLinScan.logFileStem stringFileCounter stringFileSubCounter stringChannelNum ext];   % extension is NOT automatically appended by TifStream
            fullPath = fullfile(obj.hLinScan.logFilePath,fileName);
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
