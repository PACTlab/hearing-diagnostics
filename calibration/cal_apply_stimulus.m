function [stim, cal_out] = cal_apply_stimulus(base_stim, params, cal_ctx)
% CAL_APPLY_STIMULUS  Shared calibration and level control for all measures.
%
% Single entry point for ABR, EFR, DPOAE, SFOAE and anything added later.
% Takes a peak-normalized, level-independent stimulus and returns the
% waveform to play plus the ANALOG ATTENUATION for each requested level.
%
%
% Inputs:
%   base_stim - [n x 1] stimulus, peak normalized to cal_ctx ref_peak.
%               Must NOT have level scaling applied.
%   params    - measure params. Uses:
%                 .cal_type      'atten' | 'none' | 'allstop' | 'SPL' | 'FPL'
%                 .levels_dbspl  level list; meaning depends on cal_type
%                 .frequency_hz  needed for SPL/FPL
%   cal_ctx   - optional struct; any field may be omitted:
%                 .transducer_cal  from cal_load_transducer, or []
%                 .ear_cal         in-ear filter struct, or []
%                 .fpl_cal         Thevenin source, or []
%
% Outputs:
%   stim    - [n x 1] waveform to load into the play buffer
%   cal_out - provenance and attenuation, saved with the run:
%               .atten_db          [1 x n_levels] -> att_ch1 / att_ch2
%               .levels_requested  [1 x n_levels] as given
%               .levels_achieved   [1 x n_levels] after clamp + quantize
%               .level_units       'dB attenuation' | 'dB SPL' | 'dB FPL'
%               .clamped           [1 x n_levels] logical
%               .digital_peak      scalar peak actually used
%               .cal_type          char
%               .eq_applied        logical
%               .eq_delay_samples  group delay to add to AD delay
%               .ear_cal_applied   logical
%               .ear_cal_file      char
%               .transducer_file   char
%               .measured_through  char
%               .gated             logical (allstop)
%               .warnings          cellstr
%
% CAL TYPES
%   'atten'   levels_dbspl is POSITIVE ATTENUATION in dB, 0 = loudest.
%             Needs no calibration file. Gives correct relative level
%             series immediately. Use this until the transducer cal format
%             and absolute levels are trusted.
%   'none'    No attenuation, level list ignored. Hardware debugging only.
%   'allstop' Digital zeros AND maximum analog attenuation, so a control
%             run is genuinely silent rather than merely quiet.
%   'SPL'     Not yet implemented — needs the new cal file format with
%             spl_at_full_scale_db. See calibration-design.md step 4.
%   'FPL'     Not yet implemented — needs two-load Thevenin measurements.

if nargin < 3
    cal_ctx = struct();
end

cfg = config_load();

max_atten_db  = cfg.hardware.max_atten_db;
atten_step_db = cfg.hardware.atten_step_db;
ref_peak      = cfg.calibration.ref_peak;

%% --- Initialize output ---

cal_out = struct( ...
    'atten_db',         [], ...
    'levels_requested', params.levels_dbspl(:)', ...
    'levels_achieved',  [], ...
    'level_units',      '', ...
    'clamped',          [], ...
    'digital_peak',     NaN, ...
    'cal_type',         params.cal_type, ...
    'eq_applied',       false, ...
    'eq_delay_samples', 0, ...
    'ear_cal_applied',  false, ...
    'ear_cal_file',     '', ...
    'transducer_file',  '', ...
    'measured_through', cfg.calibration.measured_through, ...
    'gated',            false, ...
    'warnings',         {{}});

stim      = base_stim(:);
n_levels  = numel(params.levels_dbspl);

%% --- Check the input really is peak-normalized ---
% Level scaling applied upstream would compound with the analog
% attenuation and put every level wrong by an unknown amount.

observed_peak = max(abs(stim));

if observed_peak == 0
    cal_out.warnings{end+1} = 'Input stimulus is all zeros.';
elseif abs(observed_peak - ref_peak) > 0.02
    cal_out.warnings{end+1} = sprintf( ...
        ['Stimulus peak is %.4f but ref_peak is %.4f. Normalize in ' ...
         '{m}_make_stimulus; do not apply level scaling there.'], ...
        observed_peak, ref_peak);
    warning('cal_apply_stimulus:notNormalized', '%s', cal_out.warnings{end});
end

cal_out.digital_peak = observed_peak;

%% =================================================================
%  LEVEL REFERENCE
%% =================================================================

