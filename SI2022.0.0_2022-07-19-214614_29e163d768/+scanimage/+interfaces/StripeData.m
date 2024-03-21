classdef StripeData < handle & matlab.mixin.Copyable
    % class defining image data
    properties
        frameNumberAcqMode;         % numeric, number of frame, counted from beginning of acquisition mode
        frameNumberAcq;             % numeric, number of frame in current acquisition
        acqNumber;                  % numeric, number of current acquisition
        stripeNumber;               % numeric, number of stripe within the frame
        stripesRemaining;           % numeric, number of unprocessed stripes in queue
        totalAcquiredFrames;
        zIdx;                       % numeric, zIdx of frame in current zSeries
        zSeries;                    % numeric, zSeries of current acquisition
        
        startOfFrame = true;        % logical, true if first stripe of frame
        endOfFrame = true;          % logical, true if last stripe of frame
        endOfAcquisition;           % logical, true if endOfFrame and last frame of acquisition
        endOfAcquisitionMode;       % logical, true if endOfFrame and end of acquisition mode
        startOfVolume = false;      % logical, true if start of volume
        endOfVolume = false;        % logical, true if start of volume
        overvoltage;                % logical, true if overvoltage was detected on any of the active channels during an acquisition mode
        
        epochAcqMode;               % string, time of the acquisition of the acquisiton of the first pixel in the current acqMode; format: output of datestr(now) '25-Jul-2014 12:55:21'
        frameTimestamp;             % [s] time of the first pixel in the frame passed since acqModeEpoch
        
        acqStartTriggerTimestamp;   % [s] time of the acq start trigger for the current acquisition
        nextFileMarkerTimestamp;    % [s] time of the last nextFileMarker recorded. NaN if no nextFileMarker was recorded
        
        channelNumbers;             % 1D array of active channel numbers for the current acquisition
        rawData;                    % Raw data samples
        rawDataStripePosition;      % Raw data samples start position
        roiData;                    % 1D cell array of type scanimage.mroi.RoiData
        transposed = true;
        
        motionMatrix = eye(4);      % 4x4 matrix for estimating 3D motion
    end
    
    methods
        function obj = StripeData()
        end
        
        function obj = castRoiData(obj,newType)
            for iterRoi = 1:length(obj.roiData)
               obj.roiData{iterRoi}.castImageData(newType); 
            end
        end
        
        function obj = multiplyRoiData(obj,factor)
            for iterRoi = 1:length(obj.roiData)
               obj.roiData{iterRoi}.multiplyData(factor); 
            end
        end
                
        function merge(obj,hStripeData)
            if isempty(hStripeData) || isempty(hStripeData.roiData) || (obj.startOfFrame && obj.endOfFrame)
                return
            end
            
            if isempty(obj.roiData)
                obj.roiData = hStripeData.roiData;
            else
                for iterRoi = 1:length(obj.roiData)
                    obj.roiData{iterRoi}.merge(hStripeData.roiData{iterRoi});
                end
            end
        end
                
        function mergeIn(obj,newStripeData)
            obj.stripeNumber = newStripeData.stripeNumber;
            obj.stripesRemaining = newStripeData.stripesRemaining;
            obj.endOfFrame = newStripeData.endOfFrame;
            obj.endOfVolume = newStripeData.endOfFrame;
            obj.totalAcquiredFrames = newStripeData.totalAcquiredFrames;
            
            obj.endOfAcquisition = obj.endOfAcquisition ||newStripeData.endOfAcquisition;
            obj.endOfAcquisitionMode = obj.endOfAcquisitionMode ||newStripeData.endOfAcquisitionMode;
            obj.overvoltage = obj.overvoltage ||newStripeData.overvoltage;
        
            if isempty(obj.acqStartTriggerTimestamp)
                obj.acqStartTriggerTimestamp = newStripeData.acqStartTriggerTimestamp;
            end
            if isempty(obj.nextFileMarkerTimestamp)
                obj.nextFileMarkerTimestamp = newStripeData.nextFileMarkerTimestamp;
            end
            
            for i = 1:numel(obj.roiData)
                obj.roiData{i}.mergeIn(newStripeData.roiData{i});
            end
        end
        
        function resetData(obj)            
            for iterRoi = 1:length(obj.roiData)
                obj.roiData{iterRoi}.resetData();
            end
        end
        
        function resetDataToZero(obj)
            for iterRoi = 1:length(obj.roiData)
                obj.roiData{iterRoi}.resetDataToZero();
            end
            
        end
        
        function val = getFrameDescription(obj,useJson)
            if nargin < 2 || isempty(useJson)
                useJson = false;
            end
            
            assert(~isempty(obj.endOfFrame) && obj.endOfFrame,'image description only available at end of frame');
            
            if useJson
                s = ['{\n  "frameNumbers": %d,\n',...
                    '  "acquisitionNumbers": %d,\n',...
                    '  "frameNumberAcquisition": %d,\n',...
                    '  "frameTimestamps_sec": %f,\n',...
                    '  "acqTriggerTimestamps_sec": %f,\n',...
                    '  "nextFileMarkerTimestamps_sec": %f,\n',...
                    '  "endOfAcquisition": %d,\n',...
                    '  "endOfAcquisitionMode": %d,\n',...
                    '  "dcOverVoltage": %d,\n',...
                    '  "epoch": %s\n}'];
            else
                s = ['frameNumbers = %d\n',...
                    'acquisitionNumbers = %d\n',...
                    'frameNumberAcquisition = %d\n',...
                    'frameTimestamps_sec = %f\n',...
                    'acqTriggerTimestamps_sec = %f\n',...
                    'nextFileMarkerTimestamps_sec = %f\n',...
                    'endOfAcquisition = %d\n',...
                    'endOfAcquisitionMode = %d\n',...
                    'dcOverVoltage = %d\n',...
                    'epoch = %s'];
            end
            
            if isempty(obj.acqStartTriggerTimestamp)
                stt = 0;
            else
                stt = obj.acqStartTriggerTimestamp;
            end
            
            if isempty(obj.nextFileMarkerTimestamp)
                ntt = 0;
            else
                ntt = obj.nextFileMarkerTimestamp;
            end
            
            val = sprintf(s,...
                obj.frameNumberAcqMode,...
                obj.acqNumber,...
                obj.frameNumberAcq,...
                obj.frameTimestamp,...
                stt, ntt,...
                obj.endOfAcquisition,...
                obj.endOfAcquisitionMode,...
                false,...
                strrep(mat2str(datevec(obj.epochAcqMode),5),' ',','));
        end
    end
    
    methods(Access = protected)
        % Override copyElement method:
        function cpObj = copyElement(obj)
            % Make a shallow copy of all properties
            cpObj = copyElement@matlab.mixin.Copyable(obj);
            % Make a deep copy of the DeepCp object
            for idx = 1:length(obj.roiData)
                cpObj.roiData{idx} = copy(obj.roiData{idx});
            end
        end
    end
    
    methods
        function set.acqNumber(obj,val)
            obj.acqNumber = val;
            for idx = 1:length(obj.roiData)
                obj.roiData{idx}.acqNumber = val;
            end
        end
        
        function set.frameNumberAcqMode(obj,val)
            obj.frameNumberAcqMode = val;
            for idx = 1:length(obj.roiData)
                obj.roiData{idx}.frameNumberAcqMode = val;
            end
        end
        
        function set.frameNumberAcq(obj,val)
            obj.frameNumberAcq = val;
            for idx = 1:length(obj.roiData)
                obj.roiData{idx}.frameNumberAcq = val;
            end
        end
        
        function set.frameTimestamp(obj,val)
            obj.frameTimestamp = val;
            for idx = 1:length(obj.roiData)
                obj.roiData{idx}.frameTimestamp = val;
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
