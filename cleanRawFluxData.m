% process_dt_clean.m
% Sap flux raw data cleaner
function sf = cleanRawFluxData(sf)


    %TEMP!!!sf0=sf;

    sf(sf<0.5)=nan;
    sf(sf>30)=nan;
    sf(sf<=0)=nan;

    [sfrows,sfcols]=size(sf);

    % Deletes points where temperature jumps more than 1 degree
    for c=1:sfcols
        for r=2:sfrows
            dx=sf(r-1,c)-sf(r,c);
            if abs(dx)>1.5
                sf(r,c)=nan;
            end
        end
    end

    % pointfill: interpolates if a single point is missing
    for c=1:sfcols
        for r=2:sfrows-1
            dx=sf(r-1:r+1,c);
            if dx(1)>0 && dx(3)>0 && isnan(dx(2))
                sf(r,c)=mean([dx(1) dx(3)]);
            end
        end
    end

    % point delete: deletes single point surrounded by missing values
    for c=1:sfcols
        for r=2:sfrows-1
            dx=sf(r-1:r+1,c);
            if dx(2)>0 && isnan(dx(3)) && isnan(dx(1))
                sf(r,c)=nan;
            end
        end
    end

end

