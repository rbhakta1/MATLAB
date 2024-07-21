function subimg = getMontageImage(thisImage,tilesToRead)
%Note: the image-out version of montage breaks my code. Not sure why. Don't
%      change this drawing to a temporary figure!
tmpFig = figure('visible','off');
if verLessThan('images','10.2')
    montage(thisImage,'Size',size(tilesToRead'));
else
    montage(thisImage,'Size',size(tilesToRead'),'Thumbnail', []);
end
%subimg = subimg.CData;
subimg = getimage(imgca);
close(tmpFig);
