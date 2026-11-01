% PROBECAL_TEST_SAVE  Check save, lookup and history using a stub calibration.
%
% Reuses R and fit from probecal_test_fit if they are in the workspace.
% The stub file is written to <fpl_data_dir>/stub and deleted at the end
% unless KEEP_FILE is true.
%
% Expected:
%   1. normal lookup       finds nothing (stubs are never used for real)
%   2. allow_stub lookup   finds the file just saved
%   3. delay comp flipped  rejected, with the delay reason given
%   4. other probe id      rejected, with the probe reason given
%   5. history             includes the file, with norm bands

KEEP_FILE = false;

params = probecal_default_params();
params.stub_mode = true;
cfg = config_load();

if ~exist('fit', 'var') || ~exist('R', 'var')
    n_cav = numel(params.cavity_lengths_mm);
    R = cell(1, n_cav);
    for k = 1:n_cav
        R{k} = probecal_measure_cavity(cfg, params, [], k);
    end
    fit = probecal_fit(R, params);
end

saved = probecal_save(cfg, fit, R, params, struct('comment', 'stub test'));
current = probecal_current_conditions(cfg, [], params.delay_comp);
stub_ok = struct('allow_stub', true);

fprintf('\n1. Normal lookup:\n');
[cal, p, info] = probecal_lookup(cfg, current);
fprintf('   source=%s  found=%d\n   %s\n', info.source, ~isempty(cal), info.message);

fprintf('\n2. Lookup allowing stubs:\n');
[cal, p, info] = probecal_lookup(cfg, current, stub_ok);
fprintf('   source=%s  same file=%d\n   %s\n', info.source, strcmp(p, saved), info.message);

fprintf('\n3. Delay compensation flipped:\n');
c3 = current;
c3.delay_comp = ~current.delay_comp;
c3.ad_delay_samples = 248;
[cal, ~, info] = probecal_lookup(cfg, c3, stub_ok);
fprintf('   found=%d\n   %s\n', ~isempty(cal), info.message);

fprintf('\n4. Different probe in config:\n');
cfg4 = cfg;
cfg4.equipment.probe.id = 'some_other_probe';
[cal, ~, info] = probecal_lookup(cfg4, current, stub_ok);
fprintf('   found=%d\n   %s\n', ~isempty(cal), info.message);

fprintf('\n5. History:\n');
c5 = current;
c5.buffer_size = fit.conditions.buffer_size;
hist = probecal_history(cfg, c5, stub_ok);
fprintf('   n=%d  includes saved file=%d  has norm=%d\n', ...
    hist.n, any(strcmp(hist.files, saved)), isfield(hist, 'norm'));

if ~KEEP_FILE
    delete(saved);
    fprintf('\nDeleted %s\n', saved);
end