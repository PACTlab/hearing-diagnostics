# Adding a New Measure

This guide walks through everything needed to add a new measure to the
hearing diagnostics system. Follow ABR as the reference implementation.
The system is designed so that adding a measure only requires work inside
`measures/{your_measure}/` and a few small additions to shared files.
Nothing in the session, config, or project infrastructure should change.

---

## 1. Create the Measure Folder
measures/
└── {measure_name}/          e.g. dpoae/, efr/
├── {name}_default_params.m
├── {name}_make_stimulus.m
├── {name}_make_file_tag.m
├── {name}_validate_params.m
├── {name}_run.m
└── {name}_gui.m

Use lowercase, no spaces. Keep it consistent — the system finds files
by naming convention so spelling matters.

---

## 2. Required Files

### `{name}_default_params.m`

Defines every parameter the measure uses. This is the canonical parameter
struct — every field that could appear in `params` must be defined here
with a sensible default.

Rules:
- `params.measure_type` must match the folder name in uppercase
  e.g. `'DPOAE'`, `'EFR'`
- `params.ear` must always be present
- `params.fs` must always be present
- Do not add fields in other files — all fields live here

```matlab
function params = dpoae_default_params()
    params.measure_type   = 'DPOAE';
    params.ear            = 'right';
    params.fs             = 48828.125;
    params.f2_hz          = 4000;
    params.f2_f1_ratio    = 1.22;
    params.levels_dbspl   = [65 55];   % [L1 L2]
    params.n_reps         = 64;
    params.epoch_ms       = 100;
    params.apply_ear_cal  = true;
    params.ear_cal_file   = '';
    % ... etc
end
```

---

### `{name}_make_file_tag.m`

Returns the measure-specific middle section of the filename.
`session_build_filename` calls this automatically — you never need
to touch the session code.

```matlab
function tag = dpoae_make_file_tag(params)
% Returns e.g. 'f2-4000Hz_65-55dB'
    tag = sprintf('f2-%dHz_%d-%ddB', ...
        round(params.f2_hz), ...
        round(params.levels_dbspl(1)), ...
        round(params.levels_dbspl(2)));
end
```

