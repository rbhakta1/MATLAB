function [allSynROI,allLabels,allUniqueIDs] = findSynchronizedROIs(parent,...
    varargin)
% [allSynROI,allLabels] = findSynchronizedROIsNEW(parent,varargin)
%
% Find all synchronizedROI's that are children of parent, matching search
% criteria.
%
% Specify type {'all', 'synchronizedImpoly', 'synchronizedImfreehand',...
% 'synchronizedImrect', 'synchronizedImline', or 'synchronizedImpoint'} to
% get the handles of the existing synchronizedROI objects. Specify label to
% find synchronizedROI's matching a particular label or feature value.
%
% SYNTAX:
% [x,y] = findSynchronizedROIs(parent,varargin);
% 
% Parent: the search parent
%
% OPTIONAL PVs:
% 'exactMatch', {T/F}
%    If true, search strings exactly; else strings matched if they are
%       contained in search strings. DEFAULT: False.
% 'queryFields'
%    Cell array of valid fields of a synchronizedROI object that you want
%    to search. %a = get(thisSynROI); fieldnames(a)
% 'queryValues'
%    Cell array of matching values. Should be the same size as queryFields.
% 'type'
%    Match type for searches. {'all',...
%      'synchronizedImfreehands',...
%      'synchronizedImrects',...
%      'synchronizedImpolys'}; %Etc.
%    DEFAULT: 'all'
%
% % EXAMPLE:
% [sROIs,labels,uniqueIDs] = findSynchronizedROIsNEW(ax,...
%    'queryFields', {'label', 'validated'},...
%    'queryValues', {'B',true});
% 
% Brett Shoelson, PhD
% brett.shoelson@mathworks.com
% 06/01/19
% Meant as a replacement for older version of findSynchronizedROIs
%
% See also: synchronizedROI synchronizedImfreehands
% synchronizedImpolys synchronizedImrects

% Copyright 2019 The MathWorks, Inc.

% Input parsing
[exactMatch, queryFields, queryValues, type] = ...
    parseInputs(varargin{:});
    
allSynROI = [];

if ~isa(type,'cell')
    switch type
        case 'all'
            searchString = 'synchronized';
        case {'poly','impoly','synchronizedImpolys'}
            searchString = 'synchronizedImpolys';
        case{'freehand','imfreehand','synchronizedImfreehands'}
            searchString = 'synchronizedImfreehands';
        case {'imrect','synchronizedImrects'}
            searchString = 'synchronizedImrects';
        case {'line','imline','synchronizedImlines'}
            searchString = 'synchronizedImlines';
        case {'point','impoint','synchronizedImpoints'}
            searchString = 'synchronizedImpoints';
        otherwise
            error('findSynchronizedROIs: Unrecognized input ''type''. Please use one of {''all'', ''impoly'', ''imfreehand'', ''imrect'', ''imline'', or ''impoint''}.');
    end
else
    searchString = 'synchronized';
end

if strcmp(type,'all')
    allSynROI = [
        findall(parent,'type','hggroup','tag','synchronizedImfreehands');
        findall(parent,'type','hggroup','tag','synchronizedImpolys');
        findall(parent,'type','hggroup','tag','synchronizedImrects');
        findall(parent,'type','hggroup','tag','synchronizedImlines');
        findall(parent,'type','hggroup','tag','synchronizedImpoints')];
elseif isa(type,'cell')
    for ii = 1:numel(type)
        allSynROI  = cat(1,allSynROI,...
            findall(parent,'type','hggroup','tag',type{ii}));
    end
else
    allSynROI = findall(parent,'type','hggroup','tag',searchString);
end
if isempty(allSynROI)
	allLabels = {};
	return
end

allSynROIInfo = get(allSynROI,'Tag');
if exactMatch
    allSynROI = allSynROI(ismember(allSynROIInfo,searchString));
else
    allSynROI = allSynROI(contains(allSynROIInfo,searchString));
end
if isempty(allSynROI)
    allLabels = {};
    return
end

tmpUD = get(allSynROI,'UserData');
% In case there is only one:
if ~iscell(tmpUD)
	tmpUD = {tmpUD};
end

keepVals = true(numel(allSynROI),1);
% EVALUATE ALL QUERYFIELD/VALUE PAIRS
for ii = 1:numel(queryFields)
    thisQuery = queryFields{ii};
    thisValue = queryValues{ii};
    thisFcn = str2func(sprintf('@(x)x.%s',thisQuery));
    searchResult = cellfun(thisFcn,tmpUD,'UniformOutput',false);
    empty = cellfun(@isempty,searchResult);
    searchResult(empty) = {false};
    if ~ischar(thisValue)
        searchResult = cell2mat(searchResult);
    end
    matched = ismember(searchResult,thisValue);
    keepVals = keepVals & matched;
end
allSynROI = tmpUD(keepVals);
allLabels = cellfun(@(x){x.label},allSynROI);
allUniqueIDs = cellfun(@(x){x.uniqueIdentifier},allSynROI);
allUniqueIDs = cell2mat(allUniqueIDs);
end

function [exactMatch, queryFields, queryValues, type] = ...
    parseInputs(varargin)
% Setup parser with defaults
parser = inputParser;
parser.CaseSensitive = false;
parser.addParameter('exactMatch', false);%'synchronized' works for all
parser.addParameter('queryFields', {});
parser.addParameter('queryValues', {});
parser.addParameter('type', 'all');
% Parse input
parser.parse(varargin{:});
% Assign outputs
r = parser.Results;
[exactMatch, queryFields, queryValues, type] = ...
    deal(r.exactMatch, r.queryFields, r.queryValues, r.type);
end %parseInputs
