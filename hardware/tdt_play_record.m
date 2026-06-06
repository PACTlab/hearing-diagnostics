function epoch = tdt_play_record(tdt, stim_L, stim_R, atten_db, trig_val_L, trig_val_R)
% TDT_PLAY_RECORD  Play one stimulus and record one epoch.
%
% Inputs:
%   tdt        - TDT handle struct from tdt_init
%   stim_L     - [n x 1] stimulus for left channel
%   stim_R     - [n x 1] stimulus for right channel (can be zeros)
%   atten_db   - attenuation in dB (same for both channels for now)
%   trig_val_L - trigger value left
%   trig_val_R - trigger value right
%
% Output:
%   epoch      - [epoch_samples x n_channels] recorded data

% Write stimulus to circuit buffers
invoke(tdt.RZ, 'WriteTagVEX', 'datainL', 0, 'F32', stim_L(:)');
invoke(tdt.RZ, 'WriteTagVEX', 'datainR', 0, 'F32', stim_R(:)');

% Set attenuation
invoke(tdt.RZ, 'SetTagVal', 'attA', atten_db);
invoke(tdt.RZ, 'SetTagVal', 'attB', atten_db);

% Set stimulus length
invoke(tdt.RZ, 'SetTagVal', 'nsamps', length(stim_L));

% Set triggers
invoke(tdt.RZ, 'SetTagVal', 'trigvalL', trig_val_L);
invoke(tdt.RZ, 'SetTagVal', 'trigvalR', trig_val_R);

% Brief pause to ensure buffer write completes
pause(0.05);

% Fire playback trigger
invoke(tdt.RZ, 'SoftTrg', 1);

% Wait for epoch to complete
% Epoch duration + small buffer for circuit latency
epoch_dur_s = tdt.epoch_samples / tdt.fs;
pause(epoch_dur_s + 0.01);

% Read epoch back from circuit
epoch(:, 1) = invoke(tdt.RZ, 'ReadTagVEX', 'epochbufL', 0, ...
    tdt.epoch_samples, 'F32', 'F64');

if tdt.n_channels == 2
    epoch(:, 2) = invoke(tdt.RZ, 'ReadTagVEX', 'epochbufR', 0, ...
        tdt.epoch_samples, 'F32', 'F64');
end

end