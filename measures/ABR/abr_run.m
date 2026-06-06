function result = abr_run(params, cal, sess)
% ABR_RUN  Run a single ABR acquisition (one frequency, all levels).
%
% Inputs:
%   params  - ABR params struct
%   cal     - calibration struct
%   sess    - Session handle object
%
% Output:
%   result  - struct saved via sess.saveRun()

n_levels  = length(params.levels_dbspl);
epoch_samples = round(diff(params.epoch_window_ms) / 1000 * params.fs);

%% --- Pre-allocate ---

epochs   = zeros(params.n_reps * 2, epoch_samples, n_levels);  % *2 for alternating
averages = zeros(epoch_samples, n_levels);
stimuli  = zeros([], n_levels);   % filled in loop, size depends on stim

%% --- Hardware init ---

% TDT Init:
circuit_path = fullfile('hardware', 'circuits', 'abr_play_record.rcx');
tdt = tdt_init(params, circuit_path, 99, 1);
fprintf('TDT hardware init\n');

%% --- Level loop ---

for lev_idx = 1:n_levels

    this_level          = params.levels_dbspl(lev_idx);
    params_this         = params;
    params_this.levels_dbspl = this_level;   % single level for stimulus gen

    [stim, stim_info]   = abr_make_stimulus(params_this, cal);
    stimuli(:, lev_idx) = stim.pos;          % save positive polarity

    fprintf('Running %s | %d Hz | %d dB SPL | %d reps\n', ...
        params.stim_type, params.frequency_hz, this_level, params.n_reps);

    rep_count   = 0;
    running_sum = zeros(epoch_samples, 1);

    %% --- Rep loop ---

    for rep = 1:params.n_reps

        % Alternate polarity
        if mod(rep, 2) == 1
            play_stim = stim.pos;
        else
            play_stim = stim.neg;
        end

        % Jittered ISI
        jitter    = 1 + (rand - 0.5) * 2 * params.jitter_pct/100;
        isi_samps = round(stim.duration_samples * jitter);

        % TDT STUB: replace with actual play/record
        % [epoch_raw] = tdt_play_record(tdt, play_stim, isi_samps);
        % epoch = tdt_play_record(tdt, play_stim, zeros(size(play_stim)), ...
        % atten_db, trig_val_L, trig_val_R);
        epoch_raw = randn(epoch_samples, params.n_channels) * 1e-6;  % fake data
        fprintf('[STUB] Play/record rep %d\n', rep);

        % Artifact rejection placeholder
        if params.artifact_reject
            % PLACEHOLDER: artifact_reject_epoch() not yet implemented
            % rejected = artifact_reject_epoch(epoch_raw, params);
            rejected = false;
        else
            rejected = false;
        end

        if ~rejected
            rep_count   = rep_count + 1;
            running_sum = running_sum + epoch_raw(:, 1);
            epochs(rep_count, :, lev_idx) = epoch_raw(:, 1);
        end

        % Sliding memory window
        if params.memory_reps > 0 && rep_count > params.memory_reps
            running_sum = running_sum - epochs(rep_count - params.memory_reps, :, lev_idx)';
            averages(:, lev_idx) = running_sum / params.memory_reps;
        else
            if rep_count > 0
                averages(:, lev_idx) = running_sum / rep_count;
            end
        end

    end   % rep loop

    fprintf('Level %d dB complete. %d/%d reps accepted.\n', ...
        this_level, rep_count, params.n_reps);

end   % level loop

%% --- Hardware cleanup ---

% TDT Close
% tdt_close(tdt);
fprintf('[STUB] TDT hardware cleanup\n');

%% --- Package and save ---

data.epochs    = epochs;
data.average   = averages;
data.stimulus  = stimuli;
data.fs        = params.fs;
data.stim_info = stim_info;

result = sess.saveRun(params, data);
fprintf('ABR run complete. Saved to: %s\n', result);

end

