function fit = probecal_fit(R, params)
% PROBECAL_FIT  Estimate the Thevenin source (Zs, Ps) of each probe driver.
%
% Takes the per-cavity results from probecal_measure_cavity, refines the
% cavity lengths with fminsearch so the cavity model best explains all
% cavities at once, then solves for the source impedance and pressure.
%
% Inputs:
%   R      - {1 x n_cav} cell of results from probecal_measure_cavity, in
%            any order (sorted by .cavity here). Every cavity must be present.
%   params - struct from probecal_default_params (needs f_err_khz, max_error)
%
% Output fit:
%   .freq            [nf x 1] Hz
%   .drivers         [1 x ndrv]
%   .Zs, .Ps         [nf x ndrv] source impedance and source pressure (Pa/V)
%   .pcav            [nf x ncav x ndrv] measured cavity responses used
%   .Zc              [nf x ncav x ndrv] fitted cavity impedances
%   .length_init_cm  [ncav x ndrv] starting lengths (from the measurement)
%   .length_cm       [ncav x ndrv] fitted lengths
%   .reflection      [1 x ndrv] fitted end reflection (<= 1)
%   .error_init      [1 x ndrv] thverr before the length fit
%   .error           [1 x ndrv] thverr after; ~1 means ~1% RMS residual
%   .cav_resid_db    [ncav x ndrv] median |model - measured| in the band, dB,
%                    so a single bad cavity can be identified and re-run
%   .pass            [1 x ndrv] error within [0, params.max_error]
%   .ok              all drivers pass and no flags
%   .flags           cellstr of problems found
%   .optim           fminsearch exit information per driver
%   .conditions      shared measurement conditions plus fit settings
%
% Zs and Ps at DC are NaN: a closed cavity has infinite impedance there.
% The fit band excludes DC, so this does not affect the fit.

IRR = 1;   % fit an end reflection along with the lengths, as the old code did

%% --- Validate and order the cavities ---

requireField(params, 'f_err_khz');
requireField(params, 'max_error');

if ~iscell(R) || isempty(R)
    error('probecal_fit:badInput', 'R must be a cell array of cavity results.');
end
if any(cellfun(@isempty, R))
    error('probecal_fit:missingCavity', ...
        'Cavities %s have not been measured.', mat2str(find(cellfun(@isempty, R))));
end

cav_ids = cellfun(@(r) r.cavity, R);
[cav_ids, order] = sort(cav_ids);
R = R(order);
if numel(unique(cav_ids)) ~= numel(cav_ids)
    error('probecal_fit:duplicateCavity', 'Cavity measured twice in R: %s.', mat2str(cav_ids));
end

n_cav = numel(R);
c0    = R{1}.conditions;

% Every cavity must share the conditions the fit assumes are common.
% A different dial, temperature or probe on one cavity would bias Zs and
% Ps without making the fit error look bad.
shared = {'stub', 'fs', 'buffer_size', 'drivers', 'atten_db', 'ref_peak', ...
          'mat2volts', 'delay_comp', 'ad_delay_samples', 'do_filt', ...
          'probe', 'mic_gain_dial', 'temp_c', 'cav_diam_cm'};
for k = 2:n_cav
    ck = R{k}.conditions;
    for j = 1:numel(shared)
        if ~isequaln(c0.(shared{j}), ck.(shared{j}))
            error('probecal_fit:mixedConditions', ...
                ['Cavity %d was measured with a different %s than cavity %d. ' ...
                 'Re-run it so all cavities share the same conditions.'], ...
                R{k}.cavity, shared{j}, R{1}.cavity);
        end
    end
    if ~isequal(R{k}.freq, R{1}.freq)
        error('probecal_fit:mixedFreq', ...
            'Cavity %d has a different frequency axis.', R{k}.cavity);
    end
end

%% --- Setup ---

freq    = R{1}.freq;
nf      = numel(freq);
drivers = c0.drivers;
n_drv   = numel(drivers);
temp_c  = c0.temp_c;
diam_cm = c0.cav_diam_cm;

ej = find(freq >= params.f_err_khz(1)*1000 & freq <= params.f_err_khz(2)*1000);
if numel(ej) < 2
    error('probecal_fit:badBand', 'f_err_khz selects fewer than 2 frequency bins.');
end

opts = optimset('TolFun', 1e-12, 'MaxIter', 1e5, 'MaxFunEvals', 1e5, 'Display', 'off');

%% --- Preallocate ---

