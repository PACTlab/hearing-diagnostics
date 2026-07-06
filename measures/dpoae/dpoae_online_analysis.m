function [result, done] = dpoae_online_analysis(trials_so_far, stim_info, params)
% DPOAE_ONLINE_ANALYSIS  LSF-based DPOAE analysis for swept stimuli.
%
% Called after each trial with the full accumulated trials matrix so far.
%
% Inputs:
%   trials_so_far - [n_trials x n_samples] matrix of recorded epochs
%   stim_info     - struct from dpoae_make_stimulus with phase/time info
%   params        - DPOAE params struct
%
% Outputs:
%   result        - struct with analysis results for plotting:
%                     .freq_f2       [1 x npoints] F2 frequencies (Hz)
%                     .freq_f1       [1 x npoints] F1 frequencies (Hz)
%                     .freq_dp       [1 x npoints] DP frequencies (Hz)
%                     .dp_amp_dB     [1 x npoints] DP amplitude (dB SPL)
%                     .noise_amp_dB  [1 x npoints] noise floor (dB SPL)
%                     .f1_amp_dB     [1 x npoints] F1 amplitude (dB SPL)
%                     .f2_amp_dB     [1 x npoints] F2 amplitude (dB SPL)
%                     .SNR           [1 x npoints] SNR (dB)
%                     .n_trials      scalar
%   done          - logical, true if auto-stop criterion met (or auto-stop off)

%% --- Setup ---

n_trials   = size(trials_so_far, 1);
npoints    = params.npoints;
windowdur  = params.windowDuration_ms / 1000;   % convert to seconds
VtoSPL     = params.VtoSPL;
nearfreqs  = params.noisefreqs_multiplier;       % e.g. [0.90 0.88 0.86 0.84]

t          = stim_info.t;
phi1_inst  = stim_info.phi1_inst * 2 * pi;
phi2_inst  = stim_info.phi2_inst * 2 * pi;
phi_dp_inst = (2 .* stim_info.phi1_inst - stim_info.phi2_inst) * 2 * pi;

%% --- Frequency and time vectors ---

if params.sweepDirection == -1
    f_start = params.max_f2_hz;
    f_end   = params.min_f2_hz;
else
    f_start = params.min_f2_hz;
    f_end   = params.max_f2_hz;
end

if strcmp(params.scale, 'log')
    freq_f2 = 2 .^ linspace(log2(f_start), log2(f_end), npoints);
    t_freq  = log2(freq_f2 / f_start) / params.speed + stim_info.buffdur;
else
    freq_f2 = linspace(f_start, f_end, npoints);
    t_freq  = (freq_f2 - f_start) / params.speed + stim_info.buffdur;
end

freq_f1 = freq_f2 ./ params.ratio;
freq_dp = 2 .* freq_f1 - freq_f2;

%% --- Artifact rejection across trials ---

% coeffs_ar = zeros(n_trials, npoints, 2);
% 
% for trial_idx = 1:n_trials
%     epoch = trials_so_far(trial_idx, :);
%     for k = 1:npoints
%         win    = find(t > (t_freq(k) - windowdur/2) & ...
%                       t < (t_freq(k) + windowdur/2));
%         taper  = hanning(numel(win))';
%         model  = [cos(phi_dp_inst(win)) .* taper;
%                  -sin(phi_dp_inst(win)) .* taper];
%         resp   = epoch(win) .* taper;
%         coeffs_ar(trial_idx, k, :) = model' \ resp';
%     end
% end
% 
% oae_ar        = abs(complex(coeffs_ar(:,:,1), coeffs_ar(:,:,2)));
% median_oae_ar = median(oae_ar, 1);
% std_oae_ar    = std(oae_ar, 0, 1);

% NaN out artifact windows
trials_clean = trials_so_far;
% for trial_idx = 1:n_trials
%     for k = 1:npoints
%         if oae_ar(trial_idx, k) > median_oae_ar(1,k) + 3 * std_oae_ar(1,k)
%             win = find(t > (t_freq(k) - windowdur * 0.1) & ...
%                        t < (t_freq(k) + windowdur * 0.1));
%             trials_clean(trial_idx, win) = NaN;
%         end
%     end
% end

