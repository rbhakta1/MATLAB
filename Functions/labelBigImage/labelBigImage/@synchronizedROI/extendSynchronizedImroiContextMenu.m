function extendSynchronizedImroiContextMenu(thisSynchronizedROI,varargin)
varname = thisSynchronizedROI.outputVarname;
sampleROI = thisSynchronizedROI.activeROI;
activeAx = get(sampleROI,'parent');
axHasImage = ~isempty(imhandles(activeAx));
roiType = class(sampleROI);
h_parent = ancestor(get(sampleROI,'parent'),'figure','toplevel');
lws = 0.5:0.5:4;
linestyles = {'-','--',':','-.'};
allROIs = thisSynchronizedROI.ROI;
PCFcns = cell(thisSynchronizedROI.numROIs,1);
%
doNotAssign = {'activeROI','Callback','idxActiveROI','isLocked','label','labelButtons','numROIs','parent',...
    'referenceMode','ROI','ROIParentHandles','ROIPositions'};

for kk = 1:thisSynchronizedROI.numROIs
    [UCM,objType] = uniqueContextMenus(allROIs(kk));
    PCFcns{kk} = allROIs(kk).getPositionConstraintFcn;
    switch roiType
        case 'imfreehand'
            for ii = 1:numel(UCM)
                uimenu(UCM(ii),'Label', '.....')
                uimenu(UCM(ii),'Label', 'Display Properties',...
                    'Callback', @displaySynROIProperties);
                if axHasImage
                    uimenu(UCM(ii),'Label', 'Toggle Image Sampling',...
                        'Callback', @toggleImageSampling);
                end
                uimenu(UCM(ii),'Label', '.....')
                uimenu(UCM(ii),'Label', 'Convert To Synchronized IMPOLY',...
                    'Callback', @convertToSynchronizedImpoly);
                lineThicknessMenu;
                lineStyleMenu;
                uimenu(UCM(ii),'Label', 'Constrain/Unconstrain this SynchronizedROI', 'Callback', @constrainUnconstrainROISet)
                uimenu(UCM(ii),'Label', 'Lock/Unlock this SynchronizedROI',...
                    'Callback',@(obj,evt) thisSynchronizedROI.togglePositionLock)
                uimenu(UCM(ii),'Label', 'Open/Close this SynchronizedROI', 'Callback', @openCloseSynchronizedROI)
                uimenu(UCM(ii),'Label', 'Copy/Paste this SynchronizedROI', 'Callback', @copyPasteSynchronizedROI)
                uimenu(UCM(ii),'Label','Add Synchronized Label',...
                    'Callback',@(obj,evt) thisSynchronizedROI.addSynchronizedLabels)
                uimenu(UCM(ii),'Label', '.....')
                uimenu(UCM(ii),'Label','Delete this SynchronizedROI','Callback',@deleteSynchronizedROI)
            end
        case 'impoly'
            for ii = 1:numel(UCM)
                uimenu(UCM(ii),'Label', '.....')
                uimenu(UCM(ii),'Label', 'Display Properties',...
                    'Callback', @displaySynROIProperties);
                if axHasImage
                    uimenu(UCM(ii),'Label', 'Toggle Image Sampling',...
                        'Callback', @toggleImageSampling);
                end
                uimenu(UCM(ii),'Label', '.....')
                %VERTICES
                if ~isempty(strfind(objType{ii},'vertex'))
                    uimenu(UCM(ii),'Label', 'Snap Vertex to nearest corner', 'Callback', @snapToCorner )
                end
                %LINES
                if ~isempty(strfind(objType{ii},'line'))
                    uimenu(UCM(ii),'Label', 'Add Vertex', 'Callback', @addVertex )
                end
                lineThicknessMenu;
                lineStyleMenu;
                uimenu(UCM(ii),'Label', 'Decimate/Downsample','Callback', @downsamplePoints)
                uimenu(UCM(ii),'Label', 'Interpolate/Upsample','Callback', @upsamplePoints)
                uimenu(UCM(ii),'Label', 'Convert To Synchronized IMFREEHAND','Callback', @convertToSynchronizedImfreehand)
                uimenu(UCM(ii),'Label', 'Constrain/Unconstrain Set', 'Callback', @constrainUnconstrainROISet)
                uimenu(UCM(ii),'Label', 'Lock/Unlock this SynchronizedROI',...
                    'Callback',@(obj,evt) thisSynchronizedROI.togglePositionLock)
                uimenu(UCM(ii),'Label', 'Open/Close ROI Set', 'Callback', @openCloseSynchronizedROI)
                uimenu(UCM(ii),'Label', 'Copy/Paste this SynchronizedROI', 'Callback', @copyPasteSynchronizedROI)
                uimenu(UCM(ii),'Label','Add Synchronized Label',...
                    'Callback',@(obj,evt) thisSynchronizedROI.addSynchronizedLabels)
                uimenu(UCM(ii),'Label', '.....')
                uimenu(UCM(ii),'Label','Delete this SynchronizedROI set','Callback',@deleteSynchronizedROI)
            end
        case 'imrect'
            for ii = 1:numel(UCM)
                uimenu(UCM(ii),'Label', '.....')
                uimenu(UCM(ii),'Label', 'Display Properties',...
                    'Callback', @displaySynROIProperties);
                uimenu(UCM(ii),'Label', '.....')
                lineThicknessMenu;
                lineStyleMenu;
                %uimenu(UCM(ii),'Label', 'Convert To Synchronized IMFREEHAND','Callback', @convertToSynchronizedImfreehand)
                %uimenu(UCM(ii),'Label', 'Convert To Synchronized IMPOLY','Callback', @convertToSynchronizedImpoly)
                uimenu(UCM(ii),'Label', 'Constrain/Unconstrain Set', 'Callback', @constrainUnconstrainROISet)
                uimenu(UCM(ii),'Label', 'Lock/Unlock this SynchronizedROI',...
                    'Callback',@(obj,evt) thisSynchronizedROI.togglePositionLock)
                uimenu(UCM(ii),'Label','Add Synchronized Label',...
                    'Callback',@(obj,evt) thisSynchronizedROI.addSynchronizedLabels)
                uimenu(UCM(ii),'Label', '.....')
                uimenu(UCM(ii),'Label','Delete this SynchronizedROI set','Callback',@deleteSynchronizedROI)
            end
    end %switch roiType
