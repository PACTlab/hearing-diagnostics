function probecal_gui(save_dir, metadata)
% PROBECAL_GUI  FPL probe (Thevenin) calibration window.
%
% Works with or without a session:
%   probecal_gui()                    calibration only (no subject)
%   probecal_gui(save_dir, metadata)  opened from the session launcher
%
% The calibration is equipment data, not subject data: it is always saved
% to cfg.calibration.fpl_data_dir, never to the session folder. The session
% is shown in the header for context only.
%
% Does not block (no uiwait), so the launcher can register the window as
% soon as this function returns.

WINDOW_LABEL = 'FPL Cal';      % must match the label the launcher uses
PREF_DB      = 20*log10(20e-6); % dB re 1 Pa of 20 uPa; dB SPL = dB(Pa) - PREF_DB
F_LIM        = [100, 24e3];

if nargin < 1, save_dir = ''; end
if nargin < 2, metadata = []; end

%% --- Load ---

cfg    = config_load();
params = probecal_default_params();
n_cav  = numel(params.cav_lengths_mm);

%% --- Hardware ---
% No silent fallback: if the TDT is missing and stub mode was not asked
% for, the operator must choose stub mode explicitly or the window stays
% unable to measure.

tdt = [];
no_hardware = false;
if ~params.stub_mode
    tdt = tdt_init(cfg, 'acoustic');
    no_hardware = isempty(tdt);
end

%% --- State ---

R       = cell(1, n_cav);  % per-cavity results, by cavity number
fit     = [];
saved   = false;
busy    = false;
close_requested = false;
hist    = loadHistory();

%% --- Figure ---

fig = uifigure('Name', 'FPL Probe Cal', 'Position', [100 80 1000 760], ...
    'CloseRequestFcn', @(~,~) onClose());
setappdata(fig, 'HearingMeasureLabel', WINDOW_LABEL);

main = uigridlayout(fig, [5 1]);
main.RowHeight  = {44, 44, 58, '1x', 90};
main.Padding    = [10 10 10 10];
main.RowSpacing = 6;

% --- Row 1: header ---
hdr = uigridlayout(main, [1 4]);
hdr.ColumnWidth = {'1x', 220, 120, 160};
hdr.Padding = [0 0 0 0];

uilabel(hdr, 'Text', 'FPL Probe Calibration', 'FontSize', 18, 'FontWeight', 'bold');
uilabel(hdr, 'Text', sessionText(), 'FontColor', [0.4 0.4 0.4]);
modeLbl = uilabel(hdr, 'FontSize', 11, 'FontWeight', 'bold', ...
    'HorizontalAlignment', 'center', 'FontColor', [1 1 1]);
statusLbl = uilabel(hdr, 'Text', '● Idle', 'FontSize', 13, ...
    'FontWeight', 'bold', 'FontColor', [0.5 0.5 0.5]);

% --- Row 2: settings ---
set2 = uigridlayout(main, [1 6]);
set2.ColumnWidth = {'1x', 260, 120, 70, 110, '1x'};
set2.Padding = [0 0 0 0];

uilabel(set2, 'Text', sprintf('Probe: %s', cfg.equipment.probe.id), 'FontWeight', 'bold');
uilabel(set2, 'Text', sprintf('Set mic amp dial to:  %g', params.mic_gain_dial), ...
    'FontSize', 14, 'FontWeight', 'bold', 'FontColor', [0.55 0.05 0.10]);
uilabel(set2, 'Text', 'Cavity temp (°C):', 'HorizontalAlignment', 'right');
tempField = uieditfield(set2, 'numeric', 'Value', params.CavTemp_C, ...
    'Limits', [10 40], 'ValueDisplayFormat', '%.1f');
startOverBtn = uibutton(set2, 'Text', 'Start over', ...
    'ButtonPushedFcn', @(~,~) onStartOver());

% --- Row 3: cavity buttons, fit, save ---
row3 = uigridlayout(main, [1 n_cav + 3]);
row3.ColumnWidth = [{70}, repmat({'1x'}, 1, n_cav), {110, 110}];
row3.Padding = [0 0 0 0];

uilabel(row3, 'Text', 'Cavity:', 'FontWeight', 'bold');
cavBtn = gobjects(1, n_cav);
for k = 1:n_cav
    cavBtn(k) = uibutton(row3, ...
        'Text', sprintf('%d\n%.1f mm', k, params.cav_lengths_mm(k)), ...
        'FontWeight', 'bold', ...
        'ButtonPushedFcn', @(~,~) onCavity(k));
end
fitBtn  = uibutton(row3, 'Text', 'Fit',  'FontWeight', 'bold', ...
    'ButtonPushedFcn', @(~,~) onFit());
