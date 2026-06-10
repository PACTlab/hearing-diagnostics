function data = tdt_play_record(tdt, stim_ch1, stim_ch2, att_ch1, att_ch2, Nreps, throwAway, delayComp)
% TDT_PLAY_RECORD  Play one stimulus and record one epoch.
%   epoch = tdt_play_record(tdt, stim_ch1, stim_ch2, att_ch1, att_ch2,
%   Nreps, delayComp)

% Inputs:
%   tdt          - TDT handle struct from tdt_init
%   stim_ch1     - [n x 1] stimulus for left channel
%   stim_ch2     - [n x 1] stimulus for right channel (can be zeros)
%   att_ch1      - analog attenuation to use on channel 1
%   att_ch2      - analog attenuation to use on channel 2
%   Nreps        - Number of repetitions of the stimulus
%   delayComp    - T/F to add the delay
%
% Output:
%   data      - [Nreps x epoch_samples] should this also be: x n_channels]
%   recorded data?

if ~exist('delayComp', 'var')
    delayComp = 1; 
end

% Check for clipping and load to buffer
if (any(abs(stim_ch1(:)) > 1)) || (any(abs(stim_ch2(:)) > 1))
    error('What did you do!? Sound is clipping!! Cannot Continue!!\n');
end

playrecTrigger = 1;

if delayComp
    delay = tdt.ADdelay; % Samples
else
    delay = 0;
end


n_samps = max(numel(stim_ch1), numel(stim_ch1)) + delay; 


% Write stimulus to circuit buffers
invoke(tdt.RZ, 'WriteTagVEX', 'datainL', 0, 'F32', stim_ch1(:)');
invoke(tdt.RZ, 'WriteTagVEX', 'datainR', 0, 'F32', stim_ch2(:)');

% Set attenuation
invoke(tdt.RZ, 'SetTagVal', 'attA', att_ch1);
invoke(tdt.RZ, 'SetTagVal', 'attB', att_ch2);

% Set stimulus length
invoke(tdt.RZ, 'SetTagVal', 'nsamps', n_samps);

% Brief pause to ensure buffer write completes
pause(0.05);

% Initialize empty data storage
data = zeros(Nreps, n_samps); 

for n = 1:(Nreps + throwAway)
    
    % Fire playback trigger
    invoke(tdt.RZ, 'SoftTrg', playrecTrigger);
    currindex = invoke(tdt.RZ, 'GetTagVal', 'indexin');

    while(currindex < n_samps)
        currindex=invoke(tdt.RZ, 'GetTagVal', 'indexin');
    end

    % Read epoch back from circuit
    vin = invoke(tdt.RZ, 'ReadTagVEX', 'dataout', 0, ...
        n_samps, 'F32', 'F64', 1);
    
    %Accumluate the time waveform - no artifact rejection
    if (n > throwAway)
        data(n-throwAway, :) = vin((delay + 1):end);
    end

    % Get ready for next trial
    invoke(tdt.RZ, 'SoftTrg', 8); % Stop and clear "OAE" buffer

end