end
% ALPHABETICAL:
%===========================================================%
    function addVertex(varargin)
        beep
        disp('Hold down the ''a'' key and click line!')
    end %addVertex
%===========================================================%
    function changeLineStyle(obj,varargin)
        thisSynchronizedROI.lineStyle = obj.Label;
    end %changeLineStyle
%===========================================================%
    function changeLineThickness(obj,varargin)
        thisSynchronizedROI.lineWidth = str2double(obj.Label);
    end %changeLineThickness
%===========================================================%
    function constrainUnconstrainROISet(varargin)
        for ll = thisSynchronizedROI.numROIs:-1:1
            tmp = getPositionConstraintFcn(thisSynchronizedROI.ROI(ll));
            tmpPCFcns{ll} = func2str(tmp);
        end
        if all(strcmp(tmpPCFcns,'makeConstrainToRectFcn/constrainPolygonToRect')) || ...
                all(strcmp(tmpPCFcns,'makeConstrainToRectFcn/constrainRectToRect'))
            isConstrained = true;
        else
            isConstrained = false;
        end
        if isConstrained
            % Unconstrain:
            tmpFcn = @(varargin)deal(varargin{:});
            for ll = 1:thisSynchronizedROI.numROIs
                setPositionConstraintFcn(thisSynchronizedROI.ROI(ll),tmpFcn);
            end
        else
            % Constrain:
            for ll = 1:thisSynchronizedROI.numROIs
                hAx = thisSynchronizedROI.ROIParentHandles(ll);
                constraintFcn = makeConstrainToRectFcn(roiType,...
                    get(hAx,'XLim'),get(hAx,'YLim'));
                setPositionConstraintFcn(thisSynchronizedROI.ROI(ll),constraintFcn);
            end
        end
    end %constrainUnconstrainROI
