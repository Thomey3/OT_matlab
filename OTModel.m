classdef OTModel < handle
    properties
        % camera
        cam
        
        X_offset = 0
        Y_offset = 0
        ROIwidth = 2048
        ROIheight = 2048
        % DAQ
        DAQ
        
        % information
        logMessage = cell(0,0)
    end
    
    events
       MessageUpdated 
    end
    
    %% connection
    methods
        % �������
        function select_camera(obj,name)
            obj.cam.camName = name;
        end

        function bool = connect_to_cam(obj)
            try
                if(strcmp(obj.cam.camName,'Daheng'))
                    obj.cam.camera = videoinput('winvideo', 1, 'RGB24_1280x1024');
                elseif(strcmp(obj.cam.camName,'PCO'))
                    obj.cam.camera = videoinput("pcocameraadaptor_r2022b", 0, "USB 3.1 Gen 1");
                end
                obj.cam.camerasrc = getselectedsource(obj.cam.camera);
                bool = true;
                obj.addlog(' Camera connected');
            catch
                bool = false;
                obj.addlog(' Camera connection failed');
            end
        end
        % �Ͽ����
        function disconnect_cam(obj)
            try
                delete(obj.cam.camera)
                obj.addlog(' Camera disconnected');
            catch
                obj.addlog(' Camera disconnected failed');
            end
        end
        
        % ����DAQ
        function bool = connect_daq(obj)
            try
                obj.DAQ = daq('ni');
                addoutput(obj.DAQ,"dev1","ao0","voltage");
                addoutput(obj.DAQ,"dev1","ao1","voltage");
                bool = true;
                obj.addlog(' DAQ connected');
            catch
                bool = false;
                obj.addlog(' DAQ connect failed');
            end
        end
        
        % �Ͽ�DAQ
        function disconnect_daq(obj)
            try
                delete(obj.DAQ);
                obj.addlog(' DAQ disconnected');
            catch
                obj.addlog(' DAQ disconnected failed');
            end
        end
    end
    
    %% camera config
    methods
        % Ԥ��
        function bool = campreview(obj)
            try
                vidRes = get(obj.cam.camera, 'VideoResolution'); % ��ȡ����ֱ���
                nBands = get(obj.cam.camera, 'NumberOfBands');   % ��ȡ�����ͨ������RGB��
                hImage = image(zeros(vidRes(2), vidRes(1), nBands)); % hImage�����洢����
                warning('off','imaq:preview:typeBiggerThanUINT8'); 
                preview(obj.cam.camera,hImage);
                bool = true;
                obj.addlog(' preview started');
            catch
                bool = false;
                obj.addlog(' preview failed');
            end
        end
        % ֹͣԤ��
        function bool = stop_preview(obj)
            try
                stoppreview(obj.cam.camera);
                bool = true;
                obj.addlog(' preview stopped');
            catch
                bool = false;
                obj.addlog(' preview stopped failed');
            end
        end
        % snapshot
        function snapshot(obj)
            try
                snapshot1 = getsnapshot(obj.cam.camera);
                imwrite(snapshot1, './save/snapshot1.tif');
                obj.addlog(' snapshot success');
            catch
                obj.addlog(' snapshot failed');
            end
        end
        % record
        function record(obj,frame)
            numFrames = str2double(frame);
            obj.cam.camera.FramesPerTrigger = numFrames;
            start(obj.cam.camera);
            wait(obj.cam.camera);
            stop(obj.cam.camera);
            recording1 = getdata(obj.cam.camera, numFrames);
            startPath = './'; % ������ʼ·��
            basePath  = uigetdir(startPath, '��ѡ�񱣴��ļ���·��');
            % ����Ƿ�����ȡ����ť
            if basePath  == 0
                disp('cancel');
            else
                disp(['select: ', basePath ]);
                % ������ִ�к��������������ȡ�򱣴��ļ�
                baseFileName = 'Frame_';
                for i = 1:numFrames
                    % �����ļ���
                    fileName = [basePath, baseFileName, num2str(i), '.tif'];
                    % ��ȡ��i֡
                    frame = recording1(:,:,:,i);
                    imwrite(frame, fileName, 'tif');
                end
            end
        end
        % exposure
        function change_exposure(obj,exposure)
           time =  str2double(exposure);
           obj.cam.camerasrc.ExposureTime_s = time;
           obj.addlog(['exposure changed to ',exposure,'s']);
        end
        % �Ŀ��
        function change_x_offset(obj,x_offset)
            obj.X_offset =  str2double(x_offset);
            obj.cam.camerasrc.H1HardwareROI_X_Offset = obj.X_offset;
            obj.cam.camera.ROIPosition = [obj.X_offset obj.Y_offset obj.ROIwidth obj.ROIheight];
            
        end
        function change_x_width(obj,x_width)
            obj.ROIwidth = x_width;
            obj.cam.camerasrc.H2HardwareROI_Width = obj.ROIwidth;
            obj.cam.camera.ROIPosition = [obj.X_offset obj.Y_offset obj.ROIwidth obj.ROIheight];
        end
        % �ĸ߶�
        function change_y_offset(obj,y_offset)
            obj.Y_offset =  str2double(y_offset);
            obj.cam.camerasrc.H4HardwareROI_Y_Offset = obj.Y_offset;
            obj.cam.camera.ROIPosition = [obj.X_offset obj.Y_offset obj.ROIwidth obj.ROIheight];
        end
        function change_y_height(obj,y_height)
            obj.ROIheight = y_height;
            obj.cam.camerasrc.H5HardwareROI_Height = obj.ROIheight;
            obj.cam.camera.ROIPosition = [obj.X_offset obj.Y_offset obj.ROIwidth obj.ROIheight];
        end
    end
    %% �����ຯ��
    methods
        function t = get_time(~)
            time = clock;
            t = [num2str(time(4)),'-',num2str(time(5)),'-',num2str(round(time(6))),'-'];
        end
        
        function addlog(obj,str)
            if ischar(str)
                time = obj.get_time;
                obj.logMessage{length(obj.logMessage)+1,1} = [time,str];
                notify(obj,'MessageUpdated');
            end
        end
        
        function customPreviewUpdateFcn(~, event, himage)
            % ���¼������л�ȡ��ǰ֡
            frameData = event.Data;

            % ����ͼ��Աȶȣ��������Ϊʾ��
            % �����ʵ����Ҫ�����㷨
            adjustedData = imadjust(frameData,stretchlim(frameData),[]);

            % ����Ԥ�����ڵ�ͼ������
            set(himage, 'CData', adjustedData);
        end

    end
end