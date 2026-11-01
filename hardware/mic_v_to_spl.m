function v_to_spl = mic_v_to_spl(mic_gain_db, mic_sens_v_per_pa)
% MIC_V_TO_SPL  Scale factor converting recorded volts to SPL ratio.
%
% Multiply a recorded voltage amplitude by this, then take 20*log10, to get
% dB SPL:
%
%   dB_SPL = db(abs(voltage) * mic_v_to_spl())
%
% Chain: divide out the mic amplifier gain, divide by mic sensitivity to
% get pascals, then reference to 20 uPa.
%
% Inputs (both optional — default to config.hardware):
%   mic_gain_db       - probe mic amplifier gain in dB
%   mic_sens_v_per_pa - probe mic sensitivity in V/Pa
%
% Output:
%   v_to_spl - scalar scale factor
%
% This replaces params.VtoSPL, which was precomputed inside
% dpoae_default_params and memr_default_params as
%
%   (1 / (db2mag(params.gain) * 500e-3)) * (1/20e-6)
%
% Storing it as a parameter meant a derived quantity travelled in the
% params struct, and a project override that changed the gain stayed
% correct only because the VtoSPL line happened to come afterwards in the
% file. Deriving it at the point of use removes that ordering dependency.
%
% The 20 uPa reference is a physical constant and stays hardcoded. The mic
% gain and sensitivity are properties of the rig and live in the config.

if nargin < 1 || isempty(mic_gain_db) || nargin < 2 || isempty(mic_sens_v_per_pa)
    cfg = config_load();
    if nargin < 1 || isempty(mic_gain_db)
        mic_gain_db = cfg.hardware.mic_gain_db;
    end
    if nargin < 2 || isempty(mic_sens_v_per_pa)
        mic_sens_v_per_pa = cfg.hardware.mic_sens_v_per_pa;
    end
end

P_REF_PA = 20e-6;   % 0 dB SPL reference

if mic_sens_v_per_pa <= 0
    error('mic_v_to_spl:badSensitivity', ...
        'Mic sensitivity must be positive, got %g V/Pa.', mic_sens_v_per_pa);
end

mic_gain_linear = 10^(mic_gain_db / 20);

v_to_spl = 1 / (mic_gain_linear * mic_sens_v_per_pa * P_REF_PA);

end