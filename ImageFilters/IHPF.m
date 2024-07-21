% Clear Command Window, Workspace, close all Figures
clc;clear;close all;
% Read an image e.g. cameraman.tif
a=imread('cameraman.tif');
% Display the original image
figure;imshow(a);title('Original Image')
% Find image size
[r, c]=size(a);
% Apply Fourier Transform to the original image
im_f=fft2(a);
% Display image in the Fourier transform
figure;imshow(log(abs(im_f)),[]);title('Fourier')
% Shift image to the center
f_shift=fftshift(im_f);
% Display shifted image
figure;imshow(log(abs(f_shift)),[]);title('Shifted')
% Find the center of the frequancy domain
p=r/2;
q=c/2;
% Cut-off Frequancy
d0=35;
% Initialize IHPF
idealHP = zeros(c, r);
% Create IHPF
for i=1:r
for j=1:c
D=sqrt((i-p)^2+(j-q)^2);
idealHP(i,j)=D >= d0;
end
end
% Display IHPF
figure;imshow(idealHP);
title('Ideal High Pass Filter')
% Display IHPF using meshc
figure;meshc(idealHP);
title('Ideal High Pass Filter')
axis([0 2*p 0 2*q 0 1]);
xlabel('u');ylabel('v');
zlabel('|H(u,v)|');
grid off
% Convolve shifted image with ILPF
convolveF=f_shift.*idealHP;
% Shifted back the image 
image_orignal=ifftshift(convolveF);
% Convert image to the spicial domain
RImage=abs(ifft2(image_orignal));
% Display Image in the spacial domain
figure;imshow(RImage,[]);title('Resulted Image')
