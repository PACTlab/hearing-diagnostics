function ear_cal_gui()
% EAR_CAL_GUI  In-ear calibration GUI.
% Requires an active session. Saves result to session folder and
% loads filter into session automatically.

%% --- Session ---

[save_dir, metadata] = session_load_or_create();
if isempty(save_dir)
    return
end

%% --- Config and hardware ---

cfg         = config_load();
tdt         = tdt_init(cfg, 'ear_cal');
transducers = cal_transducer_registry('load');
params      = ear_cal_default_params();

%% --- State ---

state.running   = false;
state.stop_req  = false;
state.stub_mode = isempty(tdt);

current_result  = [];

%% --- Figure ---

fig = uifigure(...
    'Name',            sprintf('Ear Cal — %s', metadata.subject_id), ...
    'Position',        [100 100 800 620], ...
    'CloseRequestFcn', @(~,~) onClose());

mainGrid = uigridlayout(fig, [5 1]);
mainGrid.RowHeight   = {52, 50, 36, '1x', 28};
mainGrid.Padding     = [10 10 10 10];
mainGrid.RowSpacing  = 6;

%% --- Row 1: Subject bar ---

subjectPanel = uipanel(mainGrid, ...
    'BorderType', 'line', 'BackgroundColor', 'w');
subjectPanel.Layout.Row    = 1;
subjectPanel.Layout.Column = 1;

subGrid = uigridlayout(subjectPanel, [1 5]);
subGrid.ColumnWidth     = {80, 100, 100, 100, '1x'};
subGrid.Padding         = [10 6 10 6];
subGrid.ColumnSpacing   = 12;
subGrid.BackgroundColor = 'w';

makeInfoChip(subGrid, 'Subject',  metadata.subject_id, 1);
makeInfoChip(subGrid, 'Species',  metadata.species,    2);
makeInfoChip(subGrid, 'Operator', metadata.operator,   3);
makeInfoChip(subGrid, 'Date',     metadata.date,       4);

if state.stub_mode
    stubLbl = uilabel(subGrid, ...
        'Text',                '⚠ STUB MODE', ...
        'FontSize',            11, ...
        'FontWeight',          'bold', ...
        'HorizontalAlignment', 'center', ...
        'BackgroundColor',     [0.85 0.20 0.10], ...
        'FontColor',           [1.0 1.0 1.0]);
    stubLbl.Layout.Row    = 1;
    stubLbl.Layout.Column = 5;
end

%% --- Row 2: Controls ---

ctrlPanel = uipanel(mainGrid, ...
    'BorderType', 'line', 'BackgroundColor', 'w');
ctrlPanel.Layout.Row    = 2;
ctrlPanel.Layout.Column = 1;

ctrlGrid = uigridlayout(ctrlPanel, [1 6]);
ctrlGrid.ColumnWidth     = {'2x', '1x', '1x', 80, 80, 80};
ctrlGrid.Padding         = [8 6 8 6];
ctrlGrid.ColumnSpacing   = 8;
ctrlGrid.BackgroundColor = 'w';

% Transducer dropdown
transducer_names = getTransducerNames(transducers);
transducerDrop = uidropdown(ctrlGrid, 'Items', transducer_names);
transducerDrop.Layout.Row    = 1;
transducerDrop.Layout.Column = 1;

% Channel dropdown
channelDrop = uidropdown(ctrlGrid, ...
    'Items', {'Ch 1 (Left)', 'Ch 2 (Right)', 'Both'});
channelDrop.Layout.Row    = 1;
channelDrop.Layout.Column = 2;

% Method dropdown
methodDrop = uidropdown(ctrlGrid, ...
    'Items', {'Automated', 'Manual'});
methodDrop.Layout.Row    = 1;
methodDrop.Layout.Column = 3;

% Run/Stop/Load buttons
runBtn = uibutton(ctrlGrid, ...
    'Text',            '▶  Start', ...
    'BackgroundColor', [0.11 0.62 0.46], ...
    'FontColor',       [0.88 0.96 0.93], ...
    'FontWeight',      'bold', ...
    'ButtonPushedFcn', @(~,~) onRun());
runBtn.Layout.Row    = 1;
runBtn.Layout.Column = 4;

stopBtn = uibutton(ctrlGrid, ...
    'Text',            '■  Stop', ...
    'BackgroundColor', [0.85 0.35 0.18], ...
    'FontColor',       [0.98 0.92 0.89], ...
    'FontWeight',      'bold', ...
    'Enable',          'off', ...
    'ButtonPushedFcn', @(~,~) onStop());
stopBtn.Layout.Row    = 1;
stopBtn.Layout.Column = 5;

