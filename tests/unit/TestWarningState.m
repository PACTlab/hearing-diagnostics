classdef TestWarningState < matlab.unittest.TestCase
% TESTWARNINGSTATE  Tests that warning suppression stays scoped.
%
% The bug these guard against: load_play_circuit had a bare
% warning('off'), equivalent to warning('off','all'), that was never
% restored. tdt_init calls it on every GUI launch, so opening any measure
% window silenced every warning for the rest of the MATLAB session —
% including cal_apply_transducer:clipping, the only signal that a stimulus
% is over-driving the transducer.
%
% Run:  runtests('tests/unit/TestWarningState.m')

    properties
        OriginalState
    end

    methods (TestMethodSetup)
        function saveState(tc)
            tc.OriginalState = warning;
        end
    end

    methods (TestMethodTeardown)
        function restoreState(tc)
            warning(tc.OriginalState);
        end
    end

    methods (Test)

        %% --- The safety list is well-formed ---

        function testAllSafetyWarningsEnabledByDefault(tc)
            warning('on', 'all');
            [ok, disabled] = config_check_warnings('check');
            tc.verifyTrue(ok, sprintf('Disabled with warnings on: %s', ...
                strjoin(disabled, ', ')));
        end

        function testDetectsIndividuallyDisabled(tc)
            warning('on', 'all');
            warning('off', 'cal_apply_transducer:clipping');
            [ok, disabled] = config_check_warnings('check');
            tc.verifyFalse(ok, 'Did not detect a disabled safety warning.');
            tc.verifyTrue(ismember('cal_apply_transducer:clipping', disabled));
        end

        function testDetectsBlanketOff(tc)
            warning('off', 'all');
            [ok, disabled] = config_check_warnings('check');
            tc.verifyFalse(ok, ...
                'warning(''off'',''all'') was not detected — the original bug.');
            tc.verifyNotEmpty(disabled);
        end

        function testQueryWithMixedStateDoesNotError(tc)
            % Regression: warning('query','all') returns a struct ARRAY once
            % any identifier has been set explicitly, so treating it as a
            % scalar threw MATLAB:maxrhs from strcmp.
            warning('on', 'all');
            warning('off', 'cal_apply_transducer:clipping');
            warning('off', 'abr_make_stimulus:noCal');
            warning('on',  'cal_apply:noInearCal');
            tc.verifyWarningFree(@() config_check_warnings('check'), ...
                'Mixed individual/blanket warning state errored.');
        end

        function testExplicitOnOverridesBlanketOff(tc)
            % An explicit per-identifier 'on' takes effect even while 'all'
            % is off, so that warning is NOT disabled and must not be
            % reported as such. A false alarm here is worse than no check.
            warning('off', 'all');
            warning('on',  'cal_apply_transducer:clipping');
            [~, disabled] = config_check_warnings('check');
            tc.verifyFalse(ismember('cal_apply_transducer:clipping', disabled), ...
                ['Reported an explicitly-enabled warning as disabled — ' ...
                 'false positive.']);
        end

        function testFixModeLeavesUnrelatedSuppressionAlone(tc)
            % fix mode must not blanket-enable: diagnostic warnings the
            % operator silenced on purpose should stay silenced.
            warning('on',  'all');
            warning('off', 'abr_run:stubMode');
            warning('off', 'cal_apply_transducer:clipping');

            config_check_warnings('fix');

            safety = warning('query', 'cal_apply_transducer:clipping');
            tc.verifyEqual(safety.state, 'on', ...
                'fix mode did not re-enable a safety warning.');

            diagnostic = warning('query', 'abr_run:stubMode');
            tc.verifyEqual(diagnostic.state, 'off', ...
                'fix mode re-enabled a diagnostic warning it should not touch.');
        end

        function testFixModeReenables(tc)
            warning('off', 'all');
            config_check_warnings('fix');
            [ok, ~] = config_check_warnings('check');
            tc.verifyTrue(ok, 'fix mode did not re-enable the safety warnings.');
        end

        function testSafetyIdsMatchRaisedWarnings(tc)
            % Every identifier on the safety list must actually be raised
            % somewhere, or the list is documenting a warning that no longer
            % exists (as Session:noTransducerCal did).
            [~, ids] = config_check_warnings('check');  %#ok<ASGLU>
            warning('on', 'all');

            root  = config_repo_root();
            files = dir(fullfile(root, '**', '*.m'));
            src   = '';
            for i = 1:numel(files)
                if contains(files(i).folder, [filesep 'tests' filesep])
                    continue
                end
                src = [src fileread(fullfile(files(i).folder, files(i).name))]; %#ok<AGROW>
            end

            safety_ids = safetyListFromSource();
            for i = 1:numel(safety_ids)
                tc.verifyTrue(contains(src, safety_ids{i}), sprintf( ...
                    ['Safety warning "%s" is on the list but never raised. ' ...
                     'Remove it or fix the identifier.'], safety_ids{i}));
            end
        end

        %% --- Scoping ---

        function testNoBareWarningOffInSource(tc)
            % A bare warning('off') or warning('off','all') outside tests is
            % almost always a mistake. If one is genuinely needed, it must be
            % paired with onCleanup restoration in the same file.
            root  = config_repo_root();
            files = dir(fullfile(root, '**', '*.m'));
            offenders = {};

            for i = 1:numel(files)
                if contains(files(i).folder, [filesep 'tests' filesep])
                    continue
                end
                fpath = fullfile(files(i).folder, files(i).name);
                txt   = fileread(fpath);
                txt   = regexprep(txt, '^\s*%[^\n]*$', '', 'lineanchors');

                bare = contains(txt, "warning('off')") || ...
                       contains(txt, "warning('off', 'all')") || ...
                       contains(txt, "warning('off','all')");

                if bare && ~contains(txt, 'onCleanup')
                    offenders{end+1} = files(i).name;  %#ok<AGROW>
                end
            end

            tc.verifyEmpty(offenders, sprintf( ...
                ['Unscoped warning(''off'') without onCleanup restoration in: %s. ' ...
                 'Suppress specific identifiers, or restore state on exit.'], ...
                strjoin(offenders, ', ')));
        end

        function testSessionNoTransducerCalIsGone(tc)
            % This identifier was never raised — the three GUI suppressions
            % were dead code and should have been deleted, not kept.
            root  = config_repo_root();
            files = dir(fullfile(root, 'measures', '**', '*.m'));
            found = {};
            for i = 1:numel(files)
                txt = fileread(fullfile(files(i).folder, files(i).name));
                if contains(txt, 'Session:noTransducerCal')
                    found{end+1} = files(i).name;  %#ok<AGROW>
                end
            end
            tc.verifyEmpty(found, sprintf( ...
                'Dead warning suppression Session:noTransducerCal still in: %s', ...
                strjoin(found, ', ')));
        end

    end
end

%% ================================================================
%  HELPERS
%% ================================================================

function ids = safetyListFromSource()
% Read the safety list out of config_check_warnings so the test and the
% implementation can't drift apart.
txt   = fileread(which('config_check_warnings'));
block = extractBetween(txt, 'safety_ids = {', '};');
tokens = regexp(block{1}, '''([A-Za-z_]+:[A-Za-z_]+)''', 'tokens');
ids = cellfun(@(t) t{1}, tokens, 'UniformOutput', false);
end