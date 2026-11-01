function params = abr_default_params()
% ABR_DEFAULT_PARAMS  Returns default parameters for ABR data collection.
% Edit values here to change lab defaults.
% Do not add/remove fields without updating abr_make_stimulus and abr_run.
%
% HARDWARE FACTS COME FROM THE CONFIG, NOT FROM LITERALS HERE.
% fs, electrode_gain and n_channels describe the rig, not the measure, so
% they are read from config.hardware. 

cfg = config_load();

params.measure_type       = 'ABR';

% Ear 
params.ear = 'right'; 

% Stimulus type
params.stim_type          = 'toneburst';   % 'toneburst', 'click', 'chirp'

% Calibration Type (stimulus)
% 'atten'   levels_dbspl below is POSITIVE ATTENUATION in dB, 0 = loudest.
%           Needs no cal file. Essentially allpass.
% 'SPL'     dB SPL — not wired up yet
% 'FPL'     not implemented, needs two-load Thevenin.
% 'allstop' digital zeros AND max attenuation, for control runs.
params.cal_type = 'atten';

% Spectral correction, independent of cal_type above. This is the real
% "allpass" switch. false until an in-ear cal exists, otherwise every run
% emits cal_apply:noInearCal.
params.apply_ear_cal = false;
params.ear_cal_file = ''; 

% Tone burst parameters (ignored if click or chirp)
params.frequency_hz       = 1000; 
params.duration_cyc        = 1; 
params.rise_fall_cyc       = 2;
params.window_type         = 'blackman'; 

% Click parameters (ignored if toneburst or chirp)
params.click_duration_us  = 103;           % microseconds (5 samples at 48.828125 kHz)
params.filtclick = 1; % or 0 for no filter, if 1, then use click_filter below
params.click_filter = [3000, 8000]; % passband;

% Chirp parameters
params.chirp_file         = '';            % path to .wav if loaded externally

% Level
% UNITS DEPEND ON cal_type. With 'atten' these are attenuation in dB and
% 0 is the loudest, so the list ascends from loudest to quietest. With
% 'SPL' they are dB SPL and the order reverses. cal_out.level_units in the
% saved run file records which applied.
params.levels_dbspl       = [0 10 20 30 40 50 60 70 80];
params.polarity           = 'alt'; % 'alt', 'cond', 'rare'

% Presentation
params.rate_hz            = 11.1;          % per second
params.jitter_pct         = 1;            % +/- % of ISI jittered
params.n_reps             = 512;           % per polarity per level

% Acquisition
params.rec_window_ms    = [0 20];          % window in ms that is saved
params.fs                 = cfg.hardware.fs_playback_hz;   % from config

% Recording
params.n_channels         = cfg.hardware.n_channels;  % 1 = ABR only, 2 = ABR + ECochG
params.stim_delay_ms      = 1;           % put the stim a little bit in from the beginning

% Electrode amplifier gain — LINEAR, e.g. 10000 for a 10000x amp.
% This is APPLIED IN THE RPvds CIRCUIT, not in MATLAB. abr_run's recorded
% data is therefore already electrode-referred volts, which is why it
% converts to microvolts with a bare *1e6 and no division.
%
% The value is carried here and saved with every run (abr_run does
% save_params = params) so offline analysis knows what gain was in force.
% electrode_gain_applied records WHERE it was applied, so analysis code
% does not divide by it a second time.
%
% Named electrode_gain rather than gain because DPOAE and MEMR used
% params.gain for the probe mic amplifier in dB — same field name, a
% factor of 500 apart. Mic gain now lives in params.mic_gain_db.
params.electrode_gain          = cfg.hardware.electrode_gain;
params.electrode_gain_applied  = 'circuit';   % 'circuit' | 'software' | 'none'

% Artifact rejection — placeholder
params.artifact_reject    = false;
params.artifact_thresh_uv  = 40;         % microvolts at electrode, ignored if above is false

% Display
params.memory_reps        = 0;            % 0 = cumulative average, N = sliding window
params.viz_window_ms    = [0 20];          % window for visualization
params.amplitude_window_uV = [-2 2]; 
params.viz_polarity = 'Separated';

% testing mode
% Honoured by abr_gui: when true it skips tdt_init entirely rather than
% relying on the connection failing. Previously this field was defined and
% read by nothing, so the documented way to test without hardware did not
% work.
params.stub_mode = false;

end