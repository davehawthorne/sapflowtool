function a = cutShortRuns(a, minRunLength)
    % Code largely taken from:
    % http://stackoverflow.com/questions/23877056/how-can-i-get-a-non-continuous-data-in-a-nan-array-organized-in-a-cell-array
    endIndex = find(diff([isnan(a), 1]) == 1);
    startIndex = find(diff([1, isnan(a)]) == -1);
    lengths = endIndex - startIndex + 1;

    for i = 1:length(startIndex)
        if lengths(i) < minRunLength
            a(startIndex(i):endIndex(i)) = NaN;
        end
    end

end
