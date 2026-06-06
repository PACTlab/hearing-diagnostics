function tdt_close(tdt)
% TDT_CLOSE  Clean up TDT RZ6 connection.

fprintf('Closing TDT RZ6...\n');

% Clear stimulus buffers
invoke(tdt.RZ, 'ZeroTag', 'datainL');
invoke(tdt.RZ, 'ZeroTag', 'datainR');
pause(0.5);

% Pause circuit
invoke(tdt.RZ, 'SetTagVal', 'trigvalL', 254);
invoke(tdt.RZ, 'SetTagVal', 'onsetdel', 100);
invoke(tdt.RZ, 'SoftTrg', 6);

% Close circuit
close_play_circuit(tdt.f1RZ, tdt.RZ);
fprintf('TDT RZ6 closed.\n');

end