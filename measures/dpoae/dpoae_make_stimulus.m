function [stim_out, stim_info] = dpoae_make_stimulus(params)
% DPOAE_MAKE_STIMULUS  Generate DPOAE stimulus waveform(s).

%% --- Input checks ---

% TODO: Code to verify params
fs = params.fs;

%% --- Build the base waveform (before level scaling) ---

switch lower(params.stim_type)

    case 'discrete'
        [base_stim1, base_stim2, t] = make_discrete_dp(params, fs);
        stim_info.f2_hz     = params.f2_hz;
        stim_info.f1_hz     = params.f2_hz ./ params.ratio;
    case 'swept'
        [base_stim1, base_stim2, t, phi1_inst, phi2_inst] = make_swept_dp(params, fs);
        stim_info.phi1_inst = phi1_inst;
        stim_info.phi2_inst = phi2_inst;
        stim_info.t         = t;
        stim_info.buffdur   = params.buffdur_ms / 1000;

    otherwise
        error('dpoae_make_stimulus:unknownType', ...
            'Unknown stim_type: %s. Use swept or discrete.', ...
            params.stim_type);
end

% add a standard delay so stim doesn't start at sample 1
n_stim = numel(base_stim1); 

%% --- Package output ---

stim_out.ch1         = base_stim1;
stim_out.ch2         = base_stim2;
stim_out.t              = t; 
stim_out.fs          = fs;
stim_out.n_stim      = n_stim;


%% --- Diagnostic info ---
stim_info.stim_type = params.stim_type;
stim_info.fs        = fs;
end


%% =========================================================
%  LOCAL FUNCTIONS
%% =========================================================

function [y1, y2, t, phi1_inst, phi2_inst] = make_swept_dp(params, fs)

    if params.sweepDirection == -1 % downsweep
        f_start = params.max_f2_hz;
        f_end = params.min_f2_hz;
    elseif params.sweepDirection == 1 % upsweep
        f_start = params.min_f2_hz;
        f_end = params.max_f2_hz;
    else
        error('dpoae_make_stimulus:unknownSweepDirection', ...
            'Unknown direction: %s. Use -1 (downsweep) or 1 (upsweep).', ...
            params.sweepDirection);
    end

    buffdur = params.buffdur_ms/1000; 
    if strcmp(params.scale, 'log')
        dur = log2(params.max_f2_hz/params.min_f2_hz) / abs(params.speed) + (2*buffdur);
    else
        dur = abs(f_start - f_end) / abs(params.speed) + (2*buffdur);
    end

    t = 0: (1/fs): (dur - 1/fs);

    buffinst1 = find(t < buffdur, 1, 'last');
    buffinst2 = find(t > (dur - buffdur), 1, 'first');
    buffdur_exact = t(buffinst1);

if strcmp(params.scale, 'log')
    % in Phase
    start_2 = f_start*t(1:buffinst1);
    phi2_inst = f_start*(2.^( (t-buffdur_exact) * params.speed) - 1) / (params.speed * log(2)) + start_2(end); % Cycles
    end_2 = f_end*t(1:(length(t)-buffinst2+1)) + phi2_inst(buffinst2);
    phi2_inst(1:buffinst1) = start_2;
    phi2_inst(buffinst2:end) = end_2;
else % linear sweep
    % in Phase
    start_2 = f_start*t(1:buffinst1);
    buffdur_exact = t(buffinst1);
    phi2_inst = f_start*(t-buffdur_exact) + params.speed*((t-buffdur_exact).^2)/2 + start_2(end); % Cycles
    end_2 = f_end*t(1:(length(t)-buffinst2+1)) + phi2_inst(buffinst2);
    phi2_inst(1:buffinst1) = start_2;
    phi2_inst(buffinst2:end) = end_2;
end

phi1_inst = phi2_inst / params.ratio;
y1 = scaleSound(rampsound(cos(2 * pi * phi1_inst), fs, params.rise_fall_ms/1000));
y2 = scaleSound(rampsound(cos(2 * pi * phi2_inst), fs, params.rise_fall_ms/1000));

end



function [y1, y2, t] = make_discrete_dp(params, fs)
    t = 0: (1/fs): (params.duration_ms/1000 - 1/fs);

    y1 = zeros(numel(params.f2_hz), numel(t)); 
    y2 = zeros(size(y1)); 

    for freq_idx = 1:numel(params.f2_hz)
        % in Phase
        phi2_inst = params.f2_hz(freq_idx)*t;
    
        phi1_inst = phi2_inst / params.ratio;
        y1(freq_idx,:) = scaleSound(rampsound(cos(2 * pi * phi1_inst), fs, params.rise_fall_ms/1000));
        y2(freq_idx,:) = scaleSound(rampsound(cos(2 * pi * phi2_inst), fs, params.rise_fall_ms/1000));
    end
end

function y = scaleSound(x)
    % Scales a matrix appropriately to between +/- 1 for
    % wavwrite() for example.
    
    clipbuffer = 0.95;
    
    y = clipbuffer*x./max(abs(x(:)));
end

function y = rampsound(x,fs,risetime)
    % Function to ramp a sound file using a dpss ramp
    % USAGE:
    % y = rampsound(x,fs,risetime)
    %
    % risetime in seconds, fs in Hz
    % Hari Bharadwaj
    
    Nramp = ceil(fs*risetime*2)+1;
    w = dpss(Nramp,1,1);
    
    w = w - w(1);
    w = w/max(w);
    sz = size(x);
    half = ceil(Nramp/2);
    wbig = [w(1:half); ones(numel(x)- 2*half,1); w((end-half+1):end)];
    
    if(sz(1)== numel(x))
        y = x.*wbig;
    else
        y = x.*wbig';
    end

end