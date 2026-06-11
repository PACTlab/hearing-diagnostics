function params = transducer_check_default_params()
% TRANSDUCER_CHECK_DEFAULT_PARAMS  Default parameters for transducer check.
%
% Frequency sweep parameters are designed to be easy to update when
% sample rate changes — only fs and freq_max_hz need adjusting.

%% --- Identity ---
params.measure_type     = 'TRANSDUCER_CHECK';
params.ear              = 'ch1';        % 'ch1', 'ch2', 'both'

%% --- Hardware ---
params.fs               = 48828.125;    % TDT standard — update if rate changes
params.method           = 'automated';  % 'automated' or 'manual'

%% --- Frequency sweep ---
params.freq_min_hz      = 200;          % lower limit — update if needed
params.freq_max_hz      = 20000;        % upper limit — update with fs
params.freq_n_points    = 24;           % total frequencies in sweep
params.freq_spacing     = 'log';        % 'log' or 'linear'

%% --- Tone parameters ---
params.tone_duration_s          = 0.5;  % seconds per tone
params.tone_level_norm          = 0.5;  % normalized amplitude 0-1
params.steady_state_start_pct   = 10;   % % of tone to skip at onset
params.steady_state_end_pct     = 90;   % % of tone to skip at offset

%% --- Reference comparison ---
params.deviation_thresh_db      = 3;    % flag if deviation exceeds this

%% --- File tag helper ---
params.channel_labels   = containers.Map(...
    {'ch1', 'ch2'}, ...
    {'Ch1 (Left)', 'Ch2 (Right)'});

end