classdef ResonantScanner < dabs.resources.devices.SyncedScanner & dabs.resources.widget.HasWidget
    properties (SetAccess = protected)
        WidgetClass = 'dabs.resources.widget.widgets.ResonantWidget';
    end
    
    properties (SetAccess = private,AbortSet,Abstract,SetObservable)
        currentAmplitude_deg;
    end
    
    methods
        function obj = ResonantScanner(name)
            obj@dabs.resources.devices.SyncedScanner(name);
        end
    end
    
    methods (Abstract)
        setAmplitude(obj,degrees_pp)
    end
    
    properties (SetObservable)
        amplitudeToFrequencyMap = zeros(0,2);
        amplitudeToLinePhaseMap = zeros(0,2);
        amplitudeLUT = zeros(0,2);
    end
    
    methods     
        
        function park(obj)
           obj.setAmplitude(0); 
        end
        
        function val = estimateFrequency(obj,amplitude_deg)
            % avoid rounding error
            amplitude_deg = round(amplitude_deg*1e3)/1e3;
            
            if isempty(obj.amplitudeToFrequencyMap)
                x = [0,1];
                v = [1,1] * obj.nominalFrequency_Hz;
            elseif size(obj.amplitudeToFrequencyMap,1)==1
                x = [0,1] + obj.amplitudeToFrequencyMap(1,1);
                v = [1,1] * obj.amplitudeToFrequencyMap(1,2);
            else
                x = obj.amplitudeToFrequencyMap(:,1);
                v = obj.amplitudeToFrequencyMap(:,2);
            end
            
            val = interp1(x,v,amplitude_deg,'nearest','extrap');
        end
        
        function val = estimateLinePhase(obj,amplitude_deg)
            % avoid rounding error
            amplitude_deg = round(amplitude_deg*1e3)/1e3;
            
            if isempty(obj.amplitudeToLinePhaseMap)
                x = [0,1];
                v = [0,0];
            elseif size(obj.amplitudeToLinePhaseMap,1)==1
                x = [0,1] + obj.amplitudeToLinePhaseMap(1,1);
                v = [1,1] * obj.amplitudeToLinePhaseMap(1,2);
            else
                x = obj.amplitudeToLinePhaseMap(:,1);
                v = obj.amplitudeToLinePhaseMap(:,2);
            end
            
            val = interp1(x,v,amplitude_deg,'nearest','extrap');
        end
        
        function val = lookUpAmplitude(obj,amplitude_deg,reverse)
            if nargin<3 || isempty(reverse)
                reverse = false;
            end
            
            if isempty(obj.amplitudeLUT)
                x = [0;1];
                v = [0;1];
            elseif size(obj.amplitudeLUT,1)==1
                x = [0;obj.amplitudeLUT(1,1)];
                v = [0;obj.amplitudeLUT(1,2)];
            else
                x = obj.amplitudeLUT(:,1);
                v = obj.amplitudeLUT(:,2);
            end
            
            if reverse
                [x,v] = deal(v,x);
            end
            
            val = interp1(x,v,amplitude_deg,'linear','extrap');
            
            val(amplitude_deg==0) = 0;
        end
        
        function plotLUT(obj)
            dabs.resources.devices.private.ResonantCalibrator(obj);
        end
        
        function plotFrequency(obj)
            xx = linspace(obj.angularRange_deg/100,obj.angularRange_deg,100);
            yy = obj.estimateFrequency(xx);
            
            plotName = sprintf('%s Frequency',obj.name);
            hFig = most.idioms.figure('Name',plotName,'MenuBar','none','NumberTitle','off');
            hAx = most.idioms.axes('Parent',hFig,'XLim',[0,obj.angularRange_deg],'Title',plotName,'Box','on');
            line('Parent',hAx,'XData',xx,'YData',yy,'LineWidth',2);
            line('Parent',hAx,'XData',obj.amplitudeToFrequencyMap(:,1),'YData',obj.amplitudeToFrequencyMap(:,2),'LineStyle','none','Marker','o','MarkerSize',7);
            xlabel(hAx,'Resonant Scanner Amplitude [deg]');
            ylabel(hAx,'Frequency [Hz]');
            grid(hAx,'on');
        end
        
        function plotLinePhase(obj)
            xx = linspace(obj.angularRange_deg/100,obj.angularRange_deg,100);
            yy = obj.estimateLinePhase(xx) * 1e6; % convert from seconds to microseconds
            
            plotName = sprintf('%s Line Phase',obj.name);
            hFig = most.idioms.figure('Name',plotName,'MenuBar','none','NumberTitle','off');
            hAx = most.idioms.axes('Parent',hFig,'XLim',[0,obj.angularRange_deg],'Title',plotName,'Box','on');
            line('Parent',hAx,'XData',xx,'YData',yy,'LineWidth',2);
            line('Parent',hAx,'XData',obj.amplitudeToLinePhaseMap(:,1),'YData',obj.amplitudeToLinePhaseMap(:,2)*1e6,'LineStyle','none','Marker','o','MarkerSize',7);
            xlabel(hAx,'Resonant Scanner Amplitude [deg]');
            ylabel(hAx,'Resonant Scanner Line Phase [us]');
            grid(hAx,'on');
        end
    end
    
    methods
        function addToAmplitudeToFrequencyMap(obj,amp_deg,freq_Hz)
            % avoid rounding error
            amp_deg = round(amp_deg*1e3)/1e3;
            
            lut = obj.amplitudeToFrequencyMap;
            mask = lut == amp_deg;
            lut(mask,:) = [];
            lut(end+1,:) = [amp_deg,freq_Hz];
            
            obj.amplitudeToFrequencyMap = lut;
        end
        
        function addToAmplitudeToLinePhaseMap(obj,amp_deg,linePhase_s)
            % avoid rounding error
            amp_deg = round(amp_deg*1e3)/1e3;
            
            lut = obj.amplitudeToLinePhaseMap;
            mask = lut == amp_deg;
            lut(mask,:) = [];
            lut(end+1,:) = [amp_deg,linePhase_s];
            
            obj.amplitudeToLinePhaseMap = lut;
        end
    end
    
    methods
        function set.amplitudeToFrequencyMap(obj,val)
            if isempty(val)
                val = zeros(0,2);
            end
            
            val = validateLUT(val);
            obj.amplitudeToFrequencyMap = val;
        end
        
        function set.amplitudeToLinePhaseMap(obj,val)
            if isempty(val)
                val = zeros(0,2);
            end
            
            val = validateLUT(val);
            obj.amplitudeToLinePhaseMap = val;
        end
        
        function set.amplitudeLUT(obj,val)
            if isempty(val)
                val = zeros(0,2);
            end
            
            val = validateLUT(val);
            obj.amplitudeLUT = val;
        end
    end
end

function val = validateLUT(val)
    validateattributes(val,{'numeric'},{'ncols',2,'finite','nonnan','real'});
    
    xx = val(:,1);
    yy = val(:,2);
    
    %sort LUT
    [~,sortIdx] = sort(xx);
    xx = xx(sortIdx);
    yy = yy(sortIdx);
    
    % assert strictly monotonic
    assert(all(diff(xx)>0), 'ResonantScanner: LUT column 1 needs to be strictly monotonic');
    val = [xx,yy];
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
