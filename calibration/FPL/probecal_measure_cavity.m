function res = probecal_measure_cavity(cfg, params, tdt, cav_idx)
% PROBECAL_MEASURE_CAVITY  Measure one calibrator cavity with both drivers.
%
% Called once per cavity button press. Plays a click through each driver in
% turn (the other driver silent), rejects noisy reps, averages, converts to
% a pressure response in Pa per volt of drive, and runs quick checks so a
% bad insertion or wrong tube shows up before the next cavity.
%
% Inputs:
%   cfg     - struct from config_load (schema 2)
%   params  - struct from probecal_default_params
%   tdt     - struct from tdt_init, or [] for stub mode
%   cav_idx - which cavity, 1..numel(params.cav_lengths_mm)

%
% Output res (one cavity):
%   .cavity, .nominal_length_mm
%   .freq          [nf x 1] Hz
%   .H             [nf x ndrv] pressure response, Pa per volt of drive
%   .H_noise       [nf x ndrv] noise floor of that average, same units
%   .vavg          [N x ndrv]  averaged mic voltage at the RZ6 input
%   .length_mm     [1 x ndrv]  estimated cavity length
%   .length_err_pct, .snr_db, .n_good, .n_total, .peak_in_v  [1 x ndrv]
%   .timing        {1 x ndrv}  from tdt_play_record
%   .conditions    everything the response depends on
%   .flags         cellstr of problems found; empty if none
%   .ok            true if no flags
%   .stub_truth    (stub mode only) the Zs and Ps used to make the data
%
% Units: H is Pa per volt at the DAC output. The volts include
% cfg.hardware.mat2volts, which cal_apply_stimulus must use the same way.

%% --- Validate ---

stub = isempty(tdt);
if stub && ~params.stub_mode
    error('probecal_measure_cavity:noHardware', ...
        ['No TDT connection and stub_mode is off. Refusing to produce ' ...
         'a calibration without hardware.']);
end

n_cav = numel(params.cav_lengths_mm);
if ~isscalar(cav_idx) || cav_idx < 1 || cav_idx > n_cav || cav_idx ~= round(cav_idx)
    error('probecal_measure_cavity:badCavity', ...
        'cav_idx must be an integer from 1 to %d.', n_cav);
end

requireField(cfg, 'calibration.ref_peak');
requireField(cfg, 'hardware.mat2volts');
requireField(cfg, 'hardware.fs_record_hz');
requireField(cfg, 'equipment.probe.id');
requireField(cfg, 'equipment.probe.mic_sens_v_per_pa');
requireField(cfg, 'equipment.probe.amp_fixed_gain_db');

%% --- Setup ---

if stub
    fs       = cfg.hardware.fs_record_hz;  % nominal; no hardware to ask
    ad_delay = NaN;
else
    fs       = tdt.fs;                     % measured by the hardware
    ad_delay = tdt.ADdelay;
end

N         = params.BufferSize;
freq      = (0:N/2)' * fs / N;
drivers   = params.drivers;
n_drv     = numel(drivers);
ref_peak  = cfg.calibration.ref_peak;
mat2volts = cfg.hardware.mat2volts;

%% --- make click stim --- 
y = zeros(1, params.BufferSize);
y(params.initbuff + (1:params.nsampsclick)) = ref_peak;
stim = y(:); % Just in case

% get the spectrum in volts for the stimulus
V_src = rfft(stim)*mat2volts*db2mag(-1*params.atten_db); 

% freq band to check for error in
band = freq >= params.f_err_khz(1)*1000 & freq <= params.f_err_khz(2)*1000;

%% --- Preallocate ---

nf  = numel(freq);
res.cavity            = cav_idx;
res.nominal_length_mm = params.cav_lengths_mm(cav_idx);
res.freq              = freq;
res.H                 = zeros(nf, n_drv);
res.H_noise           = zeros(nf, n_drv);
res.vavg              = zeros(N, n_drv);
res.length_mm         = NaN(1, n_drv);
res.length_err_pct    = NaN(1, n_drv);
res.snr_db            = NaN(1, n_drv);
res.n_good            = zeros(1, n_drv);
res.n_total           = zeros(1, n_drv);
res.peak_in_v         = zeros(1, n_drv);
res.timing            = cell(1, n_drv);
res.flags             = {};
if stub
    res.stub_truth.Zs = zeros(nf, n_drv);
    res.stub_truth.Ps = zeros(nf, n_drv);
