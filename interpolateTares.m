function[interpolateTares] = interpolateTares(pitchZerosFilename, correctedAOA)

    % Corrected AOA is the true angle of attack for the model, corrected
    % from the pitch angle using model loading information
    
    % Read table of pitch angle and all bridge outputs taken during initial zeros
    pitchZeros = readtable(pitchZerosFilename);

    % Fit of pitch angle during no flow vs. NF bridge output
    polynomialFit = polyfit(pitchZeros.Var2,pitchZeros.Var3,2);
    
    % Expected zeros bridge outputs for corrected AOA during run
    % NF
    interpolateTares = polyval(polynomialFit,correctedAOA);
end