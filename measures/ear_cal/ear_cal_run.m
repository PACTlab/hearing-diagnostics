function [result, metadata] = ear_cal_run(params, transducer, tdt, ...
    save_dir, metadata, callbacks)
% EAR_CAL_RUN  Run in-ear calibration sweep and compute correction filter.
%
% Plays a tone sweep in the ear, records mic response, computes FIR
% correction filter, saves result via session infrastructure, and
% returns filter info for loading into session.
%
% Inputs:
%   params      - ear cal params struct
%   transducer  - transducer registry entry
%   tdt         - TDT handle or [] for stub mode
%   save_dir    - session save directory
%   metadata    - session metadata struct
%   callbacks   - struct with function handles or []
%
% Outputs:
%   result      - saved run result struct
%   metadata    - updated metadata

has_callbacks = ~isempty(callbacks);
stub_mode     = isempty(tdt);

if stub_mode
    warning('ear_cal_run:stubMode', ...
        'Running in stub mode — fake mic data will be used.');
end

notify('Starting ear cal sweep...');

%% --- Build frequency vector ---

switch lower(params.freq_spacing)
    case 'log'
        freqs = logspace(log10(params.freq_min_hz), ...
                         log10(params.freq_max_hz), ...
                         params.freq_n_points);
    case 'linear'
        freqs = linspace(params.freq_min_hz, ...
                         params.freq_max_hz, ...
                         params.freq_n_points);
end

n_freqs       = length(freqs);
rms_values    = zeros(1, n_freqs);
db_spl        = zeros(1, n_freqs);
n_tone_samps  = round(params.tone_duration_s * params.fs);
start_idx     = round(n_tone_samps * params.steady_state_start_pct / 100);
end_idx       = round(n_tone_samps * params.steady_state_end_pct   / 100);

%% --- Sweep ---

for fi = 1:n_freqs

    if has_callbacks && callbacks.should_stop()
        notify('Ear cal stopped by user.');
        break
    end

    this_freq = freqs(fi);
    notify(sprintf('Frequency %d / %d — %.0f Hz', fi, n_freqs, this_freq));

    % Generate tone with onset/offset ramp
    t      = (0:n_tone_samps-1)' / params.fs;
    tone   = params.tone_level_norm * sin(2 * pi * this_freq * t);
    n_ramp = round(0.01 * params.fs);
    ramp   = hann(2 * n_ramp);
    tone(1:n_ramp)         = tone(1:n_ramp)         .* ramp(1:n_ramp);
    tone(end-n_ramp+1:end) = tone(end-n_ramp+1:end) .* ramp(n_ramp+1:end);

    % Play and record
    if stub_mode
        fake_sensitivity = -20 * log10(this_freq / 1000);
        fake_rms         = params.tone_level_norm * ...
                           10^((fake_sensitivity - 10) / 20);
        recording        = fake_rms * sin(2 * pi * this_freq * t) + ...
                           fake_rms * 0.1 * randn(size(t));
        pause(0.05);
    else
        zeros_buf = zeros(size(tone));
        switch lower(params.ear)
            case 'ch1'
                stim_ch1 = tone;
                stim_ch2 = zeros_buf;
            case 'ch2'
                stim_ch1 = zeros_buf;
                stim_ch2 = tone;
        end
        raw       = tdt_play_record(tdt, stim_ch1, stim_ch2, ...
            0, 0, 1, 1, true);
        recording = raw(1, :)';
    end

    % RMS over steady state
    if strcmp(params.method, 'manual')
        answer = inputdlg(...
            sprintf('Enter oscilloscope RMS for %.0f Hz (V):', this_freq), ...
            'Manual entry', 1, {''});
        if isempty(answer) || isempty(answer{1})
            notify('Manual entry cancelled.');
            break
        end
        rms_values(fi) = str2double(answer{1});
    else
        steady         = recording(start_idx:end_idx);
        rms_values(fi) = rms(steady);
    end

    % Convert to dB SPL
    mic_pa_per_v   = 10^(transducer.mic.sensitivity_dbv / 20);
    pressure_pa    = rms_values(fi) / mic_pa_per_v;
    db_spl(fi)     = 20 * log10(pressure_pa / 20e-6);

    % Update plot
    if has_callbacks
        callbacks.update_plot(freqs(1:fi), db_spl(1:fi));
    end

end   % frequency loop

notify('Computing correction filter...');

%% --- Compute filter ---

[b, filter_info] = ear_cal_compute_filter(freqs(:), db_spl(:), params);

notify('Filter computed.');

%% --- Package result ---

result_data.frequency_hz   = freqs;
result_data.rms_volts      = rms_values;
result_data.db_spl         = db_spl;
result_data.filter_b       = b;
result_data.filter_info    = filter_info;
result_data.channel        = params.ear;
result_data.transducer     = transducer.display_name;
result_data.method         = params.method;

%% --- Save via session infrastructure ---

save_params              = params;
save_params.measure_type = 'EARCAL';
save_params.ear          = params.ear;

[~, metadata] = session_save_run(save_dir, metadata, ...
    save_params, result_data);

result.filter_b    = b;
result.filter_info = filter_info;
result.channel     = params.ear;
result.db_spl      = db_spl;
result.frequency_hz = freqs;

notify(sprintf('Ear cal complete. Filter order: %d, mean group delay: %.1f ms.', ...
    filter_info.filter_order, filter_info.mean_group_delay_ms));

%% ================================================================
%  NESTED HELPER
%% ================================================================

    function notify(msg)
        fprintf('%s\n', msg);
        if has_callbacks
            callbacks.update_status(msg);
        end
    end

end