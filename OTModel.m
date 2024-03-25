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
        velocity = 30 % 默认值
        mode = "single"
        scanpath = "line"
        interval = 0.5 % 默认值
        scanmode = "contiunous"
        lh
        % ROI
        Path
        hOTROI
        hOTSP
        lenth
        OTPath_inf
        multiple_position_x = []
        multiple_position_y = []
        % 电压-坐标
        w 
        center
        curve1
        curve2
        voltage_data
        
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
                addAnalogInputChannel(obj.DAQ, 'Dev1', 'ai0', 'Voltage');
                obj.DAQ.Rate = 1000;
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
                obj.reset;
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
%         function bool = campreview(obj)
%             try
%                 vidRes = get(obj.cam.camera, 'VideoResolution'); % 获取相机分辨率
%                 nBands = get(obj.cam.camera, 'NumberOfBands');   % 获取相机的通道数（RGB）
%                 hImage = image(zeros(vidRes(2), vidRes(1), nBands)); % hImage用来存储画面
%                 warning('off','imaq:preview:typeBiggerThanUINT8'); 
%                 设置preview的自定义更新函数
%                 setappdata(hImage,'UpdatePreviewWindowFcn',@obj.mypreview_fcn);
%                 
%                 preview(obj.cam.camera,hImage);
%                 bool = true;
%                 obj.addlog(' preview started');
%             catch
%                 bool = false;
%                 obj.addlog(' preview failed');
%             end
%         end
%         停止预览
%         function bool = stop_preview(obj)
%             try
%                 stoppreview(obj.cam.camera);
%                 bool = true;
%                 obj.addlog(' preview stopped');
%             catch
%                 bool = false;
%                 obj.addlog(' preview stopped failed');
%             end
%         end
        function bool = campreview(obj,ViewAxes)
            try
                % 创建监听器对象并保留引用
                obj.lh = addlistener(obj.DAQ, 'DataAvailable', @(~,~)analogTriggeredAction(ViewAxes));
                start(obj.DAQ,obj.scanmode);
                bool = true;
            catch
                bool = false;
            end
        
            % 在需要停止预览时，记得使用 stop(t); 和 delete(t); 来停止并删除定时器
        end
        
        function analogTriggeredAction(obj,ViewAxes)
            % 从相机捕获图像
            frame = getsnapshot(obj.cam.camera); % 确保 cam 已正确配置
        
            % 如果需要，可以在这里添加图像处理代码，例如调整对比度
            frame_adjust = imadjust(frame);
            % 显示图像
            imshow(frame_adjust, 'Parent', ViewAxes);
        end

        function bool = stop_preview(obj)
            try
                stop(obj.DAQ);
                delete(obj.lh);
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
        % mode,scanpath,interval,scanmode
        function getMode(obj,mode)
           obj.mode = mode{1,1}; 
        end
        function getScanpath(obj,path)
           obj.scanpath = path{1,1}; 
        end
        function getInterval(obj,interval)
           obj.interval = interval; 
        end
        function getScanmode(obj,scanmode)
           obj.scanmode = scanmode{1,1}; 
        end
        function addpath(obj,axes)
            Mode = obj.mode; 
            scanpath = obj.scanpath; 
            Interval = obj.interval; 
            
            switch scanpath
                case 'point'
                    obj.Path = [obj.Path, drawpoint(axes,'Color','r','InteractionsAllowed','none')];
                    position = obj.Path(end).Position; 
                case 'line'
                    obj.Path = [obj.Path, drawline(axes,'Color','r','InteractionsAllowed','none')];
                    linepoint = obj.Path(end).Position;
                    xp = linepoint(:,1);
                    yp = linepoint(:,2);
                    if xp(1)>xp(2)
                        Interval = -Interval;
                    end
                    x_interval = xp(1):Interval:xp(2);
                    y_interval = interp1(xp,yp,x_interval);
                    position = [x_interval',y_interval'];
                case 'rectangle_in'
                    obj.Path = [obj.Path, drawrectangle(axes,'Color','r','InteractionsAllowed','none')];
                    point1 = obj.Path(end).Vertices(1,:);
                    point2 = obj.Path(end).Vertices(2,:);
                    point3 = obj.Path(end).Vertices(3,:);
                    point4 = obj.Path(end).Vertices(4,:);
                    density = Interval;
                    ll = abs(point4(1) - point1(1)); % xlength of rectangle
                    ww = abs(point2(2) - point1(2)); % ylength of rectangle
                    lll = floor(ll/density); % x point number
                    www = floor(ww/density);% y point number
                    % 初始化点集数组
                    sPoints = zeros(floor(lll*www), 2);
                    % 计算x和y方向上的步进间隔
                    xStep = density;
                    yStep = density;
                    % 生成S型扫描点集
                    for i = 0:www-1
                        for j = 0:lll-1
                            if mod(i, 2) == 0
                                % 偶数行：从左到右
                                x = point1(1) + j*xStep;
                            else
                                % 奇数行：从右到左
                                x = point1(1) + (lll-1-j)*xStep;
                            end
                            y = point1(2) + i*yStep;
                            sPoints(i*lll+j+1, :) = [x, y];
                        end
                    end
                    position = [sPoints(:,1),sPoints(:,2)];
            end
            [x,y] = corrdinate_transformation(position(2),position(1),obj.w,obj.center);
            pathpoint = [x,y];
            switch Mode
                case 'Single'
                    obj.hOTROI = [obj.hOTROI;pathpoint];
                    obj.hOTSP = [obj.hOTSP;pathpoint(1,:)];
                    obj.lenth = size(pathpoint,1);
                    obj.OTPath_inf.lenth = [obj.OTPath_inf.lenth,obj.lenth];
                    method_num = 1;
                case 'Multiple'
                    l = size(pathpoint,1) - size(obj.multiple_position_x,1);
                    if l > 0 && ~isempty(obj.multiple_position_x)        
                        obj.multiple_position_x = padarray(obj.multiple_position_x,[l,0],'replicate','post');
                        obj.multiple_position_y = padarray(obj.multiple_position_y,[l,0],'replicate','post');
                    elseif l < 0
                        p1 = [pathpoint(:,1)',pathpoint(end,1) * ones([1,-l])];
                        p2 = [pathpoint(:,2)',pathpoint(end,2) * ones([1,-l])];
                        pathpoint = [p1;p2]';
                    end
                    obj.multiple_position_x = [obj.multiple_position_x,pathpoint(:,1)];
                    obj.multiple_position_y = [obj.multiple_position_y,pathpoint(:,2)];
                    method_num = 2;
                case 'Return'
                    position_fz = flipud(pathpoint);
                    position_new = vertcat(pathpoint,position_fz);
                    obj.hOTROI = [obj.hOTROI;position_new];
                    obj.hOTSP = [obj.hOTSP;position_new(1,:)];
                    obj.lenth = size(position_new,1);
                    obj.OTPath_inf.lenth = [obj.OTPath_inf.lenth,obj.lenth];
                    method_num = 4;
            end
                obj.OTPath_inf.number = size(obj.Path,2);
                obj.OTPath_inf.method = [obj.OTPath_inf.method,method_num];
        end
        % finish 
        function Finish(obj)
            if ~isempty(obj.multiple_position_x)
                num1 = size(obj.multiple_position_x,1);
                num2 = size(obj.multiple_position_x,2);
                C = zeros(1,num1 * num2);
                D = zeros(1,num1 * num2);
                for i = 1:1:num2
                   C(i:num2:end) =  obj.multiple_position_x(:,i);
                   D(i:num2:end) =  obj.multiple_position_y(:,i);
                   point = [obj.multiple_position_x(1,i),obj.multiple_position_y(1,i)];
                   obj.hOTSP = [obj.hOTSP;point];
                end
                multiple_position = [C;D];
                obj.hOTROI = [obj.hOTROI;multiple_position'];
                obj.multiple_position_x = [];
                obj.multiple_position_y = [];
                obj.lenth = num1 * num2;
                obj.OTPath_inf.lenth = [obj.OTPath_inf.lenth,obj.lenth];
                obj.OTPath_inf.method = [obj.OTPath_inf.method,3];
            else
                obj.addlog('multiple_position is empty');
            end
        end
        % Delete
        function Delete(obj)
           obj.hOTROI = [];
           obj.hOTSP = [];
           delete(obj.Path);
           obj.Path = [];
           obj.OTPath_inf = struct('number',[],'lenth',[],'method',[]);
           obj.multiple_position_x = [];
           obj.multiple_position_y = [];
           obj.addlog('Deleting Path ...');
        end
        % scanthestartpoint(还没写多个点的)
        function scan_startpoint(obj)
            try
                startpoint = obj.hOTROI(1,:);
                matrix = [obj.curve1(startpoint(:,1)),obj.curve2(startpoint(:,2))];
                obj.voltage_data = repmat(matrix, 1000, 1);
                obj.addlog('voltage_data ready');
                obj.scan();
            catch
                if isempty(obj.hOTROI)
                    obj.addlog('path is empty');
                else
                    obj.addlog('scan_startpoint failed');
                end
            end
        end
        % 扫描整个路径
        function scan_path(obj)
            try
                obj.voltage_data = [obj.curve1(obj.hOTROI(:,1)),obj.curve2(obj.hOTROI(:,2))];
                obj.addlog('voltage_data ready');
                obj.DAQ.Rate = obj.velocity;
                time = line/obj.velocity;
                obj.addlog(['time : ',num2str(time)]);
                obj.scan();
            catch
                if isempty(obj.hOTROI)
                    obj.addlog('path is empty');
                else
                    obj.addlog('scan_startpoint failed');
                end
            end
        end
        % 回到(0,0)位置
        function reset(obj)
            obj.hOTROI = [0,0];
            obj.scan_startpoint;
        end
        % 启动scanner
        function scan(obj)
            scanpath = obj.voltage_data;
            Scanmode = obj.scanmode;
            stop(obj.DAQ);
            try
                start(obj.DAQ,Scanmode)
            catch
                obj.addlog(' optical tweezers did not start');
            end

            try
                write(obj.DAQ,scanpath);
                obj.addlog(' optical tweezers is running');
            catch
                obj.addlog(' Write failed ');
            end
        end
    end
    
    %% 功能类函数
    methods
        function t = get_time(~)
            time = clock; % 原来是clock
            t = [num2str(time(4)),'-',num2str(time(5)),'-',num2str(round(time(6))),'-'];
        end
        
        function addlog(obj,str)
            if ischar(str)
                time = obj.get_time;
                obj.logMessage{length(obj.logMessage)+1,1} = [time,str];
                notify(obj,'MessageUpdated');
            end
        end

        % 自定义的预览更新函数
        function mypreview_fcn(~,event,hImage)
            % 获取当前帧
            frame = event.Data;
            
            % 如果需要，可以在这里转换frame的类型，例如，如果是uint16，可以转换为uint8
            % frame = im2uint8(frame);
        
            % 对每个颜色通道应用对比度调整
            for i = 1:size(frame,3)
                frame(:,:,i) = imadjust(frame(:,:,i));
            end
            
            % 使用调整后的帧更新显示
            set(hImage, 'CData', frame);
        end
    end
end