loadBtn = uibutton(ctrlGrid, ...
    'Text',            'Load existing', ...
    'ButtonPushedFcn', @(~,~) onLoadExisting());
loadBtn.Layout.Row    = 1;
loadBtn.Layout.Column = 6;

%% --- Row 3: Status ---

statusBar = uilabel(mainGrid, ...
    'Text',      'Ready. Probe in ear before starting.', ...
    'FontSize',  11, ...
    'FontColor', [0.4 0.4 0.4]);
statusBar.Layout.Row    = 3;
statusBar.Layout.Column = 1;

%% --- Row 4: Plot ---

plotPanel = uipanel(mainGrid, ...
    'BorderType', 'line', 'BackgroundColor', 'w');
plotPanel.Layout.Row    = 4;
plotPanel.Layout.Column = 1;

plotGrid = uigridlayout(plotPanel, [1 2]);
plotGrid.ColumnWidth    = {'1x', '1x'};
plotGrid.Padding        = [4 4 4 4];
plotGrid.ColumnSpacing  = 6;
plotGrid.BackgroundColor = 'w';

% Left — measured response
axResp = uiaxes(plotGrid, 'XScale', 'log', 'Box', 'on', 'FontSize', 10);
axResp.Layout.Row    = 1;
axResp.Layout.Column = 1;
xlabel(axResp, 'Frequency (Hz)');
ylabel(axResp, 'Level (dB SPL)');
title(axResp, 'Measured response');
xlim(axResp, [params.freq_min_hz params.freq_max_hz]);
hold(axResp, 'on');
grid(axResp, 'on');

ch1_resp = plot(axResp, NaN, NaN, ...
    'Color', [0.10 0.15 0.45], 'LineWidth', 1.8, 'DisplayName', 'Ch1');
ch2_resp = plot(axResp, NaN, NaN, ...
    'Color', [0.55 0.05 0.10], 'LineWidth', 1.8, ...
    'LineStyle', '--', 'DisplayName', 'Ch2');
legend(axResp, 'Location', 'best');

% Right — filter frequency response
axFilt = uiaxes(plotGrid, 'XScale', 'log', 'Box', 'on', 'FontSize', 10);
axFilt.Layout.Row    = 1;
axFilt.Layout.Column = 2;
xlabel(axFilt, 'Frequency (Hz)');
ylabel(axFilt, 'Gain (dB)');
title(axFilt, 'Correction filter response');
xlim(axFilt, [params.freq_min_hz params.freq_max_hz]);
hold(axFilt, 'on');
grid(axFilt, 'on');

ch1_filt = plot(axFilt, NaN, NaN, ...
    'Color', [0.10 0.15 0.45], 'LineWidth', 1.8, 'DisplayName', 'Ch1 filter');
ch2_filt = plot(axFilt, NaN, NaN, ...
    'Color', [0.55 0.05 0.10], 'LineWidth', 1.8, ...
    'LineStyle', '--', 'DisplayName', 'Ch2 filter');
legend(axFilt, 'Location', 'best');

%% --- Row 5: Progress ---

progressLbl = uilabel(mainGrid, ...
    'Text',      '', ...
    'FontSize',  10, ...
    'FontColor', [0.4 0.4 0.4], ...
    'HorizontalAlignment', 'center');
progressLbl.Layout.Row    = 5;
progressLbl.Layout.Column = 1;

