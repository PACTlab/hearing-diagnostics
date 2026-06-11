function tdt = tdt_init(config, measure_type)
    % Just opens connection and loads circuit
    % No measure-specific configuration here
    try
    IAC    = -1;
    FS_tag = 3;
    fig_num = config.hardware.fig_num; 
    usb_ch = config.hardware.usb_ch;

    [tdt.f1RZ, tdt.RZ, tdt.fs] = load_play_circuit(config, measure_type, FS_tag, fig_num, usb_ch, 0, IAC);
    
    tdt.ADdelay = 98; % Samples: measured using get_electricalDelay.m
    tdt.mat2volts = 5.0; % measures using get_card2volts.m

    fprintf('TDT RZ6 connected. Fs = %.3f Hz\n', tdt.fs);
    catch e 
        warning('tdt_init:connectionFailed', ...
    'Could not connect to TDT. Running in stub mode.');
        tdt = [];
    end
end