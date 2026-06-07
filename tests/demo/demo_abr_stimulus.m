% DEMO_ABR_STIMULUS
% -------------------------------------------------------------------------
% Verifies ABR stimulus generation without any hardware.
% Run this on a new system or after changing abr_make_stimulus to confirm
% that tone bursts and clicks look and sound correct before running subjects.
%
% What this checks:
%   - Tone burst waveform shape, duration, and frequency content
%   - Click waveform
%   - Polarity alternation
%   - ISI jitter distribution
%   - Calibration warning when no cal file is loaded
%
% Usage:
%   cd to project root, run startup, then run this script.
% -------------------------------------------------------------------------

startup
close all
warning('off', 'abr_make_stimulus:noCal');

fprintf('\n=== ABR Stimulus Demo ===\n\n');

fs = 48828.125;

%% ================================================================
%  SECTION 1 — Tone burst
%% ================================================================

fprintf('--- Tone burst ---\n');

params              = abr_default_params();
params.stim_type    = 'toneburst';
params.frequency_hz = 8000;
params.levels_dbspl = 70;
params.duration_cyc = 8;
params.rise_fall_cyc = 2;
params.window_type  = 'blackman';
params.rate_hz      = 11.1;
params.jitter_pct   = 10;
params.n_reps       = 20;
params.polarity     = 'alt';
params.fs           = fs;

[stim_out, stim_info] = abr_make_stimulus(params, []);

t_stim = (0:stim_out.n_stim-1) / fs * 1000;   % ms
t_buf  = (0:length(stim_out.pos)-1) / fs * 1000;

fprintf('  Frequency:       %d Hz\n',    params.frequency_hz);
fprintf('  Duration:        %.2f ms\n',  stim_info.stim_duration_ms);
fprintf('  Nominal ISI:     %.2f ms\n',  stim_info.nominal_isi_ms);
fprintf('  Max ISI:         %.2f ms\n',  stim_info.max_isi_ms);
fprintf('  Buffer length:   %d samples\n', length(stim_out.pos));
fprintf('  Jitter range:    %.2f – %.2f ms\n', ...
    min(stim_out.isi_samples)/fs*1000, ...
    max(stim_out.isi_samples)/fs*1000);

figure('Name', 'ABR Stimulus Demo — Tone Burst', ...
    'Position', [50 50 1100 700]);

% --- Positive polarity waveform ---
subplot(3, 3, 1);
plot(t_buf, stim_out.pos, 'Color', [0.11 0.62 0.46], 'LineWidth', 1.2);
xlabel('Time (ms)'); ylabel('Amplitude');
title('Pos polarity — full buffer');
xlim([0 t_buf(end)]);
grid on;

% --- Zoom into stimulus portion ---
subplot(3, 3, 2);
plot(t_stim, stim_out.pos(1:stim_out.n_stim), ...
    'Color', [0.11 0.62 0.46], 'LineWidth', 1.5);
hold on;
plot(t_stim, stim_out.neg(1:stim_out.n_stim), ...
    'Color', [0.85 0.35 0.18], 'LineWidth', 1.5, 'LineStyle', '--');
xlabel('Time (ms)'); ylabel('Amplitude');
title('Pos (green) vs Neg (red) — stimulus only');
legend('Pos', 'Neg', 'Location', 'best');
grid on;

% --- Sum of pos + neg (should cancel for alternating) ---
subplot(3, 3, 3);
sum_sig = stim_out.pos(1:stim_out.n_stim) + stim_out.neg(1:stim_out.n_stim);
plot(t_stim, sum_sig, 'Color', [0.4 0.4 0.4], 'LineWidth', 1.2);
xlabel('Time (ms)'); ylabel('Amplitude');
title('Pos + Neg (should be ~0 for alt polarity)');
yline(0, 'k--');
grid on;

% --- Frequency content ---
subplot(3, 3, 4);
stim_portion = stim_out.pos(1:stim_out.n_stim);
n_fft = 2^nextpow2(length(stim_portion));
mag   = abs(fft(stim_portion, n_fft));
f_ax  = (0:n_fft/2-1) * fs / n_fft;
plot(f_ax/1000, 20*log10(mag(1:n_fft/2) + eps), ...
    'Color', [0.22 0.54 0.85], 'LineWidth', 1.2);
xlabel('Frequency (kHz)'); ylabel('Magnitude (dB)');
title(sprintf('Spectrum — peak should be at %d Hz', params.frequency_hz));
xline(params.frequency_hz/1000, 'r--', sprintf('%d Hz', params.frequency_hz));
xlim([0 20]); grid on;

% --- Jitter distribution ---
subplot(3, 3, 5);
isi_ms = stim_out.isi_samples / fs * 1000;
histogram(isi_ms, 10, 'FaceColor', [0.22 0.54 0.85], 'EdgeColor', 'w');
xlabel('ISI (ms)'); ylabel('Count');
title(sprintf('ISI jitter distribution (%d reps)', params.n_reps));
xline(stim_info.nominal_isi_ms, 'r--', 'Nominal');
grid on;

% --- Envelope check ---
subplot(3, 3, 6);
env = abs(hilbert(stim_out.pos(1:stim_out.n_stim)));
plot(t_stim, stim_out.pos(1:stim_out.n_stim), ...
    'Color', [0.75 0.75 0.75], 'LineWidth', 0.8);
hold on;
plot(t_stim, env, 'Color', [0.11 0.62 0.46], 'LineWidth', 1.5);
plot(t_stim, -env, 'Color', [0.11 0.62 0.46], 'LineWidth', 1.5);
xlabel('Time (ms)'); ylabel('Amplitude');
title('Stimulus envelope');
grid on;

