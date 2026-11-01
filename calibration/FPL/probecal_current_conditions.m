function current = probecal_current_conditions(cfg, tdt, delay_comp)
% PROBECAL_CURRENT_CONDITIONS  What a saved FPL cal must match to be usable now.
%
% Called by any measure that wants an FPL calibration, and by the probe
% cal GUI for its history overlays.
%
% Inputs:
%   cfg        - struct from config_load
%   tdt        - struct from tdt_init, or [] (stub: nominal fs, no AD delay)
%   delay_comp - the delay compensation setting the CALLER will record with
%
% Output current:
%   .fs, .ad_delay_samples, .delay_comp
%   (.buffer_size may be added by the caller for strict history matching)
%
% Probe identity, sensitivity, amp gain and mat2volts are read from cfg by
% probecal_compatible, so they are not repeated here.

if isempty(tdt)
    current.fs               = cfg.hardware.fs_record_hz;
    current.ad_delay_samples = NaN;
else
    current.fs               = tdt.fs;
    current.ad_delay_samples = tdt.ADdelay;
end
current.delay_comp = logical(delay_comp);

end
