function [entries, unreadable] = probecal_list_cals(cfg, include_stub)
% PROBECAL_LIST_CALS  Saved FPL calibrations, newest first.
%
% Loads only the small 'summary' variable from each file, so scanning a
% folder with months of calibrations stays fast.
%
% Inputs:
%   cfg          - struct from config_load
%   include_stub - also list the 'stub' subfolder (default false)
%
% Outputs:
%   entries    - struct array with .path and .summary, newest fit first
%   unreadable - cellstr of files that could not be read as calibrations

if nargin < 2
    include_stub = false;
end

dirs = {cfg.calibration.fpl_data_dir};
if include_stub
    dirs{end+1} = fullfile(cfg.calibration.fpl_data_dir, 'stub');
end

entries    = struct('path', {}, 'summary', {});
unreadable = {};

for i = 1:numel(dirs)
    if ~exist(dirs{i}, 'dir')
        continue
    end
    files = dir(fullfile(dirs{i}, 'FPLcal_*.mat'));
    for k = 1:numel(files)
        p = fullfile(files(k).folder, files(k).name);
        try
            S = load(p, 'summary');
            if ~isfield(S, 'summary')
                error('no summary');
            end
            entries(end+1) = struct('path', p, 'summary', S.summary); %#ok<AGROW>
        catch
            unreadable{end+1} = p; %#ok<AGROW>
        end
    end
end

if ~isempty(entries)
    t = NaT(1, numel(entries));
    for k = 1:numel(entries)
        t(k) = entries(k).summary.fitted_at;
    end
    [~, order] = sort(t, 'descend');
    entries = entries(order);
end

end