saveBtn = uibutton(row3, 'Text', 'Save', 'FontWeight', 'bold', ...
    'ButtonPushedFcn', @(~,~) onSave());

% --- Row 4: plots ---
pg = uigridlayout(main, [2 2]);
pg.Padding = [0 0 0 0];
ax1 = makeAx(pg, 'Cavity response', 'dB SPL per V');
ax2 = makeAx(pg, 'Response vs noise floor', 'dB SPL per V');
ax3 = makeAx(pg, 'Source pressure |Ps|', 'dB SPL per V');
ax4 = makeAx(pg, 'Source impedance |Zs|', 'dB');

% --- Row 5: messages ---
msgArea = uitextarea(main, 'Editable', 'off', 'FontName', 'Consolas', 'Value', {''});

%% --- Initial state ---

refreshMode();
refreshButtons();
addMsg(hist_message());

if no_hardware
    choice = uiconfirm(fig, ...
        ['No TDT connection. A calibration cannot be made without ' ...
         'hardware.\n\nRun in stub mode to test the software? Stub ' ...
         'calibrations are saved separately and never used by measures.'], ...
        'No hardware', 'Options', {'Run in stub mode', 'Close'}, ...
        'DefaultOption', 2, 'CancelOption', 2, 'Icon', 'warning');
    if strcmp(choice, 'Run in stub mode')
        params.stub_mode = true;
        no_hardware = false;
        hist = loadHistory();
        refreshMode();
        refreshButtons();
        addMsg('Running in STUB mode.');
    else
        addMsg('No hardware. Close this window, check the RZ6, and reopen.');
    end
end

%% ================================================================
%  CALLBACKS
%% ================================================================

    function onCavity(k)
        if isempty(R{k}) && all(cellfun(@isempty, R))
            params.CavTemp_C = tempField.Value;   % fixed for this calibration
        end
        if ~isempty(fit)
            fit = [];
            saved = false;
            clearFitPlots();
            addMsg('Cavity changed: previous fit discarded.');
        end

        setBusy(true, sprintf('● Cavity %d...', k));
        cavBtn(k).BackgroundColor = [1.0 0.93 0.55];
        try
            res = probecal_measure_cavity(cfg, params, tdt, k);
            R{k} = res;
            plotCavity(k);
            if res.ok
                addMsg(sprintf('Cavity %d OK: length %s cm, SNR %s dB, kept %s.', k, ...
                    fmtPair(res.length_mm, '%.2f'), fmtPair(res.snr_db, '%.0f'), ...
                    sprintf('%d/%d', res.n_good(1), res.n_total(1))));
            else
                addMsg(sprintf('Cavity %d FLAGGED:', k));
                cellfun(@(s) addMsg(['   ' s]), res.flags);
            end
        catch e
            addMsg(sprintf('Cavity %d ERROR: %s', k, e.message));
            uialert(fig, e.message, sprintf('Cavity %d failed', k));
        end
        setBusy(false);
    end

    function onFit()
        setBusy(true, '● Fitting...');
        try
            fit = probecal_fit(R, params);
            saved = false;
            plotFit();
            for d = 1:numel(fit.drivers)
                addMsg(sprintf('Driver %d: fit error %.3g (limit %g), reflection %.3f.', ...
                    fit.drivers(d), fit.error(d), params.max_error, fit.reflection(d)));
            end
            cellfun(@(s) addMsg(['   FLAG: ' s]), fit.flags);
            if fit.ok
                addMsg('Fit PASSED. Ready to save.');
            else
                addMsg('Fit did NOT pass. Re-run flagged cavities, or save as failed.');
            end
        catch e
            fit = [];
            addMsg(['Fit ERROR: ' e.message]);
            uialert(fig, e.message, 'Fit failed');
        end
        setBusy(false);
    end

    function onSave()
        opts = struct();
        if ~fit.ok
            choice = uiconfirm(fig, ...
                ['This fit did not pass. Save it as a FAILED calibration? ' ...
                 'It will be kept for the record but never used by measures.'], ...
                'Save failed fit', 'Options', {'Save as failed', 'Cancel'}, ...
                'DefaultOption', 2, 'CancelOption', 2, 'Icon', 'warning');
            if strcmp(choice, 'Cancel'), return, end
            reason = inputdlg('Why save a failed calibration?', 'Reason');
            if isempty(reason) || isempty(strtrim(reason{1})), return, end
            opts.allow_fail  = true;
            opts.fail_reason = reason{1};
        end
        c = inputdlg('Comment (optional)', 'Save calibration');
        if ~isempty(c), opts.comment = c{1}; end

        try
            path = probecal_save(cfg, fit, R, params, opts);
            saved = true;
            addMsg(['Saved: ' path]);
            addMsg('Remember to turn off the microphone.');
        catch e
            addMsg(['Save ERROR: ' e.message]);
            uialert(fig, e.message, 'Save failed');
        end
        refreshButtons();
    end

    function onStartOver()
        if ~all(cellfun(@isempty, R)) && ~saved
            choice = uiconfirm(fig, 'Discard all measured cavities?', 'Start over', ...
                'Options', {'Discard', 'Cancel'}, 'DefaultOption', 2, 'CancelOption', 2);
            if strcmp(choice, 'Cancel'), return, end
        end
        R = cell(1, n_cav);
        fit = [];
        saved = false;
        cla(ax1); cla(ax2); clearFitPlots();
        addMsg('Started over.');
        refreshButtons();
    end

    function onClose()
        if busy
            % Deleting the figure mid-acquisition would leave the loop
            % plotting into dead axes; finish the cavity, then close.
            close_requested = true;
            addMsg('Will close when the current step finishes.');
            return
        end
        if ~all(cellfun(@isempty, R)) && ~saved
            choice = uiconfirm(fig, 'Close without saving this calibration?', 'Unsaved', ...
                'Options', {'Close', 'Cancel'}, 'DefaultOption', 2, 'CancelOption', 2);
            if strcmp(choice, 'Cancel'), return, end
        end
        shutdownHardware();
        delete(fig);
    end

