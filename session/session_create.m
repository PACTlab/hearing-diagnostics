function [save_dir, metadata] = session_create(subject_id, species, operator, info)
% SESSION_CREATE  Create a new session folder and write metadata file.
%
% If a session folder already exists for this subject/date/group/status,
% loads and returns the existing session rather than creating a duplicate.
%
% Inputs:
%   subject_id  - string, e.g. 'Q047'
%   species     - string, e.g. 'Chinchilla'
%   operator    - string, e.g. 'JDoe'
%   info        - struct with optional fields:
%                   sex, group, exposure_date, animal_status,
%                   location, notes, software_ver
%
% Outputs:
%   save_dir    - full path to session folder
%   metadata    - session metadata struct

%% --- Defaults for optional info fields ---

if nargin < 4 || isempty(info)
    info = struct();
end

info = applyInfoDefaults(info);

%% --- Build folder name ---

date_str   = datestr(now, 'yyyy-mm-dd');
folder_name = sprintf('%s_%s_%s', ...
    date_str, ...
    sanitizeName(info.group), ...
    sanitizeName(info.animal_status)); % gets rid of any bad folder chars

%% --- Build full path ---

cfg      = config_load();
save_dir = fullfile(cfg.data.root_dir, subject_id, folder_name);

%% --- Check if already exists ---

metadata_path = fullfile(save_dir, 'session_metadata.mat');

if exist(metadata_path, 'file')
    fprintf('Session folder already exists. Loading: %s\n', save_dir);
    metadata = session_load(save_dir);
    return
end

%% --- Create folder ---

if ~exist(save_dir, 'dir')
    mkdir(save_dir);
    fprintf('Created session folder: %s\n', save_dir);
end

%% --- Build metadata ---

metadata.subject_id     = subject_id;
metadata.species        = species;
metadata.operator       = operator;
metadata.project        = info.project;
metadata.date           = date_str;
metadata.sex            = info.sex;
metadata.group          = info.group;
metadata.exposure_date  = info.exposure_date;
metadata.animal_status  = info.animal_status;
metadata.location       = info.location;
metadata.notes          = info.notes;
metadata.software_ver   = cfg.software_version;
metadata.total_runs     = 0;
metadata.created        = datestr(now, 'yyyy-mm-dd HH:MM:SS');
metadata.last_modified  = datestr(now, 'yyyy-mm-dd HH:MM:SS');

%% --- Write metadata to session folder ---

save(metadata_path, 'metadata');
fprintf('Session metadata saved: %s\n', metadata_path);

%% --- Write copy to project index ---

if ~strcmp(info.project, 'lab_default')
    project_index_update(metadata, save_dir);
end

end

%% ================================================================
%  LOCAL FUNCTIONS
%% ================================================================

function info = applyInfoDefaults(info)
    if ~isfield(info, 'sex');            info.sex            = 'Unknown'; end
    if ~isfield(info, 'group');          info.group          = 'Baseline'; end
    if ~isfield(info, 'exposure_date');  info.exposure_date  = 'none'; end
    if ~isfield(info, 'animal_status');  info.animal_status  = 'Awake'; end
    if ~isfield(info, 'location');       info.location       = ''; end
    if ~isfield(info, 'notes');          info.notes          = ''; end
    if ~isfield(info, 'software_ver');   info.software_ver   = ''; end
    if ~isfield(info, 'project'); info.project = 'lab_default'; end

end