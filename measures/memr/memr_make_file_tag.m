function tag = memr_make_file_tag(params)
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

tag = sprintf('%s', type_str);
end