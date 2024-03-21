classdef ThorlabsPmtPage < dabs.resources.configuration.ResourcePage
    properties
        pmhVisa
        etWavelength
        cbAutoOn
        txDescription
    end
    
    methods
        function obj = ThorlabsPmtPage(hResource,hParent)
            obj@dabs.resources.configuration.ResourcePage(hResource,hParent);
        end
        
        function makePanel(obj,hParent)
            hTabGroup = uitabgroup('Parent',hParent);
            
            hTab = uitab('Parent',hTabGroup,'Title','Basic');
            most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [0 30 120 20],'Tag','txhVisa','String','Visa Address','HorizontalAlignment','right');
            obj.pmhVisa  = most.gui.uicontrol('Parent',hTab,'Style','popupmenu','String',{''},'RelPosition', [125 27 230 20],'Tag','pmhVisa');
            
            most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [0 51 120 20],'Tag','txWavelength','String','Wavelength [nm]','HorizontalAlignment','right');
            obj.etWavelength = most.gui.uicontrol('Parent',hTab,'Style','edit','RelPosition', [125 49 60 20],'Tag','etWavelength');
            
            most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [0 71 120 20],'Tag','txAutoOn','String','Auto on','HorizontalAlignment','right');
            obj.cbAutoOn = most.gui.uicontrol('Parent',hTab,'Style','checkbox','RelPosition', [125 70 250 20],'Tag','cbAutoOn');
            
            obj.txDescription = most.gui.uicontrol('Parent',hTab,'Style','text','RelPosition', [30 182 320 100],'Tag','txDescription','String','','HorizontalAlignment','left');
            
            hTab = uitab('Parent',hTabGroup,'Title','Advanced');
            most.gui.uicontrol('Parent',hTab,'RelPosition', [20 52 150 30],'Tag','pbChangeSerial','String','Change PMT serial number','Callback',@(varargin)obj.changeSerial());
            most.gui.uicontrol('Parent',hTab,'RelPosition', [20 92 150 30],'Tag','pbChangePmtType','String','Change PMT type','Callback',@(varargin)obj.changePmtType());
        end
        
        function redraw(obj)            
            hVisas = obj.hResourceStore.filter(@(v)dabs.thorlabs.PMT.isValidThorPMT(v));
            obj.pmhVisa.String = [{''}, hVisas];
            obj.pmhVisa.pmValue = obj.hResource.hVisa;
            
            obj.etWavelength.String = num2str(obj.hResource.wavelength_nm);
            obj.cbAutoOn.Value = obj.hResource.autoOn;
            
            if isempty(obj.hResource.errorMsg)
                obj.txDescription.String = sprintf('VISA Driver: %s\nDevice manufacturer: %s\nDevice model: %s\nDevice serial: %s\nDevice firmware: %s\nPMT Type: %s' ...
                    ,obj.hResource.driverInfo,obj.hResource.manufacturer,obj.hResource.model,obj.hResource.serialNumber,obj.hResource.firmware,obj.hResource.pmtType);
            else
                obj.txDescription.String = '';
            end
        end
        
        function changeSerial(obj)
            try
                assert(most.idioms.isValidObj(obj.hResource.hVisa),'Invalid Visa Address');
                newSerial = queryUserForSerial();
                if isempty(newSerial)
                    return % User abort
                end
                
                obj.hResource.setSerial(newSerial);
                
                h = helpdlg(sprintf('Serial changed successfully.\nUnplug PMT and plug back in, then click ''OK'''),'SUCCESS');
                waitfor(h);
                
                findVisaObject(newSerial)
                
                obj.redraw();
            catch ME
                most.ErrorHandler.logAndReportError(ME);
                errordlg(ME.message);
            end
            
            %%% Nested functions
            function newSerial = queryUserForSerial()
                currentserial = obj.hResource.hVisa.name;
                currentserial = regexpi(currentserial,'[A-F0-9]{8}','match','once');
                
                prompt = sprintf('Please enter a new Hexadecimal serial number\n(e.g. ''AA00AA00'')');
                dlgtitle = 'Enter Serial';
                dims = 1;
                definput = {currentserial};
                
                newSerial = inputdlg(prompt,dlgtitle,dims,definput);
                
                if isempty(newSerial)
                    newSerial = '';
                else
                    newSerial = newSerial{1};
                end
            end
            
            function findVisaObject(serial)                
                pause(1);
                dabs.resources.VISA.scanSystem();
                
                hVisas = obj.hResourceStore.filterByClass('dabs.resources.VISA');
                visaNames = cellfun(@(hR)hR.name,hVisas,'UniformOutput',false);
                matches = regexpi(visaNames,['^USB[0-9]::0x[A-F0-9]{4}::0x[A-F0-9]{4}::' serial],'match','once');
                mask = cellfun(@(m)~isempty(m),matches);
                
                if any(mask)
                    obj.hResource.hVisa = hVisas{mask};
                    obj.hResource.saveMdf();
                    obj.hResource.reinit();
                end
            end
        end
        
        function changePmtType(obj)            
            try
                assert(most.idioms.isValidObj(obj.hResource.hVisa),'Invalid Visa Address');
                newPmtType = queryUserForPmtType();
                if iscell(newPmtType) && isempty(newPmtType)
                    return % User abort
                end
                
                obj.hResource.setPmtType(newPmtType);
                
                helpdlg(sprintf('PMT type changed successfully.'),'SUCCESS');
                obj.hResource.reinit();
                
                obj.redraw();
            catch ME
                most.ErrorHandler.logAndReportError(ME);
                errordlg(ME.message);
            end
            
            % Nested function
            function pmtType = queryUserForPmtType()
                validPmts = obj.hResource.PMT_CONSTANTS.keys;
                currentPmtType = obj.hResource.pmtType;
                
                prompt = sprintf('Please enter a new PMT type.\nValid options are:\n{%s}',strjoin(validPmts,', '));
                dlgtitle = 'Enter PMT Type';
                dims = 1;
                definput = {currentPmtType};
                
                pmtType = inputdlg(prompt,dlgtitle,dims,definput);
                
                if ~isempty(pmtType)
                    pmtType = pmtType{1};
                end
            end
        end
        
        function apply(obj)
            most.idioms.safeSetProp(obj.hResource,'hVisa',obj.pmhVisa.pmValue);
            most.idioms.safeSetProp(obj.hResource,'wavelength_nm',str2double(obj.etWavelength.String));
            most.idioms.safeSetProp(obj.hResource,'autoOn',obj.cbAutoOn.Value);
            
            obj.hResource.saveMdf();
            obj.hResource.reinit();
        end
        
        function remove(obj)
            obj.hResource.deleteAndRemoveMdfHeading();
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
