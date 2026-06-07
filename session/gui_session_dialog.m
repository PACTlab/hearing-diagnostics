function [save_dir, metadata] = gui_session_dialog()
% GUI_SESSION_DIALOG  Modal dialog to collect subject info and create Session.
% Returns a Session object on success, or [] if cancelled.

cfg     = config_load();
version = cfg.software_version;

%% --- Figure ---

dlg = uifigure( ...
    'Name',     'Start New Session', ...
    'Resize',   'off');

grid = uigridlayout(dlg, [17 2]);
grid.RowHeight     = {24, 34, 14, 30, 14, 30, 14, 30, 34, 14, 30, 14, 30, 34, 30, 14, 40};
grid.ColumnWidth   = {'1x', '1x'};
grid.Padding       = [20 16 20 16];
grid.RowSpacing    = 2;
grid.ColumnSpacing = 12;

height = sum(cell2mat(grid.RowHeight))+2.*17+32;

dlg.Position = [500 400 360 height];


%% --- Title ---

titleLbl = uilabel(grid, ...
    'Text',       'Enter Session Information:', ...
    'FontSize',   16, ...
    'FontWeight', 'bold');
titleLbl.Layout.Row    = 1;
titleLbl.Layout.Column = [1 2];

%% --- Headers ---

header1Lbl = uilabel(grid, ...
    'Text',       'Subject', ...
    'FontSize',   14, ...
    'FontWeight', 'bold', ...
    'VerticalAlignment', 'bottom');
header1Lbl.Layout.Row    = 2;
header1Lbl.Layout.Column = 1;

header2Lbl = uilabel(grid, ...
    'Text',       'Session', ...
    'FontSize',   14, ...
    'FontWeight', 'bold', ...
    'VerticalAlignment', 'bottom');
header2Lbl.Layout.Row    = 2;
header2Lbl.Layout.Column = 2;

header3Lbl = uilabel(grid, ...
    'Text',       'Project', ...
    'FontSize',   14, ...
    'FontWeight', 'bold', ...
    'VerticalAlignment', 'bottom');
header3Lbl.Layout.Row    = 9;
header3Lbl.Layout.Column = 1;

header4Lbl = uilabel(grid, ...
    'Text',       'Notes', ...
    'FontSize',   14, ...
    'FontWeight', 'bold', ...
    'VerticalAlignment', 'bottom');
header4Lbl.Layout.Row    = 14;
header4Lbl.Layout.Column = [1 2];
%% --- Subject Info ---

% --- Subj ID ---
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

% --- Species ---
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

% --- Sex ---
sexLbl = uilabel(grid, ...
    'Text',      'Sex', ...
    'FontColor', [0.45 0.45 0.45], ...
    'FontSize',  11);
sexLbl.Layout.Row    = 7;
sexLbl.Layout.Column = 1;

sexField = uidropdown(grid, ...
    'Items', {'Male', 'Female', 'Unknown'}, ...
    'Value', 'Male');
sexField.Layout.Row    = 8;
sexField.Layout.Column = 1;

%% --- Project Info ---

% --- Project Selection ---
projectLbl = uilabel(grid, ...
    'Text',      'Project Name', ...
    'FontColor', [0.45 0.45 0.45], ...
    'FontSize',  11);
projectLbl.Layout.Row    = 10;
projectLbl.Layout.Column = 1;

projectField = uidropdown(grid, ...
    'Items', getProjectNames());
projectField.Layout.Row    = 11;
projectField.Layout.Column = 1;

% --- Exposure ---
groupLbl = uilabel(grid, ...
    'Text',      'Exposure Group', ...
    'FontColor', [0.45 0.45 0.45], ...
    'FontSize',  11);
groupLbl.Layout.Row    = 12;
groupLbl.Layout.Column = 1;

groupField = uidropdown(grid, ...
    'Items', {'Baseline', 'PTS', 'TTS', 'CA', 'GE', 'FM'}, ...
    'Value', 'Baseline');
groupField.Layout.Row    = 13;
groupField.Layout.Column = 1;

% --- Exposure Date ---
expDateLbl = uilabel(grid, ...
    'Text',      'Exposure Date', ...
    'FontColor', [0.45 0.45 0.45], ...
    'FontSize',  11);
expDateLbl.Layout.Row    = 12;
expDateLbl.Layout.Column = 2;

