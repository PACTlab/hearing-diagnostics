function [stim, cal_info] = cal_apply(stim, sess, params)
% CAL_APPLY  Apply calibration pipeline to a stimulus waveform.
%
% Returns corrected stimulus and a cal_info struct that gets saved
% with the run so you always know what was applied.

cal_info.cal_type        = params.cal_type;
cal_info.apply_ear_cal = params.apply_ear_cal;
cal_info.ear_cal_file  = 'none';
cal_info.atten_db        = NaN;

%% Stage 1: Reference calibration (SPL or FPL)

switch upper(params.cal_type)
    case 'SPL'
        [stim, atten_db] = cal_apply_transducer(stim, sess.TransducerCal, ...
            params.frequency_hz, params.levels_dbspl);
        cal_info.transducer_cal_file = sess.TransducerCal.filename;

    case 'FPL'
        [stim, atten_db] = cal_apply_fpl(stim, sess.FPLCal, ...
            params.frequency_hz, params.levels_dbspl);
        cal_info.fpl_cal_file = sess.FPLCal.filename;

    otherwise
        error('cal_apply:unknownType', ...
            'Unknown cal_type: %s. Use SPL or FPL.', params.cal_type);
end

cal_info.atten_db = atten_db;

%% Stage 2: In-ear correction filter

if ~params.apply_ear_cal
    % Explicitly turned off
    fprintf('In-ear cal skipped (apply_ear_cal = false).\n');
    return
end

% Determine which filter to use
if ~isempty(params.ear_cal_file)
    % Specific file requested
    if ~exist(params.ear_cal_file, 'file')
        error('cal_apply:missingInearFile', ...
            'Specified ear_cal_file not found: %s', params.ear_cal_file);
    end
    loaded = load(params.ear_cal_file);
    ear_cal = loaded.run.result.filter;
    cal_info.ear_cal_file = params.ear_cal_file;

elseif ~isempty(sess.SessionCal)
    % Use most recent from session (default)
    ear_cal = sess.SessionCal;
    cal_info.ear_cal_file = sess.SessionCal.source_file;

else
    % Nothing available — warn but continue
    warning('cal_apply:noInearCal', ...
        ['apply_ear_cal is true but no in-ear cal is loaded. ' ...
        'Run ear_run() first or set apply_ear_cal = false.']);
    return
end

% Apply FIR filter
stim = filter(ear_cal.b, 1, stim);

end