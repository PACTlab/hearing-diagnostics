function [save_dir, metadata] = session_dummy()
% SESSION_DUMMY  Create a dummy session for testing or running without
% full session setup.
%
% Useful for:
%   - Testing measure GUIs without entering subject info
%   - Sharing code with other labs who don't use this session structure
%   - Quick stimulus checks without creating real data folders
%
% Data is saved to a temp folder and will not persist between MATLAB sessions.

metadata.subject_id    = 'TEST';
metadata.species       = 'Unknown';
metadata.operator      = 'TEST';
metadata.project       = 'lab_default'; 
metadata.date          = datestr(now, 'yyyy-mm-dd');
metadata.sex           = 'Unknown';
metadata.group         = 'TEST';
metadata.exposure_date = '';
metadata.animal_status = 'Unknown';
metadata.location      = '';
metadata.notes         = 'Dummy session — data not saved permanently';
metadata.software_ver  = '';
metadata.total_runs    = 0;
metadata.created       = datestr(now, 'yyyy-mm-dd HH:MM:SS');
metadata.last_modified = datestr(now, 'yyyy-mm-dd HH:MM:SS');

% Write to a clearly named temp folder
save_dir = fullfile(tempdir, 'HearingLab_DUMMY', ...
    sprintf('TEST_%s_TEST_Unknown', datestr(now, 'yyyy-mm-dd')));

if ~exist(save_dir, 'dir')
    mkdir(save_dir);
end

% Write metadata so session functions work normally
metadata_path = fullfile(save_dir, 'session_metadata.mat');
save(metadata_path, 'metadata');

fprintf('Dummy session started. Data will be saved to: %s\n', save_dir);
fprintf('WARNING: This folder is in tempdir and may be deleted by the OS.\n');

end