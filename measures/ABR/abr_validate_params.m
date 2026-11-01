function [err, warn] = abr_validate_params(params)
% ABR_VALIDATE_PARAMS  Check ABR parameters before acquisition.
%
% Outputs:
%   err  - char. Empty means valid. Otherwise every problem found, one per
%          line, so the operator fixes them all in one pass instead of
%          rediscovering them one Run press at a time.
%   warn - char. Things that are legal but probably not intended. The run
%          proceeds; these are for display.
%

E = {};   % errors
W = {};   % warnings

%% --- Required fields ---
% A params struct from a stale project defaults file can be missing
% fields added later. Catch that here rather than mid-run.

required = { ...
    'measure_type', 'ear', 'stim_type', 'cal_type', 'apply_ear_cal', ...
    'frequency_hz', 'duration_cyc', 'rise_fall_cyc', 'window_type', ...
    'levels_dbspl', 'polarity', 'rate_hz', 'jitter_pct', 'n_reps', ...
    'rec_window_ms', 'fs', 'stim_delay_ms', 'artifact_reject', ...
    'viz_window_ms', 'amplitude_window_uV'};

missing = required(~isfield(params, required));
if ~isempty(missing)
    E{end+1} = sprintf('Missing parameter fields: %s', strjoin(missing, ', '));
    % Without these, nothing below can be checked meaningfully.
    err  = strjoin(E, newline);
    warn = strjoin(W, newline);
    return
end

%% --- Enumerations ---

[E, stim_type] = checkMember(E, params.stim_type, ...
    {'toneburst', 'click', 'chirp'}, 'stim_type');
[E, ear]       = checkMember(E, params.ear, ...
    {'left', 'right', 'both'}, 'ear');
[E, polarity]  = checkMember(E, params.polarity, ...
    {'alt', 'cond', 'rare'}, 'polarity');
[E, cal_type]  = checkMember(E, params.cal_type, ...
    {'atten', 'none', 'allstop', 'spl', 'fpl'}, 'cal_type');

if ~ismember(lower(params.window_type), {'blackman', 'hann'})
    W{end+1} = sprintf( ...
        'window_type ''%s'' is not recognized; blackman will be used.', ...
        params.window_type);
end

%% --- Numeric guards ---

E = checkPositiveScalar(E, params.n_reps,        'n_reps');
E = checkPositiveScalar(E, params.rate_hz,       'rate_hz');
E = checkPositiveScalar(E, params.fs,            'fs');
E = checkFiniteScalar(  E, params.stim_delay_ms, 'stim_delay_ms');

if isFiniteScalar(params.n_reps) && params.n_reps ~= round(params.n_reps)
    E{end+1} = sprintf('n_reps must be a whole number, got %g.', params.n_reps);
end

if isFiniteScalar(params.stim_delay_ms) && params.stim_delay_ms < 0
    E{end+1} = 'stim_delay_ms cannot be negative.';
end

if isFiniteScalar(params.jitter_pct)
    if params.jitter_pct < 0 || params.jitter_pct > 50
        E{end+1} = sprintf( ...
            'jitter_pct must be between 0 and 50, got %g.', params.jitter_pct);
    end
else
    E{end+1} = 'jitter_pct must be a finite number.';
end

% Toneburst-only shape parameters
if strcmp(stim_type, 'toneburst')
    E = checkPositiveScalar(E, params.frequency_hz,  'frequency_hz');
    E = checkPositiveScalar(E, params.duration_cyc,  'duration_cyc');
    E = checkPositiveScalar(E, params.rise_fall_cyc, 'rise_fall_cyc');

    if isFiniteScalar(params.frequency_hz) && isFiniteScalar(params.fs)
        if params.frequency_hz >= params.fs / 2
            E{end+1} = sprintf( ...
                ['frequency_hz (%g) is at or above Nyquist (%g). ' ...
                 'The tone will alias.'], ...
                params.frequency_hz, params.fs / 2);
        end
    end
end

