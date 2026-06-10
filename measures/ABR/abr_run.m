function metadata = abr_run(params, save_dir, metadata, tdt, cal, callbacks)
% ABR_RUN  Run ABR acquisition for one frequency across all levels.
%
% Inputs:
%   params    - ABR params struct (levels_dbspl can be array)
%   save_dir  - full path to session folder
%   metadata  - session metadata struct
%   tdt       - TDT hardware struct from tdt_init, or [] for stub mode
%   cal       - transducer calibration struct, or []
%   callbacks - struct of function handles for real-time GUI updates:
%                 .update_status(msg)
%                 .update_waveform(t, avg_uv)
%                 .update_noise(rms_uv)
%                 .add_prev(t, avg_uv, level, freq)
%                 .should_stop()  returns logical
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

%% --- Epoch dimensions ---

epoch_samples = round(diff(params.rec_window_ms) / 1000 * params.fs);
t_epoch       = linspace(params.rec_window_ms(1), ...
                         params.rec_window_ms(2), epoch_samples);

%% ================================================================
%  LEVEL LOOP
%% ================================================================

for lev_idx = 1:length(params.levels_dbspl)

    this_level = params.levels_dbspl(lev_idx);

    %% --- Check stop ---
    if has_callbacks && callbacks.should_stop()
        fprintf('ABR run stopped by user at level %d.\n', lev_idx);
        break
    end

    notify(sprintf('Level %d / %d — %d dB SPL — generating stimulus...', ...
        lev_idx, length(params.levels_dbspl), this_level));

    if has_callbacks && isfield(callbacks, 'update_title')
        callbacks.update_title(sprintf('Running average — %d Hz, %d dB SPL', ...
            params.frequency_hz, this_level));
    end
    %% --- Generate stimulus for this level ---
    params_this_level              = params;
    params_this_level.levels_dbspl = this_level;

    [stim_out, stim_info] = abr_make_stimulus(params_this_level, cal);

    %% --- Initialize accumulators ---
    running_sum  = zeros(1, epoch_samples);
    epochs = zeros(params.n_reps, epoch_samples); 
    rep_accepted = 0;
    n_rejected   = 0;
    last_avg     = [];

    notify(sprintf('Level %d / %d — %d dB SPL — starting...', ...
        lev_idx, length(params.levels_dbspl), this_level));

    %% =============================================================
    %  REP LOOP
    %% =============================================================

    for rep = 1:params.n_reps

        %% --- Check stop ---
        if has_callbacks && callbacks.should_stop()
            break
        end

        %% --- Pick polarity ---
        if mod(rep, 2) == 1
            play_buff = stim_out.pos;
        else
            play_buff = stim_out.neg;
        end

        %% --- Pick Ear --- 
        if strcmp(params_this_level.ear, 'left')
            stim_ch1 = play_buff;
            stim_ch2 = zeros(size(play_buff));
        elseif strcmp(params_this_level.ear, 'right')
            stim_ch1 = zeros(size(play_buff));
            stim_ch2 = play_buff;
        else
            stim_ch1 = play_buff;
            stim_ch2 = play_buff;
        end

        stim_ch1 = stim_ch1(1:stim_out.isi_samples); 
        stim_ch2 = stim_ch2(1:stim_out.isi_samples); 

        %% --- Set attns ---
            att_ch1 = 30; 
            att_ch2 = 30; %% hardcoded now should take into account transducer

        %% --- Set other info for tdt play and record
        Nreps = 1; 
        throwAway = 0; 
        delayComp = 0; 
        %% --- Play and record ---
        if stub_mode
            epoch_raw = randn(epoch_samples, 1) * 0.3e-6;
            pause(0.001);
        else
            epoch_raw = tdt_play_record(tdt, stim_ch1, stim_ch2, att_ch1, att_ch2, Nreps, throwAway, delayComp);
            epoch = epoch_raw(1, 1:epoch_samples); 
        end

        %% --- Save all raw epochs --- 

        epochs(rep, :) = epoch; 

        %% --- Artifact rejection ---
        rejected = false;
        if params.artifact_reject
            if max(abs(epoch_raw)) > params.artifact_thresh_v
                rejected   = true;
                n_rejected = n_rejected + 1;
            end
        end

        %% --- Accumulate ---
        if ~rejected
            rep_accepted = rep_accepted + 1;
            running_sum  = running_sum + epoch_raw(1, 1:epoch_samples);
        end

        %% --- Update display every 25 reps ---
        if mod(rep, 10) == 0 && rep_accepted > 0 && has_callbacks
            current_avg = running_sum / rep_accepted;
            current_avg = current_avg - mean(current_avg); 
            callbacks.update_waveform(t_epoch, current_avg * 1e6);
            callbacks.update_noise(std(epoch_raw) * 1e6);
            notify(sprintf(...
                'Level %d / %d — %d dB SPL — rep %d / %d  |  rejected: %d', ...
                lev_idx, length(params.levels_dbspl), ...
                this_level, rep, params.n_reps, n_rejected));
            drawnow;
        end

    end   % rep loop

    %% --- Save this level ---
    if rep_accepted > 0
        final_avg = running_sum / rep_accepted;
        last_avg  = final_avg;

        save_params              = params;
        save_params.levels_dbspl = this_level;

        save_data.epochs            = epochs;
        save_data.average           = final_avg;
        save_data.fs                = params.fs;
        save_data.n_reps_accepted   = rep_accepted;
        save_data.n_reps_rejected   = n_rejected;
        save_data.stim_info         = stim_info;

        [~, metadata] = session_save_run(save_dir, metadata, ...
            save_params, save_data);

        fprintf('Level %d dB complete. %d/%d reps accepted.\n', ...
            this_level, rep_accepted, params.n_reps);

        %% --- Update previous waveforms panel ---
        if has_callbacks
            callbacks.add_prev(t_epoch, final_avg * 1e6, ...
                this_level, params.frequency_hz);
        end
    else
        fprintf('Level %d dB — no accepted reps, not saved.\n', this_level);
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