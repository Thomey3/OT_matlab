classdef CoordinateSystems < scanimage.interfaces.Component & most.HasClassDataFile
    %% USER PROPS    
    properties (SetAccess = private, SetObservable)
        hCSWorld;     % root coordinate system for ScanImage
        hCSReference; % root coordinate system for ScanImage. origin of Reference is the focal point of the objective, when FastZ is set to zero
        hCSFocus;     % focus point after taking FastZ defocus into account
    end
    
    properties (Dependent, SetAccess = private, SetObservable)
        hCSSampleAbsolute
        hCSSampleRelative
    end
    
    properties (SetAccess = private, GetAccess = private)
        hListeners = event.listener.empty(1,0);
    end
    
    properties (Hidden, Dependent)
        focalPoint
    end
    
    %% INTERNAL PROPS
    %%% ABSTRACT PROPERTY REALIZATION (most.Model)
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = ziniInitPropAttributes();
        mdlHeaderExcludeProps = {};
    end
    
    %%% ABSTRACT PROPERTY REALIZATION (scanimage.interfaces.Component)
    properties (SetAccess = protected, Hidden)
        numInstances = 1;
    end
    
    properties (Constant, Hidden)
        COMPONENT_NAME = 'CoordinateSystems';               % [char array] short name describing functionality of component e.g. 'Beams' or 'FastZ'
        PROP_TRUE_LIVE_UPDATE = {};                         % Cell array of strings specifying properties that can be set while the component is active
        PROP_FOCUS_TRUE_LIVE_UPDATE = {};                   % Cell array of strings specifying properties that can be set while focusing
        DENY_PROP_LIVE_UPDATE = {};                         % Cell array of strings specifying properties for which a live update is denied (during acqState = Focus)
        
        FUNC_TRUE_LIVE_EXECUTION = {};                      % Cell array of strings specifying functions that can be executed while the component is active
        FUNC_FOCUS_TRUE_LIVE_EXECUTION = {};                % Cell array of strings specifying functions that can be executed while focusing
        DENY_FUNC_LIVE_EXECUTION = {};                      % Cell array of strings specifying functions for which a live execution is denied (during acqState = Focus)
    end
    
    properties (Hidden, SetAccess=?scanimage.interfaces.Class, SetObservable)
        classDataFileName;
    end
    
    %% LIFECYCLE
    methods (Access = ?scanimage.SI)
        function obj = CoordinateSystems()
            obj@scanimage.interfaces.Component('SI CoordinateSystems');
            
            % Determine classDataFile name and path
            if isempty(obj.hSI.classDataDir)
                pth = most.util.className(class(obj),'classPrivatePath');
            else
                pth = obj.hSI.classDataDir;
            end
            classNameShort = most.util.className(class(obj),'classNameShort');
            obj.classDataFileName = fullfile(pth, [classNameShort '_classData.mat']);
            
            obj.hCSWorld = scanimage.mroi.coordinates.CSLinear('World',3);
            obj.hCSReference = scanimage.mroi.coordinates.CSLinear('Reference space',3,obj.hCSWorld);
            obj.hCSFocus = scanimage.mroi.coordinates.CSLinear('Focus',3,obj.hCSReference);
            obj.hCSFocus.lock = true; % do not load from class data file
        end
    end

    methods        
        function reinit(obj)
            obj.loadClassData();
            
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hSI,'imagingSystem','PostSet',@(varargin)obj.updateCSFocus);
            obj.hListeners(end+1) = most.ErrorHandler.addCatchingListener(obj.hSI.hFastZ,'position','PostSet',@(varargin)obj.updateCSFocus);
        end
        
        function delete(obj)
            % coordinate systems will automatically be deleted once they go
            % out of reference
            
            most.idioms.safeDeleteObj(obj.hListeners);
            obj.save();
        end
    end
    
    %% Abstract methods realizations (scanimage.interfaces.Component)
    methods (Access = protected, Hidden)        
        function componentStart(obj,varargin)
        end
        
        function componentAbort(obj,varargin)
        end
    end
    
    %% Class methods
    methods
        function plot(obj)
            %PLOT plot ScanImages' coordinate system tree
            %   
            %   Opens a window that visualizes ScanImage's internal
            %   coordinate system structure

            obj.hCSWorld.plotTree();
        end
             
        function reset(obj)
            %RESET resets all coordinate systems derived from 'World'
            %   
            %   Retrieves the coordinate system tree and resets all nodes
            %   with their respective reset function
            
            [~,nodes] = obj.hCSWorld.getTree();
            cellfun(@(n)n.reset(), nodes);
        end
        
        function load(obj)
            %LOAD loads the coordinate system definitions from disk
            %
            %   Loads the coordinate system settings from the class data
            %   file
            
            obj.loadClassData();
        end
        
        function save(obj)
            %SAVE saves the coordinate system definitions to disk
            %
            %   Saves the coordinate system settings to the class data
            %   file. this function is automatically executed when
            %   ScanImage is exited
            
            obj.saveClassData();
        end
    end
    
    %% Saving / Loading
    methods (Hidden)
        function s = toStruct(obj)
            [~,nodes] = obj.hCSWorld.getTree();
            nodeStructs  = cellfun(@(n)n.toStruct, nodes, 'UniformOutput', false);
            s = nodeStructs;
        end
        
        function fromStruct(obj,s)
            [~,nodes] = obj.hCSWorld.getTree();
            nodeNames  = cellfun(@(n)n.name, nodes, 'UniformOutput', false);
            
            for idx = 1:numel(s)
                try
                    nodeStruct = s{idx};
                    mask = strcmp(nodeStruct.name__,nodeNames);
                    
                    if ~any(mask)
                        %warning('Coordinate system %s on disk does not exist in ScanImage''s coordinate system tree.',nodeStruct.name__);
                    else
                        node = nodes{mask};
                        if isempty(node)
                            warning('Could not load coordinate system %s',nodeStruct.name__);
                        else
                            node.fromStruct(nodeStruct);
                        end
                    end
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
            end
        end
    
        function ensureClassDataFileProps(obj)
            obj.ensureClassDataFile(struct('CoordinateSystemConfigs',[]),obj.classDataFileName);
        end
        
        function loadClassData(obj,filePath)
            if nargin<2 || isempty(filePath)
                filePath = obj.classDataFileName;
                obj.ensureClassDataFileProps();
            end
            
            assert(exist(filePath,'file')==2,'File not found on disk: %s',filePath);
            
            s = obj.getClassDataVar('CoordinateSystemConfigs',filePath);
            obj.fromStruct(s);
        end
        
        function saveClassData(obj)
            if ~obj.mdlInitialized
                return % this is to prevent saving the default coordinate systems if startup fails before we executed obj.loadClassData 
            end
            
            try
                obj.ensureClassDataFileProps();
                
                s = obj.toStruct();
                obj.setClassDataVar('CoordinateSystemConfigs',s,obj.classDataFileName);
            catch ME
                most.ErrorHandler.logAndReportError(ME);
            end
        end
    end
    
    %% Internal Methods
    methods (Hidden)
        function updateCSFocus(obj)            
            z = obj.hSI.hFastZ.position;
            
            T = eye(4);
            T(3,4) = z;
            
            obj.hCSFocus.toParentAffine = T;
        end
    end
    
    %% Property Getter/Setter    
    methods        
        function val = get.hCSSampleAbsolute(obj)
            val = obj.hSI.hMotors.hCSSampleAbsolute;
        end
        
        function val = get.hCSSampleRelative(obj)
            val = obj.hSI.hMotors.hCSSampleRelative;
        end
        
        function val = get.focalPoint(obj)
            val = scanimage.mroi.coordinates.Points(obj.hCSFocus,[0,0,0]);
        end
    end
end

%% LOCAL (after classdef)
function s = ziniInitPropAttributes()
s = struct();
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
