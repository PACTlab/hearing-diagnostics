function metadata = session_load(save_dir)
% SESSION_LOAD  Load session metadata from an existing session folder.
%
% Input:
%   save_dir  - full path to session folder
%
% Output:
%   metadata  - session metadata struct
%

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

%% --- Essential fields ---
essential = {'subject_id', 'species', 'operator', 'date', 'project', ...
             'total_runs', 'created', 'last_modified'};

missing_essential = essential(~isfield(metadata, essential));

if ~isempty(missing_essential)
    error('session_load:missingField', ...
        ['session_metadata.mat is missing required field(s): %s\n' ...
         'Folder: %s'], ...
        strjoin(missing_essential, ', '), save_dir);
end

%% --- Descriptive fields, backfilled ---
% group was previously absent from validation but used in the success
% message below, so a session without it passed validation and then
% errored on the line announcing success — an odd place to find out.

descriptive = { ...
    'group',         '(not recorded)'
    'sex',           '(not recorded)'
    'animal_status', '(not recorded)'
    'exposure_date', ''
    'location',      '(not recorded)'
    'notes',         ''
    'software_ver',  '(unknown)'
    };

backfilled = {};

for i = 1:size(descriptive, 1)
    field = descriptive{i, 1};
    if ~isfield(metadata, field)
        metadata.(field) = descriptive{i, 2};
        backfilled{end+1} = field;   %#ok<AGROW>
    end
end

if ~isempty(backfilled)
    warning('session_load:fieldsBackfilled', ...
        ['Session metadata was missing %s; placeholder value(s) used. ' ...
         'The session file itself is unchanged — it will gain these ' ...
         'fields the next time metadata is saved.'], ...
        strjoin(backfilled, ', '));
end

%% --- Report ---

% this section will print that the final data was loaded to the command
% window
fprintf('Session loaded: %s | %s | %s | runs so far: %d\n', ...
    metadata.subject_id, metadata.date, ...
    metadata.group, metadata.total_runs);

end