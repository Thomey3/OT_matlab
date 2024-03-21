classdef TipTilt < dabs.resources.Device & most.HasMachineDataFile & dabs.resources.configuration.HasConfigPage & dabs.resources.widget.HasWidget
    %% ABSTRACT PROPERTY REALIZATIONS (most.HasMachineDataFile) 
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = '';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
        
        mdfDefault = defaultMdfSection();
    end
    
    properties (SetAccess = protected,Hidden)
        ConfigPageClass = 'dabs.resources.configuration.resourcePages.BlankPage';
    end
    
    properties (SetAccess=protected)
        WidgetClass = 'dabs.resources.widget.widgets.TipTiltWidget';
    end
    
    methods (Static)
        function names = getDescriptiveNames()
            names = {'TipTilt'};
        end
    end
    
    properties (SetObservable, SetAccess = private)
        tip  = 0;
        tilt = 0;
    end
    
    properties (SetAccess = private, GetAccess = private)
        hListeners = event.listener.empty();
        hResourceStoreListener = event.listener.empty();
        hSI = dabs.resources.Resource.empty();
    end
    
    %% Lifecycle
    methods
        function obj = TipTilt(name)
            obj@dabs.resources.Device(name);
            obj = obj@most.HasMachineDataFile(true);
            
            obj.hResourceStoreListener = most.ErrorHandler.addCatchingListener(obj.hResourceStore,'hResources','PostSet',@(varargin)obj.resourcesChanged);
            
            obj.deinit();
            obj.reinit();
        end
        
        function delete(obj)
            obj.deinit();
            most.idioms.safeDeleteObj(obj.hResourceStoreListener);
        end
    end
    
    %% Initialization
    methods
        function reinit(obj)
            try
                obj.deinit();
                
                hSI_ = obj.hResourceStore.filterByClass('scanimage.SI');
                
                assert(~isempty(hSI_),'ScanImage is not initialized');
                obj.hSI = hSI_{1};
                
                obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hSI,'fieldCurvatureTip' ,'PostSet',@(varargin)obj.tipTiltchanged);
                obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hSI,'fieldCurvatureTilt','PostSet',@(varargin)obj.tipTiltchanged);
                obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hSI,'ObjectBeingDestroyed',@(varargin)obj.deinit);
                
                obj.errorMsg = '';
                
            catch ME
                obj.deinit();
                obj.errorMsg = sprintf('%s: initialization error: %s',obj.name,ME.message);
                most.ErrorHandler.logError(ME,obj.errorMsg);
            end
        end
        
        function deinit(obj)
            obj.errorMsg = 'Uninitialized';
            
            delete(obj.hListeners);
            obj.hListeners = event.listener.empty();
            
            obj.hSI = dabs.resources.Resource.empty();
        end
    end
    
    %% Internal methods
    methods
        function tipTiltchanged(obj)
            % UI update only
            obj.tip  = obj.hSI.fieldCurvatureTip;
            obj.tilt = obj.hSI.fieldCurvatureTilt;
        end
        
        function resourcesChanged(obj)
            % if uninitialized, try to attach to ScanImage
            if ~isempty(obj.errorMsg)
                obj.reinit();
            end
        end
        
        function updateWaveforms(obj)
            if most.idioms.isValidObj(obj.hSI)
                hFastZ = obj.hSI.hFastZ.currentFastZs;
                if isempty(hFastZ)
                    return
                end
                
                hFastZ = hFastZ{1};
                z = hFastZ.targetPosition;
                
                force = true;
                obj.hSI.hFastZ.move(hFastZ,z,force); % this recalculates waveforms and performs liveUpdate
            end
        end
    end
    
    %% Public methds
    methods
        function changeTip(obj,val)
            obj.assertNoError();
            obj.hSI.fieldCurvatureTip = round(val,6);
            obj.updateWaveforms();
        end
        
        function changeTilt(obj,val)
            obj.assertNoError();
            obj.hSI.fieldCurvatureTilt = round(val,6);
            obj.updateWaveforms();
        end
        
        function changeTipTilt(obj,tip,tilt)
            obj.assertNoError();
            obj.hSI.fieldCurvatureTip  = round( tip,6);
            obj.hSI.fieldCurvatureTilt = round(tilt,6);
            obj.updateWaveforms();
        end
    end
end

function s = defaultMdfSection()
s = most.HasMachineDataFile.makeEntry('Nothing to configure');
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
