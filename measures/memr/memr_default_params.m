function params = memr_default_params()
% MEMR_DEFAULT_PARAMS  Returns default parameters for MEMR data collection.
% Edit values here to change lab defaults.
% Do not add/remove fields without updating memr_make_stimulus and memr_run.

params.measure_type       = 'MEMR';

% Ear 
params.ear = 'right'; 

% Stimulus type
params.stim_type          = 'swept';   % 'swept' or 'discrete

% Calibration Type (stimulus) 
params.cal_type = 'FPL'; 
params.apply_ear_cal = false; 
params.ear_cal_file = ''; 

% Stimulus for both 
params.rise_fall_ms       = 5;
params.elic_duration_ms   = 120;
params.level_range_db      = 54; 
params.elic_bandwidth_hz = 8000; % Hz for noise frequency content
params.elic_fc = 4500; % Hz, also for noise frequency content, 4500 Hz for 1-8 kHz with BW = 8k
params.pad_samps = 256; % extra samples after the noise burst and before the next click

params.click_samps = 5; % number of samples in the click
params.click_win_dur_ms = 41.92; % ms; desired click window length in seconds

% Stimulus parameters for discrete

% Stimulus parameters for swept tone
params.total_duration_s = 4;  % approx duration in seconds (x2 for total stim duration, up and down)
params.n_baseline_clicks = 5; % number of extra clicks to append at beginning

% Presentation
params.trials         = 12; 

% Auto Collect parameters
params.auto_stop = false; 
params.SNRcriterion = 6; 
params.maxTrials = 50; 
params.minTrials = 12; 
params.ThrowAway = 1; 

% Acquisition
params.fs                 = 48828.125;     % TDT standard

% Recording and analysis
params.gain               = 20;        % read from the transducer file?
params.VtoSPL   = (1 / (db2mag(params.gain) * 500e-3)) .* (1/20e-6); 
params.npoints = 512; 

% Artifact rejection — placeholder
params.artifact_reject      = false;
params.artifact_thresh      = 40;         % how to determine what to toss, ignored if above is false

% Display
params.amplitude_window_dB = [-2 2];
params.frequency_window_hz = [100 10000]; 

% testing mode
params.stub_mode = false;   % set to true for testing without hardware
