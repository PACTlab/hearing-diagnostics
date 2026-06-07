function tag = abr_make_file_tag(params)
% ABR_MAKE_FILE_TAG  Returns the measure-specific filename segment for ABR.
% e.g. '8000Hz_80dB' or 'click_70dB' or '8000Hz_80-20dB'

switch lower(params.stim_type)
    case 'click'
        freq_str = 'click';
    case 'chirp'
        freq_str = 'chirp';
    otherwise
        freq_str = sprintf('%dHz', round(params.frequency_hz));
end

levels = params.levels_dbspl;
if isscalar(levels)
    level_str = sprintf('%ddB', round(levels));
else
    level_str = sprintf('%d-%ddB', round(max(levels)), round(min(levels)));
end

tag = sprintf('%s_%s', freq_str, level_str);
end