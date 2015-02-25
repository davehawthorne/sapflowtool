%%
% doy and tod (day of year + time of day) might be dumped
function [yearNum, par, vpd, sapflow, doy, tod] = loadRawSapflowData(filename)

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

    timeSteps = sampleTime(2:end) - sampleTime(1:end-1);
    interval = unique(timeSteps);
    if length(interval) ~= 1
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