% Click-only
if strcmp(stim_type, 'click')
    if isfield(params, 'click_duration_us')
        E = checkPositiveScalar(E, params.click_duration_us, 'click_duration_us');
    end
    if isfield(params, 'filtclick') && params.filtclick
        if ~isfield(params, 'click_filter') || numel(params.click_filter) ~= 2
            E{end+1} = 'click_filter must be a [low high] pair when filtclick is on.';
        elseif params.click_filter(1) >= params.click_filter(2)
            E{end+1} = sprintf( ...
                'click_filter must be increasing, got [%g %g].', ...
                params.click_filter(1), params.click_filter(2));
        elseif isFiniteScalar(params.fs) && params.click_filter(2) >= params.fs/2
            E{end+1} = sprintf( ...
                'click_filter upper edge (%g) is at or above Nyquist (%g).', ...
                params.click_filter(2), params.fs/2);
        end
    end
end

% Chirp-only
if strcmp(stim_type, 'chirp')
    if ~isfield(params, 'chirp_file') || isempty(params.chirp_file)
        E{end+1} = 'stim_type is chirp but chirp_file is not set.';
    elseif ~exist(params.chirp_file, 'file')
        E{end+1} = sprintf('chirp_file not found: %s', params.chirp_file);
    end
end

%% --- Windows ---

E = checkRangePair(E, params.rec_window_ms,       'rec_window_ms');
E = checkRangePair(E, params.viz_window_ms,       'viz_window_ms');
E = checkRangePair(E, params.amplitude_window_uV, 'amplitude_window_uV');

if isRangePair(params.rec_window_ms) && params.rec_window_ms(1) < 0
    E{end+1} = 'rec_window_ms cannot start before 0.';
end

if isRangePair(params.rec_window_ms) && isRangePair(params.viz_window_ms)
    if params.viz_window_ms(1) < params.rec_window_ms(1) || ...
            params.viz_window_ms(2) > params.rec_window_ms(2)
        W{end+1} = sprintf( ...
            ['viz_window_ms [%g %g] extends outside rec_window_ms ' ...
             '[%g %g]; the plot will show empty space.'], ...
            params.viz_window_ms, params.rec_window_ms);
    end
end

%% --- Levels, and their units ---
% levels_dbspl means different things depending on cal_type. Nothing else
% in the system checks that the two agree, and the GUI field is still
% labelled dB SPL.

levels = params.levels_dbspl;

if isempty(levels)
    E{end+1} = 'levels_dbspl is empty — nothing to present.';
elseif ~isnumeric(levels) || ~isreal(levels) || any(~isfinite(levels))
    E{end+1} = ['levels_dbspl must be finite real numbers. Check the ' ...
                'Levels field for blanks or stray characters.'];
