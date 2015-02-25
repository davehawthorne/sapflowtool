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

        ssOrig

        ssL % length of sapflow data (N)

        % These are generated automatically from the sapflow values:
        % The are 1 x N vectors of indexes

        zvbl % points where nighttime VPD is zero for at least threshold duration
        spbl % zvbl values where standard deviation is less than threshold limit
        lzvbl % final zvbl value each night

        bla % Baseline adjusted (manually); a 1 x N

        % these are 1xN vectors of the same length as the ss vectors
        k_line
        ka_line
        nvpd

        config
    end

    properties (Access = private)
        cmdStack % Last on, first off stack of previously entered commands - allows undoing.
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

        % Called after each command is executed or undo requested.  It is passed a string
        % describing the last operation that can be undone.  Alternately if
        % there are no more commands to undo, 0 passed
        undoCallback
    end

    methods

        function o = SapflowProcessor(doy, tod, vpd, par, ss, config)
            % Constructor just stores the passed values.
            o.doy = doy;
            o.tod = tod;
            o.vpd = vpd;
            o.par = par;
            o.ssOrig = oneByN(ss);
            o.ss = oneByN(ss);
            o.ssL = length(o.ss);
            o.spbl = [1,o.ssL];
            o.zvbl = [1,o.ssL];
            o.lzvbl = [1,o.ssL];
            o.bla = [1,o.ssL];

            o.cmdStack = Stack(); % Used for undoing commands.

            o.config = config;
        end


        function setup(o)
            % Called each time this SFP gets focus
            if o.cmdStack.isEmpty()
                o.undoCallback(0)
            else
                nextCmd = o.cmdStack.peek();
                o.undoCallback(nextCmd{1});
            end

        end


        function cleanRawData(o)
            o.ss = cleanRawFluxData(o.ss, o.config);
        end


        function isChange = changesMade(o)
            % Called before potentially discarding work by closed
            % application or project.
            isChange = not(o.cmdStack.isEmpty());
        end


        function s = getModifications(o)
            %
            s.bla = o.bla;
            s.spbl = o.spbl;
            s.zvbl = o.zvbl;
            s.lzvbl = o.lzvbl;
            unchanged = (o.ss == o.ssOrig) | (isnan(o.ss) & isnan(o.ssOrig));

            [ts, te] = getRanges(~unchanged);
            len = length(ts);
            s.sapflow.cut = {};
            s.sapflow.new = {};
            for i = 1:len
                data = o.ss(ts(i):te(i));
                if all(isnan(data))
                    s.sapflow.cut{end+1} = struct('start', ts(i), 'end', te(i));
                else
                    s.sapflow.new{end+1} = struct('start', ts(i), 'end', te(i), 'data', data);
                end
            end

            o.emptyUndoStack();

        end

        function setModifications(o, s)
            o.bla = s.bla;
            o.spbl = s.spbl;
            o.zvbl = s.zvbl;
            o.lzvbl = s.lzvbl;
            for seg = s.sapflow.cut
                segv = seg{1};
                o.ss(segv.start:segv.end) = NaN;
            end
            for seg = s.sapflow.new
                segv = seg{1};
                o.ss(segv.start:segv.end) = segv.data;
            end

            o.emptyUndoStack();

        end

        function undo(o)
            % Each editing command can be undone one at a time.

            % Each entry is a 1 x N cell array containing:
            % - command description text (ignored by this method)
            % - handle to function that performs the actions to undo
            % - additional elements are passed as an argument to the
            % function
            if o.cmdStack.isEmpty()
                o.undoCallback(0)
                % nothing left to undo
                return;
            end

            cmd = o.cmdStack.pop();
            func = cmd{2};
            args = cmd{3};
            func(args);
            if o.cmdStack.isEmpty()
                o.undoCallback(0)
            else
                nextCmd = o.cmdStack.peek();
                o.undoCallback(nextCmd{1});
            end
        end


        function addBaselineAnchors(o, t)
            % Anchor the baseline to sapflow at the specified times t.
            % t is a 1xN vector.
            % This command can be undone.
            o.pushCommand('add baseline anchors', @o.undoBaselineChange, o.bla);
            o.bla = unique([o.bla, t]);
            o.compute();
            o.baselineCallback();
        end

        function delBaselineAnchors(o, i)
            % Delete the baseline anchor points with the index values i
            % i is a 1xN vector.
            % This command can be undone.
            o.pushCommand('delete baseline anchors', @o.undoBaselineChange, o.bla);
            o.bla(i) = [];
            o.compute();
            o.baselineCallback();
        end


        function delSapflow(o, regions)
            % Delete the sapflow values in the specified regions.
            % regions is a 1xN cell array, where each cell is a 1x2 array
            % of the form [tStart, tEnd].
            %
            % Sapflow data are deleted by setting the values to NaN.
            % Any baseline values in these ranges will also be deleted.
            %
            % This command can be undone.
            o.modifySapflow(regions, @o.delSapflowSegment, 'delete sapflow data')
        end

        function interpolateSapflow(o, regions)
            % The same as delSapflow() except that the sapflow changes
            % linearly over each range from the value at start to the value
            % at the end.
            % regions is a 1xN cell array, where each cell is a 1x2 array
            % of the form [tStart, tEnd].
            %
            % Any baseline values in these ranges will be deleted.
            %
            % This command can be undone.
            o.modifySapflow(regions, @o.interpSapflowSegment, 'interpolate sapflow data')
        end


        function auto(o)
            % Apply an algorithm to the sapflow data to identify some
            % candidate baseline anchor points.
            %
            % Populates the spbl, zvbl, lzvbl and bla vectors.
            %

            o.pushCommand('autoassign BL anchors', @o.undoSapflowChange, {{}, o.bla, o.spbl, o.zvbl, o.lzvbl});

            nDOY = o.doy;
            nDOY(o.tod < 1000) = nDOY(o.tod < 1000) - 1;

            [mySpbl, ~, myZvbl, myLzvbl] = BL_auto( ...
                o.ss', o.doy, nDOY, o.Timestep, o.par, o.PARthresh, ...
                o.vpd, o.VPDthresh, o.VPDtime ...
            );


            o.spbl = oneByN(mySpbl);  %TEMP!!! there must be a nicer way of ensuring 1xN shape.
            o.zvbl = oneByN(myZvbl);
            o.lzvbl = oneByN(myLzvbl);

            iValidSamples = find(isfinite(o.ss));
            iFirstValid = min(iValidSamples);
            iLastValid = max(iValidSamples);
            if iFirstValid == o.lzvbl(1)
                iFirstValid = [];
            end
            if iLastValid == o.lzvbl(end)
                iLastValid = [];
            end

            o.bla = [iFirstValid, o.lzvbl, iLastValid];

            o.compute();
            o.sapflowCallback();
            o.baselineCallback();
        end

        function compute(o)
            % Based on the sapflow, bla and VPD data, calculate the K, KA
            % and NVPD values.
            %
            blv = interp1(o.zvbl, o.ss(o.zvbl), (1:o.ssL));

            o.k_line = blv ./ o.ss - 1;
            o.k_line(o.k_line < 0) = 0;

            blv = interp1(o.bla, o.ss(o.bla), (1:o.ssL));
            o.ka_line = blv ./ o.ss - 1;
            o.ka_line(o.ka_line < 0) = 0;

            o.nvpd = o.vpd ./ max(o.vpd) .* max(o.ka_line);
        end

    end

    methods (Access = private)

        function undoBaselineChange(o, args)
            % Restore the baseline anchor values which were saved prior to
            % the previous command.
            o.bla = args;
            o.compute();
            o.baselineCallback();
        end


        function undoSapflowChange(o, args)
            % Restores the sapflow data ranges changed by the previous
            % command.  Restore the various candidate and manually defined
            % baseline anchor points.
            %
            % Blanket overright of baseline values, restoration of ss is
            % done one segment at a time
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
            % Callback for modifySapflow().  All sapflow data in the ts to
            % te range are discarded.
            o.ss(ts:te) = NaN;
        end

        function interpSapflowSegment(o, ts, te)
            % Callback for modifySapflow().  A little more involved than
            % delSapflowSegment().  If either end of the range is NaN then
            % the whole range is set accordingly.  Otherwise we join the
            % start with the end with a straight line.
            if isnan(o.ss(ts)) || isnan(o.ss(te))
                return
            end
            o.ss(ts:te) = interp1([ts, te], o.ss([ts,te]), ts:te);
        end

        function modifySapflow(o, regions, segmentCallback, message)
            % Does the heavy lifting for interpolateSapflow() and
            % delSapflow().  For each region, identifies enclosed baseline
            % anchor points and marks them for deletion.  Also calls the
            % appropriate callback to modify the sapflow data.
            %
            % The baseline vectors are small enough to store complete.
            % Storing the complete sapflow vectors would chew up lots of
            % memory, so we just store the segments changes, along with
            % some location information.
            blaCutI = [];
            spblCutI = [];
            zvblCutI = [];
            lzvblCutI = [];
            ssCutSegs = {};

            [rows,~] = size(regions);
            for row = 1:rows
                ts = regions(row,1);
                te = regions(row,2);
                i = find(ts <= o.bla & te >= o.bla);
                blaCutI = [blaCutI, i]; %#ok<AGROW>

                i = find(ts <= o.spbl & te >= o.spbl);
                spblCutI = [spblCutI, i]; %#ok<AGROW>

                i = find(ts <= o.zvbl & te >= o.zvbl);
                zvblCutI = [zvblCutI, i]; %#ok<AGROW>

                i = find(ts <= o.lzvbl & te >= o.lzvbl);
                lzvblCutI = [lzvblCutI, i]; %#ok<AGROW>

                ssCutSegs{end+1} = {ts, te, o.ss(ts:te)}; %#ok<AGROW>

                segmentCallback(ts, te)
            end
            o.pushCommand(message, @o.undoSapflowChange, {ssCutSegs, o.bla, o.spbl, o.zvbl, o.lzvbl});
            o.bla(blaCutI) = [];
            o.spbl(spblCutI) = [];
            o.zvbl(zvblCutI) = [];
            o.lzvbl(lzvblCutI) = [];
            o.compute();
            o.sapflowCallback();
            o.baselineCallback();
        end

        function pushCommand(o, description, callback, params)
            % With each command executed we record what's done so it can be
            % undeleted if necessary.  A callback is invoked which might be
            % used to update the text in the GUI's undo button for example.
            %
            % Parameters:
            % - description: text detailing the operation (used for the
            %   callback to the user interface code.
            % - callback: the method to call to undo the action
            % - params: a 1xN cell array with the parameters needed by the
            %   undo callback.
            o.cmdStack.push({description, callback, params})
            if isa(o.undoCallback, 'function_handle')
                o.undoCallback(description);
            end
        end

        function emptyUndoStack(o)
            o.cmdStack = Stack(); % start a new stack
            o.undoCallback(0);  % report up that the stack is empty.
        end

    end

end
