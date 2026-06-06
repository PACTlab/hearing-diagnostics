function abr_gui()
% ABR_GUI  Main ABR data collection window.
% Launches session dialog first, then opens main acquisition window.

% To do: Right now it's not saving a new file for each level/frequency
% combination. The side panel of previous waves is not changing with
% freq/stim type


warning('off', 'Session:noTransducerCal');

%% --- Session ---

sess = gui_session_dialog();
if isempty(sess)
    return
end

%% --- Default params ---

params = abr_default_params();

%% --- State ---

state.running    = false;
state.stop_req   = false;
prevAxes         = {};

%% --- Main figure ---

fig = uifigure(...
    'Name',            sprintf('ABR — %s', sess.SubjectID), ...
    'Position',        [50 50 1200 750], ...
    'CloseRequestFcn', @(~,~) onCloseRequest());

%% ================================================================
%  TOP LEVEL GRID: 3 rows
%  Row 1: subject bar
%  Row 2: control panel
%  Row 3: plots
%% ================================================================

mainGrid = uigridlayout(fig, [3 1]);
mainGrid.RowHeight   = {52, 110, '1x'};
mainGrid.ColumnWidth = {'1x'};
mainGrid.Padding     = [8 8 8 8];
mainGrid.RowSpacing  = 6;

%% ================================================================
%  ROW 1 — Subject bar
%% ================================================================

subjectPanel = uipanel(mainGrid, ...
    'BorderType',      'line', ...
    'BackgroundColor', 'w');
subjectPanel.Layout.Row    = 1;
subjectPanel.Layout.Column = 1;

subGrid = uigridlayout(subjectPanel, [1 10]);
subGrid.ColumnWidth   = {80, 100, 80, 100, 100, 8, 110, 110, 110, '1x'};
subGrid.Padding       = [10 6 10 6];
subGrid.ColumnSpacing = 12;
subGrid.BackgroundColor = 'w';

% Status
statusLbl = uilabel(subGrid, ...
    'Text',       '● Idle', ...
    'FontSize',   13, ...
    'FontWeight', 'bold', ...
    'FontColor',  [0.5 0.5 0.5]);
statusLbl.Layout.Row    = 1;
statusLbl.Layout.Column = 1;

% Subject info chips
makeInfoChip(subGrid, 'Subject',  sess.SubjectID, 2);
makeInfoChip(subGrid, 'Species',  sess.Species,   3);
makeInfoChip(subGrid, 'Operator', sess.Operator,  4);
makeInfoChip(subGrid, 'Date',     sess.Date,      5);

% Divider
divLbl = uilabel(subGrid, 'Text', '|', 'FontColor', [0.8 0.8 0.8]);
divLbl.Layout.Row    = 1;
divLbl.Layout.Column = 6;

% Cal badges
transducerCalLbl = uilabel(subGrid, ...
    'Text',                calBadgeText('Transducer', sess.TransducerCal), ...
    'FontSize',            11, ...
    'HorizontalAlignment', 'center', ...
    'BackgroundColor',     calBadgeColor(sess.TransducerCal), ...
    'FontColor',           calBadgeFontColor(sess.TransducerCal));
transducerCalLbl.Layout.Row    = 1;
transducerCalLbl.Layout.Column = 7;

earCalLbl = uilabel(subGrid, ...
    'Text',                calBadgeText('Ear cal', sess.EarCal), ...
    'FontSize',            11, ...
    'HorizontalAlignment', 'center', ...
    'BackgroundColor',     calBadgeColor(sess.EarCal), ...
    'FontColor',           calBadgeFontColor(sess.EarCal));
earCalLbl.Layout.Row    = 1;
earCalLbl.Layout.Column = 8;

% Buttons
btnGrid = uigridlayout(subGrid, [1 3]);
btnGrid.Layout.Row      = 1;
btnGrid.Layout.Column   = 10;
btnGrid.ColumnWidth     = {'1x', '1x', '1x'};
btnGrid.Padding         = [0 4 0 4];
btnGrid.ColumnSpacing   = 6;
btnGrid.BackgroundColor = 'w';

earCalBtn = uibutton(btnGrid, 'Text', 'Ear cal', ...
    'ButtonPushedFcn', @(~,~) onEarCal());
earCalBtn.Layout.Row    = 1;
earCalBtn.Layout.Column = 1;

settingsBtn = uibutton(btnGrid, 'Text', 'Settings', ...
    'ButtonPushedFcn', @(~,~) onSettings());
