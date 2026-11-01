function cfg = config_load()
% CONFIG_LOAD  Load system config and resolve all stored paths to absolute.
%
% Paths in system_config.mat are stored relative to the repo root. This
% function expands them, so every caller receives absolute paths and no
% part of the codebase depends on the operator's working directory.
%
% Resolved fields:
%   cfg.data.root_dir
%   cfg.hardware.circuit_dir
%   cfg.calibration.active_transducer_file
%   cfg.calibration.active_fpl_file
%   cfg.calibration.fpl_data_dir
%   cfg.last_session_dir
%
% The stored (relative) values are preserved alongside under
% cfg.stored.<field> so config_edit can display what is actually on disk.
%
% Do not save the struct returned by this function back to
% system_config.mat — it holds absolute paths. Use config_edit or
% config_save_last_session, which both load the raw file.

SCHEMA_REQUIRED = 2;

root_dir    = config_repo_root();
config_path = fullfile(root_dir, 'config', 'system_config.mat');

if ~exist(config_path, 'file')
    error('config_load:notFound', ...
        'system_config.mat not found at: %s', config_path);
end

loaded = load(config_path);
if ~isfield(loaded, 'config')
    error('config_load:invalidFormat', ...
        'system_config.mat must contain a struct named ''config''.');
end

cfg = loaded.config;

%% --- Schema version ---
% Checked first, so an old config gets one clear instruction rather than
% a missing-field error that hides the real cause.

requireField(cfg, 'schema_version');        % read by session_save_run

if cfg.schema_version < SCHEMA_REQUIRED
    error('config_load:oldSchema', ...
        ['system_config.mat is schema %d; this code needs schema %d.\n' ...
         'Run config_edit once to migrate it (a backup is written first).'], ...
        cfg.schema_version, SCHEMA_REQUIRED);
end

%% --- Validate structure ---
% Every field listed here is read somewhere in the codebase. Validating
% them at load time turns a confusing downstream crash into one clear
% error naming the missing field.

requireField(cfg, 'software_version');
requireField(cfg, 'hardware');
requireField(cfg, 'equipment');
requireField(cfg, 'calibration');
requireField(cfg, 'data');

% --- Rig constants ---
requireField(cfg.hardware, 'type',           'hardware');
requireField(cfg.hardware, 'fs_playback_hz', 'hardware');
requireField(cfg.hardware, 'fs_record_hz',   'hardware');
requireField(cfg.hardware, 'usb_ch',         'hardware');
requireField(cfg.hardware, 'fig_num',        'hardware');
requireField(cfg.hardware, 'n_channels',     'hardware');
requireField(cfg.hardware, 'circuit_dir',    'hardware');
requireField(cfg.hardware, 'mat2volts',      'hardware');
requireField(cfg.hardware, 'max_atten_db',   'hardware');
requireField(cfg.hardware, 'atten_step_db',  'hardware');

% Electrode gain is LINEAR and applied in the RPvds circuit.
requireField(cfg.hardware, 'electrode_gain', 'hardware');

% --- Gain fields that must NOT be present ---
% 'gain' was a single ambiguous field (linear for ABR/EFR, dB for
% DPOAE/MEMR). Schema 1's hardware.mic_gain_db and mic_sens_v_per_pa both
% counted the amp's fixed 10x, putting pressures 20 dB low. Refuse either
% if it reappears, so the double count cannot come back quietly.

if isfield(cfg.hardware, 'gain')
    error('config_load:ambiguousGainField', ...
        ['config.hardware.gain is ambiguous and no longer supported: it ' ...
         'meant a linear\nelectrode gain for ABR/EFR and a dB probe-mic ' ...
         'gain for DPOAE/MEMR.\nRun config_migrate_hardware_fields to ' ...
         'split it into electrode_gain (linear),\nmic_gain_db (dB), and ' ...
         'mic_sens_v_per_pa (V/Pa).']);
end

stale = intersect(fieldnames(cfg.hardware), {'mic_gain_db', 'mic_sens_v_per_pa'});
if ~isempty(stale)
    error('config_load:staleMicFields', ...
        ['config.hardware.%s should not exist in schema 2. Mic values live ' ...
         'in\nconfig.equipment.probe, and the amp dial is set per run. ' ...
         'Remove the field with config_edit.'], strjoin(stale, ', hardware.'));
end

% --- Swappable equipment ---
requireField(cfg.equipment, 'probe', 'equipment');
requireField(cfg.equipment.probe, 'id',                'equipment.probe');
requireField(cfg.equipment.probe, 'mic_sens_v_per_pa', 'equipment.probe');
requireField(cfg.equipment.probe, 'mic_sens_source',   'equipment.probe');
requireField(cfg.equipment.probe, 'amp_fixed_gain_db', 'equipment.probe');

% --- Calibration ---
requireField(cfg.calibration, 'active_transducer_file', 'calibration');
requireField(cfg.calibration, 'active_fpl_file',        'calibration');
requireField(cfg.calibration, 'fpl_data_dir',           'calibration');
requireField(cfg.calibration, 'max_age_days',           'calibration');
requireField(cfg.calibration, 'ref_peak',               'calibration');
requireField(cfg.calibration, 'measured_through',       'calibration');

