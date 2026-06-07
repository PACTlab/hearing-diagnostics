classdef TestABRStimulus < matlab.unittest.TestCase
% Unit tests for abr_make_stimulus.m
% No hardware required — all tests use fake or no calibration.

    properties
        OriginalDir
    end

    methods (TestMethodSetup)
        function setUp(tc)
            tc.OriginalDir = pwd;
            %warning('off', 'abr_make_stimulus:noCal');
        end
    end

    methods (TestMethodTeardown)
        function tearDown(tc)
            %warning('on', 'abr_make_stimulus:noCal');
            cd(tc.OriginalDir);
        end
    end

    methods (Test)

        %% --- Output structure ---

        function testOutputHasRequiredFields(tc)
            params = fakeToneParams();
            [stim_out, stim_info] = abr_make_stimulus(params, []);

            tc.verifyTrue(isfield(stim_out, 'pos'),         'Missing pos.');
            tc.verifyTrue(isfield(stim_out, 'neg'),         'Missing neg.');
            tc.verifyTrue(isfield(stim_out, 'isi_samples'), 'Missing isi_samples.');
            tc.verifyTrue(isfield(stim_out, 'atten_db'),    'Missing atten_db.');
            tc.verifyTrue(isfield(stim_out, 'fs'),          'Missing fs.');
            tc.verifyTrue(isfield(stim_out, 'n_stim'),      'Missing n_stim.');

            tc.verifyTrue(isfield(stim_info, 'stim_type'),        'Missing stim_type.');
            tc.verifyTrue(isfield(stim_info, 'frequency_hz'),     'Missing frequency_hz.');
            tc.verifyTrue(isfield(stim_info, 'level_dbspl'),      'Missing level_dbspl.');
            tc.verifyTrue(isfield(stim_info, 'stim_duration_ms'), 'Missing stim_duration_ms.');
            tc.verifyTrue(isfield(stim_info, 'nominal_isi_ms'),   'Missing nominal_isi_ms.');
        end

        %% --- Multiple levels error ---

        function testMultipleLevelsErrors(tc)
            params              = fakeToneParams();
            params.levels_dbspl = [80 70 60];
            tc.verifyError(@() abr_make_stimulus(params, []), ...
                'abr_make_stimulus:multiplelevels');
        end

        %% --- Tone burst ---

        function testToneBurstDuration(tc)
            params        = fakeToneParams();
            [stim_out, ~] = abr_make_stimulus(params, []);

            n_rise    = ceil((params.rise_fall_cyc / params.frequency_hz) * params.fs);
            n_plateau = ceil((params.duration_cyc  / params.frequency_hz) * params.fs);
            expected  = n_plateau + 2 * n_rise;

            tc.verifyEqual(stim_out.n_stim, expected, ...
                'Tone burst length should match duration_cyc + 2*rise_fall_cyc.');
        end

        function testToneBurstBufferLength(tc)
            params        = fakeToneParams();
            [stim_out, ~] = abr_make_stimulus(params, []);

            % Buffer should be at least nominal ISI long
            nominal_isi = round(params.fs / params.rate_hz);
            tc.verifyGreaterThanOrEqual(length(stim_out.pos), nominal_isi, ...
                'Buffer should be at least nominal ISI length.');
        end

        function testToneBurstFrequencyContent(tc)
            params              = fakeToneParams();
            params.frequency_hz = 8000;
            [stim_out, ~]       = abr_make_stimulus(params, []);

            % Extract just the stimulus portion
            stim_portion = stim_out.pos(1:stim_out.n_stim);
            n            = length(stim_portion);
            f            = (0:n-1) * params.fs / n;
            mag          = abs(fft(stim_portion));
            [~, idx]     = max(mag(1:floor(n/2)));
            peak_freq    = f(idx);

            tc.verifyEqual(peak_freq, params.frequency_hz, 'AbsTol', 200, ...
                'Peak frequency should match requested frequency.');
        end

        function testToneBurstStartsAtSampleOne(tc)
            params        = fakeToneParams();
            [stim_out, ~] = abr_make_stimulus(params, []);

            % First sample should be nonzero if no rise time delay
            % (hann window starts at 0 so check a few samples in)
            mid_stim = round(stim_out.n_stim / 2);
            tc.verifyNotEqual(stim_out.pos(mid_stim), 0, ...
                'Stimulus should have energy in the middle of stim window.');
        end

        function testToneBurstTrailingZeros(tc)
            params        = fakeToneParams();
            [stim_out, ~] = abr_make_stimulus(params, []);

            % Samples after n_stim should be zero
            trailing = stim_out.pos(stim_out.n_stim+1:end);
            tc.verifyEqual(sum(abs(trailing)), 0, ...
                'Buffer should be zero-padded after stimulus.');
        end

        %% --- Click ---

        function testClickDuration(tc)
            params           = fakeClickParams();
            [stim_out, ~]    = abr_make_stimulus(params, []);

            expected_n_stim = max(1, round(params.click_duration_us / 1e6 * params.fs));
            tc.verifyEqual(stim_out.n_stim, expected_n_stim, ...
                'Click length should match click_duration_us.');
        end

        function testClickAmplitude(tc)
            params        = fakeClickParams();
            [stim_out, ~] = abr_make_stimulus(params, []);

            % Click should be all ones before calibration
            click_portion = stim_out.pos(1:stim_out.n_stim);
            tc.verifyTrue(all(click_portion > 0), ...
                'Condensation click should be positive.');
        end

        %% --- Polarity ---

        function testAltPolarityPosNegAreInverse(tc)
            params         = fakeToneParams();
            params.polarity = 'alt';
            [stim_out, ~]  = abr_make_stimulus(params, []);

            stim_pos = stim_out.pos(1:stim_out.n_stim);
            stim_neg = stim_out.neg(1:stim_out.n_stim);
            tc.verifyEqual(stim_neg, -stim_pos, 'AbsTol', 1e-10, ...
                'Alt polarity neg should be exact inverse of pos.');
        end

        function testCondPolarityBothSame(tc)
            params          = fakeToneParams();
            params.polarity = 'cond';
            [stim_out, ~]   = abr_make_stimulus(params, []);

            stim_pos = stim_out.pos(1:stim_out.n_stim);
            stim_neg = stim_out.neg(1:stim_out.n_stim);
            tc.verifyEqual(stim_neg, stim_pos, 'AbsTol', 1e-10, ...
                'Cond polarity pos and neg should be identical.');
        end

        function testRarePolarityBothNegative(tc)
            params          = fakeToneParams();
            params.polarity = 'rare';
            [stim_out, ~]   = abr_make_stimulus(params, []);

            stim_pos = stim_out.pos(1:stim_out.n_stim);
            stim_neg = stim_out.neg(1:stim_out.n_stim);

            % Both should be the inverted stimulus
            tc.verifyEqual(stim_pos, stim_neg, 'AbsTol', 1e-10, ...
                'Rare polarity pos and neg should be identical.');
            tc.verifyTrue(mean(stim_pos) <= 0 || ...
                any(stim_pos ~= abs(stim_pos)), ...
                'Rare polarity should be inverted relative to condensation.');
        end

        function testUnknownPolarityErrors(tc)
            params          = fakeToneParams();
            params.polarity = 'badpolarity';
            tc.verifyError(@() abr_make_stimulus(params, []), ...
                'abr_make_stimulus:unknownPolarity');
        end

        function testUnknownStimTypeErrors(tc)
            params           = fakeToneParams();
            params.stim_type = 'trumpet';
            tc.verifyError(@() abr_make_stimulus(params, []), ...
                'abr_make_stimulus:unknownType');
        end

        %% --- ISI and jitter ---

        function testISISamplesLengthEqualsNReps(tc)
            params        = fakeToneParams();
            [stim_out, ~] = abr_make_stimulus(params, []);

            tc.verifyEqual(length(stim_out.isi_samples), params.n_reps, ...
                'isi_samples should have one entry per rep.');
        end

        function testISISamplesAllPositive(tc)
            params        = fakeToneParams();
            [stim_out, ~] = abr_make_stimulus(params, []);

            tc.verifyTrue(all(stim_out.isi_samples > 0), ...
                'All ISI values should be positive.');
        end

        function testISISamplesLongerThanStimulus(tc)
            params        = fakeToneParams();
            [stim_out, ~] = abr_make_stimulus(params, []);

            tc.verifyTrue(all(stim_out.isi_samples >= stim_out.n_stim), ...
                'ISI should always be longer than stimulus.');
        end

        function testJitterVariesISI(tc)
            params              = fakeToneParams();
            params.jitter_pct   = 10;
            params.n_reps       = 50;
            [stim_out, ~]       = abr_make_stimulus(params, []);

            % With 10% jitter across 50 reps, ISI should vary
            tc.verifyGreaterThan(max(stim_out.isi_samples), ...
                min(stim_out.isi_samples), ...
                'ISI should vary across reps when jitter_pct > 0.');
        end

        function testNoJitterGivesConstantISI(tc)
            params            = fakeToneParams();
            params.jitter_pct = 0;
            params.n_reps     = 20;
            [stim_out, ~]     = abr_make_stimulus(params, []);

            tc.verifyEqual(max(stim_out.isi_samples), ...
                min(stim_out.isi_samples), ...
                'Zero jitter should give constant ISI.');
        end

        function testISIWithinJitterBounds(tc)
            params            = fakeToneParams();
            params.jitter_pct = 10;
            params.n_reps     = 100;
            [stim_out, ~]     = abr_make_stimulus(params, []);

            nominal   = round(params.fs / params.rate_hz);
            lower_bnd = round(nominal * (1 - params.jitter_pct/100)) - 1;
            upper_bnd = round(nominal * (1 + params.jitter_pct/100)) + 1;

            tc.verifyTrue(all(stim_out.isi_samples >= lower_bnd), ...
                'ISI should not go below jitter lower bound.');
            tc.verifyTrue(all(stim_out.isi_samples <= upper_bnd), ...
                'ISI should not exceed jitter upper bound.');
        end

        %% --- Buffer properties ---

        function testPosNegSameLength(tc)
            params        = fakeToneParams();
            [stim_out, ~] = abr_make_stimulus(params, []);

            tc.verifyEqual(length(stim_out.pos), length(stim_out.neg), ...
                'pos and neg buffers should be the same length.');
        end

        function testBufferLengthIsMaxISI(tc)
            params        = fakeToneParams();
            [stim_out, ~] = abr_make_stimulus(params, []);

            tc.verifyEqual(length(stim_out.pos), max(stim_out.isi_samples), ...
                'Buffer length should equal max ISI across reps.');
        end

        %% --- No calibration warning ---

        function testNoCalirationRaisesWarning(tc)
            params = fakeToneParams();
            tc.verifyWarning(@() abr_make_stimulus(params, []), ...
                'abr_make_stimulus:noCal');
        end

        function testNoCalibrationAttenDbIsNaN(tc)
            params        = fakeToneParams();
            [stim_out, ~] = abr_make_stimulus(params, []);
            tc.verifyTrue(isnan(stim_out.atten_db), ...
                'atten_db should be NaN when no calibration provided.');
        end

        %% --- Stim info ---

        function testStimInfoFrequencyMatchesParams(tc)
            params        = fakeToneParams();
            [~, stim_info] = abr_make_stimulus(params, []);
            tc.verifyEqual(stim_info.frequency_hz, params.frequency_hz);
        end

        function testStimInfoLevelMatchesParams(tc)
            params        = fakeToneParams();
            [~, stim_info] = abr_make_stimulus(params, []);
            tc.verifyEqual(stim_info.level_dbspl, params.levels_dbspl);
        end

        function testStimInfoDurationMatchesParams(tc)
            params        = fakeToneParams();
            [~, stim_info] = abr_make_stimulus(params, []);

            n_rise    = ceil((params.rise_fall_cyc / params.frequency_hz) * params.fs);
            n_plateau = ceil((params.duration_cyc  / params.frequency_hz) * params.fs);
            expected_samples = n_plateau + 2 * n_rise;
            expected_dur_ms  = expected_samples / params.fs * 1000;

            tc.verifyEqual(stim_info.stim_duration_ms, expected_dur_ms, 'AbsTol', 0.1);
        end

    end

end

%% ================================================================
%  FIXTURE HELPERS
%% ================================================================

function params = fakeToneParams()
    params = abr_default_params();
    params.stim_type    = 'toneburst';
    params.frequency_hz = 8000;
    params.levels_dbspl = 70;
    params.duration_cyc = 8;
    params.rise_fall_cyc = 2;
    params.window_type  = 'blackman';
    params.rate_hz      = 11.1;
    params.jitter_pct   = 10;
    params.n_reps       = 20;
    params.polarity     = 'alt';
    params.fs           = 48828.125;
end
function params = fakeClickParams()
    params = abr_default_params();
    params.stim_type       = 'click';
    params.levels_dbspl    = 70;
    params.click_duration_us = 100;
    params.rate_hz         = 11.1;
    params.jitter_pct      = 10;
    params.n_reps          = 20;
    params.polarity        = 'cond';
    params.fs              = 48828.125;
end