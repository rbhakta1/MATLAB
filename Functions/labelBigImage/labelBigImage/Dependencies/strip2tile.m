function strip2tile(inFile, outFile, tileSize)
% Helper function for downsampleBigTiff, provided by Ashish Uthama (MathWorks).
%
% Supported/maintained by:
%    Brett Shoelson, PhD
%    brett.shoelson@mathworks.com

% Copyright The MathWorks, Inc. 2019.

if nargin==2
    tileSize = [128 128];
end

inInfo = imfinfo(inFile);

outTiff = Tiff(outFile,'w');


for resInd = 1:numel(inInfo)
    inInfoForThisLayer = inInfo(resInd);
    
    % TODO - update tileSize
    
    % This is tricky - i.e would you want compression? Should you set that based
    % on input ..etc? Right now, it assumes RGB input, and no compression.
    if strcmp(inInfoForThisLayer.ColorType,'grayscale')
        setTag(outTiff,'Photometric',Tiff.Photometric.MinIsBlack);
        setTag(outTiff,'BitsPerSample',8);    
        setTag(outTiff,'SamplesPerPixel',1);
    else
        setTag(outTiff,'Photometric',Tiff.Photometric.RGB);
        setTag(outTiff,'BitsPerSample',8);    
        setTag(outTiff,'SamplesPerPixel',3);
    end        
    setTag(outTiff,'SampleFormat',Tiff.SampleFormat.UInt);
    setTag(outTiff,'ImageLength',inInfoForThisLayer.Height);
    setTag(outTiff,'ImageWidth',inInfoForThisLayer.Width);
    setTag(outTiff,'TileLength',tileSize(1));
    setTag(outTiff,'TileWidth',tileSize(2));
    setTag(outTiff,'PlanarConfiguration',Tiff.PlanarConfiguration.Chunky);
    
    for tiledRowInd = (1:floor(inInfoForThisLayer.Height/tileSize(1)))-1
        rows = [tiledRowInd*tileSize(1)+1, tiledRowInd*tileSize(1)+tileSize(1)];
        rows(2) = min(rows(2), inInfoForThisLayer.Height);
        cols = [1 inInfoForThisLayer.Width];
        tiledStrip = imread(inFile,'Index', resInd, 'PixelRegion', {rows, cols});
        
        for tiledColInd = (1:floor(inInfoForThisLayer.Width/tileSize(2)))-1
            tcols = [tiledColInd*tileSize(1)+1, tiledColInd*tileSize(1)+tileSize(1)];
            tcols(2) = min(tcols(2), inInfoForThisLayer.Width);
            tileData = tiledStrip(:, tcols(1):tcols(2), :);
            
            tileInd = outTiff.computeTile([rows(1), tcols(1)]);
            outTiff.writeEncodedTile(tileInd, tileData);
        end
    end
        
    if resInd~=numel(inInfo)
        % Write this director(layer) and setup another
        outTiff.writeDirectory()
    end    
end


outTiff.close();

end