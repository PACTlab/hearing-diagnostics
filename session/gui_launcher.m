function gui_launcher()
% HEARING_LAB_GUI  Main launcher for hearing diagnostics system.
% Owns the session and passes it to each measure.

%% --- Session ---

[save_dir, metadata] = session_load_or_create();
if isempty(save_dir)
    return
end

%% --- Figure ---

fig = uifigure(...
    'Name',            'Hearing Lab', ...
    'Position',        [50 550 1100 280], ...
    'Resize',          'on', ...
    'CloseRequestFcn', @(~,~) onClose());

mainGrid = uigridlayout(fig, [3 1]);
mainGrid.RowHeight   = {52, 52, '1x'};
mainGrid.Padding     = [8 8 8 8];
mainGrid.RowSpacing  = 6;

%% ================================================================
%  ROW 1 — Session bar
%% ================================================================

sessionPanel = uipanel(mainGrid, ...
    'BorderType', 'line', 'BackgroundColor', 'w');
sessionPanel.Layout.Row    = 1;
sessionPanel.Layout.Column = 1;

sessGrid = uigridlayout(sessionPanel, [1 9]);
sessGrid.ColumnWidth     = {90, 100, 100, 100, 120, 8, 90, '1x', 100, 100};
sessGrid.Padding         = [10 6 10 6];
sessGrid.ColumnSpacing   = 10;
sessGrid.BackgroundColor = 'w';

makeInfoChip(sessGrid, 'Subject',  metadata.subject_id, 1);
makeInfoChip(sessGrid, 'Species',  metadata.species,    2);
makeInfoChip(sessGrid, 'Operator', metadata.operator,   3);
makeInfoChip(sessGrid, 'Date',     metadata.date,       4);
makeInfoChip(sessGrid, 'Project',  metadata.project,    5);

divLbl = uilabel(sessGrid, 'Text', '|', 'FontColor', [0.8 0.8 0.8]);
divLbl.Layout.Row    = 1;
divLbl.Layout.Column = 6;

% Session timer
timerLbl = uilabel(sessGrid, ...
    'Text',       '00:00', ...
    'FontSize',   13, ...
    'FontWeight', 'bold', ...
    'FontColor',  [0.4 0.4 0.4], ...
    'HorizontalAlignment', 'center');
timerLbl.Layout.Row    = 1;
timerLbl.Layout.Column = 7;

divLbl2 = uilabel(sessGrid, 'Text', '|', 'FontColor', [0.8 0.8 0.8]);
divLbl2.Layout.Row    = 1;
divLbl2.Layout.Column = 8;

refreshBtn = uibutton(sessGrid, 'Text', '↺ Refresh log', ...
    'BackgroundColor', [.94 .9 .55], ...
    'FontSize', 12, ...
    'FontWeight', 'bold', ...
    'ButtonPushedFcn', @(~,~) refreshFromDisk());
refreshBtn.Layout.Row = 1;
refreshBtn.Layout.Column = 8;

% Change session button
changeBtn = uibutton(sessGrid, ...
    'Text',            sprintf('Change\nSession'), ...
    'FontSize', 12, ... 
    'FontWeight', 'bold', ...
    'ButtonPushedFcn', @(~,~) onChangeSession(), ...
    'BackgroundColor', [.5 .69 .83]);
changeBtn.Layout.Row    = 1;
changeBtn.Layout.Column = 9;

% Change session button
quitBtn = uibutton(sessGrid, ...
    'Text',            'Quit', ...
    'FontSize', 12, ... 
    'FontWeight', 'bold', ...
    'ButtonPushedFcn', @(~,~) onClose(), ...
    'BackgroundColor', [.98 .5 .45]);
quitBtn.Layout.Row    = 1;
quitBtn.Layout.Column = 10;

%% ================================================================
%  ROW 2 — Measure buttons
%% ================================================================

btnPanel = uipanel(mainGrid, ...
    'BorderType', 'line', 'BackgroundColor', 'w');
btnPanel.Layout.Row    = 2;
btnPanel.Layout.Column = 1;

btnGrid = uigridlayout(btnPanel, [1 14]);
btnGrid.ColumnWidth     = repmat({'1x'}, 1, 14);
btnGrid.Padding         = [8 6 8 6];
btnGrid.ColumnSpacing   = 6;
btnGrid.BackgroundColor = 'w';

