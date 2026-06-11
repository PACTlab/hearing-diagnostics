function transducer_check_gui()
% TRANSDUCER_CHECK_GUI  Transducer frequency response check.
% No session required. Results saved to calibration/data/probe_checks/.

%% --- Load config and registry ---

cfg         = config_load();
tdt         = tdt_init(cfg, 'transducer_check');
transducers = cal_transducer_registry('load');
params      = transducer_check_default_params();

%% --- State ---

state.running   = false;
state.stop_req  = false;
state.stub_mode = isempty(tdt);

current_result  = [];   % most recent sweep result
current_channel = [];   % which channel was just run

%% --- Figure ---

fig = uifigure(...
    'Name',            'Transducer Check', ...
    'Position',        [100 100 800 600], ...
    'CloseRequestFcn', @(~,~) onClose());

mainGrid = uigridlayout(fig, [4 1]);
mainGrid.RowHeight   = {50, 36, '1x', 28};
mainGrid.Padding     = [10 10 10 10];
mainGrid.RowSpacing  = 6;

%% --- Row 1: Controls ---

ctrlPanel = uipanel(mainGrid, ...
    'BorderType', 'line', 'BackgroundColor', 'w');
ctrlPanel.Layout.Row    = 1;
ctrlPanel.Layout.Column = 1;

ctrlGrid = uigridlayout(ctrlPanel, [1 7]);
ctrlGrid.ColumnWidth     = {'2x', 80, '1x', '1x', 80, 80, 80};
ctrlGrid.Padding         = [8 6 8 6];
ctrlGrid.ColumnSpacing   = 8;
ctrlGrid.BackgroundColor = 'w';

% Transducer dropdown
transducer_names = getTransducerNames(transducers);
transducerDrop = uidropdown(ctrlGrid, ...
    'Items', transducer_names);
transducerDrop.Layout.Row    = 1;
transducerDrop.Layout.Column = 1;

% Register new button
registerBtn = uibutton(ctrlGrid, ...
    'Text',            'Register new', ...
    'ButtonPushedFcn', @(~,~) onRegisterNew());
registerBtn.Layout.Row    = 1;
registerBtn.Layout.Column = 2;

% Channel dropdown
channelDrop = uidropdown(ctrlGrid, ...
    'Items', {'Ch 1 (Left)', 'Ch 2 (Right)', 'Both'});
channelDrop.Layout.Row    = 1;
channelDrop.Layout.Column = 3;

% Method dropdown
methodDrop = uidropdown(ctrlGrid, ...
    'Items', {'Automated', 'Manual'});
methodDrop.Layout.Row    = 1;
methodDrop.Layout.Column = 4;

% Run/Stop buttons
runBtn = uibutton(ctrlGrid, ...
    'Text',            '▶  Start', ...
    'BackgroundColor', [0.11 0.62 0.46], ...
    'FontColor',       [0.88 0.96 0.93], ...
    'FontWeight',      'bold', ...
    'ButtonPushedFcn', @(~,~) onRun());
runBtn.Layout.Row    = 1;
runBtn.Layout.Column = 5;

stopBtn = uibutton(ctrlGrid, ...
    'Text',            '■  Stop', ...
    'BackgroundColor', [0.85 0.35 0.18], ...
    'FontColor',       [0.98 0.92 0.89], ...
    'FontWeight',      'bold', ...
    'Enable',          'off', ...
    'ButtonPushedFcn', @(~,~) onStop());
stopBtn.Layout.Row    = 1;
stopBtn.Layout.Column = 6;

% Save as reference button — only enabled after sweep
saveRefBtn = uibutton(ctrlGrid, ...
    'Text',   'Save as reference', ...
    'Enable', 'off', ...
    'ButtonPushedFcn', @(~,~) onSaveReference());
saveRefBtn.Layout.Row    = 1;
saveRefBtn.Layout.Column = 7;

%% --- Row 2: Status bar ---

statusBar = uilabel(mainGrid, ...
    'Text',      'Ready.', ...
    'FontSize',  11, ...
    'FontColor', [0.4 0.4 0.4]);
statusBar.Layout.Row    = 2;
statusBar.Layout.Column = 1;

%% --- Row 3: Plot ---

plotPanel = uipanel(mainGrid, ...
    'BorderType', 'line', 'BackgroundColor', 'w');
plotPanel.Layout.Row    = 3;
plotPanel.Layout.Column = 1;

plotGrid = uigridlayout(plotPanel, [1 1]);
plotGrid.Padding         = [4 4 4 4];
plotGrid.BackgroundColor = 'w';

ax = uiaxes(plotGrid, ...
    'XScale',  'log', ...
    'Box',     'on', ...
    'FontSize', 11);
