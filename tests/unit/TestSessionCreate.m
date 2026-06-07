classdef TestSessionCreate < matlab.unittest.TestCase

    properties
        OriginalDir
        ProjectRoot
        TmpDir
    end

    methods (TestMethodSetup)
        function setUp(tc)
            tc.OriginalDir = pwd;
            thisFolder     = fileparts(mfilename('fullpath'));
            tc.ProjectRoot = char(java.io.File( ...
                fullfile(thisFolder, '..', '..')).getCanonicalPath());
            tc.TmpDir      = tempdir;
            warning('off', 'all');
            cd(tc.TmpDir);
        end
    end

    methods (TestMethodTeardown)
        function tearDown(tc)
            warning('on', 'all');
            cd(tc.OriginalDir);

            % Clean up any test folders created in data/
            cfg      = config_load();
            test_ids = {'TEST_CREATE', 'TEST_META', 'TEST_FIELDS', ...
                'TEST_RUNS', 'TEST_SUBJ', 'TEST_INFO', ...
                'TEST_RESUME', 'TEST_FOLDER'};

            for i = 1:length(test_ids)
                test_dir = fullfile(cfg.data.root_dir, test_ids{i});
                if exist(test_dir, 'dir')
                    rmdir(test_dir, 's');
                end
            end
        end
    end

    methods (Test)

        function testCreatesMissingFolder(tc)
            [save_dir, ~] = session_create('TEST_CREATE', 'Chinchilla', 'JDoe', []);
            tc.verifyTrue(exist(save_dir, 'dir') == 7, ...
                'session_create should create the session folder.');
        end

        function testWritesMetadataFile(tc)
            [save_dir, ~] = session_create('TEST_META', 'Chinchilla', 'JDoe', []);
            meta_path = fullfile(save_dir, 'session_metadata.mat');
            tc.verifyTrue(exist(meta_path, 'file') == 2, ...
                'session_create should write session_metadata.mat.');
        end

        function testMetadataHasRequiredFields(tc)
            [~, metadata] = session_create('TEST_FIELDS', 'Chinchilla', 'JDoe', []);
            required = {'subject_id', 'species', 'operator', 'date', ...
                        'total_runs', 'created', 'last_modified'};
            for i = 1:length(required)
                tc.verifyTrue(isfield(metadata, required{i}), ...
                    sprintf('metadata missing field: %s', required{i}));
            end
        end

        function testTotalRunsStartsAtZero(tc)
            [~, metadata] = session_create('TEST_RUNS', 'Chinchilla', 'JDoe', []);
            tc.verifyEqual(metadata.total_runs, 0);
        end

        function testSubjectIDStoredCorrectly(tc)
            [~, metadata] = session_create('TEST_SUBJ', 'Chinchilla', 'JDoe', []);
            tc.verifyEqual(metadata.subject_id, 'TEST_SUBJ');
        end

        function testInfoFieldsStoredCorrectly(tc)
            info.sex            = 'Male';
            info.group          = 'Baseline';
            info.animal_status  = 'Awake';
            info.notes          = 'test notes';

            [~, metadata] = session_create('TEST_INFO', 'Chinchilla', 'JDoe', info);
            tc.verifyEqual(metadata.sex,            'Male');
            tc.verifyEqual(metadata.group,          'Baseline');
            tc.verifyEqual(metadata.animal_status,  'Awake');
            tc.verifyEqual(metadata.notes,          'test notes');
        end

        function testExistingSessionLoadsInsteadOfOverwriting(tc)
            info.group         = 'Baseline';
            info.animal_status = 'Awake';

            % Create once
            [save_dir1, meta1] = session_create('TEST_RESUME', 'Chinchilla', 'JDoe', info);

            % Manually set total_runs to 3 and save
            meta1.total_runs = 3;
            metadata = meta1;
            save(fullfile(save_dir1, 'session_metadata.mat'), 'metadata');

            % Create again with same params — should load existing
            [save_dir2, meta2] = session_create('TEST_RESUME', 'Chinchilla', 'JDoe', info);

            tc.verifyEqual(save_dir1, save_dir2, ...
                'Should return same folder for duplicate session.');
            tc.verifyEqual(meta2.total_runs, 3, ...
                'Should load existing metadata, not overwrite it.');
        end

        function testFolderNameContainsGroupAndStatus(tc)
            info.group         = 'PTS';
            info.animal_status = 'KetXyl';

            [save_dir, ~] = session_create('TEST_FOLDER', 'Chinchilla', 'JDoe', info);
            [~, folder_name] = fileparts(save_dir);

            tc.verifyTrue(contains(folder_name, 'PTS'), ...
                'Folder name should contain group.');
            tc.verifyTrue(contains(folder_name, 'KetXyl'), ...
                'Folder name should contain animal status.');
        end

    end

end