%===========================================================%
    function synROI = convertToSynchronizedImfreehand(varargin)
        set(h_parent,'pointer','watch');
        drawnow;
        selectedIndex = getSelectedIndex(thisSynchronizedROI,gca);
        sampleROI = thisSynchronizedROI.ROI(selectedIndex);
        samplePos = sampleROI.getPosition;
        currProps = get(thisSynchronizedROI);
        currAx = thisSynchronizedROI.ROIParentHandles(selectedIndex);
        %Recapture Position Constraint Functions:
        PCFcns = recapturePositionConstraintFcns(thisSynchronizedROI);
        synROI = imfreehand(currAx,samplePos); %#ok<*IMFREEH>
        deleteROISet(thisSynchronizedROI);
        synROI = synchronizedImfreehands(synROI,...
            'ROIParentHandles',currProps.ROIParentHandles,...
            'labelPositionPreference',currProps.labelPositionPreference,...
            'backgroundColor',currProps.backgroundColor,...
            'referenceMode',currProps.referenceMode,...
            'Callback',currProps.Callback);
        synROI.outputVarname = currProps.outputVarname;%Special handling
        varname = synROI.outputVarname;
        updateFields(synROI,currProps,PCFcns)
        set(h_parent,'pointer','arrow');
        drawnow;
        synROI.backgroundColor = currProps.backgroundColor;
        setLabelPositionPreference(synROI,currProps.labelPositionPreference);
        synROI.refresh('convert');
    end %convertToSynchronizedImfreehand
%===========================================================%
    function synROI = convertToSynchronizedImpoly(varargin)
        % Warning: this can be VERY slow!
        selectedIndex = getSelectedIndex(thisSynchronizedROI,gca);
        sampleROI = thisSynchronizedROI.ROI(selectedIndex);
        samplePos = sampleROI.getPosition;
        currProps = get(thisSynchronizedROI);
        currAx = thisSynchronizedROI.ROIParentHandles(selectedIndex);
        %Recapture Position Constraint Functions:
        PCFcns = recapturePositionConstraintFcns(thisSynchronizedROI);
        nPos = size(samplePos,1);
        maxPos = 150;
        % MAX?
        if nPos > maxPos
            opt  = questdlg(sprintf('Converting this region can be SLOW!\nWould you like to downsample the border first (to make it faster)?'), ...
                'Downsample?','YES','No, use original','Cancel','YES');
            switch opt
                case 'Cancel'
                    return
                case 'YES'
                    samplePos = downsample(samplePos,ceil(nPos/maxPos));
            end
        end
        set(h_parent,'pointer','watch');
        drawnow;
        synROI = impoly(currAx,samplePos); %#ok<*IMPOLY>
        deleteROISet(thisSynchronizedROI);
        synROI = synchronizedImpolys(synROI,...
            'ROIParentHandles',currProps.ROIParentHandles,...
            'referenceMode',currProps.referenceMode,...
            'score',currProps.score,...
            'labelPositionPreference',currProps.labelPositionPreference,...
            'backgroundColor',currProps.backgroundColor,...
            'Callback',currProps.Callback);
        synROI.outputVarname = currProps.outputVarname;%Special handling
        varname = synROI.outputVarname;
        updateFields(synROI,currProps,PCFcns);
        set(h_parent,'pointer','arrow');
        drawnow;
        synROI.backgroundColor = currProps.backgroundColor;
        setLabelPositionPreference(synROI,currProps.labelPositionPreference);
        synROI.refresh('convert');
    end %convertToSynchronizedImpoly