settingsBtn.Layout.Row    = 1;
settingsBtn.Layout.Column = 2;

quitBtn = uibutton(btnGrid, 'Text', 'Quit ABR', ...
    'FontColor',       [0.8 0.1 0.1], ...
    'ButtonPushedFcn', @(~,~) onCloseRequest());
quitBtn.Layout.Row    = 1;
quitBtn.Layout.Column = 3;

%% ================================================================
%  ROW 2 — Control panel
%% ================================================================

ctrlPanel = uipanel(mainGrid, ...
    'BorderType',      'line', ...
    'BackgroundColor', 'w');
ctrlPanel.Layout.Row    = 2;
ctrlPanel.Layout.Column = 1;

ctrlGrid = uigridlayout(ctrlPanel, [2 12]);
ctrlGrid.RowHeight      = {'1x', 24};
ctrlGrid.ColumnWidth    = {'1x','1x','1x','1x','2x','1x','1x','1x','1x','1x', 80, 80};
ctrlGrid.Padding        = [10 8 10 6];
ctrlGrid.RowSpacing     = 4;
ctrlGrid.ColumnSpacing  = 8;
ctrlGrid.BackgroundColor = 'w';

% Parameter fields — row 1
stimTypeDrop = makeField(ctrlGrid, 'Stimulus',             1, 1,  'drop', {'Tone burst','Click','Chirp'});
freqField    = makeField(ctrlGrid, 'Frequency (Hz)',       1, 2,  'edit', num2str(params.frequency_hz));
earDrop      = makeField(ctrlGrid, 'Ear',                  1, 3,  'drop', {'Right','Left'});
polarityDrop = makeField(ctrlGrid, 'Polarity',             1, 4,  'drop', {'Alternating','Condensation','Rarefaction'});
levelsField  = makeField(ctrlGrid, 'Level series (dB SPL)',1, 5,  'edit', ...
    strjoin(arrayfun(@num2str, params.levels_dbspl, 'UniformOutput', false), ', '));
repsField    = makeField(ctrlGrid, 'Reps',                 1, 6,  'edit', num2str(params.n_reps));
rateField    = makeField(ctrlGrid, 'Rate (Hz)',            1, 7,  'edit', num2str(params.rate_hz));
durField     = makeField(ctrlGrid, 'Dur (ms)',             1, 8,  'edit', num2str(params.duration_ms));
riseField    = makeField(ctrlGrid, 'Rise (ms)',            1, 9,  'edit', num2str(params.rise_fall_ms));
earCalDrop   = makeField(ctrlGrid, 'Ear cal',              1, 10, 'drop', {'Session','None','File...'});

runBtn = uibutton(ctrlGrid, ...
    'Text',            '▶  Run', ...
    'BackgroundColor', [0.11 0.62 0.46], ...
    'FontColor',       [0.88 0.96 0.93], ...
    'FontWeight',      'bold', ...
    'ButtonPushedFcn', @(~,~) onRun());
runBtn.Layout.Row    = 1;
runBtn.Layout.Column = 11;

stopBtn = uibutton(ctrlGrid, ...
    'Text',            '■  Stop', ...
    'BackgroundColor', [0.85 0.35 0.18], ...
    'FontColor',       [0.98 0.92 0.89], ...
    'FontWeight',      'bold', ...
    'Enable',          'off', ...
    'ButtonPushedFcn', @(~,~) onStop());
stopBtn.Layout.Row    = 1;
stopBtn.Layout.Column = 12;

% Status bar — row 2
statusBar = uilabel(ctrlGrid, ...
    'Text',      'Ready.', ...
    'FontSize',  11, ...
    'FontColor', [0.4 0.4 0.4]);
statusBar.Layout.Row    = 2;
statusBar.Layout.Column = [1 12];

%% ================================================================
%  ROW 3 — Plots
%% ================================================================

plotGrid = uigridlayout(mainGrid, [1 2]);
plotGrid.Layout.Row    = 3;
plotGrid.Layout.Column = 1;
plotGrid.ColumnWidth   = {'1x', 200};
plotGrid.ColumnSpacing = 6;
plotGrid.Padding       = [0 0 0 0];

%% --- Left col: waveform + noise ---

leftGrid = uigridlayout(plotGrid, [2 1]);
leftGrid.Layout.Row    = 1;
leftGrid.Layout.Column = 1;
leftGrid.RowHeight     = {'1x', 80};
leftGrid.RowSpacing    = 6;
leftGrid.Padding       = [0 0 0 0];

