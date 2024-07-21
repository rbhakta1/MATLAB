clear all; close all; clc;

lat = 35.10224;
long = -106.56546;

[XX,YY,M,Mcolor] = get_google_map(lat,long,'Zoom', 19,'MapType','satellite');
[XX,YY,M2,M2color] = get_google_map(lat,long+0.0004,'Zoom', 19,'MapType','satellite');
% M = imgaussfilt(M,2);
% M2 = imgaussfilt(M2,2);
subM = abs(M2-M);

%Plots
figure(1);
subplot(2,2,1)
title('Original Image');
imshow(M,[1 256]);
xlim([0 640])
ylim([0 640])
axis equal;
shading flat;
colormap(Mcolor)
subplot(2,2,2)
title('Shifted Image');
imshow(M2,[1 256]);
xlim([0 640])
ylim([0 640])
axis equal;
shading flat;
colormap(M2color)
subplot(2,2,3)
title('Subtracted Image');
imshow(subM);
axis equal;
xlim([0 640])
ylim([0 640])


