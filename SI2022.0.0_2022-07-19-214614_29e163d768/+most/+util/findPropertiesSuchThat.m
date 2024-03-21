function matchingPropertyNames = findPropertiesSuchThat(objectOrClassName,varargin)
    % Returns a list of property names for the class that match for all the
    % given attributes.  E.g.
    %   findPropertiesSuchThat(obj,'Dependent',false,'GetAccess','private')
    %       => a list of all properties that are independent and have
    %          private GetAccess

    % Parse atribute, value pairs
    attributeNames=varargin(1:2:end);
    desiredAttributeValues=varargin(2:2:end);    
    nDesires=length(desiredAttributeValues);
    
    % Determine if first input is object or class name
    if ischar(objectOrClassName)
        mc = meta.class.fromName(objectOrClassName);
    elseif isobject(objectOrClassName)
        mc = metaclass(objectOrClassName);
    end

    % Initialize and preallocate
    propertyProperties=mc.PropertyList;
    propertyNames={propertyProperties.Name};
    nProperties = length(propertyProperties);
    %matchingPropertyNamesSoFar = cell(1,nProperties);
    
    % For each property, check the value of the queried attribute
    isMatch=false(1,nProperties);
    for iProperty = 1:nProperties
        % Get a meta.property object from the meta.class object
        thisPropertyProperties = propertyProperties(iProperty);

        isThisPropertyAMatchSoFar=true;
        for iDesire=1:nDesires
            attributeName=attributeNames{iDesire};
            desiredAttributeValue=desiredAttributeValues{iDesire};
            
            % Determine if the specified attribute is valid on this object
            if isempty (findprop(thisPropertyProperties,attributeName))
                error('%s is not a valid attribute name',attributeName)
            end
            attributeValue = thisPropertyProperties.(attributeName);
        
            % If the attribute is set or has the specified value,
            % save its name in cell array
            if ~isequal(attributeValue,desiredAttributeValue) ,
                isThisPropertyAMatchSoFar=false;
                break
            end
        end
        isMatch(iProperty)=isThisPropertyAMatchSoFar;
    end
    
    % Return used portion of array
    matchingPropertyNames = propertyNames(isMatch);
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
