close all; clc;

% This code writes images from the webcame to a directory.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Acquire images

cam = webcam;
img_dir = 'E:\img_dir';
start = i;
for i = start:start+50
    img = snapshot(cam);
    bin_img = mat2gray(rgb2gray(img))>0.4;
    filename = strcat('img',num2str(i),'.png');
    imwrite(img,fullfile(img_dir,filename));
    image(img)
    pause(0.2);
end

clear('cam');

% Process Images

% Visualize or save







