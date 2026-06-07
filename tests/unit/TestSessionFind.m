classdef TestSessionFind < matlab.unittest.TestCase

    properties
        OriginalDir
        ProjectRoot
        CreatedDirs
    end

    methods (TestMethodSetup)
        function setUp(tc)
            tc.OriginalDir  = pwd;
            thisFolder      = fileparts(mfilename('fullpath'));
            tc.ProjectRoot  = char(java.io.File( ...
                fullfile(thisFolder, '..', '..')).getCanonicalPath());
            tc.CreatedDirs  = {};
            warning('off', 'all');
        end
    end

    methods (TestMethodTeardown)
        function tearDown(tc)
            warning('on', 'all');
            % Clean up all session folders created during tests
            for i = 1:length(tc.CreatedDirs)
                if exist(tc.CreatedDirs{i}, 'dir')
                    rmdir(tc.CreatedDirs{i}, 's');
                end
            end
            cd(tc.OriginalDir);
        end
    end

    methods (Test)

        function testFindsExistingSession(tc)
            info.group         = 'Baseline';
            info.animal_status = 'Awake';
            [save_dir, ~] = session_create('FIND_001', 'Chinchilla', 'JDoe', info);
            tc.CreatedDirs{end+1} = fullfile(config_load().data.root_dir, 'FIND_001');

            [found_dir, found] = session_find('FIND_001', [], 'Baseline', 'Awake');
            tc.verifyTrue(found, 'Should find existing session.');
            tc.verifyEqual(found_dir, save_dir, 'Should return correct path.');
        end

        function testReturnsFalseWhenNoSubjectFolder(tc)
            [~, found] = session_find('FIND_NOBODY', [], 'Baseline', 'Awake');
            tc.verifyFalse(found, 'Should return false for unknown subject.');
        end

        function testReturnsFalseWhenNoMatchingSession(tc)
            info.group         = 'PTS';
            info.animal_status = 'Awake';
            session_create('FIND_002', 'Chinchilla', 'JDoe', info);
            tc.CreatedDirs{end+1} = fullfile(config_load().data.root_dir, 'FIND_002');

            % Search for different group
            [~, found] = session_find('FIND_002', [], 'Baseline', 'Awake');
            tc.verifyFalse(found, ...
                'Should not find session with different group.');
        end

        function testIgnoresFolderWithNoMetadata(tc)
            % Create a folder that looks like a session but has no metadata
            cfg         = config_load();
            fake_dir    = fullfile(cfg.data.root_dir, 'FIND_003', ...
                sprintf('%s_Baseline_Awake', datestr(now, 'yyyy-mm-dd')));
            mkdir(fake_dir);
            tc.CreatedDirs{end+1} = fullfile(cfg.data.root_dir, 'FIND_003');

            [~, found] = session_find('FIND_003', [], 'Baseline', 'Awake');
            tc.verifyFalse(found, ...
                'Should ignore folders without session_metadata.mat.');
        end

        function testFindsCorrectDateAmongMultiple(tc)
            info.group         = 'Baseline';
            info.animal_status = 'Awake';

            % Create session for today
            session_create('FIND_004', 'Chinchilla', 'JDoe', info);
            tc.CreatedDirs{end+1} = fullfile(config_load().data.root_dir, 'FIND_004');

            % Search for today
            [~, found] = session_find('FIND_004', datestr(now, 'yyyy-mm-dd'), ...
                'Baseline', 'Awake');
            tc.verifyTrue(found, 'Should find session for today.');

            % Search for different date
            [~, found2] = session_find('FIND_004', '2020-01-01', ...
                'Baseline', 'Awake');
            tc.verifyFalse(found2, 'Should not find session for wrong date.');
        end

    end

end