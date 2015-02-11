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
        allSfp
        sfpI

        numSensors

    end

    methods (Access = public)


         function o = SapEditWindow()
            % Constructor sets up window
            %
            % It added sapflow specific items to the generic LineEditWindow object.


            o@LineEditWindow(); % Create generic window.

            mf = uimenu(o.figureHnd, 'Label', 'File');
            me = uimenu(o.figureHnd, 'Label', 'Edit');
            mh = uimenu(o.figureHnd, 'Label', 'Help');

            mo = uimenu(mf, 'Label', 'Open Project', 'Accelerator', 'O', 'Callback', @o.openProject);


            % Add in controls
            o.addButton('nextSensor',  'next sensor',         'downarrow',  'next sensor',       2, 9, @(~,~)o.selectSensor(1));
            o.addButton('prevSensor', 'prev sensor',         'uparrow', 'prev sensor',      2, 10, @(~,~)o.selectSensor(-1));
            o.addButton('panLeft',  '< pan',         'leftarrow',  'pan focus area left ("<-")',       1, 1, @(~,~)o.zoomer.pan(-0.8));
            o.addButton('panRight', 'pan >',         'rightarrow', 'pan focus area right ("->")',      2, 1, @(~,~)o.zoomer.pan(+0.8));
            o.addButton('zoomIn',   'zoom in',       'add',        'narrow focus area duration ("+")', 1, 2, @(~,~)o.zoomer.zoom(0.8));
            o.addButton('zoomOut',  'zoom out',      'subtract',   'expand focus area duration ("-")', 2, 2, @(~,~)o.zoomer.zoom(1.25));
            o.addButton('zoomReg',  'zoom sel',      'z',          'zoom to selection',                1, 3, @o.zoomtoRegion);
            o.addButton('delBla',   'del BL anchors','b',          'delete baseline anchors in range (d)', 1, 5, @o.delBla);
            o.addButton('deleteSapflow',   'delete SF data','d',          'delete selected sapflow data',         1, 7, @o.deleteSapflow);
            o.addButton('interpolateSapflow',   'interpolate SF','i',          'interpolate selected sapflow data',    2, 7, @o.interpolateSapflow);
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

            o.selectBox        = o.createEmptyLine('dtZoom',  'k:');

            o.charts.dtZoom.ButtonDownFcn = @o.selectDtArea;

            for name = {'bla', 'sapflow', 'spbl', 'zvbl', 'lzvbl'}
                line = o.lines.(name{:});
                line.ButtonDownFcn = @o.markerClick;
                line.PickableParts = 'visible';
            end

            o.zoomer.createZoomAreaIndicators();
         end



    end

    methods (Access = private)

        function year = whichYear(o, years)
            dialogOut = inputdlg('Which year? (', '', 1, {num2str(years(1))});
            year = str2double(dialogOut{:});
        end

        function openProject(o, ~, ~)
            [filename, path] = uigetfile('*.csv', 'Select Data File');
            if not(filename)
                return
            end

            for name = {'bla', 'blaAll', 'sapflowAll', 'sapflow', 'spbl', 'zvbl', 'lzvbl', 'kLineAll', 'kLine', 'kaLineAll', 'kaLine', 'nvpd'}
                o.lines.(name{1}).Visible = 'Off';
            end

            o.disableCommands({});
            o.zoomer.disable();
            o.disableChartsControl();

            savedPointer = o.figureHnd.Pointer;
            o.figureHnd.Pointer = 'watch';
            o.deselect();

            o.reportStatus('Loading');

            try
                [year, par, vpd, sf, doy, tod] = loadRawSapflowData(fullfile(path, filename), @o.whichYear);
            catch err
                errordlg(err.message, 'Well, that didn''t work')
                return;
            end
            o.reportStatus('Cleaning');

            sf = cleanRawFluxData(sf);
            o.reportStatus('Processing PAR');
            par = processPar(par, tod);

            [~, o.numSensors] = size(sf);

            o.allSfp = cell(1, o.numSensors);

            for i = 1:o.numSensors
                o.reportStatus(sprintf('Building %d of %d', i, o.numSensors));
                o.allSfp{i} = SapflowProcessor(doy, tod, vpd, par, sf(:,i));
                o.allSfp{i}.baselineCallback = @o.baselineUpdated;
                o.allSfp{i}.sapflowCallback = @o.sapflowUpdated;
                o.allSfp{i}.undoCallback = @o.undoCallback;
                o.allSfp{i}.auto();
                o.allSfp{i}.compute();
            end

            o.reportStatus('Ready');

            o.sfpI = 1;
            o.sfp = o.allSfp{o.sfpI};


            o.zoomer.setXLimit([1, o.sfp.ssL]);

            o.setXData(1:o.sfp.ssL);

            o.figureHnd.Pointer = savedPointer;

            o.selectSensor(0);
            o.zoomer.enable();
            o.enableChartsControl();

            for name = {'bla', 'blaAll', 'sapflowAll', 'sapflow', 'spbl', 'zvbl', 'lzvbl', 'kLineAll', 'kLine', 'kaLineAll', 'kaLine', 'nvpd'}
                o.lines.(name{1}).Visible = 'On';
            end

        end


        function selectSensor(o, dir)

            % the joys of MATLAB's index from 1 approach ...
            indexFromZero = o.sfpI - 1;
            indexFromZero = mod(indexFromZero + dir, o.numSensors);
            o.sfpI = indexFromZero + 1;

            o.deselect();

            o.sfp = o.allSfp{o.sfpI};
            o.baselineUpdated();
            o.sapflowUpdated();

            o.reportStatus(sprintf('Sensor %d', o.sfpI));

            o.sfp.setup();

            o.enableCommands({'panLeft', 'panRight', 'zoomIn', 'zoomOut', 'nextSensor', 'prevSensor'});

            o.zoomer.setYLimits({[0, max(o.sfp.ss)], [0, 1]});
        end

        function sapflowUpdated(o)
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


        function baselineUpdated(o)
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


        function delBla(o, ~, ~)
            % The user has clicked the delete baseline button.  Delete the
            % bla values in the selection range.
            o.deselect()
            i = o.pointsInSelection(o.lines.bla);
            o.sfp.delBaselineAnchors(i);
        end


        function i = pointsInSelection(o, line)
            % For the specified 1xN line, return a 1xN vector indicating
            % which points of that line fall within the X and Y values
            % bound by the selection rectangle.
            %
            % any NaN values in the X range are treated as in range.
            x = line.XData;
            y = line.YData;
            xr = o.selection.xRange;
            yr = o.selection.yRange;
            i = (x >= xr(1) & x <= xr(2) & y >= yr(1) & y <= yr(2));
            i = i | (isnan(y) & x >= xr(1) & x <= xr(2));  %capture NaN values  %TEMP!!! rethink
        end


        function deleteSapflow(o, ~, ~)
            % Delete all sapflow sample values inclosed in the selection
            % box.
            o.deselect()
            i = o.pointsInSelection(o.lines.sapflow);
            changes = i - [0,i(1:end-1)];
            regions = [find(changes == 1)', find(changes == -1)'];
            o.sfp.delSapflow(regions);
        end


        function interpolateSapflow(o, ~, ~)
            % Interpolate all sapflow sample values inclosed in the selection
            % box.
            o.deselect()
            i = o.pointsInSelection(o.lines.sapflow);
            changes = i - [0,i(1:end-1)];
            regions = [find(changes == 1)' - 1, find(changes == -1)'];
            o.sfp.interpolateSapflow(regions);
        end


        function zoomtoRegion(o, ~, ~)
            % Zoom in so the currently selected area fills the chart.
            o.deselect()
            o.zoomer.zoomToRange(1, o.selection.xRange, o.selection.yRange);
        end


        function anchorBla(o, ~, ~)
            % Anchor the baseline at every ZeroVpd candidate anchor point
            % in the selection box.
            o.deselect()
            i = o.pointsInSelection(o.lines.zvbl);
            o.sfp.addBaselineAnchors(o.lines.zvbl.XData(i));

        end


        function selectDtArea(o, chart, ~)
            % The user has clicked inside the zoom chart.  Once a range has
            % been selected by dragging the cursor mark this with the
            % selectBox line.  Enable any command that operates on selected
            % data.
            %
            % If the user clicks rather than drags AND the time the click
            % on has no valid sapflow data then the range without data is
            % selected.
            p1 = chart.CurrentPoint();
            rbbox();
            drawnow();  % gives next call enough time to register the mouse pointer has moved; sometimes it doesn't.
            p2 = chart.CurrentPoint();
            if p1 == p2
                % The user has clicked on an empty spot on the chart
                t = round(p1(1,1));

                % If there's no sapflow data at this time then try to place
                % the selection to bridge the NaN range.  And enable the
                % interpolate button so the user can join the dots.
                if isnan(o.sfp.ss(t))
                    notNan = not(isnan(o.sfp.ss));
                    tStart = find(notNan(1:t), 1, 'last');
                    tEnd = find(notNan(t:end), 1, 'first') + t - 1;
                    if tStart && tEnd
                        % There are valid sapflow data either side of the
                        % clicked point.
                        o.setSelectionArea([tStart, tEnd], o.sfp.ss([tStart, tEnd]));
                        o.enableCommands({'interpolateSapflow'});
                    end
                end
                return
            else
                % the user has dragged out a range
                o.setSelectionArea(sort([p1(1,1), p2(1,1)]), sort([p1(1,2), p2(1,2)]));
                o.enableCommands({'zoomReg', 'deleteSapflow', 'interpolateSapflow', 'delBla', 'anchorBla'});
            end
        end


        function markerClick(o, line, ~)
            % The user has clicked on the sapflow data line, or a baseline
            % candidate point.  Anchor the baseline to this point.
            chart = o.charts.dtZoom;
            ratio = chart.DataAspectRatio;
            p = chart.CurrentPoint();
            xr = chart.XLim;
            yr = chart.YLim;
            xd = line.XData;
            yd = line.YData;

            % Find the nearest point to where we clicked
            ii = find(xd > xr(1) & xd < xr(2) & yd > yr(1) & yd < yr(2));
            xp = p(1,1);
            yp = p(1,2);
            sqDist = ((xd(ii) - xp)/ratio(1)) .^ 2 + ((yd(ii) - yp)/ratio(2)) .^ 2;
            [~, i] = min(sqDist);

            o.sfp.addBaselineAnchors(xd(ii(i)));

        end


        function setXData(o, xData)
            % sets the common X axis values for all the 1 x ssL lines.
            for name = {'sapflowAll', 'sapflow', 'kLineAll', 'kLine', 'kaLineAll', 'kaLine', 'nvpd'}
                o.lines.(name{1}).XData = xData;
            end
        end

        function setSelectionArea(o,xRange, yRange)
            % Sets the selection range for susquent use and marks the area
            % on the zoomed chart.
            o.selection.xRange = xRange;
            o.selection.yRange = yRange;
            o.selectBox.XData = xRange([1, 2, 2, 1, 1]);
            o.selectBox.YData = yRange([1, 1, 2, 2, 1]);
            o.selectBox.Visible = 'On';
        end

        function deselect(o)
            % An action has been performed on the selected region.  We can
            % now clear the selection indicator and grey out the command
            % buttons.
            o.selectBox.Visible = 'Off';
            o.disableCommands({'zoomReg', 'deleteSapflow', 'interpolateSapflow', 'delBla', 'anchorBla'});
        end

        function undoCallback(o, description)
            % With each command executed or undone, we update the undo
            % button.  Either setting the button text to reflect the last
            % command or, if there are none, grey out the button.
            if not(description)
                o.renameCommand('undo', 'Undo');
                o.disableCommands({'undo'})
            else
                o.renameCommand('undo', strjoin({'Undo', description}));
                o.enableCommands({'undo'})
            end
        end


    end
end
