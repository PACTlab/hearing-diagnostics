% PROBECAL_TEST_FIT  Check that probecal_fit recovers the stub's known source.
%
% Reuses R from probecal_test_stub if it is in the workspace; otherwise
% measures all cavities in stub mode first.
%
% The stub cavities use the same cavimp model the fit assumes, so this is
% a self-consistency test: it proves the fit machinery works, not that the
% model matches real tubes. Real calibrations will have larger errors.
%
% Passing looks like:
%   fit error         well under params.max_error
%   fitted lengths    within a fraction of a mm of nominal
%   reflection        close to 1
%   Ps, Zs in band    within a fraction of a dB, phase within a few degrees
%   flags             none

params = probecal_default_params();
params.stub_mode = true;

if ~exist('R', 'var') || ~iscell(R) || isempty(R)
    cfg = config_load();
    n_cav = numel(params.cav_lengths_mm);
    R = cell(1, n_cav);
    for k = 1:n_cav
        R{k} = probecal_measure_cavity(cfg, params, [], k);
    end
end

fit = probecal_fit(R, params);

truth = R{1}.stub_truth;
f     = fit.freq;
band  = f >= params.f_err_khz(1)*1000 & f <= params.f_err_khz(2)*1000;
nom   = params.cav_lengths_mm(fit.cavities)' / 10;

fprintf('\n=== Fit vs stub truth ===\n');
for d = 1:numel(fit.drivers)
    ps_db  = median(abs(20*log10(abs(fit.Ps(band, d)) ./ abs(truth.Ps(band, d)))));
    ps_deg = median(abs(rad2deg(angle(fit.Ps(band, d) ./ truth.Ps(band, d)))));
    zs_db  = median(abs(20*log10(abs(fit.Zs(band, d)) ./ abs(truth.Zs(band, d)))));
    zs_deg = median(abs(rad2deg(angle(fit.Zs(band, d) ./ truth.Zs(band, d)))));

    fprintf('\nDriver %d\n', fit.drivers(d));
    fprintf('  fit error     %.4g (init %.4g, limit %g)\n', ...
        fit.error(d), fit.error_init(d), params.max_error);
    fprintf('  reflection    %.4f\n', fit.reflection(d));
    fprintf('  Ps error      %.3f dB, %.2f deg (median in band)\n', ps_db, ps_deg);
    fprintf('  Zs error      %.3f dB, %.2f deg (median in band)\n', zs_db, zs_deg);
    fprintf('  %-6s %-10s %-10s %-10s %-12s\n', 'Cav', 'Nom cm', 'Init cm', 'Fit cm', 'Resid dB');
    for k = 1:numel(fit.cavities)
        fprintf('  %-6d %-10.3f %-10.3f %-10.3f %-12.3f\n', fit.cavities(k), nom(k), ...
            fit.length_init_cm(k, d), fit.length_cm(k, d), fit.cav_resid_db(k, d));
    end
end

for j = 1:numel(fit.flags)
    fprintf('FLAG: %s\n', fit.flags{j});
end
fprintf('\nfit.ok = %d\n', fit.ok);

% --- Plots ---
nz  = 2:numel(f);
fig = figure('Name', 'Probe cal fit test');
ax1 = subplot(2, 1, 1, 'Parent', fig); hold(ax1, 'on'); set(ax1, 'XScale', 'log');
ax2 = subplot(2, 1, 2, 'Parent', fig); hold(ax2, 'on'); set(ax2, 'XScale', 'log');
for d = 1:numel(fit.drivers)
    plot(ax1, f(nz), 20*log10(abs(fit.Ps(nz, d)) / 20e-6), 'LineWidth', 1.5);
    plot(ax1, f(nz), 20*log10(abs(truth.Ps(nz, d)) / 20e-6), 'k--');
    plot(ax2, f(nz), 20*log10(abs(fit.Zs(nz, d))), 'LineWidth', 1.5);
    plot(ax2, f(nz), 20*log10(abs(truth.Zs(nz, d))), 'k--');
end
xlim(ax1, [100, 20e3]); xlim(ax2, [100, 20e3]);
xline(ax1, params.f_err_khz * 1000, ':'); xline(ax2, params.f_err_khz * 1000, ':');
ylabel(ax1, '|Ps| (dB re 20 \muPa per V)');
title(ax1, 'Fitted (solid) vs truth (dashed), both drivers');
ylabel(ax2, '|Zs| (dB)'); xlabel(ax2, 'Frequency (Hz)');