fit.freq           = freq;
fit.drivers        = drivers;
fit.cavities       = cav_ids;
fit.Zs             = NaN(nf, n_drv);
fit.Ps             = NaN(nf, n_drv);
fit.pcav           = NaN(nf, n_cav, n_drv);
fit.Zc             = NaN(nf, n_cav, n_drv);
fit.length_init_cm = NaN(n_cav, n_drv);
fit.length_mm      = NaN(n_cav, n_drv);
fit.reflection     = NaN(1, n_drv);
fit.error_init     = NaN(1, n_drv);
fit.error          = NaN(1, n_drv);
fit.cav_resid_db   = NaN(n_cav, n_drv);
fit.pass           = false(1, n_drv);
fit.flags          = {};
fit.optim          = cell(1, n_drv);

%% --- Fit each driver ---

for d = 1:n_drv
    drv = drivers(d);

    % Skip a driver if any cavity lost it to rejection.
    bad = find(cellfun(@(r) r.n_good(d) < 2, R));
    if ~isempty(bad)
        fit.flags{end+1} = sprintf( ...
            'Driver %d: no usable data in cavities %s; not fitted.', drv, mat2str(cav_ids(bad)));
        continue
    end

    pcav = zeros(nf, n_cav);
    for k = 1:n_cav
        pcav(:, k) = R{k}.H(:, d);
    end
    fit.pcav(:, :, d) = pcav;

    % Start from the per-cavity length estimates, with a perfect reflection.
    L0 = cellfun(@(r) r.length_mm(d), R);
    fit.length_init_cm(:, d) = L0(:);
    la0 = [L0(:)', 1];

    costfn = @(la) thverr(la, ej, freq, pcav, IRR, diam_cm, temp_c);
    fit.error_init(d) = costfn(la0);

    [la, err, exitflag, output] = fminsearch(costfn, la0, opts);
    fit.optim{d} = struct('exitflag', exitflag, 'iterations', output.iterations, ...
                          'funcCount', output.funcCount, 'message', output.message);

    Zc = cavimp(freq, la, IRR, diam_cm, temp_c);
    [Zs, Ps] = thvsrc(Zc, pcav);
    Zs(1) = NaN;
    Ps(1) = NaN;

    fit.Zs(:, d)        = Zs;
    fit.Ps(:, d)        = Ps;
    fit.Zc(:, :, d)     = Zc;
    fit.length_cm(:, d) = la(1:end-1)';
    fit.reflection(d)   = la(end);
    fit.error(d)        = err;

    % Per-cavity residual: how well the fitted source explains each cavity.
    pmodel = (Ps * ones(1, n_cav)) .* Zc ./ ((Zs * ones(1, n_cav)) + Zc);
    resid  = abs(20*log10(abs(pcav(ej, :)) ./ abs(pmodel(ej, :))));
    fit.cav_resid_db(:, d) = median(resid, 1)';

    % --- Checks ---
    fit.pass(d) = err >= 0 && err <= params.max_error;
    if ~fit.pass(d)
        fit.flags{end+1} = sprintf( ...
            'Driver %d: fit error %.3g outside [0, %g].', drv, err, params.max_error);
    end
    if exitflag ~= 1
        fit.flags{end+1} = sprintf( ...
            'Driver %d: fminsearch did not converge (exitflag %d).', drv, exitflag);
    end
    [worst, kw] = max(fit.cav_resid_db(:, d));
    if worst > 3 * median(fit.cav_resid_db(:, d)) && worst > 0.5
        fit.flags{end+1} = sprintf( ...
            'Driver %d: cavity %d fits much worse than the others (%.2f dB). Re-run it?', ...
            drv, cav_ids(kw), worst);
    end
end

fit.ok = all(fit.pass) && isempty(fit.flags);

%% --- Conditions ---

fit.conditions             = rmfield(c0, 'measured_at');
fit.conditions.fit_band_hz = freq(ej([1 end]))';
fit.conditions.irr         = IRR;
fit.conditions.max_error   = params.max_error;
fit.conditions.fitted_at   = datetime('now');
t = cellfun(@(r) r.conditions.measured_at, R, 'UniformOutput', false);
fit.conditions.measured_at = [t{:}];   % one timestamp per cavity, in cavity order

end

%% ================================================================
%  LOCAL FUNCTIONS
%% ================================================================

function requireField(s, name)
if ~isfield(s, name)
    error('probecal_fit:missingParam', 'params.%s is required.', name);
end
end