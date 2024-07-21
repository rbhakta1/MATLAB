function [labelButtons,thisLabel,allLabels] = addSynchronizedLabels(synchronizedROIObject,varargin)
% Brett Shoelson, PhD
isLabeled = ~isempty(synchronizedROIObject.labelButtons);
if isLabeled
    beep;
    disp('This synchronizedROI is already labeled. Please delete the existing label first.');
    labelButtons = synchronizedROIObject.labelButtons;
    thisLabel = synchronizedROIObject.label;
    if false && ~isempty(synchronizedROIObject.score)
        %Note: this needs some work. Including the score changes
        %comparison to default label, and updates label list with
        %scored labels!
        thisLabel = sprintf('%s (%0.2f)',...
            thisLabel,synchronizedROIObject.score);
    end
    allLabels = getAllLabelsFromMatfile;
    return
end
[allLabels,backgroundColor,defaultLabel,parent,positionPreference,thisLabel] = ...
    parseInputs(varargin{:});
labelPath = [];
if ischar(allLabels)
    % Path to allLabels files provided
    labelPath = allLabels;
    allLabels = getAllLabelsFromMatfile(labelPath);
end
synchronizedROIObject.label = thisLabel;
synchronizedROIObject.backgroundColor = backgroundColor;
roiPositions = synchronizedROIObject.ROIPositions;
parentFig = ancestor(parent,'figure');
%
if synchronizedROIObject.allowUnlabeled
    if ~strcmp(allLabels(end),'Delete Labels')
        allLabels = [allLabels;'Delete Labels'];
    end
end
%
labelButtons = gobjects(synchronizedROIObject.numROIs,1);
for ii = synchronizedROIObject.numROIs:-1:1
    thisPos = roiPositions{ii};
    thisParent = synchronizedROIObject.ROIParentHandles(ii);
    thisROI = synchronizedROIObject.ROI(ii);
    if isa(thisROI,'imrect')
        %thisPos = [thisPos(1)+thisPos(3)/2, thisPos(2)+thisPos(4)/2];
        thisAlignment = 'center';
    else
        %
        thisAlignment = 'left';
    end
    if strcmp(positionPreference,'Center')
        thisPos = [mean(thisPos(:,1)) mean(thisPos(:,2))];%Center
    elseif strcmp(positionPreference,'Top')
        thisPos = [min(thisPos(:,1)) 0.999*min(thisPos(:,2))];%Bottom Left
    elseif strcmp(positionPreference,'Bottom')
        thisPos = [min(thisPos(:,1)) 1.001*max(thisPos(:,2))];%Bottom Left
    else
            error('addSynchronizedLabels: Unrecognized positionPreference');
    end
    labelButtons(ii) = text('parent',thisParent,...
        'pos',thisPos,...
        'string',thisLabel,...
        'fontweight','bold',...
        'tag','labelButton',...
        'fontsize',8,...
        'edgecolor',[0.9 0.9 0.9],...
        'color','k',...
        'margin',2,...
        'clipping','on',...
        'interpreter','none',...
        'backgroundcolor',backgroundColor,...'g',...
        'horizontalalignment',thisAlignment,...
        'buttondownfcn',@addLabels);
    uistack(labelButtons(ii),'top');
    id(ii) = thisROI.addNewPositionCallback(@repositionLabel);
    set(thisROI,'UserData',thisROI);
    synchronizedROIObject.labelButtons = labelButtons;