end

%% --- Measure each driver ---

for d = 1:n_drv
    drv = drivers(d);
    fprintf('Cavity %d (%.2f cm), driver %d\n', cav_idx, res.nominal_length_mm, drv);

    ch    = {zeros(N, 1), zeros(N, 1)};
    ch{drv} = stim;
    atten = [params.silent_atten_db, params.silent_atten_db];
    atten(drv) = params.atten_db;

    if stub
        [data, timing, Zs_true, Ps_true] = stubRecord(cfg, params, ...
            cav_idx, drv, freq, V_src);
        res.stub_truth.Zs(:, d) = Zs_true;
        res.stub_truth.Ps(:, d) = Ps_true;
    else
        [data, timing] = tdt_play_record(tdt, ch{1}, ch{2}, ...
            atten(1), atten(2), params.n_averages, params.n_throwaway, ...
            params.delay_comp);
    end
    % data: [n_averages x N], volts at the RZ6 input

    res.timing{d}    = timing;
    res.peak_in_v(d) = max(abs(data(:)));

    % --- Filter, demean, reject ---
    if params.doFilt
        % High pass at 100 Hz using IIR filter
        [b, a] = butter(4, params.hp_cutoff_hz / (fs/2), 'high');
        data = filtfilt(b, a, data')';
    end
    data = demean(data, 2);

    energy = sum(data.^2, 2);
    thresh = median(energy) + params.reject_k * mad(energy, 0);  % 0 = mean abs dev, as before
    good   = data(energy < thresh, :);

    ng = size(good, 1);
    res.n_good(d)  = ng;
    res.n_total(d) = size(data, 1);

    if ng < 2
        res.flags{end+1} = sprintf('Driver %d: only %d reps survived rejection.', drv, ng);
        continue
    end

    % --- Average, and a noise floor for the same number of reps ---
    % Alternating-sign averaging cancels the response and leaves noise at
    % the level of the average itself.
    vavg   = mean(good, 1)';
    ne     = 2 * floor(ng/2);
    signs  = repmat([1; -1], ne/2, 1);
    vnoise = mean(good(1:ne, :) .* signs, 1)';

    res.vavg(:, d) = vavg;

    % --- Pressure response, Pa per volt of drive ---
    res.H(:, d)       = rfft(mic_volts_to_pa(vavg,   cfg, params.mic_gain_dial)) ./ V_src;
    res.H_noise(:, d) = rfft(mic_volts_to_pa(vnoise, cfg, params.mic_gain_dial)) ./ V_src;

    % --- Quick checks ---
    res.snr_db(d) = median(20*log10(abs(res.H(band, d)) ./ abs(res.H_noise(band, d))));

    % cavity_length takes log|H|, so a zero bin (DC after demean) would
    % poison the whole estimate. Patch a copy only.
    Hl = res.H(:, d);
    Hl(1) = Hl(2);
    Hl(Hl == 0) = eps;
    res.length_mm(d) = cavity_length(Hl, params.CavTemp_C, fs/1000, ...
        params.len_search_cm(1), params.len_search_cm(2));
    res.length_err_pct(d) = 100 * (res.length_mm(d) - (res.nominal_length_mm/10)) ...
        / (res.nominal_length_mm/10);

    if abs(res.length_err_pct(d)) > params.length_tol_pct
        res.flags{end+1} = sprintf( ...
            'Driver %d: length %.2f cm vs nominal %.2f cm (%+.0f%%). Wrong tube or poor seal?', ...
            drv, res.length_mm(d), res.nominal_length_mm, res.length_err_pct(d));
    end
    if res.snr_db(d) < params.min_snr_db
        res.flags{end+1} = sprintf( ...
            'Driver %d: median SNR %.1f dB in %g-%g kHz, below %g dB.', ...
            drv, res.snr_db(d), params.f_err_khz(1), params.f_err_khz(2), params.min_snr_db);
    end
    if any(~isfinite(res.H(:, d)))
        res.flags{end+1} = sprintf('Driver %d: response contains NaN or Inf.', drv);
    end
end

res.ok = isempty(res.flags);

%% --- Conditions this response depends on ---

[~, gain_db] = mic_volts_to_pa(0, cfg, params.mic_gain_dial);

c.stub              = stub;
c.fs                = fs;
c.buffer_size       = N;
c.drivers           = drivers;
c.atten_db          = params.atten_db;
c.silent_atten_db   = params.silent_atten_db;
c.ref_peak          = ref_peak;
c.mat2volts         = mat2volts;
c.click_onset_samp  = params.initbuff + 1;
c.click_len_samp    = params.nsampsclick;
c.n_averages        = params.n_averages;
c.n_throwaway       = params.n_throwaway;
c.delay_comp        = params.delay_comp;
c.ad_delay_samples  = ad_delay;
c.do_filt           = params.doFilt;
c.hp_cutoff_hz      = params.hp_cutoff_hz;
c.reject_k          = params.reject_k;
c.probe             = cfg.equipment.probe;   % whole block, including id
c.mic_gain_dial     = params.mic_gain_dial;
c.mic_total_gain_db = gain_db;
c.polarity          = params.electricAcousticPolarity;       % recorded, not applied
c.temp_c            = params.CavTemp_C;
c.cav_diam_cm       = params.CavDiam_cm;
c.measured_at       = datetime('now');

res.conditions = c;

end

%% ================================================================
%  LOCAL FUNCTIONS
%% ================================================================

function [data, timing, Zs, Ps] = stubRecord(cfg, params, cav_idx, drv, freq, V_src)
% Synthesize a recording from a KNOWN Thevenin source driving an ideal
% cavity, then run it backwards through the mic conversion so the real
% processing path is exercised. The fit should recover Zs and Ps.
% No AD delay is simulated, so the truth needs no phase correction.

L = params.cav_lengths_mm(cav_idx)/10; % convert to cm
[Zs, Ps] = stubSource(freq, params.CavTemp_C, params.CavDiam_cm, drv);

zc = cavimp(freq, [L, 1], 1, params.CavDiam_cm, params.CavTemp_C);
Hp = Ps .* zc ./ (Zs + zc);   % Pa per volt
Hp(1) = 0;                    % DC: closed cavity -> Inf/Inf
Hp(~isfinite(Hp)) = 0;

p_true  = irfft(Hp .* V_src);                       % Pa, [N x 1]
pa_per_v = mic_volts_to_pa(1, cfg, params.mic_gain_dial);   % Pa per mic volt
v_true  = p_true / pa_per_v;                        % volts at RZ6 input

% Fixed seed per cavity and driver, without touching the global RNG.
rs = RandStream('mt19937ar', 'Seed', 1000*cav_idx + drv);
n  = params.n_averages;
N  = numel(v_true);

data = repmat(v_true', n, 1) + params.stub_noise_v * randn(rs, n, N);

% A few artifact reps, so rejection has something to reject.
n_art = max(1, round(0.02 * n));
idx   = randperm(rs, n, n_art);
data(idx, :) = data(idx, :) + 20 * params.stub_noise_v * randn(rs, n_art, N);

timing = struct('write_s', 0, 'settle_s', 0, 'play_s', 0, 'read_s', 0, ...
                'total_s', 0, 'stub', true);
end

function [Zs, Ps] = stubSource(freq, temp_c, diam_cm, drv)
% Made-up but smooth source, different for each driver so the two are
% distinguishable in plots. The values only need to be plausible enough for
% the fit to be a fair test.
z0 = z_tube(temp_c, diam_cm);
g  = [1.0, 0.7];      % relative source strength
fc = [8000, 6000];    % source roll-off, Hz

Ps = 2 * g(drv) * exp(-1i*2*pi*freq*0.1e-3) ./ (1 + 1i*freq/fc(drv));  % Pa/V
Zs = z0 * (3 + 1i*freq/1500);
end

function requireField(s, path)
parts = strsplit(path, '.');
v = s;
for k = 1:numel(parts)
    if ~(isstruct(v) && isfield(v, parts{k}))
        error('probecal_measure_cavity:missingField', ...
            'Required field "%s" is missing. Check config_edit or the caller.', path);
    end
    v = v.(parts{k});
end
end