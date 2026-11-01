function params = probecal_default_params()
%set default parameters 

params.stub_mode = false; % true to run w/o tdt

% Equipment settings: 
params.CavTemp_C = 24; 
params.CavDiam_cm = 0.8; % cm 
params.cav_lengths_mm = [83, 54.3, 40, 25.6, 18.5];
params.drivers = [1, 2]; 
params.atten_db = 30; % MEMR click should match this
% pick whatever has good SNR but it does not distort
params.mic_gain_dial = 10; 

% for the stimulus (click)
params.nsampsclick = 1; 
params.initbuff = 2; 
params.electricAcousticPolarity = -1; 
params.BufferSize = 2048;
params.n_averages = 256;
params.n_throwaway = 4;

% Cleaning up the data
params.doInfResp = 0;
params.doFilt = 0;
params.hp_cutoff_hz = 100; 
params.reject_k = 2; % multiplier for mad of energy in rejecting clicks.

% for presentation
params.silent_atten_db = 120; 
params.delay_comp = 0; 

% for calculations
params.f_err_khz = [2 8]; % range of freq over which Thevenin calibration error is computed 
params.len_search_cm = [1 12]; 

% some values to check if the run is good 
params.length_tol_pct = 10; 
params.min_snr_db = 20; 
params.max_error = 1; 

% for stub mode
params.stub_noise_v = .001; 

% settings for running 
params.max_age_rule = 'same_day'; %also accepts a number of hours

end