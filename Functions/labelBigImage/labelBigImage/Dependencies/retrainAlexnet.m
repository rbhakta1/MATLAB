function [net,testDS] = retrainAlexnet(imds,varargin)
% NET = RETRAINALEXNET(IMDS)
%
% brett.shoelson@mathworks.com
% 02/25/2018

% Copyright 2018 The MathWorks, Inc.

% Input parsing
[pctForTraining,readFcn,writeLocation] = ...
	parseInputs(varargin{:});
imds.ReadFcn = readFcn;

net = alexnet;
layers = net.Layers;
%%% RETRAIN
%% Partition the data into a train and test set
% By default, we will use 70% of images per category to train, and specify
% 30% as a validation set to test our network after it has been trained. 
rng(0)
[trainDS,testDS] = splitEachLabel(imds,pctForTraining,'randomize',true);
testDS.ReadFcn = readFcn;
%testNetwork = true;

%Display each label and the number of images in each category
tbl = countEachLabel(trainDS);
disp(tbl)
nClasses = height(tbl);

%%% Alter network to fit our desired output
layers(23) = fullyConnectedLayer(nClasses, 'Name','fc8');
layers(25) = classificationLayer('Name','myNewClassifier');

%%% Setup learning rates for fine-tuning
layers = freezeWeights(layers);
% functions = { ...
%     @plotTrainingAccuracy, ...
%     @(info) stopTrainingAtThreshold(info,99.5)};
miniBatchSize = 16; % number of images it processes at once
maxEpochs = 48; % one epoch is one complete pass through the training data
% lower the batch size if your GPU runs out of memory
% 'ExecutionEnvironment' — Hardware resource for trainNetwork
% {'auto' (default) | 'cpu' | 'gpu' | 'multi-gpu' | 'parallel'}
% ('multi-gpu' is for local multi-gpu configurations.)
execEnv = 'gpu';
opts = trainingOptions('sgdm', ...
    'Verbose', true, ...
    'LearnRateSchedule', 'none',...
    'InitialLearnRate', 0.0001,...
    'MaxEpochs', maxEpochs, ...
    'MiniBatchSize', miniBatchSize,...
    'ExecutionEnvironment',execEnv);%,...
    %'OutputFcn',functions
%
tic
net = trainNetwork(trainDS, layers, opts);
save(fullfile(writeLocation,'TrainedNetworks',['AN_Net',datestr(now,30),'.mat']),'net','testDS');
toc
%%% Test new classifier on validation set
% if testNetwork
% 	% If you want, you can slim down the test set
% 	tic
% 	[labels,~] = classify(net, testDS, 'MiniBatchSize', miniBatchSize);
% 	toc
% end
% 
% % confMat = confusionmat(testDS.Labels, labels);
% % confMat = confMat./sum(confMat,2);
% % mean(diag(confMat))
% 
% tbl = testDS.countEachLabel;
% t = zeros(nClasses,length(labels));
% y = t;
% for ii = 1:nClasses
% 	y(ii,:) = labels == tbl.Label(ii);
% 	t(ii,:) = testDS.Labels == tbl.Label(ii);
% end
% cm = plotconfusion(t,y);
% cma = findall(cm,'type','axes');
% cma.XTickLabel = [string(tbl.Label);""];
% cma.YTickLabel = [string(tbl.Label);""];

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
        I = imresize(I,[227 227]);
    end

end