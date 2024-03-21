classdef XPS_TCP < handle
    % This class is a wrapper for tcp communication with the newport xps
    % stage controller. It is intended for use with XPS_SI, so functions
    % not called by XPS_SI might be untested. Also, some functions are none
    % not to work, specifically those that involve a variable number of
    % inputs not based on the number of positioners in a give group (see
    % below).
    
    % This code relies heavily off of supplied newport source code, with
    % much information parsed directly out of it. It is also based on
    % previous iterations of XPS by Steve and Vijay, although most of the
    % higher level functions of XPS are now performed by XPS_SI
    % Steve 3.2.12
    

    %% Properties
    properties(SetAccess=protected)
        inputBufferSize=1024;
        %positionerNames;
        groupNames;
        %groupPositionerCountMap;
        %groupPositionerMap;
       % positionerNamesUnique;
        ipAddress;
        port;
        tcpObjectMove;
        tcpObjectGet;
        tcpObjectSet;
        tcpObjectLong;
        %Note: The newport drivers previously used seemed to wait until the
        %move was complete. To work around this, a low timeoutMove was
        %previously used, so the software would stop listening for a
        %replay. Now, however, mvoe commands do not wait for verification,
        %so the timeout should never be reached (hopefully)
        timeoutMove=10;
        timeoutSet=10;
        timeoutGet=10;%2E-1;
        timeoutLong=30; %very long time out so that initialize/home have plent of time to complete
        %currentGroup;
        functionInputMap; %Holds the format of the input for each function on the XPS
        functionOutputMap; 
        functionOutputSizeMap; %The buffer size for the output. 
        nInputMap; %Number of inputs
        functionList;
        functionTCPObjectMap; 
        functionInputRepeats; % For some functions, the number of inputs is variable. This map holds the input format that is repeated
        groupSizeMap;
    end
    
    
    %% Constructor
    methods
        function obj=XPS_TCP(groupNames,positionersInEachGroup,ipAddress,port)
            %Group Names is cell array of group Names
            %positionsInEachGroup is array with the number of positioners in each group corresponding to groupNames

            %Initialization of variables
            obj.groupNames = groupNames;
            obj.groupSizeMap=containers.Map();
            for i=1:length(groupNames)
                obj.groupSizeMap(groupNames{i})=positionersInEachGroup(i);
            end
            obj.ipAddress = ipAddress;
            obj.port=port;
            
            
            %Construct tcpip objects (Is readasycnmode really have to be
            %continuous? Might be worth checking. This has to do with being
            %able to read with fread one character at a time (i think))
            obj.tcpObjectMove=cell(1,length(obj.groupNames));
            for i=1:length(obj.groupNames)
                obj.tcpObjectMove{i}=tcpip(obj.ipAddress,port,'timeout',obj.timeoutMove,'InputBufferSize',obj.inputBufferSize,'ReadAsyncMode','continuous','Name',['Move_' num2str(i)]);
            end
            obj.tcpObjectGet=tcpip(obj.ipAddress,port,'timeout',obj.timeoutGet,'InputBufferSize',obj.inputBufferSize,'ReadAsyncMode','continuous','Name','Get_1');
            obj.tcpObjectSet=tcpip(obj.ipAddress,port,'timeout',obj.timeoutSet,'InputBufferSize',obj.inputBufferSize,'ReadAsyncMode','continuous','Name','Set_1');
            obj.tcpObjectLong=tcpip(obj.ipAddress,port,'timeout',obj.timeoutLong,'InputBufferSize',obj.inputBufferSize,'ReadAsyncMode','continuous','Name','Long_1');
            

            
            
            obj.initializeFunctionMaps();
            
            % Test connection
           
            obj.executeFunction('TestTCP','Arbitrary test String');
           
            
        end
    end

    %% Methods
    methods
        function initializeFunctionMaps(obj) 

            maps=load('dabs\newport\functionMaps'); %functionMaps was generated by parsing the source code using getFunctionMaps
            
            obj.functionInputMap=maps.input;
            obj.functionOutputSizeMap=maps.output;
            obj.functionInputRepeats=maps.repeats;
            obj.functionOutputMap=containers.Map;
            obj.functionList=obj.functionInputMap.keys;
            obj.nInputMap=containers.Map;
            obj.functionTCPObjectMap=containers.Map;
            for i=1:length(obj.functionList)
                obj.nInputMap(obj.functionList{i})=numel(strfind(obj.functionInputMap(obj.functionList{i}),'%'));
                if strcmp(obj.functionList{i},'GroupInitialize')
                    obj.functionTCPObjectMap(obj.functionList{i})=obj.tcpObjectLong;
                    
                elseif strcmp(obj.functionList{i},'GroupHomeSearch') || ~isempty(regexp(obj.functionList{i},'Move','Once'));
                    % Is move command (Special case), different tcpObject
                    % for each group
                    obj.functionTCPObjectMap(obj.functionList{i})='';
                elseif strcmp(obj.functionList{i}(end-2:end),'Set');
                    % Is a set command
                    obj.functionTCPObjectMap(obj.functionList{i})=obj.tcpObjectSet;
                else
                    %Is a get command
                    obj.functionTCPObjectMap(obj.functionList{i})=obj.tcpObjectGet;
                end
                    %Create function OutputMap based on functionInputMap
                    input=obj.functionInputMap(obj.functionList{i});
                  %  [b e]=regexp(input,'\,.*\*');
                    outputCellRaw=tokenize(input,',');
                    %s={};
                    outputCellProcessed=cell(1,obj.nInputMap(obj.functionList{i}));
                    k=1;
                    for j=1:length(outputCellRaw)
                        switch outputCellRaw{j}
                            case {'double *','double *)','(double *','int *','int *)','(int *'}
                                outputCellProcessed{k}='%f';
                                k=k+1;
                            case {'char *','char *)','(char *','bool *','bool *)','(bool *'}
                                outputCellProcessed{k}='%s%c';
                                k=k+1;
                        end
                        
                    end 
                   
                    obj.functionOutputMap(obj.functionList{i})=outputCellProcessed;                        
                %Generated output map
            end
            
            
            
            
        end
        
     
        function out=executeFunction(obj,varargin)
            % Executes a function on the XPS. First input is always the
            % name of the function, as a string. The next inputs are
            % function specific.
            %fprintf('Executing %s\n', varargin{1})
            assert(ismember(varargin{1},obj.functionList),'Parameters for the function %s are not specified in this class',varargin{1});
            tcpobj=obj.getTCP(varargin{1});
            isMove=0; %Holds whether or not this command is a move command
            if isempty(tcpobj)
                %Is a move command
                isMove=1;
                [tf, i]=ismember(varargin{2},obj.groupNames); %If it is a move command, then the second argument should be a group name
                assert(tf, 'Group %s not found. Note, this should be impossible');
                tcpobj=obj.tcpObjectMove{i};
            end
            
             stringToWrite=obj.functionInputMap(varargin{1});
            if ~isempty(obj.functionInputRepeats(varargin{1})) %Apply repeats if necessary
                i=strfind(varargin{1},'Group'); 
                if isempty(i)
                    %There are some functions that use a variable number of
                    %inputs, but don't aren't dependent on group. Because
                    %this class uses the number of positioners in a group
                    %to determine the number of repeats. These other
                    %functions are currently not supported. (As of 3.2.12).
                    %This also allows us to assume that the second varargin
                    %is the group name
                    %As this class is designed to be called by XPS_SI, It
                    %should not be an issue, as XPS_SI access a limited
                    %number of functions
                    error('%s is not currently supported',varargin{1});
                end
                i=strfind(varargin{2},'.');
                if ~isempty(i)
                    %Is a positioner, not a group. For some (at least 1?)
                    %functions, it is possible to specify a positioner name
                    %instead of a group name. In this case, the number of
                    %repeats is 1 by default
                    nRepeats=1;
                else
                    %Is a group
                    nRepeats=obj.groupSizeMap(varargin{2}); %Assumes group name is the second variable, this is why functions with 'Group' in them are not supported
                end
                repeat=obj.functionInputRepeats(varargin{1});
                lengthRepeat=length(repeat);
                stringToAppend=char(32*zeros(1,(lengthRepeat+1)*nRepeats));
                 for i=1:nRepeats
                     stringToAppend(1+(i-1)*(lengthRepeat+1):1+(i-1)*(lengthRepeat+1)+lengthRepeat)=[repeat ','];
                 end
                stringToWrite=strcat(stringToWrite,stringToAppend);
                stringToWrite(end)=')'; %replace last , with a )
                
                
                
            end
            
            %assert(length(varargin)-1==obj.nInputMap(varargin{1}), 'Number of input variables does not match the necessary number for %s', varargin{1});
           % fprintf('Opening File %s\n', varargin{1})
            if strcmp(tcpobj.status,'closed')
