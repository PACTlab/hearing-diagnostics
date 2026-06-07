classdef TestSession < matlab.unittest.TestCase
    % Unit tests for Session handle class.
    % Must be run from project root directory.
    % Uses system tempdir so no real data folders are created.
    % Requires a valid system_config.mat in config/ to pass.

    properties
        TmpDir
        OriginalDir
        FixtureDir
        ProjectRoot
    end

    methods (TestMethodSetup)
        function setUp(tc)
            tc.OriginalDir  = pwd;
            thisFolder      = fileparts(mfilename('fullpath'));
            tc.ProjectRoot  = char(java.io.File(fullfile(thisFolder, '..', '..')).getCanonicalPath());
            tc.FixtureDir   = fullfile(tc.ProjectRoot, 'tests', 'fixtures');

            tc.verifyTrue(exist(fullfile(tc.ProjectRoot, 'config', 'system_config.mat'), 'file') == 2, ...
                'system_config.mat not found. Check project structure.');
            tc.verifyTrue(exist(tc.FixtureDir, 'dir') == 7, ...
                'tests/fixtures/ not found.');

            tc.TmpDir = tempdir;
            cd(tc.TmpDir);

            warning('off', 'Session:noTransducerCal');

        end
    end
    methods (TestMethodTeardown)
        function tearDown(tc)

            warning('on', 'Session:noTransducerCal');

            cd(tc.OriginalDir);
        end
    end

    methods (Test)

        %% --- Session Construction ---

        function testSessionCreatesDirectory(tc)
            sess = Session('Test001', 'chinchilla', 'Tester');
            tc.verifyTrue(exist(sess.SaveDir, 'dir') == 7, ...
                'Session should create SaveDir on construction.');
        end

        function testSessionPropertiesStored(tc)
            sess = Session('Test001', 'chinchilla', 'Tester');
            tc.verifyEqual(sess.SubjectID, 'Test001');
            tc.verifyEqual(sess.Species,   'chinchilla');
            tc.verifyEqual(sess.Operator,  'Tester');
            tc.verifyEqual(sess.RunCount,  0);
        end

        function testDateIsToday(tc)
            sess = Session('Test001', 'chinchilla', 'Tester');
            tc.verifyEqual(sess.Date, datestr(now, 'yyyy-mm-dd'));
        end

        %% --- Config Loading ---

        function testConfigLoadsFromSystemConfig(tc)
            % Real system_config.mat should load without error
            sess = Session('Test001', 'chinchilla', 'Tester');
            tc.verifyNotEmpty(sess.Config, ...
                'Config should be populated from system_config.mat.');
        end

        function testConfigHasRequiredFields(tc)
            sess = Session('Test001', 'chinchilla', 'Tester');
            tc.verifyTrue(isfield(sess.Config, 'hardware'), ...
                'Config missing hardware field.');
            tc.verifyTrue(isfield(sess.Config, 'calibration'), ...
                'Config missing calibration field.');
            tc.verifyTrue(isfield(sess.Config, 'data'), ...
                'Config missing data field.');
            tc.verifyTrue(isfield(sess.Config.data, 'root_dir'), ...
                'Config missing data.root_dir field.');
            tc.verifyTrue(isfield(sess.Config, 'software_version'), ...
                'Config missing software_version field.');
        end


        %% --- Run Counting and Saving ---

        function testRunCountIncrementsOnSave(tc)
            sess = Session('Test001', 'chinchilla', 'Tester');

            params.measure_type = 'ABR';
            params.frequency_hz = 8000;
            params.ear = 'right';
            data.epochs         = randn(10, 100);
            data.fs             = 48828.125;

            sess.saveRun(params, data);
            tc.verifyEqual(sess.RunCount, 1);

            sess.saveRun(params, data);
            tc.verifyEqual(sess.RunCount, 2);
        end

        function testFilenameFormat(tc)
            sess = Session('Test001', 'chinchilla', 'Tester');

            params.measure_type = 'ABR';
            params.ear = 'right';
            data.epochs         = randn(10, 100);
            data.fs             = 48828.125;

            filepath = sess.saveRun(params, data);
            [~, fname] = fileparts(filepath);

            % Expected format: Test001_YYYY-MM-DD_ABR_R_001
            pattern = '^Test001_\d{4}-\d{2}-\d{2}_ABR_R_001$';
            tc.verifyTrue(~isempty(regexp(fname, pattern, 'once')), ...
                sprintf('Filename format wrong: %s', fname));
        end

        %% --- Saved File Structure ---

        function testSavedFileHasCorrectFields(tc)
            sess = Session('Test001', 'chinchilla', 'Tester');

            params.measure_type = 'ABR';
            params.ear = 'right';
            params.frequency_hz = 8000;
            data.epochs         = randn(10, 100);
            data.fs             = 48828.125;

            filepath = sess.saveRun(params, data);
            loaded   = load(filepath);

            tc.verifyTrue(isfield(loaded,     'run'),    'File should contain a run struct.');
            tc.verifyTrue(isfield(loaded.run, 'info'),   'run should have info field.');
            tc.verifyTrue(isfield(loaded.run, 'params'), 'run should have params field.');
            tc.verifyTrue(isfield(loaded.run, 'data'),   'run should have data field.');
            tc.verifyTrue(isfield(loaded.run, 'result'), 'run should have result field.');
        end

        function testInfoFieldsPopulated(tc)
            sess = Session('Test001', 'chinchilla', 'Tester');

            params.measure_type = 'ABR';
            params.ear = 'right';
            data.epochs         = randn(10, 100);
            data.fs             = 48828.125;

            filepath = sess.saveRun(params, data);
            loaded   = load(filepath);
            info     = loaded.run.info;

            tc.verifyEqual(info.subject_id,   'Test001');
            tc.verifyEqual(info.species,      'chinchilla');
            tc.verifyEqual(info.ear,          'right');
            tc.verifyEqual(info.operator,     'Tester');
            tc.verifyEqual(info.measure_type, 'ABR');
            tc.verifyEqual(info.run_number,   1);
        end

        function testResultFieldIsEmptyStruct(tc)
            sess = Session('Test001', 'chinchilla', 'Tester');

            params.measure_type = 'ABR';
            params.ear = 'right';
            data.epochs         = randn(10, 100);
            data.fs             = 48828.125;

            filepath = sess.saveRun(params, data);
            loaded   = load(filepath);

            tc.verifyTrue(isstruct(loaded.run.result), ...
                'result should be a struct.');
            tc.verifyTrue(isempty(fieldnames(loaded.run.result)), ...
                'result should be empty before analysis.');
        end

        function testInfoStructStoredCorrectly(tc)
            info.sex      = 'Male';
            info.location = 'Pitt-BSP1-311B';
            info.notes    = 'baseline';

            sess = Session('Test001', 'chinchilla', 'Tester', info);
            tc.verifyEqual(sess.Info.sex,      'Male');
            tc.verifyEqual(sess.Info.location, 'Pitt-BSP1-311B');
            tc.verifyEqual(sess.Info.notes,    'baseline');
        end

        function testInfoMergedIntoSavedFile(tc)
            info.sex   = 'Female';
            info.group = 'Baseline';

            sess = Session('Test001', 'chinchilla', 'Tester', info);

            params.measure_type = 'ABR';
            params.ear          = 'right';
            data.epochs         = randn(10, 100);
            data.fs             = 48828.125;

            filepath = sess.saveRun(params, data);
            loaded   = load(filepath);

            tc.verifyEqual(loaded.run.info.sex,   'Female');
            tc.verifyEqual(loaded.run.info.group, 'Baseline');
        end

        %% --- Calibration ---

        function testTransducerCalEmptyWhenNoFile(tc)
            % system_config has empty active_transducer_file
            % TransducerCal should be empty but session should construct fine
            sess = Session('Test001', 'chinchilla', 'Tester');
            tc.verifyEmpty(sess.TransducerCal, ...
                'TransducerCal should be empty when no file is configured.');
        end

        function testEarCalEmptyOnInit(tc)
            sess = Session('Test001', 'chinchilla', 'Tester');
            tc.verifyEmpty(sess.EarCal, ...
                'EarCal should be empty on session init.');
        end

        function testLoadEarCalBadPathErrors(tc)
            sess = Session('Test001', 'chinchilla', 'Tester');
            tc.verifyError(@() sess.loadEarCal('nonexistent/path.mat'), ...
                'Session:earCalNotFound');
        end

    end
end