% Active measures
abrBtn = makeMeasureBtn(btnGrid, 'ABR', 1, true, @(~,~) launchABR());
efrBtn   = makeMeasureBtn(btnGrid, 'EFR',   2, true, @(~,~) launchEFR());
dpBtn    = makeMeasureBtn(btnGrid, 'DPOAE', 3, true, @(~,~) launchDPOAE());
sfBtn    = makeMeasureBtn(btnGrid, 'SFOAE', 4, false, @(~,~) []);
teBtn   = makeMeasureBtn(btnGrid, 'TEOAE', 5, false, @(~,~) []);
memrBtn  = makeMeasureBtn(btnGrid, 'MEMR',  6, false, @(~,~) []);

% Divider
btnGrid.ColumnWidth{1,7} = 30; 
div2 = uilabel(btnGrid, 'Text', '|', 'FontColor', [0.8 0.8 0.8], ...
    'HorizontalAlignment', 'center');
div2.Layout.Row    = 1;
div2.Layout.Column = 7;

% Calibration buttons
earCalBtn = makeMeasureBtn(btnGrid, 'Ear Cal', 8, true, @(~,~) launchEarCal());
txdBtn = makeMeasureBtn(btnGrid, 'Transducer', 9, true, @(~,~) launchTransducer());
fplBtn      = makeMeasureBtn(btnGrid, 'FPL',        10, false, @(~,~) []);


%% ================================================================
%  ROW 3 — Run log
%% ================================================================

logPanel = uipanel(mainGrid, ...
    'BorderType', 'line', ...
    'Title',      'Session Log', ...
    'BackgroundColor', 'w');
logPanel.Layout.Row    = 3;
logPanel.Layout.Column = 1;

logGrid = uigridlayout(logPanel, [2 2]);
logGrid.ColumnWidth = {'2x', '3x'};
logGrid.RowHeight = {'1x', 20};
logGrid.Padding         = [4 4 4 4];
logGrid.BackgroundColor = 'w';

logTable = uitable(logGrid, ...
    'ColumnName',   {'#', 'Measure', 'Ear', 'Time'}, ...
    'ColumnWidth',  {'1x', '3x', '1x', '4x'}, ...
    'RowName',      {}, ...
    'Enable',       'inactive');
logTable.Layout.Row    = [1,2];
logTable.Layout.Column = 1;

logTableStyle = uistyle('HorizontalAlignment','center');
addStyle(logTable,logTableStyle);

refreshLog();

% Notes field
notesField = uieditfield(logGrid, 'text', ...
    'Value',       metadata.notes, ...
    'Placeholder', 'Session notes...');
notesField.Layout.Row    = 1;
notesField.Layout.Column = 2;

btnWrapPanel = uipanel(logGrid, 'BorderType', 'none', 'BackgroundColor', 'w');
btnWrapPanel.Layout.Row    = 2;
btnWrapPanel.Layout.Column = 2;

btnWrapGrid = uigridlayout(btnWrapPanel, [1 3]);
btnWrapGrid.ColumnWidth     = {'1x', 120, '1x'};
btnWrapGrid.Padding         = [0 0 0 0];
btnWrapGrid.BackgroundColor = 'w';

saveNotesBtn = uibutton(btnWrapGrid, 'Text', 'Save Notes', ...
    'ButtonPushedFcn', @(~,~) onNotesChanged());
saveNotesBtn.Layout.Row    = 1;
saveNotesBtn.Layout.Column = 2;


%% --- Session timer ---
try
    session_start = tic;
    tim = timer(...
        'ExecutionMode', 'fixedRate', ...
        'Period',        1, ...
        'TimerFcn',      @(~,~) updateTimer());
    start(tim);
catch
    tim = [];
end
%% ================================================================
%  CALLBACKS
%% ================================================================
    function launchABR()
        metadata = load_or_init_metadata(save_dir);
        abr_gui(save_dir, metadata);
    end

    function launchEFR()
         metadata = load_or_init_metadata(save_dir);
        efr_gui(save_dir, metadata); 
    end

    function launchDPOAE()
         metadata = load_or_init_metadata(save_dir);
        dpoae_gui(save_dir, metadata); 
    end

    function launchEarCal()
         metadata = load_or_init_metadata(save_dir);
        ear_cal_gui(save_dir, metadata);
    end

    function launchTransducer()
         metadata = load_or_init_metadata(save_dir);
        transducer_check_gui(save_dir, metadata);
    end

    function refreshFromDisk()
        metadata = session_load(save_dir);
        refreshLog();
    end

    function onChangeSession()

        [new_dir, new_meta] = session_load_or_create();

        if isempty(new_dir); return; end

        save_dir = new_dir;
        metadata = new_meta;

        % Update subject bar
        updateSessionBar();
        refreshLog();
        notesField.Value = metadata.notes;
    end

    function onNotesChanged()
        metadata.notes = notesField.Value;
        metadata = session_save_metadata(save_dir, metadata);
    end

    function onClose()
        stop(tim);
        delete(tim);
        delete(fig);
    end

