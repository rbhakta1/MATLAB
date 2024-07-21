function [id, parentFigHndl] = addImroiButtonUpCallback(hndl,fcnHndl,triggerOnlyOnNewPos)
% Adds a WindowButtonUpCallback to an existing Imroi or
% synchronizedImroi. Triggers on buttonUp rather than on
% reposition--useful if the callback is expensive!
%
% SYNTAX:
% id = addImroiButtonUpCallback(hndl,fcnHndl,triggerOnlyOnNewPos);
% 
% INPUTS:
% hndl
%    Handle to the Imroi object or synchronizedImroi you want to modify.
%
% fcnHndl
%    Handle to the function you want to add.
%
% triggerOnlyOnNewPos
%    Logical true/false. Indicates whether you want to trigger the
%    callback whenever the Imroi is clicked, or only when it is
%    repositioned. Default: false.
%
% OUTPUT:
% id
%    The identification handle for the callback added to the
%    windowButtonUpFcn of the parent figure.
%
% parentFigHndl
%    The handle to the parent figure.
%
% NOTE: To remove the callback, use:
% 
% iptremovecallback(parentFigHndl, 'WindowButtonUpFcn', id)
% 
% (where parentFigHndl is the handle to the parent figure, as returned
% in the second output argument).
%
% % EXAMPLES
% 
% % Example 1: IMRECT
% figure
% imshow('cameraman.tif');
% hndl = imrect(gca, [10 10 100 100]);
% fcn = makeConstrainToRectFcn('imrect',get(gca,'XLim'),get(gca,'YLim'));
% setPositionConstraintFcn(hndl,fcn);
% titleFcn = @(p) title(mat2str(p,3));
% 
% % THIS TRIGGERS MULTIPLE CALLBACKS AS THE IMROI IS DRAGGED:
%     % addNewPositionCallback(hndl,titleFcn);
%     %
% % WHEREAS THIS TRIGGERS THE CALLBACK ONLY ON MOUSEUP:
% newTitleFcn = @(hndl) title(mat2str(hndl.getPosition,3));
% addImroiButtonUpCallback(hndl,newTitleFcn,true);
%
% % Example 2: IMPOLY
% figure
% imshow('rice.png');
% title('Move impoly or add or delete a vertex')
% p = [90 50;45 135;120 140;200 140;180 50];
% hndl = impoly(imgca, p);
% testFcn = @(hndl) fprintf('Number of vertices: %i\n',size(hndl.getPosition,1));
% addImroiButtonUpCallback(hndl,testFcn,true);
%
% % Example 3: synchronizedImfreehands
% img1 = imread('peppers.png');
% hAx(1) = subplot(1,2,1);
% imshow(img1);
% img2 = imresize(img1,2);
% hAx(2) = subplot(1,2,2);
% imshow(img2);
% title('Draw Freehand Here')
% hndl = imfreehand;
% synROI = synchronizedImfreehands(hndl,'ROIParentHandles',hAx);
% titleFcn = @(p) title(mat2str(p,3));
% addImroiButtonUpCallback(synROI,titleFcn);

%
% 
% Brett Shoelson, PhD
% brett.shoelson@mathworks.com
% 12/21/2016
% 12/17/2017 Modified to work with synchronizedROIs
%
% SEE ALSO: imroi, imrect, impoly, imfreehand, impoint, imellipse,
% synchronizedROI

% Copyright 2016-2017 The MathWorks, Inc.

persistent previousPosition

% Argument Checking:
narginchk(2, 3)
isSynROI = isa(hndl,'synchronizedROI');
if ~(isa(hndl,'imroi') || isSynROI) || ~isvalid(hndl)
	error('addImroiButtonUpFcn: First argument must be a handle to a valid Imroi object or to a synchronizedROI');
end
if ~isa(fcnHndl,'function_handle')
	error('addImroiButtonUpFcn: Second argument must be a function handle.');
end
if nargin < 3
	triggerOnlyOnNewPos = false;
elseif triggerOnlyOnNewPos
	if isSynROI
		previousPosition = hndl.ROIPositions{hndl.idxActiveROI};
	else
		previousPosition = hndl.getPosition;
	end
end

% Get parent figure for storage of windowButtonUpFcn:
parentFigHndl = getParentFig(hndl);
if ~isSynROI
	% Get a list of all objects comprising hndl. Manipulating any of them
	% must trigger the callback.
	allImroiObjects = findall(hndl);
end

% Modify WindowButtonUpFcn of parent figure to trigger action on
% manipulation of imroi object
id = iptaddcallback(parentFigHndl,'WindowButtonUpFcn',@testForTrigger);
% nVerts = size(hndl.getPosition,1);
% addNewPositionCallback(hndl,@testForVertexNumberChange);

	function pf = getParentFig(hndl)
		if isSynROI
			pf = ancestor(hndl.ROIParentHandles(1),'figure');
		else %imroi
			p = findall(hndl,'type','patch');
			pf = ancestor(p,'figure');
		end
	end %getParentFig

	function testForTrigger(varargin)
		co = get(parentFigHndl,'CurrentObject');
		% Not sure why I added isa(hndl,'imrect'); it disables the
		% triggering of overviewRegionSelector in bigImageLabeler!
		% imrect doesn't have an 
		if ~isa(hndl,'imrect')
			if isempty(co) || (~isSynROI && ~ismember(co,allImroiObjects)) || ~isvalid(hndl.activeROI)% || isa(hndl,'imrect')
				return
			end
		end
		if triggerOnlyOnNewPos
			if isSynROI
				try
					currentPosition = hndl.activeROI.getPosition;
				catch
					disp('Hmmm...Not sure how I ended up here.')
				end
			else
				currentPosition = hndl.getPosition;
			end
			if isequal(currentPosition,previousPosition)
				return
			end
			% Update position monitor:
			previousPosition = currentPosition;
		end
		
		% TRIGGER!
		feval(fcnHndl,hndl);
	end

% 	function testForVertexNumberChange(varargin)
% 		%Vertex deletion or addition should also trigger callback!
% 		nVertsNow = size(hndl.getPosition,1);
% 		if nVerts ~= nVertsNow
% 			nVerts = nVertsNow;
% 			feval(fcnHndl,hndl);
% 		end
% 	end

end %addImroiButtonUpCallback
