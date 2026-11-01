classdef TestGuiParseNumericList < matlab.unittest.TestCase
% TESTGUIPARSENUMERICLIST  Tests for GUI numeric list parsing.
%
% Replaces str2num, which called eval on whatever was typed into the
% Levels field.
%
% Run:  runtests('tests/unit/TestGuiParseNumericList.m')

    methods (Test)

        %% --- Formats operators actually type ---

        function testSpaceSeparated(tc)
            [v, err] = gui_parse_numeric_list('0 10 20 30');
            tc.verifyEmpty(err);
            tc.verifyEqual(v, [0 10 20 30]);
        end

        function testCommaSeparated(tc)
            [v, err] = gui_parse_numeric_list('0, 10, 20, 30');
            tc.verifyEmpty(err);
            tc.verifyEqual(v, [0 10 20 30]);
        end

        function testMixedSeparators(tc)
            [v, err] = gui_parse_numeric_list('0, 10  20;30');
            tc.verifyEmpty(err);
            tc.verifyEqual(v, [0 10 20 30]);
        end

        function testPastedBracketsTolerated(tc)
            [v, err] = gui_parse_numeric_list('[80 70 60]');
            tc.verifyEmpty(err);
            tc.verifyEqual(v, [80 70 60]);
        end

        function testSurroundingWhitespace(tc)
            [v, err] = gui_parse_numeric_list('   0  10   ');
            tc.verifyEmpty(err);
            tc.verifyEqual(v, [0 10]);
        end

        function testSingleValue(tc)
            [v, err] = gui_parse_numeric_list('40');
            tc.verifyEmpty(err);
            tc.verifyEqual(v, 40);
        end

        function testDecimalsAndNegatives(tc)
            [v, err] = gui_parse_numeric_list('-3.5, 0, 12.25');
            tc.verifyEmpty(err);
            tc.verifyEqual(v, [-3.5 0 12.25]);
        end

        function testRowVectorShape(tc)
            v = gui_parse_numeric_list('0 10 20');
            tc.verifyTrue(isrow(v), ...
                'Must be a row vector — abr_run indexes levels_dbspl(i).');
        end

        %% --- Failures, named clearly ---

        function testEmptyReported(tc)
            [v, err] = gui_parse_numeric_list('');
            tc.verifyEmpty(v);
            tc.verifyNotEmpty(err);
        end

        function testWhitespaceOnlyReported(tc)
            [v, err] = gui_parse_numeric_list('    ');
            tc.verifyEmpty(v);
            tc.verifyNotEmpty(err);
        end

        function testGarbageTokenNamed(tc)
            [v, err] = gui_parse_numeric_list('0 10 abc 30');
            tc.verifyEmpty(v);
            tc.verifyTrue(contains(err, 'abc'), ...
                'The error should name the offending token.');
        end

        function testTypoNamed(tc)
            [v, err] = gui_parse_numeric_list('0 1O 20');   % letter O
            tc.verifyEmpty(v);
            tc.verifyTrue(contains(err, '1O'));
        end

        function testMultipleBadTokensAllNamed(tc)
            [~, err] = gui_parse_numeric_list('0 xx 20 yy');
            tc.verifyTrue(contains(err, 'xx') && contains(err, 'yy'));
        end

        %% --- No eval ---

        function testDoesNotEvaluateExpressions(tc)
            % str2num would return 9 here. Arithmetic in a level field is
            % almost certainly a typo, and accepting it means accepting
            % arbitrary code.
            [v, err] = gui_parse_numeric_list('3*3');
            tc.verifyEmpty(v);
            tc.verifyNotEmpty(err);
        end

        function testDoesNotExecuteSideEffects(tc)
            % The actual risk with str2num: this would have run.
            marker = fullfile(tempdir, 'tdt_str2num_side_effect.txt');
            if exist(marker, 'file'); delete(marker); end

            gui_parse_numeric_list( ...
                sprintf('fopen(''%s'',''w'')', marker));

            tc.verifyFalse(exist(marker, 'file') == 2, ...
                'Field contents were executed — eval is still in the path.');
        end

        function testNoStr2NumInSource(tc)
            src = fileread(which('gui_parse_numeric_list'));
            src = regexprep(src, '^\s*%[^\n]*$', '', 'lineanchors');
            tc.verifyEmpty(regexp(src, '\bstr2num\b', 'once'));
            tc.verifyEmpty(regexp(src, '\beval\b', 'once'));
        end

        %% --- Integration with the validator ---

        function testParsedLevelsValidate(tc)
            p = abr_default_params();
            p.levels_dbspl = gui_parse_numeric_list('0 10 20 30');
            err = abr_validate_params(p);
            tc.verifyEmpty(err, sprintf('%s', err));
        end

    end
end