% Ear Cal Run

% At end of inear_run.m
sess.SessionCal.b           = filter_b;        % FIR coefficients
sess.SessionCal.source_file = filepath;        % the saved run file path
sess.SessionCal.timestamp   = now;
fprintf('In-ear calibration loaded into session from: %s\n', filepath);