%                 fprintf('TCP Object %s %s. %s.\n',tcpobj.Name,'open',varargin{1});
                fopen(tcpobj);
            else
                error('TCP Object %s already open. Trying to execute %s',tcpobj.Name,varargin{1})
            end
           % fprintf('Writing File %s\n', varargin{1})
            fwrite(tcpobj,[varargin{1} ' ' sprintf(stringToWrite, varargin{2:end})]); %Send the function call
            if ~isMove % If it is a move, then we don't bother reading the output, but simply close the file and end the function
                s=char(32.*ones(1,obj.functionOutputSizeMap(varargin{1})));
                
                try
                    s=readToEndOfAPI(tcpobj, s);
                catch exception
%                      fprintf('TCP Object %s %s. %s.\n',tcpobj.Name,'close',varargin{1});
                    fclose(tcpobj);
                    %error('Error reading from stage controller');
                    rethrow(exception)

                    
                end
%                  fprintf('TCP Object %s %s. %s.\n',tcpobj.Name,'close',varargin{1});
                fclose(tcpobj);
                %varargout=s;
                %s=char(s');
                [errorCodeStr, tail]=strtok(s,',');
                errorCode=str2double(errorCodeStr);
                if errorCode < 0 % If there was an error
                    out=obj.getErrorString(errorCode);
                    error('The Newport XPS Returned the following Error: %s\nError occured while trying to execute %s with the following arguments: %s\n',out(3:end),varargin{1},cellToString(varargin(2:end)));
                else
                    
                    if  ~isempty(obj.functionInputRepeats(varargin{1}))
                        % The output map for functions that have repeat
                        % inputs must also be adjusted. At some point, it
                        % may be best to initialize this for certain
                        % group/move combinations in an effort to speed
                        % this up
                        
                        
                        %input=obj.functionInputMap(obj.functionList{i});
                        %  [b e]=regexp(input,'\,.*\*');
                        outputCellRaw=tokenize(stringToWrite,',');
                       % s={};
                       outputCellProcessed=cell(1,numel(strfind(stringToWrite,'*')));
                       k=1;
                        for j=1:length(outputCellRaw)
                            switch outputCellRaw{j}
                                case {'double *','double *)','(double *','int *','int *)','(int *'}
                                    outputCellProcessed{k}='%f';
                                    k=k+1;
                                case {'char *','char *)','(char *','bool *','bool *)','(bool *'}
                                    outputCellProcessed{k}='%s%c';
                                    k=k+1;
                            end
                            
                        end
                        
                        form=outputCellProcessed;
                    else
                        form=obj.functionOutputMap(varargin{1});
                    end
                    
                    if isempty(form);
                        out=tail(2:end-9); %If an output format (form) is not specified, simply output a string
                    else
                        outCellRaw=tokenize(tail(2:end-8),',');
                        
                        %parse output and convert. output will be cell array
                        %The end result should be a cell array of variables
                        %in the appropriate format. This may break if one
                        %of many outputs is a string with commas.
                        out=cell(1,length(outCellRaw));
                        %form=obj.functionOutputMap(varargin{1});
                        for i=1:length(outCellRaw)
                            out{i}=sscanf(outCellRaw{i},form{i});
                        end
                        %out=scanf(tail,obj.functionOutputMap(obj.functionList{i}));
                    end
                end
            else
%                  fprintf('TCP Object %s %s. %s.\n',tcpobj.Name,'close',varargin{1});
                fclose(tcpobj);
            end
          %  fprintf('%s done\n',varargin{1})
        end
        
        function s=getErrorString(obj,errorCode)
            %Similar to execute function but specific for getting an error
            %string
            fName='ErrorStringGet';
            tcpobj=obj.functionTCPObjectMap(fName);
%              fprintf('TCP Object %s %s. %s.\n',tcpobj.Name,'open',varargin{1});
            fopen(tcpobj);
            fwrite(tcpobj,[fName ' ' sprintf(obj.functionInputMap(fName), errorCode)]);
            
            s=char(32.*ones(1,obj.functionOutputSizeMap(fName)));
            try
            s=readToEndOfAPI(tcpobj,s);
            
            catch exception
                rethrown(exception)
%                  fprintf('TCP Object %s %s. %s.\n',tcpobj.Name,'close',varargin{1});
                fclose(tcpobj);
                error('Error reading from stage controller while attempting to retrieve error string');
                
            end
%                fprintf('TCP Object %s %s. %s.\n',tcpobj.Name,'close',varargin{1});  
            fclose(tcpobj);
            %s=char(s');
            newErrorCode=str2double(strtok(s,','));
            if newErrorCode < 0
                error('Unable to get string for error %d. ErrorStringGet returned error %d',errorCode,newErrorCode);
            end
        
            
            
            
        end
        
        function tcpobj=getTCP(obj,functionName)
            %This function exists to add more objects if the desired object
            %is already being used. It does not work for move commands
            %(just returns empty). This should not be a problem, as a group
            %shouldn't be getting more than one move command at a time
            %anyways, and the number of move objects is already set to the
            %number of groups.
            
           tcpobjArray=obj.functionTCPObjectMap(functionName);
           tcpobj=[];
           if isempty(tcpobjArray)
               %is a move command
               return;
           end
           i=1;
           type=strtok(tcpobjArray(1).Name,'_');
           while isempty(tcpobj)
               if i>length(tcpobjArray)
                   %Get type (get, set, etc)
                   
                   tcpobjArray(i)=tcpip(obj.ipAddress,obj.port,'timeout',eval(['obj.timeout' type]),'InputBufferSize',obj.inputBufferSize,'ReadAsyncMode','continuous','Name',[type '_1']);
                   tcpobj=tcpobjArray(i);
		   fprintf('TCPIP object %s _ %d created\n',type,i);
               elseif strcmp(tcpobjArray(i).status,'closed')
                   tcpobj=tcpobjArray(i);
               else 
                   i=i+1;
               end
           end
           eval(['obj.tcpObject' type '=tcpobjArray;'])
               
        end
        



    end

end

function s=readToEndOfAPI(tcpobj, s)
    % Instead of waiting for the timeout, this stops reading once
    % EndOfAPI has been reached. It may be possible to speed up
    % this function in the future.
    i=1;
    while i<9 || ~strcmp(s(i-8:i-1),'EndOfAPI')
        s(i)=fread(tcpobj,1,'char');

        i=i+1;
        %   fprintf('%s',s(i));
    end
    s=s(1:i-1);
    %  fprintf('\n')
end

function s=cellToString(c)
    s=[];
    for i=1:length(c)
        s=[s num2str(c{i}) ','];
    end
    s=s(1:end-1);
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
