classdef TestSessionSaveMetadata < matlab.unittest.TestCase

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
                'SAVEMETA_TEST', 'Chinchilla', 'JDoe', info);
            tc.CreatedDirs = {fullfile(config_load().data.root_dir, 'SAVEMETA_TEST')};
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

        %% --- Basic save ---

        function testUpdatesLastModified(tc)
            pause(1.1);   % ensure timestamp changes
            original_time = tc.Metadata.last_modified;
            session_save_metadata(tc.SaveDir, tc.Metadata);
            reloaded = session_load(tc.SaveDir);
            tc.verifyNotEqual(reloaded.last_modified, original_time, ...
                'last_modified should update on save.');
        end

        function testPreservesExistingFields(tc)
            session_save_metadata(tc.SaveDir, tc.Metadata);
            reloaded = session_load(tc.SaveDir);
            tc.verifyEqual(reloaded.subject_id, 'SAVEMETA_TEST');
            tc.verifyEqual(reloaded.species,    'Chinchilla');
            tc.verifyEqual(reloaded.operator,   'JDoe');
        end

        %% --- Run log ---

        function testRunLogEmptyInitially(tc)
            reloaded = session_load(tc.SaveDir);
            tc.verifyFalse(isfield(reloaded, 'run_log') && ...
                ~isempty(reloaded.run_log), ...
                'run_log should be empty before any runs.');
        end

        function testRunLogAppendedWhenRunInfoProvided(tc)
            run_info.measure_type = 'ABR';
            run_info.ear          = 'right';
            run_info.frequency_hz = 8000;
            run_info.level_dbspl  = 70;

            tc.Metadata.total_runs = 1;
            session_save_metadata(tc.SaveDir, tc.Metadata, run_info);

            reloaded = session_load(tc.SaveDir);
            tc.verifyEqual(length(reloaded.run_log), 1, ...
                'Should have one run_log entry.');
        end

        function testRunLogNotAppendedWhenNoRunInfo(tc)
            session_save_metadata(tc.SaveDir, tc.Metadata);
            reloaded = session_load(tc.SaveDir);
            tc.verifyFalse(isfield(reloaded, 'run_log') && ...
                ~isempty(reloaded.run_log), ...
                'run_log should not be created without run_info.');
        end

        function testMultipleAppendsCumulateCorrectly(tc)
            run_info1.measure_type = 'ABR';
            run_info1.ear          = 'right';
            tc.Metadata.total_runs = 1;
            meta = session_save_metadata(tc.SaveDir, tc.Metadata, run_info1);

            run_info2.measure_type = 'EARCAL';
            run_info2.ear          = 'right';
            meta.total_runs = 2;
            session_save_metadata(tc.SaveDir, meta, run_info2);

            reloaded = session_load(tc.SaveDir);
            tc.verifyEqual(length(reloaded.run_log), 2);
            tc.verifyEqual(reloaded.run_log(1).measure_type, 'ABR');
            tc.verifyEqual(reloaded.run_log(2).measure_type, 'EARCAL');
        end

        %% --- Error handling ---

        function testMissingFolderErrors(tc)
            tc.verifyError(...
                @() session_save_metadata('nonexistent/path', tc.Metadata), ...
                'session_save_metadata:folderNotFound');
        end

        function testMissingMetadataFileErrors(tc)
            % Delete metadata file to simulate corruption
            meta_path = fullfile(tc.SaveDir, 'session_metadata.mat');
            delete(meta_path);
            tc.verifyError(...
                @() session_save_metadata(tc.SaveDir, tc.Metadata), ...
                'session_save_metadata:noMetadata');
        end

    end

end