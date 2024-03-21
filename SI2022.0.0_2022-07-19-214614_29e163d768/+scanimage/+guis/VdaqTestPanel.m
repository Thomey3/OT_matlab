classdef VdaqTestPanel < most.Gui
    
    properties (Hidden)
        deviceInfo;
        vdaqId;
        isR1;
        isH;
        
        hvDAQ;
        hFpga;
        hDataScope;
        hDelListener = event.listener.empty();
        
        stProdName;
        stFwVersion;
        stSerialNumber;
        stTemperature;
        stErrorMessages;
        pbHsaiStart;
        pbLsaiStart;
        pmInputRange;
        cbHsaiAs;
        etHsaiTimescale;
        etHsaiSampleRate;
        etHsaiFilter;
        
        cbLsaiEn = most.gui.uicontrol.empty(1,0);
        
        etAoCurrentVal = most.gui.uicontrol.empty(1,0);
        etAoNewVal = most.gui.uicontrol.empty(1,0);
        pbUpdateAo = most.gui.uicontrol.empty(1,0);
        cbLiveAo = most.gui.uicontrol.empty(1,0);
        slAoNewVal = most.gui.slider.empty(1,0);
        pbAoStartGen = most.gui.uicontrol.empty(1,0);
        
        tbDio_i = most.gui.uicontrol.empty(1,0);
        tbDio_oe = most.gui.uicontrol.empty(1,0);
        tbDio_ov = most.gui.uicontrol.empty(1,0);
        
        tbDio_i_Value  = false(1,0);
        tbDio_oe_Value = false(1,0);
        tbDio_ov_Value = cell(1,0);
        
        hFiltFlow;
        hChanFlow;
        hChannelPannels = matlab.ui.container.Panel.empty;
        
        pmPwmGenCh;
        etPwmGenF;
        etPwmGenDC;
        pbPwmGen;
        
        etFreq;
        etPW;
        
        hLsaiAx = matlab.graphics.axis.Axes.empty(1,0);
        hLsaiLine = matlab.graphics.primitive.Line.empty(1,0);
        hLsaiLegendLine = matlab.graphics.primitive.Line.empty(1,0);
        
        hHsaiAx = matlab.graphics.axis.Axes.empty(1,0);
        hHsaiLine = matlab.graphics.primitive.Line.empty(1,0);
        
        hUpdateTimer;
        hLsaiTask;
        hLsaoTask = dabs.vidrio.ddi.rdi.AoTask.empty(1,0);
        hLsaoDot = matlab.graphics.primitive.Line.empty(1,0);
        
        hPwmTask;
        
        lastTempUpdate;
        hsaiDataSize;
        hsaiActive = false;
        hsaiScaleHistory = {[] [] [] []};
        
        lsaiActive = false;
        lsaiChanEnable;
        lsaiScaleHistory;
        lsaiColors = {[0 0 0] [0 0 1] [1 0 0] [0 1 0] [1 0 1] [.5 .25 0] [0.6392 0.2863 0.6431] [.75 .5 .25] [.5 .5 1] [0 .5 .5] [0 1 1] [1 .5 0]};
        
        lsaoActive;
        
        numAo;
        numAi;
        
        enableStatTracking = false;
        statPrintPeriod = 60*5;
        lastStatPrint = [];
        initMode = true;
    end
    
    properties (SetObservable)
        hsaiSampleRate = 125e6;
        hsaiTimeSpan = .1e-3;
        hsaiAutoScale = true;
        hsaiFilter = '30 MHz';
        hsaiChannel = 1;
        
        lsaiSampleRate = 500e3;
        lsaiTimeSpan = 100e-3;
        lsaiAutoScale = true;
        
        lsaoSampleRate = 1e6;
        aoFgFunctionIdx = 1
        aoFgAmplitude = 1;
        aoFgOffset = 0;
        aoFgFrequency = 2;
        
        pwmMeasDebounce = 0;
        
        pwmGenF = 10;
        pwmGenDC = 0.5;
    end
    
    properties (SetObservable, Hidden)
        hsaiInputRangeSel = 1;
        pwmMeasChanSel = 1;
        pwmGenChanSel = 1;
        
        dioOvCache = zeros(16,1);
        rtsiOvCache = zeros(16,1);
        
        errCnt = 0;
        maxErrCnt = 0;
    end
    
    %% LifeCycle
    methods
        function obj = VdaqTestPanel(daqId,simulate)
            if nargin < 1
                daqId = 0;
            end
            
            if nargin < 2
                simulate = false;
            end
            
            obj = obj@most.Gui([], [], [1620 1000]);
            set(obj.hFig,'Name','vDAQ Test Panel');
            
            
            h = msgbox('Loading vDAQ Test Panel...');
            h.Units = 'pixels';
            p = h.Position;
            h.Position = most.gui.centeredScreenPos(p(3:4));
            delete(h.Children(1));
            h.Children.Position = [.5 .5 1 1];
            h.Children.Children.Position = [.5 .5 0];
            h.Children.Children.HorizontalAlignment = 'center';
            h.Children.Children.VerticalAlignment = 'middle';
            drawnow();
            
            try
                obj.vdaqId = daqId;
                
                obj.deviceInfo = dabs.vidrio.rdi.Device.getDeviceInfo(daqId);
                if ~dabs.vidrio.rdi.Device.getDriverInfo.numDevices && ~simulate
                    error('No vDAQ devices found. Please make sure device and latest driver are installed.');
                elseif dabs.vidrio.rdi.Device.getDriverInfo.numDevices || ~simulate
                    assert(~isempty(obj.deviceInfo), 'Invalid device ID.');
                    obj.deviceInfo.simulated = 0;
                else
                    obj.deviceInfo(end+1).productName = 'vDAQ';
                    obj.deviceInfo.hardwareRevision = 1;
                    obj.deviceInfo.numClients = 0;
                    obj.deviceInfo.simulated = 1;
                end
                
                hResourceStore = dabs.resources.ResourceStore();
                obj.hvDAQ = hResourceStore.filterByName(sprintf('vDAQ%d',daqId));
                
                if obj.hvDAQ.externalUsers > 0
                    resp = questdlg('Another application is currently accessing the vDAQ. Opening test panel might interrupt that application. Continue?', 'vDAQ Test Panel','Continue','Cancel','Cancel');
                    if strcmp(resp, 'Cancel')
                        delete(obj);
                        delete(h);
                        return;
                    end
                end
                
                obj.isR1 = isa(obj.hvDAQ, 'dabs.resources.daqs.vDAQR1');
                obj.numAo = numel(obj.hvDAQ.hAOs);
                obj.numAi = numel(obj.hvDAQ.hAIs);
                obj.lsaoActive = false(obj.numAo,1);
                
                %% init gui
                mainFlow = most.gui.uiflowcontainer('parent',obj.hFig,'flowdirection','topdown','margin',8);
                
                textProps = {'fontSize',10};
                diagPanel = most.gui.uipanel('parent',mainFlow,'title','General Info / Diagnostics',textProps{:},'HeightLimits',50);
                hsaiPanel = most.gui.uipanel('parent',mainFlow,'title','High Speed Analog Input',textProps{:});
                
                lsFlow = most.gui.uiflowcontainer('parent',mainFlow,'flowdirection','lefttoright','margin',0.0001,'HeightLimits',532);
                lsaiPanel = most.gui.uipanel('parent',lsFlow,'title','Low Speed Analog Input',textProps{:});
                most.gui.uipanel('parent',lsFlow,'bordertype','none','WidthLimits',16);
                aoFlow = most.gui.uiflowcontainer('parent',lsFlow,'flowdirection','topdown','margin',0.0001,'WidthLimits',474+236*obj.isR1);
                
                dioFlowI = most.gui.uiflowcontainer('parent',mainFlow,'flowdirection','lefttoright','margin',0.0001,'HeightLimits',144);
                dioPanel = most.gui.uipanel('parent',dioFlowI,'title','Digital Input / Output',textProps{:});
                most.gui.uipanel('parent',dioFlowI,'bordertype','none','WidthLimits',6);
                pwmMeasPanel = most.gui.uipanel('parent',dioFlowI,'title','PWM Measurement',textProps{:},'WidthLimits',240);
                most.gui.uipanel('parent',dioFlowI,'bordertype','none','WidthLimits',6);
                pwmGenPanel = most.gui.uipanel('parent',dioFlowI,'title','PWM Generation',textProps{:},'WidthLimits',192);
                
                %% Diagnostics
                diagFlow = most.gui.uiflowcontainer('parent',diagPanel,'flowdirection','lefttoright');
                
                most.gui.staticText('parent',diagFlow,'String','Product Name:','horizontalalignment','right','WidthLimits',100,textProps{:});
                obj.stProdName = most.gui.staticText('parent',diagFlow,'String','','WidthLimits',90,textProps{:});
                
                most.gui.staticText('parent',diagFlow,'String','Firmware Version:','horizontalalignment','right','WidthLimits',130,textProps{:});
                obj.stFwVersion = most.gui.staticText('parent',diagFlow,'String','','WidthLimits',50,textProps{:});
                
                most.gui.staticText('parent',diagFlow,'String','Serial Number:','horizontalalignment','right','WidthLimits',100,textProps{:});
                obj.stSerialNumber = most.gui.staticText('parent',diagFlow,'String','','WidthLimits',100,textProps{:});
                
                most.gui.staticText('parent',diagFlow,'String','Temperature:','horizontalalignment','right','WidthLimits',80,textProps{:});
                obj.stTemperature = most.gui.staticText('parent',diagFlow,'WidthLimits',40,textProps{:});
                
                most.gui.staticText('parent',diagFlow,'String','Errors:','horizontalalignment','right','WidthLimits',80,textProps{:});
                obj.stErrorMessages = most.gui.staticText('parent',diagFlow,'String','None',textProps{:});
                
                %% HS AI
                hsaiFlow = most.gui.uiflowcontainer('parent',hsaiPanel,'flowdirection','lefttoright','margin',0.0001);
                hsaiOptionFlow = most.gui.uiflowcontainer('parent',hsaiFlow,'flowdirection','topdown','WidthLimits',190,'margin',0.0001);
                hsaiOptionFlowT = most.gui.uiflowcontainer('parent',hsaiOptionFlow,'flowdirection','topdown','margin',0.0001);
                hsaiOptionFlowB = most.gui.uiflowcontainer('parent',hsaiOptionFlow,'flowdirection','bottomup','margin',8,'HeightLimits',48);
                
                rowflow = most.gui.uiflowcontainer('parent',hsaiOptionFlowT,'flowdirection','lefttoright','HeightLimits',30);
                most.gui.staticText('parent',rowflow,'String','Input Range:','horizontalalignment','right','WidthLimits',100,textProps{:});
                obj.pmInputRange = most.gui.uicontrol('parent',rowflow,'style','popupmenu',textProps{:},'Bindings', {obj 'hsaiInputRangeSel' 'value'});
                
                obj.hFiltFlow = most.gui.uiflowcontainer('parent',hsaiOptionFlowT,'flowdirection','lefttoright','HeightLimits',30);
                most.gui.staticText('parent',obj.hFiltFlow,'String','Filter Bandwidth:','horizontalalignment','right','WidthLimits',130,textProps{:});
                obj.etHsaiFilter = most.gui.uicontrol('parent',obj.hFiltFlow,'style','edit','Bindings',{obj 'hsaiFilter' 'string'},textProps{:});
                
                obj.hChanFlow = most.gui.uiflowcontainer('parent',hsaiOptionFlowT,'flowdirection','lefttoright','HeightLimits',30,'visible','off');
                most.gui.staticText('parent',obj.hChanFlow,'String','Channel:','horizontalalignment','right','WidthLimits',100,textProps{:});
                most.gui.uicontrol('parent',obj.hChanFlow,'style','popupmenu','string',{'HSAI0' 'HSAI1'},'Bindings',{obj 'hsaiChannel' 'value'},textProps{:});
                
                rowflow = most.gui.uiflowcontainer('parent',hsaiOptionFlowT,'flowdirection','lefttoright','HeightLimits',30);
                most.gui.staticText('parent',rowflow,'String','Sample Rate (MHz):','horizontalalignment','right','WidthLimits',130,textProps{:});
                obj.etHsaiSampleRate = most.gui.uicontrol('parent',rowflow,'style','edit','Bindings',{obj 'hsaiSampleRate' 'value' '%.2f' 'scaling' 1e-6},textProps{:});
                
                rowflow = most.gui.uiflowcontainer('parent',hsaiOptionFlowT,'flowdirection','lefttoright','HeightLimits',30);
                most.gui.staticText('parent',rowflow,'String','Time Span (us):','horizontalalignment','right','WidthLimits',130,textProps{:});
                obj.etHsaiTimescale = most.gui.uicontrol('parent',rowflow,'style','edit','Bindings',{obj 'hsaiTimeSpan' 'value' '%.2f' 'scaling' 1e6},textProps{:});
                
                rowflow = most.gui.uiflowcontainer('parent',hsaiOptionFlowT,'flowdirection','lefttoright','HeightLimits',30);
                most.gui.staticText('parent',rowflow,'String','Autoscale Axes:','horizontalalignment','right','WidthLimits',130,textProps{:});
                obj.cbHsaiAs = most.gui.uicontrol('parent',rowflow,'style','checkbox',textProps{:},'Bindings',{obj 'hsaiAutoScale' 'value'});
                
                obj.pbHsaiStart = most.gui.uicontrol('parent',hsaiOptionFlowB,'string','Start Monitoring',textProps{:},'callback',@obj.toggleHsaiMonitoring);
                
                for i = 0:3
                    obj.hChannelPannels(end+1) = most.gui.uipanel('parent',hsaiFlow,'bordertype','none');
                    obj.hHsaiAx(end+1) = most.idioms.axes('parent',obj.hChannelPannels(end),'box','on','xticklabel',[],'xgrid','on','ygrid','on','ylim',2^13*[-1.1 1.1]);
                    title(obj.hHsaiAx(end), sprintf('AI%d',i));
                    obj.hHsaiLine(end+1) = line('parent',obj.hHsaiAx(end),'color','k','xdata',nan,'ydata',nan);
                end
                
                %% LS AI
                lsaiFlow = most.gui.uiflowcontainer('parent',lsaiPanel,'flowdirection','lefttoright','margin',0.0001);
                lsaiOptionFlow = most.gui.uiflowcontainer('parent',lsaiFlow,'flowdirection','topdown','WidthLimits',190,'margin',0.0001);
                lsaiOptionFlowT = most.gui.uiflowcontainer('parent',lsaiOptionFlow,'flowdirection','topdown','margin',0.0001);
                lsaiOptionFlowB = most.gui.uiflowcontainer('parent',lsaiOptionFlow,'flowdirection','bottomup','margin',8,'HeightLimits',48);
                
                rowflow = most.gui.uiflowcontainer('parent',lsaiOptionFlowT,'flowdirection','lefttoright','HeightLimits',30);
                most.gui.staticText('parent',rowflow,'String','Sample Rate (kHz):','horizontalalignment','right','WidthLimits',130,textProps{:});
                most.gui.uicontrol('parent',rowflow,'style','edit','Bindings',{obj 'lsaiSampleRate' 'value' '%.2f' 'scaling' 1e-3},textProps{:});
                
                rowflow = most.gui.uiflowcontainer('parent',lsaiOptionFlowT,'flowdirection','lefttoright','HeightLimits',30);
                most.gui.staticText('parent',rowflow,'String','Time Span (ms):','horizontalalignment','right','WidthLimits',130,textProps{:});
                most.gui.uicontrol('parent',rowflow,'style','edit','Bindings',{obj 'lsaiTimeSpan' 'value' '%.2f' 'scaling' 1e3},textProps{:});
                
                rowflow = most.gui.uiflowcontainer('parent',lsaiOptionFlowT,'flowdirection','lefttoright','HeightLimits',30);
                most.gui.staticText('parent',rowflow,'String','Autoscale Axes:','horizontalalignment','right','WidthLimits',130,textProps{:});
                most.gui.uicontrol('parent',rowflow,'style','checkbox',textProps{:},'Bindings',{obj 'lsaiAutoScale' 'value'});
                
                
                rowflow = most.gui.uiflowcontainer('parent',lsaiOptionFlowT,'flowdirection','lefttoright','margin',0.0001);
                most.gui.uipanel('parent',rowflow,'bordertype','none','WidthLimits',20);
                lflow = most.gui.uiflowcontainer('parent',rowflow,'flowdirection','topdown','margin',1);
                
                obj.pbLsaiStart = most.gui.uicontrol('parent',lsaiOptionFlowB,'string','Start Monitoring',textProps{:},'callback',@obj.toggleLsaiMonitoring);
                
                plotPannel = most.gui.uipanel('parent',lsaiFlow,'bordertype','none');
                obj.hLsaiAx = most.idioms.axes('parent',plotPannel,'title',sprintf('AI%d',i),'box','on','xticklabel',[],'xgrid','on','ygrid','on','ylim',10.1*[-1 1]);
                for i = 0:(3 + 8*obj.isR1)
                    obj.hLsaiLine(end+1) = line('parent',obj.hLsaiAx,'color','k','xdata',nan,'ydata',nan);
                    
                    rowflow = most.gui.uiflowcontainer('parent',lflow,'flowdirection','lefttoright','HeightLimits',30);
                    obj.cbLsaiEn(end+1) = most.gui.uicontrol('parent',rowflow,'style','checkbox',textProps{:},'callback',@obj.setLsaiChanEn,'string',sprintf('AI%d',i),'WidthLimits',50);
                    p = most.gui.uipanel('parent',rowflow,'bordertype','none','WidthLimits',100);
                    a = most.idioms.axes('parent',p,'title',sprintf('AI%d',i),'box','on','xticklabel',[],'xlim',[0 1],'ylim',[0 1],'xcolor','none','ycolor','none','color','none');
                    obj.hLsaiLegendLine(end+1) = line('parent',a,'color','k','xdata',[0 1],'ydata',[.5 .5],'linewidth',3);
                end
                
                %% LS AO
                for i = 0:(2+obj.isR1)
                    arf = most.gui.uiflowcontainer('parent',aoFlow,'flowdirection','lefttoright','HeightLimits',104,'margin',0.0001);
                    for j = 0:(1+obj.isR1)
                        aoCh = i*(2+obj.isR1) + j;
                        ind = aoCh + 1;
                        
                        if j
                            most.gui.uipanel('parent',arf,'bordertype','none','WidthLimits',12);
                        end
                        
                        if aoCh < obj.numAo
                            newOutputPropName = sprintf('lsaoNewOutput%d',aoCh);
                            p1 = obj.addprop(newOutputPropName);
                            p1.SetObservable = true;
                            p1.Hidden = true;
                            obj.(newOutputPropName) = 0;
                            
                            aoPanel = most.gui.uipanel('parent',arf,'title',sprintf('Analog Ouptut %d',aoCh),textProps{:},'Visible',obj.tfMap(aoCh < obj.numAo));
                            aoFlowi = most.gui.uiflowcontainer('parent',aoPanel,'flowdirection','topdown','margin',0.0001);
                            
                            rowflow = most.gui.uiflowcontainer('parent',aoFlowi,'flowdirection','lefttoright','HeightLimits',30);
                            most.gui.staticText('parent',rowflow,'String','Current Output (V):','horizontalalignment','right','WidthLimits',115,textProps{:});
                            obj.etAoCurrentVal(ind) = most.gui.uicontrol('parent',rowflow,'style','edit','string','0.00',textProps{:},'enable','inactive','backgroundcolor',.95*ones(1,3),'WidthLimits',44);
                            
                            rowflow = most.gui.uiflowcontainer('parent',aoFlowi,'flowdirection','lefttoright','HeightLimits',30);
                            most.gui.staticText('parent',rowflow,'String','New Output (V):','horizontalalignment','right','WidthLimits',115,textProps{:});
                            obj.etAoNewVal(ind) = most.gui.uicontrol('parent',rowflow,'style','edit','string','0.00',textProps{:},'WidthLimits',44,'Bindings',{obj newOutputPropName 'value' '%.2f'},'Callback',@(varargin)obj.setSliderVal(ind));
                            obj.pbUpdateAo(ind) = most.gui.uicontrol('parent',rowflow,'string','Set',textProps{:},'WidthLimits',40,'callback',@(varargin)obj.updateAo(aoCh));
                            obj.cbLiveAo(ind) = most.gui.uicontrol('parent',rowflow,'style','checkbox',textProps{:},'callback',@(src,~)obj.setAoLive(aoCh,src));
                            
                            obj.slAoNewVal(ind) = most.gui.slider('parent',aoFlowi,'HeightLimits',20,'Bindings',{obj newOutputPropName 1},'max',10,'min',-10,'Callback',@(varargin)obj.setSliderVal(ind));
                            obj.hLsaoDot(ind) = line('parent',obj.slAoNewVal(ind).hAx,'xdata',.5,'ydata',.5,'markersize',16,'marker','.','pickableparts','none');
                        else
                            most.gui.uipanel('parent',arf,'bordertype','none');
                        end
                    end
                    most.gui.uipanel('parent',aoFlow,'bordertype','none','HeightLimits',8);
                end
                
                aoFlow = most.gui.uiflowcontainer('parent',aoFlow,'flowdirection','bottomup','margin',0.0001);
                aoPanel = most.gui.uipanel('parent',aoFlow,'title',sprintf('Analog Output Waveform Generation'),textProps{:},'HeightLimits',106-22*obj.isR1);
                aoFlowi = most.gui.uiflowcontainer('parent',aoPanel,'flowdirection','topdown','margin',0.0001);

                rowflow = most.gui.uiflowcontainer('parent',aoFlowi,'flowdirection','lefttoright','HeightLimits',28);
                most.gui.staticText('parent',rowflow,'String','Function:','horizontalalignment','right','WidthLimits',60,textProps{:});
                most.gui.uicontrol('parent',rowflow,'style','popupmenu','string',{'Sine Wave' 'Square Wave' 'Triangle Wave' 'Sawtooth'},'Bindings',{obj 'aoFgFunctionIdx' 'value'},'WidthLimits',106,textProps{:});

                most.gui.staticText('parent',rowflow,'String','Amplitude (V):','horizontalalignment','right','WidthLimits',120,textProps{:});
                most.gui.uicontrol('parent',rowflow,'style','edit','string','1.00',textProps{:},'WidthLimits',44,'Bindings',{obj 'aoFgAmplitude' 'value' '%.2f'});
                
                if ~obj.isR1
                    rowflow = most.gui.uiflowcontainer('parent',aoFlowi,'flowdirection','lefttoright','HeightLimits',28);
                end
                most.gui.staticText('parent',rowflow,'String','Offset (V):','horizontalalignment','right','WidthLimits',90,textProps{:});
                most.gui.uicontrol('parent',rowflow,'style','edit','string','0.00',textProps{:},'WidthLimits',44,'Bindings',{obj 'aoFgOffset' 'value' '%.2f'});

                most.gui.staticText('parent',rowflow,'String','Frequency (Hz):','horizontalalignment','right','WidthLimits',130,textProps{:});
                most.gui.uicontrol('parent',rowflow,'style','edit','string','100',textProps{:},'WidthLimits',44,'Bindings',{obj 'aoFgFrequency' 'value' '%.2f'});

                rowflow = most.gui.uiflowcontainer('parent',aoFlowi,'flowdirection','lefttoright','HeightLimits',30);
                most.gui.staticText('parent',rowflow,'String','  Start Generation:','horizontalalignment','left','WidthLimits',110,textProps{:});
                for ch = 0:(4+7*obj.isR1)
                    obj.pbAoStartGen(ch+1) = most.gui.uicontrol('parent',rowflow,'style','togglebutton','string',num2str(ch),textProps{:},'callback',@(varargin)obj.startWaveformGen(ch));
                end
                most.gui.uipanel('parent',rowflow,'bordertype','none','WidthLimits',6);
                
                %% dio
                dioFlow = most.gui.uiflowcontainer('parent',dioPanel,'flowdirection','topdown','margin',0.0001);
                
                dioGroupsFlow = most.gui.uiflowcontainer('parent',dioFlow,'flowdirection','lefttoright','margin',0.0001);
                tH = 18;
                H = 34;
                
                labelFlow = most.gui.uiflowcontainer('parent',dioGroupsFlow,'flowdirection','topdown','WidthLimits',100,'margin',0.0001);
                f = most.gui.uiflowcontainer('parent',labelFlow,'flowdirection','lefttoright','HeightLimits',tH);
                most.gui.staticText('parent',f,'String','Digital Channel','horizontalalignment','right',textProps{:});
                f = most.gui.uiflowcontainer('parent',labelFlow,'flowdirection','lefttoright','HeightLimits',H);
                most.gui.staticText('parent',f,'String','Input Value','horizontalalignment','right',textProps{:});
                f = most.gui.uiflowcontainer('parent',labelFlow,'flowdirection','lefttoright','HeightLimits',H);
                most.gui.staticText('parent',f,'String','Input/Output','horizontalalignment','right',textProps{:});
                f = most.gui.uiflowcontainer('parent',labelFlow,'flowdirection','lefttoright','HeightLimits',H);
                most.gui.staticText('parent',f,'String','Output Value','horizontalalignment','right',textProps{:});
                
                for grp = 0:(2+obj.isR1)
                    groupFlow = most.gui.uiflowcontainer('parent',dioGroupsFlow,'flowdirection','topdown','margin',0.0001);
                    groupLbl = most.gui.uiflowcontainer('parent',groupFlow,'flowdirection','lefttoright','HeightLimits',tH);
                    groupIv = most.gui.uiflowcontainer('parent',groupFlow,'flowdirection','lefttoright','HeightLimits',H);
                    groupOe = most.gui.uiflowcontainer('parent',groupFlow,'flowdirection','lefttoright','HeightLimits',H);
                    groupOv = most.gui.uiflowcontainer('parent',groupFlow,'flowdirection','lefttoright','HeightLimits',H);
                    
                    if (obj.isR1 && (grp == 2)) || (~obj.isR1 && (grp == 1))
                        most.gui.uicontrol('parent',groupOe,'style','togglebutton','string','Input Only',textProps{:},'enable','inactive');
                    elseif (obj.isR1 && (grp == 3)) || (~obj.isR1 && (grp == 2))
                        most.gui.uicontrol('parent',groupOe,'style','togglebutton','string','Output Only',textProps{:},'enable','inactive','value',1);
                    end
                    
                    for i = 0:7
                        most.gui.staticText('parent',groupLbl,'String',sprintf('%d.%d',grp,i),'horizontalalignment','center',textProps{:});
                        obj.tbDio_i(end+1) = most.gui.uicontrol('parent',groupIv,'style','togglebutton','string','0','enable','inactive',textProps{:});
                        if grp < (2 - ~obj.isR1)
                            obj.tbDio_oe(end+1) = most.gui.uicontrol('parent',groupOe,'style','togglebutton','string','IN',textProps{:},'callback',@(varargin)obj.setDioOe(grp*8+i));
                        end
                        if (grp < (2 - ~obj.isR1)) || (grp > (1 + obj.isR1))
                            obj.tbDio_ov(end+1) = most.gui.uicontrol('parent',groupOv,'style','togglebutton','string','0',textProps{:},'callback',@(varargin)obj.setDioOv(grp*8+i));
                        else
                            obj.tbDio_ov(end+1) = most.gui.uicontrol('parent',groupOv,'visible','off');
                        end
                    end
                    
                    obj.tbDio_i_Value  = false(size(obj.tbDio_i));
                    obj.tbDio_oe_Value = false(size(obj.tbDio_oe));
                    obj.tbDio_ov_Value = cell(size(obj.tbDio_ov));
                end
                
                %% pwm meas
                pwmFlo = most.gui.uiflowcontainer('parent',pwmMeasPanel,'flowdirection','topdown','margin',0.0001);
                
                options = [{' '}; arrayfun(@(p){arrayfun(@(l){sprintf('D%d.%d',p,l)},0:7)'},0:(2+obj.isR1))'; {arrayfun(@(r){sprintf('RTSI%d',r)},0:15)'}];
                options = vertcat(options{:});
                rowflow = most.gui.uiflowcontainer('parent',pwmFlo,'flowdirection','lefttoright','HeightLimits',30);
                most.gui.staticText('parent',rowflow,'String','Input Channel:','horizontalalignment','right','WidthLimits',110,textProps{:});
                most.gui.uicontrol('parent',rowflow,'style','popupmenu','string',options,textProps{:},'WidthLimits',68,'Bindings', {obj 'pwmMeasChanSel' 'value'});
                
                rowflow = most.gui.uiflowcontainer('parent',pwmFlo,'flowdirection','lefttoright','HeightLimits',30);
                most.gui.staticText('parent',rowflow,'String','Signal Debounce:','horizontalalignment','right','WidthLimits',110,textProps{:});
                most.gui.uicontrol('parent',rowflow,'style','edit',textProps{:},'WidthLimits',40,'Bindings', {obj 'pwmMeasDebounce' 'value'});
                
                rowflow = most.gui.uiflowcontainer('parent',pwmFlo,'flowdirection','lefttoright','HeightLimits',30);
                most.gui.staticText('parent',rowflow,'String','Frequency:','horizontalalignment','right','WidthLimits',110,textProps{:});
                obj.etFreq = most.gui.uicontrol('parent',rowflow,'style','edit','string','',textProps{:},'enable','inactive','backgroundcolor',.95*ones(1,3),'WidthLimits',115);
                
                rowflow = most.gui.uiflowcontainer('parent',pwmFlo,'flowdirection','lefttoright','HeightLimits',30);
                most.gui.staticText('parent',rowflow,'String','Pulse Width / DC:','horizontalalignment','right','WidthLimits',110,textProps{:});
                obj.etPW = most.gui.uicontrol('parent',rowflow,'style','edit','string','',textProps{:},'enable','inactive','backgroundcolor',.95*ones(1,3),'WidthLimits',115);
                
                %% pwm gen
                pwmFlo = most.gui.uiflowcontainer('parent',pwmGenPanel,'flowdirection','topdown','margin',0.0001);
                
                if obj.isR1
                    ps = [0 1 3];
                else
                    ps = [0 2];
                end
                options = [arrayfun(@(p){arrayfun(@(l){sprintf('D%d.%d',p,l)},0:7)'},ps)'; {arrayfun(@(r){sprintf('RTSI%d',r)},0:15)'}];
                options = vertcat(options{:});
                rowflow = most.gui.uiflowcontainer('parent',pwmFlo,'flowdirection','lefttoright','HeightLimits',30);
                most.gui.staticText('parent',rowflow,'String','Output Channel:','horizontalalignment','right','WidthLimits',110,textProps{:});
                obj.pmPwmGenCh = most.gui.uicontrol('parent',rowflow,'style','popupmenu','string',options,textProps{:},'WidthLimits',68,'Bindings', {obj 'pwmGenChanSel' 'value'});
                
                rowflow = most.gui.uiflowcontainer('parent',pwmFlo,'flowdirection','lefttoright','HeightLimits',30);
                most.gui.staticText('parent',rowflow,'String','Frequency (kHz):','horizontalalignment','right','WidthLimits',110,textProps{:});
                obj.etPwmGenF = most.gui.uicontrol('parent',rowflow,'style','edit','string','',textProps{:},'Bindings', {obj 'pwmGenF' 'value'},'WidthLimits',68);
                
                rowflow = most.gui.uiflowcontainer('parent',pwmFlo,'flowdirection','lefttoright','HeightLimits',30);
                most.gui.staticText('parent',rowflow,'String','Duty Cycle (%):','horizontalalignment','right','WidthLimits',110,textProps{:});
                obj.etPwmGenDC = most.gui.uicontrol('parent',rowflow,'style','edit','string','',textProps{:},'Bindings', {obj 'pwmGenDC' 'value'},'WidthLimits',68);
                
                rowflow = most.gui.uiflowcontainer('parent',pwmFlo,'flowdirection','lefttoright','HeightLimits',32);
                obj.pbPwmGen = uicontrol('parent',rowflow,'string','Start Generation',textProps{:},'callback',@obj.startPwmGen);
                
                %%
                obj.hUpdateTimer = timer;
                obj.hUpdateTimer.Period = .05;
                obj.hUpdateTimer.ExecutionMode = 'FixedSpacing';
                obj.hUpdateTimer.TimerFcn = @obj.updateData;
                
                varname = sprintf('hVdaq%d',obj.vdaqId);
                if evalin('base',['exist(''' varname ''')'])
                    evalin('base',['delete(' varname '); clear ' varname])
                end
                
                %% load fpga
                h.Children.Children.String = 'Initializing FPGA...';
                drawnow();
                
                obj.hFpga = obj.hvDAQ.hDevice;
                
                obj.hDelListener(end+1) = most.ErrorHandler.addCatchingListener(obj.hvDAQ,'ObjectBeingDestroyed',@(varargin)obj.delete);
                obj.hDelListener(end+1) = most.ErrorHandler.addCatchingListener(obj.hFpga,'ObjectBeingDestroyed',@(varargin)obj.delete);
                
                showMissingAfeWarning = isnan(obj.hFpga.dataClkRate) || isempty(obj.hFpga.nominalAcqSampleRate);
                
                if showMissingAfeWarning
                    try
                        obj.hFpga.configureAfeSampleClock();
                        showMissingAfeWarning = false;
                    catch
                        showMissingAfeWarning = true;
                    end
                end
                
                if showMissingAfeWarning
                    obj.pmInputRange.String = {'2 Vpp'};
                    obj.pmInputRange.Enable = 'off';
                    obj.pbHsaiStart.Enable = 'off';
                    obj.cbHsaiAs.Enable = 'off';
                    obj.etHsaiTimescale.Enable = 'off';
                    obj.etHsaiSampleRate.Enable = 'off';
                    obj.etHsaiFilter.Enable = 'off';
                    set(obj.hHsaiAx, 'Color', .94*ones(1,3));
                else
                    % prepare high speed data scope
                    obj.hDataScope = scanimage.components.scan2d.rggscan.DataScope(obj.hFpga);
                    obj.hDataScope.callbackFcn = @obj.dataScopeCb;
                    obj.hDataScope.errorCallbackFcn = @obj.dataScopeErrorCb;
                    
                    obj.isH = obj.hDataScope.isH;
                    if obj.isH
                        obj.hFiltFlow.Visible = 0;
                        obj.hChanFlow.Visible = 1;
                        set(obj.hChannelPannels(2:end),'visible',0);
                        
                        u = obj.hChannelPannels(1);
                        u.SizeChangedFcn = @obj.resizePlt;
                        
                        a = obj.hHsaiAx(1);
                        a.Title.Visible = 0;
                        a.YLim = 1.1 * 2^11 * [-1 1];
                    else
                        obj.hsaiFilter = obj.hFpga.getChannelsFilter();
                    end
                    
                    
                    % get input range options and settings
                    obj.pmInputRange.String = arrayfun(@(v){sprintf('%d Vpp',v)}, obj.hFpga.hAfe.availableInputRanges);
                    [tf,idx] = ismember(max(obj.hFpga.getChannelsInputRanges()),obj.hFpga.hAfe.availableInputRanges);
                    if tf
                        sel = idx;
                    else
                        sel = 1;
                    end
                    obj.hsaiInputRangeSel = sel;
                    obj.initMode = false;
                    
                    obj.hsaiSampleRate = obj.hFpga.nominalAcqSampleRate;
                end
                
                obj.hLsaiTask = dabs.vidrio.ddi.AiTask(obj.hFpga, 'vDAQ AI Test Task');
                obj.lsaiSampleRate = 500e3;
                obj.lsaiChanEnable = false(obj.numAi,1);
                obj.lsaiChanEnable(1:4) = true;
                
                for i = 1:obj.numAo
                    obj.hLsaoTask(i) = dabs.vidrio.ddi.AoTask(obj.hFpga, sprintf('vDAQ AO%d Test Task',i-1));
                    obj.hLsaoTask(i).addChannel(i-1);
                end
                
                obj.stProdName.String = obj.deviceInfo.productName;
                obj.stFwVersion.String = obj.deviceInfo.firmwareVersion;
                obj.stSerialNumber.String = obj.hFpga.deviceSerialNumber;
                
                obj.updateData();
                start(obj.hUpdateTimer);
                
                assignin('base',varname,obj);
                
                obj.Visible = true;
                delete(h);
                
                if showMissingAfeWarning
                    warndlg('High speed analog module not detected. High speed sampling functionality will not be available.');
                end
            catch ME
                errordlg(sprintf('Failed to load vDAQ Test Panel. %s', ME.message),'vDAQ Test Panel');
                delete(h);
                delete(obj);
                ME.rethrow
            end
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hDelListener);
            most.idioms.safeDeleteObj(obj.hDataScope);
            
            if ~isempty(obj.hUpdateTimer)
                stop(obj.hUpdateTimer);
            end
            most.idioms.safeDeleteObj(obj.hUpdateTimer);
            most.idioms.safeDeleteObj(obj.hLsaiTask);
            most.idioms.safeDeleteObj(obj.hLsaoTask);
            most.idioms.safeDeleteObj(obj.hPwmTask);
            
            if isempty(obj.hvDAQ.getAllUsers())
                obj.hvDAQ.deinitFPGA();
            end
            
            % clear vars from workspace
            if evalin('base','exist(''ans'',''var'')') && evalin('base','numel(ans) == 1') && (obj == evalin('base','ans'))
                evalin('base','clear ans');
            end
            
            varname = sprintf('hVdaq%d',obj.vdaqId);
            if evalin('base',['exist(''' varname ''')']) && (obj == evalin('base',varname))
                evalin('base',['clear ' varname]);
            end
        end
    end
    
    methods
        function resizePlt(obj,varargin)
            u = obj.hChannelPannels(1);
            a = u.Children;
            
            u.Units = 'pixels';
            p = u.Position;
            
            a.Units = 'pixels';
            lm = 48;
            m = 20;
            tm = 12;
            a.Position = [lm m p([3 4])] - [0 0 (lm+m) (m+tm)];
        end
        
        function dataScopeErrorCb(obj,~,~)
            [rateBPS, bytes, ticks] = obj.hFpga.hScopeFifo.calcDataRate();
            
            obj.stopHsaiMonitoring();
            
            if obj.enableStatTracking
                fprintf(2,'HSAI Failure occurred at %s. Throughput measurement:\n', datestr(clock))
                fprintf(2,'%.3fMB transefered over %d consecutive clock cycles. Effective rate: %.3fMB/s\n',...
                    bytes*1e-6, ticks, rateBPS*1e-6);
                try
                    obj.startHsaiMonitoring();
                catch ME
                    most.ErrorHandler.logAndReportError(ME,'Failed to restart HSAI.');
                end
            else
                warndlg(sprintf('Data transfer failure. PCIe bandwidth may be insufficient.'));
            end
        end
        
        function dataScopeCb(obj,~,evt)
            nCh = size(evt.data,2);
            N = size(evt.data,1);
            xdat = (1:N)';
            set(obj.hHsaiLine(1:nCh),'XData',xdat);
            set(obj.hHsaiAx(1:nCh),'XLim',[1 N]);
            
            for i = 1:nCh
                obj.hHsaiLine(i).YData = evt.data(:,i);
            end
            
            if obj.hsaiAutoScale
                obj.autoscaleHsai();
            end
        end
        
        function updateData(obj,varargin)
            persistent lt;
            
            if ~most.idioms.isValidObj(obj.hFig)
                delete(obj);
            elseif strcmp(obj.hFig.Visible, 'on')
                if ~isempty(lt)
%                     fprintf('In between: %.4fs\n',toc(lt))
                end
%                 st = tic;
                
                try
                    if isempty(obj.lastTempUpdate) || (toc(obj.lastTempUpdate) > 1)
                        obj.lastTempUpdate = tic;
                        tStr = sprintf('%.1f%cC',obj.hFpga.hSysmon.temperature,most.constants.Unicode.degree_sign);
                        if ~strcmp(tStr,obj.stTemperature.String)
                            obj.stTemperature.String = tStr;
                        end
                    end
                    
                    a = obj.hFpga.hSysmon.alarms;
                    if strcmp(a, 'None')
                        obj.errCnt = 0;
                    else
                        obj.errCnt = obj.errCnt + 1;
                        obj.maxErrCnt = max([obj.maxErrCnt obj.errCnt]);
                        if obj.errCnt < 20
                            a = 'None';
                        end
                    end
                    obj.stErrorMessages.String = a;
                    
                    inVals = obj.hFpga.dio_i;
                    
                    for grp = 0:(2+obj.isR1)
                        for i = 0:7
                            idx = 8*grp+i;
                            
                            iv = logical(bitand(inVals,2^idx));
                            
                            if obj.tbDio_i_Value(idx+1) ~= iv
                                obj.tbDio_i(idx+1).Value = iv;
                                obj.tbDio_i(idx+1).String = num2str(iv);
                                obj.tbDio_i_Value(idx+1) = iv;
                            end
                            
                            indDirCtl = grp < (2 - ~obj.isR1);
                            if indDirCtl || (grp > (1 + obj.isR1))
                                v = obj.hFpga.getDioOutput(idx);
                                
                                if indDirCtl
                                    oe = ~all(isnan(v));
                                    if obj.tbDio_oe_Value(idx+1) ~= oe
                                        obj.tbDio_oe(idx+1).Value = oe;
                                        obj.tbDio_oe(idx+1).String = oeToStr(oe);
                                        obj.tbDio_oe_Value(idx+1) = oe;
                                    end
                                end
                                
                                if isnumeric(v) || islogical(v)
                                    if indDirCtl
                                        if isnan(v)
                                            v = obj.dioOvCache(idx+1);
                                        else
                                            obj.dioOvCache(idx+1) = v;
                                        end
                                    else
                                        v(isnan(v)) = 0;
                                    end
                                    
                                    if ~isequal(obj.tbDio_ov_Value{idx+1},v)
                                        obj.tbDio_ov(idx+1).Value = v;
                                        obj.tbDio_ov(idx+1).String = num2str(v);
                                        obj.tbDio_ov_Value{idx+1} = v;
                                    end
                                else
                                    if ~isequal(obj.tbDio_ov_Value{idx+1},v)
                                        obj.tbDio_ov(idx+1).Value = 0;
                                        if strncmpi(v,'task',4)
                                            obj.tbDio_ov(idx+1).String = 'T';
                                        else
                                            obj.tbDio_ov(idx+1).String = 'SI';
                                        end
                                        obj.tbDio_ov_Value{idx+1} = v;
                                    end
                                end
                            end
                        end
                    end
                    
                    if obj.lsaiActive
                        dispN = round(obj.lsaiSampleRate * obj.lsaiTimeSpan);
                        
                        try
                            dat = obj.hLsaiTask.readInputBuffer();
                            Nnew = size(dat,1);
                            Nold = numel(obj.hLsaiLine(1).YData);
                            actN = min(Nnew + Nold, dispN);
                            set(obj.hLsaiLine,'XData',(1:actN)');
                            set(obj.hLsaiAx,'XLim',[1 actN]);
                            
                            datidx = 1;
                            for i = 1:obj.numAi
                                if obj.lsaiChanEnable(i)
                                    ndat = dat(:,datidx);
                                    datidx = datidx + 1;
                                else
                                    ndat = nan(Nnew,1);
                                end
                                
                                if Nnew >= dispN
                                    ydat = ndat((Nnew-dispN+1):end,:);
                                else
                                    odat = obj.hLsaiLine(i).YData(:);
                                    numo = min(dispN-Nnew,Nold);
                                    ydat = [odat(end-numo+1:end,:); ndat];
                                end
                                obj.hLsaiLine(i).YData = ydat;
                            end
                            
                            if obj.lsaiAutoScale
                                obj.autoscaleLsai();
                            end
                        catch ME
                            fprintf(2, 'LSAI Failure occurred at %s.\nMessage: %s\n', datestr(clock), ME.message)
                            obj.stopLsaiMonitoring();
                            if obj.enableStatTracking
                                try
                                    obj.startLsaiMonitoring();
                                catch ME
                                    most.ErrorHandler.logAndReportError(ME,'Failed to restart LSAI.');
                                end
                            else
                                msg = 'Failed to read precision analog input buffer. PCIe bandwidth may be insufficient. Try lowering sample rate.';
                                warndlg(msg);
                                most.ErrorHandler.logAndReportError(ME, msg);
                            end
                        end
                    end
                    
                    for i = 1:obj.numAo
                        ov = obj.hFpga.hWaveGen(i).outputValue;
                        obj.etAoCurrentVal(i).hCtl.String = sprintf('%.2f',ov);
                        obj.hLsaoDot(i).XData = (ov+10)/20;
                        
                        if obj.hFpga.hWaveGen(i).dmaFailed
                            most.ErrorHandler.logAndReportError('DMA transfer failed for AO%d.',i-1);
                            
                            if obj.enableStatTracking
                                obj.hLsaoTask(i).abort();
                                obj.hLsaoTask(i).start();
                            end
                        end
                    end
                    
                    if obj.enableStatTracking && (isempty(obj.lastStatPrint) || (toc(obj.lastStatPrint) > obj.statPrintPeriod))
                        obj.printAoStats()
                        obj.lastStatPrint = tic;
                    end
                    
                    if obj.pwmMeasChanSel > 1
                        T = obj.hFpga.pwmPeriod;
                        pw = obj.hFpga.pwmPulseWidth;
                        
                        if isempty(T) ||isempty(pw)
                            obj.etFreq.String = '';
                            obj.etPW.String = '';
                        else
                            obj.etFreq.String = sprintf('%.2f kHz',(1/T)/1000);
                            
                            str = most.idioms.engineersStyle(pw,'s');
                            obj.etPW.String = sprintf('%s (%.1f%%)',str,100*pw/T);
                        end
                    else
                        obj.etFreq.String = '';
                        obj.etPW.String = '';
                    end
                    
                catch ME
                    most.ErrorHandler.logAndReportError(ME);
                end
                
%                 fprintf('Duration: %.4fs\n',toc(st))
                lt = tic;
            end
        end
        
        function printAoStats(obj)
            maxStats = [obj.hFpga.hWaveGen.maxTransactionStats];
            
            for i = 1:obj.numAo
                obj.hFpga.hWaveGen(i).resetMaxDmaStats();
            end
            
            fprintf('%s: Max req to data latency: %.3fus, Max data duration: %.3fus\n', datestr(clock), max([maxStats.maxReqToDataLatency_us]), max([maxStats.maxDataDuration_us]));
        end
        
        function startStressTest(obj)
            obj.lsaoSampleRate = 2e6;
            for i = 1:obj.numAo
                if ~obj.hLsaoTask(i).active
                    obj.startWaveformGen(i-1);
                end
            end
            obj.lsaiChanEnable(:) = true;
            
            obj.startLsaiMonitoring();
            obj.startHsaiMonitoring();
            obj.lastStatPrint = [];
            obj.enableStatTracking = 1;
        end
        
        function stopStressTest(obj)
            for i = 1:obj.numAo
                if obj.hLsaoTask(i).active
                    obj.startWaveformGen(i-1); % stops gen if active
                end
            end
            obj.stopLsaiMonitoring();
            obj.stopHsaiMonitoring();
        end
        
        function toggleHsaiMonitoring(obj,varargin)
            if obj.hsaiActive
                obj.stopHsaiMonitoring();
            else
                obj.startHsaiMonitoring();
            end
        end
        
        function stopHsaiMonitoring(obj,varargin)
            obj.hDataScope.abort();
            obj.hsaiActive = false;
            obj.pbHsaiStart.hCtl.String = 'Start Monitoring';
        end
        
        function startHsaiMonitoring(obj,varargin)
            obj.stopHsaiMonitoring();
            
            obj.hDataScope.acquisitionTime = obj.hsaiTimeSpan;
            obj.hDataScope.desiredSampleRate = obj.hsaiSampleRate;
            
            if obj.isH
                obj.hDataScope.channel = obj.hsaiChannel;
            else
                obj.hDataScope.channel = 1:4;
            end
            
            obj.hsaiActive = true;
            obj.pbHsaiStart.hCtl.String = 'Stop Monitoring';
            obj.hsaiScaleHistory = {[] [] [] []};
            obj.hDataScope.startContinuousAcquisition();
        end
        
        function toggleLsaiMonitoring(obj,varargin)
            if obj.lsaiActive
                obj.stopLsaiMonitoring();
            else
                obj.startLsaiMonitoring();
            end
        end
        
        function stopLsaiMonitoring(obj,varargin)
            obj.lsaiActive = false;
            obj.hLsaiTask.abort();
            obj.pbLsaiStart.hCtl.String = 'Start Monitoring';
            obj.pbLsaiStart.hCtl.Enable = 'on';
        end
        
        function startLsaiMonitoring(obj,varargin)
            obj.stopLsaiMonitoring();
            
            obj.pbLsaiStart.hCtl.String = 'Starting...';
            obj.pbLsaiStart.hCtl.Value = 0;
            obj.pbLsaiStart.hCtl.Enable = 'off';
            drawnow();
            
            try
                delete(obj.hLsaiTask);
                obj.hLsaiTask = dabs.vidrio.ddi.AiTask(obj.hFpga, 'vDAQ AI Test Task');
                for i = 1:obj.numAi
                    if obj.lsaiChanEnable(i)
                        obj.hLsaiTask.addChannel(i-1);
                    end
                end
                
                obj.hLsaiTask.sampleMode = 'continuous';
                obj.hLsaiTask.sampleRate = obj.lsaiSampleRate;
                obj.hLsaiTask.bufferSize = obj.lsaiSampleRate;
                
                obj.hLsaiTask.start();
                
                obj.lsaiActive = true;
                obj.pbLsaiStart.hCtl.String = 'Stop Monitoring';
                obj.pbLsaiStart.hCtl.Enable = 'on';
                obj.lsaiScaleHistory = [];
            catch ME
                errordlg(ME.message, 'vDAQ Test Panel');
                obj.pbLsaiStart.hCtl.String = 'Start Monitoring';
                obj.pbLsaiStart.hCtl.Enable = 'on';
            end
        end
        
        function autoscaleHsai(obj)
            for i = 1:4
                scaleHistory = obj.hsaiScaleHistory{i};
                if isempty(scaleHistory)
                    scaleHistory = obj.hHsaiAx(i).YLim;
                end
                
                % calc new lims
                data = obj.hHsaiLine(i).YData;
                if ~isnan(data(1))
                    rg = double([min(data(:)) max(data(:))]);
                    dr = max(1,diff(rg));
                    lims = mean(rg) + .55*dr*[-1 1];
                    
                    % append to lim history
                    scaleHistory = [lims; scaleHistory];
                    scaleHistory(11:end,:) = [];
                    obj.hsaiScaleHistory{i} = scaleHistory;
                    nwlms = [min(scaleHistory(:,1)) max(scaleHistory(:,2))];
                    
                    % slow lim change
                    olims = obj.hHsaiAx(i).YLim;
                    dff = (nwlms - olims) .* [1 -1];
                    d = min(dff,dff*.2) .* [1 -1];
                    obj.hHsaiAx(i).YLim = olims + d;
                end
            end
        end
        
        function setLsaiChanEn(obj,s,~)
            obj.lsaiChanEnable(s == [obj.cbLsaiEn.hCtl]) = s.Value;
        end
        
        function updateLsaiLegend(obj)
            clrIdx = 1;
            for i = 1:obj.numAi
                obj.cbLsaiEn(i).hCtl.Value = obj.lsaiChanEnable(i);
                obj.hLsaiLegendLine(i).Visible = obj.tfMap(obj.lsaiChanEnable(i));
                obj.hLsaiLine(i).Visible = obj.tfMap(obj.lsaiChanEnable(i));
                if obj.lsaiChanEnable(i)
                    obj.hLsaiLegendLine(i).Color = obj.lsaiColors{clrIdx};
                    obj.hLsaiLine(i).Color = obj.lsaiColors{clrIdx};
                    clrIdx = clrIdx + 1;
                end
            end
        end
        
        function autoscaleLsai(obj)
            scaleHistory = obj.lsaiScaleHistory;
            if isempty(scaleHistory)
                scaleHistory = obj.hLsaiAx.YLim;
            end
            
            % calc new lims
            data = [obj.hLsaiLine(obj.lsaiChanEnable).YData];
            rg = double([min(data(:)) max(data(:))]);
            dr = max(.1,diff(rg));
            lims = mean(rg) + .55*dr*[-1 1];
            
            % append to lim history
            scaleHistory = [lims; scaleHistory];
            scaleHistory(11:end,:) = [];
            obj.lsaiScaleHistory = scaleHistory;
            nwlms = [min(scaleHistory(:,1)) max(scaleHistory(:,2))];
            
            % slow lim change
            olims = obj.hLsaiAx.YLim;
            dff = (nwlms - olims) .* [1 -1];
            d = min(dff,dff*.2) .* [1 -1];
            obj.hLsaiAx.YLim = olims + d;
        end
        
        function setSliderVal(obj,ind)
            if obj.cbLiveAo(ind).Value
                prop = sprintf('lsaoNewOutput%d',ind-1);
                obj.hLsaoTask(ind).setChannelOutputValues(obj.(prop));
            end
        end
        
        function updateAo(obj,ch)
            ind = ch+1;
            if obj.lsaoActive(ind)
                obj.startWaveformGen(ch);
            else
                obj.lsaoActive(ind) = false;
                obj.hLsaoTask(ind).abort();
                
                prop = sprintf('lsaoNewOutput%d',ch);
                obj.hLsaoTask(ind).setChannelOutputValues(obj.(prop));
            end
        end
        
        function setAoLive(obj,ch,src)
            ind = ch+1;
            if src.Value
                if obj.lsaoActive(ind)
                    obj.startWaveformGen(ch);
                end
                
                prop = sprintf('lsaoNewOutput%d',ch);
                obj.hLsaoTask(ind).setChannelOutputValues(obj.(prop));
            end
        end
        
        function startWaveformGen(obj,ch)
            ind = ch+1;
            obj.hLsaoTask(ind).abort();
            if obj.lsaoActive(ind)
                obj.lsaoActive(ind) = false;
                obj.pbAoStartGen(ind).Value = 0;
                obj.pbUpdateAo(ind).String = 'Set';
            else
                fcn = obj.aoFgFunctionIdx;
                o = obj.aoFgOffset;
                a = obj.aoFgAmplitude;
                f = obj.aoFgFrequency;
                N = round(obj.lsaoSampleRate / f);
                switch fcn
                    case 1
                        waveform = sin(2*pi*(1:N)/N)';
                    case 2
                        waveform = [ones(floor(N/2),1); -ones(N-floor(N/2),1)];
                    case 3
                        waveform = [linspace(-1,1,floor(N/2)) linspace(1,-1,N-floor(N/2))]';
                    case 4
                        waveform = linspace(-1,1,N)';
                end
                waveform = max(min(o + a * waveform,10),-10);
                
                obj.hLsaoTask(ind).sampleRate = obj.lsaoSampleRate;
                obj.hLsaoTask(ind).sampleMode = 'continuous';
                obj.hLsaoTask(ind).writeOutputBuffer(waveform);
                obj.hLsaoTask(ind).start();
                
                obj.lsaoActive(ind) = true;
                obj.pbAoStartGen(ind).Value = 1;
                obj.pbUpdateAo(ind).String = 'Stop';
                obj.cbLiveAo(ind).Value = 0;
            end
        end
        
        function startPwmGen(obj,varargin)
            if most.idioms.isValidObj(obj.hPwmTask) || strcmp(obj.pbPwmGen.String, 'Stop Generation')
                delete(obj.hPwmTask);
                obj.pbPwmGen.String = 'Start Generation';
                obj.pmPwmGenCh.Enable = 'on';
                obj.etPwmGenF.Enable = 'on';
                obj.etPwmGenDC.Enable = 'on';
            else
                obj.hPwmTask = dabs.vidrio.ddi.DoTask(obj.hFpga,'vDAQ Testpanel PWM Gen');
                
                nd = 8*(2+obj.isR1);
                ch = obj.pwmGenChanSel - 1;
                if ch < nd
                    p = floor(ch/8);
                    c = mod(ch,8);
                    if p > obj.isR1
                        p = p + 1;
                    end
                    ch = sprintf('D%d.%d',p,c);
                else
                    ch = sprintf('rtsi%d',ch - nd);
                end
                
                obj.hPwmTask.addChannel(ch);
                obj.hPwmTask.sampleMode = 'continuous';
                obj.hPwmTask.sampleRate = obj.hPwmTask.maxSampleRate;
                
                N = round(obj.hPwmTask.sampleRate / (obj.pwmGenF*1e3));
                Nh = floor(N * obj.pwmGenDC);
                obj.hPwmTask.writeOutputBuffer([ones(Nh,1); zeros(N-Nh,1)]);
                
                obj.hPwmTask.start();
                
                obj.pbPwmGen.String = 'Stop Generation';
                obj.pmPwmGenCh.Enable = 'off';
                obj.etPwmGenF.Enable = 'off';
                obj.etPwmGenDC.Enable = 'off';
            end
        end
        
        function setDioOe(obj,ch)
            v = obj.hFpga.getDioOutput(ch);
            if isnan(v)
                obj.hFpga.setDioOutput(ch,obj.dioOvCache(ch+1));
            else
                obj.hFpga.setDioOutput(ch,'Z');
            end
        end
        
        function setDioOv(obj,ch)
            v = obj.hFpga.getDioOutput(ch);
            if all(isnan(v)) && (ch < 8*(1+obj.isR1))
                obj.dioOvCache(ch+1) = ~obj.dioOvCache(ch+1);
            elseif ischar(v)
                obj.hFpga.setDioOutput(ch,nan);
            else
                v(isnan(v)) = 0;
                obj.hFpga.setDioOutput(ch,~v);
            end
        end
    end
    
    methods (Static)
        function launch(varargin)
            scanimage.guis.VdaqTestPanel(varargin{:});
        end
    end
    
    %% prop access
    methods
        function set.hsaiTimeSpan(obj,v)
            dataLimit = 24e6;
            maxTime = dataLimit / (obj.hsaiSampleRate * 10);
            
            obj.hsaiTimeSpan = max(min(v,maxTime),.000001);
            
            if obj.hsaiActive
                obj.startHsaiMonitoring();
            end
        end
        
        function set.hsaiSampleRate(obj,v)
            baseRate = obj.hFpga.nominalAcqSampleRate;
            decimLb2 = floor(log2(baseRate/v));
            obj.hsaiSampleRate = baseRate / 2^decimLb2;
            
            obj.hsaiTimeSpan = obj.hsaiTimeSpan;
        end
        
        function set.hsaiFilter(obj,v)
            if isempty(v) || (ischar(v) && ismember(lower(v),{'none' 'bypass' 'fbw'})) || (isnumeric(v) && (isnan(v) || ~v))
                v = nan;
                obj.hsaiFilter = 'None';
            else
                if ischar(v)
                    v = str2double(strtrim(strrep(v,'MHz','')));
                end
                v = round(v);
                assert((numel(v) == 1) && isnumeric(v) && (v < 60) && (v > 0),'Invalid filter setting.');
                obj.hFpga.setChannelsFilter(v);
                obj.hsaiFilter = sprintf('%d MHz', v);
            end
            
            if ~obj.initMode
                obj.hFpga.setChannelsFilter(v);
            end
        end
        
        function set.hsaiAutoScale(obj,v)
            obj.hsaiAutoScale = v;
            
            if ~v
                b = 13 - 2*obj.isH;
                set(obj.hHsaiAx, 'YLim', 1.1 * 2^b * [-1 1]);
            else
                obj.hsaiScaleHistory = {[] [] [] []};
                obj.autoscaleHsai();
            end
        end
        
        function set.lsaiAutoScale(obj,v)
            obj.lsaiAutoScale = v;
            
            if ~v
                set(obj.hLsaiAx, 'YLim', [-10.1 10.1]);
            else
                obj.lsaiScaleHistory = [];
                obj.autoscaleLsai();
            end
        end
        
        function set.hsaiInputRangeSel(obj,v)
            obj.hsaiInputRangeSel = v;
            
            if ~obj.initMode
                obj.hFpga.setChannelsInputRanges(obj.hFpga.hAfe.availableInputRanges(v));
            end
        end
        
        function set.lsaiSampleRate(obj,v)
            restart = obj.lsaiActive;
            obj.stopLsaiMonitoring();
            
            obj.hLsaiTask.sampleRate = v;
            obj.lsaiSampleRate = obj.hLsaiTask.sampleRate;
            
            if restart
                obj.startLsaiMonitoring();
            end
        end
        
        function set.pwmMeasChanSel(obj,v)
            if v > 1
                obj.hFpga.pwmMeasChanReg = v - 2;
            else
                obj.hFpga.pwmMeasChanReg = 63;
            end
            obj.pwmMeasChanSel = v;
        end
        
        function set.pwmMeasDebounce(obj,v)
            obj.hFpga.pwmMeasDebounce = v;
            obj.pwmMeasDebounce = v;
        end
        
        function set.lsaiChanEnable(obj,v)
            restart = obj.lsaiActive;
            obj.stopLsaiMonitoring();
            
            obj.lsaiChanEnable = v;
            obj.updateLsaiLegend();
            
            if restart && any(v)
                obj.startLsaiMonitoring();
            end
        end
        
        function set.hsaiChannel(obj,v)
            obj.hsaiChannel = v;
            obj.hDataScope.channel = v;
        end
    end
end

function str = oeToStr(oe)
    strs = {'IN' 'OUT'};
    str = strs{oe+1};
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
