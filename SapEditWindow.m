classdef SapEditWindow < LineEditWindow
    % The sapflow data editing application.
    %
    % Allows operators to view and edit sapflow data and to specify a baseline
    % representing zero sapflow.

    properties
        lines % Structure containing handles to each of the lines representing the data

        % structure to hold selected datapoints
        selection  %TEMP!!! rethink logic
        selectBox
        % selected

        sfp  % The SapflowProcessor object for the current sensor data.
    end

    methods (Access = public)


         function o = SapEditWindow()
            % Constructor sets up window
            %
            % It added sapflow specific items to the generic LineEditWindow object.


            o@LineEditWindow(); % Create generic window.

            % Add in controls
            o.addButton('panLeft',  '< pan',         'leftarrow',  'pan focus area left ("<-")',       1, 1, @(~,~)o.zoomer.pan(-0.8));
            o.addButton('panRight', 'pan >',         'rightarrow', 'pan focus area right ("->")',      2, 1, @(~,~)o.zoomer.pan(+0.8));
            o.addButton('zoomIn',   'zoom in',       'add',        'narrow focus area duration ("+")', 1, 2, @(~,~)o.zoomer.zoom(0.8));
            o.addButton('zoomOut',  'zoom out',      'subtract',   'expand focus area duration ("-")', 2, 2, @(~,~)o.zoomer.zoom(1.25));
            o.addButton('zoomReg',  'zoom sel',      'z',          'zoom to selection',                1, 3, @o.zoomtoRegion);
            o.addButton('delBla',   'del BL anchors','b',          'delete baseline anchors in range (d)', 1, 5, @o.delBla);
            o.addButton('delRaw',   'delete SF data','d',          'delete selected sapflow data',         1, 7, @o.delRaw);
            o.addButton('intRaw',   'interpolate SF','i',          'interpolate selected sapflow data',    2, 7, @o.intRaw);
            o.addButton('anchorBla','anchor BL',     'a',          'anchor baseline to suggested points',  3, 7, @o.anchorBla);
            o.addButton('undo',     'undo last',     'u',          'undo last command',                    2, 6, @(~,~)o.sfp.undo());

            % Specify all the plot lines we'll use.
            o.lines = struct();

            o.lines.sapflowAll = o.createEmptyLine('dtFull', 'b-');
            o.lines.sapflow    = o.createEmptyLine('dtZoom', 'b-');
            o.lines.spbl       = o.createEmptyLine('dtZoom', 'g.');
            o.lines.zvbl       = o.createEmptyLine('dtZoom', 'k.');
            o.lines.lzvbl      = o.createEmptyLine('dtZoom', 'k+');
            o.lines.blaAll     = o.createEmptyLine('dtFull', 'r-');
            o.lines.bla        = o.createEmptyLine('dtZoom', 'r-o');

            o.lines.kLineAll   = o.createEmptyLine('kFull',  'b-');
            o.lines.kLine      = o.createEmptyLine('kZoom',  'b-');
            o.lines.kaLineAll  = o.createEmptyLine('kFull',  'r:');
            o.lines.kaLine     = o.createEmptyLine('kZoom',  'r:');
            o.lines.nvpd       = o.createEmptyLine('kZoom',  'g-');

            o.lines.edit       = o.createEmptyLine('dtZoom',  'bo');
            o.selectBox        = o.createEmptyLine('dtZoom',  'k:');
            %o.selectPoints     = o.createEmptyLine('dtZoom',  'ko');
            %o.selectLine       = o.createEmptyLine('dtZoom',  'k');

            %TEMP!!! the following is hardcoded for now...

            [year, par, vpd, sf, doy, tod] = loadRawSapflowData('little.csv', 2012);

            sf = cleanRawFluxData(sf);

            ss = sf(:,2); % select just one sensor for now

            par = processPar(par, tod);

            % set up processor
            o.sfp = SapflowProcessor(doy, tod, vpd, par, ss);

            o.sfp.baselineCallback = @o.baselineUpdated;
            o.sfp.sapflowCallback = @o.sapflowUpdated;

            o.sfp.auto();

            o.sfp.compute();

            o.setLimits([1, o.sfp.ssL], {[0, max(o.sfp.ss)], [0, 1]});

            o.setXData(1:o.sfp.ssL);

            o.baselineUpdated();
            o.sapflowUpdated();

            for name = {'bla', 'blaAll', 'sapflowAll', 'sapflow', 'spbl', 'zvbl', 'lzvbl', 'kLineAll', 'kLine', 'kaLineAll', 'kaLine', 'nvpd'}
                o.lines.(name{1}).Visible = 'On';
            end

            o.charts.dtZoom.ButtonDownFcn = @o.selectDtArea;

            o.lines.bla.ButtonDownFcn = @o.markerClick;
            o.lines.sapflow.ButtonDownFcn = @o.markerClick;
            o.lines.spbl.ButtonDownFcn = @o.markerClick;
            o.lines.zvbl.ButtonDownFcn = @o.markerClick;
            o.lines.lzvbl.ButtonDownFcn = @o.markerClick;

            o.enableCommands({'panLeft', 'panRight', 'zoomIn', 'zoomOut', 'undo'});

         end


    end

    methods (Access = private)


        function o = sapflowUpdated(o)
            % The SapflowProcessor calls this when sapflow is changed.
            %
            %TEMP!!! need to rethink/rename the sfp update callbacks
            o.lines.sapflowAll.YData = o.sfp.ss;
            o.lines.sapflow.YData = o.sfp.ss;

            o.lines.spbl.XData = o.sfp.spbl;
            o.lines.spbl.YData = o.sfp.ss(o.sfp.spbl);

            o.lines.zvbl.XData = o.sfp.zvbl;
            o.lines.zvbl.YData = o.sfp.ss(o.sfp.zvbl);

            o.lines.lzvbl.XData = o.sfp.lzvbl;
            o.lines.lzvbl.YData = o.sfp.ss(o.sfp.lzvbl);
        end


        function o = baselineUpdated(o)
            % Callback from SapflowProcessor
            o.lines.blaAll.XData = o.sfp.bla;
            o.lines.blaAll.YData = o.sfp.ss(o.sfp.bla);
            o.lines.bla.XData = o.sfp.bla;
            o.lines.bla.YData = o.sfp.ss(o.sfp.bla);

            o.lines.kLine.YData = o.sfp.k_line;
            o.lines.kLineAll.YData = o.sfp.k_line;
            o.lines.kaLine.YData = o.sfp.ka_line;
            o.lines.kaLineAll.YData = o.sfp.ka_line;
            o.lines.nvpd.YData = o.sfp.nvpd;
        end


        function o = delBla(o, ~, ~)
            o.selectBox.Visible = 'Off';
            i = o.pointsInSelection(o.lines.bla);
            o.sfp.delBaselineAnchors(i);
        end


        function i = pointsInSelection(o, line)
            x = line.XData;
            y = line.YData;
            xr = o.selection.xRange;
            yr = o.selection.yRange;
            i = (x > xr(1) & x < xr(2) & y > yr(1) & y < yr(2));
            i = i | (isnan(y) & x > xr(1) & x < xr(2));
        end


        function o = delRaw(o, ~, ~)
            o.deselect()
            i = o.pointsInSelection(o.lines.sapflow);
            changes = i - [0,i(1:end-1)];
            regions = [find(changes == 1)', find(changes == -1)'];
            o.sfp.delSapflow(regions);
        end


        function o = intRaw(o, ~, ~)
            o.deselect()
            i = o.pointsInSelection(o.lines.sapflow);
            changes = i - [0,i(1:end-1)];
            regions = [find(changes == 1)', find(changes == -1)'];
            o.sfp.interpolateSapflow(regions);
        end


        function o = zoomtoRegion(o, ~, ~)
            o.deselect()
            o.zoomer.zoomToRange(1, o.selection.xRange, o.selection.yRange);
        end


        function anchorBla(o, ~, ~)
            o.deselect()
            i = o.pointsInSelection(o.lines.zvbl);
            o.sfp.addBaselineAnchors(o.lines.zvbl.XData(i));

        end
        function o = selectDtArea(o, chart, ~)
            p1 = chart.CurrentPoint();
            rbbox();
            p2 = chart.CurrentPoint();
            o.selection.xRange = sort([p1(1,1), p2(1,1)]);
            o.selection.yRange = sort([p1(1,2), p2(1,2)]);
            o.selectBox.XData = o.selection.xRange([1, 2, 2, 1, 1]);
            o.selectBox.YData = o.selection.yRange([1, 1, 2, 2, 1]);
            o.selectBox.Visible = 'On';
            o.enableCommands({'zoomReg', 'delRaw', 'intRaw', 'delBla', 'anchorBla'});
        end


        function o = markerClick(o, line, ~)
            chart = o.charts.dtZoom;
            ratio = chart.DataAspectRatio;
            p = chart.CurrentPoint();
            xr = chart.XLim;
            yr = chart.YLim;
            xd = line.XData;
            yd = line.YData;
            ii = find(xd > xr(1) & xd < xr(2) & yd > yr(1) & yd < yr(2));
            xp = p(1,1);
            yp = p(1,2);
            sqDist = ((xd(ii) - xp)/ratio(1)) .^ 2 + ((yd(ii) - yp)/ratio(2)) .^ 2;
            [~, i] = min(sqDist);
            o.lines.edit.XData = xd(ii(i));
            o.lines.edit.YData = yd(ii(i));
            o.lines.edit.Visible = 'On';

            o.sfp.addBaselineAnchors(xd(ii(i)));

        end


        function o = setXData(o, xData)
            for name = {'sapflowAll', 'sapflow', 'kLineAll', 'kLine', 'kaLineAll', 'kaLine', 'nvpd'}
                o.lines.(name{1}).XData = xData;
            end
        end


        function deselect(o)
            o.selectBox.Visible = 'Off';
            o.disableCommands({'zoomReg', 'delRaw', 'intRaw', 'delBla', 'anchorBla'});
        end

    end
end
