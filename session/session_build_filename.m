function fname = session_build_filename(metadata, params)
% SESSION_BUILD_FILENAME  Build standardized filename for a run file.
%
% The measure-specific middle section is provided by a function named
% {measure_type}_make_file_tag(params) that lives in the measure folder.
% session_build_filename never needs to know about individual measures.
%
% Inputs:
%   metadata  - session metadata struct
%   params    - measure params struct (must have measure_type, ear)
%
% Output:
%   fname     - e.g. CHL-047_2024-11-15_ABR_R_8000Hz_80dB_run001.mat

run_num = metadata.total_runs + 1;
ear_str = upper(params.ear(1));

% Call the measure's own tag function if it exists
tag_fn = sprintf('%s_make_file_tag', lower(params.measure_type));
if exist(tag_fn, 'file')
    tag = feval(tag_fn, params);
else
    tag = '';
end

% Assemble parts
parts = {metadata.subject_id, metadata.date, ...
         upper(params.measure_type), ear_str};

if ~isempty(tag)
    parts{end+1} = tag;
end

parts{end+1} = sprintf('run%03d', run_num);

fname = [strjoin(parts, '_') '.mat'];

end