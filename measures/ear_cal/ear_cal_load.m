function [cal_ch1, cal_ch2] = ear_cal_load(save_dir)

files = dir(fullfile(save_dir, '*ch1*'));
if isempty(files)
    cal_ch1 = [];
    return
else
    [~, idx] = max([files.datenum]);
    fpath = fullfile(files(idx).folder, files(idx).name);
    cal_ch1 = load(fpath);
end

files = dir(fullfile(save_dir, '*ch2*'));
if isempty(files)
    cal_ch2 = [];
    return
else
    [~, idx] = max([files.datenum]);
    fpath = fullfile(files(idx).folder, files(idx).name);
    cal_ch2 = load(fpath);
end 

end