function [stim_out, stim_info] = abr_make_stimulus(params, cal)
% ABR_MAKE_STIMULUS  Generate ABR stimulus waveform(s).
%
% Inputs:
%   params    - ABR params struct from abr_default_params
%   cal       - calibration struct (from cal_load), used to set level
%
% Outputs:
%   stim_out  - struct with fields:
%                 .pos  [n_samples x 1]  positive polarity waveform (normalized)
%                 .neg  [n_samples x 1]  negative polarity (= -pos for tonebursts/clicks)
%                 .fs   scalar           sampling rate
%                 .duration_samples      length of one epoch buffer (stimulus + silence)
%   stim_info - struct with diagnostic fields (actual level, attenuation set, etc.)

fs = params.fs;

%% --- Build the base waveform (before level scaling) ---

switch lower(params.stim_type)

    case 'toneburst'
        stim_out.pos = make_toneburst(params, fs);

    case 'click'
        stim_out.pos = make_click(params, fs);

    case 'chirp'
        stim_out.pos = load_chirp(params, fs);

    otherwise
        error('abr_make_stimulus:unknownType', ...
            'Unknown stim_type: %s. Use toneburst, click, or chirp.', ...
            params.stim_type);
end

%% --- Apply polarity ---

switch lower(params.polarity)
    case 'alt'
        stim_out.neg = -stim_out.pos;
    case 'cond'
        stim_out.neg = stim_out.pos;   % both same polarity
    case 'rare'
        stim_out.pos = -stim_out.pos;  % flip both
        stim_out.neg =  stim_out.pos;
    otherwise
        error('abr_make_stimulus:unknownPolarity', ...
            'Unknown polarity: %s. Use alternating, condensation, or rarefaction.', ...
            params.polarity);
end

%% --- Apply calibration / level scaling ---

[stim_out.pos, atten_db] = cal_apply(cal, stim_out.pos, ...
    params.frequency_hz, params.levels_dbspl(1), params.stim_type);
stim_out.neg = stim_out.neg * 10^(-atten_db/20);  % same attenuation

%% --- Build full epoch buffer (stimulus + silence) ---

isi_samples     = round(fs / params.rate_hz);
stim_out.duration_samples = isi_samples;
stim_out.fs               = fs;

% Zero-pad stimulus to fill the epoch buffer
n_stim = length(stim_out.pos);
if n_stim > isi_samples
    warning('abr_make_stimulus:stimTooLong', ...
        'Stimulus is longer than ISI. Increase rate or shorten stimulus.');
end
pad = zeros(isi_samples - n_stim, 1);
stim_out.pos = [stim_out.pos; pad];
stim_out.neg = [stim_out.neg; pad];

%% --- Diagnostic info ---

stim_info.atten_db        = atten_db;
stim_info.n_samples_stim  = n_stim;
stim_info.n_samples_epoch = isi_samples;
stim_info.stim_duration_ms = n_stim / fs * 1000;
stim_info.epoch_duration_ms = isi_samples / fs * 1000;

end


%% =========================================================
%  LOCAL FUNCTIONS
%% =========================================================

function s = make_toneburst(params, fs)
    n      = round(params.duration_ms / 1000 * fs);
    t      = (0:n-1)' / fs;
    s      = sin(2 * pi * params.frequency_hz * t);

    % Hanning gate
    n_ramp = round(params.rise_fall_ms / 1000 * fs);
    if 2 * n_ramp > n
        error('abr_make_stimulus:rampTooLong', ...
            'Rise/fall time is longer than half the stimulus duration.');
    end
    ramp        = hann(2 * n_ramp);
    gate        = ones(n, 1);
    gate(1:n_ramp)         = ramp(1:n_ramp);
    gate(end-n_ramp+1:end) = ramp(n_ramp+1:end);
    s = s .* gate;
end


function s = make_click(params, fs)
    n_click = max(1, round(params.click_duration_us / 1e6 * fs));
    s       = ones(n_click, 1);   % rarefaction = -ones, handled by polarity
end


function s = load_chirp(params, fs)
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