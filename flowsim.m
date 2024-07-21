clear all; close all; clc;


% Constants
Nx = 400;
Ny = 100;
tau = 0.53; % timescale and kinematic viscocity
Nt = 3000; % timescale

% lattice speed and weights
NL = 9;
cxs = [0 0 1 1 1 0 -1 -1 -1];
cys = [0 1 1 0 -1 -1 -1 0 1];
weights = [4/9 1/9 1/36 1/9 1/36 1/9 1/36 1/9 1/36];

% initial conditions

F = ones(Nx,Ny,NL) + 0.01*randn(Nx, Ny, NL);
F(:,:,4) = 2.3;

cylinder = zeros(Nx,Ny);

