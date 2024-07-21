% Author: Raj Bhakta
% Email: rajbhakta94@gmail.com
% 
% Objective: This code reads in .mp4 video files and processes the frames
% to determine if a car is present. The images of cars are then saved in a
% folder.

clear all; close all; clc;

%% User Inputs

% Video file name
filename = 'E:\josh_imgs\converted\video0.mp4';


%% Image Processing

% Create videoreader object for the video file
v = VideoReader(fullfile(filename));

% While there are frames remaining in the video, continue looping
for i = 2:v.NumFrames

    % Read in frame
    prev_frame = read(v,i-1);
    frame = read(v,i);
    
    % Convert frame to grayscale
    gray_frame = rgb2gray(frame);
    gray_prev_frame = rgb2gray(prev_frame);

    K = imabsdiff(prev_frame,frame);
    [BW,maskedRGBImage] = colorthreshold(K);

    % Open mask with line
    length = 5;
    angle = 0.000000;
    se = strel('line', length, angle);
    BW = imopen(BW, se);

    % Dilate mask with disk
    radius = 30;
    decomposition = 0;
    se = strel('disk', radius, decomposition);
    BW = imdilate(BW, se);
    
    subplot(2,1,1)
    imshow(frame);
    subplot(2,1,2)
    imshow(BW)
    drawnow
end






