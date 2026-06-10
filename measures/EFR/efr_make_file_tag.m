function tag = efr_make_file_tag(params)
% EFR_MAKE_FILE_TAG  Returns the measure-specific filename segment for EFR.
% e.g. '8000Hz_80dB' or 'click_70dB' 'stim_level'

switch lower(params.stim_type)
    case 'wav'
        file_str = params.wav_file;
    case 'sam'
        file_str = sprintf('SAM_mod%sHz_car%sHz', params.mod_frequency_hz, params.carrier_frequency_hz); 
    case 'ram'
        file_str = sprintf('RAM_mod%sHz_car%sHz', params.mod_frequency_hz, params.carrier_frequency_hz); 
    otherwise
        file_str = 'stim';
end

levels = params.levels_dbspl;
if isscalar(levels)
    level_str = sprintf('%ddB', round(levels));
else
    level_str = sprintf('%d-%ddB', round(max(levels)), round(min(levels)));
end

tag = sprintf('%s_%s', file_str, level_str);
end