function outStruct = saveAsStruct(arrayOfSynROIs,imref2dObj)
%outStruct = saveAsStruct(arrayOfSynROIs,imref2dObj)
%
% Saves a struct containing the class and intrinsic and world coordinates
% for a collection of synROIs (as returned by findSynchronizedROIs).
%
% Brett Shoelson, PhD
% bshoelso@mathworks.com
% 05/27/19
%
% See also: findSynchronizedROIs

% Copyright 2019 The MathWorks, Inc.

if nargin == 2
    includeWorld = true;
    outStruct = struct('Class',[],...
        'IntrinsicCoordinates',[],...
        'WorldCoordinates',[],...
        'Label','');
else
    includeWorld = false;
    outStruct = struct('Class',[],...
        'IntrinsicCoordinates',...
        'Label','');
end

for ii = numel(arrayOfSynROIs):-1:1
    thisSynROI = arrayOfSynROIs{ii};
    outStruct(ii).Class = class(thisSynROI.activeROI);
    worldCoords = thisSynROI.ROI(1).getPosition;
    if includeWorld
        outStruct(ii).WorldCoordinates = worldCoords;
        [thisIntrinsicX, thisIntrinsicY] = intrinsicToWorld(imref2dObj,worldCoords(:,1),worldCoords(:,2));
    else
       thisIntrinsicX = worldCoords(:,1);
       thisIntrinsicY = worldCoords(:,2);
    end
    outStruct(ii).IntrinsicCoordinates = [thisIntrinsicX, thisIntrinsicY];
    outStruct(ii).Label = thisSynROI.label;
end