%===========================================================%
%     function synROI = convertToSynchronizedImrect(varargin)
%         % Warning: this can be VERY slow!
%         selectedIndex = getSelectedIndex(thisSynchronizedROI,gca);
%         sampleROI = thisSynchronizedROI.ROI(selectedIndex);
%         samplePos = sampleROI.getPosition;
%         currProps = get(thisSynchronizedROI);
%         currAx = thisSynchronizedROI.ROIParentHandles(selectedIndex);
%         %Recapture Position Constraint Functions:
%         PCFcns = recapturePositionConstraintFcns(thisSynchronizedROI);
%         nPos = size(samplePos,1);
%         maxPos = 150;
%         % MAX?
%         if nPos > maxPos
%             opt  = questdlg(sprintf('Converting this region can be SLOW!\nWould you like to downsample the border first (to make it faster)?'), ...
%                 'Downsample?','YES','No, use original','Cancel','YES');
%             switch opt
%                 case 'Cancel'
%                     return
%                 case 'YES'
%                     samplePos = downsample(samplePos,ceil(nPos/maxPos));
%             end
%         end
%         set(h_parent,'pointer','watch');
%         drawnow;
%         %synROI = imrect(currAx,samplePos);
%         minX = min(samplePos(:,1));
%         maxX = max(samplePos(:,1));
%         rangeX = maxX - minX;
%         minY = min(samplePos(:,2));
%         maxY = max(samplePos(:,2));
%         rangeY = maxY - minY;
%         synROI = imrect(currAx,[minX maxX rangeX rangeY]);
%         deleteROISet(thisSynchronizedROI);
%         synROI = synchronizedImrects(synROI,...
%             'ROIParentHandles',currProps.ROIParentHandles,...
%             'referenceMode',currProps.referenceMode,...
%             'userData',samplePos,...
%             'Callback',currProps.Callback);
%         synROI.outputVarname = currProps.outputVarname;%Special handling
%         varname = synROI.outputVarname;
%         updateFields(synROI,currProps,PCFcns);
%         set(h_parent,'pointer','arrow');
%         drawnow;
%         synROI.refresh('convert');
%     end %convertToSynchronizedImrect
%===========================================================%
    function copyPasteSynchronizedROI(varargin)
        selectedIndex = getSelectedIndex(thisSynchronizedROI,gca);
        sampleROI = thisSynchronizedROI.ROI(selectedIndex);
        samplePos = sampleROI.getPosition;
        currProps = get(thisSynchronizedROI);
        currAx = thisSynchronizedROI.ROIParentHandles(selectedIndex);
        %Recapture Position Constraint Functions:
        PCFcns = recapturePositionConstraintFcns(thisSynchronizedROI);
        samplePos = [samplePos(:,1)+range(samplePos(:,1))/10, ...
            samplePos(:,2)+range(samplePos(:,2))/10];
        %
        if isa(currProps.activeROI,'imfreehand')
            synROI = imfreehand(currAx,samplePos);
            
        synROI = synchronizedImfreehands(synROI,...
            'ROIParentHandles',currProps.ROIParentHandles,...
            'referenceMode',currProps.referenceMode,...
            'score',currProps.score,...
            'labelPositionPreference',currProps.labelPositionPreference,...
            'backgroundColor',currProps.backgroundColor,...
            'Callback',currProps.Callback);
        elseif isa(currProps.activeROI,'impoly')
            synROI = impoly(currAx,samplePos);
            synROI = synchronizedImpolys(synROI,...
                'ROIParentHandles',currProps.ROIParentHandles,...
                'referenceMode',currProps.referenceMode,...
                'Callback',currProps.Callback);
        end
        synROI.outputVarname = currProps.outputVarname;%Special handling
        varname = synROI.outputVarname;
        updateFields(synROI,currProps,PCFcns);
        % NOTE: On type conversion, we want to keep the uniqueIdentifer;
        % but on copy/paste, we do not! However, we need to be able to
        % assign a new uniqueIdentifier that is non-sequential in case the
        % copied synROI was not the last one created!
        figParent = get(get(synROI.ROI(1),'Parent'),'Parent');
        nextUniqueIdentifier = getappdata(figParent,'nextUniqueIdentifier');
        if isempty(nextUniqueIdentifier)
            nextUniqueIdentifier = synROI.uniqueIdentifier + 1;
        else
            setappdata(figParent,'nextUniqueIdentifier',nextUniqueIdentifier + 1);
        end
        %synROI.uniqueIdentifier = synROI.uniqueIdentifier + 1;
        synROI.uniqueIdentifier = nextUniqueIdentifier;