ax.Layout.Row    = 1;
ax.Layout.Column = 1;
xlabel(ax, 'Frequency (Hz)');
ylabel(ax, 'Level (dB SPL)');
title(ax, 'Transducer frequency response');
xlim(ax, [params.freq_min_hz params.freq_max_hz]);
hold(ax, 'on');
grid(ax, 'on');

% Plot lines — initialized empty
ref_patch   = [];    % grey ±3dB band around reference
ref_line    = [];    % reference center line
ch1_line    = plot(ax, NaN, NaN, ...
    'Color', [0.10 0.15 0.45], 'LineWidth', 1.8, ...
    'DisplayName', 'Ch1 current');
ch2_line    = plot(ax, NaN, NaN, ...
    'Color', [0.55 0.05 0.10], 'LineWidth', 1.8, ...
    'LineStyle', '-', 'DisplayName', 'Ch2 current');
flag_scatter = scatter(ax, NaN, NaN, 60, 'r', 'filled', ...
    'DisplayName', '>3dB deviation');

legend(ax, 'Location', 'best');

%% --- Row 4: Progress ---

progressLbl = uilabel(mainGrid, ...
    'Text',      '', ...
    'FontSize',  10, ...
    'FontColor', [0.4 0.4 0.4], ...
    'HorizontalAlignment', 'center');
progressLbl.Layout.Row    = 4;
progressLbl.Layout.Column = 1;

%% ================================================================
%  CALLBACKS
%% ================================================================

    function onRun()
        % Read GUI params
        params.method = lower(methodDrop.Value);
        params.ear    = getChannelParam(channelDrop.Value);

        % Get selected transducer
        if isempty(transducers) || ...
                strcmp(transducerDrop.Value, 'No transducers registered')
            uialert(fig, ...
                'No transducer selected. Register one first.', ...
                'No transducer');
            return
        end
        selected_transducer = cal_transducer_registry('get', ...
            transducers, transducerDrop.Value);

        state.running  = true;
        state.stop_req = false;
        setRunning(true);
        saveRefBtn.Enable = 'off';

        % Load reference if exists
        loadAndPlotReference(selected_transducer, params.ear);

        % Build callbacks
        cbs.update_status = @(msg)        updateStatus(msg);
        cbs.should_stop   = @()           state.stop_req;

        try
            if strcmp(params.ear, 'both')
                % Run ch1 first then ch2
                params_ch1     = params;
                params_ch1.ear = 'ch1';
                cbs.update_plot = @(f, db) updatePlot(f, db, 'ch1');
                result_ch1 = transducer_check_run(...
                    params_ch1, selected_transducer, tdt, cbs);
                saveAndCheckResult(result_ch1, selected_transducer);

                if ~state.stop_req
                    params_ch2     = params;
                    params_ch2.ear = 'ch2';
                    cbs.update_plot = @(f, db) updatePlot(f, db, 'ch2');
                    result_ch2 = transducer_check_run(...
                        params_ch2, selected_transducer, tdt, cbs);
                    saveAndCheckResult(result_ch2, selected_transducer);
                end

                current_result  = result_ch2;
                current_channel = 'both';

            else
                cbs.update_plot = @(f, db) updatePlot(f, db, params.ear);
                current_result  = transducer_check_run(...
                    params, selected_transducer, tdt, cbs);
                current_channel = params.ear;
                saveAndCheckResult(current_result, selected_transducer);
            end

        catch e
            state.running = false;
            setRunning(false);
            uialert(fig, e.message, 'Sweep error');
            return
        end

        state.running     = false;
        setRunning(false);
        saveRefBtn.Enable = 'on';
        updateStatus('Sweep complete. Save as reference if this is a new baseline.');
    end

    function onStop()
        state.stop_req = true;
        updateStatus('Stopping...');
    end

    function onSaveReference()
        if isempty(current_result)
            return
        end
        selected_transducer = cal_transducer_registry('get', ...
            transducers, transducerDrop.Value);

        if strcmp(current_channel, 'both')
            % Would need both results stored — simplified for now
            uialert(fig, ...
                ['Run individual channels to save separate references. ' ...
                 'Run ch1 first, save reference, then ch2.'], ...
                'Save reference');
            return
        end

        saveReference(current_result, selected_transducer);
        updateStatus(sprintf('Reference saved for %s %s.', ...
            selected_transducer.display_name, current_channel));

        % Reload and replot reference
        loadAndPlotReference(selected_transducer, current_channel);
    end

    function onRegisterNew()
        new_transducer = showRegisterDialog();
        if isempty(new_transducer)
            return
        end
        try
            transducers = cal_transducer_registry('add', ...
                transducers, new_transducer);
            % Refresh dropdown
            transducerDrop.Items = getTransducerNames(transducers);
            transducerDrop.Value = new_transducer.display_name;
            updateStatus(sprintf('Registered: %s', new_transducer.display_name));
        catch e
            uialert(fig, e.message, 'Registration error');
        end
    end

    function onClose()
        if state.running
            uialert(fig, 'Stop the sweep before closing.', 'Cannot close');
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
                set(ch1_line, 'XData', freqs, 'YData', db_spl);
            case 'ch2'
                set(ch2_line, 'XData', freqs, 'YData', db_spl);
        end

        n = length(freqs);
        progressLbl.Text = sprintf('%d / %d frequencies complete', ...
            n, params.freq_n_points);
        drawnow limitrate;
    end

    function loadAndPlotReference(transducer_entry, channel)
        % Load and plot reference if it exists for this channel
        if strcmp(channel, 'both')
            loadAndPlotReference(transducer_entry, 'ch1');
            loadAndPlotReference(transducer_entry, 'ch2');
            return
        end

        ref_path = getReferencePath(transducer_entry, channel);
        if ~exist(ref_path, 'file')
            updateStatus(sprintf('No reference found for %s %s.', ...
                transducer_entry.display_name, channel));
            return
        end

        loaded   = load(ref_path);
        ref      = loaded.reference;

        % Plot ±3dB band as grey patch
        if ~isempty(ref_patch)
            delete(ref_patch);
        end
        if ~isempty(ref_line)
            delete(ref_line);
        end

        f    = ref.frequency_hz;
        db   = ref.db_spl;
        ref_patch = fill(ax, [f fliplr(f)], ...
            [db+3 fliplr(db-3)], ...
            [0.8 0.8 0.8], ...
            'FaceAlpha', 0.4, ...
            'EdgeColor', 'none', ...
            'DisplayName', sprintf('Reference ±3dB (%s)', ref.date));
        ref_line  = plot(ax, f, db, ...
            'Color',     [0.6 0.6 0.6], ...
            'LineWidth', 1.2, ...
            'LineStyle', ':', ...
            'DisplayName', sprintf('Reference (%s)', ref.date));
        legend(ax, 'Location', 'best');
    end

    function saveAndCheckResult(result, transducer_entry)
        % Save dated record
        saveRecord(result, transducer_entry);

        % Check against reference
        ref_path = getReferencePath(transducer_entry, result.channel);
        if ~exist(ref_path, 'file')
            updateStatus(sprintf(...
                '%s complete. No reference to compare — save as reference?', ...
                result.channel));
            return
        end

        loaded    = load(ref_path);
        ref       = loaded.reference;
        deviation = result.db_spl - ref.db_spl;
        bad_freqs = result.frequency_hz(abs(deviation) > params.deviation_thresh_db);

        % Plot flagged frequencies
        if ~isempty(bad_freqs)
            bad_db = result.db_spl(abs(deviation) > params.deviation_thresh_db);
            set(flag_scatter, 'XData', bad_freqs, 'YData', bad_db);
            updateStatus(sprintf(...
                'WARNING: %d frequencies exceed %.0f dB threshold — check transducer.', ...
                length(bad_freqs), params.deviation_thresh_db));
        else
            updateStatus(sprintf('%s: PASS — within %.0f dB of reference.', ...
                result.channel, params.deviation_thresh_db));
        end
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

