function [b, filter_info] = ear_cal_compute_filter(freq_hz, db_spl_measured, params)
% EAR_CAL_COMPUTE_FILTER  Compute FIR correction filter from measured
% in-ear frequency response.
%
% Inputs:
%   freq_hz         - [n x 1] frequencies in Hz
%   db_spl_measured - [n x 1] measured dB SPL at each frequency
%   params          - ear cal params struct
%
% Outputs:
%   b               - [filter_order+1 x 1] FIR filter coefficients
%   filter_info     - diagnostic struct

fs          = params.fs;
Nfilter     = params.filter_order;
dBSPL_ideal = params.target_dbspl;
max_gain_db = params.max_gain_db;

%% --- Compute gain needed at each frequency ---

filter_gain = dBSPL_ideal - db_spl_measured;

%% --- Limit maximum gain ---

n_clipped   = sum(filter_gain > max_gain_db);
filter_gain = min(filter_gain, max_gain_db);

if n_clipped > 0
    warning('ear_cal_compute_filter:gainClipped', ...
        '%d frequencies clipped to max gain of %.0f dB.', ...
        n_clipped, max_gain_db);
end

%% --- Build normalized frequency vector for fir2 ---
% fir2 requires frequencies normalized 0-1 where 1 = fs/2
% Must start at 0 and end at 1, strictly increasing

freq_norm   = freq_hz(:) / (fs/2);

% Add endpoints if not present
if freq_norm(1) > 0
    freq_norm   = [0;        freq_norm];
    filter_gain = [filter_gain(1); filter_gain];
end
if freq_norm(end) < 1
    freq_norm   = [freq_norm;   1];
    filter_gain = [filter_gain; filter_gain(end)];
end

% Ensure strictly increasing — remove any duplicates
[freq_norm, idx] = unique(freq_norm);
filter_gain      = filter_gain(idx);

%% --- Convert gain from dB to linear magnitude ---

gain_linear = db2mag(filter_gain);

%% --- Design FIR filter ---

b = fir2(Nfilter, freq_norm, gain_linear);
b = b(:);   % column vector

%% --- Compute group delay for diagnostics ---

[gd, gd_w] = grpdelay(b, 1, 2056, fs);
mean_gd_ms  = mean(gd(gd_w < 10e3)) / fs * 1000;

%% --- Package diagnostic info ---

filter_info.filter_order      = Nfilter;
filter_info.target_dbspl      = dBSPL_ideal;
filter_info.max_gain_db       = max_gain_db;
filter_info.n_freqs_clipped   = n_clipped;
filter_info.mean_group_delay_ms = mean_gd_ms;
filter_info.freq_hz           = freq_hz;
filter_info.db_spl_measured   = db_spl_measured;
filter_info.filter_gain_db    = filter_gain;

end