function tdt = tdt_init(circuit_path, fig_num, usb_ch)
    % Just opens connection and loads circuit
    % No measure-specific configuration here
    IAC    = -1;
    FS_tag = 3;
    [tdt.f1RZ, tdt.RZ, tdt.fs] = load_play_circuit(FS_tag, fig_num, usb_ch, 0, IAC);
    tdt.circuit_path = circuit_path;
    fprintf('TDT RZ6 connected. Fs = %.3f Hz\n', tdt.fs);
end