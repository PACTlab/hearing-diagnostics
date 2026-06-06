function [stim_scaled, atten_db, cal_info] = cal_apply_transducer(stim, transducer_cal, frequency_hz, level_dbspl)
% CAL_APPLY_TRANSDUCER  Scale stimulus to achieve desired dB SPL output.
%
% Uses a frequency-dependent sensitivity curve measured in an ear simulator
% or coupler to determine the correct attenuation for a given frequency
% and desired output level.
%
% Inputs:
%   stim            - [n x 1] stimulus waveform, normalized to peak = 1
%   transducer_cal  - calibration struct from cal_load_transducer()
%   frequency_hz    - stimulus frequency in Hz (scalar)
%                     for clicks, use the broadband reference frequency
%                     stored in transducer_cal.click_ref_hz
%   level_dbspl     - desired output level in dB SPL (scalar)
%
% Outputs:
%   stim_scaled     - [n x 1] scaled stimulus waveform
%   atten_db        - attenuation applied in dB (for logging)
%   cal_info        - struct with calibration details for saving with run

%% --- Input checks ---

if isempty(transducer_cal)
    error('cal_apply_transducer:noCal', ...
        'No transducer calibration loaded. Load one via cal_load_transducer().');
end

if abs(max(abs(stim))) - 1 > 0.01
    warning('cal_apply_transducer:stimNotNormalized', ...
        'Stimulus peak is not 1. Normalize before applying calibration.');
end

%% --- Get sensitivity at this frequency ---
% Sensitivity curve: dB SPL produced per volt RMS at each frequency
% Interpolate at the requested frequency

if frequency_hz < min(transducer_cal.frequency_hz) || ...
   frequency_hz > max(transducer_cal.frequency_hz)
    warning('cal_apply_transducer:freqOutOfRange', ...
        'Frequency %d Hz is outside calibration range [%d %d Hz]. ' ...
        'Extrapolating — results may be inaccurate.', ...
        frequency_hz, ...
        min(transducer_cal.frequency_hz), ...
        max(transducer_cal.frequency_hz));
end

sensitivity_dbspl = interp1(transducer_cal.frequency_hz, ...
                            transducer_cal.sensitivity_dbspl, ...
                            frequency_hz, ...
                            'linear', 'extrap');

%% --- Compute attenuation ---
% sensitivity_dbspl: dB SPL output when stimulus RMS = 1V (0 dB attenuation)
% We want level_dbspl, so:
%   atten_db = sensitivity_dbspl - level_dbspl

atten_db = sensitivity_dbspl - level_dbspl;

% Convert attenuation to linear scale factor
% atten_db > 0 means we need to reduce the signal
scale_factor = 10^(-atten_db / 20);

%% --- Apply scaling ---

stim_scaled = stim * scale_factor;

%% --- Clip check ---

if max(abs(stim_scaled)) > transducer_cal.max_voltage
    warning('cal_apply_transducer:clipping', ...
        ['Stimulus amplitude %.3fV exceeds transducer max %.3fV at %d dB SPL. ' ...
        'Reduce level or check calibration.'], ...
        max(abs(stim_scaled)), transducer_cal.max_voltage, level_dbspl);
end

%% --- Cal info for saving with run ---

cal_info.transducer          = transducer_cal.transducer_name;
cal_info.cal_file            = transducer_cal.filename;
cal_info.cal_date            = transducer_cal.date;
cal_info.frequency_hz        = frequency_hz;
cal_info.level_dbspl         = level_dbspl;
cal_info.sensitivity_dbspl   = sensitivity_dbspl;
cal_info.atten_db            = atten_db;
cal_info.scale_factor        = scale_factor;

end