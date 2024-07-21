function [patchHndl,posn] = getPatchFromImroi(imroiHndl)
% patchHndl = getPatchFromImroi(imroiHndl)
%
% 
patchHndl = findall(imroiHndl,'type','patch');
posn = vertToPos(patchHndl.Vertices);