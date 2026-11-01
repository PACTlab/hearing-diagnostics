function [filepath, metadata] = session_save_run(save_dir, metadata, params, data, result)
% SESSION_SAVE_RUN  Save a single run file and update session metadata.
%
% This is the main save function called by measure GUIs after each
% level completes. Handles filename generation, file saving, and
% metadata update atomically.
%
% Inputs:
%   save_dir  - full path to session folder
%   metadata  - current session metadata struct
%   params    - measure params struct for this run
%   data      - data struct for this run
%
% Outputs:
%   filepath  - full path to saved file
%   metadata  - updated metadata struct (total_runs incremented)

%% --- Validate ---

if ~exist(save_dir, 'dir')
    error('session_save_run:folderNotFound', ...
        'Session folder not found: %s', save_dir);
end

required_params = {'measure_type', 'ear'};
for i = 1:length(required_params)
    if ~isfield(params, required_params{i})
        error('session_save_run:missingParam', ...
            'params missing required field: %s', required_params{i});
    end
end

%% --- Build run struct ---

cfg = config_load(); 


run.info.subject_id       = metadata.subject_id;
run.info.species          = metadata.species;
run.info.operator         = metadata.operator;
run.info.date             = metadata.date;
run.info.measure_type     = params.measure_type;
run.info.ear              = params.ear;
run.info.schema_version   = cfg.schema_version;

% Merge all metadata info fields into run.info
meta_fields = fieldnames(metadata);
for i = 1:length(meta_fields)
    % Don't overwrite core fields already set above
    if ~isfield(run.info, meta_fields{i})
        run.info.(meta_fields{i}) = metadata.(meta_fields{i});
    end
end

run.params = params;
run.data   = data;

if nargin < 5
    run.result = struct();
else
    run.result = result;
end

%% --- Increment run counter ---

metadata.total_runs = metadata.total_runs + 1;


%% --- Build filename ---

fname    = session_build_filename(metadata, params);

filepath = fullfile(save_dir, fname);
 
% Never overwrite an existing run file. metadata.total_runs is held per
% GUI, so two windows on the same session can generate the same run
% number; save() would replace the earlier file silently.
if exist(filepath, 'file')
    error('session_save_run:fileExists', ...
        ['Run file already exists and will not be overwritten:\n  %s\n' ...
         'metadata.total_runs is %d. This usually means two measure ' ...
         'windows are open on the same session, each holding its own ' ...
         'copy of the metadata. Close one, reopen it from the launcher ' ...
         'so it reloads metadata from disk, and rerun this level.'], ...
        filepath, metadata.total_runs);
end
%% --- Save run file ---

save(filepath, 'run', '-v7.3');
fprintf('Saved: %s\n', fname);

%% --- Update metadata on disk ---

metadata = session_save_metadata(save_dir, metadata, run.info);

end