end   % transducer_check_gui

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

function p = getReferencePath(transducer_entry, channel)
    cal_dir  = fileparts(mfilename('fullpath'));
    ref_dir  = fullfile(cal_dir, '..', '..', 'calibration', ...
                        'data', 'probe_checks', 'references');
    ref_dir  = char(java.io.File(ref_dir).getCanonicalPath());
    safe_name = regexprep(transducer_entry.display_name, '[^a-zA-Z0-9_]', '_');
    p         = fullfile(ref_dir, sprintf('%s_reference_%s.mat', ...
                    safe_name, channel));
end

function saveReference(result, transducer_entry)
    ref_path = getReferencePath(transducer_entry, result.channel);
    ref_dir  = fileparts(ref_path);
    if ~exist(ref_dir, 'dir'); mkdir(ref_dir); end

    reference.frequency_hz    = result.frequency_hz;
    reference.db_spl          = result.db_spl;
    reference.channel         = result.channel;
    reference.date            = result.date;
    reference.transducer      = result.transducer;
    reference.method          = result.method;

    save(ref_path, 'reference');
    fprintf('Reference saved: %s\n', ref_path);
end

function saveRecord(result, transducer_entry)
    cal_dir    = fileparts(mfilename('fullpath'));
    rec_dir    = fullfile(cal_dir, '..', '..', 'calibration', ...
                          'data', 'probe_checks', 'records');
    rec_dir    = char(java.io.File(rec_dir).getCanonicalPath());
    if ~exist(rec_dir, 'dir'); mkdir(rec_dir); end

    safe_name  = regexprep(transducer_entry.display_name, '[^a-zA-Z0-9_]', '_');
    fname      = sprintf('%s_%s_%s.mat', safe_name, result.date, result.channel);
    filepath   = fullfile(rec_dir, fname);

    save(filepath, 'result');
    fprintf('Record saved: %s\n', fname);
