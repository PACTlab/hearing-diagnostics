classdef TestSessionBuildFilename < matlab.unittest.TestCase
    % Tests for session_build_filename.m
    % Does not require hardware, config, or real folders.

    methods (Test)

        %% --- Tone burst ABR ---

        function testABRToneSingleLevel(tc)
            metadata = fakeMetadata();
            params   = fakeABRParams();
            params.stim_type    = 'toneburst';
            params.frequency_hz = 8000;
            params.levels_dbspl = 70;
            params.ear = 'right'; 

            fname = session_build_filename(metadata, params);
            tc.verifyEqual(fname, ...
                'CHL-047_2024-11-15_ABR_R_8000Hz_70dB_run001.mat');
        end

        function testABRToneMultiLevel(tc)
            metadata = fakeMetadata();
            params   = fakeABRParams();
            params.stim_type    = 'toneburst';
            params.frequency_hz = 8000;
            params.levels_dbspl = [80 70 60 50];
            params.ear = 'right'; 

            fname = session_build_filename(metadata, params);
            tc.verifyEqual(fname, ...
                'CHL-047_2024-11-15_ABR_R_8000Hz_80-50dB_run001.mat');
        end

        %% --- Click ABR ---

        function testABRClick(tc)
            metadata = fakeMetadata();
            params   = fakeABRParams();
            params.stim_type    = 'click';
            params.levels_dbspl = 80;
            params.ear = 'right'; 

            fname = session_build_filename(metadata, params);
            tc.verifyEqual(fname, ...
                'CHL-047_2024-11-15_ABR_R_click_80dB_run001.mat');
        end

        %% --- Ear cal ---

        function testEarCal(tc)
            metadata = fakeMetadata();
            params.measure_type = 'EARCAL';
            params.ear          = 'right';

            fname = session_build_filename(metadata, params);
            tc.verifyEqual(fname, ...
                'CHL-047_2024-11-15_EARCAL_R_run001.mat');
        end

        %% --- Run number increments ---

        function testRunNumberFromMetadata(tc)
            metadata            = fakeMetadata();
            metadata.total_runs = 4;
            params              = fakeABRParams();
            params.stim_type    = 'toneburst';
            params.frequency_hz = 4000;
            params.levels_dbspl = 60;
            params.ear = 'right'; 

            fname = session_build_filename(metadata, params);
            tc.verifyEqual(fname, ...
                'CHL-047_2024-11-15_ABR_R_4000Hz_60dB_run005.mat');
        end

        %% --- Ear ---

        function testLeftEar(tc)
            metadata     = fakeMetadata();
            params       = fakeABRParams();
            params.ear   = 'left';
            params.stim_type    = 'toneburst';
            params.frequency_hz = 8000;
            params.levels_dbspl = 70;

            fname = session_build_filename(metadata, params);
            tc.verifyEqual(fname, ...
                'CHL-047_2024-11-15_ABR_L_8000Hz_70dB_run001.mat');
        end

        % --- Unknown Tag ---
        function testUnknownMeasureTypeNoTag(tc)
            metadata = fakeMetadata();
            params.measure_type = 'NEWMEASURE';
            params.ear          = 'right';

            % Should not error — just omits the tag
            fname = session_build_filename(metadata, params);
            tc.verifyEqual(fname, ...
                'CHL-047_2024-11-15_NEWMEASURE_R_run001.mat');
        end
    end

end

%% ================================================================
%  FIXTURE HELPERS
%% ================================================================

function metadata = fakeMetadata()
metadata.subject_id    = 'CHL-047';
metadata.date          = '2024-11-15';
metadata.species       = 'Chinchilla';
metadata.operator      = 'JDoe';
metadata.total_runs    = 0;
end

function params = fakeABRParams()
params = abr_default_params();
end