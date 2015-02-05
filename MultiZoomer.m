classdef MultiZoomer < handle
    properties
        figure
        fullPlots
        zoomPlots
        zoomRects
        yLimits
        xLimit
        xZoom
        plotPairs
    end

    methods (Access = public)
        function o = MultiZoomer(s)
            o.figure = s.figure;
            o.fullPlots = s.fullPlots;
            o.zoomPlots = s.zoomPlots;
            o.figure.WindowScrollWheelFcn = @o.wheelCallback;
            o.plotPairs = length(o.fullPlots);
            for i = 1:o.plotPairs
                fp = o.fullPlots{i};
                fp.ButtonDownFcn = @o.buttDownFullAxis;
                for j = 1:length(fp.Children)
                    fp.Children(j).HitTest = 'off';
                end
            end
        end

        function o = createZoomBoxes(o)
            for i = 1:o.plotPairs
                fp = o.fullPlots{i};
                hold(fp, 'on');
                o.zoomRects{i} = fill( ...
                    [0, 0, 0, 0], [0, 0, 0, 0], ...
                    'b', ...
                    'Parent', fp, ...
                    'FaceAlpha', 0.3, ...
                    'HitTest', 'off' ...
                    );
                hold(fp, 'off');
            end
        end


        function o = restoreY(o)
            for i = 1:o.plotPairs
                yp1 = o.yLimits{i}(1);
                yp2 = o.yLimits{i}(2);
                o.zoomPlots{i}.YLim = [yp1, yp2];
                o.zoomRects{i}.YData = [yp1, yp1, yp2, yp2];
            end
        end

        function o = pan(o, dx)
            width = o.xZoom(2) - o.xZoom(1);
            if dx < 0
                % pan left
                xp1 = max(o.xLimit(1), o.xZoom(1) + dx * width);
                xp2 = xp1 + width;
            else
                % pan right
                xp2 = min(o.xZoom(2) + dx * width, o.xLimit(2));
                xp1 = xp2 - width;
            end
            o.setXZoom(xp1, xp2);
        end

        function o = zoom(o, k)
            xp1 = max(o.xLimit(1), (o.xZoom(1) * (1-k) + o.xZoom(2) * k));
            xp2 = min(o.xLimit(2), (o.xZoom(2) * (1-k) + o.xZoom(1) * k));
            o.setXZoom(xp1, xp2);
        end

        function o = zoomToRange(o, i, xr, yr)
            o.setXZoom(xr(1), xr(2));
            o.setYZoom(i, yr);
        end

        function o = setLimits(o, s)
            o.xLimit = s.xLimit;
            for i = 1:o.plotPairs
                o.yLimits{i} = s.yLimits{i};
                fp = o.fullPlots{i};
                fp.YLim = s.yLimits{i};
                fp.XLim = s.xLimit;
            end
            o.setXZoom(s.xZoom(1), s.xZoom(2));
            o.restoreY();
        end

        function o = zoomToBox(o, axes, p1, p2)
            if p1 == p2  % a click
                xc = p1(1,1);
                width = o.xZoom(2) - o.xZoom(1);
                xp1 = max(o.xLimit(1), xc - width / 2);
                xp2 = min(xp1 + width, o.xLimit(2));
                xp1 = xp2 - width;
            else
                xp1 = p1(1,1);
                xp2 = p2(1,1);
                yp1 = p1(1,2);
                yp2 = p2(1,2);
                for i = 1:o.plotPairs
                    if o.fullPlots{i} == axes || o.zoomPlots{i} == axes
                        o.setYZoom(i, sort([yp1, yp2]));
                    end
                end
            end
            o.setXZoom(xp1, xp2);
        end

        function o = makeZoomer(o, i)
            o.zoomPlots{i}.ButtonDownFcn = @o.buttDownFullAxis;
        end
    end
    methods (Access = private)

        function o = buttDownFullAxis(o, axes, ~)

            p1 = axes.CurrentPoint();
            rbbox();
            p2 = axes.CurrentPoint();

            o.zoomToBox(axes, p1, p2);
        end


        function a = findAxesWhichMouseIsOn(o)

            function a = isMouseOver(p, zone)
                a = ...
                    (p(1) >= zone(1)) && (p(1) <= zone(1) + zone(3)) && ...
                    (p(2) >= zone(2)) && (p(2) <= zone(2) + zone(4));
            end

            p = o.figure.CurrentPoint();
            for i = 1:length(o.fullPlots)
                zone = o.fullPlots{i}.Position();
                if isMouseOver(p, zone)
                    a = {'f', i, o.fullPlots{i}};
                    return
                end
            end
            for i = 1:length(o.zoomPlots)
                zone = o.zoomPlots{i}.Position();
                if isMouseOver(p, zone)
                    a = {'z', i, o.zoomPlots{i}};
                    return
                end
            end

            % not over any axes
            a = {0};
            return;

        end





        function wheelCallback(o,~,evt)
            mouseLoc = o.findAxesWhichMouseIsOn();
            if mouseLoc{1} == 0
                return
            end
            axesI = mouseLoc{2};
            axes = mouseLoc{3};
            wheelDir = evt.VerticalScrollCount;
            if (wheelDir > 0)
                k = -0.2;
            else
                k = 0.2;
            end
            if mouseLoc{1} == 'z'
                p = axes.CurrentPoint();
                xp = p(1,1);
                yp = p(1,2);
                xSpan = o.zoomPlots{axesI}.XLim;
                ySpan = o.zoomPlots{axesI}.YLim;
                xp1 = max(o.xLimit(1), (xSpan(1) * (1-k) + xp * k));
                xp2 = min(o.xLimit(2), (xSpan(2) * (1-k) + xp * k));
                yLim = o.yLimits{axesI};
                yp1 = max(yLim(1),(ySpan(1) * (1-k) + yp * k));
                yp2 = min(yLim(2),(ySpan(2) * (1-k) + yp * k));
                o.zoomPlots{axesI}.YLim = [yp1, yp2];
                o.zoomRects{axesI}.YData = [yp1, yp1, yp2, yp2];
            elseif mouseLoc{1} == 'f'
                k = k / 2;
                xp1 = max(o.xLimit(1), (o.xZoom(1) * (1-k) + o.xZoom(2) * k));
                xp2 = min(o.xLimit(2), (o.xZoom(2) * (1-k) + o.xZoom(1) * k));
            end

            o.setXZoom(xp1, xp2);
        end

        function o = setYZoom(o, i, range)
            o.zoomPlots{i}.YLim = range;
            o.zoomRects{i}.YData = range([1, 1, 2, 2]);
        end

        function o = setXZoom(o, xp1, xp2)
            o.xZoom = sort([xp1, xp2]);
            for i = 1:o.plotPairs
                o.zoomPlots{i}.XLim = o.xZoom;
                o.zoomRects{i}.XData = [xp1, xp2, xp2, xp1];
            end
        end
    end
end