% Waveform panel
wavePanel = uipanel(leftGrid, ...
    'BorderType',      'line', ...
    'Title',           'Running average', ...
    'BackgroundColor', 'w');
wavePanel.Layout.Row    = 1;
wavePanel.Layout.Column = 1;

waveGrid = uigridlayout(wavePanel, [1 1]);
waveGrid.Padding         = [2 2 2 2];
waveGrid.BackgroundColor = 'w';

waveAx = uiaxes(waveGrid, ...
    'XLim',   params.epoch_window_ms, ...
    'YLim',   [-3 3], ...
    'Box',    'on', ...
    'FontSize', 11);
waveAx.Layout.Row    = 1;
waveAx.Layout.Column = 1;
xlabel(waveAx, 'Time (ms)');
ylabel(waveAx, 'Amplitude (µV)');
hold(waveAx, 'on');

avgLine  = plot(waveAx, NaN, NaN, ...
    'Color', [0.11 0.62 0.46], 'LineWidth', 1.8);
prevLine = plot(waveAx, NaN, NaN, ...
    'Color', [0.75 0.75 0.75], 'LineWidth', 1.0, 'LineStyle', '--');

% Noise panel
noisePanel = uipanel(leftGrid, ...
    'BorderType',      'line', ...
    'Title',           'Noise floor', ...
    'BackgroundColor', 'w');
noisePanel.Layout.Row    = 2;
noisePanel.Layout.Column = 1;

noiseGrid = uigridlayout(noisePanel, [1 4]);
noiseGrid.ColumnWidth    = {110, 90, 110, '1x'};
noiseGrid.Padding        = [10 4 10 4];
noiseGrid.ColumnSpacing  = 20;
noiseGrid.BackgroundColor = 'w';

noiseLbl = uilabel(noiseGrid, ...
    'Text',       '— µV', ...
    'FontSize',   20, ...
    'FontWeight', 'bold');
noiseLbl.Layout.Row    = 1;
noiseLbl.Layout.Column = 1;

makeNoiseChip(noiseGrid, 'Rejected',        '0',   2);
makeNoiseChip(noiseGrid, 'Threshold (µV)',  '—',   3);
makeNoiseChip(noiseGrid, 'Artifact reject', 'Off', 4);

%% --- Right col: previous waveforms ---

prevPanel = uipanel(plotGrid, ...
    'BorderType',      'line', ...
    'Title',           'Previous', ...
    'BackgroundColor', 'w');
prevPanel.Layout.Row    = 1;
prevPanel.Layout.Column = 2;

prevGrid = uigridlayout(prevPanel, [1 1]);
prevGrid.Padding         = [4 4 4 4];
prevGrid.BackgroundColor = 'w';

prevAx = uiaxes(prevGrid, ...
    'XTick',  [], ...
    'YTick',  [], ...
    'Box',    'on', ...
    'XLim',   params.epoch_window_ms);
prevAx.Layout.Row    = 1;
prevAx.Layout.Column = 1;
xlabel(prevAx, 'Time (ms)');

