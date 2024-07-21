% layers = freezeWeights(layers) sets the learning rates of all the
% parameters of the layers in the layer array |layers| to zero.

function layers = freezeWeights(layers,verbose)
if nargin < 2
    verbose = false;
else 
    disp('FREEZING WEIGHTS!')
    disp(' ')
end

for ii = 1:size(layers,1)
    props = properties(layers(ii));
    for p = 1:numel(props)
        propName = props{p};
        if ~isempty(regexp(propName, 'LearnRateFactor$', 'once'))
            if verbose
                fprintf('Layer %i: Layer Name: %s; %s: 0; (Was %0.2f)\n',ii,layers(ii).Name,propName,layers(ii).(propName));
            end
            layers(ii).(propName) = 0;
        end
    end
end

if verbose
    disp(' ')
end
end



