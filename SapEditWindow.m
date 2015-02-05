classdef SapEditWindow < LineEditWindow
    properties
        plots
        selection
        selected
        sfa
    end
    methods (Access = public)
         function o = SapEditWindow()
            o@LineEditWindow();

            o.addButton('panLeft', '< pan', 'leftarrow', 'pan focus area left ("<-")', 1, 1, @(~,~)o.mz.pan(-0.8));
            o.addButton('panRight', 'pan >', 'rightarrow', 'pan focus area right ("->")', 2, 1, @(~,~)o.mz.pan(+0.8));
            o.addButton('zoomIn', 'zoom in', 'add', 'narrow focus area duration ("+")', 1, 2, @(~,~)o.mz.zoom(0.8));
            o.addButton('zoomOut', 'zoom out', 'subtract', 'expand focus area duration ("-")', 2, 2, @(~,~)o.mz.zoom(1.25));
            o.addButton('zoomReg', 'zoom sel', 'z', 'zoom to selection', 1, 3, @o.zoomtoRegion);
            o.addButton('selRaw', 'sel raw', 'r', 'select enclosed raw values', 1, 4, @o.selectRaw);
            o.addButton('selBla', 'sel baseline', 'b', 'select enclosed baseline anchors', 1, 5, @o.selectBla);
            o.addButton('undo', 'undo last', 'u', 'undo last command', 2, 6, @(~,~)o.sfa.undo());
            o.addButton('delRaw', 'delete raw', 'd', 'delete raw', 2, 7, @o.delRaw);

            o.plots = struct();

            o.plots.sapflowAll = o.createEmptyPlot('dtFull',  'b-');
            o.plots.sapflow    = o.createEmptyPlot('dtZoom',  'b-');
            o.plots.spbl       = o.createEmptyPlot('dtZoom',  'g.');
            o.plots.zvbl       = o.createEmptyPlot('dtZoom',  'k.');
            o.plots.lzvbl      = o.createEmptyPlot('dtZoom',  'k+');
            o.plots.blaAll     = o.createEmptyPlot('dtFull',  'r-');
            o.plots.bla        = o.createEmptyPlot('dtZoom',  'r-o');

            o.plots.kLineAll   = o.createEmptyPlot('kFull',  'b-');
            o.plots.kLine      = o.createEmptyPlot('kZoom',  'b-');
            o.plots.kaLineAll  = o.createEmptyPlot('kFull',  'r:');
            o.plots.kaLine     = o.createEmptyPlot('kZoom',  'r:');
            o.plots.nvpd       = o.createEmptyPlot('kZoom',  'g-');

            o.plots.edit       = o.createEmptyPlot('dtZoom',  'bo');
            o.plots.select     = o.createEmptyPoly('dtZoom',  'y', 0.3);


            [year, par, vpd, sf, doy, tod] = loadRawSapflowData('little.csv', 2012);

            sf = cleanRawFluxData(sf);

            ss = sf(:,2);

            par = processPar(par, tod);

            o.sfa = SapflowProcessor(doy, tod, vpd, par, ss);

            o.sfa.baselineCallback = @o.baselineUpdated;
            o.sfa.sapflowCallback = @o.sapflowUpdated;

            o.sfa.auto();

            o.sfa.compute();

            o.setLimits([1, o.sfa.ssL], {[0, max(o.sfa.ss)], [0, 1]});

            o.setXData(1:o.sfa.ssL);

            o.baselineUpdated();
            o.sapflowUpdated();

            for name = {'bla', 'blaAll', 'sapflowAll', 'sapflow', 'spbl', 'zvbl', 'lzvbl', 'kLineAll', 'kLine', 'kaLineAll', 'kaLine', 'nvpd'}
                o.plots.(name{1}).Visible = 'On';
            end

            o.myAxes.dtZoom.ButtonDownFcn = @o.selectDtArea;

            o.plots.bla.ButtonDownFcn = @o.markerClick;
            o.plots.sapflow.ButtonDownFcn = @o.markerClick;
            o.plots.spbl.ButtonDownFcn = @o.markerClick;
            o.plots.zvbl.ButtonDownFcn = @o.markerClick;
            o.plots.lzvbl.ButtonDownFcn = @o.markerClick;

            o.enableCommands({'panLeft', 'panRight', 'zoomIn', 'zoomOut', 'undo'});
            o.enableCommands({'delRaw'});  %%TEMP!!!

         end

    end
    methods (Access = private)

        function o = sapflowUpdated(o)
            o.plots.sapflowAll.YData = o.sfa.ss;
            o.plots.sapflow.YData = o.sfa.ss;

            o.plots.spbl.XData = o.sfa.spbl;
            o.plots.spbl.YData = o.sfa.ss(o.sfa.spbl);

            o.plots.zvbl.XData = o.sfa.zvbl;
            o.plots.zvbl.YData = o.sfa.ss(o.sfa.zvbl);

            o.plots.lzvbl.XData = o.sfa.lzvbl;
            o.plots.lzvbl.YData = o.sfa.ss(o.sfa.lzvbl);
        end

        function o = baselineUpdated(o)
            o.plots.blaAll.XData = o.sfa.bla;
            o.plots.blaAll.YData = o.sfa.ss(o.sfa.bla);
            o.plots.bla.XData = o.sfa.bla;
            o.plots.bla.YData = o.sfa.ss(o.sfa.bla);

            o.plots.kLine.YData = o.sfa.k_line;
            o.plots.kLineAll.YData = o.sfa.k_line;
            o.plots.kaLine.YData = o.sfa.ka_line;
            o.plots.kaLineAll.YData = o.sfa.ka_line;
            o.plots.nvpd.YData = o.sfa.nvpd;
        end

        function o = selectPointsInRegion(o, x, y)
            o.plots.select.Visible = 'Off';
            o.disableCommands({'zoomReg', 'selRaw', 'selBla'});
            xr = o.selection.xRange;
            yr = o.selection.yRange;
            range = find(x > xr(1) & x < xr(2) & y > yr(1) & y < yr(2));
            o.plots.edit.XData = x(range);
            o.plots.edit.YData = y(range);
            o.selected = x(range);

            o.plots.edit.Visible = 'on';
        end


        function o = selectRaw(o, ~, ~)
            o.selectPointsInRegion(o.plots.sapflow.XData, o.plots.sapflow.YData);
        end

        function o = selectBla(o, ~, ~)
            o.selectPointsInRegion(o.plots.bla.XData, o.plots.bla.YData);
        end

        function o = delRaw(o, ~, ~)
            o.plots.edit.Visible = 'Off';
            o.sfa.delSapflow(o.selected);
        end

        function o = zoomtoRegion(o, ~, ~)
            o.plots.select.Visible = 'Off';
            o.disableCommands({'zoomReg', 'selRaw', 'selBla'});
            o.mz.zoomToRange(1, o.selection.xRange, o.selection.yRange);
        end


        function o = selectDtArea(o, axes, ~)
            o.plots.select.Visible = 'Off';
            p1 = axes.CurrentPoint();
            rbbox();
            p2 = axes.CurrentPoint();
            o.selection.xRange = sort([p1(1,1), p2(1,1)]);
            o.selection.yRange = sort([p1(1,2), p2(1,2)]);
            o.plots.select.XData = o.selection.xRange([1, 2, 2, 1]);
            o.plots.select.YData = o.selection.yRange([1, 1, 2, 2]);
            o.plots.select.Visible = 'On';
            o.enableCommands({'zoomReg', 'selRaw', 'selBla'});
        end

        function o = markerClick(o, line, ~)
            axes = o.myAxes.dtZoom;
            ratio = axes.DataAspectRatio;
            p = axes.CurrentPoint();
            xr = axes.XLim;
            yr = axes.YLim;
            xd = line.XData;
            yd = line.YData;
            ii = find( xd > xr(1) & xd < xr(2) & yd > yr(1) & yd < yr(2));
            xp = p(1,1);
            yp = p(1,2);
            sqDist = ((xd(ii) - xp)/ratio(1)) .^ 2 + ((yd(ii) - yp)/ratio(2)) .^ 2;
            [~, i] = min(sqDist);
            %temp = [ii(i), xd(ii(i)), yd(ii(i))]
            o.plots.edit.XData = xd(ii(i));
            o.plots.edit.YData = yd(ii(i));
            o.plots.edit.Visible = 'On';

            o.sfa.addBaseline(xd(ii(i)));



        end



        function o = setXData(o, xData)
            for name = {'sapflowAll', 'sapflow', 'kLineAll', 'kLine', 'kaLineAll', 'kaLine', 'nvpd'}
                o.plots.(name{1}).XData = xData;
            end
        end
    end
end
