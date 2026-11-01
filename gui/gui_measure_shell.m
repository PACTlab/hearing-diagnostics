function h = gui_measure_shell(measure_name, metadata, cal, opts)
% Returns handles the measure GUI needs to fill in:
%   h.fig          h.mainGrid       h.ctrlSlot   (row 2, empty)
%   h.plotSlot     (row 3, empty)   h.statusLbl
%   h.transducerCalLbl               h.earCalLbl
% opts.on_close, opts.on_ear_cal, opts.on_settings — function handles
% measure_name drives the window title and the "Quit <X>" button. 