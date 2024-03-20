classdef OTController < handle

    properties
        hOTView
        hOTmodel
    end
    
    properties
        living = false
        scanner_connect = false
        autocontrast = true
        width = 2048
        height = 2048
    end

    methods
        function obj = OTController(viewobj,modelobj)
            obj.hOTView = viewobj;
            obj.hOTmodel = modelobj;
        end
    end

    methods
        function callback_DeleteFcn(obj,~,~)
            if ~isempty(obj.hOTmodel.cam) || ~isempty(obj.hOTmodel.DAQ)
                obj.hOTmodel.disconnect_cam;
                obj.hOTmodel.disconnect_daq;
            end
        end

        %% connection
        function callback_camera_select(obj,~,~)
           name = obj.hOTView.GUI.camera_popmenu.String(obj.hOTView.GUI.camera_popmenu.Value);
           obj.hOTmodel.select_camera(name);
           set(obj.hOTView.GUI.camera_connect,'Enable','on');
        end
        
        function callback_camera_connect(obj,~,~)
            if obj.hOTView.GUI.camera_connect.Value == 1
                camera = obj.hOTmodel.connect_to_cam;
                if camera == true
                    obj.enable_camera('on');
                else
                    obj.hOTView.GUI.camera_connect.Value = 0;
                end
            else
                obj.hOTmodel.disconnect_cam;
                obj.enable_camera('off');
            end
        end
        
        function callback_scanner_connect(obj,~,~)
            if obj.hOTView.GUI.scanner_connect.Value == 1
                DAQ = obj.hOTmodel.connect_daq;
                if DAQ ==true
                    obj.scanner_connect = true;
                    if obj.living == true
                        set(obj.hOTView.GUI.calibration,'Enable','on');
                    end
                else
                    obj.hOTView.GUI.scanner_connect.Value = 0;
                end
            else
                obj.hOTmodel.disconnect_daq;
                obj.enable_scanner('off');
                obj.scanner_connect = false;
            end
        end
        % 使能camera config区域
        function enable_camera(obj,on_or_off)
            set(obj.hOTView.GUI.Live,'Enable',on_or_off);
            set(obj.hOTView.GUI.snapshot,'Enable',on_or_off);
            set(obj.hOTView.GUI.record,'Enable',on_or_off);
            set(obj.hOTView.GUI.record_frame,'Enable',on_or_off);
            set(obj.hOTView.GUI.exposure,'Enable',on_or_off);
            set(obj.hOTView.GUI.xROI_offset,'Enable',on_or_off);
            set(obj.hOTView.GUI.xROI_width,'Enable',on_or_off);
            set(obj.hOTView.GUI.yROI_offset,'Enable',on_or_off);
            set(obj.hOTView.GUI.yROI_height,'Enable',on_or_off);
            set(obj.hOTView.GUI.autocontrast,'Enable',on_or_off);
            
        end
        
        % 使能scanner config区域
        function enable_scanner(obj,on_or_off)
            %set(obj.hOTView.GUI.calibration,'Enable',on_or_off);
            set(obj.hOTView.GUI.scanner_velocity,'Enable',on_or_off);
            set(obj.hOTView.GUI.scanpath_mode,'Enable',on_or_off);
            set(obj.hOTView.GUI.scanpath,'Enable',on_or_off);
            set(obj.hOTView.GUI.interval,'Enable',on_or_off);
            set(obj.hOTView.GUI.scanmode,'Enable',on_or_off);
            set(obj.hOTView.GUI.addpath,'Enable',on_or_off);
            set(obj.hOTView.GUI.finish,'Enable',on_or_off);
            set(obj.hOTView.GUI.delete,'Enable',on_or_off);
            set(obj.hOTView.GUI.scan_startpoint,'Enable',on_or_off);
            set(obj.hOTView.GUI.scan,'Enable',on_or_off);
            set(obj.hOTView.GUI.reset,'Enable',on_or_off);
        end
        
        %% camera
        function callback_Live(obj,~,~)
            if obj.living == false
                preview = obj.hOTmodel.campreview;
                if preview == true
                    obj.living = true;
                    set(obj.hOTView.GUI.Live,'String','Stop Live');
                    if obj.scanner_connect == true
                        set(obj.hOTView.GUI.calibration,'Enable','on');
                    end
                end          
            else
                stop_preview = obj.hOTmodel.stop_preview;
                if stop_preview == true
                    obj.living = false;
                    set(obj.hOTView.GUI.Live,'String','Live');
                end
            end
        end
        
        function callback_snapshot(obj,~,~)
            obj.hOTmodel.snapshot;
        end
        
        function callback_record(obj,~,~)
            obj.hOTmodel.record(obj.hOTView.GUI.record_frame.String);
        end
        
        function callback_exposure(obj,~,~)
            obj.hOTmodel.change_exposure(obj.hOTView.GUI.exposure.String);
        end
         
        function callback_xROI_offset(obj,~,~)
            obj.hOTmodel.change_x_offset(obj.hOTView.GUI.xROI_offset.String);
        end
        function callback_xROI_width(obj,~,~)
            obj.width = str2double(obj.hOTView.GUI.xROI_width.String);
            obj.hOTmodel.change_x_width(obj.width);
            image(zeros(obj.width,obj.height),'Parent',obj.hOTView.GUI.ViewAxes);
        end
        function callback_yROI_offset(obj,~,~)
            obj.hOTmodel.change_y_offset(obj.hOTView.GUI.yROI_offset.String);
        end
        function callback_yROI_height(obj,~,~)
            obj.height = str2double(obj.hOTView.GUI.yROI_height.String);
            obj.hOTmodel.change_y_height(obj.height);
            image(zeros(obj.width,obj.height),'Parent',obj.hOTView.GUI.ViewAxes);
        end
        
%%% 还没写完
        function callback_autocontrast(obj,~,~)
            if obj.autocontrast == true
                obj.autocontrast = false;
                set(obj.hOTView.GUI.contrast_max,'Enable','on');
                set(obj.hOTView.GUI.contrast_min,'Enable','on');
            else
                obj.autocontrast = true;
                set(obj.hOTView.GUI.contrast_max,'Enable','off');
                set(obj.hOTView.GUI.contrast_min,'Enable','off');
            end
                
        end
    end

%         function callback_contrast_max(obj,~,~)
%             
%         end

%         function callback_contrast_min(obj,~,~)
%             
%         end
        
        %% scanner controller
   methods
        function callback_calibration(obj,~,~)
            calibrate = obj.hOTmodel.calibration;
            if calibrate == true
                obj.enable_scanner('on');
            end
        end

        function callback_scanner_velocity(obj,~,~)
            v = str2double(obj.hOTView.GUI.scanner_velocity.String);
            obj.hOTmodel.getvelocity(v);
        end
        
        function callback_scanpath_mode(obj,~,~)
            obj.hOTmodel.getMode(obj.hOTView.GUI.scanner_velocity.String(obj.hOTView.GUI.scanner_velocity.Value));
        end
%         
%         function callback_scanpath(obj,~,~)
%             
%         end
%         
%         function callback_interval(obj,~,~)
%             
%         end
%         
%         function callback_scanmode(obj,~,~)
%             
%         end
%         
%         function callback_addpath(obj,~,~)
%             
%         end
%         
%         function callback_finish(obj,~,~)
%             
%         end
%         
%         function callback_delete(obj,~,~)
%             
%         end
%         
%         function callback_scan_startpoint(obj,~,~)
%             
%         end
%         
%         function callback_scan(obj,~,~)
%             
%         end

%         function callback_reset(obj,~,~)
%             
%         end
   end
end