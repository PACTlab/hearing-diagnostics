function metadata = abr_run(params, save_dir, metadata, tdt, cal_ctx, callbacks)
% ABR_RUN  Run ABR acquisition for one frequency across all levels.
%
% Inputs:
%   params    - ABR params struct (levels_dbspl can be an array)
%   save_dir  - full path to session folder
%   metadata  - session metadata struct
%   tdt       - TDT hardware struct from tdt_init, or [] for stub mode
%   cal_ctx   - calibration context struct for cal_apply_stimulus:
%                 .transducer_cal, .ear_cal, .fpl_cal  (any may be [])
%               A bare transducer cal struct is accepted for backwards
%               compatibility and wrapped automatically.
%   callbacks - struct of function handles for real-time GUI updates:
%                 .update_status(msg)
%                 .update_waveform(t, avg_combined, avg_pos, avg_neg)
%                 .update_noise(rms_uv)
%                 .add_prev(t, avg_uv, level, freq)
%                 .should_stop()  returns logical
%                 .update_title(msg)
%               Pass [] to run headless with no display updates.

%% --- Validate ---

err = abr_validate_params(params);
if ~isempty(err)
    error('abr_run:invalidParams', '%s', err);
end

has_callbacks = ~isempty(callbacks);
stub_mode     = isempty(tdt);

if stub_mode
    warning('abr_run:stubMode', ...
        'TDT handle is empty — running in stub mode with fake data.');
end

% Accept a bare transducer cal struct as well as a context struct
if ~isempty(cal_ctx) && ~isfield(cal_ctx, 'transducer_cal') && ...
        ~isfield(cal_ctx, 'ear_cal') && ~isfield(cal_ctx, 'fpl_cal')
    cal_ctx = struct('transducer_cal', cal_ctx);
end

%% --- Epoch dimensions ---

epoch_samples = round(diff(params.rec_window_ms) / 1000 * params.fs);

% Sample-accurate time vector: spacing is 1/fs, not diff/(n-1).
t_epoch = (0:epoch_samples-1) / params.fs * 1000 + params.rec_window_ms(1);

%% ================================================================
%  STIMULUS — built once, level-independent
%% ================================================================

notify('Generating stimulus...');

% Stage 1: bare waveform, no delay, no padding, no calibration
[base_stim, stim_info] = abr_make_stimulus(params);

%% ================================================================
%  CALIBRATION — attenuation for every level, computed up front
%% ================================================================
% Stage 2. Operates on the unpadded waveform so an in-ear filter's group
% delay and tail do not land in the ISI padding. Computing all levels here
% means an unreachable level is caught before any data is collected,
% rather than at level 7 of 9.

[stim_cal, cal_out] = cal_apply_stimulus(base_stim, params, cal_ctx);

%% ================================================================
%  BUFFERS — onset delay, polarity, ISI jitter
%% ================================================================
% Stage 3. Level-independent, so this also runs once.

[buffers, buffer_info] = abr_make_buffers(stim_cal, params);

notify(sprintf('Calibration: %s (%s). Attenuation %g to %g dB.', ...
    cal_out.cal_type, cal_out.level_units, ...
    min(cal_out.atten_db), max(cal_out.atten_db)));

for wi = 1:numel(cal_out.warnings)
    fprintf(2, '  cal: %s\n', cal_out.warnings{wi});
end

%% ================================================================
%  LEVEL LOOP
%% ================================================================

n_levels = numel(params.levels_dbspl);