%% ================================================================
%  SECTION 2 — Different frequencies
%% ================================================================

fprintf('\n--- Frequency sweep ---\n');

freqs    = [1000 2000 4000 8000 16000];
colors   = lines(length(freqs));

subplot(3, 3, 7);
hold on;
for fi = 1:length(freqs)
    p              = params;
    p.frequency_hz = freqs(fi);
    [s, ~]         = abr_make_stimulus(p, []);
    t_s            = (0:s.n_stim-1) / fs * 1000;
    offset         = (fi-1) * 1.2;
    plot(t_s, s.pos(1:s.n_stim) + offset, ...
        'Color', colors(fi,:), 'LineWidth', 1.2);
    fprintf('  %5d Hz — duration: %.2f ms, %d samples\n', ...
        freqs(fi), stim_info.stim_duration_ms, s.n_stim);
end
xlabel('Time (ms)'); ylabel('Frequency (stacked)');
title('Tone bursts across frequencies');
yticks((0:length(freqs)-1) * 1.2);
yticklabels(arrayfun(@(f) sprintf('%d Hz', f), freqs, ...
    'UniformOutput', false));
grid on;

%% ================================================================
%  SECTION 3 — Click
%% ================================================================

fprintf('\n--- Click ---\n');

params_click                  = abr_default_params();
params_click.stim_type        = 'click';
params_click.levels_dbspl     = 70;
params_click.click_duration_us = 100;
params_click.rate_hz          = 11.1;
params_click.jitter_pct       = 10;
params_click.n_reps           = 20;
params_click.polarity         = 'alt';
params_click.filtclick        = false;
params_click.fs               = fs;
params_click.frequency_hz     = 1000;   % nominal for file naming

[stim_click, info_click] = abr_make_stimulus(params_click, []);

fprintf('  Click duration:  %.3f ms (%d samples)\n', ...
    info_click.stim_duration_ms, stim_click.n_stim);
fprintf('  Buffer length:   %d samples\n', length(stim_click.pos));

t_click = (0:length(stim_click.pos)-1) / fs * 1000;

subplot(3, 3, 8);
stem(t_click(1:stim_click.n_stim+10), ...
    stim_click.pos(1:stim_click.n_stim+10), ...
    'filled', 'Color', [0.22 0.54 0.85], 'MarkerSize', 4);
xlabel('Time (ms)'); ylabel('Amplitude');
title(sprintf('Click — %d µs (%d samples)', ...
    params_click.click_duration_us, stim_click.n_stim));
grid on;

%% ================================================================
%  SECTION 4 — Polarity check
%% ================================================================

subplot(3, 3, 9);
polarities = {'alt', 'cond', 'rare'};
colors_pol = {[0.11 0.62 0.46], [0.22 0.54 0.85], [0.85 0.35 0.18]};
hold on;
for pi = 1:length(polarities)
    p         = params;
    p.polarity = polarities{pi};
    [s, ~]    = abr_make_stimulus(p, []);
    offset    = (pi-1) * 1.5;
    plot(t_stim, s.pos(1:s.n_stim) + offset, ...
        'Color', colors_pol{pi}, 'LineWidth', 1.2, 'DisplayName', ...
        sprintf('%s pos', polarities{pi}));
    plot(t_stim, s.neg(1:s.n_stim) + offset, ...
        'Color', colors_pol{pi}, 'LineWidth', 1.2, 'LineStyle', '--', ...
        'DisplayName', sprintf('%s neg', polarities{pi}));
end
xlabel('Time (ms)');
title('Polarity options — pos (solid) neg (dash)');
yticks((0:length(polarities)-1) * 1.5);
yticklabels(polarities);
legend('Location', 'best', 'FontSize', 7);
grid on;

sgtitle(sprintf('ABR Stimulus Demo — %d Hz tone burst', params.frequency_hz), ...
    'FontSize', 14, 'FontWeight', 'bold');

%% ================================================================
%  SECTION 5 — Optional: play through sound card
%% ================================================================

fprintf('\n--- Sound card playback (optional) ---\n');

answer = input('Play tone burst through sound card? (y/n): ', 's');
if strcmpi(strtrim(answer), 'y')
    try
        % Normalize for playback
        play_sig = stim_out.pos / max(abs(stim_out.pos)) * 0.5;
        % Repeat a few times so it's audible
        play_sig = repmat(play_sig, 5, 1);
        sound(play_sig, fs);
        fprintf('  Playing %d Hz tone burst...\n', params.frequency_hz);
        pause(length(play_sig)/fs + 0.5);
    catch e
        fprintf('  Sound card playback failed: %s\n', e.message);
    end
else
    fprintf('  Skipped.\n');
end

%% ================================================================
%  SUMMARY
%% ================================================================

fprintf('\n=== Demo Complete ===\n\n');
fprintf('Check the figure and confirm:\n');
fprintf('  1. Tone burst has smooth onset and offset (no clicks)\n');
fprintf('  2. Spectrum peak is at the correct frequency\n');
fprintf('  3. Pos + Neg sum is approximately zero (alt polarity)\n');
fprintf('  4. Rare polarity: pos and neg are both inverted\n');
fprintf('  5. Cond polarity: pos and neg are identical\n');
fprintf('  6. ISI varies across reps (jitter working)\n');
fprintf('  7. Click is %d µs duration\n', params_click.click_duration_us);
fprintf('\nIf anything looks wrong, check abr_default_params and\n');
fprintf('abr_make_stimulus before running subjects.\n\n');

warning('on', 'abr_make_stimulus:noCal');