else
    if numel(unique(levels)) < numel(levels)
        W{end+1} = 'levels_dbspl contains duplicates; those levels will run twice.';
    end

    switch cal_type
        case 'atten'
            if any(levels < 0)
                E{end+1} = sprintf( ...
                    ['cal_type ''atten'' takes POSITIVE attenuation with ' ...
                     '0 = loudest. Negative values found: %s'], ...
                    mat2str(levels(levels < 0)));
            end

            % The classic mistake: an SPL-style descending list pasted in
            % while cal_type is atten, so it runs quietest-to-loudest with
            % the numbers meaning the opposite of the GUI label.
            if numel(levels) > 1 && all(diff(levels) < 0)
                W{end+1} = sprintf( ...
                    ['levels_dbspl descends (%g to %g) but cal_type is ' ...
                     '''atten'', where 0 is LOUDEST. This will present ' ...
                     'quietest first. If you meant dB SPL, these are not ' ...
                     'dB SPL.'], levels(1), levels(end));
            end

            cfg = config_load();
            over = levels > cfg.hardware.max_atten_db;
            if any(over)
                W{end+1} = sprintf( ...
                    ['%d level(s) exceed the attenuator maximum of %g dB ' ...
                     'and will be clamped: %s'], ...
                    sum(over), cfg.hardware.max_atten_db, ...
                    mat2str(levels(over)));
            end

        case {'spl', 'fpl'}
            E{end+1} = sprintf( ...
                ['cal_type ''%s'' is not wired up yet (see ' ...
                 'calibration-design.md). Use ''atten'' for a relative ' ...
                 'level series.'], upper(cal_type));

        case 'none'
            W{end+1} = ['cal_type ''none'': the level list is ignored and ' ...
                        'output runs at full scale.'];

        case 'allstop'
            W{end+1} = ['cal_type ''allstop'': NO STIMULUS WILL BE ' ...
                        'PRESENTED. This is a control run.'];
    end
end

%% --- Artifact rejection ---

if params.artifact_reject
    if ~isfield(params, 'artifact_thresh_uv')
        E{end+1} = 'artifact_reject is on but artifact_thresh_uv is missing.';
    else
        E = checkPositiveScalar(E, params.artifact_thresh_uv, 'artifact_thresh_uv');
    end
end

%% --- In-ear calibration ---

if params.apply_ear_cal && isfield(params, 'ear_cal_file') && ...
        ~isempty(params.ear_cal_file) && ~exist(params.ear_cal_file, 'file')
    E{end+1} = sprintf('ear_cal_file not found: %s', params.ear_cal_file);
end

%% --- Timing feasibility ---
% Two separate constraints, both of which currently fail at runtime rather
% than here.

if isFiniteScalar(params.fs) && isFiniteScalar(params.rate_hz) && ...
        params.fs > 0 && params.rate_hz > 0

    nominal_isi_samples = round(params.fs / params.rate_hz);
    min_isi_samples     = floor(nominal_isi_samples * ...
                                (1 - max(params.jitter_pct, 0) / 100));

    % (a) the recorded epoch must fit inside the shortest jittered ISI,
    %     or epoch_raw(1, 1:epoch_samples) indexes past the buffer
    if isRangePair(params.rec_window_ms)
        epoch_samples = round(diff(params.rec_window_ms) / 1000 * params.fs);

        if epoch_samples < 1
            E{end+1} = 'rec_window_ms is too short to contain a single sample.';
        elseif epoch_samples > min_isi_samples
            E{end+1} = sprintf( ...
                ['Record window (%.2f ms) is longer than the shortest ' ...
                 'jittered ISI (%.2f ms at %g Hz with %g%% jitter). ' ...
                 'Lower rate_hz or shorten rec_window_ms.'], ...
                diff(params.rec_window_ms), ...
                min_isi_samples / params.fs * 1000, ...
                params.rate_hz, params.jitter_pct);
        end
    end

    % (b) the stimulus itself must fit inside the ISI
    n_stim_est = estimateStimSamples(params, stim_type);

    if ~isnan(n_stim_est) && n_stim_est > nominal_isi_samples
        E{end+1} = sprintf( ...
            ['Stimulus plus onset delay (%.2f ms) is longer than the ISI ' ...
             '(%.2f ms). Increase rate_hz or shorten the stimulus.'], ...
            n_stim_est / params.fs * 1000, ...
            nominal_isi_samples / params.fs * 1000);
    end

    % (c) the stimulus should fit inside the recorded window, or the
    %     response is cut off
    if ~isnan(n_stim_est) && isRangePair(params.rec_window_ms)
        epoch_samples = round(diff(params.rec_window_ms) / 1000 * params.fs);
        if n_stim_est > epoch_samples
            W{end+1} = sprintf( ...
                ['Stimulus (%.2f ms) is longer than the record window ' ...
                 '(%.2f ms); the later part of the response is not saved.'], ...
                n_stim_est / params.fs * 1000, ...
                diff(params.rec_window_ms));
        end
    end
end

%% --- Hardware consistency ---
% A project defaults file written before the config migration can still
% carry a literal fs, which would silently disagree with the hardware.

try
    cfg = config_load();
    if isFiniteScalar(params.fs) && ...
            abs(params.fs - cfg.hardware.fs_playback_hz) > 1e-6
        E{end+1} = sprintf( ...
            ['params.fs (%.4f) does not match ' ...
             'config.hardware.fs_playback_hz (%.4f). Stimulus timing ' ...
             'and all saved time vectors would be wrong. Is this params ' ...
             'struct from an old project defaults file?'], ...
            params.fs, cfg.hardware.fs_playback_hz);
    end
catch
    W{end+1} = 'Could not load config to cross-check fs.';
end

if isfield(params, 'electrode_gain_applied') && ...
        ~ismember(params.electrode_gain_applied, {'circuit', 'software', 'none'})
    E{end+1} = sprintf( ...
        'electrode_gain_applied must be circuit, software, or none; got ''%s''.', ...
        params.electrode_gain_applied);
end

%% --- Assemble ---

err  = strjoin(E, newline);
warn = strjoin(W, newline);

end

%% ================================================================
%  LOCAL FUNCTIONS
%  Candidates to hoist into a shared validate/ folder when
%  efr_validate_params and the others are written — every measure needs
%  these same guards.
%% ================================================================

function tf = isFiniteScalar(v)
tf = isnumeric(v) && isscalar(v) && isreal(v) && isfinite(v);
end

function E = checkFiniteScalar(E, v, name)
if ~isFiniteScalar(v)
    E{end+1} = sprintf( ...
        '%s must be a single finite number (blank fields read as NaN).', name);
end
end

function E = checkPositiveScalar(E, v, name)
if ~isFiniteScalar(v)
    E{end+1} = sprintf( ...
        '%s must be a single finite number (blank fields read as NaN).', name);
elseif v <= 0
    E{end+1} = sprintf('%s must be greater than zero, got %g.', name, v);
end
end

function tf = isRangePair(v)
tf = isnumeric(v) && numel(v) == 2 && all(isfinite(v)) && v(2) > v(1);
end

function E = checkRangePair(E, v, name)
if ~isnumeric(v) || numel(v) ~= 2 || any(~isfinite(v))
    E{end+1} = sprintf('%s must be two finite numbers, [low high].', name);
elseif v(2) <= v(1)
    E{end+1} = sprintf( ...
        '%s must be increasing, got [%g %g].', name, v(1), v(2));
end
end

function [E, value] = checkMember(E, raw, allowed, name)
if ~(ischar(raw) || isstring(raw))
    E{end+1} = sprintf('%s must be text, one of: %s', ...
        name, strjoin(allowed, ', '));
    value = '';
    return
end
value = lower(char(raw));
if ~ismember(value, allowed)
    E{end+1} = sprintf('Unknown %s ''%s''. Use one of: %s', ...
        name, value, strjoin(allowed, ', '));
end
end

function n = estimateStimSamples(params, stim_type)
% Sample count abr_make_stimulus will produce, including stim_delay_ms.
% Mirrors the generation code; kept approximate on purpose, since this is
% a feasibility check rather than a measurement.

if ~isFiniteScalar(params.fs) || ~isFiniteScalar(params.stim_delay_ms)
    n = NaN;
    return
end

delay_samps = ceil(params.stim_delay_ms / 1000 * params.fs);

switch stim_type
    case 'toneburst'
        if ~isFiniteScalar(params.frequency_hz) || params.frequency_hz <= 0 ...
                || ~isFiniteScalar(params.duration_cyc) ...
                || ~isFiniteScalar(params.rise_fall_cyc)
            n = NaN;
            return
        end
        n_rise    = ceil((params.rise_fall_cyc / params.frequency_hz) * params.fs);
        n_plateau = ceil((params.duration_cyc  / params.frequency_hz) * params.fs);
        n = delay_samps + n_plateau + 2 * n_rise;

    case 'click'
        % make_click returns only the click and its filter tails. When
        % filtered, the blackman gate bounds it at ~1.66 ms; unfiltered it
        % is just click_duration_us.
        if ~isfield(params, 'click_duration_us') || ...
                ~isFiniteScalar(params.click_duration_us)
            n = NaN;
            return
        end
        if isfield(params, 'filtclick') && params.filtclick
            n = delay_samps + round(params.fs * 1.66e-3);
        else
            n = delay_samps + ...
                max(1, round(params.click_duration_us / 1e6 * params.fs));
        end

    otherwise
        n = NaN;   % chirp length is only known once the file is read
end

end