%% ================================================================
%  CALLBACKS
%% ================================================================

    function onRun()
        if isempty(transducers) || ...
                strcmp(transducerDrop.Value, 'No transducers registered')
            uialert(fig, 'No transducer selected.', 'No transducer');
            return
        end

        selected_transducer = cal_transducer_registry('get', ...
            transducers, transducerDrop.Value);

        params.method = lower(methodDrop.Value);
        params.ear    = getChannelParam(channelDrop.Value);

        state.running  = true;
        state.stop_req = false;
        setRunning(true);

        cbs.update_status = @(msg) updateStatus(msg);
        cbs.should_stop   = @()    state.stop_req;

        try
            if strcmp(params.ear, 'both')
                % Ch1 first
                params_ch1     = params;
                params_ch1.ear = 'ch1';
                cbs.update_plot = @(f, db) updatePlot(f, db, 'ch1');
                [res_ch1, metadata] = ear_cal_run(params_ch1, ...
                    selected_transducer, tdt, save_dir, metadata, cbs);
                plotFilter(res_ch1, 'ch1');

                if ~state.stop_req
                    % Ch2 second
                    params_ch2     = params;
                    params_ch2.ear = 'ch2';
                    cbs.update_plot = @(f, db) updatePlot(f, db, 'ch2');
                    [res_ch2, metadata] = ear_cal_run(params_ch2, ...
                        selected_transducer, tdt, save_dir, metadata, cbs);
                    plotFilter(res_ch2, 'ch2');
                    current_result = res_ch2;
                end

            else
                cbs.update_plot = @(f, db) updatePlot(f, db, params.ear);
                [current_result, metadata] = ear_cal_run(params, ...
                    selected_transducer, tdt, save_dir, metadata, cbs);
                plotFilter(current_result, params.ear);
            end

        catch e
            state.running = false;
            setRunning(false);
            uialert(fig, e.message, 'Ear cal error');
            return
        end

        state.running = false;
        setRunning(false);
        updateStatus('Ear cal complete. Filter loaded into session.');
    end

    function onStop()
        state.stop_req = true;
        updateStatus('Stopping...');
    end

    function onLoadExisting()
        % Let user pick an existing ear cal file from this session
        start_path = save_dir;
        [f, p]     = uigetfile(fullfile(start_path, '*.mat'), ...
            'Select ear cal file');
        if isequal(f, 0); return; end

        filepath = fullfile(p, f);
        loaded   = load(filepath);

        if ~isfield(loaded, 'run') || ~isfield(loaded.run, 'data') || ...
                ~isfield(loaded.run.data, 'filter_b')
            uialert(fig, 'Selected file is not a valid ear cal file.', ...
                'Invalid file');
            return
        end

        % Plot and confirm
        result.filter_b     = loaded.run.data.filter_b;
        result.frequency_hz = loaded.run.data.frequency_hz;
        result.db_spl       = loaded.run.data.db_spl;
        result.channel      = loaded.run.params.ear;

        updatePlot(result.frequency_hz, result.db_spl, result.channel);
        plotFilter(result, result.channel);

        current_result = result;
        updateStatus(sprintf('Loaded ear cal from: %s', f));
    end

    function onClose()
        if state.running
            uialert(fig, 'Stop before closing.', 'Cannot close');
            return
        end
        if ~isempty(tdt)
            tdt_close(tdt);
        end
        delete(fig);
    end

%% ================================================================
%  NESTED HELPERS
%% ================================================================

    function updateStatus(msg)
        statusBar.Text = msg;
        fprintf('%s\n', msg);
    end

    function updatePlot(freqs, db_spl, channel)
        switch channel
            case 'ch1'
                set(ch1_resp, 'XData', freqs, 'YData', db_spl);
            case 'ch2'
                set(ch2_resp, 'XData', freqs, 'YData', db_spl);
        end
        n = length(freqs);
        progressLbl.Text = sprintf('%d / %d frequencies complete', ...
            n, params.freq_n_points);
        drawnow limitrate;
    end

    function plotFilter(result, channel)
        % Compute and plot filter frequency response
        [H, W] = freqz(result.filter_b, 1, 2056, params.fs);
        H_db   = 20 * log10(abs(H) + eps);

        switch channel
            case 'ch1'
                set(ch1_filt, 'XData', W, 'YData', H_db);
            case 'ch2'
                set(ch2_filt, 'XData', W, 'YData', H_db);
        end
        drawnow;
    end

    function setRunning(tf)
        if tf
            runBtn.Enable  = 'off';
            stopBtn.Enable = 'on';
        else
            runBtn.Enable  = 'on';
            stopBtn.Enable = 'off';
        end
    end

end   % ear_cal_gui

%% ================================================================
%  LOCAL FUNCTIONS
%% ================================================================

function names = getTransducerNames(transducers)
    if isempty(transducers)
        names = {'No transducers registered'};
    else
        names = {transducers.display_name};
    end
end

function ch = getChannelParam(dropdown_value)
    switch dropdown_value
        case 'Ch 1 (Left)';  ch = 'ch1';
        case 'Ch 2 (Right)'; ch = 'ch2';
        otherwise;           ch = 'both';
    end
end

function makeInfoChip(parent, labelStr, valueStr, col)
    p = uipanel(parent, 'BorderType', 'none', 'BackgroundColor', 'w');
    p.Layout.Row    = 1;
    p.Layout.Column = col;
    g = uigridlayout(p, [2 1]);
    g.RowHeight       = {'1x', '1x'};
    g.Padding         = [0 2 0 2];
    g.RowSpacing      = 0;
    g.BackgroundColor = 'w';
    lbl = uilabel(g, 'Text', labelStr, 'FontSize', 9, ...
        'FontColor', [0.55 0.55 0.55]);
    lbl.Layout.Row    = 1;
    lbl.Layout.Column = 1;
    val = uilabel(g, 'Text', valueStr, 'FontSize', 12, 'FontWeight', 'bold');
    val.Layout.Row    = 2;
    val.Layout.Column = 1;
end