requireField(cfg.data, 'root_dir', 'data');

%% --- Sanity checks on units ---
% A linear gain of 20 or a dB gain of 10000 means the two fields have been
% swapped, which would put every amplitude off by orders of magnitude.

if cfg.hardware.electrode_gain < 1
    warning('config_load:electrodeGainSuspect', ...
        ['config.hardware.electrode_gain is %g. This field is LINEAR ' ...
         '(e.g. 10000 for a 10000x amp), not dB.'], ...
        cfg.hardware.electrode_gain);
end

if cfg.calibration.ref_peak >= 1 || cfg.calibration.ref_peak <= 0
    warning('config_load:refPeakSuspect', ...
        ['config.calibration.ref_peak is %g. It must be in (0,1) — at 1.0 ' ...
         'the |stim| <= 1 check in tdt_play_record becomes a hard mid-run ' ...
         'error and eq-filter ringing overshoots.'], cfg.calibration.ref_peak);
end

probe = cfg.equipment.probe;

if probe.amp_fixed_gain_db > 200
    warning('config_load:ampGainSuspect', ...
        ['config.equipment.probe.amp_fixed_gain_db is %g. This field is ' ...
         'in dB (e.g. 20 for a fixed 10x stage), not linear.'], ...
        probe.amp_fixed_gain_db);
end

% Bare mic sensitivities sit around 0.01-0.1 V/Pa. A value near 0.5 is the
% schema 1 number that still includes the amp's 10x.
if probe.mic_sens_v_per_pa <= 0 || probe.mic_sens_v_per_pa > 0.2
    warning('config_load:micSensSuspect', ...
        ['config.equipment.probe.mic_sens_v_per_pa is %g V/Pa. This is the ' ...
         'BARE mic sensitivity,\nexcluding the amp. A value near 0.5 usually ' ...
         'means the amp''s 10x is included,\nwhich double counts it.'], ...
        probe.mic_sens_v_per_pa);
end

if cfg.hardware.mat2volts <= 0
    warning('config_load:mat2voltsSuspect', ...
        'config.hardware.mat2volts is %g; expected the DAC full-scale voltage (e.g. 5).', ...
        cfg.hardware.mat2volts);
end

% Optional — absent on a fresh config, read by session_load_or_create
if ~isfield(cfg, 'last_session_dir')
    cfg.last_session_dir = '';
end

%% --- Resolve paths ---

cfg.stored.data_root_dir          = cfg.data.root_dir;
cfg.stored.circuit_dir            = cfg.hardware.circuit_dir;
cfg.stored.active_transducer_file = cfg.calibration.active_transducer_file;
cfg.stored.active_fpl_file        = cfg.calibration.active_fpl_file;
cfg.stored.fpl_data_dir           = cfg.calibration.fpl_data_dir;
cfg.stored.last_session_dir       = cfg.last_session_dir;

cfg.data.root_dir        = config_resolve_path(cfg.data.root_dir,        root_dir);
cfg.hardware.circuit_dir = config_resolve_path(cfg.hardware.circuit_dir, root_dir);
cfg.calibration.active_transducer_file = ...
    config_resolve_path(cfg.calibration.active_transducer_file, root_dir);
cfg.calibration.active_fpl_file = ...
    config_resolve_path(cfg.calibration.active_fpl_file, root_dir);
cfg.calibration.fpl_data_dir = ...
    config_resolve_path(cfg.calibration.fpl_data_dir, root_dir);
cfg.last_session_dir     = config_resolve_path(cfg.last_session_dir,     root_dir);

cfg.repo_root = root_dir;

%% --- Sanity checks on resolved paths ---
% Warnings, not errors: the data root is created on first session, the FPL
% folder on the first probe cal save, and a missing circuit folder should
% surface as a clear tdt_init failure rather than blocking every GUI.

if ~exist(cfg.hardware.circuit_dir, 'dir')
    warning('config_load:circuitDirMissing', ...
        'Circuit folder does not exist: %s', cfg.hardware.circuit_dir);
end

if ~isempty(cfg.calibration.active_transducer_file) && ...
        ~exist(cfg.calibration.active_transducer_file, 'file')
    warning('config_load:transducerCalMissing', ...
        'Active transducer cal file does not exist: %s', ...
        cfg.calibration.active_transducer_file);
end

if ~isempty(cfg.calibration.active_fpl_file) && ...
        ~exist(cfg.calibration.active_fpl_file, 'file')
    warning('config_load:fplCalMissing', ...
        'Pinned FPL cal file does not exist: %s', ...
        cfg.calibration.active_fpl_file);
end

end

%% ================================================================
%  LOCAL FUNCTIONS
%% ================================================================

function requireField(s, name, parent)
if nargin < 3
    label = name;
else
    label = sprintf('%s.%s', parent, name);
end
if ~isfield(s, name)
    error('config_load:missingField', ...
        'Config missing required field: %s', label);
end
end