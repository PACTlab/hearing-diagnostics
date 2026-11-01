classdef TestCalApplyStimulus < matlab.unittest.TestCase
% TESTCALAPPLYSTIMULUS  Tests for the shared calibration entry point.
%
% The bug this guards against: abr_run set att_ch1 = att_ch2 = 30 as
% literals while cal_apply_transducer applied the whole level correction
% digitally and returned atten_db purely as a log of what it had done.
% Nothing read it. Every ABR level was presented 30 dB below the requested
% value, silently.
%
% Run:  runtests('tests/unit/TestCalApplyStimulus.m')

    properties
        P
        RefPeak
        MaxAtten
        Step
    end

    methods (TestMethodSetup)
        function setUpParams(tc)
            cfg          = config_load();
            tc.RefPeak   = cfg.calibration.ref_peak;
            tc.MaxAtten  = cfg.hardware.max_atten_db;
            tc.Step      = cfg.hardware.atten_step_db;

            tc.P = struct( ...
                'cal_type',      'atten', ...
                'levels_dbspl',  [0 20 40], ...
                'frequency_hz',  4000, ...
                'apply_ear_cal', false);
        end
    end

    methods (Test)

        %% --- atten mode ---

        function testAttenPassesThroughUnchanged(tc)
            stim_in = tc.RefPeak * sin(2*pi*(0:999)'/50);
            [stim_out, cal] = cal_apply_stimulus(stim_in, tc.P);
            tc.verifyEqual(cal.atten_db, [0 20 40], 'AbsTol', 1e-9, ...
                'atten mode must pass the level list through as attenuation.');
            tc.verifyEqual(stim_out, stim_in, 'AbsTol', 1e-12, ...
                'atten mode must not rescale the waveform.');
        end

        function testAttenIsOnePerLevel(tc)
            tc.P.levels_dbspl = [0 5 10 15 20 25];
            [~, cal] = cal_apply_stimulus(tc.RefPeak*ones(100,1), tc.P);
            tc.verifyNumElements(cal.atten_db, 6, ...
                'One attenuation value per requested level.');
        end

        function testLevelUnitsRecorded(tc)
            [~, cal] = cal_apply_stimulus(tc.RefPeak*ones(100,1), tc.P);
            tc.verifyEqual(cal.level_units, 'dB attenuation', ...
                ['Saved runs must state the units, or a level list is ' ...
                 'uninterpretable later.']);
        end

        function testNegativeAttenRejected(tc)
            tc.P.levels_dbspl = [0 -10 20];
            tc.verifyError(@() cal_apply_stimulus(tc.RefPeak*ones(100,1), tc.P), ...
                'cal_apply_stimulus:negativeAtten');
        end

        function testZeroAttenIsLoudest(tc)
            tc.P.levels_dbspl = [0 60];
            [~, cal] = cal_apply_stimulus(tc.RefPeak*ones(100,1), tc.P);
            tc.verifyLessThan(cal.atten_db(1), cal.atten_db(2), ...
                '0 must be the loudest, per the positive-attenuation convention.');
        end

        %% --- Clamping and quantization ---

        function testClampsAboveMaxAndRecordsIt(tc)
            tc.P.levels_dbspl = [0 tc.MaxAtten + 30];
            [~, cal] = cal_apply_stimulus(tc.RefPeak*ones(100,1), tc.P);
            tc.verifyEqual(cal.atten_db(2), tc.MaxAtten, 'AbsTol', 1e-9);
            tc.verifyTrue(cal.clamped(2), ...
                'A clamped level must be flagged in the saved run.');
            tc.verifyFalse(cal.clamped(1));
        end

        function testClampWarns(tc)
            tc.P.levels_dbspl = [tc.MaxAtten + 10];
            tc.verifyWarning(@() cal_apply_stimulus(tc.RefPeak*ones(100,1), tc.P), ...
                'cal_apply_stimulus:attenClamped');
        end

        function testQuantizesToStep(tc)
            if tc.Step <= 0
                tc.assumeFail('Continuous attenuator; nothing to quantize.');
            end
            tc.P.levels_dbspl = [20.03 20.07];
            [~, cal] = cal_apply_stimulus(tc.RefPeak*ones(100,1), tc.P);
            residual = abs(cal.atten_db / tc.Step - round(cal.atten_db / tc.Step));
            tc.verifyLessThan(max(residual), 1e-9, ...
                'Attenuation must land on the attenuator grid.');
        end

        function testNothingRequestedIsStillValid(tc)
            tc.P.levels_dbspl = 0;
            [~, cal] = cal_apply_stimulus(tc.RefPeak*ones(100,1), tc.P);
            tc.verifyEqual(cal.atten_db, 0, 'AbsTol', 1e-9);
            tc.verifyFalse(any(cal.clamped));
        end

        %% --- Normalization guard ---

        function testWarnsIfLevelScalingWasAppliedUpstream(tc)
            % The failure this catches: a measure still scaling the
            % waveform by level, which would compound with the analog
            % attenuation invisibly.
            tc.verifyWarning(@() cal_apply_stimulus(0.001*ones(100,1), tc.P), ...
                'cal_apply_stimulus:notNormalized');
        end

        function testCorrectlyNormalizedIsQuiet(tc)
            tc.verifyWarningFree(@() ...
                cal_apply_stimulus(tc.RefPeak*ones(100,1), tc.P));
        end

        function testDigitalPeakRecorded(tc)
            [~, cal] = cal_apply_stimulus(tc.RefPeak*ones(100,1), tc.P);
            tc.verifyEqual(cal.digital_peak, tc.RefPeak, 'AbsTol', 1e-9);
        end

        function testRefPeakIsBelowUnity(tc)
            % tdt_play_record errors on |stim| > 1 mid-run.
            tc.verifyLessThan(tc.RefPeak, 1, ...
                'ref_peak at or above 1.0 will trip the clipping error.');
        end

        %% --- Other modes ---

        function testAllstopZeroesAndMaxAttenuates(tc)
            tc.P.cal_type = 'allstop';
            w = warning('off', 'cal_apply_stimulus:outputGated');
            restore = onCleanup(@() warning(w)); %#ok<NASGU>
            [stim_out, cal] = cal_apply_stimulus(tc.RefPeak*ones(100,1), tc.P);
            tc.verifyEqual(max(abs(stim_out)), 0, ...
                'allstop must zero the waveform.');
            tc.verifyEqual(unique(cal.atten_db), tc.MaxAtten, 'AbsTol', 1e-9, ...
                'allstop must also apply maximum attenuation.');
            tc.verifyTrue(cal.gated, ...
                'A gated run must be marked, or it looks like real data.');
        end

        function testNoneGivesZeroAtten(tc)
            tc.P.cal_type = 'none';
            [~, cal] = cal_apply_stimulus(tc.RefPeak*ones(100,1), tc.P);
            tc.verifyEqual(unique(cal.atten_db), 0, 'AbsTol', 1e-9);
        end

        function testSplErrorsWithGuidance(tc)
            tc.P.cal_type = 'SPL';
            tc.verifyError(@() cal_apply_stimulus(tc.RefPeak*ones(100,1), tc.P), ...
                'cal_apply_stimulus:notImplemented');
        end

        function testUnknownCalTypeErrors(tc)
            tc.P.cal_type = 'banana';
            tc.verifyError(@() cal_apply_stimulus(tc.RefPeak*ones(100,1), tc.P), ...
                'cal_apply_stimulus:unknownCalType');
        end

        %% --- Stimulus generation is now level-independent ---

        function testStimulusDoesNotDependOnLevel(tc)
            p1 = abr_default_params();
            p2 = p1;
            p1.levels_dbspl = 0;
            p2.levels_dbspl = 80;
            p1.n_reps = 4; p2.n_reps = 4;

            tc.verifyEqual(abr_make_stimulus(p1), abr_make_stimulus(p2), ...
                'AbsTol', 1e-12, ...
                ['Stimulus changed with level — level scaling has crept ' ...
                 'back into abr_make_stimulus.']);
        end

        function testPipelineOutputStaysUnderUnity(tc)
            % End to end through all three stages: the assembled buffers
            % must clear the tdt_play_record clipping limit.
            p = abr_default_params();
            p.n_reps = 4;

            base            = abr_make_stimulus(p);
            [stim_cal, ~]   = cal_apply_stimulus(base, p);
            b               = abr_make_buffers(stim_cal, p);

            tc.verifyLessThan(max(abs(b.pos)), 1);
            tc.verifyLessThan(max(abs(b.neg)), 1);
        end

        function testAttenModeLeavesBufferPeakAtRefPeak(tc)
            p = abr_default_params();
            p.n_reps = 4;

            base          = abr_make_stimulus(p);
            [stim_cal, ~] = cal_apply_stimulus(base, p);
            b             = abr_make_buffers(stim_cal, p);

            tc.verifyEqual(max(abs(b.pos)), tc.RefPeak, 'AbsTol', 1e-9, ...
                'atten mode must not rescale the waveform.');
        end

        function testMakeStimulusTakesNoCalArgument(tc)
            % Regression: the old signature was (params, cal) and applied
            % level scaling internally.
            tc.verifyEqual(nargin('abr_make_stimulus'), 2, ...
                'Expected abr_make_stimulus(params, ref_peak).');
        end

        %% --- No hardcoded attenuation left ---

        function testAbrRunHasNoHardcodedAttenuation(tc)
            src = fileread(which('abr_run'));
            src = regexprep(src, '^\s*%[^\n]*$', '', 'lineanchors');
            tc.verifyEmpty(regexp(src, 'att_ch[12]\s*=\s*\d', 'once'), ...
                ['abr_run assigns a literal to att_ch1/att_ch2. ' ...
                 'Attenuation must come from cal_out.atten_db.']);
        end

    end
end