end %Create "button" labels
synchronizedROIObject.labelMotionCallbackID = id;

    function addLabels(obj,varargin)
        %if ~isa(allLabels,'cell')
            allLabels = getAllLabelsFromMatfile(labelPath);
        %end
        % To support bigImageLabeler:
        baseLabel = 'Auto-Segmented';
        thisPos = obj.Position;
        figpos = parentFig.Position;
        tmpFig = figure('numbertitle','off',...
            'name','Add Label',...
            'windowstyle','modal',...
            'units','pixels',...
            'position',[thisPos(1)+figpos(1) thisPos(2)+20 350 255]);
        sortedLabels = [baseLabel;sort(setdiff(allLabels,baseLabel))];
        ind = find(strcmp(thisLabel,sortedLabels));
        if isempty(ind)
            ind = 1;
        end
        ltb = max(1,ind-1);
        thisListbox = uicontrol(tmpFig,...
            'style','listbox',...
            'string',sortedLabels,...
            'value',ind,...
            'ListboxTop',ltb,...
            'horizontalalignment','left',...
            'units','normalized',...
            'callback',@addToEditBox,...
            'position',[0.05 0.3 0.9 0.6]);
        movegui(tmpFig,'center');
        uicontrol(tmpFig,...
            'style','text',...
            'string', '(Max 28 characters, no spaces)',...
            'fontsize',10,...
            'fontweight','bold',...
            'horizontalalignment','left',...
            'foregroundcolor',[0 0.5 0],...
            'units','normalized',...
            'position',[0.05 0.205 0.9 0.075]);
        uicontrol(tmpFig,...
            'style','pushbutton',...
            'string','APPLY:',...
            'fontsize',10,...
            'fontweight','bold',...
            'horizontalalignment','left',...
            'foregroundcolor',[0 0.5 0],...
            'units','normalized',...
            'callback',@queryForLabel,...
            'tooltipstring','Apply Label, add (new) string to listbox, close window',...
            'position',[0.05 0.05 0.175 0.15]);
        edBox = uicontrol(tmpFig,...
            'style','edit',...
            'string',thisLabel,...
            'fontsize',10,...
            'fontweight','bold',...
            'horizontalalignment','left',...
            'units','normalized',...
            'position',[0.25 0.05 0.7 0.15]);
        obj.EdgeColor = [0.9 0.9 0.9];
        uiwait(tmpFig)
        if synchronizedROIObject.autoLockWhenLabeled && ~strcmp(synchronizedROIObject.label,defaultLabel) &&  ~synchronizedROIObject.isLocked
            synchronizedROIObject.togglePositionLock;
        end
        if synchronizedROIObject.isLocked && strcmp(synchronizedROIObject.label,defaultLabel)
            synchronizedROIObject.togglePositionLock
        end
        function addToEditBox(obj,varargin)
            str = get(obj,'string');
            val = get(obj,'value');
            thisLabel = str{val};
            if any(thisLabel == 32) || length(thisLabel) > 28
                beep;
                disp('Please limit region names to 28 characters, with no spaces!');
                disp('Names were automatically trimmed at 28 characters, and spaces were replaced with underscores.')
                thisLabel(thisLabel == 32) = 95;
                thisLabel = thisLabel(1:min(28,length(thisLabel)));
            end

            if strcmp(thisLabel,'----------')
                close(tmpFig)
                return
            elseif strcmp(thisLabel,'Delete Labels')
                if ~synchronizedROIObject.allowUnlabeled
                    beep;
                    disp('This label is protected!')
                    return
                end
                deleteSynchronizedLabels;
                close(tmpFig)
                return
            end
            set(edBox,'string',thisLabel)
            updateButtonVisibility
            %synchronizedROIObject.refresh();
        end %addToEditBox
        
        function queryForLabel(varargin)
            thisLabel = get(edBox,'string');
            if any(thisLabel == 32) || length(thisLabel) > 28
                beep;
                disp('Please limit region names to 28 characters, with no spaces!');
                disp('Names were automatically trimmed at 28 characters, and spaces were replaced with underscores.')
                thisLabel(thisLabel == 32) = 95;
                thisLabel = thisLabel(1:min(28,length(thisLabel)));
            end
            %%% BDS?
            allLabels = getAllLabelsFromMatfile(labelPath);
            addVal = setdiff({thisLabel},allLabels);
            if ~isempty(addVal)
                % Keep "Delete Labels" in place, add new label above it:
                allLabels = updateLabelsList(thisListbox,allLabels,addVal);
            end
            if false && ~isempty(synchronizedROIObject.score)
                %Note: this needs some work. Including the score changes
                %comparison to default label, and updates label list with
                %scored labels!
                thisLabel = sprintf('%s (%0.2f)',...
                    thisLabel,synchronizedROIObject.score);
            end
            synchronizedROIObject.label = thisLabel;
            synchronizedROIObject.labelList = labelPath;
            set(labelButtons,'string',{thisLabel})
            close(tmpFig)
            synchronizedROIObject.refresh('create');
      end %queryForLabel
        
        function updateButtonVisibility(varargin)
            showVis = get(findall(parentFig,...
                'string','Show Labels'),'value');
            if ~showVis
                set(labelButtons,'visible','off');
            end
        end %updateButtonVisibility
    end %addLabels

    function deleteSynchronizedLabels(varargin)
        tmp = questdlg('Are you sure?','Delete this label?','YES','Cancel','YES');
        if strcmp(tmp,'Cancel')
            return
        end
        synchronizedROIObject.label = '';
        synchronizedROIObject.labelButtons = [];
        delete(labelButtons)
        for jj = 1:synchronizedROIObject.numROIs
            thisObj = synchronizedROIObject.ROI(jj);
            removeNewPositionCallback(thisObj,synchronizedROIObject.labelMotionCallbackID(jj))
        end
    end %deleteSynchronizedLabels

    function allLabels = getAllLabelsFromMatfile(labelPath)
        if exist(labelPath,'file')
            allLabels = load(labelPath);
            if isfield(allLabels,'currentSessionLabels')
                allLabels = allLabels.currentSessionLabels;
            end
        else
            allLabels = {defaultLabel;thisLabel};
            save(labelPath,'allLabels');
        end
    end %getAllLabelsFromMatfile

    function repositionLabel(varargin)
        positionPreference = synchronizedROIObject.labelPositionPreference;
        for jj = 1:synchronizedROIObject.numROIs
            thisPos = synchronizedROIObject.ROIPositions{jj};
            if strcmp(positionPreference,'Center')
                thisPos = [mean(thisPos(:,1)) mean(thisPos(:,2))];%Center
            elseif strcmp(positionPreference,'Top')
                thisPos = [min(thisPos(:,1)) 0.999*min(thisPos(:,2))];%Bottom Left
            elseif strcmp(positionPreference,'Bottom')
                thisPos = [min(thisPos(:,1)) 1.001*max(thisPos(:,2))];%Bottom Left
            end
            set(labelButtons(jj),'position',thisPos);
        end        
    end %repositionLabel

    function allLabels = updateLabelsList(thisListbox,allLabels,addVal)
        allLabels = unique([allLabels(1:end - 1);addVal;allLabels(end)],'stable');
        if ~isempty(labelPath)
            save(labelPath,'allLabels');
        end
        set(thisListbox,'string',allLabels)
    end %updateLabelsList

    function [allLabels,backgroundColor,defaultLabel,parent,positionPreference,...
            thisLabel] = ...
            parseInputs(varargin)
        % Setup parser with defaults
        if isempty(synchronizedROIObject.defaultLabel)
            synchronizedROIObject.defaultLabel = 'Add/Change Label';
        end
        if ~isempty(synchronizedROIObject.label)
            thisLabel = synchronizedROIObject.label;
        else
            thisLabel = synchronizedROIObject.defaultLabel;
            if false && ~isempty(synchronizedROIObject.score)
                %Note: this needs some work. Including the score changes
                %comparison to default label, and updates label list with
                %scored labels!
                thisLabel = sprintf('%s (%0.2f)',...
                    thisLabel,synchronizedROIObject.score);
            end
        end
        parser = inputParser;
        parser.CaseSensitive = false;
        parser.addParameter('allLabels',synchronizedROIObject.labelList);
        parser.addParameter('backgroundColor',[1 0 1]);
        parser.addParameter('defaultLabel',synchronizedROIObject.defaultLabel)
        parser.addParameter('parent', gca);
        parser.addParameter('positionPreference', 'Center');
        parser.addParameter('thisLabel',thisLabel);
        % Parse input
        parser.parse(varargin{:});
        % Assign outputs
        r = parser.Results;
        [allLabels,backgroundColor,defaultLabel,parent,positionPreference,...
            thisLabel] = ...
            deal(r.allLabels,r.backgroundColor,r.defaultLabel,r.parent,...
            r.positionPreference,r.thisLabel);
    end %parseInputs

end %addSynchronizedLabels
