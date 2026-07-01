function metadata = dpoae_run(params, save_dir, metadata, tdt, ear_cal, callbacks)
% DPOAE_RUN  Run DPOAE acquisition.
%
% Inputs:
%   params    - DPOAE params struct from dpoae_default_params / GUI
%   save_dir  - full path to session folder
%   metadata  - session metadata struct
%   tdt       - TDT hardware struct from tdt_init, or [] for stub mode
%   cal       - transducer calibration struct, or []
%   callbacks - struct of function handles for real-time GUI updates:
%                 .update_status(msg)
%                 .update_waveform(t, avg)
%                 .update_noise(rms)
%                 .add_prev(t, avg, trial, freq)
%                 .should_stop()  returns logical
%               Pass [] to run headless with no display updates.

%% --- Setup ---

has_callbacks = ~isempty(callbacks);
stub_mode     = isempty(tdt);

if stub_mode
    warning('dpoae_run:stubMode', ...
        'TDT handle is empty — running in stub mode with fake data.');
end

%% --- Shared TDT play/record args ---
Nreps      = 1;
throwAway  = 0;
delayComp  = 1;

%% ================================================================
%  BRANCH: swept vs discrete
%% ================================================================

switch lower(params.stim_type)

    %% ============================================================
    case 'swept'
    %% ============================================================

        %% --- Generate stimulus ---
        [stim_out, stim_info] = dpoae_make_stimulus(params);

        %% --- Route to ear ---
        stim_ch1 = stim_out.ch1; 
        stim_ch2 = stim_out.ch2; 

        % apply calibration and set attn
        [stim_ch1, att_ch1] = ear_cal_apply(stim_ch1, ear_cal.ch1, params.level_f1_dB);
        [stim_ch2, att_ch2] = ear_cal_apply(stim_ch2, ear_cal.ch2, params.level_f2_dB);

        epoch_samples = numel(stim_ch1);
        t_epoch       = stim_info.t; 

        % Accumulate trials: rows = trials, cols = samples
        all_trials = zeros(params.trials, epoch_samples);

        for trial_idx = 1:params.trials

            if has_callbacks && callbacks.should_stop()
                fprintf('DPOAE run stopped by user at trial %d.\n', trial_idx);
                break
            end

            %% --- Play and record ---
            if stub_mode
                epoch = makeStubEpoch(stim_out.ch1, epoch_samples);
            else
                epoch_raw = tdt_play_record(tdt, stim_ch1, stim_ch2, ...
                    att_ch1, att_ch2, Nreps, throwAway, delayComp);
                epoch = epoch_raw(1, 1:epoch_samples);
            end

            all_trials(trial_idx, :) = epoch;

            notify(sprintf('Swept trial %d / %d — complete.', ...
                trial_idx, params.trials));

            %% --- Online analysis after each trial ---
            if trial_idx >= 2   % need at least 2 trials for artifact rejection stats
                [result, done] = dpoae_online_analysis(...
                    all_trials(1:trial_idx, :), stim_info, params);

                if has_callbacks
                    callbacks.update_waveform(result);
                    drawnow;
                end

                if done && trial_idx >= params.minTrials
                    notify(sprintf('Auto-stop: SNR criterion met after %d trials.', trial_idx));
                    break
                end
            end

        end   % trial loop

        %% --- Save swept data ---
        save_data.t_ms          = t_epoch;
        save_data.trials        = all_trials;
        save_data.average       = mean(all_trials, 1);
        save_data.fs            = params.fs;
        save_data.n_trials      = params.trials;
        save_data.stim_info     = stim_info;

        [~, metadata] = session_save_run(save_dir, metadata, params, save_data, result);
        fprintf('Swept DPOAE complete. %d trials saved.\n', params.trials);


        %% ============================================================
    case 'discrete'
        %% ============================================================
        n_freqs       = length(params.f2_hz);
        epoch_samples = round(params.duration_ms / 1000 * params.fs);
        t_epoch       = linspace(0, params.duration_ms, epoch_samples);

        % Generate all frequency stimuli once
        [stim_out, stim_info] = dpoae_make_stimulus(params);
        % stim_out.ch1 and .ch2 are now n_freqs x epoch_samples matrices

        % 3-D matrix: trials x samples x frequencies
        all_trials = zeros(params.trials, epoch_samples, n_freqs);

        for freq_idx = 1:n_freqs

            this_f2 = params.f2_hz(freq_idx);

            % Index into pre-generated stimulus matrix
            stim_ch1_this = stim_out.ch1(freq_idx, :);
            stim_ch2_this = stim_out.ch2(freq_idx, :);

            for trial_idx = 1:params.trials

                if has_callbacks && callbacks.should_stop()
                    fprintf('DPOAE run stopped at freq %d Hz, trial %d.\n', ...
                        this_f2, trial_idx);
                    break
                end

                notify(sprintf('Discrete — F2: %d Hz (%d/%d) — trial %d / %d', ...
                    this_f2, freq_idx, n_freqs, trial_idx, params.trials));

                %% --- Route to ear ---
                [ch1, ch2] = routeToEar(stim_ch1_this, stim_ch2_this, params.ear);

                %% --- Play and record ---
                if stub_mode
                    epoch = makeStubEpoch(stim_out.ch1, epoch_samples);
                else
                    epoch_raw = tdt_play_record(tdt, ch1, ch2, ...
                        att_ch1, att_ch2, Nreps, throwAway, delayComp);
                    epoch = epoch_raw(1, 1:epoch_samples);
                end

                all_trials(trial_idx, :, freq_idx) = epoch;

                %% --- Update display after each trial ---
                % if has_callbacks
                %     avg_so_far = squeeze(mean(all_trials(1:trial_idx, :, freq_idx), 1));
                %     callbacks.update_waveform(t_epoch, avg_so_far * 1e6);
                %     callbacks.update_noise(std(squeeze( ...
                %         all_trials(1:trial_idx, :, freq_idx)), [], 1) * 1e6);
                %     drawnow;
                % end

            end   % trial loop

        end   % freq loop

        %% --- Save discrete data ---
        save_data.t_ms      = t_epoch;
        save_data.trials    = all_trials;   % trials x samples x freqs
        save_data.average   = squeeze(mean(all_trials, 1));  % samples x freqs
        save_data.f2_hz     = params.f2_hz;
        save_data.fs        = params.fs;
        save_data.n_trials  = params.trials;
        save_data.stim_info = stim_info;

        [~, metadata] = session_save_run(save_dir, metadata, params, save_data);
        fprintf('Discrete DPOAE complete. %d freqs x %d trials saved.\n', ...
            n_freqs, params.trials);


    otherwise
        error('dpoae_run:unknownStimType', ...
            'Unknown stim_type: %s', params.stim_type);

