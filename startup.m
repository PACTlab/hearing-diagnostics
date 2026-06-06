rootDir = fileparts(mfilename('fullpath')); 

addpath(rootDir); 
addpath(fullfile(rootDir, 'hardware')); 
addpath(fullfile(rootDir, 'calibration')); 
addpath(fullfile(rootDir, 'measures', 'ABR')); 
addpath(fullfile(rootDir, 'session')); 
addpath(fullfile(rootDir, 'gui')); 
addpath(fullfile(rootDir, 'tests')); 

% If adding a new measure: 
% add something like: addpath(fullfile(rootDir, 'measures', '[measure_name]')); 

disp('Paths have been initialized')