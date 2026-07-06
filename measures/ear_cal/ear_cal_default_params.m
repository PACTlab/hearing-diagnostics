function params = ear_cal_default_params()
% EAR_CAL_DEFAULT_PARAMS  Default parameters for in-ear calibration.

%% --- Identity ---
params.measure_type     = 'EARCAL';
params.channel              = 'ch1';        % 'ch1', 'ch2', 'both' - What channel is sound coming out of? 
params.ear              = 'Right'; % what ear is the probe actually in? 
%% --- Hardware ---
params.fs               = 48828.125;
params.attn             = 20; 
params.gain_db          = 20; % 10x from probe mic amp + gain setting at 1x = 10*1 = 10, 20*log10(10) = 20; 

%% --- Frequency sweep ---
params.freq_min_hz      = 200;
params.freq_max_hz      = 20000;
params.freq_n_points    = 60;
params.freq_spacing     = 'log';

%% --- Tone parameters ---
params.tone_duration_s          = 0.3;
params.tone_level_norm          = 0.95;
params.steady_state_start_pct   = 10;
params.steady_state_end_pct     = 90;

%% --- Filter design ---
params.filter_order     = 255;
params.target_dbspl     = 90;
params.max_gain_db      = 20;

%% --- Method ---
params.method           = 'automated';   % 'automated' or 'manual'

end