end   % switch

%% ================================================================
%  CLEANUP
%% ================================================================

if ~stub_mode
    invoke(tdt.RZ, 'ZeroTag', 'datainL');
    invoke(tdt.RZ, 'ZeroTag', 'datainR');
end

%% ================================================================
%  NESTED HELPERS
%% ================================================================

    function notify(msg)
        fprintf('%s\n', msg);
        if has_callbacks
            callbacks.update_status(msg);
        end
    end

    function [ch1, ch2] = routeToEar(stim_ch1, stim_ch2, ear)
        switch lower(ear)
            case 'left'
                ch1 = stim_ch1;
                ch2 = zeros(size(stim_ch1));
            case 'right'
                ch1 = zeros(size(stim_ch1));
                ch2 = stim_ch2;
            otherwise
                ch1 = stim_ch1;
                ch2 = stim_ch2;
        end
    end

    function epoch = makeStubEpoch(buffer, n_samples, offset)
    % offset lets us skip past the lead-in buffer portion
    if nargin < 3; offset = 0; end
    start_idx = offset + 1;
    end_idx   = offset + n_samples;
    if end_idx <= length(buffer)
        epoch = buffer(start_idx:end_idx) * 0.1e-6;
    else
        epoch = zeros(1, n_samples);
        available = length(buffer) - offset;
        if available > 0
            epoch(1:available) = buffer(start_idx:end) * 0.1e-6;
        end
        epoch = epoch + randn(1, n_samples) * 0.02e-6;
    end
    end




end