function [trainingImage,nTrainingTiles,mask] = ...
    getTrainingTilesFromRectIMROI(img,positions,ax,boxW,boxH,verbose,...
    writeDir,writeClass,computeTrainingImage)
% EXAMPLE:
%
% img = imread('peppers.png');
% imshow(img);
% h = imfreehand;
% boxW = 40;
% boxH = 40;
% verbose = true;
% [trainingImage,nTrainingTiles] = getTrainingTilesFromIMROI(img,h.getPosition,imgca,boxW,boxH,verbose);
%

narginchk(5,9)
parentFig = ancestor(ax,'figure');
figure(parentFig);
%
minPos = [min(ax.XLim),min(ax.YLim)];
positions = positions - [minPos 0 0];
xs = floor(positions(1):boxW:positions(1)+positions(3)-(boxW-1));
ys = floor(positions(2):boxH:positions(2)+positions(4)-(boxH-1));
%
if nargin < 6
    verbose = false;
end
if nargin < 7
    writeDir = '';
end
if nargin < 8
    writeClass = class(img);
end
if nargin < 9
    computeTrainingImage = true;
end

% I need to work in single for applyImage to work:
img = im2single(img);
isAllNonNan = zeros(numel(xs),numel(ys));
trainingImage = [];
ind = max(0,numel(dir(writeDir))-2); %count number of entries currently in the directory, minus '.' and '..'
for ii = 1:numel(xs)
    for jj = 1:numel(ys)
        thisTile = imcrop(img,[xs(ii) ys(jj) boxW-1 boxH-1]);
        % Eliminate non-full tiles (for concatenation purposes)
        if ~all(size(thisTile(:,:,1)) == [boxH, boxW])
            continue
        end
        isAllNonNan(ii,jj) = nnz(isnan(thisTile))==0;
        if isAllNonNan(ii,jj)
            ind = ind + 1;
            if verbose
                hold on
                tmpRect = rectangle(ax,...
                    'Position',[xs(ii)+minPos(1) ys(jj)+minPos(2) boxW boxH]);
                set(tmpRect,'Tag','TempRectangle',...
                    'LineWidth',3,...
                    'PickableParts','none')
                tmpRect = rectangle(ax,...
                    'Position',[xs(ii)+minPos(1) ys(jj)+minPos(2) boxW boxH]);
                set(tmpRect,'Tag','TempRectangle',...
                    'LineWidth',3,...
                    'LineStyle','--',...)
                    'EdgeColor','y',...
                    'PickableParts','none')
                text(xs(ii)+minPos(1)+boxW/2,ys(jj)+minPos(2)+boxH/2,num2str(ind),...
                    'fontsize',9,'Color','r',...
                    'tag','tempText')
                drawnow
            end
            if computeTrainingImage
                trainingImage = [trainingImage;thisTile]; %#ok<*AGROW>
            end
            if ~isempty(writeDir)
                switch writeClass
                    case 'single'
                        % ALREADY SINGLE!
                        % img = im2single(img);
                    case 'double'
                        thisTile = im2double(thisTile);
                    case 'uint8'
                        thisTile = im2uint8(thisTile);
                    otherwise
                        beep;
                        disp('getTrainingTilesFromIMROI: edit switch case to accommodate this class!')
                        [trainingImage,nTrainingTiles,mask] = deal([]);
                        return
                end %switch writeClass
                disp(['Writing ', fullfile(writeDir,['TrainingTile' sprintf('%06i',ind) '.png'])])
                imwrite(thisTile,...
                    fullfile(writeDir,['TrainingTile' sprintf('%06i',ind) '.png']));
                
            end %~isempty(writeDir)
        end
    end
end
nTrainingTiles = nnz(isAllNonNan);