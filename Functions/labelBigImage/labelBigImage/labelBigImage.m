function userData = labelBigImage(imageName,varargin)
% labelBigImage(imageName) opens an app for ground-truth labeling of
% large images.
%
% SYNTAX:
% userData = labelBigImage(imageName);
%    Launches an instance of labelBigImage operating on image imageName.
%
% userData = labelBigImage(imageName,'includeLearningTools',TF);
%    Optional Parameter-Value pair 'includeLearningTools',{true,false}
%    indicates that an optional panel of deep learning training and
%    inference tools will be included! (Default: false--for now)
%
% ... = labelBigImage(imageName,'maxDisplayDimension',maxDisplayDimension)
%    Options Parameter-Value pair 'maxDisplayDimension',[positive integer]
%    specifies the maximum loadable full-resolution sub-image dimension. {Default: 10000}.
%
% ... = labelBigImage(imageName,'useMultiSessionLabels',TF)
%    Options Parameter-Value pair 'useMultiSessionLabels',{true,false}
%    indicates whether the names of ROIs should be saved and recalled
%    across sessions. {Default: false}.
%
% NOTABLE FEATURES:
% 1) Auto-parsing of metadata to create overview thumbnail;
% 2) Spatially referenced overview and subImage;
% 3) Interactive and automatic labeling at overview- or subImage- levels;
% 4) Auto-save timer, prompting for saving every 10 minutes if something has
%    changed;
% 5) User-configurable:
%    a) color-coded labels
%    b) optimal thumbnail size
% 6) Session logging;
% 7) Reconfigurable layouts;
%
% % EXAMPLE:
% img = '..\Data\Scan004_cellspot_pyramid.tif';
% myUserData = labelBigImage(img);
%
% Brett Shoelson, PhD
% bshoelso@mathworks.com
% 01/15/2017--11/20/2019
%
% VERSION:
% 1.5.1 Release: Ground-truth labeling of big images. First customer-ready
%       verson?
% 1.6.0 Release: (6/08/2019) Second customer-ready verson.
%
% TODO:
% * If you leave the current subimage by selecting an outside ROI from the
%   listbox, names aren't being updated to non-initial values.
% * The McCabe complexity is far too high; I need to simplify some of this!
%
% See also: groundTruthLabeler, imageLabeler

% Acknowledgements: Grateful acknowledgement for assistance to Joyeeta
% Mukherjee, PhD; Ashish Uthama; Jeff Gruneich, PhD; Abhijit Bhattacharjee;
% and Sean de Wolski.
%
% Version: 1.62
% Incompatibility changes:
% 1) 5/21/19 Changed the sensitivityThreshold to 1-sensitivityThreshold for
%    thresholding operations.
%

% Copyright 2017-2019 The MathWorks, Inc.

% TODO:
%%%%%%%%%%%%%% BUGS:
% * mask.Labels ???
%%%%%%%%%%%%%% TIER 1 ENHANCEMENTS
% * Validation panel!
%     *imageViewerAndProcessor.m
% * Export of pixel labelstores/gTruth
% * Figure out how to save (and recall) labels in general. (Current usage
%     is hard-coded for Hologic label image.)
% * Prediction mode
%     * getFreehandRegionDescriptors
% Toggle display of scores (synchronizedROI.addSynchronizedLabels)
%%%%%%%%%%%%%% TIER 2 ENHANCEMENTS
% * Parallel processing (parfor?) of all sub-tiles
% * More feature-rich version
%   * labelBigImageAndSegmenter.m (restartlabelBigImageAndSegmenter)
%%%%%%%%%%%%%% TIER 3 ENHANCEMENTS
% * Implement UNDO

fprintf('\nSetting up environment...\n\n')
% Input parsing
[includeLearningTools,maxDisplayDimension,...
    previousSessionROIs,useMultiSessionLabels] = ...
    parseInputs(varargin{:});

% Define variables in context of environment (and one global):
global notifyOfConversions
notifyOfConversions.subImageHandle = true;
notifyOfConversions.overviewImg = true;
notifyOfConversions.autoSave = false;
notifyOfMaxDimension = true;
%
[autoDetectorDir,chipHEdit,chipWEdit,colorspaceConversionMenu,...
    complementImageMenu,currentZoomPosition,displayParameters,facePatch,...
    groundTruthDir,hPanel,imageChipDir,imrefSubImageToOverview,...
    labelBackgroundColor,labelPref,lockedOrderLabels,medfiltImageMenu,...
    nROIsEdit,oldReturnedPosition,originalImageMenu,...
    overviewImageTitle,overviewRegionSelector,parentAx,pixOrMM,...
    previousSelection,processRegionsOpt,requestedTLNetwork,requestedPosition,...
    skipUnvalidated,skipValidated,subimageDir,...
    subImageHandle,subImageTitle,subImageTiles,testDS,thisLabel,...
    trainedNetwork,trainingIMDS,trainingSuperDir,utilitiesDir,validateAll] = ...
    deal([]);
%subregionProcessTime = 0; %Initial guess...will get updated
isSaved = false;
segmentThisImage = true;
createVideo = false;
isZoomed = false;
operatorIsValidator = false;
uniqueID = 0;
nextUniqueIdentifier = 1;
nLayouts = 2;
labelBackgroundColor = [1 0 0];
defaultAutoSegLabel = 'Auto-Segmented';
defaultManualSegLabel = 'ManuallySegmented';
defaultManualSegColor = 'y';
defaultThisSubimageAutoSegLabel = 'InitialAutoSegmentation';
validationOption = 'Validate All';
BILPrefs = setupEnvironment;

%
if nargin < 1 || isempty(imageName)
    [fn,pn] = uigetfile('*.*','Select a big-image file');
    if fn==0
        userData = [];
        return
    else
        imageName = fullfile(pn,fn);
    end
    if exist(BILPrefs.multiSessionLabelList,'file')
        tmp = questdlg('Would you like to use your label list history from previous labeling sessions?',...
            'Use Labeling History?',...
            'YES','No','YES');
        if strcmp(tmp,'YES')
            useMultiSessionLabels = true;
        end
        %         multiSessionLabelList = fullfile(utilitiesDir,...
        %             'multiSessionLabels.mat');
    end
end %if nargin < 1 || isempty(imageName)

% SESSION/SAVING INFORMATION:
if ~ischar(imageName)
    error('labelBigImage: Please enter the NAME of the image you want to evaluate.')
else
    [pathToImage,thisFilename,ext] = fileparts(imageName);
    if isempty(pathToImage)
        pathToImage = fileparts(which(imageName));
    end
    thisImageFullFilename = fullfile(pathToImage,thisFilename);
    switch lower(ext)
        case {'.tif','.tiff','.svs','.ndpi'}
            [overviewImage,imrefOverview,pageInfo,tiffImageClass,isTiled,currMPP] = ...
                downsampleBigTiff(imageName,[],...
                'verbose',true);
        otherwise
            beep
            temporaryDialog('Image format not yet supported!')
            return
    end
    if isempty(overviewImage)
        % User canceled in downsampleBigTiff
        disp('Cancelled');
        return
    end
end %if ~ischar(imageName)

% Make paths specific for this image:
customizeBILPrefs;
% Session Log:
currentSessionLog = [];

% MANAGE LABELS:
%  Note on labels: I maintain two copies of labels: currentSessionLabels,
%  and multiSessionLabels. currentSessionLabels is initialized on opening;
%  multiSessionLabels is maintained across sessions. If
%  "useMultiSessionLabels" is true (default: false), currentSessionLabels
%  is initialized to the list saved in BILPrefs.multiSessionLabelList. On closeReq,
%  currentSessionLabels are merged into BILPrefs.multiSessionLabelList and saved.
%
% Also: Display of synROI properties (via uicontextmenu) is managed by
% @synchronizedROI\extendSynchronizedImroiContextMenu;

if useMultiSessionLabels && exist(BILPrefs.multiSessionLabelList,'file')
    multiSessionLabels = load(BILPrefs.multiSessionLabelList);
    multiSessionLabels = multiSessionLabels.currentSessionLabels;
    currentSessionLabels = [defaultAutoSegLabel;...
        sort(setdiff(multiSessionLabels,...
        {defaultAutoSegLabel,defaultManualSegLabel,defaultThisSubimageAutoSegLabel}))];
else
    % Default:
    currentSessionLabels = ...
        {defaultAutoSegLabel};
end %if useMultiSessionLabels && exist(BILPrefs.multiSessionLabelList,'file')

lockedOrderLabels = currentSessionLabels;
labelDir = fullfile(BILPrefs.utilitiesDir,'currentSessionLabels.mat');
save(labelDir,'currentSessionLabels')


% IMAGE:
userData.tiffImageClass = tiffImageClass;
% Retrieve, create useful parameters
imgH = pageInfo.Height;
imgW = pageInfo.Width;
if isTiled
    tileH = pageInfo.TileLength;
    tileW = pageInfo.TileWidth;
    nTileRows = ceil(imgH/tileH);
    nTileCols = ceil(imgW/tileW);
    tileMap = reshape(1:nTileRows*nTileCols,nTileCols,nTileRows);
else
    error('labelBigImage: Untiled images not yet supported.')
end %if isTiled

% SET UP UI ENVIRONMENT:
% (Set this flag to false to allow multiple simultaneous instances):
singleton = true;
fname = 'Label Big Image   (PLEASE PROVIDE FEEDBACK TO: bshoelso@mathworks.com)';
if singleton
    currFig = findobj('type','figure','Name',fname);
    if ~isempty(currFig)
        tmp = questdlg('There is an open session. Do you want to close it?',...
            'Session in Progress?','CLOSE IT','Leave it open!','CLOSE IT');
        if strcmp(tmp,'CLOSE IT')
            delete(findobj('type','figure','Name',fname))
        end
    end
end %if singleton

labelBigImageHndl = figure('numbertitle','off',...
    'Name',fname,...
    'units','normalized',...
    'windowstyle','normal',...
    'menubar', 'none',...
    'toolbar','none',...
    'visible','off',...
    'position',[0 0.04 1 0.87],...0.86667
    'DefaultAxesUnits','normalized',...
    'DefaultUipanelUnits','normalized',...
    'DefaultUicontrolUnits','normalized',...
    'CloseRequestFcn',@closeLabeler);
%
setupMenus;
allColors = defineColors;
% addlistener(labelBigImageHndl,'CurrentKey','PostSet',@(~,~)figureKeyPressed);
%
setappdata(labelBigImageHndl,'nextUniqueIdentifier',nextUniqueIdentifier);
userData.figureHandle = labelBigImageHndl;
overviewImageAx = axes(labelBigImageHndl,...
    'Box','on',...
    'LineWidth',2,...
    'Visible','on',...
    'XTick',[],...
    'YTick',[]);
userData.overviewImageAxes = overviewImageAx;
hold(overviewImageAx,'on')
subImageAx = axes(labelBigImageHndl,...
    'XLim',imrefOverview.XWorldLimits,...
    'YLim',imrefOverview.YWorldLimits,...
    'FontSize',8);
userData.subImageAxes = subImageAx;
hold(subImageAx,'on')
%
toolPanel = uipanel(labelBigImageHndl,'title','Tooling/Options',...
    'DefaultUicontrolUnits','normalized',...
    'DefaultUibuttongroupUnits','normalized');
%
if includeLearningTools
    bgcolor = get(labelBigImageHndl,'color');
    %tabLabels = {'Segmentation/Labeling','Deep Learning/Training','Inference/Detection'};
    tabLabels = {'Segmentation/Labeling','Deep Learning/Training & Inference'};
    [mainTabHandle,tabCardHandles,tabHandles] = ...
        tabPanel(toolPanel,tabLabels,...
        'tabpos','t',...
        'tabheight',60,...
        'colors',[bgcolor*0.9;bgcolor*0.8;bgcolor*0.7],...
        'highlightColor',0.5*[0 1 1],...
        'TabCardPVs',{'bordertype','etchedin','title',''},...
        'TabLabelPVs',{'fontsize',10,'fontweight','n'});
    %
    toolsParent = tabCardHandles{1}(1);
    bgc = get(toolsParent,'backgroundColor');
    set(toolsParent,'defaultUIControlBackgroundColor',bgc,...
        'defaultUIPanelBackgroundColor',bgc,...
        'defaultUIButtonGroupBackgroundColor',bgc);
    set(toolPanel,'title','');
else
    toolsParent = toolPanel;
end %if includeLearningTools
%
[objpos,objdim] = distributeObjects(3,0.975,0.7,0.01);
uicontrol(toolsParent,...
    'style','pushbutton',...
    'position',[0.01 objpos(1) 0.2 objdim],...
    'string','DISPLAY/EXPORT Annotations',...
    'tooltipstring','Display in the Command Window a table of current annotations and positions.',...
    'BackgroundColor',[0.8 0.9 1],...
    'callback',@(~,~)generateSessionLog(true,true));% IncludeUnnamed,Verbose
uicontrol(toolsParent,...
    'style','pushbutton',...
    'BackgroundColor',[0.8 0.9 1],...
    'position',[0.01 objpos(2) 0.2 objdim],...
    'tooltipstring','Specify size of regions and write to directory all rectangular ROIs entirely contained within freehand regions.',...
    'string','Define/Extract Training Chips',...
    'callback',@extractTrainingData);
uicontrol(toolsParent,...
    'position',[0.01 objpos(3) 0.2 objdim],...0.01
    'BackgroundColor',[0.8 0.9 1],...
    'tooltipstring','Select labels/positions for this image from a previously saved session.',...
    'string','Recall Session',...
    'callback',@recallSession);
% uicontrol(toolsParent,...
%     'position',[0.01 objpos(4) 0.2 objdim],...0.01
%     'BackgroundColor',[0.8 0.9 1],...
%     'string','Save Now',...
%     'callback',@saveSession);
[hobjpos,hobjdim] = distributeObjects(2,0.025,0.475,0.025);
% dispBB = uibuttongroup(toolsParent,...
%     'position',[0.01 hobjpos(1) 0.2 hobjdim],...
%     'Title','Tile Reposition Behavior');%,...
roiTypeBG = uibuttongroup(toolsParent,...
    'position',[0.01 hobjpos(1) 0.2 hobjdim],...
    'Title','ROI Type');%,...
[objpos,objdim] = distributeObjects(2,0.95,0.05,0.015);
tts = sprintf('Draw manual ROIs using FREEHAND.\n(Note that you will have the opportunity to extract training chips using bounding rectangles\neven if you draw freehand ROIs.)');
drawFreehandButton = uicontrol(roiTypeBG,'Style',...
    'radiobutton',...
    'String','Freehand',...
    'tooltipstring',tts,...
    'Position',[0.01 objpos(1) 0.99 objdim],...
    'HandleVisibility','off');
tts = sprintf('Draw manual ROIs using RECT.');
drawRectButton = uicontrol(roiTypeBG,'Style','radiobutton',...
    'String','Rectangle',...
    'tooltipstring',tts,...
    'Position',[0.01 objpos(2) 0.99 objdim],...
    'HandleVisibility','off');
if strcmp(BILPrefs.drawType,'freehand')
    drawFreehandButton.Value = 1;
else
    drawRectButton.Value = 1;
end
[vobjpos,vobjdim] = distributeObjects(2,0.635,0.49,0.015);
uicontrol(toolsParent,...
    'style','text',...
    'position',[0.01 0.615 0.25 vobjdim],...
    'FontSize',8,...
    'foregroundcolor','r',...
    'horizontalalignment','left',...
    'FontWeight','bold',...
    'string','LABEL VISIBILITY:');
showLabelsCheckbox(1) = uicontrol(toolsParent,...
    'style','checkbox',...
    'position',[0.01 vobjpos(1) 0.1 vobjdim],...
    'tooltipstring','Show/Hide labels in overview axes.',...
    'string','Overview',...
    'value',0,...
    'callback',@showButtonVisibility);
showLabelsCheckbox(2) = uicontrol(toolsParent,...
    'style','checkbox',...
    'position',[0.115 vobjpos(1) 0.1 vobjdim],...
    'tooltipstring','Show/Hide labels in subimage axes.',...
    'string','SubImage',...
    'value',1,...
    'callback',@showButtonVisibility);
toggleAutoSaveCkBox = uicontrol(toolsParent,...
    'style','checkbox',...
    'position',[0.01 vobjpos(2) 0.325 vobjdim],...
    'string','Auto-Save',...
    'tooltipstring','Save every 10 minutes if something has changed.',...
    'value',1,...
    'callback',@toggleAutoSave);
labelMode = uibuttongroup(toolsParent,...
    'position',[0.01 hobjpos(2) 0.2 hobjdim],...
    'Title','Labeling Mode');
[objpos,objdim] = distributeObjects(2,0.95,0.05,0.015);
tts = sprintf('The user will be prompted to manually select all labels.');
uicontrol(labelMode,'Style',...
    'radiobutton',...
    'String','Manually Label',...
    'tooltipstring',tts,...
    'Position',[0.01 objpos(1) 0.99 objdim],...
    'HandleVisibility','off');
tts = sprintf('A prediction will be made after a sufficient number of regions have been labeled. The user will have the opportunity to verify the labels.\n(Note that this option is ignored for automatic block-segmentations.)');
predictVerifyButton = uicontrol(labelMode,'Style','radiobutton',...
    'String','Predict/Verify',...
    'tooltipstring',tts,...
    'Position',[0.01 objpos(2) 0.99 objdim],...
    'HandleVisibility','off');
%
[hpos,hdim] = distributeObjects(2,0.025,0.975,0.025);
segPanelLeft = 0.225;
segPanelWidth = 0.45;
autosegPanel = uipanel(toolsParent,...
    'title','Segmentation/Filter Settings',...
    'position',[segPanelLeft 0.025 segPanelWidth 0.975]);
[vpos,vdim] = distributeObjects(3,0.5,0.9875,0.015);
sensitivitySlider = sliderPanel(autosegPanel,...
    {'title','Sensitivity',...
    'pos',[hpos(1) vpos(3) hdim vdim],...
    'fontweight','b','units','normalized','fontsize',7},...
    {'min',0,'max',1,'value',BILPrefs.sensitivity,'callback',@(src,evt)autoSegment('uiAction'),...@autoSegment,...
    'tooltipstring','Sensitivity parameter (modified for different segmentation algorithms).',...
    'tag','sensitivity'},...
    {},...
    {},...
    '%0.2f');
maxSizeSlider = sliderPanel(autosegPanel,...
    {'title','Maximum Size',...
    'pos',[hpos(1) vpos(2) hdim vdim],...
    'fontweight','b','units','normalized','fontsize',7},...
    {'min',1000,'max',1e10,'value',BILPrefs.maxSize,'sliderstep',[0.001 0.1],...
    'callback',@(src,evt)autoSegment('uiAction'),...
    'tooltipstring','Specify (in pixels) the size of the largest acceptable region.',...
    'tag','maxSizeSlider'},...@autoSegment,...
    {},...
    {{'string','1000'},{'string','1e10'}},...
    '%0.0f');
minSizeSlider = sliderPanel(autosegPanel,...
    {'title','Minimum Size',...
    'pos',[hpos(1) vpos(1) hdim vdim],...
    'fontweight','b','units','normalized','fontsize',7},...
    {'min',0,'max',1e6,'value',BILPrefs.minSize,'sliderstep',[0.001 0.1],...
    'callback',@(src,evt)autoSegment('uiAction'),...
    'tooltipstring','Specify (in pixels) the size of the smallest acceptable region.',...
    'tag','minSizeSlider'},...@autoSegment,...
    {},...
    {{'string','0'},{'string','1e6'}},...
    '%0.0f');

simplifyAmountSlider = sliderPanel(autosegPanel,...
    {'title','Border Simplification',...
    'pos',[hpos(2) vpos(3) hdim vdim],...
    'fontweight','b','units','normalized','fontsize',7},...
    {'min',0,'max',1,'value',BILPrefs.simplifyAmount,...
    'callback',@(src,evt)autoSegment('uiAction'),...
    'tooltipstring','Amount of border simplification.',...
    'sliderstep',[0.02 0.1]},...
    {},...
    {},...
    '%0.2f');
buttonHeight = 0.06;
nRowsOfButtons = 2;
bottomPos = 0.025+nRowsOfButtons*buttonHeight;
lrGap = 0.01;
% HORIZONTAL: |(segPanelLeft+segPanelWidth+lrGap)|(lbWdith)|
lbWidth = 1-(segPanelLeft+segPanelWidth+lrGap);
lbLeft = segPanelLeft+segPanelWidth+lrGap;
listboxOfSynchronizedROIs = uicontrol(toolsParent,...
    'style','listbox',...
    'position',[lbLeft bottomPos lbWidth 1-bottomPos-buttonHeight-0.005],...
    'fontname','monospaced',...
    'fontsize',8.5,...
    'string','',...
    'Max',10,...
    'Min',1,...
    'Callback',@(obj,~)showCurrentSynROI(obj));
addlistener(listboxOfSynchronizedROIs,'Value','PreSet',@(obj,evnt)setPreviousSelection(evnt));
addlistener(listboxOfSynchronizedROIs,'Value','PostSet',@(obj,evnt)updateLabelCount);
labelButtonWidth = 0.2;
uicontrol(toolsParent,...
    'style','pushbutton',...
    'position',[lbLeft 1-buttonHeight labelButtonWidth buttonHeight],...
    'Fontsize',8,...
    'BackgroundColor',[0.8 0.9 1],...
    'FontWeight','bold',...
    'tooltipstring','Sort ascending/descending by label.',...
    'String', [' LABEL ' char(8593) char(8595)],...
    'Callback',@(src,evt)sortListbox('label'));
uicontrol(toolsParent,...
    'style','pushbutton',...
    'position',[lbLeft+labelButtonWidth 1-buttonHeight 1-(lbLeft+labelButtonWidth) buttonHeight],...
    'Fontsize',8,...
    'BackgroundColor',[0.8 0.9 1],...
    'FontWeight','bold',...
    'tooltipstring','Sort ascending/descending by unique ID.',...
    'String', ['ID ' char(8593) char(8595)],...
    'Callback',@(src,evt)sortListbox('ID'));
[bpos,bdim] = distributeObjects(3,lbLeft,1,0);
uicontrol(toolsParent,...
    'style','pushbutton',...
    'position',[bpos(1) 0.025+buttonHeight bdim buttonHeight],...
    'Fontsize',8,...
    'BackgroundColor',[0.8 0.9 1],...
    'tooltipstring','Select all regions matching desired label.',...
    'String', 'Select By Label',...
    'Callback',@selectByLabel);
uicontrol(toolsParent,...
    'style','pushbutton',...
    'position',[bpos(2) 0.025+buttonHeight bdim buttonHeight],...
    'Fontsize',8,...
    'BackgroundColor',[0.8 0.9 1],...
    'tooltipstring','Go to and highlight the (first) selected region.',...
    'String', 'GoTo',...
    'Callback',@gotoSynROI);
uicontrol(toolsParent,...
    'style','pushbutton',...
    'position',[bpos(3) 0.025+buttonHeight bdim buttonHeight],...
    'Fontsize',8,...
    'BackgroundColor',[0.8 0.9 1],...
    'tooltipstring','Delete all selected ROIs.',...
    'String', 'Delete Selected',...
    'Callback',@deleteSynROIs);
[bpos,bdim] = distributeObjects(2,lbLeft,1,0);
uicontrol(toolsParent,...
    'style','pushbutton',...
    'position',[bpos(1) 0.025 bdim buttonHeight],...
    'Fontsize',8,...
    'BackgroundColor',[0.8 0.9 1],...
    'tooltipstring','Rename all selected ROIs.',...
    'String', 'Rename Selected',...
    'Callback',@renameSelected);
