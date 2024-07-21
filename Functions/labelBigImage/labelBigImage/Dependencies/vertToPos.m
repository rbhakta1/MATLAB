function posn = vertToPos(vert)
% Convert from vertices of a rectangle to a position vector ([xmin ymin width height])
%
% Many functions in MATLAB and in Toolboxes specify rectangular regions in
% terms of "positions": [xmin ymin width height]. Many others require
% specification of the vertices of bounding regions. This function, and its
% companion |posToVert|, facilitates easy conversion between them.
%
% SYNTAX:
% posn = vertToPos(posn)
% vert = vertToPos(posn,closed)
%
% INPUTS:
% vert: a 4x2, 5x2, or 2x2 vector of the [x,y] vertices of a rectangular region.
%       Should be of the form ([x(:),y(:)]) and should span min-max of xs
%       and ys.
%
% closed (optional): indicates whether the returned vertices should be
%       "closed", meaning that the last vertex will be repeated. Logical
%       true/false. (Default: false);
%
% OUTPUTS: 
% posn: a 4-element vector indicating the position of a rectangular region,
%       as [xmin ymin width height]
%
% EXAMPLE:
% % RECTANGLES and PATCHES
% % Rectangles are specified using "position," [x y w h]; patches are
% % specified using vertices. This example demonstrates that once either is
% % specified, you can calculate the other.
%
% t = 0:pi/32:6;
% plot(t,sin(t),'r-',t,cos(t),'b--')
% legend({'Sine','Cosine'});
% % FOR DEMONSTRATION, create two rectangles. The first we
% %   specify by [x y w h]:
% posn = [pi/4-0.25 sin(pi/4)-0.1 0.5 0.2];
% xy = posToVert(posn);
% rectangle('position',posn,...
% 	'linewidth',2,'edgecolor','r');
% h = patch(xy(:,1),xy(:,2),'c',...
% 	'facealpha',0.5,'linestyle','--','linewidth',2);
% % The second, we specify using vertices of polygon:
% xy = [5*pi/4-0.25 5*pi/4+0.25 5*pi/4+0.25 5*pi/4-0.25;
% 	sin(5*pi/4)-0.1 sin(5*pi/4)-0.1 sin(5*pi/4)+0.1 sin(5*pi/4)+0.1]';
% posn = vertToPos(xy);
% rectangle('Position',posn,...
% 	'linewidth',2,'edgecolor','r');
% patch(xy(:,1),xy(:,2),'y',...
% 	'facealpha',0.5,'linestyle','--','linewidth',2);
% title({'Rectangles are specified with position vectors';...
% 	'Patches are specified by vertices'})
%
% Brett Shoelson, PhD.
% brett.shoelson@mathworks.com
% 12/08/2014
%
% See also: posToVert

% Copyright 2014 The MathWorks, Inc.

narginchk(1,1)
[m,n] = size(vert);

validTypes = {'single','double','int16','int32', 'uint8', 'uint16', 'uint32'};
validateattributes(vert,validTypes,{'nonsparse','real','nonnan'}, ...
    mfilename,'vert',1);

if m == 2 && n ~= 2
    vert = vert';      
end
xs = vert(:,1);
ys = vert(:,2);
posn = [min(xs) min(ys) max(xs)-min(xs) max(ys)-min(ys)];