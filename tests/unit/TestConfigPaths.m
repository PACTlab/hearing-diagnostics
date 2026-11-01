classdef TestConfigPaths < matlab.unittest.TestCase
% TESTCONFIGPATHS  Tests for config path resolution.
%
% The bug these guard against: config paths were stored as relative
% Windows paths ('.\data\') and resolved against pwd, so data landed in
% whatever folder MATLAB happened to start in, and nothing worked off
% Windows. Paths are now stored relative to the repo root and expanded by
% config_load.
%
% Run:  runtests('tests/unit/TestConfigPaths.m')

    methods (Test)

        %% --- config_repo_root ---

        function testRepoRootIsAbsolute(tc)
            root = config_repo_root();
            tc.verifyTrue(~isempty(root), 'Repo root is empty.');
            tc.verifyTrue(exist(root, 'dir') == 7, ...
                'Repo root is not a directory.');
            tc.verifyTrue(exist(fullfile(root, 'startup.m'), 'file') == 2, ...
                'Repo root does not contain startup.m — wrong level?');
        end

        function testRepoRootIndependentOfPwd(tc)
            expected = config_repo_root();
            old = cd(tempdir);
            restore = onCleanup(@() cd(old));
            tc.verifyEqual(config_repo_root(), expected, ...
                'Repo root changed when pwd changed.');
        end

        %% --- config_resolve_path: separators ---

        function testWindowsSeparatorsResolve(tc)
            root = config_repo_root();
            tc.verifyEqual(norm(config_resolve_path('.\data\', root)), ...
                           norm(fullfile(root, 'data')));
        end

        function testPosixSeparatorsResolve(tc)
            root = config_repo_root();
            tc.verifyEqual(norm(config_resolve_path('./data/', root)), ...
                           norm(fullfile(root, 'data')));
        end

        function testMixedSeparatorsResolve(tc)
            root = config_repo_root();
            tc.verifyEqual(norm(config_resolve_path('hardware\circuits/', root)), ...
                           norm(fullfile(root, 'hardware', 'circuits')));
        end

        function testNoTrailingSeparator(tc)
            p = config_resolve_path('.\data\', config_repo_root());
            tc.verifyFalse(endsWith(p, filesep), ...
                'Resolved path has a trailing separator — breaks fullfile callers.');
        end

        function testOutputUsesNativeSeparator(tc)
            p = config_resolve_path('hardware/circuits');
            if ispc
                tc.verifyFalse(contains(p, '/'), 'Forward slash left on Windows.');
            else
                tc.verifyFalse(contains(p, '\'), 'Backslash left on POSIX.');
            end
        end

        %% --- config_resolve_path: pwd independence ---

        function testResolutionIndependentOfPwd(tc)
            expected = config_resolve_path('data');
            old = cd(tempdir);
            restore = onCleanup(@() cd(old));
            tc.verifyEqual(config_resolve_path('data'), expected, ...
                'Resolved path depends on pwd — the original bug.');
        end

        %% --- config_resolve_path: absolute passthrough ---

        function testAbsolutePosixPassesThrough(tc)
            tc.verifyEqual(norm(config_resolve_path('/mnt/lab_share/data')), ...
                           '/mnt/lab_share/data');
        end

        function testAbsoluteWindowsPassesThrough(tc)
            tc.verifyEqual(norm(config_resolve_path('D:\LabData\chinchilla')), ...
                           'D:/LabData/chinchilla');
        end

        function testUncPathPassesThrough(tc)
            tc.verifyEqual(norm(config_resolve_path('\\server\share\data')), ...
                           '//server/share/data');
        end

        %% --- config_resolve_path: dot segments ---

        function testDotDotCollapses(tc)
            root = config_repo_root();
            tc.verifyEqual(norm(config_resolve_path('data/../calibration', root)), ...
                           norm(fullfile(root, 'calibration')));
        end

        function testRedundantDotsCollapse(tc)
            root = config_repo_root();
            tc.verifyEqual(norm(config_resolve_path('./././data', root)), ...
                           norm(fullfile(root, 'data')));
        end

        function testDuplicateSeparatorsCollapse(tc)
            root = config_repo_root();
            tc.verifyEqual(norm(config_resolve_path('data//sub///x', root)), ...
                           norm(fullfile(root, 'data', 'sub', 'x')));
        end

        %% --- config_resolve_path: empty ---

        function testEmptyStaysEmpty(tc)
            tc.verifyEmpty(config_resolve_path(''), ...
                'Empty path must stay empty, not become the repo root.');
            tc.verifyEmpty(config_resolve_path('   '), ...
                'Whitespace-only path must stay empty.');
        end

        function testNonexistentPathStillResolves(tc)
            % root_dir is resolved before the folder exists
            p = config_resolve_path('data/not_created_yet');
            tc.verifyTrue(~isempty(p), ...
                'Resolution must not require the path to exist.');
        end

        %% --- config_relative_path ---

        function testRelativizeRoundTrips(tc)
            root = config_repo_root();
            abs_in = fullfile(root, 'data', 'Q047', '2026-01-01_Baseline_Awake');
            rel    = config_relative_path(abs_in);
            tc.verifyEqual(norm(config_resolve_path(rel)), norm(abs_in), ...
                'resolve(relative(x)) did not return x.');
        end

        function testRelativizeStripsRoot(tc)
            root = config_repo_root();
            rel  = config_relative_path(fullfile(root, 'data', 'Q047'));
            tc.verifyEqual(norm(rel), 'data/Q047');
            tc.verifyFalse(contains(rel, root), ...
                'Relative path still contains the absolute root.');
        end

        function testOutsideRepoStaysAbsolute(tc)
            outside = fullfile(tempdir, 'definitely_not_in_repo');
            rel     = config_relative_path(outside);
            tc.verifyEqual(norm(rel), norm(outside), ...
                'A path outside the repo must stay absolute.');
        end

        function testRelativizeEmpty(tc)
            tc.verifyEmpty(config_relative_path(''));
        end

        %% --- config_load integration ---

        function testConfigLoadReturnsAbsolutePaths(tc)
            cfg = config_load();
            tc.verifyTrue(isAbs(cfg.data.root_dir), ...
                'cfg.data.root_dir is not absolute.');
            tc.verifyTrue(isAbs(cfg.hardware.circuit_dir), ...
                'cfg.hardware.circuit_dir is not absolute.');
        end

        function testConfigLoadPreservesStoredValues(tc)
            cfg = config_load();
            tc.verifyTrue(isfield(cfg, 'stored'), ...
                'cfg.stored missing — config_edit needs the raw values.');
            tc.verifyTrue(isfield(cfg.stored, 'data_root_dir'));
        end

        function testConfigLoadIndependentOfPwd(tc)
            cfg_before = config_load();
            old = cd(tempdir);
            restore = onCleanup(@() cd(old));
            cfg_after = config_load();
            tc.verifyEqual(cfg_after.data.root_dir, cfg_before.data.root_dir, ...
                'config_load result depends on pwd.');
        end

        function testCircuitPathBuildsWithFullfile(tc)
            % Regression: circuit_dir used to carry a trailing separator and
            % was concatenated. Without one, concatenation silently produces
            % '...circuitsBasicPlayRecord.rcx'.
            cfg  = config_load();
            path = fullfile(cfg.hardware.circuit_dir, 'BasicPlayRecord_Medusa.rcx');
            tc.verifyTrue(exist(path, 'file') == 2, ...
                sprintf('Medusa circuit not found at: %s', path));
        end

        function testSchemaVersionPresent(tc)
            % Read by session_save_run; was not validated by config_load
            cfg = config_load();
            tc.verifyTrue(isfield(cfg, 'schema_version'));
        end

    end
end

%% ================================================================
%  HELPERS
%% ================================================================

function p = norm(p)
% Compare paths without caring about separator flavour
p = strrep(p, '\', '/');
end

function tf = isAbs(p)
p  = strrep(p, '\', '/');
tf = startsWith(p, '/') || (numel(p) >= 2 && isletter(p(1)) && p(2) == ':');
end