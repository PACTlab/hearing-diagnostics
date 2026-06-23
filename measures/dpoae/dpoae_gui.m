function dpoae_gui(save_dir, metadata, launcher_fig)
% DPOAE_GUI  Main DPOAE data collection window.
% Launches session selection first, then opens main acquisition window.

if nargin < 3; launcher_fig = []; end
if nargin < 2; metadata = []; end
if nargin < 1; save_dir = ''; end

%% --- Session ---
% Lets you create (or reload) the session file to save everything to
% Reads from launcher if used to get to abr_gui()
if isempty(save_dir)
    [save_dir, metadata] = session_load_or_create();
    if isempty(save_dir); return; end
end

%% --- To Do --
% Handle calibration
warning('off', 'Session:noTransducerCal');

%% --- Load the General Config --- 
cfg = config_load();

%% --- Connect with TDT

%tdt = tdt_init(cfg, 'acoustic'); 
tdt = []; 

%% --- Load calibration ---

% Load transducer cal if configured
transducer_cal = [];
if ~isempty(cfg.calibration.active_transducer_file)
    try
        transducer_cal = cal_load_transducer(cfg.calibration.active_transducer_file);
    catch e
        warning('abr_gui:calLoadFailed', ...
            'Could not load transducer cal: %s', e.message);
    end
end

% Ear cal starts empty — loaded later if run
ear_cal = [];

%% --- Default params ---
% if lab_default project, use the params in this folder, otherwise, use the
% params in the project folder. If no params in the project folder, use
% lab_defaults.
params = project_load_defaults('dpoae', metadata.project);

default_levels_str = []; 
%% --- State ---
state.running  = false;
state.stop_req = false;
state.stub_mode = isempty(tdt); 
prevAxes       = {};

% Show stub mode warning in status bar if active
if state.stub_mode
    fprintf('DPOAE GUI running in stub mode — no hardware connected.\n');
end

%% --- Main figure ---

fig = uifigure(...
    'Name',            sprintf('DPOAE — %s', metadata.subject_id), ...
    'Position',        [50 50 1200 750], ...
    'CloseRequestFcn', @(~,~) onCloseRequest());

%% ================================================================
%  TOP LEVEL GRID: 3 rows
%  Row 1: subject bar
%  Row 2: control panel
%  Row 3: plots
%% ================================================================

mainGrid = uigridlayout(fig, [3 1]);
mainGrid.RowHeight   = {52, 140, '1x'};
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
subGrid.ColumnWidth     = {80, 100, 100, 100, 100, 8, 110, 110, 110, '1x'};
subGrid.Padding         = [10 6 10 6];
subGrid.ColumnSpacing   = 12;
subGrid.BackgroundColor = 'w';

% Status indicator
statusLbl = uilabel(subGrid, ...
    'Text',       '● Idle', ...
    'FontSize',   13, ...
    'FontWeight', 'bold', ...
    'FontColor',  [0.5 0.5 0.5]);
statusLbl.Layout.Row    = 1;
statusLbl.Layout.Column = 1;

% Subject info chips — read from metadata
makeInfoChip(subGrid, 'Subject',  metadata.subject_id, 2);
makeInfoChip(subGrid, 'Species',  metadata.species,    3);
makeInfoChip(subGrid, 'Operator', metadata.operator,   4);
makeInfoChip(subGrid, 'Date',     metadata.date,       5);

% Divider
divLbl = uilabel(subGrid, 'Text', '|', 'FontColor', [0.8 0.8 0.8]);
divLbl.Layout.Row    = 1;
divLbl.Layout.Column = 6;

% Cal status badges
transducerCalLbl = uilabel(subGrid, ...
    'Text',                calBadgeText('Transducer', transducer_cal), ...
    'FontSize',            11, ...
    'HorizontalAlignment', 'center', ...
    'BackgroundColor',     calBadgeColor(transducer_cal), ...
    'FontColor',           calBadgeFontColor(transducer_cal));
transducerCalLbl.Layout.Row    = 1;
transducerCalLbl.Layout.Column = 7;

