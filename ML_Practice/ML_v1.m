%clear all; close all; clc;

oldpath = addpath(fullfile(matlabroot,'examples','nnet','main'));
filenameImagesTrain = 'train-images.idx3-ubyte';
filenameLabelsTrain = 'train-labels.idx1-ubyte';
filenameImagesTest = 't10k-images.idx3-ubyte';
filenameLabelsTest = 't10k-labels.idx1-ubyte';

imgDataTrain = processImagesMNIST(filenameImagesTrain);
labelsTrain = processLabelsMNIST(filenameLabelsTrain);
% XTest = processImagesMNIST(filenameImagesTest);
% YTest = processLabelsMNIST(filenameLabelsTest);

layers = [
    imageInputLayer([28 28 1])
	
    convolution2dLayer(3,16,'Padding',1)
    batchNormalizationLayer
    reluLayer
	
    maxPooling2dLayer(2,'Stride',2)
	
    convolution2dLayer(3,32,'Padding',1)
    batchNormalizationLayer
    reluLayer
	
    maxPooling2dLayer(2,'Stride',2)
	
    convolution2dLayer(3,64,'Padding',1)
    batchNormalizationLayer
    reluLayer
	
    fullyConnectedLayer(10)
    softmaxLayer
    classificationLayer];

miniBatchSize = 8192;
options = trainingOptions( 'sgdm','MiniBatchSize', miniBatchSize,'Plots',...
    'training-progress','InitialLearnRate',0.01,'MaxEpochs',30);

net_0 = trainNetwork(imgDataTrain, labelsTrain, layers, options);
net = trainNetwork(imgDataTrain, labelsTrain, layers_1, options);
net2 = trainNetwork(imgDataTrain, labelsTrain, layers_2, options);
net3 = trainNetwork(imgDataTrain, labelsTrain, layers_3, options);
net4 = trainNetwork(imgDataTrain, labelsTrain, layers_4, options);
net5 = trainNetwork(imgDataTrain, labelsTrain, layers_5, options);
net6 = trainNetwork(imgDataTrain, labelsTrain, layers_6, options);
net7 = trainNetwork(imgDataTrain, labelsTrain, lgraph_1, options);

% y = extractdata(imgDataTrain);
% for i = 1:100
%     pause(0.2)
%     imshow(y(1:28,1:28,1,i))
% end

