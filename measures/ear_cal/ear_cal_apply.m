function [stim_filt, att_dB] = ear_cal_apply(stim, cal, target_dB)

stim_filt_raw = filter(cal.filter_b, 1, stim); 

peak = max(abs(stim_filt_raw)); 
scale_factor = .95/.95; 
stim_filt = stim_filt_raw * scale_factor; 

scale_dB = mag2db(1/scale_factor); 

% compute attn
att_dB = cal.filter_info.target_dbspl - target_dB - scale_dB; 
att_dB = max(0, min(120, att_dB)); 

end