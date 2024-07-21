function descriptors = getSynchronizedImageDescriptors(synROI)
% Get descriptors (features, colors, textures, border tortuosity) of
% image under synchronizedROI
%
% % EXAMPLE
% img1 = imread('peppers.png');
% hAx(1) = subplot(1,2,1);
% imshow(img1);
% img2 = imresize(img1,2);
% hAx(2) = subplot(1,2,2);
% imshow(img2);
% title('Draw Freehand Here')
% h = imfreehand;
% synROI = synchronizedImfreehands(h,'ROIParentHandles',hAx);
% %
% synROI.samplingOpts.extractorType = 'Auto';
% synROI.samplingOpts.featureType = 'SURF';
% synROI.samplingOpts.includeColor = true; %(default)
% synROI.samplingOpts.includePiecewiseTortuosity = true; %(default; 64 segments)
% synROI.samplingOpts.includeTexture = true; %(default)
% synROI.samplingOpts.verboseAnnotations = [false,true]; %(default is FALSE)
% % SAMPLE ROIs 1 and 2:
% synROI.samplingOpts.indsOfROIsToSampleWhenMoved = [1,2];
% descriptors = getSynchronizedImageDescriptors(synROI);
% %synROI.getSynchronizedImageDescriptors
%
% % ALTERNATIVELY:
% set(gcf,'WindowButtonUpFcn',@(p,evt)getSynchronizedImageDescriptors(synROI))
% disp('NOTE: ''descriptors'' is stored in synROI.regionDescriptors.')
%
%
% Brett Shoelson, PhD
% brett.shoelson@mathworks.com
% 12/15/2017
%
% SEE ALSO: synchronizedROI getTrainingTilesFromIMROI

% Copyright 2017 The MathWorks, Inc.

% if isequal(newPos,roiPositions)
% 	disp('The synROI has not moved.')
% 	descriptors = [];
% 	return
% end
if isempty(synROI.samplingOpts.indsOfROIsToSampleWhenMoved) || ...
		(~isempty(synROI.regionDescriptors) && synROI.isLocked)
	% I believe this should be low-enough overhead that I can add the
	% function handle automatically, and disregard it if not needed...
	descriptors = [];
	return
end
set(gcf,'pointer','watch')
% TempRectangles are created in getTrainingTilesFromIMROI. I delete
% them here to facilitate verbose annotations across multiple axes.
delete(findall(imgcf,'tag','TempRectangle'))
delete(findall(imgcf,'tag','tmpAnnotation'))
drawnow
nROIsToSample = numel(synROI.samplingOpts.indsOfROIsToSampleWhenMoved);
descriptorStruct = struct(...
	'AugmentedDescriptors',[],...
	'Colors',[],...
	'Features',[],...
	'FeatureDescriptors',[],...
	'GrayIntensity',[],...
	'NumFeatures',[],...
	'PiecewiseTortuosity',[],...
	'PointLocationIndices',[],...
	'PointLocations',[],...
	'TextureDescriptors',[],...
	'TrainingImage',[]);

descriptors(1,nROIsToSample) = ...
	descriptorStruct;