switch lower(params.cal_type)

    case 'atten'
        % levels_dbspl IS the attenuation, positive, 0 = loudest
        cal_out.level_units = 'dB attenuation';
        atten_req = params.levels_dbspl(:)';

        if any(atten_req < 0)
            error('cal_apply_stimulus:negativeAtten', ...
                ['cal_type ''atten'' takes POSITIVE attenuation values ' ...
                 'with 0 = loudest. Got a negative entry.']);
        end

    case 'none'
        cal_out.level_units = 'none (fixed output)';
        atten_req = zeros(1, n_levels);
        cal_out.warnings{end+1} = ...
            'cal_type ''none'': level list ignored, output at full scale.';

    case 'allstop'
        cal_out.level_units = 'none (gated off)';
        atten_req      = repmat(max_atten_db, 1, n_levels);
        stim(:)        = 0;
        cal_out.gated  = true;
        cal_out.warnings{end+1} = ...
            ['cal_type ''allstop'': NO STIMULUS PRESENTED. Digital zeros ' ...
             'and maximum attenuation. This is a control run.'];
        warning('cal_apply_stimulus:outputGated', '%s', cal_out.warnings{end});

    case 'spl'
        error('cal_apply_stimulus:notImplemented', ...
            ['cal_type ''SPL'' is not wired up yet. It needs the new cal ' ...
             'file format with spl_at_full_scale_db (see ' ...
             'calibration-design.md, step 4). The old path applied the ' ...
             'whole correction digitally and left the attenuator at a ' ...
             'hardcoded 30 dB, making every level 30 dB low.\n' ...
             'Use cal_type ''atten'' for relative level series.']);

    case 'fpl'
        error('cal_apply_stimulus:notImplemented', ...
            ['cal_type ''FPL'' is not implemented — it needs two-load ' ...
             'Thevenin measurements. Use ''atten'' or ''SPL''.']);

    otherwise
        error('cal_apply_stimulus:unknownCalType', ...
            ['Unknown cal_type: %s. Use atten, none, allstop, SPL, ' ...
             'or FPL.'], params.cal_type);
end

%% =================================================================
%  SPECTRAL CORRECTION
%% =================================================================
% Independent of the level reference above. Applied to the UNPADDED
% waveform, because an FIR filter's group delay would otherwise shift
% stimulus onset relative to rec_window_ms, and its tail would smear past
% the intended stimulus extent.

apply_ear_cal = isfield(params, 'apply_ear_cal') && params.apply_ear_cal;

if apply_ear_cal
    ear_cal = [];
    if isfield(cal_ctx, 'ear_cal') && ~isempty(cal_ctx.ear_cal)
        ear_cal = cal_ctx.ear_cal;
    end

    if isempty(ear_cal)
        cal_out.warnings{end+1} = ...
            ['apply_ear_cal is true but no in-ear cal is loaded. ' ...
             'Running uncorrected.'];
        warning('cal_apply:noInearCal', '%s', cal_out.warnings{end});
    else
        stim = filter(ear_cal.b, 1, stim);
        cal_out.ear_cal_applied  = true;
        cal_out.eq_delay_samples = firGroupDelay(ear_cal.b);

        if isfield(ear_cal, 'source_file')
            cal_out.ear_cal_file = ear_cal.source_file;
        end

        % Filtering changes the peak. Renormalize so the digital amplitude
        % stays at ref_peak and the analog attenuation stays meaningful.
        new_peak = max(abs(stim));
        if new_peak > 0
            stim = stim * (ref_peak / new_peak);
            cal_out.digital_peak = ref_peak;
        end
    end
end

%% =================================================================
%  CLAMP AND QUANTIZE ATTENUATION
%% =================================================================
% Clamp and record, rather than error. A clamped level is still useful
% data as long as the run file says plainly what was actually presented.

atten_clamped = min(max(atten_req, 0), max_atten_db);
cal_out.clamped = atten_clamped ~= atten_req;

if any(cal_out.clamped)
    idx = find(cal_out.clamped);
    cal_out.warnings{end+1} = sprintf( ...
        ['%d of %d requested levels exceed the attenuator range ' ...
         '[0 %g] dB and were clamped. Requested: %s'], ...
        numel(idx), n_levels, max_atten_db, ...
        mat2str(atten_req(idx)));
    warning('cal_apply_stimulus:attenClamped', '%s', cal_out.warnings{end});
end

if atten_step_db > 0
    atten_final = round(atten_clamped / atten_step_db) * atten_step_db;
else
    atten_final = atten_clamped;
end

cal_out.atten_db = atten_final;

%% --- What was actually presented ---

switch lower(params.cal_type)
    case 'atten'
        cal_out.levels_achieved = atten_final;
    otherwise
        cal_out.levels_achieved = atten_final;
end

%% --- Transducer provenance, even when unused ---

if isfield(cal_ctx, 'transducer_cal') && ~isempty(cal_ctx.transducer_cal) ...
        && isfield(cal_ctx.transducer_cal, 'filename')
    cal_out.transducer_file = cal_ctx.transducer_cal.filename;
end

end

%% ================================================================
%  LOCAL FUNCTIONS
%% ================================================================

function d = firGroupDelay(b)
% Group delay of an FIR filter, in samples, as its energy centroid.
% For a linear-phase filter this is (length-1)/2; the centroid is a
% reasonable approximation for the minimum-phase case too.
b = b(:);
e = b.^2;
if sum(e) == 0
    d = 0;
    return
end
d = round(sum((0:numel(b)-1)' .* e) / sum(e));
end