%% ================================================================
%  CALLBACKS
%% ================================================================

    function onRun()
        params     = readParamsFromGui();
        err        = abr_validate_params(params);
        if ~isempty(err)
            uialert(fig, err, 'Invalid parameters');
            return
        end

        state.running  = true;
        state.stop_req = false;
        setRunning(true);

        n_samples = round(diff(params.epoch_window_ms) / 1000 * params.fs);
        t_epoch   = linspace(params.epoch_window_ms(1), ...
                             params.epoch_window_ms(2), n_samples);

        data.epochs   = zeros(params.n_reps, n_samples, length(params.levels_dbspl));
        data.average  = zeros(n_samples, length(params.levels_dbspl));
        data.stimulus = [];
        data.fs       = params.fs;

        %% Level loop
        for lev_idx = 1:length(params.levels_dbspl)
            if state.stop_req; break; end

            this_level = params.levels_dbspl(lev_idx);

            running_sum  = zeros(n_samples, 1);
            rep_accepted = 0;
            n_rejected   = 0;

            wavePanel.Title = sprintf('Running average — %d Hz, %d dB SPL', ...
                params.frequency_hz, this_level);

            updateStatus(sprintf('Level %d / %d — %d dB SPL — starting...', ...
                lev_idx, length(params.levels_dbspl), this_level));

            % Show previous average faintly if available
            if lev_idx > 1
                set(prevLine, ...
                    'XData', t_epoch, ...
                    'YData', data.average(:, lev_idx-1) * 1e6);
            end
            set(avgLine, 'XData', NaN, 'YData', NaN);

            %% Rep loop
            for rep = 1:params.n_reps
                if state.stop_req; break; end

                % STUB: replace with tdt_abr_play_record()
                epoch_raw = randn(n_samples, 1) * 0.3e-6;
                pause(0.001);   % remove when real TDT calls are in
               
                % Artifact rejection
                rejected = false;
                if params.artifact_reject
                    if max(abs(epoch_raw)) > params.artifact_thresh_v
                        rejected  = true;
                        n_rejected = n_rejected + 1;
                    end
                end

                if ~rejected
                    rep_accepted = rep_accepted + 1;
                    running_sum  = running_sum + epoch_raw;
                    data.epochs(rep_accepted, :, lev_idx) = epoch_raw;
                end

                % Update display every 25 reps
                if mod(rep, 25) == 0 && rep_accepted > 0
                    current_avg = running_sum / rep_accepted;
                    set(avgLine, 'XData', t_epoch, 'YData', current_avg * 1e6);

                    noise_rms     = std(epoch_raw) * 1e6;
                    noiseLbl.Text = sprintf('%.2f µV', noise_rms);

                    updateStatus(sprintf(...
                        'Level %d / %d — %d dB SPL — rep %d / %d  |  rejected: %d', ...
                        lev_idx, length(params.levels_dbspl), ...
                        this_level, rep, params.n_reps, n_rejected));
                    drawnow;
                end

            end   % rep loop

            % Store final average for this level
            if rep_accepted > 0
                final_avg = running_sum / rep_accepted;
                data.average(:, lev_idx) = final_avg;
                addPrevWaveform(t_epoch, final_avg * 1e6, this_level, params.frequency_hz);
            end

        end   % level loop

        % Save
        if any(data.average(:) ~= 0)
            sess.saveRun(params, data);
        end

        state.running = false;
        setRunning(false);
        wavePanel.Title = 'Running average';
        updateStatus(sprintf('Done. Run #%03d saved.', sess.RunCount));
    end

    function onStop()
        state.stop_req = true;
        updateStatus('Stopping after this rep...');
    end

    function onEarCal()
        uialert(fig, 'Ear cal not yet implemented.', 'Coming soon');
    end

    function onSettings()
        uialert(fig, 'Settings not yet implemented.', 'Coming soon');
    end

    function onCloseRequest()
        % if state.running
        %     uialert(fig, ...
        %         'Stop data collection before quitting.', ...
        %         'Cannot quit');
        %     return
        % end
        sel = uiconfirm(fig, ...
            'End this session and close ABR?', ...
            'Quit ABR', ...
            'Options',       {'Quit', 'Cancel'}, ...
            'DefaultOption', 2, ...
            'CancelOption',  2);
        if strcmp(sel, 'Quit')
            delete(fig);
        end
    end

%% ================================================================
%  NESTED HELPERS
%% ================================================================

    function p = readParamsFromGui()
        p = abr_default_params();
        p.stim_type     = lower(strrep(stimTypeDrop.Value, ' ', ''));
        p.frequency_hz  = str2double(freqField.Value);
        p.ear           = lower(earDrop.Value);
        p.polarity      = lower(polarityDrop.Value);
        p.levels_dbspl  = str2num(levelsField.Value); %#ok<ST2NM>
        p.n_reps        = round(str2double(repsField.Value));
        p.rate_hz       = str2double(rateField.Value);
        p.duration_ms   = str2double(durField.Value);
        p.rise_fall_ms  = str2double(riseField.Value);

        switch earCalDrop.Value
            case 'None'
                p.apply_ear_cal = false;
            case 'File...'
                [f, pth] = uigetfile('*.mat', 'Select ear cal file');
                if isequal(f, 0)
                    p.apply_ear_cal = false;
                else
                    p.apply_ear_cal = true;
                    p.ear_cal_file  = fullfile(pth, f);
                end
            otherwise
                p.apply_ear_cal = true;
                p.ear_cal_file  = '';
        end
    end

    function updateStatus(msg)
        statusBar.Text = msg;
    end

    function setRunning(tf)
        if tf
            runBtn.Enable       = 'off';
            stopBtn.Enable      = 'on';
            statusLbl.Text      = '● Running';
            statusLbl.FontColor = [0.11 0.62 0.46];
        else
            runBtn.Enable       = 'on';
            stopBtn.Enable      = 'off';
            statusLbl.Text      = '● Idle';
            statusLbl.FontColor = [0.5 0.5 0.5];
        end
    end

    function addPrevWaveform(t, avg_uv, level_dbspl, freq_hz)
        n = length(prevAxes) + 1;
        prevAxes{n} = struct('t', t, 'avg', avg_uv, ...
            'level', level_dbspl, 'freq', freq_hz);

        cla(prevAx);
        hold(prevAx, 'on');
        for i = 1:n
            offset = (n - i) * 6;
            plot(prevAx, prevAxes{i}.t, prevAxes{i}.avg + offset, ...
                'Color', [0.22 0.54 0.85], 'LineWidth', 1);
            text(prevAx, t(end) + 0.2, offset, ...
                sprintf('%d dB', prevAxes{i}.level), ...
                'FontSize', 8, 'Color', [0.4 0.4 0.4]);
        end
        hold(prevAx, 'off');
        prevAx.YTick = [];
        prevAx.XLim  = [t(1) t(end)];
        drawnow;
    end

