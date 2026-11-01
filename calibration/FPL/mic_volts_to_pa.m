function [pa, gain_db] = mic_volts_to_pa(v, cfg, mic_dial)
% MIC_VOLTS_TO_PA  Convert probe-mic volts at the RZ6 input to pascals.
%
% The one place the mic gain convention is applied. Every measure that
% converts mic voltage to pressure (probe cal, DPOAE, SFOAE, MEMR) should
% call this rather than repeating the arithmetic.
%
% Inputs:
%   v        - mic voltage at the RZ6 input, any size
%   cfg      - struct from config_load (schema 2)
%   mic_dial - amp dial setting for this run (dial 1 = x1, dial 10 = x10)
%
% Outputs:
%   pa       - pressure in Pa, same size as v
%   gain_db  - total amp gain used: fixed stage + dial
%
% Convention (see config_edit header):
%   cfg.equipment.probe.mic_sens_v_per_pa  bare mic, excludes the amp
%   cfg.equipment.probe.amp_fixed_gain_db  the amp's fixed 10x stage
%   total gain = amp_fixed_gain_db + 20*log10(mic_dial)
%
% Polarity is NOT applied here. It only rotates the phase of the Thevenin
% source pressure, so it is harmless as long as calibration and ear
% measurements treat it the same way. If it is ever applied, it goes here,
% so every caller picks it up together.

if ~isscalar(mic_dial) || ~isnumeric(mic_dial) || ~(mic_dial > 0)
    error('mic_volts_to_pa:badDial', ...
        'mic_dial must be a positive scalar (got %s).', mat2str(mic_dial));
end

probe   = cfg.equipment.probe;
gain_db = probe.amp_fixed_gain_db + 20*log10(mic_dial);
pa      = v / (10^(gain_db/20) * probe.mic_sens_v_per_pa);

end