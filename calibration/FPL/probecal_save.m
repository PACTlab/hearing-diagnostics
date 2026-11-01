function path = probecal_save(cfg, fit, R, params, opts)
% PROBECAL_SAVE  Save a finished FPL probe calibration.
%
% Writes one .mat file per calibration to cfg.calibration.fpl_data_dir,
% named by probe id and fit time. Stub calibrations go to a 'stub'
% subfolder so they can never be picked up as real ones.
%
% Inputs:
%   cfg    - struct from config_load
%   fit    - struct from probecal_fit
%   R      - the per-cavity results the fit was made from
%   params - struct from probecal_default_params (stored for the record)
%   opts   - optional struct:
%              .comment      free text
%              .allow_fail   save even though fit.ok is false (default false)
%              .fail_reason  required when saving a failed fit
%
% Output:
%   path   - full path of the saved file
%
% The file holds two variables:
%   summary  small struct with everything the lookup needs, so scanning a
%            folder of calibrations never loads the full data
%   cal      summary, fit, per-cavity results, params, software version

if nargin < 5
    opts = struct();
end
comment     = getOpt(opts, 'comment', '');
allow_fail  = getOpt(opts, 'allow_fail', false);
fail_reason = getOpt(opts, 'fail_reason', '');

%% --- Refuse failed fits unless explicitly overridden ---

if ~fit.ok
    if ~allow_fail
        error('probecal_save:failedFit', ...
            ['The fit did not pass:\n  %s\nSet opts.allow_fail with a ' ...
             'fail_reason to save it anyway; it will never be used by the lookup.'], ...
            strjoin(fit.flags, '\n  '));
    end
    if isempty(fail_reason)
        error('probecal_save:noReason', ...
            'Saving a failed fit requires opts.fail_reason.');
    end
end

%% --- Where and what to call it ---

c    = fit.conditions;
stub = c.stub;

save_dir = cfg.calibration.fpl_data_dir;
if stub
    save_dir = fullfile(save_dir, 'stub');
end
if ~exist(save_dir, 'dir')
    mkdir(save_dir);
end

probe_tag = regexprep(c.probe.id, '[^\w-]', '_');
base = sprintf('FPLcal_%s_%s', probe_tag, char(c.fitted_at, 'yyyyMMdd_HHmmss'));
path = fullfile(save_dir, [base '.mat']);
k = 2;
while exist(path, 'file')
    path = fullfile(save_dir, sprintf('%s_%d.mat', base, k));
    k = k + 1;
end

%% --- Summary: everything the lookup and history checks read ---

summary.file_format      = 1;
summary.probe            = c.probe;
summary.fitted_at        = c.fitted_at;
summary.stub             = stub;
summary.ok               = fit.ok;
summary.valid            = fit.ok && ~stub;   % the lookup's first test
summary.error            = fit.error;
summary.fs               = c.fs;
summary.buffer_size      = c.buffer_size;
summary.mat2volts        = c.mat2volts;
summary.delay_comp       = c.delay_comp;
summary.ad_delay_samples = c.ad_delay_samples;
summary.mic_gain_dial         = c.mic_gain_dial;
summary.temp_c           = c.temp_c;
summary.comment          = comment;
summary.fail_reason      = fail_reason;

cal.summary          = summary;
cal.fit              = fit;
cal.cavities         = R;
cal.params           = params;
cal.software_version = cfg.software_version;
cal.saved_at         = datetime('now');

save(path, 'summary', 'cal');
fprintf('FPL calibration saved: %s\n', path);

end

function v = getOpt(opts, name, default)
if isfield(opts, name) && ~isempty(opts.(name))
    v = opts.(name);
else
    v = default;
end
end