validateButton = uicontrol(toolsParent,...
    'style','pushbutton',...
    'position',[bpos(2) 0.025 bdim buttonHeight],...
    'enable','off',...
    'Fontsize',8,...
    'BackgroundColor',[0.8 0.9 1],...
    'tooltipstring','Validate ALL ROIs currently displayed in the subImage axes.',...
    'String', 'Validate',...
    'Callback',@validateROIs);
tts = sprintf('Allow holes in autosegmented ROIs?\n(When holes are disallowed, performance may be faster, but interior regions will be dissolved.)');
shiftval = 0.0875;
[objpos,objdim] = distributeObjects(4,0.985+0.05,0.15,0.015);
allowHolesCheckbox = uicontrol(autosegPanel,...
    'Style','checkbox',...
    'String','Allow holes?',...
    'Value',0,...
    'Enable','on',...
    'TooltipString',tts,...
    'Tag','Threshold',...
    'Position',[hpos(1) 0.3875+0.01 hdim 0.1],...
    'HandleVisibility','off',...
    'callback',@(src,evt)autoSegment('uiAction'));
%
% Here I use a panel of radio buttons instead of a uibuttongroup so that I
%   can (re-)trigger on button (re-)selection.
segmentOpt = uipanel(autosegPanel,...
    'position',[hpos(1) 0.025 hdim 0.425+0.05-shiftval],...
    'Title','Segmentation Option');
tts = sprintf('imbinarize(grayscale(img)):\nWhen "Dark" is selected, the image is complemented before analysis.\n(Otherwise, not.)');
segOptRadio(1) = uicontrol(segmentOpt,...
    'Style','radiobutton',...
    'String','Threshold:',...
    'ToolTipString',tts,...
    'Value',1,...
    'Callback',@(src,evt)autoSegment('uiAction',src),...
    'Position',[hpos(1) objpos(1) 0.55 objdim],...
    'HandleVisibility','off');
thresholdPolarity = uicontrol(segmentOpt,...
    'Style','checkbox',...
    'String','Dark',...
    'FontSize',7,...
    'Value',1,...
    'Tag','Threshold',...
    'Position',[0.65 objpos(1) 0.375 objdim],...
    'HandleVisibility','off',...
    'Callback',@changePolarity);
tts = sprintf('When "Dark" is selected, imextendedmin(grayscale(img)) is used.\nOtherwise, imextendedmax(grayscale(img)) is used.');
segOptRadio(2) = uicontrol(segmentOpt,...
    'Style','radiobutton',...
    'String','Imextended:',... Minima
    'ToolTipString',tts,...
    'Callback',@(src,evt)autoSegment('uiAction',src),...
    'Position',[hpos(1) objpos(2) 0.55 objdim],...
    'HandleVisibility','off');
imextendedDirection = uicontrol(segmentOpt,...
    'Style','checkbox',...
    'String','Dark',...
    'FontSize',7,...
    'Value',1,...
    'Tag','Imextended',...
    'Position',[0.65 objpos(2) 0.3 objdim],...
    'HandleVisibility','off',...
    'Callback',@changePolarity);
tts = sprintf('Click on a region/object to segment it.\n(Calls grayconnected(grayscale(img)).');
segOptRadio(3) = uicontrol(segmentOpt,...
    'Style','radiobutton',...
    'String','Gray Connectivity',...
    'Tooltipstring',tts,...
    'Callback',@(src,evt)autoSegment('uiAction',src),...
    'Position',[hpos(1) objpos(3) 0.95 objdim],...
    'HandleVisibility','off');
tts = sprintf('Provide a custom function handle with the syntax\n \n@(Img,optionalArg1,...,optionalArgN)fcnHandle(Img,optionalArg1,...,optionalArgN));\n \nNOTE: CUSTOM algorithms operate directly on the extracted subimage, with no color conversions.\nIf you want to operate on a grayscale image, for example, please include the conversion to gray in the custom algorithm.');
    segOptRadio(4) = uicontrol(segmentOpt,...
    'Style','radiobutton',...
    'String','Custom',...
    'tooltipstring',tts,...
    'Callback',@(src,evt)autoSegment('uiAction',src),...
    'Position',[hpos(1) objpos(4) 0.45 objdim],...
    'HandleVisibility','off');
uicontrol(segmentOpt,...
    'Style','pushbutton',...
    'tooltipstring','Select and launch segmentation app to create a custom algorithm.',...
    'String','Use App',...
    'Position',[hpos(2) 1.25*objpos(4) 0.45 0.6*objdim],...
    'HandleVisibility','off',...
    'callback',@populateImageSegmenter);
customFcnEditBox = uicontrol(autosegPanel,'Style',...
    'edit',...
    'tooltipstring',tts,...
    'horizontalalignment','left',...
    'String',' Function Handle Here!',...
    'Position',[hpos(1) 0.0125 1-hpos(1)+0.01 0.075]);
%'callback',@(src,evt)autoSegment('uiAction'),...
%
[vobjpos,vobjdim] = distributeObjects(4,0.725,0.475,0.025);
whichAxButton(1) = uicontrol(autosegPanel,...
    'style','radio',...
    'position',[hpos(2) vobjpos(1) 0.25 vobjdim],...[hpos(2) vobjpos(1) hdim vobjdim],...
    'string','SubImage',...
    'value',1,...
    'callback',@changeSegmentAx);
whichAxButton(2) = uicontrol(autosegPanel,...
    'style','radio',...
    'position',[hpos(2)+0.25 vobjpos(1) hdim vobjdim],...[hpos(2) vobjpos(2) hdim vobjdim]
    'string','Overview',...
    'value',0,...
    'callback',@changeSegmentAx);
shift = 0.075;
tts = 'Maximum allowable area percentage of the analyzed subimage.';
maxAreaPercentText = uicontrol(autosegPanel,...
    'style','text',...
    'HorizontalAlignment','left',...
    'tooltipstring',tts,...
    'position',[hpos(2) vobjpos(3)+shift hdim vobjdim],...2*
    'string','Max Area Pct');%{'Max Allowable'; 'Overlap (%)'});
maxAreaPercent = uicontrol(autosegPanel,...
    'style','edit',...
    'position',[hpos(2)+hdim/1.5 vobjpos(3)+shift hdim/3 vobjdim],...
    'callback',@(src,evt)autoSegment('uiAction'),...
    'string',0.85);
tts = 'Nonmax suppression threshold. ( See: selectStrongestBbox() ).';
uicontrol(autosegPanel,...
    'style','text',...
    'HorizontalAlignment','left',...
    'tooltipstring',tts,...
    'position',[hpos(2) vobjpos(4)+shift hdim vobjdim],...2*
    'string','Overlap Threshold');%{'Max Allowable'; 'Overlap (%)'});
maxOverlapEdit = uicontrol(autosegPanel,...
    'style','edit',...
    'position',[hpos(2)+hdim/1.5 vobjpos(4)+shift hdim/3 vobjdim],...1.25*
    'callback',@(src,evt)autoSegment('uiAction'),...
    'string',0.50);
%iptaddcallback(grayconRadio,'callback',@manageSerialSegmentButton);
iptaddcallback(whichAxButton(1),'callback',@manageSerialSegmentButton);
iptaddcallback(whichAxButton(2),'callback',@manageSerialSegmentButton);
shift = 0.075;
[objpos,objdim] = distributeObjects(5,0.465+shift,0.0875+shift,0.0075);
uicontrol(autosegPanel,...
    'position',[hpos(2) objpos(1) hdim objdim],...
    'tooltipstring','Delete all auto-segmented ROIs that haven''t been renamed from default labels.',...
    'string','Clear Unlabeled ROIs',...
    'BackgroundColor',[0.8 0.9 1],...
    'callback',@(src,evt)clearSynROIsNamed({defaultAutoSegLabel,defaultThisSubimageAutoSegLabel},true));
tts = sprintf('NOTE: In contrast to using UICONTROLS, pressing this button does not clear current auto-segmented ROIs!');
segSelectedButton = uicontrol(autosegPanel,...
    'position',[hpos(2) objpos(2) hdim objdim],...
    'BackgroundColor',[0.8 0.9 1],...
    'string','Segment Selected',...
    'tooltipstring',tts,...
    'callback',@(src,evt)autoSegment('processNow'));
tts = sprintf('Implements nonmax suppression to eliminate overlapping bounding boxes with lower confidence scores.');
addManualRegion = uicontrol(autosegPanel,...
    'position',[hpos(2) objpos(3) hdim objdim],...
    'BackgroundColor',[0.8 0.9 1],...
    'string','Remove Overlaps',...
    'Enable','on',...
    'tooltipstring',tts,...
    'callback',@manageOverlaps);
tts = sprintf('Draw freehand on the overview image to specify the region(s) you want to process blockwise.');
addManualRegion = uicontrol(autosegPanel,...
    'position',[hpos(2) objpos(4) hdim objdim],...
    'BackgroundColor',[0.8 0.9 1],...
    'string','Select Process Region(s)',...
    'Enable','on',...
    'tooltipstring',tts,...
    'callback',@displayAndSelectGrid);
tts = sprintf('Using settings for this subregion, auto-segmentat all INCLUDED subImages in the entire image.\n\nAll tiles are included by default, but you may use the ''Select Process Region(s)'' button\nto explicitly constrain the processing to user-specified region(s).\n\n\n(NOTE: This could take some time--there may be thousands of sub-regions!)');
processAllTiles = uicontrol(autosegPanel,...
    'position',[hpos(2) objpos(5) hdim objdim],...
    'BackgroundColor',[0.8 0.9 1],...
    'string','Segment (Included) SubImages',...
    'Enable','on',...
    'tooltipstring',tts,...
    'callback',@serialAutosegment);
%
tts = sprintf('For auto-segmentation (non-click) options, trigger segmentation with any uicontrol update.\n(NOTE: De-select if you want to change multiple parameters before triggering the segmentation.)');
processImmediatelyCkbox = uicontrol(autosegPanel,...
    'style','checkbox',...
    'tooltipstring',tts,...
    'position',[hpos(2) 0.0875 hdim 0.075],...0.025
    'value',1,...
    'string','Process Immediately');
% NEXT TAB:
if includeLearningTools
    toolsParent = tabCardHandles{1}(2);
    [vobjpos,vobjdim] = distributeObjects(7,0.85,0.35,0.01);
    [hobjpos,hobjdim] = distributeObjects(4,0.01,0.98,0.01);
    %textL = 0.01;
    textW = 0.02;
    textGap = 0.01;
    % Transfer Learning Workflow
    uicontrol(toolsParent,...
        'style','text',...
        'BackgroundColor',get(toolsParent,'BackgroundColor'),...
        'position',[hobjpos(1) 0.875 hobjdim 0.1],...
        'string',{'TRANSFER LEARNING';'WORKFLOW'},...
        'Fontweight','bold',...
        'FontSize',9.5);
    uicontrol(toolsParent,...
        'style','text',...
        'BackgroundColor',get(toolsParent,'BackgroundColor'),...
        'position',[hobjpos(1) vobjpos(1) textW vobjdim],...
        'string','1)',...
        'Fontweight','bold',...
        'FontSize',11);
    uicontrol(toolsParent,...
        'style','pushbutton',...
        'BackgroundColor',[0.8 0.9 1],...
        'position',[hobjpos(1)+textW+textGap vobjpos(1) hobjdim-textW-textGap vobjdim],...
        'string','Select Training Data Directory',...
        'callback',@selectTrainingDir);
    uicontrol(toolsParent,...
        'style','text',...
        'BackgroundColor',get(toolsParent,'BackgroundColor'),...
        'position',[hobjpos(1) vobjpos(2) textW vobjdim],...
        'string','2)',...
        'Fontweight','bold',...
        'FontSize',11);
    uicontrol(toolsParent,...
        'style','pushbutton',...
        'BackgroundColor',[0.8 0.9 1],...
        'position',[hobjpos(1)+textW+textGap vobjpos(2) hobjdim-textW-textGap vobjdim],...
        'string','Validate Labels',...
        'callback',@selectTransferLearningNetwork);
    uicontrol(toolsParent,...
        'style','text',...
        'BackgroundColor',get(toolsParent,'BackgroundColor'),...
        'position',[hobjpos(1) vobjpos(3) textW vobjdim],...
        'string','3)',...
        'Fontweight','bold',...
        'FontSize',11);
    uicontrol(toolsParent,...
        'style','pushbutton',...
        'BackgroundColor',[0.8 0.9 1],...
        'position',[hobjpos(1)+textW+textGap vobjpos(3) hobjdim-textW-textGap vobjdim],...
        'string','Select Pre-trained Network',...
        'callback',@selectTransferLearningNetwork);
    uicontrol(toolsParent,...
        'style','text',...
        'BackgroundColor',get(toolsParent,'BackgroundColor'),...
        'position',[hobjpos(1) vobjpos(4) textW vobjdim],...
        'string','4)',...
        'Fontweight','bold',...
        'FontSize',11);
    uicontrol(toolsParent,...
        'style','pushbutton',...
        'BackgroundColor',[0.8 0.9 1],...
        'Enable','off',...
        'position',[hobjpos(1)+textW+textGap vobjpos(4) hobjdim-textW-textGap vobjdim],...
        'string','Specify Training Options',...
        'callback',@specifyTrainingOptions);
    uicontrol(toolsParent,...
        'style','text',...
        'BackgroundColor',get(toolsParent,'BackgroundColor'),...
        'position',[hobjpos(1) vobjpos(5) textW vobjdim],...
        'string','5)',...
        'Fontweight','bold',...
        'FontSize',11);
    uicontrol(toolsParent,...
        'style','pushbutton',...
        'BackgroundColor',[0.8 0.9 1],...
        'position',[hobjpos(1)+textW+textGap vobjpos(5) hobjdim-textW-textGap vobjdim],...
        'string','Train Network',...
        'callback',@trainTransferLearningNetwork);
    uicontrol(toolsParent,...
        'style','text',...
        'BackgroundColor',get(toolsParent,'BackgroundColor'),...
        'position',[hobjpos(1) vobjpos(6) textW vobjdim],...
        'string','6)',...
        'Fontweight','bold',...
        'FontSize',11);
    uicontrol(toolsParent,...
        'style','pushbutton',...
        'BackgroundColor',[0.8 0.9 1],...
        'position',[hobjpos(1)+textW+textGap vobjpos(6) hobjdim-textW-textGap vobjdim],...
        'string','Save Network',...
        'callback',@trainTransferLearningNetwork);
    % From-Scratch Workflow
    uicontrol(toolsParent,...
        'style','text',...
        'BackgroundColor',get(toolsParent,'BackgroundColor'),...
        'position',[hobjpos(2) 0.875 hobjdim 0.1],...
        'string',{'FROM-SCRATCH';'WORKFLOW'},...
        'Fontweight','bold',...
        'FontSize',9.5);
    uicontrol(toolsParent,...
        'style','text',...
        'BackgroundColor',get(toolsParent,'BackgroundColor'),...
        'position',[hobjpos(2) vobjpos(1) textW vobjdim],...
        'string','1)',...
        'Fontweight','bold',...
        'FontSize',11);
    uicontrol(toolsParent,...
        'style','pushbutton',...
        'BackgroundColor',[0.8 0.9 1],...
        'position',[hobjpos(2)+textW+textGap vobjpos(1) hobjdim-textW-textGap vobjdim],...
        'string','Select Training Data Directory',...
        'callback',@selectTrainingDir);
    uicontrol(toolsParent,...
        'style','text',...
        'BackgroundColor',get(toolsParent,'BackgroundColor'),...
        'position',[hobjpos(2) vobjpos(2) textW vobjdim],...
        'string','2)',...
        'Fontweight','bold',...
        'FontSize',11);
    uicontrol(toolsParent,...
        'style','pushbutton',...
        'BackgroundColor',[0.8 0.9 1],...
        'Enable','on',...
        'position',[hobjpos(2)+textW+textGap vobjpos(2) hobjdim-textW-textGap vobjdim],...
        'string','Validate Labels',...
        'callback','');
    uicontrol(toolsParent,...
        'style','text',...
        'BackgroundColor',get(toolsParent,'BackgroundColor'),...
        'position',[hobjpos(2) vobjpos(3) textW vobjdim],...
        'string','3)',...
        'Fontweight','bold',...
        'FontSize',11);
    uicontrol(toolsParent,...
        'style','pushbutton',...
        'BackgroundColor',[0.8 0.9 1],...
        'Enable','off',...
        'position',[hobjpos(2)+textW+textGap vobjpos(3) hobjdim-textW-textGap vobjdim],...
        'string','Load/Define NN Architecture',...
        'callback','');
    uicontrol(toolsParent,...
        'style','text',...
        'BackgroundColor',get(toolsParent,'BackgroundColor'),...
        'position',[hobjpos(2) vobjpos(4) textW vobjdim],...
        'string','4)',...
        'Fontweight','bold',...
        'FontSize',11);
    uicontrol(toolsParent,...
        'style','pushbutton',...
        'BackgroundColor',[0.8 0.9 1],...
        'Enable','off',...
        'position',[hobjpos(2)+textW+textGap vobjpos(4) hobjdim-textW-textGap vobjdim],...
        'string','Specify Training Options',...
        'callback',@specifyTrainingOptions);
    uicontrol(toolsParent,...
        'style','text',...
        'BackgroundColor',get(toolsParent,'BackgroundColor'),...
        'position',[hobjpos(2) vobjpos(5) textW vobjdim],...
        'string','5)',...
        'Fontweight','bold',...
        'FontSize',11);
    uicontrol(toolsParent,...
        'style','pushbutton',...
        'BackgroundColor',[0.8 0.9 1],...
        'Enable','off',...
        'position',[hobjpos(2)+textW+textGap vobjpos(5) hobjdim-textW-textGap vobjdim],...
        'string','Train Network',...
        'callback',@trainTransferLearningNetwork);
    uicontrol(toolsParent,...
        'style','text',...
        'BackgroundColor',get(toolsParent,'BackgroundColor'),...
        'position',[hobjpos(2) vobjpos(6) textW vobjdim],...
        'string','6)',...
        'Fontweight','bold',...
        'FontSize',11);
    uicontrol(toolsParent,...
        'style','pushbutton',...
        'BackgroundColor',[0.8 0.9 1],...
        'Enable','off',...
        'position',[hobjpos(2)+textW+textGap vobjpos(6) hobjdim-textW-textGap vobjdim],...
        'string','Save Network',...
        'callback',@trainTransferLearningNetwork);
    % Semantic Segmentation Workflow
    uicontrol(toolsParent,...
        'style','text',...
        'BackgroundColor',get(toolsParent,'BackgroundColor'),...
        'position',[hobjpos(3) 0.875 hobjdim 0.1],...
        'string',{'SEMANTIC SEGMENTATION';'WORKFLOW'},...
        'Fontweight','bold',...
        'FontSize',9.5);
    % Inference
    uicontrol(toolsParent,...
        'style','text',...
        'BackgroundColor',get(toolsParent,'BackgroundColor'),...
        'position',[hobjpos(4) 0.875 hobjdim 0.1],...
        'string','INFERENCE',...
        'Fontweight','bold',...
        'FontSize',9.5);
    uicontrol(toolsParent,...
        'style','text',...
        'BackgroundColor',get(toolsParent,'BackgroundColor'),...
        'position',[hobjpos(4) vobjpos(1) textW vobjdim],...
        'string','1)',...
        'Fontweight','bold',...
        'FontSize',11);
    uicontrol(toolsParent,...
        'style','pushbutton',...
        'BackgroundColor',[0.8 0.9 1],...
        'position',[hobjpos(4)+textW+textGap vobjpos(1) hobjdim-textW-textGap vobjdim],...
        'string','Select Trained Network',...
        'callback',@selectTrainedNet);
    uicontrol(toolsParent,...
        'style','text',...
        'BackgroundColor',get(toolsParent,'BackgroundColor'),...
        'position',[hobjpos(4) vobjpos(2) textW vobjdim],...
        'string','2)',...
        'Fontweight','bold',...
        'FontSize',11);
    uicontrol(toolsParent,...
        'style','pushbutton',...
        'BackgroundColor',[0.8 0.9 1],...
        'position',[hobjpos(4)+textW+textGap vobjpos(2) hobjdim-textW-textGap vobjdim],...
        'string','Evaluate Test Set',...
        'callback',@testTrainedNetwork);
    uicontrol(toolsParent,...
        'style','text',...
        'BackgroundColor',get(toolsParent,'BackgroundColor'),...
        'position',[hobjpos(4) vobjpos(3) textW vobjdim],...
        'string','3)',...
        'Fontweight','bold',...
        'FontSize',11);
    uicontrol(toolsParent,...
        'style','pushbutton',...
        'BackgroundColor',[0.8 0.9 1],...
        'tooltipstring','Click on the center of the block you want to classify...',...
        'position',[hobjpos(4)+textW+textGap vobjpos(3) hobjdim-textW-textGap vobjdim],...
        'string','Classify Selected Block',...
        'callback',@classifySelectedBlock);
    uicontrol(toolsParent,...
        'style','text',...
        'BackgroundColor',get(toolsParent,'BackgroundColor'),...
        'position',[hobjpos(4) vobjpos(4) textW vobjdim],...
        'string','4)',...
        'Fontweight','bold',...
        'FontSize',11);
    uicontrol(toolsParent,...
        'style','pushbutton',...
        'BackgroundColor',[0.8 0.9 1],...
        'Enable','off',...
        'position',[hobjpos(4)+textW+textGap vobjpos(4) hobjdim-textW-textGap vobjdim],...
        'string','Classify All Blocks',...
        'callback',@testTrainedNetwork);
    uicontrol(toolsParent,...
        'style','text',...
        'BackgroundColor',get(toolsParent,'BackgroundColor'),...
        'position',[hobjpos(4) vobjpos(5) textW vobjdim],...
        'string','5)',...
        'Fontweight','bold',...
        'FontSize',11);
    uicontrol(toolsParent,...
        'style','pushbutton',...
        'BackgroundColor',[0.8 0.9 1],...
        'Enable','off',...
        'position',[hobjpos(4)+textW+textGap vobjpos(5) hobjdim-textW-textGap vobjdim],...
        'string','Select Block(s) by Label',...
        'callback',@testTrainedNetwork);
    uicontrol(toolsParent,...
        'style','text',...
        'BackgroundColor',get(toolsParent,'BackgroundColor'),...
        'position',[hobjpos(4) vobjpos(6) textW vobjdim],...
        'string','6)',...
        'Fontweight','bold',...
        'FontSize',11);
    uicontrol(toolsParent,...
        'style','pushbutton',...
        'BackgroundColor',[0.8 0.9 1],...
        'position',[hobjpos(4)+textW+textGap vobjpos(6) hobjdim-textW-textGap vobjdim],...
        'string','Recall/Display Labels',...
        'callback',@importDisplayLabels);
end %if includeLearningTools

% useParallelCkbox = uicontrol(autosegPanel,...
% 	'style','checkbox',...
% 	'tooltipstring',tts,...
% 	'position',[hpos(2) 0.1 hdim 0.075],...
% 	'Enable','off',...
% 	'value',1,...
% 	'string','Use Parallel if Available');

layoutChangeButton = uicontrol(labelBigImageHndl,...
    'position',[0.01 0.005 0.015 0.025],...
    'TooltipString','Change Layout',...
    'String','­¯',...
    'fontsize',9,...
    'Fontname','Symbol',...
    'fontweight','bold',...
    'UserData',nLayouts,...
    'BackgroundColor',[0.8 0.9 1],...
    'callback',@cycleLayout);
updateAxesTicks;
% Set up default configuration
cycleLayout(layoutChangeButton); %Default Layout
allUIC = findall(labelBigImageHndl,'type','uicontrol');

