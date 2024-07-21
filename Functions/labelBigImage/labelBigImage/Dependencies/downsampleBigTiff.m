function [smallImage,imref,pageInfo,tiffImageClass,tiledTF,currMPP,info] = downsampleBigTiff(fName,info,varargin)
% [smallImage,imref,pageInfo,tiffImageClass,tiledTF,currMPP,info] = downsampleBigTiff(fName,info,ParamValues)
% 
% Read file parseable by Tiff-class reader; may be tiff, svs.
%
% INPUTS:
% 
% fName      Name of file to read
%
% info       The output of imfinfo operated on fName. (If not specified, use
%            [] as a placeholder. (This allows successive calls to
%            downsampleBigTiff without re-calling imfinfo.)
%
% dsFactor   Optional downsampling factor; allows specification of
%            downsampling in call call to imread(..., 'PixelRegion',{[1
%            dsFactor pageInfo.Height] [1 dsFactor pageInfo.Width]}); (See
%            doc for imread.) It is used ONLY if the default call to imread
%            fails to generate the targeted thumbnail. Default:
%            2048/(maximum image dimension).
%
% page       Optional specification of page of multipage image to be read.
%            Default: 1.
%
% verbose    Optional flag to specify verbose writing of read parameters,
%            and read time, to Command Window. Default: true.
%
% OUTPUTS:
%
% smallImage
%            Thumbnail, or overview image.
%
% imref      Referencing information to allow bidirectional mapping from
%            full resolution image to overview (thumbnail).
%
% pageInfo   The page reference from imfinfo(page).
%
% tiffImageClass
%            A struct with information about the image being
%            read, containing the value returned by Tiff(fName).
% 
% tiledTF    A flag indicating true for tiled images, false for striped. If
%            striped, a tiled version is created by an internal call to
%            strip2tile.
%
% currMPP    If it exists in the header/metadata, the "microns per pixel"
%            scaling factor for the specified file.
%
% info       The output of imfinfo operating on fName.
%
% Brett Shoelson, PhD
% brett.shoelson@mathworks.com
% With grateful acknowledgement to Ashish Uthama for his assistance.

% Copyright The MathWorks, Inc. 2019.

tic;
% Alphabetical input parsing:
if nargin < 2 || isempty(info)
    info = imfinfo(fName);
end
maxDim = max([info.Width info.Height]);
% Thumbnail/Overview image should be max 2048 x 2048:
targetSize = 2048;
if maxDim >= targetSize
    defaultDSFactor = round(maxDim/targetSize);
else
    defaultDSFactor = 1;
end
[dsFactor,page,verbose] = ...
    parseInputs(defaultDSFactor,varargin{:});
hasFigure = ~isempty(findall(groot,'type','figure'));
if hasFigure
    cp = get(gcf,'Pointer');
    set(gcf,'Pointer','watch')
end

% Create TIFF object, determine if image is tiled:
tiffImageClass = Tiff(fName,'r');
%tiledTF = isTiled(tiffImageClass);
isTiled = ~cellfun(@isempty, {info.TileLength});% Thanks, Ashish!
if ~isTiled(page)
    page = find(isTiled,1);
end
pageInfo = info(page);
setDirectory(tiffImageClass,page)
tiledTF = isTiled(page);
if tiledTF
    % IMAGE IS TILED!
    if verbose
        fprintf('Note that this is a TILED TIFF image.\n')
        %         fprintf('It contains %i tiles of %i x %i pixels.\n',...
        %             tiffImageClass.numberOfTiles,info(page).TileLength,info(page).TileWidth);
        nTiles = round((info(page).Width/info(page).TileWidth)*(info(page).Height/info(page).TileLength));
        fprintf('It contains %i tiles of %i x %i pixels.\n',...
            nTiles,info(page).TileLength,info(page).TileWidth);
    end
else
    % Stripped?
    [pn,fn,ext] = fileparts(fName);
    newFName = fullfile(pn,[fn,'_TILED',ext]);
    tiledExists = exist(newFName,'file');
    if tiledExists
        tmp = questdlg(sprintf('bigImageLabeler supports TILED Tiff images.\n(This image may be a STRIPPED image.)\nIt appears that a TILED version of the input image has already been created. Would you like to use image\n\n%s\n\ninstead?',newFName),...
            'Use Tiled Version?',...
            'USE TILED VERSION','Re-Convert to Tiled','Cancel','USE TILED VERSION');
    else
        tmp = questdlg('bigImageLabeler supports TILED Tiff images. This image may be a STRIPPED image.',...
            'Convert to tiled?',...
            'CONVERT to TILED','Cancel','CONVERT to TILED');
    end
    if strcmp(tmp,'Cancel')
        [smallImage,imref,pageInfo,tiffImageClass,tiledTF] = deal([]);
        return
    elseif ismember(tmp,{'CONVERT to TILED', 'Re-Convert to Tiled'})
        % Convert and reproduce steps as necessary:
        defaultTileSize = [512 512];
        disp('Converting to Tiled Tiff...please wait a moment.')
        strip2tile(fName,newFName,defaultTileSize);
        disp('Conversion done!')
    else %USE TILED VERSION
    end
    [smallImage,imref,pageInfo,tiffImageClass,tiledTF] = downsampleBigTiff(newFName,[],varargin{:});
    return
end

% CAN WE READ VALID THUMBNAIL FROM HIGHER PAGE?
try
    if verbose
        %Read image:
        disp('Extracting thumbnail.')
    end
    validSizes = getValidSizes(info);
    % best match:
    [~,ind] = min(abs(validSizes-targetSize));
    % NOTE: 'min' here selects the page with the next larger size;
    %       'max' selects the page with the next smaller size.
    ind = min(ind);
    smallImage = imread(fName,ind);
    smallImage = smallImage(1:validSizes(ind,1),1:validSizes(ind,2),:);
catch
    if verbose
        %Read/downsample image:
        disp('Creating thumbnail/overview image...please wait.')
        disp('(This might take a few minutes!)')
        fprintf('Downsample factor: %i\n',dsFactor);
    end
    % DOES SMALL IMAGE ALREADY EXIST???
    thumbnailStorageDir = fullfile(fileparts(which(mfilename)),'Thumbnails');
    if ~exist(thumbnailStorageDir,'dir')
        mkdir(thumbnailStorageDir);
    end
    [~,fn,ext] = fileparts(fName);
    thumbnailName = fullfile(thumbnailStorageDir,[fn '_thumbnail', ext]);
    if exist(thumbnailName,'file')
        fprintf('\nReading existing thumbnail from:\n\t%s.\n\n',thumbnailName);
        smallImage = imread(thumbnailName);
    else
        smallImage = imread(fName, page,...
            'Info', info(page),...
            'PixelRegion',{[1 dsFactor pageInfo.Height] [1 dsFactor pageInfo.Width]});
        fprintf('\nWriting thumbnail to %s.\n\n',thumbnailName);
        imwrite(smallImage,thumbnailName);
    end
end
xWorldLimits = [0 pageInfo.Width]+0.5;
yWorldLimits = [0 pageInfo.Height]+0.5;
imref = imref2d(size(smallImage),xWorldLimits,yWorldLimits);
if verbose
    fprintf('\nDone reading/downsampling image.')
    fprintf('\nOperation completed in %0.2f seconds.\n\n',toc)
    tmp = whos('smallImage');
    [h,w,c] = size(smallImage);
    fprintf('Original image is %i x %i x %i (%0.2f MB)\n',...
        pageInfo.Height,pageInfo.Width,numel(pageInfo.BitsPerSample),pageInfo.FileSize/1e6);
    fprintf('Downsampled image is %i x %i x %i (Class %s; %0.2f MB)\n\n',h,w,c,class(smallImage),tmp.bytes/1e6);
end
if hasFigure
    set(gcf,'Pointer',cp);
end
if isfield(info(1),'ImageDescription')
    try
        currDescription = info(1).ImageDescription;
        st = strfind(currDescription,'MPP = ');         % find start
        currDescription = currDescription((st+6):end);  % strip before start
        en = strfind(currDescription,'|');      % find end
        if ~isempty(en)
            currDescription = currDescription(1:(en(1)-1));    % strip after end
        else
            currDescription = [];
        end
        currMPP = str2double(currDescription);  % get MPP (microns per pixel)
    catch
        currMPP = NaN;
    end
else
    currMPP = NaN;
end
end

function [dsFactor,page,verbose] = parseInputs(defaultDSFactor,varargin)
% Setup parser with defaults
parser = inputParser;
parser.CaseSensitive = false;
parser.addParameter('dsFactor', defaultDSFactor);
parser.addParameter('page', 1);
parser.addParameter('verbose', true);
% Parse input
parser.parse(varargin{:});
% Assign outputs
r = parser.Results;
[dsFactor,page,verbose] = ...
    deal(r.dsFactor,r.page,r.verbose);
end %parseInputs