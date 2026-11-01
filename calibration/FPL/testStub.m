% PROBECAL_TEST_STUB  Check probecal_measure_cavity against known truth.
%
% Runs all cavities in stub mode. The stub builds recordings from a known
% Zs and Ps, so the measured response H should match the expected cavity
% pressure Ps*Zc/(Zs+Zc). A match confirms the click spectrum, mat2volts,
% attenuation and mic conversion all round-trip correctly.
%
% Passing looks like:
%   band error      within about +/-0.5 dB
%   length estimate within a few percent of nominal
%   SNR             roughly 30 dB or more
%   reps kept       most of them (the stub adds ~2% artifact reps)
%   flags           none

tdt = []; 

cfg    = config_load();
params = probecal_default_params();
params.stub_mode = true;

n_cav = numel(params.cav_lengths_mm);
n_drv = numel(params.drivers);
R     = cell(1, n_cav);

fig = figure('Name', 'Probe cal stub test');
ax1 = subplot(2, 1, 1, 'Parent', fig); hold(ax1, 'on'); set(ax1, 'XScale', 'log');
ax2 = subplot(2, 1, 2, 'Parent', fig); hold(ax2, 'on'); set(ax2, 'XScale', 'log');

fprintf('\n%-4s %-8s %-18s %-14s %-12s %-14s\n', ...
    'Cav', 'Nom mm', 'Est cm (drv1/2)', 'SNR dB', 'Kept', 'Band err dB');

for k = 1:n_cav
    res  = probecal_measure_cavity(cfg, params, [], k);
    R{k} = res;

    L  = params.cav_lengths_mm(k) / 10;
    zc = cavimp(res.freq, [L, 1], 1, params.CavDiam_cm, params.CavTemp_C);
    f  = res.freq;
    band = f >= params.f_err_khz(1)*1000 & f <= params.f_err_khz(2)*1000;
    nz   = 2:numel(f);   % skip DC

    band_err = zeros(1, n_drv);
    for d = 1:n_drv
        H_true = res.stub_truth.Ps(:, d) .* zc ./ (res.stub_truth.Zs(:, d) + zc);
        err_db = 20*log10(abs(res.H(:, d)) ./ abs(H_true));
        band_err(d) = median(abs(err_db(band)));

        if d == 1
            semilogx(ax1, f(nz), 20*log10(abs(res.H(nz, d)) / 20e-6), 'LineWidth', 1.5);
            semilogx(ax1, f(nz), 20*log10(abs(H_true(nz)) / 20e-6), 'k--');
            semilogx(ax2, f(nz), err_db(nz));
        end
    end

    fprintf('%-4d %-8.1f %-18s %-14s %-12s %-14s\n', k, params.cav_lengths_mm(k), ...
        sprintf('%.2f / %.2f', res.length_mm), ...
        sprintf('%.1f / %.1f', res.snr_db), ...
        sprintf('%d/%d', res.n_good(1), res.n_total(1)), ...
        sprintf('%.2f / %.2f', band_err));

    for j = 1:numel(res.flags)
        fprintf('     FLAG: %s\n', res.flags{j});
    end
end

xlim(ax1, [100, 20e3]); xlim(ax2, [100, 20e3]);
ylabel(ax1, 'dB re 20 \muPa per V');
title(ax1, 'Driver 1: measured (solid) vs truth (dashed)');
ylabel(ax2, 'Measured - truth (dB)'); xlabel(ax2, 'Frequency (Hz)');
ylim(ax2, [-3, 3]);
xline(ax2, params.f_err_khz * 1000, ':');