% Run this script first to initialize paths and start an experiment
rootDir = fileparts(mfilename('fullpath')); 

addpath(rootDir); 
addpath(fullfile(rootDir, 'config'));
addpath(fullfile(rootDir, 'session'));
addpath(fullfile(rootDir, 'hardware'));
addpath(fullfile(rootDir, 'calibration'));
addpath(fullfile(rootDir, 'gui')); 

addpath(fullfile(rootDir, 'calibration', 'FPL')); 
addpath(fullfile(rootDir, 'measures', 'transducer_check'));
addpath(fullfile(rootDir, 'measures', 'abr'));
addpath(fullfile(rootDir, 'measures', 'dpoae'));
addpath(fullfile(rootDir, 'measures', 'ear_cal'));
addpath(fullfile(rootDir, 'measures', 'efr')); 
addpath(fullfile(rootDir, 'measures', 'memr')); 

% If adding a new measure: 
% add something like: addpath(fullfile(rootDir, 'measures', '[measure_name]')); 

addpath(fullfile(rootDir, 'tests', 'unit'));
addpath(fullfile(rootDir, 'projects'));
addpath(fullfile(rootDir, 'projects', 'lab_default'));

disp('Paths have been initialized')
gui_launcher()