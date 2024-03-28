classdef OTView < most.Gui
    %OTVIEW ����Ϊ��ͼ�࣬���𹹽�GUI���棬����model��ı仯
    %�̳�most.Gui�࣬���ڶ�GUI��������Ű�

    properties
        GUI = struct;
        hOTmodel;%model������handle
        hOTcontroller
        hImage %image��Ķ��󣬸������������п���һ��������ʾͼ��
        
    end


    methods
        %����modelobj����OTModel�Ķ���
        function obj = OTView(modelobj)
            obj.hOTmodel = modelobj;
            obj.GUIConstruct;
            obj.construct_controller;
            obj.attachToController(obj.hOTcontroller);

            obj.hOTmodel.addlistener('MessageUpdated',@obj.update_logmessage);
        end
    end

    methods
        function GUIConstruct(obj,~,~)
            windowWidth = 1250;
            windowHeight = 950;
            main_position = obj.get_windows_size(windowWidth,windowHeight);
            obj.GUI.main = figure('MenuBar','none','Position',main_position ,'Resize','on',...
                'Name','OT Stimulation','NumberTitle','off');

            hMainFlow = most.gui.uiflowcontainer('Parent', obj.GUI.main,'FlowDirection','RightToLeft');%���ҵ��󴴽�
            
            %% ����panel,�������еĿؼ�
            obj.GUI.hRightPanel = uipanel('Parent',hMainFlow);
            set(obj.GUI.hRightPanel, 'WidthLimits', [300 300]);
            obj.GUI.hRightFlow = most.gui.uiflowcontainer('Parent',obj.GUI.hRightPanel,'FlowDirection','TopDown');
            
            obj.connection_panel(obj.GUI.hRightFlow,70);
            obj.camera_configuration(obj.GUI.hRightFlow,270);
            obj.scanner_configuration(obj.GUI.hRightFlow,400);
            obj.make_log_panel(obj.GUI.hRightFlow);

            %% preview panel���������
            %��panel�ﴴ��һ����������������������ʾ����
            hLeftPanel = uipanel('Parent', hMainFlow);
            obj.GUI.ViewAxes = axes('Parent',hLeftPanel,'Position',[0.05,0.05,0.92,0.92]);
            %Ĭ�Ϸֱ�����2048X2048
            image(zeros(2048,2048),'Parent',obj.GUI.ViewAxes);
        end
        %% ���Ӳ���
        function connection_panel(obj,parent,Height)
            connect_text = uicontrol('Parent',parent,'Style','text','Enable','on','String', ...
                'Connection','FontSize',10,'BackgroundColor',[0.6,0.6,0.6]);%��һ������
            set(connect_text,'HeightLimits',[20,20])
            
            connectionFlow = most.gui.uiflowcontainer('Parent', parent,'FlowDirection','TopDown');
            set(connectionFlow,'HeightLimits',[Height,Height]);
            
            %�������
            camera_connectFlow = most.gui.uiflowcontainer('Parent', connectionFlow,'FlowDirection','RightToLeft');
            obj.GUI.camera_connect = uicontrol('Parent',camera_connectFlow,'Style','checkbox','String','connect', ...
                'FontSize',14,'Enable','off');
            obj.GUI.camera_popmenu = uicontrol('Parent',camera_connectFlow,'Style','popupmenu',...
                'String',{'PCO','Daheng'});
            set(camera_connectFlow,'HeightLimits',[25,25]);
            
            %% scanner����
            scanner_connectFlow = most.gui.uiflowcontainer('Parent', connectionFlow,'FlowDirection','RightToLeft');
            obj.GUI.scanner_connect = uicontrol('Parent',scanner_connectFlow,'Style','checkbox','String','connect', ...
                'FontSize',14);
            scanner_text = uicontrol('Parent',scanner_connectFlow,'Style','text','Enable','on','String', ...
                'DAQ:','FontSize',14);
            set(scanner_connectFlow,'HeightLimits',[25,25]);
        end
       %% camera configuration
        function camera_configuration(obj,parent,Height)
            camera_text = uicontrol('Parent',parent,'Style','text','Enable','on','String', ...
                'Camera configuration','FontSize',10,'BackgroundColor',[0.6,0.6,0.6]);%��һ������
            set(camera_text,'HeightLimits',[20,20])
            
            camLiveFlow = most.gui.uiflowcontainer('Parent', parent,'FlowDirection','TopDown');
            set(camLiveFlow,'HeightLimits',[Height,Height]);
            
            %�ɼ���ť
            obj.GUI.Live = uicontrol('Parent',camLiveFlow,'Style','pushbutton','String',...
                'Live','FontSize',14,'Enable','off'); 
            %��ͼ
            obj.GUI.snapshot = uicontrol('Parent',camLiveFlow,'Style','pushbutton','String',...
                'Snapshot','FontSize',14,'Enable','off'); 
            %¼��
            record = most.gui.uiflowcontainer('Parent', camLiveFlow,'FlowDirection','RightToLeft');
            obj.GUI.record_frame = uicontrol('Parent',record,'Style','edit','Enable','off');
            uicontrol('Parent',record,'Style','text','String','duration:','HorizontalAlignment','Center',...
                'FontSize',10);
            obj.GUI.record = uicontrol('Parent',record,'Style','pushbutton','String',...
                'Record','FontSize',14,'Enable','off'); 
            
            %�ع�ʱ��
            exposure_Flow = most.gui.uiflowcontainer('Parent', camLiveFlow,'FlowDirection','RightToLeft');
            obj.GUI.exposure = uicontrol('Parent',exposure_Flow,'Style','edit','Enable','off');
            uicontrol('Parent',exposure_Flow,'Style','text','String','Exp/s:','HorizontalAlignment','Center',...
                'FontSize',10);
            
            %ROI����
            x_ROI_offset = most.gui.uiflowcontainer('Parent', camLiveFlow,'FlowDirection','RightToLeft');
            obj.GUI.xROI_offset = uicontrol('Parent',x_ROI_offset,'Style','edit','Enable','off');
            uicontrol('Parent',x_ROI_offset,'Style','text','String','x_offset:','HorizontalAlignment','Center',...
                'FontSize',10);
            
            x_ROI_width = most.gui.uiflowcontainer('Parent', camLiveFlow,'FlowDirection','RightToLeft');
            obj.GUI.xROI_width = uicontrol('Parent',x_ROI_width,'Style','edit','Enable','off');
            uicontrol('Parent',x_ROI_width,'Style','text','String','x_width:','HorizontalAlignment','Center',...
                'FontSize',10); 
            
            y_ROI_offset = most.gui.uiflowcontainer('Parent', camLiveFlow,'FlowDirection','RightToLeft');
            obj.GUI.yROI_offset = uicontrol('Parent',y_ROI_offset,'Style','edit','Enable','off');
            uicontrol('Parent',y_ROI_offset,'Style','text','String','y_offset:','HorizontalAlignment','Center',...
                'FontSize',10);
            
            y_ROI_height = most.gui.uiflowcontainer('Parent', camLiveFlow,'FlowDirection','RightToLeft');
            obj.GUI.yROI_height = uicontrol('Parent',y_ROI_height,'Style','edit','Enable','off');
            uicontrol('Parent',y_ROI_height,'Style','text','String','y_hight:','HorizontalAlignment','Center',...
                'FontSize',10); 
            
            %�Աȶ�����
            contrast = most.gui.uiflowcontainer('Parent', camLiveFlow,'FlowDirection','RightToLeft');
            obj.GUI.contrast_max = uicontrol('Parent',contrast,'Style','edit','Enable','off');
            uicontrol('Parent',contrast,'Style','text','String','��','HorizontalAlignment','Center',...
                'FontSize',10); 
            obj.GUI.contrast_min = uicontrol('Parent',contrast,'Style','edit','Enable','off');
            obj.GUI.autocontrast = uicontrol('Parent',contrast,'Style','checkbox','String','Auto', ...
                'FontSize',10,'Value',1);

            % ֡����ʾ
            Framerate = most.gui.uiflowcontainer('Parent', camLiveFlow,'FlowDirection','RightToLeft');
            obj.GUI.FrameRate = uicontrol('Parent',Framerate,'style','text','String','FrameRate', ...
                                    'HorizontalAlignment','Center','FontSize',10);
        end
        %% scanner configuration
        function scanner_configuration(obj,parent,Height)
            scanner_text = uicontrol('Parent',parent,'Style','text','Enable','on','String', ...
                'Scanner configuration','FontSize',10,'BackgroundColor',[0.6,0.6,0.6]);%��һ������
            set(scanner_text,'HeightLimits',[20,20])
            
            ScannerFlow = most.gui.uiflowcontainer('Parent', parent,'FlowDirection','TopDown');
            set(ScannerFlow,'HeightLimits',[Height,Height]);
            
            %calibration��ť
            obj.GUI.calibration = uicontrol('Parent',ScannerFlow,'Style','pushbutton','String',...
                'Calibration','FontSize',14,'Enable','off'); 
            
            % �ٶȵ���
            velocityFlow = most.gui.uiflowcontainer('Parent', ScannerFlow,'FlowDirection','RightToLeft');
            obj.GUI.scanner_velocity = uicontrol('Parent',velocityFlow,'Style','edit','Enable','off');
            uicontrol('Parent',velocityFlow,'Style','text','String','Duration:','HorizontalAlignment','Center',...
                'FontSize',10);
            
            % ·�����ģʽ
            scanpath_mode_Flow = most.gui.uiflowcontainer('Parent', ScannerFlow,'FlowDirection','RightToLeft');
            obj.GUI.scanpath_mode = uicontrol('Parent',scanpath_mode_Flow,'Style','popupmenu','Enable','off', 'String',{'single','multiple'});
            uicontrol('Parent',scanpath_mode_Flow,'Style','text','String','Mode:','HorizontalAlignment','Center',...
                'FontSize',10);
            
            % ɨ��·��
            scanpathFlow = most.gui.uiflowcontainer('Parent', ScannerFlow,'FlowDirection','RightToLeft');
            obj.GUI.scanpath = uicontrol('Parent',scanpathFlow,'Style','popupmenu','Enable','off', 'String',{'line','point','rectangle_in'});
            uicontrol('Parent',scanpathFlow,'Style','text','String','Path:','HorizontalAlignment','Center',...
                'FontSize',10);
            
            % ɨ���������
            intervalFlow = most.gui.uiflowcontainer('Parent', ScannerFlow,'FlowDirection','RightToLeft');
            obj.GUI.interval = uicontrol('Parent',intervalFlow,'Style','edit','Enable','off');
            uicontrol('Parent',intervalFlow,'Style','text','String','Interval:','HorizontalAlignment','Center',...
                'FontSize',10);
            
            % ɨ�跽ʽ
            scanmodeFlow = most.gui.uiflowcontainer('Parent', ScannerFlow,'FlowDirection','RightToLeft');
            obj.GUI.scanmode = uicontrol('Parent',scanmodeFlow,'Style','popupmenu','Enable','off', 'String',{'Continuous','RepeatOutput'});
            uicontrol('Parent',scanmodeFlow,'Style','text','String','ScanMode:','HorizontalAlignment','Center',...
                'FontSize',10);
            
            %add��ť
            obj.GUI.addpath = uicontrol('Parent',ScannerFlow,'Style','pushbutton','String',...
                'addpath','FontSize',14,'Enable','off'); 
            
            %finish��ť
            obj.GUI.finish = uicontrol('Parent',ScannerFlow,'Style','pushbutton','String',...
                'Finish','FontSize',14,'Enable','off'); 
            
            %delete��ť
            obj.GUI.delete = uicontrol('Parent',ScannerFlow,'Style','pushbutton','String',...
                'DeletePath','FontSize',14,'Enable','off'); 
            
            %��λ��ť
            obj.GUI.scan_startpoint = uicontrol('Parent',ScannerFlow,'Style','pushbutton','String',...
                'Start','FontSize',14,'Enable','off'); 
            
            %ɨ�迪ʼ��ť
            obj.GUI.scan = uicontrol('Parent',ScannerFlow,'Style','pushbutton','String',...
                'Scan','FontSize',14,'Enable','off'); 
            
            %���ù�߰�ť
            obj.GUI.reset = uicontrol('Parent',ScannerFlow,'Style','pushbutton','String',...
                'Reset','FontSize',14,'Enable','off'); 
        end
        %% log window
        function make_log_panel(obj,parent)
            hlogPanel = uipanel('Parent',parent);
            hlogFlow = most.gui.uiflowcontainer('Parent', hlogPanel,'FlowDirection','TopDown');
            obj.GUI.log = uicontrol('Parent', hlogFlow, 'Style', 'edit', 'HorizontalAlignment', ...
                'left', 'BackgroundColor', [1, 1, 1], 'FontSize', 10, ...
                'Max', 2, 'Min', 0, 'Enable', 'inactive'); % Max > Minʹ��֧�ֶ����ı���'Enable', 'inactive'ʹ�ı����ɱ༭���ɹ���

        end
    end

    %% Ԫ�ػص�
    methods
        %����controller��Ķ���
        function construct_controller(obj)
            obj.hOTcontroller = OTController(obj,obj.hOTmodel);
        end

        %������ؼ�ע��ص�
        function attachToController(obj,controller)
            set(obj.GUI.main,'DeleteFcn',@controller.callback_DeleteFcn);

            
           %% connection
           
            set(obj.GUI.camera_popmenu,'callback',@controller.callback_camera_select);
            set(obj.GUI.camera_connect,'callback',@controller.callback_camera_connect);
            set(obj.GUI.scanner_connect,'callback',@controller.callback_scanner_connect);
           
            %% camera controller
            set(obj.GUI.Live,'callback',@controller.callback_Live);
            set(obj.GUI.snapshot,'callback',@controller.callback_snapshot);
            set(obj.GUI.record,'callback',@controller.callback_record);
            set(obj.GUI.exposure,'callback',@controller.callback_exposure);
            set(obj.GUI.xROI_offset,'callback',@controller.callback_xROI_offset);
            set(obj.GUI.xROI_width,'callback',@controller.callback_xROI_width);
            set(obj.GUI.yROI_offset,'callback',@controller.callback_yROI_offset);
            set(obj.GUI.yROI_height,'callback',@controller.callback_yROI_height);
            set(obj.GUI.contrast_max,'callback',@controller.callback_contrast_max);
            set(obj.GUI.contrast_min,'callback',@controller.callback_contrast_min);
            set(obj.GUI.autocontrast,'callback',@controller.callback_autocontrast);
           %% scanner controller
            set(obj.GUI.calibration,'callback',@controller.callback_calibration);
            set(obj.GUI.scanner_velocity,'callback',@controller.callback_scanner_velocity);
            set(obj.GUI.scanpath_mode,'callback',@controller.callback_scanpath_mode);
            set(obj.GUI.scanpath,'callback',@controller.callback_scanpath);
            set(obj.GUI.interval,'callback',@controller.callback_interval);
            set(obj.GUI.scanmode,'callback',@controller.callback_scanmode);
            set(obj.GUI.addpath,'callback',@controller.callback_addpath);
            set(obj.GUI.finish,'callback',@controller.callback_finish);
            set(obj.GUI.delete,'callback',@controller.callback_delete);
            set(obj.GUI.scan_startpoint,'callback',@controller.callback_scan_startpoint);
            set(obj.GUI.scan,'callback',@controller.callback_scan);
            set(obj.GUI.reset,'callback',@controller.callback_reset);
        end
    end
    
    %% �¼��ص�
    methods
        % �¼�MessageUpdated�Ļص������ڸ���log��
        function update_logmessage(obj,~,~)
            loglength = length(obj.hOTmodel.logMessage);
            if loglength <= 9
                obj.GUI.log.String = obj.hOTmodel.logMessage;
            else
                obj.GUI.log.String = obj.hOTmodel.logMessage(loglength-8:loglength,1);
            end
        end
    end
    
    %% һЩ���㷽��
    methods
        function position = get_windows_size(~,windowWidth,windowHeight)
            % ��ȡ��Ļ����λ��
            screenSize = get(0, 'ScreenSize');
            screenWidth = screenSize(3);
            screenHeight = screenSize(4);

            % ���㴰�����½ǵ�λ��
            xPos = (screenWidth - windowWidth) / 2;
            yPos = (screenHeight - windowHeight) / 2;

            % ���ش��ڵ�λ��
            position = [xPos, yPos, windowWidth, windowHeight];
        end

    end
end

