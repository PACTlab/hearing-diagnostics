function [stim_out, stim_info] = efr_make_stimulus(params, cal)
% EFR_MAKE_STIMULUS  Generate a modulated stimulus or read in a wav file.
%
% Builds positive and negative polarity buffers with the stimulus at
% sample 1 + params.stim_delay, zero-padded to the maximum ISI length. Jitter is encoded
% in isi_samples — pass stim_out.isi_samples(rep) to TDT as nsamps
% each rep so the inter-stimulus interval varies while stimulus onset
% stays at sample 1.
%
% Inputs:
%   params    - EFR params struct from efr_default_params
%   cal       - calibration struct (from cal_load), used to set level
%
% Outputs:
%   stim_out  - struct:
%     .pos          [max_isi_samples x 1]  positive polarity buffer
%     .neg          [max_isi_samples x 1]  negative polarity buffer
%     .isi_samples  [1 x n_reps]           samples to play per rep
%     .atten_db     scalar                 attenuation applied
%     .fs           scalar
%     .n_stim       scalar                 stimulus length in samples
%
%   stim_info - struct with diagnostic fields, saved with each run

% TODO: ADD RAMPING TO SAM/RAM TONES

%% --- Input checks ---

if ~isscalar(params.levels_dbspl)
    error('efr_make_stimulus:multiplelevels', ...
        'levels_dbspl must be scalar. Call once per level.');
end

fs = params.fs;

%% --- Build the base waveform (before level scaling) ---

switch lower(params.stim_type)

    case 'wav'
        base_stim  = load_wav(params, fs);                                 

    case 'sam'
        base_stim  = make_sam_tone(params, fs);                                %%%%%

    case 'ram'
        base_stim  = make_ram_tone(params, fs);

    otherwise
        error('efr_make_stimulus:unknownType', ...
            'Unknown stim_type: %s. Use toneburst, click, or chirp.', ...
            params.stim_type);
end

% add a standard delay so stim doesn't start at sample 1
delay_samps = ceil(params.stim_delay_ms/1000 .* fs); 
base_stim = [zeros(delay_samps,1); base_stim]; 
n_stim = numel(base_stim); 

%% --- Apply calibration / level scaling ---

if ~isempty(cal)
    [base_stim, atten_db] = cal_apply_transducer(base_stim, cal, ...
        params.frequency_hz, params.levels_dbspl);
else
    atten_db = NaN;
    warning('efr_make_stimulus:noCal', ...
        'No calibration provided. Stimulus amplitude is uncalibrated.');
end
%% --- Compute ISI samples with jitter ---

nominal_isi_samples = n_stim + (params.isi_ms /1000) * fs; % samples for each epoch if no jitter

if nominal_isi_samples > 1e6
    warning('efr_make_stimulus:stimMayBeTooLong', ...
        sprintf('Stimulus (%d samples) is longer than 1e6 samples', ...
         nominal_isi_samples));
end

n_reps      = params.n_reps;
isi_samples = zeros(1, n_reps);

for rep = 1:n_reps
    jitter_factor    = 1 + (rand - 0.5) * 2 * params.jitter_pct / 100;
    isi_samples(rep) = round(nominal_isi_samples * jitter_factor);
end

max_isi = max(isi_samples);

%% --- Build polarity buffers ---
% Stimulus at sample 1, zero-padded to max ISI length.
% TDT plays only isi_samples(rep) samples per rep via nsamps tag —
% that varying length is where the jitter lives.

pos = zeros(max_isi, 1);
neg = zeros(max_isi, 1);

pos(1:n_stim) = base_stim;

switch lower(params.polarity)
    case 'alt'
        neg(1:n_stim) = -base_stim;
    case 'cond'
        neg(1:n_stim) = base_stim;    % both same polarity
    case 'rare'
        neg(1:n_stim) = -base_stim;   % both inverted
        pos(1:n_stim) = -base_stim;
    otherwise
        error('efr_make_stimulus:unknownPolarity', ...
            'Unknown polarity: %s. Use alt, cond, or rare.', ...
            params.polarity);
end

%% --- Package output ---

stim_out.pos         = pos;
stim_out.neg         = neg;
stim_out.isi_samples = isi_samples;
stim_out.atten_db    = atten_db;
stim_out.fs          = fs;
stim_out.n_stim      = n_stim;

%% --- Diagnostic info ---

stim_info.stim_type        = params.stim_type;
% stim_info.frequency_hz     = params.frequency_hz;
% stim_info.level_dbspl      = params.levels_dbspl;
% stim_info.polarity         = params.polarity;
% stim_info.n_reps           = n_reps;
% stim_info.nominal_isi_ms   = nominal_isi_samples / fs * 1000;
% stim_info.jitter_pct       = params.jitter_pct;
% stim_info.stim_duration_ms = n_stim / fs * 1000;
% stim_info.max_isi_ms       = max_isi / fs * 1000;
stim_info.atten_db         = atten_db;
stim_info.fs               = fs;
end


%% =========================================================
%  LOCAL FUNCTIONS
%% =========================================================

function s = load_wav(params, fs)
    % if loading a wav file, assume it's positive polarity and assume that
    % all ramping etc is already in place. 

    % TODO: Currently only reading wav files from the folder in efr, but
    % may want to have option for project specific files to be called. 

    if isempty(params.wav_file) || ~exist(['./wav/' params.wav_file], 'file')
        error('efr_make_stimulus:missingWavFile', ...
            'wav_file not set or file not found: %s', params.wav_file);
    end

    [s, fs_file] = audioread(['./wav/' params.wav_file]);
    s = s(:, 1);   % mono
    if fs_file ~= fs
        s = resample(s, round(fs), round(fs_file));
        warning('efr_make_stimulus:wavResampled', ...
            'wav resampled from %g to %g Hz', fs_file, fs);
    end
end


function s = make_sam_tone(params, fs)
    t = (0:1/fs:params.duration_s)';
    tone = sin(2*pi*params.carrier_frequency_hz*t);
    env = cos(2*pi*params.mod_frequency_hz*t);
    M = (1-params.mod_depth)/(1+params.mod_depth);
    
    % Raised cosine envelope oscillates between M (floor) and 1 (peak)
    envelope = M + (1 - M) .* (0.5 - 0.5 * env);
    
    % Apply envelope to carrier
    s = envelope .* tone;

    % TODO: NEEDS RAMPING
end


function s = make_ram_tone(params, fs)
    t = (0:1/fs:params.duration_s)';
    tone = sin(2*pi*params.carrier_frequency_hz*t);
    env = square(2*pi*params.mod_frequency_hz*t, params.duty_cycle_pct);
    M = (1-params.mod_depth)/(1+params.mod_depth);
    
    % Raised cosine envelope oscillates between M (floor) and 1 (peak)
    envelope = M + (1 - M) .* (0.5 - 0.5 * env);
    
    % Apply envelope to carrier
    s = envelope .* tone;
    
    % TODO: NEEDS RAMPING

end