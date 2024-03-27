function mypreview_fcn(obj,event,himage)
% Example update preview window function.

% Get timestamp for frame.
FrameRatestr = event.FrameRate;

% Get handle to text label uicontrol.
ht = getappdata(himage,'HandleToFrameRateLabel');

% Set the value of the text label.
ht.String = FrameRatestr;

% 假设event.CData是你的720x1280x3图像数据
imageData = event.Data;
% max(max(imageData))
% 使用imadjust函数调整对比度
% 这里的[0.2 0.8]是输入强度范围（可以根据需要调整这些值）
% [0 1]是输出强度范围
adjustedImageData = imadjust(imageData);
% adjustedImageData = uint8(255*imadjust(double(imageData)/255));

% 显示调整对比度后的图像
%imshow(adjustedImageData);


% Display image data.
himage.CData = imageData;
end