function config = projectDialog(origConfig)

    function fail(format, varargin)
        throw(MException('pd:err', format, varargin{:}));
    end

    function val = getFloat(index, minVal, maxVal)
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
        val = getFloat(index, minVal, maxVal);
        if round(val) ~= val
            fail('%s should be an integer', prompt{index});
        end
    end

    function val = getFilename(index)
        val = values{index};
        if exist(values{index}, 'file') ~= 2
            fail('%s is not a valid file', val);
        end
    end


    prompt = { ...
        'Source data filename:', ...
        'Project name:', ...
        'Project description:', ...
        'Maximum valid sapflow value:', ...
        'Minimum valid sapflow value:', ...
        'Maximum change per interval:', ...
        'Minimum size of valid island:', ...
    };
    dlgTitle = 'Project Configuration';
    values = { ...
        origConfig.sourceFilename, ...
        origConfig.projectName, ...
        origConfig.projectDesc, ...
        num2str(origConfig.minRawValue), ...
        num2str(origConfig.maxRawValue), ...
        num2str(origConfig.maxRawStep), ...
        num2str(origConfig.minRunLength) ...
    };
    numLines = ones(7,1) * [1,100];
    while true
        values = inputdlg(prompt, dlgTitle, numLines, values);
        if isempty(values)
            config = 0;
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
            return
        catch err
            if strcmp(err.identifier, 'pd:err')
                uiwait(errordlg(err.message, 'Bad Value', 'modal'));
                continue;
            else
                rethrow(err)
            end
        end
    end


end
