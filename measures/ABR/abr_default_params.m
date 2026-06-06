function params = abr_default_params()
% ABR_DEFAULT_PARAMS  Returns default parameters for ABR data collection.
% Edit values here to change lab defaults.
% Do not add/remove fields without updating abr_make_stimulus and abr_run.

params.measure_type       = 'ABR';

% Stimulus type
params.stim_type          = 'toneburst';   % 'toneburst', 'click', 'chirp'

% Calibration Type (stimulus) 
params.cal_type = 'SPL'; 
params.apply_ear_cal = true; 
params.ear_cal_file = ''; 

% Tone burst parameters (ignored if click or chirp)
params.frequency_hz       = 1000;
params.duration_ms        = 5;
params.rise_fall_ms       = 0.5;

% Click parameters (ignored if toneburst or chirp)
params.click_duration_us  = 100;           % microseconds

% Chirp parameters
params.chirp_file         = '';            % path to .wav if loaded externally

% Level
params.levels_dbspl       = [80 70 60 50 40 30 20 10 0];
params.polarity           = 'alt'; % 'alt', 'cond', 'rare'

% Presentation
params.rate_hz            = 11.1;          % per second
params.jitter_pct         = 10;            % +/- % of ISI jittered
params.n_reps             = 512;           % per polarity per level

% Acquisition
params.epoch_window_ms    = [0 20];
params.fs                 = 48828.125;     % TDT standard

% Recording
params.n_channels         = 1;            % 1 = ABR only, 2 = ABR + ECochG
params.gain               = 10000;        % electrode to AD gain

% Artifact rejection — placeholder
params.artifact_reject    = false;
params.artifact_thresh_v  = 0.04;         % volts at electrode, ignored if above is false

% Display
params.memory_reps        = 0;            % 0 = cumulative average, N = sliding window
params.fixed_phase        = false;