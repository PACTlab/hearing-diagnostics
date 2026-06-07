function cfg = config_load()
% CONFIG_LOAD  Load system config from project config folder.

config_path = fullfile(fileparts(mfilename('fullpath')), ...
    '..', 'config', 'system_config.mat');
config_path = char(java.io.File(config_path).getCanonicalPath());

if ~exist(config_path, 'file')
    error('config_load:notFound', ...
        'system_config.mat not found at: %s', config_path);
end

loaded = load(config_path);
if ~isfield(loaded, 'config')
    error('config_load:invalidFormat', ...
        'system_config.mat must contain a struct named ''config''.');
end

cfg = loaded.config;

required = {'hardware', 'calibration', 'data', 'software_version'};
for i = 1:length(required)
    if ~isfield(cfg, required{i})
        error('config_load:missingField', ...
            'Config missing required field: %s', required{i});
    end
end
end