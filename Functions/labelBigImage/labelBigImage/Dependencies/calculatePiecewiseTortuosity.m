function piecewiseTortuosity = calculatePiecewiseTortuosity(input,featureLength,visualize,imgSize,offsets)
%visualize = true; % For debugging only!
nPieces = 20; %Default, for consistency
if isa(input,'imfreehand')
	thisAx = get(input,'Parent');
	input = input.getPosition;
elseif isa(input,'synchronizedROI')
	input = input.activeROI;
	input = input.getPosition;
	thisAx = gca;
elseif ~size(input,2)==2
	error('calculatePiecewiseTortuosity: For ''input'', please provide an imfreehand or an m x 2 collection of [x,y] points.')
end
if nargin < 2 || isempty(featureLength)
	featureLength = nPieces;
end
if nargin < 3
	visualize = false;
end
if nargin < 4
	imgSize = [];
end
if nargin < 5
    offsets = [0 0];
end
% Make closed
if ~(input(1,:) == input(end,:))
	input(end+1,:) = input(1,:);
end
% Accommodate imreferenced/offset images:
input = input - offsets;
% Calculate indices
indices = round(linspace(1,size(input,1),nPieces+1));
% For creation of calculation image:
minmaxXY = round([max(input(:,1)),max(input(:,2))]);
%thisXSYS = getThisXY(index);
%
%tortuosityImage = zeros([minmaxXY(2)+10,minmaxXY(1)+10]);
% tortuosityImage = insertShape(tortuosityImage,'line',...
% 	xsys,'color','r');
% tortuosityImage = tortuosityImage(:,:,1)>0;
% if visualize
% 	togglefig('tortuosity')
% 	imgH = imshow(tortuosityImage);
% end

mydist = @(p1,p2) sqrt((p1(1)-p1(2))^2 + (p2(1)-p2(2))^2);
count = 1;
dists = zeros(nPieces,1);
pathlengths = zeros(nPieces,1);
%epp = [];
delete(findall(imgca,'tag','tmpAnnotation'))
for ii = 1:nPieces
	if isempty(imgSize)
		tortuosityImage = zeros([minmaxXY(2)+10,minmaxXY(1)+10]);
	else
		tortuosityImage = zeros(imgSize(1),imgSize(2));
	end
	[thisXYFlat,thisXY] = getThisXY(input,indices,count);
	tortuosityImage = insertShape(tortuosityImage,'line',...
		thisXYFlat,'color','r');
	tortuosityImage = tortuosityImage(:,:,1)>0;
	r = round([thisXY(1,2) thisXY(end,2)]);
	c = round([thisXY(1,1),thisXY(end,1)]);
	if any([r<0,c<0,r>size(tortuosityImage,1),c>size(tortuosityImage,2)])
		dists(count) = NaN;
		pathlengths(count) = NaN;
		count = count + 1;
		continue;
	end
% 	if 0 && visualize
% 		if ~isempty(epp)
% 			set(epp,'Marker','.','Color','b');
% 		end
% 		togglefig('tortuosity')
% 		imshow(tortuosityImage)
% 		hold on
% 		epp = plot(c,r,'ro');
% 		drawnow
% 	end
	dists(count) = mydist(r,c);
	% size(tortuosityImage)
	pathlengths(count) = ...
	max(max(bwdistgeodesic(tortuosityImage,c(1),r(1),...
		'quasi-euclidean')));
	if visualize
		hold on
		text(thisAx,mean(c)+offsets(1),mean(r)+offsets(2),num2str(pathlengths(count)/dists(count),2),...
			'BackgroundColor','k',...
			'Color','w',...
			'FontWeight','bold',...
			'FontSize',6,...
			'Tag','tmpAnnotation')
		drawnow
	end
	count = count + 1;
end
piecewiseTortuosity = pathlengths./dists;
piecewiseTortuosity(isinf(piecewiseTortuosity)) = NaN;
piecewiseTortuosity = imresize(piecewiseTortuosity,[featureLength,1],'nearest');
if 0 && visualize
	togglefig('Tortuosity Plot')
	plot(piecewiseTortuosity)
	title(['Mean Tortuosity: ', num2str(mean(piecewiseTortuosity),3), '; STD: ', num2str(std(piecewiseTortuosity),3)]);
end

function [thisXYFlat,thisXY] = getThisXY(input,indices,index)
% This is the form required by insertShape:
thisXY = input(indices(index):indices(index+1),:);
thisXYFlat = thisXY';
thisXYFlat = thisXYFlat(:)';
