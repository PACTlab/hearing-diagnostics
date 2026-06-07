classdef TestSessionSaveRun < matlab.unittest.TestCase

    properties
        OriginalDir
        SaveDir
        Metadata
        CreatedDirs
    end

    methods (TestMethodSetup)
        function setUp(tc)
            tc.OriginalDir = pwd;
            warning('off', 'all');

            info.group         = 'Baseline';
            info.animal_status = 'Awake';
            [tc.SaveDir, tc.Metadata] = session_create(...
                'SAVERUN_TEST', 'Chinchilla', 'JDoe', info);
            tc.CreatedDirs = {fullfile(config_load().data.root_dir, 'SAVERUN_TEST')};
        end
    end

    methods (TestMethodTeardown)
        function tearDown(tc)
            warning('on', 'all');
            for i = 1:length(tc.CreatedDirs)
                if exist(tc.CreatedDirs{i}, 'dir')
                    rmdir(tc.CreatedDirs{i}, 's');
                end
            end
            cd(tc.OriginalDir);
        end
    end

    methods (Test)

        %% --- Basic file creation ---

        function testFileIsCreated(tc)
            params = fakeABRParams();
            data   = fakeData();
            [filepath, ~] = session_save_run(tc.SaveDir, tc.Metadata, params, data);
            tc.verifyTrue(exist(filepath, 'file') == 2, ...
                'Run file should exist after save.');
        end

        function testRunCounterIncrements(tc)
            params = fakeABRParams();
            data   = fakeData();
            tc.verifyEqual(tc.Metadata.total_runs, 0);
            [~, metadata] = session_save_run(tc.SaveDir, tc.Metadata, params, data);
            tc.verifyEqual(metadata.total_runs, 1);
        end

        function testMetadataUpdatedOnDisk(tc)
            params = fakeABRParams();
            data   = fakeData();
            session_save_run(tc.SaveDir, tc.Metadata, params, data);
            reloaded = session_load(tc.SaveDir);
            tc.verifyEqual(reloaded.total_runs, 1, ...
                'total_runs should be updated on disk.');
        end

        %% --- File structure ---

        function testSavedFileHasCorrectStructure(tc)
            params        = fakeABRParams();
            data          = fakeData();
            [filepath, ~] = session_save_run(tc.SaveDir, tc.Metadata, params, data);
            loaded        = load(filepath);

            tc.verifyTrue(isfield(loaded,     'run'),    'File should have run struct.');
            tc.verifyTrue(isfield(loaded.run, 'info'),   'run should have info.');
            tc.verifyTrue(isfield(loaded.run, 'params'), 'run should have params.');
            tc.verifyTrue(isfield(loaded.run, 'data'),   'run should have data.');
            tc.verifyTrue(isfield(loaded.run, 'result'), 'run should have result.');
        end

        function testResultIsEmptyStruct(tc)
            params        = fakeABRParams();
            data          = fakeData();
            [filepath, ~] = session_save_run(tc.SaveDir, tc.Metadata, params, data);
            loaded        = load(filepath);

            tc.verifyTrue(isstruct(loaded.run.result), ...
                'result should be a struct.');
            tc.verifyTrue(isempty(fieldnames(loaded.run.result)), ...
                'result should be empty before analysis.');
        end

        function testInfoContainsSubjectID(tc)
            params        = fakeABRParams();
            data          = fakeData();
            [filepath, ~] = session_save_run(tc.SaveDir, tc.Metadata, params, data);
            loaded        = load(filepath);
            tc.verifyEqual(loaded.run.info.subject_id, 'SAVERUN_TEST');
        end

        function testInfoContainsSchemaVersion(tc)
            params        = fakeABRParams();
            data          = fakeData();
            [filepath, ~] = session_save_run(tc.SaveDir, tc.Metadata, params, data);
            loaded        = load(filepath);
            tc.verifyTrue(isfield(loaded.run.info, 'schema_version'), ...
                'run.info should have schema_version.');
            tc.verifyEqual(loaded.run.info.schema_version, ...
                config_load().schema_version);
        end

        %% --- Multiple saves ---

        function testMultipleSavesIncrementCorrectly(tc)
            params    = fakeABRParams();
            data      = fakeData();
            [~, meta] = session_save_run(tc.SaveDir, tc.Metadata, params, data);
            [~, meta] = session_save_run(tc.SaveDir, meta, params, data);
            [~, meta] = session_save_run(tc.SaveDir, meta, params, data);

            tc.verifyEqual(meta.total_runs, 3);
            reloaded = session_load(tc.SaveDir);
            tc.verifyEqual(reloaded.total_runs, 3);
        end

        %% --- Run log ---

        function testRunLogCreatedAfterFirstSave(tc)
            params = fakeABRParams();
            data   = fakeData();
            session_save_run(tc.SaveDir, tc.Metadata, params, data);

            reloaded = session_load(tc.SaveDir);
            tc.verifyTrue(isfield(reloaded, 'run_log'), ...
                'session_metadata should have run_log after first save.');
        end

        function testRunLogHasCorrectFields(tc)
            params = fakeABRParams();
            data   = fakeData();
            session_save_run(tc.SaveDir, tc.Metadata, params, data);

            reloaded = session_load(tc.SaveDir);
            entry    = reloaded.run_log(1);

            tc.verifyTrue(isfield(entry, 'run_number'),   'run_log entry missing run_number.');
            tc.verifyTrue(isfield(entry, 'measure_type'), 'run_log entry missing measure_type.');
            tc.verifyTrue(isfield(entry, 'ear'),          'run_log entry missing ear.');
            tc.verifyTrue(isfield(entry, 'timestamp'),    'run_log entry missing timestamp.');
        end

        function testRunLogRecordsMeasureType(tc)
            params = fakeABRParams();
            data   = fakeData();
            session_save_run(tc.SaveDir, tc.Metadata, params, data);

            reloaded = session_load(tc.SaveDir);
            tc.verifyEqual(reloaded.run_log(1).measure_type, 'ABR');
        end

        function testRunLogAppendsMultipleEntries(tc)
            params    = fakeABRParams();
            data      = fakeData();
            [~, meta] = session_save_run(tc.SaveDir, tc.Metadata, params, data);

            params2              = fakeABRParams();
            params2.frequency_hz = 16000;
            params2.levels_dbspl = 60;
            [~, meta] = session_save_run(tc.SaveDir, meta, params2, data);

            [~, meta] = session_save_run(tc.SaveDir, meta, params, data);

            reloaded = session_load(tc.SaveDir);
            tc.verifyEqual(length(reloaded.run_log), 3, ...
                'run_log should have 3 entries.');
        end

        function testRunLogRunNumberMatchesTotalRuns(tc)
            params    = fakeABRParams();
            data      = fakeData();
            [~, meta] = session_save_run(tc.SaveDir, tc.Metadata, params, data);
            [~, meta] = session_save_run(tc.SaveDir, meta, params, data);

            reloaded = session_load(tc.SaveDir);
            tc.verifyEqual(reloaded.run_log(1).run_number, 1);
            tc.verifyEqual(reloaded.run_log(2).run_number, 2);
        end

        %% --- Error handling ---

        function testMissingMeasureTypeErrors(tc)
            params = rmfield(fakeABRParams(), 'measure_type');
            data   = fakeData();
            tc.verifyError(...
                @() session_save_run(tc.SaveDir, tc.Metadata, params, data), ...
                'session_save_run:missingParam');
        end

        function testMissingEarErrors(tc)
            params = rmfield(fakeABRParams(), 'ear');
            data   = fakeData();
            tc.verifyError(...
                @() session_save_run(tc.SaveDir, tc.Metadata, params, data), ...
                'session_save_run:missingParam');
        end

    end

end

%% ================================================================
%  FIXTURE HELPERS
%% ================================================================

function params = fakeABRParams()
    params = abr_default_params();
    params.stim_type    = 'toneburst';
    params.frequency_hz = 8000;
    params.levels_dbspl = 70;
    params.ear          = 'right';
end

function data = fakeData()
    data.epochs  = randn(512, 977);
    data.average = randn(977, 1);
    data.fs      = 48828.125;
end