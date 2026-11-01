function [cal, path, info] = probecal_lookup(cfg, current, opts)
% PROBECAL_LOOKUP  The FPL calibration a measure should use right now.
%
% If cfg.calibration.active_fpl_file is set, that pinned file is used. It
% must still match the current equipment, but its age is not enforced,
% since pinning is a deliberate choice.
%
% Otherwise returns the newest calibration that passed its fit, is not a
% stub, matches the current equipment and signal path, and is within
% params.max_age_rule.
%
% Inputs:
%   cfg     - struct from config_load
%   current - struct from probecal_current_conditions
%   opts    - optional struct:
%               .allow_stub  accept passing stub cals (testing only)
%
% Outputs:
%   cal   - the 'cal' struct from the file, or [] if none is usable
%   path  - its file path, or ''
%   info  - .source    'pinned', 'latest' or 'none'
%           .message   one line suitable for showing the operator
%           .rejected  struct array (.path, .reasons) of newer files skipped
%
% max_age_rule (in probecal_default_params):
%   'same_day'  fitted on today's calendar date
%   numeric     maximum age in hours

if nargin < 3
    opts = struct();
end
allow_stub = isfield(opts, 'allow_stub') && opts.allow_stub;

params = probecal_default_params();
if ~isfield(params, 'max_age_rule')
    error('probecal_lookup:noAgeRule', ...
        'probecal_default_params must define max_age_rule (''same_day'' or hours).');
end
rule = params.max_age_rule;

cal  = [];
path = '';
info = struct('source', 'none', 'message', '', ...
              'rejected', struct('path', {}, 'reasons', {}));

%% --- Pinned file ---

pinned = cfg.calibration.active_fpl_file;
if ~isempty(pinned)
    if ~exist(pinned, 'file')
        error('probecal_lookup:pinnedMissing', ...
            'Pinned FPL cal (calibration.active_fpl_file) does not exist: %s', pinned);
    end
    S = load(pinned, 'summary', 'cal');
    reasons = probecal_compatible(S.summary, cfg, current);
    if ~S.summary.ok
        reasons{end+1} = 'its fit did not pass';
    end
    if S.summary.stub && ~allow_stub
        reasons{end+1} = 'it is a stub calibration';
    end
    if ~isempty(reasons)
        error('probecal_lookup:pinnedIncompatible', ...
            'Pinned FPL cal %s cannot be used:\n  %s', pinned, strjoin(reasons, '\n  '));
    end
    cal  = S.cal;
    path = pinned;
    info.source  = 'pinned';
    info.message = sprintf('Using pinned FPL cal from %s.', ...
        char(S.summary.fitted_at, 'yyyy-MM-dd HH:mm'));
    return
end

%% --- Newest usable file ---

entries = probecal_list_cals(cfg, allow_stub);

if isempty(entries)
    info.message = sprintf('No FPL calibrations found in %s.', cfg.calibration.fpl_data_dir);
    return
end

for k = 1:numel(entries)
    s = entries(k).summary;
    reasons = probecal_compatible(s, cfg, current);
    if ~s.ok
        reasons{end+1} = 'fit did not pass'; %#ok<AGROW>
    end
    if s.stub && ~allow_stub
        reasons{end+1} = 'stub calibration'; %#ok<AGROW>
    end
    if ~withinAge(s.fitted_at, rule)
        reasons{end+1} = sprintf('too old (fitted %s)', ...
            char(s.fitted_at, 'yyyy-MM-dd HH:mm')); %#ok<AGROW>
    end

    if isempty(reasons)
        S    = load(entries(k).path, 'cal');
        cal  = S.cal;
        path = entries(k).path;
        info.source  = 'latest';
        info.message = sprintf('Using FPL cal for probe %s from %s.', ...
            s.probe.id, char(s.fitted_at, 'yyyy-MM-dd HH:mm'));
        return
    end

    info.rejected(end+1) = struct('path', entries(k).path, 'reasons', {reasons});
end

% Nothing usable: report why the newest one was rejected, which is
% usually the actionable reason (new probe, delay comp changed, too old).
[~, name] = fileparts(info.rejected(1).path);
info.message = sprintf('No usable FPL cal for probe %s. Newest (%s): %s.', ...
    cfg.equipment.probe.id, name, strjoin(info.rejected(1).reasons, '; '));

end

function ok = withinAge(t, rule)
now_t = datetime('now');
if ischar(rule) || isstring(rule)
    switch char(rule)
        case 'same_day'
            ok = dateshift(t, 'start', 'day') == dateshift(now_t, 'start', 'day');
        otherwise
            error('probecal_lookup:badAgeRule', 'Unknown max_age_rule ''%s''.', char(rule));
    end
elseif isnumeric(rule) && isscalar(rule)
    ok = hours(now_t - t) <= rule;
else
    error('probecal_lookup:badAgeRule', 'max_age_rule must be ''same_day'' or a number of hours.');
end
end