clear all; close all; clc;

[XX,YY,M,Mcolor] = get_google_map(35.10224,-106.56546,'Zoom', 19,'MapType','satellite');
% Plot the result
imagesc(M);
shading flat;
colormap(Mcolor)