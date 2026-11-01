function [stim, stim_info] = abr_make_stimulus(params, ref_peak)
% ABR_MAKE_STIMULUS  Generate the bare ABR stimulus waveform.
%
% Returns ONLY the stimulus: no onset delay, no ISI padding, no polarity
% buffers, no calibration. Peak-normalized to ref_peak.
%
% This is stage 1 of three (see calibration-design.md §5):
%
%   1. abr_make_stimulus  bare waveform, level-independent      <- here
%   2. cal_apply_stimulus calibration + attenuation (shared)
%   3. abr_make_buffers   onset delay, polarity, ISI jitter
%
% Inputs:
%   params   - ABR params struct from abr_default_params
%   ref_peak - digital peak to normalize to
%              (default config.calibration.ref_peak)
%
% Outputs:
%   stim      - [n x 1] stimulus waveform, peak = ref_peak
%   stim_info - diagnostic fields, saved with each run

if nargin < 2 || isempty(ref_peak)
    cfg      = config_load();
    ref_peak = cfg.calibration.ref_peak;
end

fs = params.fs;

%% --- Build the waveform ---

switch lower(params.stim_type)

    case 'toneburst'
        stim = make_toneburst(params, fs);

    case 'click'
        stim = make_click(params, fs);

    case 'chirp'
        stim = load_chirp(params, fs);

    otherwise
        error('abr_make_stimulus:unknownType', ...
            'Unknown stim_type: %s. Use toneburst, click, or chirp.', ...
            params.stim_type);
end

stim = stim(:);

%% --- Normalize to the reference peak ---
% ref_peak is deliberately below 1.0: tdt_play_record errors on
% |stim| > 1 mid-run, and downstream filtering overshoots.

peak = max(abs(stim));

if peak == 0
    error('abr_make_stimulus:zeroStimulus', ...
        'Generated stimulus is all zeros. Check stim_type and parameters.');
end

stim = stim * (ref_peak / peak);

%% --- Diagnostic info ---

stim_info.stim_type   = params.stim_type;
stim_info.frequency_hz = params.frequency_hz;
stim_info.n_samples   = numel(stim);
stim_info.duration_ms = numel(stim) / fs * 1000;
stim_info.ref_peak    = ref_peak;
stim_info.fs          = fs;

if strcmpi(params.stim_type, 'click')
    stim_info.click_duration_us = params.click_duration_us;
    stim_info.filtclick         = params.filtclick;
    if params.filtclick
        stim_info.click_filter  = params.click_filter;
    end
else
    stim_info.duration_cyc  = params.duration_cyc;
    stim_info.rise_fall_cyc = params.rise_fall_cyc;
    stim_info.window_type   = params.window_type;
end

% Level, attenuation, polarity and ISI are NOT recorded here. They belong
% to cal_out (stage 2) and buffer_info (stage 3), both of which abr_run
% saves alongside this struct.

end


%% =========================================================
%  LOCAL FUNCTIONS
%% =========================================================

function s = make_toneburst(params, fs)
    n_rise    = ceil((params.rise_fall_cyc/params.frequency_hz)*fs);
    n_plateau = ceil((params.duration_cyc/params.frequency_hz)*fs);
    n = n_plateau + 2*n_rise;
    t = (0:n-1)' / fs;
    s = -cos(2 * pi * params.frequency_hz * t);

    switch lower(params.window_type)
        case 'blackman'
            gate = blackman(2*n_rise);
        case 'hann'
            gate = hann(2 * n_rise);
        otherwise
            gate = blackman(2*n_rise);
    end

    envelope = [gate(1:n_rise); ones(n_plateau, 1); gate(n_rise+1:end)];

    s = s .* envelope;
end


function s = make_click(params, fs)
% Returns ONLY the click and its filter tails.
%
% FIXED — audit finding #3. This previously returned a buffer one full ISI
% long with the click at its MIDPOINT, roughly 45 ms in at 11.1 Hz.
% abr_run records rec_window_ms = [0 20], so the click fell outside the
% recorded epoch entirely and click ABR collected pre-stimulus baseline
% only. It also tripped abr_make_stimulus:stimTooLong on every click run,
% because the returned buffer was one ISI long by construction.
%
% Now the click sits at the start of a short waveform and
% abr_make_buffers applies params.stim_delay_ms to position it — the same
% way make_toneburst already worked.
%
% The bandpass is still implemented by zeroing FFT bins, which needs a
% working buffer long enough for reasonable frequency resolution. That
% buffer used to be floor(fs/rate_hz), which made the stimulus SPECTRUM
% depend on the presentation rate: changing rate_hz silently changed the
% filter's bin spacing. It is now a fixed length independent of rate_hz.
% At 48828.125 Hz the resolution goes from about 11 Hz to about 6 Hz, so
% the filtered click is marginally cleaner but otherwise the same stimulus.

n_click = max(1, round(params.click_duration_us / 1e6 * fs));

if ~params.filtclick
    s = ones(n_click, 1);
    return
end

%% --- Working buffer, rate-independent ---

n_work = 2^nextpow2(round(0.1 * fs));   % ~168 ms at 48828.125 Hz
centre = floor(n_work / 2);

buf       = zeros(n_work, 1);
click_ind = (0:n_click-1) - round(median(0:n_click-1));
buf(centre + click_ind) = 1;

%% --- Bandpass by zeroing bins (as in cABR, Bharadwaj Lab) ---

clickF = fft(buf);
f      = (0:(numel(clickF)-1))' * fs / numel(clickF);
lo     = params.click_filter(1);
hi     = params.click_filter(2);

clickF(f < lo        | (f > hi        & f <= fs/2)) = 0;
clickF(f > (fs - lo) | (f < (fs - hi) & f >= fs/2)) = 0;

buf = ifft(clickF, 'symmetric');

%% --- Gate, then crop to the gate's support ---
% The blackman gate is what bounds the stimulus in time. Cropping to it is
% what makes the returned waveform short instead of one ISI long.

n_win   = round(fs * 1.66e-3);
win     = blackman(n_win);
win_ind = (0:n_win-1) - round(median(0:n_win-1));

idx = centre + win_ind;

if idx(1) < 1 || idx(end) > n_work
    error('abr_make_stimulus:clickWindowOutOfRange', ...
        'Click gate (%d samples) does not fit the working buffer (%d).', ...
        n_win, n_work);
end

s = buf(idx) .* win;

end


function s = load_chirp(params, fs)
% Chirp does not work yet!!
    if isempty(params.chirp_file) || ~exist(params.chirp_file, 'file')
        error('abr_make_stimulus:missingChirpFile', ...
            'chirp_file not set or file not found: %s', params.chirp_file);
    end
    [s, fs_file] = audioread(params.chirp_file);
    s = s(:, 1);   % mono
    if fs_file ~= fs
        s = resample(s, round(fs), round(fs_file));
        warning('abr_make_stimulus:chirpResampled', ...
            'Chirp resampled from %g to %g Hz', fs_file, fs);
    end
end