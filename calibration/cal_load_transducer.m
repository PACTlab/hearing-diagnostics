function cal = cal_load_transducer(cal_path)
% CAL_LOAD_TRANSDUCER  Load a transducer calibration file.
%
% Input:
%   cal_path  - path to a transducer cal .mat file
%               if empty, loads the file specified in system_config
%
% Output:
%   cal       - transducer calibration struct
%
% Expected fields in the cal file:
%   cal.transducer_name    string   e.g. 'ER2', 'ER10B'
%   cal.frequency_hz       [n x 1]  frequencies measured
%   cal.sensitivity_dbspl  [n x 1]  dB SPL per volt RMS at each frequency
%   cal.max_voltage        scalar   max safe output voltage
%   cal.fs                 scalar   sample rate when measured
%   cal.date               string   date measured
%   cal.measured_by        string
%   cal.equipment          string   e.g. 'B&K 4157 ear simulator'
%   cal.notes              string
%   cal.filename           string   populated by this function on load

if ~exist(cal_path, 'file')
    error('cal_load_transducer:fileNotFound', ...
        'Calibration file not found: %s', cal_path);
end

loaded = load(cal_path);

% Expect a struct named 'cal' inside the file
if ~isfield(loaded, 'cal')
    error('cal_load_transducer:badFormat', ...
        'Cal file must contain a struct named ''cal''. Got: %s', ...
        strjoin(fieldnames(loaded), ', '));
end

cal = loaded.cal;

% Validate required fields
required = {'transducer_name', 'frequency_hz', 'sensitivity_dbspl', ...
            'max_voltage', 'date'};
for i = 1:length(required)
    if ~isfield(cal, required{i})
        error('cal_load_transducer:missingField', ...
            'Cal file missing required field: %s', required{i});
    end
end

% Validate curve dimensions
if length(cal.frequency_hz) ~= length(cal.sensitivity_dbspl)
    error('cal_load_transducer:dimensionMismatch', ...
        'frequency_hz and sensitivity_dbspl must be the same length.');
end

% Store filename for logging
cal.filename = cal_path;

fprintf('Loaded transducer cal: %s (%s, measured %s)\n', ...
    cal.transducer_name, cal.equipment, cal.date);

end