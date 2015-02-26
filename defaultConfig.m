function config = defaultConfig()
    % This function returns the default values for the project configuration.
    % These can be overridden by a call to projectDialog() or by editing the
    % XML project file.
    config.sourceFilename = '';
    config.projectName = '';
    config.projectDesc = '';
    config.minRawValue = 0.5;
    config.maxRawValue = 30;
    config.maxRawStep = 1.5;
    config.minRunLength = 4;
    config.parThresh = 100.0;
    config.vpdThresh = 0.05;
    config.vpdTime = 2.0;

end
