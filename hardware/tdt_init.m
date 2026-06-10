function tdt = tdt_init()
    % Just opens connection and loads circuit
    % No measure-specific configuration here
    IAC    = -1;
    FS_tag = 3;
    fig_num = 99; 
    usb_ch = 1;

    [tdt.f1RZ, tdt.RZ, tdt.fs] = load_play_circuit(FS_tag, fig_num, usb_ch, 0, IAC);
    
    tdt.ADdelay = 98; % Samples: measured using get_electricalDelay.m
    tdt.mat2volts = 5.0; % measures using get_card2volts.m

    fprintf('TDT RZ6 connected. Fs = %.3f Hz\n', tdt.fs);
end