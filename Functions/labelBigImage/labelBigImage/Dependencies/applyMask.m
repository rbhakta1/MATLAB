function [rgbMasked,rMasked,gMasked,bMasked] = applyMask(rgb,mask,bg)
% Create a masked version of an RGB image, with optional specification
% of background. Optionally, return individual masked colorplanes.
% Image is returned as type 'double.'
%
% SYNTAX:
% [rgbMasked,rMasked,gmasked,bmasked] = applyMask(rgb,mask)
%    Apply 'mask' planewise to the colorplanes of rgb.
% [...] = applyMask(rgb,mask,bg)
%    Specify the background type as one of {'k','w','rand'}. 'k'
%    specifies black background; 'w' specifies white background, and
%    'rand' specifies random background. Default: 'k'.
%    
% % EXAMPLE:
%   img = imread('peppers.png');
%   rgbIndices = rgb2ind(img,5);       
%   mask = imbinarize(img(:,:,1));
%   [rgbMasked,rMasked,gMasked,bMasked] = applyMask(img,mask,0);
%   figure;
%   subplot(2,3,1);
%   imshow(img);
%   title('Original RGB')
%   subplot(2,3,2)
%   imshow(rgbMasked);
%   title('RGB Masked')
%   subplot(2,3,3);
%   imshow(rMasked);
%   title('Red Masked')
%   subplot(2,3,4);
%   imshow(mask)
%   title('Mask')
%   subplot(2,3,5)
%   imshow(gMasked);
%   title('Green Masked')
%   subplot(2,3,6);
%   imshow(bMasked);
%   title('Blue Masked')
%
% Brett Shoelson, PhD
% 11/17/16

% Copyright MathWorks, Inc. 2016

narginchk(2, 3)
if nargin < 3
	bg = 0;
end
if ~islogical(mask) || ~isequal(size(mask),size(rgb(:,:,1)))
	error('applyMask: ''mask'' must be logical image the same dimensions as rgb.')
end

rgb = im2double(rgb);
if isnan(bg)
	replval = NaN;
else
	switch bg
		case {'k','black',0}
			replval = 0;
		case {'w','white',1}
			replval = 1;
		case 'NaN'
			replval = NaN;
		case 'rand'
			replval = 'rand';
		otherwise
			error('Unrecognized ''bg'' parameter in applyMask.');
	end
end
[rMasked,gMasked,bMasked] = getImagePlanes(rgb);
%if ~isnan(replval) && ~(ischar(replval) && strcmp(replval,'rand'))
if ~(ischar(replval) && strcmp(replval,'rand'))
	rMasked(~mask) = replval;
	gMasked(~mask) = replval;
	bMasked(~mask) = replval;
else%if (ischar(replval) && strcmp(replval,'rand'))
	rMasked = ~mask.*rand(size(mask))+im2double(rgb(:,:,1).*mask);
	gMasked = ~mask.*rand(size(mask))+im2double(rgb(:,:,2).*mask);
	bMasked = ~mask.*rand(size(mask))+im2double(rgb(:,:,3).*mask);
%else %NanN
end
rgbMasked = cat(3,rMasked,gMasked,bMasked);
