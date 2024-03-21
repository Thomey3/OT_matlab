classdef GenericSLM < dabs.resources.devices.SLM & dabs.resources.configuration.HasConfigPage & most.HasMachineDataFile
    %%% ABSTRACT PROPERTY REALIZATIONS (most.HasMachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'Generic SLM';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
        
        mdfDefault = defaultMdfSection();
    end
    
    properties (SetAccess = protected,Hidden)
        ConfigPageClass = 'dabs.resources.configuration.resourcePages.GenericSLMPage';
    end
    
    methods (Static)
        function names = getDescriptiveNames()
            names = {'SLM\Generic Monitor SLM'};
        end
    end
    
    %%% Abstract property realizations (scanimage.mroi.scanners.SLM)
    properties (Constant)
        queueAvailable = false;
    end
    
    properties (SetObservable)
        monitorID = 5;
    end
    
    %%% Class specific properties
    properties (SetAccess = private, GetAccess = private)
        hDisp = [];
    end
    
    %% LifeCycle
    methods
        function obj = GenericSLM(name)
            obj@dabs.resources.devices.SLM(name);
            obj@most.HasMachineDataFile(true);
            
            obj.pixelBitDepth = 8;
            obj.computeTransposedPhaseMask = true;
            
            obj.deinit();
            obj.loadMdf();
            obj.reinit();
        end
        
        function delete(obj)
            obj.deinit();
        end
        
        function deinit(obj)
            obj.writeZeros();
            most.idioms.safeDeleteObj(obj.hDisp);
            obj.errorMsg = 'uninitialized';
        end
        
        function reinit(obj)
            obj.deinit();
            
            try
                obj.hDisp = dabs.generic.FullScreenDisplay(obj.monitorID);
                obj.errorMsg = '';
                obj.writeZeros();
            catch ME
                obj.deinit();
                obj.errorMsg = sprintf('%s: initialization error: %s',obj.name,ME.message);
                most.ErrorHandler.logError(ME,obj.errorMsg);
            end
        end
        
        function loadMdf(obj)
            success = true;
            success = success & obj.safeSetPropFromMdf('monitorID', 'monitorID');
            success = success & obj.safeSetPropFromMdf('pixelResolutionXY', 'pixelResolutionXY');
            success = success & obj.safeSetPropFromMdf('pixelPitchXY', 'pixelPitchXY', @(v)v/1e6); % conversion from microns to meter
            success = success & obj.safeSetPropFromMdf('maxRefreshRate', 'maxRefreshRate');
            
            if ~success
                obj.errorMsg = 'Error loading config';
            end
        end
        
        function saveMdf(obj)
            obj.safeWriteVarToHeading('monitorID',         obj.monitorID);
            obj.safeWriteVarToHeading('pixelResolutionXY', obj.pixelResolutionXY);
            obj.safeWriteVarToHeading('pixelPitchXY',      obj.pixelPitchXY * 1e6); % conversion from meter to microns
            obj.safeWriteVarToHeading('maxRefreshRate',    obj.maxRefreshRate);
        end
    end
    
    %% User Methods
    methods
        function writeBitmap(obj,phaseMaskRaw,waitForTrigger)
            if nargin < 3 || isempty(waitForTrigger)
                waitForTrigger = false;
            end
            
            assert(~waitForTrigger,'%s does not support external triggering',obj.name);
            
            sz = size(phaseMaskRaw);
            if obj.computeTransposedPhaseMask
                assert(sz(1)==obj.pixelResolutionXY(1) && sz(2)==obj.pixelResolutionXY(2),'Tried to send phase mask of wrong size to SLM');
            else
                assert(sz(1)==obj.pixelResolutionXY(2) && sz(2)==obj.pixelResolutionXY(1),'Tried to send phase mask of wrong size to SLM');
            end
            
            obj.hDisp.updateBitmap(phaseMaskRaw,obj.computeTransposedPhaseMask);
            obj.lastKnownBitmap = phaseMaskRaw;
        end
        
        function writeZeros(obj)
            if isempty(obj.errorMsg) && most.idioms.isValidObj(obj.hDisp)
                try
                    blankImage = zeros(obj.pixelResolutionXY(1),obj.pixelResolutionXY(2),'uint8');
                    obj.writeBitmap(blankImage);
                catch
                end
            end
        end
    end
    
    methods (Access = protected)
        function resizeSlmQueue(obj,length)
            error('Unsupported');
        end
        
        function writeSlmQueue(obj,frames,frameOutputIdxs)
            error('Unsupported');
        end
        
        function startSlmQueue(obj)
            error('Unsupported');
        end
        
        function abortSlmQueue(obj)
            error('Unsupported');
        end
    end
    
    methods
        function set.monitorID(obj,val)
            validateattributes(val,{'numeric'},{'positive','scalar','integer'});
            obj.deinit();
            obj.monitorID = val;
        end
    end
end

function s = defaultMdfSection()
s = [...
    most.HasMachineDataFile.makeEntry('monitorID',5,'Numeric: SLM monitor ID (1 is the main monitor)')...
    most.HasMachineDataFile.makeEntry('pixelResolutionXY',[1920,1080],'[x,y] pixel resolution of SLM')...
    most.HasMachineDataFile.makeEntry('pixelPitchXY',[6.4 6.4],'[1x2 numeric] distance from pixel center to pixel center in microns')...
    most.HasMachineDataFile.makeEntry()...
    most.HasMachineDataFile.makeEntry('maxRefreshRate',60)...
    ];
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
