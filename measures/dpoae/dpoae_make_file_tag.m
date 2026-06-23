function tag = dpoae_make_file_tag(params)
% Returns the measure specific file tag. By default, file tag is
% Subjec_Date_Measure_Ear_ then some measure specific info which is defined here. 

switch lower(params.stim_type)
    case 'swept'
        type_str = 'swept';
    case 'discrete'
        type_str = 'discrete';
    otherwise
        type_str = 'other'; 
end

level_f1 = params.level_f1_dB;
level_f2 = params.level_f2_dB;

if isscalar(levels)
    level1_str = sprintf('%ddB', round(level_f1));
    level2_str = sprintf('%ddB', round(level_f2));
end

tag = sprintf('%s_%s-%s', type_str, level1_str, level2_str);
end