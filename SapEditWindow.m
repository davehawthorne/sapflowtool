classdef SapEditWindow < LineEditWindow
    % The sapflow data editing application.
    %
    % Allows operators to view and edit sapflow data and to specify a baseline
    % representing zero sapflow.

    properties
        lines % Structure containing handles to each of the lines representing the data

        % structure to hold selected datapoints
        selection  %TEMP!!! rethink logic
        selected

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
            o.addButton('selRaw',   'sel raw',       'r',          'select enclosed raw values',       1, 4, @o.selectRaw);
            o.addButton('selBla',   'sel baseline',  'b',          'select enclosed baseline anchors', 1, 5, @o.selectBla);
            o.addButton('undo',     'undo last',     'u',          'undo last command',                2, 6, @(~,~)o.sfp.undo());
            o.addButton('delRaw',   'delete raw',    'd',          'delete raw',                       2, 7, @o.delRaw);

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
            o.lines.select     = o.createEmptyPoly('dtZoom',  'k', 0.3);

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
            o.enableCommands({'delRaw'});  %%TEMP!!!

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


        function o = selectPointsInRegion(o, x, y)

            o.lines.select.Visible = 'Off';
            o.disableCommands({'zoomReg', 'selRaw', 'selBla'});
            xr = o.selection.xRange;
            yr = o.selection.yRange;
            range = find(x > xr(1) & x < xr(2) & y > yr(1) & y < yr(2));
            o.lines.edit.XData = x(range);
            o.lines.edit.YData = y(range);
            o.selected = x(range);

            o.lines.edit.Visible = 'on';
        end


        function o = selectRaw(o, ~, ~)
            o.selectPointsInRegion(o.lines.sapflow.XData, o.lines.sapflow.YData);
        end


        function o = selectBla(o, ~, ~)
            o.selectPointsInRegion(o.lines.bla.XData, o.lines.bla.YData);
        end


        function o = delRaw(o, ~, ~)
            o.lines.edit.Visible = 'Off';
            o.sfp.delSapflow(o.selected);
        end


        function o = zoomtoRegion(o, ~, ~)
            o.lines.select.Visible = 'Off';
            o.disableCommands({'zoomReg', 'selRaw', 'selBla'});
            o.zoomer.zoomToRange(1, o.selection.xRange, o.selection.yRange);
        end


        function o = selectDtArea(o, chart, ~)
            o.lines.select.Visible = 'Off';
            p1 = chart.CurrentPoint();
            rbbox();
            p2 = chart.CurrentPoint();
            o.selection.xRange = sort([p1(1,1), p2(1,1)]);
            o.selection.yRange = sort([p1(1,2), p2(1,2)]);
            o.lines.select.XData = o.selection.xRange([1, 2, 2, 1]);
            o.lines.select.YData = o.selection.yRange([1, 1, 2, 2]);
            o.lines.select.Visible = 'On';
            o.enableCommands({'zoomReg', 'selRaw', 'selBla'});
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


    end
end
