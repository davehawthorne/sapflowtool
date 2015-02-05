classdef LineEditWindow < handle
    %% Places widgets on the window.  Handles sizing only, no logic.
    properties (SetAccess = private, GetAccess = protected)
        figPosScaler
    end
    properties (SetAccess = protected, GetAccess = public)
        myFig
        myAxes

        back, forward, nextSensor, prevSensor, zoomOut, zoomIn

        buttons, keys

        % plots

        mz

        TEMP
    end

    methods (Access = public)
        function o = LineEditWindow()

            % Create a figure and axes
            o.myFig = figure('units', 'normalized', 'OuterPosition', [0, 0.05, 1, 0.95], ...
                'ToolBar', 'none', ...
                'MenuBar', 'none');  % , ...
                % 'KeyPressFcn', @o.handleKeypress);
            % 'CloseRequestFcn', @closeConfirm,


            %%TEMP!!! doesn't work... maximize(myFig); % using 3rd party code - potentially to be deprecated

            o.myFig.Units = 'pixels';
            pos = o.myFig.Position;
            xs = pos(3)/25; % width
            ys = pos(4)/25; % height
            o.figPosScaler = [xs, ys, xs, ys];


            function a = makeAxes(pos)
                a = axes('Units', 'pixels', 'Parent', o.myFig, 'Position', pos .* o.figPosScaler);
                hold(a, 'on');
            end

            o.myAxes.dtFull = makeAxes([1, 22, 23, 2]);
            o.myAxes.kFull =  makeAxes([1, 19, 23, 2]);

            o.myAxes.dtZoom =  makeAxes([1, 10, 17, 8]);
            o.myAxes.kZoom =  makeAxes([1, 1, 17, 8]);

            s.figure = o.myFig;
            s.fullPlots = {o.myAxes.dtFull, o.myAxes.kFull};
            s.zoomPlots = {o.myAxes.dtZoom, o.myAxes.kZoom};
            o.mz = MultiZoomer(s);

            o.myFig.KeyPressFcn = @o.handleKeypress;

            o.mz.makeZoomer(2);

            %TEMP!!! o.plots = struct();


        end


        function plotHandle = createEmptyPlot(o, axesName, style)
            plotHandle = plot(o.myAxes.(axesName), 0, 0, style, 'Visible', 'Off');
        end

        function polyHandle = createEmptyPoly(o, axesName, color, alpha)
            polyHandle = fill( ...
                [0, 0, 0, 0], [0, 0, 0, 0], ...
                '', ...
                'Parent', o.myAxes.(axesName), ...
                'LineWidth', 1, ...
                'FaceColor', color, ...
                'FaceAlpha', alpha, ...
                'HitTest', 'off' ...
            );
        end



        function o = setLimits(o, xLimit, yLimits)
            o.mz.createZoomBoxes();  %TEMP!!!
            s.xLimit = xLimit;
            s.yLimits = yLimits;
            s.xZoom = [xLimit(1), xLimit(2)/10];
            o.mz.setLimits(s);
        end


    end

    methods (Access = protected)

        function closeConfirm(o, ~, ~)
            selection = questdlg('Close This Application?',...
                'Close Request Function',...
                'Yes','No','Yes');
            switch selection,
                case 'Yes',
                    delete(o.myFig)
                case 'No'
                    return
            end
        end




        function o = addButton(o, name, text, key, toolTip, x, y, callback)
            o.buttons.(name) = uicontrol( ...
                'Parent', o.myFig, ...
                'Style', 'pushbutton', 'String', text,...
                'Callback', callback, ...
                'Position', o.figPosScaler .* [x * 2 + 18, y, 1.5, 0.8], ...
                'TooltipString', toolTip, ...
                'Enable', 'Off' ...
            );
            o.keys.(name) = struct( ...
                'Key', key, 'Enable', 0, 'Callback', callback ...
            );
        end

        function handleKeypress(o, ~, event)
            key = event.Key;
            if isempty(o.keys)
                tooEarly = event.Key
                return
            end
            for name = fieldnames(o.keys)'
                keyData = o.keys.(name{1});
                if strcmp(keyData.Key, key) && keyData.Enable
                    keyData.Callback(0,0);
                    return;
                end
            end
            missed = event.Key
        end


        function o = disableCommands(o, names)
            for name = names
                o.keys.(name{1}).Enable = 0;
                o.buttons.(name{1}).Enable = 'Off';
            end
        end

        function o = enableCommands(o, names)
            for name = names
                o.keys.(name{1}).Enable = 1;
                o.buttons.(name{1}).Enable = 'On';
            end
        end


    end
end


