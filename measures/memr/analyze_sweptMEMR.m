%% Analysis // Adapted from S. Goodman
clear all

[FileName,PathName,FilterIndex] = uigetfile(strcat('./Results/sweptMEMR_*.mat'),...
    'Please pick MEM data file to analyze');
MEMfile = fullfile(PathName, FileName);
load(MEMfile);

%%
stim = data.stim;

fs = stim.fs;

elicitor = stim.N(:,1);
Clicks = stim.C(:,1);

noiseLvl = zeros(size(elicitor)); 
noiseLvl(numel(elicitor)-numel(stim.h)+1:end,1) = 20*log10(stim.h./.00002) - stim.noiseatt + 6;

% get the stimulus levels ---------------------------------------------
[rows,~] = size(elicitor);
chunkSize = numel(stim.singleClick);
totalClicks = stim.clicksPerTrain + stim.n_baseline_clicks; 

noiseLvl = noiseLvl(1:chunkSize*totalClicks);
Clicks = Clicks(1:chunkSize*totalClicks);
time = stim.t(1,1:chunkSize*totalClicks);

E = reshape(noiseLvl,chunkSize,totalClicks); % elicitor in matrix
C = reshape(Clicks(:,1),chunkSize,totalClicks); % clicks in matrix
T = reshape(time,chunkSize,totalClicks); % time in matrix

for ii=1:totalClicks % loop over columns (clicks in the sweep)
    RMS(ii,1) = sqrt(mean(E(:,ii).^2)); % elicitor RMS
    RMSC(ii,1) = sqrt(mean(C(:,ii).^2)); % rms of the click
    RMST(ii,1) = mean(T(:,ii)); % mean time of each chunk
end


%% Trying SH's simple way
% Average all responses
delay = 97;
freq = linspace(200, 8000, 1024);
MEMband = [500, 2000];
ind = (freq >= MEMband(1)) & (freq <= MEMband(2));

% Chunk the response into windows of each click
resp = data.resp.AllBuffs(:,1:chunkSize*totalClicks);

R = zeros(stim.Averages, totalClicks, chunkSize); % create a 3-D vector with trials x chunk number x time
for jj = 1:stim.Averages
    trial_resp = resp(jj,:);
    R(jj, :,:) = reshape(trial_resp, chunkSize,totalClicks)'; % elicitor in matrix
end

nSamples = ceil(stim.clickWin * 1e-3  * fs) +1; % total number of samples in just the click that we want to look at 
R = R(:,:,stim.pad+(1:nSamples)); % Get rid of the noise part, just have click; 

sampsToAnalyze = 700+(1:1024); 

% Get baseline response from baseline clicks
temp_baseline = trimmean(R(:, 1:stim.n_baseline_clicks+1, sampsToAnalyze),20, 'floor', 1);
temp_baseline = mean(squeeze(temp_baseline), 1); 
temp_baseline = detrend(temp_baseline); 
tempf_baseline = pmtm(temp_baseline, 4, freq, fs);
baseline_freq = tempf_baseline'; %median(tempf_baseline, 2);

for i = stim.n_baseline_clicks+1+1:size(R, 2) % loop through each level skipping the first baseline clicks
    temp = trimmean(R(:,i, sampsToAnalyze), 20, 'floor', 1);
    temp = squeeze(temp);
    temp = detrend(temp);

    tempf = pmtm(temp, 4, freq, fs);
    temp_freq(:,i-(stim.n_baseline_clicks+1)) = tempf; %median(tempf,2);
end

MEM = pow2db(temp_freq ./ baseline_freq);

nfilt = 65;
for k = 1:totalClicks-stim.n_baseline_clicks-1 % now look at clicks other than baseline clicks
    MEMs(:,k) = sgolayfilt(MEM(:,k), 2, nfilt);
    levels(1,k) = RMS(k+stim.n_baseline_clicks);
    Ts(1,k) = T(1,k+stim.n_baseline_clicks);
end

power = mean(abs(MEMs(ind, :)), 1);
deltapow = power; % - mean(power(1:2));

% Plotting
cols = getDivergentColors((size(MEMs,2)+1)/2);
cols = [cols; flip(cols(1:end-1,:))];
figure;
set(gcf, 'Units', 'Normalized', 'Position', [.1, .1, .7, .6])
subplot(1,2,1)
semilogx(freq / 1e3,MEMs, 'linew', 2);
xlim([0.2, 8]);
ylim([-2, 2])
xticks([0.25, 0.5, 1, 2, 4, 8])
xlabel('Frequency (kHz)')
ylabel('\Delta Ear Canal (dB SPL)')
set(gca,'ColorOrder', cols, 'FontSize', 14)


% Get the average noise level for each click and separate delta power for
% up and down
levels_up = levels(1:ceil(numel(levels)/2)); 
levels_down = levels(floor(numel(levels)/2)+1:end); 

deltapow_up = deltapow(1:ceil(numel(levels)/2)); 
deltapow_down = deltapow(floor(numel(levels)/2)+1:end); 

% Fit the up and down portions of the sweep 
[~, fittedparams] = memfit(levels_up, deltapow_up);
growthfit_up = memgrowth(levels_up, fittedparams);
threshold_up = memgrowthinv(0.1, fittedparams); 

[~, fittedparams] = memfit(levels_down(end:-1:1), deltapow_down(end:-1:1));
growthfit_down = memgrowth(levels_down(end:-1:1), fittedparams);
threshold_down = memgrowthinv(0.1, fittedparams); 


subplot(1,2,2)
hold on;
plot(levels_up, deltapow_up, 'or-', 'linew', 2);
plot(levels_down, deltapow_down, 'ob-', 'linew', 2);
plot(levels_up, growthfit_up, 'r--')
plot(levels_down(end:-1:1), growthfit_down, 'b--')
plot(threshold_up, .1, 'xr', 'MarkerSize', 14, 'LineWidth', 3)
plot(threshold_down, .1, 'xb', 'MarkerSize', 14, 'LineWidth', 3)
xlabel('Elicitor Level (dB SPL)')
ylabel('\Delta Ear Canal (dB SPL)')
set(gca, 'FontSize', 14)
legend('up', 'down')
xlim([30, 90])
ylim([0, 1.5])


threshold_up 
threshold_down