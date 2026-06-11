function result = transducer_check_run(params, transducer, tdt, callbacks)
% TRANSDUCER_CHECK_RUN  Run frequency sweep for one channel.
%
% Inputs:
%   params      - transducer_check params struct
%   transducer  - transducer registry entry struct
%   tdt         - TDT hardware struct or [] for stub mode
%   callbacks   - struct with function handles:
%                   .update_status(msg)
%                   .update_plot(freq, db_spl)
%                   .should_stop()
%                 Pass [] to run headless.
%
% Output:
%   result      - struct with frequency response and metadata

has_callbacks = ~isempty(callbacks);
stub_mode     = isempty(tdt);

if stub_mode
    warning('transducer_check_run:stubMode', ...
        'Running in stub mode — fake mic data will be used.');
end

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

n_freqs      = length(freqs);
rms_values   = zeros(1, n_freqs);
db_spl       = zeros(1, n_freqs);
n_tone_samps = round(params.tone_duration_s * params.fs);

%% --- Steady state window ---

start_idx = round(n_tone_samps * params.steady_state_start_pct / 100);
end_idx   = round(n_tone_samps * params.steady_state_end_pct   / 100);

notify('Starting frequency sweep...');

%% --- Sweep ---

for fi = 1:n_freqs

    if has_callbacks && callbacks.should_stop()
        notify('Sweep stopped by user.');
        break
    end

    this_freq = freqs(fi);
    notify(sprintf('Frequency %d / %d — %.0f Hz', fi, n_freqs, this_freq));

    %% --- Generate tone ---
    t         = (0:n_tone_samps-1)' / params.fs;
    tone      = params.tone_level_norm * sin(2 * pi * this_freq * t);

    % Apply onset/offset ramp to avoid clicks
    n_ramp    = round(0.01 * params.fs);   % 10ms ramp
    ramp      = hann(2 * n_ramp);
    tone(1:n_ramp)             = tone(1:n_ramp)             .* ramp(1:n_ramp);
    tone(end-n_ramp+1:end)     = tone(end-n_ramp+1:end)     .* ramp(n_ramp+1:end);

    %% --- Play and record ---

    if stub_mode
        % Fake a reasonable mic response with some roll-off
        fake_sensitivity = -20 * log10(this_freq / 1000);
        fake_rms         = params.tone_level_norm * ...
            10^((fake_sensitivity - 10) / 20);
        recording        = fake_rms * randn(n_tone_samps, 1) + ...
            fake_rms * sin(2 * pi * this_freq * t);
        pause(0.05);
    else
        % Build channel buffers
        zeros_buf = zeros(size(tone));
        switch params.ear
            case 'ch1'
                stim_ch1 = tone;
                stim_ch2 = zeros_buf;
            case 'ch2'
                stim_ch1 = zeros_buf;
                stim_ch2 = tone;
        end

        % Attenuation — 0 dB since level is controlled by tone_level_norm
        att_ch1 = 0;
        att_ch2 = 0;

        % Play and record — Nreps=1, throwAway=1
        raw = tdt_play_record(tdt, stim_ch1, stim_ch2, ...
            att_ch1, att_ch2, 1, 1, true);

        % raw is [1 x n_samps] — transpose to column
        recording = raw(1, :)';
    end

    %% --- Manual override ---

    if strcmp(params.method, 'manual')
        answer = inputdlg(...
            sprintf('Enter oscilloscope RMS reading for %.0f Hz (V):', ...
                this_freq), ...
            'Manual entry', 1, {''});
        if isempty(answer) || isempty(answer{1})
            notify('Manual entry cancelled.');
            break
        end
        manual_rms      = str2double(answer{1});
        rms_values(fi)  = manual_rms;
    else
        % Compute RMS over steady state window
        steady          = recording(start_idx:end_idx);
        rms_values(fi)  = rms(steady);
    end

    %% --- Convert to dB SPL ---

    mic_pa_per_v    = 10^(transducer.mic.sensitivity_dbv / 20);
    pressure_pa     = rms_values(fi) / mic_pa_per_v;
    db_spl(fi)      = 20 * log10(pressure_pa / 20e-6);

    %% --- Update plot ---

    if has_callbacks
        callbacks.update_plot(freqs(1:fi), db_spl(1:fi));
    end

end   % frequency loop

%% --- Package result ---

result.frequency_hz     = freqs;
result.rms_volts        = rms_values;
result.db_spl           = db_spl;
result.channel          = params.ear;
result.method           = params.method;
result.transducer       = transducer.display_name;
result.date             = datestr(now, 'yyyy-mm-dd');
result.fs               = params.fs;
result.tone_level_norm  = params.tone_level_norm;

notify('Sweep complete.');

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