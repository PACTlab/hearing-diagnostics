function hist = probecal_history(cfg, current, opts)
% PROBECAL_HISTORY  Past passing calibrations for overlays and norm bands.
%
% Only calibrations that passed, match the current equipment and signal
% path, and share the same frequency axis are included, so every overlay is
% a fair comparison. Age is not a criterion here.
%
% Inputs:
%   cfg     - struct from config_load
%   current - struct from probecal_current_conditions. Add .buffer_size to
%             require the same frequency axis (recommended for the GUI).
%   opts    - optional struct:
%               .n_max       most recent N to include (default 20)
%               .exclude     path to leave out, e.g. the cal just saved
%               .allow_stub  include passing stub cals (testing only)
%
% Output hist:
%   .n        number of calibrations included
%   .files    {1 x n} paths, newest first
%   .cals     {1 x n} loaded 'cal' structs, newest first
%   .last     hist.cals{1}, or [] if none
%   .norm     (when n >= 1) per-frequency bands in dB:
%               .freq
%               .pcav_db_median/_min/_max  [nf x ncav x ndrv]  20log10|H|, Pa/V
%               .Ps_db_median/_min/_max    [nf x ndrv]         20log10|Ps|, Pa/V
%               .Zs_db_median/_min/_max    [nf x ndrv]         20log10|Zs|
%
% For dB SPL in plots, subtract 20*log10(20e-6) from the Pa/V values.

if nargin < 3
    opts = struct();
end
n_max      = getOpt(opts, 'n_max', 20);
exclude    = getOpt(opts, 'exclude', '');
allow_stub = getOpt(opts, 'allow_stub', false);

entries = probecal_list_cals(cfg, allow_stub);

hist.n     = 0;
hist.files = {};
hist.cals  = {};
hist.last  = [];

ref_freq = [];
ref_size = [];

for k = 1:numel(entries)
    if hist.n >= n_max
        break
    end
    s = entries(k).summary;
    if ~s.ok || (s.stub && ~allow_stub) || strcmp(entries(k).path, exclude)
        continue
    end
    if ~isempty(probecal_compatible(s, cfg, current))
        continue
    end

    S = load(entries(k).path, 'cal');
    f = S.cal.fit;

    % Everything stacked below must line up bin for bin and cavity for cavity.
    if isempty(ref_freq)
        ref_freq = f.freq;
        ref_size = size(f.pcav);
    elseif ~isequal(f.freq, ref_freq) || ~isequal(size(f.pcav), ref_size)
        continue
    end

    hist.n = hist.n + 1;
    hist.files{end+1} = entries(k).path;
    hist.cals{end+1}  = S.cal;
end

if hist.n == 0
    return
end
hist.last = hist.cals{1};

%% --- Norm bands ---

P  = cellfun(@(c) magDb(c.fit.pcav), hist.cals, 'UniformOutput', false);
Ps = cellfun(@(c) magDb(c.fit.Ps),   hist.cals, 'UniformOutput', false);
Zs = cellfun(@(c) magDb(c.fit.Zs),   hist.cals, 'UniformOutput', false);
P  = cat(4, P{:});    % [nf x ncav x ndrv x n]
Ps = cat(3, Ps{:});   % [nf x ndrv x n]
Zs = cat(3, Zs{:});

hist.norm.freq           = ref_freq;
hist.norm.pcav_db_median = median(P, 4, 'omitnan');
hist.norm.pcav_db_min    = min(P, [], 4, 'omitnan');
hist.norm.pcav_db_max    = max(P, [], 4, 'omitnan');
hist.norm.Ps_db_median   = median(Ps, 3, 'omitnan');
hist.norm.Ps_db_min      = min(Ps, [], 3, 'omitnan');
hist.norm.Ps_db_max      = max(Ps, [], 3, 'omitnan');
hist.norm.Zs_db_median   = median(Zs, 3, 'omitnan');
hist.norm.Zs_db_min      = min(Zs, [], 3, 'omitnan');
hist.norm.Zs_db_max      = max(Zs, [], 3, 'omitnan');

end

function y = magDb(x)
y = 20*log10(abs(x));
end

function v = getOpt(opts, name, default)
if isfield(opts, name) && ~isempty(opts.(name))
    v = opts.(name);
else
    v = default;
end
end