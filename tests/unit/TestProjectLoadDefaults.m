classdef TestProjectLoadDefaults < matlab.unittest.TestCase

    properties
        OriginalDir
        ProjectsDir
        TestProjectName
    end

    methods (TestMethodSetup)
        function setUp(tc)
            tc.OriginalDir     = pwd;
            thisFolder         = fileparts(mfilename('fullpath'));
            projectRoot        = char(java.io.File( ...
                fullfile(thisFolder, '..', '..')).getCanonicalPath());
            tc.ProjectsDir     = fullfile(projectRoot, 'projects');
            tc.TestProjectName = 'test_project_defaults';
            warning('off', 'all');
        end
    end

    methods (TestMethodTeardown)
        function tearDown(tc)
            warning('on', 'all');
            % Clean up test project if created
            test_dir = fullfile(tc.ProjectsDir, tc.TestProjectName);
            if exist(test_dir, 'dir')
                rmdir(test_dir, 's');
            end
            cd(tc.OriginalDir);
        end
    end

    methods (Test)

        function testLoadsLabDefaultWhenNoProject(tc)
            params = project_load_defaults('abr', 'lab_default');
            tc.verifyTrue(isstruct(params), ...
                'Should return a struct.');
            tc.verifyTrue(isfield(params, 'measure_type'), ...
                'Should have measure_type field.');
            tc.verifyEqual(params.measure_type, 'ABR');
        end

        function testFallsBackToLabDefaultForUnknownProject(tc)
            params = project_load_defaults('abr', 'nonexistent_project');
            tc.verifyTrue(isstruct(params), ...
                'Should fall back to lab default without error.');
        end

        function testLoadsProjectOverrideWhenExists(tc)
            % Create a test project with custom abr params
            test_dir = fullfile(tc.ProjectsDir, tc.TestProjectName);
            mkdir(test_dir);

            % Write a custom params file with different frequency
            fid = fopen(fullfile(test_dir, 'abr_default_params.m'), 'w');
            fprintf(fid, 'function params = abr_default_params()\n');
            fprintf(fid, 'params = abr_default_params_base();\n');
            fprintf(fid, 'params.frequency_hz = 4000;\n');
            fprintf(fid, 'params.n_reps = 256;\n');
            fprintf(fid, 'end\n');
            fclose(fid);

            % Actually simpler — write a complete minimal params file
            fid = fopen(fullfile(test_dir, 'abr_default_params.m'), 'w');
            fprintf(fid, 'function params = abr_default_params()\n');
            fprintf(fid, 'params.measure_type       = ''ABR'';\n');
            fprintf(fid, 'params.stim_type          = ''toneburst'';\n');
            fprintf(fid, 'params.frequency_hz       = 4000;\n');
            fprintf(fid, 'params.duration_ms        = 5;\n');
            fprintf(fid, 'params.rise_fall_ms       = 0.5;\n');
            fprintf(fid, 'params.click_duration_us  = 100;\n');
            fprintf(fid, 'params.chirp_file         = '''';\n');
            fprintf(fid, 'params.levels_dbspl       = [60 50 40];\n');
            fprintf(fid, 'params.polarity           = ''alternating'';\n');
            fprintf(fid, 'params.rate_hz            = 11.1;\n');
            fprintf(fid, 'params.jitter_pct         = 10;\n');
            fprintf(fid, 'params.n_reps             = 256;\n');
            fprintf(fid, 'params.epoch_window_ms    = [0 20];\n');
            fprintf(fid, 'params.fs                 = 48828.125;\n');
            fprintf(fid, 'params.n_channels         = 1;\n');
            fprintf(fid, 'params.gain               = 10000;\n');
            fprintf(fid, 'params.artifact_reject    = false;\n');
            fprintf(fid, 'params.artifact_thresh_v  = 0.04;\n');
            fprintf(fid, 'params.memory_reps        = 0;\n');
            fprintf(fid, 'params.fixed_phase        = false;\n');
            fprintf(fid, 'params.ear                = ''right'';\n');
            fprintf(fid, 'params.apply_ear_cal      = true;\n');
            fprintf(fid, 'params.ear_cal_file       = '''';\n');
            fprintf(fid, 'end\n');
            fclose(fid);

            params = project_load_defaults('abr', tc.TestProjectName);
            tc.verifyEqual(params.frequency_hz, 4000, ...
                'Should load project override frequency.');
            tc.verifyEqual(params.n_reps, 256, ...
                'Should load project override reps.');
        end

        function testErrorForMissingMeasureInLabDefault(tc)
            tc.verifyError(...
                @() project_load_defaults('nonexistentmeasure', 'lab_default'), ...
                'project_load_defaults:notFound');
        end

        function testEmptyProjectNameUsesLabDefault(tc)
            params = project_load_defaults('abr', '');
            tc.verifyTrue(isstruct(params), ...
                'Empty project name should use lab default.');
        end

        function testReturnsCorrectMeasureType(tc)
            params = project_load_defaults('abr', 'lab_default');
            tc.verifyEqual(params.measure_type, 'ABR');
        end

    end

end