function ok = tdt_check_connection(tdt)
% TDT_CHECK_CONNECTION  Verify RZ6 is still responsive.
% Returns true if connected, false otherwise.

try
    status = invoke(tdt.RZ, 'GetStatus');
    ok = (status > 0);
catch
    ok = false;
end

if ~ok
    warning('tdt_check_connection:notResponding', ...
        'TDT RZ6 not responding. Check USB connection and circuit.');
end

end