function [] = redraw(vObj)
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
%% update the positions of all other ROIs
for ii = 1:vObj.numROIs
    if(ii~=vObj.idxActiveROI && isvalid(vObj.ROI(ii)))
        %remove callback first
        removeNewPositionCallback(vObj.ROI(ii),vObj.CallBackId(ii));
        if(isa(vObj.activeROI,'imfreehand') || isa(vObj.activeROI,'impoly'))
            if strcmp(vObj.referenceMode,'absolute')
                thisRef = {};
            else
                thisRef = vObj.referenceObjects(vObj.idxActiveROI,ii);
            end
            synchronizedROI.matchImfreehandPosition(vObj.ROI(ii),vObj.activeROI,...
                thisRef);
        else
            vObj.ROI(ii).setPosition(positionArr{ii});
        end
        vObj.CallBackId(ii) = addNewPositionCallback(vObj.ROI(ii),...
            @(p,src)setActiveROI(vObj,p,vObj.ROI(ii)));
    end
end
% % Sampling Requested?
% if vObj.samplingOpts.sampleImageWhenMoved
% 	disp('MOVING')
% end %vObj.samplingOpts.sampleImageWhenMoved

end