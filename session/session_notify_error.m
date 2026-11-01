function session_notify_error(message, title)
% SESSION_NOTIFY_ERROR  Show an error to the operator with no parent figure.
%
% Inputs:
%   message - text to show
%   title   - dialog title (default 'Session error')

if nargin < 2 || isempty(title)
    title = 'Session error';
end

if isempty(message)
    message = 'An unspecified error occurred.';
end

try
    uiwait(errordlg(message, title, 'modal'));
catch
    % No display, or dialogs unavailable
    fprintf(2, '\n*** %s ***\n%s\n\n', title, message);
end

end