for ii = 1:nROIsToSample
	thisInd = synROI.samplingOpts.indsOfROIsToSampleWhenMoved(ii);
	%[trainingImage,nTrainingTiles] = getTrainingTilesFromIMROI(img,positions,ax,boxW,boxH,verbose)
	trainingImage = getTrainingTilesFromIMROI(synROI.samplingOpts.parentImages{thisInd},...
		synROI.ROIPositions{thisInd},...
		synROI.ROIParentHandles(thisInd),...
		synROI.samplingOpts.boxW(thisInd),...
		synROI.samplingOpts.boxH(thisInd),...
		synROI.samplingOpts.verboseAnnotations(thisInd));
	drawnow;
	descriptors(thisInd).TrainingImage = trainingImage;
	if isempty(trainingImage)
		continue
	end
	imIsRGB = size(descriptors(thisInd).TrainingImage,3)==3;
	if imIsRGB
		[r,g,b ] = getImagePlanes(descriptors(thisInd).TrainingImage);
		grayImg = rgb2gray(descriptors(thisInd).TrainingImage);
	else
		grayImg = descriptors(thisInd).TrainingImage;
	end
	
	% Features:
	if strcmp(synROI.samplingOpts.featureType,'SURF')
		descriptors(thisInd).Features = detectSURFFeatures(grayImg);
	else
		beep;
		disp('getImageDescriptors: NOT YET')
		return
	end
	% PointLocations: (x,y) = (col,row)
	descriptors(thisInd).PointLocations = round(descriptors(thisInd).Features.Location);
	row = descriptors(thisInd).PointLocations(:,2);
	col = descriptors(thisInd).PointLocations(:,1);
	descriptors(thisInd).PointLocationIndices = sub2ind(size(grayImg),row,col);
	% FeatureDescriptors:
	if strcmp(synROI.samplingOpts.extractorType,'Auto')
		descriptors(thisInd).FeatureDescriptors = extractFeatures(grayImg,descriptors(thisInd).Features);
	else
		beep;
		disp('getImageDescriptors: NOT YET')
		return
	end
	% NumFeatures
	descriptors(thisInd).NumFeatures = size(descriptors(thisInd).FeatureDescriptors,1);
	% Colors:
	if imIsRGB && synROI.samplingOpts.includeColor
		descriptors(thisInd).Colors = ...
			[r(descriptors(thisInd).PointLocationIndices),...
			g(descriptors(thisInd).PointLocationIndices),...
			b(descriptors(thisInd).PointLocationIndices)];
		descriptors(thisInd).AugmentedDescriptors = [descriptors(thisInd).FeatureDescriptors,descriptors(thisInd).Colors];
	end
	% GrayIntensity
	descriptors(thisInd).GrayIntensity = grayImg(descriptors(thisInd).PointLocationIndices);
	descriptors(thisInd).AugmentedDescriptors = [descriptors(thisInd).AugmentedDescriptors,descriptors(thisInd).GrayIntensity];
	if synROI.samplingOpts.includeTexture
		% TextureDescriptors
		descriptors(thisInd).TextureDescriptors = calculateSampleEntropy(descriptors(thisInd).TrainingImage,...
			descriptors(thisInd).PointLocationIndices);
		descriptors(thisInd).AugmentedDescriptors = [descriptors(thisInd).AugmentedDescriptors,descriptors(thisInd).TextureDescriptors];
	end
	%
	if synROI.samplingOpts.includePiecewiseTortuosity && isa(synROI.ROI(1),'imfreehand')
		% Need to sample all ROIs to match the number of features.
		% OR: Need to resize 
		if descriptors(thisInd).NumFeatures > 0 && isempty(synROI.regionDescriptors)
            axesOffsets = [synROI.ROIParentHandles(thisInd).XLim(1),synROI.ROIParentHandles(thisInd).YLim(1)]-0.5;
			pwc = calculatePiecewiseTortuosity(synROI.ROI(thisInd),...
				descriptors(thisInd).NumFeatures,...
				synROI.samplingOpts.verboseAnnotations(thisInd),...
				size(synROI.samplingOpts.parentImages{thisInd}),...
                axesOffsets);
			descriptors(thisInd).PiecewiseTortuosity = pwc;
			descriptors(thisInd).AugmentedDescriptors = [descriptors(thisInd).AugmentedDescriptors,pwc];
		else
			nFeatures = size(descriptors(thisInd).AugmentedDescriptors,1);
			descriptors(thisInd).AugmentedDescriptors = [descriptors(thisInd).AugmentedDescriptors,nan(nFeatures,1)];
		end
		synROI.regionDescriptors = descriptors;
	end
	
end % for ii = 1:nROIsToSample
set(gcf,'pointer','arrow')

	function efi = calculateSampleEntropy(img,locations)
		nSamples = size(locations,1);
		[M,N] = size(img(:,:,1));
		nPixels = M*N;
		% NHOOD = true(11) translates to these offsets:
		offsets = [-5*M-5:-5*M+5;
			-4*M-5:-4*M+5;
			-3*M-5:-3*M+5;
			-2*M-5:-2*M+5;
			-1*M-5:-1*M+5;
			0-5:0+5;
			1*M-5:1*M+5;
			2*M-5:2*M+5;
			3*M-5:3*M+5;
			4*M-5:4*M+5;
			5*M-5:5*M+5]';
		efi = zeros(nSamples,1);
% 		figure
% 		imshow(img)
% 		hold on
		for jj = 1:nSamples
			inds = locations(jj)+offsets;
% 			[r,c] = ind2sub(size(img(:,:,1)),inds);
% 			plot(c,r,'k.');
			if imIsRGB
				subimg = rgb2gray(cat(3,img(inds),img(inds+nPixels),img(inds+2*nPixels)));
			else
				subimg = img(inds);
			end
			efi(jj) = entropy(subimg);
		end
	end %calculateSampleEntropy

end % getSynchronizedImageDescriptors