function abr_gui(save_dir, metadata)
% ABR_GUI  Main ABR data collection window.
% Launches session selection first, then opens main acquisition window.

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

tdt = tdt_init(cfg, 'ephys'); 
%tdt = []; 

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
params = project_load_defaults('abr', metadata.project);

default_levels_str = strjoin(arrayfun(@num2str, params.levels_dbspl, ...
    'UniformOutput', false), ', ');
%% --- State ---

state.running  = false;
state.stop_req = false;
state.stub_mode = isempty(tdt); 
prevAxes       = {};

% Show stub mode warning in status bar if active
if state.stub_mode
    fprintf('ABR GUI running in stub mode — no hardware connected.\n');
end

%% --- Main figure ---

fig = uifigure(...
    'Name',            sprintf('ABR — %s', metadata.subject_id), ...
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

ctrlGrid = uigridlayout(ctrlPanel, [2 13]);
ctrlGrid.RowHeight       = {'1x', 24};
ctrlGrid.ColumnWidth = {'1x','1x','1x','1x','2x',30,'1x','1x','1x','1x',80,80};
ctrlGrid.Padding         = [10 8 10 6];
ctrlGrid.RowSpacing      = 4;
ctrlGrid.ColumnSpacing   = 8;
ctrlGrid.BackgroundColor = 'w';

% Parameter fields
stimTypeDrop = makeField(ctrlGrid, 'Stimulus',              1, 1,  'drop', {'Tone burst','Click','Chirp'});
freqField    = makeField(ctrlGrid, 'Frequency (Hz)',        1, 2,  'edit', num2str(params.frequency_hz));
earDrop      = makeField(ctrlGrid, 'Ear',                  1, 3,  'drop', {'Right','Left'});
polarityDrop = makeField(ctrlGrid, 'Polarity',             1, 4,  'drop', {'Alt','Cond','Rare'});
levelsField  = makeField(ctrlGrid, 'Level series (dB SPL)',1, 5,  'edit', ...
    strjoin(arrayfun(@num2str, params.levels_dbspl, 'UniformOutput', false), ', '));

repsField    = makeField(ctrlGrid, 'Reps (per pol)',       1, 7,  'edit', num2str(params.n_reps));
rateField    = makeField(ctrlGrid, 'Rate (Hz)',            1, 8,  'edit', num2str(params.rate_hz));
durField     = makeField(ctrlGrid, 'Dur (cyc)',             1, 9,  'edit', num2str(params.duration_cyc));
riseField    = makeField(ctrlGrid, 'Rise (cyc)',            1, 10,  'edit', num2str(params.rise_fall_cyc));
earCalDrop   = makeField(ctrlGrid, 'Ear cal',              1, 11, 'drop', {'Session','None','File...'});

resetPanel = uipanel(ctrlGrid, 'BorderType', 'none', 'BackgroundColor', 'w');
resetPanel.Layout.Row    = 1;
resetPanel.Layout.Column = 6;

resetGrid = uigridlayout(resetPanel, [2 1]);
resetGrid.RowHeight       = {16, '1x'};
resetGrid.Padding         = [0 0 0 0];
resetGrid.RowSpacing      = 2;
resetGrid.BackgroundColor = 'w';

resetLevelsBtn = uibutton(resetGrid, ...
    'Text',            '↺', ...
    'FontSize',        14, ...
    'Tooltip',         'Reset to default levels', ...
    'ButtonPushedFcn', @(~,~) resetLevels());
resetLevelsBtn.Layout.Row    = 2;
resetLevelsBtn.Layout.Column = 1;

freqField.ValueChangedFcn    = @(~,~) clearPrevWaveforms();
stimTypeDrop.ValueChangedFcn = @(~,~) clearPrevWaveforms();
earDrop.ValueChangedFcn      = @(~,~) clearPrevWaveforms();

runBtn = uibutton(ctrlGrid, ...
    'Text',            '▶  Run', ...
    'BackgroundColor', [0.11 0.62 0.46], ...
    'FontColor',       [0.88 0.96 0.93], ...
    'FontWeight',      'bold', ...
    'ButtonPushedFcn', @(~,~) onRun());
runBtn.Layout.Row    = 1;
runBtn.Layout.Column = 12;

stopBtn = uibutton(ctrlGrid, ...
    'Text',            '■  Stop', ...
    'BackgroundColor', [0.85 0.35 0.18], ...
    'FontColor',       [0.98 0.92 0.89], ...
    'FontWeight',      'bold', ...
    'Enable',          'off', ...
    'ButtonPushedFcn', @(~,~) onStop());
stopBtn.Layout.Row    = 1;
stopBtn.Layout.Column = 13;

% Status bar
statusBar = uilabel(ctrlGrid, ...
    'Text',      'Ready.', ...
    'FontSize',  11, ...
    'FontColor', [0.4 0.4 0.4]);
statusBar.Layout.Row    = 2;
statusBar.Layout.Column = [1 8];

% Params file bar
paramsBar = uilabel(ctrlGrid, ...
    'Text',      sprintf('Parameters from: %s', metadata.project), ...
    'FontSize',  11, ...
    'FontColor', [0.4 0.4 0.4], ...
    'HorizontalAlignment', 'right');
paramsBar.Layout.Row    = 2;
paramsBar.Layout.Column = [9 12];
%% ================================================================
%  ROW 3 — Plots
%% ================================================================

plotGrid = uigridlayout(mainGrid, [1 2]);
plotGrid.Layout.Row    = 3;
plotGrid.Layout.Column = 1;
plotGrid.ColumnWidth   = {'1x', 250};
plotGrid.ColumnSpacing = 6;
plotGrid.Padding       = [0 0 0 0];

%% --- Left col: Current Waveform ---
colors.combined = [0.35 0.10 0.40];   % eggplant
colors.positive = [0.10 0.15 0.45];   % navy blue
colors.negative = [0.55 0.05 0.10];   % deep red

leftGrid = uigridlayout(plotGrid, [2 2]);
leftGrid.Layout.Row    = 1;
leftGrid.Layout.Column = 1;
leftGrid.RowHeight     = {'1x', 120};
leftGrid.ColumnWidth = {400, '1x'};
leftGrid.RowSpacing    = 6;
leftGrid.Padding       = [0 0 0 0];

% Waveform panel
wavePanel = uipanel(leftGrid, ...
    'BorderType',      'line', ...
    'Title',           'Running average', ...
    'BackgroundColor', 'w');
wavePanel.Layout.Row    = 1;
wavePanel.Layout.Column = [1,2];

waveGrid = uigridlayout(wavePanel, [1 1]);
waveGrid.Padding         = [2 2 2 2];
waveGrid.BackgroundColor = 'w';

waveAx = uiaxes(waveGrid, ...
    'XLim',   params.viz_window_ms, ...
    'YLim',   params.amplitude_window_uV, ...
    'Box',    'on', ...
    'FontSize', 11);
waveAx.Layout.Row    = 1;
waveAx.Layout.Column = 1;
xlabel(waveAx, 'Time (ms)');
ylabel(waveAx, 'Amplitude (µV)');
hold(waveAx, 'on');

avgLine     = plot(waveAx, NaN, NaN, 'LineWidth', 1.8);   % primary line
avgLine_neg = plot(waveAx, NaN, NaN, 'LineWidth', 1.4);   % negative polarity line

% Noise panel
noisePanel = uipanel(leftGrid, ...
    'BorderType',      'line', ...
    'Title',           'Noise floor', ...
    'BackgroundColor', 'w');
noisePanel.Layout.Row    = 2;
noisePanel.Layout.Column = 2;

noiseGrid = uigridlayout(noisePanel, [1 4]);
noiseGrid.ColumnWidth     = {110, 90, 110, '1x'};
noiseGrid.Padding         = [10 4 10 4];
noiseGrid.ColumnSpacing   = 20;
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

% Visualization Parameters
vizPanel = uipanel(leftGrid, ...
    'BorderType',      'line', ...
    'Title',           'Visualization Parameters', ...
    'BackgroundColor', 'w');
vizPanel.Layout.Row    = 2;
vizPanel.Layout.Column = 1;

vizGrid = uigridlayout(vizPanel, [2 2]);
vizGrid.ColumnWidth     = {'1x', '1x'};
vizGrid.RowHeight       = {'1x', '1x'};
vizGrid.Padding         = [10 4 10 4];
vizGrid.ColumnSpacing   = 50;
vizGrid.BackgroundColor = 'w';

% TODO: wire viz panel fields to update display
viz_startField    = makeField(vizGrid, 'Start (ms)',       1, 1, 'edit', num2str(params.viz_window_ms(1)));
viz_endField      = makeField(vizGrid, 'End (ms)',         1, 2, 'edit', num2str(params.viz_window_ms(2)));
viz_scaleField    = makeField(vizGrid, 'Y scale (µV)',     2, 1, 'edit', num2str(params.amplitude_window_uV(2)));
viz_polarityDrop  = makeField(vizGrid, 'Polarity display', 2, 2, 'drop', {'Combined', 'Separated', 'Positive only', 'Negative only'});

viz_startField.ValueChangedFcn   = @(~,~) updateVizWindow();
viz_endField.ValueChangedFcn     = @(~,~) updateVizWindow();
viz_scaleField.ValueChangedFcn   = @(~,~) updateVizScale();
viz_polarityDrop.ValueChangedFcn = @(~,~) updateVizPolarity();
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
    'XLim',   params.viz_window_ms);
