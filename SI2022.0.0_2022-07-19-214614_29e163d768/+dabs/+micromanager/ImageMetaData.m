classdef ImageMetaData < handle
    properties (Dependent)
        Camera
        ElapsedTime_ms
        Height
        ImageNumber
        PixelType
        StartTime_ms
        TimeReceivedByCore
        Width
    end
    
    properties (SetAccess = immutable, Hidden)
        mmMetadata
    end
    
    properties (SetAccess = private)
        metaDataStruct = [];
    end
    
    %% Lifecycle
    methods
        function obj = ImageMetaData(mmMetadata)
            obj.mmMetadata = mmMetadata;
        end
    end
    
    %% Internal methods
    methods (Access = private)        
        function deserializeMetadata(obj)
            if ~isempty(obj.metaDataStruct)
                % decoding is a performance bottleneck. only decode on first access
                return
            end
            
            import('mmcorej.Metadata');
            metaKeys = obj.mmMetadata.GetKeys();
            obj.metaDataStruct = struct();
            for iKeys=0:metaKeys.size()-1
                key = metaKeys.get(iKeys);
                try
                    sanitizedKey = str2validName(char(key));
                    obj.metaDataStruct.(sanitizedKey) = char(obj.mmMetadata.GetSingleTag(key).GetValue());
                catch ME
                    % invalid property name.  Ignored.
                    if ~strcmp(ME.identifier, 'MATLAB:assertion:failed')
                        rethrow(ME);
                    end
                end
            end
        end
    end
    
    %% Property Getter/Setter
    methods
        function val = get.Camera(obj)
            obj.deserializeMetadata();
            val = obj.metaDataStruct.Camera;
        end
        
        function val = get.ElapsedTime_ms(obj)
            obj.deserializeMetadata();
            val = str2double(obj.metaDataStruct.ElapsedTime_ms);
        end
        
        function val = get.Height(obj)
            obj.deserializeMetadata();
            val = str2double(obj.metaDataStruct.Height);
        end
        
        function val = get.ImageNumber(obj)
            obj.deserializeMetadata();
            val = str2double(obj.metaDataStruct.ImageNumber);
        end
        
        function val = get.PixelType(obj)
            obj.deserializeMetadata();
            val = obj.metaDataStruct.PixelType;
        end
        
        function val = get.StartTime_ms(obj)
            obj.deserializeMetadata();
            val = obj.metaDataStruct.StartTime_ms;
        end
        
        function val = get.TimeReceivedByCore(obj)
            obj.deserializeMetadata();
            val = obj.metaDataStruct.TimeReceivedByCore;
        end
        
        function val = get.Width(obj)
            obj.deserializeMetadata();
            val = str2double(obj.metaDataStruct.Width);
        end
    end
end


%% Local methods
function valid = str2validName(propname)
    valid = propname;
    if isvarname(valid) && ~iskeyword(valid)
        return;
    end

    % general regex /[a-zA-Z]\w*/
    %find all alphanumeric and '_' characters
    valididx = isstrprop(valid, 'alphanum');
    valididx(strfind(valid, '_')) = true;

    % replace all invalid characters with '_' for now
    valid(~valididx) = '_';

    isUnfixable = isempty(valid) || ~isstrprop(valid(1), 'alpha') || iskeyword(valid);
    assert(~isUnfixable, '`%s` cannot be converted to a valid name', propname);
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
