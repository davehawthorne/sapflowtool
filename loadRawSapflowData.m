%%
% doy and tod (day of year + time of day) might be dumped 
function [year, par, vpd, sapflow, doy, tod] = loadRawSapflowData(filename, yearSelectionCallback)
 
    raw = load(filename);
    
    yearsRepresented = unique(raw(:,2));
    
    if length(yearsRepresented) == 1
        year = yearsRepresented;
    else
        year = yearSelectionCallback(yearsRepresented);
        
        % filter out data not in this year
        raw = raw(raw(:, 2) == year, :);
    end

    
    [~, numCols] = size(raw);

    dayOfYear = raw(:, 3);
    % Time is encoded as a decimal integer of value HMM.  So 4:15 would 
    % yield the value 415
    encodedTime = raw(:, 4);  
%     hour = floor(encodedTime ./ 100);
%     minute = mod(encodedTime, 100);
% 
%     % This might be a wee bit dodgy, I couldn't find documentation for
%     % this.  I'm forcing datetime to use day-of-month data by holding the
%     % month value to one.  Seems to work, including with leap years, but
%     % the 'feature' might be depricated in future.
%     sampleTime = datetime(year, 1, dayOfYear, hour, minute, 0);
    vpd = raw(:,5);
    par = raw(:,6);
    sapflow = raw(:,7:numCols);
    
    doy = dayOfYear;  %%TEMP!!!
    tod = encodedTime; %%TEMP!!!
    
    sapflow(sapflow >= 6999) = nan;  %TEMP!!! 

end