Must handle `params.ear` being present (it's always there) but you
don't need to use it — ear is handled by `session_build_filename`.

If your measure has no meaningful frequency or level tag (e.g. a
calibration measure), return an empty string:

```matlab
function tag = mycal_make_file_tag(params)
    tag = '';
end
```

---

### `{name}_validate_params.m`

Validates the params struct before a run starts. Returns an error
message string if something is wrong, empty string if everything is fine.
The GUI calls this before starting acquisition.

```matlab
function err = dpoae_validate_params(params)
    err = '';
    if params.f2_hz < 500 || params.f2_hz > 16000
        err = sprintf('f2 frequency %d Hz is outside valid range.', ...
            params.f2_hz);
        return
    end
    if params.f2_f1_ratio <= 1
        err = 'f2/f1 ratio must be greater than 1.';
        return
    end
    % ... etc
end
```

---

### `{name}_make_stimulus.m`

Generates the stimulus waveform(s) for one condition. Should return
a struct with at minimum:

```matlab
stim_out.pos         % positive polarity buffer [n_samples x 1]
stim_out.neg         % negative polarity buffer [n_samples x 1]
stim_out.isi_samples % [1 x n_reps] samples to play per rep
stim_out.atten_db    % attenuation applied
stim_out.fs          % sample rate
stim_out.n_stim      % stimulus length in samples

stim_info            % diagnostic struct, saved with each run
```

For measures with two tones (DPOAE), return both tones mixed or
as separate channels depending on your hardware setup.

Calibration is applied inside this function — receive `cal` as
a second argument and pass it to `cal_apply_transducer`. If no
calibration is available, warn but don't error so the measure
can still run uncalibrated during development.

---

### `{name}_run.m`

The acquisition loop. Receives `params`, `save_dir`, `metadata`,
and hardware handles. Calls `session_save_run` after each level or
condition completes.

Structure to follow:

```matlab
function {name}_run(params, save_dir, metadata, tdt)

    % Validate
    err = {name}_validate_params(params);
    if ~isempty(err); error(err); end

    % Loop over conditions
    for cond_idx = 1:n_conditions

        % Generate stimulus
        stim_out = {name}_make_stimulus(params_this_cond, cal);

        % Rep loop
        for rep = 1:params.n_reps
            % Play and record via TDT
            % epoch_raw = tdt_{name}_play_record(tdt, stim_out, rep);
        end

        % Save after each condition
        [~, metadata] = session_save_run(save_dir, metadata, ...
            save_params, save_data);
    end
end
```

---

### `{name}_gui.m`

The main acquisition GUI. Copy `abr_gui.m` as a starting point and
modify the control panel fields for your measure's parameters.

Required structure:
- Call `session_load_or_create()` at launch
- Call `project_load_defaults('{name}', metadata.project)` for params
- Call `{name}_validate_params` before running
- Wrap acquisition loop in `try/catch` to prevent stuck GUI state
- Call `session_save_run` after each condition
- Implement quit confirmation that blocks if running

The session dialog, subject bar, and cal badges can be copied
directly from `abr_gui.m` — they're measure-agnostic.

---

## 3. Hardware Files

If your measure uses a different RPvds circuit or different TDT
tag names, add measure-specific hardware functions in the measure
folder alongside the other files:
measures/dpoae/
└── tdt_dpoae_setup.m
└── tdt_dpoae_play_record.m

The shared TDT connection functions (`tdt_init`, `tdt_close`,
`tdt_check_connection`) in `hardware/` are reused as-is.
Your measure-specific files just handle the circuit tags and
timing that are unique to your measure.

Store your RPvds circuit file in `hardware/circuits/`:
hardware/circuits/
└── dpoae_play_record.rcx

Add the expected tag names as comments at the top of your setup
function so anyone building a new circuit knows what MATLAB expects.

---

## 4. Startup Path

Add your measure folder to `startup.m`:

```matlab
addpath(fullfile(rootDir, 'measures', 'dpoae'));
```

---

## 5. Project Default Params

If a project needs different defaults for your measure, create
a `{name}_default_params.m` in the project folder:
projects/chinchilla_noise/
└── dpoae_default_params.m

`project_load_defaults` finds it automatically. Copy the lab default
and change only values — never add or remove fields.

---

## 6. Tests

Create a test file in `tests/unit/`:
tests/unit/Test{Name}Stimulus.m

At minimum test:
- Output struct has required fields
- Error on invalid params (wrong type, out-of-range values)
- Stimulus duration matches params
- Polarity is correct
- ISI length and jitter behave correctly
- No calibration raises warning, not error

Follow `TestABRStimulus.m` as the reference. Use fixture helper
functions at the bottom of the test file so test methods stay clean.

Run your tests alongside the existing suite:

```matlab
results = runtests({
    'tests/unit/TestSessionBuildFilename.m', ...
    'tests/unit/TestSessionCreate.m', ...
    'tests/unit/TestSessionFind.m', ...
    'tests/unit/TestSessionSaveRun.m', ...
    'tests/unit/TestSessionSaveMetadata.m', ...
    'tests/unit/TestProjectLoadDefaults.m', ...
    'tests/unit/TestABRStimulus.m', ...
    'tests/unit/Test{Name}Stimulus.m'});
disp(results)
```

---

## 7. Demo Script

Create a demo script in `tests/demo/`:
tests/demo/demo_{name}_stimulus.m
This should generate a stimulus, plot it in time and frequency
domains, and optionally play it through the sound card. New lab
members run this on day one to verify stimulus generation without
needing hardware.

Follow `tests/demo/demo_abr_stimulus.m` as the reference.

---

## 8. Checklist

Before considering a measure complete:

**Required:**
- [ ] `{name}_default_params.m` — all fields defined including `measure_type`, `ear`, `fs`
- [ ] `{name}_make_file_tag.m` — returns correct filename segment
- [ ] `{name}_validate_params.m` — catches bad parameter combinations
- [ ] `{name}_make_stimulus.m` — generates correct waveform, handles calibration
- [ ] `{name}_run.m` — acquisition loop, saves per condition
- [ ] `{name}_gui.m` — full GUI with session, controls, plots, save
- [ ] Added to `startup.m`

**Tests:**
- [ ] `Test{Name}Stimulus.m` — stimulus generation tests passing
- [ ] Full test suite still passes after adding measure

**Project:**
- [ ] `projects/lab_default/{name}_default_params.m` — NOT needed,
  lab default lives in `measures/{name}/`
- [ ] Project overrides added to relevant project folders if needed

**Hardware:**
- [ ] RPvds circuit in `hardware/circuits/`
- [ ] `tdt_{name}_setup.m` and `tdt_{name}_play_record.m` if needed
- [ ] Circuit tag names documented in setup function

**Demo:**
- [ ] `tests/demo/demo_{name}_stimulus.m`

---

## Quick Reference — File Naming Convention

| File | Naming pattern | Example |
|---|---|---|
| Default params | `{name}_default_params.m` | `dpoae_default_params.m` |
| File tag | `{name}_make_file_tag.m` | `dpoae_make_file_tag.m` |
| Validate | `{name}_validate_params.m` | `dpoae_validate_params.m` |
| Stimulus | `{name}_make_stimulus.m` | `dpoae_make_stimulus.m` |
| Run | `{name}_run.m` | `dpoae_run.m` |
| GUI | `{name}_gui.m` | `dpoae_gui.m` |
| TDT setup | `tdt_{name}_setup.m` | `tdt_dpoae_setup.m` |
| TDT play/record | `tdt_{name}_play_record.m` | `tdt_dpoae_play_record.m` |
| Stimulus test | `Test{Name}Stimulus.m` | `TestDPOAEStimulus.m` |
| Demo script | `demo_{name}_stimulus.m` | `demo_dpoae_stimulus.m` |
| RPvds circuit | `{name}_play_record.rcx` | `dpoae_play_record.rcx` |

---

## Notes

**Measure type string** — whatever you put in `params.measure_type`
is what appears in filenames and the session run log. Use uppercase
with no spaces. `'DPOAE'`, `'EFR'`, `'EARCAL'` are the conventions
established so far.

**Saving** — never write your own save logic. Always call
`session_save_run(save_dir, metadata, params, data)`. This ensures
consistent file structure, correct naming, and metadata updates.

**Calibration** — `cal` is passed in from the GUI which loads it
from config. Your stimulus function should accept `cal` as an
argument and pass it to `cal_apply_transducer`. Don't load
calibration files inside the stimulus function.

**Ear cal** — handled the same way as ABR. `params.apply_ear_cal`
and `params.ear_cal_file` control whether the filter is applied.
`cal_apply` checks these automatically.

**GUI independence** — `{name}_make_stimulus` and `{name}_run`
should work without a GUI. Tests and demo scripts call them
directly. Never reach into GUI handles from inside these functions.

