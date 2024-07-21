function [net,valImages] = retrainGooglenet(imds,varargin)
% NET = RETRAINGOOGLENET(IMDS)
%
% brett.shoelson@mathworks.com
% 02/25/2018

% Copyright 2018 The MathWorks, Inc.

% Input parsing
[pctForTraining,readFcn,writeLocation] = ...
	parseInputs(varargin{:});
imds.ReadFcn = readFcn;

%%% RETRAIN
%% Partition the data into a train and test set
% By default, we will use 70% of images per category to train, and specify
% 30% as a validation set to test our network after it has been trained. 
rng(0)
[trainImages,valImages] = splitEachLabel(imds,pctForTraining,'randomized');
valImages = valImages.splitEachLabel(50);
valImages.ReadFcn = readFcn;


net = googlenet;
lgraph = layerGraph(net);
lgraph = removeLayers(lgraph, {'loss3-classifier','prob','output'});

numClasses = numel(categories(trainImages.Labels));
newLayers = [
    fullyConnectedLayer(numClasses,'Name','fc','WeightLearnRateFactor',20,'BiasLearnRateFactor', 20)
    softmaxLayer('Name','softmax')
    classificationLayer('Name','classoutput')];
lgraph = addLayers(lgraph,newLayers);
% Connect the last of the transferred layers remaining in the network
% (|'pool5-drop_7x7_s1'|) to the new layers. To check that the new layers
% are correctly connected, plot the new layer graph and zoom in on the last
% layers of the network.
lgraph = connectLayers(lgraph,'pool5-drop_7x7_s1','fc');
options = trainingOptions('sgdm',...
    'MiniBatchSize',3,...
    'ExecutionEnvironment','cpu',...
    'MaxEpochs',3,...
    'InitialLearnRate',1e-4,...
    'VerboseFrequency',1,...
    'ValidationData',valImages,...
    'ValidationFrequency',3);

%%
% Train the network using the training data.
net = trainNetwork(trainImages,lgraph,options);
save(fullfile(writeLocation,['GN_Net',datestr(now,30),'.mat']),'net','valImages');

%%
% Classify the validation images using the fine-tuned network, and
% calculate the classification accuracy.
predictedLabels = classify(net,valImages);
accuracy = mean(predictedLabels == valImages.Labels);
disp(accuracy)
%Display each label and the number of images in each category
tbl = countEachLabel(trainDS);
disp(tbl)
nClasses = height(tbl);

tbl = testDS.countEachLabel;
t = zeros(nClasses,length(labels));
y = t;
for ii = 1:nClasses
	y(ii,:) = labels == tbl.Label(ii);
	t(ii,:) = testDS.Labels == tbl.Label(ii);
end
cm = plotconfusion(t,y);
cma = findall(cm,'type','axes');
cma.XTickLabel = [string(tbl.Label);""];
cma.YTickLabel = [string(tbl.Label);""];

    function [pctForTraining,readFcn,writeLocation] = parseInputs(varargin)
        % Setup parser with defaults
        parser = inputParser;
        parser.CaseSensitive = false;
        parser.addParameter('pctForTraining', 0.7);
        parser.addParameter('readFcn', @readAndPreprocessImage);
        parser.addParameter('writeLocation', pwd);
        % Parse input
        parser.parse(varargin{:});
        % Assign outputs
        r = parser.Results;
        [pctForTraining,readFcn,writeLocation] = ...
            deal(r.pctForTraining,r.readFcn,r.writeLocation);
    end %parseInputs

    function I = readAndPreprocessImage(filename)
        % Alexnet training images must be 227x227:
        I = imread(filename);
        I = imresize(I,[224 224]);
    end

end