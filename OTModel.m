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
        velocity
        % 电压-坐标
        w 
        center
        curve1
        curve2
        
        
        % information
        logMessage = cell(0,0)
    end
    
    events
       MessageUpdated 
    end
    
    %% connection
    methods
        % 连接相机
        function select_camera(obj,name)
            obj.cam.camName = name{1,1};
            obj.addlog([' Camera : ',obj.cam.camName]);
        end

        function bool = connect_to_cam(obj)
            if(~isfield(obj.cam,'camName'))
                obj.addlog('Camera not selected');
                bool = false;
            else
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
        end
        % 断开相机
        function disconnect_cam(obj)
            try
                delete(obj.cam.camera)
                obj.addlog(' Camera disconnected');
            catch
                obj.addlog(' Camera disconnected failed');
            end
        end
        
        % 连接DAQ
        function bool = connect_daq(obj)
            try
                obj.DAQ = daq('ni');
                addoutput(obj.DAQ,"dev1","ao0","voltage");
                addoutput(obj.DAQ,"dev1","ao1","voltage");
                bool = true;
                obj.addlog(' DAQ connected');
                obj.addlog(' Calibration requires camera living');
                obj.addlog(' You should calibrate before using scanner');
            catch
                bool = false;
                obj.addlog(' DAQ connect failed');
            end
        end
        
        % 断开DAQ
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
        % 预览
        function bool = campreview(obj)
            try
                vidRes = get(obj.cam.camera, 'VideoResolution'); % 获取相机分辨率
                nBands = get(obj.cam.camera, 'NumberOfBands');   % 获取相机的通道数（RGB）
                hImage = image(zeros(vidRes(2), vidRes(1), nBands)); % hImage用来存储画面
                warning('off','imaq:preview:typeBiggerThanUINT8'); 
                preview(obj.cam.camera,hImage);
                bool = true;
                obj.addlog(' preview started');
            catch
                bool = false;
                obj.addlog(' preview failed');
            end
        end
        % 停止预览
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
            startPath = './'; % 定义起始路径
            basePath  = uigetdir(startPath, '请选择保存文件的路径');
            % 检查是否点击了取消按钮
            if basePath  == 0
                disp('cancel');
            else
                disp(['select: ', basePath ]);
                % 在这里执行后续操作，例如读取或保存文件
                baseFileName = 'Frame_';
                for i = 1:numFrames
                    % 创建文件名
                    fileName = [basePath, baseFileName, num2str(i), '.tif'];
                    % 提取第i帧
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
        % 改宽度
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
        % 改高度
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
    
    %% scanner config
    methods
        % 获取calibration需要的光斑位置照片
        function s = CaliImgAcqui(obj)
            dq = obj.DAQ;
            ca = obj.cam.camera;

            if(strcmp(obj.cam.camName,'Daheng'))
                xframenumber = 6;
                yframenumber = 6;
                xpixel = 1280;
                ypixel = 1024;
            elseif(strcmp(obj.cam.camName,'PCO'))
                xframenumber = 20;
                yframenumber = 20;
                xpixel = obj.ROIheight;
                ypixel = obj.ROIwidth;
            end
            %% Image Acquisition
            ximgstack = uint8(ones(ypixel,xpixel,3,xframenumber));
            yimgstack = uint8(ones(ypixel,xpixel,3,yframenumber));

            if(strcmp(obj.cam.camName,'Daheng'))
                for i=1:xframenumber+1 %calibrate toward x direction
                    write(dq,[0.1*(i-1),0]);
                    pause(0.5)
                    a = getsnapshot(ca);
                    ximgstack(:,:,:,i) = a;
                    fprintf('x axis = %d\n',i)
                end
            elseif(strcmp(obj.cam.camName,'PCO'))
                for i=1:xframenumber+1 %calibrate toward x direction
                    write(dq,[0.1*(i-xframenumber/2)*xpixel/2048,0]);  %改了一下比例
                    pause(0.5)
                    a = floor(getsnapshot(ca)/256);
                    ximgstack(:,:,1,i) = a;
                    ximgstack(:,:,2,i) = a;
                    ximgstack(:,:,3,i) = a;
                    fprintf('x axis = %d\n',i)
                end
            end
            write(dq,[0,0]);
            clc

            if(strcmp(obj.cam.camName,'Daheng'))
                for j=1:yframenumber+1 %calibrate toward x direction
                    write(dq,[0,0.1*(j-1)]);
                    pause(0.5)
                    a = getsnapshot(ca);
                    yimgstack(:,:,:,j) = a;
                    fprintf('y axis = %d\n',j)
                end
            elseif(strcmp(obj.cam.camName,'PCO'))
                for j=1:yframenumber+1 %calibrate toward x direction
                    write(dq,[0,0.1*(j-yframenumber/2)*ypixel/2048]);
                    pause(0.5)
                    a = floor(getsnapshot(ca)/256);
                    yimgstack(:,:,1,j) = a;
                    yimgstack(:,:,2,j) = a;
                    yimgstack(:,:,3,j) = a;
                    fprintf('y axis = %d\n',j)
                end
            end
            write(dq,[0,0]);
            clc
            fprintf('Acquisition has down')

            s.ximgstack = ximgstack;
            s.yimgstack = yimgstack;
        end
        % 仿射变换
        function [w,center,curve1,curve2] = slope(ximgstack,yimgstack,axes)
            PointNumberx = size(ximgstack,4);
            PointNumbery = size(yimgstack,4);
            a = zeros(PointNumberx,2);
            b = zeros(PointNumbery,2);
            for i=1:PointNumberx
                x = ximgextraction(ximgstack,i);
                a(i,:) = caliimgprocess(x);
            end

            for j=1:PointNumbery
                y = yimgextraction(yimgstack,j);
                b(j,:) = caliimgprocess(y);
            end

            tx = polyfit(a(:,1),a(:,2),1);
            ty = polyfit(b(:,1),b(:,2),1);

            if((a(1,1)<a(PointNumberx,1)) && (a(1,2)>a(PointNumberx,2)))
                w1 = - atan(tx(1));
                w2 = pi/2 - atan(ty(1));
            elseif((a(1,1)>a(PointNumberx,1)) && (a(1,2)>a(PointNumberx,2)))
                w1 = pi - atan(tx(1));
                w2 = pi/2 - atan(ty(1));
            elseif((a(1,1)>a(PointNumberx,1)) && (a(1,2)<a(PointNumberx,2)))
                w1 = pi - atan(tx(1));
                w2 = 3/2*pi - atan(ty(1));
            elseif((a(1,1)<a(PointNumberx,1)) && (a(1,2)<a(PointNumberx,2)))
                w1 = -atan(tx(1));
                w2 = 3/2*pi - atan(ty(1));
            end

            w = -(w1+w2)/2;

            center = (a(floor(PointNumberx-1/2),:)+b(floor(PointNumbery/2),:))/2;
            [ax,ay] = corrdinate_transformation(a(:,2),a(:,1),w,center);
            [bx,by] = corrdinate_transformation(b(:,2),b(:,1),w,center);

            a1 = [ax,ay];
            b1 = [bx,by];

            pp1 = a(PointNumberx-1,:) + (b(PointNumbery-1,:) - b(1,:))/2;
            pp2 = a(1,:) + (b(PointNumbery-1,:) - b(1,:))/2;
            pp3 = a(1,:) - (b(PointNumbery-1,:) - b(1,:))/2;
            pp4 = a(PointNumberx-1,:) - (b(PointNumbery-1,:) - b(1,:))/2;

            my_vertices = [pp1;pp2;pp3;pp4];
            h = drawpolygon(axes,'Color','g','InteractionsAllowed','none','Position',my_vertices);

            vx = 0.1*(1-floor((PointNumberx-1)/2):1+floor((PointNumberx-1)/2))';
            vy = 0.1*(1-floor((PointNumbery-1)/2):1+floor((PointNumbery-1)/2))';

            [curve1, ~, ~] = fit(a1(:,1),vx,'smoothingspline');  %f1 = vx(V) = p1 * xpixel + p2
            [curve2, ~, ~] = fit(b1(:,2),vy,'smoothingspline');  %f2 = vy(V) = f2.p1 * ypixel + f2.p2
            
            save('data.mat','w','center','curve1','curve2')
        end
        % calibration
        function bool = calibration(obj)
            obj.addlog('calibrate start');
            try
                s = obj.CaliImgAcqui(obj);
                [obj.w,obj.center,obj.curve1,obj.curve2] = slope(s.ximgstack,s.yimgstack,axes);
                bool = true;
                obj.addlog('calibrate success');
            catch
                bool = false;
                obj.addlog('calibrate failed');
            end
        end
        % velocity (这里可以尝试一下让他在扫的时候可以直接调整)
        function getvelocity(obj,v)
            obj.velocity = v;
        end
        % 
    end
    
    %% 功能类函数
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

    end
end