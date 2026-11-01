function [data, timing] = tdt_play_record(tdt, stim_ch1, stim_ch2, ...
    att_ch1, att_ch2, Nreps, throwAway, delayComp, opts)
% TDT_PLAY_RECORD  Play one stimulus and record one epoch.
%
% Inputs:
%   tdt        - TDT handle struct from tdt_init
%   stim_ch1   - [n x 1] stimulus for channel 1 (left)
%   stim_ch2   - [n x 1] stimulus for channel 2 (right), may be zeros
%   att_ch1    - analog attenuation for channel 1, dB
%   att_ch2    - analog attenuation for channel 2, dB
%   Nreps      - repetitions of the stimulus
%   throwAway  - leading reps to discard
%   delayComp  - logical; remove tdt.ADdelay from the front of the record
%   opts       - optional struct:
%                  .write_settle_s  pause after the buffer write
%                                   (default WRITE_SETTLE_DEFAULT below)
%                  .timeout_factor  acquisition timeout as a multiple of
%                                   the expected duration (default 5)
%                  .timeout_min_s   floor on the timeout (default 1)
%
% Outputs:
%   data   - [Nreps x (n_samps - delay)] recorded epochs
%   timing - measured durations for this call, in seconds:
%              .write_s .settle_s .play_s .read_s .total_s
%            Use these to record the ACHIEVED presentation rate, which is
%            not params.rate_hz — see the note on write_settle_s below.

%% --- Tunables ---------------------------------------------------
% WRITE_SETTLE_DEFAULT was a blind pause(0.05) "to ensure buffer write
% completes". It runs once per rep, so at 512 reps x 9 levels it added
% roughly four minutes of dead time per run and pushed the real
% presentation rate from 11.1 Hz down to about 7 Hz. Since ABR amplitude
% and latency both depend on rate, stim_info.nominal_isi_ms was not
% describing what the animal heard.
%
% WriteTagVEX is a synchronous ActiveX call and returns a success status,
% which is now checked below, so the pause is belt-and-braces rather than
% load-bearing. It is kept small rather than removed outright because no
% one has measured how short it can safely go on this rig.
%
% TO TUNE: run a level with write_settle_s at 0.05, 0.005 and 0, compare
% the recorded averages, and confirm timing.play_s stays consistent. If
% the waveforms match, drop it to 0 and set it here.
WRITE_SETTLE_DEFAULT = 0.005;
TIMEOUT_FACTOR       = 5;
TIMEOUT_MIN_S        = 1;

if nargin < 8 || isempty(delayComp)
    delayComp = 1;
end
if nargin < 9
    opts = struct();
end

write_settle_s = getOpt(opts, 'write_settle_s', WRITE_SETTLE_DEFAULT);
timeout_factor = getOpt(opts, 'timeout_factor', TIMEOUT_FACTOR);
timeout_min_s  = getOpt(opts, 'timeout_min_s',  TIMEOUT_MIN_S);

t_call = tic;

%% --- Clipping check ---

if any(abs(stim_ch1(:)) > 1) || any(abs(stim_ch2(:)) > 1)
    error('tdt_play_record:clipping', ...
        ['Stimulus exceeds the +/-1 DAC limit (peak ch1 %.4f, ch2 %.4f). ' ...
         'Check config.calibration.ref_peak and any filtering in ' ...
         'cal_apply_stimulus.'], ...
        max(abs(stim_ch1(:))), max(abs(stim_ch2(:))));
end

playrecTrigger = 1;

if delayComp
    delay = tdt.ADdelay;   % samples
else
    delay = 0;
end

%% --- Pad both channels to the played length ---
% n_samps can exceed the stimulus length, either because delayComp adds
% tdt.ADdelay or because the two channels differ in length. WriteTagVEX
% only writes as many samples as you give it, so the remainder of the
% circuit buffer still holds the PREVIOUS rep's data — and playback of
% n_samps would play those stale samples.
%
% Harmless today only because abr_run passes equal-length channels with
% delayComp = 0. It becomes a real artifact at the end of every epoch the
% moment delay compensation is switched on, which is the plan.

