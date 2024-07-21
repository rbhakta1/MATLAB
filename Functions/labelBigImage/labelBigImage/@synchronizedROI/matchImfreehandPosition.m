function matchImfreehandPosition(h,hRef,refObj)
% Workaround for lack of setPosition method for imfreehand (useful for
% synchronizedROI/synchronizedImfreehands.
%
% USAGE:
% matchImfreehandPosition(thisFreehandROI,referenceFreehandROI)
%
% % EXAMPLE:
% figure;
% ax(1) = subplot(1,2,1);
% h1 = imfreehand;
% ax(2) = subplot(1,2,2);
% h2 = imfreehand;
% pause(1)
% matchImfreehandPosition(h2,h1);
%
% Brett Shoelson, PhD
% brett.shoelson@mathworks.com
% 11/02/2017

% Copyright 2017 The MathWorks, Inc.

refLines = findobj(hRef,'type','Line');
thisROILines = findobj(h,'type','Line');
if nargin < 3
	refObj = [];
end
for ii = 1:numel(refLines) %(4)
	XD = refLines(ii).XData;
	YD = refLines(ii).YData;
	if ~isempty(refObj)
		[XD,YD] = intrinsicToWorld(refObj,XD,YD);
	end
	thisROILines(ii).XData = XD;
	thisROILines(ii).YData = YD;
end
refPatch = findobj(hRef,'type','Patch');
thisROIPatch = findobj(h,'type','Patch');
thisROIPatch.Faces = refPatch.Faces;
verts = refPatch.Vertices;
if ~isempty(refObj)
	[XV,YV] = intrinsicToWorld(refObj,verts(:,1),verts(:,2));
else
	XV = verts(:,1);
	YV = verts(:,2);
end
thisROIPatch.Vertices = [XV,YV];