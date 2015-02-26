function [yearNum, par, vpd, sapflow, doy, tod] = loadRawSapflowData(filename)
    % Reads sapflow and other data from the specified file
    %TEMP!!! currently what data is in which column is hardcoded
    %TEMP!!!  doy and tod (day of year + time of day) might be dumped
    %TEMP!!! there's no error handling for missing files, bad data etc.
    raw = load(filename);

    [~, numCols] = size(raw);

    yearNum = raw(:, 2);
    dayOfYear = raw(:, 3);
    % Time is encoded as a decimal integer of value HMM.  So 4:15 would
    % yield the value 415
    encodedTime = raw(:, 4);
    hour = floor(encodedTime ./ 100);
    minute = mod(encodedTime, 100);

    % This might be a wee bit dodgy, I couldn't find documentation for
    % this.  I'm forcing datetime to use day-of-month data by holding the
    % month value to one.  Seems to work, including with leap years, but
    % the 'feature' might be deprecated in future.
    sampleTime = datetime(yearNum, 1, dayOfYear, hour, minute, 0);

    % Check that the time step is uniform.
    timeSteps = sampleTime(2:end) - sampleTime(1:end-1);       %TEMP!!! just use MATLAB's diff()

    interval = unique(timeSteps);
    if length(interval) ~= 1
        % There's more than one amount that neighbouring times change by...
        intervalList = sprintf('%d ', minutes(interval));
        throw(MException('sapflowData:fileError','Inconsistent sample intervals (%s minutes)', intervalList))
    end
    vpd = raw(:,5);
    par = raw(:,6);
    sapflow = raw(:,7:numCols);

    doy = dayOfYear;  %%TEMP!!!
    tod = encodedTime; %%TEMP!!!

    sapflow(sapflow >= 6999) = nan;  %TEMP!!!

end

