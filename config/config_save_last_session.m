function config_save_last_session(save_dir)
% CONFIG_SAVE_LAST_SESSION  Save the most recent session path to config.
% Called after any successful session create or resume.
%
% The path is stored relative to the repo root when the session lives
% inside the repo, so system_config.mat doesn't accumulate one machine's
% absolute paths. config_load expands it again on the way out.

config_path = fullfile(config_repo_root(), 'config', 'system_config.mat');

loaded = load(config_path);
config = loaded.config;

config.last_session_dir = config_relative_path(save_dir);

save(config_path, 'config');

end