end   % abr_gui

%% ================================================================
%  LOCAL FUNCTIONS
%% ================================================================

function makeInfoChip(parent, labelStr, valueStr, col)
    p = uipanel(parent, 'BorderType', 'none', 'BackgroundColor', 'w');
    p.Layout.Row    = 1;
    p.Layout.Column = col;
    g = uigridlayout(p, [2 1]);
    g.RowHeight      = {'1x', '1x'};
    g.Padding        = [0 2 0 2];
    g.RowSpacing     = 0;
    g.BackgroundColor = 'w';
    lbl = uilabel(g, 'Text', labelStr, 'FontSize', 9, ...
        'FontColor', [0.55 0.55 0.55]);
    lbl.Layout.Row    = 1;
    lbl.Layout.Column = 1;
    val = uilabel(g, 'Text', valueStr, 'FontSize', 12, 'FontWeight', 'bold');
    val.Layout.Row    = 2;
    val.Layout.Column = 1;
end

function field = makeField(parent, labelStr, row, col, type, default)
    p = uipanel(parent, 'BorderType', 'none', 'BackgroundColor', 'w');
    p.Layout.Row    = row;
    p.Layout.Column = col;
    g = uigridlayout(p, [2 1]);
    g.RowHeight       = {16, '1x'};
    g.Padding         = [0 0 0 0];
    g.RowSpacing      = 2;
    g.BackgroundColor = 'w';
    lbl = uilabel(g, 'Text', labelStr, 'FontSize', 10, ...
        'FontColor', [0.45 0.45 0.45]);
    lbl.Layout.Row    = 1;
    lbl.Layout.Column = 1;
    switch type
        case 'edit'
            field = uieditfield(g, 'text', 'Value', default);
        case 'drop'
            field = uidropdown(g, 'Items', default);
    end
    field.Layout.Row    = 2;
    field.Layout.Column = 1;
end

function makeNoiseChip(parent, labelStr, valueStr, col)
    p = uipanel(parent, 'BorderType', 'none', 'BackgroundColor', 'w');
    p.Layout.Row    = 1;
    p.Layout.Column = col;
    g = uigridlayout(p, [2 1]);
    g.RowHeight       = {'1x', '1x'};
    g.Padding         = [0 0 0 0];
    g.RowSpacing      = 2;
    g.BackgroundColor = 'w';
    lbl = uilabel(g, 'Text', labelStr, 'FontSize', 9, ...
        'FontColor', [0.55 0.55 0.55]);
    lbl.Layout.Row    = 1;
    lbl.Layout.Column = 1;
    val = uilabel(g, 'Text', valueStr, 'FontSize', 13, 'FontWeight', 'bold');
    val.Layout.Row    = 2;
    val.Layout.Column = 1;
end

function txt = calBadgeText(name, cal)
    if isempty(cal)
        txt = sprintf('%s — none', name);
    else
        txt = sprintf('%s ✓', name);
    end
end

function c = calBadgeColor(cal)
    if isempty(cal)
        c = [1.0 0.95 0.88];
    else
        c = [0.88 0.96 0.93];
    end
end

function c = calBadgeFontColor(cal)
    if isempty(cal)
        c = [0.52 0.31 0.05];
    else
        c = [0.07 0.39 0.28];
    end
end