expDateField = uidatepicker(grid);
expDateField.Layout.Row    = 13;
expDateField.Layout.Column = 2;

% --- Anesthesia ---
statusLbl = uilabel(grid, ...
    'Text',      'Status (Awake/Sed.)', ...
    'FontColor', [0.45 0.45 0.45], ...
    'FontSize',  11);
statusLbl.Layout.Row    = 10;
statusLbl.Layout.Column = 2;

statusField = uidropdown(grid, ...
    'Items', {'Awake', 'Ket/Xyl', 'Light Sed', 'Other (add notes)'}, ...
    'Value', 'Awake');
statusField.Layout.Row    = 11;
statusField.Layout.Column = 2;

%% --- Session Info ---

% --- Operator ---
operatorLbl = uilabel(grid, ...
    'Text',      'Operator(s) (F. Last)', ...
    'FontColor', [0.45 0.45 0.45], ...
    'FontSize',  11);
operatorLbl.Layout.Row    = 3;
operatorLbl.Layout.Column = 2;

operatorField = uieditfield(grid, 'text', ...
    'Placeholder', '');
operatorField.Layout.Row    = 4;
operatorField.Layout.Column = 2;

% --- Location ---
locationLbl = uilabel(grid, ...
    'Text',      'Test Location (univ-blg-rm)', ...
    'FontColor', [0.45 0.45 0.45], ...
    'FontSize',  11);
locationLbl.Layout.Row    = 5;
locationLbl.Layout.Column = 2;

locationField = uieditfield(grid, 'text', ...
    'Value', 'Pitt-BSP1-311B');
locationField.Layout.Row    = 6;
locationField.Layout.Column = 2;

% --- Software Version ---
versionField = uilabel(grid, ...
    'Text', sprintf('Software Version: %s', version), ...
    'HorizontalAlignment', 'center');
versionField.Layout.Row    = 8;
versionField.Layout.Column = 2;
%% --- Notes ---
notesField = uieditfield(grid, 'text', ...
    'Placeholder', 'e.g. baseline, 2wk post-noise');
notesField.Layout.Row    = 15;
notesField.Layout.Column = [1,2];

%% --- Buttons ---

btnGrid = uigridlayout(grid, [1 2]);
btnGrid.Layout.Row    = 17;
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

save_dir  = '';
metadata  = [];
cancelled = false;

%% --- Callbacks ---

    function okPressed()
        subjectID = strtrim(subjectField.Value);
        operator  = strtrim(operatorField.Value);

        if isempty(subjectID)
            uialert(dlg, 'Subject ID is required.', 'Missing field');
            return
        end
        if isempty(operator)
            uialert(dlg, 'Operator name is required.', 'Missing field');
            return
        end

        % Handle exposure date
        raw_date = expDateField.Value;
        group    = groupField.Value;

        if isnat(raw_date) || isempty(raw_date)
            if ~strcmp(group, 'Baseline')
                uialert(dlg, ...
                    sprintf('Exposure date is required for group: %s', group), ...
                    'Missing field');
                return
            end
            exposure_date = 'none';
        else
            exposure_date = datestr(raw_date, 'yyyy-mm-dd');
        end

        info.sex            = sexField.Value;
        info.location       = strtrim(locationField.Value);
        info.group          = group;
        info.exposure_date  = exposure_date;
        info.animal_status  = statusField.Value;
        info.notes          = strtrim(notesField.Value);
        info.software_ver   = version;
        info.project        = projectField.Value;   


        try
            [save_dir, metadata] = session_create(...
                subjectID, speciesField.Value, operator, info);
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

if cancelled
    save_dir = '';
    metadata = [];
end

end

%=========================
% Some local functions 
%=========================

function names = getProjectNames()
% Scan projects/ folder and return list of short_names
projects_dir = fullfile(fileparts(mfilename('fullpath')), ...
    '..', 'projects');
projects_dir = char(java.io.File(projects_dir).getCanonicalPath());

folders  = dir(projects_dir);
folders  = folders([folders.isdir]);
folders  = folders(~ismember({folders.name}, {'.', '..'}));

names = {};
for i = 1:length(folders)
    cfg_path = fullfile(projects_dir, folders(i).name, 'project_config.mat');
    if exist(cfg_path, 'file')
        names{end+1} = folders(i).name; %#ok<AGROW>
    end
end

% Make sure lab_default is always first
names = [{'lab_default'}, names(~strcmp(names, 'lab_default'))];
end