earCalLbl = uilabel(subGrid, ...
    'Text',                calBadgeText('Ear cal', ear_cal), ...
    'FontSize',            11, ...
    'HorizontalAlignment', 'center', ...
    'BackgroundColor',     calBadgeColor(ear_cal), ...
    'FontColor',           calBadgeFontColor(ear_cal));
earCalLbl.Layout.Row    = 1;
earCalLbl.Layout.Column = 8;

if state.stub_mode
    stubLbl = uilabel(subGrid, ...
        'Text',                '⚠ STUB MODE', ...
        'FontSize',            11, ...
        'FontWeight',          'bold', ...
        'HorizontalAlignment', 'center', ...
        'BackgroundColor',     [0.85 0.20 0.10], ... yellow % [1.0 0.75 0.00]
        'FontColor',           [1.0 1.0 1.0]);    %  white [0.15 0.10 0.00],
    stubLbl.Layout.Row    = 1;
    stubLbl.Layout.Column = 9;
end

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

quitBtn = uibutton(btnGrid, 'Text', 'Quit DPOAE', ...
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

ctrlGrid = uigridlayout(ctrlPanel, [3 11]);
ctrlGrid.RowHeight       = {'1x', '1x', 20};
ctrlGrid.ColumnWidth = {'1x', '1x', '1x', '1x','1x', '1x','1x', '1x', '1x', '1x', 80};
ctrlGrid.Padding         = [10 8 10 6];
ctrlGrid.RowSpacing      = 4;
ctrlGrid.ColumnSpacing   = 8;
ctrlGrid.BackgroundColor = 'w';

% Parameter fields
swept_color    = [.85 .37 0];  
discrete_color = [0.45 .43 .7];   

earDrop      = makeField(ctrlGrid, 'Ear', 1, 1,  'drop', {'Right','Left'});
stimTypeDrop = makeField(ctrlGrid, 'Stim Type', 2, 1,  'drop', {'swept','discrete'});
stimTypeDrop.ValueChangedFcn = @(~,~) onStimTypeChanged();

% Parameter Section varied for swept vs discrete
freqRatio = makeField(ctrlGrid, 'F2/F1 Ratio', 1, 3, 'edit', string(params.ratio)); 
sweepRate = makeField(ctrlGrid, 'Sweep Rate', 1, 6, 'edit', '1', swept_color); 
sweepDir = makeField(ctrlGrid, 'Sweep Dir', 1, 4, 'drop', {'Up', 'Down'}, swept_color); 
sweepType = makeField(ctrlGrid, 'Log/Linear Sweep', 1, 5, 'drop', {'Log', 'Linear'}, swept_color); 
sweepf2min = makeField(ctrlGrid, 'Min F2', 1, 7, 'edit', string(params.min_f2_hz), swept_color); 
sweepf2max = makeField(ctrlGrid, 'Max F2', 1, 8, 'edit', string(params.max_f2_hz), swept_color); 
sweepBuffDur = makeField(ctrlGrid, 'Buff Dur (ms)', 1, 9, 'edit', string(params.buffdur_ms), swept_color); 
disDuration = makeField(ctrlGrid, 'Duration (ms)', 2, 4, 'edit', string(params.duration_ms), discrete_color); 
disF2list = makeField(ctrlGrid, 'F2 List', 2, 5, 'edit', mat2str(params.f2_hz), discrete_color); 
levelf1 = makeField(ctrlGrid, 'F1 Level (dB)', 1, 2, 'edit', string(params.level_f1_dB)); 
levelf2 = makeField(ctrlGrid, 'F2 Level (dB)', 2, 2, 'edit', string(params.level_f2_dB)); 

autoStopCheck = uicheckbox(ctrlGrid, ...
    'Text',     'Auto-stop', ...
    'Value',    params.auto_stop, ...
    'FontSize', 11);
autoStopCheck.Layout.Row    = 2;
autoStopCheck.Layout.Column = 3;

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
stopBtn.Layout.Row    = 2;
stopBtn.Layout.Column = 11;

% Status bar
statusBar = uilabel(ctrlGrid, ...
    'Text',      'Ready.', ...
    'FontSize',  11, ...
    'FontColor', [0.4 0.4 0.4]);
statusBar.Layout.Row    = 3;
statusBar.Layout.Column = [1];

% Params file bar
paramsBar = uilabel(ctrlGrid, ...
    'Text',      sprintf('Parameters from: %s', metadata.project), ...
    'FontSize',  11, ...
    'FontColor', [0.4 0.4 0.4], ...
    'HorizontalAlignment', 'right');
paramsBar.Layout.Row    = 3;
paramsBar.Layout.Column = [8 11];
%% ================================================================
%  ROW 3 — Plots
%% ================================================================

plotGrid = uigridlayout(mainGrid, [1 2]);
plotGrid.ColumnWidth = {'4x', '1x'}; 
plotGrid.Layout.Row    = 3;
plotGrid.Layout.Column = 1;
plotGrid.ColumnSpacing = 6;
plotGrid.Padding       = [0 0 0 0];

%% --- Left col: Current Waveform ---
% Waveform panel
wavePanel = uipanel(plotGrid, ...
    'BorderType',      'line', ...
    'Title',           'Running average', ...
    'BackgroundColor', 'w');
wavePanel.Layout.Row    = 1;
wavePanel.Layout.Column = 1;

waveGrid = uigridlayout(wavePanel, [1 1]);
waveGrid.Padding         = [8 8 8 8];
waveGrid.BackgroundColor = 'w';

waveAx = uiaxes(waveGrid, ...
    'XLim',   [params.min_f2_hz, params.max_f2_hz], ...
    'YLim',   params.amplitude_window_dB, ...
    'Box',    'on', ...
    'FontSize', 11);
waveAx.Layout.Row    = 1;
waveAx.Layout.Column = 1;
xlabel(waveAx, 'Frequency (Hz)');
ylabel(waveAx, 'Amplitude (dB)');
hold(waveAx, 'on');

avgLine     = plot(waveAx, NaN, NaN, 'LineWidth', 1.8);   % primary line
avgLine_neg = plot(waveAx, NaN, NaN, 'LineWidth', 1.4);   % negative polarity line

% Plotting Panel 
plotPanel = uipanel(plotGrid, ...
    'BorderType',      'line', ...
    'Title',           'Plot Options', ...
    'BackgroundColor', 'w');
plotPanel.Layout.Row    = 1;
plotPanel.Layout.Column = 2;

plotOptionsGrid = uigridlayout(plotPanel, [4 2]);
plotOptionsGrid.RowHeight    = {40, 40, '1x',24};
plotOptionsGrid.ColumnWidth = {'1x', '1x'}; 
plotOptionsGrid.Padding      = [8 8 8 8];
plotOptionsGrid.RowSpacing   = 4;
plotOptionsGrid.BackgroundColor = 'w';

viz_xminField = makeField(plotOptionsGrid, 'X Min (Hz)', 1, 1, 'edit', ...
    string(params.min_f2_hz));
viz_xmaxField = makeField(plotOptionsGrid, 'X Max (Hz)', 1, 2, 'edit', ...
    string(params.max_f2_hz));
viz_yminField = makeField(plotOptionsGrid, 'Y Min (dB)', 2, 1, 'edit', ...
    string(params.amplitude_window_dB(1)));
viz_ymaxField = makeField(plotOptionsGrid, 'Y Max (dB)', 2, 2, 'edit', ...
    string(params.amplitude_window_dB(2)));

applyVizBtn = uibutton(plotOptionsGrid, ...
    'Text',            'Apply', ...
    'ButtonPushedFcn', @(~,~) updateVizWindow());
applyVizBtn.Layout.Row    = 4;
applyVizBtn.Layout.Column = [1 2];

% TODO: Add norms toggle

%% ================================================================
%  CALLBACKS
%% ================================================================

    function onStimTypeChanged()
            is_swept = strcmp(stimTypeDrop.Value, 'swept');
    
            swept_fields    = {sweepRate, sweepDir, sweepType, ...
                               sweepBuffDur, sweepf2min, sweepf2max};
            discrete_fields = {disDuration, disF2list};
    
            for i = 1:length(swept_fields)
                swept_fields{i}.Enable = onoff(is_swept);
            end
            for i = 1:length(discrete_fields)
                discrete_fields{i}.Enable = onoff(~is_swept);
            end
    end

% Call once to set initial state
onStimTypeChanged();

    function updateVizWindow()
        xmin = str2double(viz_xminField.Value);
        xmax = str2double(viz_xmaxField.Value);
        ymin = str2double(viz_yminField.Value);
        ymax = str2double(viz_ymaxField.Value);
        if ~isnan(xmin) && ~isnan(xmax) && xmax > xmin
            waveAx.XLim = [xmin xmax];
        end
        if ~isnan(ymin) && ~isnan(ymax) && ymax > ymin
            waveAx.YLim = [ymin ymax];
        end
    end

    function onRun()
        params = readParamsFromGui();
        err    = dpoae_validate_params(params);
        if ~isempty(err)
            uialert(fig, err, 'Invalid parameters');
            return
        end

        state.running  = true;
        state.stop_req = false;
        setRunning(true);

        % Build callbacks
        callbacks.update_status   = @(msg)           updateStatus(msg);
        callbacks.update_waveform = @(t, avg_combined, avg_pos, avg_neg) ...
            updateWaveform(t, avg_combined, avg_pos, avg_neg);        callbacks.update_noise    = @(rms)           updateNoise(rms);
        callbacks.add_prev = @(t, avg, lv, f) addPrevWaveform(t, avg, lv, f);
        callbacks.should_stop     = @()              state.stop_req;
        callbacks.update_title = @(msg) setWaveTitle(msg);

        try
            metadata = dpoae_run(params, save_dir, metadata, tdt, transducer_cal, callbacks);
        catch e
            if ~isempty(tdt)
                tdt_close(tdt); 
            end
            state.running = false;
            setRunning(false);
            wavePanel.Title = 'Running average';
            uialert(fig, e.message, 'Acquisition error');
            return
        end

        state.running = false;
        setRunning(false);
        wavePanel.Title = 'Running average';
        updateStatus(sprintf('Done. Total runs this session: %d', ...
            metadata.total_runs));
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
        % TODO: restore before deployment
        % if state.running
        %     uialert(fig, ...
        %         'Stop data collection before quitting.', ...
        %         'Cannot quit');
        %     return
        % end
        sel = uiconfirm(fig, ...
            'End this session and close DPOAE?', ...
            'Quit DPOAE', ...
            'Options',       {'Quit', 'Cancel'}, ...
            'DefaultOption', 2, ...
            'CancelOption',  2);
        if strcmp(sel, 'Quit')
            if ~isempty(launcher_fig) && isvalid(launcher_fig)
                % Re-enable launcher buttons
                buttons = findobj(launcher_fig, 'Type', 'Button');
                set(buttons, 'Enable', 'on');
                % Keep placeholders disabled
            end
            delete(fig);
            if ~isempty(tdt)
                tdt_close(tdt);
            end
        end
    end

%% ================================================================
%  NESTED HELPERS
%% ================================================================

    function p = readParamsFromGui()
    p = project_load_defaults('dpoae', metadata.project);

    % --- Shared params ---
    p.stim_type    = lower(stimTypeDrop.Value);
    p.ear          = lower(earDrop.Value);
    p.ratio        = str2double(freqRatio.Value);
    p.level_f1_dB  = str2double(levelf1.Value);
    p.level_f2_dB  = str2double(levelf2.Value);
    p.auto_stop = autoStopCheck.Value;

    % --- Swept-specific params ---
    if strcmp(p.stim_type, 'swept')
        p.min_f2_hz    = str2double(sweepf2min.Value);
        p.max_f2_hz    = str2double(sweepf2max.Value);
        p.speed        = str2double(sweepRate.Value);
        p.scale        = lower(sweepType.Value);   % 'log' or 'linear'
        p.buffdur_ms   = str2double(sweepBuffDur.Value);
        switch sweepDir.Value
            case 'Up';   p.sweepDirection =  1;
            case 'Down'; p.sweepDirection = -1;
        end

        % --- Discrete-specific params ---
    else
        p.duration_ms  = str2double(disDuration.Value);
        p.f2_hz        = str2num(disF2list.Value); %#ok<ST2NM>
    end

    % --- Viz params (display only, not passed to dpoae_run) ---
    p.viz_xlim = [str2double(viz_xminField.Value) ...
                  str2double(viz_xmaxField.Value)];
    p.amplitude_window_dB = [str2double(viz_yminField.Value) ...
                              str2double(viz_ymaxField.Value)];

    % Get the calibration things:
    % switch earCalDrop.Value
    %     case 'None'
    %         p.apply_ear_cal = false;
    %     case 'File...'
    %         [f, pth] = uigetfile('*.mat', 'Select ear cal file');
    %         if isequal(f, 0)
    %             p.apply_ear_cal = false;
    %         else
    %             p.apply_ear_cal = true;
    %             p.ear_cal_file  = fullfile(pth, f);
    %             end
    %         otherwise
    %             p.apply_ear_cal = true;
    %             p.ear_cal_file  = '';
    % end
    end

    function updateStatus(msg)
        statusBar.Text = msg;
    end

    function setWaveTitle(msg)
        wavePanel.Title = msg;
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

function updateWaveform(t, avg_combined, avg_pos, avg_neg)

       % Baseline correct each
        avg_combined = baselineCorrect(avg_combined, t);
        avg_pos      = baselineCorrect(avg_pos, t);
        avg_neg      = baselineCorrect(avg_neg, t);

        % Pick which average to display based on polarity dropdown
        switch viz_polarityDrop.Value
            case 'Combined'
                set(avgLine, ...
                    'XData', t, 'YData', avg_combined, ...
                    'Color', colors.combined);
                set(avgLine_neg, 'XData', NaN, 'YData', NaN);
            case 'Separated'
                set(avgLine, ...
                    'XData', t, 'YData', avg_pos, ...
                    'Color', colors.positive);
                set(avgLine_neg, ...
                    'XData', t, 'YData', avg_neg, ...
                    'Color', colors.negative);
            case 'Positive only'
                set(avgLine, ...
                    'XData', t, 'YData', avg_pos, ...
                    'Color', colors.positive);
                set(avgLine_neg, 'XData', NaN, 'YData', NaN);

            case 'Negative only'
                set(avgLine, ...
                    'XData', t, 'YData', avg_neg, ...
                    'Color', colors.negative);
                set(avgLine_neg, 'XData', NaN, 'YData', NaN);
        end

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

function field = makeField(parent, labelStr, row, col, type, default, label_color)

    if nargin < 7; label_color = [0.45 0.45 0.45]; end
    
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
    lbl.FontColor = label_color;
    
    switch type
        case 'edit'
            field = uieditfield(g, 'text', 'Value', default);
        case 'drop'
            field = uidropdown(g, 'Items', default);
    end
    field.Layout.Row    = 2;
    field.Layout.Column = 1;
end

function field = makeStimField(parent, labelStr, row, col, type, default)
    p = uipanel(parent, 'BorderType', 'none', 'BackgroundColor', 'w');
    p.Layout.Row    = row;
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
    switch type
        case 'edit'
            field = uieditfield(g, 'text', 'Value', default);
        case 'drop'
            field = uidropdown(g, 'Items', default);
    end
    field.Layout.Row    = 2;
    field.Layout.Column = 1;
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

function sig = baselineCorrect(sig, t)
    pre_stim_idx = t < 0;
    if any(pre_stim_idx) && ~all(sig(pre_stim_idx) == 0)
        sig = sig - mean(sig(pre_stim_idx));
    end
end

function s = onoff(tf)
    if tf; s = 'on'; else; s = 'off'; end
end