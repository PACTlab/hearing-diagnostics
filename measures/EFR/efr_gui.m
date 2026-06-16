function efr_gui(save_dir, metadata, launcher_fig)
% EFR_GUI  Main EFR data collection window.
% Launches session selection first, then opens main acquisition window.

if nargin < 3; launcher_fig = []; end
if nargin < 2; metadata = []; end
if nargin < 1; save_dir = ''; end

%% --- To Do --
% Handle calibration
warning('off', 'Session:noTransducerCal');

% fix getting Gui params

%% --- Session ---
% Lets you create (or reload) the session file to save everything to
% Reads from launcher if used to get to abr_gui()
if isempty(save_dir)
    [save_dir, metadata] = session_load_or_create();
    if isempty(save_dir); return; end
end


%% --- Load General Config Info ---
cfg = config_load();

%% --- Connect with TDT
tdt = tdt_init(cfg, 'ephys'); 
%tdt = []; 

%% --- Load Calibration --- 
% Load transducer cal if configured
transducer_cal = [];
if ~isempty(cfg.calibration.active_transducer_file)
    try
        transducer_cal = cal_load_transducer(cfg.calibration.active_transducer_file);
    catch e
        warning('efr_gui:calLoadFailed', ...
            'Could not load transducer cal: %s', e.message);
    end
end

% Ear cal starts empty — loaded later if run
ear_cal = [];

%% --- Default params ---
% if lab_default project, use the params in this folder, otherwise, use the
% params in the project folder. If no params in the project folder, use
% lab_defaults.
params = project_load_defaults('efr', metadata.project);

%% --- State ---

state.running  = false;
state.stop_req = false;
state.stub_mode = isempty(tdt); 
prevAxes       = {};

% Show stub mode warning in status bar if active
if state.stub_mode
    fprintf('EFR GUI running in stub mode — no hardware connected.\n');
end


%% --- Main figure ---

fig = uifigure(...
    'Name',            sprintf('EFR — %s', metadata.subject_id), ...
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

quitBtn = uibutton(btnGrid, 'Text', 'Quit EFR', ...
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
ctrlGrid.RowHeight       = {'1x', 24};
ctrlGrid.ColumnWidth     = {'1x', '3x', '1x','1x','2x','1x','1x','1x','1x','1x',80,80};
ctrlGrid.Padding         = [10 8 10 6];
ctrlGrid.RowSpacing      = 4;
ctrlGrid.ColumnSpacing   = 8;
ctrlGrid.BackgroundColor = 'w';

% Parameter fields
stimTypeDrop = makeField(ctrlGrid, 'Stimulus Type',              1, 1,  'drop', {'WAV','SAM','RAM'});
stimFile    = makeField(ctrlGrid, 'Wav File', 1, 2, 'drop', {params.wav_file}); 
%freqField    = makeField(ctrlGrid, 'Frequency (Hz)',        1, 2,  'edit', num2str(params.carrier_frequency_hz));
earDrop      = makeField(ctrlGrid, 'Ear',                  1, 3,  'drop', {'Right','Left'});
polarityDrop = makeField(ctrlGrid, 'Polarity',             1, 4,  'drop', {'Alt','Cond','Rare'});
levelsField  = makeField(ctrlGrid, 'Level series (dB SPL)',1, 5,  'edit', ...
    strjoin(arrayfun(@num2str, params.levels_dbspl, 'UniformOutput', false), ', '));
repsField    = makeField(ctrlGrid, 'Reps (per pol)',       1, 6,  'edit', num2str(params.n_reps));
%rateField    = makeField(ctrlGrid, 'ISI (Hz)',            1, 7,  'edit', num2str(params.isi_ms));
%durField     = makeField(ctrlGrid, 'Dur (cyc)',             1, 8,  'edit', num2str(params.duration_cyc));
%riseField    = makeField(ctrlGrid, 'Rise (cyc)',            1, 9,  'edit', num2str(params.rise_fall_cyc));
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

avgLine  = plot(waveAx, NaN, NaN, ...
    'Color', [0.11 0.62 0.46], 'LineWidth', 1.8);

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
        err    = efr_validate_params(params);
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
            metadata = efr_run(params, save_dir, metadata, tdt, transducer_cal, callbacks);
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
        p = project_load_defaults('abr', metadata.project);
        p.stim_type    = lower(strrep(stimTypeDrop.Value, ' ', ''));
        p.stimFile = lower(stimFile.Value); 
        p.frequency_hz = str2double(freqField.Value);
        p.ear          = lower(earDrop.Value);
        p.polarity     = lower(polarityDrop.Value);
        p.levels_dbspl = str2num(levelsField.Value); %#ok<ST2NM>
        p.n_reps       = round(str2double(repsField.Value));
        p.rate_hz      = str2double(rateField.Value);
        p.duration_cyc  = str2double(durField.Value);
        p.rise_fall_cyc = str2double(riseField.Value);

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

    function updateStatus(msg)
        statusBar.Text = msg;
    end

    function updateNoise(rms_uv)
        noiseLbl.Text = sprintf('%.2f µV', rms_uv);
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

    function addPrevWaveform(t, avg_uv, level_dbspl, freq_hz)
        n = length(prevAxes) + 1;
        prevAxes{n} = struct('t', t, 'avg', avg_uv, ...
            'level', level_dbspl, 'freq', freq_hz);

        cla(prevAx);
        hold(prevAx, 'on');
        for i = 1:n
            offset = (n - i) * 6;
            x_offset = length(t)-floor((length(t)/4));
            plot(prevAx, prevAxes{i}.t, prevAxes{i}.avg + offset, ...
                'Color', [0.22 0.54 0.85], 'LineWidth', 1);
            text(prevAx, t(x_offset) + 0.2, offset+.5, ...
                sprintf('%d dB', prevAxes{i}.level), ...
                'FontSize', 10, 'Color', [0.4 0.4 0.4]);
        end
        hold(prevAx, 'off');
        prevAx.YTick = [];
        prevAx.XLim  = [t(1) t(end)];
        drawnow;
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

    

end   % efr_gui

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