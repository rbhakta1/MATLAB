clear all; close all; clc;

img = zeros(100);

img(40:45,1:30) = 1;
img(40:45,70:100) = 1;

m_img = bwmorph(img,'thin');
for i = 1:5
    m_img = bwmorph(m_img,'thin');
end

d_img = imdilate(m_img, strel('disk',5));
e_img = imdilate(d_img, strel('line',20,0));

f_img = bwmorph(e_img,'thin');
for i = 1:5
    f_img = bwmorph(f_img,'thin');
end

g_img = imdilate(f_img, strel('disk',5));
h_img = imdilate(g_img, strel('line',20,0));

i_img = bwmorph(h_img, 'thin');
for i = 1:5
    i_img = bwmorph(i_img,'thin');
end

j_img = imdilate(i_img, strel('square',10));

figure;
subplot(3,3,1)
imshow(img)
title('A: Original Image')
subplot(3,3,2)
imshow(m_img)
title('B: Thinned A(x5 times)')
subplot(3,3,3)
imshow(d_img)
title('C: Dilated B with disk')
subplot(3,3,4)
imshow(e_img)
title('D: Dilated C with line')
subplot(3,3,5)
imshow(f_img)
title('E: Thinned D after line')
subplot(3,3,6)
imshow(g_img)
title('F: Dilated E with disk')
subplot(3,3,7)
imshow(h_img)
title('G: Dilated F with line')
subplot(3,3,8)
imshow(i_img)
title('H: Thinned G(x5 times)')
subplot(3,3,9)
imshow(j_img)
title('I: Dilated H with square')