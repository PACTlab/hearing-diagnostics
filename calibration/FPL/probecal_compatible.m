function reasons = probecal_compatible(summary, cfg, current)
% PROBECAL_COMPATIBLE  Reasons a saved FPL cal cannot be used now; {} if none.
%
% Checks only whether the calibration describes the same equipment and
% signal path. Pass/fail, stub and age are checked by the caller, since
% history overlays and the lookup treat those differently.
%
% Inputs:
%   summary - the 'summary' variable from a saved calibration file
%   cfg     - struct from config_load
%   current - struct from probecal_current_conditions; if it has
%             .buffer_size, that must match too (needed to overlay spectra)
%
% Not checked on purpose:
%   mic_dial  - the conversion to pascals removes it, so a cal made at one
%               dial setting is valid at another
%   atten_db  - responses are normalized by the drive level

reasons = {};
p = summary.probe;
q = cfg.equipment.probe;

if ~strcmp(p.id, q.id)
    reasons{end+1} = sprintf('made with probe %s; current probe is %s', p.id, q.id);
end
if p.mic_sens_v_per_pa ~= q.mic_sens_v_per_pa
    reasons{end+1} = sprintf('mic sensitivity %g V/Pa; config now says %g V/Pa', ...
        p.mic_sens_v_per_pa, q.mic_sens_v_per_pa);
end
if p.amp_fixed_gain_db ~= q.amp_fixed_gain_db
    reasons{end+1} = sprintf('amp fixed gain %g dB; config now says %g dB', ...
        p.amp_fixed_gain_db, q.amp_fixed_gain_db);
end
if summary.mat2volts ~= cfg.hardware.mat2volts
    reasons{end+1} = sprintf('mat2volts %g; config now says %g', ...
        summary.mat2volts, cfg.hardware.mat2volts);
end
if abs(summary.fs - current.fs) > 1e-6 * current.fs
    reasons{end+1} = sprintf('sample rate %.3f Hz; current %.3f Hz', summary.fs, current.fs);
end

% A fixed delay rotates the phase of Ps, so the setting must match. The
% delay value only matters when compensation is actually on.
if logical(summary.delay_comp) ~= logical(current.delay_comp)
    reasons{end+1} = sprintf('delay compensation %s; current is %s', ...
        onOff(summary.delay_comp), onOff(current.delay_comp));
elseif current.delay_comp && ~isequaln(summary.ad_delay_samples, current.ad_delay_samples)
    reasons{end+1} = sprintf('AD delay %g samples; current %g samples', ...
        summary.ad_delay_samples, current.ad_delay_samples);
end

if isfield(current, 'buffer_size') && summary.buffer_size ~= current.buffer_size
    reasons{end+1} = sprintf('buffer size %d; current %d', ...
        summary.buffer_size, current.buffer_size);
end

end

function s = onOff(x)
if x
    s = 'on';
else
    s = 'off';
end
end