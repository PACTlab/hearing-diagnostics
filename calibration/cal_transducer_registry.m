function varargout = cal_transducer_registry(action, varargin)
% CAL_TRANSDUCER_REGISTRY  Load, save, and manage transducer registry.
%
% Usage:
%   transducers = cal_transducer_registry('load')
%   cal_transducer_registry('save', transducers)
%   transducers = cal_transducer_registry('add', transducers, new_entry)
%   names       = cal_transducer_registry('list')
%   entry       = cal_transducer_registry('get', transducers, display_name)
%   cal_transducer_registry('init')   ← create empty registry if none exists

registry_path = cal_get_registry_path();

switch lower(action)

    case 'load'
        if ~exist(registry_path, 'file')
            warning('cal_transducer_registry:notFound', ...
                'No registry found. Run cal_transducer_registry(''init'') first.');
            varargout{1} = [];
            return
        end
        loaded         = load(registry_path);
        varargout{1}   = loaded.transducers;

    case 'save'
        transducers = varargin{1};
        save(registry_path, 'transducers');
        fprintf('Transducer registry saved: %d entries.\n', length(transducers));

    case 'add'
        transducers = varargin{1};
        new_entry   = varargin{2};

        % Validate required fields
        required = {'display_name', 'stim', 'mic', 'date_added', 'added_by'};
        for i = 1:length(required)
            if ~isfield(new_entry, required{i})
                error('cal_transducer_registry:missingField', ...
                    'New entry missing required field: %s', required{i});
            end
        end

        % Check for duplicate display name
        if ~isempty(transducers)
            existing_names = {transducers.display_name};
            if any(strcmp(existing_names, new_entry.display_name))
                error('cal_transducer_registry:duplicate', ...
                    'Transducer already registered: %s', new_entry.display_name);
            end
            transducers(end+1) = new_entry;
        else
            transducers = new_entry;
        end

        cal_transducer_registry('save', transducers);
        varargout{1} = transducers;
        fprintf('Registered: %s\n', new_entry.display_name);

    case 'list'
        if ~exist(registry_path, 'file')
            varargout{1} = {'No transducers registered'};
            return
        end
        loaded = load(registry_path);
        if isempty(loaded.transducers)
            varargout{1} = {'No transducers registered'};
        else
            varargout{1} = {loaded.transducers.display_name};
        end

    case 'get'
        transducers  = varargin{1};
        display_name = varargin{2};
        idx = find(strcmp({transducers.display_name}, display_name));
        if isempty(idx)
            error('cal_transducer_registry:notFound', ...
                'Transducer not found: %s', display_name);
        end
        varargout{1} = transducers(idx);

    case 'init'
        if exist(registry_path, 'file')
            fprintf('Registry already exists at: %s\n', registry_path);
            return
        end
        registry_dir = fileparts(registry_path);
        if ~exist(registry_dir, 'dir')
            mkdir(registry_dir);
        end
        transducers = [];
        save(registry_path, 'transducers');
        fprintf('Empty transducer registry created at: %s\n', registry_path);

    otherwise
        error('cal_transducer_registry:unknownAction', ...
            'Unknown action: %s. Use load, save, add, list, get, or init.', action);
end
end

%% ================================================================
%  LOCAL FUNCTIONS
%% ================================================================

function p = cal_get_registry_path()
    cal_dir = fullfile(fileparts(mfilename('fullpath')), 'data');
    p       = fullfile(cal_dir, 'transducer_registry.mat');
end