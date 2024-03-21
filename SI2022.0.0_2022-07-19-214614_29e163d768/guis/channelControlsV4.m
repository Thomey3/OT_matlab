function varargout = channelControlsV4(varargin)
% CHANNELCONTROLSV4 MATLAB code for channelControlsV4.fig
%      CHANNELCONTROLSV4, by itself, creates a new CHANNELCONTROLSV4 or raises the existing
%      singleton*.
%
%      H = CHANNELCONTROLSV4 returns the handle to a new CHANNELCONTROLSV4 or the handle to
%      the existing singleton*.
%
%      CHANNELCONTROLSV4('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in CHANNELCONTROLSV4.M with the given input arguments.
%
%      CHANNELCONTROLSV4('Property','Value',...) creates a new CHANNELCONTROLSV4 or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before channelControlsV4_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to channelControlsV4_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help channelControlsV4

% Last Modified by GUIDE v2.5 01-Sep-2020 12:33:24

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @channelControlsV4_OpeningFcn, ...
                   'gui_OutputFcn',  @channelControlsV4_OutputFcn, ...
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


% --- Executes just before channelControlsV4 is made visible.
function channelControlsV4_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to channelControlsV4 (see VARARGIN)

% Choose default command line output for channelControlsV4
handles.output = hObject;

%Adding PropControls
handles.pcChannelConfig = scanimage.guis.ChannelTable(hObject);

% initialize pmImageColorMap and colormaps in table
prettyColorMapSpecs = scanimage.guis.ChannelImageHandler.prettyColorMapSpecs;
set(handles.pmImageColormap,'String',[prettyColorMapSpecs(:);{'Custom'}]);
set(handles.pmImageColormap,'Value',1);
handles.channelImageHandler = scanimage.guis.ChannelImageHandler(handles.pcChannelConfig);
handles.channelImageHandler.initColorMapsInTable();

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes channelControlsV4 wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = channelControlsV4_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in pbSaveCfg.
function pbSaveCfg_Callback(hObject, eventdata, handles)
% hObject    handle to pbSaveCfg (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hModel.hConfigurationSaver.cfgSaveConfig();

% --- Executes on button press in togglebutton1.
function togglebutton1_Callback(hObject, eventdata, handles)
% hObject    handle to togglebutton1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of togglebutton1


function cbMergeEnable_Callback(hObject, eventdata, handles)
handles.hController.updateModel(hObject,eventdata,handles);

function cbChannelsMergeFocusOnly_Callback(hObject, eventdata, handles)
handles.hController.updateModel(hObject,eventdata,handles);

% --- Executes on button press in pbSaveUSR.
function pbSaveUSR_Callback(hObject, eventdata, handles)
% hObject    handle to pbSaveUSR (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hModel.hConfigurationSaver.usrSaveUsr();

% --- Executes on button press in pbSaveReference.
function pbSaveReference_Callback(hObject, eventdata, handles)
% hObject    handle to pbSaveUSR (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hModel.hDisplay.saveReference();

% --- Executes on button press in pbLoadReference.
function pbLoadReference_Callback(hObject, eventdata, handles)
% hObject    handle to pbSaveUSR (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hModel.hDisplay.loadReference();



function pmImageColormap_Callback(hObject, eventdata, handles)
strs = get(hObject,'String');
val = get(hObject,'Value');
handles.channelImageHandler.updateTable(strs{val});
handles.channelImageHandler.applyTableColorMapsToImageFigs();
handles.hController.hScanfieldDisplayControls.updateColorMaps();


% --- Executes on button press in pbReadOffsets.
function pbReadOffsets_Callback(hObject, eventdata, handles)
% hObject    handle to pbReadOffsets (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hModel.hScan2D.measureChannelOffsets([],true);

% --- Executes on button press in cbAutoReadOffsets.
function cbAutoReadOffsets_Callback(hObject, eventdata, handles)
% hObject    handle to cbAutoReadOffsets (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of cbAutoReadOffsets
handles.hController.updateModel(hObject,eventdata,handles);


% --- Executes on button press in cbDisplayReference.
function cbDisplayReference_Callback(hObject, eventdata, handles)
% hObject    handle to cbDisplayReference (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of cbDisplayReference
handles.hController.updateModel(hObject,eventdata,handles);



function etDisplayReferenceIntensity_Callback(hObject, eventdata, handles)
% hObject    handle to etDisplayReferenceIntensity (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of etDisplayReferenceIntensity as text
%        str2double(get(hObject,'String')) returns contents of etDisplayReferenceIntensity as a double
handles.hController.updateModel(hObject,eventdata,handles);



% --- Executes on button press in pbSignalConditioning.
function pbSignalConditioning_Callback(hObject, eventdata, handles)
% hObject    handle to pbSignalConditioning (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.hSignalConditioningControls.Visible = true;





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