prevAx.Layout.Row    = 1;
prevAx.Layout.Column = 1;
xlabel(prevAx, 'Time (ms)');

%% ================================================================
%  CALLBACKS
%% ================================================================

    function onRun()
        params = readParamsFromGui();
        err    = abr_validate_params(params);
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
            metadata = abr_run(params, save_dir, metadata, tdt, transducer_cal, callbacks);
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
            'End this session and close ABR?', ...
            'Quit ABR', ...
            'Options',       {'Quit', 'Cancel'}, ...
            'DefaultOption', 2, ...
            'CancelOption',  2);
        if strcmp(sel, 'Quit')
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
        p = project_load_defaults('abr', metadata.project);
        p.stim_type    = lower(strrep(stimTypeDrop.Value, ' ', ''));
        p.frequency_hz = str2double(freqField.Value);
        p.ear          = lower(earDrop.Value);
        p.polarity     = lower(polarityDrop.Value);
        p.levels_dbspl = str2num(levelsField.Value); %#ok<ST2NM>
        p.n_reps       = round(str2double(repsField.Value));
        p.rate_hz      = str2double(rateField.Value);
        p.duration_cyc  = str2double(durField.Value);
        p.rise_fall_cyc = str2double(riseField.Value);

        p.viz_window_ms       = [str2double(viz_startField.Value) ...
            str2double(viz_endField.Value)];
        p.amplitude_window_uV = [-str2double(viz_scaleField.Value) ...
            str2double(viz_scaleField.Value)];
        p.viz_polarity        = viz_polarityDrop.Value;
        % need to validate levels are a reasonable range and freq are
        % doable

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

    function clearPrevWaveforms()
        prevAxes = {};
        cla(prevAx);
        prevAx.YTick = [];
        prevAx.XLim  = [str2double(viz_startField.Value) ...
            str2double(viz_endField.Value)];
    end

    function updateStatus(msg)
        statusBar.Text = msg;
    end

    function updateNoise(rms_uv)
        noiseLbl.Text = sprintf('%.2f µV', rms_uv);
    end

    function setWaveTitle(msg)
        wavePanel.Title = msg;
    end

    function resetLevels()
        levelsField.Value = default_levels_str;
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

    function updateVizWindow()
        start_ms = str2double(viz_startField.Value);
        end_ms   = str2double(viz_endField.Value);
        if ~isnan(start_ms) && ~isnan(end_ms) && end_ms > start_ms
            waveAx.XLim = [start_ms end_ms];
            prevAx.XLim = [start_ms end_ms];
        end
    end

    function updateVizScale()
        scale = str2double(viz_scaleField.Value);
        if ~isnan(scale) && scale > 0
            waveAx.YLim = [-scale scale];
        end
    end

    function updateVizPolarity()
        % Nothing to do immediately — next update_waveform call
        % will pick up the new polarity selection automatically
    end

    function addPrevWaveform(t, avg_uv, level_dbspl, freq_hz)
        n = length(prevAxes) + 1;
        prevAxes{n} = struct('t', t, 'avg', avg_uv, ...
            'level', level_dbspl, 'freq', freq_hz);

        cla(prevAx);
        hold(prevAx, 'on');

        % Compute step based on max amplitude across all waveforms
        max_amp = max(cellfun(@(w) max(abs(w.avg)), prevAxes));
        step    = max(6, max_amp * 2.5);   % at least 6 µV, or 2.5x the largest peak

        for i = 1:n
            offset = (n - i) * step;
            x_offset = length(t)-floor((length(t)/4));
            plot(prevAx, prevAxes{i}.t, prevAxes{i}.avg + offset, ...
                'Color', colors.combined, 'LineWidth', 1);
            text(prevAx, t(x_offset) + 0.2, offset+.5, ...
                sprintf('%d dB', prevAxes{i}.level), ...
                'FontSize', 10, 'Color', [0.4 0.4 0.4]);
        end
        hold(prevAx, 'off');
        prevAx.YTick = [];
        prevAx.XLim  = [t(1) t(end)];

        prevAx.YLim = [-step/2, (n-1)*step + step/2];   % 4 µV padding top and bottom
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

function sig = baselineCorrect(sig, t)
pre_stim_idx = t < 0;
if any(pre_stim_idx) && ~all(sig(pre_stim_idx) == 0)
    sig = sig - mean(sig(pre_stim_idx));
end
end