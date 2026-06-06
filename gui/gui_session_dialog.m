function sess = gui_session_dialog()
% GUI_SESSION_DIALOG  Modal dialog to collect subject info and create Session.
% Returns a Session object on success, or [] if cancelled.

%% --- Figure ---

dlg = uifigure( ...
    'Name',     'Start New Session', ...
    'Position', [500 400 360 300], ...
    'Resize',   'off');

grid = uigridlayout(dlg, [10 2]);
grid.RowHeight     = {24, 30, 14, 30, 14, 30, 14, 30, 14, 30};
grid.ColumnWidth   = {'1x', '1x'};
grid.Padding       = [20 16 20 16];
grid.RowSpacing    = 0;
grid.ColumnSpacing = 12;

%% --- Title ---

titleLbl = uilabel(grid, ...
    'Text',       'Enter Session Information:', ...
    'FontSize',   15, ...
    'FontWeight', 'bold');
titleLbl.Layout.Row    = 1;
titleLbl.Layout.Column = [1 2];

%% --- Subject ID ---

subjectLbl = uilabel(grid, ...
    'Text',      'Subject ID', ...
    'FontColor', [0.45 0.45 0.45], ...
    'FontSize',  11);
subjectLbl.Layout.Row    = 3;
subjectLbl.Layout.Column = 1;

subjectField = uieditfield(grid, 'text', ...
    'Placeholder', 'e.g. Q000');
subjectField.Layout.Row    = 4;
subjectField.Layout.Column = 1;

%% --- Operator ---

operatorLbl = uilabel(grid, ...
    'Text',      'Operator', ...
    'FontColor', [0.45 0.45 0.45], ...
    'FontSize',  11);
operatorLbl.Layout.Row    = 3;
operatorLbl.Layout.Column = 2;

operatorField = uieditfield(grid, 'text', ...
    'Placeholder', 'e.g. SHauser');
operatorField.Layout.Row    = 4;
operatorField.Layout.Column = 2;

%% --- Species ---

speciesLbl = uilabel(grid, ...
    'Text',      'Species', ...
    'FontColor', [0.45 0.45 0.45], ...
    'FontSize',  11);
speciesLbl.Layout.Row    = 5;
speciesLbl.Layout.Column = 1;

speciesField = uidropdown(grid, ...
    'Items', {'Chinchilla', 'Human', 'Mouse', 'Gerbil'}, ...
    'Value', 'Chinchilla');
speciesField.Layout.Row    = 6;
speciesField.Layout.Column = 1;

%% --- Exposure ---

groupLbl = uilabel(grid, ...
    'Text',      'Exp. Group', ...
    'FontColor', [0.45 0.45 0.45], ...
    'FontSize',  11);
groupLbl.Layout.Row    = 7;
groupLbl.Layout.Column = 1;

groupField = uidropdown(grid, ...
    'Items', {'Baseline', 'PTS', 'TTS', 'CA', 'GE', 'FM'}, ...
    'Value', 'Baseline');
groupField.Layout.Row    = 8;
groupField.Layout.Column = 1;

%% --- Notes ---

notesLbl = uilabel(grid, ...
    'Text',      'Notes (optional)', ...
    'FontColor', [0.45 0.45 0.45], ...
    'FontSize',  11);
notesLbl.Layout.Row    = 5;
notesLbl.Layout.Column = 2;

notesField = uieditfield(grid, 'text', ...
    'Placeholder', 'e.g. baseline, 2wk post-noise');
notesField.Layout.Row    = 6;
notesField.Layout.Column = 2;

%% --- Buttons ---

btnGrid = uigridlayout(grid, [1 2]);
btnGrid.Layout.Row    = 10;
btnGrid.Layout.Column = [1 2];
btnGrid.ColumnWidth   = {'1x', '1x'};
btnGrid.Padding       = [0 8 0 0];
btnGrid.ColumnSpacing = 10;

cancelBtn = uibutton(btnGrid, ...
    'Text',            'Cancel', ...
    'ButtonPushedFcn', @(~,~) cancelPressed());
cancelBtn.Layout.Row    = 1;
cancelBtn.Layout.Column = 1;

okBtn = uibutton(btnGrid, ...
    'Text',            'Start session', ...
    'BackgroundColor', [0.11 0.62 0.46], ...
    'FontColor',       [0.88 0.96 0.93], ...
    'ButtonPushedFcn', @(~,~) okPressed());
okBtn.Layout.Row    = 1;
okBtn.Layout.Column = 2;

%% --- State ---

sess      = [];
cancelled = false;

%% --- Callbacks ---

    function okPressed()
        subjectID = strtrim(subjectField.Value);
        operator  = strtrim(operatorField.Value);
        species   = speciesField.Value;
        notes     = strtrim(notesField.Value);
        group     = groupField.Value; 

        if isempty(subjectID)
            uialert(dlg, 'Subject ID is required.', 'Missing field');
            return
        end
        if isempty(operator)
            uialert(dlg, 'Operator name is required.', 'Missing field');
            return
        end

        try
            sess       = Session(subjectID, species, operator);
            sess.Notes = notes;
            sess.Group = group; 
        catch e
            uialert(dlg, e.message, 'Session error');
            return
        end

        delete(dlg);
    end

    function cancelPressed()
        cancelled = true;
        delete(dlg);
    end

%% --- Block until closed ---

waitfor(dlg);

if cancelled || isempty(sess)
    sess = [];
end

end