% Display overview image, referenced to coordinates of subImage axes
overviewImageHandle = imshow(overviewImage,imrefOverview,'parent',overviewImageAx);
%set(overviewImageAx,'XTick',[],'YTick',[]);
set(overviewImageAx,'XLim',imrefOverview.XWorldLimits,...
    'YLim',imrefOverview.YWorldLimits);

% Clicking on the overview image will move the requestedPosition:
overviewImageHandle.ButtonDownFcn = @imageClicked;
%
initPct = min(BILPrefs.initialDisplayAndProcessDimension./[imgH,imgW]);
requestedPosition = round([imgW*(1-initPct)/2 imgH*(1-initPct)/2 imgW*initPct imgH*initPct]);
constructOverviewRegionSelector;
[XSubRange,YSubRange,returnedPosition,subImageTiles] = getDisplayParameters(requestedPosition);
subImage = retrieveSubImage(subImageTiles);
displaySubImage(returnedPosition,subImage,XSubRange,YSubRange)
uicontrol(labelBigImageHndl,...
    'style','text',...
    'fontweight','bold',...
    'string','Number of ROIs:',...
    'units','normalized',...
    'position',[0.25 0.005 0.1 0.025]);
nROIsEdit = uicontrol(labelBigImageHndl,...
    'style','edit',...
    'fontweight','bold',...
    'string',0,...
    'enable','inactive',...
    'units','normalized',...
    'position',[0.35 0.01 0.0375 0.025]);

%
tfa = timerfindall('tag','labelBigImageAutoSave');
if ~isempty(tfa)
    stop(tfa);
    delete(tfa);
end
toggleAutoSave(toggleAutoSaveCkBox);
BILImageToolbar(labelBigImageHndl,subImageAx,pageInfo);
drawnow;
%
if ~isempty(previousSessionROIs)
    %allSynROIs = previousSessionROIs;
    allSynROIs = cell(numel(previousSessionROIs),1);
    for iii = 1:numel(previousSessionROIs)
        waitbar(iii/numel(previousSessionROIs))
        thisPos = previousSessionROIs(iii).positions;
        if numel(thisPos) == 4
            tmp = imrect(overviewImageAx,thisPos);
            synROI = constructRectSynROI(tmp,...
                previousSessionROIs(iii).label,...
                previousSessionROIs(iii).score);
        else
            tmp = imfreehand(overviewImageAx,thisPos); %#ok<*IMFREEH>
            synROI = constructFreehandSynROI(tmp,...
                previousSessionROIs(iii).label,...
                previousSessionROIs(iii).score);
        end
        fieldNamesToCapture = {'lineColor','lineStyle','lineWidth','userData',...
            'score','validated'};
        for jjjj = 1:numel(fieldNamesToCapture)
            thisFieldName = fieldNamesToCapture{jjjj};
            if isfield(previousSessionROIs(iii),thisFieldName) &&...
                    ~isempty(previousSessionROIs(iii).(thisFieldName))
                try %#ok<TRYNC>
                    thisFieldValue = previousSessionROIs(iii).(thisFieldName);
                    synROI.(thisFieldName) = thisFieldValue;
                end
            end
        end
        
        %         synROI.lineColor = previousSessionROIs(iii).lineColor;
        %         synROI.lineStyle = previousSessionROIs(iii).lineStyle;
        %         synROI.lineWidth = previousSessionROIs(iii).lineWidth;
        %         synROI.userData = previousSessionROIs(iii).userData;
        togglePositionLock(synROI)
        isSaved = false;
        allSynROIs{iii} = synROI;
        %synROI.isLocked = true;
    end
    gotoSynROI(allSynROIs{1});
end

% THESE ARE NOT READY FOR PRIME TIME:
set(predictVerifyButton,'enable','off'); % ... clickSegmentRadio,maxOverlapEdit,    predictVerifyButton    grayconRadio,...
%%%
figure(labelBigImageHndl)% Toggles 'visible' to 'on', makes it current;

ss = get(0,'screensize');
if ss(4) < 1000
    fontShiftAmt = 1;
    for ll = 1:numel(allUIC)
        try %#ok<TRYNC>
            set(allUIC(ll),'FontSize',get(allUIC(ll),'FontSize')-fontShiftAmt);
        end
    end
    allUIP = findall(hPanel,'type','uicontrol');
    for ll = 1:numel(allUIP)
        set(allUIP(ll),'FontSize',get(allUIP(ll),'FontSize')+fontShiftAmt);
    end
end

if BILPrefs.showSplash
    beep
    tmpfig = contactBrett;
    waitfor(tmpfig);
end

%

