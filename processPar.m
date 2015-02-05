% Process PAR data: simple
function PAR = processPar(PAR, Time)
    % Process PAR data: simple

    % Fixes nighttime zero-PAR sensor drift
    PAR(PAR<10)=0;

    % Simple nighttime characterization
    % Sets default start and end of daylight hours if PAR data are missing
    AMthresh=700; % Sets default time for beginning of daytime
    PMthresh=2000; % Sets default time for end of daytime

    ii=find(isnan(PAR) & Time<AMthresh);
    PAR(ii)=0;
    ii=find(isnan(PAR) & Time>PMthresh);
    PAR(ii)=0;
    ii=find(isnan(PAR) & Time>=AMthresh & Time<=PMthresh);
    PAR(ii)=1000;
end