%         % However, now listeners (if there are any) are listening to the
%         % source object rather than to the copied one. Let's overwrite
%         % listeners:
%         currProps = get(synROI);
%         if isfield(currProps.userData,'listeners')
%             listeners = currProps.userData.listeners;
%             for jj = 1:numel(listeners)
%                 %Add listeners to copied synROI:
%                 addlistener(synROI.ROI(1),listeners{jj}.EventName,...
%                     str2func(func2str(listeners{jj}.Callback)));
% %                 addlistener(synROI.ROI(1),listeners{jj}.EventName,...
% %                     listeners{jj}.Callback);
% %                 %Remove listeners to original synROI:
% %                 delete(listeners{jj});
%             end
%         end
        drawnow;
        %Trigger callbacks:
        synROI.refresh('copy');
        %
        set(h_parent,'pointer','arrow');
    end %copyPasteSynchronizedROI
%===========================================================%
    function deleteSynchronizedROI(varargin)
        thisSynchronizedROI.refresh('delete')
        deleteROISet(thisSynchronizedROI)
    end %deleteSynchronizeROI
%===========================================================%
    function displaySynROIProperties(varargin)
        thisSynROIProperties = get(thisSynchronizedROI);
        txt = [];
        fn = sort(fieldnames(thisSynROIProperties));
        [~,inds] = sort(lower(fn));
        fn = fn(inds,:);
        for iii = 1:numel(fn)
            thisFn = fn{iii};
            thisVal = thisSynROIProperties.(thisFn);
            thisPadStr = repmat(' ',1,max(1,30-length(thisFn)));
            switch class(thisVal)
                case 'char'
                    txt = char(txt,sprintf('%s%s%s',thisFn,thisPadStr,thisVal));
                case {'double','single'}
                    txt = char(txt,sprintf('%s%s%f',thisFn,thisPadStr,thisVal));
                case {'logical'}
                    txt = char(txt,sprintf('%s%s%i',thisFn,thisPadStr,thisVal));
                case 'function_handle'
                    txt = char(txt,sprintf('%s%s%s',thisFn,thisPadStr,func2str(thisVal)));
                otherwise
                    txt = char(txt,sprintf('%s%s%s',thisFn,thisPadStr,class(thisVal)));
            end
        end
        assignin('base','thisSynROIProperties',thisSynROIProperties)
        disp('Assigned to base workspace as ''thisSynROIProperties''.');
        d = dialog(...
            'Units','Normalized',...
            'Position',[0.25 0.05 0.5 0.8],'Name','Description');
        uicontrol('Parent',d,...
            'Units','Normalized',...
            'Style','listbox',...
            'Position',[0.05 0.125 0.9 0.85],...
            'fontweight','bold',...
            'fontname',get(groot,'FixedWidthFontName'),...
            'fontsize',10,...
            'HorizontalAlignment','left',...
            'String',txt);
        uicontrol('Parent',d,...
            'Units','Normalized',...
            'Position',[0.05 0.05 0.9 0.05],...
            'String','Close',...
            'Callback','delete(gcf)');
    end %displaySynROIProperties
%===========================================================%
    function downsamplePoints(varargin)
        set(h_parent,'pointer','watch')
        drawnow
        samplePos = sampleROI.getPosition;
        newPos = samplePos(1:4:end,:);
        sampleROI.setPosition(newPos);
        redraw(thisSynchronizedROI)
        set(h_parent,'pointer','arrow')
        drawnow
    end %downsamplePoints
%===========================================================%
    function selectedIndex = getSelectedIndex(synROI,ax)
        for jj = 1:synROI.numROIs
            if isequal(ax,get(synROI.ROI(jj),'Parent'))
                selectedIndex = jj;
                break
            end
        end
    end %getSelectedIndex
%===========================================================%
    function lineStyleMenu(varargin)
        tmp = uimenu(UCM(ii),'Label', 'Change Synchronized Line Style');
        for jj = 1:numel(linestyles)
            uimenu(tmp,'Label',linestyles{jj},'Callback',@changeLineStyle)
        end
    end %lineStyleMenu
