function tag = earcal_make_file_tag(params)
% EAR_CAL_MAKE_FILE_TAG  Filename segment for ear cal.
tag = sprintf(params.channel);   % 'ch1' or 'ch2'
end