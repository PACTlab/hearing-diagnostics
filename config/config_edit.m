% CONFIG_EDIT  View and update system_config.mat
% Run this script to inspect or change any system configuration value.
% Located in config/ alongside system_config.mat

%% --- Load current config ---

config_path = fullfile(fileparts(mfilename('fullpath')), 'system_config.mat');

if ~exist(config_path, 'file')
    error('config_edit:notFound', 'system_config.mat not found at: %s', config_path);
end

loaded = load(config_path);
config = loaded.config;

fprintf('\n=== Current System Configuration ===\n\n');
fprintf('Software version:         %s\n',   config.software_version);
fprintf('Schema version:           %s\n',   config.schema_version); 
fprintf('Hardware type:            %s\n',   config.hardware.type);
fprintf('Playback sample rate:     %.3f Hz\n', config.hardware.fs_playback_hz);
fprintf('Record sample rate:       %.3f Hz\n', config.hardware.fs_record_hz);
fprintf('USB channel:              %d\n',   config.hardware.usb_ch);
fprintf('Figure number:            %d\n',   config.hardware.fig_num);
fprintf('N channels:               %d\n',   config.hardware.n_channels);
fprintf('Gain:                     %d\n',   config.hardware.gain);
fprintf('Active transducer cal:    %s\n',   config.calibration.active_transducer_file);
fprintf('Active FPL cal:           %s\n',   config.calibration.active_fpl_file);
fprintf('Cal max age (days):       %d\n',   config.calibration.max_age_days);
fprintf('Data root directory:      %s\n',   config.data.root_dir);
fprinf('Last Session:              %s\n',   config.last_session_dir); 
fprintf('\n');

%% --- Edit values here ---
% Uncomment and change any line below, then run the script to save.

% config.software_version                       = 'v01.1';
% config.schema_version                         = 1; 
% config.hardware.type                          = 'tdt';
% config.hardware.fs_playback_hz                = 48828.125;
% config.hardware.fs_record_hz                  = 48828.125;
% config.hardware.usb_ch                        = 1;
% config.hardware.fig_num                       = 99;
% config.hardware.n_channels                    = 1;
% config.hardware.gain                          = 10000;

% config.calibration.active_transducer_file     = 'calibration/data/transducer/MY_CAL.mat';
% config.calibration.active_fpl_file            = '';
% config.calibration.max_age_days               = 7;

% config.data.root_dir                          = 'data';
% config.last_session_dir                       = ''; 

%% --- Save if any changes were made ---
% This block runs automatically — if you uncommented anything above
% the updated config will be saved and confirmed.

save(config_path, 'config');
fprintf('=== Configuration saved. ===\n\n');

%% --- Confirm saved values ---

loaded = load(config_path);
config = loaded.config;
fprintf('Software version now:     %s\n', config.software_version);
fprintf('Data root now:            %s\n', config.data.root_dir);
fprintf('Transducer cal now:       %s\n', config.calibration.active_transducer_file);
fprintf('\n');