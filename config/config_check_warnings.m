function [ok, disabled] = config_check_warnings(mode)
% CONFIG_CHECK_WARNINGS  Verify the safety-critical warnings are enabled.
%
% Several warnings in this codebase are the only indication the operator
% gets that data may be invalid or that hardware is being over-driven.
% A stray warning('off','all') anywhere — in library code, in a test
% teardown, typed at the prompt — silences them for the rest of the MATLAB
% session with no visible sign.
%
% Call this before acquisition starts. It is cheap.
%
% Inputs:
%   mode - 'check'  (default) report only
%          'fix'    re-enable any that are off, and say so
%
% Outputs:
%   ok       - true if all safety warnings are enabled
%   disabled - cellstr of identifiers that were off
%
% Example, in a measure GUI's onRun:
%   if ~config_check_warnings('fix')
%       updateStatus('Re-enabled suppressed safety warnings — see console.');
%   end

if nargin < 1
    mode = 'check';
end

%% --- The list ---
% Add an entry whenever a new warning is the sole signal of an unsafe or
% invalid condition. Diagnostic-only warnings (stubMode, resampling
% notices) deliberately stay off this list — operators turn those off on
% purpose and that is fine.

safety_ids = {
    'cal_apply_transducer:clipping'          % stimulus exceeds transducer max voltage
    'cal_apply_transducer:freqOutOfRange'    % extrapolating calibration
    'cal_apply_transducer:stimNotNormalized' % scaling applied to wrong baseline
    'cal_apply:noInearCal'                   % running without in-ear correction
    'cal_apply_stimulus:notNormalized'       % level scaling applied twice
    'cal_apply_stimulus:attenClamped'        % requested level not presented
    'cal_apply_stimulus:outputGated'         % allstop: no stimulus at all
    'abr_make_buffers:stimTooLong'           % stimulus exceeds the ISI
    'abr_run:rateMismatch'                   % achieved rate != nominal
    'efr_make_stimulus:noCal'                % uncalibrated stimulus
    'efr_make_stimulus:stimMayBeTooLong'     % stimulus may exceed epoch
    'ear_cal_compute_filter:gainClipped'     % correction filter hit its limit
    'cal_transducer_registry:notFound'       % unknown transducer
    };
%% --- Query ---

disabled = {};
for i = 1:numel(safety_ids)
    state = warning('query', safety_ids{i});
    if strcmp(state.state, 'off')
        disabled{end+1} = safety_ids{i};   %#ok<AGROW>
    end
end

ok = isempty(disabled);

% Separately, note whether blanket suppression is in force. This does NOT
% by itself mean the safety warnings are off: an explicit per-identifier
% setting overrides 'all', so warning('query', id) above is authoritative.
% We report it only as a diagnostic hint about how things got this way.
%
% Note warning('query','all') returns a struct ARRAY once any identifier
% has been set explicitly — one entry for 'all' plus one per setting — so
% it has to be indexed by identifier, not treated as scalar.
all_off = false;
state_list = warning('query', 'all');
is_all = strcmp({state_list.identifier}, 'all');
if any(is_all)
    entry   = state_list(is_all);
    all_off = strcmp(entry(1).state, 'off');
end

%% --- Report / fix ---

if ok
    return
end

switch lower(mode)
    case 'fix'
        % Re-enable only the safety identifiers. Deliberately not
        % warning('on','all') — the operator may have silenced diagnostic
        % warnings on purpose, and an explicit per-identifier 'on' takes
        % effect even while 'all' is off.
        for i = 1:numel(disabled)
            warning('on', disabled{i});
        end
        fprintf(2, ['\n*** %d safety warning(s) were disabled and have been ' ...
            're-enabled: ***\n'], numel(disabled));
        fprintf(2, '      %s\n', disabled{:});
        if all_off
            fprintf(2, '    (warning(''off'',''all'') is in force.)\n');
        end
        fprintf(2, ['    Anything collected earlier in this MATLAB session ' ...
            'may have hidden a\n    calibration or clipping problem. ' ...
            'Check before trusting it.\n\n']);

    otherwise
        fprintf(2, '\n*** %d safety warning(s) are disabled: ***\n', ...
            numel(disabled));
        fprintf(2, '      %s\n', disabled{:});
        if all_off
            fprintf(2, '    (warning(''off'',''all'') is in force.)\n');
        end
        fprintf(2, '    Run config_check_warnings(''fix'') to re-enable.\n\n');
end

end