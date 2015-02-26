function values = cutShortRuns(values, minRunLength)
    % values may contain missing or bad data represented by NaNs.  These
    % delineate islands of good data.  If any such island contains less than
    % minRunLength values then invalidate those values by setting them all to
    % NaN.
    %
    % Code largely taken from:
    % http://stackoverflow.com/questions/23877056/how-can-i-get-a-non-continuous-data-in-a-nan-array-organized-in-a-cell-array
    endIndex = find(diff([isnan(values), 1]) == 1);
    startIndex = find(diff([1, isnan(values)]) == -1);
    lengths = endIndex - startIndex + 1;

    for i = 1:length(startIndex)
        if lengths(i) < minRunLength
            values(startIndex(i):endIndex(i)) = NaN;
        end
    end

end
