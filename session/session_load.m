function metadata = session_load(save_dir)
% SESSION_LOAD  Load session metadata from an existing session folder.
%
% Input:
%   save_dir  - full path to session folder
%
% Output:
%   metadata  - session metadata struct

%% --- Validate input ---

if nargin < 1 || isempty(save_dir)
    error('session_load:noPath', ...
        'save_dir is required.');
end

if ~exist(save_dir, 'dir')
    error('session_load:folderNotFound', ...
        'Session folder not found: %s', save_dir);
end

%% --- Find metadata file ---

metadata_path = fullfile(save_dir, 'session_metadata.mat');

if ~exist(metadata_path, 'file')
    error('session_load:noMetadata', ...
        'No session_metadata.mat found in: %s\nFolder exists but may not be a valid session folder.', ...
        save_dir);
end

%% --- Load ---

loaded = load(metadata_path);

if ~isfield(loaded, 'metadata')
    error('session_load:badFormat', ...
        'session_metadata.mat must contain a struct named ''metadata''.');
end

metadata = loaded.metadata;

%% --- Validate required fields ---

required = {'subject_id', 'species', 'operator', 'date', ...
            'total_runs', 'created', 'last_modified'};
for i = 1:length(required)
    if ~isfield(metadata, required{i})
        error('session_load:missingField', ...
            'session_metadata.mat missing required field: %s', required{i});
    end
end

fprintf('Session loaded: %s | %s | %s | runs so far: %d\n', ...
    metadata.subject_id, metadata.date, ...
    metadata.group, metadata.total_runs);

end