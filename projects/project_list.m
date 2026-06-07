function projects = project_list()
% PROJECT_LIST  List all available projects.
%
% Returns a struct array of project configs.
% Also prints a summary to the command window.

projects_dir = fileparts(mfilename('fullpath'));
folders      = dir(projects_dir);
folders      = folders([folders.isdir]);
folders      = folders(~ismember({folders.name}, {'.', '..'}));

projects = [];
fprintf('\n=== Available Projects ===\n\n');

for i = 1:length(folders)
    cfg_path = fullfile(projects_dir, folders(i).name, 'project_config.mat');
    if ~exist(cfg_path, 'file')
        continue
    end

    loaded = load(cfg_path);
    p      = loaded.project;

    % Count index entries
    index_dir   = fullfile(projects_dir, folders(i).name, 'index');
    index_files = dir(fullfile(index_dir, '*_metadata.mat'));
    n_sessions  = length(index_files);

    fprintf('  %-25s  PI: %-12s  Species: %-12s  Sessions: %d\n', ...
        p.short_name, p.pi, p.species, n_sessions);

    if isempty(projects)
        projects = p;
    else
        projects(end+1) = p; %#ok<AGROW>
    end
end

fprintf('\n');
end