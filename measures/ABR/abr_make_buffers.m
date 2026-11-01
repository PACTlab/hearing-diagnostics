function [buffers, buffer_info] = abr_make_buffers(stim, params)
% ABR_MAKE_BUFFERS  Assemble play buffers from a calibrated stimulus.
%
% Stage 3 of three (see calibration-design.md §5). Takes the CALIBRATED
% waveform and adds everything that is about presentation rather than
% about the stimulus itself: onset delay, polarity, ISI jitter, padding.
%
% Split out of abr_make_stimulus so that calibration (stage 2) operates on
% the unpadded waveform. An in-ear correction filter has group delay and a
% tail; filtering an already-padded buffer shifts onset relative to
% rec_window_ms and smears the tail past the stimulus extent.
%
% Polarity is applied here, after calibration.
%
% Inputs:
%   stim   - [n x 1] calibrated stimulus from cal_apply_stimulus
%   params - ABR params. Uses fs, stim_delay_ms, rate_hz, jitter_pct,
%            n_reps, polarity.
%
% Outputs:
%   buffers - struct:
%     .pos            [max_isi x 1]  positive polarity buffer
%     .neg            [max_isi x 1]  negative polarity buffer
%     .isi_samples    [1 x n_reps]   samples to play per rep; pass
%                                    isi_samples(rep) to TDT as nsamps so
%                                    the ISI varies while onset stays put
%     .n_stim         samples from buffer start to end of stimulus
%     .onset_samples  samples of silence before the stimulus
%     .fs
%
%   buffer_info - diagnostics saved with the run

stim = stim(:);
fs   = params.fs;

%% --- Onset delay ---
% Leading silence so the stimulus does not start at sample 1. The recorded
% epoch starts at rec_window_ms(1), so this is what puts a pre-stimulus
% baseline in the saved data.

onset_samples = ceil(params.stim_delay_ms / 1000 * fs);

padded = [zeros(onset_samples, 1); stim];
n_stim = numel(padded);

%% --- ISI with jitter ---

nominal_isi_samples = round(fs / params.rate_hz);

if n_stim > nominal_isi_samples
    warning('abr_make_buffers:stimTooLong', ...
        ['Stimulus plus onset delay (%d samples, %.2f ms) is longer than ' ...
         'the ISI (%d samples, %.2f ms). Increase rate_hz or shorten the ' ...
         'stimulus.'], ...
        n_stim, n_stim / fs * 1000, ...
        nominal_isi_samples, nominal_isi_samples / fs * 1000);
end

n_reps      = params.n_reps;
isi_samples = zeros(1, n_reps);

for rep = 1:n_reps
    jitter_factor    = 1 + (rand - 0.5) * 2 * params.jitter_pct / 100;
    isi_samples(rep) = round(nominal_isi_samples * jitter_factor);
end

% Every rep plays isi_samples(rep) samples from the front of the buffer, so
% the buffer has to be at least as long as the longest of them — and at
% least as long as the stimulus.
max_isi = max([isi_samples, n_stim]);

%% --- Polarity buffers ---
% The two buffers encode the polarity MODE, so abr_run can alternate
% between them unconditionally and still get 'cond' and 'rare' right.

pos = zeros(max_isi, 1);
neg = zeros(max_isi, 1);

switch lower(params.polarity)
    case 'alt'
        pos(1:n_stim) =  padded;
        neg(1:n_stim) = -padded;
    case 'cond'
        pos(1:n_stim) =  padded;
        neg(1:n_stim) =  padded;    % both condensation
    case 'rare'
        pos(1:n_stim) = -padded;
        neg(1:n_stim) = -padded;    % both rarefaction
    otherwise
        error('abr_make_buffers:unknownPolarity', ...
            'Unknown polarity: %s. Use alt, cond, or rare.', ...
            params.polarity);
end

%% --- Guard against clipping ---
% tdt_play_record errors on |stim| > 1 mid-run, after part of a level has
% already been collected. Catch it here instead.

peak = max(max(abs(pos)), max(abs(neg)));

if peak > 1
    error('abr_make_buffers:bufferClips', ...
        ['Play buffer peak is %.4f, above the 1.0 limit enforced by ' ...
         'tdt_play_record. Check config.calibration.ref_peak and any ' ...
         'filtering applied in cal_apply_stimulus.'], peak);
end

%% --- Package ---

buffers.pos           = pos;
buffers.neg           = neg;
buffers.isi_samples   = isi_samples;
buffers.n_stim        = n_stim;
buffers.onset_samples = onset_samples;
buffers.fs            = fs;

buffer_info.polarity           = lower(params.polarity);
buffer_info.n_reps             = n_reps;
buffer_info.onset_samples      = onset_samples;
buffer_info.onset_ms           = onset_samples / fs * 1000;
buffer_info.n_stim             = n_stim;
buffer_info.stim_extent_ms     = n_stim / fs * 1000;
buffer_info.nominal_isi_ms     = nominal_isi_samples / fs * 1000;
buffer_info.min_isi_ms         = min(isi_samples) / fs * 1000;
buffer_info.max_isi_ms         = max(isi_samples) / fs * 1000;
buffer_info.jitter_pct         = params.jitter_pct;
buffer_info.achieved_jitter_pct = ...
    (max(isi_samples) - min(isi_samples)) / nominal_isi_samples * 100;
buffer_info.buffer_peak        = peak;

end