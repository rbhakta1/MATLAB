%
% This is an example showing hot to use 'lpmfr.m' function
% Low-Pass filter with Morphologically Processed Residuals
%
% MATLAB Version: 9.6.0.1135713 (R2019a) Update 3
% Image Processing Toolbox Version 10.4 (R2019a)
%
% (c) Marcin Iwanowski 1.07.2020
% version 1.0

clear all 
im = imread('moko.png'); % im - input image
t = 0.15;   % t - amplitude threshold
s = 300;    % s - size threshold
c = 1.2 ;  % c - contrast coefficient
sigma = 20 ; % sigma of the Gaussian filter

imout = lpmpr(im,sigma,t,s,c);  % imout - output (filtered) image

imshow([im2double(im) imout]);
set(gcf,'name',strcat('lpmfr:  t = ',string(t),', s = ',string(s),', c = ', string(c)),'NumberTitle','off')

