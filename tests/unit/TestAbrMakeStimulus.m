classdef TestAbrMakeStimulus < matlab.unittest.TestCase
% TESTABRMAKESTIMULUS  Tests for stage 1 — the bare stimulus waveform.
%
% Replaces tests/unit/TestABRStimulus.m, which asserted against the old
% contract: abr_make_stimulus(params, cal) returning .pos, .neg,
% .isi_samples and .atten_db. Calibration moved to cal_apply_stimulus and
% buffer assembly to abr_make_buffers, so those assertions belong in
% TestCalApplyStimulus and TestAbrMakeBuffers now.
%
% Run:  runtests('tests/unit/TestAbrMakeStimulus.m')

    properties
        P
        RefPeak
    end

    methods (TestMethodSetup)
        function setUp(tc)
            tc.P         = abr_default_params();
            tc.P.n_reps  = 8;       % keep the tests quick
            cfg          = config_load();
            tc.RefPeak   = cfg.calibration.ref_peak;
        end
    end

    methods (Test)

        %% --- Contract ---

        function testReturnsBareColumnVector(tc)
            stim = abr_make_stimulus(tc.P);
            tc.verifyTrue(isnumeric(stim) && iscolumn(stim), ...
                'Stage 1 must return a plain column vector, not a struct.');
        end

        function testNoBufferFieldsLeak(tc)
            % Regression: these moved to abr_make_buffers.
            [stim, info] = abr_make_stimulus(tc.P);
            tc.verifyFalse(isstruct(stim));
            for f = {'pos', 'neg', 'isi_samples', 'atten_db'}
                tc.verifyFalse(isfield(info, f{1}), sprintf( ...
                    'stim_info still carries %s — that belongs to a later stage.', ...
                    f{1}));
            end
        end

        function testNormalizedToRefPeak(tc)
            stim = abr_make_stimulus(tc.P);
            tc.verifyEqual(max(abs(stim)), tc.RefPeak, 'AbsTol', 1e-9);
        end

        function testExplicitRefPeakHonoured(tc)
            stim = abr_make_stimulus(tc.P, 0.5);
            tc.verifyEqual(max(abs(stim)), 0.5, 'AbsTol', 1e-9);
        end

        function testLevelIndependent(tc)
            p1 = tc.P; p1.levels_dbspl = 0;
            p2 = tc.P; p2.levels_dbspl = 80;
            tc.verifyEqual(abr_make_stimulus(p1), abr_make_stimulus(p2), ...
                'AbsTol', 1e-12, ...
                'Level scaling has crept back into stage 1.');
        end

        function testNoOnsetDelayApplied(tc)
            % stim_delay_ms is applied by abr_make_buffers, not here.
            p = tc.P;
            p.stim_delay_ms = 5;
            stim = abr_make_stimulus(p);
            tc.verifyNotEqual(stim(1), 0, ...
                'Stage 1 must not pad — the waveform starts at sample 1.');
        end

        %% --- Toneburst ---

        function testTonburstLength(tc)
            p = tc.P;
            p.stim_type     = 'toneburst';
            p.frequency_hz  = 4000;
            p.duration_cyc  = 1;
            p.rise_fall_cyc = 2;

            n_rise    = ceil((p.rise_fall_cyc / p.frequency_hz) * p.fs);
            n_plateau = ceil((p.duration_cyc  / p.frequency_hz) * p.fs);
            expected  = n_plateau + 2 * n_rise;

            stim = abr_make_stimulus(p);
            tc.verifyEqual(numel(stim), expected);
        end

        function testTonburstStartsAndEndsNearZero(tc)
            p = tc.P;
            p.stim_type = 'toneburst';
            stim = abr_make_stimulus(p);
            tc.verifyLessThan(abs(stim(1)),   0.01 * tc.RefPeak);
            tc.verifyLessThan(abs(stim(end)), 0.01 * tc.RefPeak);
        end

        function testHannWindowAccepted(tc)
            p = tc.P;
            p.window_type = 'hann';
            tc.verifyWarningFree(@() abr_make_stimulus(p));
        end

        %% --- Click: the finding #3 regression ---

        function testClickIsShortNotOneIsi(tc)
            % THE BUG: make_click used to return floor(fs/rate_hz) samples
            % (~90 ms at 11.1 Hz) with the click at the midpoint, so it fell
            % outside rec_window_ms = [0 20] and nothing was recorded.
            p = tc.P;
            p.stim_type = 'click';

            stim     = abr_make_stimulus(p);
            isi_samp = floor(p.fs / p.rate_hz);

            tc.verifyLessThan(numel(stim), isi_samp / 4, sprintf( ...
                ['Click waveform is %d samples against an ISI of %d. ' ...
                 'make_click is returning a full-ISI buffer again.'], ...
                numel(stim), isi_samp));
        end

        function testClickFitsInsideRecordWindow(tc)
            % The property that actually matters: the click must be inside
            % the epoch abr_run saves.
            p = tc.P;
            p.stim_type = 'click';

            stim          = abr_make_stimulus(p);
            onset_samples = ceil(p.stim_delay_ms / 1000 * p.fs);
            epoch_samples = round(diff(p.rec_window_ms) / 1000 * p.fs);

            tc.verifyLessThanOrEqual(onset_samples + numel(stim), epoch_samples, ...
                'Click extends past rec_window_ms and would not be recorded.');
        end

        function testClickEnergyIsAtTheStart(tc)
            % Energy centroid in the first half, not the middle of an ISI.
            p = tc.P;
            p.stim_type = 'click';
            stim = abr_make_stimulus(p);

            e        = stim.^2;
            centroid = sum((1:numel(stim))' .* e) / sum(e);
            tc.verifyLessThan(centroid, numel(stim) * 0.75);
        end

        function testClickSpectrumIndependentOfRate(tc)
            % The old working buffer was floor(fs/rate_hz), so changing the
            % presentation rate changed the filter's bin spacing and hence
            % the stimulus spectrum.
            p1 = tc.P; p1.stim_type = 'click'; p1.rate_hz = 11.1;
            p2 = tc.P; p2.stim_type = 'click'; p2.rate_hz = 33.3;
            tc.verifyEqual(abr_make_stimulus(p1), abr_make_stimulus(p2), ...
                'AbsTol', 1e-12, ...
                'Click waveform changed with rate_hz.');
        end

        function testUnfilteredClickIsJustTheClick(tc)
            p = tc.P;
            p.stim_type = 'click';
            p.filtclick = 0;
            stim     = abr_make_stimulus(p);
            expected = max(1, round(p.click_duration_us / 1e6 * p.fs));
            tc.verifyEqual(numel(stim), expected);
        end

        function testFilteredClickIsBandlimited(tc)
            p = tc.P;
            p.stim_type    = 'click';
            p.filtclick    = 1;
            p.click_filter = [3000 8000];

            stim = abr_make_stimulus(p);

            N = 2^nextpow2(8 * numel(stim));
            S = abs(fft(stim, N));
            f = (0:N-1)' * p.fs / N;

            in_band  = f >= 3000 & f <= 8000;
            way_out  = f > 0 & f < 1000;

            tc.verifyGreaterThan(max(S(in_band)), 10 * max(S(way_out)), ...
                'Filtered click has substantial energy far below the passband.');
        end

        function testClickValidatesNow(tc)
            % Before the fix the validator rejected clicks outright,
            % because the buffer was one ISI long by construction.
            p = tc.P;
            p.stim_type = 'click';
            err = abr_validate_params(p);
            tc.verifyEmpty(err, sprintf('Click params rejected:\n%s', err));
        end

        %% --- Errors ---

        function testUnknownStimTypeErrors(tc)
            p = tc.P;
            p.stim_type = 'whistle';
            tc.verifyError(@() abr_make_stimulus(p), ...
                'abr_make_stimulus:unknownType');
        end

        function testMissingChirpFileErrors(tc)
            p = tc.P;
            p.stim_type  = 'chirp';
            p.chirp_file = '';
            tc.verifyError(@() abr_make_stimulus(p), ...
                'abr_make_stimulus:missingChirpFile');
        end

        %% --- stim_info ---

        function testStimInfoRecordsDuration(tc)
            [stim, info] = abr_make_stimulus(tc.P);
            tc.verifyEqual(info.n_samples, numel(stim));
            tc.verifyEqual(info.duration_ms, numel(stim)/tc.P.fs*1000, ...
                'AbsTol', 1e-9);
            tc.verifyEqual(info.ref_peak, tc.RefPeak, 'AbsTol', 1e-12);
        end

    end
end