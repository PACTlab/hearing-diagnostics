function project_create(short_name, full_name, pi_name, species, description)
% PROJECT_CREATE  Set up a new project folder with config and default params.
%
% Creates the project folder structure, copies lab default params as a
% starting point, and writes a project_config.mat.
%
% Usage:
%   project_create('chinchilla_noise', 'Chinchilla Noise Exposure', ...
%       'Smith', 'Chinchilla', 'Effects of noise on chinchilla hearing')
%
% Inputs:
%   short_name    - folder name, no spaces e.g. 'chinchilla_noise'
%   full_name     - display name e.g. 'Chinchilla Noise Exposure'
%   pi_name       - PI last name e.g. 'Smith'
%   species       - primary species e.g. 'Chinchilla'
%   description   - brief description of the project

%% --- Validate inputs ---

if nargin < 5
    error('project_create:missingArgs', ...
        ['Usage: project_create(short_name, full_name, ' ...
         'pi_name, species, description)']);
end

% Sanitize short_name
short_name = regexprep(short_name, '[^a-zA-Z0-9_]', '_');

if strcmp(short_name, 'lab_default')
    error('project_create:reservedName', ...
        '''lab_default'' is reserved. Choose a different project name.');
end

%% --- Check if already exists ---

projects_dir  = fileparts(mfilename('fullpath'));
project_dir   = fullfile(projects_dir, short_name);

if exist(project_dir, 'dir')
    error('project_create:alreadyExists', ...
        'Project folder already exists: %s', project_dir);
end

%% --- Create folders ---

mkdir(project_dir);
mkdir(fullfile(project_dir, 'index'));
fprintf('Created project folder: %s\n', project_dir);

%% --- Write project_config.mat ---

project.name        = full_name;
project.short_name  = short_name;
project.pi          = pi_name;
project.description = description;
project.created     = datestr(now, 'yyyy-mm-dd');
project.species     = species;
project.active      = true;

save(fullfile(project_dir, 'project_config.mat'), 'project');
fprintf('Project config saved.\n');


%% --- Remind user how to add overrides ---

fprintf('\nProject ''%s'' created successfully.\n', short_name);
fprintf('To override lab default params for a measure:\n');
fprintf('  Copy measures/{measure}/{measure}_default_params.m\n');
fprintf('  to projects/%s/ and edit values there.\n', short_name);
fprintf('  Do not add or remove fields — only change values.\n\n');

%% --- Add header comment to each copied params file ---

for i = 1:length(param_files)
    dst      = fullfile(project_dir, param_files(i).name);
    contents = fileread(dst);

    header = sprintf(['%% Project: %s\n' ...
                      '%% Created: %s\n' ...
                      '%% Edit values below to override lab defaults.\n' ...
                      '%% Do not add or remove fields — ' ...
                          'only change values.\n\n'], ...
                      full_name, datestr(now, 'yyyy-mm-dd'));

    % Insert header after first function line
    contents = regexprep(contents, ...
        '(function\s+\w+\s*=\s*\w+\s*\(\s*\)\s*\n)', ...
        ['$1' header]);

    fid = fopen(dst, 'w');
    fprintf(fid, '%s', contents);
    fclose(fid);
end

fprintf('\nProject ''%s'' created successfully.\n', short_name);
fprintf('Edit parameter files in: %s\n', project_dir);
fprintf('To use this project, select ''%s'' in the session dialog.\n\n', short_name);

end