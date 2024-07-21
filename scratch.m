clear all; close all; clc;

tic;
ExpectedMaxFreq = 50;
Fs = 1000;            % Sampling frequency                    
T = 1/Fs;             % Sampling period       
L = 100000;             % Length of signal
Sections = floor(L/(ExpectedMaxFreq*20));
SamplesPerSection = floor(L/Sections);
indexs = 1:SamplesPerSection:L;
t = (0:L-1)*T;        % Time vector
paddingMultiplier = 10;
xwindow = [3.98 4.02];
ywindow = [0 0.1];

S = 0.7*sin(2*pi*4*t) + sin(2*pi*7*t);
X = S + 2*randn(size(t));

%% Basic FFTs
% Take FFT
Y = fft(X,L);
P2 = abs(Y/L);
P1 = P2(1:L/2+1);
P1(2:end-1) = 2*P1(2:end-1);
f = Fs/L*(0:(L/2));

% Padded FFT
NewL = L*paddingMultiplier;
Y_padded = fft(X,NewL);
P2_padded = abs(Y_padded/(NewL));
P1_padded = P2_padded(1:(NewL)/2+1);
P1_padded(2:end-1) = 2*P1_padded(2:end-1);
f_padded = Fs/(NewL)*(0:((NewL)/2));

% Windowed FFT
Y_windowed = fft(X'.*hamming(L),L);
P2_windowed = abs(Y_windowed/(L));
P1_windowed = P2_windowed(1:(L)/2+1);
P1_windowed(2:end-1) = 2*P1_windowed(2:end-1);
f_windowed = Fs/(L)*(0:((L)/2));

% Windowed and padded FFT
Y_windowed_padded = fft(X'.*hamming(L),NewL);
P2_windowed_padded = abs(Y_windowed_padded/(NewL));
P1_windowed_padded = P2_windowed_padded(1:(NewL)/2+1);
P1_windowed_padded(2:end-1) = 2*P1_windowed_padded(2:end-1);
f_windowed_padded = Fs/(NewL)*(0:((NewL)/2));
%% Plots 1
figure(1);
subplot(3,2,1)
plot(1000*t,X)
title("Signal Corrupted with Zero-Mean Random Noise")
xlabel("t (milliseconds)")
ylabel("X(t)")
subplot(3,2,2)
plot(Fs/L*(-L/2:L/2-1),abs(fftshift(Y)),"LineWidth",3)
title("fft Spectrum in the Positive and Negative Frequencies")
xlabel("f (Hz)")
ylabel("|fft(X)|")
subplot(3,2,3)
plot(f,P1,"LineWidth",3) 
title("Single-Sided Amplitude Spectrum of X(t)")
xlabel("f (Hz)")
ylabel("|P1(f)|")
xlim(xwindow)
ylim(ywindow)
subplot(3,2,4)
plot(f_padded,P1_padded,"LineWidth",3) 
title('fft of padded signal')
xlabel("f (Hz)")
ylabel("|P1(f)|")
xlim(xwindow)
ylim(ywindow)
subplot(3,2,5)
plot(f_windowed,P1_windowed,"LineWidth",3) 
title('fft of windowed signal')
xlabel("f (Hz)")
ylabel("|P1(f)|")
xlim(xwindow)
ylim(ywindow)
subplot(3,2,6)
plot(f_windowed_padded,P1_windowed_padded,"LineWidth",3) 
title('fft of windowed and padded zeros signal')
xlabel("f (Hz)")
ylabel("|P1(f)|")
xlim(xwindow)
ylim(ywindow)
%% Next Lever FFTs
% Split signal into sections and avg FFTs]
count = 0;
P1_avg = zeros(Sections,SamplesPerSection+1);
Y_avg = zeros(1,(SamplesPerSection+1));
for i = 1:Sections-1
    count = count+1;
    Y_avg = fft(X(indexs(i):indexs(i+1)),SamplesPerSection+1);
    P2_avg(count,:) = abs(Y_avg/SamplesPerSection+1);
end
P2_avg = mean(P2_avg,1);
P1_avg = P2_avg(1:(SamplesPerSection+1)/2+1);
P1_avg(2:end-1) = 2*P1_avg(2:end-1);
P1_avg = P1_avg - mean(P1_avg)+0.05;
f_avg = Fs/(SamplesPerSection+1)*(0:((SamplesPerSection+1)/2));

% Split signal into sections and zero pad then avg
count = 0;
NewL = (SamplesPerSection+1)*paddingMultiplier;
P1_avg_zero = zeros(Sections,NewL);
Y_avg_zero = zeros(1,(NewL));
for i = 1:Sections-1
    count = count+1;
    Y_avg_zero = fft(X(indexs(i):indexs(i+1)),NewL);
    P2_avg_zero(count,:) = abs(Y_avg_zero/NewL);
end
P2_avg_zero = mean(P2_avg_zero,1);
P1_avg_zero = P2_avg_zero(1:(NewL)/2+1);
P1_avg_zero(2:end-1) = 2*P1_avg_zero(2:end-1);
P1_avg_zero = P1_avg_zero - mean(P1_avg_zero)+0.05;
f_avg_zero = Fs/(NewL)*(0:((NewL)/2));

% Split signal into sections and window then avg
count = 0;
NewL = (SamplesPerSection+1);
P1_avg_window = zeros(Sections,NewL);
Y_avg_window = zeros(1,(NewL));
for i = 1:Sections-1
    count = count+1;
    Y_avg_window = fft(X(indexs(i):indexs(i+1))'.*hamming(NewL),NewL);
    P2_avg_window(count,:) = abs(Y_avg_window/NewL);
end
P2_avg_window = mean(P2_avg_window,1);
P1_avg_window = P2_avg_window(1:(NewL)/2+1);
P1_avg_window(2:end-1) = 2*P1_avg_window(2:end-1);
P1_avg_window = P1_avg_window - mean(P1_avg_window)+0.05;
f_avg_window = Fs/(NewL)*(0:((NewL)/2));

% Split signal into sections, window, zero pad, and then avg
% Split signal into sections and window then avg
count = 0;
NewL = (SamplesPerSection+1)*paddingMultiplier;
P1_avg_window_zero = zeros(Sections,NewL);
Y_avg_window_zero = zeros(1,(NewL));
for i = 1:Sections-1
    count = count+1;
    Y_avg_window_zero = fft(X(indexs(i):indexs(i+1))'.*hamming(NewL/paddingMultiplier),NewL);
    P2_avg_window_zero(count,:) = abs(Y_avg_window_zero/NewL);
end
P2_avg_window_zero = mean(P2_avg_window_zero,1);
P1_avg_window_zero = P2_avg_window_zero(1:(NewL)/2+1);
P1_avg_window_zero(2:end-1) = 2*P1_avg_window_zero(2:end-1);
P1_avg_window_zero = P1_avg_window_zero - mean(P1_avg_window_zero)+0.05;
f_avg_window_zero = Fs/(NewL)*(0:((NewL)/2));

%% Plots 2
figure(2);
subplot(3,2,1)
plot(f_windowed_padded,P1_windowed_padded,"LineWidth",3) 
title('fft of windowed and padded zeros signal, no averaging')
xlabel("f (Hz)")
ylabel("|P1(f)|")
xlim(xwindow)
ylim(ywindow)
subplot(3,2,2)
plot(f_avg,P1_avg,"LineWidth",3) 
title('fft of averaged signal')
xlabel("f (Hz)")
ylabel("|P1(f)|")
xlim(xwindow)
ylim(ywindow)
subplot(3,2,3)
plot(f_avg_zero,P1_avg_zero,"LineWidth",3) 
title('fft of zero padded averaged signal')
xlabel("f (Hz)")
ylabel("|P1(f)|")
xlim(xwindow)
ylim(ywindow)
subplot(3,2,4)
plot(f_avg_window,P1_avg_window,"LineWidth",3) 
title('fft of windowed averaged signal')
xlabel("f (Hz)")
ylabel("|P1(f)|")
xlim(xwindow)
ylim(ywindow)
subplot(3,2,4)
plot(f_avg_window_zero,P1_avg_window_zero,"LineWidth",3) 
title('fft of windowed and then zero padded averaged signal')
xlabel("f (Hz)")
ylabel("|P1(f)|")
xlim(xwindow)
ylim(ywindow)
subplot(3,2,5)

xlabel("f (Hz)")
ylabel("|P1(f)|")
[~,f,Power,N]=FFT(X,Fs);
psdy = Power(1:2^(N-1));
plot(f,psdy,'r'),  xlabel('  Frequency (Hz)'), ylabel(' Magnitude (w)'),
title('  Power Spectral Density'), grid on;
xlim(xwindow)
ylim(ywindow)

subplot(3,2,6)
xlabel("f (Hz)")
ylabel("|P1(f)|")
X = X'.*hamming(L);
addZeros = zeros(1,length(X)*paddingMultiplier)';
X = [X; addZeros];
[~,f,Power,N]=FFT(X,Fs);
ploty = Power(1:2^(N-1));
plot(f,ploty.*50,'r'),  xlabel('  Frequency (Hz)'), ylabel(' Magnitude (w)'),
title('  Power Spectral Density of windowed and zero padded signal'), grid on;
xlim(xwindow)
ylim(ywindow)

%% Super Saiyan 3 FFTs
% Choose a section size, scan across signal with section size to generate
% L - sectionsize "unique" signals, then window, zero pad, and average
% count = 0;
% NewI = L - SamplesPerSection;
% NewL = (SamplesPerSection+1)*paddingMultiplier;
% Scanned_P1_avg_window_zero = zeros(Sections,NewI);
% Scanned_Y_avg_window_zero = zeros(1,NewL);
% for i = 1:NewI
%     count = count+1;
%     Scanned_Y_avg_window_zero = fft(X(i:i+SamplesPerSection)'.*hamming(NewL/paddingMultiplier),NewL);
%     Scanned_P2_avg_window_zero(count,:) = abs(Scanned_Y_avg_window_zero/NewL);
% end
% 
% Scanned_P2_avg_window_zero = mean(Scanned_P2_avg_window_zero,1);
% Scanned_P1_avg_window_zero = Scanned_P2_avg_window_zero(1:(NewL)/2+1);
% Scanned_P1_avg_window_zero(2:end-1) = 2*Scanned_P1_avg_window_zero(2:end-1);
% Scanned_P1_avg_window_zero = Scanned_P1_avg_window_zero - mean(Scanned_P1_avg_window_zero)+0.05;
% Scanned_f_avg_window_zero = Fs/(NewL)*(0:((NewL)/2));

% Average FFTs from signal size of L, then L/2, L/3, L/4, etc. sizes, then
% window, zero pad, and average
% cascades = 3;
% queryFreq = 1:(((L+1)*paddingMultiplier/2)+1);
% paddingMultiplier = 4;
% count = 0;
% for j = 1:cascades
%     SamplesPerSection = floor(L/j);
%     NewL = (SamplesPerSection+1)*paddingMultiplier;
%     Cascade_P1_avg_window_zero = zeros(j,NewL);
%     Cascade_Y_avg_window_zero = zeros(1,(NewL));
%     indexs = floor(linspace(1,L,j+1));
%     for i = 1:j
%         count = count+1;
%         Cascade_Y_avg_window_zero = fft(X(indexs(i):indexs(i+1))'.*hamming((NewL-1)/paddingMultiplier-1),NewL);
%         Cascade_P2_avg_window_zero = abs(Cascade_Y_avg_window_zero/NewL);
%         xaxis = Fs/(NewL)*(0:((NewL)/2));
%         Cascade_P2_avg_window_zero = interp1(xaxis,Cascade_P2_avg_window_zero,queryFreq);
%         Cascade_P2_avg_window_zero(count,:) = Cascade_P2_avg_window_zero;
%     end
%     
% end
% 
% Cascade_P2_avg_window_zero = mean(Cascade_P2_avg_window_zero,1);
% Cascade_P1_avg_window_zero = Cascade_P2_avg_window_zero(1:(NewL)/2+1);
% Cascade_P1_avg_window_zero(2:end-1) = 2*Cascade_P1_avg_window_zero(2:end-1);
% Cascade_P1_avg_window_zero = Cascade_P1_avg_window_zero - mean(Cascade_P1_avg_window_zero)+0.05;
% Cascade_f_avg_window_zero = Fs/(NewL)*(0:((NewL)/2));

%% Plots 3
%subplot(3,2,5)
% plot(Scanned_f_avg_window_zero,Scanned_P1_avg_window_zero,"LineWidth",3) 
% title('fft of signal scanned then windowed and then zero padded averaged signal')
% xlabel("f (Hz)")
% ylabel("|P1(f)|")
% xlim(xwindow)
% ylim(ywindow)

toc;