% BEGIN NESTED SUBFUNCTIONS
% (Listed alphabetically for convenience)

    function addToOrUpdateListbox(thisSynROI)
        % Labels are managed in:
        % C:\MFILES\imroiStuff\@synchronizedROI\addSynchronizedLabels.m
        if isa(thisSynROI,'struct')
            %{'create','delete','copy','newLabel'}
            Interaction = thisSynROI.Interaction;
            thisSynROI = thisSynROI.Source;
        end
        currString = listboxOfSynchronizedROIs.String;
        thisLabel = thisSynROI.label;
        %if ~ismember(thisLabel,...
        if ~contains(thisLabel,...
                {defaultAutoSegLabel,defaultManualSegLabel,defaultThisSubimageAutoSegLabel})
            if ~ismember(thisLabel,currentSessionLabels)
                currentSessionLabels = [defaultAutoSegLabel;...
                    sort([thisLabel;setdiff(currentSessionLabels,...
                    {defaultAutoSegLabel,defaultManualSegLabel,...
                    defaultThisSubimageAutoSegLabel})])];
                lockedOrderLabels = [lockedOrderLabels;thisLabel];
                save(labelDir,'currentSessionLabels')
            end
        end
        thisUniqueID = thisSynROI.uniqueIdentifier;
        thisString = makeListboxEntry([thisLabel ' ' num2str(thisUniqueID)]);
        switch Interaction
            case {'create','copy','newLabel'}
                if isempty(currString)
                    listboxOfSynchronizedROIs.String = thisString;
                else
                    ind = [];
                    for ii = 1:size(currString,1)
                        tmp = strsplit(currString(ii,:));
                        if str2double(tmp{2})==thisUniqueID
                            ind = ii;
                            break
                        end
                    end
                    if isempty(ind)
                        ind = ii + 1;
                    end
                    thisString = makeListboxEntry([thisLabel ' ' num2str(thisUniqueID)]);
                    currString(ind,:) = thisString;
                    listboxOfSynchronizedROIs.String = currString;
                    listboxOfSynchronizedROIs.Value = ind;
                end
                if strcmp(Interaction,'copy')
                    uniqueID = uniqueID + 1;
                    showButtonVisibility(showLabelsCheckbox);
                end
            case 'delete'
                removeFromListbox(thisUniqueID)
        end
        %set(nROIsEdit,'string',size(listboxOfSynchronizedROIs.String,1));
    end %addToOrUpdateListbox
%
    function addUpdateTitles(varargin)
        [~,str1] = fileparts(imageName);
        str1 = sprintf('SubImage from: %s;',strrep(str1,'_','\_'));
        subImageTitle = ...
            title({sprintf('%s',str1), ...
            '\color{red}\fontsize{9}LEFT-Click: \color{blue}Define new ROI. \color{red}RIGHT-Click: \color{blue}Auto-Segment.'},...
            'parent',subImageAx,'FontSize', 10);
        updateAxesTicks;
        str1 = sprintf('Overview Region: [%0.0f %0.0f %0.0f %0.0f]',...
            returnedPosition(1),returnedPosition(2),returnedPosition(3),returnedPosition(4));
        overviewImageTitle = ...
            title({sprintf('%s',str1), ...
            '\color{red}\fontsize{9}LEFT-Click: \color{blue}Move box; \color{red}DRAG: \color{blue}Reposition/Resize; \color{red}RIGHT-click: \color{blue}New ROI.'},...
            'Parent',overviewImageAx,'FontSize', 10);
    end %addUpdateTitles

    function autoSegment(option,obj,varargin)%(obj,varargin)
        score = 0.333; %Default if no information
        if nargin > 1
            set(segOptRadio,'value',0);
            set(obj,'value',1);
        end
        cancelRequest = strcmp(segSelectedButton.String,'Cancel');
        save(fullfile(BILPrefs.utilitiesDir,'cancelRequest.mat'),...
            'cancelRequest','cancelRequest')
        drawnow
        axisSelected = find([whichAxButton.Value]);
        %allTitles = [subImageTitle overviewImageTitle];
        if axisSelected == 1
            %%This triggers a refresh, including colorspaceConversion:
            %moveRegion(overviewRegionSelector)
            parentAx = subImageAx;
            segmentRequestSummary.selectedImage = 'SubImage';
            thisImage = getimage(subImageAx);
            thisTitle = subImageTitle;
            %subregionProcessTime = 0;
            tic;
        elseif axisSelected == 2
            parentAx = overviewImageAx;
            segmentRequestSummary.selectedImage = 'Overview';
            thisImage = getimage(overviewImageAx);
            thisTitle = overviewImageTitle;
        else
            error('Unrecognized segmentation request.');
        end
        % If alt-clicked, operate in the clicked axes!
        % 		isAltClick = nargin > 1 && ischar(varargin{1}) && strcmp(varargin{1},'ALT-CLICK');
        thisOpt = segOptRadio(logical([segOptRadio.Value])).String;
        if thisOpt(end)==':'
            thisOpt = thisOpt(1:end-1);
        end
        segmentRequestSummary.segmentType = thisOpt;
        autosegOptions = {'Imextended','Threshold','Custom'};
        isAutoseg = ismember(thisOpt,autosegOptions);
        segmentRequestSummary.isAutoSegmentation = isAutoseg; %#ok<STRNU>
        processImmediately = get(processImmediatelyCkbox,'Value')==1 && isAutoseg;
        processNow = strcmp(option,'processNow') || processImmediately; %|| isAltClick;
        if ~processNow && ~strcmp(thisOpt,'Gray Connectivity')
            return
        end
        if strcmp(option,'uiAction')
            clearSynROIsNamed({defaultThisSubimageAutoSegLabel})
        end
        sensitivityThreshold = sensitivitySlider.Value;
        minSize = minSizeSlider.Value;
        maxSize = maxSizeSlider.Value;
        maxAreaPct = str2double(maxAreaPercent.String);
        %         if parentAx == overviewImageAx
        %             maxAreaPct = maxAreaPct / imrefOverview.PixelExtentInWorldX / imrefOverview.PixelExtentInWorldY;
        %         end
        %         if minSize < 5000
        %             continueVal = questdlg('minSize is quite small...this could result in many false-positive regions and could take a while. Are you sure you want to continue with this analysis?','Are you sure???','YES, Continue','Cancel','YES, Continue');
        %             if ~strcmp(continueVal,'YES, Continue')
        %                 return
        %             end
        %         end
        segSelectedButton.String = 'Cancel';
        segSelectedButton.ForegroundColor = 'r';
        labelBigImageHndl.Pointer = 'watch';
        simplifyAmount = get(simplifyAmountSlider,'value');
        drawnow;
        if size(thisImage,3) ~= 1
            gray = rgb2gray(thisImage);
        else
            gray = thisImage;
        end
        switch thisOpt
            case 'Imextended'
                findDark = imextendedDirection.Value == 1;
                if findDark
                    mask = imextendedmin(im2double(gray),...
                        sensitivityThreshold,8);
                else
                    mask = imextendedmax(im2double(gray),...
                        sensitivityThreshold,8);
                end
                score = 0.5; %Default for imextended segmentations
            case 'Threshold'
                sensitivityThreshold = imcomplement(sensitivityThreshold);
                findDark = thresholdPolarity.Value == 1;
                if findDark
                    mask = imbinarize(imcomplement(gray),sensitivityThreshold);
                else
                    mask = imbinarize(gray,sensitivityThreshold);
                end
                score = 0.7; %Default for threshold % NOTE: IMPROVE THIS!!
            case 'Custom'
                customString = customFcnEditBox.String;
                hasAt = contains(customString,'@');
                % Deblank:
                %customString(customString == 32) = [];
                if ~hasAt
                    warndlg(sprintf('FIRST: Please put a valid function handle in the edit box below.\n\nFor example:\n\n\t@(img)customFcn(img)\n\n'))
                    segSelectedButton.String = 'Segment Selected';
                    segSelectedButton.ForegroundColor = 'k';
                    labelBigImageHndl.Pointer = 'arrow';
                    drawnow;
                    return
                end
                fcnHandle = str2func(customFcnEditBox.String);
                % Parse for syntax:
                inArgs = regexp(customString,'\w*','match');
                addlArgs = inArgs(1:floor(numel(inArgs)/2));
                fcnArg = inArgs{ceil(numel(inArgs)/2)};
                if ~exist(fcnArg,'file')
                    temporaryDialog('Specified function was not found on the path!',3)
                    labelBigImageHndl.Pointer = 'arrow';
                    drawnow;
                    return
                end
                % NOTE: If 'mask' is returned by a custom function handle,
                % it should be a STRUCT that contains the bounding boxes
                % ('boxes'), labels ('labels'), and scores ('scores') of
                % any detections. It will be parsed by the subfunction:
                mask = fcnHandle(thisImage,addlArgs{2:end});
                score = 0.8; %Default for custom
            case 'Gray Connectivity'
                currTitleString = get(thisTitle,'String');
                currTitleFontSize = get(thisTitle,'FontSize');
                set(thisTitle,...
                    'String','CLICK to select the region you want to capture',...
                    'FontSize',13);
                reqPos = ginput(1);
                if parentAx == subImageAx
                    [column,row] = worldToIntrinsic(imrefSubImageToOverview,...
                        reqPos(1),reqPos(2));
                else %overview
                    [column,row] = worldToIntrinsic(imrefOverview,...
                        reqPos(1),reqPos(2));
                end
                row = round(row);
                column = round(column);
                if any([row < 0, row > size(gray,1), column < 0, column > size(gray,2)])
                    temporaryDialog('Invalid selection!')
                    labelBigImageHndl.Pointer = 'arrow';
                    drawnow;
                    return
                end
                set(thisTitle,...
                    'String',currTitleString,...
                    'FontSize',currTitleFontSize);
                drawnow
                % Gray Connectivity
                % tolerance adjusted to 32 for uint8 images, based on
                % default value of 0.6 for sensitivitySlider.
                % 0.6-(32/255);
                tolerance = (sensitivityThreshold-0.475)*intmax(class(gray));
                mask = grayconnected(gray, row, column, tolerance);
                score = 0.4; %Default for grayconnected
        end
        %         if parentAx == overviewImageAx
        %             mask = bwareaopen(mask,round(minSize/mean([imrefOverview.PixelExtentInWorldX,imrefOverview.PixelExtentInWorldY])));
        %         else
        %             mask = bwareaopen(mask,minSize);
        %         end
        if isa(mask,'struct')
            % Non-Image return; treat specially
            labelBigImageHndl.Pointer = 'arrow';
            parseDetectorOutputStruct(mask);
            return
        end
        SE  = strel('Disk',7,4);
        if minSize > 100
            % For small regions, imclose will overwhelm the detections
            mask = imclose(mask, SE);
        else
            temporaryDialog('For minSize <= 100, morphological closing is suppressed. This may give unexpected results! If this is a problem, please contact Brett: bshoelso@mathworks.com.',5);
        end
        if simplifyAmount ~= 0
            SE  = strel('Disk',round(simplifyAmount*50),4);
            mask = imopen(mask, SE);
        end
        %
        if parentAx == overviewImageAx
            %mask = bwareaopen(mask,minSize);
            minS = round(minSize/mean([imrefOverview.PixelExtentInWorldX,imrefOverview.PixelExtentInWorldY]));
            maxS = round(maxSize/mean([imrefOverview.PixelExtentInWorldX,imrefOverview.PixelExtentInWorldY]));
            %mask = bwareaopen(mask,round(minSize/mean([imrefOverview.PixelExtentInWorldX,imrefOverview.PixelExtentInWorldY])));
            maxS = max(maxS,minS);
            mask = bwpropfilt(mask, 'Area', [minS, maxS]);
        else
            maxSize = max(minSize,maxSize);
            mask = bwpropfilt(mask, 'Area', [minSize, maxSize]);
            %mask = bwareaopen(mask,minSize);
        end
        if nnz(mask)==0
            temporaryDialog('No regions captured with these settings! (nnz(mask) == 0)',3)
            segSelectedButton.String = 'Segment Selected';
            segSelectedButton.ForegroundColor = 'k';
            labelBigImageHndl.Pointer = 'arrow';
            drawnow;
            return
        elseif nnz(mask) > maxAreaPct*numel(mask)
            segSelectedButton.String = 'Segment Selected';
            segSelectedButton.ForegroundColor = 'k';
            temporaryDialog('No regions captured with these settings! (Area Pct exceeded)',3)
            labelBigImageHndl.Pointer = 'arrow';
            drawnow;
            return
        end
        %synchronizedFreehandROIsFromMask(mask,parentAx,offset,label,warnoff,score)
        synchronizedFreehandROIsFromMask(mask,parentAx,[],...
            defaultThisSubimageAutoSegLabel,false,score)
        %         if parentAx == subImageAx
        %             subregionProcessTime = toc;
        %         end
        segSelectedButton.String = 'Segment Selected';
        segSelectedButton.ForegroundColor = 'k';
        labelBigImageHndl.Pointer = 'arrow';
        drawnow;
        %disp(segmentRequestSummary)
        %uistack(overviewRegionSelector,'top');
    end %autoSegment

    function autoTrain(varargin)
        option = varargin{1}.Text;
        disp(option)
        switch option
            case 'Fast Image Classifier'
            case 'ACF Object Detector'
            case 'RCNN'
            case 'YOLO v2'
            otherwise
                error('How did I end up here?')
        end
    end %autoTrain

    function changeLabelPosition(obj,varargin)
        selection = obj{1}.Text;
        set(labelPref,'checked','off');
        set(labelPref(strcmp(selection,{'Top','Center','Bottom'})),'checked','on')
        BILPrefs.labelPosition = selection;
        %Findall synROI, set(labelPositionPref)
        sROIs = findSynchronizedROIs(overviewImageAx,...
            'type',{'synchronizedImfreehands','synchronizedImrects'});
        for ii = 1:numel(sROIs)
            thisSynROI = sROIs{ii};
            thisSynROI.labelPositionPreference = selection;
        end
    end %changeLabelPosition

    function changePixOrMicrons(obj,varargin)
        % NOTE: For an example of a big Tiff image that contains MPP
        % information, use: 'CRC_Ki67_sample.svs'
        set(pixOrMM,'value',0);
        set(obj,'value',1);
        if strcmp(obj.String,'Pixels')
            set(chipHEdit,'String',100)
            set(chipWEdit,'String',100);
        else
            set(chipHEdit,'String',currMPP*100)
            set(chipWEdit,'String',currMPP*100);
        end
    end %changePixOrMicrons

    function changePolarity(obj,varargin)
        set(segOptRadio,'value',0);
        thisTag = obj.Tag;
        switch(thisTag)
            case 'Threshold'
                segOptRadio(1).Value = 1;
            case 'Imextended'
                segOptRadio(2).Value = 1;
        end
        autoSegment('uiAction')
    end %changePolarity

    function changeProcessRegionsOpt(obj,varargin)
        selection = obj{1}.Text;
        set(processRegionsOpt,'checked','off');
        set(processRegionsOpt(strcmp(selection,{'ANY: Tiles with Any ROI Overlap','ALL: Tiles Entirely Within Region'})),'checked','on')
        BILPrefs.processRegionsOption = selection;
    end %changeProcessRegionsOpt

    function changeSegmentAx(obj,varargin)
        set(whichAxButton,'value',0);
        set(obj,'value',1);
    end %changeSegmentAx

    function classifySelectedBlock(varargin)
        %%%BDS: Why is HOLOGIC stuff in here? What is this function?
        if isempty(trainedNetwork)
            temporaryDlg('Please select a trained Network first!')
            return
        end
        SIBDF = get(subImageAx,'ButtonDownFcn');
        OVBDF = get(overviewImageAx,'ButtonDownFcn');
        subImageAx.ButtonDownFcn = [];
        overviewImageAx.ButtonDownFcn = [];
        temporaryDialog('DOUBLE-CLICK (on either axes) in the center of the region you want to classify ...')
        h = impoint; %#ok<*IMPNT>
        wait(h)
        clickedPoint = h.getPosition;
        delete(h)
        subImageAx.ButtonDownFcn = SIBDF;
        overviewImageAx.ButtonDownFcn = OVBDF;
        targetSize = trainedNetwork.Layers(1).InputSize;
        
        requestedPosition = [round(clickedPoint(1)-targetSize(1)/2),...
            round(clickedPoint(2)-targetSize(2)/2),...
            targetSize(1) targetSize(2)];
        [XSubRange,YSubRange,returnedPosition,subImageTiles] = getDisplayParameters(requestedPosition);
        drawnow
        subImage = retrieveSubImage(subImageTiles);
        % If a colorspace conversion was requested:
        subImage = convertImage(subImage);
        ClassNames =  categorical({'HSIL'  'LSIL'  'non-cell'  'normal_cells'});
        recodeFcn = @(X,Y) uint8(round(sum(bsxfun(@times,X==Y,1:numel(Y)),2)/numel(Y)*255));
        %displaySubImage(returnedPosition,subImage,XSubRange,YSubRange)
        tfig = togglefig('SubImage Classification');
        set(tfig,'windowstyle','normal')
        figure(labelBigImageHndl)
        figure(tfig)
        [~,scores,YPred] = InferHologic(trainedNetwork,subImage,ClassNames,recodeFcn);
        imshow(subImage)
        title(sprintf('Best Guess: %s; Confidence: %0.3f',YPred,max(scores)),...
            'Interpreter','none')
    end %classifySelectedBlock

    function clearSynROIsNamed(label,warnMe,varargin)
        if nargin < 1
            label = defaultAutoSegLabel;
        end
        if nargin < 2
            warnMe = false;
        end
        offendingROIs = [];
        for ii = 1:numel(label)
            thisLabel = label{ii};
            %             offendingROIs = cat(2,offendingROIs,...
            %                 findSynchronizedROIs(overviewImageAx,...
            %                 {'synchronizedImfreehands','synchronizedImrects'},thisLabel,[],false));
            sROIs = findSynchronizedROIs(overviewImageAx,...
                'type',{'synchronizedImfreehands','synchronizedImrects'},...
                'queryFields', {'label'},...
                'queryValues', {thisLabel});
            if ~isempty(sROIs)
                offendingROIs = cat(2,offendingROIs, sROIs);
            end
        end
        if isempty(offendingROIs)
            return
        end
        tmp = 'Yes';
        if warnMe
            beep
            tmp = questdlg(sprintf('There are %i unnamed (or auto-named) ROIs. Do you want to delete them?',numel(offendingROIs)),...
                'Unnamed ROIs','NO','Yes','NO');
        end
        if strcmp(tmp,'Yes')
            for ii = 1:numel(offendingROIs)
                offendingROIs{ii}.deleteROISet;
                removeFromListbox(offendingROIs{ii}.uniqueIdentifier);
            end
        end
        isSaved = false;
    end %clearSynROIsNamed

    function closeAndSuppress(varargin)
        suppress = get(findobj(gcf,'tag','SuppressMessage'),'value');
        if suppress
            BILPrefs.showSplash = false;
            save(fullfile(BILPrefs.BILDir,'labelBigImagePrefs.mat'),'BILPrefs');
        end
        closereq;
    end

    function closeLabeler(varargin)
        if ~isSaved
            tmp = questdlg('Your session has not been saved.',...
                'SAVE FIRST???',...
                'SAVE','Close without Saving','Cancel','SAVE');
            if strcmp(tmp,'Cancel')
                return
            elseif strcmp(tmp,'SAVE')
                saveSession
            end
        end
        tfa = timerfindall('tag','labelBigImageAutoSave');
        if ~isempty(tfa)
            stop(tfa);
            delete(tfa);
        end
        close(tiffImageClass)
        % Save 'config' variables:
        sensitivityThreshold = sensitivitySlider.Value;
        minSize = minSizeSlider.Value;
        maxSize = maxSizeSlider.Value;
        simplifyAmount = get(simplifyAmountSlider,'value');
        if drawFreehandButton.Value == 1
            BILPrefs.drawType = 'freehand';
        else
            BILPrefs.drawType = 'rect';
        end
        tmpPos = overviewRegionSelector.getPosition;
        BILPrefs.initialDisplayAndProcessDimension = max(1000,min(tmpPos(3:4)));
        BILPrefs.minSize = minSize;
        BILPrefs.maxSize = maxSize;
        BILPrefs.sensitivity = sensitivityThreshold;
        BILPrefs.simplifyAmount = simplifyAmount;
        % Update multiSessionLabels.mat to capture this-session labels:
        multiSessionLabels = load(BILPrefs.multiSessionLabelList);
        multiSessionLabels = multiSessionLabels.currentSessionLabels;
        currentSessionLabels = [defaultAutoSegLabel;...
            sort(setdiff([multiSessionLabels; currentSessionLabels],...
            {defaultAutoSegLabel,defaultManualSegLabel,defaultThisSubimageAutoSegLabel}))];
        save(fullfile(BILPrefs.utilitiesDir,'multiSessionLabels.mat'),'currentSessionLabels')
        %
        save(fullfile(BILPrefs.BILDir,'labelBigImagePrefs.mat'),...
            'BILPrefs');
        closereq;
    end %closeLabeler

    function constructOverviewRegionSelector(varargin)
        overviewRegionSelector = imrect(overviewImageAx,...
            requestedPosition); %#ok<*IMRECT>
        set(overviewRegionSelector,'tag','overviewRegionSelector')
        addImroiButtonUpCallback(overviewRegionSelector,...
            @moveRegion,true); %true: triggerOnlyOnNewPosition
        overviewRegionSelector.Deletable = false;
        constrainToRectFcn = makeConstrainToRectFcn('imrect',...
            get(overviewImageAx,'XLim'),get(overviewImageAx,'YLim'));
        setPositionConstraintFcn(overviewRegionSelector,@customConstraintFcn);
        facePatch = getPatchFromImroi(overviewRegionSelector);
        set(facePatch,'FaceColor','c',...
            'FaceAlpha',0.3,...
            'tag','overviewRegionSelector')
        
        function posOut = customConstraintFcn(newPos)
            posOut = constrainToRectFcn(newPos);
            if any([posOut(3) > maxDisplayDimension, posOut(4) > maxDisplayDimension])
                if notifyOfMaxDimension
                    %beep
                    fprintf('\n\nThe region you requested is too big!\n\nThe ''maxDisplayDimension'' is set to %i;\nyou may edit labelBigImage to increase it if you wish,\nbut performance may suffer if you permit too-large subImages.\n',maxDisplayDimension);
                    notifyOfMaxDimension = false;
                end
                posOut = [posOut(1:2) min(posOut(3),maxDisplayDimension) min(posOut(4),maxDisplayDimension)];
            end
            boxW = posOut(3);
            boxH = posOut(4);
            posOut(1) = max(0.5,posOut(1));
            posOut(1) = min(posOut(1),imgW-boxW+0.5);
            posOut(2) = min(posOut(2),imgH-boxH+0.5);
            posOut(2) = max(0.5,posOut(2));
        end %customConstraintFcn
    end %constructOverviewRegionSelector

    function synROI = constructFreehandSynROI(modelOrParentAx,label,score,labelColor)
        currentEnable = disableReenableUIs();
        if nargin < 2
            label = defaultAutoSegLabel;
        end
        if nargin < 3
            score = [];
        end
        if nargin < 4 || isempty(labelColor)
            labelColor = labelBackgroundColor;
        end
        uniqueID = getappdata(labelBigImageHndl,'nextUniqueIdentifier');
        %uniqueID = uniqueID + 1;
        setappdata(labelBigImageHndl,'nextUniqueIdentifier',uniqueID+1);
        synROI = synchronizedImfreehands(modelOrParentAx,'ROIParentHandles',...
            [overviewImageAx,subImageAx],...
            'referenceMode','absolute',...
            'autoLockWhenLabeled',true,...
            'uniqueIdentifier',uniqueID,...
            'label',label,...
            'backgroundColor',labelColor,...%labelBackgroundColor,...
            'labelPositionPreference',BILPrefs.labelPosition,...
            'defaultLabel',defaultAutoSegLabel,...
            'labelList',labelDir,...BILPrefs.multiSessionLabelList,...
            'allowUnlabeled',false,...
            'Callback',@(src,evnt)addToOrUpdateListbox(evnt));
        if ~isempty(score)
            synROI.score = score;
        else
            synROI.score = 0.333; %DEFAULT "Undefined Score" Value
        end
        if synROI.idxActiveROI ~= 0
            % Otherwise, request canceled!
            synROI.labelButtons(1).Visible = 'off';
            %         if nnz(synROI.ROI(2).createMask) < 20
            %             tmp = questdlg('This is a very small region. Did you mean to do that?',...
            %                 'Verify region','YES','No...Discard it!','YES');
            %             if strcmp(tmp,'No...Discard it!')
            %                 synROI.deleteROISet;
            %                 uniqueID = uniqueID - 1;
            %                 return
            %             end
            %         end
            %
            % Note: I still need this to listen to label changes:
            addlistener(synROI,'label',...
                'PostSet',@(src,evnt)synROI.refresh('newLabel'));
%             addlistener(synROI,'label',...
%                 'PostSet',@(src,evnt) setLineColor(synROI));
            addlistener(synROI,'label',...
                'PostSet',@(src,evnt) validateCurrentROI(synROI));
            synROI.refresh('create');
            synROI.lineWidth = 3;
            synROI.userData = displayParameters;
            showButtonVisibility(showLabelsCheckbox);
            
            if get(predictVerifyButton,'value')
                synROI.samplingOpts.indsOfROIsToSampleWhenMoved = 2;
                synROI.samplingOpts.verboseAnnotations(1:2) = [false;true];
                synROI.samplingOpts.includePiecewiseTortuosity = true;
                synROI.samplingOpts.boxH = [100 100];
                synROI.samplingOpts.boxW = [100 100];
                synROI.samplingOpts.verboseAnnotations = [false; true];
            end
            disableReenableUIs(currentEnable);
            isSaved = false;
        end
    end %constructFreehandSynROI

    function synROI = constructRectSynROI(modelOrParentAx,label,score,labelColor)
        if nargin < 3
            score = [];
        end
        if nargin < 4 || isempty(labelColor)
            labelColor = labelBackgroundColor;
        end
        currentEnable = disableReenableUIs();
        if nargin < 2
            label = defaultAutoSegLabel;
        end
        uniqueID = getappdata(labelBigImageHndl,'nextUniqueIdentifier');
        %uniqueID = uniqueID + 1;
        setappdata(labelBigImageHndl,'nextUniqueIdentifier',uniqueID+1);
        %thisLabelList = currentSessionLabels;
        synROI = synchronizedImrects(modelOrParentAx,'ROIParentHandles',...
            [overviewImageAx,subImageAx],...
            'referenceMode','absolute',...
            'autoLockWhenLabeled',true,...
            'backgroundColor',labelColor,...%labelBackgroundColor,...
            'uniqueIdentifier',uniqueID,...
            'label',label,...
            'labelPositionPreference',BILPrefs.labelPosition,...
            'defaultLabel',defaultAutoSegLabel,...
            'labelList',labelDir,...BILPrefs.multiSessionLabelList,...
            'allowUnlabeled',false,...
            'Callback',@(src,evnt)addToOrUpdateListbox(evnt));
        if ~isempty(score)
            synROI.score = score;
        else
            synROI.score = 0.333; %DEFAULT "Undefined Score" Value
        end
        
        if synROI.idxActiveROI ~= 0
            % Otherwise, request canceled!
            synROI.labelButtons(1).Visible = 'off';
            %
            % Note: I still need this to listen to label changes:
            addlistener(synROI,'label',...
                'PostSet',@(src,evnt)synROI.refresh('newLabel'));
%             addlistener(synROI,'label',...
%                 'PostSet',@(src,evnt) setLineColor(synROI));
            addlistener(synROI,'label',...
                'PostSet',@(src,evnt) validateCurrentROI(synROI));
            synROI.refresh('create');
            synROI.lineWidth = 2;
            synROI.userData = displayParameters;
            showButtonVisibility(showLabelsCheckbox);
            % The "wings" on the overview image are annoyingly large.
            % Let's fix that:
            overviewWingLines = findall(synROI.ROI(1),'tag','wing line');
            set(overviewWingLines,'visible','off')
            %
            if get(predictVerifyButton,'value')
                synROI.samplingOpts.indsOfROIsToSampleWhenMoved = 2;
                synROI.samplingOpts.verboseAnnotations(1:2) = [false;true];
                synROI.samplingOpts.includePiecewiseTortuosity = false;
                synROI.samplingOpts.boxH = [100 100];
                synROI.samplingOpts.boxW = [100 100];
                synROI.samplingOpts.verboseAnnotations = [false; true];
            end
            disableReenableUIs(currentEnable);
            isSaved = false;
        end
    end %constructRectSynROI

    function tmpfig = contactBrett
        tmpfig = figure('windowstyle','normal',...
            'units','normalized',...
            'position',[0.3 0.275 0.4 0.55],...
            'menubar','none',...
            'name','Please provide your feedback!');
        uicontrol(tmpfig,...
            'units','normalized',...
            'fontsize',24,...
            'foregroundcolor',[0.7 0 0],...
            'position',[0.025 0.8 0.95 0.175],...
            'style','text',...
            'string',{'Thank you for downloading and trying'; 'labelBigImage!'});
        msg = {
            'A great deal of effort has gone into building this tool, and we at MathWorks are committed to improving your big-image labeling experience. We hope you find this app useful, and that you will consider providing feedback on it. Let us know what you like about it, what you don''t like, what we could do better, and what enhancements that you would like to see implemented.';
            ' ';
            'Note that this app uses functionality from the Image Processing and Computer Vision Toolboxes, as well as any Toolboxes for whatever custom algorithms you build in. The Statistics and Machine Learning Toolbox may also be useful. It does not currently use the bigImage class, but we are working on incorporating that to make your labeling experience less painful!'; 
            ' ';
            'Thank you, and happy labeling!';
            ' ';
            'Brett';
            ' ';
            'bshoelso@mathworks.com';
            '(You can find my contact information by clicking on the MATLAB logo in the toolbar.)'};
        uicontrol(tmpfig,...
            'units','normalized',...
            'fontsize',12,...
            'horizontalalignment','left',...
            'position',[0.05 0.125 0.9 0.6],...
            'style','text',...
            'string',msg);
        uicontrol(tmpfig,...
            'units','normalized',...
            'fontsize',15,...
            'position',[0.05 0.025 0.4 0.1],...
            'style','pushbutton',...
            'foregroundcolor',[0 0.7 0],...
            'string','Got it!',...
            'callback',@(varargin)closeAndSuppress);
        uicontrol(tmpfig,...
            'units','normalized',...
            'fontsize',9,...
            'fontweight','bold',...
            'position',[0.65 0.025 0.3 0.1],...
            'tag','SuppressMessage',...
            'style','checkbox',...
            'fontangle','oblique',...
            'string','Don''t show this message again');
    end %contactBrett

    function I = convertImage(varargin)
        % Manage checkmarks:
        if isa(varargin{1},'matlab.ui.container.Menu')
            csConvertCVal = varargin{1,3};
            currval = varargin{1}.Checked;
            if strcmp(csConvertCVal,'Original')
                set(colorspaceConversionMenu,'checked','off');
                set(complementImageMenu,'checked','off')
                set(medfiltImageMenu,'checked','off')
            end
            if ~strcmp(csConvertCVal,'Complement') && ~strcmp(csConvertCVal,'Medfilt')
                set(colorspaceConversionMenu,'checked','off');
            end
            if strcmp(currval,'off')
                set(varargin{1},'checked','on')
            else
                set(varargin{1},'checked','off');
            end
            set(originalImageMenu,'checked','off');
            % Note that moveRegion will call convertImage with an image
            % argument!
            clearSynROIsNamed({defaultThisSubimageAutoSegLabel})
            moveRegion(overviewRegionSelector)
            return
        end
        % If you got here, the input was an image...
        I = varargin{1};
        if strcmp(get(complementImageMenu,'checked'),'on')
            I = imcomplement(I);
        end
        if strcmp(get(medfiltImageMenu,'checked'),'on')
            for ii = 1:size(I,3)
                I(:,:,ii) = medfilt2(I(:,:,ii),[9 9]);
            end
        end
        cspaceFcn = {@(I)rgb2gray(I),...
            @(I)rgb2hsv(I),...
            @(I)rgb2lab(I),...
            @(I)decorrstretch(I)};
        thisVal = strcmp(get(colorspaceConversionMenu,'checked'),'on');
        if nnz(thisVal) ~= 0
            cspaceFcn = cspaceFcn{thisVal};
            I = cspaceFcn(I);
        end
    end %convertImage

    function customizeBILPrefs
        groundTruthDir = fullfile(BILPrefs.groundTruthDir,thisFilename);
        fprintf('**********************\nGROUND TRUTH Directory for this image:\n%s\n*\n',groundTruthDir)
        if ~exist(groundTruthDir,'dir')
            mkdir(groundTruthDir)
        end
        imageChipDir = fullfile(BILPrefs.imageChipDir,thisFilename);
        fprintf('IMAGE-CHIP Directory for this image:\n%s\n*\n',imageChipDir)
        if ~exist(imageChipDir,'dir')
            mkdir(imageChipDir)
        end
        subimageDir = fullfile(BILPrefs.subimageDir,thisFilename);
        fprintf('SUBIMAGE Directory for this image:\n%s\n**********************\n',subimageDir)
        if ~exist(subimageDir,'dir')
            mkdir(subimageDir)
        end
        autoDetectorDir = fullfile(BILPrefs.autoDetectorDir,thisFilename);
        fprintf('*\nAUTODETECTOR Directory for this image:\n%s\n**********************\n',subimageDir)
        if ~exist(autoDetectorDir,'dir')
            mkdir(autoDetectorDir)
        end
    end %customizeBILPrefs

    function cycleLayout(obj,varargin)
        if isa(obj,'matlab.ui.control.UIControl')
            curr = obj.UserData;
            newVal = rem(curr,nLayouts)+1;
            obj.UserData = newVal;
        else
            newVal = obj;
        end
        changeLayout(newVal);
        
        function changeLayout(layoutNumber)
            % Here we set the position of the toolPanel, the left axes, and
            % the right axes:
            %
            % HORIZONTAL:
            % |(smallGap)|(toolPanelWidth)|(bigGap)|(rightAxWidth)|(smallGap)|
            %
            % VERTICAL (from bottom):
            %              |(bottomGap)|(toolPanelHeight)|(topGap)|(leftAxHeight)|(topGap)|
            
            smallGap = 0.01;
            bigGap = 0.05;
            bottomGap = 0.04;
            topGap = 0.045;%0.025
            toolPanelWidth = 0.475;
            toolPanelHeight = 0.535;
            % Derived:
            rightAxWidth = 1-(2*smallGap+toolPanelWidth+bigGap);
            leftAxHeight = 1-(bottomGap+toolPanelHeight+4*topGap);
            %
            toolPanelPos = [smallGap bottomGap toolPanelWidth toolPanelHeight];
            toolPanel.Position = toolPanelPos;
            leftAxPos = [smallGap bottomGap+toolPanelHeight+topGap toolPanelWidth leftAxHeight];
            rightAxPos = [smallGap+toolPanelWidth+bigGap bottomGap rightAxWidth 1-bottomGap-topGap];
            switch layoutNumber
                case 1
                    subImageAx.Position = rightAxPos;
                    subImageAx.YAxisLocation = 'left';
                    overviewImageAx.Position = leftAxPos;
                case 2
                    subImageAx.Position = leftAxPos;
                    subImageAx.YAxisLocation = 'right';
                    overviewImageAx.Position = rightAxPos;
            end
            updateAxesTicks;
        end %changeLayout
    end %cycleLayout

    function allColors = defineColors(varargin)
        allColors = [
            1           0           0
            0           1           0
            0           0           0.17241
            1           0.10345     0.5
            1           0.82759     0
            0           0.34483     0
            0.51724     0.51724     1
            0.62069     0.31034     0.27586
            0           1           0.75862
            0           0.51724     0.58621
            0           0           0.48276
            0.58621     0.82759     0.31034
            0.96552     0.62069     0.86207
            0.82759     0.068966    1
            0.48276     0.10345     0.41379
            0.96552     0.068966    0.37931
            1           0.75862     0.51724
            0.13793     0.13793     0.034483
            0.55172     0.65517     0.48276];
    end %defineColors

    function deleteSynROIs(varargin)
        [IDs,synROIs,strs,vals,LBString] = getCurrentSelection;
        tmpDlg = questdlg(sprintf('Warning: You are about to delete %i ROIs! Are you sure you want to do that?',numel(vals)),...
            'ARE YOU SURE???!!!','CANCEL','Continue','CANCEL');
        if ~strcmp(tmpDlg,'Continue')
            return
        end
        
        listboxOfSynchronizedROIs.Value = 1;
        for ii = 1:numel(vals)
            ID = IDs(ii);
            thisSynROI = synROIs{ii};
            if ~isempty(thisSynROI)
                thisSynROI.deleteROISet;
            end
            thisSynROI.refresh('delete');
        end %for ii = 1:numel(vals)
        isSaved = false;
    end %deleteSynROIs

    function disableReenableTooltips(obj,varargin)
        if strcmp(obj.Checked,'off')
            obj.Checked = 'on';
        else
            obj.Checked = 'off';
        end
        toggleTooltips(labelBigImageHndl)
    end %disableReenableTooltips

    function currentEnable = disableReenableUIs(currentEnable)
        if nargin < 1
            currentEnable = get(allUIC,'enable');
            set(allUIC,'enable','off');
        else
            for kk = 1:numel(allUIC)
                try %#ok<TRYNC>
                    set(allUIC(kk),'enable',currentEnable{kk});
                end
            end
        end
    end %disableReenableUIs

    function displayAndSelectGrid(varargin)
        fh = drawfreehand('Color','g',...
            'Tag','ManualProcessRegion',...
            'StripeColor','k',...
            'parent',overviewImageAx);
        fh.Waypoints(1:8:end) = true;
    end %displayAndSelectGrid

    function displaySubImage(returnedPosition,subImage,XSubRange,YSubRange)
        labelBigImageHndl.Pointer = 'watch';
        delete(subImageHandle);
        imrefSubImageToOverview = imref2d(size(subImage),...
            [returnedPosition(1) returnedPosition(1)+returnedPosition(3)],...
            [returnedPosition(2) returnedPosition(2)+returnedPosition(4)]);
        subImageHandle = imshow(subImage,imrefSubImageToOverview,...
            'parent',subImageAx);
        set(subImageAx,...
            'XLim',XSubRange,...
            'YLim',YSubRange);
        uistack(subImageHandle,'bottom');
        updateAxesTicks;
        subImageHandle.ButtonDownFcn = @imageClicked;
        %
        gobjs = gobjects(2,1);
        gobjs(1) = overviewImageHandle;
        gobjs(2) = subImageHandle;
        hPanel = impixelinfoval(labelBigImageHndl,gobjs);
        set(hPanel,'units','normalized',...
            'Position',[0.0175+0.005 0.005 0.2 0.025])%0.0025
        addUpdateTitles
        % For storage in synROI, reconstruction:
        displayParameters.returnedPosition = returnedPosition;
        displayParameters.subImageTiles = subImageTiles;
        displayParameters.XSubRange = XSubRange;
        displayParameters.YSubRange = YSubRange;
        %
        labelBigImageHndl.Pointer = 'arrow';
    end %displaySubImage

    function enableValidation(obj,varargin)
        if strcmp(obj.Checked,'off')
            RUSure = questdlg('Enable validation?','!','CANCEL','Yes, I am a validator','CANCEL');
            if ~strcmp(RUSure,'Yes, I am a validator')
                return
            end
            obj.Checked = 'on';
            operatorIsValidator = true;
            validateButton.Enable = 'on';
        else
            obj.Checked = 'off';
            operatorIsValidator = false;
            validateButton.Enable = 'off';
        end
    end %enableValidation

    function exportLabels(varargin)
        disp('Not yet!')
    end %exportLabels

    function extractTrainingData(varargin)
        tmpFig = figure('Name','Extraction Type',...
            'windowstyle','normal',...
            'menubar','none',...
            'units','normalized',...
            'tag','BILTmpFig',...
            'Position',[0.3 0.4 0.4 0.5]);
        n = 2;
        [objpos,objdim] = distributeObjects(n,0.05,0.95,0.1);
        for jjj = 1:n
            switch jjj
                case 1
                    tmpImg = imread('imageChip.png');
                case 2
                    tmpImg = imread('imageChipBoundingRect.png');
            end
            subplot('position',[objpos(jjj),0.4,objdim,0.5])
            imshow(tmpImg)
        end
        extractionTypeBG = uibuttongroup(tmpFig,...
            'position',[0.05 0.05 0.9 0.3],...
            'Title','Extraction Type?');
        %[objpos,objdim] = distributeObjects(2,0.05,0.95,0.015);
        subimageChipsButton = uicontrol(extractionTypeBG,...
            'Style','radiobutton',...
            'String','Sub-image Chips',...
            'units','normalized',...
            'Position',[objpos(1) 0.3 objdim 0.6],...
            'HandleVisibility','off');
        boundedRectanglesButton = uicontrol(extractionTypeBG,...
            'Style','radiobutton',...
            'String','Bounded Rectangles',...
            'units','normalized',...
            'Position',[objpos(2) 0.3 objdim 0.6],...
            'HandleVisibility','off'); %#ok<*NASGU>
        goButton = uicontrol(extractionTypeBG,...
            'Style','pushbutton',...
            'fontweight','bold',...
            'String','Continue!',...
            'units','normalized',...
            'Position',[0.8 0 0.2 0.25],...
            'HandleVisibility','off',...
            'callback',@getExtractionType);
        
        function getExtractionType(varargin)
            if subimageChipsButton.Value == 1
                tmp = 'CHIPS';
            else
                tmp = 'Bounded Rectangles';
            end
            delete(findall(groot,'tag','BILTmpFig'))
        end %getExtractionType
        uiwait(tmpFig)
        %         tmp = questdlg('Define and Extract (sub-image) CHIPS, or bounded rectangles?',...
        %             'Chips or Bounded Rectangles','CHIPS','Bounded Rectangles','CHIPS');
        %         if isempty(tmp)
        %             delete(findall(groot,'tag','BILTmpFig'))
        %             return
        %         end
        if strcmp(tmp,'CHIPS')
            tmpFig = figure('Name','To Define and Extract Training "Chips":',...
                'windowstyle','normal',...
                'menubar','none',...
                'units','normalized',...
                'tag','BILTmpFig',...
                'Position',[0.25 0.4 0.5 0.3]);
            [objpos,objdim] = distributeObjects(6,0.95,0.05,0.025);
            uicontrol(tmpFig,...
                'style','text',...
                'units','normalized',...
                'position',[0.05 objpos(1) 0.9 objdim],...
                'fontsize',9,...
                'fontweight','bold',...
                'horizontalalignment','left',...
                'fontname','monospaced',...
                'string','1)  Clear all non-training ROIs. (Remember to save your work first!)');
            uicontrol(tmpFig,...
                'style','text',...
                'units','normalized',...
                'position',[0.05 objpos(2) 0.9 objdim],...
                'fontsize',9,...
                'fontweight','bold',...
                'horizontalalignment','left',...
                'fontname','monospaced',...
                'string','2)  Select IN THE SUBIMAGE AXES all the freehand region(s) from which you''d like to extract chips for training.');
            uicontrol(tmpFig,...
                'style','text',...
                'units','normalized',...
                'position',[0.05 objpos(3) 0.9 objdim],...
                'fontsize',9,...
                'fontweight','bold',...
                'horizontalalignment','left',...
                'fontname','monospaced',...
                'string','3)  Specify the size of the training chips (H x W):');
            rshift = 0.25;
            chipHEdit = uicontrol(tmpFig,...
                'style','edit',...
                'units','normalized',...
                'position',[0.075 objpos(4) 0.075 objdim],...
                'fontsize',9,...
                'fontweight','bold',...
                'string','100');
            uicontrol(tmpFig,...
                'style','text',...
                'units','normalized',...
                'position',[0.15 objpos(4)+objdim/4 0.025 objdim/2],...
                'fontsize',11,...
                'fontweight','bold',...
                'horizontalalignment','center',...
                'fontname','monospaced',...
                'string','X');
            chipWEdit = uicontrol(tmpFig,...
                'style','edit',...
                'units','normalized',...
                'position',[0.175 objpos(4) 0.075 objdim],...
                'fontsize',9,...
                'fontweight','bold',...
                'string','100');
            pixOrMM(1) = uicontrol(tmpFig,...
                'style','radio',...
                'units','normalized',...
                'position',[0.075+rshift objpos(4) 0.075 objdim],...
                'fontsize',9,...
                'fontweight','bold',...
                'value',1,...
                'string','Pixels',...
                'callback',@changePixOrMicrons);
            pixOrMM(2) = uicontrol(tmpFig,...
                'style','radio',...
                'units','normalized',...
                'position',[0.175+rshift objpos(4) 1.5*0.075 objdim],...
                'fontsize',9,...
                'fontweight','bold',...
                'string','Microns',...
                'callback',@changePixOrMicrons);
            if isnan(currMPP)
                pixOrMM(2).Enable = 'off';
            end
            uicontrol(tmpFig,...
                'style','text',...
                'units','normalized',...
                'position',[0.05 objpos(5) 0.9 objdim],...
                'fontsize',9,...
                'fontweight','bold',...
                'horizontalalignment','left',...
                'fontname','monospaced',...
                'string','4)  Return to this window and press CONTINUE when you''re ready!');
            uicontrol(tmpFig,...
                'style','pushbutton',...
                'units','normalized',...
                'position',[0.075 objpos(6) 0.125 objdim],...
                'fontsize',9,...
                'fontweight','bold',...
                'foregroundcolor',[0 0.8 0],...
                'string','CONTINUE',...
                'callback',@continueImageChipExtraction);
            uicontrol(tmpFig,...
                'style','pushbutton',...
                'units','normalized',...
                'position',[0.25 objpos(6) 0.125 objdim],...
                'fontsize',9,...
                'fontweight','bold',...
                'foregroundcolor',[0.8 0 0],...
                'string','Cancel',...
                'callback',@(~,~)closereq());
        elseif strcmp(tmp,'Bounded Rectangles')
            continueRegionBBExtraction;
        elseif strcmp(tmp,'Pixel Labels')
            temporaryDialog('Not yet!')
            %else %Cancelled
            %    error('Unknown option! How did I get here?')
        end %if strcmp(tmp,'CHIPS')
        
        function continueImageChipExtraction(varargin)
            chipH = str2double(chipHEdit.String);
            chipW = str2double(chipWEdit.String);
            if get(pixOrMM(2),'Value') == 1
                chipH = chipH/currMPP;
                chipW = chipW/currMPP;
            end
            chipH = round(chipH);
            chipW = round(chipW);
            %             synROI = findSynchronizedROIs(overviewImageAx,...
            %                 {'synchronizedImfreehands','synchronizedImrects'},[],[],false);
            synROI = findSynchronizedROIs(overviewImageAx,...
                'type',{'synchronizedImfreehands','synchronizedImrects'},...
                'queryFields', {'label',   'validated'},...
                'queryValues', {thisLabel,  true      });
            delete(findall(groot,'tag','BILTmpFig'))
            uniqueLabels = getLabelsInUse;
            if isempty(uniqueLabels)
                temporaryDialog('No regions specified from which to extract chips.')
                return
            end
            nChips = zeros(numel(uniqueLabels),1);
            %
            if exist(BILPrefs.imageChipDir,'dir')
                tmp = questdlg({'TrainingData directory already exists!',...
                    'If you continue, you will augment it with newly acquired chips.',...
                    sprintf('(Alternatively, quit and rename directory %s, then try again.)',BILPrefs.imageChipDir)},...
                    'Resolution?','CONTINUE/Augment','Abort','CONTINUE/Augment');
            else
                mkdir(BILPrefs.imageChipDir)
                tmp = 'CONTINUE/Augment';
            end
            if ~strcmp(tmp,'CONTINUE/Augment')
                return
            end
            try
                imds = imageDatastore(BILPrefs.imageChipDir,...
                    'IncludeSubfolders',true,...
                    'LabelSource','foldernames');
                sampleImg = readimage(imds,1);
                if size(sampleImg,1) ~= chipH || size(sampleImg,2) ~= chipW
                    beep
                    tmp = questdlg(sprintf('OOPS! Seems you have specified an incompatible chip height or width!\nExisting chips are %i x %i; Please make sure specify the same sizes,\nor remove/rename existing training data at %s!',...
                        size(sampleImg,1),size(sampleImg,2),BILPrefs.imageChipDir),...
                        'WARNING: Mismatching chip sizes requested!',...
                        'Match to existing chip size','Abort','Match to existing chip size');
                    if ~strcmp(tmp,'Match to existing chip size')
                        return
                    else
                        chipH = size(sampleImg,1);
                        chipW = size(sampleImg,2);
                    end
                end
            catch
                % Directory likely exists, but is empty. That triggers an
                % error on a call to imageDatastore;
                disp('It appears that the chip directory is empty.')
            end
            %
            h = waitbar(0,'Extracting training chips...');
            for ii = 1:numel(synROI)
                thisSynROI = synROI{ii};
                gotoSynROI(thisSynROI);
                img = thisSynROI.samplingOpts.parentImages{2};
                positions = thisSynROI.ROI(2).getPosition;
                verbose = true;
                currDir = fullfile(imageChipDir,thisSynROI.label);
                currDirExists = exist(currDir,'dir') ~= 0;
                if ~currDirExists
                    mkdir(currDir)
                end
                if isa(thisSynROI.activeROI,'imfreehand')
                    [~,nTrainingTiles] = getTrainingTilesFromFreehandIMROI(...
                        img,positions,subImageAx,chipW,chipH,verbose,...
                        currDir,'uint8',false);
                else
                    [~,nTrainingTiles] = getTrainingTilesFromRectIMROI(...
                        img,positions,subImageAx,chipW,chipH,verbose,...
                        currDir,'uint8',false);
                end
                nChips(strcmp(thisSynROI.label,uniqueLabels)) = ...
                    nChips(strcmp(thisSynROI.label,uniqueLabels))+ nTrainingTiles;
                waitbar(ii / numel(synROI))
            end
            pause(3)
            delete(findall(labelBigImageHndl,'tag','TempRectangle'))
            delete(findall(labelBigImageHndl,'tag','tempText'))
            thisRpt = [];
            for ii = 1:numel(nChips)
                thisRpt = char(thisRpt,...
                    sprintf('You wrote: %i chips of label ''%s''\n',nChips(ii),uniqueLabels{ii}));
            end
            thisRpt = thisRpt(2:end,:);%This is a bit ugly...
            temporaryDialog(char(thisRpt),6);
            close(h)
        end % continueImageChipExtraction
        
        function continueRegionBBExtraction(varargin)
            %             synROI = findSynchronizedROIs(overviewImageAx,...
            %                 {'synchronizedImfreehands','synchronizedImrects'},[],[],false);
            synROI = findSynchronizedROIs(overviewImageAx,...
                'type',{'synchronizedImfreehands','synchronizedImrects'});
            
            delete(findall(groot,'tag','BILTmpFig'))
            uniqueLabels = getLabelsInUse;
            if isempty(uniqueLabels)
                temporaryDialog('No regions specified from which to extract chips.')
                return
            end
            %
            h = waitbar(0,'Extracting bounded rectangular regions...');
            try
                imds = imageDatastore(fullfile(BILPrefs.subimageDir,thisLabel));
                nExistingImages = length(imds.Files);
            catch
                nExistingImages = 0;
            end
            hrect = gobjects(numel(synROI),1);
            for kk = 1:numel(synROI)
                thisSynROI = synROI{kk};
                axNum = thisSynROI.idxActiveROI;
                if axNum == 1
                    thisAx = overviewImageAx;
                elseif axNum == 2
                    thisAx = subImageAx;
                end
                thisLabel = thisSynROI.label;
                gotoSynROI(thisSynROI,false);%flashOn = false
                img = thisSynROI.samplingOpts.parentImages{2};
                %positions = thisSynROI.ROI(2).getPosition;
                positions = thisSynROI.ROI(axNum).getPosition;
                lims = [get(thisAx,'XLim'),get(thisAx,'YLim')];
                if isa(thisSynROI.activeROI,'imrect')
                    minx = positions(1);
                    maxx = positions(1)+positions(3);
                    miny = positions(2);
                    maxy = positions(2)+positions(4);
                else
                    minx = min(positions(:,1));
                    maxx = max(positions(:,1));
                    miny = min(positions(:,2));
                    maxy = max(positions(:,2));
                end
                BB = [minx miny maxx-minx maxy-miny];
                relBB = [minx-lims(1) miny-lims(3) BB(3:4)];
                subimage = imcrop(img,relBB);
                thisSubimageDir = fullfile(subimageDir,thisSynROI.label);
                fname = fullfile(thisSubimageDir,sprintf('subimage_%i.png',nExistingImages+kk));
                if ~isempty(subimage)
                    if ~exist(thisSubimageDir,'dir')
                        mkdir(thisSubimageDir);
                    end
                    imwrite(subimage,fname);
                    hrect(kk) = drawrectangle(subImageAx,'position',BB,'stripeColor','y','linewidth',3);
                    fprintf('You successfully wrote subimage to %s.\n',fname);
                else
                    fprintf('Skipped file %s because data was empty.\n',fname);
                end
                waitbar(kk / numel(synROI))
            end
            close(h)
            delete(hrect)
        end %continueRegionBBExtraction
    end %extractTrainingData

    function allSynROI = findSynchronizedROIsCurrentlyInSubimageView(varargin)
        thisParent = subImageAx;
        currentXBounds = thisParent.XLim;
        currentYBounds = thisParent.YLim;
        allSynROI = findSynchronizedROIs(overviewImageAx);
        searchFcn = @(obj) posToVert(vertToPos(obj.ROI(2).getPosition));
        allPos = cellfun(searchFcn,allSynROI,'UniformOutput',false);
        searchFcn = @(x) all(inpolygon(x(:,1),x(:,2),currentXBounds,currentYBounds));
        in = cell2mat(cellfun(searchFcn,allPos,'UniformOutput',false));
        allSynROI(~in) = [];
    end %findSynchronizedROIsCurrentlyInSubimageView

    function [allSynROIs,currentSessionLabels] = generateSessionLog(includeUnnamed,verbose)
        % NOTE: Whether or not it makes sense to cast the ground truth as a
        % groundTruth object is still unclear to me. Freehand regions will
        % have to be stored as an image (pixelLabel type), as a line (???),
        % or as a custom type. Given that I won't be able to use this in
        % the labelers anyway, maybe better just to save as a struct?
        [allSynROIs, currentSessionLabels] = ...
            findSynchronizedROIs(overviewImageAx,...
            'type',{'all'});
        if isempty(allSynROIs)
            if verbose
                temporaryDialog('No regions detected.')
            end
            return
        end
        if ~includeUnnamed
            allSynROIs(strcmp(currentSessionLabels,defaultAutoSegLabel)) = [];
            currentSessionLabels(strcmp(currentSessionLabels,defaultAutoSegLabel)) = [];
        end
        if isempty(allSynROIs)
            if verbose
                temporaryDialog('No named regions detected');
            end
            return
        end
        [uniqueLabels,allCurrentLabels,labelInds] = getLabelsInUse;
        Positions = cell(numel(allSynROIs),1);
        for ii = 1:numel(allSynROIs)
            Positions(ii) = allSynROIs{ii}.ROIPositions(1);
        end
        currentSessionLog = table(currentSessionLabels,Positions,...
            'VariableNames',{'Label' 'Position'});
        if verbose
            if ~isempty(Positions)
                disp(currentSessionLog)
                temporaryDialog('Annotations table displayed in Command Window.')
            else
                temporaryDialog('No named regions detected');
            end
        end
        %
        %[~,~,labelInds] = getLabelsInUse;
        pixelLabelID = num2cell(labelInds);
        %dataSource = groundTruthDataSource(repmat({imageName},[size(pixelLabelID,1),1]));
        %pixelLabelID = num2cell(1:numel(uniqueLabels));
        %types = repmat(labelType('PixelLabel'),[numel(allCurrentLabels),1]);
        %labelDefs = table(allCurrentLabels,types, pixelLabelID, ...
        %    'VariableNames',{'Name','Type','PixelLabelID'});
        %[~,fn,ext] = fileparts(imageName);
        %dataFile = {fullfile(BILPrefs.groundTruthDir,['pixelLabeled',fn,ext])};
        %labelData = table(dataFile,'VariableNames',{'PixelLabelData'});
        %gTruth = groundTruth(dataSource,...
        %    labelDefs,...
        %    labelData);
        %disp(gTruth)
    end %generateSessionLog

    function [IDs,synROIs,strs,vals,LBString] = getCurrentSelection(varargin)
        IDs = [];
        synROIs = [];
        strs  = [];
        vals = [];
        LBString = listboxOfSynchronizedROIs.String;
        if isempty(LBString)
            return
        end
        vals = listboxOfSynchronizedROIs.Value;
        if isempty(vals)
            return
        end
        strs = LBString(vals,:);
        IDs = nan(numel(vals),1);
        synROIs = cell(numel(vals),1);
        for ii = 1:numel(vals)
            thisStr = LBString(vals(ii),:);
            thisStr= strsplit(thisStr);
            IDs(ii)  = str2double(thisStr{2});
            thisSynROI = findSynchronizedROIs(overviewImageAx,...
                'type',{'synchronizedImfreehands','synchronizedImrects'},...
                'queryFields', {'uniqueIdentifier'},...
                'queryValues', {IDs(ii)});
            synROIs{ii} = thisSynROI{1};
        end
    end %getCurrentSelection

    function [ID,thisSynROI,thisStr,thisVal,LBString] = getCurrentSynROIInfo(varargin)
        ID = [];
        thisSynROI = [];
        LBString = listboxOfSynchronizedROIs.String;
        if isempty(LBString)
            return
        end
        thisVal = listboxOfSynchronizedROIs.Value;
        thisStr = LBString(thisVal,:);
        if isempty(thisStr)
            return
        elseif size(thisStr,1) > 1
            thisStr = thisStr(1,:);
        end
        strs = strsplit(thisStr);
        ID = str2double(strs{2});
        if nargout > 1
            thisSynROI = findSynchronizedROIs(overviewImageAx,...
                'type',{'synchronizedImfreehands','synchronizedImrects'},...
                'queryFields', {'uniqueIdentifier'},...
                'queryValues', {ID});
            if isempty(thisSynROI)
                return
            end
            thisSynROI = thisSynROI{1};
        end
    end %getCurrentSynROIInfo

    function [XSubRange,YSubRange] = getFullTileSubRanges(cUL,cLR,rUL,rLR,varargin)
        % We're reading whole tiles:
        XSubRange(1)  = (cUL-1)*tileW + 0.5;
        XSubRange(2) = cLR*tileW + 0.5;
        YSubRange(1) = (rUL-1)*tileH + 0.5;
        YSubRange(2) = rLR*tileH + 0.5;
    end %getFullTileSubRanges

    function [XSubRange,YSubRange,returnedPosition,subImageTiles] = getDisplayParameters(requestedPosition)
        % We'll calculate the upper left and lower right
        % tiles, and then read the range of subImageTiles from
        % the corresponding locations of tileMap;
        UL = [requestedPosition(2),requestedPosition(1)];
        LR = [requestedPosition(2)+requestedPosition(4),requestedPosition(1)+requestedPosition(3)];
        ULTile = tiffImageClass.computeTile(UL);
        LRTile = tiffImageClass.computeTile(LR);
        %
        [cUL,rUL] = find(tileMap==ULTile);
        [cLR,rLR] = find(tileMap==LRTile);
        [XSubRange,YSubRange] = getFullTileSubRanges(cUL,cLR,rUL,rLR);
        subImageTiles = tileMap(cUL:cLR,rUL:rLR);
        if isempty(subImageTiles)
            temporaryDialog('hereiam')
        end
        %Reposition returnedPosition to corners of tiles:
        %returnedPosition  = [XSubRange(1) YSubRange(1) range(XSubRange) range(YSubRange)];
        returnedPosition  = [XSubRange(1) YSubRange(1) max(XSubRange)-min(XSubRange) max(YSubRange)-min(YSubRange)];
    end %getDisplayParameters

    function getFile(varargin)
        [~,~,fname,fpath,userCanceled] = getNewImage(true,false);
        if userCanceled
            return
        end
        labelBigImage(fullfile(fpath,fname));
    end %getFile

    function [uniqueLabels,allCurrentLabels,labelInds] = getLabelsInUse(varargin)
        %uniqueLabels = getLabelsInUse;
        thisStr = listboxOfSynchronizedROIs.String;
        if isempty(thisStr)
            uniqueLabels = [];
            allCurrentLabels = [];
            return
        end
        nStr = size(thisStr,1);
        allCurrentLabels = cell(nStr,1);
        for ii = 1:nStr
            strs = strsplit(thisStr(ii,:));
            allCurrentLabels{ii} = strs{1};
        end
        uniqueLabels = unique(allCurrentLabels);
        if nargout > 2
            [~,labelInds] = ismember(allCurrentLabels,uniqueLabels);
        end
    end %getLabelsInUse

    function gotoSynROI(varargin)
        flashOn = true;
        if nargin > 1 && islogical(varargin{2})
            flashOn = varargin{2};
        end
        if isa(varargin{1},'synchronizedROI')
            thisSynROI = varargin{1};
        else
            [ID,thisSynROI] = getCurrentSynROIInfo;
        end
        thisUD = thisSynROI.userData;
        storedReturnedPosition = thisUD.returnedPosition;
        storedXSubRange = thisUD.XSubRange;
        storedYSubRange = thisUD.YSubRange;
        storedSubImageTiles = thisUD.subImageTiles;
        [XSubRange,YSubRange,returnedPosition,subImageTiles] = getDisplayParameters(storedReturnedPosition);
        % Note: This was in an if-then statement, comparing the current
        % position to the requested position. However, it then fails to
        % highlight on current region after serialAutoSegment.
        subImage = retrieveSubImage(storedSubImageTiles);
        displaySubImage(storedReturnedPosition,subImage,storedXSubRange,storedYSubRange)
        overviewRegionSelector.setPosition(storedReturnedPosition)
        showButtonVisibility(showLabelsCheckbox);
        cLw = thisSynROI.lineWidth;
        cLc = thisSynROI.lineColor;
        bgc = thisSynROI.labelButtons(1).BackgroundColor;
        if flashOn && isvalid(thisSynROI.activeROI)
            for ii = 1:3
                thisSynROI.lineWidth = 8;
                thisSynROI.lineColor = [0 0.7 0];
                for jj = 1:thisSynROI.numROIs
                    thisSynROI.labelButtons(jj).BackgroundColor = 'r';
                end
                pause(0.15)
                thisSynROI.lineWidth = cLw;
                thisSynROI.lineColor = cLc;
                for jj = 1:thisSynROI.numROIs
                    thisSynROI.labelButtons(jj).BackgroundColor = bgc;
                end
                pause(0.15)
            end
        end
    end %gotoSynROI

    function imageClicked(manualROIType,varargin)
        selType = get(labelBigImageHndl,'SelectionType'); %{'normal','alt','open','extend'}
        %currentAx = imgca; %For some reason this becomes very sluggish
        %when there are a lot of synROIs.
        currentAx = gca;
        if ~ismember(currentAx,[subImageAx,overviewImageAx])
            beep;
            temporaryDialog('Please activate an axes on labelBigImage! (Neither axes appears to be current!)');
            return
        end
        %
        switch currentAx
            case subImageAx %SUBIMAGE CLICKED
                subImageClicked
            case overviewImageAx %OVERVIEW IMAGE CLICKED
                overviewImageClicked;
        end
        
        function overviewImageClicked(varargin)
            switch selType
                case 'normal'
                    moveRegion
                case 'alt'
                    % Add an IMROI
                    if ~isempty(manualROIType) && strcmp(manualROIType,'rect')
                        constructRectSynROI(overviewImageAx,defaultManualSegLabel,1,defaultManualSegColor);
                    elseif ~isempty(manualROIType) && strcmp(manualROIType,'freehand')
                        constructFreehandSynROI(overviewImageAx,defaultManualSegLabel,1,defaultManualSegColor);
                    else
                        if drawFreehandButton.Value == 1
                            constructFreehandSynROI(overviewImageAx,defaultManualSegLabel,1,defaultManualSegColor);
                        else
                            constructRectSynROI(overviewImageAx,defaultManualSegLabel,1,defaultManualSegColor);
                        end
                    end
                otherwise
                    fprintf('Not sure what to do with this %s click!\n',selType);
            end
        end % overviewImageClicked
        
        function subImageClicked(varargin)
            switch selType
                case 'normal'
                    if ~isempty(manualROIType) && strcmp(manualROIType,'rect')
                        constructRectSynROI(subImageAx,defaultManualSegLabel,1,defaultManualSegColor);
                    elseif ~isempty(manualROIType) && strcmp(manualROIType,'freehand')
                        constructFreehandSynROI(subImageAx,defaultManualSegLabel,1,defaultManualSegColor);
                    else
                        if drawFreehandButton.Value == 1
                            constructFreehandSynROI(subImageAx,defaultManualSegLabel,1,defaultManualSegColor);
                        else
                            constructRectSynROI(subImageAx,defaultManualSegLabel,1,defaultManualSegColor);
                        end
                    end
                    %constructFreehandSynROI(subImageAx,defaultManualSegLabel);
                case 'alt'
                    %autoSegment([],'ALT-CLICK');
                    autoSegment('uiAction')
                otherwise
                    fprintf('I''m not sure what to do with this %s click!',selType);
            end
            % This is here bc stepping click-triggering to draw an ROI is
            % getting stuck in the "on" state. Stepping through the code
            % stops it.
            drawnow
        end %subImageClicked
        
    end %imageClicked

    function importDisplayLabels(varargin)
        [fn,pn] = uigetfile([pathToImage,filesep,'.tif'],'Select a labeled Tiff image');
        if fn == 0
            return
        end
        labelFile = fullfile(pn,fn);
        [m,n,~] = size(overviewImage);
        labelImage = imread(labelFile);
        labelImage = repelem(labelImage,...
            round(m/size(labelImage,1)),round(n/size(labelImage,2)));
        labelImage = imresize(labelImage,[m,n],'nearest');
        uniqueLabels = unique(labelImage(:));
        nL = numel(uniqueLabels);
        temporaryDialog('NOTE: Applying labels specific to Hologic test image!');
        ClassNames =  {'HSIL'  'LSIL'  'non-cell'  'normal_cells'};
        hold on
        opacity = 1;
        allColors = jet(nL);
        for ii = 1:nL
            overlayHndls = showMaskAsOverlay(opacity,...
                labelImage == uniqueLabels(ii),...
                allColors(ii,:),overviewImageAx,false,imrefOverview);
        end
        set(overlayHndls,'HitTest','off');
        set(overlayHndls,'HandleVisibility','off');
        set(overlayHndls,'PickableParts','none');
        delete(overviewRegionSelector)
        constructOverviewRegionSelector
        colormap(overviewImageAx,allColors);
        tmp = colorbar(overviewImageAx);
        set(tmp,'ytick',1/(nL*2):1/nL:1)
        set(tmp,'yticklabel',ClassNames,'TickLabelInterpreter','none');
    end %importDisplayLabels

    function entry = makeListboxEntry(str,len)
        % Take a space-delimited string, make it uniform in length
        if nargin == 1
            len = [28 6];
        end
        fixedLen = 40;
        strParsed = strsplit(str,' ');
        entry = [padstr(strParsed{1},len(1)),...
            padstr(strParsed{2},len(2))];
        entry(fixedLen) = 32;
        entry(entry==0) = 32;%'.';
        function str = padstr(str,len)
            str = str(1:min(length(str),len));
            str(len+1) = 0;
        end
    end %makeListboxEntry

    function manageOverlaps(varargin)
        %         allSynROI = findSynchronizedROIs(overviewImageAx,...
        %             {'synchronizedImfreehands','synchronizedImrects'},[],[],false);
        allSynROI = findSynchronizedROIs(overviewImageAx,...
            'type',{'synchronizedImfreehands','synchronizedImrects'});
        if isempty(allSynROI)
            temporaryDialog('No ROIs detected!');
            return
        end
        tmp = cellfun(@(x)x.boundingBox,allSynROI,'UniformOutput',false);
        bboxes = reshape(cell2mat(tmp'),4,[])';
        tmp = cellfun(@(x)x.score,allSynROI,'UniformOutput',false);
        scores = cell2mat(tmp);
        scores = scores(:);
        init = 1:numel(scores);
        overlapThresh = str2double(maxOverlapEdit.String);
        [selectedBboxes,selectedScores,indices] = ...
            selectStrongestBbox(bboxes,scores,...
            'OverlapThreshold',overlapThresh);
        deletions = setdiff(init,indices);
        for del = 1:numel(deletions)
            allSynROI{del}.deleteROISet;
            removeFromListbox(allSynROI{del}.uniqueIdentifier);
        end
        temporaryDialog(sprintf('%i ROIs removed.',numel(deletions)))
    end %manageOverlaps

    function manageSerialSegmentButton(obj,varargin)
        isSubax = whichAxButton(1).Value == 1;
        thisOpt = segOptRadio(logical([segOptRadio.Value])).String;
        if thisOpt(end)==':'
            thisOpt = thisOpt(1:end-1);
        end
        isAutomatable = isSubax && ismember(thisOpt,...
            {'Imextended','Threshold','Custom'});
        if isAutomatable
            processAllTiles.Enable = 'on';
        else
            processAllTiles.Enable = 'off';
        end
        autoSegment(obj)
    end %manageSerialSegmentButton

    function moveRegion(varargin)
        % This is called either by clicking on the overviewImageAx or
        % by repositioning the overviewRegionSelector. If the overviewImage
        % is clicked, varargin is empty. If the OverviewRegionSelector
        % is repositioned, varargin{1} is an imrect. First, establish
        % the trigger type:
        
        if isempty(varargin)
            triggerType = 'imageClick';
        elseif isa(varargin{1},'imrect')
            triggerType = 'regionSelectorReposition';
        end
        
        % Preparations:
        % Recode defaultThisSubimageAutoSegLabel to defaultAutoSegLabel
        %         toBeRenamed = findSynchronizedROIs(overviewImageAx,...
        %             {'synchronizedImfreehands','synchronizedImrects'},...
        %             defaultThisSubimageAutoSegLabel,[],false);
        toBeRenamed = findSynchronizedROIs(overviewImageAx,...
            'type',{'synchronizedImfreehands','synchronizedImrects'},...
            'queryFields', {'label'},...
            'queryValues', {defaultThisSubimageAutoSegLabel});
        for ii = 1:numel(toBeRenamed)
            newLabel = strrep(toBeRenamed{ii}.label,...
                defaultThisSubimageAutoSegLabel,defaultAutoSegLabel);
            %toBeRenamed{ii}.label = defaultAutoSegLabel;
            %set(toBeRenamed{ii}.labelButtons,'String',defaultAutoSegLabel)
            toBeRenamed{ii}.label = newLabel;
            set(toBeRenamed{ii}.labelButtons,'String',newLabel)
        end
        
        switch triggerType
            case 'imageClick'
                clickedPoint = overviewImageAx.CurrentPoint(1,1:2);
                %This is image-buttonDOWN
                % MOVE BOUNDING BOX:
                boxW = requestedPosition(3);
                boxH = requestedPosition(4);
                requestedPosition = [clickedPoint(1)-boxW/2,clickedPoint(2)-boxH/2 boxW, boxH];
                % NOTE: This must be inside the 'imageClick' case
                % because otherwise the repositioning of the
                % overviewRegionSelector will trigger another round of
                % actions!
                % Constrain:
                requestedPosition(1) = max(0.5,requestedPosition(1));
                requestedPosition(1) = min(requestedPosition(1),imgW-boxW+0.5);
                requestedPosition(2) = min(requestedPosition(2),imgH-boxH+0.5);
                requestedPosition(2) = max(0.5,requestedPosition(2));
                overviewRegionSelector.setPosition(requestedPosition)
                moveRegion(overviewRegionSelector)
                drawnow
            case 'regionSelectorReposition'
                % NOTE: The repositioning of the
                % overviewRegionSelector (in the imageClick scenario)
                % will trigger this! I encapsulate the redisplay here
                % so it won't be called twice!!!
                requestedPosition = overviewRegionSelector.getPosition;
                [XSubRange,YSubRange,returnedPosition,subImageTiles] = getDisplayParameters(requestedPosition);
                drawnow
                subImage = retrieveSubImage(subImageTiles);
                % If a colorspace conversion was requested:
                subImage = convertImage(subImage);
                %cla(subImageAx) %NO! This deletes synROIs, breaks things!
                displaySubImage(returnedPosition,subImage,XSubRange,YSubRange)
        end
        %
    end %moveRegion

    function nextValidation(varargin)
        [ID,thisSynROI,currStr,currVal] = getCurrentSynROIInfo;
        switch validationOption
            case 'Validate All'
                [requestedSynROIs,~,requestedIDs] = findSynchronizedROIs(overviewImageAx,...
                    'type',{'synchronizedImfreehands','synchronizedImrects'});
            case 'Skip Validated'
                [requestedSynROIs,~,requestedIDs] = findSynchronizedROIs(overviewImageAx,...
                    'type',{'synchronizedImfreehands','synchronizedImrects'},...
                    'queryFields', {'validated'},...
                    'queryValues', {false});
            case 'Skip Unvalidated'
                [requestedSynROIs,~,requestedIDs] = findSynchronizedROIs(overviewImageAx,...
                    'type',{'synchronizedImfreehands','synchronizedImrects'},...
                    'queryFields', {'validated'},...
                    'queryValues', {true});
        end
        [nextID,ind] = min(requestedIDs(requestedIDs > ID));
        if isempty(nextID)% || currVal >= size(currStr,1)
            tmp = questdlg('That''s the last one...Start from the top?','Last List Item',...
                'YES','No, I''m Done','YES');
            if ~strcmp(tmp,'YES')
                return
            end
            nextID = min(requestedIDs);
        end
        thisSynROI = selectByID(nextID);
        zoomToCurrent(thisSynROI)
    end %nextValidation

    function parseDetectorOutputStruct(detectorStruct)
        %optionalShift allows accommodation of offsets in serial custom
        %algorithms that result in Struct outputs
        discardInds = false(size(detectorStruct.Boxes,1),1);
        for jj = 1:size(detectorStruct.Boxes,1)
            thisBox = max(1,round(detectorStruct.Boxes(jj,:)));
            % 9/26/2019: Implementing minsize paring on struct outputs
            thisSize = thisBox(3)*thisBox(4);
            if thisSize < minSizeSlider.Value || thisSize > maxSizeSlider.Value
                discardInds(jj) = true;
%                 detectorStruct.Boxes(jj,:) = nan(1,4);
%                 detectorStruct.Scores(jj) = nan;
%                 detectorStruct.Labels(jj) = 'NaN';
                continue
            end
            [x1,y1] = intrinsicToWorld(imrefSubImageToOverview,thisBox(1),thisBox(2));
            tmp = imrect(parentAx,[x1 y1 thisBox(3) thisBox(4)]);
            if isfield(detectorStruct,'Scores')
                thisScore = detectorStruct.Scores(jj);
            else
                thisScore = [];
            end
            constructRectSynROI(tmp,...
                [char(detectorStruct.Labels(jj)),'_',defaultThisSubimageAutoSegLabel],...
                thisScore);
        end %for jj = 1:size(detectorStruct.Boxes,1)
        detectorStruct.Boxes(discardInds,:) = [];
        detectorStruct.Scores(discardInds) = [];
        detectorStruct.Labels(discardInds) = [];
        if isempty(detectorStruct.Scores)
            temporaryDialog('No regions captured with these settings! (nnz(mask) == 0)',3)
        end
        %
        segSelectedButton.String = 'Segment Selected';
        segSelectedButton.ForegroundColor = 'k';
        labelBigImageHndl.Pointer = 'arrow';
        drawnow;
        
    end %parseDetectorOutputStruct

    function [includeLearningTools,maxDisplayDimension,...
            previousSessionROIs,useMultiSessionLabels] = ...
            parseInputs(varargin)
        % Setup parser with defaults
        parser = inputParser;
        parser.CaseSensitive = false;
        parser.addParameter('includeLearningTools', false);
        % Disallow attempts to display huge images in full; above this height
        % or width, downsample:
        parser.addParameter('maxDisplayDimension', 10000);
        parser.addParameter('previousSessionROIs', []);
        parser.addParameter('useMultiSessionLabels', false);
        % Parse input
        parser.parse(varargin{:});
        % Assign outputs
        r = parser.Results;
        [includeLearningTools,maxDisplayDimension,...
            previousSessionROIs,useMultiSessionLabels] = ...
            deal(r.includeLearningTools,...
            r.maxDisplayDimension,r.previousSessionROIs,...
            r.useMultiSessionLabels);
    end %parseInputs

    function populateImageSegmenter(varargin)
        tmpFig = figure('Name','Select Segmentation Tool:',...
            'windowstyle','normal',...
            'menubar','none',...
            'units','normalized',...
            'tag','BILTmpFig',...
            'Position',[0.4 0.4 0.2 0.2]);
        [objpos,objdim] = distributeObjects(3,0.95,0.05,0.05);
        uicontrol(tmpFig,...
            'style','pushbutton',...
            'units','normalized',...
            'position',[0.05 objpos(1) 0.9 objdim],...
            'string','imageSegmenter',...
            'callback',@toolSelected);
        uicontrol(tmpFig,...
            'style','pushbutton',...
            'units','normalized',...
            'position',[0.05 objpos(2) 0.9 objdim],...
            'string','colorThresholder',...
            'callback',@toolSelected);
        uicontrol(tmpFig,...
            'style','pushbutton',...
            'units','normalized',...
            'position',[0.05 objpos(3) 0.9 objdim],...
            'string','segmentImage',...
            'callback',@toolSelected);
        
        function toolSelected(obj,varargin)
            toolSelection = obj.String;
            switch toolSelection
                case 'segmentImage'
                    segmentImage(subImage);
                case 'imageSegmenter'
                    imageSegmenter(rgb2gray(subImage));
                case 'colorThresholder'
                    colorThresholder(subImage);
            end
            delete(findall(groot,'tag','BILTmpFig'))
        end %toolSelected
    end %populateImageSegmenter

    function subImage = readTiles(subImageTiles)
        thisImage = zeros(tileH,tileW,3,numel(subImageTiles),'uint8');
        for ii = 1:numel(subImageTiles)
            thisTile = subImageTiles(ii);
            [a,b] = ind2sub(size(tileMap),thisTile);
            a = a*tileH;
            b = b*tileW;
            try
                tmp = tiffImageClass.readRGBATile(b,a);
            catch
                %disp('Unable to read this block...')
                continue
            end
            %thisImage(:,:,:,ii) = tiffImageClass.readRGBATile(b,a);
            thisImage(:,:,:,ii) = tmp;
        end
        %
        if numel(subImageTiles) > 1
            subImage = getMontageImage(thisImage,subImageTiles);
        else
            subImage = thisImage;
        end
    end %readTiles

    function recallSession(varargin)
        tmp = questdlg('Terminate/Close this session and RECALL a previous one?',...
            'Recall?','YES','No','YES');
        if ~strcmp(tmp,'YES')
            return
        end
        closeLabeler;
        allSesssions = dir(fullfile(BILPrefs.sessionLogDir,'*.mat'));
        if isempty(allSesssions)
            temporaryDialog('No segmentation logs detected.',3)
            return
        end
        
        %%%
        tmpFig = figure('Name','Select Segmentation Set:',...
            'windowstyle','normal',...
            'menubar','none',...
            'units','normalized',...
            'tag','BILTmpFig',...
            'Position',[0.4 0.4 0.2 0.2]);
        lb = uicontrol(tmpFig,...
            'style','listbox',...
            'units','normalized',...
            'position',[0 0 1 1],...
            'string',fliplr({allSesssions.name}),...
            'callback',@nameSelected);
        
        function nameSelected(varargin)
            thisSel = lb.String{lb.Value};
            delete(findall(groot,'tag','BILTmpFig'))
            requestedSessionName = fullfile(BILPrefs.sessionLogDir,thisSel);
            allSynROIs = load(requestedSessionName);
            allSynROIs = allSynROIs.allSynROIs;
            
            f = waitbar(0,'Loading presaved session...');
            labelBigImage(allSynROIs(1).filename,...
                'previousSessionROIs',allSynROIs);
            %             tiffImageClass = userData.tiffImageClass;
            %             figureHandle = userData.figureHandle;
            %             overviewImageAx = userData.overviewImageAxes;
            %             subImageAx = userData.subImageAxes;
            %             for ii = 1:numel(allSynROIs)
            %                 waitbar(ii/numel(allSynROIs))
            %                 thisPos = allSynROIs(ii).positions;
            %                 if numel(thisPos) == 4
            %                     tmp = imrect(overviewImageAx,thisPos);
            %                     synROI = constructRectSynROI(tmp,allSynROIs(ii).label);
            %                 else
            %                     tmp = imfreehand(overviewImageAx,thisPos); %#ok<*IMFREEH>
            %                     synROI = constructFreehandSynROI(tmp,allSynROIs(ii).label);
            %                 end
            %                 synROI.lineColor = allSynROIs(ii).lineColor;
            %                 synROI.lineStyle = allSynROIs(ii).lineStyle;
            %                 synROI.lineWidth = allSynROIs(ii).lineWidth;
            %                 synROI.userData = allSynROIs(ii).userData;
            %             end
            delete(f)
            %isSaved = false;
        end %nameSelected
    end %recallSession

    function removeFromListbox(thisUniqueID,varargin)
        if ~isvalid(listboxOfSynchronizedROIs)
            % figure deletion!
            return
        end
        %thisUniqueID = thisUniqueID.uniqueIdentifier;
        currString = listboxOfSynchronizedROIs.String;
        if ~isempty(currString)
            %contains(string(currString),num2str(thisUniqueID))
            ind = [];
            for ii = 1:size(currString,1)
                tmp = strsplit(currString(ii,:));
                if str2double(tmp{2})==thisUniqueID
                    ind = ii;
                    break
                end
            end
            if ~isempty(ind)
                currString(ind,:) = [];
                listboxOfSynchronizedROIs.Value = 1;
                listboxOfSynchronizedROIs.String = currString;
            end
        end
        isSaved = false;
        % Trigger manually:
        updateLabelCount();
    end %removeFromListbox

    function renameSelected(varargin)
        [IDs,synROIs,strs,vals,LBString] = getCurrentSelection;
        thisLabel = inputdlg(sprintf('Rename these %i ROIs to:\n\n(Leave dialog box blank to cancel renaming.)\n\n',numel(vals)),...
            '', [1 50]);
        if isempty(thisLabel)
            return
        end
        thisLabel = thisLabel{1};
        %%%
        if ~ismember(thisLabel,currentSessionLabels)
            currentSessionLabels = [defaultAutoSegLabel;...
                sort([thisLabel;setdiff(currentSessionLabels,...
                {defaultAutoSegLabel,defaultManualSegLabel,...
                defaultThisSubimageAutoSegLabel})])];
            lockedOrderLabels = [lockedOrderLabels;thisLabel];
            save(labelDir,'currentSessionLabels')
        end
        %%%
        f = waitbar(0,'Renaming selected ROIs...');
        for ii = 1:numel(vals)
            waitbar(ii/numel(vals))
            thisSynROI = synROIs{ii};
            ID = IDs(ii);
            thisSynROI.label = thisLabel;
            if ~thisSynROI.isLocked
                thisSynROI.togglePositionLock
            end
            isSaved = false;
            set(thisSynROI.labelButtons,'String',thisLabel)
            drawnow
        end
        delete(f)
        isSaved = false;
    end %renameSelected

    function subImage = retrieveSubImage(subImageTiles,type)
        if nargin < 2
            type = 'tiles';
        end
        labelBigImageHndl.Pointer = 'watch';
        switch type
            case 'tiles'
                subImage = readTiles(subImageTiles);
                repositionBehavior = roiTypeBG.SelectedObject.String;
                if strcmp(repositionBehavior,'Crop Exactly') && ~isequal(oldReturnedPosition,returnedPosition)
                    % Crop returned image here!
                    topCrop = round(oldReturnedPosition(2)+oldReturnedPosition(4) - (returnedPosition(2)+returnedPosition(4)));
                    bottomEdge = round(topCrop+returnedPosition(4)-0.5);
                    leftCrop = round(returnedPosition(1) - oldReturnedPosition(1));
                    rightEdge = round(leftCrop+returnedPosition(3)-0.5);
                    subImage = subImage(topCrop:bottomEdge,...
                        leftCrop:rightEdge,:);
                end
            case 'stripes'
                temporaryDialog('Not Yet!')
        end
        labelBigImageHndl.Pointer = 'arrow';
    end %retrieveSubImage

    function saveSubimage(varargin)
        % Save current subimage and all ROIs within
        manualSubimageDir = fullfile(BILPrefs.subimageDir,'ManuallyExtracted');
        if ~exist(manualSubimageDir,'dir')
            mkdir(manualSubimageDir);
        end
        nPrevSaved = dir(fullfile(manualSubimageDir,'*.png'));
        nPrevSaved = numel(nPrevSaved);
        thisFname = sprintf('subimage%04i.png',nPrevSaved+1);
        thisFname = fullfile(manualSubimageDir,thisFname);
        imwrite(subImage,thisFname);
        thisFname2 = fullfile(manualSubimageDir,sprintf('subimage%04i_ROIReport.mat',nPrevSaved+1));
        %         currentROIs = findSynchronizedROIs(overviewImageAx,...
        %             {'synchronizedImfreehands','synchronizedImrects'});
%         currentROIs = findSynchronizedROIs(overviewImageAx,...
%             'type',{'synchronizedImfreehands','synchronizedImrects'});
        currentROIs = findSynchronizedROIsCurrentlyInSubimageView;
        outStruct = saveAsStruct(currentROIs,imrefSubImageToOverview);
        visDebug = false;
        if visDebug
            togglefig('This Subimage')
            imshow(subImage);
        end
        for kk = numel(outStruct):-1:1
            if strcmp(outStruct(kk).Class,'imfreehand')
                thisPos = bsxfun(@minus,outStruct(kk).WorldCoordinates,[XSubRange(1),YSubRange(1)]);
            else
                thisPos = outStruct(kk).WorldCoordinates - [XSubRange(1) YSubRange(1) 0 0];
            end
            outStruct(kk).subImageROICoordinates = thisPos;
            if visDebug
                if strcmp(outStruct(kk).Class,'imfreehand')
                    drawfreehand(imgca,'Position',thisPos);
                else
                    drawrectangle(imgca,'Position',thisPos);
                end
            end
        end
        save(thisFname2,'outStruct')
        fprintf('Current subimage (and its ROIs) written to %s, %s.\n',thisFname, thisFname2);
        temporaryDialog('Done!')
    end %saveSubimage

    function saveSession(varargin)
        if ~isSaved
            allSynROIs = generateSessionLog(true,false);
            if ~isempty(allSynROIs)
                if ~exist(BILPrefs.sessionLogDir,'dir')
                    mkdir(BILPrefs.sessionLogDir);
                end
                %cd(BILPrefs.sessionLogDir)
                allSynROIs = structForSaving(allSynROIs);
                allSynROIs(1).filename = imageName;
                save(fullfile(BILPrefs.sessionLogDir,['Saved',datestr(now,30),'.mat']),...
                    'allSynROIs');
                gTruth = groundTruthForSaving(allSynROIs)
                disp(['File ', fullfile(BILPrefs.sessionLogDir,['Saved',datestr(now,30),'.mat']) ' saved.'])
            end
        end
        isSaved = true;
        function allSynROIStruct = structForSaving(allSynROIs)
            for jj = numel(allSynROIs):-1:1
                allSynROIStruct(jj).positions = allSynROIs{jj}.ROI(1).getPosition;
                allSynROIStruct(jj).lineColor = allSynROIs{jj}.lineColor;
                allSynROIStruct(jj).lineStyle = allSynROIs{jj}.lineStyle;
                allSynROIStruct(jj).lineWidth = allSynROIs{jj}.lineWidth;
                allSynROIStruct(jj).userData = allSynROIs{jj}.userData;
                allSynROIStruct(jj).label = allSynROIs{jj}.label;
                allSynROIStruct(jj).score = allSynROIs{jj}.score;
                allSynROIStruct(jj).validated = allSynROIs{jj}.validated;
            end
        end %structForSaving
        
        function gTruth = groundTruthForSaving(infile)
            uniqueLabels = unique({infile.label});
            % Get rid of dashes--they are not supported in groundTruth:
            uniqueLabels = cellfun(@(x) x(x~=45),uniqueLabels,'UniformOutput',false);
            ldc = labelDefinitionCreator()
            for lind = 1:numel(uniqueLabels)
                if size(infile(lind).positions,2) == 4
                    LType = labelType.Rectangle;
                elseif size(infile(lind).positions,2) == 2
                    LType = labelType.Custom;
                else
                    error('labelBigImage: Unsupported label!');
                end
                addLabel(ldc,uniqueLabels{lind},LType)
            end
            gtSource = groundTruthDataSource({imageName});
            names = currentSessionLog.Label;
            for lname = 1:numel(uniqueLabels)
                thisName = uniqueLabels{lname};
               disp(thisName)
            end
            labelData = table(currentSessionLog.Position',...
                'VariableNames',uniqueLabels);
            gTruth = groundTruth(gtSource,create(ldc),labelData)
        end %groundTruthForSaving
        
    end %saveSession

    function thisSynROI = selectByID(requestedID)
        [ID,thisSynROI,thisStr,thisVal,LBString] = getCurrentSynROIInfo;
        for ii = 1:size(LBString,1)
            tmpStr = LBString(ii,:);
            strs = strsplit(tmpStr);
            tmpID = str2double(strs{2});
            if tmpID == requestedID
                val = ii;
                listboxOfSynchronizedROIs.Value = val;
                [ID,thisSynROI,thisStr,thisVal,LBString] = getCurrentSynROIInfo;
                gotoSynROI(thisSynROI);
                return
            end
        end
    end %selectByID

    function selectByLabel(varargin)
        thisStr = listboxOfSynchronizedROIs.String;
        if isempty(thisStr)
            return
        end
        thisStr = thisStr(listboxOfSynchronizedROIs.Value,:);
        if isempty(thisStr)
            return
        elseif size(thisStr,1) > 1
            thisStr = thisStr(1,:);
        end
        strs = strsplit(thisStr);
        currentSelection = strs{1};
        [uniqueLabels,allCurrentLabels] = getLabelsInUse;
        ind = find(strcmp(currentSelection,uniqueLabels));
        %         if isempty(uniqueLabels)
        %             return
        %         end
        tmpFig = figure('Name','Select Label:',...
            'windowstyle','normal',...
            'menubar','none',...
            'units','normalized',...
            'tag','BILTmpFig',...
            'Position',[0.4 0.4 0.2 0.2]);
        lb = uicontrol(tmpFig,...
            'style','listbox',...
            'units','normalized',...
            'position',[0 0 1 1],...
            'string',uniqueLabels,...
            'value',ind,...
            'callback',@labelSelected);
        function labelSelected(varargin)
            requestedLabel = lb.Value;
            delete(findall(groot,'tag','BILTmpFig'))
            requestedLabel = uniqueLabels{requestedLabel};
            vals = ismember(allCurrentLabels,requestedLabel);
            listboxOfSynchronizedROIs.Value = find(vals);
        end
    end %selectByLabel

    function selectTrainingDir(varargin)
        trainingSuperDir = uigetdir(pathToImage,'Select parent directory of training (sub-)images');
        if trainingSuperDir == 0
            return
        end
        trainingIMDS = imageDatastore(trainingSuperDir,...
            'IncludeSubfolders',true,...
            'LabelSource','foldernames');
    end %selectTrainingDir

    function selectTrainedNet(varargin)
        [fn,pn] = uigetfile(fullfile(pathToImage,'TrainedNetworks','*_Net*'));
        if fn == 0
            return
        end
        loaded = load(fullfile(pn,fn));
        trainedNetwork = loaded.net;
        testDS = loaded.testDS;
    end %selectTrainedNet

    function selectTransferLearningNetwork(varargin)
        if isempty(trainingSuperDir)
            temporaryDlg('trainingSuperDir appears to be empty; please (re-)select it and try again!')
            return
        end
        availableForTransferLearning = {...
            'alexnet'
            'googlenet'
            'vgg16'
            'vgg19'
            '****'
            'ALL'
            '****'
            'KerasImport'};
        %'resnet50'
        %'importFromKeras'
        tmpFig = figure('Name','Select Pre-trained Network for TRANSFER LEARNING:',...
            'windowstyle','normal',...
            'menubar','none',...
            'units','normalized',...
            'tag','BILTmpFig',...
            'Position',[0.4 0.4 0.2 0.2]);
        lb = uicontrol(tmpFig,...
            'style','listbox',...
            'units','normalized',...
            'position',[0 0 1 1],...
            'string',availableForTransferLearning,...
            'callback',@tlNetSelected);
        function tlNetSelected(varargin)
            requestedTLNetwork = lb.Value;
            delete(findall(groot,'tag','BILTmpFig'))
            if ~strcmp(requestedTLNetwork,'****')
                requestedTLNetwork = availableForTransferLearning{requestedTLNetwork};
            end
        end
    end %selectTransferLearningNetwork

    function serialAutosegment(varargin)
        if ~segmentThisImage
            segmentThisImage = questdlg('RE-SEGMENT this image?',...
                'Resegment?','YES','No','YES');
            segmentThisImage = strcmp(segmentThisImage,'YES');
        end
        if ~segmentThisImage
            return
        end
        currString = get(processAllTiles,'String');
        if strcmp(currString,'Segment (Included) SubImages')
            set(processAllTiles,...
                'String','CANCEL!',...
                'foregroundcolor','r')
            continueProcessing = true;
        else
            set(processAllTiles,...
                'String','Segment (Included) SubImages',...
                'foregroundcolor','k')
            continueProcessing = false;
        end %if strcmp(currString,'Segment (Included) SubImages')
        save(fullfile(BILPrefs.utilitiesDir,'continueVal.mat'),...
            'continueProcessing','continueProcessing')
        drawnow
        if ~continueProcessing
            set(processAllTiles,...
                'String','Segment (Included) SubImages',...
                'foregroundcolor','k')
            return
        end
        tmpMsgBox = msgbox('Calculating some properties....................................','Please Wait');
        thisOpt = segOptRadio(logical([segOptRadio.Value])).String;
        if thisOpt(end)==':'
            thisOpt = thisOpt(1:end-1);
        end
        autosegOptions = {'Imextended','Threshold','Custom'};
        isAutoseg = ismember(thisOpt,autosegOptions);
        if ~isAutoseg
            beep
            temporaryDialog('Not valid for this segmentation option.')
            return
        end
        %
        if createVideo
            targetName = [thisImageFullFilename,'_Annotated','.mp4'];
            vidWriter = VideoWriter(targetName,'MPEG-4');
            open(vidWriter);
            cycleLayout(2);
            set(findall(labelBigImageHndl,'tag','overviewRegionSelector'),'visible','off')
        end
        
        % ACKLAMIZE (https://www.ee.columbia.edu/~marios/matlab/mtt.pdf)
        % 8.1.4 Create 2D matrix (columns first, column output)
        % Assume you want to create a m*n/q-by-q matrix Y where the submatrices of X are concatenated
        % (columns first) vertically. E.g., if A, B, C and D are p-by-q matrices, convert
        % X = [ A B
        % C D ];
        % into
        % Y = [ A;C;B;D];
        % use
        % Y = reshape( X, [ m q n/q ] );
        % Y = permute( Y, [ 1 3 2 ] );
        % Y = reshape( Y, [ m*n/q q ] );
        %
        % OR:
        %
        % 8.1.6 Create 2D matrix (rows first, column output)
        % Assume you want to create a m*n/q-by-q matrix Y where the submatrices of X are concatenated
        % (rows first) vertically. E.g., if A, B, C and D are p-by-q matrices, convert
        % X = [ A B
        % C D ];
        % into
        % Y = [ A;B;C;D];
        % use
        % Y = reshape( X, [ p m/p q n/q ] );
        % Y = permute( Y, [ 1 4 2 3 ] );
        % Y = reshape( Y, [ m*n/q q ] );
        % where:
        % [m,n] = size(X)
        % p = number of rows per chunk
        % q = number of columns per chunk
        %[m,n] = size(tileMap);
        % q = factor2(n);
        % [~,ind] = min(abs(q/(BILPrefs.initialDisplayAndProcessDimension/tileH)-1));
        % q = q(ind);
        q = floor(BILPrefs.initialDisplayAndProcessDimension/tileH);
        p = floor(BILPrefs.initialDisplayAndProcessDimension/tileW);
        % p = factor2(m);
        % [~,ind] = min(abs(p/(BILPrefs.initialDisplayAndProcessDimension/tileW)-1));
        % p = p(ind);
        tmpTileMap = tileMap(1:floor(size(tileMap,1)/q)*q,1:floor(size(tileMap,2)/p)*p);
        [m,n] = size(tmpTileMap);
        opt = "rowFirst";%"colFirst"
        if opt == "colFirst"
            % TILE BY COL:
            tileChunkMap = reshape( tmpTileMap, [ m q n/q ] );
            tileChunkMap = permute( tileChunkMap, [ 1 3 2 ] );
            tileChunkMap = reshape( tileChunkMap, [ m*n/q q ] );
        else
            % TILE BY ROW:
            tileChunkMap = reshape( tmpTileMap, [ p m/p q n/q] );
            tileChunkMap = permute(tileChunkMap, [ 1 4 2 3]);
            tileChunkMap = reshape( tileChunkMap, [ m*n/q q ] );
        end % if opt == "colFirst"
        %
        if segmentThisImage %Note: this if-then is unnecessary; can't get here unless segmentThisImage is true.
            sensitivityThreshold = sensitivitySlider.Value;
            if strcmp(thisOpt,'Threshold')
                sensitivityThreshold = 1-sensitivityThreshold;
            end
            minSize = minSizeSlider.Value;
            maxSize = maxSizeSlider.Value;
            
            simplifyAmount = get(simplifyAmountSlider,'value');
            SE  = strel('Disk',7,4);
            SE2  = strel('Disk',round(simplifyAmount*50),4);
            maxAreaPct = str2double(maxAreaPercent.String);
            %             [imrefOverview.PixelExtentInWorldX,imrefOverview.PixelExtentInWorldY]
            %
            count = 0;
            iRange = 1:p:size(tileChunkMap,1);
            %
            manualRegions = findall(overviewImageAx,'Tag','ManualProcessRegion');
            % For visualization/debugging:
            visDebug = false;
            if ~isempty(manualRegions)
                processMask = manualRegions(1).createMask;
            else
                if visDebug
                    processMask = true(size(overviewImage(:,:,1)));
                else
                    processMask = [];
                end
            end
            for ii = 2:numel(manualRegions)
                processMask = processMask | manualRegions(ii).createMask;
            end
            if visDebug
                togglefig('Visualize processMask Division') %#ok<*UNRCH>
                imshow(processMask)
                processMaskAx = imgca;
            end
            %
            if strcmp(thisOpt,'Custom')
                customString = customFcnEditBox.String;
                hasAt = contains(customString,'@');
                if ~hasAt
                    warndlg(sprintf('Please put a valid function handle in the edit box below.\n\nFor example:\n\n\t@(img)customFcn(img)\n\n'))
                    labelBigImageHndl.Pointer = 'arrow';
                    drawnow;
                    return
                end
                fcnHandle = str2func(customFcnEditBox.String);
                % Parse for syntax:
                inArgs = regexp(customString,'\w*','match');
                addlArgs = inArgs(1:floor(numel(inArgs)/2));
                fcnArg = inArgs{ceil(numel(inArgs)/2)};
                if ~exist(fcnArg,'file')
                    temporaryDialog('Specified function was not found on the path!',3)
                    labelBigImageHndl.Pointer = 'arrow';
                    drawnow;
                    return
                end
            end
            tic;
            %
            iRange = reshape(iRange,1,[]);%Ensure row vector
            processSize = round(size(overviewImage(:,:,1))./(size(tmpTileMap)./[q,p]));
            %
            % PRECOMPUTE:
            [allULTiles,allLRTiles,allcULs,allrULs,allcLRs,allrLRs,allAs,allBs] = deal(nan(numel(iRange),1));
            toProcess = false(1,numel(iRange));
            allOldReturnedPositions = nan(numel(iRange),4);
            allSubImageTiles = cell(numel(iRange),1);
            ind = 1;
            for ii = iRange
                %                 subImage = retrieveSubImage(storedSubImageTiles);
                %                 displaySubImage(storedReturnedPosition,subImage,storedXSubRange,storedYSubRange)
                %                 overviewRegionSelector.setPosition(storedReturnedPosition)
                %                 moveRegion(overviewRegionSelector)
                %                 overviewRegionSelector.setPosition(storedReturnedPosition)
                
                allSubImageTiles{ind} = tileChunkMap(ii:ii + p - 1, :);
                allULTiles(ind) = min(allSubImageTiles{ind}(:));
                allLRTiles(ind) = max(allSubImageTiles{ind}(:));
                [allcULs(ind), allrULs(ind)] = find(tileMap == allULTiles(ind));
                [allcLRs(ind), allrLRs(ind)] = find(tileMap == allLRTiles(ind));
                [xsr, ysr] = getFullTileSubRanges(...
                    allcULs(ind),allcLRs(ind),allrULs(ind),allrLRs(ind));
                [allAs(ind),allBs(ind)] = worldToIntrinsic(imrefOverview,xsr(1),ysr(1));
                if ~isempty(processMask)
                    %processMaskSubimage = imcrop(processMask,[a,b,60,60]);
                    processMaskSubimage = imcrop(processMask,...
                        [allAs(ind),allBs(ind),processSize(1),processSize(2)]);
                    overlapOption = BILPrefs.processRegionsOption; %{'ANY','ALL'}
                    switch overlapOption
                        case 'ANY: Tiles with Any ROI Overlap'
                            %NOTE: This is for processing all blocks with ANY
                            %overlap with the selected processMask:
                            toProcess(ind) = any(processMaskSubimage(:));
                        case 'ALL: Tiles Entirely Within Region'
                            %ALTERNATIVELY: This is for processing all blocks
                            %ENTIRELY CONTAINED in the selected processMask:
                            toProcess(ind) = all(processMaskSubimage(:));
                    end
                else
                    toProcess(ind) = true;
                end
                if toProcess(ind)
                    %tmpPosition = [xsr(1) ysr(1) max(xsr)-min(xsr) max(ysr)-min(ysr)];
                    allOldReturnedPositions(ind,:) = [xsr(1) ysr(1) max(xsr)-min(xsr) max(ysr)-min(ysr)];
                    %allOldReturnedPositions(ind,:) = [xsr(1) ysr(1) max(xsr)-min(xsr) max(ysr)-min(ysr)];
                end
                ind = ind + 1;
            end %for ii = iRange
            %NOW PARE:
            allULTiles = allULTiles(toProcess);
            allLRTiles = allLRTiles(toProcess);
            allcULs = allcULs(toProcess);
            allrULs = allrULs(toProcess);
            allcLRs = allcLRs(toProcess);
            allrLRs = allrLRs(toProcess);
            allAs = allAs(toProcess);
            allBs = allBs(toProcess);
            allSubImageTiles = allSubImageTiles(toProcess);
            allOldReturnedPositions = allOldReturnedPositions(toProcess,:);
            if isvalid(tmpMsgBox)
                close(tmpMsgBox);
            end
            iRange = iRange(toProcess);
            nSteps = numel(iRange);
            tmp = questdlg({'This will automatically break the image into',...
                ' ',...
                [num2str(nSteps) ' full-resolution ' num2str(p*tileH) ' x ' num2str(q*tileW) ' subImages,'],...
                ' ',...
                'that AT LEAST PARTLY INTERSECT with the process region(s), and process them sequentially. It could take several minutes. Do you want to CONTINUE?'},...
                'Continue?',...
                'YES','No','YES');
            if ~strcmp(tmp,'YES')
                set(processAllTiles,...
                    'String','Segment (Included) SubImages',...
                    'foregroundcolor','k')
                return
            end
            %%
            for ii = 1:numel(iRange)%for ii = iRange
                %%% Recover states for each ii:
                thisVal = iRange(ii);
                subImageTiles = allSubImageTiles{ii};
                oldReturnedPosition = allOldReturnedPositions(ii,:);
                cUL = allcULs(ii);
                cLR = allcLRs(ii);
                rUL = allrULs(ii);
                rLR = allrLRs(ii);
                [XSubRange,YSubRange] = getFullTileSubRanges(cUL,cLR,rUL,rLR);
                %returnedPosition  = [XSubRange(1) YSubRange(1) max(XSubRange)-min(XSubRange) max(YSubRange)-min(YSubRange)];
                a = allAs(ii);
                b = allBs(ii);
                %%%
                cp = load(fullfile(BILPrefs.utilitiesDir,'continueVal.mat'));
                continueProcessing = cp.continueProcessing;
                if ~continueProcessing
                    break
                end
                %                 if ~ismember(c1(ii),x)
                %                     ind = ind + 1;
                %                     continue
                %                 end
                %Count tracks the number of regions processed
                count = count + 1;
                subImage = readTiles(subImageTiles);
                if 1
                    %h = rectangle(overviewImageAx, 'Position', oldReturnedPosition(ii,:),...
                    h = rectangle(overviewImageAx, 'Position', oldReturnedPosition,...
                        'tag', 'tmpAnnotation',...
                        'LineStyle', ':',...
                        'PickableParts', 'none',...
                        'EdgeColor', 0.2*[1 1 1]);
                    if visDebug
                        %togglefig('Visualize processMask Division')
                        drawrectangle(processMaskAx,'position',...
                            [a b processSize])
                    end
                end
                drawnow;
                %
                if size(subImage,3) ~= 1
                    gray = rgb2gray(subImage);
                else
                    gray = subImage;
                end
                %
                switch thisOpt
                    case 'Imextended'
                        findDark = imextendedDirection.Value == 1;
                        if findDark
                            mask = imextendedmin(im2double(gray),...
                                sensitivityThreshold,8);
                        else
                            mask = imextendedmax(im2double(gray),...
                                sensitivityThreshold,8);
                        end
                    case 'Threshold'
                        % FIX: 05/21/19 sensitivityThreshold is backwards
                        % for threshold operation. Increasing sensitivity
                        % should increase the detection likelihood.
                        findDark = thresholdPolarity.Value == 1;
                        if findDark
                            mask = imbinarize(imcomplement(gray),sensitivityThreshold);
                        else
                            mask = imbinarize(gray,sensitivityThreshold);
                        end %if findDark
                    case 'Custom'
                        fcnHandle = str2func(customFcnEditBox.String);
     
                        mask = fcnHandle(subImage,addlArgs{2:end});
                        if isa(mask,'struct')
                            % Non-Image return; treat specially
                            labelBigImageHndl.Pointer = 'arrow';
                            returnedPosition  = [XSubRange(1) YSubRange(1) max(XSubRange)-min(XSubRange) max(YSubRange)-min(YSubRange)];
                            imrefSubImageToOverview = imref2d(size(subImage),...
                                [returnedPosition(1) returnedPosition(1)+returnedPosition(3)],...
                                [returnedPosition(2) returnedPosition(2)+returnedPosition(4)]);
                            
                            displayParameters.returnedPosition = returnedPosition;
                            displayParameters.subImageTiles = subImageTiles;
                            displayParameters.XSubRange = XSubRange;
                            displayParameters.YSubRange = YSubRange;

                            
                            
                            parseDetectorOutputStruct(mask);
                            continue
                        end
                        score = 0.8; %Default for custom
                        
                        %%%
                        for kkk = 1:numel(mask.Labels)
                            posn = mask.Boxes(kkk,:);
                            posn = [posn(1) + oldReturnedPosition(1), posn(2) + oldReturnedPosition(2), posn(3:4)];
                            % [x1,y1] = worldToIntrinsic(imrefSubImageToOverview,posn(1),posn(2));
                            % posn = [x1,y1,posn(3:4)];
                            tmpRect = imrect(overviewImageAx,posn);
                            synROI = constructRectSynROI(tmpRect,char(mask.Labels(1)));
                            delete(tmpRect)
                        end %for kkk = 1:numel(mask.Labels)
                        %%%
                end %switch thisOpt
                if ~isa(mask,'struct')
                    % (If struct, using a custom detector output; skip paring
                    mask = imclose(mask, SE);
                    if simplifyAmount ~= 0
                        mask = imopen(mask, SE2);
                    end
                    minS = round(minSize/mean([imrefOverview.PixelExtentInWorldX,imrefOverview.PixelExtentInWorldY]));
                    maxS = round(maxSize/mean([imrefOverview.PixelExtentInWorldX,imrefOverview.PixelExtentInWorldY]));
                    if parentAx == overviewImageAx
                        maxS = max(maxS,minS);
                        mask = bwpropfilt(mask, 'Area', [minS, maxS]);
                    else
                        maxSize = max(maxSize,minSize);
                        mask = bwpropfilt(mask, 'Area', [minSize, maxSize]);
                    end
                    numNonZeros = nnz(mask);
                    if numNonZeros > 0 && numNonZeros <= maxAreaPct*numel(mask)
                        displayParameters.returnedPosition = oldReturnedPosition;
                        displayParameters.subImageTiles = subImageTiles;
                        displayParameters.XSubRange = XSubRange;
                        displayParameters.YSubRange = YSubRange;
                        synchronizedFreehandROIsFromMask(mask, 0, ...
                            oldReturnedPosition(1:2),defaultAutoSegLabel,true)%No-Regions warning off
                    end
                end %if ~isa(mask,'struct')
                drawnow
                %end
                %
                if createVideo
                    annotatedFrame = getframe(overviewImageAx);
                    drawnow
                    writeVideo(vidWriter, annotatedFrame);
                end
                tFrame = toc;
            end %for ii = iRange
            for mr = 1:numel(manualRegions)
                set(manualRegions(mr),'FaceAlpha',0,'Color','y',...
                    'Waypoints',false(size(manualRegions(mr).Waypoints)));
            end
            set(processAllTiles,...
                'String', 'Segment (Included) SubImages',...
                'foregroundcolor', 'k')
            segmentThisImage = false;
            tAllSubregions = toc;
            disp(tAllSubregions)
        end %if segmentThisImage
        tAll = toc;
        fprintf('DONE! Processed %i subregions in %0.2f minutes.\n',count,tAll/60);
        if createVideo
            close(vidWriter)
            set(findall(labelBigImageHndl,'tag','overviewRegionSelector'),...
                'visible','on')
        end
        delete(findall(overviewImageAx,'tag','tmpAnnotation'))
        % 		end
        isSaved = false;
        % NOTE: The per-frame processing time appears to remain relatively
        % constant throughout a serial run...roughly 1 second per frame,
        % PLUS 0.8 seconds PER ROI DETECTION (on Brett's computer). The
        % perceived slowdown does not seem to reflect a memory
        % issue--rather, it slows down in the "busy" parts of the image.
    end %serialAutosegment

    function setLabelColor(thisSynROI,clr)
        thisSynROI.backgroundColor = clr;
    end %setLabelColor

%     function setLineColor(thisSynROI)
%         % This sets the line color, not the background color
%         % Note that I was managing validated flag from here, but I changed
%         % to managing that flag through validateROIs and validateCurrentROI
%         thisLabel = thisSynROI.label;
%         thisColor = allColors(strcmp(thisLabel,lockedOrderLabels),:);
%         if isempty(thisColor)
%             thisColor = allColors(numel(lockedOrderLabels)+1,:);
%         end
%         thisSynROI.lineColor = thisColor;
%         if ~thisSynROI.validated
%             setLabelColor(thisSynROI,'y');%[0.85 0.85 0]);
%         end
%     end %setLineColor

    function setPreviousSelection(obj,varargin)
        previousSelection = obj.AffectedObject.Value;
    end %setPrevVal

    function BILPrefs = setupEnvironment(varargin)
        BILDir = fullfile(userpath,'labelBigImage');
        if ~exist(BILDir,'dir')
            mkdir(BILDir)
        end
        % Session Logs
        sessionLogDir = fullfile(BILDir,'SessionLogs');
        if ~exist(sessionLogDir,'dir')
            mkdir(sessionLogDir)
        end
        % Utilities:
        utilitiesDir = fullfile(BILDir,'Utilities');
        if ~exist(utilitiesDir,'dir')
            mkdir(utilitiesDir);
        end
        % Image Chips:
        imageChipDir = fullfile(BILDir,'ImageChips');
        if ~exist(imageChipDir,'dir')
            mkdir(imageChipDir);
        end
        % Subimages:
        subimageDir = fullfile(BILDir,'Subimages');
        if ~exist(subimageDir,'dir')
            mkdir(subimageDir);
        end
        % Ground Truth Objects (NOTE: Not currently used):
        groundTruthDir = fullfile(BILDir,'GroundTruth');
        if ~exist(groundTruthDir,'dir')
            mkdir(groundTruthDir);
        end
        %
        % AutoDetectors:
        autoDetectorDir = fullfile(BILDir,'AutoDetectors');
        if ~exist(autoDetectorDir,'dir')
            mkdir(autoDetectorDir);
        end
        %
        addpath(genpath(fullfile(userpath,'labelBigImage')));
        %
        BILPrefsFile = fullfile(userpath,'labelBigImage','labelBigImagePrefs.mat');
        validBILPrefsExists = exist(BILPrefsFile,'file');
        if validBILPrefsExists
            BILPrefs = load(BILPrefsFile);
            BILPrefs = BILPrefs.BILPrefs;
        else
            % Multi-session Label List:
            multiSessionLabelList = fullfile(utilitiesDir,...
                'multiSessionLabels.mat');
            % FORCE (RE-)INITIALIZATION OF LABELS IF BILImageLabelerPrefs
            % DOES NOT EXIST!
            currentSessionLabels = {defaultAutoSegLabel};
            tmp = 'YES';
            if exist(multiSessionLabelList,'file')
                tmp = questdlg({'A cross-session label list exists on this computer.',...
                    'Do you want to reset it?',...
                    ' ',...
                    '(This is safe and will not affect any previous labeling sessions,',...
                    'but your label history will be unavailable if you select',...
                    '''useMultiSessionLabels'',true in the call to labelBigImage.)'},...
                    'RESET EXISTING MULTI-SESSION LABEL LIST?',...
                    'YES','No','YES');
            end
            if strcmp(tmp,'YES')
                save(multiSessionLabelList,'currentSessionLabels')
            end
            save(fullfile(utilitiesDir,'currentSessionLabels.mat'),...
                'currentSessionLabels');
            % Defaults:
            BILPrefs.drawType = 'freehand';
            BILPrefs.initialDisplayAndProcessDimension = 2000;
            BILPrefs.multiSessionLabelList = multiSessionLabelList;
            BILPrefs.minSize = 5000;
            BILPrefs.maxSize = 1e10;
            BILPrefs.sensitivity = 0.6;
            BILPrefs.sessionLogDir = sessionLogDir;
            BILPrefs.simplifyAmount = 0;
            BILPrefs.labelPosition = 'Center';
            BILPrefs.processRegionsOption = 'ANY: Tiles with Any ROI Overlap';
            BILPrefs.showSplash = true;
            %
        end %if validBILPrefsExists
        BILPrefs.BILDir = BILDir;
        BILPrefs.groundTruthDir = groundTruthDir;
        BILPrefs.imageChipDir = imageChipDir;
        BILPrefs.subimageDir = subimageDir;
        BILPrefs.utilitiesDir = utilitiesDir;
        BILPrefs.autoDetectorDir = autoDetectorDir;
        save(fullfile(BILPrefs.BILDir,'labelBigImagePrefs.mat'),'BILPrefs');
    end %setupEnvironment

    function setupMenus(varargin)
        %
        f = uimenu(labelBigImageHndl,'Label','FILE');
        uimenu(f,'Label','Import New Image','callback',@getFile);
        uimenu(f,'Label','Recall Previous Session','callback',@recallSession);
        uimenu(f,'Label','Save Session Now','callback',@saveSession);
        %
        %f = uimenu(labelBigImageHndl,'Label','SAVE/EXTRACT');
        saveSubimageMenu = uimenu(f,'Label','Save Current Subimage',...
            'callback',@saveSubimage);
        %
        f = uimenu(labelBigImageHndl,'Label','CONVERSIONS');
        originalImageMenu = uimenu(f,'Label','Reset to Original Image','callback',{@convertImage,'Original'});
        complementImageMenu = uimenu(f,'Label','Complement Image','callback',{@convertImage,'Complement'});
        medfiltImageMenu = uimenu(f,'Label','Medfilt(I,[9 9])','callback',{@convertImage,'Medfilt'});
        colorspaceConversionMenu(1) = uimenu(f,'Label','...to Grayscale','callback',{@convertImage,'Gray'},...
            'separator','on');
        colorspaceConversionMenu(2) = uimenu(f,'Label','...to HSV','callback',{@convertImage,'HSV'});
        colorspaceConversionMenu(3) = uimenu(f,'Label','...to L*A*B*','callback',{@convertImage,'LAB'});
        colorspaceConversionMenu(4) = uimenu(f,'Label','...Decorrelation Stretch','callback',{@convertImage,'Decorrstretch'});
        %
        f = uimenu(labelBigImageHndl,'Label','EXISTING LABELS');
        uimenu(f,'Label','Export Labels','callback',@exportLabels);
        uimenu(f,'Label','Import and Display Labels','callback',@importDisplayLabels);
        %
%         f = uimenu(labelBigImageHndl,'Label','AUTO-TRAIN DETECTOR');
%         uimenu(f,'Label','Fast Image Classifier','callback',@autoTrain);
%         %NOTE: tooltips not supported for uimenus on figures created with
%         %the figure function.
%         uimenu(f,'Label','ACF Object Detector','callback',@autoTrain);
%         uimenu(f,'Label','RCNN','callback',@autoTrain);
%         uimenu(f,'Label','YOLO v2','callback',@autoTrain);
        %
        f = uimenu(labelBigImageHndl,'Label','SHORTCUTS');
        uimenu(f,...
            'Label','Toggle Zoom',...
            'checked','off',...
            'tag','Toggle Zoom',...
            'accelerator','z',...
            'callback',@(varargin)zoom);
        uimenu(f,...
            'Label','Toggle Pan',...
            'checked','off',...
            'tag','Toggle Pan',...
            'accelerator','p',...
            'callback',@(varargin)pan);
        uimenu(f,...
            'Label','Toggle zoomToCurrent',...
            'checked','off',...
            'tag','Toggle zoomToCurrent',...
            'accelerator','e',...% Examine/Edit
            'callback',@(varargin)zoomToCurrent(varargin));
        uimenu(f,...
            'Label','Next (validation)',...
            'checked','off',...
            'tag','Evaluate/Edit Next ROI',...
            'accelerator','n',...% Examine/Edit
            'callback',@(varargin)nextValidation(varargin));
        uimenu(f,...
            'Label','Validate Currently Selected ROI',...
            'checked','off',...
            'tag','Validate Currently Selected ROI',...
            'accelerator','V',...% Examine/Edit
            'callback',@(varargin)validateCurrentROI(varargin,'Manual'));
        %
        f = uimenu(labelBigImageHndl,'Label','OPTIONS');
        uimenu(f,'Label','Disable Tooltips','checked','off',...
            'tag','DisableTooltips','callback',@(obj,~)disableReenableTooltips(obj));
        % BILPrefs.LabelPosition
        f2 = uimenu(f,'Label','Label Position','checked','off');
        labelPref(1) = uimenu(f2,...
            'Label','Top',...
            'checked','off',...
            'tag','ChangeLabelPosition',...
            'callback',@(varargin)changeLabelPosition(varargin));
        labelPref(2) = uimenu(f2,...
            'Label','Center',...
            'checked','off',...
            'tag','ChangeLabelPosition',...
            'callback',@(varargin)changeLabelPosition(varargin));
        labelPref(3) = uimenu(f2,...
            'Label','Bottom',...
            'checked','off',...
            'tag','ChangeLabelPosition',...
            'callback',@(varargin)changeLabelPosition(varargin));
        set(labelPref(strcmp(BILPrefs.labelPosition,{'Top','Center','Bottom'})),...
            'checked','on')
        %BILPrefs.processRegionsOption
        f2 = uimenu(f,'Label','Process-Regions','checked','off');
        processRegionsOpt(1) = uimenu(f2,...
            'Label','ANY: Tiles with Any ROI Overlap',...
            'checked','off',...
            'tag','changeProcessRegionsOpt',...
            'callback',@(varargin)changeProcessRegionsOpt(varargin));
        processRegionsOpt(2) = uimenu(f2,...
            'Label','ALL: Tiles Entirely Within Region',...
            'checked','off',...
            'tag','changeProcessRegionsOpt',...
            'callback',@(varargin)changeProcessRegionsOpt(varargin));
        set(processRegionsOpt(strcmp(BILPrefs.processRegionsOption,...
            {'ANY: Tiles with Any ROI Overlap','ALL: Tiles Entirely Within Region'})),...
            'checked','on')
        f = uimenu(labelBigImageHndl,'Label','VALIDATION');
        uimenu(f,'Label','Enable Validation','checked','off',...
            'tag','enableValidation','callback',@(obj,~)enableValidation(obj));
        validateAll = uimenu(f,'Label','Validate All','checked','on',...
            'tag','skipUnvalidated','callback',@(obj,~)toggleValidationOption(obj),...
            'separator','on');
        skipValidated = uimenu(f,'Label','Skip Validated','checked','off',...
            'tag','skipValidated','callback',@(obj,~)toggleValidationOption(obj));
        skipUnvalidated = uimenu(f,'Label','Skip Unvalidated','checked','off',...
            'tag','skipUnvalidated','callback',@(obj,~)toggleValidationOption(obj));
        uimenu(f,'Label','UN-Validate Selected','checked','off',...
            'tag','unValidate','callback',@(obj,~)unValidate(obj),...
            'separator','on');
        uimenu(f,...
            'Label','Next (validation)',...
            'checked','off',...
            'tag','Evaluate/Edit Next ROI',...
            'accelerator','n',...% Examine/Edit
            'callback',@(varargin)nextValidation(varargin));
    end %setupMenus

    function showButtonVisibility(varargin)
        showLabelsVal = [showLabelsCheckbox.Value];
        if showLabelsVal(1)
            set(findall(overviewImageAx,'tag','labelButton'),...labelBigImageHndl
                'visible','on')
        else
            set(findall(overviewImageAx,'tag','labelButton'),...labelBigImageHndl
                'visible','off')
        end
        if showLabelsVal(2)
            set(findall(subImageAx,'tag','labelButton'),...labelBigImageHndl
                'visible','on')
        else
            set(findall(subImageAx,'tag','labelButton'),...labelBigImageHndl
                'visible','off')
        end
    end %showButtonVisibility

    function showCurrentSynROI(obj,varargin)
        newVal = setdiff(obj.Value,previousSelection);
        if isempty(newVal)
            return
        end
        [IDs,synROIs,strs,vals,LBString] = getCurrentSelection;
        if numel(IDs) ~= 1
            return
        end
        ID = IDs;
        thisSynROI = synROIs{1};
        if ~isvalid(thisSynROI.activeROI)
            % Moved from current view; object has been deleted
            return
        end
        cLw = thisSynROI.lineWidth;
        cLc = thisSynROI.lineColor;
        bgc = thisSynROI.labelButtons(1).BackgroundColor;
        thisSynROI.lineWidth = 8;
        thisSynROI.labelButtons(2).BackgroundColor = 'r';
        pause(0.25)
        thisSynROI.lineWidth = cLw;
        thisSynROI.lineColor = cLc;
        thisSynROI.labelButtons(2).BackgroundColor = bgc;
    end %showCurrentSynROI

    function sortListbox(type)
        currString = listboxOfSynchronizedROIs.String;
        switch type
            case 'label'
                [sorted,ind] = sort(string(currString));
                if ind(1) ~= 1
                    listboxOfSynchronizedROIs.String = char(sorted);
                else
                    listboxOfSynchronizedROIs.String = char(flipud(sorted));
                end
            case 'ID'
                inds = zeros(size(currString,1),1);
                for ii = 1:numel(inds)
                    thisString = currString(ii,:);
                    tmp = strsplit(thisString);
                    thisInd = str2double(tmp{2});
                    inds(ii) = thisInd;
                end
                [~,ind] = sort(inds);
                if inds(ind(1)) == inds(1)
                    listboxOfSynchronizedROIs.String = flipud(currString(ind,:));
                else
                    listboxOfSynchronizedROIs.String = currString(ind,:);
                end
        end
    end %sortListbox

    function synchronizedFreehandROIsFromMask(mask,parentAx,offset,label,warnoff,score)
        if nargin < 6
            score = 0.333;
        end
        if nargin < 5
            warnoff = false;
        end
        if nnz(mask) == 0
            if ~warnoff
                temporaryDialog('No valid regions with these settings!',3)
            end
            return
        end
        if nargin < 3 || isempty(offset)
            offset = [0 0];
        end
        minSize = minSizeSlider.Value;
        maxSize = maxSizeSlider.Value;
        allowHoles = get(allowHolesCheckbox,'value');
        %allowHoles = true;
        % NOTE: This needs work (and pondering)
        if allowHoles
            B = bwboundaries(mask);
        else
            B = bwboundaries(mask,'noholes');
        end
        % size(B) reflects the size of the boundary, not the number of
        % pixels in the region!
        %         sizes = cellfun(@(x) size(x,1),B);
        %         B = B(sizes>=minSize);
        cxl = overviewImageAx.XLim;
        cyl = overviewImageAx.YLim;
        %maxJaccard = str2double(maxOverlapEdit.String)
        
        %[M,N] = size(mask);
        %          N = xlim;
        %          N = round(N(2));
        %          M = ylim;
        %          M = round(M(2));
        maxAreaPct = str2double(maxAreaPercent.String);
        
        for k = 1:length(B)
            cancelRequest = load(fullfile(BILPrefs.utilitiesDir,'cancelRequest.mat'));
            cancelRequest = cancelRequest.cancelRequest;
            if cancelRequest
                break
            end
            boundary = B{k};
            if parentAx == subImageAx
                [boundaryx,boundaryy] = intrinsicToWorld(imrefSubImageToOverview,boundary(:,2),boundary(:,1));
            elseif parentAx == overviewImageAx
                [boundaryx,boundaryy] = intrinsicToWorld(imrefOverview,boundary(:,2),boundary(:,1));
            else % 0: segmentAll
                boundaryx = boundary(:,2)+offset(1);
                boundaryy = boundary(:,1)+offset(2);
            end
            
            %             tmpMask = poly2mask(boundaryx,boundaryy,M,N);
            %
            %             if nnz(tmpMask) > maxAreaPct * numel(mask)
            %                 continue
            %             end
            
            if parentAx == overviewImageAx || parentAx == 0
                tmpROI = imfreehand(overviewImageAx,[boundaryx,boundaryy]);
                % Note: I should be able to compute this without creating a
                % new mask. Given:
                % posn = tmp.getPosition;
                % %
                % posn(:,1) == boundaryx, and posn(:,2) == boundaryy
                % so why is poly2mask(bounaryx,boundaryy,M,N) ~= tmpMask???
                
                tmpMask = tmpROI.createMask;
                %tmpMask2 = poly2mask(boundaryx,boundaryy,M,N);
                %isequal(tmpMask,tmpMask2)
                
                if nnz(tmpMask)/numel(tmpMask) > maxAreaPct
                    delete(tmp)
                    continue
                end
            else
                tmpROI = imfreehand(subImageAx,[boundaryx,boundaryy]);
            end
            %
            constructFreehandSynROI(tmpROI,label,score,[]);
            % NOTE: killing tmp here causes problems downstream with the
            % synROI based on it!
            overviewImageAx.XLim = cxl;
            overviewImageAx.YLim = cyl;
            drawnow;
        end
    end %synchronizedFreehandROIsFromMask

    function temporaryDialog(str,duration)
        if nargin < 2
            duration = 3;
        end
        boxw = 0.3+(size(str,2)>50)*0.1;
        %         tmp = dialog('Units','normalized',...
        %             'Position',[(1-boxw)/2 0.4 boxw 0.1*size(str,1)],...
        %             'Name','(This box will auto-close)');
        tmp = msgbox(str,'(This box will auto-close)','help');
        set(tmp,'units','normalized',...
            'Position',[(1-boxw)/2 0.4 boxw 0.1*size(str,1)])
        %         uicontrol('Parent',tmp,...
        %             'Style','text',...
        %             'Fontsize',11,...
        %             'Units','normalized',...
        %             'Position',[0.05 0.05 0.9 0.6],...
        %             'String',str);
        % currentEnable = disableReenableUIs();
        pause(duration)
        %disableReenableUIs(currentEnable);
        if isvalid(tmp)
            close(tmp)
        end
        drawnow; %Will this fix bug re: multiple repeated calls from uislider???
    end %temporaryDialog

    function testTrainedNetwork(varargin)
        if isempty(trainedNetwork)
            temporaryDlg('Please select a trained Network first!')
            return
        end
        if isempty(testDS)
            tmp = questdlg(sprintf('Your test imageDatastore hasn''t been set!\nWould you like to create it from the trainingIMDS?\n\n(Note: it may include some images used for training.)'),...
                'Create testIMDS?','Yes, Create it!', 'Cancel','Yes, Create it!');
            if ~strmcp(tmp,'Yes, Create it!')
                return
            end
        end
        labelCounts = testDS.countEachLabel;
        minSetSize = min(labelCounts.Count);
        disp(labelCounts)
        tmp = questdlg(sprintf('The smallest group contains %i test images. (See Command Window).\nIt is recommended that you use the LARGEST BALANCED SET (%i for each test group).\nAlternatively, you can use ALL test images (noting that the test sets may be unbalanced),\nor you can specify a DIFFERENT NUMBER for each set.\n\n',minSetSize,minSetSize),...
            'Split Test Data?','USE LARGEST BALANCED SET','Use All Test Images','Other Amount','USE LARGEST BALANCED SET');
        if isempty(tmp)
            return
        end
        if strcmp(tmp,'USE LARGEST BALANCED SET')
            testDSToEval = testDS.splitEachLabel(minSetSize);
        elseif strcmp(tmp,'Other Amount')
            tmp = inf;
            while tmp > minSetSize
                tmp = inputdlg('How many of each test image class do you want to use?');
                if isempty(tmp)
                    return
                end
                tmp = str2double(tmp);
            end
            testDSToEval = testDS.splitEachLabel(tmp);
        else
            testDSToEval = testDS;
        end
        tic
        [labels,~] = classify(trainedNetwork, testDSToEval, 'MiniBatchSize', 16);
        toc
        tbl = testDSToEval.countEachLabel;
        nClasses = height(tbl);
        t = zeros(nClasses,length(labels));
        y = t;
        for ii = 1:nClasses
            y(ii,:) = labels == tbl.Label(ii);
            t(ii,:) = testDSToEval.Labels == tbl.Label(ii);
        end
        togglefig('Confusion Matrix')
        cm = plotconfusion(t,y);
        cma = findall(cm,'type','axes');
        cma.XTickLabel = [string(tbl.Label);""];
        cma.YTickLabel = [string(tbl.Label);""];
    end %testTrainedNetwork

    function toggleAutoSave(obj,~,varargin)
        tfa = timerfindall('tag','labelBigImageAutoSave');
        isAutoSaving = ~isempty(tfa) && strcmp(tfa.Running,'on');
        %
        autoSaveOn = get(obj,'value');
        if autoSaveOn
            if ~isAutoSaving
                temporaryDialog('Auto-Save timer is active!',2)
                periodMinutes = 10; %minutes
                periodSeconds = periodMinutes*60;
                timerobj = timer('timerfcn',@saveSession,...
                    'period',periodSeconds,...
                    'tag','labelBigImageAutoSave',...
                    'executionmode','fixedrate');%singleShot
                start(timerobj);
            end
        else
            if isAutoSaving
                tfa = timerfindall('tag','labelBigImageAutoSave');
                if ~isempty(tfa)
                    temporaryDialog('Stopping Auto-Save timer')
                    stop(tfa);
                    delete(tfa);
                end
            end
        end
    end %toggleAutoSave

    function toggleValidationOption(obj,varargin)
        set([validateAll,skipValidated,skipUnvalidated],'checked','off')
        obj.Checked = 'on';
        validationOption = obj.Text;
    end %toggleValidationOption

    function trainTransferLearningNetwork(varargin)
        if isempty(requestedTLNetwork)
            temporaryDlg('requestedTLNetwork appears to be empty; please (re-)select it and try again!')
            return
        end
        if isempty(trainingIMDS)
            temporaryDlg('trainingIMDS appears to be empty; please (re-)generate it and try again!')
            return
        end
        %         availableForTransferLearning = {...
        %             'alexnet'
        %             'googlenet'
        %             'vgg16'
        %             'vgg19'
        %             'ALL'};
        tmp = questdlg('Train using MATLAB or TensorFlow?','Training Environment?',...
            'MATLAB','TensorFlow','MATLAB');
        if strcmp(tmp,'TensorFlow')
            temporaryDlg('NOT YET!')
            return
        end
        switch requestedTLNetwork
            case 'alexnet'
                [net,testDS] = retrainAlexnet(trainingIMDS,'writeLocation',pathToImage); %#ok<*ASGLU>
            case 'googlenet'
                [net,testDS] = retrainGooglenet(trainingIMDS,'writeLocation',pathToImage);
            case 'vgg16'
                [net,testDS] = retrainVGG16(trainingIMDS,'writeLocation',pathToImage);
            case 'vgg19'
                [net,testDS] = retrainVGG19(trainingIMDS,'writeLocation',pathToImage);
            case 'ALL'
                temporaryDialog('NOT YET')
        end
    end %trainTransferLearningNetwork

    function unValidate(varargin)
        [IDs,synROIs,strs,vals,LBString] = getCurrentSelection;
        %allSynROI = findSynchronizedROIsCurrentlyInSubimageView;
        for ii = 1:numel(synROIs)
            setLabelColor(synROIs{ii},'y');%[0.85 0.85 0]);
            synROIs{ii}.validated = false;
        end
    end %unValidate

    function updateAxesTicks()
        set(subImageAx,...
            'xtickmode','auto',...
            'ytickmode','auto',...
            'yTickLabelRotation',45);
        set(subImageAx,...
            'xticklabel',get(subImageAx,'xtick')',...
            'yticklabel',get(subImageAx,'ytick')');
    end %updateAxesTicks

    function updateLabelCount(varargin)
        set(nROIsEdit,'string',size(listboxOfSynchronizedROIs.String,1));
    end %updateLabelCount

    function validateCurrentROI(varargin)
        opt = '';
        if nargin > 1
            opt = varargin{2};
        end
        if ~operatorIsValidator && strcmp(opt,'Manual')
            msg = sprintf('This option is only available if current user is a validator!\n(See ''Enable Validation'' under ''Validation'' Toolbar.)');
            temporaryDialog(msg)
            return
        end
        [IDs,synROIs,strs,vals,LBString] = getCurrentSelection;
        if numel(IDs) ~= 1
            temporaryDialog('Select a single ROI for this option!');
            return
        end
        thisSynROI = synROIs{1};
        %setLineColor(thisSynROI);
        setLabelColor(thisSynROI,[0 0.7 0]);
        if operatorIsValidator
            thisSynROI.validated = true;
        end
    end %validateCurrentROI
    
    function validateROIs(varargin)
        allSynROI = findSynchronizedROIsCurrentlyInSubimageView;
        for ii = 1:numel(allSynROI)
            %setLineColor(allSynROI{ii});
            setLabelColor(allSynROI{ii},[0 0.7 0]);
            allSynROI{ii}.validated = true;
        end
    end %validateROIs

    function zoomToCurrent(varargin)
        if nargin > 0 && isa(varargin{1},'synchronizedROI')
            thisSynROI = varargin{1};
        else
            % Called by menu selection
            isZoomed = ~isZoomed;
            [ID,thisSynROI] = getCurrentSynROIInfo;
        end
        UD = thisSynROI.userData;
        if isZoomed
            pos = vertToPos(thisSynROI.ROIPositions{1});
            %pos = thisSynROI.boundingBox; %NOT UPDATING!!! todo BDS
            padval = 10;
            if isempty(currentZoomPosition) || ...
                    ( ischar(currentZoomPosition) && strcmp(currentZoomPosition,'Reset') )
                if strcmp(currentZoomPosition,'Reset')
                    currentZoomPosition = [];
                end
                set(subImageAx,'xlim',...
                    [pos(1)-padval,pos(1)+pos(3)+2*padval],...
                    'ylim',...
                    [pos(2)-padval,pos(2)+pos(4)+2*padval]);
            end
        else
            resetZoom;
        end
        
        function resetZoom(varargin)
            displaySubImage(UD.returnedPosition,subImage,UD.XSubRange,UD.YSubRange);
            currentZoomPosition = [];
            isZoomed = false;
        end %resetZoom
    end %zoomToCurrent

end %function userData = labelBigImage(imageName,varargin)
