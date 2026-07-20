function params = dpoae_default_params()
% ABR_DEFAULT_PARAMS  Returns default parameters for ABR data collection.
% Edit values here to change lab defaults.
% Do not add/remove fields without updating abr_make_stimulus and abr_run.

params.measure_type       = 'DPOAE';

% Ear 
params.ear = 'right'; 

% Stimulus type
params.stim_type          = 'swept';   % 'swept' or 'discrete

% Calibration Type (stimulus) 
params.cal_type = 'FPL'; 
params.apply_ear_cal = true; 
params.ear_cal_file = ''; 

% Stimulus for both 
params.rise_fall_ms       = 5;
params.ratio = 1.22; 

% Stimulus parameters for discrete
params.duration_ms        = 500;
params.window_type         = 'hann'; 
params.f2_hz = [500, 1000, 2000, 4000, 8000]; % a vector of frquencies. 

% Stimulus parameters for swept tone
params.max_f2_hz = 16000; 
params.min_f2_hz = 500; 
params.scale = 'log'; 
params.speed = 1; % octaves if scale is log
params.sweepDirection = 1; % + 1 for up sweep, -1 for downsweep
params.buffdur_ms   = 250; 

% Level
params.level_f2_dB      = 65;
params.level_f1_dB      = 55; 

% Presentation
params.trials         = 12; 

% Auto Collect parameters
params.auto_stop = false; 
params.SNRcriterion = 6; 
params.maxTrials = 50; 
params.minTrials = 12; 
params.ThrowAway = 1; 
params.windowDuration_ms = 250; 
params.noisefreqs_multiplier = 1 + -1*params.sweepDirection .* [.1:.02:.16]; 

% Acquisition
params.fs                 = 48828.125;     % TDT standard

% Recording and analysis
params.gain               = 20;        % read from the transducer file?
params.VtoSPL   = (1 / (db2mag(params.gain) * 500e-3)) .* (1/20e-6); 
params.npoints = 512; 

% Artifact rejection — placeholder
params.artifact_reject    = false;
params.artifact_thresh  = 40;         % how to determine what to toss, ignored if above is false

% Display
params.amplitude_window_dB = [-30 70 ]; 

% testing mode
params.stub_mode = false;   % set to true for testing without hardware