for lev_idx = 1:n_levels

    this_level = params.levels_dbspl(lev_idx);
    this_atten = cal_out.atten_db(lev_idx);

    %% --- Check stop ---
    if has_callbacks && callbacks.should_stop()
        fprintf('ABR run stopped by user at level %d.\n', lev_idx);
        break
    end

    if has_callbacks && isfield(callbacks, 'update_title')
        callbacks.update_title(sprintf( ...
            'Running average — %d Hz, %g %s', ...
            params.frequency_hz, this_level, cal_out.level_units));
    end

    %% --- Initialize accumulators ---
    running_sum_combined = zeros(1, epoch_samples);
    running_sum_pos      = zeros(1, epoch_samples);
    running_sum_neg      = zeros(1, epoch_samples);
    epochs               = zeros(params.n_reps, epoch_samples);
    accepted_mask        = false(params.n_reps, 1);
    rep_accepted         = 0;
    rep_accepted_pos     = 0;
    rep_accepted_neg     = 0;
    n_rejected           = 0;
    reps_run             = 0;
    rep_elapsed_s        = zeros(params.n_reps, 1);

    notify(sprintf('Level %d / %d — %g %s (atten %g dB) — starting...', ...
        lev_idx, n_levels, this_level, cal_out.level_units, this_atten));

    %% =============================================================
    %  REP LOOP
    %% =============================================================

    for rep = 1:params.n_reps

        %% --- Check stop ---
        if has_callbacks && callbacks.should_stop()
            break
        end

        reps_run = rep;

        %% --- Pick polarity ---
        % Alternating unconditionally is correct: abr_make_stimulus
        % encodes the polarity mode into the two buffers, so 'cond' has
        % both positive and 'rare' has both inverted.
        if mod(rep, 2) == 1
            play_buff = buffers.pos;
        else
            play_buff = buffers.neg;
        end

        %% --- Pick ear ---
        if strcmp(params.ear, 'left')
            stim_ch1 = play_buff;
            stim_ch2 = zeros(size(play_buff));
        elseif strcmp(params.ear, 'right')
            stim_ch1 = zeros(size(play_buff));
            stim_ch2 = play_buff;
        else
            stim_ch1 = play_buff;
            stim_ch2 = play_buff;
        end

        stim_ch1 = stim_ch1(1:buffers.isi_samples(rep));
        stim_ch2 = stim_ch2(1:buffers.isi_samples(rep));

        %% --- Attenuation for this level ---
        % Set on both channels. The silent channel has zeros in the
        % buffer, so its attenuation is immaterial, but keeping them
        % matched avoids surprises for ear = 'both'.
        att_ch1 = this_atten;
        att_ch2 = this_atten;

        %% --- Playback settings ---
        Nreps     = 1;
        throwAway = 0;
        delayComp = 0;   % TODO audit finding #2: tdt.ADdelay (~5.08 ms)
                         % is not being removed. Every waveform is offset
                         % by about one ABR wave.

        %% --- Play and record ---
        if stub_mode
            % Show the stimulus so waveform shape and polarity can be
            % checked before connecting hardware.
            stim_portion = play_buff(1:buffers.n_stim);

            if length(stim_portion) >= epoch_samples
                epoch_raw = stim_portion(1:epoch_samples)' * 0.1e-6;
            else
                epoch_raw = zeros(1, epoch_samples);
                epoch_raw(1:length(stim_portion)) = stim_portion * 0.1e-6;
                epoch_raw = epoch_raw + randn(1, epoch_samples) * 0.02e-6;
            end
            pause(0.001);
            rep_elapsed_s(rep) = NaN;   % no meaningful timing in stub mode
        else
            t_rep = tic;
            epoch_raw = tdt_play_record(tdt, stim_ch1, stim_ch2, ...
                att_ch1, att_ch2, Nreps, throwAway, delayComp);
            rep_elapsed_s(rep) = toc(t_rep);
        end

        epoch = epoch_raw(1, 1:epoch_samples);

        %% --- Artifact rejection ---
        % artifact_thresh_uv is in microvolts; epoch is in volts.
        rejected = false;
        if params.artifact_reject
            if max(abs(epoch)) > params.artifact_thresh_uv * 1e-6
                rejected   = true;
                n_rejected = n_rejected + 1;
            end
        end

        %% --- Store ---
        epochs(rep, :)      = epoch;
        accepted_mask(rep)  = ~rejected;

        %% --- Accumulate ---
        if ~rejected
            rep_accepted         = rep_accepted + 1;
            running_sum_combined = running_sum_combined + epoch;

            if mod(rep, 2) == 1
                rep_accepted_pos = rep_accepted_pos + 1;
                running_sum_pos  = running_sum_pos + epoch;
            else
                rep_accepted_neg = rep_accepted_neg + 1;
                running_sum_neg  = running_sum_neg + epoch;
            end
        end

        %% --- Update display ---
        if mod(rep, 10) == 0 && rep_accepted > 0 && has_callbacks
            avg_combined = running_sum_combined / rep_accepted;

            avg_pos = zeros(1, epoch_samples);
            avg_neg = zeros(1, epoch_samples);
            if rep_accepted_pos > 0
                avg_pos = running_sum_pos / rep_accepted_pos;
            end
            if rep_accepted_neg > 0
                avg_neg = running_sum_neg / rep_accepted_neg;
            end

            callbacks.update_waveform(t_epoch, ...
                avg_combined * 1e6, avg_pos * 1e6, avg_neg * 1e6);

            % Scalar noise estimate from accepted reps only. std() of a
            % matrix returns one value per sample, and the noise label
            % formats a scalar.
            accepted_epochs = epochs(accepted_mask(1:rep), :);
            callbacks.update_noise(mean(std(accepted_epochs, 0, 1)) * 1e6);

            notify(sprintf( ...
                'Level %d / %d — %g %s — rep %d / %d  |  rejected: %d', ...
                lev_idx, n_levels, this_level, cal_out.level_units, ...
                rep, params.n_reps, n_rejected));
            drawnow;
        end

    end   % rep loop

    %% --- Save this level ---
    if rep_accepted > 0
        final_avg = running_sum_combined / rep_accepted;

        save_params              = params;
        save_params.levels_dbspl = this_level;

        save_data.t_ms            = t_epoch;

        % Trim to reps actually run. Preallocated rows that were never
        % filled would otherwise be saved as zeros and pull any offline
        % re-average toward zero.
        save_data.epochs          = epochs(1:reps_run, :);
        save_data.accepted        = accepted_mask(1:reps_run);

        save_data.average         = final_avg;
        save_data.average_pos     = running_sum_pos / max(rep_accepted_pos, 1);
        save_data.average_neg     = running_sum_neg / max(rep_accepted_neg, 1);
        save_data.fs              = params.fs;
        save_data.n_reps_run      = reps_run;
        save_data.n_reps_accepted = rep_accepted;
        save_data.n_reps_pos      = rep_accepted_pos;
        save_data.n_reps_neg      = rep_accepted_neg;
        save_data.n_reps_rejected = n_rejected;
        save_data.stim_info       = stim_info;
        save_data.buffer_info     = buffer_info;

        % ACHIEVED presentation rate, not the nominal one. The two differ:
        % every rep carries fixed overhead (buffer write, settle, trigger,
        % read) on top of the ISI, so buffer_info.nominal_isi_ms does not
        % describe what the animal heard. ABR amplitude and latency both
        % depend on rate, so record the measured value.
        elapsed = rep_elapsed_s(1:reps_run);
        elapsed = elapsed(isfinite(elapsed));
        if ~isempty(elapsed)
            save_data.achieved_isi_ms  = mean(elapsed) * 1000;
            save_data.achieved_rate_hz = 1 / mean(elapsed);
            save_data.isi_sd_ms        = std(elapsed) * 1000;
        else
            save_data.achieved_isi_ms  = NaN;
            save_data.achieved_rate_hz = NaN;
            save_data.isi_sd_ms        = NaN;
        end
        save_data.nominal_rate_hz = params.rate_hz;

        % Attenuation and calibration provenance for this level
        save_data.cal_out           = cal_out;
        save_data.atten_db          = this_atten;
        save_data.level_requested   = this_level;
        save_data.level_units       = cal_out.level_units;
        save_data.level_was_clamped = cal_out.clamped(lev_idx);

        [~, metadata] = session_save_run(save_dir, metadata, ...
            save_params, save_data);

        fprintf(['Level %g complete (atten %g dB). %d/%d reps accepted. ' ...
                 'Rate: %.2f Hz achieved vs %.2f Hz nominal.\n'], ...
            this_level, this_atten, rep_accepted, reps_run, ...
            save_data.achieved_rate_hz, params.rate_hz);

        if isfinite(save_data.achieved_rate_hz) && ...
                abs(save_data.achieved_rate_hz - params.rate_hz) > ...
                0.1 * params.rate_hz
            warning('abr_run:rateMismatch', ...
                ['Achieved rate %.2f Hz differs from nominal %.2f Hz by ' ...
                 'more than 10%%. Per-rep overhead dominates the ISI; see ' ...
                 'write_settle_s in tdt_play_record.'], ...
                save_data.achieved_rate_hz, params.rate_hz);
        end

        if has_callbacks
            callbacks.add_prev(t_epoch, final_avg * 1e6, ...
                this_level, params.frequency_hz);
        end
    else
        fprintf('Level %g — no accepted reps, not saved.\n', this_level);
    end

end   % level loop

%% ================================================================
%  CLEANUP
%% ================================================================

if ~stub_mode
    invoke(tdt.RZ, 'ZeroTag', 'datainL');
    invoke(tdt.RZ, 'ZeroTag', 'datainR');
end

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