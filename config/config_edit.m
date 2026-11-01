% CONFIG_EDIT  View and update system_config.mat
% Run this script to inspect or change any system configuration value.
% Located in config/ alongside system_config.mat
%
% WHAT LIVES WHERE
%   config.hardware   RIG CONSTANTS. Change only if the RZ6 is replaced or
%                     rewired: sample rates, USB channel, mat2volts, circuits.
%   config.equipment  SWAPPABLE EQUIPMENT. Change when a probe, mic or amp is
%                     swapped. Each block carries an id; saved data and
%                     calibration files copy the whole block, and an FPL
%                     calibration is only valid for the probe id it recorded.
%   (not in config)   PER-RUN SETTINGS such as the mic amp dial. These are
%                     confirmed by the operator in each measure and saved
%                     with that measure's data.
%
% MIC GAIN CONVENTION (schema 2)
%   equipment.probe.mic_sens_v_per_pa is the BARE mic sensitivity and does
%   NOT include the amp. equipment.probe.amp_fixed_gain_db is the amp's fixed
%   10x stage. The dial is per-run, so the total gain a measure divides by is
%       amp_fixed_gain_db + 20*log10(dial)
%   dial at 1 -> 20 dB total, dial at 10 -> 40 dB total.
%   Schema 1 stored a sensitivity that already included the 10x AND a gain
%   that included it again, so pressures came out 20 dB low.
%
% PATHS: store them RELATIVE to the repo root (e.g. 'data', 'hardware/circuits').
% config_load expands them to absolute at load time. Use forward slashes —
% they work on every platform. Only use an absolute path if the target is
% genuinely outside the repo, such as a network share.

%% --- Load current config ---

config_dir  = fullfile(config_repo_root(), 'config');
config_path = fullfile(config_dir, 'system_config.mat');

if ~exist(config_path, 'file')
    error('config_edit:notFound', 'system_config.mat not found at: %s', config_path);
end

loaded   = load(config_path);
config   = loaded.config;
original = config;   % kept for change detection at the bottom

%% --- Schema migration (runs once) ---

TARGET_SCHEMA = 2;

if config.schema_version < TARGET_SCHEMA
    backup_path = fullfile(config_dir, sprintf('system_config_backup_schema%d_%s.mat', ...
        config.schema_version, datestr(now, 'yyyymmdd_HHMMSS')));
    copyfile(config_path, backup_path);
    fprintf('\nMigrating config from schema %d to %d.\n', ...
        config.schema_version, TARGET_SCHEMA);
    fprintf('Backup written to: %s\n', backup_path);

    config = migrate_1_to_2(config);

    fprintf(['\nNOTE: hardware.mic_sens_v_per_pa and hardware.mic_gain_db have ' ...
             'been REMOVED.\nAny measure that read them will now error on ' ...
             'purpose. Update it to use\nequipment.probe and a per-run dial ' ...
             'setting (see the header of this file).\n']);
end

%% --- Display ---

fprintf('\n=== Current System Configuration ===\n\n');
printVal(config, 'Software version',     'software_version',        '%s');
printVal(config, 'Schema version',       'schema_version',          '%d');

fprintf('\n--- Rig constants (hardware) ---\n');
printVal(config, 'Hardware type',        'hardware.type',           '%s');
printVal(config, 'Playback sample rate', 'hardware.fs_playback_hz', '%.3f Hz');
printVal(config, 'Record sample rate',   'hardware.fs_record_hz',   '%.3f Hz');
printVal(config, 'USB channel',          'hardware.usb_ch',         '%d');
printVal(config, 'Figure number',        'hardware.fig_num',        '%d');
printVal(config, 'N channels',           'hardware.n_channels',     '%d');
printVal(config, 'Mat 2 volts',          'hardware.mat2volts',      '%g V full scale');
printVal(config, 'Electrode gain',       'hardware.electrode_gain', '%g (linear, applied in RPvds circuit)');

