classdef Camera < dabs.resources.Device & dabs.resources.widget.HasWidget
    %% Camera
    %
    % Defines a common interface for all cameras.
    %
    
    properties (SetAccess=protected)
        WidgetClass = 'dabs.resources.widget.widgets.CameraWidget';
    end
    
    %% Abstract properties
    properties (Abstract, SetObservable)
        cameraExposureTime;                             % Numeric indicating the current exposure time of a camera.
    end
    
    properties (Abstract, Constant)
        isTransposed;                                   % Boolean indicating whether camera frame data is column-major order (false) OR row-major order (true)
    end
    
    properties (Hidden, SetObservable)
        datatype; % dabs.resources.devices.camera.Datatype indicating camera pixel type.
    end
    
    properties (SetObservable, SetAccess = protected)
        availableDatatypes; % NOTE: this property is technically constant but must be SetObservable for uicontrol listeners.
    end
    
    properties (Abstract, SetAccess = private, SetObservable)
        isAcquiring;                                    % Boolean indicating whether a bufferd continuous acquisition is active.
        resolutionXY;                                   % Numeric array [X Y] indicating the resolution of returned frame data.
    end
    
    properties (SetObservable, SetAccess = protected)
        lastAcquiredFrame;
    end
    
    %% Camera properties
    properties (SetAccess = immutable)
        cameraName;                                     % String indicating the name of the camera.
    end
    
    %% LIFECYCLE METHODS
    methods
        %% Constructor
        function obj = Camera(name)
            obj@dabs.resources.Device(name);
            obj.cameraName = name;
        end
    end
    
    %% ABSTRACT METHODS
    methods (Abstract)
        %% start(obj)
        %
        % Abstract function to begin a continuous buffered acquisition of
        % frames from the camera. Specifics to be implemented in subclass.
        %
        start(obj)
        
        %% stop(obj)
        %
        % Abstract function to stop a continuous buffered acquisition of
        % frames from the camera if currently active. Specifics to be
        % implemented in subclass.
        %
        stop(obj)
    end
    
    methods (Abstract, Access=protected)
        %% snap(obj)
        %
        % Abstract private function which returns a single frame's data.
        % Called by obj.snapshot().  Details are implementation-specific
        %
        img = snap(obj)
        
        %% flushQueue(obj)
        %
        % Abstract protected function which clears the internal queue.
        % Called by obj.flush().  Details are implementation-specific.
        %
        flushQueue(obj)
        
        %% grabFrames(obj)
        %
        % Abstract function which returns a cell array of multiple queued frame data.
        % Optionally returns an array of metadata structs as the second return value.
        % Acquisition and metadata details are implementation-specific.
        %
        [data, meta] = grabFrames(obj)
    end
    
    methods
        function dt = get.datatype(obj)
            dt = obj.getDatatypeFilter(obj.datatype);
        end
        
        function set.datatype(obj, val)
            newval = obj.setDatatypeFilter(val);
            if isa(newval, 'dabs.resources.devices.camera.Datatype')
                obj.datatype = val;
            else
                obj.datatype = dabs.resources.devices.camera.Datatype(newval);
            end
        end
    end
    
    methods
        function img = snapshot(obj)
            assert(~obj.isAcquiring,...
                '`%s` cannot snapshot while acquiring.', obj.cameraName);
            img = obj.snap();
            
            if ~isempty(img)
                obj.lastAcquiredFrame = img;
            end
        end
        
        function flush(obj)
            assert(obj.isAcquiring,...
                '`%s` cannot flush camera queue when not acquiring.', obj.cameraName);
            obj.flushQueue();
        end
        
        function [data, meta] = getAcquiredFrames(obj)
            assert(obj.isAcquiring,...
                '`%s` cannot get frames if camera is not acquiring.', obj.cameraName);
            [data, meta] = obj.grabFrames();
        end
        
        function value = setDatatypeFilter(obj, value)
            %% SETDATATYPECALLBACK optional validation for setting datatype callbacks.
        end
        
        function value = getDatatypeFilter(obj, value)
            %% GETDATATYPECALLBACK optional validation for getting datatype callbacks.
        end
    end
        
    %% INTERNAL METHODS
    methods(Hidden)        
        function propNames = getUserPropertyList(obj)
            mc = metaclass(obj);
            
            mStaticProps = mc.PropertyList;
            
            % get static properties
            mask = filterProps(mStaticProps);
            
            mValidProps = mStaticProps(mask);
            
            % get dynamic properties
            allPropNames = properties(obj);
            dynPropNames = setdiff(allPropNames,{mStaticProps.Name});
            
            if ~isempty(dynPropNames)
                for i=1:numel(dynPropNames)
                    mDynProps(i) = findprop(obj, dynPropNames{i});
                end
                
                mask = filterProps(mDynProps);
                mValidProps = [mValidProps;mDynProps(mask) .'];
            end
            propNames = {mValidProps.Name};
            
            function mask = filterProps(metaProps)
                if isempty(metaProps)
                    mask = [];
                    return;
                end
                isHidden     = [metaProps.Hidden];
                isObservable = [metaProps.SetObservable];
                isTransient  = [metaProps.Transient];
                setPublic    = strcmp({metaProps.SetAccess}, 'public');
                getPublic    = strcmp({metaProps.GetAccess}, 'public');
                
                mask = (~isHidden) & (~isTransient) & isObservable & (setPublic & getPublic);
            end
        end
        
        function metaProps = filterUserProps(obj,metaProps)
            % override this function if needed
        end
        
        function s = saveUserProps(obj)
            s = struct();
            s.cameraClass__ = class(obj);
            propnames = obj.getUserPropertyList();
            for idx = 1:length(propnames)
                propname = propnames{idx};
                s.(propname) = obj.(propname);
            end
        end
        
        function loadUserProps(obj,s)
            assert(strcmp(s.cameraClass__,class(obj)),'Properties do not match camera class');
            s = rmfield(s,'cameraClass__');
            
            propnames = fieldnames(s);
            for idx = 1:length(propnames)
                propname = propnames{idx};
                try
                    obj.(propname) = s.(propname);
                catch ME
                    % no op
                end
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
