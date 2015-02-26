function config = projectDialog(origConfig)
    % Presents a rudimentary dialog to set project configuration parameters.
    % This uses the fairly limited inputdlg() facility.  This forces us to
    % select filenames beforehand with a separate call to getfile().
    %
    % The user's input is checked when they press "okay" and if there's an issue
    % the an error dialog is displayed any they may then correct the problem.
    %
    % If successful the updated config is returned; if the user cancels then 0
    % is returned.


    function fail(format, varargin)
        % Convenience function that wrappers the exception throwing code.
        % This is called if any user entry is not valid.  It is caught in the
        % projectDialog() body.
        throw(MException('pd:err', format, varargin{:}));
    end


    function val = getFloat(index, minVal, maxVal)
        % Attempts to read a float from entry field number 'index'.  The value
        % must fall in the specified range.
        val = str2double(values{index});
        if isnan(val)
            fail('%s should be a single float', prompt{index});
        end
        if val < minVal
            fail('%s should be greater than %f', prompt{index}, minVal);
        end
        if val > maxVal
            fail('%s should be less than %f', prompt{index}, maxVal);
        end
    end


    function val = getInt(index, minVal, maxVal)
        % Attempts to read an int from entry field number 'index'.  The value
        % must fall in the specified range.
        val = getFloat(index, minVal, maxVal);
        if round(val) ~= val
            fail('%s should be an integer', prompt{index});
        end
    end


    function val = getFilename(index)
        % Check that field index holds a valid filename.  If so return it.
        val = values{index};
        if exist(values{index}, 'file') ~= 2
            fail('%s is not a valid file', val);
        end
    end


    dlgTitle = 'Project Configuration';
    prompt = { ...
        'Source data filename:', ...
        'Project name:', ...
        'Project description:', ...
        'Maximum valid sapflow value:', ...
        'Minimum valid sapflow value:', ...
        'Maximum change per interval:', ...
        'Minimum size of valid sapflow sequence: intervals', ...
        'PAR threshold: values below this are considered nighttime', ...
        'VPD threshold: values below this are considered zero', ...
        'VPD time: length in hours of time segment of low-VPD conditions', ...
    };

    % set default values
    values = { ...
        origConfig.sourceFilename, ...
        origConfig.projectName, ...
        origConfig.projectDesc, ...
        num2str(origConfig.minRawValue), ...
        num2str(origConfig.maxRawValue), ...
        num2str(origConfig.maxRawStep), ...
        num2str(origConfig.minRunLength), ...
        num2str(origConfig.parThresh), ...
        num2str(origConfig.vpdThresh), ...
        num2str(origConfig.vpdTime), ...
    };
    % Set all fields to 100 characters wide.
    fieldSize = ones(length(values),1) * [1,100];

    % We return from inside this loop.
    while true
        values = inputdlg(prompt, dlgTitle, fieldSize, values);
        if isempty(values)
            config = 0;  % Communicate that the user has aborted entry.
            return
        end
        try
            config.sourceFilename = getFilename(1);
            config.projectName = values{2};
            config.projectDesc = values{3};
            config.minRawValue = getFloat(4, 0, 100);
            config.maxRawValue = getFloat(5, config.minRawValue, 100);
            config.maxRawStep = getFloat(6, 0, 100);
            config.minRunLength = getInt(7, 0, 100);
            config.parThresh = getFloat(8, 0, 100);
            config.vpdThresh = getFloat(9, 0, 100);
            config.vpdTime = getFloat(10, 0, 100);

            % If we've got this far then everything is okay and we can return
            % with a valid config.
            return
        catch err
            % There's been an exception; if it's one of ours then the user has
            % entered bad data.  Alert them to this and repeat.
            if strcmp(err.identifier, 'pd:err')
                uiwait(errordlg(err.message, 'Bad Value', 'modal'));
                continue;  % Repeat the process using the last set of values.
            else
                % It's not our bad entry exception - best let it be handled up
                % the food chain.
                rethrow(err)
            end
        end
    end


end