fprintf('\n--- Swappable equipment ---\n');
printVal(config, 'Probe id',             'equipment.probe.id',                '%s');
printVal(config, 'Probe description',    'equipment.probe.description',       '%s');
printVal(config, 'Mic sensitivity',      'equipment.probe.mic_sens_v_per_pa', '%g V/Pa (bare mic, excludes amp)');
printVal(config, 'Sensitivity source',   'equipment.probe.mic_sens_source',   '%s');
printVal(config, 'Amp fixed gain',       'equipment.probe.amp_fixed_gain_db', '%g dB (dial is set per run)');

fprintf('\n--- Calibration ---\n');
printVal(config, 'Transducer cal max age', 'calibration.max_age_days', '%d days');

fprintf('\n--- Paths (stored -> resolved) ---\n');
printPath(config, 'Circuit folder',        'hardware.circuit_dir');
printPath(config, 'Data root',             'data.root_dir');
printPath(config, 'FPL cal data folder',   'calibration.fpl_data_dir');
printPath(config, 'Active transducer cal', 'calibration.active_transducer_file');
printPath(config, 'Pinned FPL cal',        'calibration.active_fpl_file');
printPath(config, 'Last session',          'last_session_dir');
fprintf('\n');

%% --- Edit values here ---
% Uncomment and change any line below, then run the script to save.

% config.software_version                     = '1.0.0';

% --- Rig constants ---
% config.hardware.type                        = 'tdt';
% config.hardware.fs_playback_hz              = 48828.125;
% config.hardware.fs_record_hz                = 48828.125;
% config.hardware.usb_ch                      = 1;
% config.hardware.fig_num                     = 99;
% config.hardware.n_channels                  = 1;
% config.hardware.mat2volts                   = 5;
% config.hardware.circuit_dir                 = 'hardware/circuits';

% electrode_gain is LINEAR and applied in the RPvds circuit, not in MATLAB;
% it is recorded in params so offline analysis knows what was applied.
% It moves to equipment if the ephys amp ever becomes swappable.
% config.hardware.electrode_gain              = 10000;

% --- Swappable equipment ---
% Change the id whenever the physical probe changes; that is what invalidates
% the FPL calibration. Set mic_sens_source to 'measured yyyy-mm-dd' once the
% sensitivity has been measured.
% config.equipment.probe.id                   = 'IHS';
% config.equipment.probe.description          = 'IHS probe';
% config.equipment.probe.mic_sens_v_per_pa    = 0.05;
% config.equipment.probe.mic_sens_source      = 'nominal';
% config.equipment.probe.amp_fixed_gain_db    = 20;

% --- Calibration ---
% max_age_days applies to the transducer calibration. The FPL probe cal has
% its own daily limit in probecal_default_params.
% config.calibration.active_transducer_file   = 'calibration/data/MY_CAL.mat';
% config.calibration.max_age_days             = 7;
% config.calibration.fpl_data_dir             = 'calibration/FPL/data';

% Leave empty to use the latest valid FPL cal for the current probe.
% Set a file only to pin a specific calibration on purpose.
% config.calibration.active_fpl_file          = '';

% config.data.root_dir                        = 'data';
% config.last_session_dir                     = '';

%% --- Save only if something changed ---

if isequal(config, original)
    fprintf('No changes made. Nothing saved.\n\n');
    return
end

save(config_path, 'config');
fprintf('=== Configuration saved. ===\n\n');

%% --- Confirm saved values ---

loaded = load(config_path);
config = loaded.config;

reportChanges(original, config, '');
fprintf('\n');

%% ================================================================
%  LOCAL FUNCTIONS
%% ================================================================

function config = migrate_1_to_2(config)
% Schema 1 -> 2: move mic values into equipment.probe, remove the double-
% counted 10x, and give the FPL data folder a single field name.

AMP_FIXED_GAIN_DB = 20;   % the amp's fixed 10x stage

% Mic: the schema 1 sensitivity INCLUDED the fixed 10x, so divide it out.
probe.id                = 'ihs_er10x';
probe.description       = 'IHS probe, ER-10X mic';
probe.amp_fixed_gain_db = AMP_FIXED_GAIN_DB;
probe.mic_sens_source   = 'nominal';
if isfield(config.hardware, 'mic_sens_v_per_pa')
    probe.mic_sens_v_per_pa = config.hardware.mic_sens_v_per_pa / 10^(AMP_FIXED_GAIN_DB/20);
    fprintf('  mic sensitivity: %g V/Pa (with 10x) -> %g V/Pa (bare mic)\n', ...
        config.hardware.mic_sens_v_per_pa, probe.mic_sens_v_per_pa);
