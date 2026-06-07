function [save_dir, metadata] = session_load_or_create()
% SESSION_LOAD_OR_CREATE  Entry point for all measure GUIs.
%
% Presents three options if no active session is passed:
%   1. New session    — runs gui_session_dialog
%   2. Resume session — folder picker, loads existing metadata
%   3. Dummy session  — for testing, no subject info required
%
% Returns empty if user cancels.
%
% Outputs:
%   save_dir  - full path to session folder
%   metadata  - session metadata struct

save_dir = '';
metadata = [];

%% --- Choice dialog ---

choice = session_launch_dialog();

switch choice
    case 'New'
        [save_dir, metadata] = handleNew();

    case 'Resume'
        [save_dir, metadata] = handleResumeLast();

    case 'ResumeOther'
        [save_dir, metadata] = handleResumeOther();

    case 'Dummy'
        [save_dir, metadata] = session_dummy();

    otherwise
        % Cancelled
        return
end

end

%% ================================================================
%  LOCAL FUNCTIONS
%% ================================================================

function choice = session_launch_dialog()
% Small dialog with three buttons

dlg = uifigure(...
    'Name',     'Start', ...
    'Position', [560 440 300 170], ...
    'Resize',   'off');

grid = uigridlayout(dlg, [2 1]);
grid.RowHeight   = {30, 100};
grid.Padding     = [20 16 20 16];
grid.RowSpacing  = 8;

titleLbl = uilabel(grid, ...
    'Text',                'Select session mode:', ...
    'FontSize',            16, ...
    'FontWeight',          'bold', ...
    'HorizontalAlignment', 'center');
titleLbl.Layout.Row    = 1;
titleLbl.Layout.Column = 1;

btnGrid1 = uigridlayout(grid, [2 2]);
btnGrid1.Layout.Row    = 2;
btnGrid1.Layout.Column = 1;
btnGrid1.RowHeight = {'1x', '1x'}; 
btnGrid1.ColumnWidth   = {'1x', '1x'};
btnGrid1.Padding       = [0 0 0 0];
btnGrid1.ColumnSpacing = 8;
btnGrid1.RowSpacing = 8; 

newBtn = uibutton(btnGrid1, ...
    'Text',            'New session', ...
    'BackgroundColor', [102,194,165]./255, ...
    'FontSize',        14, ...
    'FontColor',       [0.1200    0.0400    0.0700], ...
    'ButtonPushedFcn', @(~,~) selectChoice('New'));
newBtn.Layout.Row    = 1;
newBtn.Layout.Column = 1;

resumeLastBtn = uibutton(btnGrid1, ...
    'Text',            'Resume Last session', ...
    'BackgroundColor', [141,160,203]./255, ...
    'FontColor',       [0.1200    0.0400    0.0700], ...
    'FontSize',        14, ...
    'ButtonPushedFcn', @(~,~) selectChoice('Resume'));
resumeLastBtn.Layout.Row    = 1;
resumeLastBtn.Layout.Column = 2;

cfg      = config_load();
last_dir = cfg.last_session_dir;

if ~isempty(last_dir) && exist(last_dir, 'dir')
    try
        last_meta = session_load(last_dir);
        resumeLastBtn.Text = sprintf('Resume Last\n%s · %s', ...
            last_meta.subject_id, last_meta.date);
    catch
        resumeLastBtn.Text = 'Resume Last';
    end
else
    resumeLastBtn.Text     = 'Resume Last';
    resumeLastBtn.Enable   = 'off';
end

resumeBtn = uibutton(btnGrid1, ...
    'Text',            'Resume Other', ...
    'BackgroundColor', [231,138,195]./255, ...
    'FontColor',       [0.1200    0.0400    0.0700], ...
    'FontSize',        14, ...
    'ButtonPushedFcn', @(~,~) selectChoice('ResumeOther'));
resumeBtn.Layout.Row    = 2;
resumeBtn.Layout.Column = 1;

dummyBtn = uibutton(btnGrid1, ...
    'Text',            sprintf('Dummy session\n(testing only)'), ...
    'BackgroundColor', [252,141,98]./255, ...
    'FontColor',       [0.1200    0.0400    0.0700], ...    
    'FontSize',        14, ...
    'ButtonPushedFcn', @(~,~) selectChoice('Dummy'));
dummyBtn.Layout.Row    = 2;
dummyBtn.Layout.Column = 2;

choice    = '';
cancelled = false;

    function selectChoice(c)
        choice = c;
        delete(dlg);
    end

dlg.CloseRequestFcn = @(~,~) cancelDialog();

    function cancelDialog()
        cancelled = true;
        delete(dlg);
    end

waitfor(dlg);

if cancelled
    choice = '';
end

end


function [save_dir, metadata] = handleNew()
    save_dir = '';
    metadata = [];
    [save_dir, metadata] = gui_session_dialog();

    if ~isempty(save_dir)
        config_save_last_session(save_dir);
    end
end

function [save_dir, metadata] = handleResumeLast()
    save_dir = '';
    metadata = [];

    cfg      = config_load();
    last_dir = cfg.last_session_dir;

    if isempty(last_dir) || ~exist(last_dir, 'dir')
        uialert(uifigure, ...
            'No recent session found. Use Resume Other to browse.', ...
            'No recent session');
        return
    end

    try
        metadata = session_load(last_dir);
        save_dir = last_dir;
        fprintf('Resumed last session: %s | %s | runs: %d\n', ...
            metadata.subject_id, metadata.date, metadata.total_runs);
        config_save_last_session(save_dir);
    catch e
        uialert(uifigure, e.message, 'Could not load last session');
    end
end
function [save_dir, metadata] = handleResumeOther()
    save_dir = '';
    metadata = [];

    cfg        = config_load();
    start_path = cfg.data.root_dir;
    if ~exist(start_path, 'dir')
        start_path = pwd;
    end

    folder = uigetdir(start_path, 'Select session folder to resume');
    if isequal(folder, 0)
        return
    end

    try
        metadata = session_load(folder);
        save_dir = folder;
        fprintf('Resumed session: %s | %s | run %d\n', ...
            metadata.subject_id, metadata.date, metadata.total_runs);
    catch e
        uialert(uifigure, e.message, 'Invalid session folder');
    end
end