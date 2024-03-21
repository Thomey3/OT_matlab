function varargout = slmControls(varargin)
% SLMCONTROLS MATLAB code for slmControls.fig
%      SLMCONTROLS, by itself, creates a new SLMCONTROLS or raises the existing
%      singleton*.
%
%      H = SLMCONTROLS returns the handle to a new SLMCONTROLS or the handle to
%      the existing singleton*.
%
%      SLMCONTROLS('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in SLMCONTROLS.M with the given input arguments.
%
%      SLMCONTROLS('Property','Value',...) creates a new SLMCONTROLS or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before slmControls_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to slmControls_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help slmControls

% Last Modified by GUIDE v2.5 24-Nov-2020 15:27:18

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @slmControls_OpeningFcn, ...
                   'gui_OutputFcn',  @slmControls_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before slmControls is made visible.
function slmControls_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to slmControls (see VARARGIN)

% Choose default command line output for slmControls
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes slmControls wait for user response (see UIRESUME)
% uiwait(handles.figure1);

% --- Outputs from this function are returned to the command line.
function varargout = slmControls_OutputFcn(hObject, eventdata, handles) 
varargout{1} = handles.output;

% --- Executes on selection change in pmWavelength_nm.
function pmWavelength_nm_Callback(hObject, eventdata, handles)
handles.hController.changeWavelengthPm();

% --- Executes during object creation, after setting all properties.
function pmWavelength_nm_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function etParkPositionX_Callback(hObject, eventdata, handles)
handles.hController.changeSlmParkPosition();


% --- Executes during object creation, after setting all properties.
function etParkPositionX_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function etParkPositionY_Callback(hObject, eventdata, handles)
handles.hController.changeSlmParkPosition();

% --- Executes during object creation, after setting all properties.
function etParkPositionY_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function etParkPositionZ_Callback(hObject, eventdata, handles)
handles.hController.changeSlmParkPosition();

% --- Executes during object creation, after setting all properties.
function etParkPositionZ_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes on button press in pbShowLut.
function pbShowLut_Callback(hObject, eventdata, handles)
handles.hModel.hSlmScan.plotLut();

% --- Executes on button press in pbCalibrateLut.
function pbCalibrateLut_Callback(hObject, eventdata, handles)
answer = questdlg('Which LUT calibration method?','Method','Global LUT','Pixelwise LUT','Cancel','Cancel');
switch answer
    case 'Global LUT'
        hSlmCalibrationControls = handles.hController.hGuiClasses.SlmCalibrationControls;
        hSlmCalibrationControls.wavelength = handles.hModel.hSlmScan.wavelength * 1e9;
        hSlmCalibrationControls.Visible = true;
        handles.hController.raiseGUI('SlmCalibrationControls');
    case 'Pixelwise LUT'
        hSlmCalibrationControls = handles.hController.hGuiClasses.SlmLutCalibration;
        hSlmCalibrationControls.Visible = true;
        handles.hController.raiseGUI('SlmLutCalibration');
    otherwise
        %No op
end

% --- Executes on button press in pbShowPhaseMaskDisplay.
function pbShowPhaseMaskDisplay_Callback(hObject, eventdata, handles)
handles.hModel.hSlmScan.showPhaseMaskDisplay();

% --- Executes on selection change in pmSlmSelect.
function pmSlmSelect_Callback(hObject, eventdata, handles)
handles.hController.changeSlmControlsScanner();

% --- Executes during object creation, after setting all properties.
function pmSlmSelect_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes on button press in pbPark.
function pbPark_Callback(hObject, eventdata, handles)
handles.hModel.hSlmScan.parkScanner();

function etFocalLength_mm_Callback(hObject, eventdata, handles)
handles.hController.updateModel(hObject,eventdata,handles);

% --- Executes during object creation, after setting all properties.
function etFocalLength_mm_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function etWavelength_nm_Callback(hObject, eventdata, handles)
handles.hController.updateModel(hObject,eventdata,handles);

% --- Executes during object creation, after setting all properties.
function etWavelength_nm_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes on button press in pbLoadLut.
function pbLoadLut_Callback(hObject, eventdata, handles)
handles.hModel.hSlmScan.loadLutFromFile();

% --- Executes on button press in pbShowWavefrontCorrection.
function pbShowWavefrontCorrection_Callback(hObject, eventdata, handles)
handles.hModel.hSlmScan.plotWavefrontCorrection();


% --- Executes on button press in pbLoadWavefrontCorrection.
function pbLoadWavefrontCorrection_Callback(hObject, eventdata, handles)
handles.hModel.hSlmScan.loadWavefrontCorrectionFromFile();


% --- Executes on button press in pbAlign.
function pbAlign_Callback(hObject, eventdata, handles)
handles.hModel.hSlmScan.showAlignmentOverview();
most.gui.tetherGUIs(handles.figure1,handles.hModel.hSlmScan.hAlignmentOverview.hFig,'righttop');


% --- Executes on button press in pbShowZernike.
function pbShowZernike_Callback(hObject, eventdata, handles)
handles.hModel.hSlmScan.showZernikeGenerator();


% --- Executes on button press in pbClearLut.
function pbClearLut_Callback(hObject, eventdata, handles)
handles.hModel.hSlmScan.lut = [];




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
