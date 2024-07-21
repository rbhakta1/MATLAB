%
% This is an script that allow for tuning the parameters od lpmpr filter
%
% The image is displayed in the separate window along with the result of
% processing. Using a keyborad the user can change valuess of parameters
% having all the time view on the processing result.
%
% In the window, three images are shown:
% on the left:   input image
% in the middle: result of processing with a current set of parameters
% on the right:  saved result (with one of the previous sets of params)
%
% The saved image is provided to comapre result of processing with 
% different sets of parameters 
%
% Possible actions:
%
% q - decrease t by large step (0.1)
% w - decrease t by small step (0.01)
% e - increase t by small step (0.01)
% r - increase t by large step (0.1)
%
% a - decrease s by large step (1)
% s - decrease s by small step (10)
% d - increase s by small step (10)
% f - increase s by large step (1)
%
% z - decrease c by large step (0.1)
% x - decrease c by small step (0.01)
% c - increase c by small step (0.01)
% v - increase c by large step (0.1)
%
% o - decrease sigma by 1
% p - increase sigma by 1
%
% = - save the current result (will be kept in the right position)
% l - change orientation of three images (vertica/horizontal)
% ESC - end
%
% (c) Marcin Iwanowski 14.09.2020
% version 1.0

 clear all
 
 % filename
 fname = 'moko.png'
 % initial values of parameters
 sigma = 15
 t = 0.1;
 s = 50;
 % ----
 c = 1.1;
 im = imread(fname);
 smax = 1500; sstep_slow = 1; sstep_fast = 10;
 cmax = 3; cstep_slow = 0.01; cstep_fast = 0.1;
 tmax = 1;  tstep_slow = 0.01; tstep_fast = 0.1;
 maxsigma = 20
 vertical = (size(im,1)>size(im,2));
 endloop = false;
 modif = true;
 imout_save = false;
 imsaved = im2double(im);
 saved_title = 'copy of the original';
 while ~endloop
    if modif   
        imout = lpmpr(im,sigma,t,s,c);
        current_title = strcat(' sigma = ', string(sigma),  ', t =', string(t), ', s = ', string(s),', c = ', string(c));
        if (imout_save == true)
         imout_save = false;
         imsaved = imout;
         saved_title = current_title;
         imwrite(imout, strcat(fname(1:end-4), '_', string(sigma), '_', string(t), '_', string(s),'_', string(c),'.png'));
         beep
        end
        if vertical imshow([im2double(im) imout imsaved]);
        else imshow([im2double(im); imout; imsaved]);
        end
        set(gcf,'name',strcat('LPFMR (', fname,') CURRENT:', current_title, ' SAVED:', saved_title ),'NumberTitle','off')
        modif = false;
    end
    k = waitforbuttonpress;   
    ch = get(gcf,'CurrentCharacter');
    switch(ch)
        case 27
             endloop = 1;
        case int8('q')
             modif = true; t = t - tstep_fast; if t<0 t=0; end
        case int8('w')
             modif = true; t = t - tstep_slow; if t<0 t=0; end    
        case int8('e')
             modif = true; t = t + tstep_slow; if t>tmax t=tmax; end
        case int8('r')
             modif = true; t = t + tstep_fast; if t>tmax t=tmax; end       
        case int8('a')
             modif = true; s = s - sstep_fast; if s<0 s=0; end
        case int8('s')
             modif = true; s = s - sstep_slow; if s<0 s=0; end    
        case int8('d')
             modif = true; s = s + sstep_slow; if s>smax s=smax; end
        case int8('f')
             modif = true; s = s + sstep_fast; if s>smax s=smax; end   
        case int8('z')
             modif = true; c = c - cstep_fast; if c<0 c=0; end
        case int8('x')
             modif = true; c = c - cstep_slow; if c<0 c=0; end    
        case int8('c')
             modif = true; c = c + cstep_slow; if c>cmax c=cmax; end
        case int8('v')
             modif = true; c = c + cstep_fast; if c>cmax c=cmax; end  
        case int8('o')
             modif = true; sigma = sigma - 1; if sigma<1 sigma=1; end
        case int8('p')
             modif = true; sigma = sigma + 1; if sigma>maxsigma sigma=maxsigma; end
        case int8('=')
             imout_save = true; modif = true;
        case int8('l')
             vertical = ~vertical; modif = true;
    end
 end
