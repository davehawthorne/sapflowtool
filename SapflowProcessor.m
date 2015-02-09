classdef SapflowProcessor < handle
    % Implements the core sapflow analysis algorithms.
    %
    % Handles baseline estimation and manual adjustment, and sapflow data
    % correction.  Each instance handles a single sensor.

    properties (SetAccess = private, GetAccess = public)
        % The following are loaded from a file and are all the same 1 x N
        % size.

        doy % Day of Year
        tod % Time of Day
        vpd % Vapour Pressure Deficit
        par % Photosynthetically Active Radiation
        ss  % sapflow measurement sequence

        ssL % length of sapflow data

        % These are generated from the sapflow values:

        %TEMP!!! these are all N x 1 arrays.  Change to 1 x N to be
        %consistent
        spbl
        zvbl
        lzvbl
        bla % Baseline adjusted (manually)

        k_line
        ka_line
        nvpd
    end

    properties (Access = private)
        cmdStack % List of previously entered commands - allows undoing.
    end

    properties (SetAccess = public, GetAccess = public)

        % These allow configuration of the tool...
        Timestep = 15;
        PARthresh=100; % values less than threshold are considered nighttime
        % VPD
        VPDthresh=0.05; % values less than threshold are considered effectively zero
        VPDtime=2; % length in HOURS of time segment of low-VPD conditions

        % External function to be called when the baseline data is changed;
        % this will usually be to update a graph to reflect the change.
        baselineCallback

        % External function to call when sapflow data is changed.
        sapflowCallback
    end

    methods

        function o = SapflowProcessor(doy, tod, vpd, par, ss)
            % Constructor just stores the passed values.
            o.doy = doy;
            o.tod = tod;
            o.vpd = vpd;
            o.par = par;
            o.ss = ss;
            o.ssL = length(o.ss);

            o.cmdStack = Stack(); % Used for undoing commands.
        end


        function undo(o)
            % Each editing command can be undone one at a time.

            % Each entry is a 1 x N cell array containing:
            % - command description text (ignored by this method)
            % - handle to function that performs the actions to undo
            % - additional elements are passed as an argument to the
            % function
            if o.cmdStack.isEmpty()
                % nothing left to undo
                return;
            end

            cmd = o.cmdStack.pop();
            func = cmd{2};
            args = cmd(3:end);
            func(args);
            %TODO callback to update undo button
        end


        function addBaselineAnchors(o, t)
            % Anchor the baseline to sapflow at the specified times.
            %
            %

            o.cmdStack.push({'add baseline anchors', @o.undoBaselineChange, o.bla});
            o.bla = unique([o.bla; t']);
            o.compute();
            o.baselineCallback();
        end

        function delBaselineAnchors(o, i)
            %
            % i is the
            o.cmdStack.push({'delete baseline anchors', @o.undoBaselineChange, o.bla});
            o.bla(i) = [];
            o.compute();
            o.baselineCallback();
        end


        function delSapflow(o, regions)
            o.modifySapflow(regions, @o.delSapflowSegment, 'delete sapflow data')
        end

        function interpolateSapflow(o, regions)
            o.modifySapflow(regions, @o.interpSapflowSegment, 'interpolate sapflow data')
        end


        function auto(o)
            nDOY = o.doy;
            nDOY(o.tod < 1000) = nDOY(o.tod < 1000) - 1;

            [o.spbl, ~, o.zvbl, o.lzvbl] = BL_auto( ...
                o.ss, o.doy, nDOY, o.Timestep, o.par, o.PARthresh, ...
                o.vpd, o.VPDthresh, o.VPDtime ...
            );

            iValidSamples = find(isfinite(o.ss));
            iFirstValid = min(iValidSamples);
            iLastValid = max(iValidSamples);
            if iFirstValid == o.lzvbl(1)
                iFirstValid = [];
            end
            if iLastValid == o.lzvbl(end)
                iLastValid = [];
            end

            o.bla = [iFirstValid; o.lzvbl; iLastValid];
        end

        function compute(o)
            blv = interp1(o.zvbl, o.ss(o.zvbl), (1:o.ssL))';

            o.k_line = blv ./ o.ss - 1;
            o.k_line(o.k_line < 0) = 0;

            blv = interp1(o.bla, o.ss(o.bla), (1:o.ssL))';
            o.ka_line = blv ./ o.ss - 1;
            o.ka_line(o.ka_line < 0) = 0;

            o.nvpd = o.vpd ./ max(o.vpd) .* max(o.ka_line);
        end

    end

    methods (Access = private)

        function undoBaselineChange(o, args)
            o.bla = args{1};
            o.compute();
            o.baselineCallback();
        end


        function undoSapflowChange(o, args)
            [ssCutSeg, o.bla, o.spbl, o.zvbl, o.lzvbl] = args{1:end};
            for seg = ssCutSeg
                [ts, te, orig] = seg{1}{:};
                o.ss(ts:te) = orig;
            end

            o.compute();
            o.sapflowCallback();
            o.baselineCallback();
        end

        function delSapflowSegment(o, ts, te)
            o.ss(ts:te) = NaN;
        end

        function interpSapflowSegment(o, ts, te)
            if ts == 1 || te == o.ssL
                o.ss(ts:te) = NaN;
                return
            end
            ts = ts - 1;
            te = te + 1;
            if not(isfinite(o.ss(ts)) & isfinite(o.ss(ts)))
                return
            end
            o.ss(ts:te) = interp1([ts, te], o.ss([ts,te]), ts:te);
        end

        function modifySapflow(o, regions, segmentCallback, message)
            blaCutI = [];
            spblCutI = [];
            zvblCutI = [];
            lzvblCutI = [];
            ssCutSegs = {};

            [rows,~] = size(regions)
            for row = 1:rows
                ts = regions(row,1);
                te = regions(row,2);
                i = find(ts <= o.bla & te >= o.bla);
                blaCutI = [blaCutI, i];

                i = find(ts <= o.spbl & te >= o.spbl);
                spblCutI = [spblCutI, i];

                i = find(ts <= o.zvbl & te >= o.zvbl);
                zvblCutI = [zvblCutI, i];

                i = find(ts <= o.lzvbl & te >= o.lzvbl);
                lzvblCutI = [lzvblCutI, i];

                ssCutSegs{end+1} = {ts, te, o.ss(ts:te)};

                segmentCallback(ts, te)
            end
            o.cmdStack.push({message, @o.undoSapflowChange, ssCutSegs, o.bla, o.spbl, o.zvbl, o.lzvbl});
            o.bla(blaCutI) = [];
            o.spbl(spblCutI) = [];
            o.zvbl(zvblCutI) = [];
            o.lzvbl(lzvblCutI) = [];
            o.compute();
            o.sapflowCallback();
            o.baselineCallback();
        end


    end

end
