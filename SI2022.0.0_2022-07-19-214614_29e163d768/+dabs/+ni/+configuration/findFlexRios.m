function rioList = findFlexRios
    rioList = struct();

    % get singleton configuration object
    hConfig = dabs.ni.configuration.Configuration();
    if ~most.idioms.isValidObj(hConfig)
        return % NI drivers are not installed
    end
    
    sessionhandle = hConfig.sessionhandle;

    % find hardware
    [~,~,~,resEn] = dabs.ni.configuration.private.nisyscfgCall('NISysCfgFindHardware',sessionhandle,1,libpointer,'',libpointer);
    
    % go through list
    succ = true;
    while succ
        try
            [~,~,res] = dabs.ni.configuration.private.nisyscfgCall('NISysCfgNextResource',sessionhandle, resEn, libpointer('voidPtrPtr'));

            try
                chr = libpointer('string',blanks(100000));
                dabs.ni.configuration.private.nisyscfgCall('NISysCfgGetResourceProperty', res, 'NISysCfgResourcePropertyProvidesLinkName', chr);
                addr = chr.Value;
            catch
                addr = '';
            end

            try
                chr = libpointer('string',blanks(100000));
                dabs.ni.configuration.private.nisyscfgCall('NISysCfgGetResourceProperty', res, 'NISysCfgResourcePropertyConnectsToLinkName', chr);
                parAddr = chr.Value;
            catch
                parAddr = '';
            end

            if strncmp(addr,'RIO',3) || strncmp(parAddr,'RIO',3)
                % this will find flex rios and digitizers
                try
                    chr = libpointer('string',blanks(100000));
                    dabs.ni.configuration.private.nisyscfgCall('NISysCfgGetResourceProperty', res, 'NISysCfgResourcePropertyProductName', chr);
                    nm = chr.Value;
                    
                    dabs.ni.configuration.private.nisyscfgCall('NISysCfgGetResourceProperty', res, 'NISysCfgResourcePropertySerialNumber', chr);
                    serial = chr.Value;
                catch
                    nm = '';
                    serial = '';
                end

                if strncmp(addr,'RIO',3)
                    rioList.(addr).productName = nm;
                    rioList.(addr).pxiNumber = str2double(parAddr(4:end));
                    rioList.(addr).serial = serial;
                else
                    rioList.(parAddr).adapterModule = nm;
                    rioList.(parAddr).adapterModuleSerial = serial;
                end
            else
                % this will find oscilloscopes
                % get number of experts
                try
                    v = libpointer('uint32Ptr',0);
                    dabs.ni.configuration.private.nisyscfgCall('NISysCfgGetResourceProperty', res, 'NISysCfgResourcePropertyNumberOfExperts', v);
                    n = v.Value;
                catch
                    n = 0;
                end
                
                % look for the ni-rio expert
                for jj = 1:n
                    try
                        chr = libpointer('string',blanks(100000));
                        dabs.ni.configuration.private.nisyscfgCall('NISysCfgGetResourceIndexedProperty', res, 'NISysCfgIndexedPropertyExpertName', jj, chr);
                        nm = chr.Value;
                    catch
                        nm = '';
                    end
                    
                    if strcmp(nm, 'ni-rio')
                        try
                            chr = libpointer('string',blanks(100000));
                            dabs.ni.configuration.private.nisyscfgCall('NISysCfgGetResourceIndexedProperty', res, 'NISysCfgIndexedPropertyExpertResourceName', jj, chr);
                            rio = chr.Value;
                        catch
                            rio = '';
                        end
                        
                        if ~isempty(rio)
                            try
                                chr = libpointer('string',blanks(100000));
                                dabs.ni.configuration.private.nisyscfgCall('NISysCfgGetResourceProperty', res, 'NISysCfgResourcePropertyProductName', chr);
                                nm = chr.Value;
                                
                                dabs.ni.configuration.private.nisyscfgCall('NISysCfgGetResourceProperty', res, 'NISysCfgResourcePropertySerialNumber', chr);
                                serial = chr.Value;
                            catch
                                nm = '';
                                serial = '';
                            end
                            
                            if strncmp(rio,'RIO',3)
                                rioList.(rio).productName = nm;
                                rioList.(rio).pxiNumber = str2double(parAddr(4:end));
                                rioList.(rio).serial = serial;
                            end
                        end
                    end
                end
            end

            dabs.ni.configuration.private.nisyscfgCall('NISysCfgCloseHandle',res);
        catch
            succ = false;
        end
    end

    % close the enumerator
    dabs.ni.configuration.private.nisyscfgCall('NISysCfgCloseHandle',resEn);
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
