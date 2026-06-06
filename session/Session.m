classdef Session < handle

    properties
        SubjectID
        Species
        Operator
        Date
        RunCount
        SaveDir
        Config
        TransducerCal   % Reference of Transducers
        FPLCal          % FPL Probe filter
        EarCal      % Ear filter
        Notes       % placeholder for timepoint 
        Group
    end

    methods
        function obj = Session(subjectID, species, operator)
            obj.SubjectID = subjectID;
            obj.Species = species;
            obj.Operator = operator;
            obj.Date = datestr(now, 'yyyy-mm-dd');
            obj.RunCount = 0;
            obj.Config = obj.loadConfig();
            obj.EarCal = [];
            obj.TransducerCal = obj.loadTransducerCal();
            obj.SaveDir  = obj.initSaveDir();
            obj.Notes = ''; 
            obj.Group = ''; 
            fprintf('Session started: %s | %s \n ', subjectID, species);
        end

        function loadEarCal(obj, ear_cal_result_path)
            % LOADEARCAL  Load ear calibration filter into session after ear_cal_run.
            %
            % Called automatically at end of ear_cal_run(), or manually to load
            % a cal from a previous run.

            if ~exist(ear_cal_result_path, 'file')
                error('Session:earCalNotFound', ...
                    'Ear cal file not found: %s', ear_cal_result_path);
            end

            loaded = load(ear_cal_result_path);
            if ~isfield(loaded, 'run') || ~isfield(loaded.run, 'result')
                error('Session:badEarCalFile', ...
                    'Ear cal file does not have expected run.result structure.');
            end

            obj.EarCal             = loaded.run.result;
            obj.EarCal.source_file = ear_cal_result_path;
            obj.EarCal.timestamp   = datetime("now");

            fprintf('Ear cal loaded: %s\n', ear_cal_result_path);
        end

        function filepath = saveRun(obj, params, data)
            % Increment file counter
            obj.RunCount = obj.RunCount + 1;

            run.info.schema_version = 1;
            run.info.subject_id = obj.SubjectID;
            run.info.species = obj.Species;
            run.info.ear = params.ear;
            run.info.operator = obj.Operator;
            run.info.date = obj.Date;
            run.info.run_number = obj.RunCount;
            run.info.measure_type = params.measure_type;
            run.info.software_version = obj.Config.software_version;
            run.info.hardware = obj.Config.hardware;
            run.info.notes = obj.Notes;
            run.info.group = obj.Group; 

            run.info.transducer_cal = obj.Config.calibration.active_transducer_file;
            run.info.ear_cal = obj.getEarCalInfo();

            run.params = params;
            run.data = data;
            run.result = struct();

            % Build filename and full path
            filename = obj.buildFilename(params.measure_type, params.ear);
            filepath = fullfile(obj.SaveDir, filename);
            
            % Save the result
            save(filepath, 'run', '-v7.3');
            fprintf('Saved run %03d: %s\n', obj.RunCount, filename)
        end
    end

    methods (Access = private)
        function d = initSaveDir(obj)
            d = fullfile(obj.Config.data.root_dir, obj.SubjectID, obj.Date);
            if ~exist(d, 'dir')
                mkdir(d);
            end
        end

        function cfg = loadConfig(obj)
            config_path = fullfile(fileparts(mfilename('fullpath')), ...
                '..', 'config', 'system_config.mat');
            config_path = char(java.io.File(config_path).getCanonicalPath());
            % rest of function unchanged


            if ~exist(config_path, 'file')
                error('Session:missingConfig', ...
                    'Config file not found at: %s', config_path);
            end

            loaded = load(config_path);
            if ~isfield(loaded, 'config')
                error('Session:invalidConfig', ...
                    'Config file must contain a struct named ''config''.');
            end
            cfg = loaded.config;

            % Validate required fields
            required = {'hardware', 'calibration', 'data', 'software_version'};
            for i = 1:length(required)
                if ~isfield(cfg, required{i})
                    error('Session:invalidConfig', ...
                        'Config missing required field: %s', required{i});
                end
            end

            if ~isfield(cfg.data, 'root_dir')
                error('Session:invalidConfig', ...
                    'Config missing required field: data.root_dir');
            end
        end

        function fname = buildFilename(obj, measureType, ear)
            fname = sprintf('%s_%s_%s_%s_%03d.mat', ...
                obj.SubjectID, obj.Date, upper(measureType), upper(ear(1)), obj.RunCount);
        end

        function cal = loadTransducerCal(obj)
            calFile = obj.Config.calibration.active_transducer_file;

            if isempty(calFile)
                warning('Session:noTransducerCal', ...
                    ['No transducer cal file set in system_config. ' ...
                    'Set config.calibration.active_transducer_file.']);
                cal = [];
                return
            end

            % Resolve relative paths from project root
            if ~java.io.File(calFile).isAbsolute()
                calFile = fullfile(fileparts(fileparts(mfilename('fullpath'))), calFile);
            end

            cal = cal_load_transducer(calFile);
        end

        function info = getEarCalInfo(obj)
            if isempty(obj.EarCal)
                info = 'none';
            else
                info = obj.EarCal.source_file;
            end
        end
        
    end
end