else
    probe.mic_sens_v_per_pa = 0.05;
    fprintf('  mic sensitivity: not set, using nominal 0.05 V/Pa (bare mic)\n');
end
config.equipment.probe = probe;

if isfield(config.hardware, 'mic_gain_db')
    fprintf('  hardware.mic_gain_db (%g dB) removed: the dial is now set per run\n', ...
        config.hardware.mic_gain_db);
end
config.hardware = rmfieldIfPresent(config.hardware, {'mic_sens_v_per_pa', 'mic_gain_db'});

% FPL data folder: schema 1 had two spellings in use.
fpl_dir = 'calibration/FPL/data';
if isfield(config.calibration, 'FPLprobedata')
    old = config.calibration.FPLprobedata;
    if isfield(old, 'root_dir') && ~isempty(old.root_dir)
        fpl_dir = old.root_dir;
    elseif isfield(old, 'data_dir') && ~isempty(old.data_dir)
        fpl_dir = old.data_dir;
    end
    config.calibration = rmfield(config.calibration, 'FPLprobedata');
end
config.calibration.fpl_data_dir = fpl_dir;
fprintf('  FPL data folder: calibration.fpl_data_dir = %s\n', fpl_dir);

if ~isfield(config.calibration, 'active_fpl_file')
    config.calibration.active_fpl_file = '';
end

config.schema_version = 2;
end

function s = rmfieldIfPresent(s, names)
for k = 1:numel(names)
    if isfield(s, names{k})
        s = rmfield(s, names{k});
    end
end
end

function [v, ok] = getPath(s, path)
% Read a dotted field path, e.g. 'equipment.probe.id'. ok is false if any
% level is missing, so the display never errors on a field not yet added.
parts = strsplit(path, '.');
v  = s;
ok = true;
for k = 1:numel(parts)
    if isstruct(v) && isfield(v, parts{k})
        v = v.(parts{k});
    else
        v  = [];
        ok = false;
        return
    end
end
end

function printVal(config, label, path, fmt)
[v, ok] = getPath(config, path);
if ~ok || isempty(v)
    fprintf('%-26s (not set)\n', [label ':']);
else
    fprintf(['%-26s ' fmt '\n'], [label ':'], v);
end
end

function printPath(config, label, path)
[stored, ok] = getPath(config, path);
if ~ok || isempty(stored)
    fprintf('%-26s (not set)\n', [label ':']);
    return
end
resolved = config_resolve_path(stored);
fprintf('%-26s %s\n', [label ':'], stored);
fprintf('%-26s   -> %s\n', '', resolved);
end

function reportChanges(before, after, prefix)
% Recursive, so nested changes such as equipment.probe.id are reported by
% name, and fields that were added or removed are listed too.
fa = fieldnames(after);
for k = 1:numel(fa)
    name = joinName(prefix, fa{k});
    a = after.(fa{k});
    if ~isfield(before, fa{k})
        fprintf('  added:   %s = %s\n', name, toStr(a));
    elseif isstruct(a) && isstruct(before.(fa{k}))
        reportChanges(before.(fa{k}), a, name);
    elseif ~isequal(before.(fa{k}), a)
        fprintf('  changed: %s -> %s\n', name, toStr(a));
    end
end
fb = fieldnames(before);
for k = 1:numel(fb)
    if ~isfield(after, fb{k})
        fprintf('  removed: %s\n', joinName(prefix, fb{k}));
    end
end
end

function name = joinName(prefix, field)
if isempty(prefix)
    name = field;
else
    name = [prefix '.' field];
end
end

function s = toStr(v)
if ischar(v)
    s = v;
elseif islogical(v) && isscalar(v)
    s = mat2str(v);
elseif isnumeric(v) && numel(v) <= 10
    s = mat2str(v);
elseif isstruct(v)
    s = '<struct>';
else
    s = sprintf('<%s %s>', class(v), mat2str(size(v)));
end
end