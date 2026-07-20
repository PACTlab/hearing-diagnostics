function [stim_out] = memr_make_stimulus(params)
% DPOAE_MAKE_STIMULUS  Generate DPOAE stimulus waveform(s).

%% --- Input checks ---
% TODO: Code to verify params

%% --- Build the base stimuli ---

switch lower(params.stim_type)

    case 'discrete'
        [stim_click, stim_noise] = make_discrete_memr(params);

    case 'swept'
        [stim_click, stim_noise] = make_swept_memr(params);

    otherwise
        error('memr_make_stimulus:unknownType', ...
            'Unknown stim_type: %s. Use swept or discrete.', ...
            params.stim_type);
end

%% --- Package output ---

stim_out.ch1         = base_stim1;
stim_out.ch2         = base_stim2;
stim_out.t           = t; 
stim_out.fs          = fs;
stim_out.n_stim      = n_stim;

end


%% =========================================================
%  LOCAL FUNCTIONS
%% =========================================================

function [stim_click, stim_noise, stim_info] = make_swept_memr(params)
    fs = params.fs; 
    %% Generate a single click
    nSamples = ceil(params.click_win_dur_ms * 1e-3  * fs); % total number of samples in a click window
    
    if mod(nSamples,2) ~= 0 % make total number of samples even
        nSamples = nSamples + 1;
    end
    
    click = zeros(nSamples,1);
    
    startSample = floor(nSamples/3); % silence before the click onset (samps)
    click(startSample:startSample + (params.click_samps-1)) = 0.95;
    
    %% Generate noise shape
    noiseSamples = ceil(params.total_duration_s * fs); % total
    total_nSamples = params.pad_samps + nSamples + ceil(params.elic_duration_ms .* fs .* 1e-3) ; % samples per one burst (pad + click + noiseburst )
    
    noiseSamples = round(noiseSamples/total_nSamples) .* total_nSamples; % make this a multiple of total samples
    
    h = linspace(0,params.level_range_db,noiseSamples)';
    h(1) = eps;
    h = [h;flipud(h)];
    h = 10.^(h/20); % noise amplitude in linear units
    h = h / max(abs(h)) * 0.95; % rescale to unit amplitude
    
    %% Make the click train
    longclick = zeros(total_nSamples, 1); % give extra space for the noise burst and pad
    longclick(params.pad_samps + (1:numel(click)), 1) = click;
    
    clicksPerTrain = (noiseSamples*2) / total_nSamples; % figure out the number of clicks needed total
    clickTrain = repmat(longclick,1,clicksPerTrain); % concatenate all of them together with correct spacing
    clickTrain = clickTrain(:); % make it a row vector
       
    %% Generate noise
    rows = size(h,1); % length of noise in samples
    cols = params.trials; % total number of trials
    
    noise = zeros(rows,cols);
    for m = 1:cols
        noise_temp = makeNBNoiseFFT(params.elic_bandwidth_hz, params.elic_fc, rows/fs, fs);
        noise(:, m) = noise_temp(1:rows,1); % just make sure it's the same length because makeNBN takes a time input in seconds so could be rounding issues
    end
    
    Noise = noise .* h; % multiply your noise vector by the shaping
    
    %% Take out chunks for the click
    clickIndex = params.pad_samps+(1:numel(longclick):rows); % find location of click windows
    
    Mask = ones(size(Noise));
    
    for ii= clickIndex
        Mask(ii-params.pad_samps:ii+numel(click),:) = 0;
    end
    
    Noise_masked = Noise .* Mask;
    baseline_clicktrain = repmat(longclick, params.n_baseline_clicks,1); % Add a bunch of baseline clicks at the beginning of the stimulus
    
    %% Get the final versions of the stimuli with baseline added.
    C = [baseline_clicktrain; clickTrain];
    
    N = zeros(numel(C), cols);
    N(numel(baseline_clicktrain)+(1:rows), :) = Noise_masked;
    
    % Save final forms of noise and click stimuli
    stim_click = C;
    stim_noise = N;

    % Get a useful time vector 
    t = 0:(1/fs):(rows+numel(baseline_clicktrain)-1)/fs; 
    stim_info.t = t; 
    
    % Save extra relevant info for analysis
    stim_info.stim_click = stim_click; 
    stim_info.stim_noise = stim_noise; 
    stim_info.h = h;
    stim_info.singleClick = longclick;
    stim_info.clicksPerTrain = clicksPerTrain;
    stim_info.clickIndexes = clickIndex; % save where the click windows start
end

function [stim_click, stim_noise, stim_info] = make_discrete_memr(params)
    fs = params.fs; 
    stim_click = []; 
    stim_noise = []; 
    stim_info = []; 
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

function noise = makeNBNoiseFFT(bw,fc,tmax,fs)
% EDITED FOR SWEPT NOISE, NO RAMPING!
% USAGE:
%    noise = makeNBNoiseFFT(bw,fc,tmax,fs,rampSize,playplot);
%  e.g.:
%    noise = makeNBNoiseFFT(50,1000,0.6,48828.125,0.025,1);
% Makes notched noise with different bandwidths. RMS is 0.1 always.
%  bw - Bandwidth of noise in Hz (two-side)
%  tmax - Duration of noise in seconds
%  fs - Sampling rate
%  fc - center frequency in Hz
%-----------------------------------------------------
%% Settings

fmin = fc - bw/2;
fmax = fc + bw/2;

%-----------------------------------------------------
t = 0:(1/fs):(tmax);

%% Making Noise
fstep = 1/tmax; %Frequency bin size

hmin = ceil(fmin/fstep);
hmax = floor(fmax/fstep);

phase = rand(hmax-hmin+1,1)*2*pi;

noiseF = zeros(numel(t),1);
noiseF(hmin:hmax) = exp(1j*phase);
noiseF((end-hmax+1):(end-hmin+1)) = exp(-1*1j*phase);

noise = ifft(noiseF,'symmetric');
noiserms = rms(noise);
noise = (noise/noiserms) * 0.1;

end

