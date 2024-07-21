function [plane1,plane2,plane3] = getImagePlanes(I)
% Extract individual planes from an MxNx3 image, or from an axis containing
% an MxNx3 image.
% 
% [PLANE1,PLANE2,PLANE3] = GETIMAGEPLANES(I)
%   Extracts the individual (color) planes from the MxNx3 image specified
%   in I. I may be an image or an axes containing a single MXNx3 image.
%   Returns in 'plane1' the 1st z-plane (img(:,:,1)); in 'plane2', the 2nd
%   z-plane (img(:,:,2)); and in plane3, the 3rd z-plane (img(:,:,3)).
%
% Now, it's just: 
%        [r,g,b] = getImagePlanes(img); 
% or 
%        [r,g,b] = getImagePlanes(gca); 
% 
% instead! Simple, but useful! 
%
%%% EXAMPLES:
% %% Example 1:
% img = imread('peppers.png');
% [r,g,b] = getImagePlanes(img);
%
% %% Example 2:
% imshow('peppers.png');
% [r,g,b] = getImagePlanes(gca);
%
% Brett Shoelson, PhD
% brett.shoelson@mathworks.com
% 5/23/2014

% Copyright 2014 The Mathworks, Inc.

if numel(I) == 1
%if ishandle(I)
	% This requires the Image Processing Toolbox:
	% I = imhandles(I);
	% This does not:
	I = findall(I,'type','image');
	if isempty(I) || numel(I) > 1 
		error('Specified axis must contain exactly one RGB image')
	end
	I = get(I,'cdata');
end
if size(I,3) ~= 3
	error('Image does not have 3 planes.');
end
plane1 = I(:,:,1);
plane2 = I(:,:,2);
plane3 = I(:,:,3);
