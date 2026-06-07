function project_index_update(metadata, save_dir)
% PROJECT_INDEX_UPDATE  Write or update a session's metadata copy in the
% project index folder.
%
% Called by session_create when a session is first created, and by
% session_save_metadata after every run so total_runs and run_log
% stay current in the index.
%
% Inputs:
%   metadata  - session metadata struct
%   save_dir  - full path to session data folder (stored in index for reference)

if ~isfield(metadata, 'project') || isempty(metadata.project) || ...
        strcmp(metadata.project, 'lab_default')
    return
end

%% --- Find project index folder ---

projects_dir = getProjectsDir();
index_dir    = fullfile(projects_dir, metadata.project, 'index');

if ~exist(index_dir, 'dir')
    mkdir(index_dir);
end

%% --- Build index filename ---
% Format: SubjID_Date_Status_metadata.mat

fname = sprintf('%s_%s_%s_metadata.mat', ...
    metadata.subject_id, ...
    metadata.date, ...
    sanitize_name(metadata.animal_status));

index_path = fullfile(index_dir, fname);

%% --- Add save_dir to metadata copy so index knows where data lives ---

index_metadata          = metadata;
index_metadata.data_dir = save_dir;

%% --- Save ---

save(index_path, 'index_metadata');
fprintf('Project index updated: %s\n', index_path);

end

%% ================================================================
%  LOCAL FUNCTIONS
%% ================================================================

function d = getProjectsDir()
    d = fullfile(fileparts(mfilename('fullpath')));
    d = char(java.io.File(d).getCanonicalPath());
end

function s = sanitize_name(str)
    s = strrep(str, ' ', '');
    s = strrep(s, '/', '-');
    s = strrep(s, '\', '-');
    s = regexprep(s, '[^a-zA-Z0-9_-]', '');
end