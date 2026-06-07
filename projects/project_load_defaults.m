function params = project_load_defaults(measure_type, project_name)
% PROJECT_LOAD_DEFAULTS  Load default params for a measure, checking
% project overrides before falling back to the measure folder default.
%
% Inputs:
%   measure_type  - string, e.g. 'abr', 'oae', 'efr'
%   project_name  - string matching a folder in projects/
%                   e.g. 'chinchilla_noise' or 'lab_default'
%
% Output:
%   params        - default params struct for this measure and project

if nargin < 2 || isempty(project_name)
    project_name = 'lab_default';
end

projects_dir  = getProjectsDir();
measure_lower = lower(measure_type);
params_fname  = sprintf('%s_default_params', measure_lower);

%% --- Check project override first ---

if ~strcmp(project_name, 'lab_default')
    project_params = fullfile(projects_dir, project_name, ...
        sprintf('%s_default_params.m', measure_lower));

    if exist(project_params, 'file')
        old_dir = cd(fullfile(projects_dir, project_name));
        params  = feval(params_fname);
        cd(old_dir);
        fprintf('Loaded %s defaults for project: %s\n', ...
            upper(measure_type), project_name);
        return
    end
end

%% --- Fall back to measure folder default ---
% Found via normal path resolution — measures/abr/ is on the path

if exist(which(params_fname), 'file')
    params = feval(params_fname);
    if ~strcmp(project_name, 'lab_default')
        fprintf(['No %s override for project ''%s''. ' ...
                 'Using measure default.\n'], ...
            upper(measure_type), project_name);
    end
    return
end

%% --- Nothing found ---

error('project_load_defaults:notFound', ...
    ['No default params found for measure ''%s''. ' ...
     'Check that %s_default_params.m exists in measures/%s/'], ...
    measure_type, measure_lower, measure_lower);

end

%% ================================================================
%  LOCAL FUNCTIONS
%% ================================================================

function d = getProjectsDir()
    d = fullfile(fileparts(mfilename('fullpath')));
    d = char(java.io.File(d).getCanonicalPath());
end