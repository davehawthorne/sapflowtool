% process_dt_clean.m
% Sap flux raw data cleaner
function ss = cleanRawFluxData(ss, config)

    ss(ss < config.minRawValue) = NaN;
    ss(ss > config.maxRawValue) = NaN;

    % Deletes points either side of where temperature jumps too much
    dx = ss([1,1:end-1]) - ss;
    bad = abs(dx) > config.maxRawStep;
    bad = bad | [bad(2:end), 0];
    ss(bad) = NaN;

    % Replaces individual samples of NaN with the average of the samples
    % either side.
    nans = isnan(ss);
    loneNanI = nans & [0, ~nans(1:end-1)] & [~nans(2:end), 0];
    valuesBefore = ss(loneNanI([2:end, end]));
    valuesAfter = ss(loneNanI([1, 1:end-1]));
    ss(loneNanI) = (valuesBefore + valuesAfter) / 2;

    % point delete: deletes single point surrounded by missing values

    ss = cutShortRuns(ss, config.minRunLength);

end

