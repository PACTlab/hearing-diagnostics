function [values, err] = gui_parse_numeric_list(text)
% GUI_PARSE_NUMERIC_LIST  Parse a numeric list from a GUI text field.
%
% Replaces str2num, which calls eval — so anything typed into the field
% ran as MATLAB code. A stray character also produced a confusing error or
% a silent empty result rather than a clear message.
%
% Accepts commas, spaces, semicolons, and newlines as separators, and
% tolerates surrounding brackets so a pasted "[80 70 60]" still works.
%
% Inputs:
%   text   - char or string from a uieditfield
%
% Outputs:
%   values - [1 x n] double row vector, or [] if nothing parsed
%   err    - char; empty when the parse succeeded. Naming the offending
%            token beats "levels_dbspl must be finite real numbers".
%
% Shared across measures: every level, frequency and rate list field has
% the same problem.

values = [];
err    = '';

if nargin < 1 || isempty(text)
    err = 'Field is empty.';
    return
end

if isstring(text)
    text = char(text);
end

%% --- Strip decoration ---

txt = strtrim(text);
txt = regexprep(txt, '^\[|\]$', '');   % tolerate pasted brackets
txt = strtrim(txt);

if isempty(txt)
    err = 'Field is empty.';
    return
end

%% --- Split and convert ---

tokens = strsplit(txt, {',', ' ', ';', newline, sprintf('\t')});
tokens = tokens(~cellfun(@isempty, tokens));

if isempty(tokens)
    err = 'Field is empty.';
    return
end

parsed = str2double(tokens);
bad    = isnan(parsed) & ~strcmpi(tokens, 'nan');

if any(bad)
    err = sprintf('Could not read %s: %s', ...
        pluralize(sum(bad), 'entry', 'entries'), ...
        strjoin(cellfun(@(t) ['''' t ''''], tokens(bad), ...
            'UniformOutput', false), ', '));
    return
end

values = parsed(:)';

end

%% ================================================================
%  LOCAL FUNCTIONS
%% ================================================================

function s = pluralize(n, singular, plural)
if n == 1
    s = singular;
else
    s = plural;
end
end