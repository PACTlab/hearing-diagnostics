function root_dir = config_repo_root()
% CONFIG_REPO_ROOT  Absolute path to the repository root.
%
% Single source of truth for "where is the repo". config/ sits one level
% below the root, so the root is the parent of this file's folder.
%
% Every relative path stored in system_config.mat is resolved against this.
% Do not use pwd for path resolution anywhere in this codebase — the
% operator's working directory is not something we control.

root_dir = fileparts(fileparts(mfilename('fullpath')));

end