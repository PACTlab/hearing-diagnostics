function params = ear_cal_default_params()
% EAR_CAL_DEFAULT_PARAMS  Default parameters for in-ear calibration.

%% --- Identity ---
params.measure_type     = 'EARCAL';
params.ear              = 'ch1';        % 'ch1', 'ch2', 'both'

%% --- Hardware ---
params.fs               = 48828.125;
params.attn             = 10; 

%% --- Frequency sweep ---
params.freq_min_hz      = 200;
params.freq_max_hz      = 20000;
params.freq_n_points    = 36;
params.freq_spacing     = 'log';

%% --- Tone parameters ---
params.tone_duration_s          = 0.5;
params.tone_level_norm          = 0.95;
params.steady_state_start_pct   = 10;
params.steady_state_end_pct     = 90;

%% --- Filter design ---
params.filter_order     = 255;
params.target_dbspl     = 105;
params.max_gain_db      = 20;

%% --- Method ---
params.method           = 'automated';   % 'automated' or 'manual'

end