function metadata = probecal_run(params, save_dir, tdt)
% Run FPL Probe Calibration 
% Does not require animal subject. Should be run once per day. 
% 
% Inputs
%   save_dir    - full path to folder where data should be saved
%   tdt         - TDT hardware struct from tdt_init, or [] for stub mode


%% --- make click stim --- 
nsampsclick = 1; %WBMEMRipsi uses 5 sample clicks
initbuff =  2;
y = zeros(1, params.BufferSize);
y(initbuff + (1:nsampsclick)) = 0.95;
params.y = y(:); % Just in case

%% --- run the loop --- 

Fs = params.SamplingRate * 1000; % to Hz

vo = params.y;
params.vo = vo;

calib.vavg = zeros(numel(params.drivers), params.CavNumb, params.BufferSize);
calib.Vavg = zeros(numel(params.drivers), params.CavNumb, params.BufferSize);


for m = 1:params.CavNumb % Loop across each cavity (1:5)

    for driver = params.drivers % Loop across the two drivers (1:2)
        fprintf('Playing for cavity %d, driver %d \n', m, driver)

        buffdata = zeros(2, numel(vo));
        buffdata(driver, :) = vo; % The other source plays nothing

        drop = [120, 120];
        drop(driver) = params.Attenuation;

        % set the variables for tdt
        stim_ch1 = buffdata(1,:); 
        stim_ch2 = buffdata(2,:); 

        att_ch1 = drop(1,1); 
        att_ch2 = drop(1,2); 
        Nreps = params.Averages + params.ThrowAway; 
        throwAway = params.ThrowAway; 
        delayComp = 1; 
        
        vins = tdt_play_record(tdt, stim_ch1, stim_ch2, ...
                    att_ch1, att_ch2, Nreps, throwAway, delayComp);

        %compute the average
        if params.doFilt
            % High pass at 100 Hz using IIR filter
            [b, a] = butter(4, 100 * 2 * 1e-3/params.SamplingRate, 'high');
            vins = filtfilt(b, a, vins')';
        end

        vins = demean(vins, 2);
        energy = sum(vins.^2, 2);
        good = energy < median(energy) + 2*mad(energy);
        vavg = mean(vins(good, :), 2);
        calib.vavg(driver, m, :) = vavg;
        calib.Vavg(driver, m, :) = rfft(vavg);
    end
    
    % convert to SPL and plot 

    if m+1 <= params.CavNumb  % Tell user to make sure calibrator is set correctly
        fprintf('Move to next tube! \n');
        uiwait(warndlg('MOVE TO THE NEXT SMALLEST TUBE','SET TUBE WARNING','modal'));
    end
    
    
end

%% Get values
 % Apply calibartions to convert voltage to pressure
        % For ER-10X, this is approximate
        mic_sens = 50e-3; % mV/Pa. TO DO: change after calibration
        mic_gain = db2mag(gain); % +6 for balanced cable
        P_ref = 20e-6;
        DR_onesided = 1;
        mic_output_V_1 = Vavg_1 / (DR_onesided * mic_gain);
        output_Pa_1 = mic_output_V_1/mic_sens;
        outut_Pa_20uPa_per_Vpp_1 = output_Pa_1 / P_ref; % unit: 20 uPa / Vpeak

        freq = 1000*linspace(0,params.SamplingRate/2,length(Vavg_1))';
        params.freq = freq; %Hz

        % CARD MAT2VOLTS = 5.0
        Vo = rfft(params.vo)*5*db2mag(-1 * params.Attenuation);
        params.CavRespH_1(:,m) =  outut_Pa_20uPa_per_Vpp_1 ./ Vo; %save for later