%% ================================================================
%  NESTED HELPERS
%% ================================================================

    function refreshLog()
        if ~isfield(metadata, 'run_log') || isempty(metadata.run_log)
            logTable.Data = {};
            return
        end
        log   = metadata.run_log;
        n     = length(log);
        tdata = cell(n, 4);
        for i = 1:n
            entry = log(n - i + 1); % reverse order
            tdata{i,1} = entry.run_number;
            tdata{i,2} = entry.measure_type;
            tdata{i,3} = entry.ear;
            tdata{i,4} = entry.timestamp;
        end
        logTable.Data = tdata;
    end

    function updateSessionBar()
        % Rebuild info chips with new session info
        makeInfoChip(sessGrid, 'Subject',  metadata.subject_id, 1);
        makeInfoChip(sessGrid, 'Species',  metadata.species,    2);
        makeInfoChip(sessGrid, 'Operator', metadata.operator,   3);
        makeInfoChip(sessGrid, 'Date',     metadata.date,       4);
        makeInfoChip(sessGrid, 'Project',  metadata.project,    5);
    end

    function updateTimer()
        if ~isvalid(fig); stop(tim); return; end
        elapsed    = toc(session_start);
        hrs        = floor(elapsed / 3600);
        mins       = floor(mod(elapsed, 3600) / 60);
        secs       = floor(mod(elapsed, 60));
        if hrs > 0
            timerLbl.Text = sprintf('%02d:%02d:%02d', hrs, mins, secs);
        else
            timerLbl.Text = sprintf('%02d:%02d', mins, secs);
        end
    end

function metadata = load_or_init_metadata(save_dir)
    metadata_file = fullfile(save_dir, 'session_metadata.mat');
    if exist(metadata_file, 'file')
        loaded   = load(metadata_file, 'metadata');
        metadata = loaded.metadata;
        fprintf('Loaded existing session: %d runs so far.\n', metadata.n_runs);
    else
        metadata = session_init(save_dir);
        save(metadata_file, 'metadata');
        fprintf('New session initialized.\n');
    end
end

end   % hearing_lab_gui

%% ================================================================
%  LOCAL FUNCTIONS
%% ================================================================

function makeInfoChip(parent, labelStr, valueStr, col)
% Check if chip already exists and update, otherwise create
existing = findobj(parent, 'Tag', sprintf('chip_val_%d', col));
if ~isempty(existing)
    existing.Text = valueStr;
    return
end

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
lbl.Layout.Row = 1; lbl.Layout.Column = 1;
val = uilabel(g, 'Text', valueStr, 'FontSize', 12, ...
    'FontWeight', 'bold', 'Tag', sprintf('chip_val_%d', col));
val.Layout.Row = 2; val.Layout.Column = 1;
end

function btn = makeMeasureBtn(parent, label, col, enabled, callback)

% --- Measure Button Colors --- 
measure_colors = {
    [0.11 0.62 0.46], [0.88 0.96 0.93];   % 1 ABR
    [0.10 0.15 0.45], [0.85 0.88 0.96];   % 2 EFR
    [0.55 0.05 0.10], [0.96 0.88 0.88];   % 3 DPOAE
    [0.35 0.10 0.40], [0.93 0.88 0.96];   % 4 SFOAE
    [0.60 0.35 0.00], [0.96 0.92 0.85];   % 5 TEOAE
    [0.00 0.45 0.55], [0.85 0.94 0.96];   % 6 MEMR
    [0.22 0.54 0.85], [0.88 0.93 0.98];   % 7 Ear Cal
    [0.50 0.50 0.00], [0.96 0.96 0.85];   % 8 Transducer
    [0.45 0.25 0.10], [0.94 0.90 0.85];   % 9 FPL
};

btn = uibutton(parent, ...
    'Text',    label, ...
    'Enable',  bool2str(enabled), ...
    'FontSize', 13, ... 
    'FontWeight', 'bold');
btn.Layout.Row    = 1;
btn.Layout.Column = col;

if enabled && ~isempty(callback)
    btn.ButtonPushedFcn = callback;
    btn.BackgroundColor = measure_colors{col, 1};
    btn.FontColor = measure_colors{col, 2}; 
else
    btn.BackgroundColor = [0.93 0.93 0.93];
    btn.FontColor       = [0.65 0.65 0.65];
end
end

function s = bool2str(tf)
if tf; s = 'on'; else; s = 'off'; end
end