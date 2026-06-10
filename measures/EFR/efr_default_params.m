function params = efr_default_params()
% EFR_DEFAULT_PARAMS  Returns default parameters for EFR data collection.
% Edit values here to change lab defaults.
% Do not add/remove fields without updating abr_make_stimulus and abr_run.

params.measure_type       = 'EFR';

% Ear 
params.ear = 'right'; 

% Stimulus type
params.stim_type          = 'wav';   % 'wav', 'SAM', 'RAM'

% Calibration Type (stimulus) 
params.cal_type = 'SPL'; 
params.apply_ear_cal = true; 
params.ear_cal_file = ''; 

% Modulated tone/noise parameters (ignored if wav file)
params.carrier_frequency_hz = 1000;
params.mod_frequency_hz     = 103; 
params.mod_depth            = 1; % between 0 (no mod) to 1 (fully modulated)
params.duty_cycle_pct       = 75; % when used as mod, seems to be opposite of what we think? 
params.duration_s           = 1;
params.rise_fall_ms         = 10;
params.window_type          = 'hann'; 

% Wav parameters
params.wav_file         = 'test.wav';            % path to .wav should either be in project folder or wav folder for lab defaults

% Level
params.levels_dbspl       = [80]; % Could be a matrix
params.polarity           = 'alt'; % 'alt', 'cond', 'rare'

% Presentation
params.isi_ms          = 300; % between presentations
params.jitter_pct      = 1;            % +/- % of ISI jittered
params.n_reps          = 512;           % per polarity per level

% Acquisition
params.rec_window_ms     = [0 1300];          % window in ms that is saved
params.fs               = 48828.125;     % TDT standard

% Recording
params.n_channels         = 1;            % 1 = ABR only, 2 = ABR + ECochG
params.gain               = 10000;        % electrode to AD gain
params.stim_delay_ms      = 1;           % put the stim a little bit in from the beginning

% Artifact rejection — placeholder
params.artifact_reject    = false;
params.artifact_thresh_uv  = 100;         % volts at electrode, ignored if above is false

% Display
params.memory_reps        = 0;            % 0 = cumulative average, N = sliding window
params.viz_window_ms    = [0 1300];          % window for visualization
params.amplitude_window_uV = [-2 2]; 
