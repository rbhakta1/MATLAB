function [] = create(vObj,baseROI,varargin)
vObj.activeROI = baseROI;
vObj.activeROI.Deletable = false;

% Create synchronizedImpolys object
% disp(['CREATING Synchronized ',class(vObj.activeROI)])

% set properties 
if(vObj.idxActiveROI == 0)
    error('The specified axes list does not contain the ROI');
end
tmpPositions = cell(vObj.numROIs,1);
tmpPositions{vObj.idxActiveROI} = vObj.activeROI.getPosition();
vObj.setROIPositions(tmpPositions);
% Region Sample Options:
% NOTE: Sampling can be very slow if sampling region is too small;
% default size should reflect size of parent axes!
xl = [vObj.ROIParentHandles.XLim];
xl = round(xl(2:2:end)/10);
yl  = [vObj.ROIParentHandles.YLim];
yl = round(yl(2:2:end)/10);
samplingOpts.boxH = yl;
samplingOpts.boxW = xl;
samplingOpts.extractorType = 'Auto';
samplingOpts.featureType = 'SURF';
samplingOpts.includeColor = true;
samplingOpts.includeTexture = true;
samplingOpts.includePiecewiseTortuosity = true;
% Specify the indices of ROIs to sample to trigger sampling!!!
samplingOpts.indsOfROIsToSampleWhenMoved = [];
% Parent Images can be obtained from getimage(imgca), or may be the
% name of an image file
samplingOpts.parentImages = cell(vObj.numROIs,1);
samplingOpts.trainingImages = cell(vObj.numROIs,1);
samplingOpts.verboseAnnotations = false(vObj.numROIs,1);
set(vObj,'samplingOpts',samplingOpts);

% vObj.initPosition(vObj.activeROI.getPosition());
% Create IMREFERENCING Objects:
for ii = vObj.numROIs:-1:1
	for jj = vObj.numROIs:-1:1
		% Note: this maintains referencing objects for ii==jj as
		% placeholders
		thisAx = vObj.ROIParentHandles(ii);
		xl = get(thisAx,'XLim');
		xl = [max(xl(1),0) max(xl(2),1)];
		yl = get(thisAx,'YLim');
		yl = [max(yl(1),0) max(yl(2),1)];
		vObj.referenceObjects(ii,jj) = imref2d(floor([yl(2) xl(2)]),...
			vObj.ROIParentHandles(jj).XLim,vObj.ROIParentHandles(jj).YLim); 
	end
	% Note: getimage does a lazy copy--no extra memory
	vObj.samplingOpts.parentImages{ii} = getimage(thisAx);
end

%% Create the ROI positions using axes handles and given Active ROI position

if(vObj.idxActiveROI > 0)
    [Message, StatusOk] = setSynchronizedROIPosition(vObj);
    if(~StatusOk)
        error(Message);
    end
else
    error('No active ROIs found !!');
end

%% Check to see if all axes handles are valid
if(sum(isvalid(vObj.ROIParentHandles))~= vObj.numROIs)
    error('Some axes handles are invalid');
end
positionArr  = vObj.getROIPositions();
tmpFunc = str2func(class(vObj.activeROI));
id(vObj.numROIs).removeCallback = tmpFunc;%Placeholder for preallocation
for ii = 1:vObj.numROIs
    if(ii~=vObj.idxActiveROI)
        vObj.ROI(ii) = tmpFunc(vObj.ROIParentHandles(ii),positionArr{ii});
		vObj.ROI(ii).Deletable = false;
    else
        vObj.ROI(ii) = vObj.activeROI;
    end
    id(ii) = addNewPositionCallback(vObj.ROI(ii),...
		@(p,src)setActiveROI(vObj,p,vObj.ROI(ii)));  
end
vObj.CallBackId = id;
vObj.validated = false;
if ~vObj.allowUnlabeled || ~isempty(vObj.label)
	vObj.addSynchronizedLabels('thisLabel',vObj.label,...
		'defaultLabel',vObj.defaultLabel,...
        'backgroundColor',vObj.backgroundColor,...
        'positionPreference',vObj.labelPositionPreference);
end
synchronizedROI.extendSynchronizedImroiContextMenu(vObj);
% Add a figure button-up callback to sample the underlying image; it
% will be ignored if request is suppressed
addImroiButtonUpCallback(vObj,...
	@(obj,~)getSynchronizedImageDescriptors(vObj),true);
%vObj.callCallback(e);
% 
end