%===========================================================%
    function lineThicknessMenu
        tmp = uimenu(UCM(ii),'Label', 'Change Synchronized Line Thickness');
        for jj = 1:numel(lws)
            uimenu(tmp,'Label',num2str(lws(jj)),'Callback',@changeLineThickness)
        end
    end %lineThicknessMenu
%===========================================================%
    function openCloseSynchronizedROI(varargin)
        if ismember(get(thisSynchronizedROI.activeROI,'Tag'),{'impoly','imfreehand'})
            newClosedStatus = ~thisSynchronizedROI.isClosed;
            thisSynchronizedROI.isClosed = newClosedStatus;
        else
            beep;
            disp('isClosed property is ignored for this type of synchronizedROI.');
        end
        for jj = 1:thisSynchronizedROI.numROIs
            setClosed(thisSynchronizedROI.ROI(jj),newClosedStatus);
        end
    end %openROI
%===========================================================%
    function PCFcns = recapturePositionConstraintFcns(thisSynchronizedROI)
        PCFcns = cell(thisSynchronizedROI.numROIs,1);
        for ll = 1:thisSynchronizedROI.numROIs
            PCFcns{ll} = getPositionConstraintFcn(thisSynchronizedROI.ROI(ll));
        end
    end
%===========================================================%
    function toggleImageSampling(varargin)
        thisSynROIProperties = get(thisSynchronizedROI);
        thisSynchronizedROI.samplingOpts.verboseAnnotations = true(thisSynchronizedROI.numROIs,1);
        currSampling = thisSynROIProperties.samplingOpts.indsOfROIsToSampleWhenMoved;
        isSampling = ismember(thisSynchronizedROI.idxActiveROI,currSampling);
        if isSampling
            thisSynchronizedROI.samplingOpts.indsOfROIsToSampleWhenMoved =...
                setdiff(currSampling,thisSynchronizedROI.idxActiveROI);
            disp(['Sampling disabled for ROI ' num2str(thisSynchronizedROI.idxActiveROI)])
        else
            thisSynchronizedROI.samplingOpts.indsOfROIsToSampleWhenMoved =...
                [currSampling,thisSynchronizedROI.idxActiveROI];
            disp(['Sampling enabled for ROI ' num2str(thisSynchronizedROI.idxActiveROI)])
        end
    end %toggleImageSampling
%===========================================================%
    function updateFields(synROI,currProps,PCFcns)
        thisFieldnames = fieldnames(currProps);
        fieldnamesToAssign = setdiff(thisFieldnames,doNotAssign);
        for jj = 1:numel(fieldnamesToAssign)
            try %#ok<TRYNC>
                synROI.(fieldnamesToAssign{jj}) = currProps.(fieldnamesToAssign{jj});
                % 			catch
                % 				fieldnamesToAssign{jj}
            end
        end
        for ll = 1:synROI.numROIs
            setPositionConstraintFcn(synROI.ROI(ll),PCFcns{ll});
        end
        %
        if currProps.isLocked
            synROI.togglePositionLock;
        end
        if ~isempty(currProps.label)
            if ~isempty(currProps.labelList)
                addSynchronizedLabels(synROI,...
                    'thisLabel',currProps.label,...
                    'allLabels',currProps.labelList);
            else
                addSynchronizedLabels(synROI,...
                    'thisLabel',currProps.label);
            end
        end
%         if isfield(currProps.userData,'listeners')
%             listeners = currProps.userData.listeners;
%             for jj = 1:numel(listeners)
%                 addlistener(synROI.ROI(1),listeners{jj}.EventName,...
%                     listeners{jj}.Callback);
%             end
%         end
        if ~isempty(varname)
            assignin('caller',varname,synROI)
            assignin('base',varname,synROI)
        end
    end %updateFields
%===========================================================%
    function upsamplePoints(varargin)
        set(h_parent,'pointer','watch')
        drawnow;
        samplePos = sampleROI.getPosition;
        newPos = [interp(samplePos(:,1),2) interp(samplePos(:,2),2)];
        sampleROI.setPosition(newPos);
        redraw(thisSynchronizedROI)
        set(h_parent,'pointer','arrow')
        drawnow
    end %upsamplePoints
%===========================================================%
end %extendSynchronizedImroiContextMenu