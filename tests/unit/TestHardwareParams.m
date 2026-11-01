classdef TestHardwareParams < matlab.unittest.TestCase
% TESTHARDWAREPARAMS  Tests that hardware facts have one source of truth.
%
% Two bugs these guard against:
%
%   1. fs, gain and n_channels were literals in every {m}_default_params
%      while config.hardware carried its own unread copy. Editing the
%      config had no effect and the two could diverge silently.
%
%   2. params.gain meant a LINEAR electrode gain (10000) in ABR/EFR and a
%      dB probe-mic gain (20) in DPOAE/MEMR. Same field name, two units,
%      two pieces of hardware, a factor of 500 apart. Anything handling
%      params.gain generically would have been badly wrong.
%
% Run:  runtests('tests/unit/TestHardwareParams.m')

    methods (Test)

        %% --- Config side ---

        function testConfigHasSplitGainFields(tc)
            cfg = config_load();
            tc.verifyTrue(isfield(cfg.hardware, 'electrode_gain'));
            tc.verifyTrue(isfield(cfg.hardware, 'mic_gain_db'));
            tc.verifyTrue(isfield(cfg.hardware, 'mic_sens_v_per_pa'));
        end

        function testAmbiguousGainFieldIsGone(tc)
            % config_load errors on the old field, so reaching here at all
            % proves it is absent; assert explicitly for a clear message.
            cfg = config_load();
            tc.verifyFalse(isfield(cfg.hardware, 'gain'), ...
                ['config.hardware.gain still present. Run ' ...
                 'config_migrate_hardware_fields.']);
        end

        function testGainUnitsAreNotSwapped(tc)
            cfg = config_load();
            tc.verifyGreaterThanOrEqual(cfg.hardware.electrode_gain, 1, ...
                'electrode_gain is LINEAR — a value below 1 suggests dB.');
            tc.verifyLessThan(cfg.hardware.mic_gain_db, 200, ...
                'mic_gain_db is in dB — a large value suggests linear.');
        end

        %% --- Params side ---

        function testAbrFsComesFromConfig(tc)
            cfg    = config_load();
            params = abr_default_params();
            tc.verifyEqual(params.fs, cfg.hardware.fs_playback_hz, ...
                'params.fs is not tracking config.hardware.fs_playback_hz.');
        end

        function testAbrElectrodeGainComesFromConfig(tc)
            cfg    = config_load();
            params = abr_default_params();
            tc.verifyEqual(params.electrode_gain, cfg.hardware.electrode_gain);
        end

        function testAbrNChannelsComesFromConfig(tc)
            cfg    = config_load();
            params = abr_default_params();
            tc.verifyEqual(params.n_channels, cfg.hardware.n_channels);
        end

        function testAbrHasNoAmbiguousGainField(tc)
            params = abr_default_params();
            tc.verifyFalse(isfield(params, 'gain'), ...
                'abr_default_params still has the ambiguous params.gain.');
        end

        function testElectrodeGainAppliedIsRecorded(tc)
            % The circuit applies the gain, so analysis must know not to
            % divide by it again. Without this field that is unknowable
            % from the saved run file.
            params = abr_default_params();
            tc.verifyTrue(isfield(params, 'electrode_gain_applied'));
            tc.verifyTrue(ismember(params.electrode_gain_applied, ...
                {'circuit', 'software', 'none'}), ...
                'electrode_gain_applied must be circuit, software, or none.');
        end

        function testStubModePresentAndFalseByDefault(tc)
            params = abr_default_params();
            tc.verifyTrue(isfield(params, 'stub_mode'));
            tc.verifyFalse(params.stub_mode, ...
                'stub_mode must default to false or nobody collects data.');
        end

        function testDefaultParamsNeedsNoHardware(tc)
            % config_load only reads a .mat, so this must work with nothing
            % plugged in — tests and demo scripts depend on it.
            tc.verifyWarningFree(@() abr_default_params());
        end

        %% --- Derived quantities ---

        function testMicVtoSplMatchesOldExpression(tc)
            % Old: (1 / (db2mag(20) * 500e-3)) * (1/20e-6)
            expected = (1 / (10^(20/20) * 500e-3)) * (1/20e-6);
            tc.verifyEqual(mic_v_to_spl(20, 0.5), expected, 'RelTol', 1e-12, ...
                'mic_v_to_spl does not reproduce the original VtoSPL value.');
        end

        function testMicVtoSplDefaultsToConfig(tc)
            cfg      = config_load();
            expected = mic_v_to_spl(cfg.hardware.mic_gain_db, ...
                                    cfg.hardware.mic_sens_v_per_pa);
            tc.verifyEqual(mic_v_to_spl(), expected, 'RelTol', 1e-12);
        end

        function testMicVtoSplRejectsBadSensitivity(tc)
            tc.verifyError(@() mic_v_to_spl(20, 0), ...
                'mic_v_to_spl:badSensitivity');
        end

        function testHigherGainMeansLowerScaleFactor(tc)
            % Sanity on direction: more amplifier gain means a given SPL
            % produces more volts, so the V->SPL factor must shrink.
            tc.verifyLessThan(mic_v_to_spl(40, 0.5), mic_v_to_spl(20, 0.5));
        end

        %% --- No stragglers ---

        function testNoMeasureRestatesFsAsLiteral(tc)
            % Any remaining literal sample rate in a default_params file is
            % a second source of truth waiting to drift.
            root  = config_repo_root();
            files = dir(fullfile(root, 'measures', '**', '*_default_params.m'));
            offenders = {};
            for i = 1:numel(files)
                txt = fileread(fullfile(files(i).folder, files(i).name));
                if ~isempty(regexp(txt, 'params\.fs\s*=\s*\d', 'once'))
                    offenders{end+1} = files(i).name;  %#ok<AGROW>
                end
            end
            tc.verifyEmpty(offenders, sprintf( ...
                'Literal params.fs still in: %s', strjoin(offenders, ', ')));
        end

        function testNoMeasureUsesAmbiguousGain(tc)
            root  = config_repo_root();
            files = dir(fullfile(root, 'measures', '**', '*_default_params.m'));
            offenders = {};
            for i = 1:numel(files)
                txt = fileread(fullfile(files(i).folder, files(i).name));
                if ~isempty(regexp(txt, 'params\.gain\s*=', 'once'))
                    offenders{end+1} = files(i).name;  %#ok<AGROW>
                end
            end
            tc.verifyEmpty(offenders, sprintf( ...
                ['Ambiguous params.gain still in: %s. Use electrode_gain ' ...
                 '(linear) or mic_gain_db (dB).'], strjoin(offenders, ', ')));
        end

    end
end