function [save_dir, found] = session_find(subject_id, date_str, group, animal_status)
% SESSION_FIND  Find an existing session folder matching the given criteria.
%
% Inputs:
%   subject_id      - string, e.g. 'CHL-047'
%   date_str        - string, e.g. '2024-11-15' (uses today if empty)
%   group           - string, e.g. 'Baseline'
%   animal_status   - string, e.g. 'Awake'
%
% Outputs:
%   save_dir        - full path to matching folder, empty string if not found
%   found           - logical, true if a matching folder was found

%% --- Defaults ---

if nargin < 2 || isempty(date_str)
    date_str = datestr(now, 'yyyy-mm-dd');
end
if nargin < 3 || isempty(group)
    group = '';
end
if nargin < 4 || isempty(animal_status)
    animal_status = '';
end

save_dir = '';
found    = false;

%% --- Build expected folder name ---

cfg          = config_load();
subject_dir  = fullfile(cfg.data.root_dir, subject_id);

if ~exist(subject_dir, 'dir')
    return
end

%% --- Build search pattern ---
% Folder name format: YYYY-MM-DD_Group_Status
% Any of group/status may be empty — match on what we have

folder_pattern = date_str;
if ~isempty(group)
    folder_pattern = sprintf('%s_%s', folder_pattern, sanitizeName(group));
end
if ~isempty(animal_status)
    folder_pattern = sprintf('%s_%s', folder_pattern, sanitizeName(animal_status));
end

%% --- Search subject directory ---

contents = dir(subject_dir);
contents = contents([contents.isdir]);   % folders only
contents = contents(~ismember({contents.name}, {'.', '..'}));

for i = 1:length(contents)
    if startsWith(contents(i).name, folder_pattern)
        candidate = fullfile(subject_dir, contents(i).name);
        % Verify it's a real session folder by checking for metadata
        if exist(fullfile(candidate, 'session_metadata.mat'), 'file')
            save_dir = candidate;
            found    = true;
            fprintf('Found existing session: %s\n', save_dir);
            return
        end
    end
end

end