DPOAE = mean(trials_clean, 1, 'omitnan');

%% --- LSF analysis ---

n_nf           = numel(nearfreqs);
coeffs         = zeros(npoints, 6);
coeffs_noise   = zeros(npoints, n_nf * 2);

for k = 1:npoints
    win   = find(t > (t_freq(k) - windowdur/2) & ...
                 t < (t_freq(k) + windowdur/2));
    taper = hanning(numel(win))';
    resp  = DPOAE(win) .* taper;

    % DP model
    model_dp = [cos(phi_dp_inst(win)) .* taper;
               -sin(phi_dp_inst(win)) .* taper];
    coeffs(k, 1:2) = model_dp' \ resp';

    % F1 model
    model_f1 = [cos(phi1_inst(win)) .* taper;
               -sin(phi1_inst(win)) .* taper];
    coeffs(k, 3:4) = model_f1' \ resp';

    % F2 model
    model_f2 = [cos(phi2_inst(win)) .* taper;
               -sin(phi2_inst(win)) .* taper];
    coeffs(k, 5:6) = model_f2' \ resp';

    % Noise model — nearfreqs multipliers applied to DP phase
    noise_rows = zeros(n_nf * 2, numel(win));
    for nf = 1:n_nf
        row = (nf-1)*2 + 1;
        noise_rows(row,   :) =  cos(nearfreqs(nf) .* phi_dp_inst(win)) .* taper;
        noise_rows(row+1, :) = -sin(nearfreqs(nf) .* phi_dp_inst(win)) .* taper;
    end
    coeffs_noise(k, :) = noise_rows' \ resp';
end

%% --- Complex amplitudes ---

oae_complex   = complex(coeffs(:,1), coeffs(:,2));
f1_complex    = complex(coeffs(:,3), coeffs(:,4));
f2_complex    = complex(coeffs(:,5), coeffs(:,6));

% Average noise across nearfreq pairs
noise_pairs = zeros(npoints, n_nf);
for nf = 1:n_nf
    col = (nf-1)*2 + 1;
    noise_pairs(:, nf) = abs(complex(coeffs_noise(:,col), coeffs_noise(:,col+1)));
end
noise_complex = mean(noise_pairs, 2);

%% --- Convert to dB SPL ---

dp_amp_dB    = db(abs(oae_complex)  .* VtoSPL);
noise_amp_dB = db(noise_complex     .* VtoSPL);
f1_amp_dB    = db(abs(f1_complex)   .* VtoSPL);
f2_amp_dB    = db(abs(f2_complex)   .* VtoSPL);
SNR          = dp_amp_dB - noise_amp_dB;

%% --- Auto-stop criterion ---

done = false;

if params.auto_stop
    % Use SNR across 9 log-spaced center frequency bands (from Run_DPswept_Auto)
    edges       = 2 .^ linspace(log2(params.min_f2_hz), log2(params.max_f2_hz), 21);
    bandEdges   = edges(2:2:end-1);
    centerFreqs = edges(3:2:end-2);

    SNR_band = zeros(length(centerFreqs), 1);
    for z = 1:length(centerFreqs)
        band        = find(freq_f2 >= bandEdges(z) & freq_f2 < bandEdges(z+1));
        SNR_band(z) = mean(SNR(band));
    end

    if n_trials >= params.minTrials && ...
       all(SNR_band >= params.SNRcriterion)
        done = true;
    elseif n_trials >= params.maxTrials
        done = true;
    end
else
    % Fixed trial count — done when we hit params.trials
    if n_trials >= params.trials
        done = true;
    end
end

%% --- Package output ---

result.freq_f2      = freq_f2;
result.freq_f1      = freq_f1;
result.freq_dp      = freq_dp;
result.dp_amp_dB    = dp_amp_dB(:)';
result.noise_amp_dB = noise_amp_dB(:)';
result.f1_amp_dB    = f1_amp_dB(:)';
result.f2_amp_dB    = f2_amp_dB(:)';
result.SNR          = SNR(:)';
result.n_trials     = n_trials;

end