n_stim  = max(numel(stim_ch1), numel(stim_ch2));
n_samps = n_stim + delay;

buf_ch1 = zeros(n_samps, 1);
buf_ch2 = zeros(n_samps, 1);
buf_ch1(1:numel(stim_ch1)) = stim_ch1(:);
buf_ch2(1:numel(stim_ch2)) = stim_ch2(:);

%% --- Write buffers, attenuation, length ---

t_write = tic;

ok1 = invoke(tdt.RZ, 'WriteTagVEX', 'datainL', 0, 'F32', buf_ch1');
ok2 = invoke(tdt.RZ, 'WriteTagVEX', 'datainR', 0, 'F32', buf_ch2');

if ~ok1 || ~ok2
    error('tdt_play_record:bufferWriteFailed', ...
        ['WriteTagVEX failed (datainL: %d, datainR: %d) for %d samples. ' ...
         'The circuit buffer may be smaller than the stimulus.'], ...
        ok1, ok2, n_samps);
end

invoke(tdt.RZ, 'SetTagVal', 'attA', att_ch1);
invoke(tdt.RZ, 'SetTagVal', 'attB', att_ch2);
invoke(tdt.RZ, 'SetTagVal', 'nsamps', n_samps);

timing.write_s = toc(t_write);

t_settle = tic;
if write_settle_s > 0
    pause(write_settle_s);
end
timing.settle_s = toc(t_settle);

%% --- Acquisition timeout ---
% The wait below used to be an unbounded busy loop with no drawnow. If the
% circuit stalled or the device dropped off the bus mid-run it spun
% forever: the figure stopped responding, so Stop could not be clicked,
% and the only way out was Ctrl-C or killing MATLAB — which loses the
% session's in-memory metadata and its run counter.

expected_s  = n_samps / tdt.fs;
timeout_s   = max(timeout_min_s, timeout_factor * expected_s);

%% --- Play and record ---

data     = zeros(Nreps, n_samps - delay);
t_play   = tic;
read_s   = 0;

for n = 1:(Nreps + throwAway)

    invoke(tdt.RZ, 'SoftTrg', playrecTrigger);

    currindex = invoke(tdt.RZ, 'GetTagVal', 'indexin');
    t_wait    = tic;

    while currindex < n_samps
        if toc(t_wait) > timeout_s
            error('tdt_play_record:acquisitionTimeout', ...
                ['Acquisition stalled: indexin reached %d of %d samples ' ...
                 'in %.2f s (expected %.3f s, timeout %.2f s). Check the ' ...
                 'RZ6 is still on the bus and that the circuit is ' ...
                 'running.'], ...
                currindex, n_samps, toc(t_wait), expected_s, timeout_s);
        end

        % Keeps the figure responsive so Stop remains clickable. limitrate
        % throttles the redraw so this stays cheap inside a poll loop.
        drawnow limitrate

        currindex = invoke(tdt.RZ, 'GetTagVal', 'indexin');
    end

    t_read = tic;
    vin = invoke(tdt.RZ, 'ReadTagVEX', 'dataout', 0, ...
        n_samps, 'F32', 'F64', 1);
    read_s = read_s + toc(t_read);

    if numel(vin) < n_samps
        error('tdt_play_record:shortRead', ...
            'ReadTagVEX returned %d of %d samples.', numel(vin), n_samps);
    end

    if n > throwAway
        data(n - throwAway, :) = vin((delay + 1):end);
    end

    invoke(tdt.RZ, 'SoftTrg', 8);   % stop and clear the record buffer

end

timing.play_s  = toc(t_play) - read_s;
timing.read_s  = read_s;
timing.total_s = toc(t_call);

end

%% ================================================================
%  LOCAL FUNCTIONS
%% ================================================================

function v = getOpt(opts, name, default)
if isfield(opts, name) && ~isempty(opts.(name))
    v = opts.(name);
else
    v = default;
end
end