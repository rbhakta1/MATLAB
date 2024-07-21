a=imread('bookshelf.jpg');
a1=double(rgb2gray(a));
figure(1)
a2=fft2(a1);
imshow(a2,[0 10000]);
figure(2)
a3=imgaussfilt(a1,200);
imshow(a3,[0 100]);
a4=a2-a3;
figure(3)
imshow(a4,[0 10000]);
figure(4)
a5=ifftshift(a4);
imshow(a5,[0 10000]);