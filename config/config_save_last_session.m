function config_save_last_session(save_dir)
% CONFIG_SAVE_LAST_SESSION  Save the most recent session path to config.
% Called after any successful session create or resume.

config_path = fullfile(fileparts(mfilename('fullpath')), 'system_config.mat');
loaded      = load(config_path);
config      = loaded.config;

config.last_session_dir = save_dir;
save(config_path, 'config');
end