function tdt = tdt_init(config, measure_type)
    % Just opens connection and loads circuit
    % No measure-specific configuration here
    
    % Returns [] and warns if the hardware is unavailable, so every measure can
    % run in stub mode. 

    % Inputs:
    %   config       - struct from config_load()
    %   measure_type - 'ephys' selects BasicPlayRecord_Medusa.rcx,
    %                  anything else selects BasicPlayRecord.rcx
    %
    % Output:
    %   tdt - handle struct, or [] if unavailable:
    %           .f1RZ        ActiveX host figure
    %           .RZ          RPco.x control
    %           .fs          actual sample rate, queried from the hardware
    %           .fs_nominal  nominal rate implied by FS_tag (not exact)
    %           .ADdelay     AD delay in samples (get_electricalDelay.m)
    %           .mat2volts   DAC full-scale voltage (get_card2volts.m)

    IAC    = -1;
    FS_tag = 3;
    fig_num = config.hardware.fig_num;
    usb_ch = config.hardware.usb_ch;

    if nargin < 2
        measure_type = 'acoustic';
    end
    
    try
        [tdt.f1RZ, tdt.RZ, tdt.fs] = load_play_circuit(config, measure_type, FS_tag, fig_num, usb_ch, 0, IAC);

        tdt.ADdelay = 98+150; % Samples: measured using get_electricalDelay.m
        tdt.mat2volts = 5.0; % measures using get_card2volts.m

        fprintf('TDT RZ6 connected. Fs = %.3f Hz\n', tdt.fs);
    catch e
        warning('tdt_init:connectionFailed', ...
            'Could not connect to TDT. Running in stub mode.');
        fprintf('Check TDT - Hardware on?\n')
        tdt = [];
    end
end