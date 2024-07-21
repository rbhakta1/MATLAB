clear all; close all; clc;

%function[car_boolean, car_loc_img] = car_locator(img_dir, img)

% This code processes images and finds if there is a car in the image and
% highlights the car.

% Read in the images. 
cam = webcam;
img_dir = 'E:\img_dir';
folder = fullfile(img_dir,'*.png');
img_files = dir(folder);
% 
% for i = 1:50
%     img = snapshot(cam);
%     image(img)
%     pause(0.2);
% end
% close

% Intializations
rect = [135,215,424,138];
img_tare = snapshot(cam);
roi_tare = img_tare(rect(2):rect(2)+rect(4),rect(1):rect(1)+rect(3));
j = 0;
car_count = 0;

while j < 1
    
    color_img = snapshot(cam);
    current_img = rgb2gray(color_img);
    img_roi = current_img(rect(2):rect(2)+rect(4),rect(1):rect(1)+rect(3));
    
    sub_img = abs(roi_tare-img_roi); % Subtract tare and live image
    bin_img = sub_img>30; % Keep only large changes in the image
    sedisk = strel('disk',6); % Create disk object of radius 10 pixels
    open_img = imopen(bin_img, sedisk); % Open image with object
    
    count = sum(sum(open_img)); % Add up all the bright pixels in image
    
    if count>200 % If the number of changed pixels is greater than 300, it's a car.
        is_car = 1;
    else         % Else, no car
        is_car = 0;
    end
    
    % If there is a car, wait 3 seconds for it to pass and then check
    % again.
    
    if is_car == 1
        pause(0.3) % Wait till the car is in frame better
        car_count = car_count+1;
        c = clock; fix(c); %get date/time and round it
        time(:, car_count) = c; 
        
        color_img_resnap = snapshot(cam);
        color_roi_resnap = color_img_resnap(rect(2):rect(2)+rect(4),rect(1):rect(1)+rect(3),:);
        imwrite(color_roi_resnap,fullfile(img_dir,strcat('img',num2str(car_count),'.png')));
        image(color_roi_resnap)
        set(gcf, 'Position',  [800, 500, rect(3), rect(4)])
        pause(2.7);
        close
    end
    
    pause(0.2); % Limit framerate of 5 Hz
    
end



