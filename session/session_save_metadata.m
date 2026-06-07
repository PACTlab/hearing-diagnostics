function metadata = session_save_metadata(save_dir, metadata, run_info)
% SESSION_SAVE_METADATA  Update session metadata file on disk.
%
% Appends run summary to metadata.run_log after each save.
%
% Inputs:
%   save_dir  - full path to session folder
%   metadata  - session metadata struct
%   run_info  - (optional) run.info struct to append to run_log

if ~exist(save_dir, 'dir')
    error('session_save_metadata:folderNotFound', ...
        'Session folder not found: %s', save_dir);
end

metadata_path = fullfile(save_dir, 'session_metadata.mat');

if ~exist(metadata_path, 'file')
    error('session_save_metadata:noMetadata', ...
        'No session_metadata.mat found in: %s', save_dir);
end

% Update timestamp
metadata.last_modified = datestr(now, 'yyyy-mm-dd HH:MM:SS');

% Append to run log if run_info provided
if nargin >= 3 && ~isempty(run_info)
    entry.run_number   = metadata.total_runs;
    entry.measure_type = run_info.measure_type;
    entry.ear          = run_info.ear;
    entry.timestamp    = datestr(now, 'yyyy-mm-dd HH:MM:SS');

    if ~isfield(metadata, 'run_log') || isempty(metadata.run_log)
        metadata.run_log = entry;
    else
        metadata.run_log(end+1) = entry;
    end
end

save(metadata_path, 'metadata');

% Sync project index
if isfield(metadata, 'project') && ~strcmp(metadata.project, 'lab_default')
    project_index_update(metadata, save_dir);
end

end