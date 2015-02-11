function [iStart, iEnd] = getRanges(a)
    a = reshape(a, [1,length(a)]);
    e = a - [a(1), a(1:(end-1))];
    iStart = find(e == 1);
    iEnd = find(e == -1) - 1;
    if a(1)
        iStart = [1, iStart];
    end
    if a(end)
        iEnd = [iEnd, length(a)];
    end
end
