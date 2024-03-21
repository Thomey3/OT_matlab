classdef MotorRegistry < scanimage.interfaces.Class
    properties (Constant, Hidden)
        controllerMap = zlclInitControllerMap();
    end
    
    methods (Static)
        function [names,infos] = getStageNames()
            map = eval([mfilename('class') '.controllerMap']);
            
            infos = [];
            keys = map.keys();
            
            for idx = 1:numel(keys)
                infos = [infos map(keys{idx})];
            end
            
            names = {infos.ListName};
            [names,idxs] = unique(names);
            infos = infos(idxs);
        end
        
        function [classes,infos] = getStageClasses()
            map = eval([mfilename('class') '.controllerMap']);
            
            infos = [];
            keys = map.keys();
            
            for idx = 1:numel(keys)
                infos = [infos map(keys{idx})];
            end
            
            classes = {infos.Class};
            [classes,idxs] = unique(classes);
            infos = infos(idxs);
        end
        
        function info = getControllerInfo(type)
            assert(ischar(type),'''type'' must be a stage controller type.');
            
            m = eval([mfilename('class') '.controllerMap']);
            
            keys = m.keys();
            idx = find(strcmpi(type,keys)); % case independent key lookup
           
            info = [];
            
            if isempty(idx)
                % try searching by listname
                [names,infos] = eval([mfilename('class') '.getStageNames()']);
                mask = strcmpi(type,names);
                info = infos(mask);
            else
                key = keys{idx(1)};
                info = m(key);
            end
        end
    end
end

function m = zlclInitControllerMap
    m = containers.Map();
    
    s = struct();
    s.Names = {'simulated.stage'};
    s.Class = 'dabs.simulated.Stage';
    s.ListName = 'Simulated Stage';
    s.SupportFastZ = false;
    s.SubType = '';
    s.TwoStep.Enable = false;
    s.SafeReset = true;
    s.NumDimensions = 3;
    zlclAddMotor(m,s);
    
    list = what('dabs/legacy/motor/MotorRegistry');
    if numel(list)
        assert(numel(list)<2,'Multiple motor registries found on path. Make sure only one scanimage installation is on the path.');
        
        [~,list] = cellfun(@fileparts,list.m,'UniformOutput',false);
        list = strcat('dabs.legacy.motor.MotorRegistry.',list);
        for i = 1:numel(list)
            mtr = eval(list{i});
            zlclAddMotor(m,mtr);
        end
    else
        most.idioms.warn('Motor registry not found.');
    end
end

function zlclAddMotor(m,s)
    names = s.Names;
    for c = 1:length(names)
        m(names{c}) = s;
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
