function imout = lpmpr(im, sigma, t, s, c) 
 %
 % Low-Pass filter with Morphologically Processed Residuals
 %
 % im - input image
 % sigma - sigma of the Gaussian filter
 % t - amplitude threshold
 % s - size threshold
 % c - contrast coefficient
 % imout - output (filtered) image
 %
 % MATLAB Version: 9.6.0.1135713 (R2019a) Update 3
 % Image Processing Toolbox Version 10.4 (R2019a)
 %
 % (c) Marcin Iwanowski 1.07.2020
 % version 1.0
 %
 % The method has been described in the following paper:
 % "Edge-aware color image manipulation by combination of low-pass linear
 % filter and morphological processing of its residuals"
 %
 % For references check the MATLAB File Exchange page related to this
 % project
 %

 imin = im2double(im);
 imf = imgaussfilt(imin,sigma);
 diff = imin - imf;
 d{1} = diff.*double(diff>0);
 d{2} = -diff.*double(diff<=0);
 if (size(im,3) == 1) % graylevel input image
     for k=1:2
         marker = d{k}.*double(bwareaopen(d{k} > t,s));
         m{k} = imreconstruct(marker,d{k});
     end   
 else % color input image
     for k=1:2      
         marker = double(bwareaopen((rgb2gray(d{k}) - t) > 0,s)).*d{k};  
         for j=1:size(im,3)       
             m{k}(:,:,j) = imreconstruct(marker(:,:,j),d{k}(:,:,j)); 
         end 
     end
 end  
 imout = imf + m{1}*c - m{2}*c;
end