%% ================================================================
%  HELPERS
%% ================================================================

    function setBusy(on, txt)
        busy = on;
        if on
            statusLbl.Text = txt;
            statusLbl.FontColor = [0.85 0.55 0.0];
            set([cavBtn, fitBtn, saveBtn, startOverBtn], 'Enable', 'off');
            tempField.Enable = 'off';
            drawnow
        else
            statusLbl.Text = '● Idle';
            statusLbl.FontColor = [0.5 0.5 0.5];
            refreshButtons();
            if close_requested
                close_requested = false;
                onClose();
            end
        end
    end

    function refreshButtons()
        can_measure = ~no_hardware;
        measured = ~cellfun(@isempty, R);
        for k = 1:n_cav
            cavBtn(k).Enable = onoff(can_measure);
            if ~measured(k)
                cavBtn(k).BackgroundColor = [0.93 0.93 0.93];
            elseif R{k}.ok
                cavBtn(k).BackgroundColor = [0.75 0.90 0.75];
            else
                cavBtn(k).BackgroundColor = [1.00 0.80 0.55];
            end
        end
        fitBtn.Enable  = onoff(can_measure && all(measured));
        saveBtn.Enable = onoff(~isempty(fit) && ~saved);
        if ~isempty(fit) && ~fit.ok
            saveBtn.Text = 'Save (failed)';
        else
            saveBtn.Text = 'Save';
        end
        startOverBtn.Enable = onoff(any(measured));
        % Temperature is part of the conditions every cavity must share.
        tempField.Enable = onoff(can_measure && ~any(measured));
    end

    function refreshMode()
        if params.stub_mode
            modeLbl.Text = '⚠ STUB MODE';
            modeLbl.BackgroundColor = [0.85 0.20 0.10];
        elseif no_hardware
            modeLbl.Text = 'NO HARDWARE';
            modeLbl.BackgroundColor = [0.45 0.45 0.45];
        else
            modeLbl.Text = 'TDT ON';
            modeLbl.BackgroundColor = [0.11 0.62 0.46];
        end
    end

    function h = loadHistory()
        current = probecal_current_conditions(cfg, tdt, params.delay_comp);
        current.buffer_size = params.BufferSize;
        h = probecal_history(cfg, current, struct('allow_stub', params.stub_mode));
    end

    function s = hist_message()
        if hist.n == 0
            s = 'No previous calibrations for this probe: no overlays yet.';
        else
            s = sprintf('Comparing against %d previous calibration(s); last on %s.', ...
                hist.n, char(hist.last.fit.conditions.fitted_at, 'yyyy-MM-dd HH:mm'));
        end
    end

    function plotCavity(k)
        res = R{k};
        f = res.freq(2:end);
        col = lines(numel(res.conditions.drivers));
        cla(ax1); cla(ax2);

        % History: norm band and last time, same cavity
        j = [];
        if hist.n > 0
            j = find(hist.last.fit.cavities == k, 1);
        end
        if ~isempty(j)
            for d = 1:numel(res.conditions.drivers)
                if hist.n > 1
                    band(ax1, f, hist.norm.pcav_db_min(2:end, j, d) - PREF_DB, ...
                                 hist.norm.pcav_db_max(2:end, j, d) - PREF_DB, col(d, :));
                end
                plot(ax1, f, 20*log10(abs(hist.last.fit.pcav(2:end, j, d))) - PREF_DB, ...
                    '--', 'Color', col(d, :), 'LineWidth', 1);
            end
        end
        for d = 1:numel(res.conditions.drivers)
            plot(ax1, f, 20*log10(abs(res.H(2:end, d))) - PREF_DB, ...
                'Color', col(d, :), 'LineWidth', 1.8);
            plot(ax2, f, 20*log10(abs(res.H(2:end, d))) - PREF_DB, ...
                'Color', col(d, :), 'LineWidth', 1.5);
            plot(ax2, f, 20*log10(abs(res.H_noise(2:end, d))) - PREF_DB, ...
                ':', 'Color', col(d, :), 'LineWidth', 1);
        end
        title(ax1, sprintf('Cavity %d (%.1f mm): now (solid), last (dashed)', ...
            k, params.cav_lengths_mm(k)));
        title(ax2, sprintf('Cavity %d: response (solid), noise floor (dotted)', k));
    end

    function plotFit()
        clearFitPlots();
        f = fit.freq(2:end);
        col = lines(numel(fit.drivers));
        for d = 1:numel(fit.drivers)
            if hist.n > 1
                band(ax3, f, hist.norm.Ps_db_min(2:end, d) - PREF_DB, ...
                             hist.norm.Ps_db_max(2:end, d) - PREF_DB, col(d, :));
                band(ax4, f, hist.norm.Zs_db_min(2:end, d), ...
                             hist.norm.Zs_db_max(2:end, d), col(d, :));
            end
            if hist.n > 0
                plot(ax3, f, 20*log10(abs(hist.last.fit.Ps(2:end, d))) - PREF_DB, ...
                    '--', 'Color', col(d, :));
                plot(ax4, f, 20*log10(abs(hist.last.fit.Zs(2:end, d))), ...
                    '--', 'Color', col(d, :));
            end
            plot(ax3, f, 20*log10(abs(fit.Ps(2:end, d))) - PREF_DB, ...
                'Color', col(d, :), 'LineWidth', 1.8);
            plot(ax4, f, 20*log10(abs(fit.Zs(2:end, d))), ...
                'Color', col(d, :), 'LineWidth', 1.8);
        end
        xline(ax3, params.f_err_khz * 1000, ':');
        xline(ax4, params.f_err_khz * 1000, ':');
        title(ax3, sprintf('|Ps|  err %s', fmtPair(fit.error, '%.2g')));
        title(ax4, '|Zs|: now (solid), last (dashed)');
    end

    function clearFitPlots()
        cla(ax3); cla(ax4);
        title(ax3, 'Source pressure |Ps|');
        title(ax4, 'Source impedance |Zs|');
    end

    function addMsg(s)
        entry = sprintf('%s  %s', char(datetime('now'), 'HH:mm:ss'), s);
        msgArea.Value = [{entry}; msgArea.Value(:)];
    end

    function shutdownHardware()
        if isempty(tdt), return, end
        try
            invoke(tdt.RZ, 'SetTagVal', 'attA', cfg.hardware.max_atten_db);
            invoke(tdt.RZ, 'SetTagVal', 'attB', cfg.hardware.max_atten_db);
        catch
        end
        try
            close_play_circuit(tdt.f1RZ, tdt.RZ);
        catch e
            warning('probecal_gui:shutdown', 'Circuit close failed: %s', e.message);
        end
        tdt = [];
    end

    function s = sessionText()
        if isempty(metadata) || ~isfield(metadata, 'subject_id')
            s = 'No session (calibration only)';
        else
            s = sprintf('Session: %s', metadata.subject_id);
        end
    end

    function ax = makeAx(parent, ttl, ylab)
        ax = uiaxes(parent, 'XScale', 'log', 'XLim', F_LIM, 'Box', 'on');
        hold(ax, 'on'); grid(ax, 'on');
        title(ax, ttl); ylabel(ax, ylab); xlabel(ax, 'Frequency (Hz)');
    end

end

%% ================================================================
%  LOCAL FUNCTIONS
%% ================================================================

function band(ax, f, lo, hi, c)
fill(ax, [f; flipud(f)], [lo; flipud(hi)], c, ...
    'FaceAlpha', 0.15, 'EdgeColor', 'none');
end

function s = fmtPair(v, fmt)
s = strjoin(arrayfun(@(x) sprintf(fmt, x), v, 'UniformOutput', false), ' / ');
end

function s = onoff(tf)
if tf, s = 'on'; else, s = 'off'; end
end