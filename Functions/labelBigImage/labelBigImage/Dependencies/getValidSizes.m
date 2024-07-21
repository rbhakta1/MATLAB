function [validSize,scaleFactor] = getValidSizes(info)
% Helper function for downsampleBigTiff.
%
% Brett Shoelson, PhD
% brett.shoelson@mathworks.com

% Copyright The MathWorks, Inc. 2019.

try
    dicomInformation = info(1).ImageDescription;
    % GET VALID SIZES:
    % Dicom Pixel Spacing:
    dps = strfind(dicomInformation,'DICOM_PIXEL_SPACING');
    if isempty(dps)
        try %#ok<TRYNC>
            scaleFactor = [];
            validSize = nan(numel(info),2);
            for ii = 1:numel(info)
                validSize(ii,:) = [info(ii).Height,info(ii).Width];
            end
            return
        end
    end
    scaleFactor = nan(numel(dps)-1,1); %FIRST OCCURRENCE IS PUZZLING
    validSize = nan(numel(dps)-1,2);
    for ii = 2:numel(dps)
        substr = dicomInformation(dps(ii):dps(ii)+100);
        expression = '&quot;\d+\.?\d*&quot;';
        [a,b] = regexp(substr,expression);
        scaleFactor(ii-1) = str2double(substr(a+6:b-6));
        validSize(ii-1,:) = floor([info(1).Height,info(1).Width] * scaleFactor(1)/scaleFactor(ii-1));
        %validSize(ii-1,:) = [info(1).Height,info(1).Width] * scaleFactor(1)/scaleFactor(ii-1);
    end
catch
    scaleFactor = [];
    validSize = nan(numel(info),2);
    for ii = 1:numel(info)
        validSize(ii,:) = [info(ii).Height,info(ii).Width];
    end
end