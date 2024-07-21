function [UCM,objType] = uniqueContextMenus(roi)
% [UCM,objType] = uniqueContextMenus(roi)
% 
% Brett Shoelson, PhD
% brett.shoelson@mathworks.com
% 6/11/2015

% Copyright The MathWorks, Inc. 2015

allObj = findall(roi);
uicms = get(allObj,'UIContextMenu');
% UNIQUE doesn't work for directly UIContextMenus
[UCM,inds] = unique([uicms{:}],'stable');
% I add +1 to keep the order correct, since the first object in allObj is
% the roi itself--which doesn't have a uicontextmenu
objType = get(allObj(inds+1),'tag');