classdef TestAbrValidateParams < matlab.unittest.TestCase
% TESTABRVALIDATEPARAMS  Tests for ABR parameter validation.
%
% The stub this replaces was `err = ''` unconditionally. Two consequences:
%
%   1. readParamsFromGui uses str2double, and str2double('') is NaN. A
%      blank field put NaN into the play buffer, and tdt_play_record's
%      guard is any(abs(stim) > 1), which is false for NaN.
%
%   2. levels_dbspl means dB attenuation under cal_type 'atten' and dB SPL
%      under 'SPL', and nothing checked that the list matched the mode.
%
% Run:  runtests('tests/unit/TestAbrValidateParams.m')

    properties
        P
    end

    methods (TestMethodSetup)
        function setUpParams(tc)
            tc.P = abr_default_params();
        end
    end

    methods (Test)

        %% --- Defaults must pass ---

        function testDefaultsAreValid(tc)
            [err, ~] = abr_validate_params(tc.P);
            tc.verifyEmpty(err, sprintf( ...
                'abr_default_params does not validate:\n%s', err));
        end

        function testDefaultsProduceNoWarnings(tc)
            [~, warn] = abr_validate_params(tc.P);
            tc.verifyEmpty(warn, sprintf( ...
                'Defaults produce warnings:\n%s', warn));
        end

        function testContractUnchangedForSingleOutput(tc)
            % abr_run calls this with one output and checks ~isempty
            err = abr_validate_params(tc.P);
            tc.verifyTrue(ischar(err));
        end

        %% --- NaN from blank GUI fields ---

        function testNanFrequencyRejected(tc)
            tc.P.frequency_hz = str2double('');   % exactly what the GUI does
            err = abr_validate_params(tc.P);
            tc.verifyNotEmpty(err);
            tc.verifyTrue(contains(err, 'frequency_hz'));
        end

        function testNanRepsRejected(tc)
            tc.P.n_reps = NaN;
            tc.verifyNotEmpty(abr_validate_params(tc.P));
        end

        function testNanRateRejected(tc)
            tc.P.rate_hz = NaN;
            tc.verifyNotEmpty(abr_validate_params(tc.P));
        end

        function testEmptyLevelsRejected(tc)
            tc.P.levels_dbspl = [];
            err = abr_validate_params(tc.P);
            tc.verifyTrue(contains(err, 'levels_dbspl'));
        end

        function testNanInLevelsRejected(tc)
            tc.P.levels_dbspl = [0 NaN 40];
            tc.verifyNotEmpty(abr_validate_params(tc.P));
        end

        function testAllProblemsReportedAtOnce(tc)
            % One Run press should surface everything, not the first thing.
            tc.P.frequency_hz = NaN;
            tc.P.n_reps       = -5;
            tc.P.rate_hz      = 0;
            err   = abr_validate_params(tc.P);
            lines = strsplit(err, newline);
            tc.verifyGreaterThanOrEqual(numel(lines), 3, ...
                'Expected one line per problem.');
        end

        %% --- cal_type and level units ---

        function testNegativeAttenRejected(tc)
            tc.P.cal_type     = 'atten';
            tc.P.levels_dbspl = [0 -20 40];
            err = abr_validate_params(tc.P);
            tc.verifyTrue(contains(err, 'POSITIVE'));
        end

        function testDescendingListWarnsUnderAtten(tc)
            % The classic mistake: an SPL-style list left in place while
            % cal_type is atten, so it runs quietest first.
            tc.P.cal_type     = 'atten';
            tc.P.levels_dbspl = [80 70 60 50 40 30 20 10 0];
            [err, warn] = abr_validate_params(tc.P);
            tc.verifyEmpty(err, 'A descending atten list is legal, just suspect.');
            tc.verifyTrue(contains(warn, 'LOUDEST'));
        end

        function testAscendingAttenListIsClean(tc)
            tc.P.cal_type     = 'atten';
            tc.P.levels_dbspl = [0 10 20 30];
            [err, warn] = abr_validate_params(tc.P);
            tc.verifyEmpty(err);
            tc.verifyEmpty(warn);
        end

        function testSplRejectedWithPointer(tc)
            tc.P.cal_type = 'SPL';
            err = abr_validate_params(tc.P);
            tc.verifyTrue(contains(err, 'not wired up'));
        end

        function testUnknownCalTypeRejected(tc)
            tc.P.cal_type = 'banana';
            err = abr_validate_params(tc.P);
            tc.verifyTrue(contains(err, 'cal_type'));
        end

        function testAllstopWarnsLoudly(tc)
            tc.P.cal_type = 'allstop';
            [~, warn] = abr_validate_params(tc.P);
            tc.verifyTrue(contains(warn, 'NO STIMULUS'));
        end

        function testAttenAboveMaxWarnsAboutClamping(tc)
            cfg = config_load();
            tc.P.cal_type     = 'atten';
            tc.P.levels_dbspl = [0 cfg.hardware.max_atten_db + 40];
            [err, warn] = abr_validate_params(tc.P);
            tc.verifyEmpty(err);
            tc.verifyTrue(contains(warn, 'clamped'));
        end

        %% --- Enumerations ---

        function testBadEarRejected(tc)
            tc.P.ear = 'middle';
            tc.verifyNotEmpty(abr_validate_params(tc.P));
        end

        function testBadPolarityRejected(tc)
            tc.P.polarity = 'sideways';
            tc.verifyNotEmpty(abr_validate_params(tc.P));
        end

        function testBadStimTypeRejected(tc)
            tc.P.stim_type = 'whistle';
            tc.verifyNotEmpty(abr_validate_params(tc.P));
        end

        function testUnknownWindowOnlyWarns(tc)
            tc.P.window_type = 'kaiser';
            [err, warn] = abr_validate_params(tc.P);
            tc.verifyEmpty(err, 'make_toneburst falls back to blackman.');
            tc.verifyTrue(contains(warn, 'blackman'));
        end

        %% --- Timing feasibility ---

        function testRecordWindowLongerThanIsiRejected(tc)
            % Would index past the returned buffer at runtime.
            tc.P.rate_hz       = 60;    % ISI ~16.7 ms
            tc.P.rec_window_ms = [0 20];
            err = abr_validate_params(tc.P);
            tc.verifyTrue(contains(err, 'Record window'));
        end

        function testJitterAccountedForInIsiCheck(tc)
            % The binding constraint is the SHORTEST jittered ISI.
            tc.P.rate_hz       = 51;
            tc.P.rec_window_ms = [0 19.5];
            tc.P.jitter_pct    = 0;
            tc.verifyEmpty(abr_validate_params(tc.P));

            tc.P.jitter_pct = 20;
            tc.verifyNotEmpty(abr_validate_params(tc.P));
        end

        function testStimulusLongerThanIsiRejected(tc)
            tc.P.stim_type     = 'toneburst';
            tc.P.frequency_hz  = 200;
            tc.P.duration_cyc  = 40;
            tc.P.rise_fall_cyc = 20;
            tc.P.rate_hz       = 11.1;
            err = abr_validate_params(tc.P);
            tc.verifyTrue(contains(err, 'longer than the ISI'));
        end

        function testClickErrorNamesTheKnownBug(tc)
            tc.P.stim_type = 'click';
            err = abr_validate_params(tc.P);
            tc.verifyTrue(contains(err, 'make_click'), ...
                ['Click should fail with an explanation rather than ' ...
                 'silently recording no click.']);
        end

        function testAboveNyquistRejected(tc)
            tc.P.frequency_hz = tc.P.fs;
            err = abr_validate_params(tc.P);
            tc.verifyTrue(contains(err, 'Nyquist'));
        end

        %% --- Windows ---

        function testNonIncreasingRecWindowRejected(tc)
            tc.P.rec_window_ms = [20 0];
            tc.verifyNotEmpty(abr_validate_params(tc.P));
        end

        function testNegativeRecWindowStartRejected(tc)
            tc.P.rec_window_ms = [-5 20];
            tc.verifyNotEmpty(abr_validate_params(tc.P));
        end

        function testVizOutsideRecWindowWarns(tc)
            tc.P.viz_window_ms = [0 40];
            tc.P.rec_window_ms = [0 20];
            [~, warn] = abr_validate_params(tc.P);
            tc.verifyTrue(contains(warn, 'viz_window_ms'));
        end

        %% --- Stale params structs ---

        function testMissingFieldsReportedClearly(tc)
            p = rmfield(tc.P, {'frequency_hz', 'rate_hz'});
            err = abr_validate_params(p);
            tc.verifyTrue(contains(err, 'Missing parameter fields'));
            tc.verifyTrue(contains(err, 'frequency_hz'));
        end

        function testFsMismatchWithConfigRejected(tc)
            tc.P.fs = 44100;
            err = abr_validate_params(tc.P);
            tc.verifyTrue(contains(err, 'fs_playback_hz'), ...
                'A stale project defaults file carrying an old fs must fail.');
        end

        %% --- Artifact rejection ---

        function testArtifactThreshCheckedOnlyWhenEnabled(tc)
            tc.P.artifact_reject    = false;
            tc.P.artifact_thresh_uv = -10;
            tc.verifyEmpty(abr_validate_params(tc.P));

            tc.P.artifact_reject = true;
            tc.verifyNotEmpty(abr_validate_params(tc.P));
        end

        %% --- Ear cal ---

        function testMissingEarCalFileRejected(tc)
            tc.P.apply_ear_cal = true;
            tc.P.ear_cal_file  = fullfile(tempdir, 'no_such_ear_cal_12345.mat');
            err = abr_validate_params(tc.P);
            tc.verifyTrue(contains(err, 'ear_cal_file'));
        end

        %% --- Not a stub any more ---

        function testValidatorIsNotAStub(tc)
            src = fileread(which('abr_validate_params'));
            tc.verifyEmpty(regexp(src, 'placeholder\s*—\s*always passes', 'once'), ...
                'abr_validate_params is still the stub.');
        end

    end
end