end

function new_transducer = showRegisterDialog()
% Simple registration dialog
new_transducer = [];

dlg = uifigure('Name', 'Register Transducer', ...
    'Position', [400 300 400 420], 'Resize', 'off');

g = uigridlayout(dlg, [12 2]);
g.RowHeight    = {20, 30, 20, 30, 20, 30, 20, 30, 20, 30, 20, 40};
g.ColumnWidth  = {'1x', '1x'};
g.Padding      = [16 16 16 16];
g.RowSpacing   = 4;
g.ColumnSpacing = 10;

function lbl = addLabel(text, row)
    lbl = uilabel(g, 'Text', text, 'FontSize', 10, ...
        'FontColor', [0.45 0.45 0.45]);
    lbl.Layout.Row    = row;
    lbl.Layout.Column = [1 2];
end

function fld = addField(row, col, placeholder)
    fld = uieditfield(g, 'text', 'Placeholder', placeholder);
    fld.Layout.Row    = row;
    fld.Layout.Column = col;
end

addLabel('Stimulus transducer name:', 1);
stim_name_fld   = addField(2, 1, 'e.g. ER2');
stim_serial_fld = addField(2, 2, 'Serial number');

addLabel('Stimulus type:', 3);
stim_type_drop  = uidropdown(g, 'Items', ...
    {'Insert earphone', 'OAE probe speaker', 'Headphone', 'Speaker'});
stim_type_drop.Layout.Row    = 4;
stim_type_drop.Layout.Column = [1 2];

addLabel('Microphone name:', 5);
mic_name_fld    = addField(6, 1, 'e.g. ER10B+');
mic_serial_fld  = addField(6, 2, 'Serial number');

addLabel('Microphone type:', 7);
mic_type_drop   = uidropdown(g, 'Items', ...
    {'OAE probe mic', 'Coupler mic', 'Free field mic', 'KEMAR'});
mic_type_drop.Layout.Row    = 8;
mic_type_drop.Layout.Column = [1 2];

addLabel('Mic sensitivity (dB re 1V/Pa):', 9);
mic_sens_fld    = addField(10, 1, 'e.g. -57.5');

addLabel('Added by:', 11);
added_by_fld    = addField(11, 2, 'Initials');

% Buttons
btn_grid = uigridlayout(g, [1 2]);
btn_grid.Layout.Row    = 12;
btn_grid.Layout.Column = [1 2];
btn_grid.ColumnWidth   = {'1x', '1x'};
btn_grid.Padding       = [0 4 0 0];

cancelBtn = uibutton(btn_grid, 'Text', 'Cancel', ...
    'ButtonPushedFcn', @(~,~) cancelPressed());
cancelBtn.Layout.Row = 1; cancelBtn.Layout.Column = 1;

okBtn = uibutton(btn_grid, 'Text', 'Register', ...
    'BackgroundColor', [0.11 0.62 0.46], ...
    'FontColor',       [0.88 0.96 0.93], ...
    'ButtonPushedFcn', @(~,~) okPressed());
okBtn.Layout.Row = 1; okBtn.Layout.Column = 2;

cancelled = false;

    function okPressed()
        if isempty(strtrim(stim_name_fld.Value)) || ...
                isempty(strtrim(mic_name_fld.Value))
            uialert(dlg, 'Transducer and mic names are required.', ...
                'Missing fields');
            return
        end

        t.stim.name            = strtrim(stim_name_fld.Value);
        t.stim.serial          = strtrim(stim_serial_fld.Value);
        t.stim.type            = stim_type_drop.Value;
        t.mic.name             = strtrim(mic_name_fld.Value);
        t.mic.serial           = strtrim(mic_serial_fld.Value);
        t.mic.type             = mic_type_drop.Value;
        t.mic.sensitivity_dbv  = str2double(mic_sens_fld.Value);
        t.display_name         = sprintf('%s + %s', t.stim.name, t.mic.name);
        t.date_added           = datestr(now, 'yyyy-mm-dd');
        t.added_by             = strtrim(added_by_fld.Value);
        t.notes                = '';

        new_transducer = t;
        delete(dlg);
    end

    function cancelPressed()
        cancelled = true;
        delete(dlg);
    end

waitfor(dlg);
if cancelled
    new_transducer = [];
end
end