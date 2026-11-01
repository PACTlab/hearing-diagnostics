classdef TestAbrMakeBuffers < matlab.unittest.TestCase
% TESTABRMAKEBUFFERS  Tests for stage 3 — play buffer assembly.
%
% Covers the polarity, ISI and padding assertions that used to live in
% TestABRStimulus.m, now that they belong to abr_make_buffers.
%
% Run:  runtests('tests/unit/TestAbrMakeBuffers.m')

    properties
        P
        Stim
    end

    methods (TestMethodSetup)
        function setUp(tc)
            tc.P            = abr_default_params();
            tc.P.n_reps     = 16;
            tc.P.jitter_pct = 0;
            tc.Stim         = abr_make_stimulus(tc.P);
        end
    end

    methods (Test)

        %% --- Onset delay ---

        function testOnsetDelayApplied(tc)
            p = tc.P;
            p.stim_delay_ms = 2;
            expected = ceil(p.stim_delay_ms / 1000 * p.fs);

            b = abr_make_buffers(tc.Stim, p);

            tc.verifyEqual(b.onset_samples, expected);
            tc.verifyEqual(b.pos(1:expected), zeros(expected, 1), ...
                'Leading samples should be silent.');
            tc.verifyNotEqual(b.pos(expected+1), 0, ...
                'Stimulus should begin right after the delay.');
        end

        function testNStimCountsDelayPlusStimulus(tc)
            b = abr_make_buffers(tc.Stim, tc.P);
            expected = ceil(tc.P.stim_delay_ms / 1000 * tc.P.fs) + numel(tc.Stim);
            tc.verifyEqual(b.n_stim, expected);
        end

        function testZeroDelayWorks(tc)
            p = tc.P;
            p.stim_delay_ms = 0;
            b = abr_make_buffers(tc.Stim, p);
            tc.verifyEqual(b.onset_samples, 0);
        end

        %% --- Padding ---

        function testBufferPaddedToLongestIsi(tc)
            b = abr_make_buffers(tc.Stim, tc.P);
            tc.verifyEqual(numel(b.pos), max([b.isi_samples, b.n_stim]));
            tc.verifyEqual(numel(b.pos), numel(b.neg));
        end

        function testTailIsSilent(tc)
            b = abr_make_buffers(tc.Stim, tc.P);
            tail = b.pos(b.n_stim+1:end);
            if ~isempty(tail)
                tc.verifyEqual(max(abs(tail)), 0, ...
                    'Padding after the stimulus must be exactly zero.');
            end
        end

        function testBufferNeverShorterThanStimulus(tc)
            % A very slow stimulus against a fast rate: the buffer must
            % still hold the whole stimulus, or indexing it truncates.
            p = tc.P;
            p.rate_hz    = 200;
            p.jitter_pct = 0;
            w = warning('off', 'abr_make_buffers:stimTooLong');
            restore = onCleanup(@() warning(w)); %#ok<NASGU>
            b = abr_make_buffers(tc.Stim, p);
            tc.verifyGreaterThanOrEqual(numel(b.pos), b.n_stim);
        end

        %% --- Polarity modes ---

        function testAltInvertsNeg(tc)
            p = tc.P;
            p.polarity = 'alt';
            b = abr_make_buffers(tc.Stim, p);
            tc.verifyEqual(b.neg(1:b.n_stim), -b.pos(1:b.n_stim), ...
                'AbsTol', 1e-12);
        end

        function testCondGivesTwoIdenticalPositive(tc)
            p = tc.P;
            p.polarity = 'cond';
            b = abr_make_buffers(tc.Stim, p);
            tc.verifyEqual(b.neg(1:b.n_stim), b.pos(1:b.n_stim), ...
                'AbsTol', 1e-12);
        end

        function testRareGivesTwoIdenticalInverted(tc)
            p = tc.P;
            p.polarity = 'rare';
            b_rare = abr_make_buffers(tc.Stim, p);

            p.polarity = 'cond';
            b_cond = abr_make_buffers(tc.Stim, p);

            tc.verifyEqual(b_rare.pos(1:b_rare.n_stim), b_rare.neg(1:b_rare.n_stim), ...
                'AbsTol', 1e-12, 'rare must give both buffers the same polarity.');
            tc.verifyEqual(b_rare.pos(1:b_rare.n_stim), -b_cond.pos(1:b_cond.n_stim), ...
                'AbsTol', 1e-12, 'rare must be the inverse of cond.');
        end

        function testUnknownPolarityErrors(tc)
            p = tc.P;
            p.polarity = 'sideways';
            tc.verifyError(@() abr_make_buffers(tc.Stim, p), ...
                'abr_make_buffers:unknownPolarity');
        end

        %% --- ISI and jitter ---

        function testOneIsiPerRep(tc)
            b = abr_make_buffers(tc.Stim, tc.P);
            tc.verifyNumElements(b.isi_samples, tc.P.n_reps);
        end

        function testAllIsiPositive(tc)
            b = abr_make_buffers(tc.Stim, tc.P);
            tc.verifyTrue(all(b.isi_samples > 0));
        end

        function testZeroJitterGivesConstantIsi(tc)
            p = tc.P;
            p.jitter_pct = 0;
            b = abr_make_buffers(tc.Stim, p);
            tc.verifyEqual(numel(unique(b.isi_samples)), 1);
            tc.verifyEqual(b.isi_samples(1), round(p.fs / p.rate_hz));
        end

        function testJitterStaysWithinBounds(tc)
            p = tc.P;
            p.jitter_pct = 10;
            p.n_reps     = 500;
            b = abr_make_buffers(tc.Stim, p);

            nominal = round(p.fs / p.rate_hz);
            tc.verifyGreaterThanOrEqual(min(b.isi_samples), ...
                floor(nominal * 0.90) - 1);
            tc.verifyLessThanOrEqual(max(b.isi_samples), ...
                ceil(nominal * 1.10) + 1);
        end

        function testEveryIsiIndexableIntoBuffer(tc)
            % abr_run does stim_ch1(1:isi_samples(rep)); any ISI longer
            % than the buffer is an index error mid-run.
            p = tc.P;
            p.jitter_pct = 20;
            p.n_reps     = 200;
            b = abr_make_buffers(tc.Stim, p);
            tc.verifyLessThanOrEqual(max(b.isi_samples), numel(b.pos));
        end

        %% --- Clipping guard ---

        function testClippingBufferErrors(tc)
            % tdt_play_record errors on |stim| > 1 mid-run, after part of a
            % level has been collected. Catch it at assembly instead.
            tc.verifyError(@() abr_make_buffers(tc.Stim * 2, tc.P), ...
                'abr_make_buffers:bufferClips');
        end

        function testRefPeakStimulusDoesNotTripTheGuard(tc)
            tc.verifyWarningFree(@() abr_make_buffers(tc.Stim, tc.P));
        end

        %% --- buffer_info ---

        function testBufferInfoRecordsTiming(tc)
            [b, info] = abr_make_buffers(tc.Stim, tc.P);
            tc.verifyEqual(info.onset_samples, b.onset_samples);
            tc.verifyEqual(info.nominal_isi_ms, ...
                round(tc.P.fs / tc.P.rate_hz) / tc.P.fs * 1000, 'AbsTol', 1e-9);
            tc.verifyEqual(info.polarity, lower(tc.P.polarity));
        end

        function testStimTooLongWarns(tc)
            p = tc.P;
            p.rate_hz = 300;
            tc.verifyWarning(@() abr_make_buffers(tc.Stim, p), ...
                'abr_make_buffers:stimTooLong');
        end

    end
end